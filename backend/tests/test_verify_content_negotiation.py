"""
Content-negotiation tests for the public verification endpoint.

GET /verify/{batch_id} is the target of consumer-facing QR codes, so a
browser must always receive an HTML verification page while API clients
must receive the JSON provenance payload. The /api/verify variant is
always JSON regardless of the Accept header.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.models import CollectionBatch, Hive, User


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app := __import__("backend.main", fromlist=["app"]).app)


@pytest.fixture(scope="module")
def db():
    init_db()
    session = SessionLocal()
    yield session
    session.close()


@pytest.fixture(scope="module")
def seeded_batch(db):
    """A batch with a full hive -> harvester -> telemetry lineage so the
    verifier response includes real joined data."""
    user = User(
        name="Verify Harvester",
        email=f"verify_{uuid.uuid4().hex[:8]}@example.test",
        role="HARVESTER",
        is_verified=True,
    )
    db.add(user)
    db.flush()
    hive = Hive(
        user_id=user.id,
        hive_code=f"HIVE-VERIFY-{uuid.uuid4().hex[:6]}",
        name="Verification Hive",
        apiary_location="Test Apiary",
    )
    db.add(hive)
    db.flush()
    batch = CollectionBatch(
        batch_id=f"HC-VERIFY-{uuid.uuid4().hex[:8].upper()}",
        hive_id=hive.id,
        harvester_id=user.id,
    )
    db.add(batch)
    db.commit()
    return batch.batch_id


HTML_HEADERS = {"Accept": "text/html,application/xhtml+xml"}
JSON_HEADERS = {"Accept": "application/json"}


class TestBrowserRequestsGetHtml:
    def test_browser_accept_header_receives_html_page(self, client, seeded_batch):
        """A consumer scanning a QR code opens /verify/{id} in a browser and
        must land on the verification page, never on raw JSON."""
        resp = client.get(f"/verify/{seeded_batch}", headers=HTML_HEADERS)

        assert resp.status_code == 200
        assert "text/html" in resp.headers["content-type"]
        body = resp.text
        # Either the built verifier SPA shell or the server-rendered page.
        assert "<html" in body.lower()
        assert "HoneyChain" in body

    def test_html_response_is_never_raw_json(self, client, seeded_batch):
        resp = client.get(f"/verify/{seeded_batch}", headers=HTML_HEADERS)
        assert "text/html" in resp.headers["content-type"]
        # A JSON provenance payload would parse as a dict/object document.
        assert not resp.text.lstrip().startswith("{")

    def test_missing_batch_with_html_accept_still_reaches_handler(
        self, client
    ):
        """/verify with no batch id must not 500 for browser clients."""
        resp = client.get("/verify/", headers=HTML_HEADERS)
        assert resp.status_code in (200, 400, 404)


class TestApiRequestsGetJson:
    def test_api_verify_path_returns_json_even_for_browsers(
        self, client, seeded_batch
    ):
        """/api/* is machine surface: the Accept header must not switch it
        to HTML (frontend fetches must always get parseable JSON)."""
        resp = client.get(f"/api/verify/{seeded_batch}", headers=HTML_HEADERS)

        assert resp.status_code == 200
        assert "application/json" in resp.headers["content-type"]
        data = resp.json()
        assert data["batchId"] == seeded_batch

    def test_json_accept_on_public_path_returns_json(self, client, seeded_batch):
        resp = client.get(f"/verify/{seeded_batch}", headers=JSON_HEADERS)

        assert resp.status_code == 200
        assert "application/json" in resp.headers["content-type"]
        data = resp.json()
        assert data["batchId"] == seeded_batch

    def test_json_payload_contains_provenance_sections(self, client, seeded_batch):
        resp = client.get(f"/api/verify/{seeded_batch}")
        data = resp.json()

        # Sections consumed by the web verifier and mobile app.
        assert data["success"] is True
        assert data["batchId"] == seeded_batch
        for section in (
            "iotTelemetry",
            "aiAnalysis",
            "blockchainVerification",
            "provenanceEvents",
        ):
            assert section in data
        # Honest empty state — no fabricated telemetry for a fresh batch.
        assert data["iotTelemetry"] is None


class TestUnknownBatch:
    def test_unknown_batch_json_reports_missing_data(self, client):
        resp = client.get("/api/verify/HC-DOES-NOT-EXIST-000")

        assert resp.status_code == 200
        data = resp.json()
        assert data["batchId"] == "HC-DOES-NOT-EXIST-000"
        # No fabricated provenance for an unknown batch: telemetry and AI
        # sections stay null instead of receiving made-up readings.
        assert data["iotTelemetry"] is None
        assert data["aiAnalysis"] is None

    def test_unknown_batch_html_still_renders_page(self, client):
        resp = client.get(
            "/verify/HC-DOES-NOT-EXIST-000", headers=HTML_HEADERS
        )

        assert resp.status_code == 200
        assert "text/html" in resp.headers["content-type"]
