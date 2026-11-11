FROM python:3.12-slim AS match-source-smoke

WORKDIR /app
COPY app.py match_intelligence_lite.py ./
RUN test -f /app/app.py && test -f /app/match_intelligence_lite.py


FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py match_intelligence_lite.py ./
ENV PYTHONUNBUFFERED=1 \
    MALLOC_ARENA_MAX=2 \
    OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    SAGI_FFMPEG_THREADS=1
CMD ["sh","-c","gunicorn -w 1 -k gthread --threads 2 -b 0.0.0.0:$PORT --timeout 300 app:app"]
