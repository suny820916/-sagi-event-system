$ErrorActionPreference = 'Stop'
$bat = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../SAGI_VMIX_LAN_V433_PENALTY_RC.bat'))
$match = [regex]::Match($bat, '(?ms)^function Write-SagiUiFile\(.*?(?=^function Get-LanIPv4)')
if (!$match.Success) { throw 'Candidate UI file operations missing' }
. ([scriptblock]::Create($match.Value))

function Assert-Ui([bool]$Condition, [string]$Message) {
  if (!$Condition) { throw $Message }
}
function Invoke-WebRequest($Uri, $TimeoutSec, $Headers, $OutFile, [switch]$UseBasicParsing) {
  $text = if ($Uri -match '/v45-lan\.html') {
    '<!doctype html>SAGI LIVE MATCH DIRECTOR SAGI432_SIGNATURE_RC7 SAGI433_PENALTY_RC1 SAGIPenaltyCore mdPenaltyCommitKick mdNextEventIdentity ' + ('c' * 50000)
  } else {
    '<!doctype html>SAGI432_SIGNATURE_RC7 SAGISignatureCore lastRenderedSignatureEventKey ' + ('o' * 20000)
  }
  [IO.File]::WriteAllText($OutFile, $text)
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('sagi-ui-pair-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
try {
  $ControlCache = Join-Path $root 'control.html'
  $OutputCache = Join-Path $root 'output.html'
  $ControlBackup = Join-Path $root 'control-backup.html'
  $OutputBackup = Join-Path $root 'output-backup.html'
  $RemoteBase = 'http://unused.invalid'
  $fixtures = @{}
  $fixtures[$ControlCache] = 'current-control'
  $fixtures[$OutputCache] = 'current-output'
  $fixtures[$ControlBackup] = 'prior-control'
  $fixtures[$OutputBackup] = 'prior-output'
  foreach ($entry in $fixtures.GetEnumerator()) { [IO.File]::WriteAllText($entry.Key, $entry.Value) }
  $script:ControlHtml = 'current-control'
  $script:OutputHtml = 'current-output'
  $writeFile = ${function:Write-SagiUiFile}
  $script:failWrite = ''
  function Write-SagiUiFile($Path, $Content) {
    if ($Path -eq $script:failWrite) { throw 'Injected write failure' }
    & $writeFile $Path $Content
  }
  foreach ($failure in @($OutputCache, $OutputBackup)) {
    $script:failWrite = $failure
    $failed = $false
    try { $null = Update-SagiLan } catch { $failed = $_.Exception.Message -like '*Injected write failure*' }
    Assert-Ui $failed 'Update did not report the injected failure'
    foreach ($entry in $fixtures.GetEnumerator()) {
      Assert-Ui ([IO.File]::ReadAllText($entry.Key) -eq $entry.Value) "Update left mismatched file $($entry.Key)"
    }
  }
  $script:failWrite = $OutputCache
  $failed = $false
  try { $null = Restore-SagiLan } catch { $failed = $_.Exception.Message -like '*Injected write failure*' }
  Assert-Ui $failed 'Restore did not report the injected failure'
  foreach ($entry in $fixtures.GetEnumerator()) {
    Assert-Ui ([IO.File]::ReadAllText($entry.Key) -eq $entry.Value) "Restore left mismatched file $($entry.Key)"
  }
  Assert-Ui ($script:ControlHtml -eq 'current-control' -and $script:OutputHtml -eq 'current-output') 'Failed operation changed the served pair'
  $script:failWrite = ''
  Assert-Ui ((Update-SagiLan).ok -and $script:ControlHtml.Contains('mdPenaltyCommitKick')) 'Successful update was not applied'
  Assert-Ui ((Restore-SagiLan).ok -and $script:ControlHtml -eq 'current-control' -and $script:OutputHtml -eq 'current-output') 'Successful rollback did not restore the preceding pair'
  Assert-Ui (@(Get-ChildItem -LiteralPath $root -Filter '*.tmp').Count -eq 0) 'Staged files were left behind'
  Write-Output 'PASS paired UI update, rollback, and injected write failures'
} finally {
  foreach ($file in (Get-ChildItem -LiteralPath $root -File)) { [IO.File]::Delete($file.FullName) }
  [IO.Directory]::Delete($root)
}
