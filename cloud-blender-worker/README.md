# SAGI TACTICS · CLOUD BLENDER WORKER V1.0

Tactical JSON -> Blender Headless -> .blend + MP4 -> iPhone-safe H.264

## Included

- Blender 5.2.4 LTS in Docker
- FastAPI render service
- one-job-at-a-time render queue
- /health
- /benchmark
- /jobs
- /jobs/{id}
- /jobs/{id}/video
- /jobs/{id}/blend
- /jobs/{id}/log
- X-API-Key protection when SAGI_API_KEY is set
- Render Blueprint

## Render deployment

Blueprint path:

cloud-blender-worker/render.yaml

The service binds Uvicorn to Render's PORT.

Recommended first compute: Starter or above. Blender rendering is CPU/RAM intensive.

## Benchmark

12 sec, 540x960, 24fps:

- SHAPE view
- focus RCB
- GK -> RCB
- defender reacts after release
- focus 6
- RCB -> 6
- space appears after defensive movement
- RESULT view

## API test

Health:

curl https://YOUR-SERVICE.onrender.com/health

Start benchmark:

curl -X POST https://YOUR-SERVICE.onrender.com/benchmark -H "X-API-Key: YOUR_KEY"

Poll:

curl https://YOUR-SERVICE.onrender.com/jobs/JOB_ID -H "X-API-Key: YOUR_KEY"

Download:

curl -L https://YOUR-SERVICE.onrender.com/jobs/JOB_ID/video -H "X-API-Key: YOUR_KEY" -o sagi.mp4

## Next

- Teactics-style player mesh lock
- SHAPE / ROLE / RELATION / WEAKNESS / RESULT camera grammar
- improved ring/zone shader
- text overlays
- durable queue + background worker
- object storage for final renders
