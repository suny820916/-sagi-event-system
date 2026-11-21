# SAGI V4.32 field acceptance preflight (Windows PowerShell 5.1+)
# Read-only: never stops Bridge, changes scores, or contacts the Internet.
param(
  [string]$Package = (Join-Path $PSScriptRoot '..\SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat'),
  [string]$ReportDir = (Join-Path $env:LOCALAPPDATA 'SAGI\Acceptance')
)
$ErrorActionPreference = 'Stop'
$results = New-Object System.Collections.ArrayList
function Record([string]$Name, [bool]$Pass, [string]$Detail) {
  [void]$results.Add([pscustomobject]@{name=$Name;pass=$Pass;detail=$Detail})
  $status = if ($Pass) { 'PASS' } else { 'FAIL' }
  Write-Host "[$status] $Name : $Detail"
}
try {
  $resolved = (Resolve-Path -LiteralPath $Package).Path
  $source = [IO.File]::ReadAllText($resolved,[Text.Encoding]::UTF8)
  $pattern = '(?s)###SAGI_PS###\r?\n(.*?)\r?\n###SAGI_CONTROL###\r?\n(.*?)\r?\n###SAGI_OUTPUT###\r?\n(.*)$'
  $payload = [regex]::Match($source,$pattern)
  if (-not $payload.Success) { throw 'BAT embedded payload markers missing or reordered' }
  Record 'package-extraction' $true $resolved
  $bridge = $payload.Groups[1].Value
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseInput($bridge,[ref]$tokens,[ref]$parseErrors)
  Record 'bridge-powershell-parser' ($parseErrors.Count -eq 0) (($parseErrors | ForEach-Object { $_.ToString() }) -join '; ')
  Record 'control-payload' ($payload.Groups[2].Value.Length -gt 100000) ('bytes=' + $payload.Groups[2].Value.Length)
  Record 'output-payload' ($payload.Groups[3].Value.Length -gt 50000) ('bytes=' + $payload.Groups[3].Value.Length)
} catch {
  Record 'package-preflight' $false $_.Exception.Message
}
foreach ($port in @(8100,8088)) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $async = $client.BeginConnect('127.0.0.1',$port,$null,$null)
    $connected = $async.AsyncWaitHandle.WaitOne(1500,$false)
    if ($connected) { $client.EndConnect($async) }
    $client.Close()
    Record ("localhost-port-$port") $connected $(if ($connected) {'reachable'} else {'not listening'})
  } catch { Record ("localhost-port-$port") $false $_.Exception.Message }
}
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$report = [pscustomobject]@{
  schema='SAGI_FIELD_PREFLIGHT_V1'
  timestampUtc=(Get-Date).ToUniversalTime().ToString('o')
  computer=$env:COMPUTERNAME
  powershell=$PSVersionTable.PSVersion.ToString()
  checks=@($results.ToArray())
  note='Preflight only; NOT 4h/8h soak, disconnect/recovery, real vMix, or production certification.'
}
$path = Join-Path $ReportDir ("sagi-v432-preflight-$stamp.json")
[IO.File]::WriteAllText($path,($report | ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
Write-Host "Report: $path"
if (@($results | Where-Object { -not $_.pass }).Count -gt 0) { exit 1 }
exit 0
