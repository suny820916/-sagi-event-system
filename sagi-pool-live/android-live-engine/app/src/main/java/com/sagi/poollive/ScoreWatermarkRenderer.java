package com.sagi.poollive;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;

public final class ScoreWatermarkRenderer {
    private static final int W = 1200;
    private static final int H = 150;

    public Bitmap render(ScoreState state) {
        Bitmap bitmap = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(bitmap);

        Paint dark = new Paint(Paint.ANTI_ALIAS_FLAG);
        dark.setColor(Color.argb(232, 7, 9, 8));
        c.drawRoundRect(new RectF(0, 0, W, H), 24, 24, dark);

        Paint center = new Paint(Paint.ANTI_ALIAS_FLAG);
        center.setColor(Color.rgb(242, 244, 241));
        c.drawRect(470, 0, 730, H, center);

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

        c.drawText(trim(state.player1, 13), 34, 65, name);
        name.setTextAlign(Paint.Align.RIGHT);
        c.drawText(trim(state.player2, 13), W - 34, 65, name);
        name.setTextAlign(Paint.Align.LEFT);
        c.drawText(trim(state.clubName + " · " + state.table, 28), 34, 112, sub);
        sub.setTextAlign(Paint.Align.RIGHT);
        c.drawText(modeName(state.mode), W - 34, 112, sub);
        c.drawText(state.score1 + " : " + state.score2, W / 2f, 96, score);
        return bitmap;
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
