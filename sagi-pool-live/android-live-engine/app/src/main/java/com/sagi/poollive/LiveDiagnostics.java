package com.sagi.poollive;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public final class LiveDiagnostics {
    private static final String STORE = "sagi_pool_diagnostics_v1";
    private static final String KEY = "events";
    private static final int MAX_EVENTS = 200;
    private final SharedPreferences prefs;

    public LiveDiagnostics(Context context) {
        prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE);
    }

    public synchronized void add(String type, String detail) {
        try {
            JSONArray old = new JSONArray(prefs.getString(KEY, "[]"));
            JSONArray next = new JSONArray();
            JSONObject e = new JSONObject();
            e.put("ts", System.currentTimeMillis());
            e.put("type", sanitize(type, 48));
            e.put("detail", sanitize(detail, 180));
            next.put(e);

            int limit = Math.min(old.length(), MAX_EVENTS - 1);
            for (int i = 0; i < limit; i++) next.put(old.get(i));
            prefs.edit().putString(KEY, next.toString()).apply();
        } catch (Exception ignored) {}
    }

    public synchronized String exportText(int maxLines) {
        StringBuilder out = new StringBuilder();
        try {
            JSONArray arr = new JSONArray(prefs.getString(KEY, "[]"));
            SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA);
            int limit = Math.min(arr.length(), Math.max(1, maxLines));
            for (int i = 0; i < limit; i++) {
                JSONObject e = arr.optJSONObject(i);
                if (e == null) continue;
                out.append(format.format(new Date(e.optLong("ts"))))
                        .append("  ")
                        .append(e.optString("type"))
                        .append("  ")
                        .append(e.optString("detail"))
                        .append("\n");
            }
        } catch (Exception ignored) {}
        return out.toString();
    }

    public synchronized void clear() {
        prefs.edit().remove(KEY).apply();
    }

    private String sanitize(String v, int max) {
        String s = v == null ? "" : v.replaceAll("[\\r\\n]+", " ").trim();
        s = s.replaceAll("(?i)rtmps?://\\S+", "[RTMP hidden]");
        s = s.replaceAll("(?i)(token|secret|key)=([^\\s&]+)", "$1=[hidden]");
        return s.length() <= max ? s : s.substring(0, max);
    }
}
