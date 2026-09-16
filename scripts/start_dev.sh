#!/usr/bin/env bash
# ==============================================================================
# HoneyChain — Native (non-Docker) development launcher
#
#   ./scripts/start_dev.sh            # broker + backend + AI processor
#   ./scripts/start_dev.sh --chain    # also start a local Hardhat node
#   ./scripts/start_dev.sh --clean    # also reset the SQLite dev database
#
# Requirements: python3, pip, mosquitto (or docker for just the broker),
#               node >= 18 (only with --chain)
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHAIN=0; CLEAN=0
for arg in "$@"; do
  case "$arg" in
    --chain) CHAIN=1 ;;
    --clean) CLEAN=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

PIDS=()
cleanup() {
  echo ""
  echo "[start_dev] Shutting down..."
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  echo "[start_dev] Bye."
}
trap cleanup EXIT INT TERM

# ── 0. Python deps ──────────────────────────────────────────────────────────
echo "[start_dev] Installing backend dependencies..."
pip install -q -r backend/requirements.txt
echo "[start_dev] Installing AI/ML dependencies..."
pip install -q -r ai_ml/requirements.txt

# ── 1. MQTT broker ──────────────────────────────────────────────────────────
if command -v mosquitto >/dev/null 2>&1; then
  echo "[start_dev] Starting native mosquitto on :1883 (anonymous, dev-only)..."
  mosquitto -p 1883 &
  PIDS+=($!)
elif docker info >/dev/null 2>&1; then
  echo "[start_dev] Starting mosquitto via Docker on :1883..."
  docker run -d --rm --name honeychain-mosquitto-dev -p 1883:1883 eclipse-mosquitto:2 \
    && PIDS+=("docker")
else
  echo "[start_dev] WARNING: no mosquitto binary and no docker; telemetry pipeline disabled."
fi

# ── 2. Local blockchain node (optional) ─────────────────────────────────────
if [ "$CHAIN" -eq 1 ]; then
  echo "[start_dev] Starting Hardhat node on :8545..."
  (cd blockchain && npm install --no-audit --no-fund)
  (cd blockchain && npx hardhat node --hostname 127.0.0.1) &
  PIDS+=($!)
fi

# ── 3. FastAPI backend ──────────────────────────────────────────────────────
if [ "$CLEAN" -eq 1 ]; then
  echo "[start_dev] Removing stale dev database..."
  rm -f backend/honeychain.db
fi

echo "[start_dev] Starting FastAPI backend on :8000..."
(
  cd backend
  # Native offline dev: allow SQLite so Postgres isn't required for a quick demo
  export DEV_OFFLINE_SQLITE="${DEV_OFFLINE_SQLITE:-true}"
  export MQTT_HOST="${MQTT_HOST:-localhost}"
  export JWT_SECRET_KEY="${JWT_SECRET_KEY:-honeychain-dev-secret-$(date +%s)}"
  exec python main.py
) &
PIDS+=($!)

# ── 4. AI/ML processor ──────────────────────────────────────────────────────
echo "[start_dev] Starting AI/ML MQTT processor..."
(
  cd "$ROOT"
  export MQTT_BROKER="${MQTT_BROKER:-localhost}"
  export PYTHONPATH="$ROOT"
  exec python ai_ml/mqtt/mqtt_processor.py
) &
PIDS+=($!)

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " HoneyChain dev stack is up:"
echo "   • API + docs   → http://localhost:8000/api/health"
echo "   • Swagger UI   → http://localhost:8000/docs"
echo "   • MQTT broker  → localhost:1883"
echo "   • Flutter app  → flutter run (Android emulator: http://10.0.2.2:8000)"
echo "════════════════════════════════════════════════════════════════"
echo ""
wait
