# SAGI V4.5 vMix Bridge
# Run this file on the SAME Windows PC as vMix.
# vMix Settings -> Web must be enabled (default API: http://127.0.0.1:8088/api/)

$SupabaseUrl = "https://zgqrjuwltbnkgovtsccb.supabase.co"
$ApiKey = "sb_publishable_bqROSu6ZQRdDW3DLazUCfg_4aYxldN8"
$EventSlug = "tacheng-winter-2026"
$VmixApi = "http://127.0.0.1:8088/api/"
$PollMilliseconds = 250

$Allowed = @(
  "Cut","Fade","Stinger1","PreviewInput",
  "OverlayInput1In","OverlayInput1Out","OverlayInput1Off",
  "OverlayInput2In","OverlayInput2Out","OverlayInput2Off",
  "OverlayInput3In","OverlayInput3Out","OverlayInput3Off",
  "OverlayInput4In","OverlayInput4Out","OverlayInput4Off",
  "OverlayInputAllOff"
)

function Get-SagiEvent {
  $headers = @{ "apikey"=$ApiKey; "Content-Type"="application/json" }
  $body = @{ "p_slug"=$EventSlug } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Method Post -Uri ($SupabaseUrl.TrimEnd("/") + "/rest/v1/rpc/sagi_get_event") -Headers $headers -Body $body -TimeoutSec 4
}

function Invoke-VmixDirectorCommand($cmd) {
  $fn = [string]$cmd.functionName
  if ([string]::IsNullOrWhiteSpace($fn) -or -not ($Allowed -contains $fn)) {
    Write-Host ("[BLOCKED] Unsupported function: " + $fn) -ForegroundColor Yellow
    return
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
  Write-Host ("[vMix] " + $fn + "  Input=" + $inputValue + "  " + $label) -ForegroundColor Green
}

Write-Host "SAGI V4.5 LIVE MATCH DIRECTOR - vMix Bridge" -ForegroundColor Cyan
Write-Host ("Event: " + $EventSlug)
Write-Host ("vMix API: " + $VmixApi)
Write-Host "Bridge is listening. Keep this window open during the match." -ForegroundColor Cyan

try {
  Invoke-WebRequest -UseBasicParsing -Uri $VmixApi -TimeoutSec 3 | Out-Null
  Write-Host "[READY] vMix API connected on 127.0.0.1:8088" -ForegroundColor Green
}
catch {
  Write-Host "[ERROR] Cannot connect to vMix API on 127.0.0.1:8088" -ForegroundColor Red
  Write-Host "Open vMix -> Settings -> Web Controller -> Enable, port 8088." -ForegroundColor Yellow
  Write-Host "Then close this window and run SAGI_VMIX_BRIDGE.bat again." -ForegroundColor Yellow
  Read-Host "Press Enter to close"
  exit 1
}

$lastCommandId = ""
$initialized = $false

while ($true) {
  try {
    $eventData = Get-SagiEvent
    $cmd = $eventData.payload.vmixDirector
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.commandId)) {
      $id = [string]$cmd.commandId
      if (-not $initialized) {
        # Ignore an old cloud command when Bridge first starts.
        $lastCommandId = $id
        $initialized = $true
        Write-Host "[READY] Current cloud command acknowledged. Waiting for the next command." -ForegroundColor DarkGray
      }
      elseif ($id -ne $lastCommandId) {
        $lastCommandId = $id
        Invoke-VmixDirectorCommand $cmd
      }
    }
    elseif (-not $initialized) {
      $initialized = $true
      Write-Host "[READY] No pending command. Waiting." -ForegroundColor DarkGray
    }
  }
  catch {
    Write-Host ("[WARN] " + $_.Exception.Message) -ForegroundColor DarkYellow
  }
  Start-Sleep -Milliseconds $PollMilliseconds
}
