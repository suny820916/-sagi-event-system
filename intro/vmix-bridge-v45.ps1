# SAGI V4.5 vMix Bridge
# Run this file on the SAME Windows PC as vMix.
# vMix Settings -> Web must be enabled (default API: http://127.0.0.1:8088/api/)

$SupabaseUrl = "https://zgqrjuwltbnkgovtsccb.supabase.co"
$ApiKey = "sb_publishable_bqROSu6ZQRdDW3DLazUCfg_4aYxldN8"
$EventSlug = "tacheng-winter-2026"
$VmixApi = "http://127.0.0.1:8088/api/"
$PollMilliseconds = 500
$CloudTimeoutSeconds = 12
$MaxBackoffMilliseconds = 8000

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
  return Invoke-RestMethod -Method Post -Uri ($SupabaseUrl.TrimEnd("/") + "/rest/v1/rpc/sagi_get_event") -Headers $headers -Body $body -TimeoutSec $CloudTimeoutSeconds
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
$cloudFailures = 0
$lastWarnAt = [DateTime]::MinValue
$cloudWasDown = $false

while ($true) {
  $sleepMs = $PollMilliseconds
  try {
    $eventData = Get-SagiEvent

    if ($cloudWasDown) {
      Write-Host "[READY] Cloud link restored." -ForegroundColor Green
      $cloudWasDown = $false
    }

    $cloudFailures = 0
    $cmd = $eventData.payload.vmixDirector

    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.commandId)) {
      $id = [string]$cmd.commandId

      if (-not $initialized) {
        # Ignore an old cloud command when Bridge first starts.
        $lastCommandId = $id
        $initialized = $true
        Write-Host "[READY] Cloud connected. Waiting for the next command." -ForegroundColor Green
      }
      elseif ($id -ne $lastCommandId) {
        $lastCommandId = $id
        Invoke-VmixDirectorCommand $cmd
      }
    }
    elseif (-not $initialized) {
      $initialized = $true
      Write-Host "[READY] Cloud connected. No pending command." -ForegroundColor Green
    }
  }
  catch {
    $cloudFailures++
    $cloudWasDown = $true
    $pow = [Math]::Min(4, $cloudFailures - 1)
    $sleepMs = [Math]::Min($MaxBackoffMilliseconds, [int]($PollMilliseconds * [Math]::Pow(2, $pow)))

    $now = Get-Date
    if (($now - $lastWarnAt).TotalSeconds -ge 10) {
      Write-Host ("[CLOUD WARN] " + $_.Exception.Message + "  retry=" + $sleepMs + "ms") -ForegroundColor DarkYellow
      $lastWarnAt = $now
    }
  }

  Start-Sleep -Milliseconds $sleepMs
}
