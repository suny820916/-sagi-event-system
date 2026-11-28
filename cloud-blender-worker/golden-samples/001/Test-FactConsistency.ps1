param([string]$SampleDir=$PSScriptRoot, [string]$SourceVideo)
$ErrorActionPreference='Stop'
$x=Get-Content (Join-Path $SampleDir 'REAL_MATCH_EVENT.json') -Raw|ConvertFrom-Json
$pts=@(Get-Content (Join-Path $SampleDir 'extended-timestamps.csv')|ForEach-Object {[double]$_})
if($SourceVideo -and (Get-FileHash -LiteralPath $SourceVideo).Hash -ne $x.source.sha256){throw 'Source hash mismatch.'}
if($pts.Count -ne $x.source.frame_count){throw 'Frame count mismatch.'}
for($i=1;$i -lt $pts.Count;$i++){if($pts[$i] -le $pts[$i-1]){throw "Non-increasing PTS at $i."}}
$lastStart=-1
foreach($e in $x.events){
    $start,$end=$e.source_frames
    if($start -lt $lastStart -or $start -gt $end -or $end -ge $pts.Count){throw 'Invalid event ordering or frame span.'}
    if($e.source_timestamp -ne $pts[$start] -or $e.end_timestamp -ne $pts[$end]){throw 'Event PTS mismatch.'}
    if($e.player -and $e.player -notin $x.players.PSObject.Properties.Name){throw 'Unknown player ID.'}
    if($e.verified -isnot [bool] -or $e.uncertain.Count -eq 0){throw 'Missing fact status or uncertainty.'}
    $lastStart=$start
}
$goal=$x.goal_completion_window
if($x.events[0].source_frames[0] -ne 0 -or $x.events[-1].source_frames[1] -ne ($pts.Count-1) -or
   $goal.start_timestamp -ne $pts[$goal.start_frame] -or $goal.end_timestamp -ne $pts[$goal.end_frame]){
    throw 'Defense-to-result scope or goal evidence mismatch.'
}
if($x.identity_status -ne 'uncertain' -or
   $x.final_pass.status -ne 'uncertain' -or $x.shot.status -ne 'uncertain' -or
   $goal.exact_frame_verified -or $null -ne $x.goal_completed_timestamp){
    throw 'An unresolved claim was promoted.'
}
"PASS: $($pts.Count) PTS, $($x.events.Count) action intervals."
if ($x.identity_evidence.basis -ne 'user_verified' -or $x.identity_evidence.video_recognition) {
    throw 'External identity evidence was promoted to video recognition.'
}
$requiredChecks = 'interception','regain','scan','receive','release','run_start','first_touch','keeper_charge','shot_contact','keeper_path_and_crossing'
if ($x.second_pass.Count -ne $requiredChecks.Count -or (Compare-Object $requiredChecks @($x.second_pass.id))) {
    throw 'Second-pass review does not cover every requested checkpoint.'
}
foreach ($event in $x.events) {
    $expected = if ($event.verified) { 'video_verified' } else { 'uncertain' }
    if ($event.evidence_status -ne $expected) { throw 'Event evidence class mismatch.' }
}
foreach ($review in $x.second_pass) {
    if ($review.evidence_status -ne 'uncertain' -or $null -ne $review.exact_frame) {
        throw "Unresolved checkpoint was promoted: $($review.id)"
    }
    if ($null -ne $review.review_frames) {
        $first,$last = $review.review_frames
        if ($first -lt 0 -or $last -lt $first -or $last -ge $pts.Count -or
            $review.review_timestamps[0] -ne $pts[$first] -or $review.review_timestamps[1] -ne $pts[$last]) {
            throw "Review window does not match source PTS: $($review.id)"
        }
    } elseif ($null -ne $review.review_timestamps) {
        throw "Review time lacks frame evidence: $($review.id)"
    }
}
$keyframePath = Join-Path $SampleDir 'KEYFRAMES.svg'
[xml]$keyframeSheet = Get-Content $keyframePath -Raw
$keyframeLabels = $keyframeSheet.SelectNodes("//*[local-name()='text']")
if ($keyframeLabels.Count -ne 24) { throw 'Keyframe sheet count mismatch.' }
foreach ($label in $keyframeLabels) {
    if ($label.InnerText -notmatch '^(\d+) \| (\d+[.]\d+)s$') { throw 'Malformed keyframe label.' }
    $frame = [int]$Matches[1]
    if ($frame -ge $pts.Count -or [double]$Matches[2] -ne $pts[$frame]) { throw 'Keyframe PTS mismatch.' }
}
'PASS: 10 second-pass checkpoints, 24 labeled source keyframes, separated identity evidence.'
foreach ($review in $x.second_pass | Where-Object { $null -ne $_.candidate_frames }) {
    $first,$last = $review.candidate_frames
    if ($first -lt $review.review_frames[0] -or $last -gt $review.review_frames[1] -or $last -lt $first -or
        $review.candidate_timestamps[0] -ne $pts[$first] -or $review.candidate_timestamps[1] -ne $pts[$last]) {
        throw "Candidate evidence mismatch: $($review.id)"
    }
}
'PASS: candidate windows and evidence sheets match the source timeline.'

$coreIds = 'psv_right','cross','interception','transition','support_scan','depth_pass','early_run','behind_line','running_receive','keeper_charge','finish','goal','causal_order'
if ($x.core_facts.Count -ne $coreIds.Count -or (Compare-Object $coreIds @($x.core_facts.id))) {
    throw 'Required tactical chain is incomplete.'
}
foreach ($fact in $x.core_facts) {
    $first,$last = $fact.source_frames
    if ($first -lt 0 -or $last -lt $first -or $last -ge $pts.Count -or
        $fact.source_timestamps[0] -ne $pts[$first] -or $fact.source_timestamps[1] -ne $pts[$last] -or
        $fact.evidence_status -notin 'video_verified','user_verified','externally_verified' -or
        -not $fact.video_behavior_consistent -or [string]::IsNullOrWhiteSpace($fact.evidence)) {
        throw "Missing or inconsistent core evidence: $($fact.id)"
    }
}
$log = Get-Content (Join-Path $SampleDir 'UNCERTAINTY_LOG.json') -Raw | ConvertFrom-Json
if ($log.source_sha256 -ne $x.source.sha256 -or
    (Compare-Object @($log.items.id) @($x.non_blocking_uncertainties)) -or
    ($log.items | Where-Object status -ne 'uncertain') -or $x.production_blockers.Count -ne 0 -or
    -not $x.ready_for_director) { throw 'Core gate and uncertainty log disagree.' }
if ($x.named_core_actions.interception -ne '胡伊森' -or $x.final_pass.player -ne '贝林厄姆' -or
    $x.shot.player_name -ne '维尼修斯' -or $x.named_core_actions.goal -ne '维尼修斯' -or
    $x.final_pass.identity_evidence -ne 'user_verified' -or $x.shot.identity_evidence -ne 'user_verified') {
    throw 'User-confirmed core identity mapping mismatch.'
}
'PASS: 13 core facts and 8 non-blocking uncertainties. Director gate open.'
