package com.sagi.poollive;

public final class ScoreState {
    public final String clubName, table, mode, player1, player2;
    public final int score1, score2;
    public final long updatedAt;
    public final int logCount;
    public final String lastEventType, lastEventText, lastEventDelta;

    public ScoreState(String clubName, String table, String mode, String player1, String player2,
                      int score1, int score2, long updatedAt, int logCount,
                      String lastEventType, String lastEventText, String lastEventDelta) {
        this.clubName = clubName;
        this.table = table;
        this.mode = mode;
        this.player1 = player1;
        this.player2 = player2;
        this.score1 = score1;
        this.score2 = score2;
        this.updatedAt = updatedAt;
        this.logCount = logCount;
        this.lastEventType = lastEventType;
        this.lastEventText = lastEventText;
        this.lastEventDelta = lastEventDelta;
    }

    public String signature() {
        return player1 + "|" + score1 + "|" + score2 + "|" + player2 + "|" + mode;
    }

    public boolean hasBroadcastEvent() {
        return "大金".equals(lastEventType)
                || "小金".equals(lastEventType)
                || "黄金9".equals(lastEventType)
                || "胜局".equals(lastEventType)
                || "8号球犯规".equals(lastEventType);
    }
}
