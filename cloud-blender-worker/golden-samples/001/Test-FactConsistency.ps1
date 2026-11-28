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
if($x.ready_for_director -or $x.identity_status -ne 'uncertain' -or
   $x.final_pass.status -ne 'uncertain' -or $x.shot.status -ne 'uncertain' -or
   $goal.exact_frame_verified -or $null -ne $x.goal_completed_timestamp){
    throw 'An unresolved claim was promoted.'
}
"PASS: $($pts.Count) PTS, $($x.events.Count) action intervals. Director gate remains closed."
