const $ = (id) => document.getElementById(id);

const CLOUD_BASE = "https://sagi-cloud-bridge-suny820916.onrender.com";
const API_ROOT = CLOUD_BASE + "/api/match-intelligence";

const form = $("uploadForm");
const videoInput = $("videoInput");
const fileTitle = $("fileTitle");
const fileMeta = $("fileMeta");
const submitBtn = $("submitBtn");
const jobPanel = $("jobPanel");
const resultSection = $("resultSection");

let pollTimer = null;

async function checkCloud() {
  const badge = document.querySelector(".status-dot");
  try {
    const response = await fetch(API_ROOT + "/health", { cache: "no-store" });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error("offline");
    badge.textContent = "AI 云端已连接";
    badge.classList.remove("offline");
  } catch (_) {
    badge.textContent = "云端启动中";
    badge.classList.add("offline");
  }
}

videoInput.addEventListener("change", () => {
  const file = videoInput.files && videoInput.files[0];
  if (!file) return;
  fileTitle.textContent = file.name;
  fileMeta.textContent = (file.size / 1024 / 1024).toFixed(1) + " MB";
});

function formatSpeed(bytesPerSecond) {
  if (!Number.isFinite(bytesPerSecond) || bytesPerSecond <= 0) return "";
  if (bytesPerSecond >= 1024 * 1024) return (bytesPerSecond / 1024 / 1024).toFixed(1) + " MB/s";
  return Math.max(1, Math.round(bytesPerSecond / 1024)) + " KB/s";
}

function uploadMatch(body, attempt = 1) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const startedAt = Date.now();

    xhr.open("POST", API_ROOT + "/jobs", true);
    xhr.timeout = 180000;
    xhr.responseType = "json";

    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable) return;
      const pct = Math.max(1, Math.min(99, Math.round(event.loaded / event.total * 100)));
      const elapsed = Math.max(0.25, (Date.now() - startedAt) / 1000);
      const speed = formatSpeed(event.loaded / elapsed);

      jobPanel.classList.remove("hidden");
      $("jobId").textContent = "上传中";
      setProgress(pct, "正在上传比赛" + (speed ? " · " + speed : ""));
      submitBtn.querySelector("span").textContent = "上传 " + pct + "%";
    };

    xhr.onload = () => {
      let payload = xhr.response;
      if (!payload) {
        try { payload = JSON.parse(xhr.responseText || "{}"); } catch (_) { payload = {}; }
      }
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(payload || {});
      } else {
        reject(new Error((payload && (payload.error || payload.detail)) || ("上传失败 · HTTP " + xhr.status)));
      }
    };

    xhr.onerror = () => reject(new Error("网络中断，比赛视频没有完整上传。"));
    xhr.ontimeout = () => reject(new Error("上传超过 3 分钟，网络速度过慢或连接中断。"));
    xhr.onabort = () => reject(new Error("上传已取消。"));
    xhr.send(body);
  });
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const file = videoInput.files && videoInput.files[0];
  if (!file) return;

  if (file.size > 80 * 1024 * 1024) {
    alert("当前免费测试版单个视频最大 80MB。请先用 15–60 秒比赛片段测试。");
    return;
  }

  submitBtn.disabled = true;
  submitBtn.querySelector("span").textContent = "准备上传…";
  resultSection.classList.add("hidden");
  jobPanel.classList.remove("hidden");
  $("jobId").textContent = "准备中";
  setProgress(0, "正在连接 SAGI AI 云端");

  const buildBody = () => {
    const body = new FormData();
    body.append("video", file, file.name);
    body.append("home_team", $("homeTeam").value.trim() || "主队");
    body.append("away_team", $("awayTeam").value.trim() || "客队");
    body.append("match_format", $("matchFormat").value);
    return body;
  };

  try {
    let payload;
    try {
      payload = await uploadMatch(buildBody(), 1);
    } catch (firstError) {
      setProgress(0, "连接波动，正在自动重试一次");
      submitBtn.querySelector("span").textContent = "自动重试…";
      await new Promise((resolve) => setTimeout(resolve, 1200));
      payload = await uploadMatch(buildBody(), 2);
    }

    if (!payload || !payload.job_id) throw new Error("云端没有返回任务编号。");

    $("jobId").textContent = payload.job_id;
    setProgress(0, "视频上传完成，AI 排队中");
    submitBtn.querySelector("span").textContent = "AI 分析中…";
    startPolling(payload.job_id);
  } catch (error) {
    setProgress(0, "上传未完成");
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
      const response = await fetch(API_ROOT + "/jobs/" + jobId, { cache: "no-store" });
      const job = await response.json();
      if (!response.ok) throw new Error(job.error || job.detail || "任务读取失败");

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

  const base = API_ROOT + "/jobs/" + jobId + "/artifacts";
  $("trackingMap").src = base + "/" + result.tracking_map;
  $("homeHeatmap").src = base + "/" + home.heatmap;
  $("awayHeatmap").src = base + "/" + away.heatmap;

  resultSection.classList.remove("hidden");
  resultSection.scrollIntoView({ behavior: "smooth", block: "start" });
}

checkCloud();
setInterval(checkCloud, 60000);
