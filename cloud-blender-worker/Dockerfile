FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG BLENDER_VERSION=5.2.4

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils ffmpeg \
    libgl1 libegl1 libx11-6 libxext6 libxi6 libxrender1 libxfixes3 \
    libxkbcommon0 libsm6 libice6 libxxf86vm1 libfontconfig1 libfreetype6 \
    libdbus-1-3 libwayland-client0 libwayland-egl1 libwayland-cursor0 \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://download.blender.org/release/Blender5.2/blender-${BLENDER_VERSION}-linux-x64.tar.xz" -o /tmp/blender.tar.xz \
    && mkdir -p /opt/blender \
    && tar -xJf /tmp/blender.tar.xz --strip-components=1 -C /opt/blender \
    && ln -s /opt/blender/blender /usr/local/bin/blender \
    && rm -f /tmp/blender.tar.xz

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN python3 -m pip install --break-system-packages --no-cache-dir -r /app/requirements.txt

COPY app /app/app
COPY engine /app/engine
COPY presets /app/presets

ENV PYTHONUNBUFFERED=1 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    SAGI_JOBS_DIR=/tmp/sagi_jobs \
    SAGI_MAX_WORKERS=1 \
    SAGI_RENDER_TIMEOUT_SEC=1800

EXPOSE 10000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}"]
