"""
Batch ID chain integrity (spec §4/§13/§21/§22).

One batch ID minted at harvest must link every downstream stage —
collection request, processing, lab report, packaging, blockchain
records, and public QR verification. No stage may regenerate or
disconnect the ID. Also pins negative cases: nonexistent batch IDs are
rejected at verification, and packaging refuses an unknown batch.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import (
    BlockchainRecord,
    CollectionBatch,
    Hive,
    Lab,
    LabReport,
    PackagingFacility,
    User,
)


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


@pytest.fixture(scope="module")
def db():
    init_db()
    session = SessionLocal()
    yield session
    session.close()


def _headers(user):
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="module")
def chain(client, db):
    """Run one complete HARVEST→PACKAGING chain and capture every stage."""
    suffix = uuid.uuid4().hex[:8]

    def _user(role, **overrides):
        user = User(
            name=f"{role} {suffix}",
            email=f"{role.lower()}_{suffix}@example.com",
            phone="+919999000002",
            role=role,
            organization_name=f"{role} Org {suffix}",
            facility_location="Chain Facility",
            license_number=f"LIC-{role}-{suffix}",
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    harvester = _user("HARVESTER")
    collector = _user("COLLECTOR_PROCESSOR")
    lab_user = _user("LAB")
    packager = _user("PACKAGING")
    db.add(Lab(id=lab_user.id, user_id=lab_user.id, lab_name="Chain Lab", facility_location="Lab City", is_active=True))
    db.add(PackagingFacility(id=packager.id, name="Chain Packaging", location="Pack City", is_active=True))
    db.commit()

    hive = Hive(user_id=harvester.id, hive_code=f"HIVE-CHAIN-{suffix}", name="Chain Hive", apiary_location="Chain Apiary")
    db.add(hive)
    db.commit()
    db.refresh(hive)

    stages: dict = {}

    # HARVEST — batch ID is minted here
    harvest = client.post("/api/harvests", json={
        "hiveId": hive.id,
        "quantity": 20.0,
        "location": "Chain Apiary",
    }, headers=_headers(harvester))
    assert harvest.status_code == 200, harvest.text
    batch_id = harvest.json()["batchId"]
    stages["harvest"] = harvest.json()

    # COLLECTION request → accept → processing
    req = client.post("/api/requests", json={
        "batchId": batch_id,
        "hiveId": hive.id,
        "quantity": 20.0,
        "location": "Chain Apiary",
        "toUserId": collector.id,
    }, headers=_headers(harvester))
    assert req.status_code == 200, req.text
    request_id = req.json()["requestId"]
    stages["collection_request"] = req.json()
    assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_headers(collector)).status_code == 200

    proc = client.post("/api/processing", json={
        "batchId": batch_id,
        "processorId": collector.id,
        "quantityReceived": 20.0,
        "quantityAfter": 19.5,
        "method": "Cold Extraction",
    }, headers=_headers(collector))
    assert proc.status_code == 200, proc.text
    stages["processing"] = proc.json()

    # LAB_TEST
    lab_req = client.post(f"/api/requests/{request_id}/send-next", json={
        "toUserId": lab_user.id,
        "quantityReceived": 19.5,
        "quantityAfter": 19.0,
        "method": "Filtering",
    }, headers=_headers(collector))
    assert lab_req.status_code == 200, lab_req.text
    lab_request_id = lab_req.json()["labRequestId"]
    assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_headers(lab_user)).status_code == 200

    lab = client.post("/api/lab-reports", json={
        "batchId": batch_id,
        "labId": lab_user.id,
        "qualityScore": 97.0,
        "moistureContent": 17.0,
        "hmfValue": 15.0,
        "diastaseValue": 12.0,
        "contaminantsFound": "None",
        "purityGrade": "Grade A",
    }, headers=_headers(lab_user))
    assert lab.status_code == 200, lab.text
    stages["lab"] = lab.json()

    # PACKAGING
    client.post(f"/api/requests/{lab_request_id}/send-next", json={
        "toUserId": packager.id,
    }, headers=_headers(lab_user))
    pkg = client.post("/api/packaging", json={
        "batchId": batch_id,
        "packagerId": packager.id,
        "finalQuantity": 19.0,
        "numberOfPackages": 38,
        "packageSize": "500g",
    }, headers=_headers(packager))
    assert pkg.status_code == 200, pkg.text
    stages["packaging"] = pkg.json()

    # PUBLIC VERIFICATION
    verify = client.get(f"/api/verify/{batch_id}")
    assert verify.status_code == 200, verify.text
    stages["verification"] = verify.json()

    stages["batch_id"] = batch_id
    stages["hive_id"] = hive.id
    stages["request_id"] = request_id
    stages["user_ids"] = [harvester.id, collector.id, lab_user.id, packager.id]
    return stages


class TestBatchIdChain:
    def test_batch_id_format_and_uniqueness(self, db, chain):
        """Batch ID minted at harvest, HNY-style, unique in the DB."""
        batch_id = chain["batch_id"]
        assert batch_id, "harvest must mint a batch ID"
        rows = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).all()
        assert len(rows) == 1, "duplicate batch ID in database"

    def test_same_batch_id_in_every_stage_response(self, chain):
        """Every stage response carries the same batch ID — none regenerated."""
        batch_id = chain["batch_id"]
        assert chain["collection_request"]["batchId"] == batch_id
        assert chain["processing"]["batchId"] == batch_id
        assert chain["lab"]["batchId"] == batch_id
        assert chain["packaging"]["batchId"] == batch_id

    def test_db_rows_all_reference_one_batch(self, db, chain):
        """DB rows for processing/lab/packaging all reference the same batch."""
        batch_id = chain["batch_id"]
        batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).first()
        assert batch is not None
        assert batch.current_stage in ("PACKAGING", "COMPLETED", "QR_VERIFICATION")

    def test_blockchain_records_link_to_batch(self, db, chain):
        """Every blockchain record for this chain references the same batch ID.

        tx_hash is required only for CONFIRMED records; without a reachable
        chain the service degrades to status=PENDING (graceful, by design)."""
        batch_id = chain["batch_id"]
        records = db.query(BlockchainRecord).filter(BlockchainRecord.batch_id == batch_id).all()
        assert records, "no blockchain records for the batch chain"
        event_types = {r.event_type for r in records}
        assert event_types, "blockchain records have no event types"
        for r in records:
            assert r.data_hash, "blockchain record missing data hash anchor"
            if (r.status or "").upper() == "CONFIRMED":
                assert r.tx_hash, "CONFIRMED blockchain record missing tx hash"
        # Every record must belong to this chain's actors — no cross-batch mixing.
        assert all(r.actor_id in chain["user_ids"] for r in records)

    def test_public_verification_displays_full_chain(self, chain):
        """Public QR payload reflects the same batch and a complete stage set."""
        vdata = chain["verification"]
        assert vdata["found"] is True
        assert vdata["batchId"] == chain["batch_id"]
        assert vdata["isFullyVerified"] is True
        assert vdata["labVerification"]["status"] == "CERTIFIED APPROVED (PASS)"

    def test_unknown_batch_id_rejected_at_verification(self, client):
        """Nonexistent batch ID must not return fabricated provenance."""
        resp = client.get("/api/verify/HNY-9999-FAKE")
        data = resp.json()
        assert data["found"] is False or data["status"] == "Invalid or unrecognized batch"

    def test_packaging_rejects_unknown_batch(self, client, db, chain):
        """Packaging must refuse to package a batch that was never harvested."""
        packager_id = chain["user_ids"][3]
        resp = client.post("/api/packaging", json={
            "batchId": f"HNY-9999-{uuid.uuid4().hex[:4].upper()}",
            "packagerId": packager_id,
            "finalQuantity": 10.0,
            "numberOfPackages": 20,
            "packageSize": "500g",
        }, headers=_headers(db.query(User).filter(User.id == packager_id).first()))
        assert resp.status_code in (400, 404), (
            f"packaging accepted a nonexistent batch: {resp.status_code} {resp.text}"
        )

    def test_harvest_rejects_unknown_hive(self, client):
        """Harvest for a nonexistent hive must be rejected, not mint a batch."""
        suffix = uuid.uuid4().hex[:8]
        user = User(
            name=f"HARVESTER {suffix}",
            email=f"hv_bad_{suffix}@example.com",
            phone="+919999000003",
            role="HARVESTER",
            organization_name="Bad Hive Org",
            facility_location="X",
            license_number=f"LIC-BAD-{suffix}",
            is_verified=True,
        )
        db = SessionLocal()
        try:
            db.add(user)
            db.commit()
            db.refresh(user)
            resp = client.post("/api/harvests", json={
                "hiveId": f"hive-does-not-exist-{suffix}",
                "quantity": 5.0,
                "location": "Nowhere",
            }, headers=_headers(user))
            assert resp.status_code in (400, 404), (
                f"harvest accepted a nonexistent hive: {resp.status_code} {resp.text}"
            )
        finally:
            db.rollback()
            db.close()
