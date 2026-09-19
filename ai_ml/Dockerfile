FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ \
    && rm -rf /var/lib/apt/lists/*

# docker-compose builds this image with the repository root as context.
COPY ai_ml/requirements.txt /tmp/ai_ml-requirements.txt
RUN pip install --no-cache-dir -r /tmp/ai_ml-requirements.txt

COPY . .

CMD ["python", "-u", "-m", "ai_ml.mqtt.mqtt_processor"]
