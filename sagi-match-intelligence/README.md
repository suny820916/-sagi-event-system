# SAGI MATCH INTELLIGENCE V1.0 ALPHA

AI football match analysis engine for grassroots and amateur football.

## V1.0 scope

- Upload a full match video
- Detect players and the football with Ultralytics YOLO
- Track identities with ByteTrack
- Automatically separate the two largest jersey-colour groups
- Estimate ball possession from the nearest tracked player
- Build per-team and per-track movement heatmaps
- Export an annotated analysis preview
- Expose all results through a FastAPI API
- Mobile-first browser dashboard

> V1.0 deliberately does not claim perfect player identity, pass, tackle, xG or offside recognition. Those require stronger calibration and/or dedicated models.

## Architecture

\`\`\`
Mobile/Web UI
    |
    v
FastAPI API
    |
    +-- Job Store (JSON, V1)
    |
    +-- Analysis Worker
            |
            +-- YOLO person + sports-ball detection
            +-- ByteTrack tracking
            +-- Jersey HSV sampling
            +-- Team clustering
            +-- Ball-possession estimation
            +-- Heatmap generation
            +-- Annotated preview + result.json
\`\`\`

## Run with Docker

\`\`\`bash
cd sagi-match-intelligence
docker build -t sagi-match-intelligence .
docker run --rm -p 8000:8000 -v "$PWD/data:/app/data" sagi-match-intelligence
\`\`\`

Open http://localhost:8000

## Run locally

Python 3.11 recommended.

\`\`\`bash
cd sagi-match-intelligence
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend.app.main:app --reload --port 8000
\`\`\`

The first analysis downloads the configured YOLO model if it is not already cached.

## API

- \`GET /health\`
- \`POST /api/v1/jobs\` multipart: \`video\`, \`home_team\`, \`away_team\`, \`match_format\`
- \`GET /api/v1/jobs/{job_id}\`
- \`GET /api/v1/jobs/{job_id}/result\`
- \`GET /api/v1/jobs/{job_id}/artifacts/{filename}\`

## Environment

Copy \`.env.example\` to \`.env\`.

Important values:

- \`SAGI_MODEL=yolo11n.pt\`
- \`SAGI_DEVICE=cpu\` or \`0\` for first CUDA GPU
- \`SAGI_ANALYSIS_FPS=3\`
- \`SAGI_MAX_UPLOAD_MB=4096\`

For real full-match analysis, deploy the worker on a GPU machine. The API/UI can run separately later.

## V1.1 planned

- Manual pitch calibration + homography
- True 2D tactical pitch map
- Player-number confirmation workflow
- Better goalkeeper/referee handling
- Player ID integration
- Exportable SAGI Match Report PDF
