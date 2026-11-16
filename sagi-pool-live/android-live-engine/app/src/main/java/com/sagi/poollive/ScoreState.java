package com.sagi.poollive;

public final class ScoreState {
    public final String clubName, table, mode, player1, player2;
    public final int score1, score2;
    public final long updatedAt;

    public ScoreState(String clubName, String table, String mode, String player1, String player2,
                      int score1, int score2, long updatedAt) {
        this.clubName = clubName;
        this.table = table;
        this.mode = mode;
        this.player1 = player1;
        this.player2 = player2;
        this.score1 = score1;
        this.score2 = score2;
        this.updatedAt = updatedAt;
    }

    public String signature() {
        return player1 + "|" + score1 + "|" + score2 + "|" + player2 + "|" + mode;
    }
}
