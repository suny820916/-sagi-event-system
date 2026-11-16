package com.sagi.poollive;

import android.os.Handler;
import android.os.Looper;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class ScoreSyncClient {
    public interface Listener {
        void onScore(ScoreState state);
        void onStatus(String status);
    }

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private volatile boolean running;

    public void start(String baseUrl, String clubId, String table, String token, Listener listener) {
        stop();
        running = true;
        executor.execute(() -> {
            while (running) {
                try {
                    ScoreState state = fetch(baseUrl, clubId, table, token);
                    if (state != null) main.post(() -> listener.onScore(state));
                    main.post(() -> listener.onStatus("比分同步已连接"));
                } catch (Exception e) {
                    String msg = e.getMessage() == null ? "同步失败" : e.getMessage();
                    main.post(() -> listener.onStatus(msg));
                }
                try {
                    Thread.sleep(900);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        });
    }

    public void stop() { running = false; }
    public void shutdown() { running = false; executor.shutdownNow(); }

    private ScoreState fetch(String baseUrl, String clubId, String table, String token) throws Exception {
        String base = baseUrl.replaceAll("/+$", "");
        String url = base + "/api/rooms/"
                + URLEncoder.encode(clubId, StandardCharsets.UTF_8)
                + "/" + URLEncoder.encode(table, StandardCharsets.UTF_8);

        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(5000);
        c.setReadTimeout(5000);
        c.setRequestProperty("X-SAGI-Token", token);
        c.setRequestProperty("Cache-Control", "no-store");

        int code = c.getResponseCode();
        if (code == 401) throw new IllegalStateException("授权无效或已到期");
        if (code == 403) throw new IllegalStateException("已超出授权球桌数");
        if (code < 200 || code >= 300) throw new IllegalStateException("同步错误 " + code);

        try (BufferedReader r = new BufferedReader(
                new InputStreamReader(c.getInputStream(), StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = r.readLine()) != null) sb.append(line);

            JSONObject root = new JSONObject(sb.toString());
            if (root.isNull("room")) return null;

            JSONObject room = root.getJSONObject("room");
            JSONObject state = room.getJSONObject("state");
            JSONArray players = state.optJSONArray("players");
            if (players == null || players.length() < 2) return null;

            JSONObject a = players.getJSONObject(0);
            JSONObject b = players.getJSONObject(1);
            boolean eight = "8ball".equals(state.optString("mode"));
            int s1 = eight ? a.optInt("wins") : a.optInt("score");
            int s2 = eight ? b.optInt("wins") : b.optInt("score");

            JSONArray logs = state.optJSONArray("log");
            int logCount = logs == null ? 0 : logs.length();
            JSONObject latest = logCount > 0 ? logs.optJSONObject(0) : null;
            String eventType = latest == null ? "" : latest.optString("type", "");
            String eventText = latest == null ? "" : latest.optString("text", "");
            String eventDelta = latest == null ? "" : latest.optString("delta", "");

            return new ScoreState(
                    state.optString("club", clubId),
                    state.optString("table", table),
                    state.optString("mode", ""),
                    a.optString("name", "球员A"),
                    b.optString("name", "球员B"),
                    s1, s2,
                    room.optLong("updatedAt"),
                    logCount,
                    eventType,
                    eventText,
                    eventDelta
            );
        } finally {
            c.disconnect();
        }
    }
}
