"""Quick end-to-end workflow check for HoneyChain.

Run with the backend live:
    python scripts/e2e_workflow_check.py [BASE_URL]

Mirrors the exact request sequence used by the Flutter app:
google login -> add hive -> create collection request -> accept -> send-next(lab)
-> accept(lab) -> lab report -> send-next(packaging) -> accept(pkg) -> packaging
-> public verification (no auth).
"""
from __future__ import annotations

import json
import sys
import uuid

import requests

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"
FAILURES: list[str] = []


def check(name: str, cond: bool, extra: str = "") -> bool:
    status = "PASS" if cond else "FAIL"
    print(f"[{status}] {name}" + (f" -> {extra}" if extra and not cond else ""))
    if not cond:
        FAILURES.append(name)
    return cond


def main() -> int:
    s = requests.Session()
    suffix = uuid.uuid4().hex[:6]

    # 0. health
    r = s.get(f"{BASE}/api/health", timeout=10)
    check("health", r.ok, r.text[:200])

    # 1. Google login (dev bare-email mode; production requires idToken)
    email = f"harvester_{suffix}@e2e.test"
    r = s.post(
        f"{BASE}/api/auth/google",
        json={"email": email, "name": "E2E Harvester", "role": "HARVESTER", "photoUrl": "http://x/y.png"},
        timeout=10,
    )
    check("google login", r.ok, r.text[:300])
    token = r.json().get("token")
    user_id = (r.json().get("user") or {}).get("id")
    H = {"Authorization": f"Bearer {token}"}

    # 2. Profile readable
    r = s.get(f"{BASE}/api/profile", headers=H, timeout=10)
    check("get profile", r.ok and r.json().get("user", {}).get("id") == user_id, r.text[:200])

    # 3. Add hive
    r = s.post(
        f"{BASE}/api/hives",
        headers=H,
        json={"name": "E2E Hive", "apiaryLocation": "Test Valley", "hiveType": "Langstroth"},
        timeout=10,
    )
    check("create hive", r.ok, r.text[:300])
    hive_id = (r.json().get("hive") or {}).get("id")

    # 4. Hive list shows it
    r = s.get(f"{BASE}/api/hives", headers=H, timeout=10)
    ok = r.ok and any(h.get("id") == hive_id for h in r.json())
    check("hive list", ok, r.text[:300])

    # 5. Register the collector FIRST, then fetch nearest centres — the app
    # dispatches to a centre created from a real collector's sign-in.
    c_email = f"collector_{suffix}@e2e.test"
    r = s.post(
        f"{BASE}/api/auth/google",
        json={"email": c_email, "name": "E2E Collector", "role": "COLLECTION_PROCESSING"},
        timeout=10,
    )
    check("collector google login", r.ok, r.text[:300])
    c_token = r.json().get("token")
    collector_id = (r.json().get("user") or {}).get("id")
    CH = {"Authorization": f"Bearer {c_token}"}

    r = s.get(f"{BASE}/api/centers/nearest?role=COLLECTOR_PROCESSOR", headers=H, timeout=10)
    check("nearest centers", r.ok and r.json().get("centers"), r.text[:300])
    centers = r.json().get("centers") or []
    centre_id = next((c["id"] for c in centers if c["id"] == collector_id), centers[0]["id"] if centers else None)
    if not centre_id:
        # unaddressed requests are allowed; proceed without a target
        centre_id = None

    # 6. Create harvest + collection request (two-step, as the app does)
    r = s.post(
        f"{BASE}/api/harvests",
        headers=H,
        json={"hiveId": hive_id, "quantity": 12.5, "location": "Test Valley", "notes": "e2e"},
        timeout=10,
    )
    check("create harvest", r.ok, r.text[:500])
    batch_id = r.json().get("batchId") if r.ok else None

    r = s.post(
        f"{BASE}/api/requests",
        headers=H,
        json={"hiveId": hive_id, "batchId": batch_id, "quantity": 12.5, "location": "Test Valley",
              "collectionCentreId": centre_id, "notes": "e2e"},
        timeout=10,
    )
    check("create collection request", r.ok, r.text[:500])
    data = r.json() if r.ok else {}
    request_id = data.get("requestId")

    # 7. Harvester sees the request
    r = s.get(f"{BASE}/api/requests", headers=H, timeout=10)
    ok = r.ok and any(x.get("requestId") == request_id for x in r.json())
    check("harvester sees request", ok, r.text[:300])

    # 8. Collection & Processing user sees the request on their dashboard
    r = s.get(f"{BASE}/api/requests", headers=CH, timeout=10)
    target = next((x for x in (r.json() if r.ok else []) if x.get("requestId") == request_id), None)
    check("collector sees request", target is not None, r.text[:300])

    # 9. Collector accepts
    r = s.patch(f"{BASE}/api/requests/{request_id}/accept", headers=CH, json={}, timeout=10)
    check("collector accepts", r.ok, r.text[:500])

    # 10. Send to lab
    r = s.post(
        f"{BASE}/api/requests/{request_id}/send-next",
        headers=CH,
        json={"quantityReceived": 12.0, "quantityAfter": 11.5, "method": "Cold Extraction", "notes": "e2e"},
        timeout=10,
    )
    check("send to lab", r.ok, r.text[:500])

    # 11. Lab user login + accept (lab accepts the LAB REQUEST, not the
    # collection request — same id the app uses) + report
    l_email = f"lab_{suffix}@e2e.test"
    r = s.post(
        f"{BASE}/api/auth/google",
        json={"email": l_email, "name": "E2E Lab", "role": "LAB_TESTING"},
        timeout=10,
    )
    check("lab google login", r.ok, r.text[:300])
    l_token = r.json().get("token")
    LH = {"Authorization": f"Bearer {l_token}"}

    r = s.get(f"{BASE}/api/requests", headers=LH, timeout=10)
    lab_req = next((x for x in (r.json() if r.ok else []) if x.get("batchId") == batch_id), None)
    check("lab sees incoming request", lab_req is not None, r.text[:400])
    lab_accept_id = (lab_req or {}).get("id") or batch_id

    r = s.patch(f"{BASE}/api/requests/{lab_accept_id}/accept", headers=LH, json={}, timeout=10)
    check("lab accepts", r.ok, r.text[:500])

    r = s.post(
        f"{BASE}/api/lab-reports",
        headers=LH,
        json={"batchId": batch_id, "moistureContent": 17.5, "hmfValue": 20.0,
              "diastaseValue": 12.0, "qualityScore": 96.0, "contaminantsFound": "None"},
        timeout=10,
    )
    check("submit lab report", r.ok, r.text[:500])

    # 12. Send to packaging
    r = s.post(
        f"{BASE}/api/requests/{request_id}/send-next",
        headers=LH,
        json={"notes": "e2e"},
        timeout=10,
    )
    check("send to packaging", r.ok, r.text[:500])

    # 13. Packaging user login, sees batch, accepts, finalizes
    p_email = f"packager_{suffix}@e2e.test"
    r = s.post(
        f"{BASE}/api/auth/google",
        json={"email": p_email, "name": "E2E Packaging", "role": "PACKAGING"},
        timeout=10,
    )
    check("packaging google login", r.ok, r.text[:300])
    p_token = r.json().get("token")
    PH = {"Authorization": f"Bearer {p_token}"}

    r = s.get(f"{BASE}/api/requests", headers=PH, timeout=10)
    pkg_req = next((x for x in (r.json() if r.ok else []) if x.get("batchId") == batch_id), None)
    check("packaging sees request", pkg_req is not None, r.text[:400])

    r = s.patch(f"{BASE}/api/requests/REQ-PKG-{batch_id}/accept", headers=PH, json={}, timeout=10)
    check("packaging accepts", r.ok, r.text[:500])

    r = s.post(
        f"{BASE}/api/packaging",
        headers=PH,
        json={"batchId": batch_id, "finalQuantity": 11.0, "numberOfPackages": 22,
              "packageSize": "500g Glass Jar", "notes": "e2e"},
        timeout=10,
    )
    check("finalize packaging + QR", r.ok, r.text[:500])
    qr_url = r.json().get("verificationUrl") if r.ok else None

    # 14. Public verification WITHOUT auth (fresh session, no token)
    anon = requests.Session()
    r = anon.get(f"{BASE}/api/verify/{batch_id}", headers={"Accept": "application/json"}, timeout=10)
    check("public verify json (no auth)", r.ok, r.text[:400])
    if r.ok:
        v = r.json()
        check("verify shows harvester", bool(v.get("harvester", {}).get("name")) and v["harvester"]["name"] != "No data available yet.", json.dumps(v.get("harvester", {}))[:200])
        check("verify shows collection", v.get("collectionProcessing") is not None, str(v.get("collectionProcessing"))[:200])
        check("verify shows lab", v.get("labVerification") is not None, str(v.get("labVerification"))[:200])
        check("verify shows packaging", v.get("packaging") is not None, str(v.get("packaging"))[:200])
        check("verify fully verified", v.get("isFullyVerified") is True, str(v.get("status")))

    r = anon.get(f"{BASE}/verify/{batch_id}", headers={"Accept": "text/html"}, timeout=10)
    check("public verify html page (no auth)", r.ok and "<html" in r.text[:200].lower(), r.text[:200])

    if qr_url:
        r = anon.get(qr_url, headers={"Accept": "application/json"}, timeout=10)
        check("QR URL opens public verification", r.ok, r.text[:200])

    print()
    if FAILURES:
        print(f"FAILED STEPS: {FAILURES}")
        return 1
    print("ALL E2E WORKFLOW STEPS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
