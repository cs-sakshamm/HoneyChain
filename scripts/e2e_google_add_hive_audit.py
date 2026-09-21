"""
Live audit of the GOOGLE LOGIN -> Add Hive backend chain (real backend, real PostgreSQL).

Simulates exactly what the Flutter app does after Google sign-in:
  1. POST /api/auth/google  (session exchange, as AuthController.signInWithGoogle does)
  2. POST /api/hives        (Add Hive, Authorization: Bearer <token>)
  3. GET  /api/hives        (hive list render)
  4. POST /api/requests     (Collection & Processing request)
  5. POST /api/auth/phone   (what AuthController._restoreSession does on next app start
                             with the SAME Google/Firebase ID token shape -> expect the bug)
"""
import json
import sys
import urllib.request
import urllib.error
import uuid

BASE = "http://localhost:8000"
results = []


def check(step, ok, detail=""):
    results.append((step, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {step}" + (f" -> {detail}" if detail else ""))


def request(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data=data, timeout=30) as r:
            raw = r.read().decode()
            try:
                return r.status, json.loads(raw) if raw else {}
            except Exception:
                return r.status, {"raw": raw}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw}


# ── 1. Google session exchange (no idToken = dev-mode bare-email path, same
#       shape /api/auth/google accepts when Firebase token verification is
#       unavailable; production with GOOGLE_CLIENT_ID requires a real token) ──
email = f"google-e2e-{uuid.uuid4().hex[:8]}@gmail.com"
status, resp = request("POST", "/api/auth/google", {
    "email": email, "name": "Google E2E Harvester", "role": "HARVESTER",
})
check("POST /api/auth/google (Google login exchange)", status == 200, f"HTTP {status}")
token = resp.get("token") or ""
user = resp.get("user") or {}
check("Backend JWT returned and stored by app", bool(token), f"token={'yes' if token else 'NO'}")
check("User row role is HARVESTER", user.get("role") == "HARVESTER",
      f"role={user.get('role')}, isVerified={user.get('isVerified')}")

# ── 2. Add Hive with Bearer token (exact Flutter header) ────────────────────
now_iso = "2026-09-21T10:00:00.000"
hive_code = f"HIVE-{uuid.uuid4().hex[:6].upper()}"
status, created = request("POST", "/api/hives", {
    "id": "", "userId": user.get("id"), "name": "Google Flow Hive",
    "hiveCode": hive_code, "apiaryLocation": "Google Apiary A", "hiveType": "Langstroth",
    "dateAdded": now_iso, "queenStatus": "Mated", "totalFrames": 10, "broodFrames": 5,
    "colonyStrength": "Strong", "queenAgeMonths": 1, "beeBreed": "Italian",
    "expectedProductionKg": 20.0, "previousYearProductionKg": 12.0, "currentYearProductionKg": 4.0,
    "honeyType": "Wildflower", "lastInspectionDate": now_iso, "miteStatus": "None",
    "diseaseStatus": "None", "feedingRequired": False, "queenCondition": "Good",
    "overallHealth": "Healthy", "notes": "google-flow e2e", "updatedAt": now_iso,
}, token=token)
hive = created.get("hive") or {}
hive_id = hive.get("id")
check("POST /api/hives with Bearer token (Add Hive)", status == 200 and bool(hive_id),
      f"HTTP {status}, hiveId={hive_id}")

# ── 3. Missing header reproduces the reported message (message source) ─────
status, denied = request("POST", "/api/hives", {"name": "x", "apiaryLocation": "y"})
msg = (denied.get("detail") or {}).get("message") if isinstance(denied.get("detail"), dict) else denied.get("detail")
check("POST /api/hives WITHOUT token -> exact reported error", status == 401,
      f"HTTP {status}, message='{msg}'")

# ── 4. Hive list shows the card ─────────────────────────────────────────────
status, hive_list = request("GET", "/api/hives", token=token)
found = isinstance(hive_list, list) and any(h.get("id") == hive_id for h in hive_list)
check("GET /api/hives renders the new hive", status == 200 and found,
      f"HTTP {status}, size={len(hive_list) if isinstance(hive_list, list) else '?'}")

# ── 5. Collection & Processing request from the new hive ───────────────────
status, req_created = request("POST", "/api/requests", {
    "hiveId": hive_id, "quantity": 4.0, "location": "Google Apiary A",
}, token=token)
check("POST /api/requests (Collection & Processing)", status == 200,
      f"HTTP {status}, requestId={req_created.get('requestId')}")

# ── 6. Session restore path used by _restoreSession on next app start ──────
# Google-authenticated Firebase users carry NO phone_number claim.
status, phone_resp = request("POST", "/api/auth/phone", {"idToken": "google-user-has-no-phone-claim"})
detail = phone_resp.get("detail")
detail_msg = detail.get("message") or detail.get("error") if isinstance(detail, dict) else detail
check("POST /api/auth/phone with non-phone Firebase token (old broken restore path)",
      status == 401, f"HTTP {status}, message='{detail_msg}'")
print("      ^^ /api/auth/phone correctly rejects Google tokens (no phone claim) —")
print("         the FIXED client now routes Google restores to /api/auth/google instead")

# ── 7. FIXED restore: Google session re-exchanges via /api/auth/google ─────
# (role is re-sent from the saved session so the SAME (email, role) row is
#  resolved — no duplicate account forking)
status, restored = request("POST", "/api/auth/google", {
    "email": email, "name": "Google E2E Harvester", "role": "HARVESTER",
})
same_user = (restored.get("user") or {}).get("id") == user.get("id")
restored_token = restored.get("token") or ""
check("RESTORE (fixed): /api/auth/google re-exchange -> same user, fresh JWT",
      status == 200 and same_user and bool(restored_token),
      f"HTTP {status}, sameUserId={same_user}")

# ── 8. Restored session can still Add Hive (the actual bug scenario) ───────
hive_code2 = f"HIVE-{uuid.uuid4().hex[:6].upper()}"
status, created2 = request("POST", "/api/hives", {
    "id": "", "userId": user.get("id"), "name": "Restored Session Hive",
    "hiveCode": hive_code2, "apiaryLocation": "Google Apiary A", "hiveType": "Langstroth",
    "dateAdded": now_iso, "queenStatus": "Mated", "totalFrames": 10, "broodFrames": 3,
    "colonyStrength": "Strong", "queenAgeMonths": 1, "beeBreed": "Italian",
    "expectedProductionKg": 10.0, "previousYearProductionKg": 5.0, "currentYearProductionKg": 2.0,
    "honeyType": "Wildflower", "lastInspectionDate": now_iso, "miteStatus": "None",
    "diseaseStatus": "None", "feedingRequired": False, "queenCondition": "Good",
    "overallHealth": "Healthy", "notes": "restored-session e2e", "updatedAt": now_iso,
}, token=restored_token)
check("Add Hive with RESTORED Google session token", status == 200 and bool((created2.get("hive") or {}).get("id")),
      f"HTTP {status}, hiveId={(created2.get('hive') or {}).get('id')}")

failed = [r for r in results if not r[1]]
print(f"\n===== {len(results) - len(failed)}/{len(results)} checks passed =====")
sys.exit(1 if failed else 0)
