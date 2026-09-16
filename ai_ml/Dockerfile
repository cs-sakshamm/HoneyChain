FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy AI/ML source (ai_ml/ is the build context)
COPY . .

# Run the MQTT inference processor (subscribes hive/telemetry → publishes hive/processed)
CMD ["python", "-u", "ai_ml/mqtt/mqtt_processor.py"]
