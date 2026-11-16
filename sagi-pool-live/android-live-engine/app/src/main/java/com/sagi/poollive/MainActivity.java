package com.sagi.poollive;

import android.Manifest;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
import com.tencent.live2.V2TXLivePusherObserver;
import com.tencent.live2.impl.V2TXLivePusherImpl;
import com.tencent.rtmp.ui.TXCloudVideoView;

import java.util.Map;

public class MainActivity extends AppCompatActivity {
    private TXCloudVideoView preview;
    private V2TXLivePusher pusher;
    private final ScoreSyncClient syncClient = new ScoreSyncClient();
    private final ScoreWatermarkRenderer watermarkRenderer = new ScoreWatermarkRenderer();
    private final Handler overlayHandler = new Handler(Looper.getMainLooper());

    private TextView status, networkStatus, player1, player2, score, zoomLabel;
    private EditText syncUrl, clubId, tableNo, syncToken, rtmpUrl;

    private String lastSignature = "";
    private int lastLogCount = -1;
    private boolean frontCamera = false;
    private boolean torchEnabled = false;
    private float zoomRatio = 1f;
    private boolean pushing = false;
    private ScoreState latestState;

    private final ActivityResultLauncher<String[]> permissionLauncher =
            registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), this::onPermissions);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_main);

        preview = findViewById(R.id.preview);
        status = findViewById(R.id.status);
        networkStatus = findViewById(R.id.networkStatus);
        player1 = findViewById(R.id.player1);
        player2 = findViewById(R.id.player2);
        score = findViewById(R.id.score);
        zoomLabel = findViewById(R.id.zoomLabel);
        syncUrl = findViewById(R.id.syncUrl);
        clubId = findViewById(R.id.clubId);
        tableNo = findViewById(R.id.tableNo);
        syncToken = findViewById(R.id.syncToken);
        rtmpUrl = findViewById(R.id.rtmpUrl);

        ((Button)findViewById(R.id.startButton)).setOnClickListener(v -> startLive());
        ((Button)findViewById(R.id.stopButton)).setOnClickListener(v -> stopLive());
        ((Button)findViewById(R.id.switchCameraButton)).setOnClickListener(v -> switchCamera());
        ((Button)findViewById(R.id.torchButton)).setOnClickListener(v -> toggleTorch());
        ((Button)findViewById(R.id.zoomOutButton)).setOnClickListener(v -> changeZoom(-0.5f));
        ((Button)findViewById(R.id.zoomInButton)).setOnClickListener(v -> changeZoom(0.5f));

        pusher = new V2TXLivePusherImpl(this, V2TXLiveDef.V2TXLiveMode.TXLiveMode_RTMP);
        pusher.setRenderView(preview);
        pusher.setObserver(new SagiPusherObserver());
        requestMediaPermissions();
    }

    private void requestMediaPermissions() {
        boolean camera = checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
        boolean audio = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
        if (camera) {
            startPreview();
            if (audio) pusher.startMicrophone();
        } else {
            permissionLauncher.launch(new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO});
        }
    }

    private void onPermissions(Map<String, Boolean> grants) {
        if (Boolean.TRUE.equals(grants.get(Manifest.permission.CAMERA))) {
            startPreview();
            if (Boolean.TRUE.equals(grants.get(Manifest.permission.RECORD_AUDIO))) {
                pusher.startMicrophone();
            }
        } else {
            status.setText("需要摄像头权限");
        }
    }

    private void startPreview() {
        pusher.startCamera(frontCamera);
        status.setText(frontCamera ? "前置摄像头已开启 · 等待推流" : "后置摄像头已开启 · 等待推流");
        updateZoomLabel();
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
        video.videoResolutionMode =
                V2TXLiveDef.V2TXLiveVideoResolutionMode.V2TXLiveVideoResolutionModeLandscape;
        video.videoBitrate = 1600;
        video.minVideoBitrate = 900;
        video.videoFps = 24;
        pusher.setVideoQuality(video);

        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            pusher.startMicrophone();
        }

        int result = pusher.startPush(push);
        if (result != V2TXLiveCode.V2TXLIVE_OK) {
            status.setText("推流启动失败 · " + result);
            return;
        }

        pushing = true;
        status.setText("LIVE · 正在连接推流目标");
        networkStatus.setText("网络：连接中");

        syncClient.start(api, cid, table, token, new ScoreSyncClient.Listener() {
            @Override
            public void onScore(ScoreState state) {
                updateScore(state);
            }

            @Override
            public void onStatus(String message) {
                if (!message.contains("已连接")) status.setText(message);
            }
        });
    }

    private void updateScore(ScoreState state) {
        latestState = state;
        player1.setText(state.player1);
        player2.setText(state.player2);
        score.setText(state.score1 + " : " + state.score2);

        String signature = state.signature();
        if (!signature.equals(lastSignature)) {
            setNormalWatermark(state);
            lastSignature = signature;
        }

        if (lastLogCount < 0) {
            lastLogCount = state.logCount;
        } else if (state.logCount > lastLogCount && state.hasBroadcastEvent()) {
            lastLogCount = state.logCount;
            playEventOverlay(state);
        } else {
            lastLogCount = Math.max(lastLogCount, state.logCount);
        }
    }

    private void setNormalWatermark(ScoreState state) {
        if (!pushing) return;
        Bitmap bitmap = watermarkRenderer.render(state);
        pusher.setWatermark(bitmap, 0.06f, 0.025f, 0.88f);
    }

    private void playEventOverlay(ScoreState state) {
        if (!pushing) return;
        overlayHandler.removeCallbacksAndMessages(null);

        pusher.setWatermark(watermarkRenderer.renderEvent(state, 0), 0.06f, 0.025f, 0.88f);
        overlayHandler.postDelayed(
                () -> pusher.setWatermark(
                        watermarkRenderer.renderEvent(state, 1), 0.06f, 0.025f, 0.88f),
                90
        );
        overlayHandler.postDelayed(
                () -> pusher.setWatermark(
                        watermarkRenderer.renderEvent(state, 2), 0.06f, 0.025f, 0.88f),
                180
        );
        overlayHandler.postDelayed(() -> {
            if (latestState != null && pushing) setNormalWatermark(latestState);
        }, 1550);
    }

    private void switchCamera() {
        frontCamera = !frontCamera;
        if (torchEnabled) {
            pusher.getDeviceManager().enableCameraTorch(false);
            torchEnabled = false;
        }
        pusher.getDeviceManager().switchCamera(frontCamera);
        zoomRatio = 1f;
        pusher.getDeviceManager().setCameraZoomRatio(zoomRatio);
        updateZoomLabel();
        status.setText(frontCamera ? "已切换前置摄像头" : "已切换后置摄像头");
    }

    private void toggleTorch() {
        if (frontCamera) {
            status.setText("前置摄像头不使用手电筒");
            return;
        }
        boolean target = !torchEnabled;
        boolean ok = pusher.getDeviceManager().enableCameraTorch(target);
        if (ok) {
            torchEnabled = target;
            status.setText(torchEnabled ? "手电筒已开启" : "手电筒已关闭");
        } else {
            status.setText("当前设备不支持手电筒控制");
        }
    }

    private void changeZoom(float delta) {
        float max = pusher.getDeviceManager().getCameraZoomMaxRatio();
        if (max < 1f) max = 1f;
        zoomRatio = Math.max(1f, Math.min(max, zoomRatio + delta));
        int result = pusher.getDeviceManager().setCameraZoomRatio(zoomRatio);
        if (result != 0) status.setText("当前设备不支持该变焦");
        updateZoomLabel();
    }

    private void updateZoomLabel() {
        zoomLabel.setText(String.format(java.util.Locale.US, "%.1fx", zoomRatio));
    }

    private void stopLive() {
        pushing = false;
        overlayHandler.removeCallbacksAndMessages(null);
        syncClient.stop();
        pusher.stopPush();
        pusher.setWatermark(null, 0f, 0f, 0f);
        status.setText("直播已停止 · 摄像头预览继续");
        networkStatus.setText("网络：未推流");
    }

    private final class SagiPusherObserver extends V2TXLivePusherObserver {
        @Override
        public void onWarning(int code, String msg, Bundle extraInfo) {
            runOnUiThread(() -> {
                if (code == V2TXLiveCode.V2TXLIVE_WARNING_NETWORK_BUSY) {
                    networkStatus.setText("网络：弱网 · 建议靠近 Wi-Fi / 检查 5G");
                } else {
                    networkStatus.setText("推流提醒：" + code);
                }
            });
        }

        @Override
        public void onError(int code, String msg, Bundle extraInfo) {
            runOnUiThread(() -> status.setText("推流错误 " + code + " · " + msg));
        }

        @Override
        public void onPushStatusUpdate(
                V2TXLiveDef.V2TXLivePushStatus pushStatus,
                String msg,
                Bundle extraInfo) {
            runOnUiThread(() -> {
                if (pushStatus == V2TXLiveDef.V2TXLivePushStatus.V2TXLivePushStatusConnectSuccess) {
                    status.setText("● LIVE · 推流已连接");
                } else if (pushStatus == V2TXLiveDef.V2TXLivePushStatus.V2TXLivePushStatusReconnecting) {
                    status.setText("推流重连中…");
                } else if (pushStatus == V2TXLiveDef.V2TXLivePushStatus.V2TXLivePushStatusConnecting) {
                    status.setText("正在连接推流服务器…");
                } else if (pushStatus == V2TXLiveDef.V2TXLivePushStatus.V2TXLivePushStatusDisconnected) {
                    status.setText("推流已断开");
                }
            });
        }

        @Override
        public void onStatisticsUpdate(V2TXLiveDef.V2TXLivePusherStatistics statistics) {
            runOnUiThread(() -> networkStatus.setText(
                    "网络：" + statistics.videoBitrate + "kbps · "
                            + statistics.fps + "fps · "
                            + statistics.width + "×" + statistics.height
            ));
        }
    }

    @Override
    protected void onDestroy() {
        pushing = false;
        overlayHandler.removeCallbacksAndMessages(null);
        syncClient.shutdown();
        if (pusher != null) {
            pusher.setObserver(null);
            pusher.stopPush();
            pusher.stopMicrophone();
            pusher.stopCamera();
            pusher.release();
        }
        if (preview != null) preview.onDestroy();
        super.onDestroy();
    }
}
