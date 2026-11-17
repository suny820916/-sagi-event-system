@echo off
chcp 65001 >nul
setlocal
title SAGI VMIX LAN - V4.8 STABLE LAN / STABILITY 4.30.8

echo.
echo ==========================================
echo   SAGI LIVE MATCH DIRECTOR - LAN DIRECT
echo      V4.8 STABLE LAN / STABILITY 4.30.8
echo ==========================================
echo.
echo [SAFE] Phone control starts even if vMix is offline.
echo [SAFE] Preferred LAN port is fixed at 8100.
echo [SAFE] Bridge core locked to V4.7.2 stable build; UI/graphics unified at penalty sync 4.23.5.
echo.

set "SAGI_ROOT=%LOCALAPPDATA%\SAGI\LiveMatchDirector"
set "SAGI_SELF=%~f0"
set "SAGI_BRIDGE=%SAGI_ROOT%\bridge-stable.ps1"
set "SAGI_CONTROL=%SAGI_ROOT%\control-latest.html"
set "SAGI_OUTPUT=%SAGI_ROOT%\output-latest.html"
set "SAGI_FB_BRIDGE=%SAGI_ROOT%\fallback-bridge.ps1"
set "SAGI_FB_CONTROL=%SAGI_ROOT%\fallback-control.html"
set "SAGI_FB_OUTPUT=%SAGI_ROOT%\fallback-output.html"

if not exist "%SAGI_ROOT%" mkdir "%SAGI_ROOT%"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$s=[IO.File]::ReadAllText($env:SAGI_SELF,[Text.Encoding]::UTF8);" ^
 "$m=[regex]::Match($s,'(?s)###SAGI_PS###\r?\n(.*?)\r?\n###SAGI_CONTROL###\r?\n(.*?)\r?\n###SAGI_OUTPUT###\r?\n(.*)$');" ^
 "if(-not $m.Success){Write-Host '[ERROR] Embedded stable payload not found.' -ForegroundColor Red;exit 2};" ^
 "$utf=New-Object Text.UTF8Encoding($false);" ^
 "[IO.File]::WriteAllText($env:SAGI_FB_BRIDGE,$m.Groups[1].Value,$utf);" ^
 "[IO.File]::WriteAllText($env:SAGI_FB_CONTROL,$m.Groups[2].Value,$utf);" ^
 "[IO.File]::WriteAllText($env:SAGI_FB_OUTPUT,$m.Groups[3].Value,$utf);" ^
 "Copy-Item $env:SAGI_FB_BRIDGE $env:SAGI_BRIDGE -Force;" ^
 "$controlOk=$false;if(Test-Path $env:SAGI_CONTROL){try{$t=[IO.File]::ReadAllText($env:SAGI_CONTROL,[Text.Encoding]::UTF8);$controlOk=($t.Length -gt 100000 -and $t -match '<!doctype html>' -and $t -match 'V4\.30\.5' -and $t -match 'mdSyncDirectorPenaltyToSimple' -and $t -match 'simplePenaltyControl' -and $t -match 'replayStinger' -and $t -match 'data:image/svg\+xml')}catch{}};" ^
 "if(-not $controlOk){Copy-Item $env:SAGI_FB_CONTROL $env:SAGI_CONTROL -Force;Write-Host '[REPAIR] Control Room upgraded/restored to V4.30.8 STABILITY.' -ForegroundColor Yellow}else{Write-Host '[SAFE] Existing V4.30.8 Control Room kept.' -ForegroundColor Green};" ^
 "$outputOk=$false;if(Test-Path $env:SAGI_OUTPUT){try{$t=[IO.File]::ReadAllText($env:SAGI_OUTPUT,[Text.Encoding]::UTF8);$outputOk=($t.Length -gt 50000 -and $t -match '<!doctype html>' -and $t -match 'V4\.30\.5' -and $t -match 'simplePenaltyBoard' -and $t -match 'penaltyShootout' -and $t -match 'sagiToranhe' -and $t -match 'eventCleanupTimer' -and $t -match 'data:image/svg\+xml')}catch{}};" ^
 "if(-not $outputOk){Copy-Item $env:SAGI_FB_OUTPUT $env:SAGI_OUTPUT -Force;Write-Host '[REPAIR] vMix Graphics upgraded/restored to V4.30.8 TORANHE SCOREBUG.' -ForegroundColor Yellow}else{Write-Host '[SAFE] Existing V4.30.8 vMix Graphics kept.' -ForegroundColor Green};"

if errorlevel 1 (
  echo.
  echo [ERROR] Unable to prepare stable local files.
  pause
  exit /b 1
)

echo.
echo [READY] Starting SAGI LAN Bridge...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SAGI_BRIDGE%"

echo.
pause
exit /b

###SAGI_PS###
# SAGI V4.7.2 STABLE LAN / FILTER ENGINE / MATCH SAFE Bridge
# Same-LAN control server + local vMix API bridge.
# Phone Control: http://<PC-LAN-IP>:8099/
# vMix Browser:  http://127.0.0.1:8099/vmix

$PreferredPort = 8100
$Port = $PreferredPort
$VmixApi = "http://127.0.0.1:8088/api/"
$Root = Join-Path $env:LOCALAPPDATA "SAGI\LiveMatchDirector"
New-Item -ItemType Directory -Force -Path $Root | Out-Null

$ControlCache = Join-Path $Root "control-latest.html"
$OutputCache  = Join-Path $Root "output-latest.html"
$BridgeCache  = Join-Path $Root "bridge-stable.ps1"
$MatchdayStateFile = Join-Path $Root "matchday-state.json"
$MatchProjectsFile = Join-Path $Root "match-projects.json"
$ControlBackup = Join-Path $Root "control-backup.html"
$OutputBackup  = Join-Path $Root "output-backup.html"
$RemoteBase   = "https://suny820916.github.io/-sagi-event-system/intro"

$Allowed = @(
  "Cut","Fade","Stinger1","PreviewInput",
  "OverlayInput1In","OverlayInput1Out","OverlayInput1Off",
  "OverlayInput2In","OverlayInput2Out","OverlayInput2Off",
  "OverlayInput3In","OverlayInput3Out","OverlayInput3Off",
  "OverlayInput4In","OverlayInput4Out","OverlayInput4Off",
  "OverlayInputAllOff",
  "Effect1On","Effect1Off","Effect2On","Effect2Off","Effect3On","Effect3Off","Effect4On","Effect4Off",
  "SetEffect1Strength","SetEffect2Strength","SetEffect3Strength","SetEffect4Strength"
)

$State = @{
  lineupIntro = $null
  matchdayGraphics = $null
}
$MatchdayJson = "null"
if (Test-Path $MatchdayStateFile) {
  try {
    $savedMatchday = [IO.File]::ReadAllText($MatchdayStateFile,[Text.Encoding]::UTF8)
    if (-not [string]::IsNullOrWhiteSpace($savedMatchday)) {
      $null = $savedMatchday | ConvertFrom-Json
      $MatchdayJson = $savedMatchday
      Write-Host "[RECOVERY] Saved match state loaded." -ForegroundColor Green
    }
  } catch {
    Write-Host "[RECOVERY WARN] Saved match state could not be loaded." -ForegroundColor DarkYellow
  }
}

$MatchProjectsJson = '{"projects":[]}'
if (Test-Path $MatchProjectsFile) {
  try {
    $savedProjects = [IO.File]::ReadAllText($MatchProjectsFile,[Text.Encoding]::UTF8)
    if (-not [string]::IsNullOrWhiteSpace($savedProjects)) {
      $probeProjects = $savedProjects | ConvertFrom-Json
      if ($probeProjects.PSObject.Properties.Name -contains "projects") {
        $MatchProjectsJson = $savedProjects
        Write-Host "[RECOVERY] Saved match projects loaded." -ForegroundColor Green
      }
    }
  } catch {
    Write-Host "[RECOVERY WARN] Saved match projects could not be loaded." -ForegroundColor DarkYellow
  }
}

function Update-SagiLan {
  $ProgressPreference = "SilentlyContinue"
  $stamp = [DateTime]::UtcNow.Ticks
  $controlDownload = $ControlCache + ".download"
  $outputDownload = $OutputCache + ".download"
  try {
    Invoke-WebRequest -UseBasicParsing -Uri ($RemoteBase + "/v45-lan.html?t=" + $stamp) -TimeoutSec 8 -Headers @{"Cache-Control"="no-cache"} -OutFile $controlDownload
    Invoke-WebRequest -UseBasicParsing -Uri ($RemoteBase + "/vmix-v45-lan.html?t=" + $stamp) -TimeoutSec 8 -Headers @{"Cache-Control"="no-cache"} -OutFile $outputDownload

    if ((Get-Item $controlDownload).Length -lt 50000) { throw "Control update too small" }
    if ((Get-Item $outputDownload).Length -lt 20000) { throw "Graphics update too small" }

    $controlText = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($controlDownload))
    $outputText = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($outputDownload))
    if ($controlText -notmatch "<!doctype html>") { throw "Control validation failed" }
    if ($outputText -notmatch "<!doctype html>") { throw "Graphics validation failed" }
    if ($controlText -notmatch "SAGI LIVE MATCH DIRECTOR") { throw "Control identity validation failed" }

    Copy-Item $ControlCache $ControlBackup -Force
    Copy-Item $OutputCache $OutputBackup -Force

    [IO.File]::WriteAllText($ControlCache,$controlText,(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($OutputCache,$outputText,(New-Object Text.UTF8Encoding($false)))
    $script:ControlHtml = $controlText
    $script:OutputHtml = $outputText

    Write-Host "[SAFE UPDATE] Control Room + vMix Graphics updated. Bridge core unchanged." -ForegroundColor Green
    return @{ok=$true;version="4.26.6";updated=@("control","output");bridgeLocked=$true;rollbackAvailable=$true}
  } catch {
    Write-Host ("[SAFE UPDATE ERROR] " + $_.Exception.Message) -ForegroundColor Red
    throw
  } finally {
    Remove-Item $controlDownload -Force -ErrorAction SilentlyContinue
    Remove-Item $outputDownload -Force -ErrorAction SilentlyContinue
  }
}

function Restore-SagiLan {
  if (-not (Test-Path $ControlBackup) -or -not (Test-Path $OutputBackup)) {
    throw "No backup available"
  }
  Copy-Item $ControlBackup $ControlCache -Force
  Copy-Item $OutputBackup $OutputCache -Force
  $script:ControlHtml = [IO.File]::ReadAllText($ControlCache,[Text.Encoding]::UTF8)
  $script:OutputHtml = [IO.File]::ReadAllText($OutputCache,[Text.Encoding]::UTF8)
  Write-Host "[ROLLBACK] Previous Control Room + vMix Graphics restored." -ForegroundColor Yellow
  return @{ok=$true;version="4.26.6";rolledBack=$true}
}

function Get-LanIPv4 {
  try {
    $ips = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
      Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_.IPAddressToString -notlike "169.254.*" -and $_.IPAddressToString -ne "127.0.0.1" } |
      ForEach-Object { $_.IPAddressToString }

    $pick = $ips | Where-Object { $_ -like "192.168.*" } | Select-Object -First 1
    if (-not $pick) { $pick = $ips | Where-Object { $_ -like "10.*" } | Select-Object -First 1 }
    if (-not $pick) {
      $pick = $ips | Where-Object {
        $parts = $_.Split(".")
        if ($parts.Count -ne 4) { return $false }
        $a=[int]$parts[0];$b=[int]$parts[1]
        return ($a -eq 172 -and $b -ge 16 -and $b -le 31)
      } | Select-Object -First 1
    }
    if (-not $pick) { $pick = $ips | Select-Object -First 1 }
    if ($pick) { return [string]$pick }
  } catch {}
  return "127.0.0.1"
}
function Test-Vmix {
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $VmixApi -TimeoutSec 3 | Out-Null
    return $true
  } catch { return $false }
}

function Get-VmixStatusInfo {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $VmixApi -TimeoutSec 3
    [xml]$xml = [string]$r.Content
    $inputs = @()
    foreach ($inputNode in $xml.vmix.inputs.input) {
      $inputs += @{number=[string]$inputNode.number;key=[string]$inputNode.key;type=[string]$inputNode.type;title=[string]$inputNode.title;state=[string]$inputNode.state}
    }
    $overlays = @()
    foreach ($overlayNode in $xml.vmix.overlays.overlay) {
      $overlays += @{number=[string]$overlayNode.number;value=[string]$overlayNode.InnerText}
    }
    return @{ok=$true;active=[string]$xml.vmix.active;preview=[string]$xml.vmix.preview;inputs=$inputs;overlays=$overlays}
  } catch {
    return @{ok=$false;active="";preview="";inputs=@();overlays=@()}
  }
}

function Invoke-VmixCommand($cmd) {
  $fn = [string]$cmd.functionName
  if ([string]::IsNullOrWhiteSpace($fn) -or -not ($Allowed -contains $fn)) {
    throw ("Unsupported vMix function: " + $fn)
  }

  $pairs = New-Object System.Collections.Generic.List[string]
  $pairs.Add("Function=" + [uri]::EscapeDataString($fn))

  $inputValue = [string]$cmd.input
  if (-not [string]::IsNullOrWhiteSpace($inputValue)) {
    $pairs.Add("Input=" + [uri]::EscapeDataString($inputValue))
  }

  $durationValue = 0
  if ($null -ne $cmd.duration) { [void][int]::TryParse([string]$cmd.duration,[ref]$durationValue) }
  if ($durationValue -gt 0) { $pairs.Add("Duration=" + $durationValue) }

  $value = [string]$cmd.value
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    $pairs.Add("Value=" + [uri]::EscapeDataString($value))
  }

  $url = $VmixApi + "?" + ($pairs -join "&")
  Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 3 | Out-Null
  $label = [string]$cmd.label
  Write-Host ("[vMix] " + $fn + " Input=" + $inputValue + " " + $label) -ForegroundColor Green
}

function Read-HttpRequest($stream) {
  $headerBytes = New-Object System.Collections.Generic.List[byte]
  $match = 0
  $pattern = [byte[]](13,10,13,10)

  while ($headerBytes.Count -lt 65536) {
    $b = $stream.ReadByte()
    if ($b -lt 0) { break }
    $headerBytes.Add([byte]$b)
    if ($b -eq $pattern[$match]) {
      $match++
      if ($match -eq 4) { break }
    } else {
      if ($b -eq 13) { $match = 1 } else { $match = 0 }
    }
  }

  if ($headerBytes.Count -eq 0) { return $null }

  $headerText = [Text.Encoding]::ASCII.GetString($headerBytes.ToArray())
  $lines = $headerText -split "\r\n"
  $first = $lines[0] -split " "
  if ($first.Count -lt 2) { return $null }

  $method = $first[0].ToUpperInvariant()
  $target = $first[1]
  $headers = @{}

  for ($i=1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $pos = $line.IndexOf(":")
    if ($pos -gt 0) {
      $name = $line.Substring(0,$pos).Trim().ToLowerInvariant()
      $value = $line.Substring($pos+1).Trim()
      $headers[$name] = $value
    }
  }

  $len = 0
  if ($headers.ContainsKey("content-length")) { [void][int]::TryParse($headers["content-length"],[ref]$len) }
  if ($len -gt 20971520) { throw "Request body too large" }

  $body = ""
  if ($len -gt 0) {
    $bodyBytes = New-Object byte[] $len
    $offset = 0
    while ($offset -lt $len) {
      $n = $stream.Read($bodyBytes,$offset,$len-$offset)
      if ($n -le 0) { break }
      $offset += $n
    }
    $body = [Text.Encoding]::UTF8.GetString($bodyBytes,0,$offset)
  }

  return @{ method=$method; target=$target; headers=$headers; body=$body }
}

function Write-HttpResponse($stream,[int]$Status,[string]$ContentType,[string]$Body) {
  $statusText = switch ($Status) {
    200 {"OK"} 204 {"No Content"} 400 {"Bad Request"} 404 {"Not Found"} 500 {"Internal Server Error"} default {"OK"}
  }
  if ($null -eq $Body) { $Body = "" }
  $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
  $head = "HTTP/1.1 $Status $statusText`r`nContent-Type: $ContentType; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nAccess-Control-Allow-Origin: *`r`nAccess-Control-Allow-Headers: Content-Type`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nConnection: close`r`n`r`n"
  $headBytes = [Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($headBytes,0,$headBytes.Length)
  if ($bytes.Length -gt 0) { $stream.Write($bytes,0,$bytes.Length) }
  $stream.Flush()
}

function State-Json {
  return ($State | ConvertTo-Json -Depth 50 -Compress)
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SAGI V4.7.2 MATCH SAFE LAN DIRECT - vMix Bridge" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (-not (Test-Path $ControlCache) -or -not (Test-Path $OutputCache)) {
  Write-Host "[ERROR] Embedded LAN UI files were not extracted." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}
$ControlHtml = [IO.File]::ReadAllText($ControlCache,[Text.Encoding]::UTF8)
$OutputHtml = [IO.File]::ReadAllText($OutputCache,[Text.Encoding]::UTF8)
Write-Host "[READY] Embedded LAN UI loaded." -ForegroundColor Green

$vmixReady = Test-Vmix
if ($vmixReady) {
  Write-Host "[READY] vMix API connected on 127.0.0.1:8088" -ForegroundColor Green
} else {
  Write-Host "[WARN] vMix API is not available on 127.0.0.1:8088" -ForegroundColor Yellow
  Write-Host "[READY] LAN Control will still start. Open vMix / enable Web Controller 8088 when needed." -ForegroundColor Green
}

$lanIp = Get-LanIPv4
$listener = $null
$started = $false
for ($candidate = $PreferredPort; $candidate -le 8120; $candidate++) {
  try {
    $tryListener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any,$candidate)
    $tryListener.Start()
    $listener = $tryListener
    $Port = $candidate
    $started = $true
    if ($Port -ne $PreferredPort) {
      Write-Host ("[INFO] Port " + $PreferredPort + " is busy. Using port " + $Port + " instead.") -ForegroundColor Yellow
    }
    break
  } catch {
    try { if ($null -ne $tryListener) { $tryListener.Stop() } } catch {}
  }
}
if (-not $started -or $null -eq $listener) {
  Write-Host ("[ERROR] No free LAN port found.") -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host "[READY] LAN DIRECT server is running." -ForegroundColor Green
Write-Host ""
Write-Host ("PHONE CONTROL : http://" + $lanIp + ":" + $Port + "/") -ForegroundColor Cyan
Write-Host ("PC CONTROL    : http://127.0.0.1:" + $Port + "/") -ForegroundColor Cyan
Write-Host ("VMIX BROWSER  : http://127.0.0.1:" + $Port + "/vmix") -ForegroundColor Cyan
Write-Host ""
Write-Host "Phone and vMix PC must be on the same Wi-Fi/LAN." -ForegroundColor White
Write-Host "If Windows Firewall asks, allow PowerShell on Private networks." -ForegroundColor Yellow
Write-Host "Keep this window open during the match." -ForegroundColor White
Write-Host ""
try {
  Start-Process ("http://127.0.0.1:" + $Port + "/")
  Write-Host "[READY] PC Control Room opened automatically." -ForegroundColor Green
} catch {
  Write-Host "[INFO] Open the PC CONTROL address manually." -ForegroundColor Yellow
}


while ($true) {
  if (-not $listener.Pending()) {
    Start-Sleep -Milliseconds 25
    continue
  }

  $client = $null
  try {
    $client = $listener.AcceptTcpClient()
    $client.ReceiveTimeout = 5000
    $client.SendTimeout = 5000
    $stream = $client.GetStream()
    $req = Read-HttpRequest $stream

    if ($null -eq $req) {
      Write-HttpResponse $stream 400 "text/plain" "Bad Request"
      continue
    }

    $method = [string]$req.method
    $rawTarget = [string]$req.target
    $path = ($rawTarget -split "\?")[0]

    if ($method -eq "OPTIONS") {
      Write-HttpResponse $stream 204 "text/plain" ""
    }
    elseif ($method -eq "GET" -and ($path -eq "/" -or $path -eq "/index.html")) {
      Write-HttpResponse $stream 200 "text/html" $ControlHtml
    }
    elseif ($method -eq "GET" -and $path -eq "/vmix") {
      Write-HttpResponse $stream 200 "text/html" $OutputHtml
    }
    elseif ($method -eq "GET" -and $path -eq "/api/state") {
      Write-HttpResponse $stream 200 "application/json" (State-Json)
    }
    elseif ($method -eq "POST" -and $path -eq "/api/state") {
      try {
        $patch = $req.body | ConvertFrom-Json
        if ($patch.PSObject.Properties.Name -contains "lineupIntro") { $State["lineupIntro"] = $patch.lineupIntro }
        if ($patch.PSObject.Properties.Name -contains "matchdayGraphics") { $State["matchdayGraphics"] = $patch.matchdayGraphics }
        Write-HttpResponse $stream 200 "application/json" '{"ok":true}'
      } catch {
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 400 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "GET" -and $path -eq "/api/projects") {
      Write-HttpResponse $stream 200 "application/json" $MatchProjectsJson
    }
    elseif ($method -eq "POST" -and $path -eq "/api/projects") {
      try {
        $projectsPayload = $req.body | ConvertFrom-Json
        if (-not ($projectsPayload.PSObject.Properties.Name -contains "projects")) { throw "Missing projects" }
        $projects = @($projectsPayload.projects)
        if ($projects.Count -gt 20) { $projects = @($projects | Select-Object -First 20) }
        $safePayload = @{projects=$projects;savedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();schema="SAGI_MATCH_PROJECTS_V1"} | ConvertTo-Json -Depth 80 -Compress
        $tmpProjects = $MatchProjectsFile + ".new"
        [IO.File]::WriteAllText($tmpProjects,$safePayload,(New-Object Text.UTF8Encoding($false)))
        Move-Item $tmpProjects $MatchProjectsFile -Force
        $MatchProjectsJson = $safePayload
        Write-Host ("[PROJECTS] Saved " + $projects.Count + " match project(s).") -ForegroundColor Green
        Write-HttpResponse $stream 200 "application/json" '{"ok":true}'
      } catch {
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 400 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "GET" -and $path -eq "/api/matchday") {
      Write-HttpResponse $stream 200 "application/json" $MatchdayJson
    }
    elseif ($method -eq "POST" -and $path -eq "/api/matchday") {
      try {
        $probe = $req.body | ConvertFrom-Json
        $MatchdayJson = $req.body
        $tmpState = $MatchdayStateFile + ".new"
        [IO.File]::WriteAllText($tmpState,$MatchdayJson,(New-Object Text.UTF8Encoding($false)))
        Move-Item $tmpState $MatchdayStateFile -Force
        $hs = [string]$probe.homeScore
        $as = [string]$probe.awayScore
        $vis = [string]$probe.scoreboardVisible
        Write-Host ("[SCORE] " + $hs + ":" + $as + " visible=" + $vis) -ForegroundColor Cyan
        Write-HttpResponse $stream 200 "application/json" '{"ok":true}'
      } catch {
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 400 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "POST" -and $path -eq "/api/recovery/reset") {
      try {
        $MatchdayJson = "null"
        Remove-Item $MatchdayStateFile -Force -ErrorAction SilentlyContinue
        Write-HttpResponse $stream 200 "application/json" '{"ok":true}'
      } catch {
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 500 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "POST" -and $path -eq "/api/vmix") {
      try {
        $cmd = $req.body | ConvertFrom-Json
        Invoke-VmixCommand $cmd
        Write-HttpResponse $stream 200 "application/json" '{"ok":true}'
      } catch {
        Write-Host ("[vMix ERROR] " + $_.Exception.Message) -ForegroundColor Red
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 500 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "POST" -and $path -eq "/api/update") {
      try {
        $result = Update-SagiLan
        Write-HttpResponse $stream 200 "application/json" ($result | ConvertTo-Json -Compress)
      } catch {
        Write-Host ("[UPDATE ERROR] " + $_.Exception.Message) -ForegroundColor Red
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 500 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "POST" -and $path -eq "/api/rollback") {
      try {
        $result = Restore-SagiLan
        Write-HttpResponse $stream 200 "application/json" ($result | ConvertTo-Json -Compress)
      } catch {
        Write-Host ("[ROLLBACK ERROR] " + $_.Exception.Message) -ForegroundColor Red
        $err = $_.Exception.Message | ConvertTo-Json -Compress
        Write-HttpResponse $stream 500 "application/json" ('{"ok":false,"error":' + $err + '}')
      }
    }
    elseif ($method -eq "GET" -and $path -eq "/health") {
      $vmixInfo = Get-VmixStatusInfo
      $health = @{ok=$true;vmix=[bool]$vmixInfo.ok;vmixInfo=$vmixInfo;lan=$true;ip=$lanIp;port=$Port;version="4.7.0";mode="MATCH_MODE";bridgeLocked=$true;recovery=(Test-Path $MatchdayStateFile);projectLibrary=(Test-Path $MatchProjectsFile)} | ConvertTo-Json -Depth 8 -Compress
      Write-HttpResponse $stream 200 "application/json" $health
    }
    else {
      Write-HttpResponse $stream 404 "text/plain" "Not Found"
    }
  }
  catch {
    Write-Host ("[LAN WARN] " + $_.Exception.Message) -ForegroundColor DarkYellow
  }
  finally {
    if ($null -ne $client) { try { $client.Close() } catch {} }
  }
}

###SAGI_CONTROL###
<!doctype html>
<html lang="zh-CN">
<head>
<!-- SAGI LIVE MATCH DIRECTOR · SAFE UPDATE COMPATIBILITY MARKER -->
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#07090d">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<link rel="manifest" href="./manifest.webmanifest">
<link rel="apple-touch-icon" href="./sagi-app-icon.svg">
<meta name="application-name" content="SAGI 赛事直播导播">
<meta name="apple-mobile-web-app-title" content="SAGI 导播">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="format-detection" content="telephone=no">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2214%22 fill=%22%2307090d%22/%3E%3Ctext x=%2232%22 y=%2243%22 text-anchor=%22middle%22 font-size=%2234%22 fill=%22%23d8b55b%22%3ES%3C/text%3E%3C/svg%3E">
<title>SAGI V4.30.8 · STAGE 广播系统</title>
<style>
:root{--bg:#07090d;--panel:#11151c;--line:#2b3340;--text:#f4f0e8;--muted:#8f97a5;--gold:#d8b55b;--green:#72c79a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif}
.app{max-width:1420px;margin:auto;padding:18px 14px 70px}.top{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.brand{font-size:25px;font-weight:950}.sub{font-size:12px;color:var(--muted);margin-top:4px}.ver{border:1px solid #6b592d;color:var(--gold);border-radius:999px;padding:7px 11px;font-size:12px}
.layout{display:grid;grid-template-columns:410px minmax(0,1fr);gap:14px;align-items:start}.card{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:14px;margin:14px 0}.card h2{margin:0 0 12px;font-size:17px}.muted{color:var(--muted);font-size:12px;line-height:1.6}.tiny{font-size:10px;color:#747d8a;line-height:1.55}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:9px}.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}label{display:block;color:#99a1ae;font-size:11px;margin-bottom:5px}input,select{width:100%;background:#080b10;color:#fff;border:1px solid #343d49;border-radius:12px;padding:10px;font-size:15px}
button,.fileBtn{border:0;border-radius:12px;background:#262d37;color:#fff;font-weight:850;min-height:42px;padding:9px 12px}.primary{background:linear-gradient(135deg,#bd9949,#e6ca76);color:#101216}.ok{background:#1d4935}.danger{background:#572626}.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}.fileBtn{display:flex;align-items:center;justify-content:center;cursor:pointer}.fileBtn input{display:none}
.asset{display:grid;grid-template-columns:68px 1fr;gap:10px;align-items:center}.assetPreview{width:68px;height:68px;border:1px solid #343c48;border-radius:14px;background:#090c11;display:flex;align-items:center;justify-content:center;overflow:hidden;color:#69717c;font-size:10px}.assetPreview img{width:100%;height:100%;object-fit:cover}
.roster{display:grid;gap:7px;max-height:420px;overflow:auto}.playerRow{display:grid;grid-template-columns:50px 1fr auto;gap:9px;align-items:center;background:#0a0e14;border:1px solid #27303c;border-radius:13px;padding:7px}.playerRow.on{border-color:#8f7637;background:#15130d}.thumb{width:50px;height:50px;border-radius:11px;overflow:hidden;background:#151a22;display:flex;align-items:center;justify-content:center;color:#6f7783;font-size:10px}.thumb img{width:100%;height:100%;object-fit:cover}.pname{font-weight:850}.pmeta{font-size:11px;color:#8e96a3;margin-top:2px}.num{font-size:20px;font-weight:950;color:var(--gold)}
.stageCard{position:sticky;top:8px}.frame{position:relative;width:100%;aspect-ratio:16/9;background:#000;border:1px solid #2d3440;border-radius:18px;overflow:hidden;box-shadow:0 28px 50px #0008}.stageScale{position:absolute;left:0;top:0;width:1920px;height:1080px;transform-origin:0 0}.stage{position:absolute;inset:0;width:1920px;height:1080px;overflow:hidden;background:#07090c;transform-origin:0 0}
.stadium{position:absolute;inset:0;background:radial-gradient(circle at 50% 0,#6f8294 0,#263442 18%,#111820 42%,#06080b 74%)}.stadium:before{content:"";position:absolute;left:-5%;right:-5%;top:165px;height:300px;background:linear-gradient(#19212a,#0b1016 68%,transparent),repeating-linear-gradient(90deg,#ffffff08 0 7px,transparent 7px 22px);clip-path:polygon(0 0,100% 0,92% 100%,8% 100%)}.stadium:after{content:"";position:absolute;left:0;right:0;bottom:-35px;height:430px;background:linear-gradient(180deg,#173421,#0a2716 70%,#05130a);clip-path:polygon(20% 0,80% 0,100% 100%,0 100%)}.pitchLines{position:absolute;left:320px;right:320px;bottom:0;height:360px;opacity:.22;transform:perspective(800px) rotateX(62deg);transform-origin:bottom;border:5px solid #fff;border-bottom:0}.pitchLines:before{content:"";position:absolute;left:50%;top:0;bottom:0;border-left:4px solid #fff}.pitchLines:after{content:"";position:absolute;width:170px;height:170px;border:4px solid #fff;border-radius:50%;left:50%;top:45%;transform:translate(-50%,-50%)}
.stadiumShade{position:absolute;inset:0;background:linear-gradient(90deg,#030508e6 0,#05070a99 38%,#05070a55 58%,#030508c9 100%),linear-gradient(0deg,#040609c7 0,transparent 55%,#03050775 100%)}.stadiumPhoto{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:none}.stadiumPhoto.on{display:block}.stadiumPhoto.on+.stadiumShade{background:linear-gradient(90deg,#020305e8 0,#05070a9c 42%,#05070a6b 63%,#020305c9 100%),linear-gradient(0deg,#020305b5,transparent 60%)}
.light{position:absolute;width:760px;height:760px;border-radius:50%;filter:blur(100px);opacity:.22}.l1{left:-180px;top:-330px;background:#5cb4ff}.l2{right:-220px;top:-300px;background:#d7b051}
.headerMark{position:absolute;left:95px;top:72px;display:flex;align-items:center;gap:24px}.teamCrest{width:96px;height:96px;object-fit:contain;filter:drop-shadow(0 12px 20px #0009)}.teamHead{font-size:34px;font-weight:950;letter-spacing:2px}.teamSub{font-size:17px;color:#d8b55b;letter-spacing:5px;margin-top:7px;font-weight:850}
.groupTitle{position:absolute;left:100px;top:205px;font-size:28px;letter-spacing:7px;color:#d8b55b;font-weight:900}.groupName{position:absolute;left:95px;top:245px;font-size:72px;line-height:1;font-weight:1000;letter-spacing:-2px}.groupLine{position:absolute;left:98px;top:330px;width:400px;height:5px;background:linear-gradient(90deg,#d8b55b,#fff1b7)}
.playersArea{position:absolute;left:70px;top:350px;width:1240px;height:650px;display:flex;align-items:flex-end;justify-content:center;gap:18px}.playerCard{position:relative;width:230px;height:570px;opacity:1;transform:translateY(0);flex:0 0 auto}.playerCard.one{width:520px}.playerCut{position:absolute;left:0;right:0;bottom:82px;height:490px;display:flex;align-items:flex-end;justify-content:center}.playerCut img{width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 20px 25px #000d)}
.mediaVideo{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 20px 25px #000d);z-index:2;background:transparent}
.mediaFallback{position:absolute;inset:0;display:flex;align-items:flex-end;justify-content:center;z-index:1}
.playerCard.hasMedia .playerCut:after{content:"MEDIA DAY";position:absolute;right:8%;top:8%;z-index:4;font-size:10px;font-weight:1000;letter-spacing:2px;color:#f3d77f;background:#07090db8;border:1px solid #d8b55b66;border-radius:999px;padding:6px 9px}
.playerCard.action-WALK_IN .mediaVideo{transform:scale(1.08);transform-origin:center bottom}
.playerCard.action-ARMS .mediaVideo{transform:scale(1.03)}
.playerCard.action-LOOK .mediaVideo{transform:scale(1.05)}
.playerCard.action-GK_GLOVES .mediaVideo{transform:scale(1.07)}
.playerCard.action-CELEBRATE .mediaVideo{transform:scale(1.08)}
.mediaTag{display:inline-flex;align-items:center;gap:6px;margin-top:6px;padding:4px 8px;border-radius:999px;background:#d8b55b17;border:1px solid #d8b55b3d;color:#e9cd78;font-size:10px;font-weight:900;letter-spacing:1px}
.assetPreview video{width:100%;height:100%;object-fit:cover}
.mediaHelp{margin-top:8px;padding:9px 10px;border-radius:12px;background:#0a0d12;border:1px solid #2a313b;color:#8f98a7;font-size:11px;line-height:1.55}
.directorBox{margin-top:10px;padding:11px;border-radius:14px;border:1px solid #5a4a26;background:linear-gradient(180deg,#15120b,#0a0d12)}
.directorHead{display:flex;align-items:center;justify-content:space-between;margin-bottom:9px}.directorHead b{font-size:12px;letter-spacing:2px;color:#e2c46f}.directorHead span{font-size:10px;color:#8f98a7}
.directorGrid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.directorGrid input,.directorGrid select{font-size:13px;padding:9px}
.directorBadge{display:inline-flex;align-items:center;margin-top:5px;padding:4px 7px;border-radius:999px;background:#ffffff0b;border:1px solid #d8b55b45;color:#d8b55b;font-size:9px;font-weight:900;letter-spacing:.6px}
.playerCard.directed .playerCut:before{content:"DIRECTOR";position:absolute;left:8%;top:8%;z-index:5;font-size:9px;font-weight:1000;letter-spacing:1.5px;color:#fff;background:#000a;border:1px solid #ffffff25;border-radius:999px;padding:5px 8px}
.freezeFlash{position:absolute;inset:0;pointer-events:none;z-index:20;background:#fff;opacity:0}.playerCut .fallback{width:84%;height:86%;border-radius:34px;background:linear-gradient(160deg,#222c38,#0c1118);display:flex;align-items:center;justify-content:center;font-size:80px;font-weight:1000;color:#ffffff24;border:1px solid #ffffff10}.playerLabel{position:absolute;left:0;right:0;bottom:0;text-align:center}.playerNo{font-size:34px;color:#d8b55b;font-weight:1000}.playerName{font-size:22px;font-weight:950;text-transform:uppercase;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.playerRole{font-size:12px;color:#9ba4b1;letter-spacing:3px;margin-top:5px}
.roleBackdrop{position:absolute;left:60px;top:300px;width:1160px;height:560px;display:flex;align-items:center;justify-content:center;font-size:260px;font-weight:1000;letter-spacing:-18px;color:#ffffff08;z-index:0;pointer-events:none;user-select:none}
.roleGlow{position:absolute;left:110px;top:330px;width:1120px;height:620px;border-radius:50%;filter:blur(72px);opacity:.22;z-index:0;pointer-events:none;background:radial-gradient(circle,#d8b55b66 0,transparent 68%)}
.playersArea{z-index:2}
.playersArea .playerCard{transition:width .25s ease,height .25s ease,margin-bottom .25s ease,opacity .25s ease,filter .25s ease}
.playersArea.layout-GK .playerCard{width:540px;height:620px;margin-bottom:6px;z-index:4}
.playersArea.layout-DF .playerCard:nth-child(1),.playersArea.layout-DF .playerCard:nth-child(4){width:205px;height:500px;margin-bottom:0;opacity:.9;filter:saturate(.9)}
.playersArea.layout-DF .playerCard:nth-child(2),.playersArea.layout-DF .playerCard:nth-child(3){width:275px;height:610px;margin-bottom:28px;z-index:3}
.playersArea.layout-MF .playerCard:nth-child(1),.playersArea.layout-MF .playerCard:nth-child(3){width:250px;height:545px;margin-bottom:0;opacity:.92}
.playersArea.layout-MF .playerCard:nth-child(2){width:350px;height:635px;margin-bottom:30px;z-index:4}
.playersArea.layout-FW .playerCard:nth-child(1),.playersArea.layout-FW .playerCard:nth-child(3){width:265px;height:570px;margin-bottom:8px;opacity:.94}
.playersArea.layout-FW .playerCard:nth-child(2){width:365px;height:650px;margin-bottom:32px;z-index:5}
.playersArea.layout-TEAM{align-items:center}
.stage.group-GK .roleGlow{background:radial-gradient(circle,#67d7ff66 0,transparent 68%);opacity:.26}
.stage.group-DF .roleGlow{background:radial-gradient(circle,#d8b55b60 0,transparent 68%)}
.stage.group-MF .roleGlow{background:radial-gradient(circle,#7b8fff66 0,transparent 68%)}
.stage.group-FW .roleGlow{background:radial-gradient(circle,#ff9a5260 0,transparent 68%);opacity:.27}
.stage.group-GK .l1{background:#62d2ff}.stage.group-GK .l2{background:#d8b55b}
.stage.group-DF .l1{background:#9aa7b3}.stage.group-DF .l2{background:#d8b55b}
.stage.group-MF .l1{background:#6f82ff}.stage.group-MF .l2{background:#d8b55b}
.stage.group-FW .l1{background:#d8b55b}.stage.group-FW .l2{background:#ff8f55}
.playerCard:before{content:"";position:absolute;left:12%;right:12%;bottom:72px;height:120px;border-radius:50%;background:radial-gradient(ellipse,#000b 0,transparent 70%);filter:blur(15px);z-index:-1}
.playerCard .playerCut{z-index:1}.playerCard .playerLabel{z-index:3}

.tunnelScene{position:absolute;inset:0;overflow:hidden;perspective:1200px;z-index:0}
.tunnelScene .tunnelBack{position:absolute;left:50%;top:13%;width:480px;height:610px;transform:translateX(-50%);background:linear-gradient(#10151b,#05080b 62%);border:3px solid #ffffff18;box-shadow:0 0 120px #000 inset,0 0 80px #d8b55b18;clip-path:polygon(15% 0,85% 0,100% 100%,0 100%)}
.tunnelScene .portal{position:absolute;left:50%;top:31%;width:270px;height:430px;transform:translateX(-50%);background:linear-gradient(#afc7da55,#193726 54%,#0f2618);box-shadow:0 0 90px #95d8ff33,0 0 120px #d8b55b1f inset;border:2px solid #ffffff1f;overflow:hidden}
.tunnelScene .portal:before{content:"";position:absolute;left:-15%;right:-15%;bottom:-20px;height:220px;background:linear-gradient(#1d5b34,#0d2b19);clip-path:polygon(15% 0,85% 0,100% 100%,0 100%)}
.tunnelScene .wall{position:absolute;top:0;bottom:0;width:46%;background:linear-gradient(90deg,#020305,#0b1016 60%,#151b22);filter:drop-shadow(0 0 26px #000);transform-style:preserve-3d}
.tunnelScene .wall.left{left:-8%;clip-path:polygon(0 0,100% 14%,75% 100%,0 100%);background:linear-gradient(90deg,#020305 0,#090d12 68%,#1b222a)}
.tunnelScene .wall.right{right:-8%;clip-path:polygon(0 14%,100% 0,100% 100%,25% 100%);background:linear-gradient(270deg,#020305 0,#090d12 68%,#1b222a)}
.tunnelScene .ceiling{position:absolute;left:12%;right:12%;top:-6%;height:240px;background:linear-gradient(#06080b,#131922);clip-path:polygon(8% 0,92% 0,76% 100%,24% 100%);box-shadow:0 18px 40px #000}
.tunnelScene .floor{position:absolute;left:8%;right:8%;bottom:-5%;height:390px;background:linear-gradient(#161b20,#050709 72%);clip-path:polygon(24% 0,76% 0,100% 100%,0 100%)}
.tunnelScene .floor:before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0 110px,#ffffff08 112px 114px,transparent 116px 220px),linear-gradient(90deg,transparent,#d8b55b0d,transparent);transform:perspective(800px) rotateX(56deg);transform-origin:bottom}
.tunnelScene .led{position:absolute;top:185px;width:410px;height:470px;background:linear-gradient(#0a0d11,#111721);border:1px solid #d8b55b44;box-shadow:0 0 35px #d8b55b18 inset,0 0 22px #000;display:flex;align-items:center;justify-content:center;overflow:hidden}
.tunnelScene .led.left{left:95px;transform:skewY(7deg)}.tunnelScene .led.right{right:95px;transform:skewY(-7deg)}
.tunnelScene .led:before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,#ffffff05 0 2px,transparent 2px 8px);mix-blend-mode:screen}
.tunnelScene .ledText{position:relative;z-index:2;font-size:42px;font-weight:1000;letter-spacing:4px;color:#e7cf8a;text-align:center;max-width:330px;text-shadow:0 0 18px #d8b55b55;line-height:1.08}
.tunnelScene .ledText small{display:block;margin-top:14px;font-size:16px;letter-spacing:6px;color:#ffffffaa}
.tunnelScene .roofLights{position:absolute;left:460px;right:460px;top:115px;height:26px;background:repeating-linear-gradient(90deg,#ffffff0a 0 30px,#fff6c4 32px 42px,#ffffff0a 44px 82px);filter:blur(.4px);box-shadow:0 0 24px #fff6c455}
.tunnelScene .fog{position:absolute;left:20%;right:20%;bottom:12%;height:240px;background:radial-gradient(ellipse,#ffffff12 0,transparent 66%);filter:blur(35px);opacity:.8}
.tunnelScene .cameraVignette{position:absolute;inset:0;background:radial-gradient(circle at 50% 52%,transparent 0 34%,#0008 76%,#000d 100%)}
.stage.tunnel-open .tunnelScene .wall.left{transform:translateX(-110px)}.stage.tunnel-open .tunnelScene .wall.right{transform:translateX(110px)}
.stage.tunnel-open .tunnelScene .led.left{transform:translateX(-90px) skewY(7deg);opacity:.45}.stage.tunnel-open .tunnelScene .led.right{transform:translateX(90px) skewY(-7deg);opacity:.45}
.stage.tunnel-open .tunnelScene .portal{box-shadow:0 0 150px #b6e2ff99,0 0 180px #ffffff44 inset}
.stage.scene-stadium .tunnelScene,.stage.scene-transparent .tunnelScene,.stage.scene-chroma .tunnelScene{display:none}
.stage.scene-tunnel .stadium,.stage.scene-tunnel .stadiumPhoto,.stage.scene-tunnel .stadiumShade,.stage.scene-tunnel .pitchLines{display:none!important}
.stage.scene-tunnel .formationBox{background:#05080cd9;border-color:#e3c66a33}
.stage.scene-tunnel.group-GK .led{border-color:#6cd8ff55;box-shadow:0 0 45px #6cd8ff16 inset}
.stage.scene-tunnel.group-MF .led{border-color:#7e8fff55}.stage.scene-tunnel.group-FW .led{border-color:#ff995555}
.tunnelScene,.tunnelScene .wall,.tunnelScene .led,.tunnelScene .portal{transition:transform .7s cubic-bezier(.2,.8,.2,1),opacity .55s ease,box-shadow .55s ease}
.formationBox{position:absolute;right:78px;top:175px;width:500px;height:760px;border:1px solid #ffffff20;border-radius:32px;background:#05080cc7;backdrop-filter:blur(7px);padding:28px}.formationHead{display:flex;justify-content:space-between;align-items:flex-start}.formationTitle{font-size:25px;font-weight:950}.formationText{font-size:42px;color:#d8b55b;font-weight:1000}.pitch{position:absolute;left:34px;right:34px;top:120px;bottom:34px;border:3px solid #ffffff50;border-radius:5px;background:linear-gradient(#123d25,#0e321e);overflow:hidden}.pitch:before{content:"";position:absolute;left:0;right:0;top:50%;border-top:2px solid #ffffff55}.pitch:after{content:"";position:absolute;width:115px;height:115px;border:2px solid #ffffff55;border-radius:50%;left:50%;top:50%;transform:translate(-50%,-50%)}.boxTop,.boxBottom{position:absolute;left:50%;width:220px;height:90px;transform:translateX(-50%);border:2px solid #ffffff55}.boxTop{top:-2px}.boxBottom{bottom:-2px}.formationNodes{position:absolute;inset:0}.node{position:absolute;width:76px;height:92px;border-radius:16px;transform:translate(-50%,-50%);background:#0c131b;border:1px solid #ffffff36;display:flex;align-items:center;justify-content:center;font-weight:1000;font-size:15px;color:#fff;transition:.25s;box-shadow:0 8px 18px #0008;overflow:visible}.nodeVisual{position:absolute;left:3px;right:3px;top:3px;height:68px;border-radius:13px;overflow:hidden;background:linear-gradient(180deg,#263649,#101720);display:flex;align-items:flex-end;justify-content:center}.nodeVisual img{width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 6px 7px #0008)}.nodeFallbackNo{font-size:24px;color:#ffffff55;align-self:center}.nodeNo{position:absolute;left:5px;top:5px;z-index:3;min-width:24px;height:24px;padding:0 5px;border-radius:999px;background:#07090dcc;border:1px solid #ffffff33;color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;box-shadow:0 3px 8px #0008}.node.active{border-color:#f0d27a;box-shadow:0 0 0 4px #d8b55b30,0 10px 22px #0009}.node.active .nodeNo{background:#d8b55b;color:#111;border-color:#fff0b5}.node small{position:absolute;left:50%;top:76px;transform:translateX(-50%);font-size:10px;color:#f3f5f7;white-space:nowrap;max-width:104px;overflow:hidden;text-overflow:ellipsis;text-shadow:0 2px 5px #000;font-weight:900}.node:not(.hasPhoto){width:62px;height:72px;border-radius:50%}.node:not(.hasPhoto) .nodeVisual{inset:3px;height:auto;border-radius:50%;align-items:center}.node:not(.hasPhoto) .nodeNo{display:none}.node:not(.hasPhoto) small{top:76px}.captainNode:after{z-index:6}
.fullList{position:absolute;left:95px;top:355px;width:1130px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px 28px}.fullRow{display:grid;grid-template-columns:54px 56px 1fr auto;gap:10px;align-items:center;border-bottom:1px solid #ffffff12;padding:8px 4px}.fullRole{font-size:12px;color:#d8b55b;font-weight:900}.fullNo{font-size:25px;font-weight:1000}.fullName{font-size:22px;font-weight:900}.fullPos{font-size:11px;color:#98a1ad}
.statusBar{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-top:10px}.status{font-size:12px;color:var(--green)}.mini{font-size:11px;color:#8b93a0}
.groupButtons{display:grid;grid-template-columns:1fr 1fr;gap:8px}.groupButtons button{min-height:48px}.teamSwitch{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:10px}.teamSwitch button{padding:11px 8px;border-radius:12px;font-size:12px;font-weight:1000;letter-spacing:1px}.teamSwitch button.on{border-color:#d8b55b;background:#211b0d;color:#f1d784;box-shadow:0 0 0 1px #d8b55b33 inset}.teamSideBadge{display:inline-flex;align-items:center;padding:4px 8px;border-radius:999px;background:#d8b55b15;border:1px solid #d8b55b44;color:#e6c971;font-size:10px;font-weight:1000;letter-spacing:1px}.dualHint{margin-top:8px;padding:8px 10px;border-radius:10px;background:#0a0e13;border:1px solid #27303a;color:#87919d;font-size:10px;line-height:1.5}
.matchPackage{margin-top:10px;padding:11px;border:1px solid #33404d;border-radius:14px;background:linear-gradient(180deg,#10151b,#090c11)}
.packageHead{display:flex;justify-content:space-between;align-items:center;margin-bottom:9px}.packageHead b{font-size:12px;color:#e5ca78;letter-spacing:2px}.packageHead span{font-size:10px;color:#8c96a2}
.packageGrid{display:grid;grid-template-columns:repeat(2,1fr);gap:8px}.packageGrid input,.packageGrid select{font-size:12px}
.audioRow{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}.audioStatus{margin-top:8px;font-size:10px;color:#85909d}
.audioEngine{margin-top:10px;padding:10px;border:1px solid #5a4b27;border-radius:13px;background:linear-gradient(180deg,#15120c,#090c11)}
.audioEngineHead{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}.audioEngineHead b{font-size:11px;color:#e7cc7d;letter-spacing:2px}.audioEngineHead span{font-size:9px;color:#8d96a2}
.audioEngineGrid{display:grid;grid-template-columns:repeat(2,1fr);gap:7px}.audioEngineGrid select{font-size:11px}
.audioMeters{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:9px}.audioMeter{height:8px;border-radius:999px;background:#111821;overflow:hidden}.audioMeter i{display:block;height:100%;width:0;background:linear-gradient(90deg,#7a6531,#e2c46f);transition:width .12s ease}
.audioDiag{display:flex;justify-content:space-between;gap:8px;margin-top:6px;font-size:9px;color:#76818e}.audioDiag b{color:#d8b55b}
.matchOverlay,.countdownOverlay,.stingOverlay{position:absolute;inset:0;z-index:18;display:none;pointer-events:none}
.matchOverlay.on,.countdownOverlay.on,.stingOverlay.on{display:flex}
.stingOverlay{align-items:center;justify-content:center;background:radial-gradient(circle at center,#18212b 0,#06090d 52%,#020304 100%)}
.stingCore{text-align:center}.stingLogo{width:250px;height:250px;object-fit:contain;filter:drop-shadow(0 28px 40px #000c)}.stingComp{margin-top:20px;font-size:28px;font-weight:1000;letter-spacing:6px;color:#e9d28c}.stingLine{width:360px;height:3px;margin:18px auto;background:linear-gradient(90deg,transparent,#d8b55b,transparent)}
.matchOverlay{align-items:center;justify-content:center;background:linear-gradient(120deg,#040608e8,#0b1117ef)}
.matchCardStage{width:1320px;padding:60px 70px;border:1px solid #ffffff20;background:#070b0fdb;box-shadow:0 28px 100px #000b;position:relative;overflow:hidden}
.matchCardStage:before{content:"";position:absolute;left:0;top:0;bottom:0;width:10px;background:#d8b55b}
.matchCompetition{font-size:22px;font-weight:900;letter-spacing:6px;color:#d8b55b}.matchRound{margin-top:8px;font-size:16px;letter-spacing:4px;color:#8e99a6}
.matchTeams{display:grid;grid-template-columns:1fr 130px 1fr;gap:24px;align-items:center;margin-top:42px}.matchTeam{text-align:center;font-size:54px;font-weight:1000;letter-spacing:-2px;color:#fff}.matchVs{text-align:center;font-size:24px;font-weight:1000;letter-spacing:5px;color:#8b95a0}
.matchMetaStage{display:flex;justify-content:center;gap:36px;margin-top:36px;font-size:16px;font-weight:800;letter-spacing:2px;color:#c1c8d0}
.countdownOverlay{align-items:center;justify-content:center;background:radial-gradient(circle,#0c1118ee,#030507f7 68%)}
.countdownCore{text-align:center}.countdownLabel{font-size:22px;font-weight:900;letter-spacing:8px;color:#aeb7c1}.countdownNumber{font-size:310px;line-height:.9;font-weight:1000;color:#fff;letter-spacing:-18px;text-shadow:0 0 65px #d8b55b22}.countdownSub{font-size:16px;letter-spacing:5px;color:#d8b55b;margin-top:18px}
.showDirector{margin-top:10px;padding:11px;border:1px solid #4b4128;border-radius:14px;background:linear-gradient(180deg,#15130e,#090c11)}
.showHead{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:10px}.showHead b{font-size:13px;letter-spacing:2px;color:#e7cc7d}.showHead span{font-size:10px;color:#8d96a2}
.showTimeline{display:grid;gap:7px}.showStep{display:grid;grid-template-columns:30px 1fr 78px 105px 92px 52px 74px;gap:6px;align-items:center;padding:7px;border:1px solid #29323c;border-radius:11px;background:#0b1016}
.showStep.active{border-color:#d8b55b;background:#17140d;box-shadow:0 0 0 1px #d8b55b22 inset}.showStep.disabled{opacity:.42}
.showIndex{width:25px;height:25px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:#161d26;color:#d8b55b;font-size:10px;font-weight:1000}
.showStep .showName{font-size:11px;font-weight:950;color:#e7e9ed}.showStep input,.showStep select{min-width:0;padding:7px;font-size:11px}
.showMove{display:flex;gap:3px}.showMove button{padding:6px 7px;font-size:10px}.showEnable{display:flex;justify-content:center}
.showProgress{height:7px;border-radius:999px;background:#111821;overflow:hidden;margin-top:10px}.showProgress i{display:block;height:100%;width:0;background:linear-gradient(90deg,#806b34,#e4c978);transition:width .1s linear}
.showNow{display:flex;justify-content:space-between;gap:10px;margin-top:7px;font-size:10px;color:#8993a0}.showNow b{color:#e4c978}
.showTotal{font-variant-numeric:tabular-nums}
.transitionLayer{position:absolute;inset:0;z-index:40;pointer-events:none;opacity:0}.transitionLayer.gold{background:linear-gradient(90deg,#120f08,#d8b55b,#120f08)}.transitionLayer.dark{background:#020305}.transitionLayer.white{background:#fff}
.cueBadgeStage{position:absolute;right:52px;top:36px;z-index:41;padding:8px 12px;border-radius:999px;background:#080b0fcc;border:1px solid #d8b55b66;color:#e5ca7a;font-size:11px;font-weight:1000;letter-spacing:2px;opacity:0}
@media(max-width:650px){.showStep{grid-template-columns:28px 1fr 70px 88px}.showStep .showCue,.showStep .showEnable{grid-column:auto}.showMove{grid-column:2/5}}
.sequence{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.sequence div{background:#0b1016;border:1px solid #29323d;border-radius:11px;padding:8px;text-align:center;font-size:11px;color:#a8b0bb}.sequence b{display:block;color:#e4c878;font-size:14px;margin-bottom:3px}
.notice{display:none;position:fixed;left:50%;bottom:70px;transform:translateX(-50%);background:#1b2028;border:1px solid #4a4025;color:#f0d58d;border-radius:999px;padding:10px 14px;font-size:12px;z-index:50}
@media(max-width:940px){.layout{grid-template-columns:1fr}.stageCard{position:static;order:-1}.app{padding-bottom:30px}}

.captainBadge{display:inline-flex;align-items:center;justify-content:center;min-width:30px;height:30px;border-radius:50%;background:#d8b55b;color:#111;font-size:14px;font-weight:1000;margin-left:7px;vertical-align:middle}
.statPill{display:inline-flex;align-items:center;gap:7px;margin-top:8px;padding:6px 10px;border-radius:999px;background:#ffffff0d;border:1px solid #ffffff1b;color:#d8b55b;font-size:11px;font-weight:900;letter-spacing:1px}
.subList{position:absolute;left:95px;top:355px;width:1130px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px 28px}
.subRow{display:grid;grid-template-columns:56px 1fr auto;gap:12px;align-items:center;border-bottom:1px solid #ffffff12;padding:10px 5px;color:#fff}
.subNo{font-size:24px;font-weight:1000;color:#d8b55b}.subName{font-size:21px;font-weight:900}.subStat{font-size:11px;color:#aab2be}
.captainNode:after{content:'C';position:absolute;right:-6px;top:-7px;width:19px;height:19px;border-radius:50%;background:#fff1b7;color:#111;font-size:10px;display:flex;align-items:center;justify-content:center;font-weight:1000}

/* ===== V4.5 赛事直播导播 ===== */
.broadcastDesk{margin:14px 0 0;background:linear-gradient(180deg,#0b0f15,#070a0e);border:1px solid #303846;border-radius:20px;padding:13px;box-shadow:0 22px 48px #0006}
.bcMonitors{display:grid;grid-template-columns:1fr 1fr 280px;gap:10px}
.bcMonitor{min-height:94px;border:1px solid #323b48;border-radius:15px;background:#090d12;padding:12px 14px;position:relative;overflow:hidden}
.bcMonitor:before{content:"";position:absolute;left:0;top:0;bottom:0;width:5px;background:#616b78}
.bcMonitor.preview:before{background:#2aa6ff}.bcMonitor.program:before{background:#e84545}
.bcKicker{font-size:10px;letter-spacing:3px;font-weight:1000;color:#8994a2}.bcMonitor.preview .bcKicker{color:#67c6ff}.bcMonitor.program .bcKicker{color:#ff7474}
.bcBig{font-size:23px;font-weight:1000;margin-top:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bcMeta{font-size:10px;color:#7f8996;margin-top:6px;letter-spacing:1px}
.bcStatusBox{display:grid;gap:7px;align-content:center;border:1px solid #323b48;border-radius:15px;background:#090d12;padding:12px}
.bcStatusLine{display:flex;justify-content:space-between;gap:8px;font-size:10px;color:#87919d}.bcStatusLine b{color:#e5e8ed}
.bcLamp{display:inline-flex;align-items:center;gap:7px}.bcLamp i{width:9px;height:9px;border-radius:50%;background:#66707c;box-shadow:0 0 0 4px #ffffff08}.bcLamp.ready i{background:#5bd08c;box-shadow:0 0 14px #5bd08c88}.bcLamp.live i{background:#ef4747;box-shadow:0 0 16px #ef4747aa}
.bcTransport{display:grid;grid-template-columns:115px 115px minmax(210px,1fr) 115px 140px;gap:8px;margin-top:10px}
.bcTransport button{min-height:54px;border:1px solid #333d4a;background:#141a22;font-size:12px;letter-spacing:1px}
.bcTransport .goLive{background:linear-gradient(135deg,#c62e2e,#f05a4e);color:white;font-size:16px;box-shadow:0 10px 26px #b5252540}
.bcTransport .hold.on{background:#6b531d;color:#ffe39a;border-color:#aa8736}
.bcTransport .clearAll{background:#2b1114;border-color:#71313a;color:#ff9ca5}
.bcFullIntroBar{margin-top:10px}.bcFullIntroBtn{width:100%;min-height:64px;border:1px solid #e5c76c;background:linear-gradient(135deg,#7a6022,#e2c56c 58%,#f0da93);color:#0a0c0f;font-size:17px;font-weight:1000;letter-spacing:1px;box-shadow:0 12px 30px #d8b55b22}.bcFullIntroBtn span{display:block;margin-top:4px;font-size:10px;font-weight:900;letter-spacing:1.5px;opacity:.72}
.bcQuick{display:grid;grid-template-columns:repeat(9,1fr);gap:7px;margin-top:9px}
.bcQuick button{min-height:42px;padding:7px 5px;font-size:10px;background:#10161d;border:1px solid #2d3743}
.bcQuick button.on{border-color:#d8b55b;color:#edd68d;background:#1a160d;box-shadow:0 0 0 1px #d8b55b22 inset}
.bcHint{margin-top:8px;font-size:9px;color:#6f7a87;letter-spacing:.5px}
.frame:after{content:"预监画面";position:absolute;left:14px;top:14px;z-index:70;padding:7px 10px;border-radius:999px;background:#061019cc;border:1px solid #2aa6ff88;color:#75cfff;font-size:10px;font-weight:1000;letter-spacing:2px;pointer-events:none}
.stageCard .statusBar:before{content:"本机预监";font-size:9px;color:#58bfff;border:1px solid #2aa6ff55;border-radius:999px;padding:5px 8px}
@media(max-width:1100px){.bcMonitors{grid-template-columns:1fr 1fr}.bcStatusBox{grid-column:1/3}.bcQuick{grid-template-columns:repeat(3,1fr)}}
@media(max-width:650px){.bcMonitors{grid-template-columns:1fr}.bcStatusBox{grid-column:auto}.bcTransport{grid-template-columns:1fr 1fr}.bcTransport .goLive{grid-column:1/3}.bcQuick{grid-template-columns:repeat(3,1fr)}}


/* ===== V4.5 赛事直播导播 ===== */
.matchdayDesk{margin:14px 0 0;background:linear-gradient(180deg,#10151c,#080b10);border:1px solid #3a4350;border-radius:20px;padding:14px;box-shadow:0 24px 55px #0006}
.mdHead{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:11px}.mdTitle{font-size:14px;font-weight:1000;letter-spacing:2px;color:#ebd184}.mdTitle small{font-size:10px;color:#7e8996;letter-spacing:1px;margin-left:8px}.mdSync{font-size:10px;color:#75d49e;border:1px solid #2d6748;background:#0d2118;border-radius:999px;padding:6px 9px}
.mdGrid{display:grid;grid-template-columns:1.25fr .9fr 1.25fr;gap:10px}.mdPanel{background:#080c11;border:1px solid #2e3743;border-radius:15px;padding:11px}
.mdPanelTitle{font-size:10px;font-weight:1000;letter-spacing:2px;color:#8995a3;margin-bottom:9px}
.mdScoreLine{display:grid;grid-template-columns:1fr 56px 34px 56px 1fr;gap:7px;align-items:center}.mdTeam{text-align:center;font-size:13px;font-weight:950;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mdScore{font-size:42px;font-weight:1000;text-align:center;color:#fff}.mdScoreBtn{min-height:38px!important;padding:5px!important;font-size:17px!important}
.mdClock{font-size:42px;font-weight:1000;text-align:center;font-variant-numeric:tabular-nums;letter-spacing:1px}.mdPeriod{text-align:center;color:#d8b55b;font-size:10px;font-weight:900;letter-spacing:2px;margin-top:2px}
.mdClockBtns,.mdEventBtns{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:8px}.mdClockBtns button,.mdEventBtns button{min-height:38px;font-size:10px;padding:6px}
.mdGoal{background:#1c5137!important}.mdYellow{background:#6c5b12!important;color:#fff0a5!important}.mdRed{background:#63252b!important}.mdSub{background:#173e55!important}.mdMvp{background:#5b4720!important;color:#f3d98f!important}.mdState{background:#252c36!important}
.mdYellow,.mdRed,.mmMacroYellow,.mmMacroRed{display:flex!important;align-items:center;justify-content:center;gap:8px}
.refCardIcon{display:inline-block;width:12px;height:17px;flex:0 0 12px;border-radius:2px;transform:rotate(-3deg);box-shadow:0 3px 8px #0008,inset 0 0 0 1px #ffffff45}
.refCardIcon.yellow{background:linear-gradient(155deg,#ffe85b,#f2d536 55%,#d8b900)}
.refCardIcon.red{background:linear-gradient(155deg,#ff5c66,#e33440 55%,#b81724)}
.mmMacroYellow .refCardIcon,.mmMacroRed .refCardIcon{width:11px;height:16px;flex-basis:11px}
.mdInputs{display:grid;grid-template-columns:1fr 1.5fr;gap:7px}.mdInputs select,.mdInputs input{padding:8px;font-size:12px}
.mdBottom{display:grid;grid-template-columns:1.35fr 1fr 1fr;gap:10px;margin-top:10px}.mdSubGrid{display:grid;grid-template-columns:.8fr 1.2fr 1.2fr;gap:7px}
.mdActions{display:grid;grid-template-columns:repeat(2,1fr);gap:7px}.mdActions button{min-height:42px;font-size:11px}
.mdScoreboardBtns{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px}.mdScoreboardBtns button{min-height:38px;font-size:10px}
.mdLiveDot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#596472;margin-right:6px}.mdLiveDot.on{background:#5bd08c;box-shadow:0 0 12px #5bd08c88}
.mdEventStatus{margin-top:7px;font-size:9px;color:#737e8b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(max-width:1050px){.mdGrid,.mdBottom{grid-template-columns:1fr}.mdScoreLine{grid-template-columns:1fr 50px 30px 50px 1fr}}


/* ===== V4.5 赛事直播导播 ===== */
.vmixDirector{margin:14px 0 0;background:linear-gradient(180deg,#111722,#080c12);border:1px solid #3b4655;border-radius:20px;padding:14px;box-shadow:0 24px 58px #0007}
.vdHead{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:10px}.vdTitle{font-size:14px;font-weight:1000;letter-spacing:2px;color:#8bd2ff}.vdTitle small{font-size:10px;color:#7f8b99;margin-left:8px}.vdStatus{font-size:10px;border:1px solid #35556d;color:#8bd2ff;background:#0c1a24;border-radius:999px;padding:6px 10px}
.vdGrid{display:grid;grid-template-columns:1.15fr 1fr 1fr;gap:10px}.vdPanel{border:1px solid #303a47;border-radius:14px;background:#080c12;padding:11px}.vdPanelTitle{font-size:10px;font-weight:1000;letter-spacing:2px;color:#8996a5;margin-bottom:9px}
.vdInputs{display:grid;grid-template-columns:repeat(5,1fr);gap:6px}.vdInputs label{font-size:9px}.vdInputs input,.vdInputs select{padding:8px;font-size:11px}
.vdSources{display:grid;grid-template-columns:repeat(4,1fr);gap:7px}.vdSource{min-height:54px!important;font-size:11px!important;border:1px solid #354353!important;background:#111923!important}.vdSource:hover{border-color:#5bbcff!important}.vdSource b{display:block;color:#8bd2ff;font-size:10px;margin-bottom:3px}.vdSource:disabled,.vdPreview button:disabled,.mmDirectorOnly button[data-camera-slot]:disabled{opacity:.28!important;filter:grayscale(1);cursor:not-allowed!important;border-color:#29313a!important;background:#0b0f14!important;color:#68727c!important;box-shadow:none!important}.vdSource:disabled b{color:#65717d}.vdSource:disabled span:after{content:" · 未分配";font-size:8px;color:#69737d}
.vdPreview{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-top:7px}.vdPreview button{min-height:34px;font-size:9px;padding:5px}
.vdOverlay{display:grid;grid-template-columns:1fr 1fr;gap:7px}.vdOverlay button{min-height:45px}.vdOverlay .on{background:#17482f}.vdOverlay .off{background:#4c2529}
.vdBridgeHelp{font-size:10px;line-height:1.6;color:#8190a0;margin-top:8px}.vdDownload{display:inline-flex;align-items:center;justify-content:center;text-decoration:none;color:#0b1015;background:#8bd2ff;font-weight:1000;border-radius:10px;padding:8px 10px;margin-top:8px;font-size:10px}
.vdKeys{margin-top:8px;padding:8px 9px;border-radius:10px;background:#0b1118;border:1px solid #293442;color:#718092;font-size:9px;line-height:1.6}
.mdOpsRow{display:grid;grid-template-columns:1.45fr .75fr;gap:10px;margin-top:10px}.mdEventLog{display:grid;gap:5px;max-height:190px;overflow:auto}.mdLogRow{display:grid;grid-template-columns:56px 88px 1fr auto;gap:7px;align-items:center;padding:7px 8px;border:1px solid #26313d;border-radius:9px;background:#090e14;font-size:10px}.mdLogTime{color:#d8b55b;font-variant-numeric:tabular-nums}.mdLogType{font-weight:1000}.mdLogText{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#b8c0ca}.mdLogScore{font-weight:1000;color:#fff}.mdEmpty{padding:16px;text-align:center;color:#65717e;font-size:10px;border:1px dashed #2b3540;border-radius:10px}
.mdStatGrid{display:grid;grid-template-columns:1fr 1fr;gap:7px}.mdStat{background:#0a1016;border:1px solid #293440;border-radius:10px;padding:10px}.mdStat b{display:block;font-size:23px;color:#e5ca78}.mdStat span{font-size:9px;color:#768391}
@media(max-width:1050px){.vdGrid{grid-template-columns:1fr}.vdInputs{grid-template-columns:1fr 1fr}.mdOpsRow{grid-template-columns:1fr}}


/* ===== V4.5 比赛设置 ===== */
.setupDesk{margin:14px 0;background:linear-gradient(135deg,#0d1219,#101720);border:1px solid #34404d;border-radius:20px;padding:15px;box-shadow:0 18px 45px #0003}
.setupDesk.ready{border-color:#3e725a;box-shadow:0 0 0 1px #72c79a22 inset,0 18px 45px #0003}
.setupHead{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}.setupTitle{font-size:17px;font-weight:1000;letter-spacing:.4px}.setupTitle small{display:block;color:#7f8a97;font-size:10px;letter-spacing:2px;margin-top:4px}
.setupReadyBadge{padding:8px 12px;border:1px solid #5a3434;border-radius:999px;color:#e68c8c;background:#33161666;font-size:10px;font-weight:1000;letter-spacing:1.5px;white-space:nowrap}.setupReadyBadge.ready{border-color:#477861;color:#91e1b5;background:#14332499}
.setupGrid{display:grid;grid-template-columns:1fr 1.35fr;gap:10px}.setupPanel{background:#090d12;border:1px solid #29333e;border-radius:14px;padding:11px}.setupPanelTitle{font-size:10px;color:#d8b55b;font-weight:1000;letter-spacing:2px;margin-bottom:9px}
.setupProjectGrid{display:grid;grid-template-columns:1fr 1fr;gap:8px}.setupProjectActions{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}.setupProjectActions button{min-height:38px;font-size:11px}.setupProjectActions .recover{background:linear-gradient(135deg,#4d421f,#9b8032);color:#fff1b3;border:1px solid #b8973d}.setupPhoneImport{display:inline-flex;align-items:center;justify-content:center;position:relative;overflow:hidden;min-height:38px;padding:8px 11px;border-radius:9px;background:#213a55;color:#bfe1ff;font-size:11px;font-weight:900;cursor:pointer}.setupPhoneImport input{position:absolute;inset:0;opacity:0;cursor:pointer}.projectRecoveryStatus{margin-top:7px;padding:7px 9px;border-radius:9px;background:#0a0e13;border:1px solid #29333e;color:#8995a2;font-size:9px;line-height:1.5}.projectRecoveryStatus.on{border-color:#79652d;color:#e6cd7d;background:#17130b}
.setupChecks{display:grid;grid-template-columns:repeat(2,1fr);gap:7px}.setupCheck{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:9px 10px;border-radius:10px;border:1px solid #333e49;background:#0c1117;font-size:10px;color:#96a0ac}.setupCheck b{font-size:10px}.setupCheck.good{border-color:#315b47;background:#0d1c16;color:#9cd6b6}.setupCheck.bad{border-color:#603838;background:#241212;color:#e8a0a0}.setupCheck.warn{border-color:#6b592d;background:#211b0d;color:#e3ca7b}
.setupSummary{margin-top:9px;padding:9px 10px;border-radius:10px;background:#070a0e;border:1px solid #27313b;color:#8e98a4;font-size:10px;line-height:1.55}.setupSummary.good{border-color:#315b47;color:#9cd6b6}.setupSummary.bad{border-color:#603838;color:#e8a0a0}
.setupReadyActions{display:flex;gap:8px;flex-wrap:wrap;margin-top:9px}.setupReadyActions button{min-height:42px}.setupReadyActions .readyBtn{background:linear-gradient(135deg,#1f6545,#4a9b70);color:#fff}.setupReadyActions .readyBtn:disabled{opacity:.35;filter:saturate(.2)}.setupReadyActions .unlockBtn{background:#442322}
button:disabled{cursor:not-allowed;opacity:.42}
@media(max-width:940px){.setupGrid{grid-template-columns:1fr}.setupChecks{grid-template-columns:1fr}.setupProjectGrid{grid-template-columns:1fr}}


/* ===== V4.5 FORMATION EDITOR ===== */
.formationEditorCard{border-color:#4a432c!important;background:linear-gradient(180deg,#15130d,#10141a)!important}
.editorHeadRow{display:flex;align-items:center;justify-content:space-between;gap:10px}.editorBadge{display:inline-flex;align-items:center;padding:5px 9px;border-radius:999px;background:#171c22;border:1px solid #38414b;color:#8f99a5;font-size:9px;font-weight:1000;letter-spacing:1.4px}.editorBadge.on{background:#25311a;border-color:#718b3a;color:#d9ed8d;box-shadow:0 0 0 1px #d8b55b18 inset}
.editorContext{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:9px}.editorActions{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-top:9px}.editorActions button{font-size:11px;min-height:40px}.editorActions .editOn{background:linear-gradient(135deg,#8a6e2d,#d8b55b);color:#101216}
.editorStatus{margin-top:8px;padding:9px 10px;border-radius:10px;background:#090d12;border:1px solid #303946;color:#8e98a5;font-size:10px;line-height:1.55}.editorStatus.on{border-color:#6b592d;color:#e6cf82}
.formationBox.editorMode{border-color:#d8b55b88;box-shadow:0 0 0 2px #d8b55b12 inset,0 0 55px #d8b55b16}.formationBox.editorMode .pitch{border-color:#e5ca78;box-shadow:0 0 0 2px #d8b55b16 inset}
.formationBox.editorMode .node{cursor:grab;touch-action:none;user-select:none;pointer-events:auto;box-shadow:0 0 0 5px #d8b55b18}.formationBox.editorMode .node:active{cursor:grabbing;transform:translate(-50%,-50%) scale(1.08);z-index:20}
.formationBox.editorMode .node:before{content:"";position:absolute;inset:-12px;border:1px dashed #d8b55b45;border-radius:50%}
.formationEditorHint{position:absolute;right:92px;bottom:49px;z-index:9;display:none;padding:7px 10px;border-radius:999px;background:#090b0fe8;border:1px solid #d8b55b66;color:#e6cc7b;font-size:11px;font-weight:900;letter-spacing:1px}.formationEditorHint.on{display:block}
@media(max-width:940px){.editorActions{grid-template-columns:1fr}.editorContext{grid-template-columns:1fr}}


/* ===== INSTALLABLE PWA SHELL ===== */
.pwaBar{margin:10px 0 0;display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px 12px;border:1px solid #2e3945;border-radius:14px;background:#0a0f15}
.pwaInfo{min-width:0}.pwaTitle{font-size:11px;font-weight:1000;letter-spacing:1.4px;color:#d8b55b}.pwaStatus{margin-top:3px;font-size:10px;color:#7f8a97;line-height:1.45}
.pwaActions{display:flex;gap:7px;flex-wrap:wrap;justify-content:flex-end}.pwaActions button{min-height:36px;padding:7px 10px;font-size:10px;border-radius:10px}
.pwaInstall{background:#1d4935}.pwaUpdate{background:#5b4720;color:#f3d98f}.pwaUpdate[hidden]{display:none}
@media(max-width:650px){.pwaBar{align-items:flex-start;flex-direction:column}.pwaActions{width:100%;display:grid;grid-template-columns:1fr 1fr}.pwaActions button{width:100%;min-height:44px}.pwaStatus{font-size:11px}}


.mdColorEditor{margin-top:9px;padding:9px;border:1px solid #2a3541;border-radius:12px;background:#0a0f15}
.mdColorTitle{font-size:9px;font-weight:1000;letter-spacing:1.5px;color:#8895a3;margin-bottom:7px}
.mdColorGrid{display:grid;grid-template-columns:1fr 1fr 1fr auto;gap:7px;align-items:end}
.mdColorField{display:grid;grid-template-columns:38px 1fr;gap:7px;align-items:center}
.mdColorField span{font-size:9px;color:#8d98a5}
.mdColorField input[type=color]{width:38px;height:34px;border:1px solid #3a4653;border-radius:8px;background:#0d1218;padding:2px}
.mdColorValue{font-size:9px!important;padding:7px!important;min-width:0}
.mdColorReset{min-height:34px!important;padding:7px 10px!important;font-size:9px!important}
@media(max-width:650px){.mdColorGrid{grid-template-columns:1fr 1fr}.mdColorReset{grid-column:1/-1}}


.mobileUpdateBtn{border:1px solid #6b592d!important;background:linear-gradient(135deg,#17130b,#2a220f)!important;color:#f0d887!important;min-height:34px!important;padding:7px 11px!important;font-size:10px!important;border-radius:999px!important;white-space:nowrap}
.mobileUpdateBtn.busy{opacity:.55}.mobileUpdateStatus{font-size:9px;color:#778493;margin-top:5px;text-align:right}
.mobileRollbackBtn{border:1px solid #414b58!important;background:#171c23!important;color:#aab5c2!important;min-height:32px!important;padding:6px 10px!important;font-size:9px!important;border-radius:999px!important}
.topRight{display:grid;justify-items:end;gap:5px}
@media(max-width:650px){.mobileUpdateBtn{min-height:38px!important}}


/* ===== V4.7 MATCH MODE ===== */
.modeDock{margin:14px 0;background:linear-gradient(135deg,#101722,#0a0e14);border:1px solid #3b4756;border-radius:18px;padding:12px;display:flex;align-items:center;justify-content:space-between;gap:12px;box-shadow:0 18px 42px #0005}
.modeDockLeft{display:flex;align-items:center;gap:10px;min-width:0}.modeDockTitle{font-size:13px;font-weight:1000;letter-spacing:1.8px;color:#f0d783}.modeDockSub{font-size:9px;color:#788493;margin-top:3px}.modeDockRight{display:flex;gap:7px;align-items:center;flex-wrap:wrap;justify-content:flex-end}
.modeDock select{width:auto;min-width:125px;padding:8px;font-size:11px}.modeDock button{min-height:36px;font-size:10px}.modeEnter{background:linear-gradient(135deg,#1d6848,#48a873)!important}.preflightBtn{background:#15384d!important;color:#9fd9ff!important}
.matchCockpit{display:none;margin:14px 0;border:1px solid #465566;border-radius:22px;background:linear-gradient(180deg,#090d13,#05080c);padding:13px;box-shadow:0 25px 70px #0009}
body.mmOn .matchCockpit{display:block}
body.mmOn .top,body.mmOn .pwaBar,body.mmOn .setupDesk,body.mmOn .broadcastDesk,body.mmOn .layout,body.mmOn .vmixDirector,body.mmOn .matchdayDesk,body.mmOn .modeDock{display:none!important}
.mmHead{display:grid;grid-template-columns:1fr auto;gap:10px;align-items:center;margin-bottom:10px}.mmKicker{font-size:10px;letter-spacing:3px;color:#7d8a98;font-weight:1000}.mmTitle{font-size:20px;font-weight:1000}.mmTitle b{color:#e5ca78}.mmHeadActions{display:flex;gap:7px;align-items:center}.mmHeadActions select{width:auto;min-width:115px;padding:8px;font-size:11px}.mmExit{background:#3b2024!important;color:#ffb2b8!important}
.mmStatus{display:grid;grid-template-columns:repeat(4,1fr);gap:7px;margin-bottom:10px}.mmStatusCard{border:1px solid #2c3743;background:#0b1118;border-radius:12px;padding:9px}.mmStatusCard span{display:block;font-size:8px;letter-spacing:1.5px;color:#718090}.mmStatusCard b{display:block;margin-top:4px;font-size:11px}.mmGood{color:#7bddaa!important}.mmBad{color:#ff9298!important}.mmWarn{color:#edd17c!important}
.mmGrid{display:grid;grid-template-columns:1.15fr .95fr 1fr;gap:9px}.mmPanel{border:1px solid #2d3845;border-radius:15px;background:#090e14;padding:10px}.mmPanelTitle{font-size:9px;font-weight:1000;letter-spacing:2px;color:#8794a3;margin-bottom:8px}
.mmScoreTeams{display:grid;grid-template-columns:1fr 80px 1fr;gap:8px;align-items:center}.mmTeam{text-align:center;font-size:13px;font-weight:1000;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mmScore{font-size:48px;font-weight:1000;text-align:center}.mmScoreBtns{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:7px}.mmScoreBtns button{font-size:17px;min-height:42px}.mmClock{font-size:48px;text-align:center;font-weight:1000;font-variant-numeric:tabular-nums}.mmPeriod{text-align:center;color:#e4c979;font-size:9px;letter-spacing:2px;margin:3px 0 8px}.mmRow{display:grid;grid-template-columns:1fr 1fr;gap:6px}.mmRow3{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.mmPanel button{min-height:40px;font-size:10px}
.mmMacroGoal{background:#174c33!important}.mmMacroYellow{background:#655513!important;color:#fff0a0!important}.mmMacroRed{background:#5b2429!important}.mmMarker{background:#163247!important}.mmEmergency{margin-top:9px;border-color:#65343a;background:linear-gradient(180deg,#170b0d,#0b0d11)}.mmEmergencyGrid{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.mmEmergencyGrid button{min-height:48px;font-size:11px}.mmFreeze{background:#614c17!important;color:#ffe6a1!important}.mmHide{background:#5a2429!important}.mmSafe{background:#164d37!important}
.mmPreflight{margin-top:9px}.mmPreflightList{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}.mmCheck{padding:7px;border:1px solid #303a46;border-radius:9px;background:#0b1117;font-size:8px;color:#8995a3}.mmCheck.good{border-color:#315d49;color:#8fddb2;background:#0d1d16}.mmCheck.bad{border-color:#67383c;color:#f0a4a8;background:#241215}.mmCheck.warn{border-color:#6a592e;color:#ead17e;background:#211b0d}.mmCheck b{display:block;font-size:9px;margin-bottom:2px}
.mmMarkerList{max-height:150px;overflow:auto;display:grid;gap:4px;margin-top:7px}.mmMarkerRow{display:grid;grid-template-columns:48px 68px 1fr auto;gap:6px;padding:6px;border-radius:8px;background:#0c1219;border:1px solid #27323e;font-size:9px}.mmMarkerTime{color:#e4ca78;font-weight:1000}
.mmRecovery{font-size:8px;color:#778493;margin-top:7px}.mmRoleHint{font-size:8px;color:#72808e;margin-top:5px}
body[data-operator-role="SCOREKEEPER"] .mmDirectorOnly{display:none!important}
body[data-operator-role="DIRECTOR"] .mmScoreOnly{display:none!important}
.mdProEditor{margin-top:8px;padding:8px;border:1px solid #283440;border-radius:11px;background:#090e14}.mdProGrid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}.mdProGrid label{font-size:8px}.mdProGrid input,.mdProGrid select{padding:7px;font-size:10px}
@media(max-width:900px){.modeDock{align-items:flex-start;flex-direction:column}.modeDockRight{width:100%;justify-content:flex-start}.mmGrid{grid-template-columns:1fr}.mmStatus{grid-template-columns:1fr 1fr}.mmPreflightList{grid-template-columns:1fr 1fr}.mmEmergencyGrid{grid-template-columns:1fr 1fr 1fr}}
@media(max-width:520px){body.mmOn .app{padding:8px 7px 30px}.mmTitle{font-size:16px}.mmHead{grid-template-columns:1fr}.mmHeadActions{justify-content:space-between}.mmStatus{grid-template-columns:1fr 1fr}.mmScore{font-size:42px}.mmClock{font-size:42px}.mdProGrid{grid-template-columns:1fr 1fr}}


.filterEngine{margin-top:10px;border:1px solid #354250;border-radius:14px;background:#091018;padding:10px}
.filterHead{display:flex;justify-content:space-between;gap:8px;align-items:center;margin-bottom:8px}.filterTitle{font-size:10px;font-weight:1000;letter-spacing:2px;color:#e2ca78}.filterStatus{font-size:9px;color:#8090a0}
.filterGrid{display:grid;grid-template-columns:1fr 1fr;gap:7px}.filterPresets{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-top:7px}.filterPresets button{min-height:40px;font-size:9px}
.filterOriginal{background:#222a34!important}.filterClean{background:#183d4f!important;color:#bfeeff!important}.filterWarm{background:#4b321b!important;color:#ffd49e!important}.filterNight{background:#17233e!important;color:#b7cbff!important}
.filterStrengthRow{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:center;margin-top:8px}.filterStrengthRow input{padding:0}.filterStrengthValue{min-width:42px;text-align:right;font-size:10px;color:#e8cf83;font-weight:900}
.mmFilter{margin-top:9px}.mmFilter .filterPresets{grid-template-columns:repeat(4,1fr)}
@media(max-width:520px){.filterPresets{grid-template-columns:1fr 1fr}.filterGrid{grid-template-columns:1fr}}


/* ===== V4.8 SMART ROSTER IMPORT ===== */
.rosterImport{margin:0 0 12px;border:1px solid #394653;border-radius:15px;background:linear-gradient(180deg,#0c131b,#080c11);padding:11px}
.riHead{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:8px}.riTitle{font-size:11px;font-weight:1000;letter-spacing:1.7px;color:#e2ca78}.riSub{font-size:9px;color:#7d8996;margin-top:3px;line-height:1.45}.riBadge{font-size:8px;padding:5px 7px;border:1px solid #3a594a;border-radius:999px;color:#8ed3ac;background:#0e2018;white-space:nowrap}
.riButtons{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}.riButtons .fileBtn,.riButtons button{min-height:39px;font-size:9px}.riCamera{background:#18384a!important;color:#b9e7ff!important}.riFile{background:#2a3040!important}.riPasteBtn{background:#3d3320!important;color:#f0d790!important}
.riPaste{display:none;margin-top:7px}.riPaste.on{display:block}.riPaste textarea{width:100%;min-height:105px;resize:vertical;background:#070b10;color:#fff;border:1px solid #343f4b;border-radius:10px;padding:9px;font-size:11px;line-height:1.5}.riPasteActions{display:flex;gap:6px;margin-top:6px}
.riStatus{margin-top:7px;padding:7px 8px;border-radius:9px;background:#070b0f;border:1px solid #29343f;color:#84919e;font-size:9px;line-height:1.45}.riStatus.work{border-color:#5a4c26;color:#e4c878}.riStatus.ok{border-color:#305d48;color:#92d6b1}.riStatus.bad{border-color:#66373b;color:#ee9ea3}
.riPreview{display:none;margin-top:8px;border-top:1px solid #25303b;padding-top:8px}.riPreview.on{display:block}.riTools{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-bottom:7px}.riTools button{min-height:34px;font-size:9px}.riCount{margin-left:auto;color:#8c98a5;font-size:9px}
.riTableWrap{max-height:330px;overflow:auto;border:1px solid #28333e;border-radius:10px}.riTable{width:100%;border-collapse:collapse;min-width:610px}.riTable th{position:sticky;top:0;z-index:1;background:#111923;color:#8995a3;font-size:8px;padding:6px 5px;text-align:left}.riTable td{border-top:1px solid #222d38;padding:4px}.riTable input,.riTable select{padding:5px 6px;border-radius:7px;font-size:9px;min-height:29px}.riTable .riUse{width:28px}.riWarn{color:#e5c673;font-size:8px;white-space:nowrap}.riCommit{width:100%;margin-top:8px;background:linear-gradient(135deg,#1d6848,#48a873)!important;min-height:43px!important}
@media(max-width:520px){.riButtons{grid-template-columns:1fr 1fr}.riButtons>:last-child{grid-column:auto}.riTableWrap{max-height:390px}}


/* ===== V4.9 比赛设置 ===== */
.uxFlow{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:12px 0 14px}
.uxStep{position:relative;text-align:left;min-height:66px;padding:10px 12px;border:1px solid #303946;border-radius:14px;background:#0b1016;color:#fff}
.uxStep b{display:block;font-size:12px}.uxStep small{display:block;margin-top:5px;color:#7f8a98;font-size:9px;line-height:1.35}
.uxStep .uxN{position:absolute;right:10px;top:9px;width:23px;height:23px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:#18212c;color:#8d99a8;font-size:10px;font-weight:1000}
.uxStep.done{border-color:#2f7654;background:#0d1914}.uxStep.done .uxN{background:#2f7654;color:#fff}.uxStep.active{border-color:#d8b55b;box-shadow:0 0 0 1px #d8b55b2d inset}.uxStep.active b{color:#efd47f}
.teamSwitch.v49{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:10px 0}
.teamSwitch.v49 button{min-height:68px;text-align:left;padding:10px 12px;border:1px solid #303a47;background:#0b1016}
.teamSwitch.v49 button.on{border-color:#d8b55b;background:linear-gradient(135deg,#1a160d,#11161d);box-shadow:0 0 0 1px #d8b55b2e inset}
.teamSwitch .teamTabName{font-size:14px;font-weight:1000}.teamSwitch .teamTabMeta{display:block;margin-top:6px;font-size:9px;color:#8b96a4;font-weight:700}
.teamSwitch button.on .teamTabMeta{color:#d9c078}
.teamQuick{display:grid;grid-template-columns:1.4fr repeat(3,1fr);gap:7px;margin:9px 0 4px}
.teamQuickItem{background:#090d12;border:1px solid #29333e;border-radius:11px;padding:8px 9px}.teamQuickItem span{display:block;color:#778290;font-size:8px;letter-spacing:.8px}.teamQuickItem b{display:block;margin-top:4px;font-size:12px;color:#eef1f5}
.teamQuickItem.good{border-color:#2e674b}.teamQuickItem.warn{border-color:#70592b}
.uxTeamActions{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin-top:8px}.uxTeamActions button{min-height:42px}.uxImportJump{background:#253a55!important;color:#bfe1ff!important}
.importTarget{display:flex;justify-content:space-between;align-items:center;gap:8px;margin:8px 0;padding:9px 10px;border-radius:11px;background:#0a0f15;border:1px solid #33404d}
.importTarget span{font-size:9px;color:#8793a0}.importTarget b{font-size:11px;color:#efd47f}
.uxAutoSave{font-size:9px;color:#6fae8b;margin-top:6px}
.mobileTeamDock{display:none;position:fixed;left:8px;right:8px;bottom:max(8px,env(safe-area-inset-bottom));z-index:120;background:#090d12ee;border:1px solid #303a47;border-radius:16px;padding:7px;backdrop-filter:blur(16px);box-shadow:0 18px 40px #0009;grid-template-columns:1fr 1fr 1.15fr 1fr}
.mobileTeamDock button{min-height:44px;padding:7px 5px;font-size:10px;border:1px solid #29333e}.mobileTeamDock button.on{border-color:#d8b55b;color:#edd17e;background:#1b170e}.mobileTeamDock .dockReady{background:#173928;color:#9ce1bb}
@media(max-width:760px){
 .uxFlow{grid-template-columns:1fr 1fr}.uxStep{min-height:58px}
 .teamQuick{grid-template-columns:1fr 1fr}.teamQuickItem:first-child{grid-column:1/-1}
 .mobileTeamDock{display:grid}
 body{padding-bottom:78px}
 .teamSwitch.v49 button{min-height:62px}
}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.stage{--teamAccent:#d8b55b}
.stage .teamSub,.stage .groupTitle,.stage .formationText{color:var(--teamAccent)}
.stage .groupLine{background:linear-gradient(90deg,var(--teamAccent),#fff,transparent)}
.stage .node.active{border-color:var(--teamAccent);box-shadow:0 0 0 4px #ffffff18,0 12px 28px #000b}
.stage .node.active .nodeNo{background:var(--teamAccent);color:#090b0f}
.stage .nodeVisual:after{content:"";position:absolute;left:0;right:0;bottom:0;height:4px;background:var(--teamAccent);opacity:.95}
.stage.group-FULL .headerMark{left:88px;top:48px;z-index:12}
.stage.group-FULL .teamCrest{width:82px;height:82px}
.stage.group-FULL .teamHead{font-size:30px;letter-spacing:1px}
.stage.group-FULL .teamSub{font-size:13px;letter-spacing:4px;margin-top:5px}
.stage.group-FULL .groupTitle{left:90px;top:188px;font-size:16px;letter-spacing:5px}
.stage.group-FULL .groupName{left:88px;top:224px;font-size:46px;letter-spacing:-1px}
.stage.group-FULL .groupLine{left:90px;top:286px;width:310px;height:4px}
.stage.group-FULL .fullList{left:86px;top:330px;width:348px;grid-template-columns:1fr;gap:5px}
.stage.group-FULL .fullRow{grid-template-columns:34px 40px 1fr;gap:8px;padding:7px 9px;border:1px solid #ffffff12;border-left:3px solid var(--teamAccent);border-radius:8px;background:linear-gradient(90deg,#0a0f16e8,#0a0f169c);animation:plRowIn .42s cubic-bezier(.2,.8,.2,1) both;animation-delay:calc(var(--row-i,0)*38ms + 120ms)}
.stage.group-FULL .fullRole{font-size:9px;letter-spacing:1px;color:var(--teamAccent)}
.stage.group-FULL .fullNo{font-size:16px}
.stage.group-FULL .fullName{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.stage.group-FULL .fullPos{display:none}
.stage.group-FULL .captainBadge{min-width:20px;height:20px;font-size:10px;margin-left:4px}
.stage.group-FULL .formationBox{left:470px;right:auto;top:84px;width:1368px;height:910px;padding:34px;border-radius:28px;background:linear-gradient(145deg,#080d13ee,#101923e8 58%,#070b10f2);border:1px solid #ffffff20;box-shadow:0 34px 90px #000a,0 0 0 1px #ffffff08 inset;backdrop-filter:blur(10px);animation:plBoardIn .62s cubic-bezier(.16,.84,.28,1) both}
.stage.group-FULL .formationBox:before{content:"";position:absolute;left:34px;right:34px;top:0;height:5px;background:linear-gradient(90deg,var(--teamAccent),transparent 72%);border-radius:0 0 8px 8px}
.stage.group-FULL .formationHead{align-items:center}
.stage.group-FULL .formationTitle{font-size:18px;letter-spacing:5px}
.stage.group-FULL .formationHead .muted{font-size:10px;letter-spacing:3px}
.stage.group-FULL .formationText{font-size:50px;letter-spacing:-2px}
.stage.group-FULL .pitch{left:42px;right:42px;top:118px;bottom:42px;border:2px solid #ffffff55;border-radius:12px;background:linear-gradient(90deg,#143824,#0e2f1d 50%,#143824);box-shadow:0 22px 55px #0008 inset,0 0 0 1px #0005}
.stage.group-FULL .pitch:before{border-top-color:#ffffff48}
.stage.group-FULL .pitch:after{border-color:#ffffff48;width:145px;height:145px}
.stage.group-FULL .boxTop,.stage.group-FULL .boxBottom{width:280px;height:105px;border-color:#ffffff48}
.stage.group-FULL .node{width:104px;height:118px;border-radius:17px;background:#0b1118e8;border-color:#ffffff30;box-shadow:0 12px 24px #000a;animation:plNodeIn .5s cubic-bezier(.16,.84,.28,1) both;animation-delay:calc(var(--node-i,0)*58ms + 220ms)}
.stage.group-FULL .nodeVisual{height:88px;border-radius:14px;background:linear-gradient(180deg,#27394d,#121a24)}
.stage.group-FULL .node small{top:94px;max-width:126px;font-size:11px;letter-spacing:.2px}
.stage.group-FULL .nodeNo{left:6px;top:6px;min-width:27px;height:27px;font-size:11px}
.stage.group-FULL .node:not(.hasPhoto){width:68px;height:68px}
.stage.group-FULL .node:not(.hasPhoto) small{top:73px}
.stage.group-FULL .node:not(.hasPhoto) .nodeFallbackNo{font-size:25px}
.stage.group-FULL .node:not(.hasPhoto) .nodeVisual:after{display:none}
@keyframes plBoardIn{from{opacity:0;transform:translateX(55px) scale(.975)}to{opacity:1;transform:translateX(0) scale(1)}}
@keyframes plNodeIn{0%{opacity:0;transform:translate(-50%,-38%) scale(.72)}70%{opacity:1;transform:translate(-50%,-52%) scale(1.04)}100%{opacity:1;transform:translate(-50%,-50%) scale(1)}}
@keyframes plRowIn{from{opacity:0;transform:translateX(-24px)}to{opacity:1;transform:translateX(0)}}


/* ===== V4.30.8 SHOT SAFETY ENGINE CONTROL ===== */
.matchdayDesk{border-color:#414a57;background:linear-gradient(180deg,#0e141c,#080b10);box-shadow:0 24px 64px #0008}
.mdTitle{color:#f2f4f7;font-size:15px}.mdTitle:before{content:"LIVE";display:inline-flex;align-items:center;justify-content:center;margin-right:9px;padding:4px 7px;border-radius:5px;background:#ef343c;color:#fff;font-size:8px;letter-spacing:1.5px;vertical-align:2px}
.mdPanel{background:linear-gradient(180deg,#0a0f15,#070a0f);border-color:#313a46;box-shadow:0 1px 0 #ffffff08 inset}
.mdScoreLine{padding:10px;border-radius:12px;background:#05080c;border:1px solid #252e39}
.mdTeam{font-size:14px}.mdScore{font-size:48px;letter-spacing:-2px}
.mdClock{font-size:48px;letter-spacing:-2px}
.mdPanelTitle{color:#aab4c1;letter-spacing:2.4px}
.mdGoal{background:linear-gradient(135deg,#17623d,#1f8d5a)!important}
.mdYellow{background:linear-gradient(135deg,#806d0c,#c4a90f)!important}
.mdRed{background:linear-gradient(135deg,#721f29,#a62f3c)!important}
.mdSub{background:linear-gradient(135deg,#145276,#237fab)!important}
.mdMvp{background:linear-gradient(135deg,#806424,#b78c34)!important}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.gdBar{display:grid;grid-template-columns:minmax(210px,1.6fr) auto auto 120px 120px auto;gap:8px;align-items:center;margin:0 0 10px;padding:9px 10px;border:1px solid #33404d;border-radius:13px;background:linear-gradient(90deg,#071019,#0b131c)}
.gdIdentity{min-width:0}.gdIdentity b{display:block;font-size:11px;letter-spacing:2px;color:#f3f5f7}.gdIdentity span{display:block;margin-top:3px;font-size:9px;letter-spacing:1px;color:#72d99c}.gdIdentity span.busy{color:#f0c96b}.gdIdentity span.manual{color:#77bfff}.gdIdentity span.error{color:#ff777d}
.gdSwitch{margin:0;display:flex;align-items:center;gap:7px;height:38px;padding:0 10px;border:1px solid #303b48;border-radius:9px;background:#0a0f15;color:#cbd3dc;font-size:10px;font-weight:900;white-space:nowrap}.gdSwitch input{width:16px;height:16px;margin:0;accent-color:#d8b55b}
.gdField{margin:0}.gdField span{display:block;margin:0 0 3px;font-size:8px;color:#7f8996;letter-spacing:1px}.gdField select{height:30px;padding:4px 7px;border-radius:8px;font-size:10px}
.gdAbort{min-height:38px!important;padding:6px 10px!important;background:#3a2024!important;color:#ff9a9f!important;border:1px solid #6a3038!important;font-size:10px!important}
@media(max-width:1050px){.gdBar{grid-template-columns:1fr 1fr 1fr}.gdIdentity{grid-column:1/4}.gdAbort{grid-column:3/4}}
@media(max-width:650px){.gdBar{grid-template-columns:1fr 1fr}.gdIdentity{grid-column:1/3}.gdAbort{grid-column:1/3}.gdField select{height:36px}}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.smartDirector{margin:0 0 10px;padding:10px;border:1px solid #344250;border-radius:14px;background:linear-gradient(135deg,#071019,#0c1620)}
.sdHead{display:flex;align-items:center;gap:8px;margin-bottom:8px}.sdHead>div:first-child{margin-right:auto}.sdHead b{display:block;font-size:11px;letter-spacing:2px;color:#f2f5f7}.sdHead span{font-size:9px;color:#7f8b98;letter-spacing:1px}
.sdCue{display:grid;grid-template-columns:92px minmax(0,1fr) 74px 104px;gap:9px;align-items:center;padding:9px;border:1px solid #2b3743;border-radius:11px;background:#070c12}
.sdSlot{height:48px;display:flex;align-items:center;justify-content:center;border-radius:9px;background:#101b27;border:1px solid #31475b;color:#8fd2ff;font-size:14px;font-weight:1000;letter-spacing:1px}
.sdTitle{font-size:13px;font-weight:1000;color:#fff}.sdReason{margin-top:4px;font-size:9px;color:#93a0ad;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sdConfidence{height:34px;display:flex;align-items:center;justify-content:center;border-radius:999px;background:#10251b;border:1px solid #28563c;color:#78dda4;font-size:10px;font-weight:1000;letter-spacing:1px}.sdConfidence.mid{background:#29230f;border-color:#66581d;color:#f1d66e}.sdConfidence.high{background:#10251b;border-color:#2c704a;color:#82e3ad}
.sdExecute{min-height:42px!important;background:linear-gradient(135deg,#17628b,#2186b9)!important;color:#fff!important}
.smartDirector.disabled{opacity:.52}.smartDirector.auto .sdExecute{box-shadow:0 0 0 1px #72d99c55 inset}.smartDirector.auto .sdConfidence:after{content:" · AUTO"}
@media(max-width:760px){.sdHead{flex-wrap:wrap}.sdCue{grid-template-columns:80px 1fr 66px}.sdExecute{grid-column:1/4}.sdReason{white-space:normal}.sdSlot{height:44px}}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.cameraRoleMap{align-items:stretch}.cameraRoleItem{display:grid;grid-template-columns:1fr;gap:5px}.cameraRoleItem input{font-weight:1000}.cameraRoleItem select{padding:7px 9px;border-radius:9px;font-size:11px;color:#d9e5ef;background:#0b1118;border-color:#344454}
.cameraRoleHint{height:34px;display:flex;align-items:center;padding:0 9px;border:1px solid #2e3945;border-radius:9px;background:#0a0f15;color:#71808e;font-size:9px;font-weight:900;letter-spacing:1px}
.cameraRoleSummary{display:flex;align-items:center;gap:10px;margin-top:8px;padding:8px 10px;border:1px solid #2d3c49;border-radius:10px;background:#081019}.cameraRoleSummary b{font-size:9px;letter-spacing:1.5px;color:#8fd2ff}.cameraRoleSummary span{min-width:0;font-size:9px;color:#92a0ad;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.vmixDiscover{display:flex;align-items:center;gap:8px;margin-bottom:9px;padding:8px 9px;border:1px solid #2f4352;border-radius:10px;background:linear-gradient(135deg,#08121a,#0a1017)}.vmixDiscover button{min-height:34px!important;padding:6px 10px!important;border:1px solid #31536b!important;background:#102434!important;color:#8fd2ff!important;font-size:9px!important}.vmixDiscover button:hover{border-color:#62c8ff!important}.vmixDiscoverStatus{min-width:0;flex:1;font-size:9px;color:#8d9ba8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.vmixDiscoverStatus.good{color:#78dda4}.vmixDiscoverStatus.warn{color:#ffc96b}.vmixInputList{display:flex;gap:5px;flex-wrap:wrap;margin-top:7px}.vmixInputChip{display:inline-flex;align-items:center;gap:5px;padding:4px 7px;border-radius:999px;background:#0a131b;border:1px solid #293e4e;color:#8fa0ae;font-size:8px}.vmixInputChip b{color:#8fd2ff}.vmixInputChip.graphics{border-color:#8b6d2e;color:#e4c873}.vmixInputChip.live{box-shadow:0 0 0 1px #55d58a33 inset;color:#8fe1af}
.cameraRoleItem>select:first-of-type{font-weight:1000}
.vdSource span{display:inline-block;margin-left:4px}.roleBadge{display:inline-flex;align-items:center;padding:3px 6px;border-radius:999px;background:#10202d;border:1px solid #27435a;color:#83cfff;font-size:8px;font-weight:1000;letter-spacing:.5px}
.sdSlot{flex-direction:column;line-height:1.05}.sdSlot small{display:block;margin-top:4px;font-size:7px;color:#788b9c;letter-spacing:.4px}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.shotSafety{margin:0 0 10px;padding:10px;border:1px solid #36414c;border-radius:14px;background:linear-gradient(135deg,#0a0f14,#0a1219)}
.ssHead{display:flex;align-items:center;gap:8px}.ssHead>div:first-child{margin-right:auto}.ssHead b{display:block;font-size:11px;letter-spacing:2px;color:#f1f4f6}.ssHead span{display:block;margin-top:3px;font-size:9px;color:#78dda4;letter-spacing:1px}.ssHead span.locked{color:#ffca6e}.ssHead span.blocked{color:#ff8187}
.ssAttack{min-height:38px!important;background:linear-gradient(135deg,#8a5c13,#b87d1c)!important;color:#fff4d5!important;border:1px solid #c79237!important;font-size:10px!important}
.ssAttack.on{box-shadow:0 0 0 2px #f4c65a55 inset,0 0 26px #d3912838}
.ssGrid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:9px}.ssGrid label{margin:0}.ssGrid label span,.ssNow span{display:block;margin-bottom:4px;font-size:8px;color:#7f8a96;letter-spacing:1px}.ssGrid select{height:34px;padding:5px 8px;border-radius:8px;font-size:10px}
.ssNow{padding:5px 9px;border:1px solid #2f3b46;border-radius:9px;background:#080d12}.ssNow b{display:block;font-size:10px;color:#8fd2ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ssReason{margin-top:7px;font-size:9px;color:#8b98a4;line-height:1.45}.shotSafety.blocked{border-color:#69343a}.shotSafety.locked{border-color:#72571e;background:linear-gradient(135deg,#151007,#101217)}
@media(max-width:760px){.ssHead{flex-wrap:wrap}.ssHead>div:first-child{width:100%;margin-right:0}.ssGrid{grid-template-columns:1fr 1fr}.ssAttack{flex:1}.ssNow{min-height:50px}}


/* V4.30.8 本机预监：仅战术分组显示战术板 */
.stage.group-SUB .formationBox,
.stage.group-TEAM .formationBox,
.stage.group-STING .formationBox,
.stage.group-MATCH .formationBox,
.stage.group-COUNTDOWN .formationBox{display:none!important}


/* ===== V4.30.8 职业节目导演台 ===== */
.showDirectorPro{padding:14px;border:1px solid #374454;border-radius:18px;background:linear-gradient(180deg,#0a0f15,#070a0f);box-shadow:0 22px 55px #0007,0 1px 0 #ffffff08 inset}
.proHead{margin-bottom:12px}.proHead>div:first-child b{display:block;font-size:14px;letter-spacing:1.6px;color:#f4f6f8}.proHead>div:first-child span{display:block;margin-top:4px;font-size:9px;color:#7f8b98;letter-spacing:1px}
.pdLiveBadge{padding:6px 10px;border-radius:999px;border:1px solid #39434f;background:#121820;color:#8995a2;font-size:9px;font-weight:1000;letter-spacing:1.2px}.pdLiveBadge.live{background:#4c1115;border-color:#a83239;color:#ff8c92;box-shadow:0 0 22px #e8454533}.pdLiveBadge.hold{background:#4d3a12;border-color:#8a6d25;color:#f2d678}.pdLiveBadge.done{background:#123422;border-color:#2f6d49;color:#8ae0ad}
.pdHero{display:grid;grid-template-columns:minmax(0,1fr) 44px minmax(0,1fr);gap:9px;align-items:center}.pdCue{min-height:104px;padding:14px 16px;border:1px solid #303b47;border-radius:14px;background:linear-gradient(135deg,#0b1118,#0d151d);position:relative;overflow:hidden}.pdCue:after{content:"";position:absolute;left:0;right:0;bottom:0;height:3px;background:#34404c}.pdOnAir{border-color:#5b2b31;background:linear-gradient(135deg,#160b0d,#0e1117)}.pdOnAir:after{background:#e84545}.pdNext{border-color:#344b60}.pdNext:after{background:#2aa6ff}.pdCueKicker{display:flex;align-items:center;gap:7px;font-size:9px;color:#8e9aa7;letter-spacing:1.8px;font-weight:1000}.pdCueKicker i{width:8px;height:8px;border-radius:50%;background:#e84545;box-shadow:0 0 15px #e84545aa}.pdCue b{display:block;margin-top:12px;font-size:20px;color:#f5f7f9;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.pdCue span{display:block;margin-top:6px;font-size:10px;color:#7f8b97}.pdFlowArrow{text-align:center;color:#576574;font-size:25px;font-weight:300}
.pdStats{display:grid;grid-template-columns:repeat(4,1fr);gap:7px;margin-top:10px}.pdStats>div{padding:9px 10px;border:1px solid #293440;border-radius:11px;background:#090e14}.pdStats span{display:block;font-size:8px;color:#74808d;letter-spacing:1px}.pdStats b{display:block;margin-top:5px;color:#dce4eb;font-size:12px;font-variant-numeric:tabular-nums}.pdStats>div:nth-child(2) b{color:#efce72}
.proProgress{height:8px;margin-top:10px;background:#111923}.proProgress i{background:linear-gradient(90deg,#e84545,#e2c76a 55%,#58bfff)}
.pdNow{margin-top:8px;min-height:18px;font-size:10px;color:#8c98a5;font-variant-numeric:tabular-nums}
.pdTransport{display:grid;grid-template-columns:1.25fr 1fr 1fr 1.3fr .8fr;gap:7px;margin-top:10px}.pdTransport button{min-height:48px;font-size:10px;font-weight:1000;letter-spacing:.4px}.pdStart{background:linear-gradient(135deg,#1d6848,#43a36f)!important;color:#fff!important}.pdNextBtn{background:linear-gradient(135deg,#145276,#247fac)!important;color:#fff!important}.pdHold.on{background:#664e18!important;color:#ffe393!important;border-color:#9c7830!important}.pdStop{background:#36151a!important;color:#ff9fa5!important;border-color:#71313a!important}
.pdEditBar{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:12px;padding-top:10px;border-top:1px solid #252e38}.pdEditBar b{font-size:11px;color:#d9e1e8}.pdEditBar span{margin-left:8px;font-size:9px;color:#707d89}.pdEditBar button{min-height:34px;padding:6px 10px;font-size:9px}
.showTimelineWrap{max-height:1400px;opacity:1;overflow:hidden;transition:max-height .32s ease,opacity .22s ease,margin .25s ease}.showTimelineWrap.collapsed{max-height:0;opacity:0;margin:0}
.pdTimelineLegend{display:grid;grid-template-columns:minmax(150px,1fr) 78px 105px 92px 52px 116px;gap:6px;padding:7px 8px;margin-top:8px;color:#63707d;font-size:8px;letter-spacing:1px}.pdTimelineLegend span:not(:first-child){text-align:center}
.showDirectorPro .showTimeline{gap:5px}.showDirectorPro .showStep{grid-template-columns:31px 58px minmax(120px,1fr) 74px 100px 90px 46px 110px 74px;padding:7px 8px;border-radius:10px;background:#080d13}.showDirectorPro .showStep.active{border-color:#e84545;background:#140c0e;box-shadow:inset 3px 0 #e84545}.showDirectorPro .showStep.done{opacity:.58}.showDirectorPro .showStep.queued{border-color:#34516b}.showDirectorPro .showSide{padding:4px 5px;border-radius:999px;text-align:center;font-size:8px;font-weight:1000;background:#15202b;color:#9acfff}.showDirectorPro .showSide.away{background:#241d0d;color:#e8ce78}.showDirectorPro .showState{font-size:8px;text-align:center;color:#778390}.showDirectorPro .showState.live{color:#ff7d84}.showDirectorPro .showState.done{color:#6fae8b}.showDirectorPro .showTake{padding:6px 7px!important;font-size:8px!important;background:#132231!important;color:#8fcfff!important}.showDirectorPro .showStep input,.showDirectorPro .showStep select{padding:6px;font-size:9px}.pdEditActions{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin-top:8px}
@media(max-width:760px){.pdHero{grid-template-columns:1fr}.pdFlowArrow{display:none}.pdCue{min-height:86px}.pdStats{grid-template-columns:1fr 1fr}.pdTransport{grid-template-columns:1fr 1fr}.pdStart,.pdNextBtn{grid-column:span 1}.pdStop{grid-column:1/3}.pdTimelineLegend{display:none}.showDirectorPro .showStep{grid-template-columns:28px 48px 1fr 68px 72px}.showDirectorPro .showStep .showTransition,.showDirectorPro .showStep .showCue,.showDirectorPro .showStep .showEnable,.showDirectorPro .showStep .showMove{grid-column:auto}.showDirectorPro .showStep .showTake{grid-column:3/6}.showDirectorPro .showStep .showState{display:none}}


/* ===== V4.30.8 赛前转播包装 PRO ===== */
.matchOverlay{--homeAccent:#d8b55b;--awayAccent:#4c7dff;align-items:center;justify-content:center;background:radial-gradient(circle at 14% 50%,var(--homeAccent) 0,transparent 24%),radial-gradient(circle at 86% 50%,var(--awayAccent) 0,transparent 24%),linear-gradient(120deg,#05070a 0,#0a1017 48%,#05070a 100%);overflow:hidden}
.matchOverlay:before{content:"";position:absolute;inset:-20%;background:repeating-linear-gradient(118deg,#ffffff05 0 2px,transparent 2px 38px);transform:rotate(-4deg);opacity:.55}
.matchCardStage{width:1540px;height:770px;padding:0;border:0;background:#080d13f2;box-shadow:0 40px 120px #000c;position:relative;overflow:hidden}
.matchCardStage:before{content:"";position:absolute;left:0;right:0;top:0;height:8px;background:linear-gradient(90deg,var(--homeAccent) 0 48%,#fff 48% 52%,var(--awayAccent) 52% 100%)}
.matchCardStage:after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,var(--homeAccent) 0 15%,transparent 15% 85%,var(--awayAccent) 85% 100%);opacity:.09;pointer-events:none}
.matchTopLine{height:145px;display:flex;align-items:center;padding:25px 45px;border-bottom:1px solid #ffffff18;position:relative;z-index:2}
.matchEventLogoStage{width:86px;height:86px;object-fit:contain;margin-right:24px;filter:drop-shadow(0 12px 18px #0009)}
.matchCompetition{font-size:29px;letter-spacing:2px;color:#fff;font-weight:1000}.matchRound{margin-top:8px;font-size:14px;letter-spacing:3px;color:#9da8b5}
.matchBroadcastTag{margin-left:auto;padding:8px 13px;border-radius:999px;background:#ffffff0d;border:1px solid #ffffff20;color:#dce3ea;font-size:11px;font-weight:1000;letter-spacing:2px}
.matchTeams{height:510px;display:grid;grid-template-columns:1fr 250px 1fr;gap:20px;align-items:center;margin:0;padding:35px 60px;position:relative;z-index:2}
.matchTeamBlock{text-align:center;min-width:0}.matchCrestShell{width:175px;height:175px;margin:0 auto 24px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:#ffffff0b;border:1px solid #ffffff24;box-shadow:0 22px 55px #0008}
.matchHomeBlock .matchCrestShell{border-color:var(--homeAccent)}.matchAwayBlock .matchCrestShell{border-color:var(--awayAccent)}
.matchCrestStage{width:125px;height:125px;object-fit:contain;filter:drop-shadow(0 12px 20px #0008)}
.matchTeamRole{font-size:11px;letter-spacing:5px;color:#8793a0;font-weight:1000}.matchTeam{margin-top:10px;font-size:44px;line-height:1.05;font-weight:1000;color:#fff;letter-spacing:-1px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.matchCenterStage{text-align:center}.matchVs{font-size:38px;color:#fff;font-weight:1000;letter-spacing:6px}.matchKickoffStage{margin-top:32px;font-size:66px;font-weight:1000;letter-spacing:-3px;color:#fff;font-variant-numeric:tabular-nums}.matchKickoffLabel{margin-top:7px;font-size:10px;color:#7e8a97;letter-spacing:4px}
.matchMetaStage{height:115px;margin:0;display:flex;justify-content:center;align-items:center;gap:16px;border-top:1px solid #ffffff14;background:#05090d;color:#7e8995;font-size:11px;letter-spacing:4px;position:relative;z-index:2}.matchMetaStage b{font-size:18px;color:#fff;letter-spacing:2px}
.stage.group-GK:before,.stage.group-DF:before,.stage.group-MF:before,.stage.group-FW:before{content:"";position:absolute;inset:0;z-index:0;background:linear-gradient(118deg,var(--teamAccent) 0 20%,transparent 20% 72%,#ffffff08 72% 74%,transparent 74% 100%);opacity:.18}
.stage.group-GK:after,.stage.group-DF:after,.stage.group-MF:after,.stage.group-FW:after{content:"";position:absolute;left:65px;right:65px;bottom:54px;height:1px;background:linear-gradient(90deg,transparent,var(--teamAccent),#fff,var(--teamAccent),transparent);opacity:.45}
.stage.group-GK .tunnelScene,.stage.group-DF .tunnelScene,.stage.group-MF .tunnelScene,.stage.group-FW .tunnelScene{opacity:.22;filter:saturate(.5) brightness(.65)}
.stage.group-GK .headerMark,.stage.group-DF .headerMark,.stage.group-MF .headerMark,.stage.group-FW .headerMark{top:54px}
.stage.group-GK .groupTitle,.stage.group-DF .groupTitle,.stage.group-MF .groupTitle,.stage.group-FW .groupTitle{top:187px;font-size:16px;letter-spacing:6px}
.stage.group-GK .groupName,.stage.group-DF .groupName,.stage.group-MF .groupName,.stage.group-FW .groupName{top:221px;font-size:58px;letter-spacing:-1px}
.stage.group-GK .groupLine,.stage.group-DF .groupLine,.stage.group-MF .groupLine,.stage.group-FW .groupLine{top:292px;height:4px;width:290px;background:var(--teamAccent)}
.stage.group-GK .playersArea,.stage.group-DF .playersArea,.stage.group-MF .playersArea,.stage.group-FW .playersArea{top:315px;height:720px;left:320px;width:1280px;gap:12px}
.playerCard{isolation:isolate}.playerBigNo{position:absolute;left:50%;top:5px;transform:translateX(-50%);z-index:-1;font-size:210px;line-height:.8;font-weight:1000;letter-spacing:-16px;color:var(--teamAccent);opacity:.12;pointer-events:none}
.playerCut{bottom:106px;height:525px}.playerCut img,.mediaVideo{filter:drop-shadow(0 24px 28px #000c)}
.playerLabel{left:7%;right:7%;bottom:10px;min-height:112px;padding:15px 18px 13px;text-align:left;background:#f4f6f8;color:#071019;box-shadow:0 15px 35px #0008;overflow:hidden}
.playerLabel:before{content:"";position:absolute;left:0;top:0;bottom:0;width:7px;background:var(--teamAccent)}
.playerNo{font-size:15px;color:#071019;font-weight:1000;letter-spacing:1px}.playerName{font-size:27px;line-height:1;margin-top:5px;color:#071019;font-weight:1000;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.playerRole{font-size:10px;color:#54606c;letter-spacing:2px;margin-top:6px;font-weight:900}
.playerLabel .statPill,.playerLabel .mediaTag,.playerLabel .directorBadge{display:none}.stage.group-GK .playerCard.one{width:610px}.stage.group-GK .playerCard.one .playerBigNo{font-size:250px}
.stage.group-DF .playerCard,.stage.group-MF .playerCard,.stage.group-FW .playerCard{max-width:285px}


/* V4.30.8 开场标识 + 倒计时统一包装 */
.stingOverlay{background:radial-gradient(circle at 50% 45%,#182633 0,#081018 42%,#020405 100%);overflow:hidden}
.stingOverlay:before{content:"";position:absolute;inset:-20%;background:repeating-linear-gradient(112deg,#ffffff06 0 2px,transparent 2px 44px);opacity:.5}
.stingCore{position:relative;z-index:2;min-width:720px;padding:70px 95px;border-top:1px solid #ffffff1f;border-bottom:1px solid #ffffff14;background:linear-gradient(90deg,transparent,#071019d9 15% 85%,transparent)}
.stingLogo{width:230px;height:230px}.stingComp{font-size:30px;letter-spacing:4px;color:#fff}.stingLine{width:520px;height:5px;background:linear-gradient(90deg,transparent,var(--teamAccent),#fff,var(--teamAccent),transparent)}
.countdownOverlay{background:radial-gradient(circle at center,#121d28 0,#070c12 46%,#020405 100%);overflow:hidden}
.countdownOverlay:before{content:"";position:absolute;left:-8%;right:-8%;top:48%;height:3px;background:linear-gradient(90deg,transparent,var(--teamAccent),#fff,var(--teamAccent),transparent);opacity:.55}
.countdownCore{position:relative;z-index:2;min-width:760px;padding:50px 70px;text-align:center;background:#071019d4;border:1px solid #ffffff18;box-shadow:0 32px 90px #000b}
.countdownLabel{font-size:15px;letter-spacing:7px;color:#aab5c0}.countdownNumber{font-size:260px;letter-spacing:-13px;line-height:.9;text-shadow:none}.countdownSub{font-size:20px;color:#fff;letter-spacing:3px;margin-top:24px}


/* ===== V4.30.8 点球大战导演 ===== */
.penaltyDirector{border-color:#44505c;background:linear-gradient(145deg,#0a1016,#080d12)}
.penSetup{display:grid;grid-template-columns:1fr 1fr 1.2fr;gap:7px}.penSetup label span{display:block;margin-bottom:4px;font-size:8px;color:#7f8b97;letter-spacing:1px}.penSetup select,.penSetup button{height:40px}
.penStart{background:linear-gradient(135deg,#1c6747,#3c9d6a)!important;color:#fff!important}
.penScoreBoard{display:grid;grid-template-columns:1fr 160px 1fr;gap:10px;align-items:center;margin-top:10px;padding:12px;border:1px solid #2f3a45;border-radius:12px;background:#060b10}
.penTeam{text-align:center;min-width:0}.penTeam span{display:block;font-size:10px;color:#9aa6b2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.penTeam b{display:block;margin-top:4px;font-size:40px;line-height:1;color:#fff}.penTeam.home b{color:#e5c86d}.penTeam.away b{color:#79b9ff}
.penCenter{text-align:center}.penCenter strong{display:block;font-size:12px;color:#f0f3f6}.penCenter span{display:block;margin-top:5px;font-size:9px;color:#84919d}
.penDots{display:flex;justify-content:center;gap:5px;flex-wrap:wrap;margin-top:9px;min-height:15px}.penDot{width:13px;height:13px;border-radius:50%;border:2px solid #52606d;background:#161d24;box-sizing:border-box}.penDot.goal{border-color:#6bd694;background:#6bd694;box-shadow:0 0 9px #6bd69455}.penDot.miss{border-color:#ef646c;background:#ef646c;position:relative}.penDot.miss:after{content:"×";position:absolute;left:50%;top:50%;transform:translate(-50%,-54%);font-size:11px;line-height:1;color:#fff;font-weight:1000}.penDot.pending.current{border-color:#e8cf72;box-shadow:0 0 0 3px #e8cf7222}
.penKickGrid{display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:6px;margin-top:9px}.penGoal{background:#153c2a!important;color:#8ce0ae!important;border-color:#2d704d!important}.penMiss{background:#3b171b!important;color:#ff9ca2!important;border-color:#733239!important}.penKickGrid button:disabled,.mmPenaltyDirector button:disabled{opacity:.28;filter:grayscale(.7)}
.penOps{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:7px}.penHint{margin-top:7px;font-size:9px;line-height:1.45;color:#81909d}.penHint.finished{color:#7bdca4;font-weight:900}
.mmPenaltyDirector{border-color:#354657}.mmPenScore{display:grid;grid-template-columns:1fr 1.1fr 1fr;gap:7px;align-items:center;text-align:center}.mmPenScore>div>span{font-size:9px;color:#8c98a4}.mmPenScore>div>b{display:block;font-size:28px;color:#fff;margin-top:3px}.mmPenCenter b{display:block;font-size:10px;color:#e7cd77}.mmPenCenter span{display:block;margin-top:4px;font-size:8px;color:#7d8995}.penDots.compact{gap:3px;margin-top:5px}.penDots.compact .penDot{width:9px;height:9px;border-width:1px}.penDots.compact .penDot.miss:after{font-size:8px}
@media(max-width:760px){.penSetup{grid-template-columns:1fr 1fr}.penStart{grid-column:1/3}.penScoreBoard{grid-template-columns:1fr 105px 1fr}.penTeam b{font-size:34px}.penKickGrid{grid-template-columns:1fr 1fr}.penOps{grid-template-columns:1fr 1fr}}


/* ===== V4.30.8 SAGI PK ARENA · 创意点球记分牌 · 极简控制 ===== */
.mmPenaltyDirector{display:none!important}
.simplePenaltyControl{border-color:#415163;background:linear-gradient(145deg,#0a1016,#071019)}
.spControlScore{display:grid;grid-template-columns:1fr 120px 1fr;gap:8px;align-items:center;padding:10px;border:1px solid #2f3c49;border-radius:12px;background:#060b10;text-align:center}
.spControlTeam span{display:block;font-size:10px;color:#97a4b0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.spControlTeam b{display:block;margin-top:4px;font-size:38px;line-height:1;color:#fff}.spControlTeam.home b{color:#e3c66b}.spControlTeam.away b{color:#70b5ff}
.spControlCenter strong{display:block;font-size:11px;color:#fff;letter-spacing:1.5px}.spControlCenter span{display:block;margin-top:5px;font-size:8px;color:#7e8b98}
.spControlDots{display:flex;justify-content:center;gap:4px;margin-top:7px;min-height:11px}.spControlDot{width:11px;height:11px;border-radius:50%;border:1px solid #596673;background:#151d24}.spControlDot.on{background:#64da91;border-color:#64da91;box-shadow:0 0 8px #64da9155}
.spBigButtons{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:9px}.spBigButtons button{min-height:72px!important;font-size:21px!important;font-weight:1000!important;letter-spacing:1px}.spPlus.home{background:linear-gradient(135deg,#6d5818,#c19c31)!important;color:#fff6cf!important;border-color:#d6b548!important}.spPlus.away{background:linear-gradient(135deg,#164a70,#267fc0)!important;color:#e6f4ff!important;border-color:#3b92cd!important}
.spSmallButtons{display:grid;grid-template-columns:1.2fr 1fr .8fr;gap:6px;margin-top:7px}.spSmallButtons button{min-height:38px}.spHint{margin-top:7px;color:#7f8c98;font-size:9px;line-height:1.45}
@media(max-width:760px){.spControlScore{grid-template-columns:1fr 92px 1fr}.spBigButtons button{min-height:78px!important;font-size:22px!important}.spSmallButtons{grid-template-columns:1fr 1fr}.spSmallButtons .danger{grid-column:1/3}}


/* V4.30.8 点球罚失显示 */
.spMissButtons{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:7px}.spMissButtons .spMiss{min-height:42px!important;background:#3c171b!important;border-color:#763139!important;color:#ff9aa1!important;font-weight:1000!important}
.spControlDot.miss{background:#e9525b;border-color:#ff9aa1;position:relative;box-shadow:0 0 8px #e9525b55}.spControlDot.miss:after{content:"×";position:absolute;left:50%;top:50%;transform:translate(-50%,-56%);font-size:8px;color:#fff;font-weight:1000}


/* ===== V4.30.8 · SAGI STAGE CONTROL SYSTEM ===== */
:root{
 --stageNavy:#061744;--stageNavy2:#071d57;--stageBlue:#0a43c9;--stageBlueBright:#19a7ff;
 --stageRed:#f33b4b;--stagePaper:#f7f8fc;--stageText:#f5f8ff;--stageMuted:#8da3c8;--stageLine:#ffffff1d
}
body{background:radial-gradient(circle at 78% -10%,#0a43c933,transparent 28%),linear-gradient(180deg,#03091c,#050d24 56%,#03091c)!important}
.app{max-width:1580px}
.top{
 border:1px solid var(--stageLine);border-radius:18px;padding:13px 15px!important;
 background:linear-gradient(112deg,#061744,#08265f)!important;box-shadow:0 18px 48px #01061780
}
.brand{color:#fff!important;letter-spacing:.5px}.top .sub{color:#a7bee5!important}.ver{background:#fff!important;color:#071638!important;border-radius:10px!important}
.mobileUpdateBtn{border-color:#265ec8!important;background:linear-gradient(135deg,#0a2c7a,#0a43c9)!important;color:#fff!important}
.mobileRollbackBtn{background:#0a183a!important;border-color:#263b68!important;color:#b7c7e5!important}
.uxStep{border-color:#20375f!important;background:#07142f!important;border-radius:14px!important}
.uxStep.active{border-color:#3485ff!important;box-shadow:0 0 0 1px #3485ff38 inset,0 12px 30px #01071c60!important}
.uxStep.active b{color:#fff!important}.uxStep.done{border-color:#225da5!important;background:#071e48!important}.uxStep.done .uxN{background:#0a43c9!important}
.setupDesk,.vmixDirector,.matchdayDesk,.modeDock,.matchCockpit{
 border-color:#213960!important;background:linear-gradient(180deg,#061329,#040a19)!important;box-shadow:0 24px 64px #01061980!important
}
.setupPanel,.vdPanel,.mdPanel,.mmPanel,.card,.smartDirector,.shotSafety,.showDirectorPro,.penaltyDirector,.simplePenaltyControl{
 background:linear-gradient(180deg,#081a3b,#06132c)!important;border-color:#243e68!important;border-radius:16px!important
}
.setupPanelTitle,.vdPanelTitle,.mdPanelTitle,.mmPanelTitle,.mdColorTitle{color:#91b8ff!important}
.mdTitle,.vdTitle,.setupTitle{color:#fff!important}
.mdTitle:before{background:var(--stageRed)!important;border-radius:7px!important}
.mdSync{background:#08224c!important;border-color:#20579c!important;color:#9cc8ff!important}
.mdLiveDot.on{background:#48a3ff!important;box-shadow:0 0 12px #48a3ff88!important}
.mdScore{font-size:46px!important;color:#fff!important;font-variant-numeric:tabular-nums}
.mdScoreBtn{background:#0b2d70!important;border-color:#2758a7!important;color:#fff!important;border-radius:11px!important}
.mdScoreBtn:hover{background:#0a43c9!important}
.mdClock{color:#fff!important}.mdPeriod{color:#8ab6ff!important}
.mdGoal{background:#0b6d4a!important}.mdYellow{background:#6a5712!important}.mdRed{background:#781f2a!important}
.mdSub{background:#0a3e83!important}.mdMvp{background:#5f4616!important}.mdState{background:#17315e!important}
.mdEventBtns button,.mdActions button,.mdScoreboardBtns button,.vdSource,.vdPreview button,.vdOverlay button,.pdTransport button{
 border-radius:11px!important;border-color:#294675!important
}
.mdColorEditor,.mdProEditor,.gdBar,.sdCue,.ssGrid,.spControlScore,.penScoreBoard{
 background:#041028!important;border-color:#223a63!important;border-radius:14px!important
}
.mdColorField input[type=color]{border-radius:9px!important;border-color:#315189!important;background:#061631!important}
.gdIdentity span,.sdHead span,.ssHead span,.pdHead span,.tiny,.muted{color:#8399bf!important}
.gdSwitch{background:#071a3a!important;border-color:#29466f!important;color:#c4d4ef!important}
.sdExecute,.pdStart,.pdNextBtn,.setupReadyActions .readyBtn{background:linear-gradient(135deg,#0a2f86,#0a43c9)!important;color:#fff!important;border-color:#3485ff!important}
.pdStop,.danger,.mmExit{background:#5a1620!important;color:#ffb5bd!important;border-color:#96313d!important}
.pdLiveBadge.live{background:#761b25!important;border-color:#f33b4b!important;color:#fff!important}
.pdCue,.showStep{background:#061530!important;border-color:#24406c!important;border-radius:13px!important}
.showProgress{background:#041027!important}.showProgress i{background:linear-gradient(90deg,#0a43c9,#19a7ff)!important}
.vdSource{background:#071b3d!important}.vdSource b{color:#8fc6ff!important}
.vdSource:hover{border-color:#3a91ff!important;background:#09295f!important}
.shotSafety{border-color:#294976!important}.ssAttack{background:linear-gradient(135deg,#7a4c0d,#b87912)!important}
.mmMacroGoal{background:#0b6042!important}.mmMacroYellow{background:#6a5712!important}.mmMacroRed{background:#781f2a!important}
.simplePenaltyControl{border-color:#294976!important}
.spPlus.home{background:linear-gradient(135deg,#0a3174,#0a43c9)!important;border-color:#3485ff!important;color:#fff!important}
.spPlus.away{background:linear-gradient(135deg,#17375f,#2864b1)!important;border-color:#4a83d3!important;color:#fff!important}
.penGoal{background:#0b4e37!important}.penMiss{background:#671a24!important}
.stageCard>.card,.stageCard .card{background:#041027!important;border-color:#233e69!important}
.frame{border-radius:16px!important;overflow:hidden!important;box-shadow:0 24px 70px #010619a0!important}
.statusBar{color:#8da3c8!important}
.refCardIcon.yellow,.refCardIcon.red{box-shadow:0 3px 8px #0008,inset 0 0 0 1px #ffffff45!important}
@media(max-width:760px){
 .top{border-radius:14px!important}.matchdayDesk,.vmixDirector,.setupDesk{border-radius:16px!important}
 .mdPanel,.mmPanel,.card{border-radius:14px!important}
}


/* ===== V4.30.8 · LIVE RELIABILITY ===== */
.mdSync{transition:border-color .2s ease,background .2s ease,color .2s ease;max-width:420px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.mdSync:has(.mdLiveDot.on){box-shadow:0 0 0 1px #2b68b933 inset,0 10px 26px #01071b55}
.mdEventStatus{min-height:18px}


/* ===== V4.30.8 · SCORE INTELLIGENCE CONTROL ===== */
.mdScoreBoard{position:relative}
.mdScoreBoard:after{content:"比分 · 时间 · 阶段 · 红牌 · 补时";display:block;margin-top:7px;color:#6f8fc6;font-size:8px;letter-spacing:.7px;text-align:center}


/* V4.30.8 compact scorebug note */
.mdScoreBoard:after{content:"常态：比分 + 时间｜补时：仅设置后显示 +N"!important}


/* V4.30.8 integrated identity note */
.mdScoreBoard:after{content:"常态：赛事标识与比分/时间一体化｜补时仅设置后显示 +N"!important}


/* ===== V4.30.8 · BROADCAST SHORT NAMES ===== */
#mdHomeShort,#mdAwayShort{font-weight:900;letter-spacing:.2px}
.mdProEditor .mdProGrid>div:has(#mdHomeShort),.mdProEditor .mdProGrid>div:has(#mdAwayShort){border-color:#2e5fa2!important;background:#061a3b!important}


/* ===== V4.30.8 · SCORE RAIL NOTE ===== */
.mdScoreBoard:after{content:"常规：比分 + 时间｜补时：+N｜加时/点球：自动显示阶段"!important}


/* ===== V4.30.8 · SCORE CENTER NOTE ===== */
.mdScoreBoard:after{content:"常规：紧凑比分中心 + 时间｜比分变化：数字滚动｜补时/特殊阶段按需显示"!important}

</style>
</head>
<body>
<div class="app">
  <div class="top"><div><div class="brand">SAGI 赛事直播导播</div><div class="sub">V4.30.8 · STAGE 广播系统 · 比赛设置</div></div><div class="topRight"><div class="ver">V4.30.8</div><button id="mobileUpdateBtn" class="mobileUpdateBtn" type="button">↻ 安全更新</button><button id="mobileRollbackBtn" class="mobileRollbackBtn" type="button">↶ 回退上一版</button><div id="mobileUpdateStatus" class="mobileUpdateStatus">V4.30.8 · STAGE 广播系统 · 桥接服务已锁定</div></div></div>

  <div id="pwaBar" class="pwaBar" style="display:none">
    <div class="pwaInfo">
      <div class="pwaTitle">SAGI 导播应用 · 手机 / 桌面同步</div>
      <div id="pwaStatus" class="pwaStatus">正在检查应用安装与更新状态…</div>
    </div>
    <div class="pwaActions">
      <button id="pwaInstallBtn" class="pwaInstall" type="button">安装到主屏幕 / 桌面</button>
      <button id="pwaUpdateBtn" class="pwaUpdate" type="button" hidden>立即更新</button>
    </div>
  </div>

  <div class="uxFlow" id="uxFlow">
    <button class="uxStep active" id="uxStepMatch" type="button"><span class="uxN">1</span><b>比赛信息</b><small id="uxMatchMeta">赛事 / 时间 / 场地</small></button>
    <button class="uxStep" id="uxStepHome" type="button"><span class="uxN">2</span><b>主队</b><small id="uxHomeMeta">等待名单</small></button>
    <button class="uxStep" id="uxStepAway" type="button"><span class="uxN">3</span><b>客队</b><small id="uxAwayMeta">等待名单</small></button>
    <button class="uxStep" id="uxStepReady" type="button"><span class="uxN">4</span><b>赛前检查</b><small id="uxReadyMeta">未就绪</small></button>
  </div>

  <div id="setupDesk" class="setupDesk">
    <div class="setupHead">
      <div class="setupTitle">比赛设置 · 比赛设置<small>V4.30.8 · 广播动效引擎 · 就绪检查</small></div>
      <div id="setupReadyBadge" class="setupReadyBadge">未就绪</div>
    </div>
    <div class="setupGrid">
      <div class="setupPanel">
        <div class="setupPanelTitle">比赛项目</div>
        <div class="setupProjectGrid">
          <div><label>项目名称</label><input id="projectName" placeholder="例如：长风联赛 MD01 · TARLAN vs ICE POINT"></div>
          <div><label>已保存项目</label><select id="projectSelect"><option value="">选择比赛项目</option></select></div>
        </div>
        <div class="setupProjectActions">
          <button id="projectSaveBtn" class="ok" type="button">保存比赛项目</button>
          <button id="projectLoadBtn" type="button">读取项目</button>
          <button id="projectDeleteBtn" class="danger" type="button">删除项目</button>
          <button id="projectRecoverBtn" class="recover" type="button">↻ 找回历史比赛</button>
          <button id="projectCloudSyncBtn" class="ok" type="button">☁ 同步赛前云端</button>
          <label class="setupPhoneImport">📦 读取赛前 ZIP / 文件<input id="projectPhoneImportFile" type="file" accept=".zip,.sagi,.json,application/zip,application/json"></label>
        </div>
        <div id="projectRecoveryStatus" class="projectRecoveryStatus">可扫描旧版本、旧端口与 Bridge 恢复库；找回后自动并入永久比赛库，不覆盖现有项目。</div>
        <div class="tiny" style="margin-top:8px">比赛项目保存赛事信息、赛制、主客队名单、阵型、节目时间线与比赛事件状态；赛前 ZIP 可携带主客队名单、首发/替补、队徽和球员照片；导入后直接写入本机素材库。</div>
      </div>
      <div class="setupPanel">
        <div class="setupPanelTitle">赛前检查</div>
        <div id="setupChecks" class="setupChecks"></div>
        <div id="setupSummary" class="setupSummary">尚未检查。完成比赛信息和双队阵容后点击“检查比赛”。</div>
        <div class="setupReadyActions">
          <button id="setupValidateBtn" type="button">检查比赛</button>
          <button id="setupReadyBtn" class="readyBtn" type="button" disabled>可以播出</button>
          <button id="setupUnlockBtn" class="unlockBtn" type="button">解除就绪</button>
        </div>
      </div>
    </div>
  </div>

  <div class="broadcastDesk">
    <div class="bcMonitors">
      <div class="bcMonitor preview"><div class="bcKicker">预监画面</div><div id="bcPreviewLabel" class="bcBig">主队 · 球队开场</div><div id="bcPreviewMeta" class="bcMeta">准备就绪 · 本机预监，不会直接上屏</div></div>
      <div class="bcMonitor program"><div class="bcKicker">播出画面</div><div id="bcProgramLabel" class="bcBig">安全画面 / 未播出</div><div id="bcProgramMeta" class="bcMeta">等待切入播出</div></div>
      <div class="bcStatusBox">
        <div class="bcStatusLine"><span class="bcLamp ready" id="bcVmixLamp"><i></i>vMix 连接</span><b id="bcVmixStatus">检查中</b></div>
        <div class="bcStatusLine"><span class="bcLamp" id="bcOnAirLamp"><i></i>正在播出</span><b id="bcOnAirStatus">安全</b></div>
        <div class="bcStatusLine"><span>下一画面</span><b id="bcNextLabel">主队门将</b></div>
      </div>
    </div>
    <div class="bcFullIntroBar"><button id="fullIntroBtn" class="bcFullIntroBtn" type="button">▶ 一键播放完整出场<span>赛事标识 → 主队首发/替补 → 客队首发/替补</span></button></div>
    <div class="bcTransport">
      <button id="prevLiveBtn" type="button">← 上一个</button>
      <button id="holdBtn" class="hold" type="button">保持</button>
      <button id="goLiveBtn" class="goLive" type="button">● 切入播出</button>
      <button id="nextLiveBtn" type="button">下一画面 →</button>
      <button id="clearAllBtn" class="clearAll" type="button">一键清屏</button>
    </div>
    <div class="bcQuick">
      <button type="button" data-bc-group="STING" data-bc-label="赛事Logo">赛事标识</button>
      <button type="button" data-bc-group="MATCH" data-bc-label="比赛信息">比赛信息</button>
      <button type="button" data-bc-group="COUNTDOWN" data-bc-label="开场倒计时">开场倒计时</button>
      <button type="button" data-bc-side="HOME" data-bc-group="TEAM" data-bc-label="主队开场">主队开场</button>
      <button type="button" data-bc-side="HOME" data-bc-group="FULL" data-bc-label="主队首发">主队首发</button>
      <button type="button" data-bc-side="HOME" data-bc-group="SUB" data-bc-label="主队替补">主队替补</button>
      <button type="button" data-bc-side="AWAY" data-bc-group="TEAM" data-bc-label="客队开场">客队开场</button>
      <button type="button" data-bc-side="AWAY" data-bc-group="FULL" data-bc-label="客队首发">客队首发</button>
      <button type="button" data-bc-side="AWAY" data-bc-group="SUB" data-bc-label="客队替补">客队替补</button>
    </div>
    <div class="bcHint">空格键 = 切入播出 · H = 暂停/继续 · ←/→ = 上一画面/下一画面 · ESC = 一键清屏 · 本机大画面始终作为预监，vMix 浏览器作为播出画面。</div>
  </div>




  <div class="modeDock">
    <div class="modeDockLeft"><div><div class="modeDockTitle">V4.7 · 比赛模式</div><div class="modeDockSub">比赛驾驶舱 · 赛前自检 · 状态恢复 · 双角色 · 比赛安全</div></div></div>
    <div class="modeDockRight">
      <select id="operatorRole"><option value="FULL">完整导演</option><option value="DIRECTOR">导演模式</option><option value="SCOREKEEPER">比分员模式</option></select>
      <button id="technicalPreflightBtn" class="preflightBtn" type="button">赛前技术自检</button>
      <button id="enterMatchModeBtn" class="modeEnter" type="button">进入比赛模式</button>
    </div>
  </div>

  <div id="matchCockpit" class="matchCockpit">
    <div class="mmHead">
      <div><div class="mmKicker">SAGI 赛事直播导播 · V4.7</div><div class="mmTitle"><b>比赛模式</b> · 比赛驾驶舱</div></div>
      <div class="mmHeadActions"><select id="mmOperatorRole"><option value="FULL">完整导演</option><option value="DIRECTOR">导演</option><option value="SCOREKEEPER">比分员</option></select><button id="mmExit" class="mmExit" type="button">退出比赛模式</button></div>
    </div>
    <div class="mmStatus">
      <div class="mmStatusCard"><span>桥接服务</span><b id="mmBridgeStatus">检查中</b></div>
      <div class="mmStatusCard"><span>VMIX</span><b id="mmVmixStatus">检查中</b></div>
      <div class="mmStatusCard"><span>赛前自检</span><b id="mmReadyStatus">未检查</b></div>
      <div class="mmStatusCard"><span>状态恢复</span><b id="mmRecoveryStatus">本机 + 桥接服务</b></div>
    </div>

    <div class="mmGrid">
      <div class="mmPanel mmScoreOnly">
        <div class="mmPanelTitle">比分与计时</div>
        <div class="mmScoreTeams"><div><div id="mmHomeName" class="mmTeam">HOME</div><div id="mmHomeScore" class="mmScore">0</div></div><div><div id="mmClock" class="mmClock" style="font-size:25px">00:00</div><div id="mmPeriod" class="mmPeriod">1H</div></div><div><div id="mmAwayName" class="mmTeam">AWAY</div><div id="mmAwayScore" class="mmScore">0</div></div></div>
        <div class="mmScoreBtns"><button id="mmHomeMinus" type="button">主队 −</button><button id="mmHomePlus" class="ok" type="button">主队 ＋</button><button id="mmAwayMinus" type="button">客队 −</button><button id="mmAwayPlus" class="ok" type="button">客队 ＋</button></div>
        <div class="mmRow3" style="margin-top:6px"><button id="mmClockStart" class="ok" type="button">▶ 开始</button><button id="mmClockPause" type="button">Ⅱ 暂停</button><button id="mmScoreboardToggle" type="button">比分牌 开/关</button></div>
      </div>
      <div class="mmPanel mmScoreOnly simplePenaltyControl">
        <div class="mmPanelTitle">世界杯级点球记分牌</div>
        <div class="spControlScore">
          <div class="spControlTeam home"><span id="spHomeName">主队</span><b id="spHomeScore">0</b><div id="spHomeDots" class="spControlDots"></div></div>
          <div class="spControlCenter"><strong>点球大战</strong><span id="spVisibleState">当前隐藏</span></div>
          <div class="spControlTeam away"><span id="spAwayName">客队</span><b id="spAwayScore">0</b><div id="spAwayDots" class="spControlDots"></div></div>
        </div>
        <div class="spBigButtons">
          <button id="spHomePlus" class="spPlus home" type="button">主队 +1</button>
          <button id="spAwayPlus" class="spPlus away" type="button">客队 +1</button>
        </div>
        <div class="spMissButtons">
          <button id="spHomeMiss" class="spMiss" type="button">主队 ✕ 罚失</button>
          <button id="spAwayMiss" class="spMiss" type="button">客队 ✕ 罚失</button>
        </div>
        <div class="spSmallButtons">
          <button id="spToggle" type="button">显示点球记分牌</button>
          <button id="spUndo" type="button">↶ 撤销上一分</button>
          <button id="spReset" class="danger" type="button">清零</button>
        </div>
        <div class="spHint">直播端已升级为 SAGI PK ARENA：当前主罚侧高亮、进球绿勾、罚失红叉；超过5轮自动进入突然死亡，比分无限累加。</div>
      </div>
      <div class="mmPanel mmScoreOnly mmPenaltyDirector">
        <div class="mmPanelTitle">点球大战</div>
        <div class="mmPenScore"><div><span id="mmPenHomeName">主队</span><b id="mmPenHomeScore">0</b><div id="mmPenHomeDots" class="penDots compact"></div></div><div class="mmPenCenter"><b id="mmPenStage">未开始</b><span id="mmPenNext">等待进入点球大战</span></div><div><span id="mmPenAwayName">客队</span><b id="mmPenAwayScore">0</b><div id="mmPenAwayDots" class="penDots compact"></div></div></div>
        <div class="mmRow" style="margin-top:7px"><button id="mmPenGoal" class="penGoal" type="button">✓ 当前主罚 · 进</button><button id="mmPenMiss" class="penMiss" type="button">✕ 当前主罚 · 失</button></div>
        <div class="mmRow" style="margin-top:6px"><button id="mmPenStart" type="button">开始点球大战</button><button id="mmPenUndo" type="button">↶ 撤销上一罚</button></div>
      </div>

      <div class="mmPanel mmScoreOnly">
        <div class="mmPanelTitle">一键事件</div>
        <div class="mmRow"><select id="mmEventSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select><select id="mmEventPlayer"><option value="">球员可选</option></select></div>
        <div class="mmRow3" style="margin-top:6px"><button id="mmGoalMacro" class="mmMacroGoal" type="button">⚽ 进球宏</button><button id="mmYellowMacro" class="mmMacroYellow" type="button"><span class="refCardIcon yellow" aria-hidden="true"></span><span>黄牌宏</span></button><button id="mmRedMacro" class="mmMacroRed" type="button"><span class="refCardIcon red" aria-hidden="true"></span><span>红牌宏</span></button></div>
        <div class="mmRow" style="margin-top:6px"><button id="mmHalf" type="button">半场结束</button><button id="mmFull" type="button">全场结束</button></div>
        <div class="mmPanelTitle" style="margin-top:9px">换人快捷操作</div>
        <div class="mmRow3"><select id="mmSubSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select><select id="mmSubOff"><option value="">换下</option></select><select id="mmSubOn"><option value="">换上</option></select></div>
        <button id="mmSubMacro" style="width:100%;margin-top:6px" type="button">↕ 一键播放换人</button>
        <div class="mmRoleHint">进球宏：自动加分 → 记录回放点 → 播放事件 → 自动回到比分牌。换人同样自动收起。</div>
      </div>

      <div class="mmPanel mmDirectorOnly">
        <div class="mmPanelTitle">机位导播</div>
        <div class="mmRow"><button id="mmCam1" class="ok" type="button" data-camera-slot="cam1">1 主机位</button><button id="mmCam2" type="button" data-camera-slot="cam2">2 机位2</button><button id="mmDrone" type="button" data-camera-slot="drone">3 无人机</button><button id="mmReplay" class="mmMarker" type="button" data-camera-slot="replay">4 回放</button></div>
        <div class="mmRow" style="margin-top:6px"><button id="mmGraphicsOn" type="button">图形开启</button><button id="mmGraphicsOff" type="button">图形关闭</button></div>
        <div class="mmFilter"><div class="mmPanelTitle" style="margin-top:10px">画面滤镜 · 电影感</div><div class="filterPresets"><button class="filterOriginal" type="button" data-mm-filter="ORIGINAL">原片</button><button class="filterClean" type="button" data-mm-filter="CLEAN">清晰</button><button class="filterWarm" type="button" data-mm-filter="WARM">暖色</button><button class="filterNight" type="button" data-mm-filter="NIGHT">夜场</button></div></div>
        <div class="mmPanelTitle" style="margin-top:10px">回放标记</div>
        <div class="mmRow3"><button id="mmMarkSave" class="mmMarker" type="button">扑救</button><button id="mmMarkIncident" class="mmMarker" type="button">对抗/冲突</button><button id="mmMarkKey" class="mmMarker" type="button">精彩</button></div>
      </div>
    </div>

    <div class="mmPanel mmEmergency">
      <div class="mmPanelTitle">紧急保护区</div>
      <div class="mmEmergencyGrid"><button id="mmFreeze" class="mmFreeze" type="button">冻结比分牌</button><button id="mmHideAll" class="mmHide" type="button">隐藏全部图形</button><button id="mmSafeCam" class="mmSafe" type="button">恢复安全主画面</button></div>
    </div>

    <div class="mmGrid" style="margin-top:9px;grid-template-columns:1.15fr .85fr">
      <div class="mmPanel mmPreflight">
        <div class="mmPanelTitle">赛前技术自检</div>
        <div id="mmPreflightList" class="mmPreflightList"><div class="mmCheck warn"><b>尚未检查</b>点击“运行赛前自检”</div></div>
        <div class="mmRow3" style="margin-top:7px"><button id="mmRunPreflight" class="preflightBtn" type="button">运行赛前自检</button><button id="mmLiveHealth" class="preflightBtn" type="button">比赛中健康检查</button><button id="mmRestoreState" type="button">从桥接服务恢复状态</button></div>
        <div id="mmRecoveryInfo" class="mmRecovery">状态保护：手机本地 + 桥接服务本地文件双重保存。</div>
      </div>
      <div class="mmPanel">
        <div class="mmPanelTitle">回放记录 · 时间点</div>
        <div id="mmMarkerList" class="mmMarkerList"><div class="mmRecovery">暂无标记</div></div>
        <div class="mmRow" style="margin-top:7px"><button id="mmCopyMarkers" type="button">复制标记</button><button id="mmClearMarkers" type="button">清空标记</button></div>
      </div>
    </div>
  </div>

  <div class="vmixDirector">
    <div class="vdHead">
      <div class="vdTitle">V4.30.8 · vMix 导播控制 <small>赛事直播导播</small></div>
      <div id="vdStatus" class="vdStatus">局域网桥接待命</div>
    </div>
    <div class="vdGrid">
      <div class="vdPanel">
        <div class="vdPanelTitle">输入映射 · 自动读取 vMix</div>
        <div class="vmixDiscover">
          <button id="vdAutoReadInputs" type="button">↻ 自动读取 vMix 输入</button>
          <div id="vdAutoReadStatus" class="vmixDiscoverStatus">等待读取 vMix Input…</div>
        </div>
        <div class="vdInputs cameraRoleMap">
          <div class="cameraRoleItem"><label>机位 1 · 输入</label><select id="vdCam1" aria-label="机位1输入"><option value="">未分配</option><option value="1">Input 1</option></select><select id="vdCam1Role" aria-label="CAM1角色">
            <option value="MAIN_WIDE">主全景</option>
            <option value="SIDELINE_CLOSE">边线近景</option>
            <option value="BENCH">教练席</option>
            <option value="GOAL_BEHIND">球门后</option>
            <option value="DRONE">无人机</option>
            <option value="BEAUTY_WIDE">氛围宽景</option>
            <option value="REPLAY">回放</option></select></div>
          <div class="cameraRoleItem"><label>机位 2 · 输入</label><select id="vdCam2" aria-label="机位2输入"><option value="">未分配</option></select><select id="vdCam2Role" aria-label="CAM2角色">
            <option value="MAIN_WIDE">主全景</option>
            <option value="SIDELINE_CLOSE">边线近景</option>
            <option value="BENCH">教练席</option>
            <option value="GOAL_BEHIND">球门后</option>
            <option value="DRONE">无人机</option>
            <option value="BEAUTY_WIDE">氛围宽景</option>
            <option value="REPLAY">回放</option></select></div>
          <div class="cameraRoleItem"><label>机位 3 · 输入</label><select id="vdDrone" aria-label="机位3输入"><option value="">未分配</option></select><select id="vdDroneRole" aria-label="CAM3角色">
            <option value="MAIN_WIDE">主全景</option>
            <option value="SIDELINE_CLOSE">边线近景</option>
            <option value="BENCH">教练席</option>
            <option value="GOAL_BEHIND">球门后</option>
            <option value="DRONE">无人机</option>
            <option value="BEAUTY_WIDE">氛围宽景</option>
            <option value="REPLAY">回放</option></select></div>
          <div class="cameraRoleItem"><label>机位 4 · 输入</label><select id="vdReplay" aria-label="机位4输入"><option value="">未分配</option></select><select id="vdReplayRole" aria-label="CAM4角色">
            <option value="MAIN_WIDE">主全景</option>
            <option value="SIDELINE_CLOSE">边线近景</option>
            <option value="BENCH">教练席</option>
            <option value="GOAL_BEHIND">球门后</option>
            <option value="DRONE">无人机</option>
            <option value="BEAUTY_WIDE">氛围宽景</option>
            <option value="REPLAY">回放</option></select></div>
          <div><label>SAGI 图形输入</label><select id="vdGraphics" aria-label="萨吉图形输入"><option value="">自动识别 / 未分配</option></select><div class="cameraRoleHint">Browser 自动识别为图形</div></div>
        </div>
        <div class="cameraRoleSummary"><b>机位角色引擎</b><span id="cameraRoleSummary">等待 vMix 输入</span></div>
        <div id="vdInputList" class="vmixInputList"></div>
        <div class="vdInputs" style="grid-template-columns:1fr 1fr 1fr;margin-top:7px">
          <div><label>切换方式</label><select id="vdTransition"><option value="Cut">硬切</option><option value="Fade">淡变</option><option value="Stinger1">转场 1</option></select></div>
          <div><label>淡变时长（毫秒）</label><input id="vdDuration" type="number" value="350" min="0" max="5000"></div>
          <div><label>图形叠加通道</label><select id="vdOverlay"><option value="1">叠加 1</option><option value="2">叠加 2</option><option value="3">叠加 3</option><option value="4">叠加 4</option></select></div>
        </div>
      </div>

      <div class="vdPanel">
        <div class="vdPanelTitle">播出画面 · 切入</div>
        <div class="vdSources">
          <button class="vdSource" id="vdTakeCam1" type="button" data-vd-take="cam1"><b>1</b><span>主全景</span></button>
          <button class="vdSource" id="vdTakeCam2" type="button" data-vd-take="cam2"><b>2</b><span>边线近景</span></button>
          <button class="vdSource" id="vdTakeDrone" type="button" data-vd-take="drone"><b>3</b><span>无人机</span></button>
          <button class="vdSource" id="vdTakeReplay" type="button" data-vd-take="replay"><b>4</b><span>回放</span></button>
        </div>
        <div class="vdPreview">
          <button id="vdPreviewCam1" type="button" data-vd-preview="cam1">预监 · 主全景</button>
          <button id="vdPreviewCam2" type="button" data-vd-preview="cam2">预监 · 边线近景</button>
          <button id="vdPreviewDrone" type="button" data-vd-preview="drone">预监 · 无人机</button>
          <button id="vdPreviewReplay" type="button" data-vd-preview="replay">预监 · 回放</button>
        </div>
      </div>

      <div class="vdPanel">
        <div class="vdPanelTitle">图形叠加</div>
        <div class="vdOverlay">
          <button id="vdGraphicsIn" class="on" type="button">图形叠加开启</button>
          <button id="vdGraphicsOut" class="off" type="button">图形叠加关闭</button>
          <button id="vdReloadGraphics" type="button">↻ 刷新直播图形</button>
          <button id="vdAllOverlaysOff" type="button">关闭全部图形叠加</button>
          <button id="vdTest" type="button">测试桥接指令</button>
        </div>
        <div class="vdBridgeHelp">局域网直连：手机与 vMix 电脑连接同一 Wi‑Fi。此页面由桥接服务在本机提供，所有导播指令与比赛图形直接走局域网，不依赖 Supabase。</div>
        <a class="vdDownload" href="/health" target="_blank">检查局域网桥接</a>
        <div class="vdKeys">快捷键：1/2/3/4 手动切机位 · G 图形开启 · X 图形关闭 · A 关键进攻保护。输入框正在编辑时快捷键自动停用。</div>
      </div>
      <div class="vdPanel">
        <div class="vdPanelTitle">画面滤镜 · 电影感</div>
        <div class="filterEngine">
          <div class="filterHead"><div class="filterTitle">机位画面</div><div id="filterStatus" class="filterStatus">原始画面 · 待命</div></div>
          <div class="filterGrid">
            <div><label>作用机位</label><select id="filterTarget"><option value="ALL">全部机位</option><option value="cam1">主机位</option><option value="cam2">机位2</option><option value="drone">无人机</option><option value="replay">回放</option></select></div>
            <div><label>LUT 滤镜槽位</label><input value="1 CLEAN · 2 WARM · 3 NIGHT" readonly></div>
          </div>
          <div class="filterPresets"><button class="filterOriginal" type="button" data-filter-preset="ORIGINAL">原始画面</button><button class="filterClean" type="button" data-filter-preset="CLEAN">球场清晰</button><button class="filterWarm" type="button" data-filter-preset="WARM">电影暖色</button><button class="filterNight" type="button" data-filter-preset="NIGHT">夜场电影感</button></div>
          <div class="filterStrengthRow"><input id="filterStrength" type="range" min="0" max="100" value="65"><div id="filterStrengthValue" class="filterStrengthValue">65%</div></div>
          <div class="vdBridgeHelp" style="margin-top:7px">vMix 每个摄像机输入：滤镜 1 = 清晰，滤镜 2 = 暖色，滤镜 3 = 夜场。控制台只开关 LUT，不改相机原始色彩。</div>
        </div>
      </div>
    </div>
  </div>

  <div class="matchdayDesk">
    <div class="mdHead">
      <div class="mdTitle">V4.30.8 · 比赛模式 <small>STAGE 广播系统 · 安全自动</small></div>
      <div id="mdSync" class="mdSync"><span id="mdSyncDot" class="mdLiveDot"></span>比赛图形待命</div>
    </div>
    <div class="gdBar">
      <div class="gdIdentity"><b>自动图形导演</b><span id="gdStatus">安全自动 · 就绪</span></div>
      <label class="gdSwitch"><input id="gdEnabled" type="checkbox" checked><span>自动图形</span></label>
      <label class="gdSwitch"><input id="gdAutoReplay" type="checkbox"><span>自动回放</span></label>
      <label class="gdField"><span>回放停留</span><select id="gdReplayHold"><option value="2500">2.5s</option><option value="3500" selected>3.5s</option><option value="5000">5s</option></select></label>
      <label class="gdField"><span>返回机位</span><select id="gdReturnSlot"><option value="cam1" selected>主机位</option><option value="cam2">机位 2</option></select></label>
      <button id="gdAbort" class="gdAbort" type="button">■ 终止自动流程</button>
    </div>
    <div id="smartDirector" class="smartDirector">
      <div class="sdHead">
        <div><b>智能导播</b><span>按机位职责推荐下一镜头</span></div>
        <label class="gdSwitch"><input id="sdEnabled" type="checkbox" checked><span>智能建议</span></label>
        <label class="gdSwitch"><input id="sdAutoTake" type="checkbox"><span>自动切换</span></label>
      </div>
      <div class="sdCue">
        <div id="sdCueSlot" class="sdSlot">机位 1</div>
        <div class="sdBody"><div id="sdCueTitle" class="sdTitle">保持主机位</div><div id="sdCueReason" class="sdReason">等待比赛事件</div></div>
        <div id="sdConfidence" class="sdConfidence">安全</div>
        <button id="sdExecute" class="sdExecute" type="button">执行建议</button>
      </div>
    </div>
    <div id="shotSafety" class="shotSafety">
      <div class="ssHead">
        <div><b>镜头安全</b><span id="ssStatus">安全 · 等待镜头</span></div>
        <label class="gdSwitch"><input id="ssEnabled" type="checkbox" checked><span>安全引擎</span></label>
        <button id="ssAttackLock" class="ssAttack" type="button">⚡ 关键进攻保护 12s</button>
      </div>
      <div class="ssGrid">
        <label><span>最短镜头</span><select id="ssMinShot"><option value="2000">2s</option><option value="3000" selected>3s</option><option value="4000">4s</option><option value="5000">5s</option></select></label>
        <label><span>自动冷却</span><select id="ssCooldown"><option value="1000">1s</option><option value="2000" selected>2s</option><option value="3000">3s</option><option value="4000">4s</option></select></label>
        <label><span>防来回跳</span><select id="ssBounce"><option value="4000">4s</option><option value="6000" selected>6s</option><option value="8000">8s</option><option value="10000">10s</option></select></label>
        <div class="ssNow"><span>当前播出画面</span><b id="ssCurrentShot">未知</b></div>
      </div>
      <div id="ssReason" class="ssReason">自动切换必须通过安全检查；手动切换永远优先。</div>
    </div>
    <div class="mdGrid">
      <div class="mdPanel">
        <div class="mdPanelTitle">比分控制</div>
        <div class="mdScoreLine">
          <div id="mdHomeName" class="mdTeam">主队</div>
          <button id="mdHomeMinus" class="mdScoreBtn" type="button">−</button>
          <div id="mdHomeScore" class="mdScore">0</div>
          <button id="mdHomePlus" class="mdScoreBtn" type="button">＋</button>
          <div id="mdAwayName" class="mdTeam">客队</div>
        </div>
        <div class="mdScoreLine" style="margin-top:4px">
          <div></div><button id="mdAwayMinus" class="mdScoreBtn" type="button">−</button><div id="mdAwayScore" class="mdScore">0</div><button id="mdAwayPlus" class="mdScoreBtn" type="button">＋</button><div></div>
        </div>
        <div class="mdScoreboardBtns"><button id="mdScoreboardShow" class="ok" type="button">显示比分牌</button><button id="mdScoreboardHide" type="button">隐藏比分牌</button></div>
        <div class="mdColorEditor">
          <div class="mdColorTitle">比分牌配色</div>
          <div class="mdColorGrid">
            <label class="mdColorField"><input id="mdHomeColor" type="color" value="#d8b55b"><span>主队颜色</span></label>
            <label class="mdColorField"><input id="mdAwayColor" type="color" value="#4c7dff"><span>客队颜色</span></label>
            <label class="mdColorField"><input id="mdAccentColor" type="color" value="#f4f0e8"><span>主题高光</span></label>
            <button id="mdColorReset" class="mdColorReset" type="button">恢复默认</button>
          </div>
        </div>
        <div class="mdProEditor">
          <div class="mdColorTitle">职业比分牌 V2</div>
          <div class="mdProGrid">
            <div><label>主队比分牌简称</label><input id="mdHomeShort" maxlength="12" autocomplete="off" placeholder="例：塔城地区"></div>
            <div><label>客队比分牌简称</label><input id="mdAwayShort" maxlength="12" autocomplete="off" placeholder="例：托里县"></div>
            <div><label>模板</label><select id="mdScoreTheme"><option value="sagi-pro">SAGI 职业风格</option><option value="sagi">SAGI 直播风格</option><option value="premier">英超风格</option><option value="uefa">欧战极简</option></select></div>
            <div><label>补时</label><input id="mdStoppage" maxlength="4" placeholder="+3"></div>
            <div><label>主队红牌</label><input id="mdHomeRed" type="number" min="0" max="5" value="0"></div>
            <div><label>客队红牌</label><input id="mdAwayRed" type="number" min="0" max="5" value="0"></div>
            <div><label>主队点球得分（自动）</label><input id="mdHomePen" type="number" min="0" max="20" value="0" readonly></div>
            <div><label>客队点球得分（自动）</label><input id="mdAwayPen" type="number" min="0" max="20" value="0" readonly></div>
          </div>
        </div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">比赛计时</div>
        <div id="mdClock" class="mdClock">00:00</div>
        <div id="mdPeriodLabel" class="mdPeriod">上半场</div>
        <div class="mdInputs" style="margin-top:8px">
          <select id="mdPeriod"><option value="1H">上半场</option><option value="2H">下半场</option><option value="ET1">加时上半场</option><option value="ET2">加时下半场</option><option value="PEN">点球大战</option></select>
          <input id="mdSetClock" value="00:00" placeholder="00:00">
        </div>
        <div class="mdClockBtns"><button id="mdClockStart" class="ok" type="button">▶ 开始</button><button id="mdClockPause" type="button">Ⅱ 暂停</button><button id="mdClockSetBtn" type="button">设置时间</button></div>
      </div>
      <div id="mdPenaltyDirector" class="mdPanel penaltyDirector">
        <div class="mdPanelTitle">点球大战导演</div>
        <div class="penSetup">
          <label><span>初始轮次</span><select id="mdPenRounds"><option value="3">3轮</option><option value="5" selected>5轮</option></select></label>
          <label><span>先罚球队</span><select id="mdPenFirst"><option value="HOME">主队</option><option value="AWAY">客队</option></select></label>
          <button id="mdPenStart" class="penStart" type="button">开始点球大战</button>
        </div>
        <div class="penScoreBoard">
          <div class="penTeam home"><span id="mdPenHomeName">主队</span><b id="mdPenHomeScore">0</b><div id="mdPenHomeDots" class="penDots"></div></div>
          <div class="penCenter"><strong id="mdPenStage">等待开始</strong><span id="mdPenNext">常规比分保持不变</span></div>
          <div class="penTeam away"><span id="mdPenAwayName">客队</span><b id="mdPenAwayScore">0</b><div id="mdPenAwayDots" class="penDots"></div></div>
        </div>
        <div class="penKickGrid">
          <button id="mdPenHomeGoal" class="penGoal" type="button">主队 ✓ 罚进</button>
          <button id="mdPenHomeMiss" class="penMiss" type="button">主队 ✕ 罚失</button>
          <button id="mdPenAwayGoal" class="penGoal" type="button">客队 ✓ 罚进</button>
          <button id="mdPenAwayMiss" class="penMiss" type="button">客队 ✕ 罚失</button>
        </div>
        <div class="penOps"><button id="mdPenUndo" type="button">↶ 撤销上一罚</button><button id="mdPenReset" class="danger" type="button">重置点球大战</button></div>
        <div id="mdPenHint" class="penHint">进入点球大战后，系统自动计算轮次、当前主罚方和突然死亡。</div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">比赛事件</div>
        <div class="mdInputs">
          <select id="mdEventSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select>
          <select id="mdEventPlayer"><option value="">选择球员</option></select>
        </div>
        <div class="mdEventBtns">
          <button id="mdGoalBtn" class="mdGoal" type="button">⚽ 进球</button>
          <button id="mdYellowBtn" class="mdYellow" type="button"><span class="refCardIcon yellow" aria-hidden="true"></span><span>黄牌</span></button>
          <button id="mdRedBtn" class="mdRed" type="button"><span class="refCardIcon red" aria-hidden="true"></span><span>红牌</span></button>
        </div>
        <div id="mdEventStatus" class="mdEventStatus">选择球队和球员后触发直播图形</div>
      </div>
    </div>

    <div class="mdBottom">
      <div class="mdPanel">
        <div class="mdPanelTitle">换人</div>
        <div class="mdSubGrid">
          <select id="mdSubSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select>
          <select id="mdSubOff"><option value="">换下球员</option></select>
          <select id="mdSubOn"><option value="">换上球员</option></select>
        </div>
        <div class="mdActions" style="margin-top:8px"><button id="mdSubBtn" class="mdSub" type="button">↕ 播放换人图形</button><button id="mdClearEventBtn" type="button">清除事件图形</button></div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">比赛阶段</div>
        <div class="mdActions">
          <button id="mdHalfBtn" class="mdState" type="button">半场结束</button>
          <button id="mdFullBtn" class="mdState" type="button">全场结束</button>
          <button id="mdClockReset" type="button">计时归零</button>
          <button id="mdScoreReset" type="button">比分归零</button>
        </div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">本场最佳球员</div>
        <div class="mdInputs">
          <select id="mdMvpSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select>
          <select id="mdMvpPlayer"><option value="">选择本场最佳球员</option></select>
        </div>
        <div class="mdActions" style="margin-top:8px"><button id="mdMvpBtn" class="mdMvp" type="button">★ 播放本场最佳图形</button><button id="mdPublishState" type="button">同步当前比分</button></div>
      </div>
    </div>

    <div class="mdOpsRow">
      <div class="mdPanel">
        <div class="mdPanelTitle">比赛事件日志</div>
        <div id="mdEventLog" class="mdEventLog"><div class="mdEmpty">暂无比赛事件</div></div>
        <div class="mdActions" style="margin-top:8px">
          <button id="mdUndoLast" class="danger" type="button">↶ 撤销最近事件</button>
          <button id="mdClearLog" type="button">清空事件日志</button>
        </div>
      </div>
      <div class="mdPanel">
        <div class="mdPanelTitle">本场事件统计</div>
        <div class="mdStatGrid">
          <div class="mdStat"><b id="mdStatGoal">0</b><span>进球事件</span></div>
          <div class="mdStat"><b id="mdStatYellow">0</b><span>黄牌</span></div>
          <div class="mdStat"><b id="mdStatRed">0</b><span>红牌</span></div>
          <div class="mdStat"><b id="mdStatSub">0</b><span>换人</span></div>
        </div>
      </div>
    </div>
  </div>

  <div class="layout">
    <div class="controls">
      <div class="card">
        <h2>比赛规格 <span id="formatBadge" class="teamSideBadge">11人制</span></h2>
        <div class="grid3">
          <div><label>比赛人数</label><select id="matchFormat"><option value="5">五人制</option><option value="7">七人制</option><option value="8">八人制</option><option value="9">九人制</option><option value="11" selected>十一人制</option><option value="CUSTOM">自定义</option></select></div>
          <div id="customCountWrap" style="display:none"><label>自定义场上人数（含门将）</label><input id="customPlayerCount" type="number" min="3" max="15" step="1" value="11"></div>
          <div><label>首发上限</label><input id="starterLimitView" value="11" readonly></div>
        </div>
        <div class="grid2" style="margin-top:9px">
          <div><label>自定义阵型（不含门将）</label><input id="customFormation" placeholder="例如 2-3-1"></div>
          <div><label>当前比赛规格</label><input id="formatStatus" value="11人制 · 4-3-3" readonly></div>
        </div>
        <div class="actions"><button id="applyCustomFormationBtn" type="button">应用自定义阵型</button></div>
        <div class="tiny" style="margin-top:8px">5 / 7 / 8 / 9 / 11 人制及自定义人数均可使用。阵型数字之和必须等于“场上人数 - 1”，门将固定为 1 人；主客队可使用不同阵型。</div>
      </div>


      <div class="card formationEditorCard">
        <div class="editorHeadRow"><h2 style="margin:0">阵型编辑器</h2><span id="editorBadge" class="editorBadge">已锁定</span></div>
        <div class="editorContext">
          <div><label>编辑对象</label><input id="editorContext" value="HOME · 4-3-3" readonly></div>
          <div><label>吸附网格</label><select id="editorGrid"><option value="1">1% 精细</option><option value="2" selected>2% 推荐</option><option value="5">5% 快速</option></select></div>
        </div>
        <div class="editorActions">
          <button id="editorToggleBtn" class="primary" type="button">开启拖动编辑</button>
          <button id="editorMirrorBtn" type="button">左右镜像</button>
          <button id="editorResetBtn" class="danger" type="button">重置预设站位</button>
        </div>
        <div id="editorStatus" class="editorStatus">右侧战术板为锁定状态。开启后直接拖动球员圆点；站位自动按球队 + 阵型保存。</div>
      </div>

      <div class="card" id="teamCard">
        <h2>双队阵容 <span id="activeSideBadge" class="teamSideBadge">主队</span></h2>
        <div class="teamSwitch v49">
          <button id="homeSideBtn" class="on" type="button"><span class="teamTabName">主队</span><span id="homeRosterMini" class="teamTabMeta">0 人 · 📷 0</span></button>
          <button id="awaySideBtn" type="button"><span class="teamTabName">客队</span><span id="awayRosterMini" class="teamTabMeta">0 人 · 📷 0</span></button>
        </div>
        <div class="teamQuick">
          <div class="teamQuickItem"><span>当前编辑</span><b id="currentTeamQuick">主队</b></div>
          <div class="teamQuickItem"><span>有效首发</span><b id="currentStarterQuick">0/11</b></div>
          <div class="teamQuickItem"><span>球员照片</span><b id="currentPhotoQuick">0/0</b></div>
          <div class="teamQuickItem"><span>替补</span><b id="currentBenchQuick">0</b></div>
        </div>
        <div class="grid2">
          <div><label>当前球队</label><input id="teamName" value="TARLAN FC"></div>
          <div><label>当前阵型</label><select id="formation"><option>4-3-3</option><option>4-4-2</option><option>4-2-3-1</option><option>3-5-2</option><option>3-4-3</option><option>5-3-2</option></select></div>
        </div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="crestPreview">队徽</div><div><label>球队队徽</label><label class="fileBtn">上传队徽<input id="crestFile" type="file" accept="image/*"></label></div></div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="bgPreview">球场</div><div><label>专业球场背景（可选）</label><label class="fileBtn">上传球场背景<input id="bgFile" type="file" accept="image/*"></label></div></div>
        <div class="actions"><button id="clearBgBtn" type="button">使用内置职业球场</button></div>
        <div class="dualHint">主队 / 客队各自独立保存阵型、队徽、动态首发、替补、球员照片/视频与球员视频导演参数。比赛人数由比赛规格统一控制，切换球队不会覆盖另一队。</div>
        <div class="uxTeamActions"><button id="jumpRosterBtn" class="uxImportJump" type="button">↓ 导入 / 编辑当前队名单</button><button id="quickValidateBtn" type="button">✓ 检查双队阵容</button></div>
        <div class="uxAutoSave" id="uxAutoSaveState">● 当前队修改后自动保存</div>
      </div>

      <div class="card">
        <h2>比赛包装</h2>
        <div class="matchPackage">
          <div class="packageHead"><b>比赛信息</b><span>赛事信息 · 标识动画 · 倒计时 · 音频</span></div>
          <div class="packageGrid">
            <div><label>赛事名称</label><input id="matchCompetition" value="TFC 冬季联赛"></div>
            <div><label>轮次</label><input id="matchRound" value="比赛日 01"></div>
            <div><label>主队</label><input id="matchHome" value="TARLAN FC"></div>
            <div><label>客队</label><input id="matchAway" value="对手"></div>
            <div><label>比赛时间</label><input id="matchKickoff" value="20:00"></div>
            <div><label>比赛场地</label><input id="matchVenue" value="TACHENG"></div>
          </div>
          <div class="asset" style="margin-top:10px"><div class="assetPreview" id="eventLogoPreview">赛事标识</div><div><label>赛事标识转场</label><label class="fileBtn">上传赛事标识<input id="eventLogoFile" type="file" accept="image/*"></label></div></div>
          <div class="packageHead" style="margin-top:12px"><b>音频素材</b><span>主音乐 + 提示音效</span></div>
          <div class="asset"><div class="assetPreview" id="musicPreview">音乐</div><div><label>本机主音乐</label><label class="fileBtn">上传音乐<input id="musicFile" type="file" accept="audio/*"></label></div></div>
          <div class="packageGrid" style="margin-top:8px">
            <div><label>vMix 主音乐链接</label><input id="musicUrl" placeholder="https://.../show-music.mp3"></div>
            <div><label>音乐音量</label><select id="musicVolume"><option value="0.35">35%</option><option value="0.5">50%</option><option value="0.65" selected>65%</option><option value="0.8">80%</option><option value="1">100%</option></select></div>
            <div><label>呼啸音效链接</label><input id="sfxWhoosh" placeholder="https://.../whoosh.mp3"></div>
            <div><label>冲击音效链接</label><input id="sfxHit" placeholder="https://.../hit.mp3"></div>
            <div><label>渐强音效链接</label><input id="sfxRiser" placeholder="https://.../riser.mp3"></div>
            <div><label>观众音效链接</label><input id="sfxCrowd" placeholder="https://.../crowd.mp3"></div>
            <div><label>转场音效链接</label><input id="sfxSting" placeholder="https://.../sting.mp3"></div>
          </div>
          <div class="audioEngine">
            <div class="audioEngineHead"><b>SAGI 音频引擎</b><span>主音乐总线 · 提示音 · 自动闪避 · 备用音效</span></div>
            <div class="audioEngineGrid">
              <div><label>音频模式</label><select id="audioMode"><option value="HYBRID" selected>混合模式</option><option value="EXTERNAL">仅外部素材</option><option value="BUILTIN">仅内置引擎</option><option value="MUTE">静音</option></select></div>
              <div><label>内置主题</label><select id="audioTheme"><option value="SAGI_PULSE" selected>SAGI 节奏</option><option value="NORTH_WIND">北疆风</option><option value="BLACK_GOLD">黑金</option></select></div>
              <div><label>音效强度</label><select id="audioIntensity"><option value="0.55">低</option><option value="0.75" selected>中</option><option value="1">高</option></select></div>
              <div><label>音乐自动闪避</label><select id="audioDucking"><option value="0">关闭</option><option value="0.18">轻</option><option value="0.35" selected>中</option><option value="0.55">强</option></select></div>
              <div><label>提示音音量</label><select id="cueVolume"><option value="0.65">65%</option><option value="0.8">80%</option><option value="1" selected>100%</option></select></div>
              <div><label>倒计时节拍</label><select id="countdownBeat"><option value="1" selected>开启</option><option value="0">关闭</option></select></div>
            </div>
            <div class="audioMeters"><div><label>主音乐</label><div class="audioMeter"><i id="masterMeter"></i></div></div><div><label>提示音</label><div class="audioMeter"><i id="cueMeter"></i></div></div></div>
            <div class="audioDiag"><span id="audioEngineState">引擎就绪</span><span>备用音效 <b>开启</b></span></div>
          </div>
          <div class="actions"><button id="audioTestBtn" type="button">测试音乐</button><button id="cueTestBtn" type="button">测试重击音</button><button id="audioStopBtn" type="button">停止音频</button><button id="clearMusicBtn" type="button">清除本机音乐</button></div>
          <div id="audioStatus" class="audioStatus">音频已就绪 · 混合模式优先使用上传素材，缺失时自动使用 SAGI 内置音频</div>
        </div>
      </div>

      <div class="card" id="rosterCard">
        <h2>球员名单 · <span id="rosterSideText">主队</span></h2>
        <div class="importTarget"><span>本次导入将替换</span><b id="importTargetBadge">主队</b></div>
        <div class="rosterImport">
          <div class="riHead"><div><div class="riTitle">智能名单导入</div><div class="riSub">推荐：球队 ZIP 资料包（Excel + photos + 队徽）→ 自动匹配 → 一键替换当前球队；同时兼容 JSON / Excel / CSV / Word / PDF / 文本</div></div><div class="riBadge">赛前工具 · 不影响直播核心</div></div>
          <div class="riButtons">
            <label class="fileBtn riCamera">📷 拍照识别<input id="rosterCameraFile" type="file" accept="image/*" capture="environment"></label>
            <label class="fileBtn riFile">📦 导入球队资料包 / 文件<input id="rosterImportFile" type="file" accept=".zip,application/zip,application/x-zip-compressed,image/*,.txt,.csv,.tsv,.json,.xlsx,.xls,.docx,.pdf,text/plain,text/csv,application/json,application/pdf,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.openxmlformats-officedocument.wordprocessingml.document"></label>
            <button id="rosterPasteToggle" class="riPasteBtn" type="button">⌨ 粘贴名单</button>
            <button id="rosterTemplateBtn" type="button">⬇ 球队填报 Excel 模板</button>
          </div>
          <div id="rosterPaste" class="riPaste"><textarea id="rosterPasteText" placeholder="可直接粘贴：&#10;1  张三  GK  首发&#10;5  李四  CB  首发&#10;10 王五  CM  首发&#10;9  赵六  ST  首发&#10;18 阿力  MF  替补"></textarea><div class="riPasteActions"><button id="rosterParsePaste" class="ok" type="button">解析文字</button><button id="rosterPasteClear" type="button">清空</button></div></div>
          <div id="rosterImportStatus" class="riStatus">推荐球队资料包：ZIP 内放 1 个 Excel/CSV 名单 + 球员照片文件夹 + 可选队徽。系统自动按号码/姓名匹配照片；导入前会显示匹配结果。</div>
          <div id="rosterImportPreview" class="riPreview">
            <div class="riTools"><button id="riAllStarter" type="button">前 <span id="riStarterLimit">11</span> 人设首发</button><button id="riAutoRole" type="button">按阵型补位置</button><button id="riClearDraft" type="button">取消导入</button><span id="riCount" class="riCount">0 人</span></div>
            <div class="riTableWrap"><table class="riTable"><thead><tr><th>用</th><th>号码</th><th>姓名</th><th>身份</th><th>位置组</th><th>详细位置</th><th>队长</th><th>提示</th></tr></thead><tbody id="rosterImportBody"></tbody></table></div>
            <button id="rosterCommitImport" class="riCommit" type="button">确认替换并导入当前球队</button>
          </div>
        </div>
        <div class="grid2">
          <div><label>姓名</label><input id="playerName" value="MARHULAN"></div>
          <div><label>号码</label><input id="playerNo" value="88"></div>
          <div><label>名单身份</label><select id="squadType"><option value="STARTER">首发</option><option value="SUB">替补</option></select></div>
          <div><label>位置组</label><select id="role"><option value="GK">门将</option><option value="DF">后卫</option><option value="MF" selected>中场</option><option value="FW">前锋</option></select></div>
          <div><label>详细位置</label><input id="position" value="CM"></div>
          <div><label>队长</label><select id="captain"><option value="0">否</option><option value="1">C 队长</option></select></div>
          <div><label>数据名称</label><input id="statLabel" value="APPS"></div>
          <div><label>数据值</label><input id="statValue" value="12"></div>
        </div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="photoPreview">球员</div><div><label>球员照片</label><label class="fileBtn">上传球员照片<input id="photoFile" type="file" accept="image/*"></label></div></div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="mediaPreview">视频</div><div><label>球员短视频</label><label class="fileBtn">上传3–5秒视频<input id="mediaFile" type="file" accept="video/mp4,video/webm,video/quicktime,video/*"></label></div></div>
        <div class="grid2" style="margin-top:10px">
          <div><label>动作类型</label><select id="mediaAction"><option value="STANDARD">标准站姿</option><option value="WALK_IN">走向镜头</option><option value="ARMS">抱臂站定</option><option value="LOOK">转身看镜头</option><option value="GK_GLOVES">门将整理手套</option><option value="CELEBRATE">庆祝动作</option></select></div>
          <div><label>远端 vMix 视频链接</label><input id="mediaUrl" placeholder="https://.../player.mp4"></div>
        </div>
        <div class="mediaHelp">本机上传的视频保存在浏览器本地，用于手机/电脑预演；另一台电脑上的 vMix 优先读取上面的公开 HTTPS 视频URL。未填写时自动回退球员照片。</div>
        <div class="directorBox">
          <div class="directorHead"><b>球员视频导演</b><span>每名球员可独立设置</span></div>
          <div class="directorGrid">
            <div><label>开始点（秒）</label><input id="directorIn" type="number" min="0" step="0.1" value="0"></div>
            <div><label>结束点（秒）</label><input id="directorOut" type="number" min="0" step="0.1" value="0" placeholder="0=片尾"></div>
            <div><label>播放速度</label><select id="directorSpeed"><option value="0.5">0.50× 慢动作</option><option value="0.75">0.75× 慢动作</option><option value="1" selected>1.00× 正常</option><option value="1.25">1.25×</option></select></div>
            <div><label>结尾定格</label><select id="directorFreeze"><option value="0">关闭</option><option value="1">开启</option></select></div>
            <div><label>定格时长</label><select id="directorFreezeMs"><option value="500">0.5秒</option><option value="1000" selected>1秒</option><option value="1500">1.5秒</option><option value="2000">2秒</option></select></div>
            <div><label>镜头推进强度</label><select id="directorCamera"><option value="NONE">无</option><option value="LIGHT">轻</option><option value="MEDIUM" selected>中</option><option value="STRONG">强</option></select></div>
          </div>
        </div>
        <div class="actions"><button id="addBtn" class="ok" type="button">加入首发</button><button id="updateBtn" type="button">更新当前</button><button id="removeBtn" class="danger" type="button">删除当前</button><button id="clearMediaBtn" type="button">清除视频</button></div>
        <div id="starterHint" class="muted" style="margin-top:8px">当前首发 0/11；替补人数独立，不受场上人数限制。</div>
        <div id="roster" class="roster" style="margin-top:10px"></div>
        <div class="actions"><button id="saveBtn" type="button">保存当前队</button><button id="loadBtn" type="button">读取当前队</button><button id="demoBtn" type="button">载入当前赛制示例</button></div>
      </div>

      <div class="card">
        <h2>节目导演</h2>
        <div class="groupButtons">
          <button id="teamBtn" type="button">球队开场</button>
          <button id="gkBtn" type="button">门将</button>
          <button id="dfBtn" type="button">后卫</button>
          <button id="mfBtn" type="button">中场</button>
          <button id="fwBtn" type="button">前锋</button>
          <button id="fullBtn" type="button">完整首发</button><button id="subsBtn" type="button">替补名单</button>
        </div>
        <div class="showDirector showDirectorPro">
          <div class="showHead proHead"><div><b>职业节目导演台</b><span>当前播出 · 下一段 · 节奏 · 安全跳转</span></div><div id="showDirectorState" class="pdLiveBadge">待命</div></div>
          <div class="pdHero">
            <div class="pdCue pdOnAir"><div class="pdCueKicker"><i></i>正在播出</div><b id="showOnAirLabel">尚未开始</b><span id="showOnAirMeta">等待节目开始</span></div>
            <div class="pdFlowArrow">→</div>
            <div class="pdCue pdNext"><div class="pdCueKicker">下一段</div><b id="showNextProLabel">赛事标识</b><span id="showNextProMeta">第 1 段 · 2.0 秒</span></div>
          </div>
          <div class="pdStats">
            <div><span>节目位置</span><b id="showPosition">0 / 17</b></div>
            <div><span>剩余时间</span><b id="showRemain">57.0 秒</b></div>
            <div><span>节目总长</span><b id="showTotal">57.0 秒</b></div>
            <div><span>控制模式</span><b id="showMode">自动连续</b></div>
          </div>
          <div class="showProgress proProgress"><i id="showProgressBar"></i></div>
          <div id="showNow" class="pdNow">待命 · 可以开始节目</div>
          <div class="pdTransport">
            <button id="showPlayBtn" class="pdStart" type="button">▶ 从头播出</button>
            <button id="showHoldDirectorBtn" class="pdHold" type="button">保持当前</button>
            <button id="showPrevBtn" type="button">← 上一段</button>
            <button id="showNextBtn" class="pdNextBtn" type="button">执行下一段 →</button>
            <button id="stopBtn" class="pdStop" type="button">■ 停止</button>
          </div>
          <div class="pdEditBar"><div><b>节目单</b><span>17 段 · 主队 + 客队</span></div><button id="showEditToggle" type="button">展开节目单</button></div>
          <div id="showTimelineWrap" class="showTimelineWrap collapsed">
            <div class="pdTimelineLegend"><span>段落</span><span>时长</span><span>转场</span><span>提示音</span><span>启用</span><span>排序</span></div>
            <div id="showTimeline" class="showTimeline"></div>
            <div class="pdEditActions"><button id="showResetBtn" type="button">恢复默认节目单</button><button id="showSaveBtn" class="primary" type="button">保存节目单</button></div>
          </div>
        </div>
      </div>

      <div class="card">
        <h2>vMix 直播输出</h2>
        <div class="grid2"><div><label>输出背景</label><select id="outputBg"><option value="tunnel" selected>球员通道</option><option value="stadium">球场背景</option><option value="transparent">透明背景叠加</option><option value="chroma">绿幕</option></select></div><div><label>画面</label><input value="1920 × 1080" readonly></div></div>
        <div class="actions"><button id="copyVmixBtn" type="button">复制局域网 vMix 图形链接</button></div>
        <div class="tiny" style="margin-top:8px">vMix：添加输入 → 网页浏览器 → 粘贴局域网专用图形链接。控制端点击“切入播出”后同步到直播电脑。</div>
      </div>
    </div>

    <div class="stageCard">
      <div class="card">
        <div id="frame" class="frame">
          <div id="stageScale" class="stageScale">
            <div id="stage" class="stage">
              <div id="transitionLayer" class="transitionLayer"></div><div id="cueBadgeStage" class="cueBadgeStage"></div>
              <div id="stingOverlay" class="stingOverlay"><div class="stingCore"><img id="stingLogo" class="stingLogo"><div class="stingLine"></div><div id="stingCompetition" class="stingComp">SAGI FOOTBALL</div></div></div>
              <div id="matchOverlay" class="matchOverlay"><div class="matchCardStage">
                <div class="matchTopLine"><img id="matchEventLogoStage" class="matchEventLogoStage"><div><div id="matchCompetitionStage" class="matchCompetition">TFC 冬季联赛</div><div id="matchRoundStage" class="matchRound">比赛日 01</div></div><div class="matchBroadcastTag">赛前直播</div></div>
                <div class="matchTeams">
                  <div class="matchTeamBlock matchHomeBlock"><div class="matchCrestShell"><img id="matchHomeCrestStage" class="matchCrestStage"></div><div class="matchTeamRole">主队</div><div id="matchHomeStage" class="matchTeam">TARLAN FC</div></div>
                  <div class="matchCenterStage"><div class="matchVs">VS</div><div id="matchKickoffStage" class="matchKickoffStage">20:00</div><div class="matchKickoffLabel">开赛时间</div></div>
                  <div class="matchTeamBlock matchAwayBlock"><div class="matchCrestShell"><img id="matchAwayCrestStage" class="matchCrestStage"></div><div class="matchTeamRole">客队</div><div id="matchAwayStage" class="matchTeam">对手</div></div>
                </div>
                <div class="matchMetaStage"><span>比赛场地</span><b id="matchVenueStage">TACHENG</b></div>
              </div></div>
              <div id="countdownOverlay" class="countdownOverlay"><div class="countdownCore"><div class="countdownLabel">开赛倒计时</div><div id="countdownNumber" class="countdownNumber">5</div><div id="countdownSub" class="countdownSub">TFC 冬季联赛</div></div></div>
              <div id="tunnelScene" class="tunnelScene">
                <div class="tunnelBack"></div><div class="portal"></div><div class="wall left"></div><div class="wall right"></div><div class="ceiling"></div><div class="floor"></div>
                <div class="led left"><div id="ledLeft" class="ledText">TARLAN FC<small>STARTING XI</small></div></div>
                <div class="led right"><div id="ledRight" class="ledText">SAGI<small>球员通道</small></div></div>
                <div class="roofLights"></div><div class="fog"></div><div class="cameraVignette"></div>
              </div>
              <div class="stadium"></div><img id="stadiumPhoto" class="stadiumPhoto"><div class="stadiumShade"></div><div class="pitchLines"></div><div class="light l1"></div><div class="light l2"></div>
              <div id="headerMark" class="headerMark"><img id="stageCrest" class="teamCrest"><div><div id="stageTeam" class="teamHead">TARLAN FC</div><div id="stageLineupLabel" class="teamSub">STARTING XI</div></div></div>
              <div id="groupTitle" class="groupTitle">STARTING XI</div><div id="groupName" class="groupName">TEAM LINEUP</div><div class="groupLine"></div>
              <div id="freezeFlash" class="freezeFlash"></div><div id="roleGlow" class="roleGlow"></div><div id="roleBackdrop" class="roleBackdrop">11</div>
              <div id="playersArea" class="playersArea layout-TEAM"></div><div id="fullList" class="fullList" style="display:none"></div><div id="subList" class="subList" style="display:none"></div>
              <div id="formationEditorHint" class="formationEditorHint">拖动球员调整站位 · 自动保存</div><div id="formationBox" class="formationBox"><div class="formationHead"><div><div class="formationTitle">阵型</div><div class="muted">首发阵型</div></div><div id="formationText" class="formationText">4-3-3</div></div><div class="pitch"><div class="boxTop"></div><div class="boxBottom"></div><div id="formationNodes" class="formationNodes"></div></div></div>
            </div>
          </div>
        </div>
        <div class="statusBar"><div id="status" class="status">V4.30.8 · SHOT SAFETY ENGINE 已就绪</div><div class="mini">1920 × 1080</div></div>
      </div>
    </div>
  </div>
</div>
<div class="mobileTeamDock" id="mobileTeamDock">
  <button id="mobileHomeBtn" class="on" type="button">HOME<br>主队</button>
  <button id="mobileAwayBtn" type="button">AWAY<br>客队</button>
  <button id="mobileRosterBtn" type="button">名单<br>导入/编辑</button>
  <button id="mobileCheckBtn" class="dockReady" type="button">检查<br>赛前检查</button>
</div>
<div id="notice" class="notice"></div>

<script>
(function(){
'use strict';
const LAN_DIRECT=true;
async function lanJson(url,options={}){
  const r=await fetch(url,Object.assign({cache:'no-store'},options));
  if(!r.ok)throw new Error('LAN '+r.status);
  const t=await r.text();
  return t?JSON.parse(t):{};
}
async function lanPost(url,data){
  let payload=data||{};
  if(String(url).startsWith('/api/matchday')&&payload&&typeof payload==='object'&&!Array.isArray(payload)){
    try{const ps=(typeof getMatchProjects==='function')?getMatchProjects():[];if(ps.length)payload={...payload,__sagiProjects:ps}}catch(e){}
  }
  return lanJson(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
}

const q=id=>document.getElementById(id);
const FORMATIONS={
 '4-3-3':{GK:[[50,91]],DF:[[16,73],[38,72],[62,72],[84,73]],MF:[[24,48],[50,52],[76,48]],FW:[[18,22],[50,18],[82,22]]},
 '4-4-2':{GK:[[50,91]],DF:[[16,73],[38,72],[62,72],[84,73]],MF:[[16,48],[38,50],[62,50],[84,48]],FW:[[35,22],[65,22]]},
 '4-2-3-1':{GK:[[50,91]],DF:[[16,74],[38,72],[62,72],[84,74]],MF:[[36,56],[64,56],[18,38],[50,36],[82,38]],FW:[[50,18]]},
 '3-5-2':{GK:[[50,91]],DF:[[25,72],[50,75],[75,72]],MF:[[12,48],[32,54],[50,42],[68,54],[88,48]],FW:[[35,22],[65,22]]},
 '3-4-3':{GK:[[50,91]],DF:[[25,72],[50,75],[75,72]],MF:[[16,49],[38,52],[62,52],[84,49]],FW:[[18,22],[50,18],[82,22]]},
 '5-3-2':{GK:[[50,91]],DF:[[10,72],[30,75],[50,73],[70,75],[90,72]],MF:[[25,48],[50,52],[75,48]],FW:[[35,22],[65,22]]}
};
const ROLE_NAMES={GK:'门将',DF:'后卫',MF:'中场',FW:'前锋'};

const FORMAT_PRESETS={
 5:['1-2-1','2-1-1','2-2'],
 7:['2-3-1','3-2-1','2-2-2'],
 8:['2-3-2','3-2-2','3-3-1'],
 9:['3-3-2','3-2-3','2-3-3','4-2-2'],
 11:['4-3-3','4-4-2','4-2-3-1','3-5-2','3-4-3','5-3-2']
};
let matchConfig={mode:'11',playerCount:11};
function clampPlayerCount(n){return Math.max(3,Math.min(15,Math.round(Number(n)||11)))}
function starterLimit(){return clampPlayerCount(matchConfig.playerCount)}
function formationParts(name){return String(name||'').split('-').map(Number).filter(n=>Number.isFinite(n)&&n>0)}
function formationOutfieldCount(name){return formationParts(name).reduce((a,n)=>a+n,0)}
function defaultFormationForCount(n){
 n=clampPlayerCount(n);if(FORMAT_PRESETS[n])return FORMAT_PRESETS[n][0];
 const out=n-1;if(out<=2)return String(out);
 let df=Math.max(1,Math.round(out*.36)),fw=Math.max(1,Math.round(out*.25)),mf=out-df-fw;
 if(mf<1){mf=1;df=Math.max(1,out-fw-mf)}return [df,mf,fw].join('-')
}
function formatPresetList(n){n=clampPlayerCount(n);return (FORMAT_PRESETS[n]||[defaultFormationForCount(n)]).slice()}
function linePoints(count,y){count=Math.max(0,Number(count)||0);return Array.from({length:count},(_,i)=>[((i+1)/(count+1))*100,y])}
function formationPoints(name){
 if(FORMATIONS[name])return FORMATIONS[name];
 const nums=formationParts(name),f={GK:[[50,91]],DF:[],MF:[],FW:[]};if(!nums.length)return f;
 if(nums.length===1){f.MF=linePoints(nums[0],48);return f}
 if(nums.length===2){f.DF=linePoints(nums[0],72);f.FW=linePoints(nums[1],22);return f}
 f.DF=linePoints(nums[0],72);f.FW=linePoints(nums[nums.length-1],22);
 const mids=nums.slice(1,-1);mids.forEach((count,i)=>{const y=mids.length===1?48:58-(i*20/(mids.length-1));f.MF.push(...linePoints(count,y))});return f
}
function formationRoleCounts(name){
 const nums=formationParts(name),out={GK:1,DF:0,MF:0,FW:0};
 if(nums.length===1)out.MF=nums[0]||0;else if(nums.length===2){out.DF=nums[0]||0;out.FW=nums[1]||0}
 else if(nums.length>=3){out.DF=nums[0]||0;out.FW=nums[nums.length-1]||0;out.MF=nums.slice(1,-1).reduce((a,n)=>a+n,0)}return out
}
function startingLabel(n=starterLimit()){return '首发'+n+'人'}
function starterCode(n=starterLimit()){return String(n)}
function formatDisplay(){return matchConfig.mode==='CUSTOM'?'自定义 '+starterLimit()+'人制':starterLimit()+'人制'}
function refreshFormationOptions(preferred=''){
 const n=starterLimit(),el=q('formation'),list=formatPresetList(n);
 if(preferred&&formationOutfieldCount(preferred)===n-1&&!list.includes(preferred))list.unshift(preferred);
 const chosen=preferred&&list.includes(preferred)?preferred:defaultFormationForCount(n);
 el.innerHTML=list.map(f=>'<option value="'+escAttr(f)+'">'+esc(f)+'</option>').join('');
 if(!list.includes(chosen)){const o=document.createElement('option');o.value=chosen;o.textContent=chosen;el.appendChild(o)}
 el.value=chosen;teamStore[activeSide].formation=chosen;return chosen
}
function updateFormatUI(){
 const limit=starterLimit(),count=starters().length,over=Math.max(0,count-limit);
 q('formatBadge').textContent=formatDisplay();q('customCountWrap').style.display=matchConfig.mode==='CUSTOM'?'block':'none';
 q('starterLimitView').value=String(limit);q('customPlayerCount').value=String(limit);
 q('formatStatus').value=formatDisplay()+' · '+(q('formation').value||defaultFormationForCount(limit));
 const valid=effectiveStarters(roster,q('formation').value),need=formationRoleCounts(q('formation').value),have={GK:0,DF:0,MF:0,FW:0};valid.forEach(p=>have[p.role]=(have[p.role]||0)+1);
 const detail=['GK','DF','MF','FW'].map(r=>r+' '+(have[r]||0)+'/'+(need[r]||0)).join(' · '),missing=Math.max(0,limit-valid.length);
 q('starterHint').textContent=over?('当前标记首发 '+count+'/'+limit+'，系统只使用有效 '+valid.length+' 人。'):('有效首发 '+valid.length+'/'+limit+' · '+detail+(missing?' · 缺 '+missing+' 人':'')+'；替补人数独立。');
 q('starterHint').style.color=(over||missing)?'#ffb37a':'';q('addBtn').textContent=q('squadType').value==='SUB'?'加入替补':'加入首发';if(typeof refreshUXDashboard==='function')refreshUXDashboard()
}
function applyStoredMatchConfig(c={},silent=true){
 const count=clampPlayerCount(c.playerCount||c.count||11),isPreset=[5,7,8,9,11].includes(count),raw=String(c.mode||'');
 matchConfig={mode:(raw==='CUSTOM'||!isPreset)?'CUSTOM':String(count),playerCount:count};
 q('matchFormat').value=matchConfig.mode;q('customPlayerCount').value=String(count);if(!silent)note('已读取比赛规格 '+formatDisplay())
}
function setMatchFormatFromUI(silent=false){
 const mode=q('matchFormat').value||'11',count=mode==='CUSTOM'?clampPlayerCount(q('customPlayerCount').value):clampPlayerCount(mode);
 matchConfig={mode,playerCount:count};q('customPlayerCount').value=String(count);
 const results={};
 for(const side of ['HOME','AWAY']){
   const f=teamStore[side].formation;if(formationOutfieldCount(f)!==count-1)teamStore[side].formation=defaultFormationForCount(count);
   results[side]=reconcileTeamStarters(side,teamStore[side].formation)
 }
 roster=teamStore[activeSide].roster||roster;refreshFormationOptions(teamStore[activeSide].formation);renderRoster();updateFormatUI();renderStage(currentGroup);refreshMatchdayPlayers();
 if(!silent){const total={demoted:results.HOME.demoted+results.AWAY.demoted,promoted:results.HOME.promoted+results.AWAY.promoted,missing:results.HOME.missing+results.AWAY.missing};note('已切换 '+formatDisplay()+' · '+syncSummary(total))}
}
function applyCustomFormation(){
 const raw=q('customFormation').value.trim();
 if(!/^\d+(?:-\d+)*$/.test(raw)||formationOutfieldCount(raw)!==starterLimit()-1){note('阵型无效：数字之和必须等于 '+(starterLimit()-1)+'（不含门将）');return}
 const el=q('formation');if(![...el.options].some(o=>o.value===raw)){const o=document.createElement('option');o.value=raw;o.textContent=raw;el.appendChild(o)}
 el.value=raw;teamStore[activeSide].formation=raw;
 const sync=reconcileTeamStarters(activeSide,raw);roster=teamStore[activeSide].roster||roster;
 renderRoster();updateFormatUI();renderStage(currentGroup);refreshMatchdayPlayers();
 note('已应用自定义阵型 '+raw+(sync.changed?' · '+syncSummary(sync):''))
}
function rawStarters(list=roster){return (list||[]).filter(p=>(p.squadType||'STARTER')==='STARTER')}
function effectiveStarters(list=roster,formationName=''){
 const f=formationName||(q('formation')?q('formation').value:'')||defaultFormationForCount(starterLimit()),need=formationRoleCounts(f),out=[];
 for(const role of ['GK','DF','MF','FW']){
   const n=Math.max(0,Number(need[role])||0),arr=(list||[]).filter(p=>(p.squadType||'STARTER')==='STARTER'&&p.role===role);
   out.push(...arr.slice(0,n));
 }
 return out.slice(0,starterLimit())
}
function reconcileRosterForFormation(list,formationName){
 const need=formationRoleCounts(formationName),before=new Map((list||[]).map(p=>[p.id||p,p.squadType||'STARTER']));
 let promoted=0,demoted=0,selected=0;
 for(const role of ['GK','DF','MF','FW']){
   const target=Math.max(0,Number(need[role])||0),candidates=(list||[]).filter(p=>p.role===role);
   const current=candidates.filter(p=>(p.squadType||'STARTER')==='STARTER'),bench=candidates.filter(p=>p.squadType==='SUB');
   const chosen=current.slice(0,target);
   if(chosen.length<target)chosen.push(...bench.slice(0,target-chosen.length));
   const keep=new Set(chosen);candidates.forEach(p=>p.squadType=keep.has(p)?'STARTER':'SUB');selected+=chosen.length;
 }
 (list||[]).filter(p=>!['GK','DF','MF','FW'].includes(p.role)).forEach(p=>p.squadType='SUB');
 for(const p of (list||[])){
   const old=before.get(p.id||p)||'STARTER',now=p.squadType||'STARTER';
   if(old!==now){if(now==='SUB')demoted++;else promoted++}
 }
 return{promoted,demoted,selected,missing:Math.max(0,starterLimit()-selected),changed:(promoted+demoted)>0}
}
function reconcileTeamStarters(side,formationName){
 const t=teamStore&&teamStore[side];if(!t)return{promoted:0,demoted:0,selected:0,missing:starterLimit(),changed:false};
 return reconcileRosterForFormation(t.roster||[],formationName||t.formation||defaultFormationForCount(starterLimit()))
}
function syncSummary(r){
 const parts=[];if(r.demoted)parts.push('转替补 '+r.demoted+' 人');if(r.promoted)parts.push('补入首发 '+r.promoted+' 人');if(r.missing)parts.push('缺 '+r.missing+' 人');
 return parts.length?parts.join(' · '):'首发人数已匹配'
}

let roster=[],selected=-1,activeSide='HOME',teamStore={HOME:{roster:[],formation:'4-3-3',crest:'',customPositions:{}},AWAY:{roster:[],formation:'4-3-3',crest:'',customPositions:{}}},assets={photo:'',crest:'',bg:'',eventLogo:'',mediaBlob:null,mediaObjectUrl:'',musicBlob:null,musicObjectUrl:''},playing=false,seqTimer=null,currentGroup='TEAM';
let matchReady=false,setupReadySignature='',setupLastValidation=null;
const MATCH_PROJECTS_KEY='sagi_match_projects_v44';
let formationEditorActive=false,formationEditorGrid=2,formationDrag=null;


function formationPlayerKey(p){return String(p&&p.id||((p&&p.number)||'')+'|'+((p&&p.name)||'')+'|'+((p&&p.role)||''))}
function ensureCustomPositions(side=activeSide){
 const t=teamStore[side]||(teamStore[side]={roster:[],formation:defaultFormationForCount(starterLimit()),crest:'',customPositions:{}});
 if(!t.customPositions||typeof t.customPositions!=='object')t.customPositions={};return t.customPositions
}
function formationPositionMap(side=activeSide,formationName='',create=false){
 const t=teamStore[side],f=formationName||(t&&t.formation)||defaultFormationForCount(starterLimit()),all=ensureCustomPositions(side);
 if(create&&!all[f])all[f]={};return all[f]||{}
}
function clampFormationXY(v){return Math.max(5,Math.min(95,Number(v)||50))}
function snapFormationXY(v){const g=Math.max(1,Number(formationEditorGrid)||1);return Math.round(clampFormationXY(v)/g)*g}
function getFormationPointsFor(side,formationName){
 const t=teamStore[side]||{roster:[]},f=formationPoints(formationName),custom=formationPositionMap(side,formationName,false),out=[],valid=effectiveStarters(t.roster||[],formationName);
 for(const role of ['GK','DF','MF','FW']){
  const ps=f[role]||[],players=valid.filter(p=>p.role===role);
  players.forEach((p,i)=>{const key=formationPlayerKey(p),saved=custom[key],xy=Array.isArray(saved)&&saved.length>=2?[clampFormationXY(saved[0]),clampFormationXY(saved[1])]:(ps[i]||fallbackPoint(role,i,players.length));out.push({p,role,xy,key})})
 }
 return out
}
function currentFormationLayoutPayload(){
 const out={};getFormationPointsFor(activeSide,q('formation').value).forEach(({key,xy})=>out[key]=[Number(xy[0].toFixed(2)),Number(xy[1].toFixed(2))]);return out
}
function invalidateReadyForFormationEdit(message='阵型站位已调整'){
 if(matchReady){matchReady=false;setupReadySignature='';refreshSetupReadyUI()}
 validateMatchSetup(true);if(message)note(message+' · 请重新 READY')
}
function updateFormationEditorUI(){
 const f=q('formation').value||defaultFormationForCount(starterLimit()),box=q('formationBox');
 q('editorContext').value=sideLabel(activeSide)+' · '+f;q('editorGrid').value=String(formationEditorGrid);
 q('editorBadge').textContent=formationEditorActive?'EDIT MODE':'LOCKED';q('editorBadge').classList.toggle('on',formationEditorActive);
 q('editorToggleBtn').textContent=formationEditorActive?'完成编辑':'开启拖动编辑';q('editorToggleBtn').classList.toggle('editOn',formationEditorActive);
 q('editorStatus').classList.toggle('on',formationEditorActive);q('editorStatus').textContent=formationEditorActive?'编辑中：直接拖动右侧战术板球员圆点。坐标按 '+formationEditorGrid+'% 网格吸附并自动保存。':'右侧战术板为锁定状态。开启后直接拖动球员圆点；站位自动按球队 + 阵型保存。';
 if(box)box.classList.toggle('editorMode',formationEditorActive);q('formationEditorHint').classList.toggle('on',formationEditorActive)
}
function toggleFormationEditor(){
 if(!validStarters().length){note('请先设置首发阵容');return}
 if(matchReady){matchReady=false;setupReadySignature='';refreshSetupReadyUI();note('进入阵型编辑 · READY 已解除')}
 formationEditorActive=!formationEditorActive;if(formationEditorActive){currentGroup='FULL';renderStage('FULL')}else renderStage(currentGroup);
 updateFormationEditorUI()
}
function saveFormationNodePosition(playerKey,x,y){
 const f=q('formation').value,map=formationPositionMap(activeSide,f,true);map[playerKey]=[snapFormationXY(x),snapFormationXY(y)];
}
function beginFormationDrag(ev,node,playerKey){
 if(!formationEditorActive)return;ev.preventDefault();ev.stopPropagation();const pitch=node.closest('.pitch');if(!pitch)return;
 try{node.setPointerCapture(ev.pointerId)}catch(e){}
 formationDrag={pointerId:ev.pointerId,node,playerKey,pitch,moved:false};
 const move=e=>{if(!formationDrag||e.pointerId!==formationDrag.pointerId)return;const r=pitch.getBoundingClientRect();if(!r.width||!r.height)return;const x=snapFormationXY((e.clientX-r.left)/r.width*100),y=snapFormationXY((e.clientY-r.top)/r.height*100);node.style.left=x+'%';node.style.top=y+'%';saveFormationNodePosition(playerKey,x,y);formationDrag.moved=true;q('editorStatus').textContent='编辑中 · X '+x.toFixed(0)+'% · Y '+y.toFixed(0)+'% · 自动保存';};
 const end=e=>{if(!formationDrag||e.pointerId!==formationDrag.pointerId)return;node.removeEventListener('pointermove',move);node.removeEventListener('pointerup',end);node.removeEventListener('pointercancel',end);const moved=formationDrag.moved;formationDrag=null;if(moved){renderFormation(currentGroup);invalidateReadyForFormationEdit('球员站位已更新')}};
 node.addEventListener('pointermove',move);node.addEventListener('pointerup',end);node.addEventListener('pointercancel',end)
}
function mirrorFormationLayout(){
 const f=q('formation').value,map=formationPositionMap(activeSide,f,true),points=getFormationPointsFor(activeSide,f);points.forEach(({key,xy})=>map[key]=[snapFormationXY(100-xy[0]),snapFormationXY(xy[1])]);renderStage(currentGroup);invalidateReadyForFormationEdit('阵型已左右镜像')
}
function resetFormationLayout(){
 const f=q('formation').value,all=ensureCustomPositions(activeSide);delete all[f];renderStage(currentGroup);invalidateReadyForFormationEdit('已恢复 '+f+' 预设站位')
}
function initFormationEditor(){
 q('editorToggleBtn').onclick=toggleFormationEditor;q('editorMirrorBtn').onclick=mirrorFormationLayout;q('editorResetBtn').onclick=resetFormationLayout;
 q('editorGrid').onchange=()=>{formationEditorGrid=Math.max(1,Number(q('editorGrid').value)||2);updateFormationEditorUI()};updateFormationEditorUI()
}

function setupNormalizeNumber(v){const s=String(v??'').trim();if(/^\d+$/.test(s))return String(Number(s));return s.toUpperCase()}
function setupDuplicateNumbers(list=[]){
 const seen=new Map(),dups=[];(list||[]).forEach(p=>{const n=setupNormalizeNumber(p.number);if(!n)return;if(seen.has(n))dups.push(n);else seen.set(n,1)});return [...new Set(dups)]
}
function setupProjectDefaultName(){
 const comp=q('matchCompetition').value.trim(),round=q('matchRound').value.trim(),home=q('matchHome').value.trim(),away=q('matchAway').value.trim();
 return [comp,round,[home,away].filter(Boolean).join(' vs ')].filter(Boolean).join(' · ')||'SAGI MATCH PROJECT'
}
function setupTeamValidation(side){
 const t=teamStore[side]||{roster:[],formation:defaultFormationForCount(starterLimit())},list=t.roster||[],formation=t.formation||defaultFormationForCount(starterLimit()),limit=starterLimit();
 const valid=effectiveStarters(list,formation),raw=rawStarters(list),dups=setupDuplicateNumbers(list),missingIdentity=list.filter(p=>!String(p.name||'').trim()||!String(p.number||'').trim()),badStatus=list.filter(p=>!['STARTER','SUB'].includes(p.squadType||'STARTER'));
 const gk=valid.filter(p=>p.role==='GK').length,formationOK=formationOutfieldCount(formation)===limit-1;
 const issues=[];
 if(!formationOK)issues.push('阵型与'+limit+'人制不匹配');
 if(raw.length!==limit)issues.push('首发 '+raw.length+'/'+limit);
 if(valid.length!==limit)issues.push('有效首发 '+valid.length+'/'+limit);
 if(gk!==1)issues.push('门将 '+gk+'/1');
 if(dups.length)issues.push('号码重复 '+dups.join(', '));
 if(missingIdentity.length)issues.push('有 '+missingIdentity.length+' 名球员缺姓名/号码');
 if(badStatus.length)issues.push('名单身份异常 '+badStatus.length+' 人');
 return{side,ok:issues.length===0,issues,limit,formation,validCount:valid.length,rawCount:raw.length,gk,duplicates:dups}
}
function validateMatchSetup(render=true){
 stashActiveTeam();
 const competition=q('matchCompetition').value.trim(),home=q('matchHome').value.trim(),away=q('matchAway').value.trim(),kickoff=q('matchKickoff').value.trim(),venue=q('matchVenue').value.trim(),formatOK=starterLimit()>=3&&formationOutfieldCount(teamStore.HOME.formation)===starterLimit()-1&&formationOutfieldCount(teamStore.AWAY.formation)===starterLimit()-1;
 const infoIssues=[],infoWarnings=[];if(!competition)infoIssues.push('赛事名称');if(!home)infoIssues.push('主队');if(!away)infoIssues.push('客队');if(home&&away&&home===away)infoIssues.push('主客队名称相同');if(!kickoff)infoWarnings.push('比赛时间');if(!venue)infoWarnings.push('比赛场地');
 const H=setupTeamValidation('HOME'),A=setupTeamValidation('AWAY');
 const infoMeta=infoIssues.length?'缺少/异常：'+infoIssues.join('、'):(infoWarnings.length?'核心信息完整 · 可稍后补：'+infoWarnings.join('、'):'赛事信息完整');
 const checks=[
  {label:'比赛信息',ok:infoIssues.length===0,warn:infoIssues.length===0&&infoWarnings.length>0,meta:infoMeta},
  {label:'比赛规格',ok:formatOK,meta:formatDisplay()+' · HOME '+teamStore.HOME.formation+' · AWAY '+teamStore.AWAY.formation},
  {label:'主队首发',ok:H.ok,meta:H.ok?('有效首发 '+H.validCount+'/'+H.limit+' · GK '+H.gk):H.issues.join(' · ')},
  {label:'客队首发',ok:A.ok,meta:A.ok?('有效首发 '+A.validCount+'/'+A.limit+' · GK '+A.gk):A.issues.join(' · ')},
  {label:'主队号码',ok:H.duplicates.length===0,meta:H.duplicates.length?'重复：'+H.duplicates.join(', '):'无重复号码'},
  {label:'客队号码',ok:A.duplicates.length===0,meta:A.duplicates.length?'重复：'+A.duplicates.join(', '):'无重复号码'}
 ];
 const ok=checks.every(x=>x.ok),result={ok,checks,home:H,away:A,infoIssues,infoWarnings,signature:setupSignatureRaw()};
 setupLastValidation=result;if(render)renderSetupValidation(result);return result
}
function setupSignatureRaw(){
 stashActiveTeam();
 const teamSig=side=>{const t=teamStore[side]||{roster:[]};return{formation:t.formation,customPositions:t.customPositions||{},roster:(t.roster||[]).map(p=>({id:p.id,name:p.name,number:p.number,squadType:p.squadType||'STARTER',role:p.role,position:p.position,captain:!!p.captain}))}};
 return JSON.stringify({matchConfig:{...matchConfig},competition:q('matchCompetition').value.trim(),home:q('matchHome').value.trim(),away:q('matchAway').value.trim(),HOME:teamSig('HOME'),AWAY:teamSig('AWAY')})
}
function renderSetupValidation(result){
 const w=q('setupChecks');w.innerHTML=result.checks.map(x=>'<div class="setupCheck '+(!x.ok?'bad':(x.warn?'good warn':'good'))+'"><span>'+esc(x.label)+'</span><b>'+(!x.ok?'检查':(x.warn?'提醒':'通过'))+'</b><span style="display:none">'+esc(x.meta)+'</span></div>').join('');
 q('setupSummary').className='setupSummary '+(result.ok?'good':'bad');
 q('setupSummary').textContent=result.ok?((result.infoWarnings&&result.infoWarnings.length)?'赛前检查通过 · '+result.infoWarnings.join('、')+'未填写，不影响比分牌和正式播出。':'赛前检查通过。可以点击 可以播出 解锁正式播出。'):'未通过：'+result.checks.filter(x=>!x.ok).map(x=>x.label+'（'+x.meta+'）').join('；');
 q('setupReadyBtn').disabled=!result.ok;
}
function setMatchReady(on){
 if(on){
   const r=validateMatchSetup(true);if(!r.ok){matchReady=false;refreshSetupReadyUI();note('赛前检查未通过');return false}
   matchReady=true;setupReadySignature=r.signature;note('可以播出 · 已解锁正式播出')
 }else{matchReady=false;setupReadySignature='';note('已解除就绪 · 播出已锁定')}
 refreshSetupReadyUI();return matchReady
}
function requireMatchReady(){
 if(!matchReady){note('请先完成 可以播出');return false}
 const now=setupSignatureRaw();if(now!==setupReadySignature){matchReady=false;setupReadySignature='';validateMatchSetup(true);refreshSetupReadyUI();note('比赛设置已变化 · 就绪状态自动解除');return false}
 const r=validateMatchSetup(false);if(!r.ok){matchReady=false;setupReadySignature='';renderSetupValidation(r);refreshSetupReadyUI();note('赛前检查状态已失效');return false}
 return true
}
function refreshSetupReadyUI(){
 const b=q('setupReadyBadge'),desk=q('setupDesk');b.textContent=matchReady?'可以播出':'NOT READY';b.classList.toggle('ready',matchReady);desk.classList.toggle('ready',matchReady);
 q('goLiveBtn').disabled=!matchReady;q('showPlayBtn').disabled=!matchReady;
 document.querySelectorAll('[data-vd-take]').forEach(x=>x.disabled=!matchReady);q('vdGraphicsIn').disabled=!matchReady;
 q('setupUnlockBtn').disabled=!matchReady;
}
function currentMatchMeta(){
 return{competition:q('matchCompetition').value.trim(),round:q('matchRound').value.trim(),home:q('matchHome').value.trim(),away:q('matchAway').value.trim(),kickoff:q('matchKickoff').value.trim(),venue:q('matchVenue').value.trim()}
}
function parseProjectJson(v){try{return typeof v==='string'?JSON.parse(v):((v&&typeof v==='object')?v:{})}catch(e){return{}}}
function projectMatchMeta(p={}){
 const core=parseProjectJson(p.core),md=parseProjectJson(p.matchday),pkg=core.package||{},top=p.meta||{},saved=md.matchMeta||{};
 return{
  competition:String(top.competition||pkg.competition||saved.competition||md.competition||'').trim(),
  round:String(top.round||pkg.round||saved.round||'').trim(),
  home:String(top.home||pkg.home||saved.home||md.home||'').trim(),
  away:String(top.away||pkg.away||saved.away||md.away||'').trim(),
  kickoff:String(top.kickoff||pkg.kickoff||saved.kickoff||'').trim(),
  venue:String(top.venue||pkg.venue||saved.venue||'').trim()
 }
}
function applyMatchMeta(meta={},overwrite=false){
 const map={competition:'matchCompetition',round:'matchRound',home:'matchHome',away:'matchAway',kickoff:'matchKickoff',venue:'matchVenue'};
 for(const [k,id] of Object.entries(map)){const el=q(id),v=String(meta&&meta[k]||'').trim();if(el&&v&&(overwrite||!String(el.value||'').trim()))el.value=v}
 if(overwrite&&!q('matchCompetition').value.trim())q('matchCompetition').value='SAGI FOOTBALL';
 mdEnforceCanonicalTeams();syncMatchStage();refreshMatchdayUI();refreshUXDashboard()
}
function compactProjectForLocal(p={}){
 const a=p.assets&&typeof p.assets==='object'?p.assets:{};
 return{...p,__compact:true,assets:{...a,photos:{HOME:{},AWAY:{}}}}
}
async function cacheMatchProjectsFull(list=[]){
 const full=(list||[]).filter(p=>p&&p.id&&!p.__compact);if(!full.length)return;
 await dbPutMany(full.map(p=>['matchProject:'+p.id,p]))
}
let matchProjectsCache=null;
function localMatchProjects(){try{const x=JSON.parse(localStorage.getItem(MATCH_PROJECTS_KEY)||'[]');return Array.isArray(x)?x:[]}catch(e){return[]}}
function getMatchProjects(){return Array.isArray(matchProjectsCache)?matchProjectsCache.slice():localMatchProjects()}
async function resolveMatchProject(id){
 const p=getMatchProjects().find(x=>x.id===id);if(!p)return null;
 const full=await dbGet('matchProject:'+id);
 if(full&&typeof full==='object'&&Number(full.savedAt||0)>=Number(p.savedAt||0)){const merged={...p,...full};delete merged.__compact;return merged}
 const fallback={...p};delete fallback.__compact;return fallback
}
function putMatchProjects(list){
 matchProjectsCache=(list||[]).slice(0,20);
 cacheMatchProjectsFull(matchProjectsCache).catch(()=>{});
 try{localStorage.setItem(MATCH_PROJECTS_KEY,JSON.stringify(matchProjectsCache.map(compactProjectForLocal)))}catch(e){}
}
function mergeMatchProjects(a=[],b=[]){
 const map=new Map();[...a,...b].forEach(p=>{if(!p||!p.id)return;const key=String(p.id),old=map.get(key);if(!old||(Number(p.savedAt)||0)>(Number(old.savedAt)||0))map.set(key,p)});
 const byName=new Map();[...map.values()].sort((x,y)=>(Number(y.savedAt)||0)-(Number(x.savedAt)||0)).forEach(p=>{const k=String(p.name||p.id);if(!byName.has(k))byName.set(k,p)});
 return [...byName.values()].slice(0,20)
}
async function persistMatchProjectsBridge(list){
 const projects=(list||[]).slice(0,20);
 try{await lanPost('/api/projects',{projects,savedAt:Date.now(),schema:'SAGI_MATCH_PROJECTS_V1'});return true}catch(e){}
 try{
  let state=await lanJson('/api/matchday?projectSave='+Date.now());if(!state||typeof state!=='object'||Array.isArray(state))state={};
  state.__sagiProjects=projects;await lanPost('/api/matchday',state);return true
 }catch(e){return false}
}
async function syncMatchProjectsFromBridge(){
 const localIndex=localMatchProjects();matchProjectsCache=localIndex.slice();
 const local=await Promise.all(localIndex.map(async p=>(await resolveMatchProject(p.id))||p));let remoteList=[];
 try{
  const remote=await lanJson('/api/projects?ts='+Date.now());remoteList=Array.isArray(remote&&remote.projects)?remote.projects:[]
 }catch(e){
  try{const state=await lanJson('/api/matchday?projectLoad='+Date.now());remoteList=Array.isArray(state&&state.__sagiProjects)?state.__sagiProjects:[]}catch(_){}
 }
 const merged=mergeMatchProjects(remoteList,local);putMatchProjects(merged);refreshProjectList();
 if(merged.length&&(JSON.stringify(merged)!==JSON.stringify(remoteList)))await persistMatchProjectsBridge(merged);
 return merged.length>0||remoteList.length===0
}
function projectAssetsSnapshot(){
 const photos={HOME:{},AWAY:{}};for(const side of ['HOME','AWAY'])for(const p of (teamStore[side]&&teamStore[side].roster||[]))if(p&&p.id&&p.photo)photos[side][p.id]=p.photo;
 return{homeCrest:(teamStore.HOME&&teamStore.HOME.crest)||'',awayCrest:(teamStore.AWAY&&teamStore.AWAY.crest)||'',stadium:assets.bg||'',eventLogo:assets.eventLogo||'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20256%20239%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%2348cf35%22%2F%3E%3Cstop%20offset%3D%22.45%22%20stop-color%3D%22%230a8b4a%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23005432%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Cpath%20d%3D%22M%20133%20184%20L%20133%20213%20L%20134%20214%20L%20134%20222%20L%20135%20223%20L%20136%20231%20L%20137%20232%20L%20144%20232%20L%20164%20226%20L%20165%20224%20L%20162%20219%20L%20142%20199%20Z%20M%20129%20184%20L%20120%20199%20L%20113%20207%20L%20101%20218%20L%2097%20225%20L%20103%20228%20L%20109%20229%20L%20113%20231%20L%20126%20232%20L%20126%20228%20L%20128%20222%20L%20128%20216%20L%20129%20215%20Z%20M%2028%2083%20L%2029%2096%20L%2034%20108%20L%2041%20118%20L%2050%20126%20L%2061%20132%20L%2070%20133%20L%2071%20134%20L%20102%20134%20L%20103%20133%20L%20101%20127%20L%2092%20119%20L%2083%20116%20L%2071%20115%20L%2063%20111%20L%2052%2099%20L%2052%2097%20L%2049%2091%20L%2048%2083%20Z%20M%20234%2082%20L%20214%2082%20L%20214%2087%20L%20211%2097%20L%20203%20108%20L%20196%20113%20L%20194%20113%20L%20191%20115%20L%20178%20116%20L%20168%20120%20L%20161%20127%20L%20159%20133%20L%20196%20133%20L%20203%20131%20L%20212%20126%20L%20222%20117%20L%20227%20110%20L%20233%2096%20L%20233%2093%20L%20234%2092%20Z%20M%20227%2053%20L%20200%2053%20L%20198%2054%20L%20139%20112%20L%20134%20121%20L%20134%20173%20L%20137%20182%20L%20147%20195%20L%20153%20200%20L%20169%20210%20L%20175%20216%20L%20177%20220%20L%20181%20219%20L%20194%20209%20L%20194%20207%20L%20191%20203%20L%20184%20197%20L%20176%20193%20L%20173%20193%20L%20164%20190%20L%20157%20186%20L%20158%20185%20L%20161%20186%20L%20175%20186%20L%20185%20189%20L%20193%20194%20L%20201%20201%20L%20205%20199%20L%20215%20189%20L%20214%20187%20L%20203%20179%20L%20191%20174%20L%20179%20173%20L%20178%20172%20L%20159%20172%20L%20157%20171%20L%20153%20166%20L%20153%20161%20L%20154%20159%20L%20158%20156%20L%20206%20156%20L%20207%20155%20L%20212%20155%20L%20219%20153%20L%20228%20148%20L%20233%20144%20L%20239%20137%20L%20246%20124%20L%20248%20118%20L%20248%20114%20L%20239%20116%20L%20226%20121%20L%20223%20126%20L%20217%20132%20L%20208%20137%20L%20201%20138%20L%20200%20139%20L%20159%20139%20L%20153%20142%20L%20152%20141%20L%20153%20131%20L%20155%20127%20L%20211%2072%20Z%20M%20156%20185%20L%20157%20184%20L%20158%20185%20L%20157%20186%20Z%20M%2035%2053%20L%2038%2058%20L%2048%2069%20L%20107%20127%20L%20109%20131%20L%20109%20134%20L%20110%20135%20L%20110%20140%20L%20109%20141%20L%20104%20139%20L%2062%20139%20L%2061%20138%20L%2054%20137%20L%2045%20132%20L%2039%20126%20L%2036%20121%20L%2014%20114%20L%2014%20117%20L%2017%20126%20L%2023%20137%20L%2032%20147%20L%2042%20153%20L%2048%20155%20L%2053%20155%20L%2054%20156%20L%20104%20156%20L%20109%20160%20L%20110%20163%20L%20109%20167%20L%20103%20172%20L%2087%20172%20L%2086%20173%20L%2076%20173%20L%2075%20174%20L%2072%20174%20L%2056%20181%20L%2048%20188%20L%2048%20189%20L%2061%20201%20L%2068%20195%20L%2080%20188%20L%2087%20187%20L%2088%20186%20L%20102%20186%20L%20103%20187%20L%2098%20190%20L%2080%20196%20L%2068%20207%20L%2069%20210%20L%2085%20221%20L%2086%20218%20L%2091%20212%20L%20113%20197%20L%20120%20190%20L%20126%20180%20L%20128%20174%20L%20128%20167%20L%20129%20166%20L%20129%20125%20L%20128%20124%20L%20128%20121%20L%20126%20116%20L%2064%2054%20L%2061%2053%20Z%20M%20102%20186%20L%20103%20185%20L%20105%20186%20L%20104%20187%20Z%20M%2093%2024%20L%2075%2035%20L%2075%2045%20L%2076%2046%20L%2076%2050%20L%2078%2056%20L%2084%2066%20L%20129%20110%20L%20129%2093%20L%20128%2092%20L%20127%2084%20L%20124%2079%20L%2098%2052%20L%2095%2046%20L%2095%2042%20L%2094%2041%20L%2094%2024%20Z%20M%20169%2023%20L%20168%2023%20L%20168%2043%20L%20165%2051%20L%20159%2059%20L%20138%2079%20L%20135%2084%20L%20134%2092%20L%20133%2093%20L%20133%20110%20L%20178%2066%20L%20185%2054%20L%20186%2047%20L%20187%2046%20L%20187%2034%20Z%20M%20134%205%20L%20133%206%20L%20133%2074%20L%20142%2067%20L%20150%2059%20L%20150%2016%20L%20147%2013%20Z%20M%20128%205%20L%20118%2012%20L%20115%2013%20L%20112%2017%20L%20112%2059%20L%20129%2074%20L%20129%205%20Z%22%20fill%3D%22url(%23g)%22%20fill-rule%3D%22evenodd%22%2F%3E%3C%2Fsvg%3E',photos}
}
async function restoreProjectAssets(a){
 if(!a||typeof a!=='object')return;
 await dbPut('crest:HOME',a.homeCrest||'');await dbPut('crest:AWAY',a.awayCrest||'');await dbPut('stadium',a.stadium||'');await dbPut('eventLogo',a.eventLogo||'');
 const ph=a.photos||{};for(const side of ['HOME','AWAY'])for(const [id,data] of Object.entries(ph[side]||{}))if(id&&data)await dbPut('photo:'+id,data)
}
function refreshProjectList(selected=''){
 const list=getMatchProjects().sort((a,b)=>(b.savedAt||0)-(a.savedAt||0)),el=q('projectSelect');el.innerHTML='<option value="">选择比赛项目</option>'+list.map(p=>'<option value="'+escAttr(p.id)+'">'+esc(p.name)+' · '+new Date(p.savedAt).toLocaleString()+'</option>').join('');if(selected)el.value=selected
}
let projectSaveBusy=false,projectLoadBusy=false;
async function saveMatchProject(){
 if(projectSaveBusy)return;projectSaveBusy=true;const btn=q('projectSaveBtn');if(btn){btn.disabled=true;btn.textContent='保存中…'}
 try{
  const name=q('projectName').value.trim()||setupProjectDefaultName();q('projectName').value=name;await save();mdPersist();vdSave();
  const id='match_'+Date.now().toString(36),project={id,name,savedAt:Date.now(),meta:currentMatchMeta(),core:localStorage.getItem('sagi_player_intro_v40')||'',show:localStorage.getItem('sagi_show_director_v40')||'',matchday:localStorage.getItem('sagi_matchday_graphics_v47')||localStorage.getItem('sagi_matchday_graphics_v42')||'',vmix:localStorage.getItem('sagi_vmix_director_v42')||'',assets:projectAssetsSnapshot()};
  let list=getMatchProjects();const same=list.findIndex(p=>p.name===name);if(same>=0){project.id=list[same].id;list.splice(same,1)}
  await dbPut('matchProject:'+project.id,project);list.unshift(project);putMatchProjects(list);refreshProjectList(project.id);
  note('比赛项目已保存 · '+name+' · 本机已安全落盘');
  persistMatchProjectsBridge(list).then(safe=>{if(!safe)note('Bridge 同步失败 · 本机项目不受影响')}).catch(()=>note('Bridge 同步失败 · 本机项目不受影响'))
 }finally{projectSaveBusy=false;if(btn){btn.disabled=false;btn.textContent='保存比赛项目'}}
}
function portablePlayer(p={},photo=''){
 return{
  id:p.id||uid(),
  name:String(p.name||'PLAYER'),
  number:String(p.number||'00'),
  squadType:String(p.squadType||'SUB').toUpperCase()==='STARTER'?'STARTER':'SUB',
  role:['GK','DF','MF','FW'].includes(String(p.role||'').toUpperCase())?String(p.role).toUpperCase():(riRoleFrom(p.position||p.role)||'MF'),
  position:String(p.position||p.role||'MF'),
  captain:!!p.captain,
  statLabel:p.statLabel||'',
  statValue:p.statValue||'',
  photo:photo||p.photo||'',
  mediaBlob:null,
  mediaObjectUrl:'',
  mediaUrl:p.mediaUrl||'',
  mediaAction:p.mediaAction||'STANDARD',
  directorIn:Number(p.directorIn)||0,
  directorOut:Number(p.directorOut)||0,
  directorSpeed:Number(p.directorSpeed)||1,
  directorFreeze:!!p.directorFreeze,
  directorFreezeMs:Number(p.directorFreezeMs)||1000,
  directorCamera:p.directorCamera||'MEDIUM'
 }
}
async function applyPortableMatchProject(p){
 if(!p||!p.core)throw new Error('项目缺少 core');
 let x;try{x=typeof p.core==='string'?JSON.parse(p.core):p.core}catch(e){throw new Error('比赛数据解析失败')}
 if(!x||!x.teams||!x.teams.HOME||!x.teams.AWAY)throw new Error('比赛项目缺少 HOME/AWAY 名单');
 const ph=(p.assets&&p.assets.photos)||{},homeRaw=Array.isArray(x.teams.HOME.roster)?x.teams.HOME.roster:[],awayRaw=Array.isArray(x.teams.AWAY.roster)?x.teams.AWAY.roster:[];
 applyStoredMatchConfig(x.matchConfig||x.package?.matchFormat||{mode:'11',playerCount:11},true);
 writePackage(x.package||{});
 const homeFormation=x.teams.HOME.formation||defaultFormationForCount(starterLimit()),awayFormation=x.teams.AWAY.formation||defaultFormationForCount(starterLimit());
 const home=homeRaw.map(z=>portablePlayer(z,(ph.HOME||{})[z.id]||'')),away=awayRaw.map(z=>portablePlayer(z,(ph.AWAY||{})[z.id]||''));
 teamStore.HOME={formation:homeFormation,customPositions:x.teams.HOME.customPositions||{},roster:home,crest:(p.assets&&p.assets.homeCrest)||''};
 teamStore.AWAY={formation:awayFormation,customPositions:x.teams.AWAY.customPositions||{},roster:away,crest:(p.assets&&p.assets.awayCrest)||''};
 const assetWrites=[];for(const s of ['HOME','AWAY'])for(const z of teamStore[s].roster)if(z.id&&z.photo)assetWrites.push(['photo:'+z.id,z.photo]);
 assets.bg=(p.assets&&p.assets.stadium)||'';assets.eventLogo=(p.assets&&p.assets.eventLogo)||x.package?.eventLogo||'';
 assetWrites.push(['crest:HOME',teamStore.HOME.crest||''],['crest:AWAY',teamStore.AWAY.crest||''],['stadium',assets.bg||''],['eventLogo',assets.eventLogo||'']);await dbPutMany(assetWrites);
 if(p.show){try{const sh=typeof p.show==='string'?JSON.parse(p.show):p.show;if(Array.isArray(sh)&&sh.length)showSteps=normalizeShowSteps(sh)}catch(e){}}
 activeSide='HOME';roster=teamStore.HOME.roster;selected=roster.length?0:-1;assets.crest=teamStore.HOME.crest||'';assets.photo=selected>=0?(roster[0].photo||''):'';
 refreshFormationOptions(homeFormation);if(q('formation'))q('formation').value=homeFormation;
 refreshSideUI();updateFormatUI();updateFormationEditorUI();renderRoster();renderPreviews();renderShowTimeline();syncMatchStage();renderStage(currentGroup);refreshMatchdayPlayers();
 // Persist the newly applied portable project as the current director state.
 await save();
 return{home:home.length,away:away.length,homeStarters:home.filter(z=>z.squadType==='STARTER').length,awayStarters:away.filter(z=>z.squadType==='STARTER').length}
}
async function loadMatchProject(){
 if(projectLoadBusy)return;const id=q('projectSelect').value;if(!id){note('请选择比赛项目');return}
 projectLoadBusy=true;const btn=q('projectLoadBtn');if(btn){btn.disabled=true;btn.textContent='读取中…'}
 try{
  const p=await resolveMatchProject(id);if(!p)throw new Error('比赛项目不存在或已删除');
  let stats=null;
  if(p.core)stats=await applyPortableMatchProject(p);
  else{if(p.show)localStorage.setItem('sagi_show_director_v40',p.show);await restoreProjectAssets(p.assets);await load()}
  if(p.matchday){localStorage.setItem('sagi_matchday_graphics_v47',p.matchday);localStorage.setItem('sagi_matchday_graphics_v42',p.matchday);await mdLoad({recoverBridge:false})}
  else mdResetForProject();
  applyMatchMeta(projectMatchMeta(p),true);
  if(p.vmix){localStorage.setItem('sagi_vmix_director_v42',p.vmix);vdLoad()}
  q('projectName').value=p.name;matchReady=false;setupReadySignature='';const check=validateMatchSetup(true);refreshSetupReadyUI();refreshUXDashboard();syncMatchStage();refreshMatchdayUI();
  note('比赛项目已读取 · '+p.name+(stats?' · HOME '+stats.home+'人/'+stats.homeStarters+'首发 · AWAY '+stats.away+'人/'+stats.awayStarters+'首发':'')+(check.ok?' · 可进行赛前确认':' · 请检查阵容'))
 }catch(e){recoveryStatus('比赛项目读取失败 · '+(e&&e.message||'未知错误'),true);note('比赛项目读取失败 · '+(e&&e.message||'未知错误'))}
 finally{projectLoadBusy=false;if(btn){btn.disabled=false;btn.textContent='读取项目'}}
}
function phonePrematchDbOpen(){
 return new Promise((resolve,reject)=>{const r=indexedDB.open('sagi_prematch_phone_v1',1);r.onupgradeneeded=()=>{const db=r.result;if(!db.objectStoreNames.contains('packages'))db.createObjectStore('packages')};r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error||new Error('本机赛前数据库打开失败'))})
}
async function phonePrematchDbGet(key){const db=await phonePrematchDbOpen();return new Promise((resolve,reject)=>{const tx=db.transaction('packages','readonly'),r=tx.objectStore('packages').get(key);r.onsuccess=()=>{const v=r.result;db.close();resolve(v)};r.onerror=()=>{db.close();reject(r.error||new Error('本机赛前读取失败'))}})}
async function loadPhonePrematchLocal(){
 try{
  const data=await phonePrematchDbGet('current');if(!data||data.schema!=='sagi.prematch.package.v1'||!data.project)throw new Error('本机还没有保存赛前比赛');
  const p=data.project;let core;try{core=typeof p.core==='string'?JSON.parse(p.core):p.core}catch(e){throw new Error('本机赛前数据损坏')}
  const hc=Array.isArray(core?.teams?.HOME?.roster)?core.teams.HOME.roster.length:0,ac=Array.isArray(core?.teams?.AWAY?.roster)?core.teams.AWAY.roster.length:0;
  if(!hc&&!ac)throw new Error('本机赛前包内没有球员名单');
  const imported={...p,id:String(p.id||('phone_'+Date.now().toString(36))),name:String(p.name||'本机赛前比赛'),savedAt:Number(p.savedAt)||Date.now(),importedFrom:'PHONE_INDEXEDDB'};
  let list=getMatchProjects(),same=list.findIndex(x=>String(x.id)===imported.id||x.name===imported.name);if(same>=0)list.splice(same,1);list.unshift(imported);putMatchProjects(list);refreshProjectList(imported.id);
  await persistMatchProjectsBridge(list).catch(()=>false);
  await loadMatchProject();
  const h=(teamStore.HOME&&teamStore.HOME.roster||[]),a=(teamStore.AWAY&&teamStore.AWAY.roster||[]);
  recoveryStatus('本机赛前已读取 · 主队 '+h.length+' 人 / 首发 '+h.filter(x=>x.squadType==='STARTER').length+' · 客队 '+a.length+' 人 / 首发 '+a.filter(x=>x.squadType==='STARTER').length,true);
  note('本机赛前读取成功')
 }catch(e){recoveryStatus('本机赛前读取失败 · '+(e&&e.message||'未知错误'),true);note('本机赛前读取失败')}
}
async function importPhonePrematchPackage(file){
 if(!file)return;
 try{
  if(file.size>32*1024*1024)throw new Error('赛前包超过32MB，请重新导出较小版本');
  let data=null,backup=null;
  const extName=riExt(file.name||'');
  if(extName==='zip'||file.type==='application/zip'){
   recoveryStatus('正在读取赛前 ZIP…',true);
   await riLoadScript(RI_LIBS.jszip,'JSZip',20000);
   const zip=await JSZip.loadAsync(await file.arrayBuffer()),entries=Object.values(zip.files).filter(x=>!x.dir);
   const main=entries.find(x=>/SAGI_PREMATCH\.json$/i.test(x.name))||entries.find(x=>/\.json$/i.test(x.name));
   const rb=entries.find(x=>/ROSTER_BACKUP\.json$/i.test(x.name));
   if(!main)throw new Error('ZIP 中没有找到 SAGI_PREMATCH.json');
   try{data=JSON.parse(await main.async('string'))}catch(e){throw new Error('ZIP 内赛前数据损坏')}
   if(rb){try{backup=JSON.parse(await rb.async('string'))}catch(_){}}
  }else{
   const raw=await file.text();try{data=JSON.parse(raw)}catch(e){throw new Error('文件不是有效的 SAGI 赛前包')}
  }

  let p=(data&&data.schema==='sagi.prematch.package.v1')?data.project:(data&&data.project&&data.project.core?data.project:data);
  if(!p||typeof p!=='object'||!p.core)throw new Error('赛前包缺少比赛项目数据');

  let core;try{core=typeof p.core==='string'?JSON.parse(p.core):p.core}catch(e){throw new Error('赛前包比赛数据损坏')}
  if(!core.teams||!core.teams.HOME||!core.teams.AWAY)throw new Error('赛前包缺少主客队名单');

  let hc=Array.isArray(core.teams.HOME.roster)?core.teams.HOME.roster.length:0,ac=Array.isArray(core.teams.AWAY.roster)?core.teams.AWAY.roster.length:0;

  // V4.30.8 fallback: recover from ROSTER_BACKUP.json when primary core rosters are empty.
  if((!hc||!ac)&&backup&&backup.teams&&backup.teams.HOME&&backup.teams.AWAY){
    const bh=Array.isArray(backup.teams.HOME.roster)?backup.teams.HOME.roster:[],ba=Array.isArray(backup.teams.AWAY.roster)?backup.teams.AWAY.roster:[];
    if(!hc&&bh.length)core.teams.HOME={...(core.teams.HOME||{}),formation:backup.teams.HOME.formation||core.teams.HOME.formation,roster:bh};
    if(!ac&&ba.length)core.teams.AWAY={...(core.teams.AWAY||{}),formation:backup.teams.AWAY.formation||core.teams.AWAY.formation,roster:ba};
    if(backup.package)core.package={...(core.package||{}),...backup.package};
    if(backup.matchConfig)core.matchConfig=backup.matchConfig;
    const photos={HOME:{},AWAY:{}};for(const s of ['HOME','AWAY'])for(const z of (core.teams[s].roster||[]))if(z&&z.id&&z.photo)photos[s][z.id]=z.photo;
    p={...p,core:JSON.stringify(core),assets:{...(p.assets||{}),homeCrest:backup.teams.HOME.crest||(p.assets&&p.assets.homeCrest)||'',awayCrest:backup.teams.AWAY.crest||(p.assets&&p.assets.awayCrest)||'',photos:{...((p.assets&&p.assets.photos)||{}),HOME:{...(((p.assets&&p.assets.photos)||{}).HOME||{}),...photos.HOME},AWAY:{...(((p.assets&&p.assets.photos)||{}).AWAY||{}),...photos.AWAY}}}};
    hc=core.teams.HOME.roster.length;ac=core.teams.AWAY.roster.length;
  }

  if(!hc&&!ac)throw new Error('赛前包内主客队名单均为空');
  if(!hc||!ac)throw new Error('赛前包只有一支球队名单');

  const imported={...p,id:String(p.id||('phone_'+Date.now().toString(36))),name:String(p.name||'手机赛前比赛'),savedAt:Number(p.savedAt)||Date.now(),importedFrom:extName==='zip'?'PHONE_PREMATCH_ZIP':'PHONE_PREMATCH_FILE'};
  let list=getMatchProjects(),same=list.findIndex(x=>String(x.id)===imported.id||x.name===imported.name);if(same>=0)list.splice(same,1);list.unshift(imported);putMatchProjects(list);refreshProjectList(imported.id);
  await persistMatchProjectsBridge(list).catch(()=>false);
  await loadMatchProject();
  const nowHome=(teamStore.HOME&&teamStore.HOME.roster||[]),nowAway=(teamStore.AWAY&&teamStore.AWAY.roster||[]);
  recoveryStatus('赛前包读取成功 · 主队 '+nowHome.length+' 人 / 首发 '+nowHome.filter(x=>x.squadType==='STARTER').length+' · 客队 '+nowAway.length+' 人 / 首发 '+nowAway.filter(x=>x.squadType==='STARTER').length,true);
  note('赛前包读取成功')
 }catch(e){recoveryStatus('赛前包读取失败 · '+(e&&e.message||'文件错误'),true);note('赛前包读取失败')}
}
async function deleteMatchProject(){
 const id=q('projectSelect').value;if(!id){note('请选择比赛项目');return}let list=getMatchProjects(),p=list.find(x=>x.id===id);list=list.filter(x=>x.id!==id);putMatchProjects(list);refreshProjectList();await dbDel('matchProject:'+id);await persistMatchProjectsBridge(list);note('已删除比赛项目'+(p?' · '+p.name:''))
}
function recoveryStatus(t,on=true){const el=q('projectRecoveryStatus');if(!el)return;el.textContent=t;el.classList.toggle('on',!!on)}
function storageVersionValue(prefix){
 try{
  const keys=[];for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);if(k&&k.startsWith(prefix))keys.push(k)}
  keys.sort((a,b)=>{const av=Number((a.match(/v(\d+)/i)||[])[1])||0,bv=Number((b.match(/v(\d+)/i)||[])[1])||0;return bv-av});
  for(const k of keys){const v=localStorage.getItem(k);if(v)return v}
 }catch(e){}return''
}
function legacySnapshotProject(){
 try{
  const core=storageVersionValue('sagi_player_intro_');if(!core)return null;const x=JSON.parse(core);if(!x||typeof x!=='object')return null;
  const pkg=x.package||{},home=String(pkg.home||pkg.homeTeam||'主队'),away=String(pkg.away||pkg.awayTeam||'客队'),stamp=Date.now();
  let h=2166136261;for(const ch of core.slice(0,4000)){h^=ch.charCodeAt(0);h=Math.imul(h,16777619)}
  return{id:'legacy_'+(h>>>0).toString(36),name:'历史快照 · '+home+' vs '+away,savedAt:stamp-1,core,show:storageVersionValue('sagi_show_director_'),matchday:storageVersionValue('sagi_matchday_graphics_'),vmix:storageVersionValue('sagi_vmix_director_'),recoveredFrom:'LOCAL_LEGACY'}
 }catch(e){return null}
}
function scanLocalLegacyProjects(){
 let out=[];try{
  for(let i=0;i<localStorage.length;i++){
   const k=localStorage.key(i);if(!k||!k.startsWith('sagi_match_projects_'))continue;
   try{const x=JSON.parse(localStorage.getItem(k)||'[]');if(Array.isArray(x))out.push(...x.map(p=>({...p,recoveredFrom:p.recoveredFrom||('LOCAL '+k)})))}catch(_){}
  }
 }catch(e){}
 const snap=legacySnapshotProject();if(snap)out.push(snap);return out
}
async function recoveryFetchJson(url,timeout=650){
 const ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),timeout);
 try{const r=await fetch(url,{cache:'no-store',signal:ctl.signal,mode:'cors'});if(!r.ok)throw new Error('HTTP '+r.status);return await r.json()}finally{clearTimeout(tm)}
}
async function scanLegacyLanPorts(){
 const host=location.hostname;if(!host||location.protocol!=='http:')return[];
 const current=Number(location.port)||80,ports=[8099,8100,8101,8102,8103,8104,8105,8106,8107,8108,8109,8110,8111,8112,8113,8114,8115,8116,8117,8118,8119,8120].filter((v,i,a)=>a.indexOf(v)===i);
 if(!ports.includes(current))ports.unshift(current);
 const jobs=ports.map(async port=>{
  const base='http://'+host+':'+port,out=[];
  try{const x=await recoveryFetchJson(base+'/api/projects?recover='+Date.now());if(Array.isArray(x&&x.projects))out.push(...x.projects.map(p=>({...p,recoveredFrom:p.recoveredFrom||('BRIDGE '+port)})))}catch(e){}
  try{const x=await recoveryFetchJson(base+'/api/matchday?recoverProjects='+Date.now());if(Array.isArray(x&&x.__sagiProjects))out.push(...x.__sagiProjects.map(p=>({...p,recoveredFrom:p.recoveredFrom||('BRIDGE STATE '+port)})))}catch(e){}
  return out
 });
 const all=await Promise.all(jobs);return all.flat()
}
const PREMATCH_CLOUD_URL='https://sagi-cloud-bridge-suny820916.onrender.com/api/prematch';
async function syncPrematchCloud(silent=false){
 const btn=q('projectCloudSyncBtn');if(btn&&!silent){btn.disabled=true;btn.textContent='同步中…'}if(!silent)recoveryStatus('正在连接 SAGI PRE-MATCH 云端…',true);
 const ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),30000);
 try{
  const r=await fetch(PREMATCH_CLOUD_URL+'?t='+Date.now(),{cache:'no-store',signal:ctl.signal});
  const x=await r.json().catch(()=>({}));if(!r.ok||!x.ok)throw new Error(x.error||('HTTP '+r.status));
  const remote=Array.isArray(x.items)?x.items:[],before=getMatchProjects(),merged=mergeMatchProjects(remote,before);
  const beforeMap=new Map(before.map(p=>[String(p.id),Number(p.savedAt)||0]));
  const added=merged.filter(p=>!beforeMap.has(String(p.id))).length;
  const updated=merged.filter(p=>beforeMap.has(String(p.id))&&(Number(p.savedAt)||0)>(beforeMap.get(String(p.id))||0)).length;
  putMatchProjects(merged);refreshProjectList();await persistMatchProjectsBridge(merged);
  const msg='赛前云端已同步 · '+remote.length+' 个云端项目'+(added?' · 新增 '+added:'')+(updated?' · 更新 '+updated:'');
  if(!silent){recoveryStatus(msg,true);note(msg)}else if((added+updated)>0)note('赛前云端自动同步 · '+(added+updated)+' 个项目有变化');
  return true
 }catch(e){if(!silent){recoveryStatus('赛前云端同步失败 · 当前本机项目不受影响。',true);note('赛前云端同步失败')}return false}
 finally{clearTimeout(tm);if(btn&&!silent){btn.disabled=false;btn.textContent='☁ 同步赛前云端'}}
}
async function recoverHistoryProjects(){
 const btn=q('projectRecoverBtn');if(btn){btn.disabled=true;btn.textContent='扫描中…'}recoveryStatus('正在扫描：当前手机旧版本 → Bridge 永久库 → 8099–8120 旧导播端口…',true);
 try{
  const before=getMatchProjects(),local=scanLocalLegacyProjects(),lan=await scanLegacyLanPorts(),merged=mergeMatchProjects(before,mergeMatchProjects(local,lan));
  const oldIds=new Set(before.map(p=>String(p.id))),added=merged.filter(p=>!oldIds.has(String(p.id))).length;
  putMatchProjects(merged);refreshProjectList();const saved=await persistMatchProjectsBridge(merged);
  if(added>0){recoveryStatus('找回完成：新增 '+added+' 个历史比赛，共 '+merged.length+' 个项目'+(saved?'，已写入导播电脑永久库。':'。'));note('已找回 '+added+' 个历史比赛')}
  else if(merged.length>before.length){recoveryStatus('找回完成：已合并历史记录，共 '+merged.length+' 个项目。');note('历史比赛已合并')}
  else recoveryStatus('扫描完成：没有发现新的历史项目。若旧导播 IP 已变化，Safari 无法跨旧 IP 直接读取原浏览器存储；以后新保存的比赛不会再受地址变化影响。',true)
 }catch(e){recoveryStatus('历史找回未完成 · 当前项目没有被修改。',true);note('历史比赛找回失败')}
 finally{if(btn){btn.disabled=false;btn.textContent='↻ 找回历史比赛'}}
}
function initMatchSetup(){
 q('projectName').value=setupProjectDefaultName();refreshProjectList();q('projectSaveBtn').onclick=saveMatchProject;q('projectLoadBtn').onclick=loadMatchProject;q('projectDeleteBtn').onclick=deleteMatchProject;q('projectRecoverBtn').onclick=recoverHistoryProjects;q('projectCloudSyncBtn').onclick=()=>syncPrematchCloud(false);q('projectPhoneImportFile').onchange=async e=>{const f=e.target.files&&e.target.files[0];if(f)await importPhonePrematchPackage(f);e.target.value=''};
 q('setupValidateBtn').onclick=()=>validateMatchSetup(true);q('setupReadyBtn').onclick=()=>setMatchReady(true);q('setupUnlockBtn').onclick=()=>setMatchReady(false);
 validateMatchSetup(true);refreshSetupReadyUI();syncMatchProjectsFromBridge().catch(()=>{});
 const startCloud=()=>syncPrematchCloud(true).catch(()=>{});if('requestIdleCallback' in window)requestIdleCallback(startCloud,{timeout:6000});else setTimeout(startCloud,4500)
}

const DEFAULT_SHOW=[
 {id:'sting',group:'STING',label:'赛事标识',duration:2000,transition:'FLASH',cue:'STING',enabled:true},
 {id:'match',group:'MATCH',label:'比赛信息',duration:3000,transition:'FADE',cue:'RISER',enabled:true},
 {id:'countdown',group:'COUNTDOWN',label:'开场倒计时',duration:5000,transition:'ZOOM',cue:'HIT',enabled:true},
 {id:'home_team',side:'HOME',group:'TEAM',label:'主队开场',duration:2500,transition:'FADE',cue:'RISER',enabled:true},
 {id:'home_gk',side:'HOME',group:'GK',label:'主队门将',duration:3000,transition:'ZOOM',cue:'HIT',enabled:true},
 {id:'home_df',side:'HOME',group:'DF',label:'主队后卫',duration:4000,transition:'SLIDE',cue:'WHOOSH',enabled:true},
 {id:'home_mf',side:'HOME',group:'MF',label:'主队中场',duration:4000,transition:'SLIDE',cue:'WHOOSH',enabled:true},
 {id:'home_fw',side:'HOME',group:'FW',label:'主队前锋',duration:4000,transition:'FLASH',cue:'HIT',enabled:true},
 {id:'home_full',side:'HOME',group:'FULL',label:'主队完整首发',duration:6000,transition:'ZOOM',cue:'CROWD',enabled:true},
 {id:'home_sub',side:'HOME',group:'SUB',label:'主队替补名单',duration:5000,transition:'SLIDE',cue:'WHOOSH',enabled:true},
 {id:'away_team',side:'AWAY',group:'TEAM',label:'客队开场',duration:2500,transition:'FADE',cue:'RISER',enabled:true},
 {id:'away_gk',side:'AWAY',group:'GK',label:'客队门将',duration:3000,transition:'ZOOM',cue:'HIT',enabled:true},
 {id:'away_df',side:'AWAY',group:'DF',label:'客队后卫',duration:4000,transition:'SLIDE',cue:'WHOOSH',enabled:true},
 {id:'away_mf',side:'AWAY',group:'MF',label:'客队中场',duration:4000,transition:'SLIDE',cue:'WHOOSH',enabled:true},
 {id:'away_fw',side:'AWAY',group:'FW',label:'客队前锋',duration:4000,transition:'FLASH',cue:'HIT',enabled:true},
 {id:'away_full',side:'AWAY',group:'FULL',label:'客队完整首发',duration:6000,transition:'ZOOM',cue:'CROWD',enabled:true},
 {id:'away_sub',side:'AWAY',group:'SUB',label:'客队替补名单',duration:5000,transition:'SLIDE',cue:'WHOOSH',enabled:true}
];
let showSteps=DEFAULT_SHOW.map(x=>({...x})),showIndex=-1,showStartedAt=0,showSession='',showTimer=null,showHoldElapsed=0;
let broadcastHold=false,broadcastPreview={group:'TEAM',side:'HOME',label:'主队开场',duration:2500},broadcastProgram=null,broadcastManualIndex=3;
const BROADCAST_MANUAL=[
 {group:'STING',side:'HOME',label:'赛事Logo',duration:2000},
 {group:'MATCH',side:'HOME',label:'比赛信息',duration:3000},
 {group:'COUNTDOWN',side:'HOME',label:'开场倒计时',duration:5000},
 {group:'TEAM',side:'HOME',label:'主队开场',duration:2500},
 {group:'GK',side:'HOME',label:'主队门将',duration:3000},
 {group:'DF',side:'HOME',label:'主队后卫',duration:4000},
 {group:'MF',side:'HOME',label:'主队中场',duration:4000},
 {group:'FW',side:'HOME',label:'主队前锋',duration:4000},
 {group:'FULL',side:'HOME',label:'主队首发',duration:6000},
 {group:'SUB',side:'HOME',label:'主队替补',duration:5000},
 {group:'TEAM',side:'AWAY',label:'客队开场',duration:2500},
 {group:'GK',side:'AWAY',label:'客队门将',duration:3000},
 {group:'DF',side:'AWAY',label:'客队后卫',duration:4000},
 {group:'MF',side:'AWAY',label:'客队中场',duration:4000},
 {group:'FW',side:'AWAY',label:'客队前锋',duration:4000},
 {group:'FULL',side:'AWAY',label:'客队首发',duration:6000},
 {group:'SUB',side:'AWAY',label:'客队替补',duration:5000}
];


let matchdayState={homeScore:0,awayScore:0,scoreboardVisible:false,scoreboardFrozen:false,period:'1H',clockBase:0,clockRunning:false,clockStartedAt:0,lastEvent:null,eventLog:[],replayMarkers:[],homeColor:'#d8b55b',awayColor:'#4c7dff',accentColor:'#f4f0e8',homeShort:'',awayShort:'',scoreHomeName:'',scoreAwayName:'',scoreNameFixture:'',homeRedCards:0,awayRedCards:0,homePen:0,awayPen:0,penaltyShootout:{started:false,rounds:5,firstSide:'HOME',history:[],winner:'',finished:false},simplePenalty:{visible:false,home:0,away:0,history:[],slots:5},stoppageTime:'',scoreTheme:'sagi-pro',overlayVisible:false};
let technicalReady=false,matchModeActive=false,matchOperatorRole='FULL',mdMacroTimer=null,mdMacroSeq=0;
let graphicsDirectorSettings={enabled:true,autoReplay:false,replayHold:3500,returnSlot:'cam1'},gdTimers=[],gdCameraTimers=[],gdSequence=0,gdAutoCameraActive=false;
let smartDirectorSettings={enabled:true,autoTake:false},smartCue={slot:'cam1',title:'保持主机位',reason:'等待比赛事件',confidence:70,eventType:'IDLE'};
let shotSafetySettings={enabled:true,minShotMs:3000,cooldownMs:2000,bounceMs:6000,attackLockMs:12000},shotSafetyState={currentSlot:'',previousSlot:'',lastSwitchAt:0,lastAutoSwitchAt:0,attackLockUntil:0,lastBlock:'',switchCount:0};
function mdPeriodName(p){return({'1H':'上半场','2H':'下半场','ET1':'加时上半场','ET2':'加时下半场','PEN':'点球大战'})[p]||p}
function mdNormalizeMatchMode(){
 let period=String(matchdayState.period||'1H');
 const simple=matchdayState.simplePenalty&&typeof matchdayState.simplePenalty==='object'?matchdayState.simplePenalty:(matchdayState.simplePenalty={});
 const pen=matchdayState.penaltyShootout&&typeof matchdayState.penaltyShootout==='object'?matchdayState.penaltyShootout:(matchdayState.penaltyShootout={});
 const penHistory=Array.isArray(pen.history)?pen.history:[],simpleHistory=Array.isArray(simple.history)?simple.history:[];
 const realPenalty=!!pen.started||!!simple.visible||penHistory.length>0||simpleHistory.length>0;
 if(period==='PEN'&&!realPenalty){period='2H';matchdayState.period='2H'}
 if(period!=='PEN'){
  simple.visible=false;pen.started=false;pen.finished=false;pen.winner='';
  matchdayState.homePen=0;matchdayState.awayPen=0
 }
}
function mdSimplePenaltyState(){
 let p=matchdayState.simplePenalty;if(!p||typeof p!=='object')p={};
 p.visible=!!p.visible;p.home=Math.max(0,Number(p.home)||0);p.away=Math.max(0,Number(p.away)||0);p.slots=Math.max(5,Number(p.slots)||5);if(!Array.isArray(p.history))p.history=[];
 matchdayState.simplePenalty=p;return p
}
function mdSimplePenaltyTeamAttempts(side){
 const p=mdSimplePenaltyState();return (p.history||[]).map(x=>typeof x==='string'?{side:x,result:'GOAL'}:x).filter(x=>x&&x.side===side)
}
function mdSimplePenaltyRound(){
 const h=mdSimplePenaltyTeamAttempts('HOME').length,a=mdSimplePenaltyTeamAttempts('AWAY').length;return Math.max(h,a)
}
function mdSimplePenaltyDots(side){
 const attempts=mdSimplePenaltyTeamAttempts(side),round=mdSimplePenaltyRound(),visible=round<=5?attempts.slice(0,5):attempts.slice(-5),pad=Math.max(0,5-visible.length);
 const items=visible.map(x=>'<i class="spControlDot'+(x.result==='MISS'?' miss':' on')+'"></i>');
 for(let i=0;i<pad;i++)items.push('<i class="spControlDot"></i>');return items.join('')
}
function mdSimplePenaltySnapshot(){
 const p=mdSimplePenaltyState(),history=(p.history||[]).map(x=>typeof x==='string'?{side:x,result:'GOAL'}:x).filter(Boolean),round=mdSimplePenaltyRound();return{visible:!!p.visible,home:p.home,away:p.away,history,round,suddenDeath:round>5,slots:Math.max(5,p.slots,mdSimplePenaltyTeamAttempts('HOME').length,mdSimplePenaltyTeamAttempts('AWAY').length)}
}
function mdSyncDirectorPenaltyToSimple(reset=false){
 const simple=mdSimplePenaltyState();
 if(reset){
  simple.visible=false;simple.home=0;simple.away=0;simple.history=[];simple.slots=5;mdRenderSimplePenalty();return
 }
 const p=mdPenaltyState(),st=mdPenaltyStats();
 simple.visible=!!p.started;
 simple.home=st.homeGoals;simple.away=st.awayGoals;
 simple.history=(p.history||[]).map(x=>({side:x.side==='AWAY'?'AWAY':'HOME',result:x.result==='MISS'?'MISS':'GOAL',at:x.at||new Date().toISOString()}));
 simple.slots=Math.max(5,st.homeAttempts,st.awayAttempts);
 mdRenderSimplePenalty();
}
function mdRenderSimplePenalty(){
 const p=mdSimplePenaltyState(),director=mdPenaltyState(),home=q('matchHome').value.trim()||'主队',away=q('matchAway').value.trim()||'客队';
 const set=(id,val)=>{const e=q(id);if(e)e.textContent=val};
 const round=mdSimplePenaltyRound(),next=director.started&&!director.finished?mdPenaltyNextSide():'';
 set('spHomeName',home);set('spAwayName',away);set('spHomeScore',p.home);set('spAwayScore',p.away);set('spVisibleState',p.visible?(round>5?'突然死亡 · 第'+round+'轮':'直播中 · 第'+Math.max(1,round)+'轮'):'当前隐藏');
 if(q('spHomeDots'))q('spHomeDots').innerHTML=mdSimplePenaltyDots('HOME');if(q('spAwayDots'))q('spAwayDots').innerHTML=mdSimplePenaltyDots('AWAY');
 if(q('spToggle'))q('spToggle').textContent=p.visible?'隐藏点球记分牌':'显示点球记分牌';if(q('spUndo'))q('spUndo').disabled=!director.history.length;
 const active=director.started&&!director.finished;[['spHomePlus','HOME'],['spHomeMiss','HOME'],['spAwayPlus','AWAY'],['spAwayMiss','AWAY']].forEach(([id,side])=>{if(q(id))q(id).disabled=active&&next!==side})
}
function mdSimplePenaltyEnsureOverlay(){
 const p=mdSimplePenaltyState();p.visible=true;matchdayState.period='PEN';matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;
 if(!matchdayState.overlayVisible&&matchReady){vdSave();matchdayState.overlayVisible=true;publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'点球比分牌开启')}
}
async function mdSimplePenaltyKick(side,result='GOAL'){
 const cleanSide=side==='AWAY'?'AWAY':'HOME',cleanResult=result==='MISS'?'MISS':'GOAL',director=mdPenaltyState();
 mdSimplePenaltyEnsureOverlay();
 if(!director.started){
  director.started=true;director.finished=false;director.winner='';director.rounds=[3,5].includes(Number(director.rounds))?Number(director.rounds):5;
  if(!director.history.length)director.firstSide=cleanSide
 }
 if(director.finished){note('点球大战已经结束');return false}
 const next=mdPenaltyNextSide();if(cleanSide!==next){note('当前应由 '+(next==='HOME'?'主队':'客队')+' 主罚');mdRenderSimplePenalty();return false}
 director.history.push({side:cleanSide,result:cleanResult,at:new Date().toISOString()});const winner=mdPenaltyEvaluateWinner();
 mdSyncDirectorPenaltyToSimple();mdRenderPenaltyDirector();await publishMatchday(null);
 if(winner)note('点球大战结束 · '+(winner==='HOME'?(q('matchHome').value||'主队'):(q('matchAway').value||'客队'))+' 获胜');return true
}
async function mdSimplePenaltyAdd(side){return mdSimplePenaltyKick(side,'GOAL')}
async function mdSimplePenaltyMiss(side){return mdSimplePenaltyKick(side,'MISS')}
async function mdSimplePenaltyToggle(){
 const simple=mdSimplePenaltyState(),director=mdPenaltyState(),show=!simple.visible;
 if(show){
  if(!director.started){director.started=true;director.finished=false;director.winner='';if(!director.history.length)director.firstSide=(q('mdPenFirst')&&q('mdPenFirst').value)==='AWAY'?'AWAY':'HOME'}
  matchdayState.period='PEN';matchdayState.clockBase=mdNowSeconds();matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;matchdayState.scoreboardVisible=true;
  mdSyncDirectorPenaltyToSimple();mdSimplePenaltyState().visible=true;
  if(!matchdayState.overlayVisible&&matchReady){vdSave();matchdayState.overlayVisible=true;publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'点球比分牌开启')}
 }else{
  simple.visible=false
 }
 mdRenderSimplePenalty();mdRenderPenaltyDirector();refreshMatchdayUI();await publishMatchday(null)
}
async function mdSimplePenaltyUndo(){return mdPenaltyUndo()}
async function mdSimplePenaltyReset(){return mdPenaltyReset()}
function mdPenaltyState(){
 let p=matchdayState.penaltyShootout;if(!p||typeof p!=='object')p={};
 if(!Array.isArray(p.history))p.history=[];
 p.rounds=[3,5].includes(Number(p.rounds))?Number(p.rounds):5;
 p.firstSide=p.firstSide==='AWAY'?'AWAY':'HOME';p.started=!!p.started;p.winner=p.winner==='AWAY'?'AWAY':p.winner==='HOME'?'HOME':'';p.finished=!!p.finished;matchdayState.penaltyShootout=p;return p
}
function mdPenaltyStats(){
 const p=mdPenaltyState(),h=p.history||[],home=h.filter(x=>x.side==='HOME'),away=h.filter(x=>x.side==='AWAY');
 return{homeAttempts:home.length,awayAttempts:away.length,homeGoals:home.filter(x=>x.result==='GOAL').length,awayGoals:away.filter(x=>x.result==='GOAL').length}
}
function mdPenaltyNextSide(){
 const p=mdPenaltyState();if(p.finished)return'';const n=p.history.length;return n%2===0?p.firstSide:(p.firstSide==='HOME'?'AWAY':'HOME')
}
function mdPenaltyCurrentRound(){const st=mdPenaltyStats();return Math.min(st.homeAttempts,st.awayAttempts)+1}
function mdPenaltySuddenDeath(){
 const p=mdPenaltyState(),st=mdPenaltyStats(),r=p.rounds;return Math.min(st.homeAttempts,st.awayAttempts)>=r||Math.max(st.homeAttempts,st.awayAttempts)>r
}
function mdPenaltyEvaluateWinner(){
 const p=mdPenaltyState(),st=mdPenaltyStats(),r=p.rounds;let winner='';
 if(st.homeAttempts<=r&&st.awayAttempts<=r){
  const remH=Math.max(0,r-st.homeAttempts),remA=Math.max(0,r-st.awayAttempts);
  if(st.homeGoals>st.awayGoals+remA)winner='HOME';
  else if(st.awayGoals>st.homeGoals+remH)winner='AWAY'
 }
 if(!winner&&st.homeAttempts===st.awayAttempts&&st.homeAttempts>=r&&st.homeGoals!==st.awayGoals)winner=st.homeGoals>st.awayGoals?'HOME':'AWAY';
 p.winner=winner;p.finished=!!winner;matchdayState.homePen=st.homeGoals;matchdayState.awayPen=st.awayGoals;return winner
}
function mdPenaltyDots(side,compact=false){
 const p=mdPenaltyState(),h=p.history.filter(x=>x.side===side),r=p.rounds,total=Math.max(r,h.length+(p.finished?0:1)),next=mdPenaltyNextSide(),st=mdPenaltyStats(),attempts=side==='HOME'?st.homeAttempts:st.awayAttempts;
 return Array.from({length:Math.min(12,total)},(_,i)=>{const x=h[i],cls=x?(x.result==='GOAL'?'goal':'miss'):'pending'+((side===next&&i===attempts)?' current':'');return'<i class="penDot '+cls+'"></i>'}).join('')
}
function mdPenaltyStatus(){
 const p=mdPenaltyState(),st=mdPenaltyStats(),home=q('matchHome').value.trim()||'主队',away=q('matchAway').value.trim()||'客队';
 if(p.finished)return{stage:'点球大战结束',next:(p.winner==='HOME'?home:away)+' 获胜',winner:p.winner};
 if(!p.started)return{stage:'等待开始',next:'常规比分保持不变',winner:''};
 const sudden=mdPenaltySuddenDeath(),round=mdPenaltyCurrentRound(),next=mdPenaltyNextSide(),name=next==='HOME'?home:away;
 return{stage:sudden?'突然死亡':'第 '+round+' 轮',next:'当前主罚 · '+name,winner:''}
}
function mdPenaltySnapshot(){
 const p=mdPenaltyState(),st=mdPenaltyStats(),status=mdPenaltyStatus();
 return{started:p.started,rounds:p.rounds,firstSide:p.firstSide,history:(p.history||[]).slice(0,24),winner:p.winner||'',finished:!!p.finished,nextSide:mdPenaltyNextSide(),currentRound:mdPenaltyCurrentRound(),suddenDeath:mdPenaltySuddenDeath(),homeAttempts:st.homeAttempts,awayAttempts:st.awayAttempts,homeGoals:st.homeGoals,awayGoals:st.awayGoals,status:status.stage}
}
function mdRenderPenaltyDirector(){
 const p=mdPenaltyState(),st=mdPenaltyStats(),status=mdPenaltyStatus(),next=mdPenaltyNextSide(),home=q('matchHome').value.trim()||'主队',away=q('matchAway').value.trim()||'客队';
 const set=(id,val)=>{const e=q(id);if(e)e.textContent=val};
 set('mdPenHomeName',home);set('mdPenAwayName',away);set('mdPenHomeScore',st.homeGoals);set('mdPenAwayScore',st.awayGoals);set('mdPenStage',status.stage);set('mdPenNext',status.next);
 set('mmPenHomeName',home);set('mmPenAwayName',away);set('mmPenHomeScore',st.homeGoals);set('mmPenAwayScore',st.awayGoals);set('mmPenStage',status.stage);set('mmPenNext',status.next);
 ['mdPenHomeDots','mmPenHomeDots'].forEach(id=>{if(q(id))q(id).innerHTML=mdPenaltyDots('HOME',id.startsWith('mm'))});['mdPenAwayDots','mmPenAwayDots'].forEach(id=>{if(q(id))q(id).innerHTML=mdPenaltyDots('AWAY',id.startsWith('mm'))});
 if(q('mdPenRounds')){q('mdPenRounds').value=String(p.rounds);q('mdPenRounds').disabled=p.started&&p.history.length>0}
 if(q('mdPenFirst')){q('mdPenFirst').value=p.firstSide;q('mdPenFirst').disabled=p.started&&p.history.length>0}
 const active=p.started&&!p.finished;[['mdPenHomeGoal','HOME'],['mdPenHomeMiss','HOME'],['mdPenAwayGoal','AWAY'],['mdPenAwayMiss','AWAY']].forEach(([id,side])=>{if(q(id))q(id).disabled=!active||next!==side});
 if(q('mmPenGoal'))q('mmPenGoal').disabled=!active;if(q('mmPenMiss'))q('mmPenMiss').disabled=!active;if(q('mdPenUndo'))q('mdPenUndo').disabled=!p.history.length;if(q('mmPenUndo'))q('mmPenUndo').disabled=!p.history.length;
 if(q('mdPenStart')){q('mdPenStart').textContent=p.started?(p.finished?'点球大战已结束':'点球大战进行中'):'开始点球大战';q('mdPenStart').disabled=!!p.started}
 if(q('mmPenStart')){q('mmPenStart').textContent=p.started?(p.finished?'已结束':'进行中'):'开始点球大战';q('mmPenStart').disabled=!!p.started}
 const hint=q('mdPenHint');if(hint){hint.textContent=p.finished?status.next+' · 常规比分 '+matchdayState.homeScore+'-'+matchdayState.awayScore+' · 点球 '+st.homeGoals+'-'+st.awayGoals:(p.started?(mdPenaltySuddenDeath()?'已进入突然死亡 · 双方必须完成同轮后才能判胜':'系统自动轮换主罚方并判断是否提前结束'):'进入后常规比分不会被点球比分覆盖。');hint.classList.toggle('finished',p.finished)}
}
async function mdPenaltyStart(){
 const p=mdPenaltyState();if(p.finished&&p.history.length){note('点球大战已经结束 · 如需重来请先重置');return}if(p.started&&!p.finished){mdSyncDirectorPenaltyToSimple();await publishMatchday(null);note('点球大战正在进行 · 已重新同步直播点球牌');return}if(!p.history.length){p.rounds=Number(q('mdPenRounds')&&q('mdPenRounds').value)||p.rounds;p.firstSide=(q('mdPenFirst')&&q('mdPenFirst').value)==='AWAY'?'AWAY':'HOME'}
 p.started=true;p.finished=false;p.winner='';matchdayState.period='PEN';matchdayState.clockBase=mdNowSeconds();matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;matchdayState.scoreboardVisible=true;mdPenaltyEvaluateWinner();mdSyncDirectorPenaltyToSimple();mdRenderPenaltyDirector();
 await refreshGraphicsBrowser(false);await sagiDelay(500);await publishMatchday(null);note('点球大战已开始 · 世界杯级点球牌已同步')
}
async function mdPenaltyKick(side,result){
 const p=mdPenaltyState();if(!p.started)await mdPenaltyStart();if(p.finished){note('点球大战已经结束');return}
 const next=mdPenaltyNextSide();if(side!==next){note('当前应由 '+(next==='HOME'?'主队':'客队')+' 主罚');return}
 p.history.push({side,result:result==='MISS'?'MISS':'GOAL',at:new Date().toISOString()});const winner=mdPenaltyEvaluateWinner();mdSyncDirectorPenaltyToSimple();mdRenderPenaltyDirector();await publishMatchday(null);
 if(winner)note('点球大战结束 · '+(winner==='HOME'?(q('matchHome').value||'主队'):(q('matchAway').value||'客队'))+' 获胜')
}
async function mdPenaltyUndo(){
 const p=mdPenaltyState();if(!p.history.length){note('没有可撤销的点球');return}p.history.pop();p.finished=false;p.winner='';mdPenaltyEvaluateWinner();mdSyncDirectorPenaltyToSimple();mdRenderPenaltyDirector();await publishMatchday(null);note('已撤销上一罚 · 直播点球牌已同步')
}
async function mdPenaltyReset(){
 matchdayState.penaltyShootout={started:false,rounds:Number(q('mdPenRounds')&&q('mdPenRounds').value)||5,firstSide:(q('mdPenFirst')&&q('mdPenFirst').value)==='AWAY'?'AWAY':'HOME',history:[],winner:'',finished:false};matchdayState.homePen=0;matchdayState.awayPen=0;mdSyncDirectorPenaltyToSimple(true);if(matchdayState.period==='PEN')matchdayState.period='2H';mdRenderPenaltyDirector();await publishMatchday(null);note('点球大战已重置 · 常规比分未改变')
}
function mdNowSeconds(){return Math.max(0,matchdayState.clockBase+(matchdayState.clockRunning?((Date.now()-matchdayState.clockStartedAt)/1000):0))}
function mdFormat(sec){sec=Math.max(0,Math.floor(Number(sec)||0));return String(Math.floor(sec/60)).padStart(2,'0')+':'+String(sec%60).padStart(2,'0')}
function mdParse(s){const m=String(s||'').trim().match(/^(\d{1,3})(?::(\d{1,2}))?$/);if(!m)return null;return Math.max(0,(+m[1])*60+(+(m[2]||0)))}
function mdRoster(side){stashActiveTeam();return (teamStore[side]&&teamStore[side].roster||[]).slice()}
function mdPlayer(side,id){return mdRoster(side).find(p=>p.id===id)||null}
function mdFillSelect(id,side,placeholder){
 const el=q(id);if(!el)return;const old=el.value,arr=mdRoster(side);el.innerHTML='<option value="">'+placeholder+'</option>'+arr.map(p=>'<option value="'+esc(p.id)+'">#'+esc(p.number)+' · '+esc(p.name)+' · '+esc(p.squadType==='SUB'?'替补':p.position||p.role)+'</option>').join('');if(arr.some(p=>p.id===old))el.value=old;
}
function refreshMatchdayPlayers(){
 mdFillSelect('mdEventPlayer',q('mdEventSide').value,'选择球员');
 mdFillSelect('mdSubOff',q('mdSubSide').value,'换下球员');
 mdFillSelect('mdSubOn',q('mdSubSide').value,'换上球员');
 mdFillSelect('mdMvpPlayer',q('mdMvpSide').value,'选择本场最佳球员');
 if(q('mmEventPlayer'))mdFillSelect('mmEventPlayer',q('mmEventSide').value,'球员可选');
 if(q('mmSubSide')){mdFillSelect('mmSubOff',q('mmSubSide').value,'换下');mdFillSelect('mmSubOn',q('mmSubSide').value,'换上')}
}
function mdShortAuto(name,fallback){
 const x=String(name||'').trim();if(!x)return fallback;
 if(/[\u3400-\u9fff]/.test(x)){
  const clean=x.replace(/足球俱乐部|足球队|俱乐部|青年足球|足球/gi,'').replace(/\s+/g,'').trim()||x.replace(/\s+/g,'');
  return clean.length<=6?clean:clean.slice(0,6)
 }
 const parts=x.split(/\s+/).filter(Boolean);
 if(parts.length>1){const initials=parts.map(p=>p[0]).join('').replace(/[^A-Za-z0-9]/g,'').toUpperCase();if(initials)return initials.slice(0,5)}
 return x.replace(/\s+/g,'').slice(0,7).toUpperCase()
}
function mdCanonicalTeams(){return{home:String(q('matchHome')&&q('matchHome').value||'').trim()||'主队',away:String(q('matchAway')&&q('matchAway').value||'').trim()||'客队'}}
function mdFixtureKey(){const t=mdCanonicalTeams(),competition=String(q('matchCompetition')&&q('matchCompetition').value||'').trim();return[competition,t.home,t.away].map(mdIdentityNorm).join('|')}
function mdEnforceCanonicalTeams(){
 const t=mdCanonicalTeams();matchdayState.homeShort=t.home;matchdayState.awayShort=t.away;
 const scoreKey=[t.home,t.away].map(mdIdentityNorm).join('|');
 if(matchdayState.scoreNameFixture!==scoreKey){
  matchdayState.scoreHomeName=mdShortAuto(t.home,'主队');matchdayState.scoreAwayName=mdShortAuto(t.away,'客队');matchdayState.scoreNameFixture=scoreKey
 }
 if(!String(matchdayState.scoreHomeName||'').trim())matchdayState.scoreHomeName=mdShortAuto(t.home,'主队');
 if(!String(matchdayState.scoreAwayName||'').trim())matchdayState.scoreAwayName=mdShortAuto(t.away,'客队');
 if(q('mdHomeShort')&&document.activeElement!==q('mdHomeShort'))q('mdHomeShort').value=matchdayState.scoreHomeName;
 if(q('mdAwayShort')&&document.activeElement!==q('mdAwayShort'))q('mdAwayShort').value=matchdayState.scoreAwayName;
 return t
}

function refreshMatchdayClockUI(){
 const clockText=mdFormat(mdNowSeconds());if(q('mdClock'))q('mdClock').textContent=clockText;if(q('mmClock'))q('mmClock').textContent=clockText
}
function refreshMatchdayUI(){
 const canonical=mdEnforceCanonicalTeams(),homeName=canonical.home,awayName=canonical.away;refreshMatchdayClockUI();
 q('mdHomeName').textContent=homeName;q('mdAwayName').textContent=awayName;
 q('mdHomeScore').textContent=matchdayState.homeScore;q('mdAwayScore').textContent=matchdayState.awayScore;
 q('mdPeriod').value=matchdayState.period;q('mdPeriodLabel').textContent=mdPeriodName(matchdayState.period);
 if(q('mdHomeColor'))q('mdHomeColor').value=matchdayState.homeColor||'#d8b55b';
 if(q('mdAwayColor'))q('mdAwayColor').value=matchdayState.awayColor||'#4c7dff';
 if(q('mdAccentColor'))q('mdAccentColor').value=matchdayState.accentColor||'#f4f0e8';
 if(q('mdHomeShort'))q('mdHomeShort').value=matchdayState.scoreHomeName||mdShortAuto(homeName,'主队');
 if(q('mdAwayShort'))q('mdAwayShort').value=matchdayState.scoreAwayName||mdShortAuto(awayName,'客队');
 if(q('mdScoreTheme'))q('mdScoreTheme').value=matchdayState.scoreTheme||'sagi-pro';
 if(q('mdStoppage'))q('mdStoppage').value=matchdayState.stoppageTime||'';
 if(q('mdHomeRed'))q('mdHomeRed').value=Number(matchdayState.homeRedCards)||0;
 if(q('mdAwayRed'))q('mdAwayRed').value=Number(matchdayState.awayRedCards)||0;
 if(q('mdHomePen'))q('mdHomePen').value=Number(matchdayState.homePen)||0;
 if(q('mdAwayPen'))q('mdAwayPen').value=Number(matchdayState.awayPen)||0;
 q('mdScoreboardShow').classList.toggle('primary',matchdayState.scoreboardVisible);
 const syncDot=q('mdSyncDot');if(syncDot)syncDot.classList.toggle('on',matchdayState.scoreboardVisible||!!matchdayState.lastEvent);

 if(q('mmHomeName'))q('mmHomeName').textContent=homeName;
 if(q('mmAwayName'))q('mmAwayName').textContent=awayName;
 if(q('mmHomeScore'))q('mmHomeScore').textContent=matchdayState.homeScore;
 if(q('mmAwayScore'))q('mmAwayScore').textContent=matchdayState.awayScore;
 if(q('mmPeriod'))q('mmPeriod').textContent=mdPeriodName(matchdayState.period)+(matchdayState.stoppageTime?' · '+matchdayState.stoppageTime:'');
 if(q('mmScoreboardToggle'))q('mmScoreboardToggle').textContent=matchdayState.scoreboardVisible?'隐藏比分牌':'显示比分牌';
 if(q('mmFreeze'))q('mmFreeze').textContent=matchdayState.scoreboardFrozen?'解除比分冻结':'冻结比分牌';
 mdRenderMarkers();mdRenderSimplePenalty();mdRenderPenaltyDirector();applyOperatorRole(matchOperatorRole,false);
}
function mdPersist(){
 try{
  mdEnforceCanonicalTeams();
  const savedAt=Date.now(),now=mdNowSeconds(),s={...matchdayState,matchMeta:currentMatchMeta(),clockBase:now,clockRunning:!!matchdayState.clockRunning,clockStartedAt:matchdayState.clockRunning?savedAt:0,savedAt};
  localStorage.setItem('sagi_matchday_graphics_v47',JSON.stringify(s));mdLocalRecoveryStamp=Math.max(mdLocalRecoveryStamp||0,savedAt);
 }catch(e){}
}
function mdApplyRecovered(x,overwriteMeta=false){
 if(!x||typeof x!=='object')return false;
 applyMatchMeta({...((x.matchMeta&&typeof x.matchMeta==='object')?x.matchMeta:{}),competition:(x.matchMeta&&x.matchMeta.competition)||x.competition||'',home:(x.matchMeta&&x.matchMeta.home)||x.home||'',away:(x.matchMeta&&x.matchMeta.away)||x.away||''},!!overwriteMeta);
 const copy={...x};delete copy.__sagiProjects;delete copy.commandId;delete copy.visualVersion;delete copy.home;delete copy.away;delete copy.event;delete copy.clock;delete copy.updatedAt;delete copy.homeCrest;delete copy.awayCrest;delete copy.competition;delete copy.matchMeta;
 matchdayState={...matchdayState,...copy,eventLog:Array.isArray(x.eventLog)?x.eventLog:(matchdayState.eventLog||[]),replayMarkers:Array.isArray(x.replayMarkers)?x.replayMarkers:(matchdayState.replayMarkers||[])};
 if(x.clock){
   let sec=Math.max(0,Number(x.clock.baseSeconds)||0);
   if(x.clock.running&&x.clock.startedAt){const t=Date.parse(x.clock.startedAt);if(Number.isFinite(t))sec+=Math.max(0,(Date.now()-t)/1000)}
   matchdayState.clockBase=sec;matchdayState.clockRunning=!!x.clock.running;matchdayState.clockStartedAt=x.clock.running?Date.now():0;matchdayState.period=x.clock.period||matchdayState.period;
 }
 mdNormalizeMatchMode();return true
}
function mdIdentityNorm(v){return String(v||'').trim().toLowerCase().replace(/\s+/g,' ')}
function mdIdentityGeneric(v){return !v||['home','away','主队','客队','team home','team away'].includes(mdIdentityNorm(v))}
function mdBridgeMatchesCurrent(x){
 const ch=String(q('matchHome').value||'').trim(),ca=String(q('matchAway').value||'').trim(),bh=String(x&&x.home||'').trim(),ba=String(x&&x.away||'').trim();
 if(mdIdentityGeneric(ch)||mdIdentityGeneric(ca)||mdIdentityGeneric(bh)||mdIdentityGeneric(ba))return true;
 return mdIdentityNorm(ch)===mdIdentityNorm(bh)&&mdIdentityNorm(ca)===mdIdentityNorm(ba)
}
function mdRecoveryTimestamp(x){
 const saved=Math.max(0,Number(x&&x.savedAt)||0),parsed=Date.parse(String(x&&x.updatedAt||''));
 return Math.max(saved,Number.isFinite(parsed)?parsed:0)
}
async function recoverMatchdayFromBridge(showNote=false,opts={}){
 try{
   const x=await lanJson('/api/matchday?recover='+Date.now());
   const bridgeMatches=!!(x&&x.commandId&&mdBridgeMatchesCurrent(x));
   if(x&&x.commandId&&!bridgeMatches&&!opts.allowIdentityTakeover){if(showNote)note('Bridge 是另一场比赛 · 已忽略旧比分状态');return false}
   if(x&&x.commandId){
     const remoteStamp=mdRecoveryTimestamp(x),localStamp=Math.max(Number(opts.localStamp)||0,mdLocalRecoveryStamp||0);
     if(opts.preferNewest&&localStamp&&(!remoteStamp||localStamp>remoteStamp+250)){
       mdRecoveryMetrics.localWins++;mdRecoveryMetrics.lastReason='LOCAL_NEWER';mdRecoveryMetrics.lastRecoveryAt=Date.now();
       await publishMatchday(matchdayState.lastEvent||null);
       if(showNote)note('本机比赛状态更新 · 已阻止旧 Bridge 回退');
       return true
     }
     if(mdApplyRecovered(x,!!opts.allowIdentityTakeover)){
       if(opts.preferNewest)mdRecoveryMetrics.bridgeWins++;
       mdLocalRecoveryStamp=Math.max(mdLocalRecoveryStamp||0,remoteStamp);
       refreshMatchdayUI();mdRenderLog();mdPersist();
       if(showNote){vdSave();if(matchdayState.overlayVisible)publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'RESTORE 图形开启');else publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'Out','',0,'RESTORE 图形关闭');note('已从 Bridge 恢复比赛状态与 Overlay')}
       return true
     }
   }
 }catch(e){}
 if(showNote)note('Bridge 暂无可恢复比赛状态');return false
}
function mdResetForProject(){
 matchdayState={...matchdayState,homeScore:0,awayScore:0,scoreboardVisible:false,scoreboardFrozen:false,period:'1H',clockBase:0,clockRunning:false,clockStartedAt:0,lastEvent:null,eventLog:[],replayMarkers:[],scoreHomeName:'',scoreAwayName:'',scoreNameFixture:'',homeRedCards:0,awayRedCards:0,homePen:0,awayPen:0,penaltyShootout:{started:false,rounds:5,firstSide:'HOME',history:[],winner:'',finished:false},simplePenalty:{visible:false,home:0,away:0,history:[],slots:5},stoppageTime:'',overlayVisible:false};refreshMatchdayUI();refreshMatchdayPlayers();mdRenderLog();mdPersist()
}
async function mdLoad(opts={}){
 let localStamp=0;
 try{
   let x=JSON.parse(localStorage.getItem('sagi_matchday_graphics_v47')||'null');
   if(!x)x=mdLoadLastGood();
   if(!x)x=JSON.parse(localStorage.getItem('sagi_matchday_graphics_v42')||'null');
   if(x){
     localStamp=mdRecoveryTimestamp(x);mdLocalRecoveryStamp=Math.max(mdLocalRecoveryStamp||0,localStamp);
     if(x.matchMeta)applyMatchMeta(x.matchMeta,true);
     if(x.clockRunning&&x.savedAt){x.clockBase=(Number(x.clockBase)||0)+Math.max(0,(Date.now()-Number(x.savedAt))/1000);x.clockStartedAt=Date.now()}
     matchdayState={...matchdayState,...x,eventLog:Array.isArray(x.eventLog)?x.eventLog:[],replayMarkers:Array.isArray(x.replayMarkers)?x.replayMarkers:[]};delete matchdayState.matchMeta;if(!x.scoreTheme||x.scoreTheme==='sagi')matchdayState.scoreTheme='sagi-pro';mdNormalizeMatchMode();
   }
 }catch(e){}
 refreshMatchdayUI();refreshMatchdayPlayers();mdRenderLog();
 if(opts.recoverBridge!==false)await recoverMatchdayFromBridge(false,{preferNewest:true,localStamp,allowIdentityTakeover:!localStamp});
 if(matchdayState.period==='PEN'&&mdPenaltyState().started)mdSyncDirectorPenaltyToSimple()
}
const MD_LAST_GOOD_KEY='sagi_matchday_last_good_v429';
let mdPublishRevision=0,mdLastAckRevision=0,mdPublishChain=Promise.resolve(),mdConsistencyBusy=false,mdLastConsistencyAt=0,mdLastConsistencyState='INIT',mdLocalRecoveryStamp=0;
let mdPublishMetrics={ok:0,failed:0,retried:0,recovered:0,lastOkAt:0,lastErrorAt:0,lastAttempts:0},mdEventGateSig='',mdEventGateAt=0;
let mdRecoveryMetrics={resumeChecks:0,networkRestores:0,forcedRepairs:0,localWins:0,bridgeWins:0,lastRecoveryAt:0,lastReason:'INIT'},mdRecoveryTimer=null;
function mdDelay(ms){return new Promise(r=>setTimeout(r,Math.max(0,Number(ms)||0)))}
function mdSaveLastGood(){
 try{
  const savedAt=Date.now(),now=mdNowSeconds(),s={...matchdayState,matchMeta:currentMatchMeta(),clockBase:now,clockRunning:!!matchdayState.clockRunning,clockStartedAt:matchdayState.clockRunning?savedAt:0,savedAt,schema:'SAGI_MATCHDAY_LKG_V4308'};
  localStorage.setItem(MD_LAST_GOOD_KEY,JSON.stringify(s));mdLocalRecoveryStamp=Math.max(mdLocalRecoveryStamp||0,savedAt);return true
 }catch(e){return false}
}
function mdLoadLastGood(){try{return JSON.parse(localStorage.getItem(MD_LAST_GOOD_KEY)||'null')}catch(e){return null}}
function mdAcceptOperatorEvent(signature,windowMs=850){
 const now=Date.now(),sig=String(signature||'');
 if(sig&&sig===mdEventGateSig&&(now-mdEventGateAt)<windowMs){if(q('mdEventStatus'))q('mdEventStatus').textContent='已拦截重复操作';return false}
 mdEventGateSig=sig;mdEventGateAt=now;return true
}
async function mdPostMatchdayWithRetry(state){
 const waits=[0,180,520,1200];let lastError=null;
 for(let i=0;i<waits.length;i++){
  if(waits[i])await mdDelay(waits[i]);
  try{
   await lanPost('/api/matchday',state);
   mdPublishMetrics.ok++;mdPublishMetrics.lastOkAt=Date.now();mdPublishMetrics.lastAttempts=i+1;if(i){mdPublishMetrics.retried+=i;mdPublishMetrics.recovered++}
   mdSaveLastGood();return{ok:true,attempts:i+1}
  }catch(e){lastError=e;mdPublishMetrics.lastErrorAt=Date.now()}
 }
 mdPublishMetrics.failed++;mdPublishMetrics.lastAttempts=waits.length;throw lastError||new Error('MATCHDAY_SYNC_FAILED')
}
window.sagiMatchdayReliabilityDiagnostic=()=>({metrics:{...mdPublishMetrics},recovery:{...mdRecoveryMetrics},localRecoveryStamp:mdLocalRecoveryStamp,lastAckRevision:mdLastAckRevision,lastConsistencyState:mdLastConsistencyState,lastConsistencyAt:mdLastConsistencyAt,lastGood:!!mdLoadLastGood(),fixtureKey:mdFixtureKey()});
function mdCloudSnapshot(event=null){
 const now=mdNowSeconds(),canonical=mdEnforceCanonicalTeams(),homeName=canonical.home||'HOME',awayName=canonical.away||'AWAY',revision=++mdPublishRevision;
 return{
  commandId:Date.now()+'_'+Math.random().toString(36).slice(2,7),
  revision,fixtureKey:mdFixtureKey(),
  visualVersion:'V4.30.8-LIVE-SCORE-GOAL-DIRECTOR',
  home:homeName,away:awayName,homeShort:homeName,awayShort:awayName,scoreHomeName:matchdayState.scoreHomeName||mdShortAuto(homeName,'主队'),scoreAwayName:matchdayState.scoreAwayName||mdShortAuto(awayName,'客队'),
  homeCrest:(teamStore.HOME&&teamStore.HOME.crest)||'',awayCrest:(teamStore.AWAY&&teamStore.AWAY.crest)||'',eventLogo:assets.eventLogo||'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20256%20239%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%2348cf35%22%2F%3E%3Cstop%20offset%3D%22.45%22%20stop-color%3D%22%230a8b4a%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23005432%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Cpath%20d%3D%22M%20133%20184%20L%20133%20213%20L%20134%20214%20L%20134%20222%20L%20135%20223%20L%20136%20231%20L%20137%20232%20L%20144%20232%20L%20164%20226%20L%20165%20224%20L%20162%20219%20L%20142%20199%20Z%20M%20129%20184%20L%20120%20199%20L%20113%20207%20L%20101%20218%20L%2097%20225%20L%20103%20228%20L%20109%20229%20L%20113%20231%20L%20126%20232%20L%20126%20228%20L%20128%20222%20L%20128%20216%20L%20129%20215%20Z%20M%2028%2083%20L%2029%2096%20L%2034%20108%20L%2041%20118%20L%2050%20126%20L%2061%20132%20L%2070%20133%20L%2071%20134%20L%20102%20134%20L%20103%20133%20L%20101%20127%20L%2092%20119%20L%2083%20116%20L%2071%20115%20L%2063%20111%20L%2052%2099%20L%2052%2097%20L%2049%2091%20L%2048%2083%20Z%20M%20234%2082%20L%20214%2082%20L%20214%2087%20L%20211%2097%20L%20203%20108%20L%20196%20113%20L%20194%20113%20L%20191%20115%20L%20178%20116%20L%20168%20120%20L%20161%20127%20L%20159%20133%20L%20196%20133%20L%20203%20131%20L%20212%20126%20L%20222%20117%20L%20227%20110%20L%20233%2096%20L%20233%2093%20L%20234%2092%20Z%20M%20227%2053%20L%20200%2053%20L%20198%2054%20L%20139%20112%20L%20134%20121%20L%20134%20173%20L%20137%20182%20L%20147%20195%20L%20153%20200%20L%20169%20210%20L%20175%20216%20L%20177%20220%20L%20181%20219%20L%20194%20209%20L%20194%20207%20L%20191%20203%20L%20184%20197%20L%20176%20193%20L%20173%20193%20L%20164%20190%20L%20157%20186%20L%20158%20185%20L%20161%20186%20L%20175%20186%20L%20185%20189%20L%20193%20194%20L%20201%20201%20L%20205%20199%20L%20215%20189%20L%20214%20187%20L%20203%20179%20L%20191%20174%20L%20179%20173%20L%20178%20172%20L%20159%20172%20L%20157%20171%20L%20153%20166%20L%20153%20161%20L%20154%20159%20L%20158%20156%20L%20206%20156%20L%20207%20155%20L%20212%20155%20L%20219%20153%20L%20228%20148%20L%20233%20144%20L%20239%20137%20L%20246%20124%20L%20248%20118%20L%20248%20114%20L%20239%20116%20L%20226%20121%20L%20223%20126%20L%20217%20132%20L%20208%20137%20L%20201%20138%20L%20200%20139%20L%20159%20139%20L%20153%20142%20L%20152%20141%20L%20153%20131%20L%20155%20127%20L%20211%2072%20Z%20M%20156%20185%20L%20157%20184%20L%20158%20185%20L%20157%20186%20Z%20M%2035%2053%20L%2038%2058%20L%2048%2069%20L%20107%20127%20L%20109%20131%20L%20109%20134%20L%20110%20135%20L%20110%20140%20L%20109%20141%20L%20104%20139%20L%2062%20139%20L%2061%20138%20L%2054%20137%20L%2045%20132%20L%2039%20126%20L%2036%20121%20L%2014%20114%20L%2014%20117%20L%2017%20126%20L%2023%20137%20L%2032%20147%20L%2042%20153%20L%2048%20155%20L%2053%20155%20L%2054%20156%20L%20104%20156%20L%20109%20160%20L%20110%20163%20L%20109%20167%20L%20103%20172%20L%2087%20172%20L%2086%20173%20L%2076%20173%20L%2075%20174%20L%2072%20174%20L%2056%20181%20L%2048%20188%20L%2048%20189%20L%2061%20201%20L%2068%20195%20L%2080%20188%20L%2087%20187%20L%2088%20186%20L%20102%20186%20L%20103%20187%20L%2098%20190%20L%2080%20196%20L%2068%20207%20L%2069%20210%20L%2085%20221%20L%2086%20218%20L%2091%20212%20L%20113%20197%20L%20120%20190%20L%20126%20180%20L%20128%20174%20L%20128%20167%20L%20129%20166%20L%20129%20125%20L%20128%20124%20L%20128%20121%20L%20126%20116%20L%2064%2054%20L%2061%2053%20Z%20M%20102%20186%20L%20103%20185%20L%20105%20186%20L%20104%20187%20Z%20M%2093%2024%20L%2075%2035%20L%2075%2045%20L%2076%2046%20L%2076%2050%20L%2078%2056%20L%2084%2066%20L%20129%20110%20L%20129%2093%20L%20128%2092%20L%20127%2084%20L%20124%2079%20L%2098%2052%20L%2095%2046%20L%2095%2042%20L%2094%2041%20L%2094%2024%20Z%20M%20169%2023%20L%20168%2023%20L%20168%2043%20L%20165%2051%20L%20159%2059%20L%20138%2079%20L%20135%2084%20L%20134%2092%20L%20133%2093%20L%20133%20110%20L%20178%2066%20L%20185%2054%20L%20186%2047%20L%20187%2046%20L%20187%2034%20Z%20M%20134%205%20L%20133%206%20L%20133%2074%20L%20142%2067%20L%20150%2059%20L%20150%2016%20L%20147%2013%20Z%20M%20128%205%20L%20118%2012%20L%20115%2013%20L%20112%2017%20L%20112%2059%20L%20129%2074%20L%20129%205%20Z%22%20fill%3D%22url(%23g)%22%20fill-rule%3D%22evenodd%22%2F%3E%3C%2Fsvg%3E',competition:q('matchCompetition').value.trim()||'SAGI FOOTBALL',
  homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore,scoreboardVisible:!!matchdayState.scoreboardVisible,scoreboardFrozen:!!matchdayState.scoreboardFrozen,
  homeColor:matchdayState.homeColor||'#d8b55b',awayColor:matchdayState.awayColor||'#4c7dff',accentColor:matchdayState.accentColor||'#f4f0e8',
  homeRedCards:Number(matchdayState.homeRedCards)||0,awayRedCards:Number(matchdayState.awayRedCards)||0,homePen:Number(matchdayState.homePen)||0,awayPen:Number(matchdayState.awayPen)||0,penaltyShootout:mdPenaltySnapshot(),simplePenalty:mdSimplePenaltySnapshot(),
  stoppageTime:matchdayState.stoppageTime||'',scoreTheme:matchdayState.scoreTheme||'sagi-pro',overlayVisible:!!matchdayState.overlayVisible,
  replayMarkers:(matchdayState.replayMarkers||[]).slice(0,80),eventLog:(matchdayState.eventLog||[]).slice(0,40),
  clock:{baseSeconds:now,running:!!matchdayState.clockRunning,startedAt:matchdayState.clockRunning?new Date().toISOString():null,period:matchdayState.period},
  controller:{operatorRole:matchOperatorRole,matchMode:matchModeActive,autoGraphics:!!graphicsDirectorSettings.enabled,autoReplay:!!graphicsDirectorSettings.autoReplay,smartDirector:!!smartDirectorSettings.enabled,autoTake:!!smartDirectorSettings.autoTake,smartCue:{slot:smartCue.slot,role:cameraRoleOf(smartCue.slot),title:smartCue.title,confidence:smartCue.confidence},cameraRoles:{cam1:cameraRoleOf('cam1'),cam2:cameraRoleOf('cam2'),drone:cameraRoleOf('drone'),replay:cameraRoleOf('replay')},shotSafety:{enabled:!!shotSafetySettings.enabled,currentSlot:shotSafetyState.currentSlot,minShotMs:shotSafetySettings.minShotMs,cooldownMs:shotSafetySettings.cooldownMs,bounceMs:shotSafetySettings.bounceMs,attackLockUntil:shotSafetyState.attackLockUntil}},event:event||null,updatedAt:new Date().toISOString()
 };
}
async function publishMatchday(event=null){
 const state=mdCloudSnapshot(event),revision=state.revision;matchdayState.lastEvent=event;mdPersist();refreshMatchdayUI();
 const send=async()=>{
  try{
   const r=await mdPostMatchdayWithRetry(state);mdLastAckRevision=Math.max(mdLastAckRevision,revision);
   if(q('mdSync'))q('mdSync').innerHTML='<span class="mdLiveDot on"></span>LAN 状态一致 · R'+mdLastAckRevision+(r.attempts>1?' · 自动重试 '+(r.attempts-1)+' 次':'');
   return{ok:true,revision,attempts:r.attempts}
  }catch(e){
   if(q('mdSync'))q('mdSync').innerHTML='<span class="mdLiveDot"></span>LAN 同步失败 · 已保留本机状态 / 最近正确状态';
   return{ok:false,revision,attempts:mdPublishMetrics.lastAttempts}
  }
 };
 mdPublishChain=mdPublishChain.then(send,send);return mdPublishChain
}
function mdConsistencyComparable(x){
 if(!x||typeof x!=='object')return'';
 const clock=x.clock||{},pen=x.penaltyShootout||{},simple=x.simplePenalty||{},normHex=v=>String(v||'').trim().toLowerCase();
 return JSON.stringify({
  fixtureKey:x.fixtureKey||[x.competition,x.home,x.away].map(mdIdentityNorm).join('|'),
  competition:String(x.competition||''),home:String(x.home||''),away:String(x.away||''),
  scoreHomeName:String(x.scoreHomeName||x.home||''),scoreAwayName:String(x.scoreAwayName||x.away||''),
  homeScore:Number(x.homeScore)||0,awayScore:Number(x.awayScore)||0,
  period:String(clock.period||x.period||''),scoreboardVisible:!!x.scoreboardVisible,scoreboardFrozen:!!x.scoreboardFrozen,
  scoreTheme:String(x.scoreTheme||'sagi-pro'),homeColor:normHex(x.homeColor),awayColor:normHex(x.awayColor),accentColor:normHex(x.accentColor),
  homeRedCards:Number(x.homeRedCards)||0,awayRedCards:Number(x.awayRedCards)||0,
  stoppageTime:String(x.stoppageTime||'').trim().replace(/^\+/,''),homePen:Number(x.homePen)||0,awayPen:Number(x.awayPen)||0,
  penaltyStarted:!!pen.started,penaltyFinished:!!pen.finished,penaltyHistory:Array.isArray(pen.history)?pen.history.length:0,
  simplePenaltyVisible:!!simple.visible,simplePenaltyHome:Number(simple.home)||0,simplePenaltyAway:Number(simple.away)||0,
  simplePenaltyHistory:Array.isArray(simple.history)?simple.history.length:0
 })
}
async function mdConsistencyCheck(force=false){
 if(mdConsistencyBusy||(!force&&(document.hidden||!matchReady||!(matchModeActive||matchdayState.scoreboardVisible||matchdayState.clockRunning))))return false;
 mdConsistencyBusy=true;
 try{
  const local=mdCloudSnapshot(null),remote=await lanJson('/api/matchday?consistency='+Date.now()),sameFixture=remote&&mdBridgeMatchesCurrent(remote);
  if(!remote||!remote.commandId||!sameFixture||mdConsistencyComparable(remote)!==mdConsistencyComparable(local)){
   mdLastConsistencyState=sameFixture?'REPAIR':'FIXTURE_REPAIR';await publishMatchday(matchdayState.lastEvent||null);mdLastConsistencyAt=Date.now();
   if(q('mdSync'))q('mdSync').innerHTML='<span class="mdLiveDot on"></span>状态已自动校正';return true
  }
  mdLastConsistencyState='OK';mdLastConsistencyAt=Date.now();if(q('mdSync'))q('mdSync').innerHTML='<span class="mdLiveDot on"></span>导播台 / 比分牌一致';return true
 }catch(e){mdLastConsistencyState='OFFLINE';return false}finally{mdConsistencyBusy=false}
}

async function mdRecoverySync(reason='MANUAL'){
 const active=!!(matchReady||matchModeActive||matchdayState.scoreboardVisible||matchdayState.clockRunning);
 if(!active)return false;
 mdRecoveryMetrics.lastReason=String(reason||'MANUAL');mdRecoveryMetrics.lastRecoveryAt=Date.now();
 if(reason==='ONLINE')mdRecoveryMetrics.networkRestores++;
 if(reason==='VISIBLE'||reason==='PAGESHOW')mdRecoveryMetrics.resumeChecks++;
 try{
  const repaired=await mdConsistencyCheck(true);
  if(repaired)mdRecoveryMetrics.forcedRepairs++;
  return repaired
 }catch(e){return false}
}
function mdScheduleRecovery(reason='AUTO',delay=120){
 clearTimeout(mdRecoveryTimer);
 mdRecoveryTimer=setTimeout(()=>{mdRecoverySync(reason).catch(()=>{})},Math.max(0,Number(delay)||0))
}
window.sagiMatchdayConsistencyCheck=(force=true)=>mdConsistencyCheck(!!force);
window.sagiMatchdayRecoverySync=(reason='MANUAL')=>mdRecoverySync(reason);
window.sagiMatchdaySoakDiagnostic=(cycles=5000)=>{
 const n=Math.max(1,Math.min(10000,Number(cycles)||1800));
 for(let i=0;i<n;i++){mdEnforceCanonicalTeams();refreshMatchdayClockUI();if(i%60===0)refreshMatchdayUI()}
 const t=mdCanonicalTeams();return{cycles:n,home:t.home,away:t.away,mirrorHome:q('mdHomeShort')?q('mdHomeShort').value:'',mirrorAway:q('mdAwayShort')?q('mdAwayShort').value:'',score:q('mdHomeScore')?q('mdHomeScore').textContent:''}
};
function mdEventLabel(e){
 if(!e)return'事件';if(e.type==='GOAL')return'进球';if(e.type==='YELLOW')return'黄牌';if(e.type==='RED')return'红牌';if(e.type==='SUB')return'换人';if(e.type==='HALF_TIME')return'半场';if(e.type==='FULL_TIME')return'全场';if(e.type==='MVP')return'MVP';return e.type||'事件';
}
function mdEventText(e){
 if(!e)return'';if(e.player)return'#'+(e.player.number||'')+' '+(e.player.name||'');if(e.type==='SUB')return'#'+(e.off&&e.off.number||'')+' '+(e.off&&e.off.name||'')+' → #'+(e.on&&e.on.number||'')+' '+(e.on&&e.on.name||'');if(e.type==='HALF_TIME'||e.type==='FULL_TIME')return(e.home||'HOME')+' '+(e.homeScore||0)+':'+(e.awayScore||0)+' '+(e.away||'AWAY');return e.team||'';
}
function mdRecordEvent(ev,before){
 if(!ev||ev.type==='CLEAR_EVENT')return;
 const item={id:'ev_'+Date.now()+'_'+Math.random().toString(36).slice(2,6),createdAt:new Date().toISOString(),event:ev,beforeHomeScore:before.homeScore,beforeAwayScore:before.awayScore,beforeHomeRed:Number(before.homeRedCards??matchdayState.homeRedCards)||0,beforeAwayRed:Number(before.awayRedCards??matchdayState.awayRedCards)||0};
 matchdayState.eventLog=[item].concat(matchdayState.eventLog||[]).slice(0,40);mdRenderLog();
}
function mdRenderLog(){
 const list=Array.isArray(matchdayState.eventLog)?matchdayState.eventLog:[],box=q('mdEventLog');if(!box)return;
 if(!list.length)box.innerHTML='<div class="mdEmpty">暂无比赛事件</div>';
 else box.innerHTML=list.map(x=>{const e=x.event||{};return'<div class="mdLogRow"><span class="mdLogTime">'+esc(e.at||'--:--')+'</span><span class="mdLogType">'+esc(mdEventLabel(e))+'</span><span class="mdLogText">'+esc(mdEventText(e))+'</span><span class="mdLogScore">'+x.beforeHomeScore+'→'+(e.type==='GOAL'&&e.side==='HOME'?x.beforeHomeScore+1:x.beforeHomeScore)+' / '+x.beforeAwayScore+'→'+(e.type==='GOAL'&&e.side==='AWAY'?x.beforeAwayScore+1:x.beforeAwayScore)+'</span></div>'}).join('');
 const count=t=>list.filter(x=>x.event&&x.event.type===t).length;q('mdStatGoal').textContent=count('GOAL');q('mdStatYellow').textContent=count('YELLOW');q('mdStatRed').textContent=count('RED');q('mdStatSub').textContent=count('SUB');
}
function mdUndoLast(){
 const list=matchdayState.eventLog||[];if(!list.length){note('没有可撤销的比赛事件');return}
 const x=list.shift(),e=x.event||{};matchdayState.homeScore=Number(x.beforeHomeScore)||0;matchdayState.awayScore=Number(x.beforeAwayScore)||0;
 matchdayState.homeRedCards=Number(x.beforeHomeRed)||0;matchdayState.awayRedCards=Number(x.beforeAwayRed)||0;matchdayState.eventLog=list;
 if(e.type==='GOAL'||e.type==='RED'){const idx=(matchdayState.replayMarkers||[]).findIndex(m=>m.type===e.type);if(idx>=0)matchdayState.replayMarkers.splice(idx,1)}
 mdRenderLog();mdRenderMarkers();q('mdEventStatus').textContent='已撤销 · '+mdEventLabel(e);publishMatchday({type:'CLEAR_EVENT'});note('已撤销 '+mdEventLabel(e));
}
function mdScore(side,delta){
 if(matchdayState.period==='PEN'){note('点球大战中 · 常规比分已锁定，请使用点球按钮');return false}
 if(side==='HOME')matchdayState.homeScore=Math.max(0,matchdayState.homeScore+delta);else matchdayState.awayScore=Math.max(0,matchdayState.awayScore+delta);publishMatchday(null);return true
}
function mdEventAutoClear(ms=5400){
 const seq=++mdMacroSeq;clearTimeout(mdMacroTimer);mdMacroTimer=setTimeout(()=>{if(seq!==mdMacroSeq)return;matchdayState.lastEvent=null;publishMatchday({type:'CLEAR_EVENT'})},ms)
}
function gdSetStatus(text,kind=''){
 const el=q('gdStatus');if(!el)return;el.textContent=text;el.className=kind||''
}
function gdPersist(){try{localStorage.setItem('sagi_graphics_director_v415',JSON.stringify(graphicsDirectorSettings))}catch(e){}}
function gdRefreshUI(){
 if(q('gdEnabled'))q('gdEnabled').checked=graphicsDirectorSettings.enabled!==false;
 if(q('gdAutoReplay'))q('gdAutoReplay').checked=!!graphicsDirectorSettings.autoReplay;
 if(q('gdReplayHold'))q('gdReplayHold').value=String(graphicsDirectorSettings.replayHold||3500);
 if(q('gdReturnSlot'))q('gdReturnSlot').value=graphicsDirectorSettings.returnSlot||'cam1';
 gdSetStatus(graphicsDirectorSettings.enabled===false?'MANUAL GRAPHICS':'安全自动 · 就绪',graphicsDirectorSettings.enabled===false?'manual':'')
}
function gdLoad(){
 try{const x=JSON.parse(localStorage.getItem('sagi_graphics_director_v415')||'null');if(x)graphicsDirectorSettings={...graphicsDirectorSettings,...x}}catch(e){}
 gdRefreshUI()
}
function gdSaveFromUI(){
 graphicsDirectorSettings.enabled=!!q('gdEnabled').checked;
 graphicsDirectorSettings.autoReplay=!!q('gdAutoReplay').checked;
 graphicsDirectorSettings.replayHold=Math.max(1500,Math.min(8000,Number(q('gdReplayHold').value)||3500));
 graphicsDirectorSettings.returnSlot=q('gdReturnSlot').value==='cam2'?'cam2':'cam1';
 gdPersist();gdRefreshUI()
}
function gdClearTimers(){for(const t of gdTimers)clearTimeout(t);gdTimers=[]}
function gdClearCameraTimers(){for(const t of gdCameraTimers)clearTimeout(t);gdCameraTimers=[]}
function gdSchedule(fn,ms,seq=gdSequence){
 const id=setTimeout(()=>{if(seq!==gdSequence)return;fn()},Math.max(0,Number(ms)||0));gdTimers.push(id);return id
}
function gdScheduleCamera(fn,ms,seq=gdSequence){
 const id=setTimeout(()=>{if(seq!==gdSequence||!gdAutoCameraActive)return;fn()},Math.max(0,Number(ms)||0));gdCameraTimers.push(id);return id
}
function gdAbort(showNote=true){
 gdSequence++;gdClearTimers();gdClearCameraTimers();gdAutoCameraActive=false;clearTimeout(mdMacroTimer);mdMacroSeq++;
 gdSetStatus('AUTO FLOW ABORTED','manual');if(showNote)note('自动导播流程已终止')
}
async function gdEnsureOverlay(){
 if(!graphicsDirectorSettings.enabled||!matchReady)return false;
 vdSave();
 if(matchdayState.overlayVisible)return true;
 matchdayState.overlayVisible=true;mdPersist();
 const ok=await publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'AUTO 图形开启');
 return !!ok
}
async function gdTakeCamera(slot,label,opts={}){
 const source=opts.source||'AUTO',eventType=opts.eventType||'',force=!!opts.force;
 return ssTake(slot,label,source,force,eventType)
}

const REPLAY_STINGER_SWITCH_MS=950,REPLAY_STINGER_CLEAR_MS=420;
function replayStingerPayload(phase='IN'){
 return{type:'REPLAY_STINGER',phase:phase==='OUT'?'OUT':'IN',title:phase==='OUT'?'BACK TO LIVE':'INSTANT REPLAY',label:phase==='OUT'?'回到比赛':'精彩回放',at:mdFormat(mdNowSeconds())}
}
async function replayStingerTake(slot,phase='IN',source='MANUAL',label=''){
 if(!matchReady)return false;vdSave();
 if(!vdSlotAvailable(slot)){note('回放/返回机位未分配，无法执行转场');return false}
 const overlayWasVisible=!!matchdayState.overlayVisible;
 if(!overlayWasVisible){
   matchdayState.overlayVisible=true;mdPersist();
   await publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'REPLAY LOGO STINGER ON')
 }
 gdSetStatus((phase==='OUT'?'RETURN':'REPLAY')+' · LOGO STINGER','busy');
 await publishMatchday(replayStingerPayload(phase));
 await new Promise(r=>setTimeout(r,REPLAY_STINGER_SWITCH_MS));
 const ok=await ssTake(slot,label||(phase==='OUT'?'REPLAY RETURN':'INSTANT REPLAY'),source,true,phase==='OUT'?'RETURN':'REPLAY');
 await new Promise(r=>setTimeout(r,REPLAY_STINGER_CLEAR_MS));
 await publishMatchday({type:'CLEAR_EVENT'});
 if(!overlayWasVisible){
   await new Promise(r=>setTimeout(r,120));
   matchdayState.overlayVisible=false;mdPersist();
   await publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'Out','',0,'REPLAY LOGO STINGER RESTORE')
 }
 return !!ok
}
async function gdRunEvent(ev,holdMs=5200){
 sdRecommend(ev);const seq=++gdSequence;gdClearTimers();clearTimeout(mdMacroTimer);mdMacroSeq++;
 const enabled=graphicsDirectorSettings.enabled!==false;
 if(enabled)await gdEnsureOverlay();
 if(!ev){await publishMatchday(null);return}
 const type=ev.type||'EVENT';
 if(type==='GOAL'&&enabled){
  gdSetStatus('1/3 · SCORE UPDATE','busy');
  await publishMatchday(null);
  gdSchedule(async()=>{
   gdSetStatus('2/3 · GOAL CARD','busy');await publishMatchday(ev);mdEventAutoClear(holdMs)
  },520,seq);
  const replaySlot=cameraSlotForRole('REPLAY','');
  if(graphicsDirectorSettings.autoReplay&&matchReady&&replaySlot&&vdSlotAvailable(replaySlot)){
   gdAutoCameraActive=true;
   gdClearCameraTimers();gdScheduleCamera(async()=>{
    gdSetStatus('AUTO REPLAY · LOGO STINGER','busy');
    await replayStingerTake(replaySlot,'IN','AUTO_REPLAY','AUTO GOAL REPLAY · '+cameraRoleLabel(cameraRoleOf(replaySlot)))
   },1450,seq);
   gdScheduleCamera(async()=>{
    const preferred=graphicsDirectorSettings.returnSlot||'cam1',returnSlot=vdSlotAvailable(preferred)?preferred:ssMainSlot();
    await replayStingerTake(returnSlot,'OUT','AUTO_REPLAY','AUTO RETURN TO MATCH');
    gdAutoCameraActive=false;gdSetStatus('3/3 · RETURN SCOREBUG','busy');smartCue={slot:returnSlot,title:'回到比赛',reason:'赛事 Logo 转场结束，恢复主比赛画面',confidence:99,eventType:'RETURN'};sdRender()
   },1450+REPLAY_STINGER_SWITCH_MS+(Number(graphicsDirectorSettings.replayHold)||3500),seq)
  }else if(graphicsDirectorSettings.autoReplay&&type==='GOAL'){
   gdAutoCameraActive=false;gdSetStatus('GOAL CARD · 无有效回放机位，已跳过自动回放','manual')
  }
  gdSchedule(()=>{if(seq===gdSequence)gdSetStatus('安全自动 · 就绪')},Math.max(holdMs+900,5200),seq);
  return
 }
 gdSetStatus(type+' · GRAPHIC LIVE','busy');await publishMatchday(ev);mdEventAutoClear(holdMs);
 gdSchedule(()=>{if(seq===gdSequence)gdSetStatus('安全自动 · 就绪')},holdMs+500,seq)
}
function ssPersist(){try{localStorage.setItem('sagi_shot_safety_v418',JSON.stringify(shotSafetySettings))}catch(e){}}
function ssLoad(){try{const x=JSON.parse(localStorage.getItem('sagi_shot_safety_v418')||'null');if(x)shotSafetySettings={...shotSafetySettings,...x}}catch(e){}}
function ssAttackRemaining(){return Math.max(0,(Number(shotSafetyState.attackLockUntil)||0)-Date.now())}
function ssMainSlot(){return cameraSlotForRole('MAIN_WIDE','')||'cam1'}
function ssCurrentLabel(){
 const slot=shotSafetyState.currentSlot;if(!slot)return'UNKNOWN';
 return cameraRoleLabel(cameraRoleOf(slot))+' · '+String(slot).toUpperCase()+' / INPUT '+String(vmixDirectorSettings[slot]||'—')
}
function ssRender(){
 const box=q('shotSafety');if(!box)return;
 q('ssEnabled').checked=shotSafetySettings.enabled!==false;q('ssMinShot').value=String(shotSafetySettings.minShotMs||3000);q('ssCooldown').value=String(shotSafetySettings.cooldownMs||2000);q('ssBounce').value=String(shotSafetySettings.bounceMs||6000);
 q('ssCurrentShot').textContent=ssCurrentLabel();
 const remain=ssAttackRemaining(),locked=remain>0,status=q('ssStatus');box.classList.toggle('locked',locked);box.classList.toggle('blocked',!!shotSafetyState.lastBlock&&!locked);q('ssAttackLock').classList.toggle('on',locked);
 if(shotSafetySettings.enabled===false){status.textContent='BYPASS · 安全引擎关闭';status.className='';q('ssReason').textContent='AUTO TAKE 不再受安全节奏限制；手动切换仍正常。';return}
 if(locked){status.textContent='ATTACK LOCK · '+(remain/1000).toFixed(1)+'s';status.className='locked';q('ssReason').textContent='关键进攻保护中：自动系统只能保持/返回主全景。';return}
 if(shotSafetyState.lastBlock){status.textContent='BLOCKED · AUTO TAKE';status.className='blocked';q('ssReason').textContent=shotSafetyState.lastBlock;return}
 status.textContent='SAFE · READY';status.className='';q('ssReason').textContent='自动切换已受最短镜头、冷却、防来回跳和关键比赛保护约束。'
}
function ssSaveFromUI(){
 shotSafetySettings.enabled=!!q('ssEnabled').checked;shotSafetySettings.minShotMs=Math.max(1000,Number(q('ssMinShot').value)||3000);shotSafetySettings.cooldownMs=Math.max(500,Number(q('ssCooldown').value)||2000);shotSafetySettings.bounceMs=Math.max(2000,Number(q('ssBounce').value)||6000);ssPersist();shotSafetyState.lastBlock='';ssRender()
}
function ssBlock(reason){shotSafetyState.lastBlock=reason;ssRender();setTimeout(()=>{if(shotSafetyState.lastBlock===reason){shotSafetyState.lastBlock='';ssRender()}},2600)}
function ssEvaluate(slot,source='AUTO',eventType=''){
 if(!slot)return{ok:false,reason:'没有目标机位'};
 if(source==='MANUAL'||source==='OPERATOR'||shotSafetySettings.enabled===false)return{ok:true};
 const now=Date.now(),current=shotSafetyState.currentSlot,role=cameraRoleOf(slot),elapsed=current?now-shotSafetyState.lastSwitchAt:1e9;
 if(current===slot)return{ok:false,noOp:true,reason:'已经在 '+cameraRoleLabel(role)};
 if(ssAttackRemaining()>0&&role!=='MAIN_WIDE')return{ok:false,reason:'关键进攻保护中，禁止自动离开主全景'};
 if(sdLateCloseGame()&&!['HALF_TIME','FULL_TIME','MVP'].includes(eventType)&&role!=='MAIN_WIDE'&&role!=='REPLAY')return{ok:false,reason:'比赛末段且比分接近，自动系统锁定主全景'};
 if(current&&elapsed<shotSafetySettings.minShotMs)return{ok:false,reason:'当前镜头仅 '+(elapsed/1000).toFixed(1)+'s，未达到最短 '+(shotSafetySettings.minShotMs/1000).toFixed(0)+'s'};
 if(shotSafetyState.lastAutoSwitchAt&&now-shotSafetyState.lastAutoSwitchAt<shotSafetySettings.cooldownMs)return{ok:false,reason:'自动切换冷却中，避免连续乱切'};
 if(shotSafetyState.previousSlot===slot&&elapsed<shotSafetySettings.bounceMs)return{ok:false,reason:'防来回跳保护：暂不返回上一机位'};
 return{ok:true}
}
function ssRegisterSwitch(slot,source='AUTO'){
 if(!slot)return;const prev=shotSafetyState.currentSlot;if(prev&&prev!==slot)shotSafetyState.previousSlot=prev;
 shotSafetyState.currentSlot=slot;shotSafetyState.lastSwitchAt=Date.now();if(source==='AUTO'||source==='SMART_AUTO'||source==='AUTO_REPLAY')shotSafetyState.lastAutoSwitchAt=Date.now();shotSafetyState.switchCount++;shotSafetyState.lastBlock='';ssRender()
}
function vdSlotAvailable(slot){vdSave();const input=String(vmixDirectorSettings[slot]||'').trim();return !!input&&input!==String(vmixDirectorSettings.graphics||'').trim()}
async function ssTake(slot,label,source='AUTO',force=false,eventType=''){
 if(!matchReady)return false;vdSave();
 const input=String(vmixDirectorSettings[slot]||'').trim();
 if(!input||input===String(vmixDirectorSettings.graphics||'').trim()){ssBlock('该机位未分配有效 vMix Input');if(source==='MANUAL'||source==='OPERATOR')note('该机位未分配，已阻止误切');return false}
 const check=force?{ok:true}:ssEvaluate(slot,source,eventType);
 if(check.noOp){ssBlock(check.reason);return true}
 if(!check.ok){ssBlock(check.reason);if(source!=='MANUAL'&&source!=='OPERATOR')gdSetStatus('SHOT SAFETY · BLOCKED','manual');return false}
 const fn=vmixDirectorSettings.transition,d=fn==='Fade'?vmixDirectorSettings.duration:0,ok=await publishVmixDirector(fn,input,d,label);
 if(ok)ssRegisterSwitch(slot,source);return !!ok
}
async function ssAttackLock(){
 shotSafetySettings.enabled=true;ssPersist();const main=ssMainSlot();shotSafetyState.attackLockUntil=Date.now()+(Number(shotSafetySettings.attackLockMs)||12000);shotSafetyState.lastBlock='';ssRender();
 smartCue={slot:main,role:'MAIN_WIDE',title:'关键进攻 · 主全景',reason:'SHOT SAFETY 已锁定主全景 12 秒',confidence:100,eventType:'ATTACK_LOCK'};sdRender();
 if(shotSafetyState.currentSlot!==main){await ssTake(main,'ATTACK LOCK · MAIN WIDE','OPERATOR',true,'ATTACK_LOCK')}
 note('关键进攻保护已开启 · 12秒')
}
function ssInit(){
 ssLoad();ssRender();
 ['ssEnabled','ssMinShot','ssCooldown','ssBounce'].forEach(id=>q(id).onchange=ssSaveFromUI);q('ssAttackLock').onclick=ssAttackLock;
 setInterval(()=>{if(!document.hidden)ssRender()},650)
}
function sdSlotLabel(slot){return cameraRoleLabel(cameraRoleOf(slot))}
function sdSlotTechnical(slot){return String(slot||'cam1').toUpperCase()+' · INPUT '+String(vmixDirectorSettings[slot]||'—')}
function sdPersist(){try{localStorage.setItem('sagi_smart_director_v417',JSON.stringify(smartDirectorSettings))}catch(e){}}
function sdLoad(){try{const raw=localStorage.getItem('sagi_smart_director_v417')||localStorage.getItem('sagi_smart_director_v416')||'null',x=JSON.parse(raw);if(x)smartDirectorSettings={...smartDirectorSettings,...x}}catch(e){}}
function sdRender(){
 const box=q('sdCueSlot');if(!box)return;
 q('sdEnabled').checked=smartDirectorSettings.enabled!==false;q('sdAutoTake').checked=!!smartDirectorSettings.autoTake;
 q('smartDirector').classList.toggle('disabled',smartDirectorSettings.enabled===false);q('smartDirector').classList.toggle('auto',!!smartDirectorSettings.autoTake);
 box.innerHTML='<span>'+esc(sdSlotLabel(smartCue.slot))+'</span><small>'+esc(sdSlotTechnical(smartCue.slot))+'</small>';q('sdCueTitle').textContent=smartCue.title||'保持主机位';q('sdCueReason').textContent=smartCue.reason||'';
 const c=Math.max(0,Math.min(100,Number(smartCue.confidence)||0)),ce=q('sdConfidence');ce.textContent=c>=88?('HIGH '+c+'%'):c>=75?('MED '+c+'%'):('SAFE '+c+'%');ce.className='sdConfidence '+(c>=88?'high':c>=75?'mid':'')
}
function sdHasSlot(slot){vdSave();return !!String(vmixDirectorSettings[slot]||'').trim()}
function sdRoleSlot(role,fallback='cam1'){return cameraSlotForRole(role,'')||fallback}
function sdHasRole(role){return cameraRoleAvailable(role)}
function sdLateCloseGame(){
 const sec=mdNowSeconds(),period=matchdayState.period,diff=Math.abs((Number(matchdayState.homeScore)||0)-(Number(matchdayState.awayScore)||0));
 return (period==='2H'&&sec>=75*60&&diff<=1)||(period==='ET2'&&diff<=1)
}
function sdRecommend(ev=null){
 if(smartDirectorSettings.enabled===false)return smartCue;
 vdSave();const type=ev&&ev.type||'IDLE',late=sdLateCloseGame(),main=sdRoleSlot('MAIN_WIDE','cam1');
 let cue={slot:main,title:'保持主全景',reason:late?'比赛末段且比分接近，主全景优先完整跟球':'主全景保持比赛连续性',confidence:late?96:80,eventType:type,role:'MAIN_WIDE'};
 if(type==='GOAL'){
  if(graphicsDirectorSettings.autoReplay){cue={slot:main,title:'AUTO REPLAY 已接管',reason:'自动回放流程正在执行，结束后回主比赛机位',confidence:99,eventType:type,role:'MAIN_WIDE'}}
  else if(sdHasRole('REPLAY')){cue={slot:sdRoleSlot('REPLAY','replay'),title:'准备进球回放',reason:'检测到 REPLAY 职责机位；进球后优先回放',confidence:98,eventType:type,role:'REPLAY'}}
  else cue={slot:main,title:'保持主全景',reason:'没有分配 REPLAY 职责，避免切到错误输入',confidence:99,eventType:type,role:'MAIN_WIDE'}
 }else if(type==='SUB'){
  if(sdHasRole('SIDELINE_CLOSE'))cue={slot:sdRoleSlot('SIDELINE_CLOSE',main),title:'边线近景看换人',reason:'换人阶段优先使用 SIDELINE CLOSE',confidence:91,eventType:type,role:'SIDELINE_CLOSE'};
  else if(sdHasRole('BENCH'))cue={slot:sdRoleSlot('BENCH',main),title:'教练席/技术区',reason:'没有边线近景，使用 BENCH 职责补充换人画面',confidence:86,eventType:type,role:'BENCH'};
  else cue={slot:main,title:'保持主全景',reason:'未配置边线近景或教练席职责',confidence:94,eventType:type,role:'MAIN_WIDE'}
 }else if(type==='YELLOW'){
  const close=sdHasRole('SIDELINE_CLOSE')?sdRoleSlot('SIDELINE_CLOSE',main):main;
  cue={slot:late?main:close,title:late?'保持主全景':'裁判/球员近景',reason:late?'末段关键比赛优先不丢球':'黄牌死球阶段可短暂使用边线近景',confidence:late?97:(close===main?92:84),eventType:type,role:late?'MAIN_WIDE':cameraRoleOf(close)}
 }else if(type==='RED'){
  cue={slot:main,title:'保持主全景',reason:'红牌属于高风险事件，优先保留冲突、裁判和重新开球完整信息',confidence:98,eventType:type,role:'MAIN_WIDE'}
 }else if(type==='HALF_TIME'){
  if(sdHasRole('DRONE'))cue={slot:sdRoleSlot('DRONE',main),title:'半场无人机建立镜头',reason:'比赛暂停，DRONE 用于场地与氛围建立',confidence:94,eventType:type,role:'DRONE'};
  else if(sdHasRole('BEAUTY_WIDE'))cue={slot:sdRoleSlot('BEAUTY_WIDE',main),title:'半场氛围宽景',reason:'使用 BEAUTY WIDE 完成半场建立镜头',confidence:90,eventType:type,role:'BEAUTY_WIDE'};
  else cue={slot:main,title:'半场主全景',reason:'无无人机/氛围宽景职责，主全景最安全',confidence:95,eventType:type,role:'MAIN_WIDE'}
 }else if(type==='FULL_TIME'){
  if(sdHasRole('DRONE'))cue={slot:sdRoleSlot('DRONE',main),title:'终场无人机收尾',reason:'终场后使用 DRONE 完成赛事环境收尾',confidence:97,eventType:type,role:'DRONE'};
  else if(sdHasRole('BEAUTY_WIDE'))cue={slot:sdRoleSlot('BEAUTY_WIDE',main),title:'终场氛围宽景',reason:'使用 BEAUTY WIDE 完成赛事收尾',confidence:94,eventType:type,role:'BEAUTY_WIDE'};
  else cue={slot:main,title:'终场主全景',reason:'没有环境建立机位，主全景收尾',confidence:96,eventType:type,role:'MAIN_WIDE'}
 }else if(type==='MVP'){
  const close=sdHasRole('SIDELINE_CLOSE')?sdRoleSlot('SIDELINE_CLOSE',main):main;
  cue={slot:close,title:close===main?'MVP 后回主全景':'MVP 后球员近景',reason:close===main?'回到现场主画面':'边线近景更适合人物与颁奖画面',confidence:88,eventType:type,role:cameraRoleOf(close)}
 }
 smartCue=cue;sdRender();
 if(smartDirectorSettings.autoTake&&cue.confidence>=90&&!gdAutoCameraActive&&type!=='GOAL')sdExecuteCue(true);
 return cue
}
async function sdExecuteCue(auto=false){
 if(smartDirectorSettings.enabled===false)return false;
 if(gdAutoCameraActive){if(!auto)note('AUTO REPLAY 正在执行，建议等待或先终止自动流程');return false}
 const cue=smartCue||{};if(!cue.slot)return false;
 const ok=await gdTakeCamera(cue.slot,(auto?'SMART AUTO TAKE · ':'SMART TAKE · ')+(cue.title||cue.slot),{source:auto?'SMART_AUTO':'OPERATOR',eventType:cue.eventType||'',force:!auto});
 gdSetStatus((auto?'AUTO TAKE · ':'SMART TAKE · ')+sdSlotLabel(cue.slot),auto?'busy':'manual');
 if(!auto)note('已执行建议 · '+sdSlotLabel(cue.slot));return !!ok
}
function sdInit(){
 sdLoad();sdRender();
 q('sdEnabled').onchange=()=>{smartDirectorSettings.enabled=!!q('sdEnabled').checked;sdPersist();sdRecommend(null)};
 q('sdAutoTake').onchange=()=>{smartDirectorSettings.autoTake=!!q('sdAutoTake').checked;sdPersist();sdRender();note(smartDirectorSettings.autoTake?'AUTO TAKE 已开启':'AUTO TAKE 已关闭')};
 q('sdExecute').onclick=()=>sdExecuteCue(false)
}
function gdInit(){
 gdLoad();
 q('gdEnabled').onchange=gdSaveFromUI;q('gdAutoReplay').onchange=gdSaveFromUI;q('gdReplayHold').onchange=gdSaveFromUI;q('gdReturnSlot').onchange=gdSaveFromUI;
 q('gdAbort').onclick=()=>gdAbort(true)
}
function mdAddReplayMarker(type,label=''){
 const sec=mdNowSeconds(),m={id:'mk_'+Date.now().toString(36),type:String(type||'KEY'),label:String(label||type||'KEY'),at:mdFormat(sec),seconds:Math.floor(sec),score:matchdayState.homeScore+'-'+matchdayState.awayScore,createdAt:new Date().toISOString()};
 matchdayState.replayMarkers=[m].concat(matchdayState.replayMarkers||[]).slice(0,80);mdPersist();mdRenderMarkers();return m
}
function mdRenderMarkers(){
 const box=q('mmMarkerList');if(!box)return;const list=Array.isArray(matchdayState.replayMarkers)?matchdayState.replayMarkers:[];
 box.innerHTML=list.length?list.map(x=>'<div class="mmMarkerRow"><span class="mmMarkerTime">'+esc(x.at||'--:--')+'</span><b>'+esc(x.type||'KEY')+'</b><span>'+esc(x.label||'')+'</span><span>'+esc(x.score||'')+'</span></div>').join(''):'<div class="mmRecovery">暂无标记</div>';
}
async function mdCopyMarkers(){
 const list=(matchdayState.replayMarkers||[]).slice().reverse(),txt=list.map(x=>(x.at||'--:--')+' · '+(x.type||'KEY')+' · '+(x.label||'')+' · '+(x.score||'')).join('\n');
 try{await navigator.clipboard.writeText(txt);note('回放标记已复制')}catch(e){prompt('复制回放标记：',txt)}
}
function mdMacroEvent(type,side,playerId=''){
 if(type==='GOAL'&&matchdayState.period==='PEN'){note('点球大战中 · 请使用点球罚进/罚失按钮');return false}
 if(!mdAcceptOperatorEvent(['EVENT',type,side,playerId].join('|'),1400))return false;
 const p=playerId?mdPlayer(side,playerId):null,before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore,homeRedCards:matchdayState.homeRedCards,awayRedCards:matchdayState.awayRedCards};
 if(type==='GOAL'){if(side==='HOME')matchdayState.homeScore++;else matchdayState.awayScore++;matchdayState.scoreboardVisible=true}
 if(type==='RED'){if(side==='HOME')matchdayState.homeRedCards=Math.min(5,(Number(matchdayState.homeRedCards)||0)+1);else matchdayState.awayRedCards=Math.min(5,(Number(matchdayState.awayRedCards)||0)+1)}
 const team=side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY');
 const ev={type,side,team,player:p?{id:p.id,name:p.name,number:p.number,position:p.position||p.role,photo:p.photo||''}:{id:'',name:team,number:'',position:'',photo:''},at:mdFormat(mdNowSeconds())};
 mdRecordEvent(ev,before);
 if(type==='GOAL'||type==='RED')mdAddReplayMarker(type,type==='GOAL'?'进球 · '+team:'红牌 · '+team);
 q('mdEventStatus').textContent=(type==='GOAL'?'进球':type==='YELLOW'?'黄牌':'红牌')+(p?' · #'+p.number+' '+p.name:' · '+team);
 gdRunEvent(ev,type==='GOAL'?5800:5000);refreshMatchdayUI();
}
function mdEvent(type){
 const side=q('mdEventSide').value,pid=q('mdEventPlayer').value;if(!pid){note('请先选择球员');return}mdMacroEvent(type,side,pid)
}

function mdSubstitutionByIds(side,offId,onId){
 if(!mdAcceptOperatorEvent(['SUB',side,offId,onId].join('|'),1000))return false;
 const off=mdPlayer(side,offId),on=mdPlayer(side,onId);if(!off||!on){note('请选择换下和换上球员');return}
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore,homeRedCards:matchdayState.homeRedCards,awayRedCards:matchdayState.awayRedCards};
 const ev={type:'SUB',side,team:side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY'),off:{id:off.id,name:off.name,number:off.number,position:off.position||off.role,photo:off.photo||''},on:{id:on.id,name:on.name,number:on.number,position:on.position||on.role,photo:on.photo||''},at:mdFormat(mdNowSeconds())};
 mdRecordEvent(ev,before);q('mdEventStatus').textContent='换人 · #'+off.number+' '+off.name+' → #'+on.number+' '+on.name;gdRunEvent(ev,6200)
}
function mdSubstitution(){mdSubstitutionByIds(q('mdSubSide').value,q('mdSubOff').value,q('mdSubOn').value)}

function mdMatchState(type){
 if(!mdAcceptOperatorEvent('MATCH_STATE|'+type,1200))return false;
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore},sec=mdNowSeconds();matchdayState.clockBase=sec;matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;
 const ev={type,home:q('matchHome').value||'HOME',away:q('matchAway').value||'AWAY',homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore,at:mdFormat(sec)};
 mdRecordEvent(ev,before);q('mdEventStatus').textContent=type==='HALF_TIME'?'半场图形已触发':'全场图形已触发';gdRunEvent(ev,type==='FULL_TIME'?9000:6500)
}
function mdMvp(){
 const side=q('mdMvpSide').value,pid=q('mdMvpPlayer').value;
 if(!mdAcceptOperatorEvent(['MVP',side,pid].join('|'),1200))return false;
 const p=mdPlayer(side,pid);if(!p){note('请选择本场最佳球员');return}
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore},ev={type:'MVP',side,team:side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY'),player:{id:p.id,name:p.name,number:p.number,position:p.position||p.role,photo:p.photo||''},score:matchdayState.homeScore+'-'+matchdayState.awayScore,at:mdFormat(mdNowSeconds())};
 mdRecordEvent(ev,before);q('mdEventStatus').textContent='MVP · #'+p.number+' '+p.name;gdRunEvent(ev,9000)
}
function applyOperatorRole(role,persist=true){
 matchOperatorRole=['FULL','DIRECTOR','SCOREKEEPER'].includes(role)?role:'FULL';document.body.dataset.operatorRole=matchOperatorRole;
 if(q('operatorRole'))q('operatorRole').value=matchOperatorRole;if(q('mmOperatorRole'))q('mmOperatorRole').value=matchOperatorRole;
 if(persist)try{localStorage.setItem('sagi_operator_role_v47',matchOperatorRole)}catch(e){}
}
function setMatchMode(on){
 matchModeActive=!!on;document.body.classList.toggle('mmOn',matchModeActive);
 try{localStorage.setItem('sagi_match_mode_v47',matchModeActive?'1':'0')}catch(e){}
 refreshMatchdayUI();if(matchModeActive)runTechnicalPreflight();
}
function mmCheckHtml(x){return '<div class="mmCheck '+esc(x.level)+'"><b>'+esc(x.label)+'</b>'+esc(x.meta)+'</div>'}
async function runTechnicalPreflight(){
 const checks=[];let h=null;
 try{h=await lanJson('/health?ts='+Date.now());checks.push({label:'LAN Bridge',level:h&&h.ok?'good':'bad',meta:h&&h.ok?'ONLINE':'OFFLINE'})}catch(e){checks.push({label:'LAN Bridge',level:'bad',meta:'OFFLINE'})}
 const vmixOk=!!(h&&h.vmix);checks.push({label:'vMix API 8088',level:vmixOk?'good':'bad',meta:vmixOk?'CONNECTED':'NOT CONNECTED'});
 vdSave();
 const inputs=h&&h.vmixInfo&&Array.isArray(h.vmixInfo.inputs)?h.vmixInfo.inputs:[];
 const findInput=n=>inputs.find(x=>String(x.number)===String(n));
 const main=findInput(vmixDirectorSettings.cam1),gfx=findInput(vmixDirectorSettings.graphics);
 checks.push({label:'主机位',level:main?'good':'bad',meta:main?(main.title||('INPUT '+vmixDirectorSettings.cam1)):'INPUT '+vmixDirectorSettings.cam1+' 不存在'});
 const gfxBrowser=gfx&&(/browser|web/i.test((gfx.type||'')+' '+(gfx.title||'')));
 checks.push({label:'SAGI 图形输入',level:gfxBrowser?'good':gfx?'warn':'bad',meta:gfx?(gfx.title||gfx.type||'已找到'):'INPUT '+vmixDirectorSettings.graphics+' 不存在'});
 const unique=String(vmixDirectorSettings.graphics)!==String(vmixDirectorSettings.cam1)&&String(vmixDirectorSettings.graphics)!==String(vmixDirectorSettings.cam2)&&String(vmixDirectorSettings.graphics)!==String(vmixDirectorSettings.drone)&&String(vmixDirectorSettings.graphics)!==String(vmixDirectorSettings.replay);
 checks.push({label:'输入编号冲突',level:unique?'good':'bad',meta:unique?'无冲突':'图形输入与机位重复'});
 let outputOk=false,stateOk=false;try{outputOk=(await fetch('/vmix?check='+Date.now(),{cache:'no-store'})).ok}catch(e){};try{stateOk=(await fetch('/api/matchday?check='+Date.now(),{cache:'no-store'})).ok}catch(e){}
 checks.push({label:'vMix 图形页',level:outputOk?'good':'bad',meta:outputOk?'READY':'ERROR'});checks.push({label:'比分状态通道',level:stateOk?'good':'bad',meta:stateOk?'READY':'ERROR'});
 const optional=['cam2','drone','replay'].filter(k=>!findInput(vmixDirectorSettings[k]));
 checks.push({label:'辅助机位',level:optional.length?'warn':'good',meta:optional.length?('缺 '+optional.join('/')):'全部可用'});
 const mainRole=cameraSlotForRole('MAIN_WIDE',''),replayRole=cameraSlotForRole('REPLAY',''),closeRole=cameraSlotForRole('SIDELINE_CLOSE',''),droneRole=cameraSlotForRole('DRONE','');
 checks.push({label:'主全景职责',level:mainRole?'good':'warn',meta:mainRole?(cameraRoleSlotLabel(mainRole)):'未分配 · 将回退 CAM1'});
 checks.push({label:'回放职责',level:replayRole?'good':'warn',meta:replayRole?(cameraRoleSlotLabel(replayRole)):'未分配 · 进球不会自动建议回放'});
 checks.push({label:'边线近景职责',level:closeRole?'good':'warn',meta:closeRole?(cameraRoleSlotLabel(closeRole)):'可选 · 换人将保持主全景'});
 checks.push({label:'无人机职责',level:droneRole?'good':'warn',meta:droneRole?(cameraRoleSlotLabel(droneRole)):'可选 · 半场/全场使用其他宽景'});
 checks.push({label:'STAGE 广播系统',level:shotSafetySettings.enabled?'good':'warn',meta:shotSafetySettings.enabled?('ON · 最短 '+(shotSafetySettings.minShotMs/1000)+'s · 防跳 '+(shotSafetySettings.bounceMs/1000)+'s'):'OFF · AUTO TAKE 无节奏保护'});
 checks.push({label:'比赛项目 READY',level:matchReady?'good':'warn',meta:matchReady?'READY':'尚未锁定'});
 technicalReady=!checks.some(x=>x.level==='bad');
 if(q('mmPreflightList'))q('mmPreflightList').innerHTML=checks.map(mmCheckHtml).join('');
 if(q('mmReadyStatus')){q('mmReadyStatus').textContent=technicalReady?'READY TO AIR':'NOT READY';q('mmReadyStatus').className=technicalReady?'mmGood':'mmBad'}
 if(q('mmBridgeStatus')){q('mmBridgeStatus').textContent=h&&h.ok?'ONLINE':'OFFLINE';q('mmBridgeStatus').className=h&&h.ok?'mmGood':'mmBad'}
 if(q('mmVmixStatus')){q('mmVmixStatus').textContent=vmixOk?'CONNECTED':'OFFLINE';q('mmVmixStatus').className=vmixOk?'mmGood':'mmBad'}
 if(q('mmRecoveryStatus')){q('mmRecoveryStatus').textContent=h&&h.recovery?'SAVED':'ARMED';q('mmRecoveryStatus').className='mmGood'}
 return technicalReady
}
function mdHealthLocalView(){
 const meta=currentMatchMeta();
 return{...matchdayState,fixtureKey:mdFixtureKey(),competition:meta.competition||'',home:meta.home||'',away:meta.away||'',scoreHomeName:matchdayState.scoreHomeName||mdShortAuto(meta.home,'主队'),scoreAwayName:matchdayState.scoreAwayName||mdShortAuto(meta.away,'客队'),clock:{period:matchdayState.period},penaltyShootout:mdPenaltySnapshot(),simplePenalty:mdSimplePenaltySnapshot()}
}
async function runLiveHealthCheck(){
 const checks=[];let health=null,remote=null,outputOk=false;
 try{health=await lanJson('/health?live='+Date.now());checks.push({label:'LAN Bridge',level:health&&health.ok?'good':'bad',meta:health&&health.ok?'ONLINE':'OFFLINE'})}catch(e){checks.push({label:'LAN Bridge',level:'bad',meta:'OFFLINE'})}
 checks.push({label:'vMix API',level:health&&health.vmix?'good':health&&health.ok?'warn':'bad',meta:health&&health.vmix?'CONNECTED':'未确认'});
 try{remote=await lanJson('/api/matchday?liveHealth='+Date.now())}catch(e){}
 const sameFixture=!!(remote&&remote.commandId&&mdBridgeMatchesCurrent(remote));
 const stateAligned=!!(sameFixture&&mdConsistencyComparable(remote)===mdConsistencyComparable(mdHealthLocalView()));
 checks.push({label:'比分状态',level:stateAligned?'good':remote&&remote.commandId?'warn':'bad',meta:stateAligned?'一致':remote&&remote.commandId?'检测到差异 · 未自动改动':'不可读'});
 try{outputOk=(await fetch('/vmix?liveHealth='+Date.now(),{cache:'no-store'})).ok}catch(e){}
 if(!outputOk)try{outputOk=(await fetch('/intro/vmix-v45-lan.html?liveHealth='+Date.now(),{cache:'no-store'})).ok}catch(e){}
 checks.push({label:'Browser Input',level:outputOk?'good':'bad',meta:outputOk?'页面可读取':'页面不可读取'});
 checks.push({label:'本机恢复点',level:mdLoadLastGood()?'good':'warn',meta:mdLoadLastGood()?'已保存':'尚未保存'});
 const safe=checks.every(x=>x.level!=='bad');
 if(q('mmPreflightList'))q('mmPreflightList').innerHTML=checks.map(mmCheckHtml).join('');
 if(q('mmReadyStatus')){q('mmReadyStatus').textContent=safe?(stateAligned?'LIVE HEALTHY':'LIVE CHECK'):'LIVE WARNING';q('mmReadyStatus').className=safe?'mmGood':'mmBad'}
 if(q('mmBridgeStatus')){q('mmBridgeStatus').textContent=health&&health.ok?'ONLINE':'OFFLINE';q('mmBridgeStatus').className=health&&health.ok?'mmGood':'mmBad'}
 if(q('mmRecoveryStatus')){q('mmRecoveryStatus').textContent=mdLoadLastGood()?'CHECKPOINT':'ARMED';q('mmRecoveryStatus').className='mmGood'}
 return{ok:safe,stateAligned,outputOk,bridge:!!(health&&health.ok),vmix:!!(health&&health.vmix),checks:checks.map(x=>({label:x.label,level:x.level,meta:x.meta}))}
}
window.sagiLiveHealthCheck=runLiveHealthCheck;
function emergencyFreeze(){
 matchdayState.scoreboardFrozen=!matchdayState.scoreboardFrozen;publishMatchday(null);refreshMatchdayUI();note(matchdayState.scoreboardFrozen?'比分牌已冻结':'比分牌已解除冻结')
}
function emergencyHideAll(){
 matchdayState.scoreboardVisible=false;matchdayState.lastEvent=null;publishMatchday({type:'CLEAR_EVENT'});publishVmixDirector('OverlayInputAllOff','','0','EMERGENCY HIDE ALL');note('全部图形已隐藏')
}
async function emergencySafeCamera(){
 matchdayState.scoreboardVisible=false;matchdayState.lastEvent=null;await publishMatchday({type:'CLEAR_EVENT'});await publishVmixDirector('OverlayInputAllOff','','0','SAFE OVERLAYS OFF');vdSave();await publishVmixDirector('Cut',vmixDirectorSettings.cam1,0,'SAFE MAIN CAMERA');note('已恢复安全主画面')
}
function initMatchMode(){
 try{matchOperatorRole=localStorage.getItem('sagi_operator_role_v47')||'FULL'}catch(e){};applyOperatorRole(matchOperatorRole,false);
 q('operatorRole').onchange=e=>applyOperatorRole(e.target.value);q('mmOperatorRole').onchange=e=>applyOperatorRole(e.target.value);
 q('enterMatchModeBtn').onclick=()=>setMatchMode(true);q('mmExit').onclick=()=>setMatchMode(false);q('technicalPreflightBtn').onclick=runTechnicalPreflight;q('mmRunPreflight').onclick=runTechnicalPreflight;q('mmLiveHealth').onclick=runLiveHealthCheck;q('mmRestoreState').onclick=()=>recoverMatchdayFromBridge(true);
 q('mmHomeMinus').onclick=()=>mdScore('HOME',-1);q('mmHomePlus').onclick=()=>mdScore('HOME',1);q('mmAwayMinus').onclick=()=>mdScore('AWAY',-1);q('mmAwayPlus').onclick=()=>mdScore('AWAY',1);
 q('mmClockStart').onclick=()=>q('mdClockStart').click();q('mmClockPause').onclick=()=>q('mdClockPause').click();q('mmScoreboardToggle').onclick=()=>{matchdayState.scoreboardVisible=!matchdayState.scoreboardVisible;publishMatchday(null)};
 q('mmEventSide').onchange=refreshMatchdayPlayers;q('mmGoalMacro').onclick=()=>mdMacroEvent('GOAL',q('mmEventSide').value,q('mmEventPlayer').value);q('mmYellowMacro').onclick=()=>mdMacroEvent('YELLOW',q('mmEventSide').value,q('mmEventPlayer').value);q('mmRedMacro').onclick=()=>mdMacroEvent('RED',q('mmEventSide').value,q('mmEventPlayer').value);
 q('mmHalf').onclick=()=>mdMatchState('HALF_TIME');q('mmFull').onclick=()=>mdMatchState('FULL_TIME');
 q('mmSubSide').onchange=refreshMatchdayPlayers;q('mmSubMacro').onclick=()=>mdSubstitutionByIds(q('mmSubSide').value,q('mmSubOff').value,q('mmSubOn').value);
 q('mmCam1').onclick=()=>vdTake('cam1');q('mmCam2').onclick=()=>vdTake('cam2');q('mmDrone').onclick=()=>vdTake('drone');q('mmReplay').onclick=()=>vdTake('replay');q('mmGraphicsOn').onclick=vdOverlayIn;q('mmGraphicsOff').onclick=vdOverlayOut;
 q('mmMarkSave').onclick=()=>{mdAddReplayMarker('SAVE','精彩扑救');note('已标记扑救')};q('mmMarkIncident').onclick=()=>{mdAddReplayMarker('INCIDENT','对抗/冲突');note('已标记事件')};q('mmMarkKey').onclick=()=>{mdAddReplayMarker('KEY','精彩时刻');note('已标记精彩时刻')};
 q('mmCopyMarkers').onclick=mdCopyMarkers;q('mmClearMarkers').onclick=()=>{matchdayState.replayMarkers=[];mdPersist();mdRenderMarkers();note('回放标记已清空')};
 q('mmFreeze').onclick=emergencyFreeze;q('mmHideAll').onclick=emergencyHideAll;q('mmSafeCam').onclick=emergencySafeCamera;
 refreshMatchdayPlayers();refreshMatchdayUI();runTechnicalPreflight();
}
function initMatchdayGraphics(){
 q('mdHomeMinus').onclick=()=>mdScore('HOME',-1);q('mdHomePlus').onclick=()=>mdScore('HOME',1);q('mdAwayMinus').onclick=()=>mdScore('AWAY',-1);q('mdAwayPlus').onclick=()=>mdScore('AWAY',1);
 q('mdScoreboardShow').onclick=()=>{matchdayState.scoreboardVisible=true;publishMatchday(null)};q('mdScoreboardHide').onclick=()=>{matchdayState.scoreboardVisible=false;publishMatchday(null)};
 q('mdHomeColor').oninput=e=>{matchdayState.homeColor=e.target.value;publishMatchday(null)};
 q('mdAwayColor').oninput=e=>{matchdayState.awayColor=e.target.value;publishMatchday(null)};
 q('mdAccentColor').oninput=e=>{matchdayState.accentColor=e.target.value;publishMatchday(null)};
 q('mdColorReset').onclick=()=>{matchdayState.homeColor='#d8b55b';matchdayState.awayColor='#4c7dff';matchdayState.accentColor='#f4f0e8';refreshMatchdayUI();publishMatchday(null)};
 const syncScoreNames=()=>{const t=mdCanonicalTeams();matchdayState.scoreHomeName=String(q('mdHomeShort').value||'').trim()||mdShortAuto(t.home,'主队');matchdayState.scoreAwayName=String(q('mdAwayShort').value||'').trim()||mdShortAuto(t.away,'客队');matchdayState.scoreNameFixture=[t.home,t.away].map(mdIdentityNorm).join('|');refreshMatchdayUI();publishMatchday(null)};
 q('mdHomeShort').addEventListener('change',syncScoreNames);q('mdAwayShort').addEventListener('change',syncScoreNames);
 q('mdHomeShort').addEventListener('blur',syncScoreNames);q('mdAwayShort').addEventListener('blur',syncScoreNames);
 q('mdStoppage').addEventListener('input',()=>{matchdayState.stoppageTime=q('mdStoppage').value.trim();publishMatchday(null)});
 q('mdScoreTheme').onchange=()=>{matchdayState.scoreTheme=q('mdScoreTheme').value;publishMatchday(null)};
 ['mdHomeRed','mdAwayRed','mdHomePen','mdAwayPen'].forEach(id=>q(id).addEventListener('change',()=>{matchdayState.homeRedCards=Math.max(0,Number(q('mdHomeRed').value)||0);matchdayState.awayRedCards=Math.max(0,Number(q('mdAwayRed').value)||0);matchdayState.homePen=Math.max(0,Number(q('mdHomePen').value)||0);matchdayState.awayPen=Math.max(0,Number(q('mdAwayPen').value)||0);publishMatchday(null)}));
 q('mdClockStart').onclick=()=>{if(!matchdayState.clockRunning){matchdayState.clockStartedAt=Date.now();matchdayState.clockRunning=true;publishMatchday(null)}};
 q('mdClockPause').onclick=()=>{matchdayState.clockBase=mdNowSeconds();matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;publishMatchday(null)};
 q('mdClockReset').onclick=()=>{matchdayState.clockBase=0;matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;publishMatchday(null)};
 q('mdClockSetBtn').onclick=()=>{const s=mdParse(q('mdSetClock').value);if(s==null){note('时间格式请使用 45:00');return}matchdayState.clockBase=s;matchdayState.clockStartedAt=matchdayState.clockRunning?Date.now():0;publishMatchday(null)};
 q('mdPeriod').onchange=()=>{const p=q('mdPeriod').value;if(p==='PEN')mdPenaltyStart();else{matchdayState.period=p;const simple=mdSimplePenaltyState();simple.visible=false;const pen=mdPenaltyState();pen.started=false;pen.finished=false;pen.winner='';matchdayState.homePen=0;matchdayState.awayPen=0;matchdayState.scoreboardVisible=true;mdRenderSimplePenalty();mdRenderPenaltyDirector();publishMatchday(null);note('已退出点球模式 · 常规小比分牌恢复')}};
 q('mdGoalBtn').onclick=()=>mdEvent('GOAL');q('mdYellowBtn').onclick=()=>mdEvent('YELLOW');q('mdRedBtn').onclick=()=>mdEvent('RED');
 q('mdSubBtn').onclick=mdSubstitution;q('mdHalfBtn').onclick=()=>mdMatchState('HALF_TIME');q('mdFullBtn').onclick=()=>mdMatchState('FULL_TIME');q('mdMvpBtn').onclick=mdMvp;
 q('mdScoreReset').onclick=()=>{matchdayState.homeScore=0;matchdayState.awayScore=0;matchdayState.homePen=0;matchdayState.awayPen=0;matchdayState.penaltyShootout={started:false,rounds:5,firstSide:'HOME',history:[],winner:'',finished:false};mdSyncDirectorPenaltyToSimple(true);if(matchdayState.period==='PEN')matchdayState.period='2H';matchdayState.scoreboardVisible=true;mdNormalizeMatchMode();publishMatchday(null)};
 q('mdClearEventBtn').onclick=()=>{gdAbort(false);matchdayState.lastEvent=null;publishMatchday({type:'CLEAR_EVENT'})};q('mdPublishState').onclick=()=>publishMatchday(null);q('mdUndoLast').onclick=mdUndoLast;q('mdClearLog').onclick=()=>{matchdayState.eventLog=[];mdRenderLog();mdPersist();note('事件日志已清空')};
 q('spHomePlus').onclick=()=>mdSimplePenaltyAdd('HOME');q('spAwayPlus').onclick=()=>mdSimplePenaltyAdd('AWAY');q('spHomeMiss').onclick=()=>mdSimplePenaltyMiss('HOME');q('spAwayMiss').onclick=()=>mdSimplePenaltyMiss('AWAY');q('spToggle').onclick=mdSimplePenaltyToggle;q('spUndo').onclick=mdSimplePenaltyUndo;q('spReset').onclick=mdSimplePenaltyReset;
 q('mdPenStart').onclick=mdPenaltyStart;q('mdPenHomeGoal').onclick=()=>mdPenaltyKick('HOME','GOAL');q('mdPenHomeMiss').onclick=()=>mdPenaltyKick('HOME','MISS');q('mdPenAwayGoal').onclick=()=>mdPenaltyKick('AWAY','GOAL');q('mdPenAwayMiss').onclick=()=>mdPenaltyKick('AWAY','MISS');q('mdPenUndo').onclick=mdPenaltyUndo;q('mdPenReset').onclick=mdPenaltyReset;
 q('mdPenRounds').onchange=()=>{const p=mdPenaltyState();if(!p.history.length){p.rounds=Number(q('mdPenRounds').value)||5;mdRenderPenaltyDirector();mdPersist()}};
 q('mdPenFirst').onchange=()=>{const p=mdPenaltyState();if(!p.history.length){p.firstSide=q('mdPenFirst').value==='AWAY'?'AWAY':'HOME';mdRenderPenaltyDirector();mdPersist()}};
 q('mmPenStart').onclick=mdPenaltyStart;q('mmPenGoal').onclick=()=>{const side=mdPenaltyNextSide();if(side)mdPenaltyKick(side,'GOAL')};q('mmPenMiss').onclick=()=>{const side=mdPenaltyNextSide();if(side)mdPenaltyKick(side,'MISS')};q('mmPenUndo').onclick=mdPenaltyUndo;
 q('mdEventSide').onchange=refreshMatchdayPlayers;q('mdSubSide').onchange=refreshMatchdayPlayers;q('mdMvpSide').onchange=refreshMatchdayPlayers;
 ['addBtn','updateBtn','removeBtn','demoBtn','loadBtn','homeSideBtn','awaySideBtn'].forEach(id=>q(id)&&q(id).addEventListener('click',()=>setTimeout(refreshMatchdayPlayers,60)));
 ['matchHome','matchAway'].forEach(id=>q(id)&&q(id).addEventListener('input',()=>{mdEnforceCanonicalTeams();refreshMatchdayUI()}));
 ['matchHome','matchAway','matchCompetition'].forEach(id=>q(id)&&q(id).addEventListener('change',()=>{mdEnforceCanonicalTeams();refreshMatchdayUI();if(matchReady||matchdayState.scoreboardVisible)publishMatchday(null)}));
 setInterval(()=>{if(matchdayState.clockRunning&&!document.hidden)refreshMatchdayClockUI()},500);setInterval(()=>{if(!document.hidden&&!matchdayState.lastEvent&&!gdAutoCameraActive)sdRecommend(null)},5000);setInterval(()=>{mdConsistencyCheck(false).catch(()=>{})},12000);
 window.addEventListener('online',()=>mdScheduleRecovery('ONLINE',80));
 window.addEventListener('pageshow',()=>mdScheduleRecovery('PAGESHOW',120));
 window.addEventListener('pagehide',()=>{mdPersist();mdSaveLastGood()});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)mdScheduleRecovery('VISIBLE',120)});
 gdInit();sdInit();ssInit();mdLoad();
}



let vmixDirectorSettings={cam1:'1',cam2:'',drone:'',replay:'',graphics:'',transition:'Cut',duration:350,overlay:'1',cam1Role:'MAIN_WIDE',cam2Role:'SIDELINE_CLOSE',droneRole:'DRONE',replayRole:'REPLAY'};
let filterSettings={target:'ALL',preset:'ORIGINAL',strength:.65};
const FILTER_SLOT={CLEAN:1,WARM:2,NIGHT:3};
function filterSave(){try{localStorage.setItem('sagi_filter_engine_v471',JSON.stringify(filterSettings))}catch(e){}}
function filterLoad(){try{const x=JSON.parse(localStorage.getItem('sagi_filter_engine_v471')||'null');if(x)filterSettings={...filterSettings,...x}}catch(e){}}
function filterInputs(target=filterSettings.target){vdSave();const slots=target==='ALL'?['cam1','cam2','drone','replay']:[target],seen=new Set(),out=[];for(const slot of slots){const n=String(vmixDirectorSettings[slot]||'').trim();if(n&&n!==String(vmixDirectorSettings.graphics)&&!seen.has(n)){seen.add(n);out.push(n)}}return out}
async function filterCommand(fn,input,value=''){const cmd={commandId:Date.now()+'_'+Math.random().toString(36).slice(2,7),functionName:fn,input:String(input||''),duration:0,value:String(value??''),label:'FILTER '+fn,issuedAt:new Date().toISOString(),version:'V4.30.8-LAN'};try{await lanPost('/api/vmix',cmd);return true}catch(e){return false}}
async function applyFilterPreset(preset,target=filterSettings.target){
 preset=['ORIGINAL','CLEAN','WARM','NIGHT'].includes(preset)?preset:'ORIGINAL';const inputs=filterInputs(target);if(!inputs.length){if(q('filterStatus'))q('filterStatus').textContent='没有可用摄像机 Input';note('没有可用摄像机 Input');return false}
 if(q('filterStatus'))q('filterStatus').textContent='正在应用 '+preset+'…';let ok=true;
 for(const input of inputs){for(const n of [1,2,3])ok=(await filterCommand('Effect'+n+'Off',input))&&ok;if(preset!=='ORIGINAL'){const n=FILTER_SLOT[preset],strength=Math.max(0,Math.min(1,Number(filterSettings.strength)||0));ok=(await filterCommand('SetEffect'+n+'Strength',input,strength.toFixed(2)))&&ok;ok=(await filterCommand('Effect'+n+'On',input))&&ok}}
 filterSettings.preset=preset;filterSettings.target=target;filterSave();if(q('filterStatus'))q('filterStatus').textContent=(ok?'已应用 · ':'部分失败 · ')+preset+' · '+Math.round(filterSettings.strength*100)+'%';return ok
}
function initFilterEngine(){
 filterLoad();if(q('filterTarget'))q('filterTarget').value=filterSettings.target;if(q('filterStrength'))q('filterStrength').value=Math.round((Number(filterSettings.strength)||.65)*100);if(q('filterStrengthValue'))q('filterStrengthValue').textContent=Math.round((Number(filterSettings.strength)||.65)*100)+'%';
 document.querySelectorAll('[data-filter-preset]').forEach(b=>b.onclick=()=>applyFilterPreset(b.dataset.filterPreset,q('filterTarget').value));document.querySelectorAll('[data-mm-filter]').forEach(b=>b.onclick=()=>applyFilterPreset(b.dataset.mmFilter,'ALL'));
 if(q('filterTarget'))q('filterTarget').onchange=e=>{filterSettings.target=e.target.value;filterSave()};
 if(q('filterStrength')){q('filterStrength').oninput=e=>q('filterStrengthValue').textContent=e.target.value+'%';q('filterStrength').onchange=e=>{filterSettings.strength=Math.max(0,Math.min(1,Number(e.target.value)/100));filterSave();if(filterSettings.preset!=='ORIGINAL')applyFilterPreset(filterSettings.preset,filterSettings.target)}}
 if(q('filterStatus'))q('filterStatus').textContent=filterSettings.preset+' · '+Math.round(filterSettings.strength*100)+'%';
}

const CAMERA_ROLE_LABELS={MAIN_WIDE:'主全景',SIDELINE_CLOSE:'边线近景',BENCH:'教练席',GOAL_BEHIND:'球门后',DRONE:'无人机',BEAUTY_WIDE:'氛围宽景',REPLAY:'回放'};
const CAMERA_SLOTS=['cam1','cam2','drone','replay'];
function cameraRoleLabel(role){return CAMERA_ROLE_LABELS[role]||role||'未定义'}
function cameraRoleKey(slot){return slot+'Role'}
function cameraRoleOf(slot){return vmixDirectorSettings[cameraRoleKey(slot)]||({cam1:'MAIN_WIDE',cam2:'SIDELINE_CLOSE',drone:'DRONE',replay:'REPLAY'})[slot]||'MAIN_WIDE'}
function cameraSlotForRole(role,fallback=''){
 vdSave();const hit=CAMERA_SLOTS.find(slot=>String(vmixDirectorSettings[slot]||'').trim()&&cameraRoleOf(slot)===role);return hit||fallback
}
function cameraRoleAvailable(role){return !!cameraSlotForRole(role,'')}
function cameraRoleSlotLabel(slot){return cameraRoleLabel(cameraRoleOf(slot))+' · '+String(slot||'').toUpperCase()}
function refreshCameraRoleUI(){
 const pairs=[['cam1','vdCam1Role','vdTakeCam1','vdPreviewCam1','mmCam1'],['cam2','vdCam2Role','vdTakeCam2','vdPreviewCam2','mmCam2'],['drone','vdDroneRole','vdTakeDrone','vdPreviewDrone','mmDrone'],['replay','vdReplayRole','vdTakeReplay','vdPreviewReplay','mmReplay']];
 for(const [slot,selectId,takeId,previewId,mmId] of pairs){
  const role=cameraRoleOf(slot),input=String(vmixDirectorSettings[slot]||'').trim(),available=!!input,sel=q(selectId);if(sel)sel.value=role;
  const take=q(takeId);if(take){take.disabled=!available;take.dataset.input=input;const b=take.querySelector('b'),sp=take.querySelector('span');if(b)b.textContent=input||'—';if(sp)sp.textContent=cameraRoleLabel(role)}
  const prev=q(previewId);if(prev){prev.disabled=!available;prev.textContent=available?('预监 · '+cameraRoleLabel(role)+' · Input '+input):('预监 · '+cameraRoleLabel(role)+' · 未分配')}
  const mm=q(mmId);if(mm){mm.disabled=!available;mm.textContent=(input||'—')+' '+cameraRoleLabel(role)}
 }
 const summary=q('cameraRoleSummary');if(summary){const active=CAMERA_SLOTS.filter(slot=>String(vmixDirectorSettings[slot]||'').trim());summary.textContent=active.length?(active.map(slot=>'Input '+String(vmixDirectorSettings[slot])+' '+cameraRoleLabel(cameraRoleOf(slot))).join(' · ')): '没有可用机位'}
}
let vmixInputCatalog=[];
function vmixInputText(x){
 const n=String(x&&x.number||''),title=String(x&&x.title||'').trim(),type=String(x&&x.type||'').trim();
 return 'Input '+n+(title?' · '+title:'')+(type&&type.toLowerCase()!==title.toLowerCase()?' · '+type:'')
}
function vmixIsBrowser(x){return /browser|web/i.test(String(x&&x.type||'')+' '+String(x&&x.title||''))}
function vmixIsReplay(x){return /replay/i.test(String(x&&x.type||'')+' '+String(x&&x.title||''))}
function vmixIsDrone(x){return /drone|uav|无人机|航拍/i.test(String(x&&x.type||'')+' '+String(x&&x.title||''))}
function vmixIsLikelyCamera(x){
 const t=String(x&&x.type||'')+' '+String(x&&x.title||'');
 return !vmixIsBrowser(x)&&!vmixIsReplay(x)&&/camera|capture|webcam|integrated|ndi|decklink|hdmi|usb|avermedia|blackmagic|摄像|采集/i.test(t)
}
function vdEnsureSelectValue(id,value){
 const el=q(id);if(!el)return;value=String(value||'');
 if(value&&![...el.options].some(o=>o.value===value)){const o=document.createElement('option');o.value=value;o.textContent='Input '+value+' · 已保存';el.appendChild(o)}
 el.value=value
}
function vdPopulateInputSelect(id,inputs,selected){
 const el=q(id);if(!el)return;const current=String(selected??el.value??'');el.innerHTML='<option value="">未分配</option>';
 for(const x of inputs){const o=document.createElement('option');o.value=String(x.number||'');o.textContent=vmixInputText(x);el.appendChild(o)}
 if(current&&![...el.options].some(o=>o.value===current)){const o=document.createElement('option');o.value=current;o.textContent='Input '+current+' · 当前已保存 / vMix 未找到';el.appendChild(o)}
 el.value=current
}
function vdRenderInputChips(info){
 const box=q('vdInputList');if(!box)return;const inputs=Array.isArray(info&&info.inputs)?info.inputs:[],active=String(info&&info.active||'');
 if(!inputs.length){box.innerHTML='';return}
 box.innerHTML=inputs.map(x=>{const n=String(x.number||''),cls=(vmixIsBrowser(x)?' graphics':'')+(n===active?' live':'');return '<span class="vmixInputChip'+cls+'"><b>'+esc(n)+'</b>'+esc(String(x.title||x.type||'Input'))+(n===active?' · PGM':'')+'</span>'}).join('')
}
function vdAutoMapFromInputs(info,force=false){
 const inputs=Array.isArray(info&&info.inputs)?info.inputs:[];if(!inputs.length)return false;
 const byNum=n=>inputs.find(x=>String(x.number)===String(n)),numbers=new Set(inputs.map(x=>String(x.number)));
 const browsers=inputs.filter(vmixIsBrowser),replays=inputs.filter(vmixIsReplay),drones=inputs.filter(vmixIsDrone);
 const graphics=browsers.find(x=>/127\.0\.0\.1|sagi|vmix|browser/i.test(String(x.title||'')))||browsers[0]||null;
 const cameras=inputs.filter(x=>!vmixIsBrowser(x)&&!vmixIsReplay(x)&&!vmixIsDrone(x)&&vmixIsLikelyCamera(x));
 const active=inputs.find(x=>String(x.number)===String(info&&info.active||''));
 const preferredMain=(active&&!vmixIsBrowser(active)&&!vmixIsReplay(active)?active:null)||cameras[0]||inputs.find(x=>!vmixIsBrowser(x)&&!vmixIsReplay(x))||null;
 const current={cam1:String(vmixDirectorSettings.cam1||''),cam2:String(vmixDirectorSettings.cam2||''),drone:String(vmixDirectorSettings.drone||''),replay:String(vmixDirectorSettings.replay||''),graphics:String(vmixDirectorSettings.graphics||'')};
 const currentGraphics=byNum(current.graphics),currentMain=byNum(current.cam1);
 const badGraphics=!currentGraphics||!vmixIsBrowser(currentGraphics),badMain=!currentMain||vmixIsBrowser(currentMain)||vmixIsReplay(currentMain);
 const conflict=current.graphics&&[current.cam1,current.cam2,current.drone,current.replay].includes(current.graphics);
 const needsRepair=badGraphics||badMain||conflict;
 if(!force&&!needsRepair)return false;
 const used=new Set();
 const main=preferredMain;if(main)used.add(String(main.number));
 const drone=drones.find(x=>!used.has(String(x.number)))||null;if(drone)used.add(String(drone.number));
 const replay=replays.find(x=>!used.has(String(x.number)))||null;if(replay)used.add(String(replay.number));
 const second=cameras.find(x=>!used.has(String(x.number)))||inputs.find(x=>!used.has(String(x.number))&&!vmixIsBrowser(x)&&!vmixIsReplay(x)&&!vmixIsDrone(x))||null;
 vmixDirectorSettings.cam1=main?String(main.number):'';
 vmixDirectorSettings.cam2=second?String(second.number):'';
 vmixDirectorSettings.drone=drone?String(drone.number):'';
 vmixDirectorSettings.replay=replay?String(replay.number):'';
 vmixDirectorSettings.graphics=graphics?String(graphics.number):'';
 vmixDirectorSettings.cam1Role='MAIN_WIDE';vmixDirectorSettings.cam2Role='SIDELINE_CLOSE';vmixDirectorSettings.droneRole='DRONE';vmixDirectorSettings.replayRole='REPLAY';
 return true
}
async function vdReadVmixInputs(forceAutoMap=false){
 const status=q('vdAutoReadStatus');if(status){status.textContent='正在读取 vMix Input…';status.className='vmixDiscoverStatus'}
 try{
  const h=await lanJson('/health?inputs='+Date.now()),info=h&&h.vmixInfo||{},inputs=Array.isArray(info.inputs)?info.inputs:[];
  if(!h||!h.vmix||!inputs.length)throw new Error('vMix 未连接或没有 Input');
  vmixInputCatalog=inputs;
  const repaired=vdAutoMapFromInputs(info,!!forceAutoMap);
  vdPopulateInputSelect('vdCam1',inputs,vmixDirectorSettings.cam1);vdPopulateInputSelect('vdCam2',inputs,vmixDirectorSettings.cam2);vdPopulateInputSelect('vdDrone',inputs,vmixDirectorSettings.drone);vdPopulateInputSelect('vdReplay',inputs,vmixDirectorSettings.replay);vdPopulateInputSelect('vdGraphics',inputs,vmixDirectorSettings.graphics);
  q('vdCam1Role').value=vmixDirectorSettings.cam1Role||'MAIN_WIDE';q('vdCam2Role').value=vmixDirectorSettings.cam2Role||'SIDELINE_CLOSE';q('vdDroneRole').value=vmixDirectorSettings.droneRole||'DRONE';q('vdReplayRole').value=vmixDirectorSettings.replayRole||'REPLAY';
  vdSave();refreshCameraRoleUI();vdRenderInputChips(info);sdRecommend(null);
  const g=inputs.find(x=>String(x.number)===String(vmixDirectorSettings.graphics)),m=inputs.find(x=>String(x.number)===String(vmixDirectorSettings.cam1));
  if(status){status.textContent='已读取 '+inputs.length+' 个 Input'+(repaired?' · 已自动完成映射':' · 映射已确认')+(m?' · 主机位 '+m.number:'')+(g?' · 图形 '+g.number:'');status.className='vmixDiscoverStatus good'}
  q('vdStatus').textContent='LAN READY · vMix 输入已读取';
  if(forceAutoMap)note('vMix 输入已自动识别并映射');
  return true
 }catch(e){
  if(status){status.textContent='读取失败 · 请确认 vMix Web Controller 8088 已开启';status.className='vmixDiscoverStatus warn'}q('vdStatus').textContent='vMix 输入读取失败';return false
 }
}
function vdSave(){
 vmixDirectorSettings={cam1:q('vdCam1').value.trim()||'1',cam2:q('vdCam2').value.trim(),drone:q('vdDrone').value.trim(),replay:q('vdReplay').value.trim(),graphics:q('vdGraphics').value.trim(),transition:q('vdTransition').value||'Cut',duration:Math.max(0,Number(q('vdDuration').value)||0),overlay:q('vdOverlay').value||'1',cam1Role:q('vdCam1Role').value||'MAIN_WIDE',cam2Role:q('vdCam2Role').value||'SIDELINE_CLOSE',droneRole:q('vdDroneRole').value||'DRONE',replayRole:q('vdReplayRole').value||'REPLAY'};
 try{localStorage.setItem('sagi_vmix_director_v42',JSON.stringify(vmixDirectorSettings))}catch(e){}
}
function vdLoad(){
 try{const x=JSON.parse(localStorage.getItem('sagi_vmix_director_v42')||'null');if(x)vmixDirectorSettings={...vmixDirectorSettings,...x}}catch(e){}
 vdEnsureSelectValue('vdCam1',vmixDirectorSettings.cam1);vdEnsureSelectValue('vdCam2',vmixDirectorSettings.cam2);vdEnsureSelectValue('vdDrone',vmixDirectorSettings.drone);vdEnsureSelectValue('vdReplay',vmixDirectorSettings.replay);vdEnsureSelectValue('vdGraphics',vmixDirectorSettings.graphics);
 q('vdTransition').value=vmixDirectorSettings.transition;q('vdDuration').value=vmixDirectorSettings.duration;q('vdOverlay').value=vmixDirectorSettings.overlay;q('vdCam1Role').value=vmixDirectorSettings.cam1Role||'MAIN_WIDE';q('vdCam2Role').value=vmixDirectorSettings.cam2Role||'SIDELINE_CLOSE';q('vdDroneRole').value=vmixDirectorSettings.droneRole||'DRONE';q('vdReplayRole').value=vmixDirectorSettings.replayRole||'REPLAY';refreshCameraRoleUI();
}
function vdInput(slot){vdSave();return vmixDirectorSettings[slot]||''}
async function publishVmixDirector(functionName,input='',duration=0,label='',value=''){
 const cmd={commandId:Date.now()+'_'+Math.random().toString(36).slice(2,7),functionName,input:String(input||''),duration:Math.max(0,Number(duration)||0),value:String(value??''),label,issuedAt:new Date().toISOString(),version:'V4.30.8-LAN'};
 q('vdStatus').textContent='LAN 发送中 · '+(label||functionName);
 try{
   await lanPost('/api/vmix',cmd);
   q('vdStatus').textContent='LAN 已执行 · '+(label||functionName);
   return true;
 }catch(e){
   q('vdStatus').textContent='LAN 执行失败 · 检查 Bridge';
   return false;
 }
}

async function vdTake(slot){
 if(gdAutoCameraActive){gdClearCameraTimers();gdAutoCameraActive=false;gdSetStatus('MANUAL CAMERA OVERRIDE','manual')}
 if(!requireMatchReady())return false;vdSave();
 if(!vdSlotAvailable(slot)){note('该机位未分配，不能切换');refreshCameraRoleUI();return false}
 const current=shotSafetyState.currentSlot||'',targetRole=cameraRoleOf(slot),currentRole=current?cameraRoleOf(current):'';
 smartCue={slot,role:targetRole,title:'手动 · '+cameraRoleLabel(targetRole),reason:'你已手动接管导播',confidence:100,eventType:'MANUAL'};sdRender();
 if(targetRole==='REPLAY'&&currentRole!=='REPLAY')return replayStingerTake(slot,'IN','MANUAL','PROGRAM REPLAY · LOGO STINGER');
 if(currentRole==='REPLAY'&&targetRole!=='REPLAY')return replayStingerTake(slot,'OUT','MANUAL','RETURN LIVE · LOGO STINGER');
 return ssTake(slot,'PROGRAM '+slot.toUpperCase(),'MANUAL',true,'MANUAL');
}
function vdPreview(slot){vdSave();if(!vdSlotAvailable(slot)){note('该机位未分配，不能预监');refreshCameraRoleUI();return false}return publishVmixDirector('PreviewInput',vdInput(slot),0,'PREVIEW '+slot.toUpperCase())}
function vdOverlayIn(){if(!requireMatchReady())return;vdSave();matchdayState.overlayVisible=true;mdPersist();publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'图形开启')}
function vdOverlayOut(){vdSave();matchdayState.overlayVisible=false;mdPersist();publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'Out','',0,'图形关闭')}
async function directVmixBrowserReload(input){
 const host=location.hostname||'127.0.0.1',url='http://'+host+':8088/api/?Function=BrowserReload&Input='+encodeURIComponent(input)+'&_='+Date.now();
 try{await fetch(url,{mode:'no-cors',cache:'no-store'});return true}catch(e){}
 return await new Promise(resolve=>{
   let done=false;const finish=ok=>{if(done)return;done=true;try{frame.remove()}catch(e){}resolve(ok)};
   const frame=document.createElement('iframe');frame.style.display='none';frame.onload=()=>finish(true);frame.onerror=()=>finish(false);frame.src=url;document.body.appendChild(frame);setTimeout(()=>finish(true),1200)
 })
}
async function refreshGraphicsBrowser(showNote=true){
 vdSave();const input=String(vmixDirectorSettings.graphics||'').trim();
 if(!input){if(showNote)note('请先设置图形输入编号');return false}
 let ok=false;
 try{
   const cmd={commandId:Date.now()+'_'+Math.random().toString(36).slice(2,7),functionName:'BrowserReload',input:String(input),duration:0,value:'',label:'刷新直播图形',issuedAt:new Date().toISOString(),version:'V4.30.8-LAN'};
   const r=await lanPost('/api/vmix',cmd);ok=!!r
 }catch(e){}
 if(!ok){
   q('vdStatus').textContent='旧版 Bridge · 正在直连刷新 vMix 图形';
   ok=await directVmixBrowserReload(input);
 }
 if(ok){
   q('vdStatus').textContent='直播图形刷新指令已发送 · Input '+input;
   if(showNote)note('直播图形已发送刷新 · Input '+input)
 }else{
   q('vdStatus').textContent='图形刷新失败 · 检查 vMix Web Controller 8088';
   if(showNote)note('无法刷新直播图形 · 请检查 vMix Web Controller 8088')
 }
 return !!ok
}
function sagiDelay(ms){return new Promise(r=>setTimeout(r,ms))}
function initVmixDirector(){
 vdLoad();
 if(q('vdAutoReadInputs'))q('vdAutoReadInputs').onclick=()=>vdReadVmixInputs(true);
 vdReadVmixInputs(false);
 document.querySelectorAll('[data-vd-take]').forEach(b=>b.onclick=()=>vdTake(b.dataset.vdTake));
 document.querySelectorAll('[data-vd-preview]').forEach(b=>b.onclick=()=>vdPreview(b.dataset.vdPreview));
 q('vdGraphicsIn').onclick=vdOverlayIn;q('vdGraphicsOut').onclick=vdOverlayOut;q('vdReloadGraphics').onclick=()=>refreshGraphicsBrowser(true);q('vdAllOverlaysOff').onclick=()=>publishVmixDirector('OverlayInputAllOff','','0','ALL OVERLAYS OFF');q('vdTest').onclick=()=>vdPreview('cam1');
 ['vdCam1','vdCam2','vdDrone','vdReplay','vdGraphics','vdTransition','vdDuration','vdOverlay','vdCam1Role','vdCam2Role','vdDroneRole','vdReplayRole'].forEach(id=>q(id).addEventListener('change',()=>{vdSave();refreshCameraRoleUI();sdRecommend(null)}));
 addEventListener('keydown',e=>{const tag=(e.target&&e.target.tagName)||'';if(tag==='INPUT'||tag==='SELECT'||tag==='TEXTAREA')return;if(e.key==='1')vdTake('cam1');else if(e.key==='2')vdTake('cam2');else if(e.key==='3')vdTake('drone');else if(e.key==='4')vdTake('replay');else if(e.key.toLowerCase()==='g')vdOverlayIn();else if(e.key.toLowerCase()==='x')vdOverlayOut();else if(e.key.toLowerCase()==='a')ssAttackLock()});
 const params=new URLSearchParams(location.search);if(params.has('safe')||params.has('homescreen'))setTimeout(()=>refreshGraphicsBrowser(false),900);
}

function note(t){const n=q('notice');n.textContent=t;n.style.display='block';clearTimeout(note.t);note.t=setTimeout(()=>n.style.display='none',1500)}
function esc(s){return String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function uid(){return'p_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,8)}
function openDB(){return new Promise((res,rej)=>{const r=indexedDB.open('sagi_player_intro_v2_assets',1);r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains('assets'))r.result.createObjectStore('assets')};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)})}
async function dbPut(k,v){try{const db=await openDB();await new Promise((res,rej)=>{const tx=db.transaction('assets','readwrite');tx.objectStore('assets').put(v,k);tx.oncomplete=res;tx.onerror=()=>rej(tx.error)});db.close()}catch(e){}}
async function dbGet(k){try{const db=await openDB();const v=await new Promise(res=>{const tx=db.transaction('assets','readonly'),r=tx.objectStore('assets').get(k);r.onsuccess=()=>res(r.result||'');r.onerror=()=>res('')});db.close();return v}catch(e){return''}}
async function dbDel(k){try{const db=await openDB();await new Promise(res=>{const tx=db.transaction('assets','readwrite');tx.objectStore('assets').delete(k);tx.oncomplete=res;tx.onerror=res});db.close()}catch(e){}}
async function dbPutMany(entries=[]){
 const list=(entries||[]).filter(x=>Array.isArray(x)&&x[0]);
 if(!list.length)return;
 try{
  const db=await openDB();
  await new Promise((res,rej)=>{const tx=db.transaction('assets','readwrite'),store=tx.objectStore('assets');for(const [k,v] of list)store.put(v,k);tx.oncomplete=res;tx.onerror=()=>rej(tx.error);tx.onabort=()=>rej(tx.error)});
  db.close()
 }catch(e){}
}
async function dbDelMany(keys=[]){
 const list=(keys||[]).filter(Boolean);if(!list.length)return;
 try{
  const db=await openDB();
  await new Promise(res=>{const tx=db.transaction('assets','readwrite'),store=tx.objectStore('assets');for(const k of list)store.delete(k);tx.oncomplete=res;tx.onerror=res;tx.onabort=res});
  db.close()
 }catch(e){}
}
function fileData(file,max=1100,quality=.82){return new Promise((res,rej)=>{const r=new FileReader();r.onerror=rej;r.onload=()=>{const im=new Image();im.onerror=()=>res(r.result);im.onload=()=>{const ratio=Math.min(1,max/im.width,max/im.height),w=Math.max(1,Math.round(im.width*ratio)),h=Math.max(1,Math.round(im.height*ratio)),cv=document.createElement('canvas');cv.width=w;cv.height=h;const cx=cv.getContext('2d');cx.clearRect(0,0,w,h);cx.drawImage(im,0,0,w,h);try{res(cv.toDataURL('image/webp',quality))}catch(e){res(r.result)}};im.src=r.result};r.readAsDataURL(file)})}
function displayRoleLabel(v){const x=String(v||'').toUpperCase();return({GK:'门将',DF:'后卫',MF:'中场',FW:'前锋',SUB:'替补',CB:'中后卫',LB:'左后卫',RB:'右后卫',DM:'后腰',CM:'中场',AM:'前腰',LW:'左边锋',RW:'右边锋',ST:'前锋'})[x]||String(v||'')}
function sideLabel(side){return side==='AWAY'?'客队':'主队'}
function currentTeamName(){return activeSide==='AWAY'?(q('matchAway').value.trim()||q('teamName').value.trim()||'AWAY'):(q('matchHome').value.trim()||q('teamName').value.trim()||'HOME')}
function stashActiveTeam(){
 const t=teamStore[activeSide];t.roster=roster;t.formation=q('formation').value||defaultFormationForCount(starterLimit());t.crest=assets.crest||'';if(!t.customPositions)t.customPositions={};
}
function refreshSideUI(){
 q('homeSideBtn').classList.toggle('on',activeSide==='HOME');q('awaySideBtn').classList.toggle('on',activeSide==='AWAY');
 q('activeSideBadge').textContent=sideLabel(activeSide);q('rosterSideText').textContent=sideLabel(activeSide);q('stage').dataset.side=activeSide;
 if(typeof refreshUXDashboard==='function')refreshUXDashboard();
}
function switchTeam(side,opts={}){
 if(side!=='HOME'&&side!=='AWAY')return;if(!opts.skipStash)stashActiveTeam();activeSide=side;const t=teamStore[side];
 reconcileTeamStarters(side,t.formation);roster=t.roster||[];refreshFormationOptions(t.formation||defaultFormationForCount(starterLimit()));assets.crest=t.crest||'';
 q('teamName').value=side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY');
 selected=roster.length?0:-1;if(selected>=0)writePlayer(roster[0]);else{assets.photo='';assets.mediaBlob=null;assets.mediaObjectUrl='';renderPreviews()}
 refreshSideUI();updateFormatUI();updateFormationEditorUI();q('stage').dataset.side=activeSide;renderRoster();renderPreviews();if(!opts.noRender)renderStage(currentGroup);if(!opts.silent)note('已切换到 '+sideLabel(side))
}

let uxSaveTimer=null;
function uxTeamStats(side){
 const t=teamStore[side]||{roster:[],formation:defaultFormationForCount(starterLimit())},list=t.roster||[],formation=t.formation||defaultFormationForCount(starterLimit());
 const valid=effectiveStarters(list,formation),photos=list.filter(p=>p.photo).length,subs=list.filter(p=>p.squadType==='SUB').length;
 return{total:list.length,valid:valid.length,photos,subs,limit:starterLimit()}
}
function refreshUXDashboard(){
 if(!q('homeRosterMini'))return;
 const h=uxTeamStats('HOME'),a=uxTeamStats('AWAY'),cur=activeSide==='AWAY'?a:h;
 q('homeRosterMini').textContent=h.total+' 人 · 首发 '+h.valid+'/'+h.limit+' · 📷 '+h.photos;
 q('awayRosterMini').textContent=a.total+' 人 · 首发 '+a.valid+'/'+a.limit+' · 📷 '+a.photos;
 q('currentTeamQuick').textContent=sideLabel(activeSide);q('currentStarterQuick').textContent=cur.valid+'/'+cur.limit;q('currentPhotoQuick').textContent=cur.photos+'/'+cur.total;q('currentBenchQuick').textContent=String(cur.subs);
 q('importTargetBadge').textContent=sideLabel(activeSide);
 q('mobileHomeBtn')&&q('mobileHomeBtn').classList.toggle('on',activeSide==='HOME');q('mobileAwayBtn')&&q('mobileAwayBtn').classList.toggle('on',activeSide==='AWAY');
 const infoOK=!!(q('matchCompetition').value.trim()&&q('matchHome').value.trim()&&q('matchAway').value.trim()&&q('matchHome').value.trim()!==q('matchAway').value.trim()),infoWarn=!(q('matchKickoff').value.trim()&&q('matchVenue').value.trim());
 const homeOK=h.valid===h.limit,awayOK=a.valid===a.limit;
 q('uxStepMatch').classList.toggle('done',infoOK);q('uxStepHome').classList.toggle('done',homeOK);q('uxStepAway').classList.toggle('done',awayOK);q('uxStepReady').classList.toggle('done',!!matchReady);
 const activeStep=!infoOK?'MATCH':(!homeOK?'HOME':(!awayOK?'AWAY':'READY'));
 q('uxStepMatch').classList.toggle('active',activeStep==='MATCH');q('uxStepHome').classList.toggle('active',activeStep==='HOME');q('uxStepAway').classList.toggle('active',activeStep==='AWAY');q('uxStepReady').classList.toggle('active',activeStep==='READY');
 q('uxHomeMeta').textContent='首发 '+h.valid+'/'+h.limit+' · 照片 '+h.photos+'/'+h.total;q('uxAwayMeta').textContent='首发 '+a.valid+'/'+a.limit+' · 照片 '+a.photos+'/'+a.total;
 q('uxMatchMeta').textContent=infoOK?(infoWarn?'核心信息已完成 · 时间/场地可后补':'比赛信息已完成'):'赛事 / 主队 / 客队待完善';q('uxReadyMeta').textContent=matchReady?'可以播出':'等待赛前检查';
 ['currentStarterQuick','currentPhotoQuick'].forEach(id=>{const el=q(id);if(el&&el.parentElement)el.parentElement.classList.toggle('good',id==='currentStarterQuick'?cur.valid===cur.limit:(cur.total>0&&cur.photos===cur.total))});
}
function uxQueueAutoSave(){
 clearTimeout(uxSaveTimer);uxSaveTimer=setTimeout(()=>{saveCurrentSideRoster(true).catch(()=>{})},350)
}
function initUXV49(){
 refreshUXDashboard();
 q('uxStepMatch').onclick=()=>q('setupDesk').scrollIntoView({behavior:'smooth',block:'start'});
 q('uxStepHome').onclick=()=>{switchTeam('HOME');q('teamCard').scrollIntoView({behavior:'smooth',block:'start'})};
 q('uxStepAway').onclick=()=>{switchTeam('AWAY');q('teamCard').scrollIntoView({behavior:'smooth',block:'start'})};
 q('uxStepReady').onclick=()=>{q('setupDesk').scrollIntoView({behavior:'smooth',block:'start'});setTimeout(()=>q('setupValidateBtn').click(),250)};
 q('jumpRosterBtn').onclick=()=>q('rosterCard').scrollIntoView({behavior:'smooth',block:'start'});
 q('quickValidateBtn').onclick=()=>{q('setupDesk').scrollIntoView({behavior:'smooth',block:'start'});setTimeout(()=>q('setupValidateBtn').click(),250)};
 q('mobileHomeBtn').onclick=()=>switchTeam('HOME');q('mobileAwayBtn').onclick=()=>switchTeam('AWAY');
 q('mobileRosterBtn').onclick=()=>q('rosterCard').scrollIntoView({behavior:'smooth',block:'start'});
 q('mobileCheckBtn').onclick=()=>{q('setupDesk').scrollIntoView({behavior:'smooth',block:'start'});setTimeout(()=>q('setupValidateBtn').click(),250)};
 ['addBtn','updateBtn','removeBtn','rosterCommitImport'].forEach(id=>q(id)&&q(id).addEventListener('click',()=>setTimeout(()=>{refreshUXDashboard();uxQueueAutoSave()},180)));
 ['matchCompetition','matchHome','matchAway','matchKickoff','matchVenue'].forEach(id=>q(id)&&q(id).addEventListener('input',refreshUXDashboard));
 q('formation')&&q('formation').addEventListener('change',()=>{refreshUXDashboard();uxQueueAutoSave()});
}

let rosterImportDraft=[],rosterImportSeq=0,rosterImportTeamMeta={name:'',crest:'',source:'',photoCount:0};
const RI_LIBS={
 xlsx:'https://cdn.sheetjs.com/xlsx-0.20.3/package/dist/xlsx.full.min.js',
 mammoth:'https://cdnjs.cloudflare.com/ajax/libs/mammoth/1.13.0/mammoth.browser.min.js',
 tesseract:'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js',
 jszip:'https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js'
};
function riStatus(text,kind=''){const el=q('rosterImportStatus');if(!el)return;el.textContent=text;el.className='riStatus'+(kind?' '+kind:'')}
function riLoadScript(src,globalName,timeout=20000){
 if(globalName&&window[globalName])return Promise.resolve(window[globalName]);
 return new Promise((resolve,reject)=>{
   const found=[...document.scripts].find(s=>s.src===src);if(found){const t=setInterval(()=>{if(!globalName||window[globalName]){clearInterval(t);resolve(globalName?window[globalName]:true)}},100);setTimeout(()=>{clearInterval(t);reject(new Error('模块加载超时'))},timeout);return}
   const s=document.createElement('script');s.src=src;s.async=true;s.crossOrigin='anonymous';
   const timer=setTimeout(()=>{s.remove();reject(new Error('模块加载超时'))},timeout);
   s.onload=()=>{clearTimeout(timer);if(globalName&&!window[globalName])reject(new Error('模块未初始化'));else resolve(globalName?window[globalName]:true)};
   s.onerror=()=>{clearTimeout(timer);reject(new Error('模块下载失败'))};document.head.appendChild(s);
 })
}
function riExt(name=''){const m=String(name).toLowerCase().match(/\.([a-z0-9]+)$/);return m?m[1]:''}
function riClean(s){return String(s==null?'':s).replace(/[\u200b\ufeff]/g,'').replace(/\s+/g,' ').trim()}
function riRoleFrom(s=''){
 const x=String(s).toUpperCase();
 if(/门将|守门|GOAL|GK/.test(x))return'GK';
 if(/后卫|中卫|边后卫|DF|CB|LB|RB|LWB|RWB|BACK/.test(x))return'DF';
 if(/中场|前腰|后腰|MF|CM|CDM|DM|CAM|AM|LM|RM|MID/.test(x))return'MF';
 if(/前锋|边锋|FW|ST|CF|LW|RW|WG|FORWARD|STRIKER/.test(x))return'FW';
 return''
}
function riSquadFrom(s=''){const x=String(s).toUpperCase();return /替补|SUB|BENCH/.test(x)?'SUB':/首发|START|STARTER/.test(x)?'STARTER':''}
function riCaptainFrom(s=''){return /队长|CAPTAIN|(^|\s)C($|\s)|\(C\)|（C）/i.test(String(s))}
function riPositionFrom(s='',role=''){
 const x=String(s).toUpperCase();
 const tokens=['GK','CB','LB','RB','LWB','RWB','DM','CDM','CM','CAM','AM','LM','RM','LW','RW','ST','CF','FW','DF','MF'];
 for(const t of tokens)if(new RegExp('(^|[^A-Z])'+t+'([^A-Z]|$)').test(x))return t;
 if(/门将|守门/.test(s))return'GK';if(/中卫/.test(s))return'CB';if(/左后卫/.test(s))return'LB';if(/右后卫/.test(s))return'RB';if(/后腰/.test(s))return'DM';if(/前腰/.test(s))return'AM';if(/中场/.test(s))return'CM';if(/边锋/.test(s))return'WG';if(/前锋/.test(s))return'ST';return role||''
}
function riLooksHeader(s=''){return /姓名|球员|号码|编号|位置|首发|替补|name|number|no\.?|position|player/i.test(String(s))}
function riLikelyName(s=''){
 const x=riClean(s);if(!x||riLooksHeader(x)||/^\d{1,3}$/.test(x))return false;
 return /[\u3400-\u9fff\u0400-\u04ffA-Za-z·•'’-]/.test(x)&&x.length<=32
}
function riParseLine(line,index=0){
 let raw=riClean(line);if(!raw||riLooksHeader(raw)&&!/\d/.test(raw))return null;
 raw=raw.replace(/[，；;|]+/g,'\t');
 let cells=raw.split(/\t+/).map(riClean).filter(Boolean);
 if(cells.length<2)cells=raw.split(/\s{2,}/).map(riClean).filter(Boolean);
 if(cells.length<2)cells=raw.split(/\s+/).map(riClean).filter(Boolean);
 if(!cells.length)return null;
 let number='',name='',rest=[];
 const numIdx=cells.findIndex(x=>/^#?\d{1,3}$/.test(x));
 if(numIdx>=0){number=cells[numIdx].replace('#','');rest=cells.filter((_,i)=>i!==numIdx)}
 else rest=[...cells];
 const nameIdx=rest.findIndex(riLikelyName);
 if(nameIdx>=0){name=rest[nameIdx];rest.splice(nameIdx,1)}
 if(!name&&cells.length===1){const m=raw.match(/^#?(\d{1,3})\s*[-.、]?\s*(.+)$/);if(m){number=m[1];name=riClean(m[2]);rest=[]}}
 if(!name)return null;
 const meta=rest.join(' '),role=riRoleFrom(meta),position=riPositionFrom(meta,role),squadType=riSquadFrom(meta);
 return{use:true,number:number||String(index+1),name,role:role||'',position:position||'',squadType:squadType||'',captain:riCaptainFrom(raw),warning:(!number?'缺号码 · ':'')+(!role?'位置待确认':'')}
}

function riHeaderNorm(s=''){return riClean(s).toLowerCase().replace(/[\s_\-\/\\.（）()：:]+/g,'')}
const RI_HEADER_ALIASES={
 number:['号码','球衣号码','背号','no','number','jerseynumber','shirtno'],
 name:['姓名','球员姓名','球员','name','player','playername'],
 squad:['身份','名单身份','首发替补','首发/替补','status','squad','squadtype','starter'],
 role:['位置组','位置类别','role','positiongroup'],
 position:['详细位置','位置','position','pos'],
 captain:['队长','captain','iscaptain'],
 photo:['照片文件','照片文件名','照片','photo','photofile','image','imagefile'],
 team:['球队名称','球队','队名','teamname','team']
};
function riHeaderKey(v){
 const n=riHeaderNorm(v);for(const [k,arr] of Object.entries(RI_HEADER_ALIASES))if(arr.some(a=>riHeaderNorm(a)===n))return k;return''
}
function riSquadSmart(v=''){
 const s=riClean(v),x=s.toUpperCase();
 if(/替补|SUB|BENCH/.test(x)||/^(0|否|NO|N)$/i.test(s))return'SUB';
 if(/首发|START|STARTER/.test(x)||/^(1|是|YES|Y)$/i.test(s))return'STARTER';
 return riSquadFrom(s)
}
function riRowsFromSmartMatrix(matrix){
 let headerRow=-1,map={};
 for(let r=0;r<Math.min(12,matrix.length);r++){
   const m={};(matrix[r]||[]).forEach((v,i)=>{const k=riHeaderKey(v);if(k&&!Object.prototype.hasOwnProperty.call(m,k))m[k]=i});
   if(m.name!=null&&(m.number!=null||m.position!=null||m.role!=null)){headerRow=r;map=m;break}
 }
 if(headerRow<0)return riRowsFromMatrix(matrix);
 const out=[];
 for(let r=headerRow+1;r<matrix.length;r++){
   const row=(matrix[r]||[]).map(riClean),get=k=>(map[k]!=null?riClean(row[map[k]]):'');
   const name=get('name');if(!name||riLooksHeader(name))continue;
   const number=get('number')||String(out.length+1),roleRaw=get('role'),posRaw=get('position'),role=riRoleFrom(roleRaw)||riRoleFrom(posRaw),position=riPositionFrom(posRaw||roleRaw,role);
   const squadType=riSquadSmart(get('squad'))||'',photoRef=get('photo'),teamName=get('team');
   out.push({use:true,number,name,role:role||'',position:position||role||'',squadType,captain:riCaptainFrom(get('captain')),photoRef,teamName,warning:(!role?'位置待确认':'')})
 }
 return out.length?out:riRowsFromMatrix(matrix)
}
function riImageMime(name=''){const e=riExt(name);return e==='png'?'image/png':e==='webp'?'image/webp':(e==='gif'?'image/gif':'image/jpeg')}
function riZipStem(name=''){return String(name).split('/').pop().replace(/\.[^.]+$/,'')}
function riPhotoKey(s=''){return riHeaderNorm(String(s).replace(/^0+(?=\d)/,''))}
function riPhotoMatchScore(p,path){
 const stem=riZipStem(path),key=riPhotoKey(stem),nameKey=riPhotoKey(p.name),num=String(Number(p.number)||p.number||'').replace(/^0+/,'')||'0';
 if(p.photoRef){
   const explicit=riPhotoKey(riZipStem(p.photoRef));if(explicit&&explicit===key)return 100;
 }
 let score=0;
 const startNum=(stem.match(/^0*(\d{1,3})(?:[^0-9]|$)/)||[])[1];if(startNum&&String(Number(startNum))===String(Number(num)))score+=12;
 if(nameKey&&key.includes(nameKey))score+=10;
 if(nameKey&&nameKey===key)score+=5;
 return score
}
async function riRowsFromWorkbookBuffer(buf){
 await riLoadScript(RI_LIBS.xlsx,'XLSX',20000);
 const wb=XLSX.read(buf,{type:'array'}),sheet=wb.Sheets[wb.SheetNames[0]],matrix=XLSX.utils.sheet_to_json(sheet,{header:1,raw:false,defval:''});
 return riRowsFromSmartMatrix(matrix)
}
function riRowsFromJsonData(data){
 const list=Array.isArray(data)?data:(data.starting_xi||data.players||data.roster||[]);
 if(!Array.isArray(list)||!list.length)throw new Error('JSON 中没有球员数据');
 return list.map((p,i)=>{
   const pos=riClean(p.position_code||p.positionCode||p.position||p.pos||p.role||''),role=riRoleFrom(pos)||riRoleFrom(p.position||'')||'';
   const starter=(p.starter===true||p.starter===1||String(p.starter).toLowerCase()==='true'||String(p.squadType||'').toUpperCase()==='STARTER');
   return{use:p.use!==false,number:riClean(p.number||p.no||p.jersey_number||p.jerseyNumber)||String(i+1),name:riClean(p.name||p.player_name||p.playerName),role,position:pos||role,squadType:starter?'STARTER':(String(p.squadType||'').toUpperCase()==='SUB'?'SUB':'STARTER'),captain:!!p.captain,photo:String(p.photo||p.photo_data||p.photoData||p.image||''),photoRef:String(p.photo_file||p.photoFile||''),teamName:riClean(p.team_name||p.teamName||''),warning:''}
 }).filter(p=>p.name)
}
async function riReadTeamZip(file){
 if(file.size>120*1024*1024)throw new Error('ZIP 超过 120MB。请先压缩球员照片后重新打包');
 riStatus('正在打开球队 ZIP 资料包…','work');await riLoadScript(RI_LIBS.jszip,'JSZip',20000);
 const zip=await JSZip.loadAsync(await file.arrayBuffer()),entries=Object.values(zip.files).filter(x=>!x.dir&&!x.name.startsWith('__MACOSX/')&&!/\/\./.test(x.name));
 const rosterFiles=entries.filter(x=>['xlsx','xls','csv','tsv','txt','json'].includes(riExt(x.name)));
 if(!rosterFiles.length)throw new Error('ZIP 中没有找到 Excel/CSV/JSON 名单文件');
 const pri=e=>{const ext=riExt(e.name),base=/名单|roster|player|team/i.test(e.name)?20:0;return base+({xlsx:9,xls:8,csv:7,tsv:6,json:5,txt:4}[ext]||0)};
 rosterFiles.sort((a,b)=>pri(b)-pri(a));const rosterEntry=rosterFiles[0],ext=riExt(rosterEntry.name);let rows=[];
 if(['xlsx','xls'].includes(ext))rows=await riRowsFromWorkbookBuffer(await rosterEntry.async('arraybuffer'));
 else if(ext==='json')rows=riRowsFromJsonData(JSON.parse(await rosterEntry.async('string')));
 else rows=riParseText(await rosterEntry.async('string'));
 if(!rows.length)throw new Error('名单文件中没有识别到球员');
 const imageEntries=entries.filter(x=>['jpg','jpeg','png','webp'].includes(riExt(x.name)));
 const crest=imageEntries.find(x=>/队徽|logo|crest|badge/i.test(x.name));
 const playerImages=imageEntries.filter(x=>x!==crest);
 const used=new Set();
 for(const p of rows){
   let best=null,bestScore=0;
   for(const img of playerImages){if(used.has(img.name))continue;const s=riPhotoMatchScore(p,img.name);if(s>bestScore){bestScore=s;best=img}}
   if(best&&bestScore>=10){
     const blob=await best.async('blob'),tmp=new File([blob],riZipStem(best.name)+'.'+riExt(best.name),{type:riImageMime(best.name)});
     p.photo=await fileData(tmp,800,.82);p.warning='📷 已匹配';used.add(best.name)
   }else p.warning=(p.warning?p.warning+' · ':'')+'无照片'
 }
 const teamNames=rows.map(x=>riClean(x.teamName)).filter(Boolean),teamName=teamNames[0]||riClean(riZipStem(file.name).replace(/资料包|名单|roster/ig,''));
 let crestData='';if(crest){const blob=await crest.async('blob'),tmp=new File([blob],riZipStem(crest.name)+'.'+riExt(crest.name),{type:riImageMime(crest.name)});crestData=await fileData(tmp,600,.9)}
 const matched=rows.filter(x=>x.photo).length;rosterImportTeamMeta={name:teamName,crest:crestData,source:file.name,photoCount:matched};
 rows.forEach(p=>{if(!p.teamName&&teamName)p.teamName=teamName});
 riStatus('球队资料包已解析 · '+rows.length+' 人 · 照片 '+matched+'/'+rows.length+(crestData?' · 队徽 ✓':' · 无队徽')+'。请检查后确认替换 '+sideLabel(activeSide)+'。','ok');
 return rows
}
function riRowsFromMatrix(matrix){
 const out=[];for(let r=0;r<matrix.length;r++){
   const row=(matrix[r]||[]).map(riClean);if(!row.some(Boolean))continue;
   const joined=row.filter(Boolean).join('\t');const p=riParseLine(joined,out.length);if(p)out.push(p)
 }return out
}
function riParseText(text=''){
 const lines=String(text).replace(/\r/g,'\n').split(/\n+/).map(riClean).filter(Boolean),out=[];
 for(const line of lines){const p=riParseLine(line,out.length);if(p)out.push(p)}
 if(out.length<2){
   const chunks=String(text).split(/[;；]/).map(riClean).filter(Boolean);for(const ch of chunks){const p=riParseLine(ch,out.length);if(p)out.push(p)}
 }
 return out
}
function riAutoFillRoles(list=rosterImportDraft){
 const starters=list.filter(x=>x.use&&x.squadType!=='SUB'),need=formationRoleCounts(q('formation').value),left={...need};
 for(const p of starters)if(p.role&&left[p.role]>0)left[p.role]--;
 const order=[];for(const role of ['GK','DF','MF','FW'])for(let i=0;i<Math.max(0,left[role]||0);i++)order.push(role);
 let oi=0;for(const p of starters){if(!p.role){p.role=order[oi++]||'MF';p.position=p.position||p.role;p.warning=p.warning.replace('位置待确认','自动补位')}}
 for(const p of list.filter(x=>x.use&&x.squadType==='SUB')){if(!p.role){p.role=riRoleFrom(p.position)||'MF';p.position=p.position||p.role}}
 riRenderDraft()
}
function riSetDraft(rows,source=''){
 rosterImportDraft=(rows||[]).slice(0,40).map((p,i)=>({...p,use:p.use!==false,number:riClean(p.number)||String(i+1),name:riClean(p.name),squadType:p.squadType||'',role:p.role||'',position:p.position||'',captain:!!p.captain,warning:p.warning||''})).filter(p=>p.name);
 if(!rosterImportDraft.length){q('rosterImportPreview').classList.remove('on');riStatus('没有识别到有效球员。可换一张更清晰的照片，或使用“粘贴名单”。','bad');return}
 const limit=starterLimit();let starterCount=0;
 for(const p of rosterImportDraft){if(!p.squadType){p.squadType=starterCount<limit?'STARTER':'SUB'}if(p.squadType==='STARTER')starterCount++}
 q('rosterImportPreview').classList.add('on');q('riStarterLimit').textContent=limit;riRenderDraft();if(!rosterImportTeamMeta.source)riStatus('已识别 '+rosterImportDraft.length+' 人'+(source?' · '+source:'')+'。请先检查号码、姓名、首发/替补和位置，再确认导入。','ok')
}
function riRenderDraft(){
 const body=q('rosterImportBody');if(!body)return;body.innerHTML='';
 rosterImportDraft.forEach((p,i)=>{
   const tr=document.createElement('tr');tr.innerHTML=
   '<td><input class="riUse" type="checkbox" data-ri="use" data-i="'+i+'" '+(p.use?'checked':'')+'></td>'+
   '<td><input value="'+escAttr(p.number)+'" data-ri="number" data-i="'+i+'"></td>'+
   '<td><input value="'+escAttr(p.name)+'" data-ri="name" data-i="'+i+'"></td>'+
   '<td><select data-ri="squadType" data-i="'+i+'"><option value="STARTER" '+(p.squadType==='STARTER'?'selected':'')+'>首发</option><option value="SUB" '+(p.squadType==='SUB'?'selected':'')+'>替补</option></select></td>'+
   '<td><select data-ri="role" data-i="'+i+'"><option value="" '+(!p.role?'selected':'')+'>待定</option><option value="GK" '+(p.role==='GK'?'selected':'')+'>GK</option><option value="DF" '+(p.role==='DF'?'selected':'')+'>DF</option><option value="MF" '+(p.role==='MF'?'selected':'')+'>MF</option><option value="FW" '+(p.role==='FW'?'selected':'')+'>FW</option></select></td>'+
   '<td><input value="'+escAttr(p.position)+'" data-ri="position" data-i="'+i+'"></td>'+
   '<td><select data-ri="captain" data-i="'+i+'"><option value="0" '+(!p.captain?'selected':'')+'>否</option><option value="1" '+(p.captain?'selected':'')+'>C</option></select></td>'+
   '<td><span class="riWarn">'+esc(p.warning||'')+'</span></td>';body.appendChild(tr)
 });
 body.querySelectorAll('[data-ri]').forEach(el=>{el.onchange=()=>{const i=+el.dataset.i,k=el.dataset.ri;if(!rosterImportDraft[i])return;rosterImportDraft[i][k]=k==='use'?el.checked:k==='captain'?el.value==='1':el.value}});
 q('riCount').textContent=rosterImportDraft.filter(x=>x.use).length+' 人';
}
function riReadTextFile(file){return new Promise((res,rej)=>{const r=new FileReader();r.onerror=()=>rej(r.error);r.onload=()=>res(String(r.result||''));r.readAsText(file,'utf-8')})}
async function riReadJson(file){
 const raw=await riReadTextFile(file);let data;try{data=JSON.parse(raw)}catch(e){throw new Error('JSON 格式错误')}return riRowsFromJsonData(data)
}
async function riReadSpreadsheet(file){
 riStatus('正在加载 Excel 解析模块…','work');return riRowsFromWorkbookBuffer(await file.arrayBuffer())
}
async function riReadDocx(file){
 riStatus('正在加载 Word 解析模块…','work');await riLoadScript(RI_LIBS.mammoth,'mammoth',20000);const result=await mammoth.extractRawText({arrayBuffer:await file.arrayBuffer()});return riParseText(result.value||'')
}
async function riReadPdf(file){
 riStatus('正在加载 PDF 解析模块…','work');
 const pdfjs=await import('https://cdn.jsdelivr.net/npm/pdfjs-dist@6.5.438/build/pdf.min.mjs');pdfjs.GlobalWorkerOptions.workerSrc='https://cdn.jsdelivr.net/npm/pdfjs-dist@6.5.438/build/pdf.worker.min.mjs';
 const doc=await pdfjs.getDocument({data:new Uint8Array(await file.arrayBuffer())}).promise;let text='';
 for(let n=1;n<=doc.numPages;n++){const page=await doc.getPage(n),tc=await page.getTextContent();text+='\n'+tc.items.map(x=>x.str).join(' ')}
 return riParseText(text)
}
async function riImageCanvas(file){
 const url=URL.createObjectURL(file);try{
   const img=await new Promise((res,rej)=>{const im=new Image();im.onload=()=>res(im);im.onerror=()=>rej(new Error('照片无法读取'));im.src=url});
   const max=2400,scale=Math.min(1,max/Math.max(img.naturalWidth,img.naturalHeight)),cv=document.createElement('canvas');cv.width=Math.max(1,Math.round(img.naturalWidth*scale));cv.height=Math.max(1,Math.round(img.naturalHeight*scale));
   const cx=cv.getContext('2d',{willReadFrequently:true});cx.drawImage(img,0,0,cv.width,cv.height);const d=cx.getImageData(0,0,cv.width,cv.height),a=d.data;
   for(let i=0;i<a.length;i+=4){const y=.299*a[i]+.587*a[i+1]+.114*a[i+2],v=Math.max(0,Math.min(255,(y-128)*1.35+128));a[i]=a[i+1]=a[i+2]=v}cx.putImageData(d,0,0);return cv
 }finally{URL.revokeObjectURL(url)}
}
async function riReadImage(file){
 riStatus('正在加载照片文字识别模块…首次使用需要联网下载 OCR 组件。','work');await riLoadScript(RI_LIBS.tesseract,'Tesseract',30000);const cv=await riImageCanvas(file);
 const worker=await Tesseract.createWorker('chi_sim+eng',1,{logger:m=>{if(m&&m.status){const pct=Number.isFinite(m.progress)?' '+Math.round(m.progress*100)+'%':'';riStatus('照片识别：'+m.status+pct,'work')}}});
 try{const r=await worker.recognize(cv);return riParseText(r.data&&r.data.text||'')}finally{await worker.terminate()}
}

async function riDownloadTeamTemplate(){
 try{
  riStatus('正在生成球队填报模板…','work');await riLoadScript(RI_LIBS.xlsx,'XLSX',20000);
  const header=['球队名称','号码','姓名','首发/替补','位置组','详细位置','队长','照片文件名'];
  const sample=[
   ['示例足球队','1','张三','首发','GK','GK','否','01_张三.jpg'],
   ['示例足球队','4','李四','首发','DF','CB','是','04_李四.jpg'],
   ['示例足球队','8','王五','首发','MF','CM','否','08_王五.jpg'],
   ['示例足球队','9','赵六','首发','FW','ST','否','09_赵六.jpg'],
   ['示例足球队','18','阿力','替补','MF','CM','否','18_阿力.jpg']
  ];
  const ws=XLSX.utils.aoa_to_sheet([header,...sample]);ws['!cols']=[{wch:16},{wch:8},{wch:14},{wch:12},{wch:10},{wch:12},{wch:8},{wch:22}];
  const guide=XLSX.utils.aoa_to_sheet([
   ['SAGI 球队填报说明'],
   ['1','填写“名单”工作表，每名球员一行。'],
   ['2','位置组只填 GK / DF / MF / FW；详细位置可填 GK、CB、LB、RB、DM、CM、AM、LW、RW、ST 等。'],
   ['3','照片建议使用 JPG/PNG，文件名使用“号码_姓名.jpg”，例如 10_马尔胡兰.jpg。'],
   ['4','把 Excel、photos 文件夹、可选“队徽.png”放在同一个文件夹内，压缩成 ZIP 后发送。'],
   ['5','导播收到 ZIP 后：选择 HOME/AWAY → 导入球队资料包 → 检查照片匹配 → 确认替换。'],
   ['6','不要在同一个 ZIP 中放两支球队。建议单队 ZIP 控制在 120MB 以内。']
  ]);guide['!cols']=[{wch:6},{wch:88}];
  const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'名单');XLSX.utils.book_append_sheet(wb,guide,'填报说明');
  XLSX.writeFile(wb,'SAGI_球队大名单填报模板.xlsx');riStatus('球队填报模板已生成。填好后与 photos 文件夹、队徽一起压缩成 ZIP。','ok')
 }catch(e){riStatus('模板生成失败：'+(e&&e.message||'未知错误'),'bad')}
}
async function riHandleFile(file){
 if(!file)return;const seq=++rosterImportSeq,ext=riExt(file.name),type=String(file.type||'').toLowerCase();rosterImportTeamMeta={name:'',crest:'',source:'',photoCount:0};riStatus('读取 '+file.name+'…','work');
 try{
   let rows=[];
   if(ext==='zip'||type==='application/zip'||type==='application/x-zip-compressed')rows=await riReadTeamZip(file);
   else if(type.startsWith('image/')||['jpg','jpeg','png','webp','heic','heif'].includes(ext))rows=await riReadImage(file);
   else if(ext==='json'||type==='application/json')rows=await riReadJson(file);
   else if(['csv','tsv','txt'].includes(ext)||type.startsWith('text/'))rows=riParseText(await riReadTextFile(file));
   else if(['xlsx','xls'].includes(ext))rows=await riReadSpreadsheet(file);
   else if(ext==='docx')rows=await riReadDocx(file);
   else if(ext==='pdf'||type==='application/pdf')rows=await riReadPdf(file);
   else throw new Error('暂不支持此文件格式');
   if(seq!==rosterImportSeq)return;riSetDraft(rows,file.name)
 }catch(e){if(seq!==rosterImportSeq)return;riStatus('导入失败：'+(e&&e.message||'无法解析')+'。可改用“粘贴名单”作为稳定备用。','bad')}
}
function riCommit(){
 const selectedRows=rosterImportDraft.filter(p=>p.use&&riClean(p.name));if(!selectedRows.length){note('没有勾选球员');return}
 const limit=starterLimit(),starterRows=selectedRows.filter(p=>p.squadType==='STARTER');
 if(starterRows.length>limit){note('首发超过 '+limit+' 人，请先调整首发/替补');return}
 if(selectedRows.some(p=>!p.role)){note('还有球员“位置组”未确认');return}
 const seen=new Set(),next=[];
 for(const x of selectedRows){
   const key=(String(x.number)+'|'+String(x.name)).toLowerCase();if(seen.has(key))continue;seen.add(key);
   next.push({id:uid(),name:riClean(x.name),number:riClean(x.number)||'00',squadType:x.squadType||'SUB',role:x.role||'MF',position:riClean(x.position)||x.role||'MF',captain:!!x.captain,statLabel:'',statValue:'',photo:String(x.photo||''),mediaBlob:null,mediaObjectUrl:'',mediaUrl:'',mediaAction:'STANDARD',directorIn:0,directorOut:0,directorSpeed:1,directorFreeze:false,directorFreezeMs:1000,directorCamera:'MEDIUM'})
 }
 roster=next;teamStore[activeSide].roster=roster;
 if(rosterImportTeamMeta.name){if(activeSide==='AWAY')q('matchAway').value=rosterImportTeamMeta.name;else q('matchHome').value=rosterImportTeamMeta.name;q('teamName').value=rosterImportTeamMeta.name}
 if(rosterImportTeamMeta.crest){teamStore[activeSide].crest=rosterImportTeamMeta.crest;assets.crest=rosterImportTeamMeta.crest;dbPut('crest:'+activeSide,rosterImportTeamMeta.crest)}
 reconcileTeamStarters(activeSide,q('formation').value);
 selected=roster.length?0:-1;if(selected>=0)writePlayer(roster[0]);else{assets.photo='';assets.mediaBlob=null;assets.mediaObjectUrl='';renderPreviews()}
 renderRoster();updateFormatUI();refreshMatchdayPlayers();renderStage(currentGroup);mdPersist();
 const photoCount=roster.filter(p=>p.photo).length;
 riStatus('已替换 '+sideLabel(activeSide)+' 名单 · '+roster.length+' 人 · 照片 '+photoCount+'/'+roster.length+'。','ok');
 q('rosterImportPreview').classList.remove('on');rosterImportDraft=[];rosterImportTeamMeta={name:'',crest:'',source:'',photoCount:0};syncMatchStage();renderPreviews();if(typeof refreshUXDashboard==='function')refreshUXDashboard();if(typeof uxQueueAutoSave==='function')uxQueueAutoSave();note('名单替换完成 · '+roster.length+' 人 · 照片 '+photoCount)
}
function initRosterImport(){
 q('rosterPasteToggle').onclick=()=>q('rosterPaste').classList.toggle('on');q('rosterPasteClear').onclick=()=>{q('rosterPasteText').value=''};q('rosterTemplateBtn').onclick=riDownloadTeamTemplate;
 q('rosterParsePaste').onclick=()=>riSetDraft(riParseText(q('rosterPasteText').value),'粘贴文字');
 q('rosterCameraFile').onchange=e=>{const f=e.target.files&&e.target.files[0];riHandleFile(f);e.target.value=''};
 q('rosterImportFile').onchange=e=>{const f=e.target.files&&e.target.files[0];riHandleFile(f);e.target.value=''};
 q('riAllStarter').onclick=()=>{const limit=starterLimit();let n=0;for(const p of rosterImportDraft){if(!p.use)continue;p.squadType=n++<limit?'STARTER':'SUB'}riRenderDraft()};
 q('riAutoRole').onclick=()=>riAutoFillRoles();q('riClearDraft').onclick=()=>{rosterImportDraft=[];rosterImportTeamMeta={name:'',crest:'',source:'',photoCount:0};q('rosterImportPreview').classList.remove('on');riStatus('已取消本次导入。')};q('rosterCommitImport').onclick=riCommit
}
function readPlayer(){return{id:selected>=0&&roster[selected]?roster[selected].id:'',name:q('playerName').value.trim()||'PLAYER',number:q('playerNo').value.trim()||'00',squadType:q('squadType').value||'STARTER',role:q('role').value,position:q('position').value.trim()||q('role').value,captain:q('captain').value==='1',statLabel:q('statLabel').value.trim()||'',statValue:q('statValue').value.trim()||'',photo:assets.photo||'',mediaBlob:assets.mediaBlob||null,mediaObjectUrl:assets.mediaObjectUrl||'',mediaUrl:q('mediaUrl').value.trim()||'',mediaAction:q('mediaAction').value||'STANDARD',directorIn:Math.max(0,parseFloat(q('directorIn').value)||0),directorOut:Math.max(0,parseFloat(q('directorOut').value)||0),directorSpeed:parseFloat(q('directorSpeed').value)||1,directorFreeze:q('directorFreeze').value==='1',directorFreezeMs:parseInt(q('directorFreezeMs').value,10)||1000,directorCamera:q('directorCamera').value||'MEDIUM'}}
function writePlayer(p){q('playerName').value=p.name||'';q('playerNo').value=p.number||'';q('squadType').value=p.squadType||'STARTER';q('role').value=p.role||'MF';q('position').value=p.position||p.role||'';q('captain').value=p.captain?'1':'0';q('statLabel').value=p.statLabel||'';q('statValue').value=p.statValue||'';q('mediaUrl').value=p.mediaUrl||'';q('mediaAction').value=p.mediaAction||'STANDARD';q('directorIn').value=Number.isFinite(+p.directorIn)?+p.directorIn:0;q('directorOut').value=Number.isFinite(+p.directorOut)?+p.directorOut:0;q('directorSpeed').value=String(p.directorSpeed||1);q('directorFreeze').value=p.directorFreeze?'1':'0';q('directorFreezeMs').value=String(p.directorFreezeMs||1000);q('directorCamera').value=p.directorCamera||'MEDIUM';assets.photo=p.photo||'';assets.mediaBlob=p.mediaBlob||null;assets.mediaObjectUrl=p.mediaObjectUrl||'';renderPreviews()}
function packageData(){
 return{matchFormat:{mode:matchConfig.mode,playerCount:starterLimit()},competition:q('matchCompetition').value.trim()||'MATCH',round:q('matchRound').value.trim()||'',home:q('matchHome').value.trim()||'HOME',away:q('matchAway').value.trim()||'AWAY',kickoff:q('matchKickoff').value.trim()||'',venue:q('matchVenue').value.trim()||'',eventLogo:assets.eventLogo||'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20256%20239%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%2348cf35%22%2F%3E%3Cstop%20offset%3D%22.45%22%20stop-color%3D%22%230a8b4a%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23005432%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Cpath%20d%3D%22M%20133%20184%20L%20133%20213%20L%20134%20214%20L%20134%20222%20L%20135%20223%20L%20136%20231%20L%20137%20232%20L%20144%20232%20L%20164%20226%20L%20165%20224%20L%20162%20219%20L%20142%20199%20Z%20M%20129%20184%20L%20120%20199%20L%20113%20207%20L%20101%20218%20L%2097%20225%20L%20103%20228%20L%20109%20229%20L%20113%20231%20L%20126%20232%20L%20126%20228%20L%20128%20222%20L%20128%20216%20L%20129%20215%20Z%20M%2028%2083%20L%2029%2096%20L%2034%20108%20L%2041%20118%20L%2050%20126%20L%2061%20132%20L%2070%20133%20L%2071%20134%20L%20102%20134%20L%20103%20133%20L%20101%20127%20L%2092%20119%20L%2083%20116%20L%2071%20115%20L%2063%20111%20L%2052%2099%20L%2052%2097%20L%2049%2091%20L%2048%2083%20Z%20M%20234%2082%20L%20214%2082%20L%20214%2087%20L%20211%2097%20L%20203%20108%20L%20196%20113%20L%20194%20113%20L%20191%20115%20L%20178%20116%20L%20168%20120%20L%20161%20127%20L%20159%20133%20L%20196%20133%20L%20203%20131%20L%20212%20126%20L%20222%20117%20L%20227%20110%20L%20233%2096%20L%20233%2093%20L%20234%2092%20Z%20M%20227%2053%20L%20200%2053%20L%20198%2054%20L%20139%20112%20L%20134%20121%20L%20134%20173%20L%20137%20182%20L%20147%20195%20L%20153%20200%20L%20169%20210%20L%20175%20216%20L%20177%20220%20L%20181%20219%20L%20194%20209%20L%20194%20207%20L%20191%20203%20L%20184%20197%20L%20176%20193%20L%20173%20193%20L%20164%20190%20L%20157%20186%20L%20158%20185%20L%20161%20186%20L%20175%20186%20L%20185%20189%20L%20193%20194%20L%20201%20201%20L%20205%20199%20L%20215%20189%20L%20214%20187%20L%20203%20179%20L%20191%20174%20L%20179%20173%20L%20178%20172%20L%20159%20172%20L%20157%20171%20L%20153%20166%20L%20153%20161%20L%20154%20159%20L%20158%20156%20L%20206%20156%20L%20207%20155%20L%20212%20155%20L%20219%20153%20L%20228%20148%20L%20233%20144%20L%20239%20137%20L%20246%20124%20L%20248%20118%20L%20248%20114%20L%20239%20116%20L%20226%20121%20L%20223%20126%20L%20217%20132%20L%20208%20137%20L%20201%20138%20L%20200%20139%20L%20159%20139%20L%20153%20142%20L%20152%20141%20L%20153%20131%20L%20155%20127%20L%20211%2072%20Z%20M%20156%20185%20L%20157%20184%20L%20158%20185%20L%20157%20186%20Z%20M%2035%2053%20L%2038%2058%20L%2048%2069%20L%20107%20127%20L%20109%20131%20L%20109%20134%20L%20110%20135%20L%20110%20140%20L%20109%20141%20L%20104%20139%20L%2062%20139%20L%2061%20138%20L%2054%20137%20L%2045%20132%20L%2039%20126%20L%2036%20121%20L%2014%20114%20L%2014%20117%20L%2017%20126%20L%2023%20137%20L%2032%20147%20L%2042%20153%20L%2048%20155%20L%2053%20155%20L%2054%20156%20L%20104%20156%20L%20109%20160%20L%20110%20163%20L%20109%20167%20L%20103%20172%20L%2087%20172%20L%2086%20173%20L%2076%20173%20L%2075%20174%20L%2072%20174%20L%2056%20181%20L%2048%20188%20L%2048%20189%20L%2061%20201%20L%2068%20195%20L%2080%20188%20L%2087%20187%20L%2088%20186%20L%20102%20186%20L%20103%20187%20L%2098%20190%20L%2080%20196%20L%2068%20207%20L%2069%20210%20L%2085%20221%20L%2086%20218%20L%2091%20212%20L%20113%20197%20L%20120%20190%20L%20126%20180%20L%20128%20174%20L%20128%20167%20L%20129%20166%20L%20129%20125%20L%20128%20124%20L%20128%20121%20L%20126%20116%20L%2064%2054%20L%2061%2053%20Z%20M%20102%20186%20L%20103%20185%20L%20105%20186%20L%20104%20187%20Z%20M%2093%2024%20L%2075%2035%20L%2075%2045%20L%2076%2046%20L%2076%2050%20L%2078%2056%20L%2084%2066%20L%20129%20110%20L%20129%2093%20L%20128%2092%20L%20127%2084%20L%20124%2079%20L%2098%2052%20L%2095%2046%20L%2095%2042%20L%2094%2041%20L%2094%2024%20Z%20M%20169%2023%20L%20168%2023%20L%20168%2043%20L%20165%2051%20L%20159%2059%20L%20138%2079%20L%20135%2084%20L%20134%2092%20L%20133%2093%20L%20133%20110%20L%20178%2066%20L%20185%2054%20L%20186%2047%20L%20187%2046%20L%20187%2034%20Z%20M%20134%205%20L%20133%206%20L%20133%2074%20L%20142%2067%20L%20150%2059%20L%20150%2016%20L%20147%2013%20Z%20M%20128%205%20L%20118%2012%20L%20115%2013%20L%20112%2017%20L%20112%2059%20L%20129%2074%20L%20129%205%20Z%22%20fill%3D%22url(%23g)%22%20fill-rule%3D%22evenodd%22%2F%3E%3C%2Fsvg%3E',homeCrest:(teamStore.HOME&&teamStore.HOME.crest)||'',awayCrest:(teamStore.AWAY&&teamStore.AWAY.crest)||'',homeColor:matchdayState.homeColor||'#d8b55b',awayColor:matchdayState.awayColor||'#4c7dff',musicUrl:q('musicUrl').value.trim()||'',musicVolume:Math.max(0,Math.min(1,parseFloat(q('musicVolume').value)||.65)),audioEngine:{mode:q('audioMode').value||'HYBRID',theme:q('audioTheme').value||'SAGI_PULSE',intensity:Math.max(.1,Math.min(1,parseFloat(q('audioIntensity').value)||.75)),ducking:Math.max(0,Math.min(.8,parseFloat(q('audioDucking').value)||.35)),cueVolume:Math.max(.1,Math.min(1,parseFloat(q('cueVolume').value)||1)),countdownBeat:q('countdownBeat').value==='1'},sfx:{WHOOSH:q('sfxWhoosh').value.trim()||'',HIT:q('sfxHit').value.trim()||'',RISER:q('sfxRiser').value.trim()||'',CROWD:q('sfxCrowd').value.trim()||'',STING:q('sfxSting').value.trim()||''}}
}
function writePackage(p={}){
 if(p.matchFormat)applyStoredMatchConfig(p.matchFormat,true);q('matchCompetition').value=p.competition||'TFC 冬季联赛';q('matchRound').value=p.round||'比赛日 01';q('matchHome').value=p.home||'TARLAN FC';q('matchAway').value=p.away||'对手';q('matchKickoff').value=p.kickoff||'20:00';q('matchVenue').value=p.venue||'TACHENG';q('musicUrl').value=p.musicUrl||'';q('musicVolume').value=String(p.musicVolume||.65);const s=p.sfx||{};q('sfxWhoosh').value=s.WHOOSH||'';q('sfxHit').value=s.HIT||'';q('sfxRiser').value=s.RISER||'';q('sfxCrowd').value=s.CROWD||'';q('sfxSting').value=s.STING||'';const a=p.audioEngine||{};q('audioMode').value=a.mode||'HYBRID';q('audioTheme').value=a.theme||'SAGI_PULSE';q('audioIntensity').value=String(a.intensity||.75);q('audioDucking').value=String(a.ducking==null?.35:a.ducking);q('cueVolume').value=String(a.cueVolume||1);q('countdownBeat').value=a.countdownBeat===false?'0':'1';mdEnforceCanonicalTeams()
}
function syncMatchStage(){
 const p=packageData();q('stingLogo').src=p.eventLogo||assets.crest||'';q('stingLogo').style.visibility=(p.eventLogo||assets.crest)?'visible':'hidden';q('stingCompetition').textContent=p.competition;q('matchCompetitionStage').textContent=p.competition;q('matchRoundStage').textContent=p.round;q('matchHomeStage').textContent=p.home;q('matchAwayStage').textContent=p.away;q('matchKickoffStage').textContent=p.kickoff;q('matchVenueStage').textContent=p.venue;q('countdownSub').textContent=p.competition;
 const eventLogo=q('matchEventLogoStage'),homeCrest=q('matchHomeCrestStage'),awayCrest=q('matchAwayCrestStage');eventLogo.src=p.eventLogo||'';eventLogo.style.visibility=p.eventLogo?'visible':'hidden';homeCrest.src=p.homeCrest||'';homeCrest.style.visibility=p.homeCrest?'visible':'hidden';awayCrest.src=p.awayCrest||'';awayCrest.style.visibility=p.awayCrest?'visible':'hidden';q('matchOverlay').style.setProperty('--homeAccent',p.homeColor||'#d8b55b');q('matchOverlay').style.setProperty('--awayAccent',p.awayColor||'#4c7dff')
}
function renderPreviews(){q('photoPreview').innerHTML=assets.photo?'<img src="'+assets.photo+'">':'球员';q('mediaPreview').innerHTML=assets.mediaObjectUrl?'<video src="'+assets.mediaObjectUrl+'" muted loop playsinline autoplay></video>':'VIDEO';q('crestPreview').innerHTML=assets.crest?'<img src="'+assets.crest+'" style="object-fit:contain">':'队徽';q('bgPreview').innerHTML=assets.bg?'<img src="'+assets.bg+'">':'球场';q('eventLogoPreview').innerHTML=assets.eventLogo?'<img src="'+assets.eventLogo+'" style="object-fit:contain">':'赛事LOGO';q('musicPreview').textContent=assets.musicObjectUrl?'AUDIO ✓':'MUSIC'}
function starters(){return rawStarters(roster)}
function validStarters(){return effectiveStarters(roster,q('formation').value)}
function substitutes(){return roster.filter(p=>p.squadType==='SUB')}
function addPlayer(){const p=readPlayer(),limit=starterLimit();if(p.squadType==='STARTER'&&starters().length>=limit){note('首发最多'+limit+'人 · '+formatDisplay());return}if(roster.length>=30){note('整份名单最多30人');return}p.id=uid();roster.push(p);teamStore[activeSide].roster=roster;reconcileTeamStarters(activeSide,q('formation').value);selected=roster.length-1;renderRoster();updateFormatUI();dbPut('photo:'+p.id,p.photo||'');if(p.mediaBlob)dbPut('media:'+p.id,p.mediaBlob);note('已加入名单 '+roster.length+'人')}
function updatePlayer(){if(selected<0||!roster[selected]){note('先选择一名球员');return}const p=readPlayer(),wasStarter=(roster[selected].squadType||'STARTER')==='STARTER';if(p.squadType==='STARTER'&&!wasStarter&&starters().length>=starterLimit()){note('首发最多'+starterLimit()+'人 · '+formatDisplay());return}p.id=roster[selected].id;roster[selected]=p;teamStore[activeSide].roster=roster;reconcileTeamStarters(activeSide,q('formation').value);renderRoster();updateFormatUI();dbPut('photo:'+p.id,p.photo||'');if(p.mediaBlob)dbPut('media:'+p.id,p.mediaBlob);else dbDel('media:'+p.id);note('已更新')}
function removePlayer(){if(selected<0)return;const p=roster[selected];roster.splice(selected,1);if(p&&p.id){dbDel('photo:'+p.id);dbDel('media:'+p.id)}teamStore[activeSide].roster=roster;reconcileTeamStarters(activeSide,q('formation').value);selected=Math.min(selected,roster.length-1);if(selected>=0)writePlayer(roster[selected]);renderRoster();updateFormatUI();renderStage(currentGroup);note('已删除')}
function renderRoster(){const w=q('roster');w.innerHTML='';if(!roster.length){w.innerHTML='<div class="muted">当前球队还没有球员。可直接导入名单，或手动添加球员。</div>';if(typeof refreshUXDashboard==='function')refreshUXDashboard();return}roster.forEach((p,i)=>{const d=document.createElement('div');d.className='playerRow'+(i===selected?' on':'');d.innerHTML='<div class="thumb">'+(p.photo?'<img src="'+p.photo+'">':p.role)+'</div><div><div class="pname">'+esc(p.name)+(p.captain?' <span style="color:#d8b55b">C</span>':'')+'</div><div class="pmeta">'+(p.squadType==='SUB'?'SUB · ':'')+esc(p.role)+' · '+esc(p.position)+(p.statValue?' · '+esc(p.statLabel)+' '+esc(p.statValue):'')+((p.mediaBlob||p.mediaUrl)?' · MEDIA '+(p.directorSpeed||1)+'×'+(p.directorFreeze?' · 定格':''):'')+'</div></div><div class="num">'+esc(p.number)+'</div>';d.onclick=()=>{selected=i;writePlayer(p);renderRoster()};w.appendChild(d)});if(typeof refreshUXDashboard==='function')refreshUXDashboard()}
function grouped(role){return validStarters().filter(p=>p.role===role)}
function getFormationPoints(){return getFormationPointsFor(activeSide,q('formation').value)}
function fallbackPoint(role,i,n){const y={GK:91,DF:72,MF:48,FW:22}[role]||50;return[((i+1)/(n+1))*100,y]}
function renderFormation(activeRole){
 q('formationText').textContent=q('formation').value;const box=q('formationNodes');box.innerHTML='';getFormationPoints().forEach(({p,role,xy,key},i)=>{const n=document.createElement('div'),hasPhoto=!!p.photo;n.className='node'+(hasPhoto?' hasPhoto':'')+((activeRole==='FULL'||activeRole===role)?' active':'')+(p.captain?' captainNode':'');n.style.left=xy[0]+'%';n.style.top=xy[1]+'%';n.style.setProperty('--node-i',i);n.dataset.playerKey=key;const visual=hasPhoto?'<img src="'+escAttr(p.photo)+'" alt="">':'<span class="nodeFallbackNo">'+esc(p.number)+'</span>';n.innerHTML='<div class="nodeVisual">'+visual+'</div><span class="nodeNo">'+esc(p.number)+'</span><small>'+esc(p.name)+'</small>';if(formationEditorActive)n.addEventListener('pointerdown',e=>beginFormationDrag(e,n,key));box.appendChild(n)});updateFormationEditorUI()
}
function mediaSource(p){return p.mediaObjectUrl||p.mediaUrl||''}
function directorAttrs(p){
 return ' data-in="'+(Number(p.directorIn)||0)+'" data-out="'+(Number(p.directorOut)||0)+'" data-speed="'+(Number(p.directorSpeed)||1)+'" data-freeze="'+(p.directorFreeze?'1':'0')+'" data-freezems="'+(Number(p.directorFreezeMs)||1000)+'" data-camera="'+esc(p.directorCamera||'MEDIUM')+'"';
}
function playerCard(p,n){
 const one=n===1?' one':'',media=mediaSource(p),action=' action-'+esc(p.mediaAction||'STANDARD'),hasMedia=media?' hasMedia':'',directed=media?' directed':'';
 const fallback=p.photo?'<img src="'+p.photo+'">':'<div class="fallback">'+esc(p.number)+'</div>';
 const visual=media?'<div class="mediaFallback">'+fallback+'</div><video class="mediaVideo" src="'+esc(media)+'" muted playsinline preload="auto"'+directorAttrs(p)+'></video>':fallback;
 const dirTag=media?'<div class="directorBadge">入点 '+(Number(p.directorIn)||0).toFixed(1)+' · '+(Number(p.directorSpeed)||1).toFixed(2)+'×'+(p.directorFreeze?' · 定格':'')+'</div>':'';
 return '<div class="playerCard'+one+hasMedia+action+directed+'"><div class="playerBigNo">'+esc(p.number)+'</div><div class="playerCut">'+visual+'</div><div class="playerLabel"><div class="playerNo">#'+esc(p.number)+(p.captain?'<span class="captainBadge">C</span>':'')+'</div><div class="playerName">'+esc(p.name)+'</div><div class="playerRole">'+esc(p.position||p.role)+'</div>'+(p.statValue?'<div class="statPill">'+esc(p.statLabel)+' <strong>'+esc(p.statValue)+'</strong></div>':'')+(media?'<div class="mediaTag">球员定妆</div>':'')+dirTag+'</div></div>'
}
function flashFreeze(){
 const f=q('freezeFlash');if(!f||!f.animate)return;
 f.animate([{opacity:0},{opacity:.22,offset:.35},{opacity:0}],{duration:180,fill:'none'});
}
function configureDirectorVideo(v){
 const inPt=Math.max(0,parseFloat(v.dataset.in)||0),outPt=Math.max(0,parseFloat(v.dataset.out)||0),speed=Math.max(.25,parseFloat(v.dataset.speed)||1),freeze=v.dataset.freeze==='1',freezeMs=Math.max(0,parseInt(v.dataset.freezems,10)||1000);
 v.playbackRate=speed;
 const start=()=>{try{const max=Math.max(0,(v.duration||0)-.03),target=Math.min(inPt,max);if(Math.abs(v.currentTime-target)>.08)v.currentTime=target;const p=v.play();if(p&&p.catch)p.catch(()=>{})}catch(e){}};
 if(v.readyState>=1)start();else v.addEventListener('loadedmetadata',start,{once:true});
 const onTime=()=>{const end=outPt>inPt?outPt:(Number.isFinite(v.duration)?v.duration:0);if(end>0&&v.currentTime>=Math.max(inPt,end-.035)){v.removeEventListener('timeupdate',onTime);try{v.pause();v.currentTime=Math.max(inPt,Math.min(end,v.duration||end)-.03)}catch(e){}if(freeze){flashFreeze();v.dataset.frozen='1';setTimeout(()=>{v.dataset.freezeDone='1'},freezeMs)}}};
 v.addEventListener('timeupdate',onTime);
}
function playMediaVideos(){q('stage').querySelectorAll('video.mediaVideo').forEach(configureDirectorVideo)}
function renderFull(){
 q('playersArea').style.display='none';q('subList').style.display='none';const list=q('fullList');list.style.display='grid';list.innerHTML=validStarters().map((p,i)=>'<div class="fullRow" style="--row-i:'+i+'"><div class="fullRole">'+esc(p.role)+'</div><div class="fullNo">'+esc(p.number)+'</div><div class="fullName">'+esc(p.name)+(p.captain?' <span class="captainBadge">C</span>':'')+'</div><div class="fullPos">'+esc(p.position)+(p.statValue?' · '+esc(p.statLabel)+' '+esc(p.statValue):'')+'</div></div>').join('');

}
function renderSubs(){
 q('playersArea').style.display='none';q('fullList').style.display='none';const list=q('subList');list.style.display='grid';
 const subs=substitutes();list.innerHTML=subs.length?subs.map(p=>'<div class="subRow"><div class="subNo">#'+esc(p.number)+'</div><div><div class="subName">'+esc(p.name)+'</div><div class="subStat">'+esc(p.role)+' · '+esc(p.position)+'</div></div><div class="subStat">'+(p.statValue?esc(p.statLabel)+' '+esc(p.statValue):'替补')+'</div></div>').join(''):'<div class="muted">暂无替补球员</div>';
}
function updateTunnelLabels(group){
 const team=currentTeamName(),left=q('ledLeft'),right=q('ledRight'),lineup=startingLabel();
 const role={TEAM:lineup,GK:'门将',DF:'后卫',MF:'中场',FW:'前锋',FULL:'阵型',SUB:'替补球员'}[group]||lineup;
 left.innerHTML=esc(team)+'<small>'+role+'</small>';
 right.innerHTML=(group==='TEAM'?'SAGI':(ROLE_NAMES[group]||group))+'<small>'+esc(q('formation').value)+'</small>';
}
function applyVisualGroup(group){
 const st=q('stage'),area=q('playersArea'),code=q('roleBackdrop');updateTunnelLabels(group);
 st.classList.remove('group-GK','group-DF','group-MF','group-FW','group-TEAM','group-FULL','group-SUB','group-STING','group-MATCH','group-COUNTDOWN','tunnel-open');
 st.classList.add('group-'+group);if(group==='FULL')st.classList.add('tunnel-open');
 area.className='playersArea layout-'+group;
 const codes={STING:'SAGI',MATCH:'赛',COUNTDOWN:'5',TEAM:starterCode(),GK:'门',DF:'卫',MF:'中',FW:'锋',FULL:starterCode(),SUB:'替'};
 code.textContent=codes[group]||starterCode();
 const packageGroup=['STING','MATCH','COUNTDOWN'].includes(group);q('roleGlow').style.display=(group==='FULL'||group==='SUB'||packageGroup)?'none':'block';code.style.display=(group==='FULL'||group==='SUB'||packageGroup)?'none':'flex';
}
function renderStage(group){
 currentGroup=group||'TEAM';applyVisualGroup(currentGroup);q('stage').style.setProperty('--teamAccent',activeSide==='HOME'?(matchdayState.homeColor||'#d8b55b'):(matchdayState.awayColor||'#4c7dff'));syncMatchStage();['stingOverlay','matchOverlay','countdownOverlay'].forEach(id=>q(id).classList.remove('on'));q('stageTeam').textContent=currentTeamName();q('stageCrest').src=assets.crest||'';q('stageCrest').style.visibility=assets.crest?'visible':'hidden';q('stadiumPhoto').src=assets.bg||'';q('stadiumPhoto').className='stadiumPhoto'+(assets.bg?' on':'');q('fullList').style.display='none';q('subList').style.display='none';q('playersArea').style.display='flex';
 const lineupLabel=startingLabel();q('stageLineupLabel').textContent=lineupLabel;let title=lineupLabel,name='球队阵容',players=[];
 if(group==='STING'){title='赛事包装';name='赛事标识';q('playersArea').style.display='none';q('stingOverlay').classList.add('on')}
 else if(group==='MATCH'){title='赛事包装';name='比赛信息';q('playersArea').style.display='none';q('matchOverlay').classList.add('on')}
 else if(group==='COUNTDOWN'){title='赛事包装';name='开场倒计时';q('playersArea').style.display='none';q('countdownOverlay').classList.add('on')}
 else if(group==='TEAM'){title='SAGI 赛事直播';name=currentTeamName()+' · '+q('formation').value;players=[]}
 else if(group==='FULL'){title=lineupLabel;name='完整首发阵容';renderFull()} else if(group==='SUB'){title='球队名单';name='替补球员';renderSubs()}
 else{title=lineupLabel;name=ROLE_NAMES[group]||group;players=grouped(group);q('playersArea').innerHTML=players.map(p=>playerCard(p,players.length)).join('')}
 q('groupTitle').textContent=title;q('groupName').textContent=name;
 if(group==='TEAM')q('playersArea').innerHTML='<div style="align-self:center;text-align:center;color:#ffffff52;font-weight:1000;font-size:138px;letter-spacing:10px;text-shadow:0 18px 45px #000">'+esc(q('formation').value)+'</div>';
 const tacticalOn=['GK','DF','MF','FW','FULL'].includes(group);
 q('formationBox').style.display=tacticalOn?'block':'none';
 if(tacticalOn)renderFormation(group);else{q('formationNodes').innerHTML='';updateFormationEditorUI()}
 applyOutputBackground();setTimeout(playMediaVideos,0)
}
function applyOutputBackground(){
 const mode=q('outputBg').value,st=q('stage');
 st.classList.remove('scene-tunnel','scene-stadium','scene-transparent','scene-chroma');st.classList.add('scene-'+mode);
 if(mode==='transparent'){st.style.background='transparent';st.querySelector('.stadium').style.display='none';q('stadiumPhoto').style.display='none';st.querySelector('.stadiumShade').style.display='none';st.querySelector('.pitchLines').style.display='none'}
 else if(mode==='chroma'){st.style.background='#00b140';st.querySelector('.stadium').style.display='none';q('stadiumPhoto').style.display='none';st.querySelector('.stadiumShade').style.display='none';st.querySelector('.pitchLines').style.display='none'}
 else if(mode==='stadium'){st.style.background='#07090c';st.querySelector('.stadium').style.display='block';q('stadiumPhoto').style.display=assets.bg?'block':'none';st.querySelector('.stadiumShade').style.display='block';st.querySelector('.pitchLines').style.display='block'}
 else{st.style.background='#05070a'}
}
function animateStage(){
 const cards=[...q('stage').querySelectorAll('.playerCard,.fullRow,.subRow,.node.active')];
 cards.forEach((el,i)=>{
   if(!el.animate)return;
   const isNode=el.classList.contains('node'),isPlayer=el.classList.contains('playerCard');
   let frames;
   if(isNode)frames=[{opacity:0,transform:'translate(-50%,-50%) scale(.25)'},{opacity:1,transform:'translate(-50%,-50%) scale(1.18)',offset:.72},{opacity:1,transform:'translate(-50%,-50%) scale(1)'}];
   else if(isPlayer){
     const dir=i%2===0?-70:70;
     frames=[{opacity:0,transform:'translate('+dir+'px,24px) scale(.94)',filter:'blur(5px)'},{opacity:1,transform:'translate(0,0) scale(1)',filter:'blur(0)'}];
   } else frames=[{opacity:0,transform:'translateY(35px) scale(.97)'},{opacity:1,transform:'translateY(0) scale(1)'}];
   el.animate(frames,{duration:isNode?620:isPlayer?680:520,delay:i*(isNode?95:90),fill:'forwards',easing:'cubic-bezier(.18,.82,.18,1)'})
 });
 q('stage').querySelectorAll('video.mediaVideo').forEach((v,i)=>{if(!v.animate)return;const cam=v.dataset.camera||'MEDIUM',scale={NONE:1.02,LIGHT:1.06,MEDIUM:1.10,STRONG:1.16}[cam]||1.10;v.animate([{opacity:0,transform:'scale('+scale+') translateY(20px)'},{opacity:1,transform:'scale(1) translateY(0)'}],{duration:900,delay:100+i*90,fill:'forwards',easing:'cubic-bezier(.18,.82,.18,1)'})});
  const title=q('groupName');if(title.animate)title.animate([{opacity:0,transform:'translateX(-70px)',letterSpacing:'8px'},{opacity:1,transform:'translateX(0)',letterSpacing:'-2px'}],{duration:620,fill:'forwards',easing:'ease-out'});
 if(q('outputBg').value==='tunnel'){
   const tunnel=q('tunnelScene'),cams=[...q('stage').querySelectorAll('video.mediaVideo')].map(v=>v.dataset.camera||'MEDIUM'),rank={NONE:0,LIGHT:1,MEDIUM:2,STRONG:3},best=cams.sort((a,b)=>(rank[b]||0)-(rank[a]||0))[0]||'MEDIUM',scale={NONE:1.025,LIGHT:1.045,MEDIUM:1.07,STRONG:1.105}[best]||1.07,y={NONE:5,LIGHT:9,MEDIUM:15,STRONG:23}[best]||15;
   if(tunnel&&tunnel.animate)tunnel.animate([{transform:'scale('+scale+') translateY('+y+'px)',filter:'brightness(.7)'},{transform:'scale(1) translateY(0)',filter:'brightness(1)'}],{duration:1050,fill:'forwards',easing:'cubic-bezier(.15,.8,.2,1)'});
   [q('ledLeft'),q('ledRight')].forEach((el,i)=>{if(el&&el.animate)el.animate([{opacity:0,transform:'translateY(24px)',filter:'blur(7px)'},{opacity:1,transform:'translateY(0)',filter:'blur(0)'}],{duration:620,delay:110+i*90,fill:'forwards',easing:'ease-out'})});
 }
  const glow=q('roleGlow');if(glow&&glow.style.display!=='none'&&glow.animate)glow.animate([{opacity:0,transform:'scale(.72)'},{opacity:.26,transform:'scale(1.04)',offset:.7},{opacity:.22,transform:'scale(1)'}],{duration:900,fill:'forwards',easing:'ease-out'});
 const code=q('roleBackdrop');if(code&&code.style.display!=='none'&&code.animate)code.animate([{opacity:0,transform:'scale(.86)'},{opacity:1,transform:'scale(1)'}],{duration:780,fill:'forwards',easing:'ease-out'})
}
function animatePackageGroup(group,duration){
 if(group==='STING'){
  const core=q('stingOverlay').querySelector('.stingCore');if(core&&core.animate)core.animate([{opacity:0,transform:'scale(.72)'},{opacity:1,transform:'scale(1.04)',offset:.7},{opacity:1,transform:'scale(1)'}],{duration:900,fill:'forwards',easing:'cubic-bezier(.2,.8,.2,1)'})
 }else if(group==='MATCH'){
  const card=q('matchOverlay').querySelector('.matchCardStage');if(card&&card.animate)card.animate([{opacity:0,transform:'translateY(24px) scale(.985)'},{opacity:1,transform:'translateY(0) scale(1)'}],{duration:520,fill:'forwards',easing:'cubic-bezier(.16,.84,.28,1)'});
  q('matchOverlay').querySelectorAll('.matchTopLine,.matchTeamBlock,.matchCenterStage,.matchMetaStage').forEach((el,i)=>{if(el&&el.animate)el.animate([{opacity:0,transform:'translateY('+(i?18:-12)+'px)'},{opacity:1,transform:'translateY(0)'}],{duration:460,delay:90+i*90,fill:'forwards',easing:'ease-out'})})
 }else if(group==='COUNTDOWN'){
  startCountdown(duration)
 }
}
function startCountdown(duration){
 const el=q('countdownNumber'),seconds=Math.max(1,Math.round((Number(duration)||5000)/1000));let n=seconds;el.textContent=n;clearInterval(startCountdown.t);const pulse=()=>{if(el.animate)el.animate([{opacity:.2,transform:'scale(1.3)'},{opacity:1,transform:'scale(1)'}],{duration:420,easing:'ease-out'})};pulse();startCountdown.t=setInterval(()=>{n--;if(n<=0){clearInterval(startCountdown.t);el.textContent='GO';pulse();if(audioSettings().countdownBeat)builtInCue('HIT',.8);return}el.textContent=n;pulse();if(audioSettings().countdownBeat)builtInCue('HIT',.55)},1000)
}
function stopCountdown(){clearInterval(startCountdown.t)}
function cloudAdmin(){try{const x=JSON.parse(localStorage.getItem('sagi_cloud_admin_v20')||'null')||{},b=window.SAGI_CLOUD||{};return{url:x.url||b.url||'',key:x.key||b.key||'',eventSlug:x.eventSlug||b.eventSlug||'',token:x.token||''}}catch(e){const b=window.SAGI_CLOUD||{};return{url:b.url||'',key:b.key||'',eventSlug:b.eventSlug||'',token:''}}}
function compactPlayersForGroup(group){const src=group==='FULL'?validStarters():group==='SUB'?substitutes():(['GK','DF','MF','FW'].includes(group)?grouped(group):[]);return src.map(p=>({id:p.id,layoutKey:formationPlayerKey(p),name:p.name,number:p.number,role:p.role,position:p.position,captain:!!p.captain,statLabel:p.statLabel||'',statValue:p.statValue||'',squadType:p.squadType||'STARTER',photo:(group==='FULL'||group==='SUB')?'':p.photo||'',mediaUrl:(group==='FULL'||group==='SUB')?'':p.mediaUrl||'',mediaAction:p.mediaAction||'STANDARD',directorIn:Number(p.directorIn)||0,directorOut:Number(p.directorOut)||0,directorSpeed:Number(p.directorSpeed)||1,directorFreeze:!!p.directorFreeze,directorFreezeMs:Number(p.directorFreezeMs)||1000,directorCamera:p.directorCamera||'MEDIUM'}))}
async function publishGroup(group,duration,show=null){
 const state={commandId:Date.now()+'_'+Math.random().toString(36).slice(2,6),group,side:activeSide,team:currentTeamName(),formation:q('formation').value,matchFormat:{mode:matchConfig.mode,playerCount:starterLimit()},playerCount:starterLimit(),startingLabel:startingLabel(),players:compactPlayersForGroup(group),formationLayout:currentFormationLayoutPayload(),allPlayers:validStarters().map(p=>({id:p.id,layoutKey:formationPlayerKey(p),name:p.name,number:p.number,role:p.role,position:p.position,captain:!!p.captain,statLabel:p.statLabel||'',statValue:p.statValue||'',photo:p.photo||'',mediaUrl:p.mediaUrl||'',mediaAction:p.mediaAction||'STANDARD',directorIn:Number(p.directorIn)||0,directorOut:Number(p.directorOut)||0,directorSpeed:Number(p.directorSpeed)||1,directorFreeze:!!p.directorFreeze,directorFreezeMs:Number(p.directorFreezeMs)||1000,directorCamera:p.directorCamera||'MEDIUM'})),substitutes:substitutes().map(p=>({name:p.name,number:p.number,role:p.role,position:p.position,statLabel:p.statLabel||'',statValue:p.statValue||''})),crest:assets.crest||'',stadium:assets.bg||'',background:q('outputBg').value,teamColor:(activeSide==='HOME'?(matchdayState.homeColor||'#d8b55b'):(matchdayState.awayColor||'#4c7dff')),visualVersion:'V4.30.8-PREMIER-BROADCAST',duration,show:show||null,package:packageData(),startedAt:new Date().toISOString()};
 try{
   await lanPost('/api/state',{lineupIntro:state});
   return{ok:true}
 }catch(e){return{ok:false}}
}

function focusAndRun(fn){const mobile=matchMedia&&matchMedia('(max-width:940px)').matches;if(!mobile){fn();return}try{q('frame').scrollIntoView({behavior:'auto',block:'center'});requestAnimationFrame(()=>requestAnimationFrame(fn))}catch(e){fn()}}
function escAttr(s){return String(s??'').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;')}
function normalizeShowSteps(list){
 const src=Array.isArray(list)?list.map(s=>({...s})):[];
 const homeSub=DEFAULT_SHOW.find(s=>s.id==='home_sub'),awaySub=DEFAULT_SHOW.find(s=>s.id==='away_sub');
 if(!src.some(s=>s.id==='home_sub')){
   const i=src.findIndex(s=>s.id==='away_team');
   if(i>=0)src.splice(i,0,{...homeSub});else src.push({...homeSub});
 }
 if(!src.some(s=>s.id==='away_sub'))src.push({...awaySub});
 return src.map(s=>({...s,duration:Math.max(500,Number(s.duration)||1000),enabled:s.enabled!==false}));
}
function showEnabled(){return showSteps.filter(s=>s.enabled)}
function showTotalMs(){return showEnabled().reduce((a,s)=>a+(Number(s.duration)||0),0)}
function showTransitionLabel(v){return({CUT:'硬切',FADE:'淡变',SLIDE:'滑动',ZOOM:'推进',FLASH:'闪白'})[v]||v}
function showCueLabel(v){return({NONE:'无',WHOOSH:'呼啸',HIT:'冲击',RISER:'渐强',CROWD:'观众',STING:'转场'})[v]||v}
function showTransitionOptions(v){return ['CUT','FADE','SLIDE','ZOOM','FLASH'].map(x=>'<option value="'+x+'"'+(x===v?' selected':'')+'>'+showTransitionLabel(x)+'</option>').join('')}
function showCueOptions(v){return ['NONE','WHOOSH','HIT','RISER','CROWD','STING'].map(x=>'<option value="'+x+'"'+(x===v?' selected':'')+'>'+showCueLabel(x)+'</option>').join('')}
function showNextEnabledIndex(from){let i=Math.max(0,Number(from)||0);while(i<showSteps.length&&!showSteps[i].enabled)i++;return i<showSteps.length?i:-1}
function showRemainingMs(){
 const enabled=showEnabled();if(!enabled.length)return 0;
 if(!playing||showIndex<0)return showTotalMs();
 let remain=0;
 const current=showSteps[showIndex],elapsed=Math.max(0,broadcastHold?showHoldElapsed:(performance.now()-showStartedAt));
 if(current&&current.enabled)remain+=Math.max(0,(Number(current.duration)||0)-elapsed);
 for(let i=showIndex+1;i<showSteps.length;i++)if(showSteps[i].enabled)remain+=Number(showSteps[i].duration)||0;
 return remain
}
function renderShowDirectorMonitor(){
 const en=showEnabled(),current=(showIndex>=0&&showIndex<showSteps.length)?showSteps[showIndex]:null,nextIdx=showNextEnabledIndex(showIndex>=0?showIndex+1:0),next=nextIdx>=0?showSteps[nextIdx]:null;
 const currentPos=current&&current.enabled?en.indexOf(current)+1:0;
 const on=q('showOnAirLabel'),onMeta=q('showOnAirMeta'),nx=q('showNextProLabel'),nxMeta=q('showNextProMeta'),pos=q('showPosition'),remain=q('showRemain'),mode=q('showMode'),state=q('showDirectorState');
 if(on)on.textContent=current?(current.label||'当前段'):'尚未开始';
 if(onMeta)onMeta.textContent=current?((current.side==='AWAY'?'客队':current.side==='HOME'?'主队':'赛事包装')+' · '+showTransitionLabel(current.transition)+' · '+showCueLabel(current.cue)):'等待节目开始';
 if(nx)nx.textContent=next?(next.label||'下一段'):'节目结束';
 if(nxMeta)nxMeta.textContent=next?('第 '+(en.indexOf(next)+1)+' 段 · '+((Number(next.duration)||0)/1000).toFixed(1)+' 秒'):'没有后续段落';
 if(pos)pos.textContent=currentPos+' / '+en.length;
 if(remain)remain.textContent=(showRemainingMs()/1000).toFixed(1)+' 秒';
 if(mode)mode.textContent=broadcastHold?'人工保持':'自动连续';
 if(state){state.textContent=broadcastHold?'保持中':playing?'播出中':(currentPos>=en.length&&currentPos>0?'已完成':'待命');state.className='pdLiveBadge '+(broadcastHold?'hold':playing?'live':(currentPos>=en.length&&currentPos>0?'done':''))}
 const hb=q('showHoldDirectorBtn');if(hb){hb.classList.toggle('on',broadcastHold);hb.textContent=broadcastHold?'继续下一段':'保持当前'}
}
function renderShowTimeline(){
 const w=q('showTimeline');if(!w)return;w.innerHTML='';
 const nextIdx=showNextEnabledIndex(showIndex>=0?showIndex+1:0);
 showSteps.forEach((s,i)=>{const d=document.createElement('div'),isActive=i===showIndex&&playing,isDone=showIndex>=0&&i<showIndex,isQueued=i===nextIdx&&playing;
   d.className='showStep'+(isActive?' active':'')+(isDone?' done':'')+(isQueued?' queued':'')+(s.enabled?'':' disabled');d.dataset.i=i;
   const side=s.side==='AWAY'?'客队':s.side==='HOME'?'主队':'包装',sideClass=s.side==='AWAY'?' away':'';
   const stateText=isActive?'播出中':isDone?'完成':isQueued?'下一段':s.enabled?'待播':'停用';
   d.innerHTML='<div class="showIndex">'+(i+1)+'</div><div class="showSide'+sideClass+'">'+side+'</div><div class="showName">'+esc(s.label)+'</div>'+
   '<input class="showDur" type="number" min="0.5" max="30" step="0.5" value="'+((Number(s.duration)||1000)/1000).toFixed(1)+'">'+
   '<select class="showTransition">'+showTransitionOptions(s.transition)+'</select>'+
   '<select class="showCue">'+showCueOptions(s.cue)+'</select>'+
   '<label class="showEnable"><input type="checkbox" '+(s.enabled?'checked':'')+'></label>'+
   '<div class="showMove"><button class="up" type="button">↑</button><button class="down" type="button">↓</button></div>'+
   '<div><button class="showTake" type="button">立即执行</button><div class="showState '+(isActive?'live':isDone?'done':'')+'">'+stateText+'</div></div>';
   d.querySelector('.showDur').onchange=e=>{s.duration=Math.max(500,Math.round((parseFloat(e.target.value)||1)*1000));renderShowSummary()};
   d.querySelector('.showTransition').onchange=e=>s.transition=e.target.value;
   d.querySelector('.showCue').onchange=e=>s.cue=e.target.value;
   d.querySelector('.showEnable input').onchange=e=>{s.enabled=e.target.checked;renderShowTimeline()};
   d.querySelector('.up').onclick=()=>moveShowStep(i,-1);d.querySelector('.down').onclick=()=>moveShowStep(i,1);
   d.querySelector('.showTake').onclick=()=>takeShowStep(i);w.appendChild(d)
 });
 renderShowSummary();renderShowDirectorMonitor()
}
function renderShowSummary(){const total=showTotalMs(),el=q('showTotal');if(el)el.textContent=(total/1000).toFixed(1)+' 秒';renderShowDirectorMonitor()}
function moveShowStep(i,dir){const j=i+dir;if(j<0||j>=showSteps.length)return;[showSteps[i],showSteps[j]]=[showSteps[j],showSteps[i]];if(showIndex===i)showIndex=j;else if(showIndex===j)showIndex=i;renderShowTimeline()}
function takeShowStep(i){
 if(!requireMatchReady())return;if(i<0||i>=showSteps.length||!showSteps[i].enabled){note('该节目段当前不可执行');return}
 clearTimeout(showTimer);broadcastHold=false;const hb=q('holdBtn');if(hb){hb.classList.remove('on');hb.textContent='保持'}
 playing=true;showSession=showSession||Date.now().toString(36);ensureShowMusic();runShowStep(i);note('已执行 · '+showSteps[i].label)
}
function toggleShowEdit(){
 const w=q('showTimelineWrap'),b=q('showEditToggle');if(!w||!b)return;const open=w.classList.toggle('collapsed')===false;b.textContent=open?'收起节目单':'展开节目单'
}
function resetShow(){stopShow(false);showSteps=DEFAULT_SHOW.map(x=>({...x}));showIndex=-1;renderShowTimeline();note('节目时间线已恢复默认')}
function saveShow(){localStorage.setItem('sagi_show_director_v40',JSON.stringify(showSteps));note('节目时间线已保存')}
function loadShow(){try{let x=JSON.parse(localStorage.getItem('sagi_show_director_v40')||'null');if(!x){try{x=JSON.parse(localStorage.getItem('sagi_show_director_v36')||'null')}catch(_){}}if(Array.isArray(x)&&x.length)showSteps=normalizeShowSteps(x);else showSteps=normalizeShowSteps(DEFAULT_SHOW);}catch(e){showSteps=normalizeShowSteps(DEFAULT_SHOW)}renderShowTimeline();renderShowDirectorMonitor()}
function applyShowTransition(type){
 const l=q('transitionLayer');if(!l||!l.animate)return;l.className='transitionLayer';l.style.opacity='0';
 if(type==='CUT')return;
 if(type==='FLASH'){l.classList.add('white');l.animate([{opacity:0},{opacity:.82,offset:.28},{opacity:0}],{duration:380,easing:'ease-out'});return}
 if(type==='SLIDE'){l.classList.add('gold');l.animate([{opacity:.78,transform:'translateX(-105%)'},{opacity:.78,transform:'translateX(0)',offset:.48},{opacity:0,transform:'translateX(105%)'}],{duration:650,easing:'cubic-bezier(.2,.8,.2,1)'});return}
 if(type==='ZOOM'){q('stage').animate([{filter:'brightness(.55)',transform:'scale(1.035)'},{filter:'brightness(1)',transform:'scale(1)'}],{duration:620,easing:'ease-out'});return}
 l.classList.add('dark');l.animate([{opacity:.85},{opacity:0}],{duration:520,easing:'ease-out'})
}
function audioSettings(){return packageData().audioEngine||{mode:'HYBRID',theme:'SAGI_PULSE',intensity:.75,ducking:.35,cueVolume:1,countdownBeat:true}}
function audioSrcForCue(cue){const p=packageData();return p.sfx&&p.sfx[cue]||''}
function getAudioCtx(){const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return null;const ctx=getAudioCtx.ctx||(getAudioCtx.ctx=new AC());if(ctx.state==='suspended')ctx.resume().catch(()=>{});return ctx}
function pulseMeter(id,level=1,ms=420){const el=q(id);if(!el)return;el.style.width=Math.max(0,Math.min(100,level*100))+'%';clearTimeout(el._t);el._t=setTimeout(()=>el.style.width='8%',ms)}
function playAudioUrl(url,volume=1){if(!url)return null;try{const a=new Audio(url);a.volume=Math.max(0,Math.min(1,volume));a.play().catch(()=>{});return a}catch(e){return null}}
function noiseBuffer(ctx,duration=.5){const len=Math.max(1,Math.floor(ctx.sampleRate*duration)),b=ctx.createBuffer(1,len,ctx.sampleRate),d=b.getChannelData(0);for(let i=0;i<len;i++)d[i]=Math.random()*2-1;return b}
function synthTone(ctx,type,f1,f2,dur,gain=.1,when=0){const o=ctx.createOscillator(),g=ctx.createGain(),t=ctx.currentTime+when;o.type=type;o.frequency.setValueAtTime(f1,t);if(f2>0)o.frequency.exponentialRampToValueAtTime(Math.max(1,f2),t+dur);g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(Math.max(.0002,gain),t+.012);g.gain.exponentialRampToValueAtTime(.0001,t+dur);o.connect(g);g.connect(ctx.destination);o.start(t);o.stop(t+dur+.03)}
function synthNoise(ctx,dur=.45,gain=.08,filterStart=1200,filterEnd=180,when=0){const s=ctx.createBufferSource(),f=ctx.createBiquadFilter(),g=ctx.createGain(),t=ctx.currentTime+when;s.buffer=noiseBuffer(ctx,dur);f.type='bandpass';f.frequency.setValueAtTime(filterStart,t);f.frequency.exponentialRampToValueAtTime(Math.max(40,filterEnd),t+dur);f.Q.value=.8;g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(Math.max(.0002,gain),t+.02);g.gain.exponentialRampToValueAtTime(.0001,t+dur);s.connect(f);f.connect(g);g.connect(ctx.destination);s.start(t);s.stop(t+dur+.03)}
function builtInCue(cue,level=1){
 const ctx=getAudioCtx();if(!ctx)return false;const s=audioSettings(),k=Math.max(.2,Math.min(1,level*s.intensity*s.cueVolume));pulseMeter('cueMeter',k,650);duckMusic();
 if(cue==='HIT'){synthTone(ctx,'sine',105,38,.34,.22*k);synthNoise(ctx,.24,.08*k,900,120)}
 else if(cue==='WHOOSH'){synthNoise(ctx,.62,.11*k,180,2600);synthTone(ctx,'triangle',170,460,.48,.045*k)}
 else if(cue==='RISER'){synthTone(ctx,'sawtooth',90,920,.88,.055*k);synthNoise(ctx,.82,.055*k,220,2600)}
 else if(cue==='CROWD'){synthNoise(ctx,1.15,.07*k,260,750);synthTone(ctx,'triangle',115,155,.7,.025*k)}
 else if(cue==='STING'){synthTone(ctx,'sine',82,42,.46,.24*k);synthTone(ctx,'sawtooth',220,520,.55,.045*k,.04);synthNoise(ctx,.36,.09*k,1800,220,.02)}
 return true
}
function builtInThemeStart(){
 const s=audioSettings();if(s.mode==='MUTE'||s.mode==='EXTERNAL')return false;const ctx=getAudioCtx();if(!ctx)return false;builtInThemeStop();const state={ctx,nodes:[],timer:null,step:0};builtInThemeStart.state=state;
 const theme=s.theme||'SAGI_PULSE',int=s.intensity||.75;const bpm=theme==='NORTH_WIND'?96:theme==='BLACK_GOLD'?118:108,beat=60/bpm;
 const tick=()=>{if(builtInThemeStart.state!==state)return;const st=state.step++,root=theme==='NORTH_WIND'?73.42:theme==='BLACK_GOLD'?55:65.41;const accent=st%4===0;
   synthTone(ctx,'sine',accent?root:root*1.5,accent?root*.72:root*1.2,Math.min(.38,beat*.7),(accent?.075:.035)*int);
   if(st%2===0)synthNoise(ctx,.08,.015*int,theme==='NORTH_WIND'?1600:2600,900);
   if(theme==='NORTH_WIND'&&st%4===2)synthTone(ctx,'triangle',root*3,root*2.25,.2,.018*int);
   if(theme==='BLACK_GOLD'&&st%4===1)synthTone(ctx,'square',root*4,root*3,.09,.008*int);
   pulseMeter('masterMeter',accent?.72:.42,Math.min(300,beat*700));
 };
 tick();state.timer=setInterval(tick,beat*1000);q('audioEngineState').textContent='BUILT-IN · '+theme.replaceAll('_',' ');return true
}
function builtInThemeStop(){const s=builtInThemeStart.state;if(s){clearInterval(s.timer);builtInThemeStart.state=null}}
function duckMusic(){
 const s=audioSettings(),a=ensureShowMusic.audio;if(!a||!s.ducking)return;q('stage').dataset.duck='active';setTimeout(()=>q('stage').dataset.duck='idle',650);const base=packageData().musicVolume,low=Math.max(.05,base*(1-s.ducking));try{a.volume=low;clearTimeout(duckMusic.t);duckMusic.t=setTimeout(()=>{try{a.volume=base}catch(e){}},620)}catch(e){}
}
function ensureShowMusic(){
 const p=packageData(),s=p.audioEngine||audioSettings(),src=assets.musicObjectUrl||p.musicUrl;q('stage').dataset.audioMode=s.mode;q('stage').dataset.audioTheme=s.theme;q('stage').dataset.music='off';if(s.mode==='MUTE'){stopShowMusic();q('stage').dataset.music='muted';q('audioStatus').textContent='AUDIO MUTED';return}
 let externalStarted=false;
 if((s.mode==='HYBRID'||s.mode==='EXTERNAL')&&src){let a=ensureShowMusic.audio;if(!a||a.src!==src){try{if(a)a.pause()}catch(e){}a=new Audio(src);a.loop=true;ensureShowMusic.audio=a}a.volume=p.musicVolume;try{const pr=a.play();if(pr&&pr.catch)pr.catch(()=>{});externalStarted=true}catch(e){}}
 if((s.mode==='BUILTIN')||(s.mode==='HYBRID'&&!src)){builtInThemeStart();q('stage').dataset.music='builtin'}else{builtInThemeStop();if(externalStarted)q('stage').dataset.music='external'}
 q('audioStatus').textContent=(externalStarted?'EXTERNAL MUSIC':'BUILT-IN MUSIC')+' · '+Math.round(p.musicVolume*100)+'%';q('audioEngineState').textContent=s.mode+' · '+s.theme; pulseMeter('masterMeter',.55,700)
}
function stopShowMusic(){const a=ensureShowMusic.audio;if(a){try{a.pause();a.currentTime=0}catch(e){}}builtInThemeStop();q('audioStatus').textContent='AUDIO READY';q('audioEngineState').textContent='引擎就绪';pulseMeter('masterMeter',0,10);pulseMeter('cueMeter',0,10)}
function triggerCue(cue){
 const b=q('cueBadgeStage');if(!b||cue==='NONE')return;q('stage').dataset.cue=cue;b.textContent=cue;b.animate([{opacity:0,transform:'translateY(-8px)'},{opacity:1,transform:'translateY(0)',offset:.25},{opacity:0}],{duration:900,easing:'ease-out'});
 const s=audioSettings();q('stage').dataset.cueSource='none';if(s.mode==='MUTE')return;const real=audioSrcForCue(cue);if((s.mode==='HYBRID'||s.mode==='EXTERNAL')&&real){q('stage').dataset.cueSource='real';duckMusic();pulseMeter('cueMeter',s.cueVolume,.7);playAudioUrl(real,s.cueVolume);return}
 if(s.mode!=='EXTERNAL'){q('stage').dataset.cueSource='builtin';builtInCue(cue,1)}
}
function showProgressTick(step,duration){
 const bar=q('showProgressBar'),now=q('showNow');showStartedAt=performance.now();
 const tick=()=>{if(!playing||showSteps[showIndex]!==step)return;const elapsed=broadcastHold?showHoldElapsed:(performance.now()-showStartedAt),p=Math.min(1,elapsed/duration);if(bar)bar.style.width=(p*100).toFixed(1)+'%';if(now)now.innerHTML='正在播出 · <b>'+esc(step.label)+'</b> · 当前段剩余 '+Math.max(0,(duration-elapsed)/1000).toFixed(1)+' 秒';renderShowDirectorMonitor();if(p<1)requestAnimationFrame(tick)};tick()
}
function showMeta(step){const en=showEnabled(),pos=en.indexOf(step);return{sessionId:showSession,stepIndex:showIndex,sequenceIndex:pos,stepTotal:en.length,label:step.label,side:step.side||activeSide,transition:step.transition,cue:step.cue,autoNext:true,isFirst:pos===0,isLast:pos===en.length-1}}
function runShowStep(i){
 if(!playing)return;
 while(i<showSteps.length&&!showSteps[i].enabled)i++;
 if(i>=showSteps.length){playing=false;showIndex=showSteps.length-1;stopCountdown();stopShowMusic();q('status').textContent='节目播放结束';q('showNow').textContent='节目完成 · 已播出全部启用段落';q('showProgressBar').style.width='100%';renderShowTimeline();renderShowDirectorMonitor();return}
 showIndex=i;showHoldElapsed=0;const s=showSteps[i],d=Math.max(500,Number(s.duration)||1000);if(s.side&&s.side!==activeSide)switchTeam(s.side,{silent:true,noRender:true});renderShowTimeline();broadcastProgramFromShow(s,d);applyShowTransition(s.transition);triggerCue(s.cue);renderStage(s.group);animateStage();animatePackageGroup(s.group,d);showProgressTick(s,d);q('status').textContent='节目 '+(i+1)+' / '+showSteps.length+' · '+s.label;publishGroup(s.group,d,showMeta(s));clearTimeout(showTimer);if(!broadcastHold)showTimer=setTimeout(()=>runShowStep(i+1),d)
}
function startFullIntro(){
 broadcastHold=false;const hb=q('holdBtn');if(hb){hb.classList.remove('on');hb.textContent='保持'}broadcastManualIndex=0;
 q('status').textContent='一键完整出场 · 赛事Logo → 客队替补';
 startShow();
}
function startShow(){if(!requireMatchReady())return;if(roster.length<1){note('请先加入球员');return}stopShow(false);playing=true;showSession=Date.now().toString(36);ensureShowMusic();focusAndRun(()=>runShowStep(0))}
function stopShow(update=true){playing=false;clearTimeout(showTimer);clearTimeout(seqTimer);stopCountdown();stopShowMusic();if(update){q('status').textContent='节目已停止';q('showNow').textContent='节目已停止 · 当前画面保持'}renderShowTimeline();renderShowDirectorMonitor()}
function nextShow(){if(!requireMatchReady())return;if(!showSteps.length)return;playing=true;showSession=showSession||Date.now().toString(36);clearTimeout(showTimer);runShowStep(Math.min(showSteps.length,showIndex+1))}
function prevShow(){if(!requireMatchReady())return;if(!showSteps.length)return;playing=true;showSession=showSession||Date.now().toString(36);clearTimeout(showTimer);let i=Math.max(0,showIndex-1);while(i>0&&!showSteps[i].enabled)i--;runShowStep(i)}
function playGroup(group,duration){playing=true;focusAndRun(()=>{renderStage(group);animateStage();q('status').textContent='正在播放 '+(group==='TEAM'?'球队开场':group==='FULL'?'完整首发':group==='SUB'?'替补名单':ROLE_NAMES[group]||group);publishGroup(group,duration).then(r=>{if(!r.ok)q('status').textContent+=' · 本机预览'});clearTimeout(seqTimer);seqTimer=setTimeout(()=>{playing=false;q('status').textContent='播放完成 · 画面已保留'},duration)})}
function autoPlay(){startShow()}
function stop(){stopShow()}
function resize(){const f=q('frame'),scale=Math.min(f.clientWidth/1920,f.clientHeight/1080),left=(f.clientWidth-1920*scale)/2,top=(f.clientHeight-1080*scale)/2,w=q('stageScale');w.style.transformOrigin='0 0';w.style.transform='translate3d('+left+'px,'+top+'px,0) scale('+scale+')'}
async function save(){
 stashActiveTeam();
 for(const side of ['HOME','AWAY'])for(const p of teamStore[side].roster)p.id=p.id||uid();
 const playerMeta=p=>({id:p.id,name:p.name,number:p.number,squadType:p.squadType||'STARTER',role:p.role,position:p.position,captain:!!p.captain,statLabel:p.statLabel||'',statValue:p.statValue||'',mediaUrl:p.mediaUrl||'',mediaAction:p.mediaAction||'STANDARD',directorIn:Number(p.directorIn)||0,directorOut:Number(p.directorOut)||0,directorSpeed:Number(p.directorSpeed)||1,directorFreeze:!!p.directorFreeze,directorFreezeMs:Number(p.directorFreezeMs)||1000,directorCamera:p.directorCamera||'MEDIUM'});
 const snapshot={activeSide,matchConfig:{...matchConfig},package:JSON.parse(JSON.stringify(packageData())),teams:{HOME:{formation:teamStore.HOME.formation,customPositions:JSON.parse(JSON.stringify(teamStore.HOME.customPositions||{})),roster:teamStore.HOME.roster.map(playerMeta)},AWAY:{formation:teamStore.AWAY.formation,customPositions:JSON.parse(JSON.stringify(teamStore.AWAY.customPositions||{})),roster:teamStore.AWAY.roster.map(playerMeta)}},show:showSteps.map(s=>({...s}))};
 const puts=[],dels=[];for(const side of ['HOME','AWAY'])for(const p of teamStore[side].roster){puts.push(['photo:'+p.id,p.photo||'']);if(p.mediaBlob)puts.push(['media:'+p.id,p.mediaBlob]);else dels.push('media:'+p.id)}
 puts.push(['crest:HOME',teamStore.HOME.crest||''],['crest:AWAY',teamStore.AWAY.crest||''],['stadium',assets.bg||''],['eventLogo',assets.eventLogo||'']);if(assets.musicBlob)puts.push(['showMusic',assets.musicBlob]);else dels.push('showMusic');await Promise.all([dbPutMany(puts),dbDelMany(dels)]);
 localStorage.setItem('sagi_player_intro_v40',JSON.stringify({activeSide:snapshot.activeSide,matchConfig:snapshot.matchConfig,package:snapshot.package,teams:snapshot.teams}));
 localStorage.setItem('sagi_show_director_v40',JSON.stringify(snapshot.show));
 note('V4.8 双队阵容、音频与节目已保存')
}
async function hydrateRoster(list=[]){const out=[];for(const p of list){p.photo=await dbGet('photo:'+p.id);p.mediaBlob=await dbGet('media:'+p.id);p.mediaObjectUrl=p.mediaBlob instanceof Blob?URL.createObjectURL(p.mediaBlob):'';p.mediaAction=p.mediaAction||'STANDARD';p.directorIn=Number(p.directorIn)||0;p.directorOut=Number(p.directorOut)||0;p.directorSpeed=Number(p.directorSpeed)||1;p.directorFreeze=!!p.directorFreeze;p.directorFreezeMs=Number(p.directorFreezeMs)||1000;p.directorCamera=p.directorCamera||'MEDIUM';out.push(p)}return out}
async function saveCurrentSideRoster(silent=false){
 const side=activeSide==='AWAY'?'AWAY':'HOME';stashActiveTeam();const t=teamStore[side]||{roster:[],formation:defaultFormationForCount(starterLimit()),crest:'',customPositions:{}};
 for(const p of (t.roster||[]))p.id=p.id||uid();
 const playerMeta=p=>({id:p.id,name:p.name,number:p.number,squadType:p.squadType||'STARTER',role:p.role,position:p.position,captain:!!p.captain,statLabel:p.statLabel||'',statValue:p.statValue||'',mediaUrl:p.mediaUrl||'',mediaAction:p.mediaAction||'STANDARD',directorIn:Number(p.directorIn)||0,directorOut:Number(p.directorOut)||0,directorSpeed:Number(p.directorSpeed)||1,directorFreeze:!!p.directorFreeze,directorFreezeMs:Number(p.directorFreezeMs)||1000,directorCamera:p.directorCamera||'MEDIUM'});
 const puts=[],dels=[];for(const p of (t.roster||[])){puts.push(['photo:'+p.id,p.photo||'']);if(p.mediaBlob)puts.push(['media:'+p.id,p.mediaBlob]);else dels.push('media:'+p.id)}puts.push(['crest:'+side,t.crest||'']);await Promise.all([dbPutMany(puts),dbDelMany(dels)]);
 const snap={side,teamName:side==='AWAY'?(q('matchAway').value.trim()||q('teamName').value.trim()||'AWAY'):(q('matchHome').value.trim()||q('teamName').value.trim()||'HOME'),matchConfig:{...matchConfig},formation:t.formation||defaultFormationForCount(starterLimit()),customPositions:JSON.parse(JSON.stringify(t.customPositions||{})),roster:(t.roster||[]).map(playerMeta),savedAt:Date.now()};
 localStorage.setItem('sagi_team_roster_v48_'+side,JSON.stringify(snap));if(!silent)note('已保存 '+sideLabel(side)+' 阵容 · '+snap.roster.length+' 人');if(q('uxAutoSaveState'))q('uxAutoSaveState').textContent='● 已自动保存 '+sideLabel(side)+' · '+new Date().toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'})
}
async function loadCurrentSideRoster(){
 const side=(q('awaySideBtn')&&q('awaySideBtn').classList.contains('on'))?'AWAY':((q('homeSideBtn')&&q('homeSideBtn').classList.contains('on'))?'HOME':(activeSide==='AWAY'?'AWAY':'HOME'));
 try{
  let snap=JSON.parse(localStorage.getItem('sagi_team_roster_v48_'+side)||'null');
  if(!snap){
   let legacy=JSON.parse(localStorage.getItem('sagi_player_intro_v40')||'null');if(!legacy){try{legacy=JSON.parse(localStorage.getItem('sagi_player_intro_v36')||'null')}catch(_){}}
   const lt=legacy&&legacy.teams&&legacy.teams[side];
   if(lt)snap={side,teamName:side==='AWAY'?(legacy.package&&legacy.package.away||q('matchAway').value):(legacy.package&&legacy.package.home||q('matchHome').value),matchConfig:legacy.matchConfig||legacy.package?.matchFormat||null,formation:lt.formation,customPositions:lt.customPositions||{},roster:lt.roster||[]};
  }
  if(!snap||!Array.isArray(snap.roster)){note('还没有保存 '+sideLabel(side)+' 阵容');return}
  if(snap.matchConfig)applyStoredMatchConfig(snap.matchConfig,true);
  if(side==='AWAY'&&snap.teamName)q('matchAway').value=snap.teamName;if(side==='HOME'&&snap.teamName)q('matchHome').value=snap.teamName;
  const loaded=await hydrateRoster(snap.roster.map(p=>({...p}))),formation=snap.formation||defaultFormationForCount(starterLimit()),crest=await dbGet('crest:'+side)||'';
  teamStore[side]={formation,customPositions:snap.customPositions||{},roster:loaded,crest};
  reconcileTeamStarters(side,formation);switchTeam(side,{silent:true,skipStash:true});
  refreshSideUI();renderRoster();renderPreviews();updateFormatUI();updateFormationEditorUI();refreshMatchdayPlayers();syncMatchStage();renderStage(currentGroup);
  setTimeout(()=>{if(activeSide!==side)switchTeam(side,{silent:true,skipStash:true});refreshSideUI()},0);
  note('已读取 '+sideLabel(side)+' 阵容 · '+loaded.length+' 人')
 }catch(e){note('读取 '+sideLabel(side)+' 阵容失败')}
}
async function load(){
 const requestedSide=activeSide==='AWAY'?'AWAY':'HOME';
 try{
  let x=JSON.parse(localStorage.getItem('sagi_player_intro_v40')||'null');if(!x){try{x=JSON.parse(localStorage.getItem('sagi_player_intro_v36')||'null')}catch(_){}}
  if(!x){
   const legacy=JSON.parse(localStorage.getItem('sagi_player_intro_v2')||'null');
   if(legacy)x={activeSide:'HOME',matchConfig:{mode:'11',playerCount:11},package:legacy.package||{},teams:{HOME:{formation:legacy.formation||'4-3-3',roster:legacy.roster||[]},AWAY:{formation:'4-3-3',roster:[]}}};
  }
  if(!x){note('还没有保存阵容');return}
  applyStoredMatchConfig(x.matchConfig||x.package?.matchFormat||{mode:'11',playerCount:11},true);writePackage(x.package||{});
  teamStore.HOME={formation:x.teams?.HOME?.formation||defaultFormationForCount(starterLimit()),customPositions:x.teams?.HOME?.customPositions||{},roster:await hydrateRoster(x.teams?.HOME?.roster||[]),crest:await dbGet('crest:HOME')||await dbGet('crest')||''};
  teamStore.AWAY={formation:x.teams?.AWAY?.formation||defaultFormationForCount(starterLimit()),customPositions:x.teams?.AWAY?.customPositions||{},roster:await hydrateRoster(x.teams?.AWAY?.roster||[]),crest:await dbGet('crest:AWAY')||''};
  reconcileTeamStarters('HOME',teamStore.HOME.formation);reconcileTeamStarters('AWAY',teamStore.AWAY.formation);
  assets.bg=await dbGet('stadium');assets.eventLogo=await dbGet('eventLogo');assets.musicBlob=await dbGet('showMusic');assets.musicObjectUrl=assets.musicBlob instanceof Blob?URL.createObjectURL(assets.musicBlob):'';
  let storedShow=JSON.parse(localStorage.getItem('sagi_show_director_v40')||'null');if(!storedShow){try{storedShow=JSON.parse(localStorage.getItem('sagi_show_director_v36')||'null')}catch(_){}}if(Array.isArray(storedShow)&&storedShow.length)showSteps=normalizeShowSteps(storedShow);else showSteps=normalizeShowSteps(DEFAULT_SHOW);
  switchTeam(requestedSide,{silent:true,skipStash:true});renderPreviews();renderShowTimeline();syncMatchStage();note('V4.8 双队阵容已读取 · 当前保持 '+sideLabel(requestedSide))
 }catch(e){note('读取失败')}
}

function demoPlayer(a){return{id:uid(),number:a[0],name:a[1],squadType:a[2],role:a[3],position:a[4],captain:!!a[5],statLabel:a[6],statValue:a[7],photo:'',mediaBlob:null,mediaObjectUrl:'',mediaUrl:'',mediaAction:(a[3]==='GK'?'GK_GLOVES':a[3]==='FW'?'CELEBRATE':'ARMS'),directorIn:0,directorOut:0,directorSpeed:(a[3]==='FW'?.75:1),directorFreeze:a[3]==='FW',directorFreezeMs:1000,directorCamera:(a[3]==='GK'?'STRONG':a[3]==='FW'?'STRONG':'MEDIUM')}}
function demo(){
 const home=[
 ['1','AZAMAT','STARTER','GK','GK',0,'CLEAN SHEETS','6'],['2','DIAS','STARTER','DF','RB',0,'APPS','12'],['4','NURLAN','STARTER','DF','CB',1,'APPS','14'],['5','ALMAS','STARTER','DF','CB',0,'APPS','13'],['3','ERLAN','STARTER','DF','LB',0,'APPS','11'],['6','SULTAN','STARTER','MF','CM',0,'ASSISTS','5'],['8','MARHULAN','STARTER','MF','CM',0,'APPS','14'],['10','ASLAN','STARTER','MF','AM',0,'GOALS','7'],['7','DANIYAR','STARTER','FW','RW',0,'GOALS','8'],['9','ARDAK','STARTER','FW','ST',0,'GOALS','12'],['11','TIMUR','STARTER','FW','LW',0,'GOALS','6'],['12','BEK','SUB','GK','GK',0,'APPS','3'],['14','RUSLAN','SUB','DF','CB',0,'APPS','6'],['16','ILIAS','SUB','MF','CM',0,'ASSISTS','2'],['18','SAMAT','SUB','FW','ST',0,'GOALS','3'],['20','AMAN','SUB','FW','RW',0,'APPS','5']];
 const away=[
 ['1','MURAT','STARTER','GK','GK',0,'SAVES','31'],['2','ADIL','STARTER','DF','RB',0,'APPS','11'],['4','BEKZAT','STARTER','DF','CB',1,'APPS','13'],['5','SERIK','STARTER','DF','CB',0,'APPS','12'],['3','AYDIN','STARTER','DF','LB',0,'APPS','10'],['6','NURAS','STARTER','MF','CM',0,'ASSISTS','4'],['8','ELDAR','STARTER','MF','CM',0,'APPS','12'],['10','ALIKHAN','STARTER','MF','AM',0,'GOALS','5'],['7','DAUREN','STARTER','FW','RW',0,'GOALS','6'],['9','YERNAR','STARTER','FW','ST',0,'GOALS','9'],['11','SAYAT','STARTER','FW','LW',0,'GOALS','4'],['12','ASKAR','SUB','GK','GK',0,'APPS','2'],['14','KANAT','SUB','DF','CB',0,'APPS','5'],['16','ARLAN','SUB','MF','CM',0,'ASSISTS','2'],['18','BOLAT','SUB','FW','ST',0,'GOALS','2'],['20','RAMAZAN','SUB','FW','RW',0,'APPS','4']];
 const demoFormation=(teamStore[activeSide]&&formationOutfieldCount(teamStore[activeSide].formation)===starterLimit()-1)?teamStore[activeSide].formation:defaultFormationForCount(starterLimit());
 const buildDemo=(src)=>{const need=formationRoleCounts(demoFormation),used={GK:0,DF:0,MF:0,FW:0};return src.map(demoPlayer).map(p=>{if(p.squadType==='STARTER'){if((used[p.role]||0)<(need[p.role]||0))used[p.role]=(used[p.role]||0)+1;else p.squadType='SUB'}return p})};
 teamStore.HOME={roster:buildDemo(home),formation:demoFormation,crest:'',customPositions:{}};teamStore.AWAY={roster:buildDemo(away),formation:demoFormation,crest:'',customPositions:{}};
 writePackage({matchFormat:{...matchConfig},competition:'TFC 冬季联赛',round:'比赛日 01',home:'TARLAN FC',away:'ICE POINT FC',kickoff:'20:00',venue:'TACHENG',musicVolume:.65,audioEngine:{mode:'HYBRID',theme:'SAGI_PULSE',intensity:.75,ducking:.35,cueVolume:1,countdownBeat:true},sfx:{}});
 activeSide='HOME';roster=teamStore.HOME.roster;refreshFormationOptions(demoFormation);assets.crest='';selected=0;writePlayer(roster[0]);refreshSideUI();updateFormatUI();renderRoster();renderStage('FULL');syncMatchStage();note('已载入 '+formatDisplay()+' 双队示例 · '+demoFormation)
}


function bcCueFor(group){return({STING:'STING',MATCH:'RISER',COUNTDOWN:'HIT',TEAM:'RISER',GK:'HIT',DF:'WHOOSH',MF:'WHOOSH',FW:'HIT',FULL:'CROWD',SUB:'WHOOSH'})[group]||'NONE'}
function bcDuration(group){return({STING:2000,MATCH:3000,COUNTDOWN:5000,TEAM:2500,GK:3000,DF:4000,MF:4000,FW:4000,FULL:6000,SUB:5000})[group]||3500}
function bcLabel(group,side){const p=side==='AWAY'?'AWAY':'HOME';return({STING:'赛事Logo',MATCH:'比赛信息',COUNTDOWN:'开场倒计时',TEAM:p+' TEAM',GK:p+' GK',DF:p+' DF',MF:p+' MF',FW:p+' FW',FULL:p+' '+starterCode(),SUB:p+' SUBS'})[group]||group}
function refreshBroadcastStatus(){
 const cfg=cloudAdmin(),ready=!!(cfg.url&&cfg.key&&cfg.eventSlug&&cfg.token);
 q('bcVmixStatus').textContent=ready?'已连接':'仅本机';
 q('bcVmixLamp').classList.toggle('ready',ready);
 q('bcOnAirLamp').classList.toggle('live',!!broadcastProgram);
 q('bcOnAirStatus').textContent=broadcastProgram?'正在播出':'SAFE';
 q('bcProgramLabel').textContent=broadcastProgram?broadcastProgram.label:'安全画面 / 未播出';
 q('bcProgramMeta').textContent=broadcastProgram?(broadcastProgram.side+' · '+broadcastProgram.group+' · '+(broadcastProgram.duration/1000).toFixed(1)+'s'):'等待切入播出';
 q('bcPreviewLabel').textContent=broadcastPreview.label;
 q('bcPreviewMeta').textContent=broadcastPreview.side+' · '+broadcastPreview.group+' · READY';
 const nxt=BROADCAST_MANUAL[(broadcastManualIndex+1+BROADCAST_MANUAL.length)%BROADCAST_MANUAL.length];q('bcNextLabel').textContent=nxt.label;
 document.querySelectorAll('[data-bc-group]').forEach(b=>b.classList.toggle('on',b.dataset.bcGroup===broadcastPreview.group&&(!b.dataset.bcSide||b.dataset.bcSide===broadcastPreview.side)));
}
function setBroadcastPreview(group,side=activeSide,label='',duration=0){
 const targetSide=(side==='AWAY'?'AWAY':'HOME');if(targetSide!==activeSide)switchTeam(targetSide,{silent:true,noRender:true});
 broadcastPreview={group,side:targetSide,label:label||bcLabel(group,targetSide),duration:duration||bcDuration(group)};
 currentGroup=group;renderStage(group);animateStage();
 const found=BROADCAST_MANUAL.findIndex(x=>x.group===group&&x.side===targetSide);if(found>=0)broadcastManualIndex=found;
 q('status').textContent='预监 · '+broadcastPreview.label+' · 等待切入播出';refreshBroadcastStatus();
}
async function takeBroadcastLive(){
 if(!requireMatchReady())return;const c=broadcastPreview;if(!c)return;if(c.side!==activeSide)switchTeam(c.side,{silent:true,noRender:true});
 broadcastProgram={...c,startedAt:Date.now()};applyShowTransition('FADE');triggerCue(bcCueFor(c.group));renderStage(c.group);animateStage();
 if(c.group!=='STING')ensureShowMusic();
 const meta={sessionId:'manual-'+Date.now().toString(36),stepIndex:-1,sequenceIndex:-1,stepTotal:1,label:c.label,side:c.side,transition:'FADE',cue:bcCueFor(c.group),autoNext:false,isFirst:true,isLast:false,controlRoom:true};
 const r=await publishGroup(c.group,c.duration,meta);q('status').textContent=(r.ok?'PROGRAM 正在播出 · ':'本机播出 · ')+c.label;refreshBroadcastStatus();
}
function stepBroadcastPreview(dir){
 broadcastManualIndex=(broadcastManualIndex+dir+BROADCAST_MANUAL.length)%BROADCAST_MANUAL.length;const c=BROADCAST_MANUAL[broadcastManualIndex];setBroadcastPreview(c.group,c.side,c.label,c.duration);
}
function toggleBroadcastHold(){
 broadcastHold=!broadcastHold;if(broadcastHold)showHoldElapsed=Math.max(0,performance.now()-showStartedAt);else showHoldElapsed=0;
 q('holdBtn').classList.toggle('on',broadcastHold);q('holdBtn').textContent=broadcastHold?'继续':'保持';
 const hb=q('showHoldDirectorBtn');if(hb){hb.classList.toggle('on',broadcastHold);hb.textContent=broadcastHold?'继续下一段':'保持当前'}
 if(broadcastHold){clearTimeout(showTimer);q('status').textContent='保持中 · 当前播出画面不变';}
 else{q('status').textContent='已继续 · 执行下一段';if(playing&&showIndex>=0)runShowStep(showIndex+1)}
 renderShowDirectorMonitor()
}
async function clearBroadcastAll(){
 broadcastHold=false;q('holdBtn').classList.remove('on');q('holdBtn').textContent='保持';stopShow(false);stopShowMusic();
 const meta={sessionId:'clear-'+Date.now().toString(36),stepIndex:-1,sequenceIndex:-1,stepTotal:1,label:'一键清屏',side:activeSide,transition:'CUT',cue:'NONE',autoNext:false,isFirst:true,isLast:true,controlRoom:true};
 await publishGroup('CLEAR',200,meta);broadcastProgram=null;q('status').textContent='播出已清空 · 安全';refreshBroadcastStatus();
}
function broadcastProgramFromShow(s,d){
 broadcastProgram={group:s.group,side:s.side||activeSide,label:'自动 · '+s.label,duration:d,startedAt:Date.now()};refreshBroadcastStatus();
}
function initBroadcastControl(){
 document.querySelectorAll('[data-bc-group]').forEach(b=>b.onclick=()=>setBroadcastPreview(b.dataset.bcGroup,b.dataset.bcSide||activeSide,b.dataset.bcLabel||'',bcDuration(b.dataset.bcGroup)));
 q('fullIntroBtn').onclick=startFullIntro;q('goLiveBtn').onclick=takeBroadcastLive;q('holdBtn').onclick=toggleBroadcastHold;q('prevLiveBtn').onclick=()=>stepBroadcastPreview(-1);q('nextLiveBtn').onclick=()=>stepBroadcastPreview(1);q('clearAllBtn').onclick=clearBroadcastAll;
 document.addEventListener('keydown',e=>{const tag=(document.activeElement&&document.activeElement.tagName)||'';if(['INPUT','SELECT','TEXTAREA'].includes(tag))return;
  if(e.code==='Space'){e.preventDefault();takeBroadcastLive()}else if(e.key==='h'||e.key==='H'){toggleBroadcastHold()}else if(e.key==='ArrowRight'){stepBroadcastPreview(1)}else if(e.key==='ArrowLeft'){stepBroadcastPreview(-1)}else if(e.key==='Escape'){clearBroadcastAll()}
 });
 refreshBroadcastStatus();
}

function vmixLink(){return new URL('/vmix',location.href).toString()}
async function copyVmix(){try{await navigator.clipboard.writeText(vmixLink());note('LAN vMix 图形链接已复制')}catch(e){prompt('复制这个链接：',vmixLink())}}

q('crestFile').onchange=async e=>{const f=e.target.files[0];if(!f)return;assets.crest=await fileData(f,420,.84);teamStore[activeSide].crest=assets.crest;renderPreviews();renderStage(currentGroup)};
q('bgFile').onchange=async e=>{const f=e.target.files[0];if(!f)return;assets.bg=await fileData(f,1600,.78);renderPreviews();renderStage(currentGroup)};
q('photoFile').onchange=async e=>{const f=e.target.files[0];if(!f)return;assets.photo=await fileData(f,1000,.82);renderPreviews()};
q('mediaFile').onchange=async e=>{const f=e.target.files[0];if(!f)return;if(f.size>20*1024*1024){note('视频建议控制在20MB以内');e.target.value='';return}if(assets.mediaObjectUrl&&assets.mediaObjectUrl.startsWith('blob:'))try{URL.revokeObjectURL(assets.mediaObjectUrl)}catch(_){}
 assets.mediaBlob=f;assets.mediaObjectUrl=URL.createObjectURL(f);renderPreviews();note('球员视频已载入 · '+Math.round(f.size/1024)+'KB')};
q('clearMediaBtn').onclick=()=>{if(assets.mediaObjectUrl&&assets.mediaObjectUrl.startsWith('blob:'))try{URL.revokeObjectURL(assets.mediaObjectUrl)}catch(_){}assets.mediaBlob=null;assets.mediaObjectUrl='';q('mediaUrl').value='';renderPreviews();note('已清除当前球员视频')};
q('eventLogoFile').onchange=async e=>{const f=e.target.files[0];if(!f)return;assets.eventLogo=await fileData(f,600,.88);renderPreviews();syncMatchStage()};
q('musicFile').onchange=e=>{const f=e.target.files[0];if(!f)return;if(f.size>30*1024*1024){note('音乐建议控制在30MB以内');e.target.value='';return}if(assets.musicObjectUrl&&assets.musicObjectUrl.startsWith('blob:'))try{URL.revokeObjectURL(assets.musicObjectUrl)}catch(_){}assets.musicBlob=f;assets.musicObjectUrl=URL.createObjectURL(f);renderPreviews();q('audioStatus').textContent='LOCAL MUSIC READY · '+Math.round(f.size/1024)+'KB'};
q('audioTestBtn').onclick=()=>ensureShowMusic();q('cueTestBtn').onclick=()=>triggerCue('HIT');q('audioStopBtn').onclick=()=>stopShowMusic();q('clearMusicBtn').onclick=()=>{stopShowMusic();if(assets.musicObjectUrl&&assets.musicObjectUrl.startsWith('blob:'))try{URL.revokeObjectURL(assets.musicObjectUrl)}catch(_){}assets.musicBlob=null;assets.musicObjectUrl='';renderPreviews();note('已清除本机音乐')};
q('clearBgBtn').onclick=()=>{assets.bg='';renderPreviews();renderStage(currentGroup)};q('homeSideBtn').onclick=()=>switchTeam('HOME');q('awaySideBtn').onclick=()=>switchTeam('AWAY');
q('addBtn').onclick=addPlayer;q('updateBtn').onclick=updatePlayer;q('removeBtn').onclick=removePlayer;q('saveBtn').onclick=saveCurrentSideRoster;q('loadBtn').onclick=loadCurrentSideRoster;q('demoBtn').onclick=demo;
q('teamBtn').onclick=()=>setBroadcastPreview('TEAM',activeSide,bcLabel('TEAM',activeSide),2500);q('gkBtn').onclick=()=>setBroadcastPreview('GK',activeSide,bcLabel('GK',activeSide),3000);q('dfBtn').onclick=()=>setBroadcastPreview('DF',activeSide,bcLabel('DF',activeSide),4000);q('mfBtn').onclick=()=>setBroadcastPreview('MF',activeSide,bcLabel('MF',activeSide),4000);q('fwBtn').onclick=()=>setBroadcastPreview('FW',activeSide,bcLabel('FW',activeSide),4000);q('fullBtn').onclick=()=>setBroadcastPreview('FULL',activeSide,bcLabel('FULL',activeSide),6000);q('subsBtn').onclick=()=>setBroadcastPreview('SUB',activeSide,bcLabel('SUB',activeSide),5000);q('showPlayBtn').onclick=startShow;q('showHoldDirectorBtn').onclick=toggleBroadcastHold;q('showPrevBtn').onclick=prevShow;q('showNextBtn').onclick=nextShow;q('stopBtn').onclick=stopShow;q('showEditToggle').onclick=toggleShowEdit;q('showResetBtn').onclick=resetShow;q('showSaveBtn').onclick=saveShow;q('copyVmixBtn').onclick=copyVmix;
q('matchFormat').onchange=()=>setMatchFormatFromUI();q('customPlayerCount').onchange=()=>{if(q('matchFormat').value==='CUSTOM')setMatchFormatFromUI()};q('applyCustomFormationBtn').onclick=applyCustomFormation;q('squadType').onchange=updateFormatUI;
q('formation').onchange=()=>{teamStore[activeSide].formation=q('formation').value;const r=reconcileTeamStarters(activeSide,q('formation').value);roster=teamStore[activeSide].roster||roster;renderRoster();updateFormatUI();updateFormationEditorUI();renderStage(currentGroup);refreshMatchdayPlayers();if(matchReady){matchReady=false;setupReadySignature='';refreshSetupReadyUI()}note('阵型已切换 '+q('formation').value+(r.changed?' · '+syncSummary(r):''))};q('teamName').oninput=()=>{if(activeSide==='HOME')q('matchHome').value=q('teamName').value;else q('matchAway').value=q('teamName').value;renderStage(currentGroup)};q('outputBg').onchange=()=>renderStage(currentGroup);
['matchCompetition','matchRound','matchKickoff','matchVenue'].forEach(id=>q(id).oninput=syncMatchStage);q('matchHome').oninput=()=>{if(activeSide==='HOME')q('teamName').value=q('matchHome').value;syncMatchStage()};q('matchAway').oninput=()=>{if(activeSide==='AWAY')q('teamName').value=q('matchAway').value;syncMatchStage()};
['audioMode','audioTheme','audioIntensity','audioDucking','cueVolume','countdownBeat'].forEach(id=>q(id).onchange=()=>{q('audioEngineState').textContent=q('audioMode').value+' · '+q('audioTheme').value.replaceAll('_',' ')});
window.addEventListener('resize',resize);renderPreviews();renderRoster();loadShow();applyStoredMatchConfig({mode:'11',playerCount:11},true);refreshFormationOptions('4-3-3');demo();refreshSideUI();updateFormatUI();syncMatchStage();renderStage('TEAM');resize();initBroadcastControl();initMatchdayGraphics();initVmixDirector();initFilterEngine();initRosterImport();initMatchSetup();initFormationEditor();initMatchMode();initUXV49();setBroadcastPreview('TEAM','HOME','主队开场',2500);
})();
</script>

<script>
(function(){
'use strict';
const statusEl=document.getElementById('pwaStatus');
const installBtn=document.getElementById('pwaInstallBtn');
const updateBtn=document.getElementById('pwaUpdateBtn');
if(!statusEl||!installBtn||!updateBtn)return;

const isIOS=/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
const standalone=window.matchMedia('(display-mode: standalone)').matches||window.navigator.standalone===true;
let deferredPrompt=null;
let waitingWorker=null;

function setStatus(text){statusEl.textContent=text}
function setInstalledState(){
  if(standalone){
    installBtn.textContent='已安装';
    installBtn.disabled=true;
    setStatus('已从主屏幕 / 桌面打开 · 每次启动都会检查最新版本');
  }else if(isIOS){
    installBtn.textContent='添加到主屏幕';
    setStatus('iPhone / iPad：Safari → 分享 → 添加到主屏幕');
  }else{
    setStatus('可安装为独立应用 · 桌面图标始终打开最新 Control Room');
  }
}

window.addEventListener('beforeinstallprompt',e=>{
  e.preventDefault();
  deferredPrompt=e;
  if(!standalone){
    installBtn.disabled=false;
    installBtn.textContent='安装到桌面';
    setStatus('已准备好安装 · 安装后可像普通应用一样从桌面打开');
  }
});

window.addEventListener('appinstalled',()=>{
  deferredPrompt=null;
  installBtn.textContent='已安装';
  installBtn.disabled=true;
  setStatus('安装完成 · 以后从桌面 / 主屏幕打开即可');
});

installBtn.addEventListener('click',async()=>{
  if(standalone)return;
  if(deferredPrompt){
    try{
      deferredPrompt.prompt();
      await deferredPrompt.userChoice;
      deferredPrompt=null;
    }catch(e){}
    return;
  }
  if(isIOS){
    setStatus('操作：Safari 底部“分享” → “添加到主屏幕” → 右上角“添加”');
  }else{
    setStatus('Chrome / Edge：地址栏右侧“安装”图标，或浏览器菜单 → 安装此网站为应用');
  }
});

if('serviceWorker' in navigator&&window.isSecureContext){
  navigator.serviceWorker.register('./sw.js',{scope:'./',updateViaCache:'none'}).then(reg=>{
    reg.update().catch(()=>{});

    function showUpdate(worker){
      waitingWorker=worker||reg.waiting;
      updateBtn.hidden=false;
      setStatus('发现新版本 · 可立即更新；不操作也会在下次打开时使用最新版');
    }

    if(reg.waiting)showUpdate(reg.waiting);

    reg.addEventListener('updatefound',()=>{
      const worker=reg.installing;
      if(!worker)return;
      worker.addEventListener('statechange',()=>{
        if(worker.state==='installed'&&navigator.serviceWorker.controller)showUpdate(reg.waiting||worker);
      });
    });

    setInterval(()=>reg.update().catch(()=>{}),300000);
  }).catch(()=>{
    setStatus('应用可正常使用 · 当前浏览器未启用自动更新服务');
  });

  updateBtn.addEventListener('click',()=>{
    if(waitingWorker){
      waitingWorker.postMessage({type:'SKIP_WAITING'});
      updateBtn.disabled=true;
      updateBtn.textContent='更新中…';
      setStatus('正在切换到新版本…');
    }else{
      location.reload();
    }
  });

  let reloading=false;
  navigator.serviceWorker.addEventListener('controllerchange',()=>{
    if(reloading)return;
    reloading=true;
    location.reload();
  });
}else{
  setStatus('当前浏览器不支持应用安装服务；仍可用浏览器书签方式打开');
}

setInstalledState();

const HOME_SCREEN_BUILD='V4.30.8-HOME-20261116-01';
async function homeScreenColdStartUpdate(){
  if(!standalone||location.protocol!=='http:')return;
  const once='sagi_homescreen_boot_'+HOME_SCREEN_BUILD;
  try{if(sessionStorage.getItem(once))return;sessionStorage.setItem(once,'1')}catch(e){}
  setStatus('主屏幕启动 · 正在同步最新 V4.30.8…');
  try{
    const r=await fetch('/api/update',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',cache:'no-store'});
    const x=await r.json().catch(()=>({}));
    if(r.ok&&x.ok){
      try{localStorage.setItem('sagi_homescreen_last_update',String(Date.now()))}catch(e){}
      location.replace('/?homescreen='+Date.now());
      return;
    }
  }catch(e){}
  setStatus('主屏幕已打开 · 未连接到更新服务，继续使用本机版本');
}
if(standalone){
  window.addEventListener('pageshow',e=>{
    if(e.persisted){
      try{location.replace('/?resume='+Date.now())}catch(_){}
    }
  });
  setTimeout(homeScreenColdStartUpdate,350);
}
})();
</script>

<script>
(function(){
 const btn=document.getElementById('mobileUpdateBtn');
 const rollback=document.getElementById('mobileRollbackBtn');
 const status=document.getElementById('mobileUpdateStatus');
 if(!btn||!status)return;

 btn.addEventListener('click',async()=>{
   if(btn.disabled)return;
   btn.disabled=true;btn.classList.add('busy');btn.textContent='正在安全更新…';status.textContent='只更新控制界面和vMix图形 · Bridge保持锁定';
   try{
     const r=await fetch('/api/update',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',cache:'no-store'});
     const x=await r.json().catch(()=>({}));
     if(!r.ok||!x.ok)throw new Error(x.error||('HTTP '+r.status));
     status.textContent='文件已下载 · 正在核对版本…';
     const verify=await fetch('/?verify='+Date.now(),{cache:'no-store'}).then(r=>r.text()).catch(()=> '');
     if(!verify.includes('V4.30.8'))throw new Error('VERSION_VERIFY_FAILED');
     status.textContent='已确认 V4.30.8 · 更新完成';
     btn.textContent='V4.30.8 ✓';
     setTimeout(()=>location.replace('/?safe='+Date.now()),500);
   }catch(e){
     status.textContent='更新失败 · 当前版本未改变';
     btn.textContent='↻ 安全更新';btn.disabled=false;btn.classList.remove('busy');
   }
 });

 if(rollback)rollback.addEventListener('click',async()=>{
   if(rollback.disabled)return;
   rollback.disabled=true;rollback.textContent='正在回退…';status.textContent='恢复上一次稳定界面和图形';
   try{
     const r=await fetch('/api/rollback',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',cache:'no-store'});
     const x=await r.json().catch(()=>({}));
     if(!r.ok||!x.ok)throw new Error(x.error||('HTTP '+r.status));
     status.textContent='已回退上一版 · 正在刷新';
     setTimeout(()=>location.replace('/?rollback='+Date.now()),650);
   }catch(e){
     status.textContent='没有可用备份或回退失败';
     rollback.textContent='↶ 回退上一版';rollback.disabled=false;
   }
 });
})();
</script>
</body></html>
###SAGI_OUTPUT###
<!doctype html>
<html lang="zh-CN"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SAGI V4.30.8 · STAGE 广播系统 · vMix</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2214%22 fill=%22%2307090d%22/%3E%3Ctext x=%2232%22 y=%2243%22 text-anchor=%22middle%22 font-size=%2234%22 fill=%22%23d8b55b%22%3ES%3C/text%3E%3C/svg%3E">
<style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent;font-family:Arial,"PingFang SC","Microsoft YaHei",sans-serif}.stage{position:absolute;left:0;top:0;width:1920px;height:1080px;overflow:hidden;background:#07090c;transform-origin:0 0}.stadium{position:absolute;inset:0;background:radial-gradient(circle at 50% 0,#6f8294 0,#263442 18%,#111820 42%,#06080b 74%)}.stadium:before{content:"";position:absolute;left:-5%;right:-5%;top:165px;height:300px;background:linear-gradient(#19212a,#0b1016 68%,transparent),repeating-linear-gradient(90deg,#ffffff08 0 7px,transparent 7px 22px);clip-path:polygon(0 0,100% 0,92% 100%,8% 100%)}.stadium:after{content:"";position:absolute;left:0;right:0;bottom:-35px;height:430px;background:linear-gradient(180deg,#173421,#0a2716 70%,#05130a);clip-path:polygon(20% 0,80% 0,100% 100%,0 100%)}.stadiumPhoto{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:none}.shade{position:absolute;inset:0;background:linear-gradient(90deg,#030508e6 0,#05070a99 38%,#05070a55 58%,#030508c9 100%),linear-gradient(0deg,#040609c7 0,transparent 55%,#03050775 100%)}.pitchLines{position:absolute;left:320px;right:320px;bottom:0;height:360px;opacity:.22;transform:perspective(800px) rotateX(62deg);transform-origin:bottom;border:5px solid #fff;border-bottom:0}.pitchLines:before{content:"";position:absolute;left:50%;top:0;bottom:0;border-left:4px solid #fff}.pitchLines:after{content:"";position:absolute;width:170px;height:170px;border:4px solid #fff;border-radius:50%;left:50%;top:45%;transform:translate(-50%,-50%)}.light{position:absolute;width:760px;height:760px;border-radius:50%;filter:blur(100px);opacity:.22}.l1{left:-180px;top:-330px;background:#5cb4ff}.l2{right:-220px;top:-300px;background:#d7b051}.header{position:absolute;left:95px;top:72px;display:flex;align-items:center;gap:24px}.crest{width:96px;height:96px;object-fit:contain;filter:drop-shadow(0 12px 20px #0009)}.team{font-size:34px;font-weight:950;letter-spacing:2px;color:#fff}.sub{font-size:17px;color:#d8b55b;letter-spacing:5px;margin-top:7px;font-weight:850}.groupTitle{position:absolute;left:100px;top:205px;font-size:28px;letter-spacing:7px;color:#d8b55b;font-weight:900}.groupName{position:absolute;left:95px;top:245px;font-size:72px;line-height:1;font-weight:1000;letter-spacing:-2px;color:#fff}.line{position:absolute;left:98px;top:330px;width:400px;height:5px;background:linear-gradient(90deg,#d8b55b,#fff1b7)}.players{position:absolute;left:70px;top:350px;width:1240px;height:650px;display:flex;align-items:flex-end;justify-content:center;gap:18px}.card{position:relative;width:230px;height:570px;flex:0 0 auto}.card.one{width:520px}.cut{position:absolute;left:0;right:0;bottom:82px;height:490px;display:flex;align-items:flex-end;justify-content:center}.cut img{width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 20px 25px #000d)}
.mediaVideo{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 20px 25px #000d);z-index:2;background:transparent}
.mediaFallback{position:absolute;inset:0;display:flex;align-items:flex-end;justify-content:center;z-index:1}
.card.hasMedia .cut:after{content:"球员定妆";position:absolute;right:8%;top:8%;z-index:4;font-size:10px;font-weight:1000;letter-spacing:2px;color:#f3d77f;background:#07090db8;border:1px solid #d8b55b66;border-radius:999px;padding:6px 9px}
.card.action-WALK_IN .mediaVideo{transform:scale(1.08);transform-origin:center bottom}
.card.action-ARMS .mediaVideo{transform:scale(1.03)}
.card.action-LOOK .mediaVideo{transform:scale(1.05)}
.card.action-GK_GLOVES .mediaVideo{transform:scale(1.07)}
.card.action-CELEBRATE .mediaVideo{transform:scale(1.08)}
.mediaTag{display:inline-flex;align-items:center;gap:6px;margin-top:6px;padding:4px 8px;border-radius:999px;background:#d8b55b17;border:1px solid #d8b55b3d;color:#e9cd78;font-size:10px;font-weight:900;letter-spacing:1px}
.directorBadge{display:inline-flex;align-items:center;margin-top:5px;padding:4px 7px;border-radius:999px;background:#ffffff0b;border:1px solid #d8b55b45;color:#d8b55b;font-size:9px;font-weight:900;letter-spacing:.6px}
.card.directed .cut:before{content:"导演";position:absolute;left:8%;top:8%;z-index:5;font-size:9px;font-weight:1000;letter-spacing:1.5px;color:#fff;background:#000a;border:1px solid #ffffff25;border-radius:999px;padding:5px 8px}
.freezeFlash{position:absolute;inset:0;pointer-events:none;z-index:20;background:#fff;opacity:0}
.matchOverlay,.countdownOverlay,.stingOverlay{position:absolute;inset:0;z-index:18;display:none;pointer-events:none}
.matchOverlay.on,.countdownOverlay.on,.stingOverlay.on{display:flex}
.stingOverlay{align-items:center;justify-content:center;background:radial-gradient(circle at center,#18212b 0,#06090d 52%,#020304 100%)}
.stingCore{text-align:center}.stingLogo{width:250px;height:250px;object-fit:contain;filter:drop-shadow(0 28px 40px #000c)}.stingComp{margin-top:20px;font-size:28px;font-weight:1000;letter-spacing:6px;color:#e9d28c}.stingLine{width:360px;height:3px;margin:18px auto;background:linear-gradient(90deg,transparent,#d8b55b,transparent)}
.matchOverlay{align-items:center;justify-content:center;background:linear-gradient(120deg,#040608e8,#0b1117ef)}
.matchCardStage{width:1320px;padding:60px 70px;border:1px solid #ffffff20;background:#070b0fdb;box-shadow:0 28px 100px #000b;position:relative;overflow:hidden}.matchCardStage:before{content:"";position:absolute;left:0;top:0;bottom:0;width:10px;background:#d8b55b}
.matchCompetition{font-size:22px;font-weight:900;letter-spacing:6px;color:#d8b55b}.matchRound{margin-top:8px;font-size:16px;letter-spacing:4px;color:#8e99a6}
.matchTeams{display:grid;grid-template-columns:1fr 130px 1fr;gap:24px;align-items:center;margin-top:42px}.matchTeam{text-align:center;font-size:54px;font-weight:1000;letter-spacing:-2px;color:#fff}.matchVs{text-align:center;font-size:24px;font-weight:1000;letter-spacing:5px;color:#8b95a0}
.matchMetaStage{display:flex;justify-content:center;gap:36px;margin-top:36px;font-size:16px;font-weight:800;letter-spacing:2px;color:#c1c8d0}
.countdownOverlay{align-items:center;justify-content:center;background:radial-gradient(circle,#0c1118ee,#030507f7 68%)}.countdownCore{text-align:center}.countdownLabel{font-size:22px;font-weight:900;letter-spacing:8px;color:#aeb7c1}.countdownNumber{font-size:310px;line-height:.9;font-weight:1000;color:#fff;letter-spacing:-18px;text-shadow:0 0 65px #d8b55b22}.countdownSub{font-size:16px;letter-spacing:5px;color:#d8b55b;margin-top:18px}
.transitionLayer{position:absolute;inset:0;z-index:40;pointer-events:none;opacity:0}.transitionLayer.gold{background:linear-gradient(90deg,#120f08,#d8b55b,#120f08)}.transitionLayer.dark{background:#020305}.transitionLayer.white{background:#fff}
.cueBadgeStage{position:absolute;right:52px;top:36px;z-index:41;padding:8px 12px;border-radius:999px;background:#080b0fcc;border:1px solid #d8b55b66;color:#e5ca7a;font-size:11px;font-weight:1000;letter-spacing:2px;opacity:0}
.sideBadgeStage{position:absolute;left:52px;top:38px;z-index:39;padding:7px 10px;border-radius:999px;background:#080b0fcc;border:1px solid #d8b55b55;color:#e7cd7d;font-size:10px;font-weight:1000;letter-spacing:2px}
.showStepStage{position:absolute;left:52px;bottom:38px;z-index:39;font-size:10px;font-weight:900;letter-spacing:2px;color:#d8b55b99}.fallback{width:84%;height:86%;border-radius:34px;background:linear-gradient(160deg,#222c38,#0c1118);display:flex;align-items:center;justify-content:center;font-size:80px;font-weight:1000;color:#ffffff24;border:1px solid #ffffff10}.label{position:absolute;left:0;right:0;bottom:0;text-align:center}.no{font-size:34px;color:#d8b55b;font-weight:1000}.name{font-size:22px;font-weight:950;text-transform:uppercase;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.role{font-size:12px;color:#9ba4b1;letter-spacing:3px;margin-top:5px}
.roleBackdrop{position:absolute;left:60px;top:300px;width:1160px;height:560px;display:flex;align-items:center;justify-content:center;font-size:260px;font-weight:1000;letter-spacing:-18px;color:#ffffff08;z-index:0;pointer-events:none}
.roleGlow{position:absolute;left:110px;top:330px;width:1120px;height:620px;border-radius:50%;filter:blur(72px);opacity:.22;z-index:0;pointer-events:none;background:radial-gradient(circle,#d8b55b66 0,transparent 68%)}
.players{z-index:2}.players .card{transition:width .25s ease,height .25s ease,margin-bottom .25s ease,opacity .25s ease,filter .25s ease}
.players.layout-GK .card{width:540px;height:620px;margin-bottom:6px;z-index:4}
.players.layout-DF .card:nth-child(1),.players.layout-DF .card:nth-child(4){width:205px;height:500px;margin-bottom:0;opacity:.9;filter:saturate(.9)}
.players.layout-DF .card:nth-child(2),.players.layout-DF .card:nth-child(3){width:275px;height:610px;margin-bottom:28px;z-index:3}
.players.layout-MF .card:nth-child(1),.players.layout-MF .card:nth-child(3){width:250px;height:545px;margin-bottom:0;opacity:.92}
.players.layout-MF .card:nth-child(2){width:350px;height:635px;margin-bottom:30px;z-index:4}
.players.layout-FW .card:nth-child(1),.players.layout-FW .card:nth-child(3){width:265px;height:570px;margin-bottom:8px;opacity:.94}
.players.layout-FW .card:nth-child(2){width:365px;height:650px;margin-bottom:32px;z-index:5}
.stage.group-GK .roleGlow{background:radial-gradient(circle,#67d7ff66 0,transparent 68%);opacity:.26}
.stage.group-DF .roleGlow{background:radial-gradient(circle,#d8b55b60 0,transparent 68%)}
.stage.group-MF .roleGlow{background:radial-gradient(circle,#7b8fff66 0,transparent 68%)}
.stage.group-FW .roleGlow{background:radial-gradient(circle,#ff9a5260 0,transparent 68%);opacity:.27}
.stage.group-GK .l1{background:#62d2ff}.stage.group-GK .l2{background:#d8b55b}
.stage.group-DF .l1{background:#9aa7b3}.stage.group-DF .l2{background:#d8b55b}
.stage.group-MF .l1{background:#6f82ff}.stage.group-MF .l2{background:#d8b55b}
.stage.group-FW .l1{background:#d8b55b}.stage.group-FW .l2{background:#ff8f55}
.card:before{content:"";position:absolute;left:12%;right:12%;bottom:72px;height:120px;border-radius:50%;background:radial-gradient(ellipse,#000b 0,transparent 70%);filter:blur(15px);z-index:-1}
.cut{z-index:1}.label{z-index:3}.tunnelScene{position:absolute;inset:0;overflow:hidden;perspective:1200px;z-index:0}
.tunnelScene .tunnelBack{position:absolute;left:50%;top:13%;width:480px;height:610px;transform:translateX(-50%);background:linear-gradient(#10151b,#05080b 62%);border:3px solid #ffffff18;box-shadow:0 0 120px #000 inset,0 0 80px #d8b55b18;clip-path:polygon(15% 0,85% 0,100% 100%,0 100%)}
.tunnelScene .portal{position:absolute;left:50%;top:31%;width:270px;height:430px;transform:translateX(-50%);background:linear-gradient(#afc7da55,#193726 54%,#0f2618);box-shadow:0 0 90px #95d8ff33,0 0 120px #d8b55b1f inset;border:2px solid #ffffff1f;overflow:hidden}
.tunnelScene .portal:before{content:"";position:absolute;left:-15%;right:-15%;bottom:-20px;height:220px;background:linear-gradient(#1d5b34,#0d2b19);clip-path:polygon(15% 0,85% 0,100% 100%,0 100%)}
.tunnelScene .wall{position:absolute;top:0;bottom:0;width:46%;transform-style:preserve-3d;filter:drop-shadow(0 0 26px #000)}
.tunnelScene .wall.left{left:-8%;clip-path:polygon(0 0,100% 14%,75% 100%,0 100%);background:linear-gradient(90deg,#020305 0,#090d12 68%,#1b222a)}
.tunnelScene .wall.right{right:-8%;clip-path:polygon(0 14%,100% 0,100% 100%,25% 100%);background:linear-gradient(270deg,#020305 0,#090d12 68%,#1b222a)}
.tunnelScene .ceiling{position:absolute;left:12%;right:12%;top:-6%;height:240px;background:linear-gradient(#06080b,#131922);clip-path:polygon(8% 0,92% 0,76% 100%,24% 100%);box-shadow:0 18px 40px #000}
.tunnelScene .floor{position:absolute;left:8%;right:8%;bottom:-5%;height:390px;background:linear-gradient(#161b20,#050709 72%);clip-path:polygon(24% 0,76% 0,100% 100%,0 100%)}
.tunnelScene .floor:before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0 110px,#ffffff08 112px 114px,transparent 116px 220px),linear-gradient(90deg,transparent,#d8b55b0d,transparent);transform:perspective(800px) rotateX(56deg);transform-origin:bottom}
.tunnelScene .led{position:absolute;top:185px;width:410px;height:470px;background:linear-gradient(#0a0d11,#111721);border:1px solid #d8b55b44;box-shadow:0 0 35px #d8b55b18 inset,0 0 22px #000;display:flex;align-items:center;justify-content:center;overflow:hidden}
.tunnelScene .led.left{left:95px;transform:skewY(7deg)}.tunnelScene .led.right{right:95px;transform:skewY(-7deg)}
.tunnelScene .led:before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,#ffffff05 0 2px,transparent 2px 8px)}
.tunnelScene .ledText{position:relative;z-index:2;font-size:42px;font-weight:1000;letter-spacing:4px;color:#e7cf8a;text-align:center;max-width:330px;text-shadow:0 0 18px #d8b55b55;line-height:1.08}.tunnelScene .ledText small{display:block;margin-top:14px;font-size:16px;letter-spacing:6px;color:#ffffffaa}
.tunnelScene .roofLights{position:absolute;left:460px;right:460px;top:115px;height:26px;background:repeating-linear-gradient(90deg,#ffffff0a 0 30px,#fff6c4 32px 42px,#ffffff0a 44px 82px);box-shadow:0 0 24px #fff6c455}
.tunnelScene .fog{position:absolute;left:20%;right:20%;bottom:12%;height:240px;background:radial-gradient(ellipse,#ffffff12 0,transparent 66%);filter:blur(35px);opacity:.8}.tunnelScene .cameraVignette{position:absolute;inset:0;background:radial-gradient(circle at 50% 52%,transparent 0 34%,#0008 76%,#000d 100%)}
.stage.tunnel-open .tunnelScene .wall.left{transform:translateX(-110px)}.stage.tunnel-open .tunnelScene .wall.right{transform:translateX(110px)}
.stage.tunnel-open .tunnelScene .led.left{transform:translateX(-90px) skewY(7deg);opacity:.45}.stage.tunnel-open .tunnelScene .led.right{transform:translateX(90px) skewY(-7deg);opacity:.45}
.stage.tunnel-open .tunnelScene .portal{box-shadow:0 0 150px #b6e2ff99,0 0 180px #ffffff44 inset}
.stage.scene-stadium .tunnelScene,.stage.scene-transparent .tunnelScene,.stage.scene-chroma .tunnelScene{display:none}
.stage.scene-tunnel .stadium,.stage.scene-tunnel .stadiumPhoto,.stage.scene-tunnel .shade,.stage.scene-tunnel .pitchLines{display:none!important}
.tunnelScene,.tunnelScene .wall,.tunnelScene .led,.tunnelScene .portal{transition:transform .7s cubic-bezier(.2,.8,.2,1),opacity .55s ease,box-shadow .55s ease}
.formation{position:absolute;right:78px;top:175px;width:500px;height:760px;border:1px solid #ffffff20;border-radius:32px;background:#05080cc7;padding:28px}.formationHead{display:flex;justify-content:space-between}.formationTitle{font-size:25px;font-weight:950;color:#fff}.formationText{font-size:42px;color:#d8b55b;font-weight:1000}.pitch{position:absolute;left:34px;right:34px;top:120px;bottom:34px;border:3px solid #ffffff50;background:linear-gradient(#123d25,#0e321e);overflow:hidden}.pitch:before{content:"";position:absolute;left:0;right:0;top:50%;border-top:2px solid #ffffff55}.pitch:after{content:"";position:absolute;width:115px;height:115px;border:2px solid #ffffff55;border-radius:50%;left:50%;top:50%;transform:translate(-50%,-50%)}.boxTop,.boxBottom{position:absolute;left:50%;width:220px;height:90px;transform:translateX(-50%);border:2px solid #ffffff55}.boxTop{top:-2px}.boxBottom{bottom:-2px}.nodes{position:absolute;inset:0}.node{position:absolute;width:76px;height:92px;border-radius:16px;transform:translate(-50%,-50%);background:#0c131b;border:1px solid #ffffff36;display:flex;align-items:center;justify-content:center;font-weight:1000;font-size:15px;color:#fff;box-shadow:0 8px 18px #0008;overflow:visible}.nodeVisual{position:absolute;left:3px;right:3px;top:3px;height:68px;border-radius:13px;overflow:hidden;background:linear-gradient(180deg,#263649,#101720);display:flex;align-items:flex-end;justify-content:center}.nodeVisual img{width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 6px 7px #0008)}.nodeFallbackNo{font-size:24px;color:#ffffff55;align-self:center}.nodeNo{position:absolute;left:5px;top:5px;z-index:3;min-width:24px;height:24px;padding:0 5px;border-radius:999px;background:#07090dcc;border:1px solid #ffffff33;color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;box-shadow:0 3px 8px #0008}.node.active{border-color:#f0d27a;box-shadow:0 0 0 4px #d8b55b30,0 10px 22px #0009}.node.active .nodeNo{background:#d8b55b;color:#111;border-color:#fff0b5}.node small{position:absolute;left:50%;top:76px;transform:translateX(-50%);font-size:10px;color:#f3f5f7;white-space:nowrap;max-width:104px;overflow:hidden;text-overflow:ellipsis;text-shadow:0 2px 5px #000;font-weight:900}.node:not(.hasPhoto){width:62px;height:72px;border-radius:50%}.node:not(.hasPhoto) .nodeVisual{inset:3px;height:auto;border-radius:50%;align-items:center}.node:not(.hasPhoto) .nodeNo{display:none}.node:not(.hasPhoto) small{top:76px}.captainNode:after{z-index:6}.fullList{position:absolute;left:95px;top:355px;width:1130px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px 28px}.fullRow{display:grid;grid-template-columns:54px 56px 1fr auto;gap:10px;align-items:center;border-bottom:1px solid #ffffff12;padding:8px 4px;color:#fff}.fullRole{font-size:12px;color:#d8b55b;font-weight:900}.fullNo{font-size:25px;font-weight:1000}.fullName{font-size:22px;font-weight:900}.fullPos{font-size:11px;color:#98a1ad}

.captainBadge{display:inline-flex;align-items:center;justify-content:center;min-width:30px;height:30px;border-radius:50%;background:#d8b55b;color:#111;font-size:14px;font-weight:1000;margin-left:7px;vertical-align:middle}
.statPill{display:inline-flex;align-items:center;gap:7px;margin-top:8px;padding:6px 10px;border-radius:999px;background:#ffffff0d;border:1px solid #ffffff1b;color:#d8b55b;font-size:11px;font-weight:900;letter-spacing:1px}
.subList{position:absolute;left:95px;top:355px;width:1130px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px 28px}
.subRow{display:grid;grid-template-columns:56px 1fr auto;gap:12px;align-items:center;border-bottom:1px solid #ffffff12;padding:10px 5px;color:#fff}
.subNo{font-size:24px;font-weight:1000;color:#d8b55b}.subName{font-size:21px;font-weight:900}.subStat{font-size:11px;color:#aab2be}
.captainNode:after{content:'C';position:absolute;right:-6px;top:-7px;width:19px;height:19px;border-radius:50%;background:#fff1b7;color:#111;font-size:10px;display:flex;align-items:center;justify-content:center;font-weight:1000}

/* ===== V4.7 SCOREBUG V2 ===== */
.graphicsStage{position:absolute;left:0;top:0;width:1920px;height:1080px;transform-origin:0 0;overflow:hidden;pointer-events:none;color:#fff;z-index:9999}
.scoreBug{--home:#d8b55b;--away:#4c7dff;--accent:#f4f0e8;position:absolute;left:50%;top:34px;transform:translateX(-50%);display:none;height:84px;border-radius:17px;background:linear-gradient(180deg,#121820f7,#070a0ef9);border:1px solid #ffffff24;box-shadow:0 18px 54px #000a,0 1px 0 #ffffff18 inset;overflow:hidden;align-items:stretch;font-weight:900;backdrop-filter:blur(16px);transition:.2s}
.scoreBug.on{display:flex}.scoreBug.frozen{box-shadow:0 18px 54px #000a,0 0 0 2px #e4c97966}.scoreBug.frozen:before{content:'FROZEN';position:absolute;right:8px;bottom:4px;font-size:7px;letter-spacing:1.5px;color:#e4c979;z-index:8}
.sbTeamBlock{position:relative;min-width:270px;max-width:360px;padding:0 20px;display:flex;align-items:center;gap:11px;background:#0e131a;color:#fff}
.sbTeamBlock.home{border-left:7px solid var(--home)}.sbTeamBlock.away{border-right:7px solid var(--away);flex-direction:row-reverse}
.sbCrest{width:42px;height:42px;object-fit:contain;filter:drop-shadow(0 5px 8px #0009);display:none}.sbCrest.on{display:block}
.sbTeamMeta{min-width:0;display:flex;align-items:center;gap:8px;flex:1}.sbTeamBlock.away .sbTeamMeta{justify-content:flex-end}
.sbTeam{font-size:23px;line-height:1.02;font-weight:1000;letter-spacing:.35px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:205px;text-shadow:0 2px 7px #0008}
.sbReds{display:flex;gap:3px;min-width:0}.sbRedCard{width:7px;height:12px;border-radius:1px;background:#df3038;box-shadow:0 2px 5px #0008}
.sbScoreWrap{width:82px;display:flex;flex-direction:column;align-items:center;justify-content:center;background:#f7f8fa;color:#090c10;position:relative}
.sbScore{font-size:38px;font-weight:1000;line-height:1}.sbPenalty{font-size:8px;letter-spacing:1px;margin-top:3px;color:#59616a;font-weight:1000;display:none}.sbPenalty.on{display:block}
#sbHomeScoreWrap{box-shadow:inset 0 -5px 0 var(--home)}#sbAwayScoreWrap{box-shadow:inset 0 -5px 0 var(--away)}
.sbMid{width:142px;display:flex;flex-direction:column;align-items:center;justify-content:center;background:linear-gradient(180deg,#161d26,#0b1016);border-left:1px solid #ffffff10;border-right:1px solid #ffffff10;position:relative}
.sbCompetition{position:absolute;top:4px;font-size:6px;letter-spacing:1.5px;color:#8995a3;max-width:120px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sbClockRow{display:flex;align-items:center;gap:6px;margin-top:8px}.sbClock{font-size:22px;font-variant-numeric:tabular-nums;letter-spacing:1px;color:#fff}.sbStoppage{display:none;padding:3px 5px;border-radius:5px;background:var(--accent);color:#0a0d11;font-size:9px;font-weight:1000}.sbStoppage.on{display:block}.sbPeriod{font-size:8px;color:var(--accent);letter-spacing:2.2px;margin-top:3px;font-weight:1000}
.scoreBug.theme-premier{background:#fff;border-color:#fff;color:#1b092e;box-shadow:0 16px 45px #0008}.scoreBug.theme-premier .sbTeamBlock{background:#f7f6fa;color:#23112f}.scoreBug.theme-premier .sbMid{background:#2b0b3f}.scoreBug.theme-premier .sbScoreWrap{background:#21e89b;color:#170722}.scoreBug.theme-premier .sbPeriod{color:#21e89b}.scoreBug.theme-premier .sbCompetition{color:#c7b9d3}
.scoreBug.theme-uefa{height:76px;border-radius:4px;background:#071a34;border-color:#31527b;box-shadow:0 12px 35px #0009}.scoreBug.theme-uefa .sbTeamBlock{background:#0a2343}.scoreBug.theme-uefa .sbMid{background:#06172c}.scoreBug.theme-uefa .sbScoreWrap{background:#fff;color:#071a34}.scoreBug.theme-uefa .sbTeam{font-size:17px;letter-spacing:1.4px}.scoreBug.theme-uefa .sbCrest{width:36px;height:36px}.scoreBug.theme-uefa .sbPeriod{color:#73b8ff}
.eventCard{position:absolute;left:78px;bottom:72px;width:760px;min-height:176px;background:linear-gradient(115deg,#080b10f5,#111923f2);border:1px solid #ffffff23;border-left:8px solid #d8b55b;border-radius:8px;box-shadow:0 24px 75px #000b;display:none;align-items:center;padding:28px 34px;gap:26px}
.eventCard.on{display:flex}.eventIcon{width:104px;height:104px;border-radius:14px;display:flex;align-items:center;justify-content:center;background:#d8b55b;color:#0a0c0f;font-size:54px;font-weight:1000}.eventCard.yellow .eventIcon{background:#f2d536}.eventCard.red .eventIcon{background:#db3038;color:#fff}.eventCard.sub .eventIcon{background:#2786b5;color:#fff}
.eventKicker{font-size:15px;font-weight:1000;letter-spacing:5px;color:#d8b55b}.eventName{font-size:42px;font-weight:1000;margin-top:7px}.eventMeta{font-size:16px;color:#b4bdc8;margin-top:8px;letter-spacing:1px}.eventCard.yellow{border-left-color:#f2d536}.eventCard.red{border-left-color:#db3038}.eventCard.sub{border-left-color:#2786b5}
.subRows{display:grid;gap:8px;margin-top:8px}.subRowG{font-size:25px;font-weight:950}.subRowG.in{color:#72d99c}.subRowG.out{color:#ef777d}.subArrow{font-size:17px;margin-right:10px}
.stateSplash{position:absolute;inset:0;display:none;align-items:center;justify-content:center;background:radial-gradient(circle at center,#0f151ddd,#020304f5 72%)}.stateSplash.on{display:flex}.stateBox{min-width:900px;text-align:center;padding:55px 70px;border:1px solid #ffffff22;background:#070b10e8;box-shadow:0 30px 100px #000c}.stateKicker{font-size:20px;letter-spacing:8px;color:#d8b55b;font-weight:1000}.stateTitle{font-size:92px;font-weight:1000;margin-top:12px;letter-spacing:-3px}.stateScore{font-size:74px;font-weight:1000;margin-top:25px}.stateTeams{font-size:22px;color:#aab4c0;margin-top:10px}.mvpName{font-size:82px;font-weight:1000;margin-top:18px}.mvpMeta{font-size:24px;color:#d8b55b;margin-top:8px;letter-spacing:3px}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.stage{--teamAccent:#d8b55b}
.stage .sub,.stage .groupTitle,.stage .formationText{color:var(--teamAccent)}
.stage .line{background:linear-gradient(90deg,var(--teamAccent),#fff,transparent)}
.stage .node.active{border-color:var(--teamAccent);box-shadow:0 0 0 4px #ffffff18,0 12px 28px #000b}
.stage .node.active .nodeNo{background:var(--teamAccent);color:#090b0f}
.stage .nodeVisual:after{content:"";position:absolute;left:0;right:0;bottom:0;height:4px;background:var(--teamAccent);opacity:.95}
.stage.group-FULL .header{left:88px;top:48px;z-index:12}
.stage.group-FULL .crest{width:82px;height:82px}
.stage.group-FULL .team{font-size:30px;letter-spacing:1px}
.stage.group-FULL .sub{font-size:13px;letter-spacing:4px;margin-top:5px}
.stage.group-FULL .groupTitle{left:90px;top:188px;font-size:16px;letter-spacing:5px}
.stage.group-FULL .groupName{left:88px;top:224px;font-size:46px;letter-spacing:-1px}
.stage.group-FULL .line{left:90px;top:286px;width:310px;height:4px}
.stage.group-FULL .fullList{left:86px;top:330px;width:348px;grid-template-columns:1fr;gap:5px}
.stage.group-FULL .fullRow{grid-template-columns:34px 40px 1fr;gap:8px;padding:7px 9px;border:1px solid #ffffff12;border-left:3px solid var(--teamAccent);border-radius:8px;background:linear-gradient(90deg,#0a0f16e8,#0a0f169c);animation:plRowIn .42s cubic-bezier(.2,.8,.2,1) both;animation-delay:calc(var(--row-i,0)*38ms + 120ms)}
.stage.group-FULL .fullRole{font-size:9px;letter-spacing:1px;color:var(--teamAccent)}
.stage.group-FULL .fullNo{font-size:16px}
.stage.group-FULL .fullName{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.stage.group-FULL .fullPos{display:none}
.stage.group-FULL .captainBadge{min-width:20px;height:20px;font-size:10px;margin-left:4px}
.stage.group-FULL .formation{left:470px;right:auto;top:84px;width:1368px;height:910px;padding:34px;border-radius:28px;background:linear-gradient(145deg,#080d13ee,#101923e8 58%,#070b10f2);border:1px solid #ffffff20;box-shadow:0 34px 90px #000a,0 0 0 1px #ffffff08 inset;animation:plBoardIn .62s cubic-bezier(.16,.84,.28,1) both}
.stage.group-FULL .formation:before{content:"";position:absolute;left:34px;right:34px;top:0;height:5px;background:linear-gradient(90deg,var(--teamAccent),transparent 72%);border-radius:0 0 8px 8px}
.stage.group-FULL .formationHead{align-items:center}
.stage.group-FULL .formationTitle{font-size:18px;letter-spacing:5px}
.stage.group-FULL .formationText{font-size:50px;letter-spacing:-2px}
.stage.group-FULL .pitch{left:42px;right:42px;top:118px;bottom:42px;border:2px solid #ffffff55;border-radius:12px;background:linear-gradient(90deg,#143824,#0e2f1d 50%,#143824);box-shadow:0 22px 55px #0008 inset,0 0 0 1px #0005}
.stage.group-FULL .pitch:before{border-top-color:#ffffff48}
.stage.group-FULL .pitch:after{border-color:#ffffff48;width:145px;height:145px}
.stage.group-FULL .boxTop,.stage.group-FULL .boxBottom{width:280px;height:105px;border-color:#ffffff48}
.stage.group-FULL .node{width:104px;height:118px;border-radius:17px;background:#0b1118e8;border-color:#ffffff30;box-shadow:0 12px 24px #000a;animation:plNodeIn .5s cubic-bezier(.16,.84,.28,1) both;animation-delay:calc(var(--node-i,0)*58ms + 220ms)}
.stage.group-FULL .nodeVisual{height:88px;border-radius:14px;background:linear-gradient(180deg,#27394d,#121a24)}
.stage.group-FULL .node small{top:94px;max-width:126px;font-size:11px;letter-spacing:.2px}
.stage.group-FULL .nodeNo{left:6px;top:6px;min-width:27px;height:27px;font-size:11px}
.stage.group-FULL .node:not(.hasPhoto){width:68px;height:68px}
.stage.group-FULL .node:not(.hasPhoto) small{top:73px}
.stage.group-FULL .node:not(.hasPhoto) .nodeFallbackNo{font-size:25px}
.stage.group-FULL .node:not(.hasPhoto) .nodeVisual:after{display:none}
@keyframes plBoardIn{from{opacity:0;transform:translateX(55px) scale(.975)}to{opacity:1;transform:translateX(0) scale(1)}}
@keyframes plNodeIn{0%{opacity:0;transform:translate(-50%,-38%) scale(.72)}70%{opacity:1;transform:translate(-50%,-52%) scale(1.04)}100%{opacity:1;transform:translate(-50%,-50%) scale(1)}}
@keyframes plRowIn{from{opacity:0;transform:translateX(-24px)}to{opacity:1;transform:translateX(0)}}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.scoreBug.theme-sagi-pro{height:72px;top:28px;border-radius:8px;background:#071019;border:1px solid #ffffff1f;box-shadow:0 14px 36px #0009;overflow:hidden;animation:sbIn .32s cubic-bezier(.2,.8,.2,1) both}
.scoreBug.theme-sagi-pro .sbTeamBlock{min-width:210px;max-width:270px;padding:0 15px;background:#0a1119}
.scoreBug.theme-sagi-pro .sbTeamBlock.home{border-left:5px solid var(--home)}
.scoreBug.theme-sagi-pro .sbTeamBlock.away{border-right:5px solid var(--away)}
.scoreBug.theme-sagi-pro .sbCrest{width:34px;height:34px}
.scoreBug.theme-sagi-pro .sbTeam{font-size:16px;letter-spacing:1px}
.scoreBug.theme-sagi-pro .sbScoreWrap{width:66px;background:#f4f6f8;color:#05080c}
.scoreBug.theme-sagi-pro .sbScore{font-size:32px;letter-spacing:-1px}
.scoreBug.theme-sagi-pro #sbHomeScoreWrap{box-shadow:inset 0 -4px 0 var(--home)}
.scoreBug.theme-sagi-pro #sbAwayScoreWrap{box-shadow:inset 0 -4px 0 var(--away)}
.scoreBug.theme-sagi-pro .sbMid{width:120px;background:#071019;border-color:#ffffff12}
.scoreBug.theme-sagi-pro .sbClock{font-size:19px}.scoreBug.theme-sagi-pro .sbCompetition{font-size:6px;letter-spacing:1.3px}.scoreBug.theme-sagi-pro .sbPeriod{font-size:7px;letter-spacing:2px;color:var(--accent)}
.scoreBug.theme-sagi-pro .sbStoppage{font-size:8px;border-radius:3px}
.scoreBug.theme-sagi-pro .sbPenalty{font-size:7px}
.eventCard{--eventAccent:#d8b55b;left:58px;bottom:58px;width:920px;height:230px;min-height:0;padding:0 32px 0 0;gap:0;border:0;border-radius:10px;background:linear-gradient(105deg,#060a0ff7,#111b26f5);box-shadow:0 28px 80px #000c;overflow:hidden;align-items:stretch;animation:eventIn .46s cubic-bezier(.16,.84,.28,1) both}
.eventCard:before{content:"";position:absolute;left:0;right:0;top:0;height:5px;background:var(--eventAccent);z-index:5}
.eventPhotoWrap{width:230px;min-width:230px;height:230px;display:none;align-items:flex-end;justify-content:center;background:linear-gradient(150deg,#1c2b39,#0a1118);overflow:hidden;position:relative}
.eventPhotoWrap.on{display:flex}.eventPhoto{width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 12px 18px #0008)}
.eventIcon{width:86px;height:86px;min-width:86px;border-radius:50%;margin:72px 24px 0 26px;font-size:42px;background:var(--eventAccent);box-shadow:0 0 0 8px #ffffff08}
.eventCopy{display:flex;flex-direction:column;justify-content:center;min-width:0;flex:1}
.eventKicker{font-size:13px;letter-spacing:5px;color:var(--eventAccent)}
.eventName{font-size:48px;line-height:1.02;margin-top:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.eventMeta{font-size:15px;margin-top:9px;color:#aeb9c6}
.eventCard.yellow{--eventAccent:#f2d536;border-left:0}.eventCard.red{--eventAccent:#e33440;border-left:0}.eventCard.sub{--eventAccent:#39a7db;border-left:0}
.eventCard.yellow .eventIcon,.eventCard.red .eventIcon,.eventCard.sub .eventIcon{background:var(--eventAccent)}
.eventCard.yellow .eventIcon,.eventCard.red .eventIcon{width:58px;height:82px;min-width:58px;border-radius:7px;margin:74px 38px 0 34px;font-size:0;transform:rotate(-3deg);box-shadow:0 12px 24px #0008,0 0 0 1px #0005,inset 0 0 0 2px #ffffff35;position:relative}
.eventCard.yellow .eventIcon:before,.eventCard.red .eventIcon:before{content:"";position:absolute;inset:5px;border-radius:4px;border:1px solid #ffffff2c;background:linear-gradient(155deg,#ffffff28,transparent 38%,#00000012 100%)}
.eventCard.yellow .eventIcon{background-color:#f2d536!important;background-image:linear-gradient(155deg,#ffe85b 0,#f2d536 44%,#d8b900 100%)!important}
.eventCard.red .eventIcon{background-color:#e33440!important;background-image:linear-gradient(155deg,#ff5c66 0,#e33440 46%,#b81724 100%)!important}
.subRows{gap:5px;margin-top:10px}.subRowG{font-size:22px}.subRowG.in{color:#76e3a6}.subRowG.out{color:#ff868c}
.stateSplash{background:radial-gradient(circle at 60% 40%,#101c28e8,#020406f8 68%);backdrop-filter:blur(5px)}
.stateBox{position:relative;width:1420px;min-width:0;height:690px;text-align:left;padding:0;border:1px solid #ffffff1d;border-radius:18px;background:linear-gradient(120deg,#071019f4,#0c1722f2);box-shadow:0 36px 120px #000d;overflow:hidden;display:flex;align-items:stretch}
.stateAccent{position:absolute;left:0;top:0;bottom:0;width:8px;background:var(--stateAccent,#d8b55b)}
.stateCopy{position:relative;z-index:2;flex:1;display:flex;flex-direction:column;justify-content:center;padding:70px 86px}
.stateKicker{font-size:17px;letter-spacing:8px;color:var(--stateAccent,#d8b55b)}
.stateTitle{font-size:100px;line-height:.95;margin-top:18px;letter-spacing:-4px}
.stateScore{font-size:86px;line-height:1;margin-top:34px}
.stateTeams{font-size:20px;margin-top:14px}
.mvpPhoto{display:none;width:540px;min-width:540px;height:690px;object-fit:contain;object-position:center bottom;background:linear-gradient(155deg,#182635,#071019);filter:drop-shadow(0 22px 32px #0009)}
.stateSplash.mvp .mvpPhoto{display:block}
.stateSplash.mvp .stateTitle{font-size:34px;letter-spacing:5px;color:#9eabb8;margin-top:24px}
.stateSplash.mvp .stateScore{font-size:34px;color:#dbe1e7;margin-top:24px}
.stateSplash.mvp .mvpName{font-size:76px;line-height:1.02;margin-top:18px}
.stateSplash.mvp .mvpMeta{font-size:20px;color:var(--stateAccent,#d8b55b)}
@keyframes sbIn{from{opacity:0;transform:translateX(-50%) translateY(-18px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}
@keyframes eventIn{from{opacity:0;transform:translateX(-48px) scale(.98)}to{opacity:1;transform:translateX(0) scale(1)}}


/* ===== V4.30.8 SHOT SAFETY ENGINE ===== */
.scoreBug{display:flex!important;opacity:0;visibility:hidden;pointer-events:none;transform:translateX(-50%) translateY(-18px) scale(.985);transition:opacity .24s ease,transform .36s cubic-bezier(.16,.84,.28,1),visibility 0s linear .36s}
.scoreBug.on{opacity:1;visibility:visible;transform:translateX(-50%) translateY(0) scale(1);transition-delay:0s}
.scoreBug.theme-sagi-pro{animation:none}
.scoreBug.motionPulse .sbMid{animation:sbClockPunch .34s cubic-bezier(.2,.8,.2,1)}
.sbScoreWrap.scoreChanged{animation:sbScoreWrapPunch .52s cubic-bezier(.16,.84,.28,1)}
.sbScore.scoreChanged{animation:sbScoreNumberPunch .52s cubic-bezier(.16,.84,.28,1)}
.eventCard{animation:none;opacity:0;transform:translateX(-46px) scale(.985)}
.eventCard.on{opacity:1;transform:translateX(0) scale(1)}
.eventCard.motionIn{animation:eventCardIn .46s cubic-bezier(.16,.84,.28,1) both}
.eventCard.motionOut{animation:eventCardOut .30s cubic-bezier(.4,0,.8,.2) both}
.eventPhotoWrap.motionIn{animation:eventPhotoIn .58s cubic-bezier(.16,.84,.28,1) both}
.eventIcon.motionIn{animation:eventIconIn .46s .08s cubic-bezier(.16,.84,.28,1) both}
.eventCopy.motionIn{animation:eventCopyIn .48s .12s cubic-bezier(.16,.84,.28,1) both}
.subRows .subRowG{opacity:0;transform:translateX(24px)}
.subRows.motionIn .subRowG:first-child{animation:subRowIn .34s .22s ease-out both}
.subRows.motionIn .subRowG:last-child{animation:subRowIn .34s .34s ease-out both}
.stateSplash{opacity:0;transition:opacity .28s ease}
.stateSplash.on{opacity:1}
.stateSplash.motionOut{animation:splashOut .34s ease-in both}
.stateBox.motionIn{animation:stateBoxIn .58s cubic-bezier(.16,.84,.28,1) both}
.stateSplash.mvp .mvpPhoto.motionIn{animation:mvpPhotoIn .68s .08s cubic-bezier(.16,.84,.28,1) both}
.stateSplash.mvp .stateCopy.motionIn{animation:mvpCopyIn .58s .18s cubic-bezier(.16,.84,.28,1) both}
.graphicsStage.goalFlash:after{content:"";position:absolute;inset:0;background:radial-gradient(circle at 50% 42%,#ffffff30,transparent 48%);animation:goalFlash .42s ease-out both;pointer-events:none}
@keyframes sbScoreWrapPunch{0%{transform:scale(1);filter:brightness(1)}35%{transform:scale(1.12);filter:brightness(1.28)}70%{transform:scale(.97)}100%{transform:scale(1);filter:brightness(1)}}
@keyframes sbScoreNumberPunch{0%{transform:translateY(10px) scale(.72);opacity:.2}55%{transform:translateY(-4px) scale(1.22);opacity:1}100%{transform:translateY(0) scale(1);opacity:1}}
@keyframes sbClockPunch{0%,100%{transform:scale(1)}50%{transform:scale(1.04)}}
@keyframes eventCardIn{0%{opacity:0;transform:translateX(-54px) scale(.975)}68%{opacity:1;transform:translateX(7px) scale(1.006)}100%{opacity:1;transform:translateX(0) scale(1)}}
@keyframes eventCardOut{0%{opacity:1;transform:translateX(0) scale(1)}100%{opacity:0;transform:translateX(-36px) scale(.985)}}
@keyframes eventPhotoIn{0%{opacity:0;transform:translateX(-30px) scale(1.08)}100%{opacity:1;transform:translateX(0) scale(1)}}
@keyframes eventIconIn{0%{opacity:0;transform:scale(.45) rotate(-12deg)}70%{opacity:1;transform:scale(1.10) rotate(2deg)}100%{opacity:1;transform:scale(1) rotate(0)}}
@keyframes eventCopyIn{0%{opacity:0;transform:translateX(30px)}100%{opacity:1;transform:translateX(0)}}
@keyframes subRowIn{0%{opacity:0;transform:translateX(24px)}100%{opacity:1;transform:translateX(0)}}
@keyframes stateBoxIn{0%{opacity:0;transform:translateY(38px) scale(.97)}70%{opacity:1;transform:translateY(-5px) scale(1.006)}100%{opacity:1;transform:translateY(0) scale(1)}}
@keyframes mvpPhotoIn{0%{opacity:0;transform:translateX(-70px) scale(1.06)}100%{opacity:1;transform:translateX(0) scale(1)}}
@keyframes mvpCopyIn{0%{opacity:0;transform:translateX(52px)}100%{opacity:1;transform:translateX(0)}}
@keyframes splashOut{0%{opacity:1}100%{opacity:0}}
@keyframes goalFlash{0%{opacity:0}28%{opacity:1}100%{opacity:0}}


/* ===== V4.30.8 CAMERA + GRAPHICS COORDINATION ===== */
.graphicsStage.eventActive .scoreBug.on{transform:translateX(-50%) translateY(0) scale(.96);filter:brightness(.92);transition:transform .32s cubic-bezier(.16,.84,.28,1),filter .25s ease}
.graphicsStage.eventActive .scoreBug.on .sbMid{box-shadow:0 0 0 1px #ffffff0c inset}


/* ===== V4.30.8 COMPACT SCOREBUG + GOAL EXPAND ===== */
.scoreBug{
  left:58px!important;top:42px!important;transform:translateY(-14px) scale(.985)!important;
  height:68px!important;border-radius:10px!important;overflow:hidden!important;
  box-shadow:0 12px 36px #0009,0 1px 0 #ffffff16 inset!important;
  backdrop-filter:blur(12px);transform-origin:left top;
  transition:opacity .22s ease,transform .34s cubic-bezier(.16,.84,.28,1),visibility 0s linear .34s,box-shadow .28s ease!important
}
.scoreBug.on{transform:translateY(0) scale(1)!important;transition-delay:0s!important}
.scoreBug .sbTeamBlock{min-width:190px!important;max-width:225px!important;padding:0 13px!important;gap:8px!important}
.scoreBug .sbTeamBlock.home{border-left-width:5px!important}.scoreBug .sbTeamBlock.away{border-right-width:5px!important}
.scoreBug .sbCrest{width:34px!important;height:34px!important}
.scoreBug .sbTeamMeta{gap:5px!important}
.scoreBug .sbTeam{font-size:20px!important;max-width:152px!important;letter-spacing:.15px!important}
.scoreBug .sbReds{gap:2px!important}.scoreBug .sbRedCard{width:6px!important;height:10px!important}
.scoreBug .sbScoreWrap{width:58px!important;min-width:58px!important}
.scoreBug .sbScore{font-size:31px!important}
.scoreBug .sbPenalty{font-size:7px!important}
.scoreBug .sbMid{width:108px!important;min-width:108px!important}
.scoreBug .sbCompetition{top:3px!important;max-width:92px!important;font-size:5px!important;letter-spacing:1px!important}
.scoreBug .sbClockRow{margin-top:7px!important;gap:4px!important}
.scoreBug .sbClock{font-size:18px!important;letter-spacing:.4px!important}
.scoreBug .sbPeriod{font-size:7px!important;letter-spacing:1.5px!important;margin-top:2px!important}
.scoreBug .sbStoppage{font-size:7px!important;padding:2px 4px!important}
.graphicsStage.eventActive .scoreBug.on{transform:translateY(0) scale(.97)!important;filter:brightness(.94)}
.sbGoalBurst{
  width:0;min-width:0;height:68px;display:flex;flex-direction:column;align-items:center;justify-content:center;
  position:relative;opacity:0;overflow:hidden;background:linear-gradient(115deg,#0b1017,#131a23);
  border-left:0 solid var(--goalAccent,var(--accent));transition:width .46s cubic-bezier(.16,.84,.28,1),opacity .20s ease,border-width .30s ease;
  isolation:isolate
}
.sbGoalBurst:before{content:"";position:absolute;inset:0;background:linear-gradient(110deg,var(--goalAccent,var(--accent)) 0,transparent 38%);opacity:.20;z-index:-1}
.sbGoalBurst:after{content:"";position:absolute;left:0;right:0;bottom:0;height:4px;background:var(--goalAccent,var(--accent));box-shadow:0 0 20px var(--goalAccent,var(--accent));transform:scaleX(0);transform-origin:left}
.scoreBug.goalExpand{box-shadow:0 15px 46px #000b,0 0 0 1px #ffffff12 inset!important}
.scoreBug.goalExpand .sbGoalBurst{width:290px;min-width:290px;opacity:1;border-left-width:4px}
.scoreBug.goalExpand .sbGoalBurst:after{animation:sbGoalRail 3.8s linear both}
.sbGoalWord{display:flex;align-items:center;justify-content:center;gap:2px;font-size:36px;line-height:.9;font-style:italic;font-weight:1000;letter-spacing:-1px;color:#fff;text-shadow:0 4px 14px #000}
.sbGoalWord span{display:inline-block;opacity:0;transform:translateY(18px) scale(.65) rotate(8deg)}
.scoreBug.goalExpand .sbGoalWord span:nth-child(1){animation:sbGoalLetter .42s .10s cubic-bezier(.16,.84,.28,1) both}
.scoreBug.goalExpand .sbGoalWord span:nth-child(2){animation:sbGoalLetter .42s .22s cubic-bezier(.16,.84,.28,1) both}
.scoreBug.goalExpand .sbGoalWord span:nth-child(3){animation:sbGoalLetter .42s .34s cubic-bezier(.16,.84,.28,1) both}
.scoreBug.goalExpand .sbGoalWord span:nth-child(4){animation:sbGoalLetter .42s .46s cubic-bezier(.16,.84,.28,1) both}
.sbGoalScorer{margin-top:5px;max-width:250px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:9px;font-weight:1000;letter-spacing:1.6px;color:#c8d1db;opacity:0;transform:translateY(5px)}
.scoreBug.goalExpand .sbGoalScorer{animation:sbGoalScorerIn .35s .68s ease-out both}
@keyframes sbGoalLetter{0%{opacity:0;transform:translateY(18px) scale(.65) rotate(8deg)}68%{opacity:1;transform:translateY(-3px) scale(1.14) rotate(-2deg)}100%{opacity:1;transform:translateY(0) scale(1) rotate(0)}}
@keyframes sbGoalScorerIn{to{opacity:1;transform:translateY(0)}}
@keyframes sbGoalRail{0%{transform:scaleX(0)}18%{transform:scaleX(1)}84%{transform:scaleX(1)}100%{transform:scaleX(0)}}
@media (prefers-reduced-motion:reduce){.scoreBug,.sbGoalBurst{transition:none!important}.scoreBug.goalExpand .sbGoalWord span,.scoreBug.goalExpand .sbGoalScorer,.scoreBug.goalExpand .sbGoalBurst:after{animation:none!important;opacity:1!important;transform:none!important}}


/* ===== V4.30.8 GOAL PLAYER LOWER CARD ===== */
.eventCard.goal{left:70px;bottom:64px;width:690px;min-height:154px;padding:22px 28px;gap:22px;background:linear-gradient(115deg,#070b10f7,#111923f4);border-left-width:7px}
.eventCard.goal .eventPhotoWrap{width:132px;min-width:132px;height:132px;flex:0 0 132px;overflow:hidden;border-radius:8px;background:#0a1017}
.eventCard.goal .eventPhoto{width:100%;height:100%;object-fit:contain;object-position:center bottom}
.eventCard.goal .eventIcon{width:64px;height:64px;min-width:64px;font-size:32px;border-radius:10px;margin:0 4px 0 0;align-self:center}
.eventCard.goal .eventKicker{font-size:13px;letter-spacing:4px}
.eventCard.goal .eventName{font-size:36px;line-height:1.02;margin-top:5px}
.eventCard.goal .eventMeta{font-size:14px;margin-top:7px}


/* ===== V4.30.8 FINAL SCOREBUG LAYOUT ===== */
#scoreBug.scoreBug{
 left:42px!important;right:auto!important;top:34px!important;
 width:auto!important;min-width:0!important;max-width:none!important;
 height:58px!important;margin:0!important;overflow:hidden!important;
 transform:translateY(-12px) scale(.985)!important;transform-origin:left top!important
}
#scoreBug.scoreBug.on{transform:translateY(0) scale(1)!important}
#scoreBug.scoreBug .sbTeamBlock{
 min-width:118px!important;width:auto!important;max-width:none!important;
 padding:0 9px!important;gap:6px!important;flex:0 0 auto!important;
 overflow:visible!important
}
#scoreBug.scoreBug .sbTeamMeta{
 min-width:0!important;width:auto!important;max-width:none!important;
 flex:0 0 auto!important;overflow:visible!important
}
#scoreBug.scoreBug .sbTeam{
 width:auto!important;min-width:0!important;max-width:none!important;
 white-space:nowrap!important;overflow:visible!important;text-overflow:clip!important;
 letter-spacing:0!important;flex:0 0 auto!important
}
#scoreBug.scoreBug .sbCrest{width:27px!important;height:27px!important;flex:0 0 27px!important}
#scoreBug.scoreBug .sbScoreWrap{width:46px!important;min-width:46px!important;flex:0 0 46px!important}
#scoreBug.scoreBug .sbScore{font-size:26px!important}
#scoreBug.scoreBug .sbMid{width:92px!important;min-width:92px!important;flex:0 0 92px!important}
#scoreBug.scoreBug .sbClock{font-size:16px!important}
#scoreBug.scoreBug .sbCompetition{max-width:80px!important}
#scoreBug.scoreBug .sbGoalBurst{
 width:0!important;min-width:0!important;max-width:0!important;height:58px!important;
 padding:0!important;flex:0 0 0!important;opacity:0!important;border-left-width:0!important;
 transition:flex-basis .46s cubic-bezier(.16,.84,.28,1),width .46s cubic-bezier(.16,.84,.28,1),max-width .46s cubic-bezier(.16,.84,.28,1),opacity .18s ease!important
}
#scoreBug.scoreBug.goalExpand .sbGoalBurst{
 width:260px!important;min-width:260px!important;max-width:260px!important;
 flex:0 0 260px!important;opacity:1!important;border-left-width:4px!important
}
#scoreBug.scoreBug .sbGoalWord{
 width:100%!important;display:flex!important;justify-content:center!important;gap:3px!important;
 font-size:34px!important;letter-spacing:0!important;white-space:nowrap!important;overflow:visible!important
}
#scoreBug.scoreBug .sbGoalWord span{flex:0 0 auto!important}
#scoreBug.scoreBug .sbGoalScorer{max-width:230px!important;font-size:9px!important}

/* PK team names also stay complete: shrink font before ever clipping text. */
.spbIdentity{max-width:360px!important;overflow:visible!important}
.spbIdentity strong{
 max-width:none!important;overflow:visible!important;text-overflow:clip!important;white-space:nowrap!important
}


/* V4.30.8 LINEUP DISPLAY HOTFIX */
.stage.group-SUB .formation,
.stage.group-TEAM .formation,
.stage.group-STING .formation,
.stage.group-MATCH .formation,
.stage.group-COUNTDOWN .formation{display:none!important}


/* ===== V4.30.8 赛前转播包装 PRO ===== */
.matchOverlay{--homeAccent:#d8b55b;--awayAccent:#4c7dff;align-items:center;justify-content:center;background:radial-gradient(circle at 14% 50%,var(--homeAccent) 0,transparent 24%),radial-gradient(circle at 86% 50%,var(--awayAccent) 0,transparent 24%),linear-gradient(120deg,#05070a 0,#0a1017 48%,#05070a 100%);overflow:hidden}
.matchOverlay:before{content:"";position:absolute;inset:-20%;background:repeating-linear-gradient(118deg,#ffffff05 0 2px,transparent 2px 38px);transform:rotate(-4deg);opacity:.55}
.matchCardStage{width:1540px;height:770px;padding:0;border:0;background:#080d13f2;box-shadow:0 40px 120px #000c;position:relative;overflow:hidden}
.matchCardStage:before{content:"";position:absolute;left:0;right:0;top:0;height:8px;background:linear-gradient(90deg,var(--homeAccent) 0 48%,#fff 48% 52%,var(--awayAccent) 52% 100%)}
.matchCardStage:after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,var(--homeAccent) 0 15%,transparent 15% 85%,var(--awayAccent) 85% 100%);opacity:.09;pointer-events:none}
.matchTopLine{height:145px;display:flex;align-items:center;padding:25px 45px;border-bottom:1px solid #ffffff18;position:relative;z-index:2}
.matchEventLogoStage{width:86px;height:86px;object-fit:contain;margin-right:24px;filter:drop-shadow(0 12px 18px #0009)}
.matchCompetition{font-size:29px;letter-spacing:2px;color:#fff;font-weight:1000}.matchRound{margin-top:8px;font-size:14px;letter-spacing:3px;color:#9da8b5}
.matchBroadcastTag{margin-left:auto;padding:8px 13px;border-radius:999px;background:#ffffff0d;border:1px solid #ffffff20;color:#dce3ea;font-size:11px;font-weight:1000;letter-spacing:2px}
.matchTeams{height:510px;display:grid;grid-template-columns:1fr 250px 1fr;gap:20px;align-items:center;margin:0;padding:35px 60px;position:relative;z-index:2}
.matchTeamBlock{text-align:center;min-width:0}.matchCrestShell{width:175px;height:175px;margin:0 auto 24px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:#ffffff0b;border:1px solid #ffffff24;box-shadow:0 22px 55px #0008}
.matchHomeBlock .matchCrestShell{border-color:var(--homeAccent)}.matchAwayBlock .matchCrestShell{border-color:var(--awayAccent)}
.matchCrestStage{width:125px;height:125px;object-fit:contain;filter:drop-shadow(0 12px 20px #0008)}
.matchTeamRole{font-size:11px;letter-spacing:5px;color:#8793a0;font-weight:1000}.matchTeam{margin-top:10px;font-size:44px;line-height:1.05;font-weight:1000;color:#fff;letter-spacing:-1px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.matchCenterStage{text-align:center}.matchVs{font-size:38px;color:#fff;font-weight:1000;letter-spacing:6px}.matchKickoffStage{margin-top:32px;font-size:66px;font-weight:1000;letter-spacing:-3px;color:#fff;font-variant-numeric:tabular-nums}.matchKickoffLabel{margin-top:7px;font-size:10px;color:#7e8a97;letter-spacing:4px}
.matchMetaStage{height:115px;margin:0;display:flex;justify-content:center;align-items:center;gap:16px;border-top:1px solid #ffffff14;background:#05090d;color:#7e8995;font-size:11px;letter-spacing:4px;position:relative;z-index:2}.matchMetaStage b{font-size:18px;color:#fff;letter-spacing:2px}
.stage.group-GK:before,.stage.group-DF:before,.stage.group-MF:before,.stage.group-FW:before{content:"";position:absolute;inset:0;z-index:0;background:linear-gradient(118deg,var(--teamAccent) 0 20%,transparent 20% 72%,#ffffff08 72% 74%,transparent 74% 100%);opacity:.18}
.stage.group-GK:after,.stage.group-DF:after,.stage.group-MF:after,.stage.group-FW:after{content:"";position:absolute;left:65px;right:65px;bottom:54px;height:1px;background:linear-gradient(90deg,transparent,var(--teamAccent),#fff,var(--teamAccent),transparent);opacity:.45}
.stage.group-GK .tunnelScene,.stage.group-DF .tunnelScene,.stage.group-MF .tunnelScene,.stage.group-FW .tunnelScene{opacity:.22;filter:saturate(.5) brightness(.65)}
.stage.group-GK .header,.stage.group-DF .header,.stage.group-MF .header,.stage.group-FW .header{top:54px}
.stage.group-GK .groupTitle,.stage.group-DF .groupTitle,.stage.group-MF .groupTitle,.stage.group-FW .groupTitle{top:187px;font-size:16px;letter-spacing:6px}
.stage.group-GK .groupName,.stage.group-DF .groupName,.stage.group-MF .groupName,.stage.group-FW .groupName{top:221px;font-size:58px;letter-spacing:-1px}
.stage.group-GK .line,.stage.group-DF .line,.stage.group-MF .line,.stage.group-FW .line{top:292px;height:4px;width:290px;background:var(--teamAccent)}
.stage.group-GK .players,.stage.group-DF .players,.stage.group-MF .players,.stage.group-FW .players{top:315px;height:720px;left:320px;width:1280px;gap:12px}
.card{isolation:isolate}.playerBigNo{position:absolute;left:50%;top:5px;transform:translateX(-50%);z-index:-1;font-size:210px;line-height:.8;font-weight:1000;letter-spacing:-16px;color:var(--teamAccent);opacity:.12;pointer-events:none}
.cut{bottom:106px;height:525px}.cut img,.mediaVideo{filter:drop-shadow(0 24px 28px #000c)}
.label{left:7%;right:7%;bottom:10px;min-height:112px;padding:15px 18px 13px;text-align:left;background:#f4f6f8;color:#071019;box-shadow:0 15px 35px #0008;overflow:hidden}
.label:before{content:"";position:absolute;left:0;top:0;bottom:0;width:7px;background:var(--teamAccent)}
.no{font-size:15px;color:#071019;font-weight:1000;letter-spacing:1px}.name{font-size:27px;line-height:1;margin-top:5px;color:#071019;font-weight:1000;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.role{font-size:10px;color:#54606c;letter-spacing:2px;margin-top:6px;font-weight:900}
.label .statPill,.label .mediaTag,.label .directorBadge{display:none}.stage.group-GK .card.one{width:610px}.stage.group-GK .card.one .playerBigNo{font-size:250px}
.stage.group-DF .card,.stage.group-MF .card,.stage.group-FW .card{max-width:285px}


/* V4.30.8 开场标识 + 倒计时统一包装 */
.stingOverlay{background:radial-gradient(circle at 50% 45%,#182633 0,#081018 42%,#020405 100%);overflow:hidden}
.stingOverlay:before{content:"";position:absolute;inset:-20%;background:repeating-linear-gradient(112deg,#ffffff06 0 2px,transparent 2px 44px);opacity:.5}
.stingCore{position:relative;z-index:2;min-width:720px;padding:70px 95px;border-top:1px solid #ffffff1f;border-bottom:1px solid #ffffff14;background:linear-gradient(90deg,transparent,#071019d9 15% 85%,transparent)}
.stingLogo{width:230px;height:230px}.stingComp{font-size:30px;letter-spacing:4px;color:#fff}.stingLine{width:520px;height:5px;background:linear-gradient(90deg,transparent,var(--teamAccent),#fff,var(--teamAccent),transparent)}
.countdownOverlay{background:radial-gradient(circle at center,#121d28 0,#070c12 46%,#020405 100%);overflow:hidden}
.countdownOverlay:before{content:"";position:absolute;left:-8%;right:-8%;top:48%;height:3px;background:linear-gradient(90deg,transparent,var(--teamAccent),#fff,var(--teamAccent),transparent);opacity:.55}
.countdownCore{position:relative;z-index:2;min-width:760px;padding:50px 70px;text-align:center;background:#071019d4;border:1px solid #ffffff18;box-shadow:0 32px 90px #000b}
.countdownLabel{font-size:15px;letter-spacing:7px;color:#aab5c0}.countdownNumber{font-size:260px;letter-spacing:-13px;line-height:.9;text-shadow:none}.countdownSub{font-size:20px;color:#fff;letter-spacing:3px;margin-top:24px}


/* ===== V4.30.8 点球大战专用比分牌 ===== */
.scoreBug.penaltyMode{overflow:visible}
.scoreBug.penaltyMode .sbClock{font-size:15px;letter-spacing:1px}.scoreBug.penaltyMode .sbPeriod{font-size:7px;max-width:112px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.scoreBug.penaltyMode .sbPenalty{display:block;font-size:8px;font-weight:1000;color:#303842;letter-spacing:.5px}
.penaltyShootoutBar{position:absolute;left:0;right:0;top:100%;height:54px;display:none;grid-template-columns:1fr 190px 1fr;gap:12px;align-items:center;padding:0 16px;background:#071019;border:1px solid #ffffff1f;border-top:0;border-radius:0 0 9px 9px;box-shadow:0 16px 32px #0008;color:#fff}
.scoreBug.penaltyMode .penaltyShootoutBar{display:grid}
.sbPenDots{display:flex;gap:5px;align-items:center}.penSide.away .sbPenDots{justify-content:flex-end}.sbPenDot{width:16px;height:16px;border-radius:50%;border:2px solid #54616d;background:#17202a;box-sizing:border-box;position:relative}
.sbPenDot.goal{background:#62d48e;border-color:#62d48e;box-shadow:0 0 9px #62d48e55}.sbPenDot.miss{background:#e9515b;border-color:#e9515b}.sbPenDot.miss:after{content:"×";position:absolute;left:50%;top:50%;transform:translate(-50%,-56%);font-size:12px;color:#fff;font-weight:1000}.sbPenDot.pending.current{border-color:var(--accent);box-shadow:0 0 0 3px #ffffff13,0 0 10px var(--accent)}
.penCenter{text-align:center;min-width:0}.penCenter b{display:block;font-size:11px;letter-spacing:1.5px;color:var(--accent);white-space:nowrap}.penCenter span{display:block;margin-top:4px;font-size:9px;color:#94a1ad;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.scoreBug.theme-premier.penaltyMode .penaltyShootoutBar{background:#2b0b3f;border-color:#fff}.scoreBug.theme-premier .sbPenDot.pending.current{border-color:#21e89b}.scoreBug.theme-premier .penCenter b{color:#21e89b}
.scoreBug.theme-uefa.penaltyMode .penaltyShootoutBar{background:#06172c;border-color:#31527b}.scoreBug.theme-uefa .penCenter b{color:#73b8ff}


/* ===== V4.30.8 世界杯级独立点球记分牌 ===== */
.simplePenaltyBoard{--home:#d8b55b;--away:#4c7dff;position:absolute;left:50%;bottom:54px;transform:translateX(-50%) translateY(34px) scale(.97);width:1240px;height:190px;color:#fff;opacity:0;pointer-events:none;transition:opacity .22s ease,transform .42s cubic-bezier(.16,.84,.28,1);filter:drop-shadow(0 24px 36px #000b);z-index:30}
.simplePenaltyBoard.on{opacity:1;transform:translateX(-50%) translateY(0) scale(1)}
.simplePenaltyBoard:before{content:"";position:absolute;left:50%;top:23px;width:520px;height:150px;transform:translateX(-50%);background:radial-gradient(ellipse at center,#ffffff12 0,#ffffff05 34%,transparent 70%);filter:blur(8px);pointer-events:none}
.spbHalo{position:absolute;left:50%;top:70px;width:340px;height:110px;transform:translateX(-50%);background:radial-gradient(ellipse at center,#ffffff14,transparent 67%);filter:blur(18px);opacity:.75}
.spbHeader{position:absolute;left:50%;top:0;transform:translateX(-50%);width:540px;height:46px;display:grid;grid-template-columns:1fr auto 1fr;align-items:center;padding:0 22px;box-sizing:border-box;background:linear-gradient(180deg,#18212beb,#080d13f5);border:1px solid #ffffff28;clip-path:polygon(6% 0,94% 0,100% 50%,94% 100%,6% 100%,0 50%);box-shadow:0 10px 28px #0009,0 0 28px #ffffff0b inset;z-index:4}
.spbHeader:before,.spbHeader:after{content:"";position:absolute;top:0;bottom:0;width:74px;opacity:.9}.spbHeader:before{left:0;background:linear-gradient(90deg,var(--home),transparent)}.spbHeader:after{right:0;background:linear-gradient(270deg,var(--away),transparent)}
.spbCompetition{font-size:9px;font-weight:900;letter-spacing:2px;color:#9ca8b4;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;z-index:2}
.spbTitle{grid-column:2;display:flex;align-items:center;gap:9px;font-size:14px;font-weight:1000;letter-spacing:5px;color:#fff;z-index:2;text-shadow:0 3px 8px #000}.spbTitle i{width:25px;height:1px;background:linear-gradient(90deg,transparent,#fff)}.spbTitle i:last-child{background:linear-gradient(90deg,#fff,transparent)}.spbTitle em{display:none}.spbPhaseFloat{justify-self:end;font-size:9px;font-style:normal;font-weight:1000;letter-spacing:1px;color:#f4d77b;border:1px solid #f4d77b55;border-radius:999px;padding:5px 8px;z-index:2;white-space:nowrap}
.spbArena{position:absolute;left:0;right:0;top:36px;height:142px;display:grid;grid-template-columns:1fr 310px 1fr;align-items:center;gap:0}
.spbWing{height:112px;display:flex;align-items:center;gap:18px;position:relative;overflow:hidden;background:linear-gradient(180deg,#121a23f5,#070b11f8);border:1px solid #ffffff20;box-shadow:0 18px 38px #000a,0 0 0 1px #ffffff08 inset;transition:filter .25s ease,transform .25s ease}
.spbWing:before{content:"";position:absolute;inset:0;opacity:.22;pointer-events:none}.spbWing:after{content:"";position:absolute;bottom:0;height:5px;width:70%;background:var(--wing);box-shadow:0 0 22px var(--wing)}
.spbWing.home{--wing:var(--home);justify-content:flex-end;text-align:right;padding:0 56px 0 34px;clip-path:polygon(0 0,91% 0,100% 50%,91% 100%,0 100%);border-left:5px solid var(--home)}.spbWing.home:before{background:linear-gradient(110deg,var(--home),transparent 38%)}.spbWing.home:after{right:9%}
.spbWing.away{--wing:var(--away);justify-content:flex-start;text-align:left;padding:0 34px 0 56px;clip-path:polygon(9% 0,100% 0,100% 100%,9% 100%,0 50%);border-right:5px solid var(--away)}.spbWing.away:before{background:linear-gradient(250deg,var(--away),transparent 38%)}.spbWing.away:after{left:9%}
.spbWing.current{transform:translateY(-3px);filter:brightness(1.16)}.spbWing.current .spbRole:after{content:" · 主罚中";color:#fff}.spbWing.current:after{height:7px;box-shadow:0 0 32px var(--wing)}
.spbCrestShell{width:64px;height:64px;display:flex;align-items:center;justify-content:center;border-radius:50%;background:radial-gradient(circle,#ffffff16,#ffffff05 64%,transparent 66%);border:2px solid var(--wing);box-shadow:0 0 0 5px #ffffff08,0 0 24px var(--wing);flex:0 0 auto;position:relative;z-index:2}.spbCrestShell:after{content:"";position:absolute;inset:-8px;border:1px solid #ffffff18;border-radius:50%}
.spbCrest{width:44px;height:44px;object-fit:contain;filter:drop-shadow(0 7px 12px #000a);display:none}.spbCrest.on{display:block}
.spbIdentity{min-width:0;max-width:320px;position:relative;z-index:2}.spbRole{display:block;font-size:9px;letter-spacing:2px;color:#9aa6b1;font-weight:1000;margin-bottom:5px}.spbIdentity strong{display:block;font-size:30px;line-height:1.02;font-weight:1000;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;letter-spacing:.25px;text-shadow:0 3px 10px #000}
.spbDots{display:flex;gap:8px;margin-top:11px;min-height:20px}.spbWing.home .spbDots{justify-content:flex-end}.spbWing.away .spbDots{justify-content:flex-start}
.spbDot{width:20px;height:20px;border-radius:50%;border:2px solid #73808d;background:#0b1118;box-sizing:border-box;position:relative;transition:transform .22s ease,background .22s ease,border-color .22s ease;box-shadow:0 0 0 2px #0006 inset}.spbDot.on{background:#42da79;border-color:#b8ffd0;box-shadow:0 0 0 4px #42da7920,0 0 18px #42da7990}.spbDot.on:after{content:"✓";position:absolute;left:50%;top:50%;transform:translate(-50%,-56%);font-size:13px;line-height:1;color:#fff;font-weight:1000}.spbDot.new{animation:spDotWorld .46s cubic-bezier(.16,.84,.28,1)}
.spbCore{height:142px;position:relative;display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:5}
.spbCore:before{content:"";position:absolute;inset:9px 3px 8px;background:linear-gradient(180deg,#111821fa,#060a0ffd);clip-path:polygon(13% 0,87% 0,100% 50%,87% 100%,13% 100%,0 50%);border:1px solid #ffffff24;box-shadow:0 18px 40px #000b}
.spbCore:after{content:"";position:absolute;left:50%;top:22px;width:90px;height:90px;transform:translateX(-50%);border-radius:50%;background:conic-gradient(from 0deg,var(--home),#fff,var(--away),#fff,var(--home));opacity:.35;filter:blur(1px);animation:spOrbSpin 7s linear infinite}
.spbScoreLine{width:270px;height:82px;display:grid;grid-template-columns:82px 86px 82px;align-items:center;justify-content:center;position:relative;z-index:3}
.spbScore{font-size:70px;line-height:1;font-weight:1000;font-variant-numeric:tabular-nums;letter-spacing:-4px;text-align:center;color:#fff;text-shadow:0 6px 18px #000}.spbScore.home{color:var(--home);text-shadow:0 0 22px var(--home),0 6px 18px #000}.spbScore.away{color:var(--away);text-shadow:0 0 22px var(--away),0 6px 18px #000}.spbScore.pulse{animation:spScorePulse .34s cubic-bezier(.2,.8,.2,1)}
.spbPkOrb{width:64px;height:64px;margin:auto;border-radius:50%;display:flex;align-items:center;justify-content:center;position:relative;background:radial-gradient(circle at 38% 30%,#263646,#0a1118 55%,#020407 100%);border:1px solid #ffffff46;box-shadow:0 0 0 6px #ffffff08,0 0 26px #ffffff24 inset,0 10px 24px #000a}.spbPkOrb:before{content:"";position:absolute;inset:8px;border-radius:50%;border:1px dashed #ffffff4b;animation:spRingSpin 5s linear infinite}.spbPkOrb b{font-size:16px;letter-spacing:2px;color:#fff;z-index:2}.spbDivider{display:none}
.spbCoreMeta{position:relative;z-index:3;display:flex;align-items:center;gap:9px;margin-top:-2px}.spbCoreMeta b{font-size:9px;letter-spacing:2px;color:#0b1117;background:#f3d474;padding:4px 8px;border-radius:999px}.spbCoreMeta span{font-size:9px;letter-spacing:.5px;color:#aab5bf;max-width:155px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.spbScoreCenter small{display:none}
.spbRail{position:absolute;left:96px;right:96px;bottom:0;height:7px;display:grid;grid-template-columns:1fr 110px 1fr;gap:5px;z-index:5}.spbRail .home{background:linear-gradient(90deg,transparent,var(--home));box-shadow:0 0 16px var(--home)}.spbRail .center{background:#fff;box-shadow:0 0 18px #fff8}.spbRail .away{background:linear-gradient(90deg,var(--away),transparent);box-shadow:0 0 16px var(--away)}
.simplePenaltyBoard.sudden .spbHeader{box-shadow:0 10px 34px #000a,0 0 35px #f2c14f25 inset}.simplePenaltyBoard.sudden .spbCoreMeta b{background:#e4565f;color:#fff}
@keyframes spOrbSpin{to{transform:translateX(-50%) rotate(360deg)}}@keyframes spRingSpin{to{transform:rotate(360deg)}}@keyframes spDotWorld{0%{transform:scale(.3);opacity:.1}55%{transform:scale(1.32);opacity:1}100%{transform:scale(1)}}@keyframes spScorePulse{0%{transform:scale(.72);opacity:.35}62%{transform:scale(1.15);opacity:1}100%{transform:scale(1)}}

/* V4.30.8 世界杯级罚失红点 */
.spbDot.miss{background:#e94f59;border-color:#ff9aa1;box-shadow:0 0 0 3px #e94f591c,0 0 15px #e94f5966}
.spbDot.miss:after{content:"×";position:absolute;left:50%;top:50%;transform:translate(-50%,-56%);font-size:12px;line-height:1;color:#fff;font-weight:1000}


/* SAGI V4.27 TORANHE broadcast scorebug — event identity + team goal reveal */
#scoreBug.scoreBug.sagiToranhe{
 --toranheDeep:#073c2c;--toranheLime:#65ed38;
 background:#fff!important;border:0!important;border-radius:0 9px 9px 0!important;
 box-shadow:0 7px 24px #0008!important;overflow:visible!important;
 height:62px!important;padding-left:60px!important;align-items:center!important;
}
#scoreBug.sagiToranhe .sbEventBrand{
 position:absolute;left:-10px;top:-8px;width:76px;height:76px;z-index:12;
 display:flex;align-items:center;justify-content:center;
 background:linear-gradient(135deg,#08714d,#042f25);clip-path:polygon(50% 0,96% 20%,96% 76%,50% 100%,4% 76%,4% 20%);
}
#scoreBug.sagiToranhe .sbEventBrand img{width:66px;height:66px;object-fit:contain}
#scoreBug.sagiToranhe .sbEventFallback{font-size:25px;color:#74ff50;font-weight:1000;letter-spacing:-2px}
#scoreBug.sagiToranhe .sbTeamBlock{background:#fff!important;color:#092e25!important;height:62px!important}
#scoreBug.sagiToranhe .sbTeam{color:#093d30!important}
#scoreBug.sagiToranhe .sbScoreWrap{background:#fff!important;color:#182b25!important;height:62px!important}
#scoreBug.sagiToranhe .sbScore{color:#182b25!important}
#scoreBug.sagiToranhe .sbMid{
 position:relative;background:var(--toranheDeep)!important;color:#fff!important;
 height:62px!important;min-width:105px!important;width:105px!important;flex:0 0 105px!important;
}
#scoreBug.sagiToranhe .sbClock{color:#fff!important;font-size:18px!important}
#scoreBug.sagiToranhe .sbStoppage.on{background:var(--toranheLime)!important;color:#082b21!important}
#scoreBug.sagiToranhe .sbCompetition{color:#b4efcf!important}
#scoreBug.sagiToranhe .sbPeriod{color:#fff!important}
#scoreBug.sagiToranhe .sbGoalBurst{
 height:62px!important;background:linear-gradient(115deg,var(--toranheDeep),#008b51)!important;
 color:#fff!important;border:0!important;align-items:stretch!important;justify-content:center!important;
}
#scoreBug.sagiToranhe.goalExpand .sbGoalBurst{
 width:330px!important;min-width:330px!important;max-width:330px!important;flex:0 0 330px!important;
}
#scoreBug.sagiToranhe .sbGoalCrest{
 position:absolute;left:10px;top:3px;width:58px;height:56px;object-fit:contain;
 opacity:0;transform:scale(.4);z-index:3;filter:drop-shadow(0 2px 5px #0007)
}
#scoreBug.sagiToranhe.goalExpand .sbGoalCrest.on{animation:toranheCrest .5s cubic-bezier(.15,1.4,.4,1) both}
#scoreBug.sagiToranhe .sbGoalWord{margin-left:76px!important;width:calc(100% - 82px)!important;font-size:38px!important}
#scoreBug.sagiToranhe .sbGoalScorer{margin-left:76px!important;text-align:center!important;max-width:235px!important;color:#fff!important}
@keyframes toranheCrest{to{opacity:1;transform:scale(1)}}
#scoreBug.sagiToranhe.goalExpand{max-width:calc(1920px - 60px)!important}


/* ===== V4.30.8 FINAL · TORANHE SCOREBUG ===== */
#scoreBug.scoreBug.sagiToranhe{
 --toranheDeep:#26052f;--toranheGreen:#0d6b45;--toranheLime:#20ed82;--toranhePaper:#f6f4f2;--toranheInk:#25052e;
 left:42px!important;right:auto!important;top:34px!important;
 width:auto!important;min-width:0!important;max-width:none!important;height:58px!important;
 margin:0!important;padding:0!important;display:flex!important;align-items:flex-start!important;
 background:transparent!important;border:0!important;border-radius:0!important;box-shadow:none!important;
 overflow:visible!important;transform:translateY(-12px) scale(.985)!important;transform-origin:left top!important;
 isolation:isolate
}
#scoreBug.scoreBug.sagiToranhe.on{transform:translateY(0) scale(1)!important}
.graphicsStage.eventActive #scoreBug.scoreBug.sagiToranhe.on{transform:translateY(0) scale(1)!important;filter:none!important}

/* Event logo: permanent left identity block. */
#scoreBug.sagiToranhe .sbEventBrand{
 position:relative!important;left:auto!important;top:auto!important;
 width:64px!important;height:58px!important;flex:0 0 64px!important;z-index:12!important;
 display:flex!important;align-items:center!important;justify-content:center!important;
 background:linear-gradient(135deg,#031e16 0,#08472f 62%,#0b7046 100%)!important;
 clip-path:polygon(0 0,84% 0,100% 50%,84% 100%,0 100%)!important;
 box-shadow:0 10px 28px #0006!important
}
#scoreBug.sagiToranhe .sbEventBrand:after{content:"";position:absolute;left:0;right:10px;bottom:0;height:4px;background:#3ce35e;box-shadow:0 0 12px #44ef6680}
#scoreBug.sagiToranhe .sbEventBrand img{width:49px!important;height:49px!important;object-fit:contain!important;filter:drop-shadow(0 4px 7px #0007)!important}
#scoreBug.sagiToranhe .sbEventFallback{display:none!important}

/* Main score ribbon: white, clean and television-readable. */
#scoreBug.sagiToranhe .sbTeamBlock{
 height:58px!important;min-width:118px!important;width:auto!important;max-width:none!important;
 padding:0 10px!important;gap:7px!important;flex:0 0 auto!important;overflow:visible!important;
 background:var(--toranhePaper)!important;color:var(--toranheInk)!important;border:0!important;
 box-shadow:inset 0 -4px 0 var(--home)!important
}
#scoreBug.sagiToranhe .sbTeamBlock.away{box-shadow:inset 0 -4px 0 var(--away)!important}
#scoreBug.sagiToranhe .sbTeamMeta{min-width:0!important;width:auto!important;max-width:none!important;flex:0 0 auto!important;overflow:visible!important}
#scoreBug.sagiToranhe .sbTeam{
 width:auto!important;min-width:0!important;max-width:none!important;white-space:nowrap!important;
 overflow:visible!important;text-overflow:clip!important;color:var(--toranheInk)!important;text-shadow:none!important;
 font-weight:1000!important;letter-spacing:0!important
}
#scoreBug.sagiToranhe .sbCrest{width:28px!important;height:28px!important;flex:0 0 28px!important;filter:drop-shadow(0 3px 5px #0004)!important}
#scoreBug.sagiToranhe .sbScoreWrap{
 width:48px!important;min-width:48px!important;height:58px!important;flex:0 0 48px!important;
 background:var(--toranhePaper)!important;color:var(--toranheInk)!important;box-shadow:none!important;z-index:4
}
#scoreBug.sagiToranhe .sbScore{font-size:27px!important;color:var(--toranheInk)!important}
#scoreBug.sagiToranhe #sbHomeScoreWrap:after{
 content:"–";position:absolute;right:-12px;top:50%;transform:translateY(-53%);z-index:12;
 width:24px;text-align:center;color:var(--toranheInk);font-size:25px;font-weight:1000;pointer-events:none
}
#scoreBug.sagiToranhe #sbAwayScoreWrap{margin-left:14px!important}
#scoreBug.sagiToranhe .sbPenalty{font-size:7px!important}

/* Time ribbon moves below the main score line, like the first reference. */
#scoreBug.sagiToranhe .sbMid{
 position:absolute!important;left:50%!important;top:58px!important;transform:translateX(-50%)!important;
 width:164px!important;min-width:164px!important;height:32px!important;z-index:3!important;flex:none!important;
 display:flex!important;align-items:center!important;justify-content:center!important;
 background:var(--toranheDeep)!important;border:0!important;
 clip-path:polygon(6% 0,94% 0,100% 100%,0 100%)!important;
 box-shadow:0 8px 18px #0006!important
}
#scoreBug.sagiToranhe .sbCompetition,#scoreBug.sagiToranhe .sbPeriod{display:none!important}
#scoreBug.sagiToranhe .sbClockRow{height:100%!important;width:100%!important;margin:0!important;display:flex!important;align-items:center!important;justify-content:center!important;gap:0!important}
#scoreBug.sagiToranhe .sbClock{
 height:32px!important;min-width:106px!important;padding:0 10px!important;display:flex!important;
 align-items:center!important;justify-content:center!important;font-size:18px!important;letter-spacing:.4px!important;color:#fff!important
}
#scoreBug.sagiToranhe .sbStoppage{
 height:32px!important;min-width:56px!important;margin:0!important;padding:0 11px!important;border-radius:0!important;
 align-items:center!important;justify-content:center!important;background:var(--toranheLime)!important;color:var(--toranheInk)!important;
 font-size:15px!important;clip-path:polygon(14% 0,100% 0,86% 100%,0 100%)!important
}
#scoreBug.sagiToranhe .sbStoppage.on{display:flex!important}

/* GOAL reveal: panel expands only to the right; normal scorebar never moves. */
#scoreBug.sagiToranhe .sbGoalBurst{
 position:absolute!important;left:100%!important;top:0!important;
 width:0!important;min-width:0!important;max-width:0!important;height:58px!important;
 margin:0!important;padding:0!important;display:block!important;flex:none!important;
 opacity:0!important;overflow:hidden!important;border:0!important;
 background:linear-gradient(105deg,color-mix(in srgb,var(--goalAccent) 82%,#072417),#075235 62%,#031b13)!important;
 clip-path:polygon(0 0,94% 0,100% 50%,94% 100%,0 100%)!important;
 box-shadow:0 12px 30px #0007!important;
 transition:width .46s cubic-bezier(.16,.84,.28,1),max-width .46s cubic-bezier(.16,.84,.28,1),opacity .18s ease!important;
 isolation:isolate
}
#scoreBug.sagiToranhe .sbGoalBurst:before{content:"";position:absolute;inset:0;background:linear-gradient(115deg,#ffffff25,transparent 30%,#ffffff0d 55%,transparent 78%);opacity:.7;z-index:-1}
#scoreBug.sagiToranhe .sbGoalBurst:after{content:"";position:absolute;left:0;right:20px;bottom:0;height:4px;background:#fff;opacity:.9;transform:scaleX(0);transform-origin:left}
#scoreBug.sagiToranhe.goalExpand .sbGoalBurst{
 width:330px!important;min-width:330px!important;max-width:330px!important;opacity:1!important;overflow:visible!important
}
#scoreBug.sagiToranhe.goalExpand .sbGoalBurst:after{animation:sbGoalRail 3.8s linear both}
#scoreBug.sagiToranhe .sbGoalCrest{
 position:absolute!important;left:10px!important;top:-10px!important;width:78px!important;height:78px!important;
 object-fit:contain!important;opacity:0!important;transform:scale(.42) rotate(-8deg)!important;z-index:4!important;
 filter:drop-shadow(0 8px 13px #0008)!important
}
#scoreBug.sagiToranhe.goalExpand .sbGoalCrest.on{animation:toranheCrestV427 .58s .06s cubic-bezier(.16,.84,.28,1) both!important}
#scoreBug.sagiToranhe .sbGoalWord{
 position:absolute!important;left:96px!important;right:24px!important;top:5px!important;height:38px!important;
 margin:0!important;width:auto!important;display:flex!important;align-items:center!important;justify-content:flex-start!important;
 gap:2px!important;font-size:39px!important;line-height:.9!important;letter-spacing:-1px!important;
 white-space:nowrap!important;overflow:visible!important;color:#fff!important;text-shadow:0 4px 13px #0008!important
}
#scoreBug.sagiToranhe .sbGoalWord span{flex:0 0 auto!important}
#scoreBug.sagiToranhe .sbGoalScorer{display:none!important}
@keyframes toranheCrestV427{
 0%{opacity:0;transform:scale(.42) rotate(-8deg)}
 68%{opacity:1;transform:scale(1.14) rotate(2deg)}
 100%{opacity:1;transform:scale(1) rotate(0)}
}

/* Keep the detailed goal-player photo/information card below exactly as before. */


/* ===== V4.30.8 CERTIFICATION FIX · LOGO SCALE + GOAL CREST POP ===== */
#scoreBug.sagiToranhe .sbEventBrand{
 background:transparent!important;clip-path:none!important;box-shadow:none!important;overflow:visible!important
}
#scoreBug.sagiToranhe .sbEventBrand:before{
 content:"";position:absolute;inset:0 2px 0 0;z-index:0;
 background:linear-gradient(135deg,#031e16 0,#08472f 62%,#0b7046 100%);
 clip-path:polygon(0 0,84% 0,100% 50%,84% 100%,0 100%);
 box-shadow:0 10px 28px #0006
}
#scoreBug.sagiToranhe .sbEventBrand:after{z-index:1}
#scoreBug.sagiToranhe .sbEventBrand img{
 position:absolute!important;left:-4px!important;top:-6px!important;width:70px!important;height:70px!important;
 z-index:3!important;object-fit:contain!important;filter:drop-shadow(0 5px 8px #0008)!important
}
#scoreBug.sagiToranhe .sbGoalCrest{
 width:86px!important;height:86px!important;left:8px!important;top:-14px!important;
 opacity:0;transform:scale(.42) rotate(-8deg)
}
#scoreBug.sagiToranhe.goalExpand .sbGoalCrest.on{
 opacity:1!important;transform:scale(1) rotate(0)!important;
 animation:toranheCrestV427b .58s .06s cubic-bezier(.16,.84,.28,1) both!important
}
@keyframes toranheCrestV427b{
 0%{opacity:0;transform:scale(.42) rotate(-8deg)}
 68%{opacity:1;transform:scale(1.14) rotate(2deg)}
 100%{opacity:1;transform:scale(1) rotate(0)}
}
#scoreBug.sagiToranhe .sbGoalWord{left:106px!important}


/* ===== V4.30.8 EVENT LOGO REPLAY STINGER ===== */
.replayStinger{position:absolute;inset:0;display:none;z-index:20000;overflow:hidden;pointer-events:none}
.replayStinger.on{display:block}
.rsPanel{position:absolute;top:-12%;height:124%;width:62%;background:linear-gradient(135deg,#032b20 0%,#076b45 48%,#65ed38 100%);will-change:transform;box-shadow:0 0 70px #001c16aa inset}
.rsLeft{left:-10%;clip-path:polygon(0 0,100% 0,82% 100%,0 100%)}
.rsRight{right:-10%;clip-path:polygon(18% 0,100% 0,100% 100%,0 100%);background:linear-gradient(225deg,#032b20 0%,#08764c 48%,#65ed38 100%)}
.replayStinger.on .rsLeft{animation:rsLeftSweep 1.45s cubic-bezier(.2,.78,.2,1) both}
.replayStinger.on .rsRight{animation:rsRightSweep 1.45s cubic-bezier(.2,.78,.2,1) both}
.rsCenter{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;opacity:0;transform:scale(.7);text-align:center}
.replayStinger.on .rsCenter{animation:rsCenterPulse 1.45s cubic-bezier(.16,.84,.28,1) both}
.rsLogoWrap{width:270px;height:270px;display:flex;align-items:center;justify-content:center;filter:drop-shadow(0 20px 38px #001b1488)}
.rsLogo{max-width:250px;max-height:250px;object-fit:contain}
.rsLogoFallback{display:none;width:190px;height:190px;border:8px solid #a5ff6e;border-radius:50%;align-items:center;justify-content:center;color:#fff;font-size:44px;font-weight:1000;letter-spacing:5px}
.rsKicker{margin-top:8px;color:#caffb5;font-size:24px;font-weight:1000;letter-spacing:10px}
.rsTitle{margin-top:12px;color:#fff;font-size:62px;line-height:1;font-weight:1000;font-style:italic;letter-spacing:3px;text-shadow:0 8px 28px #00150f99}
.rsRule{width:390px;height:5px;margin-top:18px;background:#72ff49;box-shadow:0 0 22px #72ff49}
.replayStinger.out .rsKicker{color:#d7ffe9}
.replayStinger.out .rsRule{background:#fff;box-shadow:0 0 20px #fff8}
@keyframes rsLeftSweep{0%{transform:translateX(-110%)}18%{transform:translateX(0)}72%{transform:translateX(0)}100%{transform:translateX(-110%)}}
@keyframes rsRightSweep{0%{transform:translateX(110%)}18%{transform:translateX(0)}72%{transform:translateX(0)}100%{transform:translateX(110%)}}
@keyframes rsCenterPulse{0%,16%{opacity:0;transform:scale(.7)}28%{opacity:1;transform:scale(1.08)}38%,66%{opacity:1;transform:scale(1)}78%,100%{opacity:0;transform:scale(.86)}}
@media (prefers-reduced-motion:reduce){.replayStinger.on .rsLeft,.replayStinger.on .rsRight,.replayStinger.on .rsCenter{animation-duration:1.45s!important}}


/* ===== V4.30.8 · SAGI STAGE BROADCAST SYSTEM =====
   Inspired by modern 2025 sports-broadcast system principles:
   modular stage surfaces, strict grid, type hierarchy and unified motion.
   SAGI/TORANHE identity remains original. */
:root{
 --sagiStageBlue:#071d57;--sagiStageBlue2:#0a43c9;--sagiStageBlue3:#19a7ff;
 --sagiStageRed:#f33b4b;--sagiStagePaper:#f7f8fc;--sagiStageInk:#071638;
 --sagiStageLine:#ffffff24;--sagiStageRadius:16px
}
#graphicsStage:before{content:"";position:absolute;inset:0;pointer-events:none;opacity:.11;background:
 linear-gradient(115deg,transparent 0 58%,#ffffff10 58% 58.15%,transparent 58.15%),
 repeating-linear-gradient(90deg,transparent 0 119px,#ffffff08 119px 120px)}
#scoreBug.sagiToranhe .sbEventBrand{border-radius:14px 0 0 14px!important}
#scoreBug.sagiToranhe .sbEventBrand:before{
 background:linear-gradient(145deg,#04163d 0,var(--sagiStageBlue) 54%,var(--sagiStageBlue2) 100%)!important;
 clip-path:none!important;border-radius:14px 0 0 14px!important;box-shadow:0 12px 30px #020b24a8!important
}
#scoreBug.sagiToranhe .sbEventBrand:after{left:8px!important;right:8px!important;bottom:5px!important;height:3px!important;border-radius:3px!important;background:var(--sagiStageRed)!important;box-shadow:0 0 13px #f33b4b75!important}
#scoreBug.sagiToranhe .sbTeamBlock{background:var(--sagiStagePaper)!important;color:var(--sagiStageInk)!important}
#scoreBug.sagiToranhe .sbTeamBlock.home{border-top:1px solid #fff!important;border-bottom:4px solid var(--home)!important;box-shadow:none!important}
#scoreBug.sagiToranhe .sbTeamBlock.away{border-top:1px solid #fff!important;border-bottom:4px solid var(--away)!important;box-shadow:none!important;border-radius:0 12px 12px 0!important}
#scoreBug.sagiToranhe .sbTeam,#scoreBug.sagiToranhe .sbScore{color:var(--sagiStageInk)!important}
#scoreBug.sagiToranhe .sbScoreWrap{background:var(--sagiStagePaper)!important;color:var(--sagiStageInk)!important}
#scoreBug.sagiToranhe .sbMid{
 background:linear-gradient(105deg,var(--sagiStageBlue),#0a2e86 60%,var(--sagiStageBlue2))!important;
 clip-path:none!important;border-radius:0 0 12px 12px!important;box-shadow:0 12px 28px #020b2580!important
}
#scoreBug.sagiToranhe .sbStoppage{background:var(--sagiStageRed)!important;color:#fff!important;clip-path:none!important;border-radius:0 0 10px 0!important}
#scoreBug.sagiToranhe .sbGoalBurst{
 background:linear-gradient(112deg,var(--sagiStageBlue) 0,#0b3fb4 55%,color-mix(in srgb,var(--goalAccent) 60%,#0b3fb4) 100%)!important;
 clip-path:none!important;border-radius:0 14px 14px 0!important;box-shadow:0 12px 34px #020b25a0!important
}
#scoreBug.sagiToranhe .sbGoalBurst:before{background:linear-gradient(118deg,#ffffff2d,transparent 28%,#ffffff0f 55%,transparent 76%)!important}
#scoreBug.sagiToranhe .sbGoalBurst:after{left:96px!important;right:22px!important;height:4px!important;background:var(--goalAccent)!important;border-radius:5px!important}
#scoreBug.sagiToranhe .sbGoalWord{font-style:normal!important;font-weight:1000!important;letter-spacing:.5px!important}
.eventCard{
 left:64px!important;bottom:60px!important;width:780px!important;height:176px!important;min-height:176px!important;
 border-radius:var(--sagiStageRadius)!important;background:linear-gradient(108deg,#061744 0,var(--sagiStageBlue) 45%,#0a2e86 100%)!important;
 box-shadow:0 28px 70px #01091fc9!important;border:1px solid #ffffff20!important;overflow:hidden!important
}
.eventCard:before{left:0!important;right:0!important;top:0!important;height:5px!important;background:var(--eventAccent)!important}
.eventCard:after{content:"";position:absolute;inset:0;pointer-events:none;opacity:.16;background:
 linear-gradient(118deg,transparent 0 60%,#ffffff2a 60% 60.4%,transparent 60.4%),
 repeating-linear-gradient(90deg,transparent 0 92px,#ffffff12 92px 93px)}
.eventPhotoWrap{width:176px!important;min-width:176px!important;height:176px!important;background:linear-gradient(150deg,#0b3aa9,#061744)!important}
.eventIcon{margin-top:45px!important;box-shadow:0 0 0 6px #ffffff0c,0 14px 26px #020819a0!important}
.eventCopy{position:relative;z-index:2;padding-right:22px!important}
.eventKicker{font-size:12px!important;letter-spacing:3.2px!important;font-weight:1000!important;text-transform:uppercase}
.eventName{font-size:38px!important;line-height:1!important;margin-top:8px!important;color:#fff!important;letter-spacing:-.6px!important}
.eventMeta{font-size:13px!important;margin-top:10px!important;color:#c7d5ee!important}
.eventCard.goal{width:780px!important;height:176px!important;min-height:176px!important;padding:0!important;border-left:0!important}
.eventCard.goal .eventPhotoWrap{width:176px!important;min-width:176px!important;height:176px!important}
.eventCard.goal .eventPhoto{width:100%!important;height:100%!important}
.eventCard.goal .eventCopy{padding:0 28px!important}
.eventCard.goal .eventKicker{color:#fff!important}
.eventCard.yellow .eventIcon,.eventCard.red .eventIcon{
 width:58px!important;height:82px!important;min-width:58px!important;border-radius:7px!important;margin:47px 36px 0 32px!important;transform:rotate(-3deg)!important
}
.eventCard.sub .eventIcon{background:#fff!important;color:var(--sagiStageBlue)!important}
.subRowG{font-size:19px!important}
.stateSplash{background:radial-gradient(circle at 72% 36%,#0c45bc66,transparent 34%),linear-gradient(135deg,#020a22f5,#071d57f4 55%,#0a2f84f4)!important}
.stateBox{
 width:1260px!important;height:560px!important;border-radius:24px!important;border:1px solid #ffffff25!important;
 background:linear-gradient(112deg,#061744f7,var(--sagiStageBlue) 56%,#0a3aaaf5)!important;box-shadow:0 42px 120px #010618db!important
}
.stateBox:after{content:"";position:absolute;inset:0;pointer-events:none;opacity:.17;background:repeating-linear-gradient(90deg,transparent 0 119px,#ffffff16 119px 120px)}
.stateAccent{width:8px!important;background:var(--stateAccent)!important}
.stateCopy{padding:58px 70px!important}
.stateKicker{font-size:14px!important;letter-spacing:6px!important;color:#bcd0f8!important}
.stateTitle{font-size:76px!important;letter-spacing:-2.5px!important;color:#fff!important}
.stateScore{font-size:74px!important;color:#fff!important}
.stateTeams{color:#c2d0e9!important}
.stateSplash.mvp .mvpPhoto{width:420px!important;min-width:420px!important;height:560px!important;background:linear-gradient(155deg,#0b3aa9,#041235)!important}
.stateSplash.mvp .mvpName{font-size:64px!important;color:#fff!important}
.matchOverlay{
 background:radial-gradient(circle at 10% 50%,color-mix(in srgb,var(--homeAccent) 34%,transparent),transparent 30%),
 radial-gradient(circle at 90% 50%,color-mix(in srgb,var(--awayAccent) 34%,transparent),transparent 30%),
 linear-gradient(130deg,#020a22 0,var(--sagiStageBlue) 52%,#06143a 100%)!important
}
.matchOverlay:before{inset:0!important;transform:none!important;opacity:.22!important;background:
 repeating-linear-gradient(90deg,transparent 0 119px,#ffffff13 119px 120px),
 linear-gradient(116deg,transparent 0 64%,#ffffff12 64% 64.25%,transparent 64.25%)!important}
.matchCardStage{
 width:1500px!important;height:750px!important;border-radius:28px!important;background:linear-gradient(118deg,#071947f2,#0a2c7af5)!important;
 border:1px solid #ffffff26!important;box-shadow:0 44px 125px #01071bde!important
}
.matchCardStage:before{height:6px!important;background:linear-gradient(90deg,var(--homeAccent) 0 48%,#fff 48% 52%,var(--awayAccent) 52% 100%)!important}
.matchTopLine{height:132px!important;padding:22px 38px!important;border-bottom:1px solid #ffffff1b!important}
.matchBroadcastTag{background:var(--sagiStageRed)!important;border:0!important;color:#fff!important;border-radius:10px!important}
.matchTeams{height:500px!important;padding:32px 48px!important;grid-template-columns:1fr 230px 1fr!important}
.matchTeamBlock{
 min-height:340px;padding:30px 24px!important;border-radius:22px!important;background:var(--sagiStagePaper)!important;
 box-shadow:0 22px 54px #01071c80!important;border:1px solid #fff!important
}
.matchHomeBlock{box-shadow:inset 0 -7px 0 var(--homeAccent),0 22px 54px #01071c80!important}
.matchAwayBlock{box-shadow:inset 0 -7px 0 var(--awayAccent),0 22px 54px #01071c80!important}
.matchCrestShell{width:150px!important;height:150px!important;margin-bottom:20px!important;background:#fff!important;border-color:#d7deea!important}
.matchTeamRole{color:#60708c!important}.matchTeam{font-size:38px!important;color:var(--sagiStageInk)!important}
.matchCenterStage{color:#fff}.matchVs{font-size:32px!important}.matchKickoffStage{font-size:58px!important}
.matchMetaStage{height:118px!important;background:#041235!important;border-top:1px solid #ffffff1a!important;border-radius:0 0 28px 28px!important}
.stage.group-GK:before,.stage.group-DF:before,.stage.group-MF:before,.stage.group-FW:before{
 background:linear-gradient(118deg,var(--sagiStageBlue2) 0 18%,transparent 18% 72%,#ffffff0c 72% 72.3%,transparent 72.3% 100%)!important;opacity:.28!important
}
.label,.playerLabel{
 border-radius:14px!important;background:var(--sagiStagePaper)!important;color:var(--sagiStageInk)!important;
 box-shadow:0 18px 38px #01071ca8!important;border:1px solid #ffffffaa!important
}
.label:before,.playerLabel:before{width:6px!important;border-radius:14px 0 0 14px!important}
.name,.playerName,.no,.playerNo{color:var(--sagiStageInk)!important}
.role,.playerRole{color:#56657e!important}
.stingOverlay,.countdownOverlay{background:linear-gradient(132deg,#020a22,var(--sagiStageBlue) 54%,#0a2f86)!important}
.stingOverlay:before,.countdownOverlay:before{opacity:.18!important;background:repeating-linear-gradient(90deg,transparent 0 119px,#ffffff15 119px 120px)!important}
.stingCore,.countdownCore{border-radius:24px!important;background:#061744df!important;border:1px solid #ffffff24!important;box-shadow:0 34px 100px #01061ad0!important}
.stingLine{background:linear-gradient(90deg,transparent,var(--sagiStageRed),#fff,var(--sagiStageRed),transparent)!important}
.replayStinger .rsPanel{background:linear-gradient(135deg,#020b26 0,var(--sagiStageBlue) 48%,var(--sagiStageBlue2) 100%)!important;box-shadow:0 0 80px #01081f inset!important}
.replayStinger .rsLeft{clip-path:polygon(0 0,100% 0,78% 100%,0 100%)!important;border-right:8px solid var(--sagiStageRed)!important}
.replayStinger .rsRight{clip-path:polygon(22% 0,100% 0,100% 100%,0 100%)!important;border-left:8px solid #fff!important}
.rsKicker{color:#bcd0f8!important}.rsRule{background:var(--sagiStageRed)!important;box-shadow:0 0 22px #f33b4b88!important}
.rsTitle{font-style:normal!important;letter-spacing:1px!important}
.simplePenaltyBoard{filter:drop-shadow(0 28px 42px #01071cbc)!important}
.spbHeader,.spbWing,.spbCore:before{background:linear-gradient(180deg,#071c52f5,#041235fa)!important}
.spbHeader{border-radius:14px!important;clip-path:none!important;border-color:#ffffff2b!important}
.spbWing.home{clip-path:polygon(0 0,93% 0,100% 50%,93% 100%,0 100%)!important}
.spbWing.away{clip-path:polygon(7% 0,100% 0,100% 100%,7% 100%,0 50%)!important}


/* ===== V4.30.8 · SAGI MOTION LANGUAGE =====
   One motion grammar for live information: stage -> reveal -> emphasis -> return. */
:root{
 --sagiMotionFast:160ms;--sagiMotionBase:300ms;--sagiMotionHero:480ms;
 --sagiMotionEase:cubic-bezier(.16,.84,.28,1);--sagiMotionEaseSoft:cubic-bezier(.2,.72,.2,1)
}
@keyframes sagiInfoUp{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:translateY(0)}}
@keyframes sagiInfoIn{from{opacity:0;transform:translateX(-18px)}to{opacity:1;transform:translateX(0)}}
@keyframes sagiScaleIn{from{opacity:0;transform:scale(.92)}to{opacity:1;transform:scale(1)}}
@keyframes sagiStageRise{from{opacity:0;transform:translateY(24px) scale(.985)}to{opacity:1;transform:translateY(0) scale(1)}}
.eventCard.on .eventKicker{animation:sagiInfoIn var(--sagiMotionBase) var(--sagiMotionEase) .05s both}
.eventCard.on .eventName{animation:sagiInfoIn var(--sagiMotionHero) var(--sagiMotionEase) .11s both}
.eventCard.on .eventMeta{animation:sagiInfoUp var(--sagiMotionBase) var(--sagiMotionEaseSoft) .22s both}
.eventCard.on .subRows{animation:sagiInfoUp var(--sagiMotionBase) var(--sagiMotionEaseSoft) .25s both}
.eventCard.on .eventPhotoWrap.on .eventPhoto{animation:sagiScaleIn var(--sagiMotionHero) var(--sagiMotionEase) both}
.eventCard.yellow.on .eventIcon,.eventCard.red.on .eventIcon{animation:sagiScaleIn var(--sagiMotionBase) var(--sagiMotionEase) .04s both}
.stateSplash.on .stateBox{animation:sagiStageRise var(--sagiMotionHero) var(--sagiMotionEase) both}
.stateSplash.on .stateAccent{animation:sagiInfoIn var(--sagiMotionBase) var(--sagiMotionEase) .06s both}
.stateSplash.on .stateKicker{animation:sagiInfoUp var(--sagiMotionBase) var(--sagiMotionEaseSoft) .12s both}
.stateSplash.on .stateTitle{animation:sagiInfoUp var(--sagiMotionHero) var(--sagiMotionEase) .18s both}
.stateSplash.on .stateScore,.stateSplash.on .mvpName{animation:sagiInfoUp var(--sagiMotionHero) var(--sagiMotionEase) .25s both}
.stateSplash.on .stateTeams,.stateSplash.on .mvpMeta{animation:sagiInfoUp var(--sagiMotionBase) var(--sagiMotionEaseSoft) .32s both}
.matchOverlay.on .matchCardStage{animation:sagiStageRise .54s var(--sagiMotionEase) both}
.matchOverlay.on .matchTopLine{animation:sagiInfoUp .34s var(--sagiMotionEaseSoft) .08s both}
.matchOverlay.on .matchHomeBlock{animation:sagiInfoIn .48s var(--sagiMotionEase) .15s both}
.matchOverlay.on .matchAwayBlock{animation:sagiInfoIn .48s var(--sagiMotionEase) .21s both}
.matchOverlay.on .matchCenterStage{animation:sagiScaleIn .42s var(--sagiMotionEase) .27s both}
.matchOverlay.on .matchMetaStage{animation:sagiInfoUp .34s var(--sagiMotionEaseSoft) .34s both}
.stingOverlay.on .stingCore,.countdownOverlay.on .countdownCore{animation:sagiStageRise .5s var(--sagiMotionEase) both}
.stingOverlay.on .stingLogo{animation:sagiScaleIn .5s var(--sagiMotionEase) .08s both}
.countdownOverlay.on .countdownNumber{animation:sagiScaleIn .4s var(--sagiMotionEase) .08s both}
@media(prefers-reduced-motion:reduce){
 .eventCard.on .eventKicker,.eventCard.on .eventName,.eventCard.on .eventMeta,.eventCard.on .subRows,
 .eventCard.on .eventPhoto,.eventCard.yellow.on .eventIcon,.eventCard.red.on .eventIcon,
 .stateSplash.on .stateBox,.stateSplash.on .stateAccent,.stateSplash.on .stateKicker,.stateSplash.on .stateTitle,
 .stateSplash.on .stateScore,.stateSplash.on .stateTeams,.stateSplash.on .mvpName,.stateSplash.on .mvpMeta,
 .matchOverlay.on .matchCardStage,.matchOverlay.on .matchTopLine,.matchOverlay.on .matchHomeBlock,.matchOverlay.on .matchAwayBlock,
 .matchOverlay.on .matchCenterStage,.matchOverlay.on .matchMetaStage,.stingOverlay.on .stingCore,.stingOverlay.on .stingLogo,
 .countdownOverlay.on .countdownCore,.countdownOverlay.on .countdownNumber{animation:none!important}
}


/* ===== V4.30.8 · SAGI SCORE INTELLIGENCE =====
   Broadcast information hierarchy:
   identity -> score -> clock -> phase -> exceptional state. */
#scoreBug.sagiToranhe{
 --scorePaper:#f8f9fc;--scoreInk:#071638;--scoreNavy:#061744;--scoreBlue:#0a43c9;--scoreRed:#ed3348;
 height:58px!important;filter:drop-shadow(0 10px 24px #01081d80)
}
#scoreBug.sagiToranhe .sbEventBrand{
 width:60px!important;height:58px!important;flex-basis:60px!important;border-radius:12px 0 0 12px!important
}
#scoreBug.sagiToranhe .sbEventBrand:before{border-radius:12px 0 0 12px!important}
#scoreBug.sagiToranhe .sbEventBrand img{left:-2px!important;top:-5px!important;width:68px!important;height:68px!important}
#scoreBug.sagiToranhe .sbEventBrand:after{left:7px!important;right:7px!important;bottom:4px!important;height:3px!important}
#scoreBug.sagiToranhe .sbTeamBlock{
 height:58px!important;min-width:124px!important;padding:0 11px!important;gap:7px!important;
 background:var(--scorePaper)!important;color:var(--scoreInk)!important
}
#scoreBug.sagiToranhe .sbTeamBlock.home{border-radius:0!important}
#scoreBug.sagiToranhe .sbTeamBlock.away{border-radius:0 12px 12px 0!important}
#scoreBug.sagiToranhe .sbCrest{width:27px!important;height:27px!important;flex:0 0 27px!important}
#scoreBug.sagiToranhe .sbTeamMeta{gap:6px!important}
#scoreBug.sagiToranhe .sbTeam{
 font-size:19px!important;line-height:1!important;font-weight:950!important;letter-spacing:-.15px!important;
 color:var(--scoreInk)!important;text-shadow:none!important
}
#scoreBug.sagiToranhe .sbReds{gap:3px!important;align-items:center!important}
#scoreBug.sagiToranhe .sbRedCard{
 width:8px!important;height:14px!important;border-radius:2px!important;background:#e3313d!important;
 transform:rotate(-2deg)!important;box-shadow:0 2px 5px #0005,inset 0 0 0 1px #ffffff45!important
}
#scoreBug.sagiToranhe .sbScoreWrap{
 width:44px!important;min-width:44px!important;height:58px!important;flex:0 0 44px!important;
 background:var(--scorePaper)!important;color:var(--scoreInk)!important
}
#scoreBug.sagiToranhe .sbScore{
 font-size:28px!important;font-weight:1000!important;line-height:1!important;color:var(--scoreInk)!important;
 font-variant-numeric:tabular-nums!important;letter-spacing:-1px!important
}
#scoreBug.sagiToranhe #sbHomeScoreWrap:after{
 content:"";display:none!important
}
#scoreBug.sagiToranhe #sbAwayScoreWrap{margin-left:4px!important}
#scoreBug.sagiToranhe #sbHomeScoreWrap{
 position:relative!important;margin-right:0!important
}
#scoreBug.sagiToranhe #sbHomeScoreWrap:before{
 content:"–";position:absolute!important;right:-7px!important;top:50%!important;transform:translateY(-54%)!important;
 width:14px!important;text-align:center!important;color:#4e5c76!important;font-size:17px!important;font-weight:900!important;z-index:9!important
}
#scoreBug.sagiToranhe .sbMid{
 left:calc(60px + 124px + 44px + 2px)!important;top:58px!important;transform:none!important;
 width:auto!important;min-width:198px!important;height:30px!important;padding:0 8px!important;
 display:flex!important;flex-direction:row!important;align-items:center!important;justify-content:center!important;gap:8px!important;
 background:linear-gradient(105deg,#041235,#071d57 60%,#0a2e86)!important;border-radius:0 0 11px 11px!important;
 box-shadow:0 10px 24px #01081c80!important
}
#scoreBug.sagiToranhe .sbCompetition{display:none!important}
#scoreBug.sagiToranhe .sbPeriod{
 display:flex!important;order:0!important;height:20px!important;padding:0 7px!important;align-items:center!important;justify-content:center!important;
 border-radius:6px!important;background:#ffffff12!important;color:#d9e5fa!important;font-size:9px!important;letter-spacing:.6px!important;
 font-weight:1000!important;white-space:nowrap!important
}
#scoreBug.sagiToranhe .sbClockRow{
 order:1!important;height:30px!important;width:auto!important;margin:0!important;display:flex!important;align-items:center!important;
 justify-content:center!important;gap:6px!important
}
#scoreBug.sagiToranhe .sbClock{
 min-width:58px!important;height:30px!important;padding:0!important;font-size:16px!important;line-height:30px!important;
 font-weight:950!important;letter-spacing:.25px!important;color:#fff!important;font-variant-numeric:tabular-nums!important
}
#scoreBug.sagiToranhe .sbStoppage{
 height:22px!important;min-width:0!important;margin:0!important;padding:0 7px!important;border-radius:6px!important;
 display:none!important;align-items:center!important;justify-content:center!important;background:var(--scoreRed)!important;color:#fff!important;
 font-size:9px!important;font-weight:1000!important;letter-spacing:.1px!important;white-space:nowrap!important
}
#scoreBug.sagiToranhe .sbStoppage.on{display:flex!important}
#scoreBug.sagiToranhe .sbPenalty{font-size:7px!important;letter-spacing:.2px!important;margin-top:2px!important}
#scoreBug.sagiToranhe.goalExpand .sbGoalBurst{
 top:0!important;height:58px!important;border-radius:0 12px 12px 0!important
}
#scoreBug.sagiToranhe .sbGoalCrest{top:-15px!important;width:84px!important;height:84px!important}
#scoreBug.sagiToranhe .sbGoalWord{top:5px!important;font-size:37px!important}


/* ===== V4.30.8 · COMPACT LIVE SCOREBUG =====
   Regular play stays minimal. Added time appears only when explicitly set. */
#scoreBug.scoreBug.sagiToranhe{
 left:42px!important;top:34px!important;height:54px!important;width:auto!important;min-width:0!important;
 overflow:visible!important;filter:drop-shadow(0 9px 20px #01081d70)!important
}
#scoreBug.scoreBug.sagiToranhe .sbEventBrand{
 width:54px!important;height:54px!important;flex:0 0 54px!important;border-radius:12px 0 0 12px!important
}
#scoreBug.scoreBug.sagiToranhe .sbEventBrand img{width:60px!important;height:60px!important;left:-3px!important;top:-4px!important}
#scoreBug.scoreBug.sagiToranhe .sbTeamBlock{
 height:54px!important;min-width:96px!important;max-width:150px!important;width:auto!important;
 padding:0 8px!important;gap:5px!important;overflow:hidden!important
}
#scoreBug.scoreBug.sagiToranhe .sbCrest{width:24px!important;height:24px!important;flex:0 0 24px!important}
#scoreBug.scoreBug.sagiToranhe .sbTeamMeta{min-width:0!important;overflow:hidden!important}
#scoreBug.scoreBug.sagiToranhe .sbTeam{
 font-size:18px!important;max-width:108px!important;overflow:hidden!important;text-overflow:clip!important;
 white-space:nowrap!important;letter-spacing:-.2px!important
}
#scoreBug.scoreBug.sagiToranhe .sbScoreWrap{
 width:38px!important;min-width:38px!important;height:54px!important;flex:0 0 38px!important
}
#scoreBug.scoreBug.sagiToranhe .sbScore{font-size:27px!important}
#scoreBug.scoreBug.sagiToranhe #sbAwayScoreWrap{margin-left:2px!important}
#scoreBug.scoreBug.sagiToranhe #sbHomeScoreWrap:before{right:-6px!important;width:12px!important;font-size:16px!important}
#scoreBug.scoreBug.sagiToranhe .sbMid{
 left:54px!important;top:54px!important;min-width:116px!important;width:auto!important;height:27px!important;
 padding:0 7px!important;gap:6px!important;border-radius:0 0 9px 9px!important;justify-content:flex-start!important
}
#scoreBug.scoreBug.sagiToranhe .sbPeriod{
 height:18px!important;padding:0 6px!important;font-size:8px!important;border-radius:5px!important
}
#scoreBug.scoreBug.sagiToranhe .sbClockRow{height:27px!important;gap:5px!important}
#scoreBug.scoreBug.sagiToranhe .sbClock{
 min-width:53px!important;height:27px!important;line-height:27px!important;font-size:15px!important
}
#scoreBug.scoreBug.sagiToranhe .sbStoppage{
 height:21px!important;padding:0 8px!important;border-radius:5px!important;
 background:#19e77d!important;color:#071638!important;font-size:10px!important;font-weight:1000!important
}
#scoreBug.scoreBug.sagiToranhe .sbReds{gap:2px!important}
#scoreBug.scoreBug.sagiToranhe .sbRedCard{width:7px!important;height:12px!important}
#scoreBug.scoreBug.sagiToranhe.goalExpand .sbGoalBurst{
 height:54px!important;width:260px!important;min-width:260px!important;max-width:260px!important;flex:0 0 260px!important
}
#scoreBug.scoreBug.sagiToranhe .sbGoalWord{font-size:31px!important}
#scoreBug.scoreBug.sagiToranhe .sbGoalScorer{max-width:205px!important}


/* ===== V4.30.8 · INTEGRATED EVENT IDENTITY =====
   Event logo, score ribbon and clock rail behave as one broadcast object. */
#scoreBug.scoreBug.sagiToranhe{
 --identityDeep:#061744;--identityDeep2:#0a2e86;--identityAccent:#19e77d;
 height:54px!important;overflow:visible!important;isolation:isolate!important
}
#scoreBug.scoreBug.sagiToranhe .sbEventBrand{
 position:relative!important;left:auto!important;top:auto!important;
 width:66px!important;height:81px!important;flex:0 0 66px!important;z-index:8!important;
 margin:0!important;border-radius:13px 0 0 13px!important;clip-path:none!important;overflow:visible!important;
 background:linear-gradient(145deg,var(--identityDeep) 0,var(--identityDeep2) 100%)!important;
 box-shadow:0 10px 24px #01081d75!important
}
#scoreBug.scoreBug.sagiToranhe .sbEventBrand:before{
 content:""!important;position:absolute!important;inset:0!important;z-index:0!important;
 border-radius:13px 0 0 13px!important;clip-path:none!important;
 background:
 linear-gradient(115deg,transparent 0 52%,#ffffff12 52% 53%,transparent 53%),
 linear-gradient(145deg,var(--identityDeep) 0,var(--identityDeep2) 100%)!important;
 box-shadow:none!important
}
#scoreBug.scoreBug.sagiToranhe .sbEventBrand:after{
 content:""!important;position:absolute!important;left:9px!important;right:10px!important;bottom:8px!important;height:3px!important;
 border-radius:3px!important;background:var(--identityAccent)!important;box-shadow:0 0 10px #19e77d80!important;z-index:1!important
}
#scoreBug.scoreBug.sagiToranhe .sbEventBrand img{
 position:absolute!important;left:2px!important;top:1px!important;width:60px!important;height:60px!important;z-index:3!important;
 object-fit:contain!important;filter:drop-shadow(0 4px 7px #0006)!important
}
/* White score ribbon tucks into the logo block instead of starting as a separate card. */
#scoreBug.scoreBug.sagiToranhe .sbTeamBlock.home{
 margin-left:-8px!important;padding-left:14px!important;position:relative!important;z-index:5!important;
 border-radius:0!important;clip-path:polygon(8px 0,100% 0,100% 100%,0 100%,8px 50%)!important
}
#scoreBug.scoreBug.sagiToranhe .sbTeamBlock.away{
 border-radius:0 11px 11px 0!important
}
/* Clock rail begins inside the logo footprint so the lower rail feels continuous with it. */
#scoreBug.scoreBug.sagiToranhe .sbMid{
 left:58px!important;top:54px!important;min-width:122px!important;height:27px!important;
 border-radius:0 0 9px 0!important;z-index:6!important;
 background:linear-gradient(105deg,var(--identityDeep) 0,var(--identityDeep2) 100%)!important;
 box-shadow:0 9px 18px #01081d66!important
}
#scoreBug.scoreBug.sagiToranhe .sbPeriod{
 background:#ffffff12!important;color:#dfeaff!important
}
#scoreBug.scoreBug.sagiToranhe .sbStoppage{
 background:var(--identityAccent)!important;color:#071638!important
}
/* Keep the main live object concise; the identity block may extend down, but not horizontally. */
#scoreBug.scoreBug.sagiToranhe .sbGoalBurst{z-index:4!important}
#scoreBug.scoreBug.sagiToranhe.goalExpand .sbGoalBurst{border-radius:0 11px 11px 0!important}


/* ===== V4.30.8 · TIME-FIRST SCORE RAIL =====
   Normal halves show clock only. Added time and exceptional phases appear only when relevant. */
#scoreBug.scoreBug.sagiToranhe .sbMid{
 min-width:69px!important;width:auto!important;height:27px!important;padding:0 7px!important;gap:0!important;
 align-items:center!important;justify-content:flex-start!important;overflow:visible!important
}
#scoreBug.scoreBug.sagiToranhe .sbPeriod{
 display:none!important;order:0!important;height:19px!important;margin:0 6px 0 0!important;padding:0 7px!important;
 align-items:center!important;justify-content:center!important;border-radius:5px!important;background:#ffffff12!important;
 color:#dfeaff!important;font-size:8px!important;letter-spacing:.5px!important;font-weight:1000!important;white-space:nowrap!important
}
#scoreBug.scoreBug.sagiToranhe .sbPeriod.special{display:flex!important}
#scoreBug.scoreBug.sagiToranhe .sbClockRow{
 order:1!important;height:27px!important;width:auto!important;margin:0!important;display:flex!important;
 align-items:center!important;justify-content:flex-start!important;gap:5px!important
}
#scoreBug.scoreBug.sagiToranhe .sbClock{
 min-width:55px!important;width:auto!important;height:27px!important;line-height:27px!important;padding:0!important;
 font-size:15px!important;font-weight:950!important;letter-spacing:.15px!important;font-variant-numeric:tabular-nums!important
}
#scoreBug.scoreBug.sagiToranhe .sbStoppage{margin-left:1px!important}


/* ===== V4.30.8 · SCORE CENTER REFINEMENT =====
   One visual score pair, tighter identity spacing, restrained score roll. */
#scoreBug.scoreBug .sbTeamBlock{
 min-width:102px!important;max-width:150px!important;padding:0 7px!important;gap:4px!important
}
#scoreBug.scoreBug .sbTeamMeta{gap:4px!important}
#scoreBug.scoreBug .sbCrest{width:23px!important;height:23px!important;flex:0 0 23px!important}
#scoreBug.scoreBug .sbTeam{font-size:17px!important}
#scoreBug.scoreBug .sbReds{margin-left:1px!important}
#scoreBug.scoreBug .sbRedCard{width:6px!important;height:11px!important}

#scoreBug.scoreBug .sbScoreWrap{
 width:38px!important;min-width:38px!important;flex:0 0 38px!important;height:58px!important;
 background:#eef2f7!important;color:#071638!important;box-shadow:none!important;overflow:hidden!important
}
#scoreBug.scoreBug #sbHomeScoreWrap{
 margin:0!important;border-radius:0!important;padding-left:2px!important;z-index:7!important
}
#scoreBug.scoreBug #sbAwayScoreWrap{
 margin:0!important;border-radius:0!important;padding-right:2px!important;z-index:6!important
}
#scoreBug.scoreBug .sbScore{
 position:relative!important;z-index:4!important;font-size:27px!important;font-weight:1000!important;
 font-variant-numeric:tabular-nums!important;letter-spacing:-.8px!important
}
#scoreBug.scoreBug #sbHomeScoreWrap:before{
 content:"–"!important;display:block!important;position:absolute!important;right:-8px!important;top:50%!important;
 transform:translateY(-53%)!important;width:16px!important;text-align:center!important;color:#66738b!important;
 font-size:16px!important;font-weight:1000!important;line-height:1!important;z-index:12!important;pointer-events:none!important
}
#scoreBug.scoreBug #sbHomeScoreWrap:after{display:none!important}
#scoreBug.scoreBug .sbScoreWrap.scoreRolling:after{
 content:attr(data-old-score)!important;display:block!important;position:absolute!important;inset:0!important;
 z-index:3!important;align-items:center!important;justify-content:center!important;padding-top:16px!important;
 text-align:center!important;color:#071638!important;font-size:27px!important;font-weight:1000!important;
 font-variant-numeric:tabular-nums!important;animation:sagiOldScoreOut .38s cubic-bezier(.4,0,.7,.2) both!important
}
#scoreBug.scoreBug .sbScore.scoreRolling{
 animation:sagiNewScoreIn .42s cubic-bezier(.16,.84,.28,1) both!important
}
#scoreBug.scoreBug.scoreAccentPulse .sbScoreWrap{
 animation:sagiScorePairGlow .38s cubic-bezier(.2,.8,.2,1) both
}
@keyframes sagiOldScoreOut{
 0%{opacity:1;transform:translateY(0)}
 100%{opacity:0;transform:translateY(-18px)}
}
@keyframes sagiNewScoreIn{
 0%{opacity:0;transform:translateY(18px)}
 70%{opacity:1;transform:translateY(-2px)}
 100%{opacity:1;transform:translateY(0)}
}
@keyframes sagiScorePairGlow{
 0%,100%{filter:brightness(1)}
 45%{filter:brightness(1.08)}
}
@media(prefers-reduced-motion:reduce){
 #scoreBug.scoreBug .sbScoreWrap.scoreRolling:after{display:none!important;animation:none!important}
 #scoreBug.scoreBug .sbScore.scoreRolling,#scoreBug.scoreBug.scoreAccentPulse .sbScoreWrap{animation:none!important}
}


/* V4.30.8 geometry lock: override all legacy scorebug widths. */
#scoreBug.scoreBug.sagiToranhe .sbTeamBlock{
 box-sizing:border-box!important;min-width:102px!important;max-width:150px!important;padding:0 7px!important
}
#scoreBug.scoreBug.sagiToranhe .sbCrest{width:23px!important;height:23px!important;flex:0 0 23px!important}
#scoreBug.scoreBug.sagiToranhe .sbScoreWrap{
 box-sizing:border-box!important;width:38px!important;min-width:38px!important;max-width:38px!important;flex:0 0 38px!important;padding:0!important
}
#scoreBug.scoreBug.sagiToranhe #sbHomeScoreWrap{margin:0!important}
#scoreBug.scoreBug.sagiToranhe #sbAwayScoreWrap{margin:0!important}



/* ===== V4.30.8 · REFEREE CARD LANGUAGE LOCK ===== */
.eventCard.yellow .eventIcon,.eventCard.red .eventIcon{
 width:56px!important;min-width:56px!important;max-width:56px!important;height:82px!important;flex:0 0 56px!important;
 border-radius:4px!important;transform:rotate(-2deg)!important;box-shadow:0 13px 25px #0009,0 0 0 1px #0006,inset 0 0 0 1px #ffffff38!important;
}
.eventCard.yellow .eventIcon{background-color:#f2d536!important;background-image:linear-gradient(155deg,#ffeb66 0,#f2d536 48%,#d5b800 100%)!important}
.eventCard.red .eventIcon{background-color:#e33440!important;background-image:linear-gradient(155deg,#ff636d 0,#e33440 48%,#b51824 100%)!important}
.eventCard.yellow .eventKicker{color:#f2d536!important}.eventCard.red .eventKicker{color:#e33440!important}
.eventCard.yellow .eventIcon:before,.eventCard.red .eventIcon:before{inset:4px!important;border-radius:2px!important}
</style></head>
<body>
<div id="stage" class="stage"><div id="transitionLayer" class="transitionLayer"></div><div id="cueBadgeStage" class="cueBadgeStage"></div><div id="showStepStage" class="showStepStage"></div><div id="sideBadgeStage" class="sideBadgeStage">主队</div>
  <div id="stingOverlay" class="stingOverlay"><div class="stingCore"><img id="stingLogo" class="stingLogo"><div class="stingLine"></div><div id="stingCompetition" class="stingComp">SAGI 足球</div></div></div>
  <div id="matchOverlay" class="matchOverlay"><div class="matchCardStage">
    <div class="matchTopLine"><img id="matchEventLogoStage" class="matchEventLogoStage"><div><div id="matchCompetitionStage" class="matchCompetition">比赛</div><div id="matchRoundStage" class="matchRound"></div></div><div class="matchBroadcastTag">赛前直播</div></div>
    <div class="matchTeams">
      <div class="matchTeamBlock matchHomeBlock"><div class="matchCrestShell"><img id="matchHomeCrestStage" class="matchCrestStage"></div><div class="matchTeamRole">主队</div><div id="matchHomeStage" class="matchTeam">主队</div></div>
      <div class="matchCenterStage"><div class="matchVs">VS</div><div id="matchKickoffStage" class="matchKickoffStage"></div><div class="matchKickoffLabel">开赛时间</div></div>
      <div class="matchTeamBlock matchAwayBlock"><div class="matchCrestShell"><img id="matchAwayCrestStage" class="matchCrestStage"></div><div class="matchTeamRole">客队</div><div id="matchAwayStage" class="matchTeam">客队</div></div>
    </div>
    <div class="matchMetaStage"><span>比赛场地</span><b id="matchVenueStage"></b></div>
  </div></div>
  <div id="countdownOverlay" class="countdownOverlay"><div class="countdownCore"><div class="countdownLabel">开赛倒计时</div><div id="countdownNumber" class="countdownNumber">5</div><div id="countdownSub" class="countdownSub">比赛</div></div></div>
  <div id="tunnelScene" class="tunnelScene"><div class="tunnelBack"></div><div class="portal"></div><div class="wall left"></div><div class="wall right"></div><div class="ceiling"></div><div class="floor"></div><div class="led left"><div id="ledLeft" class="ledText">球队<small>首发11人</small></div></div><div class="led right"><div id="ledRight" class="ledText">SAGI<small>球员通道</small></div></div><div class="roofLights"></div><div class="fog"></div><div class="cameraVignette"></div></div>
  <div id="stadium" class="stadium"></div><img id="stadiumPhoto" class="stadiumPhoto"><div id="shade" class="shade"></div><div id="pitchLines" class="pitchLines"></div><div class="light l1"></div><div class="light l2"></div>
  <div class="header"><img id="crest" class="crest"><div><div id="team" class="team">球队</div><div id="stageLineupLabel" class="sub">首发11人</div></div></div>
  <div id="groupTitle" class="groupTitle">首发11人</div><div id="groupName" class="groupName">球队阵容</div><div class="line"></div>
  <div id="freezeFlash" class="freezeFlash"></div><div id="roleGlow" class="roleGlow"></div><div id="roleBackdrop" class="roleBackdrop">11</div><div id="players" class="players layout-TEAM"></div><div id="fullList" class="fullList" style="display:none"></div><div id="subList" class="subList" style="display:none"></div>
  <div id="formationPanel" class="formation"><div class="formationHead"><div><div class="formationTitle">阵型</div><div style="font-size:12px;color:#8f97a5">首发阵型</div></div><div id="formationText" class="formationText">4-3-3</div></div><div class="pitch"><div class="boxTop"></div><div class="boxBottom"></div><div id="nodes" class="nodes"></div></div></div>
</div>

<div id="graphicsStage" class="graphicsStage">
  <div id="simplePenaltyBoard" class="simplePenaltyBoard">
    <div class="spbHalo"></div>
    <div class="spbHeader">
      <div id="spbCompetition" class="spbCompetition">SAGI 赛事直播</div>
      <div class="spbTitle"><i></i><span>点球大战</span><i></i></div>
      <em id="spbPhase" class="spbPhaseFloat">第1轮</em>
    </div>
    <div class="spbArena">
      <div id="spbHomeWing" class="spbWing home">
        <div class="spbCrestShell"><img id="spbHomeCrest" class="spbCrest"></div>
        <div class="spbIdentity"><span class="spbRole">HOME · 主队</span><strong id="spbHomeName">主队</strong><div id="spbHomeDots" class="spbDots"></div></div>
      </div>
      <div class="spbCore">
        <div class="spbScoreLine">
          <b id="spbHomeScore" class="spbScore home">0</b>
          <div class="spbPkOrb"><b>PK</b></div>
          <b id="spbAwayScore" class="spbScore away">0</b>
        </div>
        <div class="spbCoreMeta"><b id="spbLiveStatus">进行中</b><span id="spbNext">等待主罚</span></div>
      </div>
      <div id="spbAwayWing" class="spbWing away">
        <div class="spbIdentity"><span class="spbRole">AWAY · 客队</span><strong id="spbAwayName">客队</strong><div id="spbAwayDots" class="spbDots"></div></div>
        <div class="spbCrestShell"><img id="spbAwayCrest" class="spbCrest"></div>
      </div>
    </div>
    <div class="spbRail"><span class="home"></span><span class="center"></span><span class="away"></span></div>
  </div>
  <div id="scoreBug" class="scoreBug sagiToranhe"><div class="sbEventBrand"><img id="sbEventLogo" alt=""><span id="sbEventFallback" class="sbEventFallback">SAGI</span></div>
    <div class="sbTeamBlock home"><img id="sbHomeCrest" class="sbCrest"><div class="sbTeamMeta"><div id="sbHome" class="sbTeam">主队</div><div id="sbHomeReds" class="sbReds"></div></div></div>
    <div id="sbHomeScoreWrap" class="sbScoreWrap"><div id="sbHomeScore" class="sbScore">0</div><div id="sbHomePen" class="sbPenalty">点球 0</div></div>
    <div class="sbMid"><div id="sbCompetition" class="sbCompetition">SAGI 直播</div><div class="sbClockRow"><div id="sbClock" class="sbClock">00:00</div><div id="sbStoppage" class="sbStoppage">+3</div></div><div id="sbPeriod" class="sbPeriod">1H</div></div>
    <div id="sbAwayScoreWrap" class="sbScoreWrap"><div id="sbAwayScore" class="sbScore">0</div><div id="sbAwayPen" class="sbPenalty">点球 0</div></div>
    <div class="sbTeamBlock away"><img id="sbAwayCrest" class="sbCrest"><div class="sbTeamMeta"><div id="sbAwayReds" class="sbReds"></div><div id="sbAway" class="sbTeam">客队</div></div></div>
    <div id="sbGoalBurst" class="sbGoalBurst" aria-hidden="true"><img id="sbGoalCrest" class="sbGoalCrest" alt="">
      <div class="sbGoalWord"><span>G</span><span>O</span><span>A</span><span>L</span></div>
      <div id="sbGoalScorer" class="sbGoalScorer">进球</div>
    </div>
    <div id="penaltyShootoutBar" class="penaltyShootoutBar">
      <div class="penSide home"><div id="sbPenHomeDots" class="sbPenDots"></div></div>
      <div class="penCenter"><b id="sbPenStage">点球大战</b><span id="sbPenNext">等待主罚</span></div>
      <div class="penSide away"><div id="sbPenAwayDots" class="sbPenDots"></div></div>
    </div>
  </div>
  <div id="replayStinger" class="replayStinger" aria-hidden="true">
    <div class="rsPanel rsLeft"></div><div class="rsPanel rsRight"></div>
    <div class="rsCenter">
      <div class="rsLogoWrap"><img id="rsLogo" class="rsLogo" alt=""><div id="rsLogoFallback" class="rsLogoFallback">SAGI</div></div>
      <div id="rsKicker" class="rsKicker">精彩回放</div>
      <div id="rsTitle" class="rsTitle">INSTANT REPLAY</div>
      <div class="rsRule"></div>
    </div>
  </div>
  <div id="eventCard" class="eventCard"><div id="eventPhotoWrap" class="eventPhotoWrap"><img id="eventPhoto" class="eventPhoto"></div><div id="eventIcon" class="eventIcon">⚽</div><div id="eventCopy" class="eventCopy"><div id="eventKicker" class="eventKicker">进球</div><div id="eventName" class="eventName"></div><div id="eventMeta" class="eventMeta"></div><div id="subRows" class="subRows"></div></div></div>
  <div id="stateSplash" class="stateSplash"><div id="stateBox" class="stateBox"><div class="stateAccent"></div><img id="mvpPhoto" class="mvpPhoto"><div id="stateCopy" class="stateCopy"><div id="stateKicker" class="stateKicker"></div><div id="stateTitle" class="stateTitle"></div><div id="stateScore" class="stateScore"></div><div id="stateTeams" class="stateTeams"></div><div id="mvpName" class="mvpName"></div><div id="mvpMeta" class="mvpMeta"></div></div></div></div>
</div>

<script>
(function(){
'use strict';
const LAN_DIRECT=true;
async function lanState(){
 const r=await fetch('/api/state',{cache:'no-store'});
 if(!r.ok)throw new Error('LAN '+r.status);
 return r.json();
}
async function lanMatchday(){
 const r=await fetch('/api/matchday?ts='+Date.now(),{cache:'no-store'});
 if(!r.ok)throw new Error('MATCHDAY '+r.status);
 return r.json();
}

const q=id=>document.getElementById(id),ROLE_NAMES={GK:'门将',DF:'后卫',MF:'中场',FW:'前锋'};
function displayRoleLabel(v){const x=String(v||'').toUpperCase();return({GK:'门将',DF:'后卫',MF:'中场',FW:'前锋',SUB:'替补',CB:'中后卫',LB:'左后卫',RB:'右后卫',DM:'后腰',CM:'中场',AM:'前腰',LW:'左边锋',RW:'右边锋',ST:'前锋'})[x]||String(v||'')}
const FORMATIONS={
 '4-3-3':{GK:[[50,91]],DF:[[16,73],[38,72],[62,72],[84,73]],MF:[[24,48],[50,52],[76,48]],FW:[[18,22],[50,18],[82,22]]},
 '4-4-2':{GK:[[50,91]],DF:[[16,73],[38,72],[62,72],[84,73]],MF:[[16,48],[38,50],[62,50],[84,48]],FW:[[35,22],[65,22]]},
 '4-2-3-1':{GK:[[50,91]],DF:[[16,74],[38,72],[62,72],[84,74]],MF:[[36,56],[64,56],[18,38],[50,36],[82,38]],FW:[[50,18]]},
 '3-5-2':{GK:[[50,91]],DF:[[25,72],[50,75],[75,72]],MF:[[12,48],[32,54],[50,42],[68,54],[88,48]],FW:[[35,22],[65,22]]},
 '3-4-3':{GK:[[50,91]],DF:[[25,72],[50,75],[75,72]],MF:[[16,49],[38,52],[62,52],[84,49]],FW:[[18,22],[50,18],[82,22]]},
 '5-3-2':{GK:[[50,91]],DF:[[10,72],[30,75],[50,73],[70,75],[90,72]],MF:[[25,48],[50,52],[75,48]],FW:[[35,22],[65,22]]}
};

function clampPlayerCount(n){return Math.max(3,Math.min(15,Math.round(Number(n)||11)))}
function playerCount(x){return clampPlayerCount(x&&x.playerCount||x&&x.matchFormat&&x.matchFormat.playerCount||x&&x.package&&x.package.matchFormat&&x.package.matchFormat.playerCount||(x&&x.allPlayers&&x.allPlayers.length)||11)}
function startingLabel(x){const n=playerCount(x);return '首发'+n+'人'}
function starterCode(x){return String(playerCount(x))}
function formationParts(name){return String(name||'').split('-').map(Number).filter(n=>Number.isFinite(n)&&n>0)}
function linePoints(count,y){count=Math.max(0,Number(count)||0);return Array.from({length:count},(_,i)=>[((i+1)/(count+1))*100,y])}
function formationPoints(name){
 if(FORMATIONS[name])return FORMATIONS[name];
 const nums=formationParts(name),f={GK:[[50,91]],DF:[],MF:[],FW:[]};if(!nums.length)return f;
 if(nums.length===1){f.MF=linePoints(nums[0],48);return f}
 if(nums.length===2){f.DF=linePoints(nums[0],72);f.FW=linePoints(nums[1],22);return f}
 f.DF=linePoints(nums[0],72);f.FW=linePoints(nums[nums.length-1],22);
 const mids=nums.slice(1,-1);mids.forEach((count,i)=>{const y=mids.length===1?48:58-(i*20/(mids.length-1));f.MF.push(...linePoints(count,y))});return f
}
function formationRoleCounts(name){
 const nums=formationParts(name),out={GK:1,DF:0,MF:0,FW:0};
 if(nums.length===1)out.MF=nums[0]||0;else if(nums.length===2){out.DF=nums[0]||0;out.FW=nums[1]||0}
 else if(nums.length>=3){out.DF=nums[0]||0;out.FW=nums[nums.length-1]||0;out.MF=nums.slice(1,-1).reduce((a,n)=>a+n,0)}return out
}
function effectivePlayers(x){
 const src=Array.isArray(x&&x.allPlayers)?x.allPlayers:[],need=formationRoleCounts(x&&x.formation||''),out=[];
 for(const role of ['GK','DF','MF','FW'])out.push(...src.filter(p=>p.role===role).slice(0,Math.max(0,Number(need[role])||0)));
 return out.slice(0,playerCount(x))
}
function effectiveGroupPlayers(x){
 if(!x||!['GK','DF','MF','FW'].includes(x.group))return Array.isArray(x&&x.players)?x.players:[];
 const need=formationRoleCounts(x.formation||''),n=Math.max(0,Number(need[x.group])||0);
 return (Array.isArray(x.players)?x.players:[]).slice(0,n)
}

let last='',lastGraphics='',lastGraphicsRevision=0,lastGraphicsFixtureKey='',hideTimer=null,current=null,currentGraphics=null,eventTimer=null,eventCleanupTimer=null,frozenGraphics=null,lastHomeScore=null,lastAwayScore=null,lastScoreboardVisible=false;
let outputHealth={pollOk:0,pollFail:0,recoveries:0,consecutiveFailures:0,watchdogTrips:0,softRepolls:0,lastOkAt:0,lastErrorAt:0,lastAppliedAt:0,lastWatchdogAt:0};let outputWatchdogBusy=false;
function esc(s){return String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function escAttr(s){return String(s??'').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;')}
function fit(){const s=Math.min(innerWidth/1920,innerHeight/1080),x=(innerWidth-1920*s)/2,y=(innerHeight-1080*s)/2,t='translate3d('+x+'px,'+y+'px,0) scale('+s+')';q('stage').style.transform=t;q('graphicsStage').style.transform=t}
function fallback(role,i,n){const y={GK:91,DF:72,MF:48,FW:22}[role]||50;return[((i+1)/(n+1))*100,y]}
function formationPlayerKey(p){return String(p&&p.layoutKey||p&&p.id||((p&&p.number)||'')+'|'+((p&&p.name)||'')+'|'+((p&&p.role)||''))}
function safeFormationXY(xy,fallbackXY){if(!Array.isArray(xy)||xy.length<2)return fallbackXY;return[Math.max(5,Math.min(95,Number(xy[0])||fallbackXY[0])),Math.max(5,Math.min(95,Number(xy[1])||fallbackXY[1]))]}
function allPoints(x){const form=formationPoints(x.formation),out=[],valid=effectivePlayers(x),layout=x&&x.formationLayout&&typeof x.formationLayout==='object'?x.formationLayout:{};for(const role of ['GK','DF','MF','FW']){const ps=form[role]||[],arr=valid.filter(p=>p.role===role);arr.forEach((p,i)=>{const base=ps[i]||fallback(role,i,arr.length),xy=safeFormationXY(layout[formationPlayerKey(p)],base);out.push({p,role,xy})})}return out}
function renderNodes(x){q('formationText').textContent=x.formation||'4-3-3';q('nodes').innerHTML='';allPoints(x).forEach(({p,role,xy},i)=>{const d=document.createElement('div'),hasPhoto=!!p.photo;d.className='node'+(hasPhoto?' hasPhoto':'')+((x.group==='FULL'||x.group===role)?' active':'')+(p.captain?' captainNode':'');d.style.left=xy[0]+'%';d.style.top=xy[1]+'%';d.style.setProperty('--node-i',i);const visual=hasPhoto?'<img src="'+escAttr(p.photo)+'" alt="">':'<span class="nodeFallbackNo">'+esc(p.number)+'</span>';d.innerHTML='<div class="nodeVisual">'+visual+'</div><span class="nodeNo">'+esc(p.number)+'</span><small>'+esc(p.name)+'</small>';q('nodes').appendChild(d)})}
function directorAttrs(p){
 return ' data-in="'+(Number(p.directorIn)||0)+'" data-out="'+(Number(p.directorOut)||0)+'" data-speed="'+(Number(p.directorSpeed)||1)+'" data-freeze="'+(p.directorFreeze?'1':'0')+'" data-freezems="'+(Number(p.directorFreezeMs)||1000)+'" data-camera="'+esc(p.directorCamera||'MEDIUM')+'"';
}
function card(p,n){
 const media=p.mediaUrl||'',action=' action-'+esc(p.mediaAction||'STANDARD'),hasMedia=media?' hasMedia':'',directed=media?' directed':'';
 const fallback=p.photo?'<img src="'+p.photo+'">':'<div class="fallback">'+esc(p.number)+'</div>';
 const visual=media?'<div class="mediaFallback">'+fallback+'</div><video class="mediaVideo" src="'+esc(media)+'" muted playsinline preload="auto"'+directorAttrs(p)+'></video>':fallback;
 const dirTag=media?'<div class="directorBadge">入点 '+(Number(p.directorIn)||0).toFixed(1)+' · '+(Number(p.directorSpeed)||1).toFixed(2)+'×'+(p.directorFreeze?' · 定格':'')+'</div>':'';
 return '<div class="card'+(n===1?' one':'')+hasMedia+action+directed+'"><div class="playerBigNo">'+esc(p.number)+'</div><div class="cut">'+visual+'</div><div class="label"><div class="no">#'+esc(p.number)+(p.captain?'<span class="captainBadge">C</span>':'')+'</div><div class="name">'+esc(p.name)+'</div><div class="role">'+esc(p.position||p.role)+'</div>'+(p.statValue?'<div class="statPill">'+esc(p.statLabel)+' <strong>'+esc(p.statValue)+'</strong></div>':'')+(media?'<div class="mediaTag">球员定妆</div>':'')+dirTag+'</div></div>'
}
function flashFreeze(){
 const f=q('freezeFlash');if(!f||!f.animate)return;
 f.animate([{opacity:0},{opacity:.22,offset:.35},{opacity:0}],{duration:180,fill:'none'});
}
function configureDirectorVideo(v){
 const inPt=Math.max(0,parseFloat(v.dataset.in)||0),outPt=Math.max(0,parseFloat(v.dataset.out)||0),speed=Math.max(.25,parseFloat(v.dataset.speed)||1),freeze=v.dataset.freeze==='1',freezeMs=Math.max(0,parseInt(v.dataset.freezems,10)||1000);
 v.playbackRate=speed;
 v.addEventListener('error',()=>{v.style.display='none'},{once:true});
 const start=()=>{try{const max=Math.max(0,(v.duration||0)-.03),target=Math.min(inPt,max);if(Math.abs(v.currentTime-target)>.08)v.currentTime=target;const p=v.play();if(p&&p.catch)p.catch(()=>{})}catch(e){}};
 if(v.readyState>=1)start();else v.addEventListener('loadedmetadata',start,{once:true});
 const onTime=()=>{const end=outPt>inPt?outPt:(Number.isFinite(v.duration)?v.duration:0);if(end>0&&v.currentTime>=Math.max(inPt,end-.035)){v.removeEventListener('timeupdate',onTime);try{v.pause();v.currentTime=Math.max(inPt,Math.min(end,v.duration||end)-.03)}catch(e){}if(freeze){flashFreeze();v.dataset.frozen='1';setTimeout(()=>{v.dataset.freezeDone='1'},freezeMs)}}};
 v.addEventListener('timeupdate',onTime);
}
function playMediaVideos(){q('stage').querySelectorAll('video.mediaVideo').forEach(configureDirectorVideo)}
function applyBg(x){
 q('stadiumPhoto').src=x.stadium||'';q('crest').src=x.crest||'';q('crest').style.visibility=x.crest?'visible':'hidden';
 const mode=x.background||'tunnel',st=q('stage');st.classList.remove('scene-tunnel','scene-stadium','scene-transparent','scene-chroma');st.classList.add('scene-'+mode);
 if(mode==='transparent'){st.style.background='transparent';q('stadium').style.display='none';q('stadiumPhoto').style.display='none';q('shade').style.display='none';q('pitchLines').style.display='none'}
 else if(mode==='chroma'){st.style.background='#00b140';q('stadium').style.display='none';q('stadiumPhoto').style.display='none';q('shade').style.display='none';q('pitchLines').style.display='none'}
 else if(mode==='stadium'){st.style.background='#07090c';q('stadium').style.display='block';q('stadiumPhoto').style.display=x.stadium?'block':'none';q('shade').style.display='block';q('pitchLines').style.display='block'}
 else st.style.background='#05070a'
}
function updateTunnelLabels(x){
 const lineup=startingLabel(x),role={STING:'赛事标识',MATCH:'比赛信息',COUNTDOWN:'开赛倒计时',TEAM:lineup,GK:'门将',DF:'后卫',MF:'中场',FW:'前锋',FULL:'阵型',SUB:'替补球员'}[x.group]||lineup;
 q('ledLeft').innerHTML=esc(x.team||'球队')+'<small>'+role+'</small>';
 q('ledRight').innerHTML=(x.group==='TEAM'?'SAGI':(ROLE_NAMES[x.group]||x.group))+'<small>'+esc(x.formation||'')+'</small>';
}
function applyVisualGroup(group,x){
 const st=q('stage'),area=q('players'),code=q('roleBackdrop');
 st.classList.remove('group-GK','group-DF','group-MF','group-FW','group-TEAM','group-FULL','group-SUB','group-STING','group-MATCH','group-COUNTDOWN','tunnel-open');
 st.classList.add('group-'+group);if(group==='FULL')st.classList.add('tunnel-open');
 area.className='players layout-'+group;
 const codes={STING:'SAGI',MATCH:'赛',COUNTDOWN:'5',TEAM:starterCode(x),GK:'门',DF:'卫',MF:'中',FW:'锋',FULL:starterCode(x),SUB:'替'};
 code.textContent=codes[group]||starterCode(x);
 const packageGroup=['STING','MATCH','COUNTDOWN'].includes(group);q('roleGlow').style.display=(group==='FULL'||group==='SUB'||packageGroup)?'none':'block';code.style.display=(group==='FULL'||group==='SUB'||packageGroup)?'none':'flex';
}
function applyShowTransition(type){
 const l=q('transitionLayer');if(!l||!l.animate)return;l.className='transitionLayer';l.style.opacity='0';
 if(type==='CUT'||!type)return;
 if(type==='FLASH'){l.classList.add('white');l.animate([{opacity:0},{opacity:.82,offset:.28},{opacity:0}],{duration:380,easing:'ease-out'});return}
 if(type==='SLIDE'){l.classList.add('gold');l.animate([{opacity:.78,transform:'translateX(-105%)'},{opacity:.78,transform:'translateX(0)',offset:.48},{opacity:0,transform:'translateX(105%)'}],{duration:650,easing:'cubic-bezier(.2,.8,.2,1)'});return}
 if(type==='ZOOM'){q('stage').animate([{filter:'brightness(.55)',transform:'scale(1.035)'},{filter:'brightness(1)',transform:'scale(1)'}],{duration:620,easing:'ease-out'});return}
 l.classList.add('dark');l.animate([{opacity:.85},{opacity:0}],{duration:520,easing:'ease-out'})
}
function showCueDisplay(show){
 const badge=q('cueBadgeStage'),label=q('showStepStage');
 if(label)label.textContent=show&&show.label?('节目 · '+show.label):'';
 if(!badge||!show||!show.cue||show.cue==='NONE')return;
 badge.textContent=show.cue;if(badge.animate)badge.animate([{opacity:0,transform:'translateY(-8px)'},{opacity:1,transform:'translateY(0)',offset:.25},{opacity:0}],{duration:900,easing:'ease-out'})
}
function packageInfo(x){return x&&x.package||{}}
function syncPackageStage(x){
 const p=packageInfo(x);q('stingLogo').src=p.eventLogo||x.crest||'';q('stingLogo').style.visibility=(p.eventLogo||x.crest)?'visible':'hidden';q('stingCompetition').textContent=p.competition||'比赛';q('matchCompetitionStage').textContent=p.competition||'比赛';q('matchRoundStage').textContent=p.round||'';q('matchHomeStage').textContent=p.home||x.team||'主队';q('matchAwayStage').textContent=p.away||'客队';q('matchKickoffStage').textContent=p.kickoff||'';q('matchVenueStage').textContent=p.venue||'';q('countdownSub').textContent=p.competition||'比赛';
 const eventLogo=q('matchEventLogoStage'),homeCrest=q('matchHomeCrestStage'),awayCrest=q('matchAwayCrestStage');eventLogo.src=p.eventLogo||'';eventLogo.style.visibility=p.eventLogo?'visible':'hidden';homeCrest.src=p.homeCrest||'';homeCrest.style.visibility=p.homeCrest?'visible':'hidden';awayCrest.src=p.awayCrest||'';awayCrest.style.visibility=p.awayCrest?'visible':'hidden';q('matchOverlay').style.setProperty('--homeAccent',p.homeColor||'#d8b55b');q('matchOverlay').style.setProperty('--awayAccent',p.awayColor||'#4c7dff')
}
function startCountdown(duration){
 const el=q('countdownNumber'),seconds=Math.max(1,Math.round((Number(duration)||5000)/1000));let n=seconds;el.textContent=n;clearInterval(startCountdown.t);const pulse=()=>{if(el.animate)el.animate([{opacity:.2,transform:'scale(1.3)'},{opacity:1,transform:'scale(1)'}],{duration:420,easing:'ease-out'})};pulse();startCountdown.t=setInterval(()=>{n--;if(n<=0){clearInterval(startCountdown.t);el.textContent='GO';pulse();if(current&&audioSettings(current).countdownBeat)builtInCue(current,'HIT',.8);return}el.textContent=n;pulse();if(current&&audioSettings(current).countdownBeat)builtInCue(current,'HIT',.55)},1000)
}
function audioSettings(x){const p=packageInfo(x),a=p.audioEngine||{};return{mode:a.mode||'HYBRID',theme:a.theme||'SAGI_PULSE',intensity:Math.max(.1,Math.min(1,Number(a.intensity)||.75)),ducking:Math.max(0,Math.min(.8,Number(a.ducking)==null?.35:Number(a.ducking))),cueVolume:Math.max(.1,Math.min(1,Number(a.cueVolume)||1)),countdownBeat:a.countdownBeat!==false}}
function playRemoteAudio(url,volume=1,loop=false){if(!url)return null;try{const a=new Audio(url);a.volume=Math.max(0,Math.min(1,volume));a.loop=loop;const p=a.play();if(p&&p.catch)p.catch(()=>{});return a}catch(e){return null}}
function getAudioCtx(){const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return null;const ctx=getAudioCtx.ctx||(getAudioCtx.ctx=new AC());if(ctx.state==='suspended')ctx.resume().catch(()=>{});return ctx}
function noiseBuffer(ctx,duration=.5){const len=Math.max(1,Math.floor(ctx.sampleRate*duration)),b=ctx.createBuffer(1,len,ctx.sampleRate),d=b.getChannelData(0);for(let i=0;i<len;i++)d[i]=Math.random()*2-1;return b}
function synthTone(ctx,type,f1,f2,dur,gain=.1,when=0){const o=ctx.createOscillator(),g=ctx.createGain(),t=ctx.currentTime+when;o.type=type;o.frequency.setValueAtTime(f1,t);if(f2>0)o.frequency.exponentialRampToValueAtTime(Math.max(1,f2),t+dur);g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(Math.max(.0002,gain),t+.012);g.gain.exponentialRampToValueAtTime(.0001,t+dur);o.connect(g);g.connect(ctx.destination);o.start(t);o.stop(t+dur+.03)}
function synthNoise(ctx,dur=.45,gain=.08,filterStart=1200,filterEnd=180,when=0){const s=ctx.createBufferSource(),f=ctx.createBiquadFilter(),g=ctx.createGain(),t=ctx.currentTime+when;s.buffer=noiseBuffer(ctx,dur);f.type='bandpass';f.frequency.setValueAtTime(filterStart,t);f.frequency.exponentialRampToValueAtTime(Math.max(40,filterEnd),t+dur);f.Q.value=.8;g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(Math.max(.0002,gain),t+.02);g.gain.exponentialRampToValueAtTime(.0001,t+dur);s.connect(f);f.connect(g);g.connect(ctx.destination);s.start(t);s.stop(t+dur+.03)}
function duckRemoteMusic(x){const s=audioSettings(x),a=manageShowMusic.audio;if(!a||!s.ducking)return;const base=(packageInfo(x).musicVolume==null?.65:packageInfo(x).musicVolume),low=Math.max(.05,base*(1-s.ducking));try{a.volume=low;clearTimeout(duckRemoteMusic.t);duckRemoteMusic.t=setTimeout(()=>{try{a.volume=base}catch(e){}},620);q('stage').dataset.duck='active';setTimeout(()=>q('stage').dataset.duck='idle',650)}catch(e){}}
function builtInCue(x,cue,level=1){
 const ctx=getAudioCtx();if(!ctx)return false;const s=audioSettings(x),k=Math.max(.2,Math.min(1,level*s.intensity*s.cueVolume));duckRemoteMusic(x);q('stage').dataset.cueSynth='active';
 if(cue==='HIT'){synthTone(ctx,'sine',105,38,.34,.22*k);synthNoise(ctx,.24,.08*k,900,120)}
 else if(cue==='WHOOSH'){synthNoise(ctx,.62,.11*k,180,2600);synthTone(ctx,'triangle',170,460,.48,.045*k)}
 else if(cue==='RISER'){synthTone(ctx,'sawtooth',90,920,.88,.055*k);synthNoise(ctx,.82,.055*k,220,2600)}
 else if(cue==='CROWD'){synthNoise(ctx,1.15,.07*k,260,750);synthTone(ctx,'triangle',115,155,.7,.025*k)}
 else if(cue==='STING'){synthTone(ctx,'sine',82,42,.46,.24*k);synthTone(ctx,'sawtooth',220,520,.55,.045*k,.04);synthNoise(ctx,.36,.09*k,1800,220,.02)}
 setTimeout(()=>q('stage').dataset.cueSynth='idle',950);return true
}
function builtInThemeStop(){const s=builtInThemeStart.state;if(s){clearInterval(s.timer);builtInThemeStart.state=null}}
function builtInThemeStart(x){
 const s=audioSettings(x);if(s.mode==='MUTE'||s.mode==='EXTERNAL')return false;const ctx=getAudioCtx();if(!ctx)return false;builtInThemeStop();const state={ctx,timer:null,step:0};builtInThemeStart.state=state;
 const theme=s.theme||'SAGI_PULSE',int=s.intensity||.75,bpm=theme==='NORTH_WIND'?96:theme==='BLACK_GOLD'?118:108,beat=60/bpm;
 const tick=()=>{if(builtInThemeStart.state!==state)return;const st=state.step++,root=theme==='NORTH_WIND'?73.42:theme==='BLACK_GOLD'?55:65.41,accent=st%4===0;
  synthTone(ctx,'sine',accent?root:root*1.5,accent?root*.72:root*1.2,Math.min(.38,beat*.7),(accent?.075:.035)*int);
  if(st%2===0)synthNoise(ctx,.08,.015*int,theme==='NORTH_WIND'?1600:2600,900);
  if(theme==='NORTH_WIND'&&st%4===2)synthTone(ctx,'triangle',root*3,root*2.25,.2,.018*int);
  if(theme==='BLACK_GOLD'&&st%4===1)synthTone(ctx,'square',root*4,root*3,.09,.008*int);
 };tick();state.timer=setInterval(tick,beat*1000);q('stage').dataset.audioTheme=theme;q('stage').dataset.music='builtin';return true
}
function manageShowMusic(x){
 const p=packageInfo(x),show=x.show||{},url=p.musicUrl||'',s=audioSettings(x);q('stage').dataset.audioMode=s.mode;q('stage').dataset.audioTheme=s.theme;q('stage').dataset.music='off';
 if(s.mode==='MUTE'){try{if(manageShowMusic.audio)manageShowMusic.audio.pause()}catch(e){}builtInThemeStop();return}
 let a=manageShowMusic.audio,external=false;
 if((s.mode==='HYBRID'||s.mode==='EXTERNAL')&&url){if(show.isFirst||!a||a.src!==url){try{if(a)a.pause()}catch(e){}a=playRemoteAudio(url,p.musicVolume==null?.65:p.musicVolume,true);manageShowMusic.audio=a}if(a){a.volume=Math.max(0,Math.min(1,p.musicVolume==null?.65:p.musicVolume));external=true;q('stage').dataset.music='external'}}
 if(s.mode==='BUILTIN'||(s.mode==='HYBRID'&&!url))builtInThemeStart(x);else if(external)builtInThemeStop();
 clearTimeout(manageShowMusic.stopTimer);if(show.isLast)manageShowMusic.stopTimer=setTimeout(()=>{try{if(a){a.pause();a.currentTime=0}}catch(e){}builtInThemeStop();q('stage').dataset.music='off'},Math.max(500,Number(x.duration)||1000)+300)
}
function playRealCue(x){
 const p=packageInfo(x),show=x.show||{},cue=show.cue,s=audioSettings(x);q('stage').dataset.cue=cue||'NONE';q('stage').dataset.cueSource='none';if(!cue||cue==='NONE'||s.mode==='MUTE')return;
 const url=p.sfx&&p.sfx[cue];if((s.mode==='HYBRID'||s.mode==='EXTERNAL')&&url){q('stage').dataset.cueSource='real';duckRemoteMusic(x);playRemoteAudio(url,s.cueVolume,false);return}
 if(s.mode!=='EXTERNAL'){q('stage').dataset.cueSource='builtin';builtInCue(x,cue,1)}
}
function animatePackage(x){
 if(x.group==='STING'){const core=q('stingOverlay').querySelector('.stingCore');if(core&&core.animate)core.animate([{opacity:0,transform:'scale(.72)'},{opacity:1,transform:'scale(1.04)',offset:.7},{opacity:1,transform:'scale(1)'}],{duration:900,fill:'forwards',easing:'cubic-bezier(.2,.8,.2,1)'})}
 else if(x.group==='MATCH'){const card=q('matchOverlay').querySelector('.matchCardStage');if(card&&card.animate)card.animate([{opacity:0,transform:'translateY(24px) scale(.985)'},{opacity:1,transform:'translateY(0) scale(1)'}],{duration:520,fill:'forwards',easing:'cubic-bezier(.16,.84,.28,1)'});q('matchOverlay').querySelectorAll('.matchTopLine,.matchTeamBlock,.matchCenterStage,.matchMetaStage').forEach((el,i)=>{if(el&&el.animate)el.animate([{opacity:0,transform:'translateY('+(i?18:-12)+'px)'},{opacity:1,transform:'translateY(0)'}],{duration:460,delay:90+i*90,fill:'forwards',easing:'ease-out'})})}
 else if(x.group==='COUNTDOWN')startCountdown(x.duration)
}
function render(x){
 if(x&&x.group==='CLEAR'){
  current=x;clearInterval(startCountdown.t);clearTimeout(hideTimer);clearTimeout(manageShowMusic.stopTimer);
  try{if(manageShowMusic.audio){manageShowMusic.audio.pause();manageShowMusic.audio.currentTime=0}}catch(e){}
  builtInThemeStop();['stingOverlay','matchOverlay','countdownOverlay'].forEach(id=>q(id).classList.remove('on'));
  q('players').innerHTML='';q('fullList').innerHTML='';q('subList').innerHTML='';q('nodes').innerHTML='';
  q('stage').style.opacity='0';q('stage').dataset.program='clear';return;
 }
 q('stage').style.opacity='1';q('stage').dataset.program='on';q('stage').style.setProperty('--teamAccent',x.teamColor||'#d8b55b');
 current=x;q('stage').dataset.side=x.side||'HOME';q('sideBadgeStage').textContent=(x.side==='AWAY'?'AWAY · 客队':'HOME · 主队');clearInterval(startCountdown.t);['stingOverlay','matchOverlay','countdownOverlay'].forEach(id=>q(id).classList.remove('on'));syncPackageStage(x);manageShowMusic(x);playRealCue(x);applyShowTransition(x.show&&x.show.transition);showCueDisplay(x.show||null);q('stage').dataset.showStep=x.show&&Number.isFinite(+x.show.stepIndex)?String(x.show.stepIndex):'';applyVisualGroup(x.group||'TEAM',x);updateTunnelLabels(x);q('stageLineupLabel').textContent=startingLabel(x);q('team').textContent=x.team||'TEAM';applyBg(x);const tacticalOn=['GK','DF','MF','FW','FULL'].includes(x.group);q('formationPanel').style.display=tacticalOn?'block':'none';q('fullList').style.display='none';q('subList').style.display='none';q('players').style.display='flex';
 if(x.group==='STING'){q('groupTitle').textContent='赛事包装';q('groupName').textContent='赛事标识';q('players').style.display='none';q('stingOverlay').classList.add('on')}
 else if(x.group==='MATCH'){q('groupTitle').textContent='赛事包装';q('groupName').textContent='比赛信息';q('players').style.display='none';q('matchOverlay').classList.add('on')}
 else if(x.group==='COUNTDOWN'){q('groupTitle').textContent='赛事包装';q('groupName').textContent='开赛倒计时';q('players').style.display='none';q('countdownOverlay').classList.add('on')}
 else if(x.group==='TEAM'){q('groupTitle').textContent='SAGI 赛事直播';q('groupName').textContent=(x.team||'TEAM')+' · '+(x.formation||'');q('players').innerHTML='<div style="align-self:center;text-align:center;color:#ffffff52;font-weight:1000;font-size:138px;letter-spacing:10px;text-shadow:0 18px 45px #000">'+esc(x.formation||'')+'</div>'}
 else if(x.group==='FULL'){q('groupTitle').textContent=startingLabel(x);q('groupName').textContent='完整首发阵容';q('players').style.display='none';q('fullList').style.display='grid';q('fullList').innerHTML=effectivePlayers(x).map((p,i)=>'<div class="fullRow" style="--row-i:'+i+'"><div class="fullRole">'+esc(p.role)+'</div><div class="fullNo">'+esc(p.number)+'</div><div class="fullName">'+esc(p.name)+(p.captain?' <span class="captainBadge">C</span>':'')+'</div><div class="fullPos">'+esc(p.position)+(p.statValue?' · '+esc(p.statLabel)+' '+esc(p.statValue):'')+'</div></div>').join('')} else if(x.group==='SUB'){q('groupTitle').textContent='球队名单';q('groupName').textContent='替补球员';q('players').style.display='none';q('subList').style.display='grid';const subs=x.substitutes||x.players||[];q('subList').innerHTML=subs.length?subs.map(p=>'<div class="subRow"><div class="subNo">#'+esc(p.number)+'</div><div><div class="subName">'+esc(p.name)+'</div><div class="subStat">'+esc(p.role)+' · '+esc(p.position)+'</div></div><div class="subStat">'+(p.statValue?esc(p.statLabel)+' '+esc(p.statValue):'替补')+'</div></div>').join(''):'<div class="subStat">暂无替补球员</div>'}
 else{q('groupTitle').textContent=startingLabel(x);q('groupName').textContent=ROLE_NAMES[x.group]||x.group;const gp=effectiveGroupPlayers(x);q('players').innerHTML=gp.map(p=>card(p,gp.length)).join('')}
 if(['GK','DF','MF','FW','FULL'].includes(x.group))renderNodes(x);else q('nodes').innerHTML='';animate(x);animatePackage(x);setTimeout(playMediaVideos,0)
}
function animate(x){
 const els=[...q('stage').querySelectorAll('.card,.fullRow,.subRow,.node.active')];
 els.forEach((el,i)=>{
  if(!el.animate)return;
  const isNode=el.classList.contains('node'),isPlayer=el.classList.contains('card');
  let frames;
  if(isNode)frames=[{opacity:0,transform:'translate(-50%,-50%) scale(.25)'},{opacity:1,transform:'translate(-50%,-50%) scale(1.18)',offset:.72},{opacity:1,transform:'translate(-50%,-50%) scale(1)'}];
  else if(isPlayer){const dir=i%2===0?-70:70;frames=[{opacity:0,transform:'translate('+dir+'px,24px) scale(.94)',filter:'blur(5px)'},{opacity:1,transform:'translate(0,0) scale(1)',filter:'blur(0)'}]}
  else frames=[{opacity:0,transform:'translateY(35px) scale(.97)'},{opacity:1,transform:'translateY(0) scale(1)'}];
  el.animate(frames,{duration:isNode?620:isPlayer?680:520,delay:i*(isNode?95:90),fill:'forwards',easing:'cubic-bezier(.18,.82,.18,1)'})
 });
 q('stage').querySelectorAll('video.mediaVideo').forEach((v,i)=>{if(!v.animate)return;const cam=v.dataset.camera||'MEDIUM',scale={NONE:1.02,LIGHT:1.06,MEDIUM:1.10,STRONG:1.16}[cam]||1.10;v.animate([{opacity:0,transform:'scale('+scale+') translateY(20px)'},{opacity:1,transform:'scale(1) translateY(0)'}],{duration:900,delay:100+i*90,fill:'forwards',easing:'cubic-bezier(.18,.82,.18,1)'})});
  const title=q('groupName');if(title.animate)title.animate([{opacity:0,transform:'translateX(-70px)',letterSpacing:'8px'},{opacity:1,transform:'translateX(0)',letterSpacing:'-2px'}],{duration:620,fill:'forwards',easing:'ease-out'});
 if((x.background||'tunnel')==='tunnel'){
  const tunnel=q('tunnelScene'),cams=[...q('stage').querySelectorAll('video.mediaVideo')].map(v=>v.dataset.camera||'MEDIUM'),rank={NONE:0,LIGHT:1,MEDIUM:2,STRONG:3},best=cams.sort((a,b)=>(rank[b]||0)-(rank[a]||0))[0]||'MEDIUM',scale={NONE:1.025,LIGHT:1.045,MEDIUM:1.07,STRONG:1.105}[best]||1.07,y={NONE:5,LIGHT:9,MEDIUM:15,STRONG:23}[best]||15;
  if(tunnel&&tunnel.animate)tunnel.animate([{transform:'scale('+scale+') translateY('+y+'px)',filter:'brightness(.7)'},{transform:'scale(1) translateY(0)',filter:'brightness(1)'}],{duration:1050,fill:'forwards',easing:'cubic-bezier(.15,.8,.2,1)'});
  [q('ledLeft'),q('ledRight')].forEach((el,i)=>{if(el&&el.animate)el.animate([{opacity:0,transform:'translateY(24px)',filter:'blur(7px)'},{opacity:1,transform:'translateY(0)',filter:'blur(0)'}],{duration:620,delay:110+i*90,fill:'forwards',easing:'ease-out'})});
 }
  const glow=q('roleGlow');if(glow&&glow.style.display!=='none'&&glow.animate)glow.animate([{opacity:0,transform:'scale(.72)'},{opacity:.26,transform:'scale(1.04)',offset:.7},{opacity:.22,transform:'scale(1)'}],{duration:900,fill:'forwards',easing:'ease-out'});
 const code=q('roleBackdrop');if(code&&code.style.display!=='none'&&code.animate)code.animate([{opacity:0,transform:'scale(.86)'},{opacity:1,transform:'scale(1)'}],{duration:780,fill:'forwards',easing:'ease-out'});
 clearTimeout(hideTimer);hideTimer=setTimeout(()=>{},Math.max(1000,+x.duration||4000))
}

function gfxPeriodName(p){return({'1H':'上半场','2H':'下半场','ET1':'加时上半场','ET2':'加时下半场','PEN':'点球'})[p]||p||''}
function gfxSeconds(g){const c=g&&g.clock||{};let s=Number(c.baseSeconds)||0;if(c.running&&c.startedAt){const t=Date.parse(c.startedAt);if(Number.isFinite(t))s+=(Date.now()-t)/1000}return Math.max(0,s)}
function gfxFormat(sec){sec=Math.max(0,Math.floor(Number(sec)||0));return String(Math.floor(sec/60)).padStart(2,'0')+':'+String(sec%60).padStart(2,'0')}
function validHex(v,f){return /^#[0-9a-f]{6}$/i.test(String(v||''))?v:f}
function redCardsHtml(n){return Array.from({length:Math.max(0,Math.min(5,Number(n)||0))},()=>'<i class="sbRedCard"></i>').join('')}
function setCrest(id,src){const el=q(id);if(src){if(el.src!==src)el.src=src;el.classList.add('on')}else{el.removeAttribute('src');el.classList.remove('on')}}
function motionRestart(el,cls,ms=650){
 if(!el)return;el.classList.remove(cls);void el.offsetWidth;el.classList.add(cls);setTimeout(()=>el.classList.remove(cls),ms)
}
function scoreMotion(el,wrap,oldValue,newValue){
 if(oldValue===null||Number(oldValue)===Number(newValue))return;
 wrap.dataset.oldScore=String(oldValue);
 motionRestart(wrap,'scoreRolling',520);motionRestart(el,'scoreRolling',520);
 motionRestart(q('scoreBug'),'scoreAccentPulse',420)
}
function graphicsGoalFlash(){
 const g=q('graphicsStage');if(!g)return;g.classList.remove('goalFlash');void g.offsetWidth;g.classList.add('goalFlash');setTimeout(()=>g.classList.remove('goalFlash'),520)
}
let replayStingerTimer=null;
function cleanupEventVisuals(){
 clearTimeout(eventCleanupTimer);eventCleanupTimer=null;
 clearTimeout(replayStingerTimer);const rs=q('replayStinger');if(rs)rs.className='replayStinger';
 clearTimeout(scorebugGoalTimer);scorebugGoalActive=false;const scorebug=q('scoreBug');if(scorebug)scorebug.classList.remove('goalExpand');
 q('graphicsStage').classList.remove('eventActive');const card=q('eventCard'),splash=q('stateSplash');
 card.className='eventCard';card.style.borderLeftColor='';q('eventIcon').style.background='';q('eventIcon').removeAttribute('data-card-type');q('eventIcon').removeAttribute('aria-label');
 q('eventPhotoWrap').className='eventPhotoWrap';q('eventPhoto').removeAttribute('src');q('eventIcon').className='eventIcon';q('eventCopy').className='eventCopy';q('subRows').className='subRows';
 splash.className='stateSplash';q('stateBox').className='stateBox';q('mvpPhoto').className='mvpPhoto';q('stateCopy').className='stateCopy';q('mvpPhoto').removeAttribute('src')
}
function hideEvent(animated=false){
 clearTimeout(eventTimer);eventTimer=null;
 clearTimeout(eventCleanupTimer);eventCleanupTimer=null;
 const card=q('eventCard'),splash=q('stateSplash'),hasCard=card.classList.contains('on'),hasSplash=splash.classList.contains('on');
 if(animated&&(hasCard||hasSplash)){
  if(hasCard)card.classList.add('motionOut');
  if(hasSplash)splash.classList.add('motionOut');
  eventCleanupTimer=setTimeout(()=>{eventCleanupTimer=null;cleanupEventVisuals()},340);return
 }
 cleanupEventVisuals()
}
function scheduleEventHide(ms){clearTimeout(eventTimer);eventTimer=setTimeout(()=>hideEvent(true),Math.max(800,Number(ms)||5000))}
function motionInEvent(type){
 const card=q('eventCard'),photo=q('eventPhotoWrap'),icon=q('eventIcon'),copy=q('eventCopy'),rows=q('subRows');
 card.classList.add('motionIn');if(photo.classList.contains('on'))photo.classList.add('motionIn');icon.classList.add('motionIn');copy.classList.add('motionIn');
 if(type==='SUB')rows.classList.add('motionIn');if(type==='GOAL')graphicsGoalFlash()
}
function motionInSplash(type){
 q('stateBox').classList.add('motionIn');
 if(type==='MVP'){q('mvpPhoto').classList.add('motionIn');q('stateCopy').classList.add('motionIn')}
}
function gfxPenaltyDots(ps,side){
 const h=Array.isArray(ps&&ps.history)?ps.history.filter(x=>x.side===side):[],rounds=[3,5].includes(Number(ps&&ps.rounds))?Number(ps.rounds):5,attempts=side==='HOME'?Number(ps&&ps.homeAttempts)||h.length:Number(ps&&ps.awayAttempts)||h.length,next=ps&&ps.nextSide,total=Math.max(rounds,h.length+(ps&&ps.finished?0:1));
 return Array.from({length:Math.min(12,total)},(_,i)=>{const x=h[i],cls=x?(x.result==='GOAL'?'goal':'miss'):'pending'+((next===side&&i===attempts)?' current':'');return'<i class="sbPenDot '+cls+'"></i>'}).join('')
}
function gfxPenaltyStatus(ps,g){
 if(!ps||!ps.started)return{stage:'点球大战',next:'等待主罚'};
 if(ps.finished){const name=ps.winner==='HOME'?(g.home||g.homeShort||'主队'):(g.away||g.awayShort||'客队');return{stage:'点球大战结束',next:name+' 获胜'}}
 const stage=ps.suddenDeath?'突然死亡':'第 '+(Number(ps.currentRound)||1)+' 轮',name=ps.nextSide==='HOME'?(g.home||g.homeShort||'主队'):(g.away||g.awayShort||'客队');return{stage,next:'当前主罚 · '+name}
}
let lastSimplePenaltyHome=0,lastSimplePenaltyAway=0,lastSimplePenaltyHomeAttempts=0,lastSimplePenaltyAwayAttempts=0;
function gfxSimplePenaltyDots(ps,side,previousAttempts){
 const history=Array.isArray(ps&&ps.history)?ps.history.map(x=>typeof x==='string'?{side:x,result:'GOAL'}:x).filter(Boolean):[],attempts=history.filter(x=>x.side===side),round=Number(ps&&ps.round)||Math.max(history.filter(x=>x.side==='HOME').length,history.filter(x=>x.side==='AWAY').length),visible=round<=5?attempts.slice(0,5):attempts.slice(-5),startIndex=Math.max(0,attempts.length-visible.length),items=[];
 visible.forEach((x,i)=>{const absoluteIndex=startIndex+i,isNew=absoluteIndex===attempts.length-1&&attempts.length>Number(previousAttempts||0),cls=x.result==='MISS'?' miss':' on';items.push('<i class="spbDot'+cls+(isNew?' new':'')+'"></i>')});
 while(items.length<5)items.push('<i class="spbDot"></i>');return items.join('')
}
function simplePenaltyScorePulse(el,previous,current){
 if(!el||Number(current)===Number(previous))return;el.classList.remove('pulse');void el.offsetWidth;el.classList.add('pulse')
}
function fitBroadcastTeamName(el,text,mode='regular'){
 if(!el)return;
 const t=String(text||'').trim()||'球队';el.textContent=t;
 el.style.setProperty('white-space','nowrap','important');
 el.style.setProperty('overflow','visible','important');
 el.style.setProperty('text-overflow','clip','important');
 el.style.setProperty('max-width','none','important');
 if(mode==='penalty'){
  let size=30;const limit=315;
  el.style.setProperty('font-size',size+'px','important');
  while(el.scrollWidth>limit&&size>17){size--;el.style.setProperty('font-size',size+'px','important')}
  return
 }
 let size=18;const block=el.closest('.sbTeamBlock');
 el.style.setProperty('font-size',size+'px','important');
 const crest=block&&block.querySelector('.sbCrest.on'),reds=block?block.querySelectorAll('.sbRedCard').length:0;
 const chrome=(crest?27:5)+(reds*8)+16,maxBlock=150,minBlock=92;
 while(el.scrollWidth>maxBlock-chrome&&size>11){size--;el.style.setProperty('font-size',size+'px','important')}
 const target=Math.max(minBlock,Math.min(maxBlock,Math.ceil(el.scrollWidth)+chrome));
 if(block){
  block.style.setProperty('width',target+'px','important');
  block.style.setProperty('min-width',target+'px','important');
  block.style.setProperty('max-width',target+'px','important');
  block.style.setProperty('flex-basis',target+'px','important')
 }
}
let scorebugGoalActive=false,scorebugGoalTimer=null;
function scorebugGoalExpand(e,g){
 const bug=q('scoreBug'),burst=q('sbGoalBurst'),scorer=q('sbGoalScorer');if(!bug||!burst)return;
 clearTimeout(scorebugGoalTimer);scorebugGoalActive=true;
 const accent=e&&e.side==='AWAY'?validHex(g&&g.awayColor,'#4c7dff'):validHex(g&&g.homeColor,'#d8b55b');
 bug.style.setProperty('--goalAccent',accent);
 const goalCrest=q('sbGoalCrest'),goalSide=e&&e.side==='AWAY'?'AWAY':'HOME',goalSrc=goalSide==='AWAY'?(g&&g.awayCrest):(g&&g.homeCrest);
 if(goalCrest){goalCrest.classList.remove('on');if(goalSrc){goalCrest.src=goalSrc;goalCrest.classList.add('on')}else{goalCrest.removeAttribute('src')}}

 const no=e&&e.player&&e.player.number?('#'+e.player.number+' · '):'',name=e&&e.player&&e.player.name||e&&e.team||'进球';
 if(scorer)scorer.textContent=no+name;
 bug.classList.remove('goalExpand');void bug.offsetWidth;bug.classList.add('goalExpand');
 scorebugGoalTimer=setTimeout(()=>{scorebugGoalActive=false;bug.classList.remove('goalExpand')},4200)
}
function gfxPenaltyActive(g){
 const period=String(g&&g.clock&&g.clock.period||''),ps=g&&g.penaltyShootout||{},raw=g&&g.simplePenalty||{};
 const ph=Array.isArray(ps.history)?ps.history:[],rh=Array.isArray(raw.history)?raw.history:[];
 return period==='PEN'&&(!!ps.started||!!raw.visible||ph.length>0||rh.length>0)
}
function updateSimplePenaltyBoard(g){
 const raw=g&&g.simplePenalty||{},ps=g&&g.penaltyShootout||{},period=String(g&&g.clock&&g.clock.period||''),penaltyMode=gfxPenaltyActive(g),board=q('simplePenaltyBoard');
 if(!board)return false;
 if(!penaltyMode){board.classList.remove('on','sudden');if(q('spbHomeWing'))q('spbHomeWing').classList.remove('current');if(q('spbAwayWing'))q('spbAwayWing').classList.remove('current');return false}
 const directorHist=Array.isArray(ps.history)?ps.history.map(x=>typeof x==='string'?{side:x,result:'GOAL'}:x).filter(Boolean):[];
 const directorHome=Number.isFinite(Number(ps.homeGoals))?Number(ps.homeGoals):directorHist.filter(x=>x.side==='HOME'&&x.result!=='MISS').length;
 const directorAway=Number.isFinite(Number(ps.awayGoals))?Number(ps.awayGoals):directorHist.filter(x=>x.side==='AWAY'&&x.result!=='MISS').length;
 const directorRound=Number(ps.currentRound)||Math.max(directorHist.filter(x=>x.side==='HOME').length,directorHist.filter(x=>x.side==='AWAY').length);
 const p=raw.visible?raw:(ps.started?{visible:true,home:directorHome,away:directorAway,history:directorHist,round:directorRound,slots:Math.max(5,directorRound)}:raw),on=!!p.visible;
 board.classList.toggle('on',on);if(!on)return false;
 const home=validHex(g.homeColor,'#d8b55b'),away=validHex(g.awayColor,'#4c7dff');board.style.setProperty('--home',home);board.style.setProperty('--away',away);
 const h=Number(p.home)||0,a=Number(p.away)||0,hEl=q('spbHomeScore'),aEl=q('spbAwayScore'),round=Number(p.round)||Math.max((p.history||[]).filter(x=>(typeof x==='string'?x:x&&x.side)==='HOME').length,(p.history||[]).filter(x=>(typeof x==='string'?x:x&&x.side)==='AWAY').length);q('spbCompetition').textContent=g.competition||'SAGI 赛事直播';q('spbPhase').textContent=round>5?('突然死亡 · '+round):('第'+Math.max(1,round)+'轮');fitBroadcastTeamName(q('spbHomeName'),g.home||g.homeShort||'主队','penalty');fitBroadcastTeamName(q('spbAwayName'),g.away||g.awayShort||'客队','penalty');hEl.textContent=h;aEl.textContent=a;
 const hist=Array.isArray(p.history)?p.history.map(x=>typeof x==='string'?{side:x,result:'GOAL'}:x).filter(Boolean):[],hAttempts=hist.filter(x=>x.side==='HOME').length,aAttempts=hist.filter(x=>x.side==='AWAY').length;
 const directorNext=ps&&ps.started&&!ps.finished?(ps.nextSide==='AWAY'?'AWAY':'HOME'):null,nextSide=directorNext||(hAttempts<=aAttempts?'HOME':'AWAY'),nextName=nextSide==='HOME'?(g.home||g.homeShort||'主队'):(g.away||g.awayShort||'客队');
 board.classList.toggle('sudden',round>5);q('spbHomeWing').classList.toggle('current',nextSide==='HOME'&&!(ps&&ps.finished));q('spbAwayWing').classList.toggle('current',nextSide==='AWAY'&&!(ps&&ps.finished));
 q('spbLiveStatus').textContent=(ps&&ps.finished)?'已结束':(round>5?'突然死亡':'进行中');q('spbNext').textContent=(ps&&ps.finished)?((ps.winner==='HOME'?(g.home||g.homeShort||'主队'):(g.away||g.awayShort||'客队'))+' 获胜'):('当前主罚 · '+nextName);
 q('spbHomeDots').innerHTML=gfxSimplePenaltyDots(p,'HOME',lastSimplePenaltyHomeAttempts);q('spbAwayDots').innerHTML=gfxSimplePenaltyDots(p,'AWAY',lastSimplePenaltyAwayAttempts);simplePenaltyScorePulse(hEl,lastSimplePenaltyHome,h);simplePenaltyScorePulse(aEl,lastSimplePenaltyAway,a);lastSimplePenaltyHome=h;lastSimplePenaltyAway=a;lastSimplePenaltyHomeAttempts=hAttempts;lastSimplePenaltyAwayAttempts=aAttempts;setCrest('spbHomeCrest',g.homeCrest||'');setCrest('spbAwayCrest',g.awayCrest||'');return true
}
function updateScoreBug(){
 const live=currentGraphics;if(!live)return;
 const g=(live.scoreboardFrozen&&frozenGraphics)?frozenGraphics:live,bug=q('scoreBug');
 const home=validHex(g.homeColor,'#d8b55b'),away=validHex(g.awayColor,'#4c7dff'),accent=validHex(g.accentColor,'#f4f0e8');
 bug.style.setProperty('--home',home);bug.style.setProperty('--away',away);bug.style.setProperty('--accent',accent);
 const ps=g.penaltyShootout||{},simpleOn=updateSimplePenaltyBoard(live),penMode=gfxPenaltyActive(g),displayPeriod=penMode?'PEN':(String(g.clock&&g.clock.period||'')==='PEN'?'2H':String(g.clock&&g.clock.period||''));bug.className='scoreBug'+((live.scoreboardVisible&&!simpleOn)?' on':'')+(live.scoreboardFrozen?' frozen':'')+' theme-'+(g.scoreTheme||'sagi-pro')+' sagiToranhe'+(penMode?' penaltyMode':'')+(scorebugGoalActive?' goalExpand':'');
 fitBroadcastTeamName(q('sbHome'),g.scoreHomeName||g.home||g.homeShort||'主队','regular');fitBroadcastTeamName(q('sbAway'),g.scoreAwayName||g.away||g.awayShort||'客队','regular');
 const hs=Number(g.homeScore)||0,as=Number(g.awayScore)||0,hEl=q('sbHomeScore'),aEl=q('sbAwayScore');hEl.textContent=hs;aEl.textContent=as;scoreMotion(hEl,q('sbHomeScoreWrap'),lastHomeScore,hs);scoreMotion(aEl,q('sbAwayScoreWrap'),lastAwayScore,as);lastHomeScore=hs;lastAwayScore=as;lastScoreboardVisible=!!live.scoreboardVisible;
 if(penMode){const pst=gfxPenaltyStatus(ps,g);q('sbClock').textContent='点球大战';q('sbPeriod').textContent=pst.stage;q('sbPenStage').textContent=pst.stage;q('sbPenNext').textContent=pst.next;q('sbPenHomeDots').innerHTML=gfxPenaltyDots(ps,'HOME');q('sbPenAwayDots').innerHTML=gfxPenaltyDots(ps,'AWAY')}else{q('sbClock').textContent=gfxFormat(gfxSeconds(g));q('sbPeriod').textContent=gfxPeriodName(displayPeriod);q('sbPenHomeDots').innerHTML='';q('sbPenAwayDots').innerHTML=''}
 const specialPhase=penMode||['ET1','ET2'].includes(displayPeriod);q('sbPeriod').classList.toggle('special',specialPhase);
 q('sbCompetition').textContent=g.competition||'SAGI LIVE';
 const rawStoppage=String(g.stoppageTime||'').trim(),stoppage=rawStoppage?(rawStoppage.startsWith('+')?rawStoppage:'+'+rawStoppage):'';q('sbStoppage').textContent=stoppage;q('sbStoppage').classList.toggle('on',!!stoppage);
 q('sbHomeReds').innerHTML=redCardsHtml(g.homeRedCards);q('sbAwayReds').innerHTML=redCardsHtml(g.awayRedCards);
 q('sbHomeReds').setAttribute('aria-label',(Number(g.homeRedCards)||0)+' 张红牌');q('sbAwayReds').setAttribute('aria-label',(Number(g.awayRedCards)||0)+' 张红牌');
 bug.setAttribute('aria-label',(g.home||g.homeShort||'主队')+' '+hs+' 比 '+as+' '+(g.away||g.awayShort||'客队')+' · '+gfxFormat(gfxSeconds(g))+' · '+gfxPeriodName(displayPeriod)+(stoppage?' · 补时 '+stoppage:''));
 const penOn=penMode;
 q('sbHomePen').textContent='点球 '+(Number(g.homePen)||0);q('sbAwayPen').textContent='点球 '+(Number(g.awayPen)||0);q('sbHomePen').classList.toggle('on',penOn);q('sbAwayPen').classList.toggle('on',penOn);
 setCrest('sbHomeCrest',g.homeCrest||'');setCrest('sbAwayCrest',g.awayCrest||'');
 const eventLogo=q('sbEventLogo'),eventFallback=q('sbEventFallback'),eventSrc=g.eventLogo||g.logo||'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20256%20239%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%2348cf35%22%2F%3E%3Cstop%20offset%3D%22.45%22%20stop-color%3D%22%230a8b4a%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23005432%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Cpath%20d%3D%22M%20133%20184%20L%20133%20213%20L%20134%20214%20L%20134%20222%20L%20135%20223%20L%20136%20231%20L%20137%20232%20L%20144%20232%20L%20164%20226%20L%20165%20224%20L%20162%20219%20L%20142%20199%20Z%20M%20129%20184%20L%20120%20199%20L%20113%20207%20L%20101%20218%20L%2097%20225%20L%20103%20228%20L%20109%20229%20L%20113%20231%20L%20126%20232%20L%20126%20228%20L%20128%20222%20L%20128%20216%20L%20129%20215%20Z%20M%2028%2083%20L%2029%2096%20L%2034%20108%20L%2041%20118%20L%2050%20126%20L%2061%20132%20L%2070%20133%20L%2071%20134%20L%20102%20134%20L%20103%20133%20L%20101%20127%20L%2092%20119%20L%2083%20116%20L%2071%20115%20L%2063%20111%20L%2052%2099%20L%2052%2097%20L%2049%2091%20L%2048%2083%20Z%20M%20234%2082%20L%20214%2082%20L%20214%2087%20L%20211%2097%20L%20203%20108%20L%20196%20113%20L%20194%20113%20L%20191%20115%20L%20178%20116%20L%20168%20120%20L%20161%20127%20L%20159%20133%20L%20196%20133%20L%20203%20131%20L%20212%20126%20L%20222%20117%20L%20227%20110%20L%20233%2096%20L%20233%2093%20L%20234%2092%20Z%20M%20227%2053%20L%20200%2053%20L%20198%2054%20L%20139%20112%20L%20134%20121%20L%20134%20173%20L%20137%20182%20L%20147%20195%20L%20153%20200%20L%20169%20210%20L%20175%20216%20L%20177%20220%20L%20181%20219%20L%20194%20209%20L%20194%20207%20L%20191%20203%20L%20184%20197%20L%20176%20193%20L%20173%20193%20L%20164%20190%20L%20157%20186%20L%20158%20185%20L%20161%20186%20L%20175%20186%20L%20185%20189%20L%20193%20194%20L%20201%20201%20L%20205%20199%20L%20215%20189%20L%20214%20187%20L%20203%20179%20L%20191%20174%20L%20179%20173%20L%20178%20172%20L%20159%20172%20L%20157%20171%20L%20153%20166%20L%20153%20161%20L%20154%20159%20L%20158%20156%20L%20206%20156%20L%20207%20155%20L%20212%20155%20L%20219%20153%20L%20228%20148%20L%20233%20144%20L%20239%20137%20L%20246%20124%20L%20248%20118%20L%20248%20114%20L%20239%20116%20L%20226%20121%20L%20223%20126%20L%20217%20132%20L%20208%20137%20L%20201%20138%20L%20200%20139%20L%20159%20139%20L%20153%20142%20L%20152%20141%20L%20153%20131%20L%20155%20127%20L%20211%2072%20Z%20M%20156%20185%20L%20157%20184%20L%20158%20185%20L%20157%20186%20Z%20M%2035%2053%20L%2038%2058%20L%2048%2069%20L%20107%20127%20L%20109%20131%20L%20109%20134%20L%20110%20135%20L%20110%20140%20L%20109%20141%20L%20104%20139%20L%2062%20139%20L%2061%20138%20L%2054%20137%20L%2045%20132%20L%2039%20126%20L%2036%20121%20L%2014%20114%20L%2014%20117%20L%2017%20126%20L%2023%20137%20L%2032%20147%20L%2042%20153%20L%2048%20155%20L%2053%20155%20L%2054%20156%20L%20104%20156%20L%20109%20160%20L%20110%20163%20L%20109%20167%20L%20103%20172%20L%2087%20172%20L%2086%20173%20L%2076%20173%20L%2075%20174%20L%2072%20174%20L%2056%20181%20L%2048%20188%20L%2048%20189%20L%2061%20201%20L%2068%20195%20L%2080%20188%20L%2087%20187%20L%2088%20186%20L%20102%20186%20L%20103%20187%20L%2098%20190%20L%2080%20196%20L%2068%20207%20L%2069%20210%20L%2085%20221%20L%2086%20218%20L%2091%20212%20L%20113%20197%20L%20120%20190%20L%20126%20180%20L%20128%20174%20L%20128%20167%20L%20129%20166%20L%20129%20125%20L%20128%20124%20L%20128%20121%20L%20126%20116%20L%2064%2054%20L%2061%2053%20Z%20M%20102%20186%20L%20103%20185%20L%20105%20186%20L%20104%20187%20Z%20M%2093%2024%20L%2075%2035%20L%2075%2045%20L%2076%2046%20L%2076%2050%20L%2078%2056%20L%2084%2066%20L%20129%20110%20L%20129%2093%20L%20128%2092%20L%20127%2084%20L%20124%2079%20L%2098%2052%20L%2095%2046%20L%2095%2042%20L%2094%2041%20L%2094%2024%20Z%20M%20169%2023%20L%20168%2023%20L%20168%2043%20L%20165%2051%20L%20159%2059%20L%20138%2079%20L%20135%2084%20L%20134%2092%20L%20133%2093%20L%20133%20110%20L%20178%2066%20L%20185%2054%20L%20186%2047%20L%20187%2046%20L%20187%2034%20Z%20M%20134%205%20L%20133%206%20L%20133%2074%20L%20142%2067%20L%20150%2059%20L%20150%2016%20L%20147%2013%20Z%20M%20128%205%20L%20118%2012%20L%20115%2013%20L%20112%2017%20L%20112%2059%20L%20129%2074%20L%20129%205%20Z%22%20fill%3D%22url(%23g)%22%20fill-rule%3D%22evenodd%22%2F%3E%3C%2Fsvg%3E';
 if(eventLogo){if(eventSrc){eventLogo.src=eventSrc;eventLogo.style.display='block';eventFallback.style.display='none'}else{eventLogo.removeAttribute('src');eventLogo.style.display='none';eventFallback.style.display='block'}}

}
function showReplayStinger(g,e){
 const st=q('replayStinger'),logo=q('rsLogo'),fallback=q('rsLogoFallback');if(!st)return;
 clearTimeout(replayStingerTimer);const phase=e&&e.phase==='OUT'?'out':'in';
 const src=(g&&g.eventLogo)||(g&&g.logo)||'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20256%20239%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%2348cf35%22%2F%3E%3Cstop%20offset%3D%22.45%22%20stop-color%3D%22%230a8b4a%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23005432%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Cpath%20d%3D%22M%20133%20184%20L%20133%20213%20L%20134%20214%20L%20134%20222%20L%20135%20223%20L%20136%20231%20L%20137%20232%20L%20144%20232%20L%20164%20226%20L%20165%20224%20L%20162%20219%20L%20142%20199%20Z%20M%20129%20184%20L%20120%20199%20L%20113%20207%20L%20101%20218%20L%2097%20225%20L%20103%20228%20L%20109%20229%20L%20113%20231%20L%20126%20232%20L%20126%20228%20L%20128%20222%20L%20128%20216%20L%20129%20215%20Z%20M%2028%2083%20L%2029%2096%20L%2034%20108%20L%2041%20118%20L%2050%20126%20L%2061%20132%20L%2070%20133%20L%2071%20134%20L%20102%20134%20L%20103%20133%20L%20101%20127%20L%2092%20119%20L%2083%20116%20L%2071%20115%20L%2063%20111%20L%2052%2099%20L%2052%2097%20L%2049%2091%20L%2048%2083%20Z%20M%20234%2082%20L%20214%2082%20L%20214%2087%20L%20211%2097%20L%20203%20108%20L%20196%20113%20L%20194%20113%20L%20191%20115%20L%20178%20116%20L%20168%20120%20L%20161%20127%20L%20159%20133%20L%20196%20133%20L%20203%20131%20L%20212%20126%20L%20222%20117%20L%20227%20110%20L%20233%2096%20L%20233%2093%20L%20234%2092%20Z%20M%20227%2053%20L%20200%2053%20L%20198%2054%20L%20139%20112%20L%20134%20121%20L%20134%20173%20L%20137%20182%20L%20147%20195%20L%20153%20200%20L%20169%20210%20L%20175%20216%20L%20177%20220%20L%20181%20219%20L%20194%20209%20L%20194%20207%20L%20191%20203%20L%20184%20197%20L%20176%20193%20L%20173%20193%20L%20164%20190%20L%20157%20186%20L%20158%20185%20L%20161%20186%20L%20175%20186%20L%20185%20189%20L%20193%20194%20L%20201%20201%20L%20205%20199%20L%20215%20189%20L%20214%20187%20L%20203%20179%20L%20191%20174%20L%20179%20173%20L%20178%20172%20L%20159%20172%20L%20157%20171%20L%20153%20166%20L%20153%20161%20L%20154%20159%20L%20158%20156%20L%20206%20156%20L%20207%20155%20L%20212%20155%20L%20219%20153%20L%20228%20148%20L%20233%20144%20L%20239%20137%20L%20246%20124%20L%20248%20118%20L%20248%20114%20L%20239%20116%20L%20226%20121%20L%20223%20126%20L%20217%20132%20L%20208%20137%20L%20201%20138%20L%20200%20139%20L%20159%20139%20L%20153%20142%20L%20152%20141%20L%20153%20131%20L%20155%20127%20L%20211%2072%20Z%20M%20156%20185%20L%20157%20184%20L%20158%20185%20L%20157%20186%20Z%20M%2035%2053%20L%2038%2058%20L%2048%2069%20L%20107%20127%20L%20109%20131%20L%20109%20134%20L%20110%20135%20L%20110%20140%20L%20109%20141%20L%20104%20139%20L%2062%20139%20L%2061%20138%20L%2054%20137%20L%2045%20132%20L%2039%20126%20L%2036%20121%20L%2014%20114%20L%2014%20117%20L%2017%20126%20L%2023%20137%20L%2032%20147%20L%2042%20153%20L%2048%20155%20L%2053%20155%20L%2054%20156%20L%20104%20156%20L%20109%20160%20L%20110%20163%20L%20109%20167%20L%20103%20172%20L%2087%20172%20L%2086%20173%20L%2076%20173%20L%2075%20174%20L%2072%20174%20L%2056%20181%20L%2048%20188%20L%2048%20189%20L%2061%20201%20L%2068%20195%20L%2080%20188%20L%2087%20187%20L%2088%20186%20L%20102%20186%20L%20103%20187%20L%2098%20190%20L%2080%20196%20L%2068%20207%20L%2069%20210%20L%2085%20221%20L%2086%20218%20L%2091%20212%20L%20113%20197%20L%20120%20190%20L%20126%20180%20L%20128%20174%20L%20128%20167%20L%20129%20166%20L%20129%20125%20L%20128%20124%20L%20128%20121%20L%20126%20116%20L%2064%2054%20L%2061%2053%20Z%20M%20102%20186%20L%20103%20185%20L%20105%20186%20L%20104%20187%20Z%20M%2093%2024%20L%2075%2035%20L%2075%2045%20L%2076%2046%20L%2076%2050%20L%2078%2056%20L%2084%2066%20L%20129%20110%20L%20129%2093%20L%20128%2092%20L%20127%2084%20L%20124%2079%20L%2098%2052%20L%2095%2046%20L%2095%2042%20L%2094%2041%20L%2094%2024%20Z%20M%20169%2023%20L%20168%2023%20L%20168%2043%20L%20165%2051%20L%20159%2059%20L%20138%2079%20L%20135%2084%20L%20134%2092%20L%20133%2093%20L%20133%20110%20L%20178%2066%20L%20185%2054%20L%20186%2047%20L%20187%2046%20L%20187%2034%20Z%20M%20134%205%20L%20133%206%20L%20133%2074%20L%20142%2067%20L%20150%2059%20L%20150%2016%20L%20147%2013%20Z%20M%20128%205%20L%20118%2012%20L%20115%2013%20L%20112%2017%20L%20112%2059%20L%20129%2074%20L%20129%205%20Z%22%20fill%3D%22url(%23g)%22%20fill-rule%3D%22evenodd%22%2F%3E%3C%2Fsvg%3E';
 if(logo&&fallback){if(src){logo.src=src;logo.style.display='block';fallback.style.display='none'}else{logo.removeAttribute('src');logo.style.display='none';fallback.style.display='flex'}}
 q('rsKicker').textContent=phase==='out'?'回到比赛':'精彩回放';
 q('rsTitle').textContent=phase==='out'?'BACK TO LIVE':'INSTANT REPLAY';
 st.className='replayStinger';void st.offsetWidth;st.className='replayStinger on '+phase;
 replayStingerTimer=setTimeout(()=>{if(st)st.className='replayStinger'},1520)
}
function showEvent(g){
 const e=g&&g.event;if(!e||e.type==='CLEAR_EVENT'){hideEvent(true);return}
 if(e.type==='REPLAY_STINGER'){hideEvent(false);showReplayStinger(g,e);return}
 hideEvent(false);q('graphicsStage').classList.add('eventActive');const card=q('eventCard'),icon=q('eventIcon'),k=q('eventKicker'),name=q('eventName'),meta=q('eventMeta'),rows=q('subRows'),splash=q('stateSplash'),photo=q('eventPhoto'),photoWrap=q('eventPhotoWrap');
 rows.innerHTML='';q('mvpName').textContent='';q('mvpMeta').textContent='';const teamColor=e.side==='AWAY'?validHex(g.awayColor,'#4c7dff'):validHex(g.homeColor,'#d8b55b');card.style.setProperty('--eventAccent',teamColor);splash.style.setProperty('--stateAccent',teamColor);
 if(e.type==='GOAL'){
   scorebugGoalExpand(e,g);
   card.style.borderLeftColor=teamColor;icon.style.background=teamColor;
   card.className='eventCard on goal';icon.textContent='⚽';k.textContent='进球';
   if(e.player&&e.player.photo){photo.src=e.player.photo;photoWrap.classList.add('on')}
   {const no=e.player&&e.player.number?('#'+e.player.number+'  '):'';name.textContent=no+(e.player&&e.player.name||e.team||'球员')}
   meta.textContent=(e.team||'')+'  ·  '+(e.at||'')+'  ·  '+(Number(g.homeScore)||0)+' - '+(Number(g.awayScore)||0);
   motionInEvent('GOAL');scheduleEventHide(5600);
 } else if(e.type==='YELLOW'||e.type==='RED'){
   const cardColor=e.type==='YELLOW'?'#f2d536':'#e33440';
   card.style.borderLeftColor='';card.style.setProperty('--eventAccent',cardColor);icon.style.background='';icon.style.color='';
   card.className='eventCard on '+(e.type==='YELLOW'?'yellow':'red');icon.textContent='';icon.dataset.cardType=e.type;icon.setAttribute('aria-label',e.type==='YELLOW'?'黄牌':'红牌');k.textContent=e.type==='YELLOW'?'黄牌 · YELLOW CARD':'红牌 · RED CARD';if(e.player&&e.player.photo){photo.src=e.player.photo;photoWrap.classList.add('on')}{const no=e.player&&e.player.number?('#'+e.player.number+'  '):'';name.textContent=no+(e.player&&e.player.name||e.team||'球员')}meta.textContent=(e.team||'')+'  ·  '+(e.at||'')+'  ·  '+(Number(g.homeScore)||0)+' - '+(Number(g.awayScore)||0);
   motionInEvent(e.type);scheduleEventHide(5200);
 } else if(e.type==='SUB'){
   card.className='eventCard on sub';icon.textContent='↕';k.textContent='换人';name.textContent=e.team||'';meta.textContent=e.at||'';if(e.on&&e.on.photo){photo.src=e.on.photo;photoWrap.classList.add('on')}rows.innerHTML='<div class="subRowG in"><span class="subArrow">▲</span>#'+esc(e.on&&e.on.number)+' '+esc(e.on&&e.on.name)+'</div><div class="subRowG out"><span class="subArrow">▼</span>#'+esc(e.off&&e.off.number)+' '+esc(e.off&&e.off.name)+'</div>';motionInEvent('SUB');scheduleEventHide(6500);
 } else if(e.type==='HALF_TIME'||e.type==='FULL_TIME'){
   splash.classList.add('on');splash.style.setProperty('--stateAccent',validHex(g.accentColor,'#f4f0e8'));q('stateKicker').textContent=e.type==='HALF_TIME'?'半场结束':'全场结束';q('stateTitle').textContent=e.type==='HALF_TIME'?'半场结束':'全场结束';q('stateScore').textContent=(Number(e.homeScore)||0)+'  :  '+(Number(e.awayScore)||0);q('stateTeams').textContent=(e.home||g.home||'主队')+'    ·    '+(e.away||g.away||'客队');motionInSplash(e.type);scheduleEventHide(e.type==='FULL_TIME'?9000:6500);
 } else if(e.type==='MVP'){
   splash.classList.add('on','mvp');splash.style.setProperty('--stateAccent',teamColor);q('stateKicker').textContent='本场最佳球员';q('stateTitle').textContent=e.team||'';q('stateScore').textContent=e.score||'';q('stateTeams').textContent='';q('mvpName').textContent='#'+(e.player&&e.player.number||'')+'  '+(e.player&&e.player.name||'球员');q('mvpMeta').textContent=displayRoleLabel(e.player&&e.player.position||'');if(e.player&&e.player.photo)q('mvpPhoto').src=e.player.photo;motionInSplash('MVP');scheduleEventHide(9000);
 }
}
function applyGraphics(g){
 const fixture=String(g&&g.fixtureKey||'');
 if(fixture&&fixture!==lastGraphicsFixtureKey){lastGraphicsFixtureKey=fixture;lastGraphicsRevision=0}
 const revision=Math.max(0,Number(g&&g.revision)||0);
 if(revision&&lastGraphicsRevision&&revision<lastGraphicsRevision)return false;
 if(revision)lastGraphicsRevision=revision;
 const enteringFreeze=!!g.scoreboardFrozen&&!(currentGraphics&&currentGraphics.scoreboardFrozen);
 if(enteringFreeze){frozenGraphics={...g,clock:{...(g.clock||{}),baseSeconds:gfxSeconds(g),running:false,startedAt:null}}}
 if(!g.scoreboardFrozen)frozenGraphics=null;
 currentGraphics=g;outputHealth.lastAppliedAt=Date.now();updateScoreBug();showEvent(g);return true
}

window.sagiScoreCenterDiagnostic=()=>{const g=currentGraphics||{},clock=g.clock||{};return{build:'V4.30.8',fixtureKey:g.fixtureKey||'',revision:lastGraphicsRevision,commandId:g.commandId||'',home:g.scoreHomeName||g.home||'',away:g.scoreAwayName||g.away||'',score:[Number(g.homeScore)||0,Number(g.awayScore)||0],colors:[g.homeColor||'',g.awayColor||'',g.accentColor||''],stoppageTime:g.stoppageTime||'',frozen:!!g.scoreboardFrozen,period:clock.period||'',penalty:g.penaltyShootout||null,health:{...outputHealth,staleMs:outputHealth.lastOkAt?Math.max(0,Date.now()-outputHealth.lastOkAt):null}}};


const OUTPUT_BUILD='V4.30.8';
function versionParts(v){return String(v||'').replace(/^V/i,'').split('.').map(n=>Number(n)||0)}
function versionIsNewer(a,b){const A=versionParts(a),B=versionParts(b);for(let i=0;i<3;i++){if((A[i]||0)>(B[i]||0))return true;if((A[i]||0)<(B[i]||0))return false}return false}
async function checkOutputBuild(){
 try{
  const t=await fetch('/?graphicsBuild='+Date.now(),{cache:'no-store'}).then(r=>r.text());
  const m=t.match(/V\d+\.\d+\.\d+/);if(m&&versionIsNewer(m[0],OUTPUT_BUILD)){location.reload();return}
 }catch(e){}
}
async function poll(){
 try{
   const p=await lanState(),x=p.lineupIntro;
   if(x&&x.commandId&&x.commandId!==last){last=x.commandId;render(x)}
 }catch(e){}
 try{
   const g=await lanMatchday();
   if(outputHealth.consecutiveFailures>0)outputHealth.recoveries++;
   outputHealth.pollOk++;outputHealth.consecutiveFailures=0;outputHealth.lastOkAt=Date.now();
   if(g&&g.commandId&&(g.commandId!==lastGraphics||Number(g.revision||0)!==lastGraphicsRevision)){lastGraphics=g.commandId;applyGraphics(g)}
 }catch(e){outputHealth.pollFail++;outputHealth.consecutiveFailures++;outputHealth.lastErrorAt=Date.now()}
}
async function outputWatchdog(){
 const age=outputHealth.lastOkAt?Date.now()-outputHealth.lastOkAt:999999;
 if(age<4000||outputWatchdogBusy)return false;
 outputHealth.watchdogTrips++;outputHealth.lastWatchdogAt=Date.now();outputWatchdogBusy=true;
 try{
  outputHealth.softRepolls++;await poll();
  if(outputHealth.consecutiveFailures>0){await new Promise(r=>setTimeout(r,260));outputHealth.softRepolls++;await poll()}
  return outputHealth.consecutiveFailures===0
 }finally{outputWatchdogBusy=false}
}
window.sagiOutputRecoveryPoll=()=>poll();
window.sagiOutputWatchdog=()=>outputWatchdog();

addEventListener('resize',fit);
addEventListener('online',()=>poll());
addEventListener('pageshow',()=>poll());
document.addEventListener('visibilitychange',()=>{if(!document.hidden)poll()});
fit();poll();setInterval(poll,650);setInterval(outputWatchdog,2500);setInterval(updateScoreBug,250);setInterval(checkOutputBuild,15000);
})();
</script></body></html>
