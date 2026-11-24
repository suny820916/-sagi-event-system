import fs from "node:fs";

const path = "intro/SAGI_AUTO_TEST_V03.bat";
const source = fs.readFileSync(path, "utf8");

function requireContains(marker, label = marker) {
  if (!source.includes(marker)) throw new Error("Missing " + label);
}

function requireNotContains(marker, label = marker) {
  if (source.includes(marker)) throw new Error("Forbidden " + label);
}

requireContains("SAGI AUTO TEST V0.3");
requireContains("###SAGI_AUTO_TEST_PS###");
requireContains("http://127.0.0.1:8100");
requireContains("http://127.0.0.1:8088/api/");
requireNotContains("https://", "remote HTTPS dependency");
requireNotContains("http://192.", "hard-coded LAN host");
requireContains("snapshot-matchday");
requireContains("live-safety-guard");
requireContains("isolated-fixture-commit");
requireContains("score-roundtrip-home-plus");
requireContains("same-command-idempotent-retry");
requireContains("same-revision-conflict-guard");
requireContains("stale-revision-guard");
requireContains("penalty-start-roundtrip");
requireContains("penalty-home-goal-history-dot-state");
requireContains("penalty-undo-roundtrip");
requireContains("restore-original-match-state");
requireContains("restore-original-empty-state");
requireContains("allowFixtureTakeover");
requireContains("finally {");
requireContains("SAGI_AUTO_TEST_V03");
requireContains("latency-20x");
requireContains("Start-Process notepad.exe");
requireContains("scoreboardVisible' $false");
requireContains("overlayVisible' $false");

const snapshotIndex = source.indexOf("snapshot-matchday");
const mutationIndex = source.indexOf("isolated-fixture-commit");
const restoreIndex = source.indexOf("restore-original-match-state");
if (!(snapshotIndex >= 0 && mutationIndex > snapshotIndex && restoreIndex > mutationIndex)) {
  throw new Error("snapshot -> mutation -> restore ordering regressed");
}

const localhostUrls = [...source.matchAll(/https?:\/\/[^'"\s)]+/g)].map(m => m[0]);
for (const u of localhostUrls) {
  if (!u.startsWith("http://127.0.0.1:")) throw new Error("Non-local URL in AUTO TEST: " + u);
}

console.log("SAGI AUTO TEST V0.3 static safety audit PASS");
