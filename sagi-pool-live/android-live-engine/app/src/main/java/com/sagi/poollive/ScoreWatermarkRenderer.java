package com.sagi.poollive;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;

public final class ScoreWatermarkRenderer {
    private static final int W = 1200;
    private static final int SCORE_H = 150;

    public Bitmap render(ScoreState state) {
        Bitmap bitmap = Bitmap.createBitmap(W, SCORE_H, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(bitmap);
        drawScore(c, state, 0);
        return bitmap;
    }

    public Bitmap renderEvent(ScoreState state, int phase) {
        Bitmap bitmap = Bitmap.createBitmap(W, 340, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(bitmap);
        drawScore(c, state, 0);

        int alpha = phase <= 0 ? 145 : phase == 1 ? 215 : 245;
        float inset = phase <= 0 ? 54f : phase == 1 ? 24f : 8f;
        float top = 174f + (phase <= 0 ? 18f : phase == 1 ? 7f : 0f);

        Paint banner = new Paint(Paint.ANTI_ALIAS_FLAG);
        banner.setColor(Color.argb(alpha, 8, 10, 9));
        c.drawRoundRect(new RectF(inset, top, W - inset, 332), 28, 28, banner);

        Paint accent = new Paint(Paint.ANTI_ALIAS_FLAG);
        accent.setColor(eventAccent(state.lastEventType));
        c.drawRoundRect(new RectF(inset + 18, top + 18, inset + 30, 314), 6, 6, accent);

        Paint title = new Paint(Paint.ANTI_ALIAS_FLAG);
        title.setColor(Color.WHITE);
        title.setTextSize(58);
        title.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        c.drawText(eventEnglish(state.lastEventType), inset + 54, top + 72, title);

        Paint detail = new Paint(Paint.ANTI_ALIAS_FLAG);
        detail.setColor(Color.rgb(211, 220, 214));
        detail.setTextSize(31);
        detail.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));

        String detailText = state.lastEventType == null ? "" : state.lastEventType;
        if (state.lastEventDelta != null && !state.lastEventDelta.isEmpty()) {
            detailText += "  " + state.lastEventDelta;
        }
        if (state.lastEventText != null && !state.lastEventText.isEmpty()) {
            detailText += "  ·  " + trim(state.lastEventText, 28);
        }
        c.drawText(detailText, inset + 54, top + 124, detail);
        return bitmap;
    }

    private void drawScore(Canvas c, ScoreState state, float y) {
        Paint dark = new Paint(Paint.ANTI_ALIAS_FLAG);
        dark.setColor(Color.argb(235, 7, 9, 8));
        c.drawRoundRect(new RectF(0, y, W, y + SCORE_H), 24, 24, dark);

        Paint center = new Paint(Paint.ANTI_ALIAS_FLAG);
        center.setColor(Color.rgb(242, 244, 241));
        c.drawRect(470, y, 730, y + SCORE_H, center);

        Paint name = new Paint(Paint.ANTI_ALIAS_FLAG);
        name.setColor(Color.WHITE);
        name.setTextSize(44);
        name.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));

        Paint sub = new Paint(Paint.ANTI_ALIAS_FLAG);
        sub.setColor(Color.rgb(170, 180, 173));
        sub.setTextSize(25);

        Paint score = new Paint(Paint.ANTI_ALIAS_FLAG);
        score.setColor(Color.rgb(9, 11, 10));
        score.setTextSize(66);
        score.setTextAlign(Paint.Align.CENTER);
        score.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));

        c.drawText(trim(state.player1, 13), 34, y + 65, name);
        name.setTextAlign(Paint.Align.RIGHT);
        c.drawText(trim(state.player2, 13), W - 34, y + 65, name);
        name.setTextAlign(Paint.Align.LEFT);

        c.drawText(trim(state.clubName + " · " + state.table, 28), 34, y + 112, sub);
        sub.setTextAlign(Paint.Align.RIGHT);
        c.drawText(modeName(state.mode), W - 34, y + 112, sub);

        c.drawText(state.score1 + " : " + state.score2, W / 2f, y + 96, score);
    }

    private int eventAccent(String type) {
        if ("大金".equals(type) || "黄金9".equals(type)) return Color.rgb(215, 180, 106);
        if ("小金".equals(type)) return Color.rgb(115, 202, 154);
        if ("8号球犯规".equals(type)) return Color.rgb(244, 92, 103);
        return Color.rgb(238, 242, 238);
    }

    private String eventEnglish(String type) {
        if ("大金".equals(type)) return "BIG GOLDEN";
        if ("小金".equals(type)) return "SMALL GOLDEN";
        if ("黄金9".equals(type)) return "GOLDEN 9";
        if ("胜局".equals(type)) return "RACK WIN";
        if ("8号球犯规".equals(type)) return "8-BALL FOUL";
        return "SCORE UPDATE";
    }

    private String trim(String s, int n) {
        if (s == null) return "";
        return s.length() <= n ? s : s.substring(0, Math.max(1, n - 1)) + "…";
    }

    private String modeName(String mode) {
        if ("8ball".equals(mode)) return "中式八球";
        if ("chase4".equals(mode)) return "4球追分";
        if ("chase6".equals(mode)) return "6球追分";
        if ("chase9".equals(mode)) return "9球追分";
        return "SAGI POOL";
    }
}
