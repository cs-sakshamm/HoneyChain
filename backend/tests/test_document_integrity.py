"""
Document integrity re-comparison (spec §11, §29-30 negative testing).

The public verifier must actually re-compute the lab report's SHA-256 over
its certification payload and compare it with the hash anchored on-chain.
A report row altered after certification must surface as
REPORT INTEGRITY FAILED — tamper-evidence, not a static "anchored" label.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import (
    CollectionBatch,
    CollectionRequest,
    Hive,
    Lab,
    LabReport,
    LabRequest,
    PackagingFacility,
    User,
)


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


def _mk_user(db, role: str, tag: str) -> User:
    sfx = f"{uuid.uuid4().hex[:6]}{tag}"
    user = User(
        name=f"{role} {sfx}",
        email=f"integ_{role.lower()}_{sfx}@example.test",
        phone=f"+9191600{sfx[-6:]}",
        role=role,
        organization_name=f"{role} Org {sfx}",
        facility_location="Integrity Facility",
        license_number=f"LIC-{sfx}",
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _headers(user: User) -> dict:
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="module")
def certified_batch():
    """Run one full HARVEST→…→LAB PASS chain for integrity checks."""
    db = SessionLocal()
    try:
        harvester = _mk_user(db, "HARVESTER", "fx")
        collector = _mk_user(db, "COLLECTOR_PROCESSOR", "fx")
        lab_user = _mk_user(db, "LAB", "fx")
        packager = _mk_user(db, "PACKAGING", "fx")
        db.add(Lab(id=lab_user.id, user_id=lab_user.id, lab_name="Integrity Lab", facility_location="Lab City", is_active=True))
        db.add(PackagingFacility(id=packager.id, name="Integrity Packaging", location="Pack City", is_active=True))
        hive = Hive(
            user_id=harvester.id,
            device_id=f"SIH_INTEG_{uuid.uuid4().hex[:8]}",
            hive_code=f"HIVE-INTEG-{uuid.uuid4().hex[:6].upper()}",
            name="Integrity Hive",
            apiary_location="Integrity Apiary",
        )
        db.add(hive)
        db.commit()
        db.refresh(hive)
        hive_id = hive.id
        users = {
            "harvester": {"id": harvester.id, "email": harvester.email, "role": harvester.role},
            "collector": {"id": collector.id, "email": collector.email, "role": collector.role},
            "lab": {"id": lab_user.id, "email": lab_user.id and lab_user.email, "role": lab_user.role},
            "packager": {"id": packager.id, "email": packager.email, "role": packager.role},
        }
    finally:
        db.close()

    client = TestClient(app)
    h = lambda u: _headers(type("U", (), {"id": u["id"], "email": u["email"], "role": u["role"]}))

    harvest = client.post("/api/harvests", json={
        "hiveId": hive_id, "quantity": 12.0, "location": "Integrity Apiary",
    }, headers=h(users["harvester"]))
    assert harvest.status_code == 200, harvest.text
    batch_id = harvest.json()["batchId"]

    req = client.post("/api/requests", json={
        "batchId": batch_id, "hiveId": hive_id, "quantity": 12.0,
        "location": "Integrity Apiary", "toUserId": users["collector"]["id"],
    }, headers=h(users["harvester"]))
    assert req.status_code == 200, req.text
    request_id = req.json()["requestId"]

    assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=h(users["collector"])).status_code == 200

    proc = client.post("/api/processing", json={
        "batchId": batch_id, "quantityReceived": 12.0, "quantityAfter": 11.5,
    }, headers=h(users["collector"]))
    assert proc.status_code == 200, proc.text

    lab_req = client.post(f"/api/requests/{request_id}/send-next", json={
        "toUserId": users["lab"]["id"], "quantityReceived": 11.5, "quantityAfter": 11.0,
    }, headers=h(users["collector"]))
    assert lab_req.status_code == 200, lab_req.text
    lab_request_id = lab_req.json()["labRequestId"]
    assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=h(users["lab"])).status_code == 200

    report = client.post("/api/lab-reports", json={
        "batchId": batch_id, "moistureContent": 17.0, "hmfValue": 15.0,
        "diastaseValue": 12.0, "contaminantsFound": "None", "qualityScore": 96.0,
    }, headers=h(users["lab"]))
    assert report.status_code == 200, report.text
    assert report.json()["overallResult"] == "PASS"

    # Complete the chain through packaging so the final QR record exists.
    pkg = client.post("/api/packaging", json={
        "batchId": batch_id, "finalQuantity": 11.0, "numberOfPackages": 22,
    }, headers=h(users["packager"]))
    assert pkg.status_code == 200, pkg.text

    return batch_id


def test_intact_chain_shows_document_integrity_verified(client, certified_batch):
    batch_id = certified_batch
    res = client.get(f"/api/verify/{batch_id}")
    assert res.status_code == 200
    lab = res.json()["labVerification"]
    assert lab["documentHash"], "certified batch must have an anchored hash"
    assert lab["documentIntegrityStatus"] == "DOCUMENT INTEGRITY VERIFIED"
    # The verdict must be the real comparison result, not the static legacy label.
    assert lab["documentIntegrityStatus"] != "DOCUMENT HASH ANCHORED"


def test_tampered_report_row_fails_integrity(client, certified_batch, db_fixture=None):
    batch_id = certified_batch
    db = SessionLocal()
    try:
        report = db.query(LabReport).filter(LabReport.batch_id == batch_id).first()
        original_hmf = report.hmf_value
        # Simulate post-certification tampering of the report record.
        report.hmf_value = 12.0
        db.commit()
    finally:
        db.close()

    try:
        res = client.get(f"/api/verify/{batch_id}")
        assert res.status_code == 200
        lab = res.json()["labVerification"]
        assert lab["documentIntegrityStatus"] == "REPORT INTEGRITY FAILED", (
            f"tampered report must fail integrity, got: {lab['documentIntegrityStatus']}"
        )
    finally:
        # Restore so the module-scoped fixture chain stays consistent.
        db = SessionLocal()
        try:
            report = db.query(LabReport).filter(LabReport.batch_id == batch_id).first()
            report.hmf_value = original_hmf
            db.commit()
        finally:
            db.close()


def test_final_qr_uses_real_batch_id_and_public_verify_route(client, certified_batch):
    """Spec §20: the final QR must encode the REAL batch ID pointing at the
    public /verify route, and the stored image must be a genuine PNG that
    decodes back to exactly that URL."""
    import base64
    import io
    import os

    import zxingcpp
    from PIL import Image

    from backend.models import QRCode

    batch_id = certified_batch
    db = SessionLocal()
    try:
        qr = db.query(QRCode).filter(QRCode.batch_id == batch_id).first()
        assert qr is not None, "packaging must persist a QR record"
        expected_base = os.getenv("PUBLIC_APP_URL", "http://127.0.0.1:8000").rstrip("/")
        expected_url = f"{expected_base}/verify/{batch_id}"
        assert qr.verification_url == expected_url
        assert qr.qr_image_data_uri, "QR image data must be stored"
        assert qr.qr_image_data_uri.startswith("data:image/png;base64,")
        png_bytes = base64.b64decode(qr.qr_image_data_uri.split(",", 1)[1])
        assert png_bytes[:8] == b"\x89PNG\r\n\x1a\n", "stored QR must decode to a real PNG"
    finally:
        db.close()

    # The stored image must actually be a scannable QRCode encoding exactly
    # the public verification URL — not a placeholder or a different payload.
    decoded = zxingcpp.read_barcodes(Image.open(io.BytesIO(png_bytes)))
    assert decoded, "stored PNG must be a readable QR code"
    assert [r.text for r in decoded] == [expected_url]
    assert all(r.format == zxingcpp.BarcodeFormat.QRCode for r in decoded)

    # The encoded URL must resolve publicly (fresh, unauthenticated).
    res = client.get(f"/verify/{batch_id}")
    assert res.status_code == 200


def test_no_anchored_hash_never_claims_integrity(client):
    """A lab report without a LAB_CERTIFICATION blockchain record must not
    display any integrity-verified claim (§11: no fake hash verification)."""
    sfx = uuid.uuid4().hex[:8]
    db = SessionLocal()
    try:
        # Any user works as the lab identity; the point is no blockchain record.
        lab_user = _mk_user(db, "LAB", "nl")
        report = LabReport(
            report_id=f"LAB-RPT-NOLINK-{sfx}",
            batch_id=f"HC-BATCH-NOLINK-{sfx}",
            lab_id=lab_user.id,
            moisture_content=17.0,
            hmf_value=15.0,
            diastase_value=12.0,
            overall_result="PASS",
        )
        db.add(report)
        db.commit()
    finally:
        db.close()

    res = client.get(f"/api/verify/HC-BATCH-NOLINK-{sfx}")
    assert res.status_code in (200, 404)
    if res.status_code == 200:
        lab = res.json()["labVerification"]
        assert lab["documentIntegrityStatus"] != "DOCUMENT INTEGRITY VERIFIED"
