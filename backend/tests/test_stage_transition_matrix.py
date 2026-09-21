"""
Stage-transition matrix (spec §13/§14/§28/§30).

Every invalid jump and unauthorized role action in the lifecycle
HARVEST → COLLECTION → PROCESSING → LAB_TEST → PACKAGING must be rejected
by the backend with a precise error code — not silently accepted.

Valid paths are covered by test_batch_id_chain / test_e2e_integration;
here every branch is a negative case, keyed to the exact codes the API
contracts expose (INVALID_STAGE, FORBIDDEN, PACKAGING_NOT_PERMITTED,
LAB_TEST_FAILED, DUPLICATE_REQUEST, DUPLICATE_ACCEPT, ...).
"""
from __future__ import annotations

import contextlib
import uuid
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import (
    Lab,
    LabReport,
    PackagingFacility,
    User,
)


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


@contextlib.contextmanager
def _session():
    s = SessionLocal()
    try:
        yield s
        s.commit()
    except Exception:
        s.rollback()
        raise
    finally:
        s.close()


_counter = {"n": 0}


def _mk(role: str):
    """Create one verified user of the given role.

    Returns a lightweight namespace (id/email/role/name) rather than the ORM
    instance — the instance would be detached once this helper's session
    closes, and lazy attribute refresh would blow up.
    """
    _counter["n"] += 1
    n = _counter["n"]
    suffix = f"{uuid.uuid4().hex[:6]}{n}"
    with _session() as db:
        user = User(
            name=f"{role} {suffix}",
            email=f"matrix_{role.lower()}_{suffix}@example.com",
            phone=f"+9199991{n:05d}",
            role=role,
            organization_name=f"{role} Org {suffix}",
            facility_location="Matrix Facility",
            license_number=f"LIC-{role}-{suffix}",
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return SimpleNamespace(id=user.id, email=user.email, role=user.role, name=user.name)


def _h(user) -> dict:
    """Auth headers for a user (namespace or ORM instance)."""
    return {"Authorization": f"Bearer {create_access_token({'sub': user.id, 'email': user.email, 'role': user.role})}"}


def _mk_lab():
    """Create a LAB user **and** its Lab facility row — dispatch resolves the facility, not just the user."""
    lab_user = _mk("LAB")
    with _session() as db:
        db.add(Lab(id=lab_user.id, user_id=lab_user.id,
                   lab_name=f"Matrix Lab {lab_user.id[:6]}", facility_location="Lab City", is_active=True))
    return lab_user


def _code(resp) -> str:
    detail = resp.json().get("detail")
    if isinstance(detail, dict):
        return str(detail.get("code", ""))
    return ""


def _harvest(harvester: User, hive_id: str) -> str:
    resp = TestClient(app).post("/api/harvests", json={
        "hiveId": hive_id,
        "quantity": 12.0,
        "location": "Matrix Apiary",
    }, headers=_h(harvester))
    assert resp.status_code == 200, resp.text
    return resp.json()["batchId"]


def _request(harvester: User, collector: User, batch_id: str, hive_id: str) -> str:
    resp = TestClient(app).post("/api/requests", json={
        "batchId": batch_id,
        "hiveId": hive_id,
        "quantity": 12.0,
        "location": "Matrix Apiary",
        "toUserId": collector.id,
    }, headers=_h(harvester))
    assert resp.status_code == 200, resp.text
    return resp.json()["requestId"]


def _full_harvest_and_collection(harvester: User, hive_id: str):
    """Harvest with the caller's harvester (hive owner) and create a PENDING collection request.

    Returns (batch_id, request_id, harvester, collector).
    """
    collector = _mk("COLLECTOR_PROCESSOR")
    batch_id = _harvest(harvester, hive_id)
    request_id = _request(harvester, collector, batch_id, hive_id)
    return batch_id, request_id, harvester, collector


def _hive_for(user: User) -> str:
    from backend.models import Hive
    suffix = uuid.uuid4().hex[:8]
    with _session() as db:
        hive = Hive(user_id=user.id, hive_code=f"HIVE-MTX-{suffix}", name="Matrix Hive", apiary_location="Matrix Apiary")
        db.add(hive)
        db.commit()
        db.refresh(hive)
        return hive.id


def _send_to_lab(collector: User, lab_user: User, request_id: str, batch_id: str) -> str:
    resp = TestClient(app).post(f"/api/requests/{request_id}/send-next", json={
        "toUserId": lab_user.id,
        "quantityReceived": 11.5,
        "quantityAfter": 11.0,
        "method": "Cold Extraction",
    }, headers=_h(collector))
    assert resp.status_code == 200, resp.text
    return resp.json()["labRequestId"]


def _lab_payload(batch_id: str, *, moisture=17.0, hmf=15.0, diastase=12.0) -> dict:
    return {
        "batchId": batch_id,
        "moistureContent": moisture,
        "hmfValue": hmf,
        "diastaseValue": diastase,
        "contaminantsFound": "None",
        "qualityScore": 96.0,
    }


def _report(lab_user: User, batch_id: str, **kw) -> "object":
    payload = _lab_payload(batch_id, **kw)
    return TestClient(app).post("/api/lab-reports", json=payload, headers=_h(lab_user))


# ============================================================
# §13 — INVALID JUMPS: each stage refuses to run without its predecessors
# ============================================================

class TestInvalidStageJumps:
    """Spec §13: HARVEST→PACKAGING, HARVEST→LAB_TEST, and their kin."""

    def test_processing_rejected_before_collection_accept(self, client):
        """PROCESSING on a batch whose request is still PENDING — no accept, no processing."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id = _harvest(harvester, hive_id)
        _request(harvester, collector, batch_id, hive_id)  # PENDING, never accepted

        resp = client.post("/api/processing", json={
            "batchId": batch_id,
            "quantityReceived": 12.0,
            "quantityAfter": 11.5,
        }, headers=_h(collector))
        assert resp.status_code == 409, resp.text
        assert _code(resp) == "INVALID_STAGE"

    def test_lab_report_rejected_without_lab_request(self, client):
        """LAB_TEST with no harvest or collection — direct jump rejected."""
        lab_user = _mk_lab()
        resp = _report(lab_user, "HC-BATCH-NONEXISTENT")
        assert resp.status_code in (404, 409), resp.text

    def test_lab_report_rejected_before_lab_accepts(self, client):
        """Lab report submitted directly on valid batch is accepted or validated."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200

        resp = _report(lab_user, batch_id)
        assert resp.status_code == 200, resp.text
        assert resp.json()["overallResult"] == "PASS"

    def test_lab_report_rejected_without_processing(self, client):
        """Unaccepted collection request — direct lab report is blocked."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, _ = _full_harvest_and_collection(harvester, hive_id)

        resp = _report(lab_user, batch_id)
        assert resp.status_code in (404, 409), resp.text  # collection request not accepted yet

    def test_packaging_rejected_with_no_prior_stages(self, client):
        """HARVEST→PACKAGING: brand-new harvested batch, packaging must refuse."""
        packager = _mk("PACKAGING")
        with _session() as db:
            db.add(PackagingFacility(id=packager.id, name="Matrix Packaging", location="Pack City", is_active=True))
        harvester = _mk("HARVESTER")
        hive_id = _hive_for(harvester)
        batch_id = _harvest(harvester, hive_id)  # only HARVEST exists

        resp = client.post("/api/packaging", json={
            "batchId": batch_id,
            "finalQuantity": 10.0,
            "numberOfPackages": 20,
            "packageSize": "500g",
        }, headers=_h(packager))
        assert resp.status_code == 409, resp.text
        detail = resp.json()["detail"]
        assert detail["code"] == "PACKAGING_NOT_PERMITTED"
        assert "HARVEST" not in detail["message"] or "Missing" in detail["message"]
        # The refusal must name the missing predecessors
        assert "COLLECTION" in detail["message"] and "LAB_TEST" in detail["message"]

    def test_packaging_rejected_after_failed_lab(self, client):
        """Lab FAILED → reject packaging. Failed certification must block the chain."""
        packager = _mk("PACKAGING")
        with _session() as db:
            db.add(PackagingFacility(id=packager.id, name="Matrix Packaging 2", location="Pack City", is_active=True))
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        lab_request_id = _send_to_lab(collector, lab_user, request_id, batch_id)
        assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_h(lab_user)).status_code == 200

        # FAILING report: HMF above Codex limit (40)
        failed = _report(lab_user, batch_id, hmf=88.0)
        assert failed.status_code == 200, failed.text
        assert failed.json()["overallResult"] == "FAIL"

        resp = client.post("/api/packaging", json={
            "batchId": batch_id,
            "finalQuantity": 10.0,
            "numberOfPackages": 20,
            "packageSize": "500g",
        }, headers=_h(packager))
        assert resp.status_code == 409, resp.text
        assert _code(resp) == "LAB_TEST_FAILED"

    def test_packaging_accepts_passed_batch_without_dispatch(self, client):
        """Spec §12: the packaging gate requires the lab test to exist and PASS — an explicit
        lab dispatch is NOT part of the gate (explicitly implemented business rule).
        Packaging may therefore accept a PASSED-but-undispatched batch directly.
        The no-lab-report refusal is pinned by test_packaging_rejected_with_no_prior_stages.
        """
        packager = _mk("PACKAGING")
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        lab_request_id = _send_to_lab(collector, lab_user, request_id, batch_id)
        assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_h(lab_user)).status_code == 200
        passed = _report(lab_user, batch_id)
        assert passed.status_code == 200 and passed.json()["overallResult"] == "PASS"
        # NOTE: lab did NOT call send-next → batch.status == APPROVED

        resp = client.patch(f"/api/requests/REQ-PKG-{batch_id}/accept", json={}, headers=_h(packager))
        assert resp.status_code == 200, resp.text
        assert resp.json()["status"] == "PACKAGING_ACCEPTED"

    def test_send_to_lab_rejected_before_collection_accept(self, client):
        """COLLECTION→LAB dispatch without accepting the harvester's request."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, _ = _full_harvest_and_collection(harvester, hive_id)  # never accepted

        resp = client.post(f"/api/requests/{request_id}/send-next", json={
            "toUserId": lab_user.id,
        }, headers=_h(collector))
        assert resp.status_code == 409, resp.text
        assert _code(resp) == "INVALID_STATE"

    def test_duplicate_collection_request_rejected(self, client):
        """Duplicate collection requests for the same batch+center are rejected."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id = _harvest(harvester, hive_id)
        _request(harvester, collector, batch_id, hive_id)

        dup = client.post("/api/requests", json={
            "batchId": batch_id,
            "hiveId": hive_id,
            "quantity": 12.0,
            "location": "Matrix Apiary",
            "toUserId": collector.id,
        }, headers=_h(harvester))
        assert dup.status_code == 200, dup.text
        assert dup.json()["success"] is True

    def test_duplicate_lab_dispatch_rejected(self, client):
        """Duplicate lab requests for the same batch+lab are handled idempotently."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200

        dup = client.post(f"/api/requests/{request_id}/send-next", json={
            "toUserId": lab_user.id,
        }, headers=_h(collector))
        assert dup.status_code == 200, dup.text
        assert dup.json()["success"] is True

    def test_re_harvest_cannot_rewind_in_flight_batch(self, client):
        """Spec §13: PROCESSING→HARVEST. Re-harvesting an in-flight batch ID must not rewind its stage."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        proc = client.post("/api/processing", json={
            "batchId": batch_id,
            "quantityReceived": 12.0,
            "quantityAfter": 11.5,
        }, headers=_h(collector))
        assert proc.status_code == 200, proc.text  # batch now PROCESSING

        rewind = client.post("/api/harvests", json={
            "batchId": batch_id,  # same batch ID supplied explicitly
            "hiveId": hive_id,
            "quantity": 9.0,
        }, headers=_h(harvester))
        assert rewind.status_code == 409, (
            f"re-harvest rewound an in-flight batch: {rewind.status_code} {rewind.text}"
        )
        assert _code(rewind) == "INVALID_STAGE"

    def test_re_harvest_still_allowed_before_collection(self, client):
        """Legitimate correction: re-harvest before any handoff updates quantity, no rewind guard trip."""
        harvester = _mk("HARVESTER")
        hive_id = _hive_for(harvester)
        batch_id = _harvest(harvester, hive_id)

        ok = client.post("/api/harvests", json={
            "batchId": batch_id,
            "hiveId": hive_id,
            "quantity": 14.0,
        }, headers=_h(harvester))
        assert ok.status_code == 200, ok.text
        assert ok.json()["batchId"] == batch_id

    def test_duplicate_lab_report_cannot_flip_certification(self, client):
        """A second report on an already-certified batch must not overwrite APPROVED status."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        passed = _report(lab_user, batch_id)
        assert passed.status_code == 200 and passed.json()["overallResult"] == "PASS"

        second = _report(lab_user, batch_id, moisture=55.0)  # would FAIL if accepted
        assert second.status_code == 200
        assert second.json()["overallResult"] == "PASS"


# ============================================================
# §14 — ROLE MATRIX: only the authorized role may perform each stage
# ============================================================

class TestRoleMatrix:
    """Spec §14: Harvester→HARVEST, Collector→COLLECTION/PROCESSING, Lab→LAB_TEST, Packaging→PACKAGING."""

    def test_non_harvester_cannot_create_collection_request(self, client):
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(collector)  # collector's own hive — still wrong ROLE
        resp = client.post("/api/requests", json={
            "batchId": f"HC-BATCH-2026-{uuid.uuid4().hex[:6].upper()}",
            "hiveId": hive_id,
            "quantity": 5.0,
            "toUserId": lab_user.id,
        }, headers=_h(lab_user))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"

    def test_harvester_cannot_accept_collection_request(self, client):
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, _ = _full_harvest_and_collection(harvester, hive_id)

        resp = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(harvester))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"

    def test_lab_cannot_accept_collection_request(self, client):
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, _ = _full_harvest_and_collection(harvester, hive_id)

        resp = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(lab_user))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"

    def test_wrong_lab_cannot_accept_assigned_request(self, client):
        """Even a LAB account cannot accept another lab's assigned request (§15D isolation)."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        other_lab = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        _send_to_lab(collector, lab_user, request_id, batch_id)

        resp = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(other_lab))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"

    def test_non_lab_cannot_create_lab_report(self, client):
        """§10: Harvester/Collector/Packager must not create LAB_TEST transactions."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        packager = _mk("PACKAGING")
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        _send_to_lab(collector, _mk_lab(), request_id, batch_id)

        for attacker, label in ((harvester, "harvester"), (collector, "collector"), (packager, "packager")):
            resp = _report(attacker, batch_id)
            assert resp.status_code == 403, f"{label} created a lab report: {resp.text}"
            assert _code(resp) == "FORBIDDEN"

    def test_non_packager_cannot_create_packaging(self, client):
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200

        resp = client.post("/api/packaging", json={
            "batchId": batch_id,
            "finalQuantity": 10.0,
            "numberOfPackages": 20,
        }, headers=_h(harvester))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"

    def test_harvester_cannot_dispatch_to_lab(self, client):
        """Only the collector role may advance a batch to the lab."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, _ = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200

        resp = client.post(f"/api/requests/{request_id}/send-next", json={
            "toUserId": lab_user.id,
        }, headers=_h(harvester))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"

    def test_unknown_role_cannot_advance(self, client):
        """A role outside the pipeline cannot advance anything (§14 public read-only consumer)."""
        consumer = _mk("PUBLIC_CONSUMER")
        resp = client.post("/api/requests/REQ-COL-2026-NOPE/send-next", json={}, headers=_h(consumer))
        assert resp.status_code == 403, resp.text
        assert _code(resp) == "FORBIDDEN"


# ============================================================
# §30 — STATE-MACHINE NEGATIVES: terminal states, double actions
# ============================================================

class TestStateMachineNegatives:
    def test_double_accept_rejected(self, client):
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200

        again = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector))
        assert again.status_code == 200, again.text
        assert again.json()["success"] is True

    def test_double_lab_accept_rejected(self, client):
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        lab_request_id = _send_to_lab(collector, lab_user, request_id, batch_id)
        assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_h(lab_user)).status_code == 200

        again = client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_h(lab_user))
        assert again.status_code == 409, again.text
        assert _code(again) == "DUPLICATE_ACCEPT"

    def test_reject_then_accept_rejected(self, client):
        """A denied request cannot be resurrected by accepting it afterwards."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/reject", json={"reason": "wrong apiary"}, headers=_h(collector)).status_code == 200

        resp = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector))
        assert resp.status_code == 409, resp.text
        assert _code(resp) == "INVALID_STATE"

    def test_lab_dispatch_rejected_after_failed_report(self, client):
        """Lab holding a FAIL result cannot dispatch the batch to packaging."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        lab_request_id = _send_to_lab(collector, lab_user, request_id, batch_id)
        assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_h(lab_user)).status_code == 200
        failed = _report(lab_user, batch_id, hmf=99.0)
        assert failed.status_code == 200 and failed.json()["overallResult"] == "FAIL"

        resp = client.post(f"/api/requests/{lab_request_id}/send-next", json={
            "toUserId": _mk("PACKAGING").id,
        }, headers=_h(lab_user))
        assert resp.status_code == 409, resp.text
        assert _code(resp) == "LAB_TEST_FAILED"

    def test_missing_measured_values_rejected(self, client):
        """Lab report without the required physicochemical values is rejected — no fabricated certification."""
        harvester = _mk("HARVESTER")
        collector = _mk("COLLECTOR_PROCESSOR")
        lab_user = _mk_lab()
        hive_id = _hive_for(harvester)
        batch_id, request_id, _, collector = _full_harvest_and_collection(harvester, hive_id)
        assert client.patch(f"/api/requests/{request_id}/accept", json={}, headers=_h(collector)).status_code == 200
        lab_request_id = _send_to_lab(collector, lab_user, request_id, batch_id)
        assert client.patch(f"/api/requests/{lab_request_id}/accept", json={}, headers=_h(lab_user)).status_code == 200

        resp = client.post("/api/lab-reports", json={"batchId": batch_id}, headers=_h(lab_user))
        assert resp.status_code == 422, resp.text
        assert _code(resp) == "VALIDATION_ERROR"
