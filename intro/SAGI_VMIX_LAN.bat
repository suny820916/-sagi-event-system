@echo off
chcp 65001 >nul
setlocal
title SAGI VMIX LAN - SELF HEAL AUTO UPDATE

echo.
echo ==========================================
echo   SAGI LIVE MATCH DIRECTOR - LAN DIRECT
echo      V4.6.5 SELF-HEAL AUTO UPDATE
echo ==========================================
echo.
echo Preparing SAGI LAN...

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
 "if(-not $m.Success){Write-Host '[ERROR] Embedded fallback payload not found.' -ForegroundColor Red;exit 2};" ^
 "$utf=New-Object Text.UTF8Encoding($false);" ^
 "[IO.File]::WriteAllText($env:SAGI_FB_BRIDGE,$m.Groups[1].Value,$utf);" ^
 "[IO.File]::WriteAllText($env:SAGI_FB_CONTROL,$m.Groups[2].Value,$utf);" ^
 "[IO.File]::WriteAllText($env:SAGI_FB_OUTPUT,$m.Groups[3].Value,$utf);" ^
 "Copy-Item $env:SAGI_FB_BRIDGE $env:SAGI_BRIDGE -Force;" ^
 "Copy-Item $env:SAGI_FB_CONTROL $env:SAGI_CONTROL -Force;" ^
 "Copy-Item $env:SAGI_FB_OUTPUT $env:SAGI_OUTPUT -Force;"

if errorlevel 1 (
  echo.
  echo [ERROR] Unable to restore embedded files.
  pause
  exit /b 1
)

echo [READY] Local files repaired from embedded fallback.
echo [UPDATE] Checking latest SAGI files...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ProgressPreference='SilentlyContinue';" ^
 "function U([string]$url,[string]$dest,[string]$name,[int]$min){$dl=$dest+'.download';try{$u=$url+'?t='+[DateTime]::UtcNow.Ticks;Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 8 -Headers @{'Cache-Control'='no-cache'} -OutFile $dl;if(-not(Test-Path $dl)){throw 'missing download'};$len=(Get-Item $dl).Length;if($len -lt $min){throw ('download too small '+$len)};$bytes=[IO.File]::ReadAllBytes($dl);$text=[Text.Encoding]::UTF8.GetString($bytes);if([string]::IsNullOrWhiteSpace($text)){throw 'empty response'};if($name -eq 'Bridge' -and $text -notmatch 'SAGI V4\.'){throw 'bridge validation failed'};if(($name -eq 'Control Room' -or $name -eq 'vMix Graphics') -and $text -notmatch '<!doctype html>'){throw 'html validation failed'};[IO.File]::WriteAllText($dest,$text,(New-Object Text.UTF8Encoding($false)));Write-Host ('[UPDATE] '+$name+' updated') -ForegroundColor Green}catch{Write-Host ('[OFFLINE] '+$name+' using embedded fallback') -ForegroundColor DarkYellow}finally{Remove-Item $dl -Force -ErrorAction SilentlyContinue}};" ^
 "U 'https://suny820916.github.io/-sagi-event-system/intro/vmix-bridge-stable.ps1' $env:SAGI_BRIDGE 'Bridge' 5000;" ^
 "U 'https://suny820916.github.io/-sagi-event-system/intro/v45-lan.html' $env:SAGI_CONTROL 'Control Room' 50000;" ^
 "U 'https://suny820916.github.io/-sagi-event-system/intro/vmix-v45-lan.html' $env:SAGI_OUTPUT 'vMix Graphics' 20000;"

echo.
echo Starting SAGI LAN Bridge...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SAGI_BRIDGE%"

echo.
pause
exit /b

###SAGI_PS###
# SAGI V4.6.5 AUTO UPDATE LAN DIRECT Bridge
# Same-LAN control server + local vMix API bridge.
# Phone Control: http://<PC-LAN-IP>:8099/
# vMix Browser:  http://127.0.0.1:8099/vmix

$PreferredPort = 8099
$Port = $PreferredPort
$VmixApi = "http://127.0.0.1:8088/api/"
$Root = Join-Path $env:LOCALAPPDATA "SAGI\LiveMatchDirector"
New-Item -ItemType Directory -Force -Path $Root | Out-Null

$ControlCache = Join-Path $Root "control-latest.html"
$OutputCache  = Join-Path $Root "output-latest.html"
$BridgeCache  = Join-Path $Root "bridge-stable.ps1"
$RemoteBase   = "https://suny820916.github.io/-sagi-event-system/intro"

$Allowed = @(
  "Cut","Fade","Stinger1","PreviewInput",
  "OverlayInput1In","OverlayInput1Out","OverlayInput1Off",
  "OverlayInput2In","OverlayInput2Out","OverlayInput2Off",
  "OverlayInput3In","OverlayInput3Out","OverlayInput3Off",
  "OverlayInput4In","OverlayInput4Out","OverlayInput4Off",
  "OverlayInputAllOff"
)

$State = @{
  lineupIntro = $null
  matchdayGraphics = $null
}
$MatchdayJson = "null"

function Update-SagiLan {
  $ProgressPreference = "SilentlyContinue"
  $stamp = [DateTime]::UtcNow.Ticks
  $items = @(
    @{url=($RemoteBase + "/v45-lan.html?t=" + $stamp); dest=$ControlCache; kind="control"; min=50000},
    @{url=($RemoteBase + "/vmix-v45-lan.html?t=" + $stamp); dest=$OutputCache; kind="output"; min=20000},
    @{url=($RemoteBase + "/vmix-bridge-stable.ps1?t=" + $stamp); dest=$BridgeCache; kind="bridge"; min=5000}
  )
  $updated = New-Object System.Collections.Generic.List[string]
  foreach ($item in $items) {
    $download = $item.dest + ".download"
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $item.url -TimeoutSec 8 -Headers @{"Cache-Control"="no-cache"} -OutFile $download
      if (-not (Test-Path $download)) { throw ("Download missing: " + $item.kind) }
      $len = (Get-Item $download).Length
      if ($len -lt [int]$item.min) { throw ("Download too small: " + $item.kind + " " + $len) }
      $bytes = [IO.File]::ReadAllBytes($download)
      $text = [Text.Encoding]::UTF8.GetString($bytes)
      if ([string]::IsNullOrWhiteSpace($text)) { throw ("Empty update payload: " + $item.kind) }
      if ($item.kind -eq "bridge" -and $text -notmatch "SAGI V4\.") { throw "Bridge validation failed" }
      if (($item.kind -eq "control" -or $item.kind -eq "output") -and $text -notmatch "<!doctype html>") { throw ("HTML validation failed: " + $item.kind) }
      $tmp = $item.dest + ".new"
      [IO.File]::WriteAllText($tmp,$text,(New-Object Text.UTF8Encoding($false)))
      Move-Item $tmp $item.dest -Force
      if ($item.kind -eq "control") { $script:ControlHtml = $text }
      elseif ($item.kind -eq "output") { $script:OutputHtml = $text }
      $updated.Add([string]$item.kind)
    } finally {
      Remove-Item $download -Force -ErrorAction SilentlyContinue
    }
  }
  Write-Host ("[UPDATE] Mobile update complete: " + ($updated -join ", ")) -ForegroundColor Green
  return @{ok=$true;version="4.6.5";updated=$updated;restartBridge=$false}
}

function Get-LanIPv4 {
  try {
    $ips = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
      Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_.IPAddressToString -notlike "169.254.*" -and $_.IPAddressToString -ne "127.0.0.1" }
    if ($ips.Count -gt 0) { return $ips[0].IPAddressToString }
  } catch {}
  return "127.0.0.1"
}

function Test-Vmix {
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $VmixApi -TimeoutSec 3 | Out-Null
    return $true
  } catch { return $false }
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
Write-Host "  SAGI V4.6.5 AUTO UPDATE LAN DIRECT - vMix Bridge" -ForegroundColor Cyan
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
  Write-Host "[ERROR] vMix API is not available on 127.0.0.1:8088" -ForegroundColor Red
  Write-Host "Open vMix -> Settings -> Web Controller -> Enable -> Port 8088." -ForegroundColor Yellow
  Read-Host "Press Enter to close"
  exit 1
}

$lanIp = Get-LanIPv4
$listener = $null
$started = $false
for ($candidate = $PreferredPort; $candidate -le ($PreferredPort + 20); $candidate++) {
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
    elseif ($method -eq "GET" -and $path -eq "/api/matchday") {
      Write-HttpResponse $stream 200 "application/json" $MatchdayJson
    }
    elseif ($method -eq "POST" -and $path -eq "/api/matchday") {
      try {
        $probe = $req.body | ConvertFrom-Json
        $MatchdayJson = $req.body
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
    elseif ($method -eq "GET" -and $path -eq "/health") {
      $health = @{ok=$true;vmix=(Test-Vmix);lan=$true;ip=$lanIp;port=$Port;version="4.6.5"} | ConvertTo-Json -Compress
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
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#07090d">
<link rel="manifest" href="./manifest.webmanifest">
<link rel="apple-touch-icon" href="./sagi-app-icon.svg">
<meta name="application-name" content="SAGI LIVE MATCH DIRECTOR">
<meta name="apple-mobile-web-app-title" content="SAGI 导播">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="format-detection" content="telephone=no">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2214%22 fill=%22%2307090d%22/%3E%3Ctext x=%2232%22 y=%2243%22 text-anchor=%22middle%22 font-size=%2234%22 fill=%22%23d8b55b%22%3ES%3C/text%3E%3C/svg%3E">
<title>SAGI V4.6.5 · PREMIUM SCOREBUG · MOBILE UPDATE · LAN DIRECT</title>
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
.formationBox{position:absolute;right:78px;top:175px;width:500px;height:760px;border:1px solid #ffffff20;border-radius:32px;background:#05080cc7;backdrop-filter:blur(7px);padding:28px}.formationHead{display:flex;justify-content:space-between;align-items:flex-start}.formationTitle{font-size:25px;font-weight:950}.formationText{font-size:42px;color:#d8b55b;font-weight:1000}.pitch{position:absolute;left:34px;right:34px;top:120px;bottom:34px;border:3px solid #ffffff50;border-radius:5px;background:linear-gradient(#123d25,#0e321e);overflow:hidden}.pitch:before{content:"";position:absolute;left:0;right:0;top:50%;border-top:2px solid #ffffff55}.pitch:after{content:"";position:absolute;width:115px;height:115px;border:2px solid #ffffff55;border-radius:50%;left:50%;top:50%;transform:translate(-50%,-50%)}.boxTop,.boxBottom{position:absolute;left:50%;width:220px;height:90px;transform:translateX(-50%);border:2px solid #ffffff55}.boxTop{top:-2px}.boxBottom{bottom:-2px}.formationNodes{position:absolute;inset:0}.node{position:absolute;width:54px;height:54px;border-radius:50%;transform:translate(-50%,-50%);background:#161e28;border:2px solid #ffffff75;display:flex;align-items:center;justify-content:center;font-weight:1000;font-size:15px;color:#fff;transition:.25s}.node.active{background:#d8b55b;color:#111;border-color:#fff3b8;box-shadow:0 0 0 8px #d8b55b22}.node small{position:absolute;top:58px;font-size:9px;color:#cbd1d9;white-space:nowrap;max-width:86px;overflow:hidden;text-overflow:ellipsis}
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

/* ===== V4.5 LIVE MATCH DIRECTOR ===== */
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
.bcQuick{display:grid;grid-template-columns:repeat(9,1fr);gap:7px;margin-top:9px}
.bcQuick button{min-height:42px;padding:7px 5px;font-size:10px;background:#10161d;border:1px solid #2d3743}
.bcQuick button.on{border-color:#d8b55b;color:#edd68d;background:#1a160d;box-shadow:0 0 0 1px #d8b55b22 inset}
.bcHint{margin-top:8px;font-size:9px;color:#6f7a87;letter-spacing:.5px}
.frame:after{content:"预监 PREVIEW";position:absolute;left:14px;top:14px;z-index:70;padding:7px 10px;border-radius:999px;background:#061019cc;border:1px solid #2aa6ff88;color:#75cfff;font-size:10px;font-weight:1000;letter-spacing:2px;pointer-events:none}
.stageCard .statusBar:before{content:"本机预监";font-size:9px;color:#58bfff;border:1px solid #2aa6ff55;border-radius:999px;padding:5px 8px}
@media(max-width:1100px){.bcMonitors{grid-template-columns:1fr 1fr}.bcStatusBox{grid-column:1/3}.bcQuick{grid-template-columns:repeat(3,1fr)}}
@media(max-width:650px){.bcMonitors{grid-template-columns:1fr}.bcStatusBox{grid-column:auto}.bcTransport{grid-template-columns:1fr 1fr}.bcTransport .goLive{grid-column:1/3}.bcQuick{grid-template-columns:repeat(3,1fr)}}


/* ===== V4.5 LIVE MATCH DIRECTOR ===== */
.matchdayDesk{margin:14px 0 0;background:linear-gradient(180deg,#10151c,#080b10);border:1px solid #3a4350;border-radius:20px;padding:14px;box-shadow:0 24px 55px #0006}
.mdHead{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:11px}.mdTitle{font-size:14px;font-weight:1000;letter-spacing:2px;color:#ebd184}.mdTitle small{font-size:10px;color:#7e8996;letter-spacing:1px;margin-left:8px}.mdSync{font-size:10px;color:#75d49e;border:1px solid #2d6748;background:#0d2118;border-radius:999px;padding:6px 9px}
.mdGrid{display:grid;grid-template-columns:1.25fr .9fr 1.25fr;gap:10px}.mdPanel{background:#080c11;border:1px solid #2e3743;border-radius:15px;padding:11px}
.mdPanelTitle{font-size:10px;font-weight:1000;letter-spacing:2px;color:#8995a3;margin-bottom:9px}
.mdScoreLine{display:grid;grid-template-columns:1fr 56px 34px 56px 1fr;gap:7px;align-items:center}.mdTeam{text-align:center;font-size:13px;font-weight:950;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mdScore{font-size:42px;font-weight:1000;text-align:center;color:#fff}.mdScoreBtn{min-height:38px!important;padding:5px!important;font-size:17px!important}
.mdClock{font-size:42px;font-weight:1000;text-align:center;font-variant-numeric:tabular-nums;letter-spacing:1px}.mdPeriod{text-align:center;color:#d8b55b;font-size:10px;font-weight:900;letter-spacing:2px;margin-top:2px}
.mdClockBtns,.mdEventBtns{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:8px}.mdClockBtns button,.mdEventBtns button{min-height:38px;font-size:10px;padding:6px}
.mdGoal{background:#1c5137!important}.mdYellow{background:#6c5b12!important;color:#fff0a5!important}.mdRed{background:#63252b!important}.mdSub{background:#173e55!important}.mdMvp{background:#5b4720!important;color:#f3d98f!important}.mdState{background:#252c36!important}
.mdInputs{display:grid;grid-template-columns:1fr 1.5fr;gap:7px}.mdInputs select,.mdInputs input{padding:8px;font-size:12px}
.mdBottom{display:grid;grid-template-columns:1.35fr 1fr 1fr;gap:10px;margin-top:10px}.mdSubGrid{display:grid;grid-template-columns:.8fr 1.2fr 1.2fr;gap:7px}
.mdActions{display:grid;grid-template-columns:repeat(2,1fr);gap:7px}.mdActions button{min-height:42px;font-size:11px}
.mdScoreboardBtns{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px}.mdScoreboardBtns button{min-height:38px;font-size:10px}
.mdLiveDot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#596472;margin-right:6px}.mdLiveDot.on{background:#5bd08c;box-shadow:0 0 12px #5bd08c88}
.mdEventStatus{margin-top:7px;font-size:9px;color:#737e8b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(max-width:1050px){.mdGrid,.mdBottom{grid-template-columns:1fr}.mdScoreLine{grid-template-columns:1fr 50px 30px 50px 1fr}}


/* ===== V4.5 LIVE MATCH DIRECTOR ===== */
.vmixDirector{margin:14px 0 0;background:linear-gradient(180deg,#111722,#080c12);border:1px solid #3b4655;border-radius:20px;padding:14px;box-shadow:0 24px 58px #0007}
.vdHead{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:10px}.vdTitle{font-size:14px;font-weight:1000;letter-spacing:2px;color:#8bd2ff}.vdTitle small{font-size:10px;color:#7f8b99;margin-left:8px}.vdStatus{font-size:10px;border:1px solid #35556d;color:#8bd2ff;background:#0c1a24;border-radius:999px;padding:6px 10px}
.vdGrid{display:grid;grid-template-columns:1.15fr 1fr 1fr;gap:10px}.vdPanel{border:1px solid #303a47;border-radius:14px;background:#080c12;padding:11px}.vdPanelTitle{font-size:10px;font-weight:1000;letter-spacing:2px;color:#8996a5;margin-bottom:9px}
.vdInputs{display:grid;grid-template-columns:repeat(5,1fr);gap:6px}.vdInputs label{font-size:9px}.vdInputs input,.vdInputs select{padding:8px;font-size:11px}
.vdSources{display:grid;grid-template-columns:repeat(4,1fr);gap:7px}.vdSource{min-height:54px!important;font-size:11px!important;border:1px solid #354353!important;background:#111923!important}.vdSource:hover{border-color:#5bbcff!important}.vdSource b{display:block;color:#8bd2ff;font-size:10px;margin-bottom:3px}
.vdPreview{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-top:7px}.vdPreview button{min-height:34px;font-size:9px;padding:5px}
.vdOverlay{display:grid;grid-template-columns:1fr 1fr;gap:7px}.vdOverlay button{min-height:45px}.vdOverlay .on{background:#17482f}.vdOverlay .off{background:#4c2529}
.vdBridgeHelp{font-size:10px;line-height:1.6;color:#8190a0;margin-top:8px}.vdDownload{display:inline-flex;align-items:center;justify-content:center;text-decoration:none;color:#0b1015;background:#8bd2ff;font-weight:1000;border-radius:10px;padding:8px 10px;margin-top:8px;font-size:10px}
.vdKeys{margin-top:8px;padding:8px 9px;border-radius:10px;background:#0b1118;border:1px solid #293442;color:#718092;font-size:9px;line-height:1.6}
.mdOpsRow{display:grid;grid-template-columns:1.45fr .75fr;gap:10px;margin-top:10px}.mdEventLog{display:grid;gap:5px;max-height:190px;overflow:auto}.mdLogRow{display:grid;grid-template-columns:56px 88px 1fr auto;gap:7px;align-items:center;padding:7px 8px;border:1px solid #26313d;border-radius:9px;background:#090e14;font-size:10px}.mdLogTime{color:#d8b55b;font-variant-numeric:tabular-nums}.mdLogType{font-weight:1000}.mdLogText{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#b8c0ca}.mdLogScore{font-weight:1000;color:#fff}.mdEmpty{padding:16px;text-align:center;color:#65717e;font-size:10px;border:1px dashed #2b3540;border-radius:10px}
.mdStatGrid{display:grid;grid-template-columns:1fr 1fr;gap:7px}.mdStat{background:#0a1016;border:1px solid #293440;border-radius:10px;padding:10px}.mdStat b{display:block;font-size:23px;color:#e5ca78}.mdStat span{font-size:9px;color:#768391}
@media(max-width:1050px){.vdGrid{grid-template-columns:1fr}.vdInputs{grid-template-columns:1fr 1fr}.mdOpsRow{grid-template-columns:1fr}}


/* ===== V4.5 MATCH SETUP ENGINE ===== */
.setupDesk{margin:14px 0;background:linear-gradient(135deg,#0d1219,#101720);border:1px solid #34404d;border-radius:20px;padding:15px;box-shadow:0 18px 45px #0003}
.setupDesk.ready{border-color:#3e725a;box-shadow:0 0 0 1px #72c79a22 inset,0 18px 45px #0003}
.setupHead{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}.setupTitle{font-size:17px;font-weight:1000;letter-spacing:.4px}.setupTitle small{display:block;color:#7f8a97;font-size:10px;letter-spacing:2px;margin-top:4px}
.setupReadyBadge{padding:8px 12px;border:1px solid #5a3434;border-radius:999px;color:#e68c8c;background:#33161666;font-size:10px;font-weight:1000;letter-spacing:1.5px;white-space:nowrap}.setupReadyBadge.ready{border-color:#477861;color:#91e1b5;background:#14332499}
.setupGrid{display:grid;grid-template-columns:1fr 1.35fr;gap:10px}.setupPanel{background:#090d12;border:1px solid #29333e;border-radius:14px;padding:11px}.setupPanelTitle{font-size:10px;color:#d8b55b;font-weight:1000;letter-spacing:2px;margin-bottom:9px}
.setupProjectGrid{display:grid;grid-template-columns:1fr 1fr;gap:8px}.setupProjectActions{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}.setupProjectActions button{min-height:38px;font-size:11px}
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
.topRight{display:grid;justify-items:end;gap:5px}
@media(max-width:650px){.mobileUpdateBtn{min-height:38px!important}}

</style>
</head>
<body>
<div class="app">
  <div class="top"><div><div class="brand">SAGI LIVE MATCH DIRECTOR</div><div class="sub">V4.6.5 · PREMIUM SCOREBUG · MOBILE UPDATE · LAN DIRECT · 主客队独立配色</div></div><div class="topRight"><div class="ver">V4.6.5</div><button id="mobileUpdateBtn" class="mobileUpdateBtn" type="button">↻ 手机一键更新</button><div id="mobileUpdateStatus" class="mobileUpdateStatus">当前 V4.6.5</div></div></div>

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

  <div id="setupDesk" class="setupDesk">
    <div class="setupHead">
      <div class="setupTitle">比赛设置 · MATCH SETUP ENGINE<small>V4.6.5 · 比赛项目 · 赛制校验 · 阵容检查 · READY GATE</small></div>
      <div id="setupReadyBadge" class="setupReadyBadge">NOT READY</div>
    </div>
    <div class="setupGrid">
      <div class="setupPanel">
        <div class="setupPanelTitle">比赛项目 · MATCH PROJECT</div>
        <div class="setupProjectGrid">
          <div><label>项目名称</label><input id="projectName" placeholder="例如：长风联赛 MD01 · TARLAN vs ICE POINT"></div>
          <div><label>已保存项目</label><select id="projectSelect"><option value="">选择比赛项目</option></select></div>
        </div>
        <div class="setupProjectActions">
          <button id="projectSaveBtn" class="ok" type="button">保存比赛项目</button>
          <button id="projectLoadBtn" type="button">读取项目</button>
          <button id="projectDeleteBtn" class="danger" type="button">删除项目</button>
        </div>
        <div class="tiny" style="margin-top:8px">比赛项目保存赛事信息、赛制、主客队名单、阵型、节目时间线与比赛事件状态；球员照片/视频继续使用本机素材库。</div>
      </div>
      <div class="setupPanel">
        <div class="setupPanelTitle">赛前检查 · PRE-FLIGHT CHECK</div>
        <div id="setupChecks" class="setupChecks"></div>
        <div id="setupSummary" class="setupSummary">尚未检查。完成比赛信息和双队阵容后点击“检查比赛”。</div>
        <div class="setupReadyActions">
          <button id="setupValidateBtn" type="button">检查比赛</button>
          <button id="setupReadyBtn" class="readyBtn" type="button" disabled>READY FOR BROADCAST</button>
          <button id="setupUnlockBtn" class="unlockBtn" type="button">解除 READY</button>
        </div>
      </div>
    </div>
  </div>

  <div class="broadcastDesk">
    <div class="bcMonitors">
      <div class="bcMonitor preview"><div class="bcKicker">预监 PREVIEW</div><div id="bcPreviewLabel" class="bcBig">主队 · 球队开场</div><div id="bcPreviewMeta" class="bcMeta">准备就绪 · 本机预监，不会直接上屏</div></div>
      <div class="bcMonitor program"><div class="bcKicker">播出 PROGRAM</div><div id="bcProgramLabel" class="bcBig">安全画面 / 未播出</div><div id="bcProgramMeta" class="bcMeta">等待切入播出</div></div>
      <div class="bcStatusBox">
        <div class="bcStatusLine"><span class="bcLamp ready" id="bcVmixLamp"><i></i>vMix 连接</span><b id="bcVmixStatus">CHECKING</b></div>
        <div class="bcStatusLine"><span class="bcLamp" id="bcOnAirLamp"><i></i>正在播出</span><b id="bcOnAirStatus">SAFE</b></div>
        <div class="bcStatusLine"><span>下一画面</span><b id="bcNextLabel">主队门将</b></div>
      </div>
    </div>
    <div class="bcTransport">
      <button id="prevLiveBtn" type="button">← 上一个</button>
      <button id="holdBtn" class="hold" type="button">保持</button>
      <button id="goLiveBtn" class="goLive" type="button">● 切入播出</button>
      <button id="nextLiveBtn" type="button">下一画面 →</button>
      <button id="clearAllBtn" class="clearAll" type="button">一键清屏</button>
    </div>
    <div class="bcQuick">
      <button type="button" data-bc-group="STING" data-bc-label="赛事Logo">赛事Logo</button>
      <button type="button" data-bc-group="MATCH" data-bc-label="比赛信息">比赛信息</button>
      <button type="button" data-bc-group="COUNTDOWN" data-bc-label="开场倒计时">开场倒计时</button>
      <button type="button" data-bc-side="HOME" data-bc-group="TEAM" data-bc-label="主队开场">主队开场</button>
      <button type="button" data-bc-side="HOME" data-bc-group="FULL" data-bc-label="主队首发">主队首发</button>
      <button type="button" data-bc-side="HOME" data-bc-group="SUB" data-bc-label="主队替补">主队替补</button>
      <button type="button" data-bc-side="AWAY" data-bc-group="TEAM" data-bc-label="客队开场">客队开场</button>
      <button type="button" data-bc-side="AWAY" data-bc-group="FULL" data-bc-label="客队首发">客队首发</button>
      <button type="button" data-bc-side="AWAY" data-bc-group="SUB" data-bc-label="客队替补">客队替补</button>
    </div>
    <div class="bcHint">SPACE = GO LIVE · H = HOLD/RESUME · ←/→ = PREV/下一画面 · ESC = 一键清屏 · 本机大画面始终作为 PREVIEW，vMix Browser 作为 PROGRAM。</div>
  </div>



  <div class="vmixDirector">
    <div class="vdHead">
      <div class="vdTitle">V4.6.5 · vMix 导播控制 <small>LIVE MATCH DIRECTOR</small></div>
      <div id="vdStatus" class="vdStatus">LAN Bridge 待命</div>
    </div>
    <div class="vdGrid">
      <div class="vdPanel">
        <div class="vdPanelTitle">输入映射 · INPUT MAP</div>
        <div class="vdInputs">
          <div><label>主机位 1</label><input id="vdCam1" value="1"></div>
          <div><label>机位 2</label><input id="vdCam2" value="2"></div>
          <div><label>无人机</label><input id="vdDrone" value="3"></div>
          <div><label>回放输入</label><input id="vdReplay" value="4"></div>
          <div><label>V4.6.5图形输入</label><input id="vdGraphics" value="5"></div>
        </div>
        <div class="vdInputs" style="grid-template-columns:1fr 1fr 1fr;margin-top:7px">
          <div><label>切换方式</label><select id="vdTransition"><option value="Cut">CUT 硬切</option><option value="Fade">FADE 淡变</option><option value="Stinger1">STINGER 1</option></select></div>
          <div><label>淡变时长 ms</label><input id="vdDuration" type="number" value="350" min="0" max="5000"></div>
          <div><label>Overlay 通道</label><select id="vdOverlay"><option value="1">Overlay 1</option><option value="2">Overlay 2</option><option value="3">Overlay 3</option><option value="4">Overlay 4</option></select></div>
        </div>
      </div>

      <div class="vdPanel">
        <div class="vdPanelTitle">PROGRAM · 切入播出</div>
        <div class="vdSources">
          <button class="vdSource" type="button" data-vd-take="cam1"><b>1</b>主机位</button>
          <button class="vdSource" type="button" data-vd-take="cam2"><b>2</b>机位 2</button>
          <button class="vdSource" type="button" data-vd-take="drone"><b>3</b>无人机</button>
          <button class="vdSource" type="button" data-vd-take="replay"><b>4</b>回放</button>
        </div>
        <div class="vdPreview">
          <button type="button" data-vd-preview="cam1">预监 1</button>
          <button type="button" data-vd-preview="cam2">预监 2</button>
          <button type="button" data-vd-preview="drone">预监无人机</button>
          <button type="button" data-vd-preview="replay">预监回放</button>
        </div>
      </div>

      <div class="vdPanel">
        <div class="vdPanelTitle">GRAPHICS OVERLAY · 图形叠加</div>
        <div class="vdOverlay">
          <button id="vdGraphicsIn" class="on" type="button">图形 Overlay ON</button>
          <button id="vdGraphicsOut" class="off" type="button">图形 Overlay OFF</button>
          <button id="vdAllOverlaysOff" type="button">关闭全部 Overlay</button>
          <button id="vdTest" type="button">测试桥接指令</button>
        </div>
        <div class="vdBridgeHelp">LAN DIRECT：手机与 vMix 电脑连接同一 Wi‑Fi。此页面由 Bridge 本机提供，所有导播指令与比赛图形直接走局域网，不依赖 Supabase。</div>
        <a class="vdDownload" href="/health" target="_blank">检查 LAN Bridge</a>
        <div class="vdKeys">快捷键：1 主机位 · 2 机位2 · 3 无人机 · 4 回放 · G 图形ON · X 图形OFF。输入框正在编辑时快捷键自动停用。</div>
      </div>
    </div>
  </div>

  <div class="matchdayDesk">
    <div class="mdHead">
      <div class="mdTitle">V4.6.5 · PREMIUM SCOREBUG <small>LIVE MATCH DIRECTOR</small></div>
      <div id="mdSync" class="mdSync"><span id="mdSyncDot" class="mdLiveDot"></span>比赛图形待命</div>
    </div>
    <div class="mdGrid">
      <div class="mdPanel">
        <div class="mdPanelTitle">比分控制 · SCORE</div>
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
          <div class="mdColorTitle">比分牌配色 · SCOREBUG COLORS</div>
          <div class="mdColorGrid">
            <label class="mdColorField"><input id="mdHomeColor" type="color" value="#d8b55b"><span>主队颜色</span></label>
            <label class="mdColorField"><input id="mdAwayColor" type="color" value="#4c7dff"><span>客队颜色</span></label>
            <label class="mdColorField"><input id="mdAccentColor" type="color" value="#f4f0e8"><span>主题高光</span></label>
            <button id="mdColorReset" class="mdColorReset" type="button">恢复默认</button>
          </div>
        </div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">比赛计时 · CLOCK</div>
        <div id="mdClock" class="mdClock">00:00</div>
        <div id="mdPeriodLabel" class="mdPeriod">上半场</div>
        <div class="mdInputs" style="margin-top:8px">
          <select id="mdPeriod"><option value="1H">上半场</option><option value="2H">下半场</option><option value="ET1">加时上半场</option><option value="ET2">加时下半场</option><option value="PEN">点球大战</option></select>
          <input id="mdSetClock" value="00:00" placeholder="00:00">
        </div>
        <div class="mdClockBtns"><button id="mdClockStart" class="ok" type="button">▶ 开始</button><button id="mdClockPause" type="button">Ⅱ 暂停</button><button id="mdClockSetBtn" type="button">设置时间</button></div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">比赛事件 · EVENT</div>
        <div class="mdInputs">
          <select id="mdEventSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select>
          <select id="mdEventPlayer"><option value="">选择球员</option></select>
        </div>
        <div class="mdEventBtns">
          <button id="mdGoalBtn" class="mdGoal" type="button">⚽ 进球</button>
          <button id="mdYellowBtn" class="mdYellow" type="button">▮ 黄牌</button>
          <button id="mdRedBtn" class="mdRed" type="button">▮ 红牌</button>
        </div>
        <div id="mdEventStatus" class="mdEventStatus">选择球队和球员后触发直播图形</div>
      </div>
    </div>

    <div class="mdBottom">
      <div class="mdPanel">
        <div class="mdPanelTitle">换人 · SUBSTITUTION</div>
        <div class="mdSubGrid">
          <select id="mdSubSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select>
          <select id="mdSubOff"><option value="">换下球员</option></select>
          <select id="mdSubOn"><option value="">换上球员</option></select>
        </div>
        <div class="mdActions" style="margin-top:8px"><button id="mdSubBtn" class="mdSub" type="button">↕ 播放换人图形</button><button id="mdClearEventBtn" type="button">清除事件图形</button></div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">比赛阶段 · MATCH STATE</div>
        <div class="mdActions">
          <button id="mdHalfBtn" class="mdState" type="button">半场 HALF TIME</button>
          <button id="mdFullBtn" class="mdState" type="button">全场 FULL TIME</button>
          <button id="mdClockReset" type="button">计时归零</button>
          <button id="mdScoreReset" type="button">比分归零</button>
        </div>
      </div>

      <div class="mdPanel">
        <div class="mdPanelTitle">本场最佳 · MVP</div>
        <div class="mdInputs">
          <select id="mdMvpSide"><option value="HOME">主队</option><option value="AWAY">客队</option></select>
          <select id="mdMvpPlayer"><option value="">选择MVP球员</option></select>
        </div>
        <div class="mdActions" style="margin-top:8px"><button id="mdMvpBtn" class="mdMvp" type="button">★ 播放 MVP 图形</button><button id="mdPublishState" type="button">同步当前比分</button></div>
      </div>
    </div>

    <div class="mdOpsRow">
      <div class="mdPanel">
        <div class="mdPanelTitle">比赛事件日志 · EVENT LOG</div>
        <div id="mdEventLog" class="mdEventLog"><div class="mdEmpty">暂无比赛事件</div></div>
        <div class="mdActions" style="margin-top:8px">
          <button id="mdUndoLast" class="danger" type="button">↶ 撤销最近事件</button>
          <button id="mdClearLog" type="button">清空事件日志</button>
        </div>
      </div>
      <div class="mdPanel">
        <div class="mdPanelTitle">本场事件统计 · LIVE STATS</div>
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
        <h2>比赛规格 · MATCH FORMAT <span id="formatBadge" class="teamSideBadge">11人制</span></h2>
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
        <div class="editorHeadRow"><h2 style="margin:0">阵型编辑器 · FORMATION EDITOR</h2><span id="editorBadge" class="editorBadge">LOCKED</span></div>
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

      <div class="card">
        <h2>双队阵容 <span id="activeSideBadge" class="teamSideBadge">HOME 主队</span></h2>
        <div class="teamSwitch"><button id="homeSideBtn" class="on" type="button">HOME 主队</button><button id="awaySideBtn" type="button">AWAY 客队</button></div>
        <div class="grid2">
          <div><label>当前球队</label><input id="teamName" value="TARLAN FC"></div>
          <div><label>当前阵型</label><select id="formation"><option>4-3-3</option><option>4-4-2</option><option>4-2-3-1</option><option>3-5-2</option><option>3-4-3</option><option>5-3-2</option></select></div>
        </div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="crestPreview">队徽</div><div><label>球队队徽</label><label class="fileBtn">上传队徽<input id="crestFile" type="file" accept="image/*"></label></div></div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="bgPreview">球场</div><div><label>专业球场背景（可选）</label><label class="fileBtn">上传球场背景<input id="bgFile" type="file" accept="image/*"></label></div></div>
        <div class="actions"><button id="clearBgBtn" type="button">使用内置职业球场</button></div>
        <div class="dualHint">HOME / AWAY 各自独立保存阵型、队徽、动态首发、替补、球员照片/视频与球员视频导演参数。比赛人数由 MATCH FORMAT 统一控制，切换球队不会覆盖另一队。</div>
      </div>

      <div class="card">
        <h2>比赛包装</h2>
        <div class="matchPackage">
          <div class="packageHead"><b>比赛信息</b><span>赛事信息 · Logo动画 · 倒计时 · 音频</span></div>
          <div class="packageGrid">
            <div><label>赛事名称</label><input id="matchCompetition" value="TFC WINTER LEAGUE"></div>
            <div><label>轮次</label><input id="matchRound" value="MATCHDAY 01"></div>
            <div><label>主队</label><input id="matchHome" value="TARLAN FC"></div>
            <div><label>客队</label><input id="matchAway" value="OPPONENT"></div>
            <div><label>比赛时间</label><input id="matchKickoff" value="20:00"></div>
            <div><label>比赛场地</label><input id="matchVenue" value="TACHENG"></div>
          </div>
          <div class="asset" style="margin-top:10px"><div class="assetPreview" id="eventLogoPreview">赛事LOGO</div><div><label>Logo Sting 赛事Logo</label><label class="fileBtn">上传赛事Logo<input id="eventLogoFile" type="file" accept="image/*"></label></div></div>
          <div class="packageHead" style="margin-top:12px"><b>音频素材</b><span>主音乐 + 提示音效</span></div>
          <div class="asset"><div class="assetPreview" id="musicPreview">MUSIC</div><div><label>本机主音乐</label><label class="fileBtn">上传音乐<input id="musicFile" type="file" accept="audio/*"></label></div></div>
          <div class="packageGrid" style="margin-top:8px">
            <div><label>vMix 主音乐URL</label><input id="musicUrl" placeholder="https://.../show-music.mp3"></div>
            <div><label>音乐音量</label><select id="musicVolume"><option value="0.35">35%</option><option value="0.5">50%</option><option value="0.65" selected>65%</option><option value="0.8">80%</option><option value="1">100%</option></select></div>
            <div><label>WHOOSH 音效URL</label><input id="sfxWhoosh" placeholder="https://.../whoosh.mp3"></div>
            <div><label>HIT 音效URL</label><input id="sfxHit" placeholder="https://.../hit.mp3"></div>
            <div><label>RISER 音效URL</label><input id="sfxRiser" placeholder="https://.../riser.mp3"></div>
            <div><label>CROWD 音效URL</label><input id="sfxCrowd" placeholder="https://.../crowd.mp3"></div>
            <div><label>STING 音效URL</label><input id="sfxSting" placeholder="https://.../sting.mp3"></div>
          </div>
          <div class="audioEngine">
            <div class="audioEngineHead"><b>SAGI 音频引擎</b><span>主音乐总线 · 提示音 · 自动闪避 · 备用音效</span></div>
            <div class="audioEngineGrid">
              <div><label>音频模式</label><select id="audioMode"><option value="HYBRID" selected>混合模式</option><option value="EXTERNAL">仅外部素材</option><option value="BUILTIN">仅内置引擎</option><option value="MUTE">静音</option></select></div>
              <div><label>内置主题</label><select id="audioTheme"><option value="SAGI_PULSE" selected>SAGI PULSE</option><option value="NORTH_WIND">NORTH WIND</option><option value="BLACK_GOLD">BLACK GOLD</option></select></div>
              <div><label>音效强度</label><select id="audioIntensity"><option value="0.55">LOW</option><option value="0.75" selected>MEDIUM</option><option value="1">HIGH</option></select></div>
              <div><label>音乐自动闪避</label><select id="audioDucking"><option value="0">OFF</option><option value="0.18">LIGHT</option><option value="0.35" selected>MEDIUM</option><option value="0.55">STRONG</option></select></div>
              <div><label>提示音音量</label><select id="cueVolume"><option value="0.65">65%</option><option value="0.8">80%</option><option value="1" selected>100%</option></select></div>
              <div><label>倒计时节拍</label><select id="countdownBeat"><option value="1" selected>开启</option><option value="0">关闭</option></select></div>
            </div>
            <div class="audioMeters"><div><label>主音乐</label><div class="audioMeter"><i id="masterMeter"></i></div></div><div><label>提示音</label><div class="audioMeter"><i id="cueMeter"></i></div></div></div>
            <div class="audioDiag"><span id="audioEngineState">ENGINE READY</span><span>备用音效 <b>开启</b></span></div>
          </div>
          <div class="actions"><button id="audioTestBtn" type="button">测试音乐</button><button id="cueTestBtn" type="button">测试重击音</button><button id="audioStopBtn" type="button">停止音频</button><button id="clearMusicBtn" type="button">清除本机音乐</button></div>
          <div id="audioStatus" class="audioStatus">音频已就绪 · 混合模式优先使用上传素材，缺失时自动使用 SAGI 内置音频</div>
        </div>
      </div>

      <div class="card">
        <h2>球员名单 · <span id="rosterSideText">HOME 主队</span></h2>
        <div class="grid2">
          <div><label>姓名</label><input id="playerName" value="MARHULAN"></div>
          <div><label>号码</label><input id="playerNo" value="88"></div>
          <div><label>名单身份</label><select id="squadType"><option value="STARTER">首发</option><option value="SUB">替补</option></select></div>
          <div><label>位置组</label><select id="role"><option value="GK">GK 门将</option><option value="DF">DF 后卫</option><option value="MF" selected>MF 中场</option><option value="FW">FW 前锋</option></select></div>
          <div><label>详细位置</label><input id="position" value="CM"></div>
          <div><label>队长</label><select id="captain"><option value="0">否</option><option value="1">C 队长</option></select></div>
          <div><label>数据名称</label><input id="statLabel" value="APPS"></div>
          <div><label>数据值</label><input id="statValue" value="12"></div>
        </div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="photoPreview">球员</div><div><label>球员照片</label><label class="fileBtn">上传球员照片<input id="photoFile" type="file" accept="image/*"></label></div></div>
        <div class="asset" style="margin-top:10px"><div class="assetPreview" id="mediaPreview">VIDEO</div><div><label>球员短视频</label><label class="fileBtn">上传3–5秒视频<input id="mediaFile" type="file" accept="video/mp4,video/webm,video/quicktime,video/*"></label></div></div>
        <div class="grid2" style="margin-top:10px">
          <div><label>动作类型</label><select id="mediaAction"><option value="STANDARD">标准站姿</option><option value="WALK_IN">走向镜头</option><option value="ARMS">抱臂站定</option><option value="LOOK">转身看镜头</option><option value="GK_GLOVES">门将整理手套</option><option value="CELEBRATE">庆祝动作</option></select></div>
          <div><label>远端 vMix 视频URL</label><input id="mediaUrl" placeholder="https://.../player.mp4"></div>
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
        <div class="actions"><button id="saveBtn" type="button">保存阵容</button><button id="loadBtn" type="button">读取阵容</button><button id="demoBtn" type="button">载入当前赛制示例</button></div>
      </div>

      <div class="card">
        <h2>节目导演</h2>
        <div class="groupButtons">
          <button id="teamBtn" type="button">球队开场</button>
          <button id="gkBtn" type="button">门将 GK</button>
          <button id="dfBtn" type="button">后卫 DF</button>
          <button id="mfBtn" type="button">中场 MF</button>
          <button id="fwBtn" type="button">前锋 FW</button>
          <button id="fullBtn" type="button">完整首发</button><button id="subsBtn" type="button">替补名单</button>
        </div>
        <div class="showDirector">
          <div class="showHead"><b>双队节目时间线</b><span>主队 + 客队 · 顺序 · 时长 · 转场 · 提示音</span></div>
          <div id="showTimeline" class="showTimeline"></div>
          <div class="showProgress"><i id="showProgressBar"></i></div>
          <div class="showNow"><span id="showNow">READY</span><span class="showTotal">TOTAL <b id="showTotal">57.0s</b></span></div>
          <div class="actions"><button id="showPlayBtn" class="primary" type="button">▶ 整套预演</button><button id="showPrevBtn" type="button">← 上一段</button><button id="showNextBtn" type="button">下一段 →</button><button id="stopBtn" type="button">■ 停止</button></div>
          <div class="actions"><button id="showResetBtn" type="button">恢复默认时间线</button><button id="showSaveBtn" type="button">保存节目</button></div>
        </div>
      </div>

      <div class="card">
        <h2>vMix 直播输出</h2>
        <div class="grid2"><div><label>输出背景</label><select id="outputBg"><option value="tunnel" selected>球员通道</option><option value="stadium">球场背景</option><option value="transparent">透明背景叠加</option><option value="chroma">绿幕</option></select></div><div><label>画面</label><input value="1920 × 1080" readonly></div></div>
        <div class="actions"><button id="copyVmixBtn" type="button">复制 LAN vMix 图形链接</button></div>
        <div class="tiny" style="margin-top:8px">vMix：添加输入 → Web Browser（网页浏览器）→ 粘贴 LAN 专用图形链接。控制端点击“切入播出”后同步到直播电脑。</div>
      </div>
    </div>

    <div class="stageCard">
      <div class="card">
        <div id="frame" class="frame">
          <div id="stageScale" class="stageScale">
            <div id="stage" class="stage">
              <div id="transitionLayer" class="transitionLayer"></div><div id="cueBadgeStage" class="cueBadgeStage"></div>
              <div id="stingOverlay" class="stingOverlay"><div class="stingCore"><img id="stingLogo" class="stingLogo"><div class="stingLine"></div><div id="stingCompetition" class="stingComp">SAGI FOOTBALL</div></div></div>
              <div id="matchOverlay" class="matchOverlay"><div class="matchCardStage"><div id="matchCompetitionStage" class="matchCompetition">TFC WINTER LEAGUE</div><div id="matchRoundStage" class="matchRound">MATCHDAY 01</div><div class="matchTeams"><div id="matchHomeStage" class="matchTeam">TARLAN FC</div><div class="matchVs">VS</div><div id="matchAwayStage" class="matchTeam">OPPONENT</div></div><div class="matchMetaStage"><span id="matchKickoffStage">20:00</span><span>·</span><span id="matchVenueStage">TACHENG</span></div></div></div>
              <div id="countdownOverlay" class="countdownOverlay"><div class="countdownCore"><div class="countdownLabel">KICKOFF SHOW</div><div id="countdownNumber" class="countdownNumber">5</div><div id="countdownSub" class="countdownSub">TFC WINTER LEAGUE</div></div></div>
              <div id="tunnelScene" class="tunnelScene">
                <div class="tunnelBack"></div><div class="portal"></div><div class="wall left"></div><div class="wall right"></div><div class="ceiling"></div><div class="floor"></div>
                <div class="led left"><div id="ledLeft" class="ledText">TARLAN FC<small>STARTING XI</small></div></div>
                <div class="led right"><div id="ledRight" class="ledText">SAGI<small>TUNNEL</small></div></div>
                <div class="roofLights"></div><div class="fog"></div><div class="cameraVignette"></div>
              </div>
              <div class="stadium"></div><img id="stadiumPhoto" class="stadiumPhoto"><div class="stadiumShade"></div><div class="pitchLines"></div><div class="light l1"></div><div class="light l2"></div>
              <div id="headerMark" class="headerMark"><img id="stageCrest" class="teamCrest"><div><div id="stageTeam" class="teamHead">TARLAN FC</div><div id="stageLineupLabel" class="teamSub">STARTING XI</div></div></div>
              <div id="groupTitle" class="groupTitle">STARTING XI</div><div id="groupName" class="groupName">TEAM LINEUP</div><div class="groupLine"></div>
              <div id="freezeFlash" class="freezeFlash"></div><div id="roleGlow" class="roleGlow"></div><div id="roleBackdrop" class="roleBackdrop">XI</div>
              <div id="playersArea" class="playersArea layout-TEAM"></div><div id="fullList" class="fullList" style="display:none"></div><div id="subList" class="subList" style="display:none"></div>
              <div id="formationEditorHint" class="formationEditorHint">拖动球员调整站位 · 自动保存</div><div id="formationBox" class="formationBox"><div class="formationHead"><div><div class="formationTitle">FORMATION</div><div class="muted">LIVE LINEUP</div></div><div id="formationText" class="formationText">4-3-3</div></div><div class="pitch"><div class="boxTop"></div><div class="boxBottom"></div><div id="formationNodes" class="formationNodes"></div></div></div>
            </div>
          </div>
        </div>
        <div class="statusBar"><div id="status" class="status">V4.6.5 · FORMATION EDITOR 已就绪</div><div class="mini">1920 × 1080</div></div>
      </div>
    </div>
  </div>
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
  return lanJson(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data||{})});
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
const ROLE_NAMES={GK:'GOALKEEPER',DF:'DEFENDERS',MF:'MIDFIELDERS',FW:'FORWARDS'};

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
function startingLabel(n=starterLimit()){const w={5:'FIVE',7:'SEVEN',8:'EIGHT',9:'NINE'};return n===11?'STARTING XI':'STARTING '+(w[n]||n)}
function starterCode(n=starterLimit()){return n===11?'XI':String(n)}
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
 q('starterHint').style.color=(over||missing)?'#ffb37a':'';q('addBtn').textContent=q('squadType').value==='SUB'?'加入替补':'加入首发'
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
 const infoIssues=[];if(!competition)infoIssues.push('赛事名称');if(!home)infoIssues.push('主队');if(!away)infoIssues.push('客队');if(!kickoff)infoIssues.push('比赛时间');if(!venue)infoIssues.push('比赛场地');if(home&&away&&home===away)infoIssues.push('主客队名称相同');
 const H=setupTeamValidation('HOME'),A=setupTeamValidation('AWAY');
 const checks=[
  {label:'比赛信息',ok:infoIssues.length===0,meta:infoIssues.length?'缺少/异常：'+infoIssues.join('、'):'赛事信息完整'},
  {label:'比赛规格',ok:formatOK,meta:formatDisplay()+' · HOME '+teamStore.HOME.formation+' · AWAY '+teamStore.AWAY.formation},
  {label:'主队首发',ok:H.ok,meta:H.ok?('有效首发 '+H.validCount+'/'+H.limit+' · GK '+H.gk):H.issues.join(' · ')},
  {label:'客队首发',ok:A.ok,meta:A.ok?('有效首发 '+A.validCount+'/'+A.limit+' · GK '+A.gk):A.issues.join(' · ')},
  {label:'主队号码',ok:H.duplicates.length===0,meta:H.duplicates.length?'重复：'+H.duplicates.join(', '):'无重复号码'},
  {label:'客队号码',ok:A.duplicates.length===0,meta:A.duplicates.length?'重复：'+A.duplicates.join(', '):'无重复号码'}
 ];
 const ok=checks.every(x=>x.ok),result={ok,checks,home:H,away:A,infoIssues,signature:setupSignatureRaw()};
 setupLastValidation=result;if(render)renderSetupValidation(result);return result
}
function setupSignatureRaw(){
 stashActiveTeam();
 const teamSig=side=>{const t=teamStore[side]||{roster:[]};return{formation:t.formation,customPositions:t.customPositions||{},roster:(t.roster||[]).map(p=>({id:p.id,name:p.name,number:p.number,squadType:p.squadType||'STARTER',role:p.role,position:p.position,captain:!!p.captain}))}};
 return JSON.stringify({matchConfig:{...matchConfig},competition:q('matchCompetition').value.trim(),round:q('matchRound').value.trim(),home:q('matchHome').value.trim(),away:q('matchAway').value.trim(),kickoff:q('matchKickoff').value.trim(),venue:q('matchVenue').value.trim(),HOME:teamSig('HOME'),AWAY:teamSig('AWAY')})
}
function renderSetupValidation(result){
 const w=q('setupChecks');w.innerHTML=result.checks.map(x=>'<div class="setupCheck '+(x.ok?'good':'bad')+'"><span>'+esc(x.label)+'</span><b>'+(x.ok?'PASS':'CHECK')+'</b><span style="display:none">'+esc(x.meta)+'</span></div>').join('');
 q('setupSummary').className='setupSummary '+(result.ok?'good':'bad');
 q('setupSummary').textContent=result.ok?'赛前检查通过。可以点击 READY FOR BROADCAST 解锁正式播出。':'未通过：'+result.checks.filter(x=>!x.ok).map(x=>x.label+'（'+x.meta+'）').join('；');
 q('setupReadyBtn').disabled=!result.ok;
}
function setMatchReady(on){
 if(on){
   const r=validateMatchSetup(true);if(!r.ok){matchReady=false;refreshSetupReadyUI();note('赛前检查未通过');return false}
   matchReady=true;setupReadySignature=r.signature;note('READY FOR BROADCAST · 已解锁正式播出')
 }else{matchReady=false;setupReadySignature='';note('已解除 READY · PROGRAM 已锁定')}
 refreshSetupReadyUI();return matchReady
}
function requireMatchReady(){
 if(!matchReady){note('请先完成 READY FOR BROADCAST');return false}
 const now=setupSignatureRaw();if(now!==setupReadySignature){matchReady=false;setupReadySignature='';validateMatchSetup(true);refreshSetupReadyUI();note('比赛设置已变化 · READY 自动解除');return false}
 const r=validateMatchSetup(false);if(!r.ok){matchReady=false;setupReadySignature='';renderSetupValidation(r);refreshSetupReadyUI();note('赛前检查状态已失效');return false}
 return true
}
function refreshSetupReadyUI(){
 const b=q('setupReadyBadge'),desk=q('setupDesk');b.textContent=matchReady?'READY FOR BROADCAST':'NOT READY';b.classList.toggle('ready',matchReady);desk.classList.toggle('ready',matchReady);
 q('goLiveBtn').disabled=!matchReady;q('showPlayBtn').disabled=!matchReady;
 document.querySelectorAll('[data-vd-take]').forEach(x=>x.disabled=!matchReady);q('vdGraphicsIn').disabled=!matchReady;
 q('setupUnlockBtn').disabled=!matchReady;
}
function getMatchProjects(){try{const x=JSON.parse(localStorage.getItem(MATCH_PROJECTS_KEY)||'[]');return Array.isArray(x)?x:[]}catch(e){return[]}}
function putMatchProjects(list){localStorage.setItem(MATCH_PROJECTS_KEY,JSON.stringify((list||[]).slice(0,20)))}
function refreshProjectList(selected=''){
 const list=getMatchProjects().sort((a,b)=>(b.savedAt||0)-(a.savedAt||0)),el=q('projectSelect');el.innerHTML='<option value="">选择比赛项目</option>'+list.map(p=>'<option value="'+escAttr(p.id)+'">'+esc(p.name)+' · '+new Date(p.savedAt).toLocaleString()+'</option>').join('');if(selected)el.value=selected
}
async function saveMatchProject(){
 const name=q('projectName').value.trim()||setupProjectDefaultName();q('projectName').value=name;await save();mdPersist();vdSave();
 const id='match_'+Date.now().toString(36),project={id,name,savedAt:Date.now(),core:localStorage.getItem('sagi_player_intro_v40')||'',show:localStorage.getItem('sagi_show_director_v40')||'',matchday:localStorage.getItem('sagi_matchday_graphics_v42')||'',vmix:localStorage.getItem('sagi_vmix_director_v42')||''};
 let list=getMatchProjects();const same=list.findIndex(p=>p.name===name);if(same>=0){project.id=list[same].id;list.splice(same,1)}list.unshift(project);putMatchProjects(list);refreshProjectList(project.id);note('比赛项目已保存 · '+name)
}
async function loadMatchProject(){
 const id=q('projectSelect').value,p=getMatchProjects().find(x=>x.id===id);if(!p){note('请选择比赛项目');return}
 if(p.core)localStorage.setItem('sagi_player_intro_v40',p.core);if(p.show)localStorage.setItem('sagi_show_director_v40',p.show);if(p.matchday)localStorage.setItem('sagi_matchday_graphics_v42',p.matchday);if(p.vmix)localStorage.setItem('sagi_vmix_director_v42',p.vmix);
 await load();mdLoad();vdLoad();q('projectName').value=p.name;matchReady=false;setupReadySignature='';validateMatchSetup(true);refreshSetupReadyUI();note('比赛项目已读取 · '+p.name)
}
function deleteMatchProject(){
 const id=q('projectSelect').value;if(!id){note('请选择比赛项目');return}let list=getMatchProjects(),p=list.find(x=>x.id===id);list=list.filter(x=>x.id!==id);putMatchProjects(list);refreshProjectList();note('已删除比赛项目'+(p?' · '+p.name:''))
}
function initMatchSetup(){
 q('projectName').value=setupProjectDefaultName();refreshProjectList();q('projectSaveBtn').onclick=saveMatchProject;q('projectLoadBtn').onclick=loadMatchProject;q('projectDeleteBtn').onclick=deleteMatchProject;
 q('setupValidateBtn').onclick=()=>validateMatchSetup(true);q('setupReadyBtn').onclick=()=>setMatchReady(true);q('setupUnlockBtn').onclick=()=>setMatchReady(false);
 validateMatchSetup(true);refreshSetupReadyUI()
}

const DEFAULT_SHOW=[
 {id:'sting',group:'STING',label:'Logo Sting',duration:2000,transition:'FLASH',cue:'STING',enabled:true},
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
let showSteps=DEFAULT_SHOW.map(x=>({...x})),showIndex=-1,showStartedAt=0,showSession='',showTimer=null;
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


let matchdayState={homeScore:0,awayScore:0,scoreboardVisible:false,period:'1H',clockBase:0,clockRunning:false,clockStartedAt:0,lastEvent:null,eventLog:[],homeColor:'#d8b55b',awayColor:'#4c7dff',accentColor:'#f4f0e8'};
function mdPeriodName(p){return({'1H':'上半场','2H':'下半场','ET1':'加时上半场','ET2':'加时下半场','PEN':'点球大战'})[p]||p}
function mdNowSeconds(){return Math.max(0,matchdayState.clockBase+(matchdayState.clockRunning?((Date.now()-matchdayState.clockStartedAt)/1000):0))}
function mdFormat(sec){sec=Math.max(0,Math.floor(Number(sec)||0));return String(Math.floor(sec/60)).padStart(2,'0')+':'+String(sec%60).padStart(2,'0')}
function mdParse(s){const m=String(s||'').trim().match(/^(\d{1,3})(?::(\d{1,2}))?$/);if(!m)return null;return Math.max(0,(+m[1])*60+(+(m[2]||0)))}
function mdRoster(side){stashActiveTeam();return (teamStore[side]&&teamStore[side].roster||[]).slice()}
function mdPlayer(side,id){return mdRoster(side).find(p=>p.id===id)||null}
function mdFillSelect(id,side,placeholder){
 const el=q(id),old=el.value,arr=mdRoster(side);el.innerHTML='<option value="">'+placeholder+'</option>'+arr.map(p=>'<option value="'+esc(p.id)+'">#'+esc(p.number)+' · '+esc(p.name)+' · '+esc(p.squadType==='SUB'?'替补':p.position||p.role)+'</option>').join('');if(arr.some(p=>p.id===old))el.value=old;
}
function refreshMatchdayPlayers(){
 mdFillSelect('mdEventPlayer',q('mdEventSide').value,'选择球员');
 mdFillSelect('mdSubOff',q('mdSubSide').value,'换下球员');
 mdFillSelect('mdSubOn',q('mdSubSide').value,'换上球员');
 mdFillSelect('mdMvpPlayer',q('mdMvpSide').value,'选择MVP球员');
}
function refreshMatchdayUI(){
 q('mdHomeName').textContent=q('matchHome').value.trim()||'主队';q('mdAwayName').textContent=q('matchAway').value.trim()||'客队';
 q('mdHomeScore').textContent=matchdayState.homeScore;q('mdAwayScore').textContent=matchdayState.awayScore;
 q('mdClock').textContent=mdFormat(mdNowSeconds());q('mdPeriod').value=matchdayState.period;q('mdPeriodLabel').textContent=mdPeriodName(matchdayState.period);
 if(q('mdHomeColor'))q('mdHomeColor').value=matchdayState.homeColor||'#d8b55b';
 if(q('mdAwayColor'))q('mdAwayColor').value=matchdayState.awayColor||'#4c7dff';
 if(q('mdAccentColor'))q('mdAccentColor').value=matchdayState.accentColor||'#f4f0e8';
 q('mdScoreboardShow').classList.toggle('primary',matchdayState.scoreboardVisible);const syncDot=q('mdSyncDot');if(syncDot)syncDot.classList.toggle('on',matchdayState.scoreboardVisible||!!matchdayState.lastEvent);
}
function mdPersist(){try{const s={...matchdayState,clockBase:mdNowSeconds(),clockRunning:false,clockStartedAt:0};localStorage.setItem('sagi_matchday_graphics_v42',JSON.stringify(s))}catch(e){}}
function mdLoad(){
 try{let x=JSON.parse(localStorage.getItem('sagi_matchday_graphics_v42')||'null');if(!x)x=JSON.parse(localStorage.getItem('sagi_matchday_graphics_v41')||'null');if(x)matchdayState={...matchdayState,...x,clockRunning:false,clockStartedAt:0,eventLog:Array.isArray(x.eventLog)?x.eventLog:[]};}catch(e){}
 refreshMatchdayUI();refreshMatchdayPlayers();mdRenderLog();
}
function mdCloudSnapshot(event=null){
 const now=mdNowSeconds();return{
  commandId:Date.now()+'_'+Math.random().toString(36).slice(2,7),
  visualVersion:'V4.6.5-PREMIUM-SCOREBUG',
  home:q('matchHome').value.trim()||'HOME',away:q('matchAway').value.trim()||'AWAY',
  homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore,scoreboardVisible:!!matchdayState.scoreboardVisible,
  homeColor:matchdayState.homeColor||'#d8b55b',awayColor:matchdayState.awayColor||'#4c7dff',accentColor:matchdayState.accentColor||'#f4f0e8',
  clock:{baseSeconds:now,running:!!matchdayState.clockRunning,startedAt:matchdayState.clockRunning?new Date().toISOString():null,period:matchdayState.period},
  event:event||null,updatedAt:new Date().toISOString()
 };
}
async function publishMatchday(event=null){
 const state=mdCloudSnapshot(event);matchdayState.lastEvent=event;mdPersist();refreshMatchdayUI();
 try{
  await lanPost('/api/matchday',state);
  q('mdSync').innerHTML='<span class="mdLiveDot on"></span>LAN 比分已同步 vMix';
  return{ok:true}
 }catch(e){
  q('mdSync').innerHTML='<span class="mdLiveDot"></span>LAN 比分同步失败';
  return{ok:false}
 }
}

function mdEventLabel(e){
 if(!e)return'事件';if(e.type==='GOAL')return'进球';if(e.type==='YELLOW')return'黄牌';if(e.type==='RED')return'红牌';if(e.type==='SUB')return'换人';if(e.type==='HALF_TIME')return'半场';if(e.type==='FULL_TIME')return'全场';if(e.type==='MVP')return'MVP';return e.type||'事件';
}
function mdEventText(e){
 if(!e)return'';if(e.player)return'#'+(e.player.number||'')+' '+(e.player.name||'');if(e.type==='SUB')return'#'+(e.off&&e.off.number||'')+' '+(e.off&&e.off.name||'')+' → #'+(e.on&&e.on.number||'')+' '+(e.on&&e.on.name||'');if(e.type==='HALF_TIME'||e.type==='FULL_TIME')return(e.home||'HOME')+' '+(e.homeScore||0)+':'+(e.awayScore||0)+' '+(e.away||'AWAY');return e.team||'';
}
function mdRecordEvent(ev,before){
 if(!ev||ev.type==='CLEAR_EVENT')return;
 const item={id:'ev_'+Date.now()+'_'+Math.random().toString(36).slice(2,6),createdAt:new Date().toISOString(),event:ev,beforeHomeScore:before.homeScore,beforeAwayScore:before.awayScore};
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
 const x=list.shift();matchdayState.homeScore=Number(x.beforeHomeScore)||0;matchdayState.awayScore=Number(x.beforeAwayScore)||0;matchdayState.eventLog=list;mdRenderLog();q('mdEventStatus').textContent='已撤销 · '+mdEventLabel(x.event);publishMatchday({type:'CLEAR_EVENT'});note('已撤销 '+mdEventLabel(x.event));
}

function mdScore(side,delta){if(side==='HOME')matchdayState.homeScore=Math.max(0,matchdayState.homeScore+delta);else matchdayState.awayScore=Math.max(0,matchdayState.awayScore+delta);publishMatchday(null)}
function mdEvent(type){
 const side=q('mdEventSide').value,p=mdPlayer(side,q('mdEventPlayer').value);if(!p){note('请先选择球员');return}
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore};
 if(type==='GOAL'){if(side==='HOME')matchdayState.homeScore++;else matchdayState.awayScore++}
 const ev={type,side,team:side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY'),player:{id:p.id,name:p.name,number:p.number,position:p.position||p.role},at:mdFormat(mdNowSeconds())};
 mdRecordEvent(ev,before);q('mdEventStatus').textContent=(type==='GOAL'?'进球':type==='YELLOW'?'黄牌':'红牌')+' · #'+p.number+' '+p.name;publishMatchday(ev)
}
function mdSubstitution(){
 const side=q('mdSubSide').value,off=mdPlayer(side,q('mdSubOff').value),on=mdPlayer(side,q('mdSubOn').value);if(!off||!on){note('请选择换下和换上球员');return}
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore};
 const ev={type:'SUB',side,team:side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY'),off:{id:off.id,name:off.name,number:off.number},on:{id:on.id,name:on.name,number:on.number},at:mdFormat(mdNowSeconds())};mdRecordEvent(ev,before);q('mdEventStatus').textContent='换人 · #'+off.number+' '+off.name+' → #'+on.number+' '+on.name;publishMatchday(ev)
}
function mdMatchState(type){
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore},sec=mdNowSeconds();matchdayState.clockBase=sec;matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;
 const ev={type,home:q('matchHome').value||'HOME',away:q('matchAway').value||'AWAY',homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore,at:mdFormat(sec)};
 mdRecordEvent(ev,before);q('mdEventStatus').textContent=type==='HALF_TIME'?'半场图形已触发':'全场图形已触发';publishMatchday(ev)
}
function mdMvp(){
 const side=q('mdMvpSide').value,p=mdPlayer(side,q('mdMvpPlayer').value);if(!p){note('请选择MVP球员');return}
 const before={homeScore:matchdayState.homeScore,awayScore:matchdayState.awayScore},ev={type:'MVP',side,team:side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY'),player:{id:p.id,name:p.name,number:p.number,position:p.position||p.role},score:matchdayState.homeScore+'-'+matchdayState.awayScore,at:mdFormat(mdNowSeconds())};
 mdRecordEvent(ev,before);q('mdEventStatus').textContent='MVP · #'+p.number+' '+p.name;publishMatchday(ev)
}
function initMatchdayGraphics(){
 q('mdHomeMinus').onclick=()=>mdScore('HOME',-1);q('mdHomePlus').onclick=()=>mdScore('HOME',1);q('mdAwayMinus').onclick=()=>mdScore('AWAY',-1);q('mdAwayPlus').onclick=()=>mdScore('AWAY',1);
 q('mdScoreboardShow').onclick=()=>{matchdayState.scoreboardVisible=true;publishMatchday(null)};q('mdScoreboardHide').onclick=()=>{matchdayState.scoreboardVisible=false;publishMatchday(null)};
 q('mdHomeColor').oninput=e=>{matchdayState.homeColor=e.target.value;publishMatchday(null)};
 q('mdAwayColor').oninput=e=>{matchdayState.awayColor=e.target.value;publishMatchday(null)};
 q('mdAccentColor').oninput=e=>{matchdayState.accentColor=e.target.value;publishMatchday(null)};
 q('mdColorReset').onclick=()=>{matchdayState.homeColor='#d8b55b';matchdayState.awayColor='#4c7dff';matchdayState.accentColor='#f4f0e8';refreshMatchdayUI();publishMatchday(null)};
 q('mdClockStart').onclick=()=>{if(!matchdayState.clockRunning){matchdayState.clockStartedAt=Date.now();matchdayState.clockRunning=true;publishMatchday(null)}};
 q('mdClockPause').onclick=()=>{matchdayState.clockBase=mdNowSeconds();matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;publishMatchday(null)};
 q('mdClockReset').onclick=()=>{matchdayState.clockBase=0;matchdayState.clockRunning=false;matchdayState.clockStartedAt=0;publishMatchday(null)};
 q('mdClockSetBtn').onclick=()=>{const s=mdParse(q('mdSetClock').value);if(s==null){note('时间格式请使用 45:00');return}matchdayState.clockBase=s;matchdayState.clockStartedAt=matchdayState.clockRunning?Date.now():0;publishMatchday(null)};
 q('mdPeriod').onchange=()=>{matchdayState.period=q('mdPeriod').value;publishMatchday(null)};
 q('mdGoalBtn').onclick=()=>mdEvent('GOAL');q('mdYellowBtn').onclick=()=>mdEvent('YELLOW');q('mdRedBtn').onclick=()=>mdEvent('RED');
 q('mdSubBtn').onclick=mdSubstitution;q('mdHalfBtn').onclick=()=>mdMatchState('HALF_TIME');q('mdFullBtn').onclick=()=>mdMatchState('FULL_TIME');q('mdMvpBtn').onclick=mdMvp;
 q('mdScoreReset').onclick=()=>{matchdayState.homeScore=0;matchdayState.awayScore=0;publishMatchday(null)};
 q('mdClearEventBtn').onclick=()=>{matchdayState.lastEvent=null;publishMatchday({type:'CLEAR_EVENT'})};q('mdPublishState').onclick=()=>publishMatchday(null);q('mdUndoLast').onclick=mdUndoLast;q('mdClearLog').onclick=()=>{matchdayState.eventLog=[];mdRenderLog();mdPersist();note('事件日志已清空')};
 q('mdEventSide').onchange=refreshMatchdayPlayers;q('mdSubSide').onchange=refreshMatchdayPlayers;q('mdMvpSide').onchange=refreshMatchdayPlayers;
 ['addBtn','updateBtn','removeBtn','demoBtn','loadBtn','homeSideBtn','awaySideBtn'].forEach(id=>q(id)&&q(id).addEventListener('click',()=>setTimeout(refreshMatchdayPlayers,60)));
 ['matchHome','matchAway'].forEach(id=>q(id)&&q(id).addEventListener('input',refreshMatchdayUI));
 setInterval(()=>{if(matchdayState.clockRunning)refreshMatchdayUI()},250);
 mdLoad();
}



let vmixDirectorSettings={cam1:'1',cam2:'2',drone:'3',replay:'4',graphics:'5',transition:'Cut',duration:350,overlay:'1'};
function vdSave(){
 vmixDirectorSettings={cam1:q('vdCam1').value.trim()||'1',cam2:q('vdCam2').value.trim()||'2',drone:q('vdDrone').value.trim()||'3',replay:q('vdReplay').value.trim()||'4',graphics:q('vdGraphics').value.trim()||'5',transition:q('vdTransition').value||'Cut',duration:Math.max(0,Number(q('vdDuration').value)||0),overlay:q('vdOverlay').value||'1'};
 try{localStorage.setItem('sagi_vmix_director_v42',JSON.stringify(vmixDirectorSettings))}catch(e){}
}
function vdLoad(){
 try{const x=JSON.parse(localStorage.getItem('sagi_vmix_director_v42')||'null');if(x)vmixDirectorSettings={...vmixDirectorSettings,...x}}catch(e){}
 q('vdCam1').value=vmixDirectorSettings.cam1;q('vdCam2').value=vmixDirectorSettings.cam2;q('vdDrone').value=vmixDirectorSettings.drone;q('vdReplay').value=vmixDirectorSettings.replay;q('vdGraphics').value=vmixDirectorSettings.graphics;q('vdTransition').value=vmixDirectorSettings.transition;q('vdDuration').value=vmixDirectorSettings.duration;q('vdOverlay').value=vmixDirectorSettings.overlay;
}
function vdInput(slot){vdSave();return vmixDirectorSettings[slot]||''}
async function publishVmixDirector(functionName,input='',duration=0,label=''){
 const cmd={commandId:Date.now()+'_'+Math.random().toString(36).slice(2,7),functionName,input:String(input||''),duration:Math.max(0,Number(duration)||0),label,issuedAt:new Date().toISOString(),version:'V4.6.5-LAN'};
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

function vdTake(slot){
 if(!requireMatchReady())return;vdSave();const input=vdInput(slot),fn=vmixDirectorSettings.transition,d=fn==='Fade'?vmixDirectorSettings.duration:0;publishVmixDirector(fn,input,d,'PROGRAM '+slot.toUpperCase());
}
function vdPreview(slot){publishVmixDirector('PreviewInput',vdInput(slot),0,'PREVIEW '+slot.toUpperCase())}
function vdOverlayIn(){if(!requireMatchReady())return;vdSave();publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'In',vmixDirectorSettings.graphics,0,'GRAPHICS ON')}
function vdOverlayOut(){vdSave();publishVmixDirector('OverlayInput'+vmixDirectorSettings.overlay+'Out','',0,'GRAPHICS OFF')}
function initVmixDirector(){
 vdLoad();
 lanJson('/health').then(x=>{q('vdStatus').textContent='LAN READY · vMix '+(x.vmix?'已连接':'未连接')}).catch(()=>{q('vdStatus').textContent='LAN Bridge 未连接'});
 document.querySelectorAll('[data-vd-take]').forEach(b=>b.onclick=()=>vdTake(b.dataset.vdTake));
 document.querySelectorAll('[data-vd-preview]').forEach(b=>b.onclick=()=>vdPreview(b.dataset.vdPreview));
 q('vdGraphicsIn').onclick=vdOverlayIn;q('vdGraphicsOut').onclick=vdOverlayOut;q('vdAllOverlaysOff').onclick=()=>publishVmixDirector('OverlayInputAllOff','','0','ALL OVERLAYS OFF');q('vdTest').onclick=()=>vdPreview('cam1');
 ['vdCam1','vdCam2','vdDrone','vdReplay','vdGraphics','vdTransition','vdDuration','vdOverlay'].forEach(id=>q(id).addEventListener('change',vdSave));
 addEventListener('keydown',e=>{const tag=(e.target&&e.target.tagName)||'';if(tag==='INPUT'||tag==='SELECT'||tag==='TEXTAREA')return;if(e.key==='1')vdTake('cam1');else if(e.key==='2')vdTake('cam2');else if(e.key==='3')vdTake('drone');else if(e.key==='4')vdTake('replay');else if(e.key.toLowerCase()==='g')vdOverlayIn();else if(e.key.toLowerCase()==='x')vdOverlayOut()});
}

function note(t){const n=q('notice');n.textContent=t;n.style.display='block';clearTimeout(note.t);note.t=setTimeout(()=>n.style.display='none',1500)}
function esc(s){return String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function uid(){return'p_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,8)}
function openDB(){return new Promise((res,rej)=>{const r=indexedDB.open('sagi_player_intro_v2_assets',1);r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains('assets'))r.result.createObjectStore('assets')};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)})}
async function dbPut(k,v){try{const db=await openDB();await new Promise((res,rej)=>{const tx=db.transaction('assets','readwrite');tx.objectStore('assets').put(v,k);tx.oncomplete=res;tx.onerror=()=>rej(tx.error)});db.close()}catch(e){}}
async function dbGet(k){try{const db=await openDB();const v=await new Promise(res=>{const tx=db.transaction('assets','readonly'),r=tx.objectStore('assets').get(k);r.onsuccess=()=>res(r.result||'');r.onerror=()=>res('')});db.close();return v}catch(e){return''}}
async function dbDel(k){try{const db=await openDB();await new Promise(res=>{const tx=db.transaction('assets','readwrite');tx.objectStore('assets').delete(k);tx.oncomplete=res;tx.onerror=res});db.close()}catch(e){}}
function fileData(file,max=1100,quality=.82){return new Promise((res,rej)=>{const r=new FileReader();r.onerror=rej;r.onload=()=>{const im=new Image();im.onerror=()=>res(r.result);im.onload=()=>{const ratio=Math.min(1,max/im.width,max/im.height),w=Math.max(1,Math.round(im.width*ratio)),h=Math.max(1,Math.round(im.height*ratio)),cv=document.createElement('canvas');cv.width=w;cv.height=h;const cx=cv.getContext('2d');cx.clearRect(0,0,w,h);cx.drawImage(im,0,0,w,h);try{res(cv.toDataURL('image/webp',quality))}catch(e){res(r.result)}};im.src=r.result};r.readAsDataURL(file)})}
function sideLabel(side){return side==='AWAY'?'客队 AWAY':'主队 HOME'}
function currentTeamName(){return activeSide==='AWAY'?(q('matchAway').value.trim()||q('teamName').value.trim()||'AWAY'):(q('matchHome').value.trim()||q('teamName').value.trim()||'HOME')}
function stashActiveTeam(){
 const t=teamStore[activeSide];t.roster=roster;t.formation=q('formation').value||defaultFormationForCount(starterLimit());t.crest=assets.crest||'';if(!t.customPositions)t.customPositions={};
}
function refreshSideUI(){
 q('homeSideBtn').classList.toggle('on',activeSide==='HOME');q('awaySideBtn').classList.toggle('on',activeSide==='AWAY');
 q('activeSideBadge').textContent=sideLabel(activeSide);q('rosterSideText').textContent=sideLabel(activeSide);q('stage').dataset.side=activeSide;
}
function switchTeam(side,opts={}){
 if(side!=='HOME'&&side!=='AWAY')return;if(!opts.skipStash)stashActiveTeam();activeSide=side;const t=teamStore[side];
 reconcileTeamStarters(side,t.formation);roster=t.roster||[];refreshFormationOptions(t.formation||defaultFormationForCount(starterLimit()));assets.crest=t.crest||'';
 q('teamName').value=side==='HOME'?(q('matchHome').value||'HOME'):(q('matchAway').value||'AWAY');
 selected=roster.length?0:-1;if(selected>=0)writePlayer(roster[0]);else{assets.photo='';assets.mediaBlob=null;assets.mediaObjectUrl='';renderPreviews()}
 refreshSideUI();updateFormatUI();updateFormationEditorUI();q('stage').dataset.side=activeSide;renderRoster();renderPreviews();if(!opts.noRender)renderStage(currentGroup);if(!opts.silent)note('已切换到 '+sideLabel(side))
}
function readPlayer(){return{id:selected>=0&&roster[selected]?roster[selected].id:'',name:q('playerName').value.trim()||'PLAYER',number:q('playerNo').value.trim()||'00',squadType:q('squadType').value||'STARTER',role:q('role').value,position:q('position').value.trim()||q('role').value,captain:q('captain').value==='1',statLabel:q('statLabel').value.trim()||'',statValue:q('statValue').value.trim()||'',photo:assets.photo||'',mediaBlob:assets.mediaBlob||null,mediaObjectUrl:assets.mediaObjectUrl||'',mediaUrl:q('mediaUrl').value.trim()||'',mediaAction:q('mediaAction').value||'STANDARD',directorIn:Math.max(0,parseFloat(q('directorIn').value)||0),directorOut:Math.max(0,parseFloat(q('directorOut').value)||0),directorSpeed:parseFloat(q('directorSpeed').value)||1,directorFreeze:q('directorFreeze').value==='1',directorFreezeMs:parseInt(q('directorFreezeMs').value,10)||1000,directorCamera:q('directorCamera').value||'MEDIUM'}}
function writePlayer(p){q('playerName').value=p.name||'';q('playerNo').value=p.number||'';q('squadType').value=p.squadType||'STARTER';q('role').value=p.role||'MF';q('position').value=p.position||p.role||'';q('captain').value=p.captain?'1':'0';q('statLabel').value=p.statLabel||'';q('statValue').value=p.statValue||'';q('mediaUrl').value=p.mediaUrl||'';q('mediaAction').value=p.mediaAction||'STANDARD';q('directorIn').value=Number.isFinite(+p.directorIn)?+p.directorIn:0;q('directorOut').value=Number.isFinite(+p.directorOut)?+p.directorOut:0;q('directorSpeed').value=String(p.directorSpeed||1);q('directorFreeze').value=p.directorFreeze?'1':'0';q('directorFreezeMs').value=String(p.directorFreezeMs||1000);q('directorCamera').value=p.directorCamera||'MEDIUM';assets.photo=p.photo||'';assets.mediaBlob=p.mediaBlob||null;assets.mediaObjectUrl=p.mediaObjectUrl||'';renderPreviews()}
function packageData(){
 return{matchFormat:{mode:matchConfig.mode,playerCount:starterLimit()},competition:q('matchCompetition').value.trim()||'MATCH',round:q('matchRound').value.trim()||'',home:q('matchHome').value.trim()||'HOME',away:q('matchAway').value.trim()||'AWAY',kickoff:q('matchKickoff').value.trim()||'',venue:q('matchVenue').value.trim()||'',eventLogo:assets.eventLogo||'',musicUrl:q('musicUrl').value.trim()||'',musicVolume:Math.max(0,Math.min(1,parseFloat(q('musicVolume').value)||.65)),audioEngine:{mode:q('audioMode').value||'HYBRID',theme:q('audioTheme').value||'SAGI_PULSE',intensity:Math.max(.1,Math.min(1,parseFloat(q('audioIntensity').value)||.75)),ducking:Math.max(0,Math.min(.8,parseFloat(q('audioDucking').value)||.35)),cueVolume:Math.max(.1,Math.min(1,parseFloat(q('cueVolume').value)||1)),countdownBeat:q('countdownBeat').value==='1'},sfx:{WHOOSH:q('sfxWhoosh').value.trim()||'',HIT:q('sfxHit').value.trim()||'',RISER:q('sfxRiser').value.trim()||'',CROWD:q('sfxCrowd').value.trim()||'',STING:q('sfxSting').value.trim()||''}}
}
function writePackage(p={}){
 if(p.matchFormat)applyStoredMatchConfig(p.matchFormat,true);q('matchCompetition').value=p.competition||'TFC WINTER LEAGUE';q('matchRound').value=p.round||'MATCHDAY 01';q('matchHome').value=p.home||'TARLAN FC';q('matchAway').value=p.away||'OPPONENT';q('matchKickoff').value=p.kickoff||'20:00';q('matchVenue').value=p.venue||'TACHENG';q('musicUrl').value=p.musicUrl||'';q('musicVolume').value=String(p.musicVolume||.65);const s=p.sfx||{};q('sfxWhoosh').value=s.WHOOSH||'';q('sfxHit').value=s.HIT||'';q('sfxRiser').value=s.RISER||'';q('sfxCrowd').value=s.CROWD||'';q('sfxSting').value=s.STING||'';const a=p.audioEngine||{};q('audioMode').value=a.mode||'HYBRID';q('audioTheme').value=a.theme||'SAGI_PULSE';q('audioIntensity').value=String(a.intensity||.75);q('audioDucking').value=String(a.ducking==null?.35:a.ducking);q('cueVolume').value=String(a.cueVolume||1);q('countdownBeat').value=a.countdownBeat===false?'0':'1'
}
function syncMatchStage(){
 const p=packageData();q('stingLogo').src=p.eventLogo||assets.crest||'';q('stingLogo').style.visibility=(p.eventLogo||assets.crest)?'visible':'hidden';q('stingCompetition').textContent=p.competition;q('matchCompetitionStage').textContent=p.competition;q('matchRoundStage').textContent=p.round;q('matchHomeStage').textContent=p.home;q('matchAwayStage').textContent=p.away;q('matchKickoffStage').textContent=p.kickoff;q('matchVenueStage').textContent=p.venue;q('countdownSub').textContent=p.competition;
}
function renderPreviews(){q('photoPreview').innerHTML=assets.photo?'<img src="'+assets.photo+'">':'球员';q('mediaPreview').innerHTML=assets.mediaObjectUrl?'<video src="'+assets.mediaObjectUrl+'" muted loop playsinline autoplay></video>':'VIDEO';q('crestPreview').innerHTML=assets.crest?'<img src="'+assets.crest+'" style="object-fit:contain">':'队徽';q('bgPreview').innerHTML=assets.bg?'<img src="'+assets.bg+'">':'球场';q('eventLogoPreview').innerHTML=assets.eventLogo?'<img src="'+assets.eventLogo+'" style="object-fit:contain">':'赛事LOGO';q('musicPreview').textContent=assets.musicObjectUrl?'AUDIO ✓':'MUSIC'}
function starters(){return rawStarters(roster)}
function validStarters(){return effectiveStarters(roster,q('formation').value)}
function substitutes(){return roster.filter(p=>p.squadType==='SUB')}
function addPlayer(){const p=readPlayer(),limit=starterLimit();if(p.squadType==='STARTER'&&starters().length>=limit){note('首发最多'+limit+'人 · '+formatDisplay());return}if(roster.length>=30){note('整份名单最多30人');return}p.id=uid();roster.push(p);teamStore[activeSide].roster=roster;reconcileTeamStarters(activeSide,q('formation').value);selected=roster.length-1;renderRoster();updateFormatUI();dbPut('photo:'+p.id,p.photo||'');if(p.mediaBlob)dbPut('media:'+p.id,p.mediaBlob);note('已加入名单 '+roster.length+'人')}
function updatePlayer(){if(selected<0||!roster[selected]){note('先选择一名球员');return}const p=readPlayer(),wasStarter=(roster[selected].squadType||'STARTER')==='STARTER';if(p.squadType==='STARTER'&&!wasStarter&&starters().length>=starterLimit()){note('首发最多'+starterLimit()+'人 · '+formatDisplay());return}p.id=roster[selected].id;roster[selected]=p;teamStore[activeSide].roster=roster;reconcileTeamStarters(activeSide,q('formation').value);renderRoster();updateFormatUI();dbPut('photo:'+p.id,p.photo||'');if(p.mediaBlob)dbPut('media:'+p.id,p.mediaBlob);else dbDel('media:'+p.id);note('已更新')}
function removePlayer(){if(selected<0)return;const p=roster[selected];roster.splice(selected,1);if(p&&p.id){dbDel('photo:'+p.id);dbDel('media:'+p.id)}teamStore[activeSide].roster=roster;reconcileTeamStarters(activeSide,q('formation').value);selected=Math.min(selected,roster.length-1);if(selected>=0)writePlayer(roster[selected]);renderRoster();updateFormatUI();renderStage(currentGroup);note('已删除')}
function renderRoster(){const w=q('roster');w.innerHTML='';if(!roster.length){w.innerHTML='<div class="muted">当前球队还没有球员。可载入双队示例查看效果。</div>';return}roster.forEach((p,i)=>{const d=document.createElement('div');d.className='playerRow'+(i===selected?' on':'');d.innerHTML='<div class="thumb">'+(p.photo?'<img src="'+p.photo+'">':p.role)+'</div><div><div class="pname">'+esc(p.name)+(p.captain?' <span style="color:#d8b55b">C</span>':'')+'</div><div class="pmeta">'+(p.squadType==='SUB'?'SUB · ':'')+esc(p.role)+' · '+esc(p.position)+(p.statValue?' · '+esc(p.statLabel)+' '+esc(p.statValue):'')+((p.mediaBlob||p.mediaUrl)?' · MEDIA '+(p.directorSpeed||1)+'×'+(p.directorFreeze?' · FREEZE':''):'')+'</div></div><div class="num">'+esc(p.number)+'</div>';d.onclick=()=>{selected=i;writePlayer(p);renderRoster()};w.appendChild(d)})}
function grouped(role){return validStarters().filter(p=>p.role===role)}
function getFormationPoints(){return getFormationPointsFor(activeSide,q('formation').value)}
function fallbackPoint(role,i,n){const y={GK:91,DF:72,MF:48,FW:22}[role]||50;return[((i+1)/(n+1))*100,y]}
function renderFormation(activeRole){
 q('formationText').textContent=q('formation').value;const box=q('formationNodes');box.innerHTML='';getFormationPoints().forEach(({p,role,xy,key})=>{const n=document.createElement('div');n.className='node'+((activeRole==='FULL'||activeRole===role)?' active':'')+(p.captain?' captainNode':'');n.style.left=xy[0]+'%';n.style.top=xy[1]+'%';n.dataset.playerKey=key;n.innerHTML='<span>'+esc(p.number)+'</span><small>'+esc(p.name)+'</small>';if(formationEditorActive)n.addEventListener('pointerdown',e=>beginFormationDrag(e,n,key));box.appendChild(n)});updateFormationEditorUI()
}
function mediaSource(p){return p.mediaObjectUrl||p.mediaUrl||''}
function directorAttrs(p){
 return ' data-in="'+(Number(p.directorIn)||0)+'" data-out="'+(Number(p.directorOut)||0)+'" data-speed="'+(Number(p.directorSpeed)||1)+'" data-freeze="'+(p.directorFreeze?'1':'0')+'" data-freezems="'+(Number(p.directorFreezeMs)||1000)+'" data-camera="'+esc(p.directorCamera||'MEDIUM')+'"';
}
function playerCard(p,n){
 const one=n===1?' one':'',media=mediaSource(p),action=' action-'+esc(p.mediaAction||'STANDARD'),hasMedia=media?' hasMedia':'',directed=media?' directed':'';
 const fallback=p.photo?'<img src="'+p.photo+'">':'<div class="fallback">'+esc(p.number)+'</div>';
 const visual=media?'<div class="mediaFallback">'+fallback+'</div><video class="mediaVideo" src="'+esc(media)+'" muted playsinline preload="auto"'+directorAttrs(p)+'></video>':fallback;
 const dirTag=media?'<div class="directorBadge">IN '+(Number(p.directorIn)||0).toFixed(1)+' · '+(Number(p.directorSpeed)||1).toFixed(2)+'×'+(p.directorFreeze?' · FREEZE':'')+'</div>':'';
 return '<div class="playerCard'+one+hasMedia+action+directed+'"><div class="playerCut">'+visual+'</div><div class="playerLabel"><div class="playerNo">#'+esc(p.number)+(p.captain?'<span class="captainBadge">C</span>':'')+'</div><div class="playerName">'+esc(p.name)+'</div><div class="playerRole">'+esc(p.position||p.role)+'</div>'+(p.statValue?'<div class="statPill">'+esc(p.statLabel)+' <strong>'+esc(p.statValue)+'</strong></div>':'')+(media?'<div class="mediaTag">MEDIA DAY · '+esc(p.mediaAction||'STANDARD')+'</div>':'')+dirTag+'</div></div>'
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
 q('playersArea').style.display='none';q('subList').style.display='none';const list=q('fullList');list.style.display='grid';list.innerHTML=validStarters().map(p=>'<div class="fullRow"><div class="fullRole">'+esc(p.role)+'</div><div class="fullNo">'+esc(p.number)+'</div><div class="fullName">'+esc(p.name)+(p.captain?' <span class="captainBadge">C</span>':'')+'</div><div class="fullPos">'+esc(p.position)+(p.statValue?' · '+esc(p.statLabel)+' '+esc(p.statValue):'')+'</div></div>').join('');

}
function renderSubs(){
 q('playersArea').style.display='none';q('fullList').style.display='none';const list=q('subList');list.style.display='grid';
 const subs=substitutes();list.innerHTML=subs.length?subs.map(p=>'<div class="subRow"><div class="subNo">#'+esc(p.number)+'</div><div><div class="subName">'+esc(p.name)+'</div><div class="subStat">'+esc(p.role)+' · '+esc(p.position)+'</div></div><div class="subStat">'+(p.statValue?esc(p.statLabel)+' '+esc(p.statValue):'SUB')+'</div></div>').join(''):'<div class="muted">暂无替补球员</div>';
}
function updateTunnelLabels(group){
 const team=currentTeamName(),left=q('ledLeft'),right=q('ledRight'),lineup=startingLabel();
 const role={TEAM:lineup,GK:'GOALKEEPER',DF:'DEFENDERS',MF:'MIDFIELDERS',FW:'FORWARDS',FULL:'FORMATION',SUB:'SUBSTITUTES'}[group]||lineup;
 left.innerHTML=esc(team)+'<small>'+role+'</small>';
 right.innerHTML=(group==='TEAM'?'SAGI':(ROLE_NAMES[group]||group))+'<small>'+esc(q('formation').value)+'</small>';
}
function applyVisualGroup(group){
 const st=q('stage'),area=q('playersArea'),code=q('roleBackdrop');updateTunnelLabels(group);
 st.classList.remove('group-GK','group-DF','group-MF','group-FW','group-TEAM','group-FULL','group-SUB','group-STING','group-MATCH','group-COUNTDOWN','tunnel-open');
 st.classList.add('group-'+group);if(group==='FULL')st.classList.add('tunnel-open');
 area.className='playersArea layout-'+group;
 const codes={STING:'SAGI',MATCH:'MATCH',COUNTDOWN:'5',TEAM:starterCode(),GK:'GK',DF:'DEF',MF:'MID',FW:'FWD',FULL:starterCode(),SUB:'SUB'};
 code.textContent=codes[group]||starterCode();
 const packageGroup=['STING','MATCH','COUNTDOWN'].includes(group);q('roleGlow').style.display=(group==='FULL'||group==='SUB'||packageGroup)?'none':'block';code.style.display=(group==='FULL'||group==='SUB'||packageGroup)?'none':'flex';
}
function renderStage(group){
 currentGroup=group||'TEAM';applyVisualGroup(currentGroup);syncMatchStage();['stingOverlay','matchOverlay','countdownOverlay'].forEach(id=>q(id).classList.remove('on'));q('stageTeam').textContent=currentTeamName();q('stageCrest').src=assets.crest||'';q('stageCrest').style.visibility=assets.crest?'visible':'hidden';q('stadiumPhoto').src=assets.bg||'';q('stadiumPhoto').className='stadiumPhoto'+(assets.bg?' on':'');q('fullList').style.display='none';q('subList').style.display='none';q('playersArea').style.display='flex';
 const lineupLabel=startingLabel();q('stageLineupLabel').textContent=lineupLabel;let title=lineupLabel,name='TEAM LINEUP',players=[];
 if(group==='STING'){title='MATCH SHOW';name='赛事Logo';q('playersArea').style.display='none';q('stingOverlay').classList.add('on')}
 else if(group==='MATCH'){title='MATCH SHOW';name='比赛信息';q('playersArea').style.display='none';q('matchOverlay').classList.add('on')}
 else if(group==='COUNTDOWN'){title='MATCH SHOW';name='开场倒计时';q('playersArea').style.display='none';q('countdownOverlay').classList.add('on')}
 else if(group==='TEAM'){title='SAGI BROADCAST';name=currentTeamName()+' · '+q('formation').value;players=[]}
 else if(group==='FULL'){title=lineupLabel;name='FULL LINEUP';renderFull()} else if(group==='SUB'){title='SQUAD';name='SUBSTITUTES';renderSubs()}
 else{title=lineupLabel;name=ROLE_NAMES[group]||group;players=grouped(group);q('playersArea').innerHTML=players.map(p=>playerCard(p,players.length)).join('')}
 q('groupTitle').textContent=title;q('groupName').textContent=name;
 if(group==='TEAM')q('playersArea').innerHTML='<div style="align-self:center;text-align:center;color:#ffffff52;font-weight:1000;font-size:138px;letter-spacing:10px;text-shadow:0 18px 45px #000">'+esc(q('formation').value)+'</div>';
 renderFormation(['TEAM','STING','MATCH','COUNTDOWN'].includes(group)?'':group);applyOutputBackground();setTimeout(playMediaVideos,0)
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
     frames=[{opacity:0,transform:'translate('+dir+'px,42px) scale(.9)'},{opacity:1,transform:'translate(0,0) scale(1)'}];
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
  const card=q('matchOverlay').querySelector('.matchCardStage');if(card&&card.animate)card.animate([{opacity:0,transform:'translateY(45px) scale(.97)'},{opacity:1,transform:'translateY(0) scale(1)'}],{duration:720,fill:'forwards',easing:'ease-out'})
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
 const state={commandId:Date.now()+'_'+Math.random().toString(36).slice(2,6),group,side:activeSide,team:currentTeamName(),formation:q('formation').value,matchFormat:{mode:matchConfig.mode,playerCount:starterLimit()},playerCount:starterLimit(),startingLabel:startingLabel(),players:compactPlayersForGroup(group),formationLayout:currentFormationLayoutPayload(),allPlayers:validStarters().map(p=>({id:p.id,layoutKey:formationPlayerKey(p),name:p.name,number:p.number,role:p.role,position:p.position,captain:!!p.captain,statLabel:p.statLabel||'',statValue:p.statValue||'',mediaUrl:p.mediaUrl||'',mediaAction:p.mediaAction||'STANDARD',directorIn:Number(p.directorIn)||0,directorOut:Number(p.directorOut)||0,directorSpeed:Number(p.directorSpeed)||1,directorFreeze:!!p.directorFreeze,directorFreezeMs:Number(p.directorFreezeMs)||1000,directorCamera:p.directorCamera||'MEDIUM'})),substitutes:substitutes().map(p=>({name:p.name,number:p.number,role:p.role,position:p.position,statLabel:p.statLabel||'',statValue:p.statValue||''})),crest:assets.crest||'',stadium:assets.bg||'',background:q('outputBg').value,visualVersion:'V4.6.5-FORMATION-EDITOR',duration,show:show||null,package:packageData(),startedAt:new Date().toISOString()};
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
function showTransitionOptions(v){return ['CUT','FADE','SLIDE','ZOOM','FLASH'].map(x=>'<option'+(x===v?' selected':'')+'>'+x+'</option>').join('')}
function showCueOptions(v){return ['NONE','WHOOSH','HIT','RISER','CROWD','STING'].map(x=>'<option'+(x===v?' selected':'')+'>'+x+'</option>').join('')}
function renderShowTimeline(){
 const w=q('showTimeline');if(!w)return;w.innerHTML='';
 showSteps.forEach((s,i)=>{const d=document.createElement('div');d.className='showStep'+(i===showIndex?' active':'')+(s.enabled?'':' disabled');d.dataset.i=i;
   d.innerHTML='<div class="showIndex">'+(i+1)+'</div><div class="showName">'+esc(s.label)+'</div>'+
   '<input class="showDur" type="number" min="0.5" max="30" step="0.5" value="'+((Number(s.duration)||1000)/1000).toFixed(1)+'">'+
   '<select class="showTransition">'+showTransitionOptions(s.transition)+'</select>'+
   '<select class="showCue">'+showCueOptions(s.cue)+'</select>'+
   '<label class="showEnable"><input type="checkbox" '+(s.enabled?'checked':'')+'></label>'+
   '<div class="showMove"><button class="up" type="button">↑</button><button class="down" type="button">↓</button></div>';
   d.querySelector('.showDur').onchange=e=>{s.duration=Math.max(500,Math.round((parseFloat(e.target.value)||1)*1000));renderShowSummary()};
   d.querySelector('.showTransition').onchange=e=>s.transition=e.target.value;
   d.querySelector('.showCue').onchange=e=>s.cue=e.target.value;
   d.querySelector('.showEnable input').onchange=e=>{s.enabled=e.target.checked;renderShowTimeline()};
   d.querySelector('.up').onclick=()=>moveShowStep(i,-1);d.querySelector('.down').onclick=()=>moveShowStep(i,1);w.appendChild(d)
 });
 renderShowSummary()
}
function renderShowSummary(){
 const total=showTotalMs(),el=q('showTotal');if(el)el.textContent=(total/1000).toFixed(1)+'s';
}
function moveShowStep(i,dir){const j=i+dir;if(j<0||j>=showSteps.length)return;[showSteps[i],showSteps[j]]=[showSteps[j],showSteps[i]];if(showIndex===i)showIndex=j;else if(showIndex===j)showIndex=i;renderShowTimeline()}
function resetShow(){stopShow(false);showSteps=DEFAULT_SHOW.map(x=>({...x}));showIndex=-1;renderShowTimeline();note('节目时间线已恢复默认')}
function saveShow(){localStorage.setItem('sagi_show_director_v40',JSON.stringify(showSteps));note('节目时间线已保存')}
function loadShow(){try{let x=JSON.parse(localStorage.getItem('sagi_show_director_v40')||'null');if(!x){try{x=JSON.parse(localStorage.getItem('sagi_show_director_v36')||'null')}catch(_){}}if(Array.isArray(x)&&x.length)showSteps=normalizeShowSteps(x);else showSteps=normalizeShowSteps(DEFAULT_SHOW);}catch(e){showSteps=normalizeShowSteps(DEFAULT_SHOW)}renderShowTimeline()}
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
function stopShowMusic(){const a=ensureShowMusic.audio;if(a){try{a.pause();a.currentTime=0}catch(e){}}builtInThemeStop();q('audioStatus').textContent='AUDIO READY';q('audioEngineState').textContent='ENGINE READY';pulseMeter('masterMeter',0,10);pulseMeter('cueMeter',0,10)}
function triggerCue(cue){
 const b=q('cueBadgeStage');if(!b||cue==='NONE')return;q('stage').dataset.cue=cue;b.textContent=cue;b.animate([{opacity:0,transform:'translateY(-8px)'},{opacity:1,transform:'translateY(0)',offset:.25},{opacity:0}],{duration:900,easing:'ease-out'});
 const s=audioSettings();q('stage').dataset.cueSource='none';if(s.mode==='MUTE')return;const real=audioSrcForCue(cue);if((s.mode==='HYBRID'||s.mode==='EXTERNAL')&&real){q('stage').dataset.cueSource='real';duckMusic();pulseMeter('cueMeter',s.cueVolume,.7);playAudioUrl(real,s.cueVolume);return}
 if(s.mode!=='EXTERNAL'){q('stage').dataset.cueSource='builtin';builtInCue(cue,1)}
}
function showProgressTick(step,duration){
 const bar=q('showProgressBar'),now=q('showNow');showStartedAt=performance.now();
 const tick=()=>{if(!playing||showSteps[showIndex]!==step)return;const p=Math.min(1,(performance.now()-showStartedAt)/duration);if(bar)bar.style.width=(p*100).toFixed(1)+'%';if(now)now.innerHTML='<b>'+esc(step.label)+'</b> · '+((duration-(performance.now()-showStartedAt))/1000).toFixed(1)+'s';if(p<1)requestAnimationFrame(tick)};tick()
}
function showMeta(step){const en=showEnabled(),pos=en.indexOf(step);return{sessionId:showSession,stepIndex:showIndex,sequenceIndex:pos,stepTotal:en.length,label:step.label,side:step.side||activeSide,transition:step.transition,cue:step.cue,autoNext:true,isFirst:pos===0,isLast:pos===en.length-1}}
function runShowStep(i){
 if(!playing)return;
 while(i<showSteps.length&&!showSteps[i].enabled)i++;
 if(i>=showSteps.length){playing=false;showIndex=-1;stopCountdown();stopShowMusic();q('status').textContent='节目播放结束';q('showNow').textContent='COMPLETE';q('showProgressBar').style.width='100%';renderShowTimeline();return}
 showIndex=i;const s=showSteps[i],d=Math.max(500,Number(s.duration)||1000);if(s.side&&s.side!==activeSide)switchTeam(s.side,{silent:true,noRender:true});renderShowTimeline();broadcastProgramFromShow(s,d);applyShowTransition(s.transition);triggerCue(s.cue);renderStage(s.group);animateStage();animatePackageGroup(s.group,d);showProgressTick(s,d);q('status').textContent='SHOW '+(i+1)+' / '+showSteps.length+' · '+s.label;publishGroup(s.group,d,showMeta(s));clearTimeout(showTimer);if(!broadcastHold)showTimer=setTimeout(()=>runShowStep(i+1),d)
}
function startShow(){if(!requireMatchReady())return;if(roster.length<1){note('请先加入球员');return}stopShow(false);playing=true;showSession=Date.now().toString(36);ensureShowMusic();focusAndRun(()=>runShowStep(0))}
function stopShow(update=true){playing=false;clearTimeout(showTimer);clearTimeout(seqTimer);stopCountdown();stopShowMusic();if(update){q('status').textContent='节目已停止';q('showNow').textContent='STOPPED'}renderShowTimeline()}
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
 for(const side of ['HOME','AWAY'])for(const p of teamStore[side].roster){await dbPut('photo:'+p.id,p.photo||'');if(p.mediaBlob)await dbPut('media:'+p.id,p.mediaBlob);else await dbDel('media:'+p.id)}
 await dbPut('crest:HOME',teamStore.HOME.crest||'');await dbPut('crest:AWAY',teamStore.AWAY.crest||'');await dbPut('stadium',assets.bg||'');await dbPut('eventLogo',assets.eventLogo||'');
 if(assets.musicBlob)await dbPut('showMusic',assets.musicBlob);else await dbDel('showMusic');
 localStorage.setItem('sagi_player_intro_v40',JSON.stringify({activeSide:snapshot.activeSide,matchConfig:snapshot.matchConfig,package:snapshot.package,teams:snapshot.teams}));
 localStorage.setItem('sagi_show_director_v40',JSON.stringify(snapshot.show));
 note('V4.6.5 双队阵容、音频与节目已保存')
}
async function hydrateRoster(list=[]){const out=[];for(const p of list){p.photo=await dbGet('photo:'+p.id);p.mediaBlob=await dbGet('media:'+p.id);p.mediaObjectUrl=p.mediaBlob instanceof Blob?URL.createObjectURL(p.mediaBlob):'';p.mediaAction=p.mediaAction||'STANDARD';p.directorIn=Number(p.directorIn)||0;p.directorOut=Number(p.directorOut)||0;p.directorSpeed=Number(p.directorSpeed)||1;p.directorFreeze=!!p.directorFreeze;p.directorFreezeMs=Number(p.directorFreezeMs)||1000;p.directorCamera=p.directorCamera||'MEDIUM';out.push(p)}return out}
async function load(){
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
  switchTeam(x.activeSide||'HOME',{silent:true,skipStash:true});renderPreviews();renderShowTimeline();syncMatchStage();note('V4.6.5 双队阵容、音频与节目已读取')
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
 writePackage({matchFormat:{...matchConfig},competition:'TFC WINTER LEAGUE',round:'MATCHDAY 01',home:'TARLAN FC',away:'ICE POINT FC',kickoff:'20:00',venue:'TACHENG',musicVolume:.65,audioEngine:{mode:'HYBRID',theme:'SAGI_PULSE',intensity:.75,ducking:.35,cueVolume:1,countdownBeat:true},sfx:{}});
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
 broadcastHold=!broadcastHold;
 q('holdBtn').classList.toggle('on',broadcastHold);q('holdBtn').textContent=broadcastHold?'继续':'保持';
 if(broadcastHold){clearTimeout(showTimer);q('status').textContent='保持中 · 当前播出画面不变';}
 else{q('status').textContent='已继续 · 准备就绪';if(playing&&showIndex>=0)runShowStep(showIndex+1)}
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
 q('goLiveBtn').onclick=takeBroadcastLive;q('holdBtn').onclick=toggleBroadcastHold;q('prevLiveBtn').onclick=()=>stepBroadcastPreview(-1);q('nextLiveBtn').onclick=()=>stepBroadcastPreview(1);q('clearAllBtn').onclick=clearBroadcastAll;
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
q('addBtn').onclick=addPlayer;q('updateBtn').onclick=updatePlayer;q('removeBtn').onclick=removePlayer;q('saveBtn').onclick=save;q('loadBtn').onclick=load;q('demoBtn').onclick=demo;
q('teamBtn').onclick=()=>setBroadcastPreview('TEAM',activeSide,bcLabel('TEAM',activeSide),2500);q('gkBtn').onclick=()=>setBroadcastPreview('GK',activeSide,bcLabel('GK',activeSide),3000);q('dfBtn').onclick=()=>setBroadcastPreview('DF',activeSide,bcLabel('DF',activeSide),4000);q('mfBtn').onclick=()=>setBroadcastPreview('MF',activeSide,bcLabel('MF',activeSide),4000);q('fwBtn').onclick=()=>setBroadcastPreview('FW',activeSide,bcLabel('FW',activeSide),4000);q('fullBtn').onclick=()=>setBroadcastPreview('FULL',activeSide,bcLabel('FULL',activeSide),6000);q('subsBtn').onclick=()=>setBroadcastPreview('SUB',activeSide,bcLabel('SUB',activeSide),5000);q('showPlayBtn').onclick=startShow;q('showPrevBtn').onclick=prevShow;q('showNextBtn').onclick=nextShow;q('stopBtn').onclick=stopShow;q('showResetBtn').onclick=resetShow;q('showSaveBtn').onclick=saveShow;q('copyVmixBtn').onclick=copyVmix;
q('matchFormat').onchange=()=>setMatchFormatFromUI();q('customPlayerCount').onchange=()=>{if(q('matchFormat').value==='CUSTOM')setMatchFormatFromUI()};q('applyCustomFormationBtn').onclick=applyCustomFormation;q('squadType').onchange=updateFormatUI;
q('formation').onchange=()=>{teamStore[activeSide].formation=q('formation').value;const r=reconcileTeamStarters(activeSide,q('formation').value);roster=teamStore[activeSide].roster||roster;renderRoster();updateFormatUI();updateFormationEditorUI();renderStage(currentGroup);refreshMatchdayPlayers();if(matchReady){matchReady=false;setupReadySignature='';refreshSetupReadyUI()}note('阵型已切换 '+q('formation').value+(r.changed?' · '+syncSummary(r):''))};q('teamName').oninput=()=>{if(activeSide==='HOME')q('matchHome').value=q('teamName').value;else q('matchAway').value=q('teamName').value;renderStage(currentGroup)};q('outputBg').onchange=()=>renderStage(currentGroup);
['matchCompetition','matchRound','matchKickoff','matchVenue'].forEach(id=>q(id).oninput=syncMatchStage);q('matchHome').oninput=()=>{if(activeSide==='HOME')q('teamName').value=q('matchHome').value;syncMatchStage()};q('matchAway').oninput=()=>{if(activeSide==='AWAY')q('teamName').value=q('matchAway').value;syncMatchStage()};
['audioMode','audioTheme','audioIntensity','audioDucking','cueVolume','countdownBeat'].forEach(id=>q(id).onchange=()=>{q('audioEngineState').textContent=q('audioMode').value+' · '+q('audioTheme').value.replaceAll('_',' ')});
window.addEventListener('resize',resize);renderPreviews();renderRoster();loadShow();applyStoredMatchConfig({mode:'11',playerCount:11},true);refreshFormationOptions('4-3-3');demo();refreshSideUI();updateFormatUI();syncMatchStage();renderStage('TEAM');resize();initBroadcastControl();initMatchdayGraphics();initVmixDirector();initMatchSetup();initFormationEditor();setBroadcastPreview('TEAM','HOME','主队开场',2500);
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

if(false&&'serviceWorker' in navigator){
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
})();
</script>

<script>
(function(){
 const btn=document.getElementById('mobileUpdateBtn'),status=document.getElementById('mobileUpdateStatus');
 if(!btn||!status)return;
 btn.addEventListener('click',async()=>{
   if(btn.disabled)return;
   btn.disabled=true;btn.classList.add('busy');btn.textContent='正在更新…';status.textContent='正在获取最新版';
   try{
     const r=await fetch('/api/update',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',cache:'no-store'});
     const x=await r.json().catch(()=>({}));
     if(!r.ok||!x.ok)throw new Error(x.error||('HTTP '+r.status));
     status.textContent='更新成功 · 正在刷新';
     btn.textContent='更新完成 ✓';
     setTimeout(()=>location.replace('/?updated='+Date.now()),650);
   }catch(e){
     status.textContent='更新失败 · 当前版本继续可用';
     btn.textContent='↻ 重新更新';btn.disabled=false;btn.classList.remove('busy');
   }
 });
})();
</script>
</body></html>
###SAGI_OUTPUT###
<!doctype html>
<html lang="zh-CN"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SAGI V4.6.5 · PREMIUM SCOREBUG · MOBILE UPDATE · LAN DIRECT · vMix</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2214%22 fill=%22%2307090d%22/%3E%3Ctext x=%2232%22 y=%2243%22 text-anchor=%22middle%22 font-size=%2234%22 fill=%22%23d8b55b%22%3ES%3C/text%3E%3C/svg%3E">
<style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent;font-family:Arial,"PingFang SC","Microsoft YaHei",sans-serif}.stage{position:absolute;left:0;top:0;width:1920px;height:1080px;overflow:hidden;background:#07090c;transform-origin:0 0}.stadium{position:absolute;inset:0;background:radial-gradient(circle at 50% 0,#6f8294 0,#263442 18%,#111820 42%,#06080b 74%)}.stadium:before{content:"";position:absolute;left:-5%;right:-5%;top:165px;height:300px;background:linear-gradient(#19212a,#0b1016 68%,transparent),repeating-linear-gradient(90deg,#ffffff08 0 7px,transparent 7px 22px);clip-path:polygon(0 0,100% 0,92% 100%,8% 100%)}.stadium:after{content:"";position:absolute;left:0;right:0;bottom:-35px;height:430px;background:linear-gradient(180deg,#173421,#0a2716 70%,#05130a);clip-path:polygon(20% 0,80% 0,100% 100%,0 100%)}.stadiumPhoto{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:none}.shade{position:absolute;inset:0;background:linear-gradient(90deg,#030508e6 0,#05070a99 38%,#05070a55 58%,#030508c9 100%),linear-gradient(0deg,#040609c7 0,transparent 55%,#03050775 100%)}.pitchLines{position:absolute;left:320px;right:320px;bottom:0;height:360px;opacity:.22;transform:perspective(800px) rotateX(62deg);transform-origin:bottom;border:5px solid #fff;border-bottom:0}.pitchLines:before{content:"";position:absolute;left:50%;top:0;bottom:0;border-left:4px solid #fff}.pitchLines:after{content:"";position:absolute;width:170px;height:170px;border:4px solid #fff;border-radius:50%;left:50%;top:45%;transform:translate(-50%,-50%)}.light{position:absolute;width:760px;height:760px;border-radius:50%;filter:blur(100px);opacity:.22}.l1{left:-180px;top:-330px;background:#5cb4ff}.l2{right:-220px;top:-300px;background:#d7b051}.header{position:absolute;left:95px;top:72px;display:flex;align-items:center;gap:24px}.crest{width:96px;height:96px;object-fit:contain;filter:drop-shadow(0 12px 20px #0009)}.team{font-size:34px;font-weight:950;letter-spacing:2px;color:#fff}.sub{font-size:17px;color:#d8b55b;letter-spacing:5px;margin-top:7px;font-weight:850}.groupTitle{position:absolute;left:100px;top:205px;font-size:28px;letter-spacing:7px;color:#d8b55b;font-weight:900}.groupName{position:absolute;left:95px;top:245px;font-size:72px;line-height:1;font-weight:1000;letter-spacing:-2px;color:#fff}.line{position:absolute;left:98px;top:330px;width:400px;height:5px;background:linear-gradient(90deg,#d8b55b,#fff1b7)}.players{position:absolute;left:70px;top:350px;width:1240px;height:650px;display:flex;align-items:flex-end;justify-content:center;gap:18px}.card{position:relative;width:230px;height:570px;flex:0 0 auto}.card.one{width:520px}.cut{position:absolute;left:0;right:0;bottom:82px;height:490px;display:flex;align-items:flex-end;justify-content:center}.cut img{width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 20px 25px #000d)}
.mediaVideo{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;object-position:center bottom;filter:drop-shadow(0 20px 25px #000d);z-index:2;background:transparent}
.mediaFallback{position:absolute;inset:0;display:flex;align-items:flex-end;justify-content:center;z-index:1}
.card.hasMedia .cut:after{content:"MEDIA DAY";position:absolute;right:8%;top:8%;z-index:4;font-size:10px;font-weight:1000;letter-spacing:2px;color:#f3d77f;background:#07090db8;border:1px solid #d8b55b66;border-radius:999px;padding:6px 9px}
.card.action-WALK_IN .mediaVideo{transform:scale(1.08);transform-origin:center bottom}
.card.action-ARMS .mediaVideo{transform:scale(1.03)}
.card.action-LOOK .mediaVideo{transform:scale(1.05)}
.card.action-GK_GLOVES .mediaVideo{transform:scale(1.07)}
.card.action-CELEBRATE .mediaVideo{transform:scale(1.08)}
.mediaTag{display:inline-flex;align-items:center;gap:6px;margin-top:6px;padding:4px 8px;border-radius:999px;background:#d8b55b17;border:1px solid #d8b55b3d;color:#e9cd78;font-size:10px;font-weight:900;letter-spacing:1px}
.directorBadge{display:inline-flex;align-items:center;margin-top:5px;padding:4px 7px;border-radius:999px;background:#ffffff0b;border:1px solid #d8b55b45;color:#d8b55b;font-size:9px;font-weight:900;letter-spacing:.6px}
.card.directed .cut:before{content:"DIRECTOR";position:absolute;left:8%;top:8%;z-index:5;font-size:9px;font-weight:1000;letter-spacing:1.5px;color:#fff;background:#000a;border:1px solid #ffffff25;border-radius:999px;padding:5px 8px}
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
.formation{position:absolute;right:78px;top:175px;width:500px;height:760px;border:1px solid #ffffff20;border-radius:32px;background:#05080cc7;padding:28px}.formationHead{display:flex;justify-content:space-between}.formationTitle{font-size:25px;font-weight:950;color:#fff}.formationText{font-size:42px;color:#d8b55b;font-weight:1000}.pitch{position:absolute;left:34px;right:34px;top:120px;bottom:34px;border:3px solid #ffffff50;background:linear-gradient(#123d25,#0e321e);overflow:hidden}.pitch:before{content:"";position:absolute;left:0;right:0;top:50%;border-top:2px solid #ffffff55}.pitch:after{content:"";position:absolute;width:115px;height:115px;border:2px solid #ffffff55;border-radius:50%;left:50%;top:50%;transform:translate(-50%,-50%)}.boxTop,.boxBottom{position:absolute;left:50%;width:220px;height:90px;transform:translateX(-50%);border:2px solid #ffffff55}.boxTop{top:-2px}.boxBottom{bottom:-2px}.nodes{position:absolute;inset:0}.node{position:absolute;width:54px;height:54px;border-radius:50%;transform:translate(-50%,-50%);background:#161e28;border:2px solid #ffffff75;display:flex;align-items:center;justify-content:center;font-weight:1000;font-size:15px;color:#fff}.node.active{background:#d8b55b;color:#111;border-color:#fff3b8;box-shadow:0 0 0 8px #d8b55b22}.node small{position:absolute;top:58px;font-size:9px;color:#cbd1d9;white-space:nowrap;max-width:86px;overflow:hidden;text-overflow:ellipsis}.fullList{position:absolute;left:95px;top:355px;width:1130px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px 28px}.fullRow{display:grid;grid-template-columns:54px 56px 1fr auto;gap:10px;align-items:center;border-bottom:1px solid #ffffff12;padding:8px 4px;color:#fff}.fullRole{font-size:12px;color:#d8b55b;font-weight:900}.fullNo{font-size:25px;font-weight:1000}.fullName{font-size:22px;font-weight:900}.fullPos{font-size:11px;color:#98a1ad}

.captainBadge{display:inline-flex;align-items:center;justify-content:center;min-width:30px;height:30px;border-radius:50%;background:#d8b55b;color:#111;font-size:14px;font-weight:1000;margin-left:7px;vertical-align:middle}
.statPill{display:inline-flex;align-items:center;gap:7px;margin-top:8px;padding:6px 10px;border-radius:999px;background:#ffffff0d;border:1px solid #ffffff1b;color:#d8b55b;font-size:11px;font-weight:900;letter-spacing:1px}
.subList{position:absolute;left:95px;top:355px;width:1130px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px 28px}
.subRow{display:grid;grid-template-columns:56px 1fr auto;gap:12px;align-items:center;border-bottom:1px solid #ffffff12;padding:10px 5px;color:#fff}
.subNo{font-size:24px;font-weight:1000;color:#d8b55b}.subName{font-size:21px;font-weight:900}.subStat{font-size:11px;color:#aab2be}
.captainNode:after{content:'C';position:absolute;right:-6px;top:-7px;width:19px;height:19px;border-radius:50%;background:#fff1b7;color:#111;font-size:10px;display:flex;align-items:center;justify-content:center;font-weight:1000}

/* ===== V4.6 PREMIUM SCOREBUG ===== */
.graphicsStage{position:absolute;left:0;top:0;width:1920px;height:1080px;transform-origin:0 0;overflow:hidden;pointer-events:none;color:#fff;z-index:9999}
.scoreBug{--home:#d8b55b;--away:#4c7dff;--accent:#f4f0e8;position:absolute;left:50%;top:38px;transform:translateX(-50%);display:none;height:78px;border-radius:18px;background:linear-gradient(180deg,#121820f5,#070a0ef7);border:1px solid #ffffff24;box-shadow:0 18px 50px #000a,0 1px 0 #ffffff14 inset;overflow:hidden;align-items:stretch;font-weight:900;backdrop-filter:blur(16px)}
.scoreBug.on{display:flex}
.scoreBug:after{content:'SAGI LIVE';position:absolute;left:50%;top:-1px;transform:translateX(-50%);font-size:8px;letter-spacing:2.5px;color:#0a0d11;background:var(--accent);padding:2px 8px 3px;border-radius:0 0 7px 7px;font-weight:1000}
.sbTeam{position:relative;min-width:245px;max-width:330px;padding:0 28px;display:flex;align-items:center;justify-content:center;font-size:20px;letter-spacing:.4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;background:#0e131a;color:#fff}
.sbTeam.home{border-left:7px solid var(--home);box-shadow:18px 0 34px -28px var(--home) inset}
.sbTeam.away{border-right:7px solid var(--away);box-shadow:-18px 0 34px -28px var(--away) inset}
.sbTeam.home:after,.sbTeam.away:after{content:'';position:absolute;bottom:0;height:3px;width:68%;opacity:.95}
.sbTeam.home:after{left:14%;background:var(--home)}
.sbTeam.away:after{right:14%;background:var(--away)}
.sbScore{width:78px;display:flex;align-items:center;justify-content:center;font-size:38px;font-weight:1000;background:#f7f8fa;color:#090c10;text-shadow:none}
#sbHomeScore{box-shadow:inset 0 -5px 0 var(--home)}
#sbAwayScore{box-shadow:inset 0 -5px 0 var(--away)}
.sbMid{width:132px;display:flex;flex-direction:column;align-items:center;justify-content:center;background:linear-gradient(180deg,#161d26,#0b1016);border-left:1px solid #ffffff10;border-right:1px solid #ffffff10}
.sbClock{font-size:23px;font-variant-numeric:tabular-nums;letter-spacing:1px;color:#fff}
.sbPeriod{font-size:9px;color:var(--accent);letter-spacing:2.4px;margin-top:4px;font-weight:1000}
.eventCard{position:absolute;left:78px;bottom:72px;width:760px;min-height:176px;background:linear-gradient(115deg,#080b10f5,#111923f2);border:1px solid #ffffff23;border-left:8px solid #d8b55b;border-radius:8px;box-shadow:0 24px 75px #000b;display:none;align-items:center;padding:28px 34px;gap:26px}
.eventCard.on{display:flex}.eventIcon{width:104px;height:104px;border-radius:14px;display:flex;align-items:center;justify-content:center;background:#d8b55b;color:#0a0c0f;font-size:54px;font-weight:1000}.eventCard.yellow .eventIcon{background:#f2d536}.eventCard.red .eventIcon{background:#db3038;color:#fff}.eventCard.sub .eventIcon{background:#2786b5;color:#fff}
.eventKicker{font-size:15px;font-weight:1000;letter-spacing:5px;color:#d8b55b}.eventName{font-size:42px;font-weight:1000;margin-top:7px}.eventMeta{font-size:16px;color:#b4bdc8;margin-top:8px;letter-spacing:1px}.eventCard.yellow{border-left-color:#f2d536}.eventCard.red{border-left-color:#db3038}.eventCard.sub{border-left-color:#2786b5}
.subRows{display:grid;gap:8px;margin-top:8px}.subRowG{font-size:25px;font-weight:950}.subRowG.in{color:#72d99c}.subRowG.out{color:#ef777d}.subArrow{font-size:17px;margin-right:10px}
.stateSplash{position:absolute;inset:0;display:none;align-items:center;justify-content:center;background:radial-gradient(circle at center,#0f151ddd,#020304f5 72%)}.stateSplash.on{display:flex}.stateBox{min-width:900px;text-align:center;padding:55px 70px;border:1px solid #ffffff22;background:#070b10e8;box-shadow:0 30px 100px #000c}.stateKicker{font-size:20px;letter-spacing:8px;color:#d8b55b;font-weight:1000}.stateTitle{font-size:92px;font-weight:1000;margin-top:12px;letter-spacing:-3px}.stateScore{font-size:74px;font-weight:1000;margin-top:25px}.stateTeams{font-size:22px;color:#aab4c0;margin-top:10px}.mvpName{font-size:82px;font-weight:1000;margin-top:18px}.mvpMeta{font-size:24px;color:#d8b55b;margin-top:8px;letter-spacing:3px}

</style></head>
<body>
<div id="stage" class="stage"><div id="transitionLayer" class="transitionLayer"></div><div id="cueBadgeStage" class="cueBadgeStage"></div><div id="showStepStage" class="showStepStage"></div><div id="sideBadgeStage" class="sideBadgeStage">HOME</div>
  <div id="stingOverlay" class="stingOverlay"><div class="stingCore"><img id="stingLogo" class="stingLogo"><div class="stingLine"></div><div id="stingCompetition" class="stingComp">SAGI FOOTBALL</div></div></div>
  <div id="matchOverlay" class="matchOverlay"><div class="matchCardStage"><div id="matchCompetitionStage" class="matchCompetition">MATCH</div><div id="matchRoundStage" class="matchRound"></div><div class="matchTeams"><div id="matchHomeStage" class="matchTeam">HOME</div><div class="matchVs">VS</div><div id="matchAwayStage" class="matchTeam">AWAY</div></div><div class="matchMetaStage"><span id="matchKickoffStage"></span><span>·</span><span id="matchVenueStage"></span></div></div></div>
  <div id="countdownOverlay" class="countdownOverlay"><div class="countdownCore"><div class="countdownLabel">KICKOFF SHOW</div><div id="countdownNumber" class="countdownNumber">5</div><div id="countdownSub" class="countdownSub">MATCH</div></div></div>
  <div id="tunnelScene" class="tunnelScene"><div class="tunnelBack"></div><div class="portal"></div><div class="wall left"></div><div class="wall right"></div><div class="ceiling"></div><div class="floor"></div><div class="led left"><div id="ledLeft" class="ledText">TEAM<small>STARTING XI</small></div></div><div class="led right"><div id="ledRight" class="ledText">SAGI<small>TUNNEL</small></div></div><div class="roofLights"></div><div class="fog"></div><div class="cameraVignette"></div></div>
  <div id="stadium" class="stadium"></div><img id="stadiumPhoto" class="stadiumPhoto"><div id="shade" class="shade"></div><div id="pitchLines" class="pitchLines"></div><div class="light l1"></div><div class="light l2"></div>
  <div class="header"><img id="crest" class="crest"><div><div id="team" class="team">TEAM</div><div id="stageLineupLabel" class="sub">STARTING XI</div></div></div>
  <div id="groupTitle" class="groupTitle">STARTING XI</div><div id="groupName" class="groupName">TEAM LINEUP</div><div class="line"></div>
  <div id="freezeFlash" class="freezeFlash"></div><div id="roleGlow" class="roleGlow"></div><div id="roleBackdrop" class="roleBackdrop">XI</div><div id="players" class="players layout-TEAM"></div><div id="fullList" class="fullList" style="display:none"></div><div id="subList" class="subList" style="display:none"></div>
  <div class="formation"><div class="formationHead"><div><div class="formationTitle">FORMATION</div><div style="font-size:12px;color:#8f97a5">LIVE LINEUP</div></div><div id="formationText" class="formationText">4-3-3</div></div><div class="pitch"><div class="boxTop"></div><div class="boxBottom"></div><div id="nodes" class="nodes"></div></div></div>
</div>

<div id="graphicsStage" class="graphicsStage">
  <div id="scoreBug" class="scoreBug">
    <div id="sbHome" class="sbTeam home">HOME</div><div id="sbHomeScore" class="sbScore">0</div>
    <div class="sbMid"><div id="sbClock" class="sbClock">00:00</div><div id="sbPeriod" class="sbPeriod">1H</div></div>
    <div id="sbAwayScore" class="sbScore">0</div><div id="sbAway" class="sbTeam away">AWAY</div>
  </div>
  <div id="eventCard" class="eventCard"><div id="eventIcon" class="eventIcon">⚽</div><div><div id="eventKicker" class="eventKicker">GOAL</div><div id="eventName" class="eventName"></div><div id="eventMeta" class="eventMeta"></div><div id="subRows" class="subRows"></div></div></div>
  <div id="stateSplash" class="stateSplash"><div class="stateBox"><div id="stateKicker" class="stateKicker"></div><div id="stateTitle" class="stateTitle"></div><div id="stateScore" class="stateScore"></div><div id="stateTeams" class="stateTeams"></div><div id="mvpName" class="mvpName"></div><div id="mvpMeta" class="mvpMeta"></div></div></div>
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

const q=id=>document.getElementById(id),ROLE_NAMES={GK:'GOALKEEPER',DF:'DEFENDERS',MF:'MIDFIELDERS',FW:'FORWARDS'};
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
function startingLabel(x){const n=playerCount(x),w={5:'FIVE',7:'SEVEN',8:'EIGHT',9:'NINE'};return n===11?'STARTING XI':'STARTING '+(w[n]||n)}
function starterCode(x){return playerCount(x)===11?'XI':String(playerCount(x))}
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

let last='',lastGraphics='',hideTimer=null,current=null,currentGraphics=null,eventTimer=null;
function esc(s){return String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function fit(){const s=Math.min(innerWidth/1920,innerHeight/1080),x=(innerWidth-1920*s)/2,y=(innerHeight-1080*s)/2,t='translate3d('+x+'px,'+y+'px,0) scale('+s+')';q('stage').style.transform=t;q('graphicsStage').style.transform=t}
function fallback(role,i,n){const y={GK:91,DF:72,MF:48,FW:22}[role]||50;return[((i+1)/(n+1))*100,y]}
function formationPlayerKey(p){return String(p&&p.layoutKey||p&&p.id||((p&&p.number)||'')+'|'+((p&&p.name)||'')+'|'+((p&&p.role)||''))}
function safeFormationXY(xy,fallbackXY){if(!Array.isArray(xy)||xy.length<2)return fallbackXY;return[Math.max(5,Math.min(95,Number(xy[0])||fallbackXY[0])),Math.max(5,Math.min(95,Number(xy[1])||fallbackXY[1]))]}
function allPoints(x){const form=formationPoints(x.formation),out=[],valid=effectivePlayers(x),layout=x&&x.formationLayout&&typeof x.formationLayout==='object'?x.formationLayout:{};for(const role of ['GK','DF','MF','FW']){const ps=form[role]||[],arr=valid.filter(p=>p.role===role);arr.forEach((p,i)=>{const base=ps[i]||fallback(role,i,arr.length),xy=safeFormationXY(layout[formationPlayerKey(p)],base);out.push({p,role,xy})})}return out}
function renderNodes(x){q('formationText').textContent=x.formation||'4-3-3';q('nodes').innerHTML='';allPoints(x).forEach(({p,role,xy})=>{const d=document.createElement('div');d.className='node'+((x.group==='FULL'||x.group===role)?' active':'')+(p.captain?' captainNode':'');d.style.left=xy[0]+'%';d.style.top=xy[1]+'%';d.innerHTML='<span>'+esc(p.number)+'</span><small>'+esc(p.name)+'</small>';q('nodes').appendChild(d)})}
function directorAttrs(p){
 return ' data-in="'+(Number(p.directorIn)||0)+'" data-out="'+(Number(p.directorOut)||0)+'" data-speed="'+(Number(p.directorSpeed)||1)+'" data-freeze="'+(p.directorFreeze?'1':'0')+'" data-freezems="'+(Number(p.directorFreezeMs)||1000)+'" data-camera="'+esc(p.directorCamera||'MEDIUM')+'"';
}
function card(p,n){
 const media=p.mediaUrl||'',action=' action-'+esc(p.mediaAction||'STANDARD'),hasMedia=media?' hasMedia':'',directed=media?' directed':'';
 const fallback=p.photo?'<img src="'+p.photo+'">':'<div class="fallback">'+esc(p.number)+'</div>';
 const visual=media?'<div class="mediaFallback">'+fallback+'</div><video class="mediaVideo" src="'+esc(media)+'" muted playsinline preload="auto"'+directorAttrs(p)+'></video>':fallback;
 const dirTag=media?'<div class="directorBadge">IN '+(Number(p.directorIn)||0).toFixed(1)+' · '+(Number(p.directorSpeed)||1).toFixed(2)+'×'+(p.directorFreeze?' · FREEZE':'')+'</div>':'';
 return '<div class="card'+(n===1?' one':'')+hasMedia+action+directed+'"><div class="cut">'+visual+'</div><div class="label"><div class="no">#'+esc(p.number)+(p.captain?'<span class="captainBadge">C</span>':'')+'</div><div class="name">'+esc(p.name)+'</div><div class="role">'+esc(p.position||p.role)+'</div>'+(p.statValue?'<div class="statPill">'+esc(p.statLabel)+' <strong>'+esc(p.statValue)+'</strong></div>':'')+(media?'<div class="mediaTag">MEDIA DAY · '+esc(p.mediaAction||'STANDARD')+'</div>':'')+dirTag+'</div></div>'
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
 const lineup=startingLabel(x),role={STING:'LOGO STING',MATCH:'MATCH INFO',COUNTDOWN:'COUNTDOWN',TEAM:lineup,GK:'GOALKEEPER',DF:'DEFENDERS',MF:'MIDFIELDERS',FW:'FORWARDS',FULL:'FORMATION',SUB:'SUBSTITUTES'}[x.group]||lineup;
 q('ledLeft').innerHTML=esc(x.team||'TEAM')+'<small>'+role+'</small>';
 q('ledRight').innerHTML=(x.group==='TEAM'?'SAGI':(ROLE_NAMES[x.group]||x.group))+'<small>'+esc(x.formation||'')+'</small>';
}
function applyVisualGroup(group,x){
 const st=q('stage'),area=q('players'),code=q('roleBackdrop');
 st.classList.remove('group-GK','group-DF','group-MF','group-FW','group-TEAM','group-FULL','group-SUB','group-STING','group-MATCH','group-COUNTDOWN','tunnel-open');
 st.classList.add('group-'+group);if(group==='FULL')st.classList.add('tunnel-open');
 area.className='players layout-'+group;
 const codes={STING:'SAGI',MATCH:'MATCH',COUNTDOWN:'5',TEAM:starterCode(x),GK:'GK',DF:'DEF',MF:'MID',FW:'FWD',FULL:starterCode(x),SUB:'SUB'};
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
 if(label)label.textContent=show&&show.label?('SHOW · '+show.label):'';
 if(!badge||!show||!show.cue||show.cue==='NONE')return;
 badge.textContent=show.cue;if(badge.animate)badge.animate([{opacity:0,transform:'translateY(-8px)'},{opacity:1,transform:'translateY(0)',offset:.25},{opacity:0}],{duration:900,easing:'ease-out'})
}
function packageInfo(x){return x&&x.package||{}}
function syncPackageStage(x){
 const p=packageInfo(x);q('stingLogo').src=p.eventLogo||x.crest||'';q('stingLogo').style.visibility=(p.eventLogo||x.crest)?'visible':'hidden';q('stingCompetition').textContent=p.competition||'MATCH';q('matchCompetitionStage').textContent=p.competition||'MATCH';q('matchRoundStage').textContent=p.round||'';q('matchHomeStage').textContent=p.home||x.team||'HOME';q('matchAwayStage').textContent=p.away||'AWAY';q('matchKickoffStage').textContent=p.kickoff||'';q('matchVenueStage').textContent=p.venue||'';q('countdownSub').textContent=p.competition||'MATCH';
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
 else if(x.group==='MATCH'){const card=q('matchOverlay').querySelector('.matchCardStage');if(card&&card.animate)card.animate([{opacity:0,transform:'translateY(45px) scale(.97)'},{opacity:1,transform:'translateY(0) scale(1)'}],{duration:720,fill:'forwards',easing:'ease-out'})}
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
 q('stage').style.opacity='1';q('stage').dataset.program='on';
 current=x;q('stage').dataset.side=x.side||'HOME';q('sideBadgeStage').textContent=(x.side==='AWAY'?'AWAY · 客队':'HOME · 主队');clearInterval(startCountdown.t);['stingOverlay','matchOverlay','countdownOverlay'].forEach(id=>q(id).classList.remove('on'));syncPackageStage(x);manageShowMusic(x);playRealCue(x);applyShowTransition(x.show&&x.show.transition);showCueDisplay(x.show||null);q('stage').dataset.showStep=x.show&&Number.isFinite(+x.show.stepIndex)?String(x.show.stepIndex):'';applyVisualGroup(x.group||'TEAM',x);updateTunnelLabels(x);q('stageLineupLabel').textContent=startingLabel(x);q('team').textContent=x.team||'TEAM';applyBg(x);q('fullList').style.display='none';q('subList').style.display='none';q('players').style.display='flex';
 if(x.group==='STING'){q('groupTitle').textContent='MATCH SHOW';q('groupName').textContent='LOGO STING';q('players').style.display='none';q('stingOverlay').classList.add('on')}
 else if(x.group==='MATCH'){q('groupTitle').textContent='MATCH SHOW';q('groupName').textContent='MATCH INFO';q('players').style.display='none';q('matchOverlay').classList.add('on')}
 else if(x.group==='COUNTDOWN'){q('groupTitle').textContent='MATCH SHOW';q('groupName').textContent='COUNTDOWN';q('players').style.display='none';q('countdownOverlay').classList.add('on')}
 else if(x.group==='TEAM'){q('groupTitle').textContent='SAGI BROADCAST';q('groupName').textContent=(x.team||'TEAM')+' · '+(x.formation||'');q('players').innerHTML='<div style="align-self:center;text-align:center;color:#ffffff52;font-weight:1000;font-size:138px;letter-spacing:10px;text-shadow:0 18px 45px #000">'+esc(x.formation||'')+'</div>'}
 else if(x.group==='FULL'){q('groupTitle').textContent=startingLabel(x);q('groupName').textContent='FULL LINEUP';q('players').style.display='none';q('fullList').style.display='grid';q('fullList').innerHTML=effectivePlayers(x).map(p=>'<div class="fullRow"><div class="fullRole">'+esc(p.role)+'</div><div class="fullNo">'+esc(p.number)+'</div><div class="fullName">'+esc(p.name)+(p.captain?' <span class="captainBadge">C</span>':'')+'</div><div class="fullPos">'+esc(p.position)+(p.statValue?' · '+esc(p.statLabel)+' '+esc(p.statValue):'')+'</div></div>').join('')} else if(x.group==='SUB'){q('groupTitle').textContent='SQUAD';q('groupName').textContent='SUBSTITUTES';q('players').style.display='none';q('subList').style.display='grid';const subs=x.substitutes||x.players||[];q('subList').innerHTML=subs.length?subs.map(p=>'<div class="subRow"><div class="subNo">#'+esc(p.number)+'</div><div><div class="subName">'+esc(p.name)+'</div><div class="subStat">'+esc(p.role)+' · '+esc(p.position)+'</div></div><div class="subStat">'+(p.statValue?esc(p.statLabel)+' '+esc(p.statValue):'SUB')+'</div></div>').join(''):'<div class="subStat">NO SUBSTITUTES</div>'}
 else{q('groupTitle').textContent=startingLabel(x);q('groupName').textContent=ROLE_NAMES[x.group]||x.group;const gp=effectiveGroupPlayers(x);q('players').innerHTML=gp.map(p=>card(p,gp.length)).join('')}
 if(!['STING','MATCH','COUNTDOWN'].includes(x.group))renderNodes(x);else q('nodes').innerHTML='';animate(x);animatePackage(x);setTimeout(playMediaVideos,0)
}
function animate(x){
 const els=[...q('stage').querySelectorAll('.card,.fullRow,.subRow,.node.active')];
 els.forEach((el,i)=>{
  if(!el.animate)return;
  const isNode=el.classList.contains('node'),isPlayer=el.classList.contains('card');
  let frames;
  if(isNode)frames=[{opacity:0,transform:'translate(-50%,-50%) scale(.25)'},{opacity:1,transform:'translate(-50%,-50%) scale(1.18)',offset:.72},{opacity:1,transform:'translate(-50%,-50%) scale(1)'}];
  else if(isPlayer){const dir=i%2===0?-70:70;frames=[{opacity:0,transform:'translate('+dir+'px,42px) scale(.9)'},{opacity:1,transform:'translate(0,0) scale(1)'}]}
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
function updateScoreBug(){
 const g=currentGraphics;if(!g)return;
 const bug=q('scoreBug'),home=validHex(g.homeColor,'#d8b55b'),away=validHex(g.awayColor,'#4c7dff'),accent=validHex(g.accentColor,'#f4f0e8');
 bug.style.setProperty('--home',home);bug.style.setProperty('--away',away);bug.style.setProperty('--accent',accent);
 bug.classList.toggle('on',!!g.scoreboardVisible);q('sbHome').textContent=g.home||'HOME';q('sbAway').textContent=g.away||'AWAY';q('sbHomeScore').textContent=Number(g.homeScore)||0;q('sbAwayScore').textContent=Number(g.awayScore)||0;q('sbClock').textContent=gfxFormat(gfxSeconds(g));q('sbPeriod').textContent=gfxPeriodName(g.clock&&g.clock.period);
}
function hideEvent(){clearTimeout(eventTimer);q('eventCard').className='eventCard';q('eventCard').style.borderLeftColor='';q('eventIcon').style.background='';q('stateSplash').classList.remove('on')}
function showEvent(g){
 const e=g&&g.event;if(!e||e.type==='CLEAR_EVENT'){hideEvent();return}
 hideEvent();const card=q('eventCard'),icon=q('eventIcon'),k=q('eventKicker'),name=q('eventName'),meta=q('eventMeta'),rows=q('subRows'),splash=q('stateSplash');
 rows.innerHTML='';q('mvpName').textContent='';q('mvpMeta').textContent='';
 if(e.type==='GOAL'||e.type==='YELLOW'||e.type==='RED'){
   const teamColor=e.side==='AWAY'?validHex(g.awayColor,'#4c7dff'):validHex(g.homeColor,'#d8b55b');
   card.style.borderLeftColor=e.type==='GOAL'?teamColor:'';
   icon.style.background=e.type==='GOAL'?teamColor:'';
   card.className='eventCard on '+(e.type==='YELLOW'?'yellow':e.type==='RED'?'red':'goal');icon.textContent=e.type==='GOAL'?'⚽':'▮';k.textContent=e.type==='GOAL'?'进球 · GOAL':e.type==='YELLOW'?'黄牌 · YELLOW CARD':'红牌 · RED CARD';name.textContent='#'+(e.player&&e.player.number||'')+'  '+(e.player&&e.player.name||'PLAYER');meta.textContent=(e.team||'')+'  ·  '+(e.at||'');
   eventTimer=setTimeout(hideEvent,5200);
 } else if(e.type==='SUB'){
   card.className='eventCard on sub';icon.textContent='↕';k.textContent='换人 · SUBSTITUTION';name.textContent=e.team||'';meta.textContent=e.at||'';rows.innerHTML='<div class="subRowG in"><span class="subArrow">▲</span>#'+esc(e.on&&e.on.number)+' '+esc(e.on&&e.on.name)+'</div><div class="subRowG out"><span class="subArrow">▼</span>#'+esc(e.off&&e.off.number)+' '+esc(e.off&&e.off.name)+'</div>';eventTimer=setTimeout(hideEvent,6500);
 } else if(e.type==='HALF_TIME'||e.type==='FULL_TIME'){
   splash.classList.add('on');q('stateKicker').textContent=e.type==='HALF_TIME'?'HALF TIME · 半场':'FULL TIME · 全场';q('stateTitle').textContent=e.type==='HALF_TIME'?'半场':'全场';q('stateScore').textContent=(Number(e.homeScore)||0)+'  :  '+(Number(e.awayScore)||0);q('stateTeams').textContent=(e.home||g.home||'HOME')+'    ·    '+(e.away||g.away||'AWAY');eventTimer=setTimeout(hideEvent,e.type==='FULL_TIME'?9000:6500);
 } else if(e.type==='MVP'){
   splash.classList.add('on');q('stateKicker').textContent='PLAYER OF THE MATCH · 本场最佳';q('stateTitle').textContent='MVP';q('stateScore').textContent=e.score||'';q('stateTeams').textContent=e.team||'';q('mvpName').textContent='#'+(e.player&&e.player.number||'')+'  '+(e.player&&e.player.name||'PLAYER');q('mvpMeta').textContent=e.player&&e.player.position||'';eventTimer=setTimeout(hideEvent,9000);
 }
}
function applyGraphics(g){currentGraphics=g;updateScoreBug();showEvent(g)}

async function poll(){
 try{
   const p=await lanState(),x=p.lineupIntro;
   if(x&&x.commandId&&x.commandId!==last){last=x.commandId;render(x)}
 }catch(e){}
 try{
   const g=await lanMatchday();
   if(g&&g.commandId&&g.commandId!==lastGraphics){lastGraphics=g.commandId;applyGraphics(g)}
 }catch(e){}
}

addEventListener('resize',fit);fit();poll();setInterval(poll,650);setInterval(updateScoreBug,250);
})();
</script></body></html>