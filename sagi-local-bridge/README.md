# SAGI REMOTE WORKER

用于解决 Render 云出口被 Instagram 429 限流的问题。

## 原理

手机仍然使用 SAGI CLOUD 创建任务，但 Instagram 下载不再由 Render 执行。
电脑上的 Remote Worker 会从 SAGI CLOUD 领取任务，用你自己的网络出口下载，再把 MP4 上传回 SAGI CLOUD，手机随后直接下载。

## 第一次使用

1. 双击 `START_SAGI_REMOTE_WORKER.bat`
2. CONTENT OS → DOWN → SAGI CLOUD → 生成 6 位配对码
3. 在电脑窗口输入配对码
4. 成功后 `worker-config.json` 会保存身份，以后不再输入

## 日常使用

只要电脑上的 Worker 窗口保持开启：

手机 5G → CONTENT OS → 粘贴 Instagram → 下载 INS 视频

## 可选 cookies.txt

如果 Instagram 在你的本地网络也要求登录，可在本目录放置 Netscape 格式 `cookies.txt`。Remote Worker 会自动读取。

只用于你拥有或已获授权保存/使用的内容。
