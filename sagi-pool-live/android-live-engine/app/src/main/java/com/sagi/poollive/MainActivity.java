package com.sagi.poollive;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.text.method.PasswordTransformationMethod;
import android.view.View;
import android.view.WindowManager;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.tencent.live2.V2TXLiveCode;
import com.tencent.live2.V2TXLiveDef;
import com.tencent.live2.V2TXLivePusher;
import com.tencent.live2.V2TXLivePusherObserver;
import com.tencent.live2.impl.V2TXLivePusherImpl;
import com.tencent.rtmp.ui.TXCloudVideoView;

import java.util.Locale;
import java.util.Map;

public class MainActivity extends AppCompatActivity {
    private TXCloudVideoView preview;
    private V2TXLivePusher pusher;
    private final ScoreSyncClient syncClient = new ScoreSyncClient();
    private final ProvisionClient provisionClient = new ProvisionClient();
    private final HealthCheckClient healthCheckClient = new HealthCheckClient();
    private final ScoreWatermarkRenderer watermarkRenderer = new ScoreWatermarkRenderer();
    private final Handler overlayHandler = new Handler(Looper.getMainLooper());

    private TextView status, networkStatus, player1, player2, score, zoomLabel;
    private EditText installCode, syncUrl, clubId, tableNo, syncToken, rtmpUrl;
    private Spinner qualitySpinner;
    private Button audioButton, directorModeButton, configLockButton, claimInstallButton;
    private View controlPanel;
    private SecurePrefs securePrefs;

    private String lastSignature = "";
    private int lastLogCount = -1;
    private boolean frontCamera = false;
    private boolean torchEnabled = false;
    private float zoomRatio = 1f;
    private boolean pushing = false;
    private boolean audioEnabled = true;
    private boolean directorMode = false;
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
        installCode = findViewById(R.id.installCode);
        syncUrl = findViewById(R.id.syncUrl);
        clubId = findViewById(R.id.clubId);
        tableNo = findViewById(R.id.tableNo);
        syncToken = findViewById(R.id.syncToken);
        rtmpUrl = findViewById(R.id.rtmpUrl);
        qualitySpinner = findViewById(R.id.qualitySpinner);
        audioButton = findViewById(R.id.audioButton);
        directorModeButton = findViewById(R.id.directorModeButton);
        configLockButton = findViewById(R.id.configLockButton);
        claimInstallButton = findViewById(R.id.claimInstallButton);
        controlPanel = findViewById(R.id.controlPanel);
        securePrefs = new SecurePrefs(this);

        ArrayAdapter<String> qualityAdapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                new String[]{"540P 流畅", "720P 标准", "1080P 高清"});
        qualityAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        qualitySpinner.setAdapter(qualityAdapter);

        loadConfig();

        claimInstallButton.setOnClickListener(v -> claimInstall());
        ((Button)findViewById(R.id.healthButton)).setOnClickListener(v -> runPreflight(false));
        ((Button)findViewById(R.id.startButton)).setOnClickListener(v -> runPreflight(true));
        ((Button)findViewById(R.id.stopButton)).setOnClickListener(v -> stopLive());
        ((Button)findViewById(R.id.switchCameraButton)).setOnClickListener(v -> switchCamera());
        ((Button)findViewById(R.id.torchButton)).setOnClickListener(v -> toggleTorch());
        ((Button)findViewById(R.id.zoomOutButton)).setOnClickListener(v -> changeZoom(-0.5f));
        ((Button)findViewById(R.id.zoomInButton)).setOnClickListener(v -> changeZoom(0.5f));
        audioButton.setOnClickListener(v -> toggleAudio());
        directorModeButton.setOnClickListener(v -> toggleDirectorMode());
        configLockButton.setOnClickListener(v -> handleConfigLock());

        pusher = new V2TXLivePusherImpl(this, V2TXLiveDef.V2TXLiveMode.TXLiveMode_RTMP);
        pusher.setRenderView(preview);
        pusher.setObserver(new SagiPusherObserver());
        requestMediaPermissions();
    }

    private void loadConfig() {
        String savedSyncUrl = securePrefs.get("sync_url");
        syncUrl.setText(savedSyncUrl.isEmpty() ? BuildConfig.DEFAULT_SYNC_URL : savedSyncUrl);
        String cid = securePrefs.get("club_id");
        clubId.setText(cid.isEmpty() ? "SAGI-DEMO" : cid);
        String table = securePrefs.get("table_no");
        tableNo.setText(table.isEmpty() ? "01桌" : table);
        syncToken.setText(securePrefs.get("sync_token"));
        rtmpUrl.setText(securePrefs.get("rtmp_url"));

        int quality = safeInt(securePrefs.get("quality"), 1);
        qualitySpinner.setSelection(Math.max(0, Math.min(2, quality)));

        String audio = securePrefs.get("audio_enabled");
        audioEnabled = audio.isEmpty() || "1".equals(audio);
        updateAudioButton();
        applyConfigLockUI();
    }

    private void saveConfig() {
        securePrefs.put("sync_url", syncUrl.getText().toString().trim());
        securePrefs.put("club_id", clubId.getText().toString().trim());
        securePrefs.put("table_no", tableNo.getText().toString().trim());
        securePrefs.put("sync_token", syncToken.getText().toString());
        securePrefs.put("rtmp_url", rtmpUrl.getText().toString().trim());
        securePrefs.put("quality", String.valueOf(qualitySpinner.getSelectedItemPosition()));
        securePrefs.put("audio_enabled", audioEnabled ? "1" : "0");
    }

    private boolean isConfigLocked() {
        return "1".equals(securePrefs.get("config_locked"));
    }

    private void handleConfigLock() {
        final boolean locked = isConfigLocked();
        final EditText pin = new EditText(this);
        pin.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        pin.setTransformationMethod(PasswordTransformationMethod.getInstance());
        pin.setHint(locked ? "输入管理 PIN" : "设置 4–8 位管理 PIN");

        new AlertDialog.Builder(this)
                .setTitle(locked ? "解锁直播配置" : "锁定直播配置")
                .setMessage(locked
                        ? "解锁后可修改同步密钥和 RTMP 地址。"
                        : "锁定后普通员工仍可开播、切镜头和操作比分，但不能修改敏感配置。")
                .setView(pin)
                .setNegativeButton("取消", null)
                .setPositiveButton(locked ? "解锁" : "锁定", (dialog, which) -> {
                    String value = pin.getText().toString().trim();
                    if (value.length() < 4 || value.length() > 8) {
                        status.setText("管理 PIN 必须为 4–8 位");
                        return;
                    }

                    if (locked) {
                        String saved = securePrefs.get("config_pin");
                        if (!value.equals(saved)) {
                            status.setText("管理 PIN 不正确");
                            return;
                        }
                        securePrefs.put("config_locked", "0");
                        status.setText("配置已解锁");
                    } else {
                        securePrefs.put("config_pin", value);
                        securePrefs.put("config_locked", "1");
                        status.setText("配置已锁定");
                    }
                    applyConfigLockUI();
                })
                .show();
    }

    private void applyConfigLockUI() {
        boolean locked = isConfigLocked();
        syncUrl.setEnabled(!locked);
        clubId.setEnabled(!locked);
        tableNo.setEnabled(!locked);
        syncToken.setEnabled(!locked);
        rtmpUrl.setEnabled(!locked);
        installCode.setEnabled(!locked);
        claimInstallButton.setEnabled(!locked);

        if (locked) {
            rtmpUrl.setTransformationMethod(PasswordTransformationMethod.getInstance());
        } else {
            rtmpUrl.setTransformationMethod(null);
        }
        configLockButton.setText(locked ? "解锁配置" : "锁配置");
    }

    private int safeInt(String value, int fallback) {
        try {
            return Integer.parseInt(value);
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private void claimInstall() {
        String base = syncUrl.getText().toString().trim();
        String code = installCode.getText().toString().trim().toUpperCase(Locale.ROOT);

        if (base.isEmpty()) {
            status.setText("请填写国内同步服务器，正式版可预置");
            return;
        }
        if (code.length() < 6) {
            status.setText("请输入有效安装码");
            return;
        }

        status.setText("正在领取球房配置…");
        provisionClient.claim(base, code, new ProvisionClient.Callback() {
            @Override
            public void onSuccess(ProvisionClient.Config config) {
                clubId.setText(config.clubId);
                tableNo.setText(config.table);
                syncToken.setText(config.token);
                installCode.setText("");
                saveConfig();
                status.setText("安装完成 · " + config.clubName + " · " + config.table);
            }

            @Override
            public void onError(String message) {
                status.setText(message);
            }
        });
    }

    private void runPreflight(boolean startAfter) {
        saveConfig();

        String api = syncUrl.getText().toString().trim();
        String cid = clubId.getText().toString().trim();
        String table = tableNo.getText().toString().trim();
        String token = syncToken.getText().toString();
        String push = rtmpUrl.getText().toString().trim();

        if (api.isEmpty()) {
            status.setText("检测失败 · 未配置国内同步服务器");
            return;
        }
        if (cid.isEmpty() || table.isEmpty() || token.isEmpty()) {
            status.setText("检测失败 · 球房安装配置不完整");
            return;
        }
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            status.setText("检测失败 · 缺少摄像头权限");
            return;
        }
        if (audioEnabled
                && checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            status.setText("检测失败 · 麦克风已开启但缺少权限");
            return;
        }
        if (startAfter && !push.startsWith("rtmp://") && !push.startsWith("rtmps://")) {
            status.setText("检测失败 · RTMP / RTMPS 推流地址无效");
            return;
        }

        status.setText("正在检测国内服务器与球房授权…");
        networkStatus.setText("自检：连接中");

        healthCheckClient.check(api, cid, table, token, new HealthCheckClient.Callback() {
            @Override
            public void onSuccess(String serverVersion) {
                boolean sdkLicenceReady =
                        !BuildConfig.LIVE_LICENSE_URL.isEmpty() && !BuildConfig.LIVE_LICENSE_KEY.isEmpty();

                if (!sdkLicenceReady) {
                    status.setText("同步正常 · 当前APK未注入直播SDK License");
                    networkStatus.setText("自检：服务器 " + serverVersion + " · SDK授权缺失");
                    return;
                }

                networkStatus.setText("自检：全部通过 · 服务器 " + serverVersion);
                status.setText(startAfter ? "自检通过 · 正在启动直播" : "✓ 开播条件全部通过");
                if (startAfter) startLive();
            }

            @Override
            public void onError(String message) {
                status.setText("检测失败 · " + message);
                networkStatus.setText("自检：未通过");
            }
        });
    }

    private void requestMediaPermissions() {
        boolean camera = checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
        boolean audio = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;

        if (camera) {
            startPreview();
            if (audio && audioEnabled) pusher.startMicrophone();
        } else {
            permissionLauncher.launch(new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO});
        }
    }

    private void onPermissions(Map<String, Boolean> grants) {
        if (Boolean.TRUE.equals(grants.get(Manifest.permission.CAMERA))) {
            startPreview();
            if (Boolean.TRUE.equals(grants.get(Manifest.permission.RECORD_AUDIO)) && audioEnabled) {
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
        saveConfig();

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

        applyVideoQuality();

        if (audioEnabled
                && checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            pusher.startMicrophone();
        } else {
            pusher.stopMicrophone();
        }

        startKeepAliveService();
        int result = pusher.startPush(push);
        if (result != V2TXLiveCode.V2TXLIVE_OK) {
            stopKeepAliveService();
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

    private void applyVideoQuality() {
        int selected = qualitySpinner.getSelectedItemPosition();
        V2TXLiveDef.V2TXLiveVideoResolution resolution;
        int target;
        int min;

        if (selected == 0) {
            resolution = V2TXLiveDef.V2TXLiveVideoResolution.V2TXLiveVideoResolution960x540;
            target = 1200;
            min = 700;
        } else if (selected == 2) {
            resolution = V2TXLiveDef.V2TXLiveVideoResolution.V2TXLiveVideoResolution1920x1080;
            target = 2800;
            min = 1800;
        } else {
            resolution = V2TXLiveDef.V2TXLiveVideoResolution.V2TXLiveVideoResolution1280x720;
            target = 1600;
            min = 900;
        }

        V2TXLiveDef.V2TXLiveVideoEncoderParam video =
                new V2TXLiveDef.V2TXLiveVideoEncoderParam(resolution);
        video.videoResolutionMode =
                V2TXLiveDef.V2TXLiveVideoResolutionMode.V2TXLiveVideoResolutionModeLandscape;
        video.videoBitrate = target;
        video.minVideoBitrate = min;
        video.videoFps = 24;
        pusher.setVideoQuality(video);
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
                90);
        overlayHandler.postDelayed(
                () -> pusher.setWatermark(
                        watermarkRenderer.renderEvent(state, 2), 0.06f, 0.025f, 0.88f),
                180);
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
        zoomLabel.setText(String.format(Locale.US, "%.1fx", zoomRatio));
    }

    private void toggleAudio() {
        audioEnabled = !audioEnabled;
        if (audioEnabled) {
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                pusher.startMicrophone();
            } else {
                permissionLauncher.launch(
                        new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO});
            }
        } else {
            pusher.stopMicrophone();
        }
        updateAudioButton();
        saveConfig();
    }

    private void updateAudioButton() {
        audioButton.setText(audioEnabled ? "麦克风 开" : "麦克风 关");
    }

    private void toggleDirectorMode() {
        directorMode = !directorMode;
        controlPanel.setVisibility(directorMode ? View.GONE : View.VISIBLE);
        directorModeButton.setText(directorMode ? "显示控制" : "隐藏控制");
    }

    private void startKeepAliveService() {
        Intent intent = new Intent(this, LiveKeepAliveService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
    }

    private void stopKeepAliveService() {
        stopService(new Intent(this, LiveKeepAliveService.class));
    }

    private void stopLive() {
        pushing = false;
        stopKeepAliveService();
        overlayHandler.removeCallbacksAndMessages(null);
        syncClient.stop();
        pusher.stopPush();
        pusher.setWatermark(null, 0f, 0f, 0f);
        status.setText("直播已停止 · 摄像头预览继续");
        networkStatus.setText("网络：未推流");
        saveConfig();
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
                            + statistics.width + "×" + statistics.height));
        }
    }

    @Override
    protected void onDestroy() {
        saveConfig();
        pushing = false;
        stopKeepAliveService();
        overlayHandler.removeCallbacksAndMessages(null);
        syncClient.shutdown();
        provisionClient.shutdown();
        healthCheckClient.shutdown();
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
