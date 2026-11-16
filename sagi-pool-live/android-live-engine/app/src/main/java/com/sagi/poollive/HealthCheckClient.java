package com.sagi.poollive;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class HealthCheckClient {
    public interface Callback {
        void onSuccess(String serverVersion);
        void onError(String message);
    }

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    public void check(String baseUrl, String clubId, String table, String token, Callback callback) {
        executor.execute(() -> {
            try {
                String version = checkBlocking(baseUrl, clubId, table, token);
                main.post(() -> callback.onSuccess(version));
            } catch (Exception e) {
                String msg = e.getMessage() == null ? "网络检测失败" : e.getMessage();
                main.post(() -> callback.onError(msg));
            }
        });
    }

    public void shutdown() {
        executor.shutdownNow();
    }

    private String checkBlocking(String baseUrl, String clubId, String table, String token) throws Exception {
        String base = baseUrl.replaceAll("/+$", "");

        HttpURLConnection health = open(base + "/health", "");
        int healthCode = health.getResponseCode();
        if (healthCode < 200 || healthCode >= 300) {
            health.disconnect();
            throw new IllegalStateException("国内服务器健康检查失败 · " + healthCode);
        }
        JSONObject healthJson = readJson(health);
        String version = healthJson.optString("version", "unknown");
        health.disconnect();

        String roomUrl = base + "/api/rooms/"
                + URLEncoder.encode(clubId, StandardCharsets.UTF_8)
                + "/" + URLEncoder.encode(table, StandardCharsets.UTF_8);
        HttpURLConnection room = open(roomUrl, token);
        int code = room.getResponseCode();
        JSONObject body = readJson(room);
        room.disconnect();

        if (code == 401) throw new IllegalStateException("球房授权无效或已到期");
        if (code == 403) throw new IllegalStateException("该球桌超出购买数量");
        if (code < 200 || code >= 300) {
            throw new IllegalStateException("比分同步检测失败 · " + body.optString("error", String.valueOf(code)));
        }
        return version;
    }

    private HttpURLConnection open(String url, String token) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(5000);
        c.setReadTimeout(5000);
        c.setRequestProperty("Cache-Control", "no-store");
        if (token != null && !token.isEmpty()) c.setRequestProperty("X-SAGI-Token", token);
        return c;
    }

    private JSONObject readJson(HttpURLConnection c) throws Exception {
        int code = c.getResponseCode();
        BufferedReader reader = new BufferedReader(new InputStreamReader(
                code >= 200 && code < 300 ? c.getInputStream() : c.getErrorStream(),
                StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) sb.append(line);
        reader.close();
        return new JSONObject(sb.toString().isEmpty() ? "{}" : sb.toString());
    }
}
