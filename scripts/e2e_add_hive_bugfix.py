"""
E2E verification for the Harvester -> Add Hive bug fix.

Exercises the REAL HoneyChain stack (no mocks):
  1. POST /api/auth/register      -> real JWT from the backend
  2. POST /api/hives              -> real insert (exact payload the Flutter app sends)
  3. GET  /api/hives              -> what the Flutter hive list actually renders
  4. Direct PostgreSQL row check  -> proves persistence in the configured DB
  5. CORS preflight + credentialed request from the Flutter web dev origin
  6. POST /api/requests           -> Collection & Processing request created

Run:  backend/.venv/Scripts/python.exe scripts/e2e_add_hive_bugfix.py
"""
import json
import sys
import urllib.request
import urllib.error
import uuid

BASE = "http://localhost:8000"
# The exact origin `flutter run -d chrome` served the app from during the bug
# report (random port). Proves the CORS fix lets the real Flutter web client in.
FLUTTER_WEB_ORIGIN = "http://localhost:57639"

results = []


def check(step, ok, detail=""):
    results.append((step, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {step}" + (f" -> {detail}" if detail else ""))
    return ok


def _maybe_json(raw):
    """Parse JSON when possible; preflight/HTML responses are plain text."""
    try:
        return json.loads(raw) if raw else {}
    except Exception:
        return {"raw": raw}


def request(method, path, body=None, token=None, origin=None, preflight=False):
    req = urllib.request.Request(BASE + path, method=method)
    if preflight:
        req.add_header("Origin", origin or FLUTTER_WEB_ORIGIN)
        req.add_header("Access-Control-Request-Method", "POST")
        req.add_header("Access-Control-Request-Headers", "content-type,authorization")
    else:
        if body is not None:
            req.add_header("Content-Type", "application/json")
        if origin:
            req.add_header("Origin", origin)
        if token:
            req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if (body is not None and not preflight) else None
    try:
        with urllib.request.urlopen(req, data=data, timeout=30) as r:
            raw = r.read().decode()
            return r.status, dict(r.headers), _maybe_json(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        return e.code, dict(e.headers), _maybe_json(raw)


# ── 0. Health (backend reachable, real PostgreSQL) ─────────────────────────
status, _, health = request("GET", "/api/health")
check("Backend reachable at http://localhost:8000/api/health", status == 200, f"HTTP {status}")
db_engine = (health.get("database") or {}).get("engine", "?")
check("Database engine is PostgreSQL (real DB, not mock/SQLite)", db_engine == "postgresql", f"engine={db_engine}")

# ── 1. CORS preflight from the actual Flutter web dev origin ───────────────
status, headers, _ = request("OPTIONS", "/api/hives", preflight=True)
allowed = headers.get("access-control-allow-origin")
check(
    f"CORS preflight from Flutter web origin {FLUTTER_WEB_ORIGIN}",
    status == 200 and allowed == FLUTTER_WEB_ORIGIN,
    f"HTTP {status}, allow-origin={allowed}",
)

# ── 2. Register a real harvester (auth path) ────────────────────────────────
email = f"e2e-hive-{uuid.uuid4().hex[:8]}@honeychain.io"
password = "E2ePass!2026"
status, _, reg = request("POST", "/api/auth/register", {
    "name": "E2E Bugfix Harvester", "email": email, "password": password, "role": "HARVESTER",
})
token = reg.get("token") or ""
check("Register harvester -> real JWT issued", status == 200 and bool(token), f"HTTP {status}")

# ── 3. POST /api/hives with the EXACT payload Flutter sends ────────────────
now_iso = "2026-09-21T09:00:00.000"
hive_code = f"HIVE-{uuid.uuid4().hex[:6].upper()}"
flutter_payload = {  # shape mirrors mobile_app Hive.toJson()
    "id": "", "userId": reg["user"]["id"], "name": "E2E Verification Hive",
    "hiveCode": hive_code, "apiaryLocation": "Test Apiary Block C", "hiveType": "Langstroth",
    "dateAdded": now_iso, "queenStatus": "Mated", "totalFrames": 10, "broodFrames": 4,
    "colonyStrength": "Strong", "queenAgeMonths": 2, "beeBreed": "Italian",
    "expectedProductionKg": 25.0, "previousYearProductionKg": 18.5, "currentYearProductionKg": 6.25,
    "honeyType": "Wildflower", "lastInspectionDate": now_iso, "miteStatus": "None",
    "diseaseStatus": "None", "feedingRequired": False, "queenCondition": "Good",
    "overallHealth": "Healthy", "notes": "Created by E2E bugfix verification",
    "updatedAt": now_iso,
}
status, _, created = request("POST", "/api/hives", flutter_payload, token=token)
hive = created.get("hive") or {}
new_hive_id = hive.get("id")
check("POST /api/hives (Flutter payload) -> 200 hive registered", status == 200 and bool(new_hive_id),
      f"HTTP {status}, id={new_hive_id}, code={hive.get('hiveCode')}")

# ── 4. GET /api/hives renders the new hive (what the UI list shows) ────────
status, _, hive_list = request("GET", "/api/hives", token=token)
found = any(h.get("id") == new_hive_id for h in hive_list if isinstance(h, dict))
check("GET /api/hives returns the new hive card data", status == 200 and found,
      f"HTTP {status}, list size={len(hive_list) if isinstance(hive_list, list) else '?'}")

# ── 5. Direct PostgreSQL row check (persistence in the REAL database) ──────
pg_ok = False
pg_detail = "skipped (psycopg2 not available)"
try:
    import psycopg2
    from dotenv import dotenv_values
    env = dotenv_values("backend/.env")
    db_url = env.get("DATABASE_URL", "")
    conn = psycopg2.connect(db_url, connect_timeout=15)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT name, hive_code, apiary_location, overall_health FROM hives WHERE id = %s",
            (new_hive_id,),
        )
        row = cur.fetchone()
    conn.close()
    pg_ok = row is not None and row[1] == hive_code
    pg_detail = f"row={row}" if row else f"no row for id {new_hive_id}"
except ImportError:
    pass
except Exception as e:
    pg_detail = f"error: {type(e).__name__}: {e}"
check("PostgreSQL hives table contains the inserted row", pg_ok, pg_detail)

# ── 6. Collection & Processing request created from the new hive ───────────
status, _, req_created = request("POST", "/api/requests", {
    "hiveId": new_hive_id, "quantity": 6.25, "location": "Test Apiary Block C",
    "requestType": "HARVEST_TO_COLLECTION",
}, token=token)
req_code = req_created.get("requestId") or (req_created.get("request") or {}).get("requestId")
check("POST /api/requests -> Collection & Processing request created",
      status == 200 and bool(req_code), f"HTTP {status}, request={req_code}")

# ── 7. Duplicate hive code rejected with REAL 409 (not masked as offline) ──
status, _, dup = request("POST", "/api/hives", flutter_payload, token=token)
msg = (dup.get("detail") or {}).get("message", "")
check("Duplicate hive code -> real 409 with backend message (no false connection error)",
      status == 409, f"HTTP {status}, message='{msg}'")

print()
failed = [r for r in results if not r[1]]
print(f"===== {len(results) - len(failed)}/{len(results)} checks passed =====")
sys.exit(1 if failed else 0)
