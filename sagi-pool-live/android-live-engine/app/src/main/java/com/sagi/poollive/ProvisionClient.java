package com.sagi.poollive;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class ProvisionClient {
    public static final class Config {
        public final String clubId;
        public final String clubName;
        public final String table;
        public final String token;
        public final String plan;
        public final int maxTables;
        public final long expiresAt;

        Config(String clubId, String clubName, String table, String token,
               String plan, int maxTables, long expiresAt) {
            this.clubId = clubId;
            this.clubName = clubName;
            this.table = table;
            this.token = token;
            this.plan = plan;
            this.maxTables = maxTables;
            this.expiresAt = expiresAt;
        }
    }

    public interface Callback {
        void onSuccess(Config config);
        void onError(String message);
    }

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    public void claim(String baseUrl, String code, String deviceId, String deviceLabel, Callback callback) {
        executor.execute(() -> {
            try {
                Config config = claimBlocking(baseUrl, code, deviceId, deviceLabel);
                main.post(() -> callback.onSuccess(config));
            } catch (Exception e) {
                String msg = e.getMessage() == null ? "安装码领取失败" : e.getMessage();
                main.post(() -> callback.onError(msg));
            }
        });
    }

    public void shutdown() {
        executor.shutdownNow();
    }

    private Config claimBlocking(String baseUrl, String code, String deviceId, String deviceLabel) throws Exception {
        String base = baseUrl.replaceAll("/+$", "");
        HttpURLConnection c = (HttpURLConnection)
                new URL(base + "/api/provision/claim").openConnection();
        c.setRequestMethod("POST");
        c.setDoOutput(true);
        c.setConnectTimeout(6000);
        c.setReadTimeout(6000);
        c.setRequestProperty("Content-Type", "application/json; charset=utf-8");

        JSONObject request = new JSONObject();
        request.put("code", code.trim().toUpperCase());
        request.put("deviceId", deviceId == null ? "" : deviceId);
        request.put("deviceLabel", deviceLabel == null ? "SAGI Android" : deviceLabel);

        try (OutputStream out = c.getOutputStream()) {
            out.write(request.toString().getBytes(StandardCharsets.UTF_8));
        }

        int status = c.getResponseCode();
        BufferedReader reader = new BufferedReader(new InputStreamReader(
                status >= 200 && status < 300 ? c.getInputStream() : c.getErrorStream(),
                StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) sb.append(line);
        reader.close();

        JSONObject root = new JSONObject(sb.toString().isEmpty() ? "{}" : sb.toString());
        if (status == 404 || status == 410) {
            throw new IllegalStateException("安装码无效、已使用或已过期");
        }
        if (status == 401) {
            throw new IllegalStateException("球房授权已失效");
        }
        if (status == 429) {
            throw new IllegalStateException("安装码尝试过多，请稍后再试");
        }
        if (status < 200 || status >= 300) {
            throw new IllegalStateException("安装失败 · " + root.optString("error", String.valueOf(status)));
        }

        JSONObject cfg = root.getJSONObject("config");
        return new Config(
                cfg.optString("clubId", ""),
                cfg.optString("clubName", ""),
                cfg.optString("table", ""),
                cfg.optString("token", ""),
                cfg.optString("plan", "CLUB"),
                cfg.optInt("maxTables", 1),
                cfg.optLong("expiresAt", 0)
        );
    }
}
