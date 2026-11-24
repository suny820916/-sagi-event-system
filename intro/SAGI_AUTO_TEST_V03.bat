@echo off
chcp 65001 >nul
setlocal
title SAGI AUTO TEST V0.3 - V4.33 LIVE SAFE ACCEPTANCE
set "SAGI_AUTO_SELF=%~f0"

echo.
echo ============================================================
echo   SAGI AUTO TEST V0.3 / V4.33 LIVE-SAFE ACCEPTANCE
echo ============================================================
echo [SAFE] Localhost only. No cloud dependency.
echo [SAFE] Snapshot first; isolated mutation; automatic restore.
echo [SAFE] If a live match is detected, mutation tests are skipped.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$src=[IO.File]::ReadAllText($env:SAGI_AUTO_SELF,[Text.Encoding]::UTF8);" ^
 "$m=[regex]::Match($src,'(?s)###SAGI_AUTO_TEST_PS###\r?\n(.*)$');" ^
 "if(-not $m.Success){Write-Host '[FAIL] Embedded AUTO TEST payload missing.' -ForegroundColor Red;exit 90};" ^
 "$sb=[scriptblock]::Create($m.Groups[1].Value);& $sb"

set "SAGI_AUTO_RC=%ERRORLEVEL%"
echo.
if "%SAGI_AUTO_RC%"=="0" (
  echo [PASS] SAGI AUTO TEST V0.3 completed.
) else if "%SAGI_AUTO_RC%"=="3" (
  echo [SAFE GUARD] Live activity detected. Mutation suite was not executed.
) else (
  echo [CHECK] AUTO TEST found a failure. Open the generated report.
)
echo.
pause
exit /b %SAGI_AUTO_RC%

###SAGI_AUTO_TEST_PS###
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$Base = 'http://127.0.0.1:8100'
$VmixApi = 'http://127.0.0.1:8088/api/'
$Root = Join-Path $env:LOCALAPPDATA 'SAGI\LiveMatchDirector'
$ReportDir = Join-Path $env:LOCALAPPDATA 'SAGI\AutoTest'
$Control = Join-Path $Root 'control-latest.html'
$Output = Join-Path $Root 'output-latest.html'
$Bridge = Join-Path $Root 'bridge-stable.ps1'
$results = New-Object System.Collections.ArrayList
$latencies = New-Object System.Collections.ArrayList
$mutationRan = $false
$restoreAttempted = $false
$restoreVerified = $false
$originalRaw = ''
$originalObj = $null
$originalWasNull = $true
$testRevision = 0L
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runId = 'autotest-' + $stamp + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)

function Add-Result([string]$Name,[bool]$Pass,[string]$Detail,[string]$Kind='CHECK') {
  [void]$results.Add([pscustomobject]@{name=$Name;pass=$Pass;kind=$Kind;detail=$Detail})
  $tag = if($Pass){'PASS'}else{'FAIL'}
  $color = if($Pass){'Green'}else{'Yellow'}
  Write-Host "[$tag] $Name : $Detail" -ForegroundColor $color
}

function Read-Utf8([string]$Path) {
  try { return [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8) } catch { return '' }
}

function Test-Tcp([int]$Port,[int]$TimeoutMs=1200) {
  $client = $null
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $ar = $client.BeginConnect('127.0.0.1',$Port,$null,$null)
    if(-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs,$false)){ return $false }
    $client.EndConnect($ar)
    return $true
  } catch { return $false }
  finally { if($client){$client.Close()} }
}

function Invoke-LocalGetRaw([string]$Path,[int]$TimeoutSec=3) {
  $r = Invoke-WebRequest -UseBasicParsing -Uri ($Base + $Path) -TimeoutSec $TimeoutSec -Headers @{'Cache-Control'='no-store'}
  return [string]$r.Content
}

function Invoke-LocalGetJson([string]$Path,[int]$TimeoutSec=3) {
  $raw = Invoke-LocalGetRaw $Path $TimeoutSec
  if([string]::IsNullOrWhiteSpace($raw)){ return $null }
  return ($raw | ConvertFrom-Json)
}

function Invoke-LocalPostObject([string]$Path,$Object,[int]$TimeoutSec=4) {
  $json = $Object | ConvertTo-Json -Depth 40 -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-WebRequest -UseBasicParsing -Uri ($Base + $Path) -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec $TimeoutSec
    $sw.Stop()
    return [pscustomobject]@{ok=($r.StatusCode -ge 200 -and $r.StatusCode -lt 300);status=[int]$r.StatusCode;body=[string]$r.Content;latencyMs=[int]$sw.ElapsedMilliseconds}
  } catch [System.Net.WebException] {
    $status = 0
    $body = $_.Exception.Message
    try {
      if($_.Exception.Response){
        $status = [int]$_.Exception.Response.StatusCode
        $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
        try { $body = $sr.ReadToEnd() } finally { $sr.Dispose() }
      }
    } catch {}
    return [pscustomobject]@{ok=$false;status=$status;body=$body;latencyMs=-1}
  } catch {
    return [pscustomobject]@{ok=$false;status=0;body=$_.Exception.Message;latencyMs=-1}
  }
}

function Invoke-LocalPostEmpty([string]$Path,[int]$TimeoutSec=4) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri ($Base + $Path) -Method Post -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes('{}')) -TimeoutSec $TimeoutSec
    return [pscustomobject]@{ok=($r.StatusCode -ge 200 -and $r.StatusCode -lt 300);status=[int]$r.StatusCode;body=[string]$r.Content}
  } catch {
    return [pscustomobject]@{ok=$false;status=0;body=$_.Exception.Message}
  }
}

function Clone-JsonObject($Object) {
  if($null -eq $Object){ return [pscustomobject]@{} }
  return (($Object | ConvertTo-Json -Depth 40 -Compress) | ConvertFrom-Json)
}

function Set-Prop($Object,[string]$Name,$Value) {
  if($Object.PSObject.Properties.Name -contains $Name){ $Object.$Name = $Value }
  else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Get-LongProp($Object,[string]$Name) {
  try { return [int64]$Object.$Name } catch { return 0L }
}

function Get-HistoryCount($Object) {
  try {
    if($Object.penaltyShootout -and $Object.penaltyShootout.history){ return @($Object.penaltyShootout.history).Count }
  } catch {}
  return 0
}

function Important-State-Same($A,$B) {
  if($null -eq $A -or $null -eq $B){ return $false }
  $keys = @('fixtureKey','competition','home','away','homeScore','awayScore','homePen','awayPen','scoreboardVisible','overlayVisible')
  foreach($k in $keys){
    $av = $null; $bv = $null
    try { $av = $A.$k } catch {}
    try { $bv = $B.$k } catch {}
    if([string]$av -ne [string]$bv){ return $false }
  }
  if((Get-HistoryCount $A) -ne (Get-HistoryCount $B)){ return $false }
  try {
    $ar = [bool]$A.clock.running
    $br = [bool]$B.clock.running
    if($ar -ne $br){ return $false }
  } catch {}
  return $true
}

function Percentile95($Values) {
  $a = @($Values | Sort-Object)
  if($a.Count -eq 0){ return 0 }
  $i = [Math]::Ceiling($a.Count * 0.95) - 1
  if($i -lt 0){$i=0}
  if($i -ge $a.Count){$i=$a.Count-1}
  return [int]$a[$i]
}

function Make-Penalty([bool]$Started,[object[]]$History) {
  $h = @($History)
  $home = @($h | Where-Object { $_.side -eq 'HOME' })
  $away = @($h | Where-Object { $_.side -eq 'AWAY' })
  $hg = @($home | Where-Object { $_.result -eq 'GOAL' }).Count
  $ag = @($away | Where-Object { $_.result -eq 'GOAL' }).Count
  $next = if($h.Count % 2 -eq 0){'HOME'}else{'AWAY'}
  return [pscustomobject]@{
    started=$Started;rounds=5;firstSide='HOME';history=$h;winner='';finished=$false;
    nextSide=$next;currentRound=([Math]::Min($home.Count,$away.Count)+1);suddenDeath=$false;
    homeAttempts=$home.Count;awayAttempts=$away.Count;homeGoals=$hg;awayGoals=$ag;
    status=$(if($Started){'AUTO TEST'}else{'WAITING'});coreVersion='4.33.0-rc.1'
  }
}

function Make-SimplePenalty([bool]$Visible,[object[]]$History) {
  $h = @($History)
  $home = @($h | Where-Object { $_.side -eq 'HOME' })
  $away = @($h | Where-Object { $_.side -eq 'AWAY' })
  return [pscustomobject]@{
    visible=$Visible;
    home=@($home | Where-Object { $_.result -eq 'GOAL' }).Count;
    away=@($away | Where-Object { $_.result -eq 'GOAL' }).Count;
    history=$h;round=[Math]::Max($home.Count,$away.Count);suddenDeath=$false;slots=5;
    nextSide=$(if($h.Count % 2 -eq 0){'HOME'}else{'AWAY'});finished=$false;winner=''
  }
}

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
Write-Host ''
Write-Host ('SAGI AUTO TEST V0.3  |  Run: ' + $runId) -ForegroundColor Cyan
Write-Host ('Computer: ' + $env:COMPUTERNAME + '  PowerShell: ' + $PSVersionTable.PSVersion.ToString())
Write-Host ''

$bridgePort = Test-Tcp 8100
$vmixPort = Test-Tcp 8088
Add-Result 'bridge-port-8100' $bridgePort $(if($bridgePort){'reachable'}else{'not listening'}) 'PREFLIGHT'
Add-Result 'vmix-api-8088' $vmixPort $(if($vmixPort){'reachable'}else{'not listening'}) 'PREFLIGHT'

$controlText = Read-Utf8 $Control
$outputText = Read-Utf8 $Output
$bridgeText = Read-Utf8 $Bridge
Add-Result 'control-v433-marker' ($controlText -match 'SAGI433_PENALTY_RC1' -and $controlText -match 'SAGIPenaltyCore') 'V4.33 penalty control installed' 'PREFLIGHT'
Add-Result 'output-penalty-contract' ($outputText -match 'penaltyShootout' -and $outputText -match 'penDot') 'vMix output contains penalty state + dot renderer' 'PREFLIGHT'
Add-Result 'bridge-v472-runtime' ($bridgeText -match '4\.7\.2' -or $controlText -match '4\.33') 'local V4.33 runtime files present' 'PREFLIGHT'

$health = $null
try { $health = Invoke-LocalGetJson '/health?autotest=1' 3 } catch {}
$healthPass = ($null -ne $health -and [string]$health.version -eq '4.33' -and [string]$health.bridgeVersion -eq '4.7.2')
Add-Result 'bridge-health-version' $healthPass $(if($health){'V'+$health.version+' / Bridge '+$health.bridgeVersion}else{'no health response'}) 'PREFLIGHT'
Add-Result 'bridge-health-vmix' ($null -ne $health -and [bool]$health.vmix) $(if($health){'vmix='+[string]$health.vmix}else{'no health response'}) 'PREFLIGHT'

$vmixRaw = ''
try {
  $vr = Invoke-WebRequest -UseBasicParsing -Uri $VmixApi -TimeoutSec 3
  $vmixRaw = [string]$vr.Content
} catch {}
Add-Result 'vmix-xml-readable' ($vmixRaw -match '<vmix' -and $vmixRaw -match '<inputs') ('bytes=' + $vmixRaw.Length) 'PREFLIGHT'

try {
  $originalRaw = Invoke-LocalGetRaw ('/api/matchday?autotestSnapshot=' + [uri]::EscapeDataString($runId)) 3
  if(-not [string]::IsNullOrWhiteSpace($originalRaw) -and $originalRaw.Trim() -ne 'null'){
    $originalObj = $originalRaw | ConvertFrom-Json
    $originalWasNull = $false
  }
  Add-Result 'snapshot-matchday' $true $(if($originalWasNull){'Bridge state is empty'}else{'snapshot R'+(Get-LongProp $originalObj 'revision')}) 'SNAPSHOT'
} catch {
  Add-Result 'snapshot-matchday' $false $_.Exception.Message 'SNAPSHOT'
}

$projectsOk = $false
try {
  $projectsRaw = Invoke-LocalGetRaw ('/api/projects?autotest=' + [uri]::EscapeDataString($runId)) 3
  $projectsObj = $projectsRaw | ConvertFrom-Json
  $projectsOk = ($projectsObj.PSObject.Properties.Name -contains 'projects')
  Add-Result 'project-library-read' $projectsOk ('projects=' + @($projectsObj.projects).Count) 'SNAPSHOT'
} catch { Add-Result 'project-library-read' $false $_.Exception.Message 'SNAPSHOT' }

for($i=0;$i -lt 20;$i++){
  try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $null = Invoke-LocalGetRaw ('/health?latency=' + $i + '&ts=' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) 3
    $sw.Stop()
    [void]$latencies.Add([int]$sw.ElapsedMilliseconds)
  } catch {}
  Start-Sleep -Milliseconds 35
}
$lat = @($latencies.ToArray())
$avg = if($lat.Count){[int](($lat | Measure-Object -Average).Average)}else{0}
$max = if($lat.Count){[int](($lat | Measure-Object -Maximum).Maximum)}else{0}
$p95 = Percentile95 $lat
Add-Result 'lan-latency-20x' ($lat.Count -eq 20) ('samples='+$lat.Count+' avg='+$avg+'ms p95='+$p95+'ms max='+$max+'ms') 'LATENCY'

$clockRunning = $false
$visibleLive = $false
$transientEvent = $false
if(-not $originalWasNull){
  try { $clockRunning = [bool]$originalObj.clock.running } catch {}
  try { $visibleLive = ([bool]$originalObj.scoreboardVisible -and [bool]$originalObj.overlayVisible) } catch {}
  try { $transientEvent = ($null -ne $originalObj.event) } catch {}
}
$liveRisk = $clockRunning -or $visibleLive -or $transientEvent
Add-Result 'live-safety-guard' $true $(if($liveRisk){'LIVE indicators detected; mutation suite will be skipped'}else{'no active live indicators; isolated mutation allowed'}) 'SAFETY'

$criticalPreflight = @('bridge-port-8100','vmix-api-8088','control-v433-marker','output-penalty-contract','bridge-health-version','bridge-health-vmix','vmix-xml-readable','snapshot-matchday','project-library-read')
$preflightFailed = @($results | Where-Object { $criticalPreflight -contains $_.name -and -not $_.pass })

if($preflightFailed.Count -eq 0 -and -not $liveRisk){
  $mutationRan = $true
  Write-Host ''
  Write-Host '[MUTATION] Isolated test fixture starting. Original state is already snapshotted.' -ForegroundColor Cyan
  $testState = if($originalWasNull){[pscustomobject]@{}}else{Clone-JsonObject $originalObj}
  $baseRevision = if($originalWasNull){0L}else{Get-LongProp $originalObj 'revision'}
  $testRevision = [Math]::Max(1000L,$baseRevision + 1000L)
  $fixture = 'sagi-auto-test|' + $runId
  Set-Prop $testState 'fixtureKey' $fixture
  Set-Prop $testState 'competition' 'SAGI AUTO TEST'
  Set-Prop $testState 'home' 'AUTO HOME'
  Set-Prop $testState 'away' 'AUTO AWAY'
  Set-Prop $testState 'homeShort' 'AUTO HOME'
  Set-Prop $testState 'awayShort' 'AUTO AWAY'
  Set-Prop $testState 'scoreHomeName' 'AUTO H'
  Set-Prop $testState 'scoreAwayName' 'AUTO A'
  Set-Prop $testState 'homeScore' 0
  Set-Prop $testState 'awayScore' 0
  Set-Prop $testState 'homePen' 0
  Set-Prop $testState 'awayPen' 0
  Set-Prop $testState 'homeRedCards' 0
  Set-Prop $testState 'awayRedCards' 0
  Set-Prop $testState 'scoreboardVisible' $false
  Set-Prop $testState 'overlayVisible' $false
  Set-Prop $testState 'event' $null
  Set-Prop $testState 'lastEvent' $null
  Set-Prop $testState 'penaltyShootout' (Make-Penalty $false @())
  Set-Prop $testState 'simplePenalty' (Make-SimplePenalty $false @())
  $clock = [pscustomobject]@{baseSeconds=0;running=$false;startedAt=$null;period='1H'}
  Set-Prop $testState 'clock' $clock
  Set-Prop $testState 'allowFixtureTakeover' $true
  Set-Prop $testState 'revision' $testRevision
  Set-Prop $testState 'commandId' ($runId + '-fixture')
  Set-Prop $testState 'updatedAt' (Get-Date).ToUniversalTime().ToString('o')

  try {
    $r = Invoke-LocalPostObject '/api/matchday' $testState
    $after = Invoke-LocalGetJson ('/api/matchday?verifyFixture=' + [uri]::EscapeDataString($runId)) 3
    $ok = $r.ok -and [string]$after.fixtureKey -eq $fixture -and [int]$after.homeScore -eq 0 -and [int]$after.awayScore -eq 0
    Add-Result 'isolated-fixture-commit' $ok ('HTTP '+$r.status+' / '+$r.latencyMs+'ms / R'+$testRevision) 'MUTATION'

    $testRevision++
    Set-Prop $testState 'homeScore' 1
    Set-Prop $testState 'revision' $testRevision
    Set-Prop $testState 'commandId' ($runId + '-score-home-1')
    $rScore = Invoke-LocalPostObject '/api/matchday' $testState
    $afterScore = Invoke-LocalGetJson ('/api/matchday?verifyScore=' + [uri]::EscapeDataString($runId)) 3
    Add-Result 'score-roundtrip-home-plus' ($rScore.ok -and [int]$afterScore.homeScore -eq 1 -and [int]$afterScore.awayScore -eq 0) ('HTTP '+$rScore.status+' / '+$rScore.latencyMs+'ms') 'MUTATION'

    $rDup = Invoke-LocalPostObject '/api/matchday' $testState
    $afterDup = Invoke-LocalGetJson ('/api/matchday?verifyIdempotent=' + [uri]::EscapeDataString($runId)) 3
    Add-Result 'same-command-idempotent-retry' ($rDup.ok -and [int]$afterDup.homeScore -eq 1) ('HTTP '+$rDup.status) 'MUTATION'

    $conflict = Clone-JsonObject $testState
    Set-Prop $conflict 'commandId' ($runId + '-conflict-same-revision')
    $rConflict = Invoke-LocalPostObject '/api/matchday' $conflict
    Add-Result 'same-revision-conflict-guard' ($rConflict.status -eq 409) ('HTTP '+$rConflict.status) 'MUTATION'

    $stale = Clone-JsonObject $testState
    Set-Prop $stale 'revision' ($testRevision - 1)
    Set-Prop $stale 'commandId' ($runId + '-stale-revision')
    $rStale = Invoke-LocalPostObject '/api/matchday' $stale
    Add-Result 'stale-revision-guard' ($rStale.status -eq 409) ('HTTP '+$rStale.status) 'MUTATION'

    $testRevision++
    Set-Prop $testState 'revision' $testRevision
    Set-Prop $testState 'commandId' ($runId + '-penalty-start')
    Set-Prop $testState 'clock' ([pscustomobject]@{baseSeconds=0;running=$false;startedAt=$null;period='PEN'})
    Set-Prop $testState 'penaltyShootout' (Make-Penalty $true @())
    Set-Prop $testState 'simplePenalty' (Make-SimplePenalty $false @())
    $rPenStart = Invoke-LocalPostObject '/api/matchday' $testState
    $penStart = Invoke-LocalGetJson ('/api/matchday?verifyPenaltyStart=' + [uri]::EscapeDataString($runId)) 3
    Add-Result 'penalty-start-roundtrip' ($rPenStart.ok -and [bool]$penStart.penaltyShootout.started -and (Get-HistoryCount $penStart) -eq 0) ('HTTP '+$rPenStart.status) 'MUTATION'

    $kick = [pscustomobject]@{kickId=($runId+'-kick-home-goal');side='HOME';result='GOAL';at=(Get-Date).ToUniversalTime().ToString('o')}
    $history = @($kick)
    $testRevision++
    Set-Prop $testState 'revision' $testRevision
    Set-Prop $testState 'commandId' ($runId + '-penalty-home-goal')
    Set-Prop $testState 'homePen' 1
    Set-Prop $testState 'awayPen' 0
    Set-Prop $testState 'penaltyShootout' (Make-Penalty $true $history)
    Set-Prop $testState 'simplePenalty' (Make-SimplePenalty $false $history)
    $rKick = Invoke-LocalPostObject '/api/matchday' $testState
    $afterKick = Invoke-LocalGetJson ('/api/matchday?verifyPenaltyKick=' + [uri]::EscapeDataString($runId)) 3
    $kickOk = $rKick.ok -and [int]$afterKick.homePen -eq 1 -and (Get-HistoryCount $afterKick) -eq 1 -and [string]$afterKick.penaltyShootout.history[0].result -eq 'GOAL'
    Add-Result 'penalty-home-goal-history-dot-state' $kickOk ('HTTP '+$rKick.status+' / history='+(Get-HistoryCount $afterKick)+' / homePen='+$afterKick.homePen) 'MUTATION'

    $testRevision++
    Set-Prop $testState 'revision' $testRevision
    Set-Prop $testState 'commandId' ($runId + '-penalty-undo')
    Set-Prop $testState 'homePen' 0
    Set-Prop $testState 'penaltyShootout' (Make-Penalty $true @())
    Set-Prop $testState 'simplePenalty' (Make-SimplePenalty $false @())
    $rUndo = Invoke-LocalPostObject '/api/matchday' $testState
    $afterUndo = Invoke-LocalGetJson ('/api/matchday?verifyPenaltyUndo=' + [uri]::EscapeDataString($runId)) 3
    Add-Result 'penalty-undo-roundtrip' ($rUndo.ok -and [int]$afterUndo.homePen -eq 0 -and (Get-HistoryCount $afterUndo) -eq 0) ('HTTP '+$rUndo.status) 'MUTATION'
  } catch {
    Add-Result 'mutation-suite-exception' $false $_.Exception.Message 'MUTATION'
  } finally {
    $restoreAttempted = $true
    try {
      if($originalWasNull){
        $rr = Invoke-LocalPostEmpty '/api/recovery/reset' 4
        $checkRaw = Invoke-LocalGetRaw ('/api/matchday?verifyRestore=' + [uri]::EscapeDataString($runId)) 3
        $restoreVerified = $rr.ok -and ($checkRaw.Trim() -eq 'null')
        Add-Result 'restore-original-empty-state' $restoreVerified ('HTTP '+$rr.status) 'RESTORE'
      } else {
        $restore = Clone-JsonObject $originalObj
        $testRevision = [Math]::Max($testRevision + 100L,(Get-LongProp $originalObj 'revision') + 2000L)
        Set-Prop $restore 'revision' $testRevision
        Set-Prop $restore 'commandId' ($runId + '-restore')
        Set-Prop $restore 'allowFixtureTakeover' $true
        Set-Prop $restore 'event' $null
        Set-Prop $restore 'lastEvent' $null
        Set-Prop $restore 'updatedAt' (Get-Date).ToUniversalTime().ToString('o')
        $rr = Invoke-LocalPostObject '/api/matchday' $restore
        $restored = Invoke-LocalGetJson ('/api/matchday?verifyRestore=' + [uri]::EscapeDataString($runId)) 3
        $restoreVerified = $rr.ok -and (Important-State-Same $originalObj $restored)
        Add-Result 'restore-original-match-state' $restoreVerified ('HTTP '+$rr.status+' / restored as R'+$testRevision) 'RESTORE'
      }
    } catch {
      Add-Result 'restore-original-match-state' $false $_.Exception.Message 'RESTORE'
    }
  }
} elseif($liveRisk) {
  Add-Result 'mutation-suite' $true 'SKIPPED BY LIVE SAFETY GUARD' 'SAFETY'
} else {
  Add-Result 'mutation-suite' $false 'SKIPPED because preflight failed' 'SAFETY'
}

$report = [pscustomobject]@{
  schema='SAGI_AUTO_TEST_V03'
  version='0.3'
  target='SAGI V4.33 PENALTY RC'
  runId=$runId
  timestampUtc=(Get-Date).ToUniversalTime().ToString('o')
  computer=$env:COMPUTERNAME
  powershell=$PSVersionTable.PSVersion.ToString()
  localhostOnly=$true
  liveRiskDetected=$liveRisk
  mutationSuiteRan=$mutationRan
  restoreAttempted=$restoreAttempted
  restoreVerified=$restoreVerified
  latency=[pscustomobject]@{samples=$lat.Count;averageMs=$avg;p95Ms=$p95;maxMs=$max;values=@($lat)}
  checks=@($results.ToArray())
}
$jsonPath = Join-Path $ReportDir ('SAGI_AUTO_TEST_V03_' + $stamp + '.json')
$txtPath = Join-Path $ReportDir ('SAGI_AUTO_TEST_V03_' + $stamp + '.txt')
[IO.File]::WriteAllText($jsonPath,($report | ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
$txt = New-Object System.Collections.Generic.List[string]
$txt.Add('SAGI AUTO TEST V0.3')
$txt.Add('Run: ' + $runId)
$txt.Add('UTC: ' + $report.timestampUtc)
$txt.Add('Live risk: ' + $liveRisk)
$txt.Add('Mutation suite: ' + $(if($mutationRan){'RAN'}else{'SKIPPED'}))
$txt.Add('Restore verified: ' + $restoreVerified)
$txt.Add('Latency: avg ' + $avg + 'ms / p95 ' + $p95 + 'ms / max ' + $max + 'ms')
$txt.Add('')
foreach($x in $results){$txt.Add('['+$(if($x.pass){'PASS'}else{'FAIL'})+'] '+$x.kind+' / '+$x.name+' : '+$x.detail)}
[IO.File]::WriteAllLines($txtPath,$txt,(New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ('Report JSON: ' + $jsonPath) -ForegroundColor Cyan
Write-Host ('Report TXT : ' + $txtPath) -ForegroundColor Cyan
try { Start-Process notepad.exe $txtPath } catch {}

$failed = @($results | Where-Object { -not $_.pass })
if($failed.Count -gt 0){ exit 1 }
if($liveRisk){ exit 3 }
if($mutationRan -and -not $restoreVerified){ exit 2 }
exit 0
