"""
HoneyChain End-to-End Complete Integration Test.
Verifies:
1. AI/ML Isolation Forest inference & Risk Engine.
2. IoT Telemetry publishing & validation.
3. MQTT pipeline (telemetry -> processed -> DB storage).
4. Full Traceability Workflow: Harvester -> Collection -> Lab -> Packaging -> Blockchain -> QR Verification.
5. Public QR Verification API.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app
from backend.models import User, Hive, CollectionBatch, Lab, PackagingFacility
from backend.services.mqtt_consumer import mqtt_consumer
from ai_ml.src.feature_builder import FeatureBuilder
from ai_ml.src.anomaly_detector import AnomalyDetector
from ai_ml.src.risk_engine import RiskEngine
from ai_ml.src.output_formatter import build_app_json


def test_e2e_integration():
    print("=" * 70)
    print(" [*] HONEYCHAIN COMPLETE END-TO-END INTEGRATION TEST")
    print("=" * 70)

    # 1. Initialize Database
    init_db()
    client = TestClient(app)
    db = SessionLocal()

    # 2. Verify Health
    health_res = client.get("/api/health")
    assert health_res.status_code == 200, f"Health check failed: {health_res.text}"
    print("\n[OK] Backend Health Check: PASSED")

    # 3. Setup Test Harvester & Hive with Device ID
    harvester = db.query(User).filter(User.role == "HARVESTER").first()
    if not harvester:
        harvester = User(
            name="Ramesh Patil (Certified Beekeeper)",
            email="ramesh.patil@honeychain.io",
            phone="+919876543210",
            role="HARVESTER",
            beekeeper_id="HC-BK-97FD3395",
        )
        db.add(harvester)
        db.commit()
        db.refresh(harvester)

    device_id = "SIH_HIVE_MVP_01"
    hive = db.query(Hive).filter(Hive.device_id == device_id).first()
    if not hive:
        hive = Hive(
            user_id=harvester.id,
            device_id=device_id,
            hive_code="HIVE-MVP-01",
            name="Western Ghats Primary Hive 01",
            apiary_location="Mahabaleshwar Forest Reserve, Apiary Section 3",
            honey_type="Wild Forest Multi-Flora",
            bee_breed="Apis cerana indica",
            colony_strength="Strong",
        )
        db.add(hive)
        db.commit()
        db.refresh(hive)

    print(f"[OK] Harvester & Hive Setup: {hive.name} | Device: {hive.device_id} | Code: {hive.hive_code}")

    # 4. Test AI/ML Isolation Forest Pipeline with Telemetry
    print("\n[STEP 1] Testing AI/ML Inference Pipeline...")
    feature_builder = FeatureBuilder()
    current_t = int(time.time())
    # Pre-seed 145 historical readings (10-minute intervals = 24 hours of history)
    for i in range(145):
        t = current_t - (145 - i) * 600
        feature_builder.add_reading(
            device_id=device_id,
            timestamp=t,
            sensors={
                "temperature_c": 34.2,
                "humidity_pct": 61.5,
                "weight_kg": 3.25,
                "acoustics_hz": 245.0,
            },
        )
    features = feature_builder.build_latest_features(device_id)
    assert features is not None, "FeatureBuilder failed to generate features"

    model_path = Path("ai_ml/models/honeychain_isolation_forest.joblib")
    threshold_path = Path("ai_ml/models/threshold.json")
    detector = AnomalyDetector(model_path, threshold_path)
    ml_result = detector.predict(features)
    assert "anomaly_detected" in ml_result, "ML prediction failed"

    risk_engine = RiskEngine()
    sensors_dict = {"temperature_c": 34.2, "humidity_pct": 61.5, "weight_kg": 3.25, "acoustics_hz": 245.0}
    risk_result = risk_engine.analyze(sensors=sensors_dict, ml_result=ml_result, features=features)

    processed_payload = build_app_json(
        device_id=device_id,
        timestamp=int(time.time()),
        sensors=sensors_dict,
        diagnostics={"battery_v": 4.12, "wifi_rssi_dbm": -68},
        ml_result=ml_result,
        risk_result=risk_result,
    )
    print(f"[OK] AI/ML Pipeline: Risk Level={risk_result['risk_level']}, Status={risk_result['status']}, Anomaly={ml_result['anomaly_detected']}")

    # 5. Ingest Processed Payload via Backend MQTT Consumer Service
    print("\n[STEP 2] Testing Backend Ingestion of AI Processed Payload...")
    mqtt_consumer.process_processed_payload(processed_payload)

    # Verify Telemetry stored in DB
    telemetry_res = client.get(f"/api/telemetry/live/{hive.id}")
    assert telemetry_res.status_code == 200, "Failed to retrieve live telemetry"
    telemetry_data = telemetry_res.json().get("telemetry", [])
    assert len(telemetry_data) > 0, "No telemetry was saved in DB"
    print(f"[OK] Telemetry DB Persistence: {len(telemetry_data)} records found. Latest Temp={telemetry_data[0]['temperature']}°C")

    # 6. Test Harvester Collection Request
    print("\n[STEP 3] Harvester Submitting Collection Request...")
    from backend.main import create_access_token
    harvester_token = create_access_token({"sub": harvester.id, "email": harvester.email, "role": "HARVESTER"})
    harvester_headers = {"Authorization": f"Bearer {harvester_token}"}

    harvest_res = client.post("/api/harvests", json={
        "hiveId": hive.id,
        "quantity": 25.0,
        "location": hive.apiary_location,
        "notes": "Premium raw forest honey harvest.",
    }, headers=harvester_headers)
    assert harvest_res.status_code == 200, f"Harvest creation failed: {harvest_res.text}"
    batch_id = harvest_res.json()["batchId"]

    req_res = client.post("/api/requests", json={
        "batchId": batch_id,
        "harvesterId": harvester.id,
        "hiveId": hive.id,
        "quantity": 25.0,
        "location": hive.apiary_location,
        "notes": "Premium raw forest honey harvest.",
    }, headers=harvester_headers)
    assert req_res.status_code == 200, f"Collection request failed: {req_res.text}"
    req_data = req_res.json()
    request_id = req_data["requestId"]
    print(f"[OK] Collection Request Created: {request_id} | Batch: {batch_id}")

    # 7. Test Collection & Processing Step
    print("\n[STEP 4] Collection Centre Accepting & Cold Extraction Processing...")
    collector = db.query(User).filter(User.role == "COLLECTOR_PROCESSOR").first()
    if not collector:
        collector = User(
            name="Central Processing Hub",
            email="collector@honeychain.io",
            phone="+919823011223",
            role="COLLECTOR_PROCESSOR",
            organization_name="Sahyadri Honey Processing Hub",
            facility_location="Mahabaleshwar, MH",
            license_number="FSSAI-COL-2026",
            is_verified=True,
        )
        db.add(collector)
        db.commit()
        db.refresh(collector)

    collector_token = create_access_token({"sub": collector.id, "email": collector.email, "role": "COLLECTOR_PROCESSOR"})
    collector_headers = {"Authorization": f"Bearer {collector_token}"}

    accept_res = client.patch(f"/api/requests/{request_id}/accept", json={"notes": "Accepted for intake."}, headers=collector_headers)
    assert accept_res.status_code == 200, f"Collection accept failed: {accept_res.text}"

    proc_res = client.post("/api/processing", json={
        "batchId": batch_id,
        "processorId": collector.id,
        "quantityReceived": 25.0,
        "quantityAfter": 24.2,
        "method": "Centrifugal Cold Extraction (< 38°C)",
        "notes": "Optimal clarity and moisture retention.",
    }, headers=collector_headers)
    assert proc_res.status_code == 200, f"Processing failed: {proc_res.text}"
    print(f"[OK] Processing Completed & Provenance Recorded on Blockchain.")

    # 8. Test Lab Testing & Certification Step
    print("\n[STEP 5] Analytical Food Safety Testing & Quality Certification...")
    lab_user = db.query(User).filter(User.role == "LAB").first()
    if not lab_user:
        lab_user = User(
            name="Food Safety Testing Lab",
            email="lab@honeychain.io",
            phone="+912025691100",
            role="LAB",
            organization_name="National Apiculture Analytical Lab",
            facility_location="Pune Agri-Tech Park, MH",
            license_number="NABL-TC-8891",
            is_verified=True,
        )
        db.add(lab_user)
        db.commit()
        db.refresh(lab_user)

    lab_token = create_access_token({"sub": lab_user.id, "email": lab_user.email, "role": "LAB"})
    lab_headers = {"Authorization": f"Bearer {lab_token}"}
    if not db.query(Lab).filter((Lab.id == lab_user.id) | (Lab.user_id == lab_user.id)).first():
        db.add(Lab(
            id=lab_user.id,
            user_id=lab_user.id,
            lab_name=lab_user.organization_name or lab_user.name,
            facility_location=lab_user.facility_location or "Pune Agri-Tech Park, MH",
            is_active=True,
        ))
        db.commit()

    lab_req_res = client.post(f"/api/requests/{request_id}/send-next", json={
        "toUserId": lab_user.id,
        "quantityReceived": 25.0,
        "quantityAfter": 24.2,
        "method": "Centrifugal Cold Extraction (< 38Â°C)",
        "notes": "Processed sample ready for lab.",
    }, headers=collector_headers)
    assert lab_req_res.status_code == 200, f"Send to lab failed: {lab_req_res.text}"
    lab_request_id = lab_req_res.json()["labRequestId"]

    lab_accept_res = client.patch(f"/api/requests/{lab_request_id}/accept", json={"notes": "Accepted for testing."}, headers=lab_headers)
    assert lab_accept_res.status_code == 200, f"Lab accept failed: {lab_accept_res.text}"

    lab_res = client.post("/api/lab-reports", json={
        "batchId": batch_id,
        "labId": lab_user.id,
        "qualityScore": 99.1,
        "moistureContent": 16.5,
        "hmfValue": 12.0,
        "diastaseValue": 15.0,
        "contaminantsFound": "None",
        "purityGrade": "Grade A (99.5% Pure)",
        "remarks": "100% compliant with FSSAI & Codex Alimentarius Honey Standards.",
    }, headers=lab_headers)
    assert lab_res.status_code == 200, f"Lab report failed: {lab_res.text}"
    lab_data = lab_res.json()
    print(f"[OK] Lab Certified: Report ID {lab_data['reportId']} | Status: {lab_data['status']}")

    # 9. Test Packaging & Final QR Generation
    print("\n[STEP 6] Cleanroom Packaging & Final Tamper-Evident QR Generation...")
    pkg_user = db.query(User).filter(User.role == "PACKAGING").first()
    if not pkg_user:
        pkg_user = User(
            name="Sahyadri Pure Packaging Unit",
            email="packaging@honeychain.io",
            phone="+919823044556",
            role="PACKAGING",
            organization_name="Sahyadri Pure Honey Bottling",
            facility_location="Mahabaleshwar, MH",
            license_number="FSSAI-PKG-1152026",
            is_verified=True,
        )
        db.add(pkg_user)
        db.commit()
        db.refresh(pkg_user)

    pkg_token = create_access_token({"sub": pkg_user.id, "email": pkg_user.email, "role": "PACKAGING"})
    pkg_headers = {"Authorization": f"Bearer {pkg_token}"}
    if not db.query(PackagingFacility).filter(PackagingFacility.id == pkg_user.id).first():
        db.add(PackagingFacility(
            id=pkg_user.id,
            name=pkg_user.organization_name or pkg_user.name,
            location=pkg_user.facility_location or "Mahabaleshwar, MH",
            is_active=True,
        ))
        db.commit()

    send_pkg_res = client.post(f"/api/requests/{lab_request_id}/send-next", json={
        "toUserId": pkg_user.id,
        "notes": "Lab passed; ready for packaging.",
    }, headers=lab_headers)
    assert send_pkg_res.status_code == 200, f"Send to packaging failed: {send_pkg_res.text}"

    pkg_res = client.post("/api/packaging", json={
        "batchId": batch_id,
        "packagerId": pkg_user.id,
        "finalQuantity": 24.0,
        "numberOfPackages": 48,
        "packageSize": "500g Glass Jar",
    }, headers=pkg_headers)
    assert pkg_res.status_code == 200, f"Packaging failed: {pkg_res.text}"
    pkg_data = pkg_res.json()
    verification_url = pkg_data["verificationUrl"]
    assert "data:image/png;base64," in pkg_data["qrDataUri"], "Missing valid QR data URI"
    print(f"[OK] Packaging Sealed. Final Verification URL: {verification_url}")

    # 10. Test Public QR Verification API
    print("\n[STEP 7] Verifying Public Provenance & Batch Verification API...")
    verify_res = client.get(f"/api/verify/{batch_id}")
    assert verify_res.status_code == 200, f"Public verification failed: {verify_res.text}"
    vdata = verify_res.json()

    assert vdata["found"] is True, "Batch was not found by verification API"
    assert vdata["batchId"] == batch_id, "Batch ID mismatch in verification"
    assert vdata["isFullyVerified"] is True, "Batch was not marked fully verified"
    assert vdata["labVerification"]["status"] == "CERTIFIED APPROVED (PASS)", "Lab verification status mismatch"

    print("\n========================================")
    print(" [SUMMARY] PUBLIC VERIFICATION SUMMARY")
    print("=" * 70)
    print(f"Product           : {vdata['product']['productName']}")
    print(f"Batch Code        : {vdata['product']['batchCode']}")
    print(f"Harvester         : {vdata['harvester']['name']} ({vdata['harvester']['beekeeperId']})")
    print(f"Hive Source       : {vdata['harvester']['hiveCode']} @ {vdata['harvester']['apiaryLocation']}")
    print(f"Processing        : {vdata['collectionProcessing']['method']}")
    print(f"Lab Certification : {vdata['labVerification']['status']} (Quality Score: {vdata['labVerification']['qualityScore']}/100)")
    print(f"Blockchain Status : {vdata['blockchainVerification']['ledgerStatus']}")
    print(f"Events Tracked    : {vdata['blockchainVerification']['totalConfirmedEvents']}")
    print("=" * 70)
    print("\n[SUCCESS] ALL END-TO-END INTEGRATION TESTS PASSED SUCCESSFULLY!\n")


run_e2e_test = test_e2e_integration

if __name__ == "__main__":
    test_e2e_integration()
