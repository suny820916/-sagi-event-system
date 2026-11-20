# SAGI V4.32 Bridge SSoT runtime self-test (Windows PowerShell 5.1)
# Runs the embedded Bridge in an isolated LOCALAPPDATA sandbox.
$ErrorActionPreference = 'Stop'
$bat = (Resolve-Path (Join-Path $PSScriptRoot '..\SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat')).Path
$source = [IO.File]::ReadAllText($bat,[Text.Encoding]::UTF8)
$pattern = '(?s)###SAGI_PS###\r?\n(.*?)\r?\n###SAGI_CONTROL###\r?\n(.*?)\r?\n###SAGI_OUTPUT###\r?\n(.*)$'
$m = [regex]::Match($source,$pattern)
if (-not $m.Success) { throw 'embedded payload extraction failed' }

$oldLocal = $env:LOCALAPPDATA
$sandbox = Join-Path $env:RUNNER_TEMP ('sagi-v432-bridge-ssot-' + [guid]::NewGuid().ToString('N'))
$env:LOCALAPPDATA = $sandbox
$root = Join-Path $sandbox 'SAGI\LiveMatchDirector'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$bridgePath = Join-Path $root 'bridge-stable.ps1'
[IO.File]::WriteAllText($bridgePath,$m.Groups[1].Value,$utf8)
[IO.File]::WriteAllText((Join-Path $root 'control-latest.html'),$m.Groups[2].Value,$utf8)
[IO.File]::WriteAllText((Join-Path $root 'output-latest.html'),$m.Groups[3].Value,$utf8)

$ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$base = 'http://127.0.0.1:8100'
$proc = $null

function Start-Bridge {
  $script:proc = Start-Process -FilePath $ps51 -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$bridgePath) -PassThru -WindowStyle Hidden
  $end=(Get-Date).AddSeconds(25)
  while((Get-Date) -lt $end){
    try { $r=Invoke-WebRequest -UseBasicParsing -Uri ($base+'/health?t='+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -TimeoutSec 2; if($r.StatusCode -eq 200){ return } } catch {}
    Start-Sleep -Milliseconds 500
  }
  throw 'Bridge did not start on 8100'
}
function Stop-Bridge {
  if($script:proc -and -not $script:proc.HasExited){ try { Stop-Process -Id $script:proc.Id -Force -ErrorAction Stop } catch {} }
  Start-Sleep -Milliseconds 700
}
function Get-State {
  $r=Invoke-WebRequest -UseBasicParsing -Uri ($base+'/api/matchday?t='+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -TimeoutSec 3
  return ($r.Content | ConvertFrom-Json)
}
function New-State([string]$fixture,[int]$revision,[string]$command,[int]$score,[bool]$takeover){
  return [ordered]@{
    commandId=$command; revision=$revision; fixtureKey=$fixture; allowFixtureTakeover=$takeover;
    home='HOME'; away='AWAY'; competition='CI'; homeScore=$score; awayScore=0;
    scoreboardVisible=$true; scoreboardFrozen=$false; homeRedCards=0; awayRedCards=0;
    homePen=0; awayPen=0; penaltyShootout=[ordered]@{started=$false;history=@();finished=$false};
    simplePenalty=[ordered]@{visible=$false;home=0;away=0;history=@()};
    clock=[ordered]@{baseSeconds=0;running=$false;startedAt=$null;period='1H'};
    event=$null; eventLog=@(); replayMarkers=@(); updatedAt=(Get-Date).ToUniversalTime().ToString('o')
  }
}
function Post-State($state,[int]$expected){
  $body=$state | ConvertTo-Json -Depth 30 -Compress
  $status=0
  try {
    $r=Invoke-WebRequest -UseBasicParsing -Uri ($base+'/api/matchday') -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 4
    $status=[int]$r.StatusCode
  } catch {
    if($_.Exception.Response){ $status=[int]$_.Exception.Response.StatusCode.value__ } else { throw }
  }
  if($status -ne $expected){ throw ('Expected HTTP '+$expected+' got '+$status) }
}

try {
  Start-Bridge
  $a='CI-FIXTURE-A|HOME|AWAY'
  $b='CI-FIXTURE-B|HOME|AWAY'

  Post-State (New-State $a 4 'a-r4' 4 $true) 200
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw 'Initial authoritative state mismatch' }

  Post-State (New-State $a 2 'a-r2-stale' 99 $false) 409
  $s=Get-State
  if([int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw 'Stale same-fixture write changed state' }

  Post-State (New-State $b 99 'b-foreign' 88 $false) 409
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4){ throw 'Unapproved cross-fixture write changed state' }

  Stop-Bridge
  Start-Bridge
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw ('Restart persistence failed: fixture='+$s.fixtureKey+' revision='+$s.revision+' score='+$s.homeScore) }

  Post-State (New-State $b 100 'b-after-restart' 77 $false) 409
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4){ throw 'Foreign stale controller took over after restart' }

  Post-State (New-State $a 4 'a-conflict' 66 $false) 409
  $s=Get-State
  if([int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw 'Equal-revision conflict changed state' }

  Post-State (New-State $b 1 'b-authorized' 1 $true) 200
  $s=Get-State
  if([string]$s.fixtureKey -ne $b -or [int]$s.revision -ne 1 -or [int]$s.homeScore -ne 1){ throw 'Authorized fixture takeover failed' }

  Stop-Bridge
  Start-Bridge
  $s=Get-State
  if([string]$s.fixtureKey -ne $b -or [int]$s.revision -ne 1){ throw 'Authorized fixture did not persist across restart' }

  Write-Host 'V4.32 BRIDGE SSOT RUNTIME PASS'
}
finally {
  Stop-Bridge
  $env:LOCALAPPDATA=$oldLocal
  Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
