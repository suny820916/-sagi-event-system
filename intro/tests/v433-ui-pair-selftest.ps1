$ErrorActionPreference = 'Stop'
$bat = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../SAGI_VMIX_LAN_V433_PENALTY_RC.bat'))
$match = [regex]::Match($bat, '(?ms)^function Write-SagiUiFile\(.*?(?=^function Get-LanIPv4)')
if (!$match.Success) { throw 'Candidate UI file operations missing' }
. ([scriptblock]::Create($match.Value))
$stateFunctions = [regex]::Match($bat, '(?ms)^function Read-SagiMatchdaySnapshot\(.*?(?=^\$MatchdayJson = Restore-SagiMatchdaySnapshot)')
if (!$stateFunctions.Success) { throw 'Candidate match state persistence functions missing' }
. ([scriptblock]::Create($stateFunctions.Value))

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
  $UiPairStamp = Join-Path $root 'ui-pair-v433.txt'
  $script:UiPackageDigest = 'test-package'
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
  foreach ($failure in @($OutputCache, $OutputBackup, $UiPairStamp)) {
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

  $embeddedControl = Join-Path $root 'fallback-control.html'
  $embeddedOutput = Join-Path $root 'fallback-output.html'
  [IO.File]::WriteAllText($embeddedControl, 'packaged-control-a')
  [IO.File]::WriteAllText($embeddedOutput, 'packaged-output-a')
  $matchState = Join-Path $root 'matchday-state.json'
  [IO.File]::WriteAllText($matchState, '{"score":3}')
  Initialize-SagiUiPair $embeddedControl $embeddedOutput
  Assert-Ui ([IO.File]::ReadAllText($ControlCache) -eq 'packaged-control-a' -and [IO.File]::ReadAllText($OutputCache) -eq 'packaged-output-a') 'First launch kept unverified caches'
  Assert-Ui ((Update-SagiLan).ok) 'Manual update failed'
  Initialize-SagiUiPair $embeddedControl $embeddedOutput
  Assert-Ui ([IO.File]::ReadAllText($ControlCache).Contains('mdPenaltyCommitKick')) 'Same package restart overwrote verified manual update'
  Assert-Ui ((Restore-SagiLan).ok) 'Manual rollback failed'
  Initialize-SagiUiPair $embeddedControl $embeddedOutput
  Assert-Ui ([IO.File]::ReadAllText($ControlCache) -eq 'packaged-control-a') 'Same package restart overwrote verified rollback'

  [IO.File]::WriteAllText($embeddedControl, 'packaged-control-b')
  [IO.File]::WriteAllText($embeddedOutput, 'packaged-output-b')
  Initialize-SagiUiPair $embeddedControl $embeddedOutput
  Assert-Ui ([IO.File]::ReadAllText($ControlCache) -eq 'packaged-control-b' -and [IO.File]::ReadAllText($OutputCache) -eq 'packaged-output-b') 'New package did not replace the prior UI pair'
  [IO.File]::WriteAllText($ControlCache, 'partial-write')
  Initialize-SagiUiPair $embeddedControl $embeddedOutput
  Assert-Ui ([IO.File]::ReadAllText($ControlCache) -eq 'packaged-control-b' -and [IO.File]::ReadAllText($OutputCache) -eq 'packaged-output-b') 'Damaged cache did not restore the packaged pair'
  Assert-Ui ([IO.File]::ReadAllText($matchState) -eq '{"score":3}') 'UI package initialization touched saved match state'
  Write-Output 'PASS exact package identity, same-package restart, cache repair and match state preservation'

  $revisionOne = '{"fixtureKey":"isolated","revision":1,"homeScore":1,"event":{"type":"GOAL"},"lastEvent":{"type":"GOAL"}}'
  $revisionTwo = '{"fixtureKey":"isolated","revision":2,"homeScore":2}'
  $revisionThree = '{"fixtureKey":"isolated","revision":3,"homeScore":3}'
  Write-SagiMatchdaySnapshot $matchState $revisionOne -KeepPrevious
  Write-SagiMatchdaySnapshot $matchState $revisionTwo -KeepPrevious
  Write-SagiMatchdaySnapshot $matchState $revisionThree -KeepPrevious
  Assert-Ui (((Restore-SagiMatchdaySnapshot $matchState | ConvertFrom-Json).revision) -eq 3) 'Primary revision not preferred'
  [IO.File]::WriteAllText($matchState, 'broken')
  Assert-Ui (((Restore-SagiMatchdaySnapshot $matchState | ConvertFrom-Json).revision) -eq 2) 'Existing backup not recovered'
  Write-SagiMatchdaySnapshot $matchState $revisionOne -KeepPrevious
  Assert-Ui (((Restore-SagiMatchdaySnapshot $matchState | ConvertFrom-Json).event) -eq $null) 'Recovered state replayed live graphics'
  [IO.File]::WriteAllText($matchState, 'broken-again')
  Assert-Ui (((Restore-SagiMatchdaySnapshot $matchState | ConvertFrom-Json).revision) -eq 2) 'Corrupt primary overwrote the valid backup'
  Clear-SagiMatchdaySnapshot $matchState
  Assert-Ui ((Restore-SagiMatchdaySnapshot $matchState) -eq 'null') 'Reset did not survive restart'
  [IO.File]::WriteAllText($matchState, 'broken-reset')
  Assert-Ui ((Restore-SagiMatchdaySnapshot $matchState) -eq 'null') 'Corrupt reset revived an older match'
  [IO.File]::Delete($matchState)
  [IO.File]::WriteAllText(($matchState + '.bak'), $revisionOne)
  Assert-Ui ((Restore-SagiMatchdaySnapshot $matchState) -eq 'null') 'Legacy reset revived a backup without a primary file'
  Write-SagiMatchdaySnapshot $matchState $revisionTwo -KeepPrevious
  [IO.File]::WriteAllText($matchState, 'broken-new-match')
  Assert-Ui ((Restore-SagiMatchdaySnapshot $matchState) -eq 'null') 'First write after legacy reset kept an old backup'
  Write-Output 'PASS match state primary, backup, recovery, durable reset and legacy reset'

} finally {
  foreach ($file in (Get-ChildItem -LiteralPath $root -File)) { [IO.File]::Delete($file.FullName) }
  [IO.Directory]::Delete($root)
}
