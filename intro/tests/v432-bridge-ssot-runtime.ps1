# SAGI V4.32 Bridge SSoT runtime self-test (Windows PowerShell 5.1)
# Runs the embedded Bridge in an isolated LOCALAPPDATA sandbox and verifies
# persistence, revision monotonicity, fixture ownership and explicit takeover.
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
$proc = $null
$startCount = 0
$bridgeOut = $null
$bridgeErr = $null

function Invoke-RawBridgeHttp {
  param(
    [string]$Method,
    [string]$Path,
    [string]$Body = ''
  )
  $client = New-Object System.Net.Sockets.TcpClient
  $stream = $null
  $ms = $null
  try {
    # GitHub Windows runners can briefly stall local PowerShell/TCP scheduling under parallel browser setup.
    # Keep the gate strict, but allow a longer first-byte window so runner jitter is not misclassified as Bridge failure.
    $client.ReceiveTimeout = 10000
    $client.SendTimeout = 10000
    $client.Connect('127.0.0.1',8100)
    $stream = $client.GetStream()

    $bodyBytes = [Text.Encoding]::UTF8.GetBytes([string]$Body)
    $head = $Method.ToUpperInvariant() + ' ' + $Path + " HTTP/1.1`r`nHost: 127.0.0.1`r`nConnection: close`r`n"
    if ($bodyBytes.Length -gt 0) {
      $head += "Content-Type: application/json; charset=utf-8`r`nContent-Length: " + $bodyBytes.Length + "`r`n"
    }
    $head += "`r`n"
    $headBytes = [Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($headBytes,0,$headBytes.Length)
    if ($bodyBytes.Length -gt 0) { $stream.Write($bodyBytes,0,$bodyBytes.Length) }
    $stream.Flush()

    $ms = New-Object IO.MemoryStream
    $buf = New-Object byte[] 8192
    while ($true) {
      try { $n = $stream.Read($buf,0,$buf.Length) }
      catch [IO.IOException] {
        if ($ms.Length -gt 0) { break }
        throw
      }
      if ($n -le 0) { break }
      $ms.Write($buf,0,$n)
    }
    $raw = [Text.Encoding]::UTF8.GetString($ms.ToArray())
    $split = $raw.IndexOf("`r`n`r`n")
    if ($split -lt 0) { throw ('Malformed HTTP response: ' + $raw) }
    $header = $raw.Substring(0,$split)
    $bodyText = $raw.Substring($split+4)
    $statusLine = ($header -split "`r`n")[0]
    $parts = $statusLine -split ' '
    if ($parts.Count -lt 2) { throw ('Malformed HTTP status: ' + $statusLine) }
    $status = 0
    if (-not [int]::TryParse($parts[1],[ref]$status)) { throw ('Invalid HTTP status: ' + $statusLine) }
    return [pscustomobject]@{Status=$status;Body=$bodyText;StatusLine=$statusLine}
  }
  finally {
    try { if ($ms) { $ms.Dispose() } } catch {}
    try { if ($stream) { $stream.Dispose() } } catch {}
    try { $client.Close() } catch {}
  }
}

function Invoke-RawBridgeHttpReliable {
  param(
    [string]$Method,
    [string]$Path,
    [string]$Body = ''
  )
  $last = $null
  for($attempt=1;$attempt -le 3;$attempt++){
    try { return Invoke-RawBridgeHttp -Method $Method -Path $Path -Body $Body }
    catch {
      $last = $_
      if($attempt -lt 3){ Start-Sleep -Milliseconds (150 * $attempt) }
    }
  }
  throw $last
}

function Read-BridgeLogs {
  $out=''; $err=''
  try { if($script:bridgeOut -and (Test-Path $script:bridgeOut)){ $out=Get-Content -LiteralPath $script:bridgeOut -Raw -ErrorAction SilentlyContinue } } catch {}
  try { if($script:bridgeErr -and (Test-Path $script:bridgeErr)){ $err=Get-Content -LiteralPath $script:bridgeErr -Raw -ErrorAction SilentlyContinue } } catch {}
  return [pscustomobject]@{Out=$out;Err=$err}
}

function Start-Bridge {
  $script:startCount++
  $script:bridgeOut = Join-Path $sandbox ('bridge-' + $script:startCount + '.stdout.log')
  $script:bridgeErr = Join-Path $sandbox ('bridge-' + $script:startCount + '.stderr.log')
  $script:proc = Start-Process -FilePath $ps51 -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$bridgePath) -PassThru -WindowStyle Hidden -RedirectStandardOutput $script:bridgeOut -RedirectStandardError $script:bridgeErr
  $end=(Get-Date).AddSeconds(25)
  while((Get-Date) -lt $end){
    try {
      $r=Invoke-RawBridgeHttp -Method 'GET' -Path ('/health?t=' + [DateTime]::UtcNow.Ticks)
      if($r.Status -eq 200){ return }
    } catch {}
    if($script:proc.HasExited){
      $logs=Read-BridgeLogs
      throw ('Bridge exited early code=' + $script:proc.ExitCode + ' stdout=' + $logs.Out + ' stderr=' + $logs.Err)
    }
    Start-Sleep -Milliseconds 350
  }
  $logs=Read-BridgeLogs
  throw ('Bridge did not become HTTP-ready on 8100 stdout=' + $logs.Out + ' stderr=' + $logs.Err)
}

function Stop-Bridge {
  if($script:proc -and -not $script:proc.HasExited){
    try { Stop-Process -Id $script:proc.Id -Force -ErrorAction Stop } catch {}
  }
  Start-Sleep -Milliseconds 700
}

function Get-State {
  $r=Invoke-RawBridgeHttpReliable -Method 'GET' -Path ('/api/matchday?t=' + [DateTime]::UtcNow.Ticks)
  if($r.Status -ne 200){ throw ('GET /api/matchday expected 200 got ' + $r.Status + ' body=' + $r.Body) }
  return ($r.Body | ConvertFrom-Json)
}

function New-State {
  param(
    [string]$Fixture,
    [int]$Revision,
    [string]$Command,
    [int]$Score,
    [bool]$Takeover
  )
  return [ordered]@{
    commandId=$Command
    revision=$Revision
    fixtureKey=$Fixture
    allowFixtureTakeover=$Takeover
    home='HOME'
    away='AWAY'
    competition='CI'
    homeScore=$Score
    awayScore=0
    scoreboardVisible=$true
    scoreboardFrozen=$false
    homeRedCards=0
    awayRedCards=0
    homePen=0
    awayPen=0
    penaltyShootout=[ordered]@{started=$false;history=@();finished=$false}
    simplePenalty=[ordered]@{visible=$false;home=0;away=0;history=@()}
    clock=[ordered]@{baseSeconds=0;running=$false;startedAt=$null;period='1H'}
    event=$null
    eventLog=@()
    replayMarkers=@()
    updatedAt=(Get-Date).ToUniversalTime().ToString('o')
  }
}

function Post-State {
  param($State,[int]$Expected)
  $body=$State | ConvertTo-Json -Depth 30 -Compress
  $r=Invoke-RawBridgeHttpReliable -Method 'POST' -Path '/api/matchday' -Body $body
  if([int]$r.Status -ne $Expected){
    throw ('Expected HTTP ' + $Expected + ' got ' + $r.Status + ' body=' + $r.Body)
  }
}

try {
  Start-Bridge
  $a='CI-FIXTURE-A|HOME|AWAY'
  $b='CI-FIXTURE-B|HOME|AWAY'

  $initial=New-State -Fixture $a -Revision 4 -Command 'a-r4' -Score 4 -Takeover $true
  $initial.event=[ordered]@{type='GOAL';eventId='ci-goal-r4';sequence=4}
  Post-State -State $initial -Expected 200
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw 'Initial authoritative state mismatch' }
  if($null -eq $s.event -or [string]$s.event.type -ne 'GOAL'){ throw 'Live event payload not visible before restart' }

  Post-State -State (New-State -Fixture $a -Revision 2 -Command 'a-r2-stale' -Score 99 -Takeover $false) -Expected 409
  $s=Get-State
  if([int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw 'Stale same-fixture write changed state' }

  Post-State -State (New-State -Fixture $b -Revision 99 -Command 'b-foreign' -Score 88 -Takeover $false) -Expected 409
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4){ throw 'Unapproved cross-fixture write changed state' }

  Stop-Bridge
  Start-Bridge
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){
    throw ('Restart persistence failed: fixture=' + $s.fixtureKey + ' revision=' + $s.revision + ' score=' + $s.homeScore)
  }
  if($null -ne $s.event){ throw ('Stale transient event survived Bridge restart: ' + ($s.event | ConvertTo-Json -Compress)) }

  Post-State -State (New-State -Fixture $b -Revision 100 -Command 'b-after-restart' -Score 77 -Takeover $false) -Expected 409
  $s=Get-State
  if([string]$s.fixtureKey -ne $a -or [int]$s.revision -ne 4){ throw 'Foreign stale controller took over after restart' }

  Post-State -State (New-State -Fixture $a -Revision 4 -Command 'a-conflict' -Score 66 -Takeover $false) -Expected 409
  $s=Get-State
  if([int]$s.revision -ne 4 -or [int]$s.homeScore -ne 4){ throw 'Equal-revision conflict changed state' }

  Post-State -State (New-State -Fixture $b -Revision 1 -Command 'b-authorized' -Score 1 -Takeover $true) -Expected 200
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
