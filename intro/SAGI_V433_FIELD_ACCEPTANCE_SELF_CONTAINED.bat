@echo off
chcp 65001 >nul
setlocal
title SAGI V4.33 FIELD ACCEPTANCE - SELF CONTAINED
set "SAGI_ACCEPT_SELF=%~f0"

echo.
echo ==============================================
echo   SAGI V4.33 FIELD ACCEPTANCE / SELF-CONTAINED
echo ==============================================
echo [SAFE] No TEMP .ps1 dependency.
echo [SAFE] Read-only checks; no score/event mutation.
echo [SAFE] Reports are saved under LocalAppData\SAGI\Acceptance.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$src=[IO.File]::ReadAllText($env:SAGI_ACCEPT_SELF,[Text.Encoding]::UTF8);" ^
 "$m=[regex]::Match($src,'(?s)###SAGI_ACCEPTANCE_PS###\r?\n(.*)$');" ^
 "if(-not $m.Success){Write-Host '[FAIL] Embedded acceptance payload missing.' -ForegroundColor Red;exit 90};" ^
 "$sb=[scriptblock]::Create($m.Groups[1].Value);& $sb"

set "SAGI_ACCEPT_RC=%ERRORLEVEL%"
echo.
if "%SAGI_ACCEPT_RC%"=="0" (
  echo [PASS] SAGI V4.33 field preflight completed.
) else (
  echo [CHECK] One or more acceptance checks failed. See the report path above.
)
echo.
pause
exit /b %SAGI_ACCEPT_RC%

###SAGI_ACCEPTANCE_PS###
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$Root = Join-Path $env:LOCALAPPDATA 'SAGI\LiveMatchDirector'
$ReportDir = Join-Path $env:LOCALAPPDATA 'SAGI\Acceptance'
$Control = Join-Path $Root 'control-latest.html'
$Output = Join-Path $Root 'output-latest.html'
$Bridge = Join-Path $Root 'bridge-stable.ps1'
$results = New-Object System.Collections.ArrayList

function Add-Result([string]$Name,[bool]$Pass,[string]$Detail) {
  [void]$results.Add([pscustomobject]@{name=$Name;pass=$Pass;detail=$Detail})
  $tag = if($Pass){'PASS'}else{'FAIL'}
  $color = if($Pass){'Green'}else{'Yellow'}
  Write-Host "[$tag] $Name : $Detail" -ForegroundColor $color
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

function Read-Utf8([string]$Path) {
  try { return [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8) } catch { return '' }
}

Write-Host ''
Write-Host 'SAGI V4.33 FIELD ACCEPTANCE' -ForegroundColor Cyan
Write-Host ('Time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Write-Host ('Computer: ' + $env:COMPUTERNAME)
Write-Host ('PowerShell: ' + $PSVersionTable.PSVersion.ToString())
Write-Host ''

Add-Result 'no-temp-script-dependency' $true 'launcher executes its embedded payload directly'
Add-Result 'runtime-root' (Test-Path -LiteralPath $Root) $Root
Add-Result 'bridge-file' (Test-Path -LiteralPath $Bridge) $Bridge
Add-Result 'control-file' (Test-Path -LiteralPath $Control) $Control
Add-Result 'output-file' (Test-Path -LiteralPath $Output) $Output

$controlText = Read-Utf8 $Control
$outputText = Read-Utf8 $Output
$bridgeText = Read-Utf8 $Bridge

Add-Result 'control-v433-marker' ($controlText -match 'SAGI433_PENALTY_RC1') 'SAGI433_PENALTY_RC1'
Add-Result 'control-v432-signature-marker' ($controlText -match 'SAGI432_SIGNATURE_RC7') 'SAGI432_SIGNATURE_RC7'
Add-Result 'output-signature-marker' ($outputText -match 'SAGI432_SIGNATURE_RC7' -and $outputText -match 'SAGISignatureCore') 'V4.32 SIGNATURE output family'
Add-Result 'bridge-progress-safe' ($bridgeText -match '\$ProgressPreference\s*=\s*["'']SilentlyContinue["'']') 'blue progress bar suppression present'
Add-Result 'bridge-request-guard' ($bridgeText -match 'request' -or $bridgeText -match 'body') 'Bridge request handling present'

$bridgePort = Test-Tcp 8100
$vmixPort = Test-Tcp 8088
Add-Result 'bridge-port-8100' $bridgePort $(if($bridgePort){'reachable'}else{'not listening'})
Add-Result 'vmix-api-8088' $vmixPort $(if($vmixPort){'reachable'}else{'not listening'})

$healthRaw = ''
$healthOk = $false
if($bridgePort) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8100/health' -TimeoutSec 2
    $healthRaw = [string]$resp.Content
    $healthOk = ($resp.StatusCode -eq 200 -and $healthRaw.Length -gt 2)
  } catch { $healthRaw = $_.Exception.Message }
}
Add-Result 'bridge-health' $healthOk $(if($healthRaw){$healthRaw.Substring(0,[Math]::Min(300,$healthRaw.Length))}else{'no response'})

$lanIp = ''
try {
  $lanIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Sort-Object InterfaceMetric |
    Select-Object -First 1 -ExpandProperty IPAddress
} catch {}
if(-not $lanIp) {
  try {
    $lanIp = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
      Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_.IPAddressToString -notlike '127.*' } |
      Select-Object -First 1 -ExpandProperty IPAddressToString
  } catch {}
}
Add-Result 'lan-ip' ([bool]$lanIp) $(if($lanIp){$lanIp}else{'not detected'})

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$phoneUrl = if($lanIp){ 'http://{0}:8100/' -f $lanIp }else{ '' }
$summary = [pscustomobject]@{
  schema='SAGI_V433_FIELD_ACCEPTANCE_V2'
  timestampUtc=(Get-Date).ToUniversalTime().ToString('o')
  computer=$env:COMPUTERNAME
  powershell=$PSVersionTable.PSVersion.ToString()
  lanIp=$lanIp
  controlUrl='http://127.0.0.1:8100/'
  vmixOverlayUrl='http://127.0.0.1:8100/vmix'
  phoneUrl=$phoneUrl
  checks=@($results.ToArray())
  note='Read-only preflight. Real penalty/undo/reconnect/LAN-only/soak acceptance still requires operator actions in vMix and phone.'
}
$jsonPath = Join-Path $ReportDir ("sagi-v433-field-acceptance-$stamp.json")
$txtPath = Join-Path $ReportDir ("sagi-v433-field-acceptance-$stamp.txt")
[IO.File]::WriteAllText($jsonPath,($summary | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
$lines = @(
  'SAGI V4.33 FIELD ACCEPTANCE',
  ('UTC: ' + $summary.timestampUtc),
  ('Computer: ' + $summary.computer),
  ('LAN IP: ' + $summary.lanIp),
  ('Phone: ' + $summary.phoneUrl),
  ('Control: ' + $summary.controlUrl),
  ('vMix Overlay: ' + $summary.vmixOverlayUrl),
  ''
) + @($results | ForEach-Object { ('[' + $(if($_.pass){'PASS'}else{'FAIL'}) + '] ' + $_.name + ' : ' + $_.detail) })
[IO.File]::WriteAllLines($txtPath,$lines,(New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ('Report JSON: ' + $jsonPath) -ForegroundColor Cyan
Write-Host ('Report TXT : ' + $txtPath) -ForegroundColor Cyan
if($phoneUrl){ Write-Host ('PHONE CONTROL: ' + $phoneUrl) -ForegroundColor Green }
Write-Host 'VMIX BROWSER : http://127.0.0.1:8100/vmix' -ForegroundColor Green

if($bridgePort) {
  try { Start-Process 'http://127.0.0.1:8100/' } catch {}
}

$critical = @('runtime-root','bridge-file','control-file','output-file','control-v433-marker','output-signature-marker','bridge-port-8100','bridge-health')
$failedCritical = @($results | Where-Object { $critical -contains $_.name -and -not $_.pass })
if($failedCritical.Count -gt 0){ exit 1 }
exit 0
