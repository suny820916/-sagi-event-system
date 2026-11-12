# SAGI V4.5.5 LAN DIRECT Bridge
# Same-LAN control server + local vMix API bridge.
# Phone Control: http://<PC-LAN-IP>:8099/
# vMix Browser:  http://127.0.0.1:8099/vmix

$Port = 8099
$VmixApi = "http://127.0.0.1:8088/api/"
$Root = Join-Path $env:LOCALAPPDATA "SAGI\LiveMatchDirector"
New-Item -ItemType Directory -Force -Path $Root | Out-Null

$ControlUrl = "https://raw.githubusercontent.com/suny820916/-sagi-event-system/main/intro/v45-lan.html?v=455"
$OutputUrl  = "https://raw.githubusercontent.com/suny820916/-sagi-event-system/main/intro/vmix-v45-lan.html?v=455"
$ControlCache = Join-Path $Root "v45-lan.html"
$OutputCache  = Join-Path $Root "vmix-v45-lan.html"

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

function Get-CachedText([string]$Url,[string]$CachePath) {
  try {
    $wc = New-Object Net.WebClient
    $wc.Headers.Add("Cache-Control","no-cache")
    $text = $wc.DownloadString($Url)
    [IO.File]::WriteAllText($CachePath,$text,(New-Object Text.UTF8Encoding($false)))
    return $text
  }
  catch {
    if (Test-Path $CachePath) {
      Write-Host ("[OFFLINE] Using cached UI: " + [IO.Path]::GetFileName($CachePath)) -ForegroundColor DarkYellow
      return [IO.File]::ReadAllText($CachePath,[Text.Encoding]::UTF8)
    }
    throw
  }
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
Write-Host "  SAGI V4.5.5 LAN DIRECT - vMix Bridge" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
  $ControlHtml = Get-CachedText $ControlUrl $ControlCache
  $OutputHtml = Get-CachedText $OutputUrl $OutputCache
} catch {
  Write-Host ("[ERROR] Cannot load LAN UI: " + $_.Exception.Message) -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

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
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any,$Port)

try {
  $listener.Start()
} catch {
  Write-Host ("[ERROR] Cannot start LAN server on port " + $Port + ": " + $_.Exception.Message) -ForegroundColor Red
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
    elseif ($method -eq "GET" -and $path -eq "/health") {
      $health = @{ok=$true;vmix=(Test-Vmix);lan=$true;ip=$lanIp;port=$Port;version="4.5.5"} | ConvertTo-Json -Compress
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
