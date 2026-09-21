import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import User, Hive, Lab, PackagingFacility


@pytest.fixture()
def client():
    init_db()
    return TestClient(app)


@pytest.fixture()
def db():
    init_db()
    session = SessionLocal()
    yield session
    session.close()


def _user(db, role, suffix, **overrides):
    user = User(
        name=overrides.get("name", f"{role} {suffix}"),
        email=overrides.get("email", f"{role.lower()}_{suffix}@example.com"),
        phone=overrides.get("phone", "+919999000000"),
        role=role,
        organization_name=overrides.get("organization_name", f"{role} Org {suffix}"),
        facility_location=overrides.get("facility_location", "Demo Facility"),
        license_number=overrides.get("license_number", f"LIC-{suffix}"),
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _headers(user):
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}


def _create_harvest_and_request(client, db, harvester, collector, suffix, quantity=18.0):
    hive = Hive(
        user_id=harvester.id,
        hive_code=f"HIVE-GUARD-{suffix}",
        name=f"Guard Hive {suffix}",
        apiary_location="Guard Apiary",
    )
    db.add(hive)
    db.commit()
    db.refresh(hive)

    harvest_res = client.post("/api/harvests", json={
        "hiveId": hive.id,
        "quantity": quantity,
        "location": hive.apiary_location,
    }, headers=_headers(harvester))
    assert harvest_res.status_code == 200, harvest_res.text
    batch_id = harvest_res.json()["batchId"]

    req_res = client.post("/api/requests", json={
        "batchId": batch_id,
        "hiveId": hive.id,
        "quantity": quantity,
        "location": hive.apiary_location,
        "toUserId": collector.id,
    }, headers=_headers(harvester))
    assert req_res.status_code == 200, req_res.text
    return hive, batch_id, req_res.json()["requestId"]


def test_duplicate_collection_request_is_blocked(client, db):
    suffix = uuid.uuid4().hex[:8]
    harvester = _user(db, "HARVESTER", suffix)
    collector = _user(db, "COLLECTOR_PROCESSOR", suffix)
    hive, batch_id, _ = _create_harvest_and_request(client, db, harvester, collector, suffix)

    duplicate = client.post("/api/requests", json={
        "batchId": batch_id,
        "hiveId": hive.id,
        "quantity": 18.0,
        "location": hive.apiary_location,
        "toUserId": collector.id,
    }, headers=_headers(harvester))

    assert duplicate.status_code == 200
    assert duplicate.json()["success"] is True


def test_lab_request_accept_requires_lab_role(client, db):
    suffix = uuid.uuid4().hex[:8]
    harvester = _user(db, "HARVESTER", suffix)
    collector = _user(db, "COLLECTOR_PROCESSOR", suffix)
    lab_user = _user(db, "LAB", suffix)
    db.add(Lab(id=lab_user.id, user_id=lab_user.id, lab_name="Guard Lab", facility_location="Lab City", is_active=True))
    db.commit()
    _, _, request_id = _create_harvest_and_request(client, db, harvester, collector, suffix)

    accept_res = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_headers(collector))
    assert accept_res.status_code == 200, accept_res.text
    lab_req_res = client.post(f"/api/requests/{request_id}/send-next", json={
        "toUserId": lab_user.id,
        "quantityReceived": 18.0,
        "quantityAfter": 17.5,
        "method": "Filtering",
    }, headers=_headers(collector))
    assert lab_req_res.status_code == 200, lab_req_res.text
    lab_request_id = lab_req_res.json()["labRequestId"]

    wrong_role = client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_headers(collector))

    assert wrong_role.status_code == 403
    assert wrong_role.json()["detail"]["code"] == "FORBIDDEN"


def test_packaging_blocked_after_failed_lab_test(client, db):
    suffix = uuid.uuid4().hex[:8]
    harvester = _user(db, "HARVESTER", suffix)
    collector = _user(db, "COLLECTOR_PROCESSOR", suffix)
    lab_user = _user(db, "LAB", suffix)
    packager = _user(db, "PACKAGING", suffix)
    db.add(Lab(id=lab_user.id, user_id=lab_user.id, lab_name="Guard Lab", facility_location="Lab City", is_active=True))
    db.add(PackagingFacility(id=packager.id, name="Guard Packaging", location="Pack City", is_active=True))
    db.commit()

    _, batch_id, request_id = _create_harvest_and_request(client, db, harvester, collector, suffix)
    assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_headers(collector)).status_code == 200
    lab_req_res = client.post(f"/api/requests/{request_id}/send-next", json={
        "toUserId": lab_user.id,
        "quantityReceived": 18.0,
        "quantityAfter": 17.5,
        "method": "Filtering",
    }, headers=_headers(collector))
    assert lab_req_res.status_code == 200, lab_req_res.text
    lab_request_id = lab_req_res.json()["labRequestId"]
    assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_headers(lab_user)).status_code == 200

    failed_report = client.post("/api/lab-reports", json={
        "batchId": batch_id,
        "qualityScore": 40.0,
        "moistureContent": 24.0,
        "hmfValue": 55.0,
        "diastaseValue": 3.0,
        "contaminantsFound": "Residues detected",
    }, headers=_headers(lab_user))
    assert failed_report.status_code == 200, failed_report.text
    assert failed_report.json()["overallResult"] == "FAIL"

    send_packaging = client.post(f"/api/requests/{lab_request_id}/send-next", json={
        "toUserId": packager.id,
    }, headers=_headers(lab_user))
    assert send_packaging.status_code == 409
    assert send_packaging.json()["detail"]["code"] == "LAB_TEST_FAILED"

    package_res = client.post("/api/packaging", json={
        "batchId": batch_id,
        "finalQuantity": 17.0,
        "numberOfPackages": 34,
    }, headers=_headers(packager))
    assert package_res.status_code == 409
    assert package_res.json()["detail"]["code"] == "LAB_TEST_FAILED"
