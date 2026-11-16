package com.sagi.poollive;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class LiveSessionClient {
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    public void send(String baseUrl,
                     String clubId,
                     String deviceId,
                     String token,
                     String action,
                     int bitrate,
                     int fps,
                     int width,
                     int height,
                     String error) {
        executor.execute(() -> {
            try {
                String base = baseUrl == null ? "" : baseUrl.trim().replaceAll("/+$", "");
                if (base.isEmpty() || clubId == null || clubId.isEmpty()
                        || deviceId == null || deviceId.isEmpty()
                        || token == null || token.isEmpty()) {
                    return;
                }

                String endpoint = base + "/api/devices/"
                        + java.net.URLEncoder.encode(clubId, StandardCharsets.UTF_8)
                        + "/"
                        + java.net.URLEncoder.encode(deviceId, StandardCharsets.UTF_8)
                        + "/live";

                HttpURLConnection c = (HttpURLConnection) new URL(endpoint).openConnection();
                c.setRequestMethod("POST");
                c.setDoOutput(true);
                c.setConnectTimeout(4000);
                c.setReadTimeout(4000);
                c.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                c.setRequestProperty("X-SAGI-Token", token);

                JSONObject body = new JSONObject();
                body.put("action", action == null ? "heartbeat" : action);
                body.put("bitrate", Math.max(0, bitrate));
                body.put("fps", Math.max(0, fps));
                body.put("width", Math.max(0, width));
                body.put("height", Math.max(0, height));
                if (error != null && !error.isEmpty()) body.put("error", error);

                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
                try (OutputStream out = c.getOutputStream()) {
                    out.write(bytes);
                }

                c.getResponseCode();
                c.disconnect();
            } catch (Exception ignored) {
                // Telemetry must never interrupt the live stream.
            }
        });
    }

    public void shutdown() {
        executor.shutdownNow();
    }
}
