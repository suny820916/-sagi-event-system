const $ = (id) => document.getElementById(id);

const form = $("uploadForm");
const videoInput = $("videoInput");
const fileTitle = $("fileTitle");
const fileMeta = $("fileMeta");
const submitBtn = $("submitBtn");
const jobPanel = $("jobPanel");
const resultSection = $("resultSection");

let pollTimer = null;

videoInput.addEventListener("change", () => {
  const file = videoInput.files && videoInput.files[0];
  if (!file) return;
  fileTitle.textContent = file.name;
  fileMeta.textContent = (file.size / 1024 / 1024).toFixed(1) + " MB";
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const file = videoInput.files && videoInput.files[0];
  if (!file) return;

  submitBtn.disabled = true;
  submitBtn.querySelector("span").textContent = "正在上传比赛…";
  resultSection.classList.add("hidden");

  const body = new FormData();
  body.append("video", file);
  body.append("home_team", $("homeTeam").value.trim() || "主队");
  body.append("away_team", $("awayTeam").value.trim() || "客队");
  body.append("match_format", $("matchFormat").value);

  try {
    const response = await fetch("/api/v1/jobs", { method: "POST", body: body });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.detail || "上传失败");

    jobPanel.classList.remove("hidden");
    $("jobId").textContent = payload.job_id;
    setProgress(0, "视频上传完成，AI排队中");
    startPolling(payload.job_id);
  } catch (error) {
    alert(error.message || "上传失败");
    resetSubmit();
  }
});

function setProgress(value, message) {
  const safe = Math.max(0, Math.min(100, Number(value || 0)));
  $("progressBar").style.width = safe + "%";
  $("progressText").textContent = Math.round(safe) + "%";
  $("jobMessage").textContent = message || "分析中";
}

function startPolling(jobId) {
  if (pollTimer) clearInterval(pollTimer);

  const poll = async () => {
    try {
      const response = await fetch("/api/v1/jobs/" + jobId, { cache: "no-store" });
      const job = await response.json();
      if (!response.ok) throw new Error(job.detail || "任务读取失败");

      setProgress(job.progress, job.message);

      if (job.status === "completed") {
        clearInterval(pollTimer);
        pollTimer = null;
        resetSubmit();
        renderResult(jobId, job.result);
      } else if (job.status === "failed") {
        clearInterval(pollTimer);
        pollTimer = null;
        resetSubmit();
        alert("分析失败：" + (job.message || job.error || "未知错误"));
      }
    } catch (error) {
      console.error(error);
    }
  };

  poll();
  pollTimer = setInterval(poll, 2500);
}

function resetSubmit() {
  submitBtn.disabled = false;
  submitBtn.querySelector("span").textContent = "开始 AI 分析";
}

function renderResult(jobId, result) {
  if (!result) return;

  const home = result.teams.home;
  const away = result.teams.away;
  const video = result.video;

  $("matchTitle").textContent = home.name + " VS " + away.name;
  $("homeName").textContent = home.name;
  $("awayName").textContent = away.name;
  $("homePoss").textContent = home.possession_percent + "%";
  $("awayPoss").textContent = away.possession_percent + "%";
  $("homeTracks").textContent = home.tracked_players;
  $("awayTracks").textContent = away.tracked_players;
  $("sampledFrames").textContent = Number(video.sampled_frames || 0).toLocaleString();
  $("ballFrames").textContent = Number(video.ball_seen_samples || 0).toLocaleString();

  $("homeHeatTitle").textContent = home.name + " · 热区";
  $("awayHeatTitle").textContent = away.name + " · 热区";

  const base = "/api/v1/jobs/" + jobId + "/artifacts";
  $("previewVideo").src = base + "/analysis-preview.mp4";
  $("homeHeatmap").src = base + "/" + home.heatmap;
  $("awayHeatmap").src = base + "/" + away.heatmap;

  resultSection.classList.remove("hidden");
  resultSection.scrollIntoView({ behavior: "smooth", block: "start" });
}
