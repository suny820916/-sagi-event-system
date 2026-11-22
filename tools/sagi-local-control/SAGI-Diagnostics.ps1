# SAGI LOCAL CONTROL V1 — read-only Windows diagnostics
# Compatible with Windows PowerShell 5.1+. No internet access required.
[CmdletBinding()]
param(
  [string]$VmixBaseUrl = "http://127.0.0.1:8088",
  [string]$BridgeHealthUrl = "http://127.0.0.1:8787/health",
  [string]$OutputDirectory = "$env:USERPROFILE\Documents\SAGI-Diagnostics",
  [int]$TimeoutSeconds = 3
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Test-HttpEndpoint([string]$Url) {
  try {
    $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing
    return [ordered]@{ reachable=$true; statusCode=[int]$response.StatusCode; contentType=[string]$response.Headers["Content-Type"]; error=$null }
  } catch {
    $status = $null
    try { $status = [int]$_.Exception.Response.StatusCode } catch {}
    return [ordered]@{ reachable=$false; statusCode=$status; contentType=$null; error=$_.Exception.Message }
  }
}
function Test-TcpPort([string]$HostName,[int]$Port) {
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $task = $client.BeginConnect($HostName,$Port,$null,$null)
    if (-not $task.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000,$false)) { return $false }
    $client.EndConnect($task); return $true
  } catch { return $false } finally { $client.Close() }
}
function Get-RedactedUrl([string]$Url) {
  try { $u=[uri]$Url; return "$($u.Scheme)://$($u.Host):$($u.Port)$($u.AbsolutePath)" } catch { return "[invalid-url]" }
}
$started = Get-Date
$vmixUri = $null
try { $vmixUri = [uri]$VmixBaseUrl } catch {}
$bridgeUri = $null
try { $bridgeUri = [uri]$BridgeHealthUrl } catch {}
$vmixProbe = if ($vmixUri) { Test-HttpEndpoint ($VmixBaseUrl.TrimEnd("/") + "/api/") } else { @{reachable=$false;error="Invalid vMix URL"} }
$bridgeProbe = if ($bridgeUri) { Test-HttpEndpoint $BridgeHealthUrl } else { @{reachable=$false;error="Invalid Bridge URL"} }
$vmixProcess = @(Get-Process -Name "vmix" -ErrorAction SilentlyContinue | Select-Object -First 3 Id,ProcessName,StartTime)
$ports = @(
  [ordered]@{name="vMix Web Controller";host="127.0.0.1";port=8088;open=(Test-TcpPort "127.0.0.1" 8088)},
  [ordered]@{name="SAGI Bridge default";host="127.0.0.1";port=8787;open=(Test-TcpPort "127.0.0.1" 8787)}
)
$report = [ordered]@{
  schema="sagi.local-control.diagnostics.v1"
  generatedAt=$started.ToString("o")
  machine=[ordered]@{ os=[System.Environment]::OSVersion.VersionString; powershell=$PSVersionTable.PSVersion.ToString(); is64Bit=[Environment]::Is64BitOperatingSystem }
  network=[ordered]@{ internetRequired=$false; mode="loopback-only diagnostics"; adapters=@(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {$_.NetAdapter.Status -eq "Up"} | ForEach-Object { [ordered]@{name=$_.InterfaceAlias;ipv4=@($_.IPv4Address | ForEach-Object {$_.IPv4Address})} }) }
  vmix=[ordered]@{ configuredUrl=(Get-RedactedUrl $VmixBaseUrl); api=$vmixProbe; process=$vmixProcess; port8088=$ports[0].open }
  bridge=[ordered]@{ configuredHealthUrl=(Get-RedactedUrl $BridgeHealthUrl); health=$bridgeProbe; port8787=$ports[1].open }
  ports=$ports
  limitations=@("Read-only checks only; no match state is changed.","Browser/Overlay visual output cannot be certified by a local HTTP probe.","A reachable endpoint is not proof of correct score/clock/event rendering.","No remote desktop or vMix control channel is created.")
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp = $started.ToString("yyyyMMdd-HHmmss")
$jsonPath = Join-Path $OutputDirectory "SAGI-Diagnostics-$stamp.json"
$mdPath = Join-Path $OutputDirectory "SAGI-Diagnostics-$stamp.md"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$lines = @(
  "# SAGI Local Diagnostics",
  "",
  "- Generated: $($report.generatedAt)",
  "- Windows: $($report.machine.os)",
  "- PowerShell: $($report.machine.powershell)",
  "- vMix process: $($vmixProcess.Count -gt 0)",
  "- vMix API reachable: $($vmixProbe.reachable)",
  "- SAGI Bridge health reachable: $($bridgeProbe.reachable)",
  "- vMix TCP 8088: $($ports[0].open)",
  "- Bridge TCP 8787: $($ports[1].open)",
  "",
  "## Safety / limitations",
  ($report.limitations | ForEach-Object {"- $_"}),
  "",
  "JSON evidence: $jsonPath"
)
$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8
Write-Host "SAGI diagnostics completed." -ForegroundColor Green
Write-Host "Markdown: $mdPath"
Write-Host "JSON:     $jsonPath"
Write-Host "No live match state was changed."
