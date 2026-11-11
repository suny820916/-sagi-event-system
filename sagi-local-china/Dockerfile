FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY sagi-local-china/server/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY sagi-local-china/server /app/server
COPY sagi-local-china/web /app/web

RUN mkdir -p /data/uploads
ENV SAGI_DATA_DIR=/data
EXPOSE 8080

CMD ["uvicorn","server.app:app","--host","0.0.0.0","--port","8080","--proxy-headers"]
