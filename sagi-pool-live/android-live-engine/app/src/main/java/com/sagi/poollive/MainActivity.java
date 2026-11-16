package com.sagi.poollive;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import com.tencent.live2.V2TXLiveCode;
import com.tencent.live2.V2TXLiveDef;
import com.tencent.live2.V2TXLivePusher;
import com.tencent.live2.impl.V2TXLivePusherImpl;
import com.tencent.rtmp.ui.TXCloudVideoView;
import java.util.Map;

public class MainActivity extends AppCompatActivity {
    private TXCloudVideoView preview;
    private V2TXLivePusher pusher;
    private final ScoreSyncClient syncClient = new ScoreSyncClient();
    private final ScoreWatermarkRenderer watermarkRenderer = new ScoreWatermarkRenderer();
    private TextView status, player1, player2, score;
    private EditText syncUrl, clubId, tableNo, syncToken, rtmpUrl;
    private String lastSignature = "";

    private final ActivityResultLauncher<String[]> permissionLauncher =
            registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), this::onPermissions);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_main);

        preview = findViewById(R.id.preview);
        status = findViewById(R.id.status);
        player1 = findViewById(R.id.player1);
        player2 = findViewById(R.id.player2);
        score = findViewById(R.id.score);
        syncUrl = findViewById(R.id.syncUrl);
        clubId = findViewById(R.id.clubId);
        tableNo = findViewById(R.id.tableNo);
        syncToken = findViewById(R.id.syncToken);
        rtmpUrl = findViewById(R.id.rtmpUrl);

        ((Button)findViewById(R.id.startButton)).setOnClickListener(v -> startLive());
        ((Button)findViewById(R.id.stopButton)).setOnClickListener(v -> stopLive());

        pusher = new V2TXLivePusherImpl(this, V2TXLiveDef.V2TXLiveMode.TXLiveMode_RTMP);
        pusher.setRenderView(preview);
        requestMediaPermissions();
    }

    private void requestMediaPermissions() {
        boolean camera = checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
        boolean audio = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
        if (camera && audio) startPreview();
        else permissionLauncher.launch(new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO});
    }

    private void onPermissions(Map<String, Boolean> grants) {
        if (Boolean.TRUE.equals(grants.get(Manifest.permission.CAMERA))) startPreview();
        else status.setText("需要摄像头权限");
    }

    private void startPreview() {
        pusher.startCamera(false);
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) pusher.startMicrophone();
        status.setText("后置摄像头已开启 · 等待推流");
    }

    private void startLive() {
        String push = rtmpUrl.getText().toString().trim();
        String api = syncUrl.getText().toString().trim();
        String cid = clubId.getText().toString().trim();
        String table = tableNo.getText().toString().trim();
        String token = syncToken.getText().toString();

        if (!push.startsWith("rtmp://") && !push.startsWith("rtmps://")) {
            status.setText("请填写合法 RTMP / RTMPS 推流地址");
            return;
        }
        if (api.isEmpty() || cid.isEmpty() || table.isEmpty()) {
            status.setText("请填写国内同步服务器、Club ID 和球桌");
            return;
        }

        V2TXLiveDef.V2TXLiveVideoEncoderParam video =
                new V2TXLiveDef.V2TXLiveVideoEncoderParam(
                        V2TXLiveDef.V2TXLiveVideoResolution.V2TXLiveVideoResolution1280x720);
        video.videoResolutionMode = V2TXLiveDef.V2TXLiveVideoResolutionMode.V2TXLiveVideoResolutionModeLandscape;
        video.videoBitrate = 1600;
        video.minVideoBitrate = 900;
        video.videoFps = 24;
        pusher.setVideoQuality(video);

        int result = pusher.startPush(push);
        if (result != V2TXLiveCode.V2TXLIVE_OK) {
            status.setText("推流启动失败 · " + result);
            return;
        }

        status.setText("LIVE · RTMP 推流中");
        syncClient.start(api, cid, table, token, new ScoreSyncClient.Listener() {
            @Override public void onScore(ScoreState state) { updateScore(state); }
            @Override public void onStatus(String message) {
                if (!message.contains("已连接")) status.setText(message);
            }
        });
    }

    private void updateScore(ScoreState state) {
        player1.setText(state.player1);
        player2.setText(state.player2);
        score.setText(state.score1 + " : " + state.score2);
        String signature = state.signature();
        if (!signature.equals(lastSignature)) {
            pusher.setWatermark(watermarkRenderer.render(state), 0.06f, 0.025f, 0.88f);
            lastSignature = signature;
        }
    }

    private void stopLive() {
        syncClient.stop();
        pusher.stopPush();
        pusher.setWatermark(null, 0f, 0f, 0f);
        status.setText("直播已停止 · 摄像头预览继续");
    }

    @Override
    protected void onDestroy() {
        syncClient.shutdown();
        if (pusher != null) {
            pusher.stopPush();
            pusher.stopMicrophone();
            pusher.stopCamera();
            pusher.release();
        }
        super.onDestroy();
    }
}
