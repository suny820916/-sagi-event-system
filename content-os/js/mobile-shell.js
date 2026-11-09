(()=>{'use strict';
const C=window.SAGI_CORE;if(!C)return;const q=C.q;
window.SAGI_MOBILE={renderMatchday:()=>window.SAGI_MATCHDAY?.render?.(),renderVideoJobs:()=>window.SAGI_VIDEO_JOBS?.render?.(),renderReview:()=>window.SAGI_REVIEW?.render?.(),renderAll(){this.renderMatchday();this.renderVideoJobs();this.renderReview()}};
document.querySelectorAll('[data-match-event]').forEach(b=>b.onclick=()=>window.SAGI_MATCHDAY?.addMarker?.(b.dataset.matchEvent));
document.querySelectorAll('[data-match-recent]').forEach(b=>b.onclick=()=>window.SAGI_MATCHDAY?.addMarker?.(b.dataset.matchRecent,{recent:true}));
document.querySelectorAll('[data-goal-side]').forEach(b=>b.onclick=()=>window.SAGI_MATCHDAY?.goal?.(b.dataset.goalSide));
document.querySelectorAll('[data-score-side]').forEach(b=>b.onclick=()=>window.SAGI_MATCHDAY?.changeScore?.(b.dataset.scoreSide,Number(b.dataset.scoreDelta||0)));
if(q('matchClockBtn'))q('matchClockBtn').onclick=()=>window.SAGI_MATCHDAY?.toggleClock?.();if(q('matchResetBtn'))q('matchResetBtn').onclick=()=>window.SAGI_MATCHDAY?.reset?.();if(q('matchHalfBtn'))q('matchHalfBtn').onclick=()=>window.SAGI_MATCHDAY?.half?.();if(q('matchFullBtn'))q('matchFullBtn').onclick=()=>window.SAGI_MATCHDAY?.finish?.();if(q('matchUndoBtn'))q('matchUndoBtn').onclick=()=>window.SAGI_MATCHDAY?.undo?.();if(q('matchExportBtn'))q('matchExportBtn').onclick=()=>window.SAGI_MATCHDAY?.exportMarkers?.();if(q('matchHome'))q('matchHome').onchange=()=>window.SAGI_MATCHDAY?.setTeams?.();if(q('matchAway'))q('matchAway').onchange=()=>window.SAGI_MATCHDAY?.setTeams?.();
if(q('matchToJobBtn'))q('matchToJobBtn').onclick=()=>{C.switchView('videojobs');if(q('jobSource'))q('jobSource').value='matchday'};
document.querySelectorAll('[data-job-type]').forEach(b=>b.onclick=()=>window.SAGI_VIDEO_JOBS?.setType?.(b.dataset.jobType));if(q('jobCreateBtn'))q('jobCreateBtn').onclick=()=>window.SAGI_VIDEO_JOBS?.create?.();if(q('jobExportAllBtn'))q('jobExportAllBtn').onclick=()=>window.SAGI_VIDEO_JOBS?.exportAll?.();
document.addEventListener('click',e=>{const s=e.target.closest?.('[data-job-suggest]');if(s)window.SAGI_VIDEO_JOBS?.create?.(s.dataset.jobSuggest)});
document.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>{if(matchMedia('(max-width:900px)').matches)localStorage.setItem('sagi_mobile_view',b.dataset.view)}));
window.SAGI_MOBILE.renderAll();
if(matchMedia('(max-width:900px)').matches){const v=localStorage.getItem('sagi_mobile_view')||'matchday';if(['matchday','videojobs','review','daily','publish'].includes(v))C.switchView(v);else C.switchView('matchday')}
})();