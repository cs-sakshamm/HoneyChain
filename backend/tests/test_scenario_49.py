"""
HoneyChain Exact Scenario 49 Test:
User: Harvester
Hive: HIVE_TEST_001
Device: SIH_HIVE_TEST_001

Telemetry Input:
temperature = 34.2
humidity = 61.5
weight = 3.25
acoustics = 245

Flow:
MQTT receives telemetry -> AI processes telemetry -> Backend receives processed result ->
PostgreSQL stores result -> Flutter/REST displays result ->
Harvester -> Collection Request -> Collection Centre -> Processing ->
Lab -> Certified -> Packaging -> Blockchain -> QR -> Public Verification.
"""
from __future__ import annotations

import time
from pathlib import Path
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app
from backend.models import User, Hive, CollectionBatch, LabReport, PackagingBatch, BlockchainRecord
from backend.services.mqtt_consumer import mqtt_consumer
from ai_ml.src.feature_builder import FeatureBuilder
from ai_ml.src.anomaly_detector import AnomalyDetector
from ai_ml.src.risk_engine import RiskEngine
from ai_ml.src.output_formatter import build_app_json


def test_section_49_scenario():
    print("=" * 70)
    print(" [*] RUNNING SECTION 49 EXACT END-TO-END SCENARIO")
    print("=" * 70)

    init_db()
    client = TestClient(app)
    db = SessionLocal()

    # 1. Setup Exact Harvester, Hive & Device
    harvester = db.query(User).filter(User.email == "harvester_test@honeychain.io").first()
    if not harvester:
        harvester = User(
            name="Harvester",
            email="harvester_test@honeychain.io",
            phone="+919876543210",
            role="HARVESTER",
            beekeeper_id="HC-BK-SCENARIO-49",
            is_verified=True,
        )
        db.add(harvester)
        db.commit()
        db.refresh(harvester)
    else:
        harvester.phone = "+919876543210"
        harvester.is_verified = True
        db.commit()
        db.refresh(harvester)

    hive_code = "HIVE_TEST_001"
    device_id = "SIH_HIVE_TEST_001"

    hive = db.query(Hive).filter(Hive.hive_code == hive_code).first()
    if not hive:
        hive = Hive(
            user_id=harvester.id,
            hive_code=hive_code,
            device_id=device_id,
            name="Test Scenario Hive 001",
            apiary_location="Valley Apiary Section 01",
            honey_type="Wildflower",
        )
        db.add(hive)
        db.commit()
        db.refresh(hive)
    else:
        hive.device_id = device_id
        db.commit()

    print(f"[1] Verified Hive: {hive.hive_code} | Device: {hive.device_id} | User: {harvester.name}")

    # 2. ESP32 MQTT Telemetry
    raw_esp32_payload = {
        "device_id": device_id,
        "timestamp": int(time.time()),
        "sensors": {
            "weight_kg": 3.25,
            "temperature_c": 34.2,
            "humidity_pct": 61.5,
            "acoustics_hz": 245.0,
        },
        "diagnostics": {
            "battery_v": 4.12,
            "wifi_rssi_dbm": -68,
        },
    }
    print(f"[2] Raw ESP32 Payload Published: Temp={raw_esp32_payload['sensors']['temperature_c']}C, Humidity={raw_esp32_payload['sensors']['humidity_pct']}%, Weight={raw_esp32_payload['sensors']['weight_kg']}kg, Acoustics={raw_esp32_payload['sensors']['acoustics_hz']}Hz")

    # 3. AI/ML Processing
    fb = FeatureBuilder()
    current_t = raw_esp32_payload["timestamp"]
    for i in range(145):
        t = current_t - (145 - i) * 600
        fb.add_reading(
            device_id=device_id,
            timestamp=t,
            sensors=raw_esp32_payload["sensors"],
        )
    features = fb.build_latest_features(device_id)
    assert features is not None

    detector = AnomalyDetector(
        "ai_ml/models/honeychain_isolation_forest.joblib",
        "ai_ml/models/threshold.json",
    )
    ml_result = detector.predict(features)

    risk_engine = RiskEngine()
    risk_result = risk_engine.analyze(sensors=raw_esp32_payload["sensors"], ml_result=ml_result, features=features)

    processed_json = build_app_json(
        device_id=device_id,
        timestamp=raw_esp32_payload["timestamp"],
        sensors=raw_esp32_payload["sensors"],
        diagnostics=raw_esp32_payload["diagnostics"],
        ml_result=ml_result,
        risk_result=risk_result,
    )
    print(f"[3] AI/ML Processed: Status={processed_json['hive_status']['status']} | Risk={processed_json['hive_status']['risk_level']} | Anomaly={processed_json['hive_status']['anomaly_detected']}")

    # 4. Backend Ingestion & PostgreSQL Persistence
    mqtt_consumer.process_processed_payload(processed_json)

    # 5. Verify Telemetry Display for Harvester Mobile Screen
    telemetry_res = client.get(f"/api/telemetry/live/{hive.id}")
    assert telemetry_res.status_code == 200
    telemetries = telemetry_res.json().get("telemetry", [])
    assert len(telemetries) > 0
    latest_tel = telemetries[0]
    print(f"[4] Backend PostgreSQL Telemetry: Temp={latest_tel['temperature']}C, Hum={latest_tel['humidity']}%, Weight={latest_tel['weightKg']}kg")

    # 6. Harvester sends Collection Request
    from backend.main import create_access_token
    harvester_token = create_access_token({"sub": harvester.id, "email": harvester.email, "role": "HARVESTER"})
    harvester_headers = {"Authorization": f"Bearer {harvester_token}"}

    req_res = client.post("/api/requests", json={
        "harvesterId": harvester.id,
        "hiveId": hive.id,
        "quantity": 30.0,
        "location": hive.apiary_location,
        "notes": "Harvest from SIH_HIVE_TEST_001",
    }, headers=harvester_headers)
    assert req_res.status_code == 200
    req_data = req_res.json()
    batch_id = req_data["batchId"]
    request_id = req_data["requestId"]
    print(f"[5] Harvester Collection Request: {request_id} -> Batch: {batch_id}")

    # 7. Collection Centre receives & processes batch
    collector = db.query(User).filter(User.role == "COLLECTOR_PROCESSOR").first()
    if not collector:
        collector = User(
            name="Collection Center 01",
            email="collector_s49@honeychain.io",
            phone="+919876543201",
            role="COLLECTOR_PROCESSOR",
            organization_name="Valley Collection Center",
            facility_location="Valley Apiary Section 01",
            license_number="FSSAI-VALLEY-01",
            is_verified=True,
        )
        db.add(collector)
        db.commit()
        db.refresh(collector)

    collector_token = create_access_token({"sub": collector.id, "email": collector.email, "role": "COLLECTOR_PROCESSOR"})
    collector_headers = {"Authorization": f"Bearer {collector_token}"}

    proc_res = client.post("/api/processing", json={
        "batchId": batch_id,
        "processorId": collector.id,
        "quantityReceived": 30.0,
        "quantityAfter": 29.1,
        "method": "Cold Centrifugation Extraction",
    }, headers=collector_headers)
    assert proc_res.status_code == 200
    print(f"[6] Processing Batch: 29.1 kg cold-extracted honey produced")

    # 8. Lab Testing & Certification
    lab_user = db.query(User).filter(User.role == "LAB").first()
    if not lab_user:
        lab_user = User(
            name="Lab Certifier 01",
            email="lab_s49@honeychain.io",
            phone="+919876543202",
            role="LAB",
            organization_name="National Honey Testing Lab",
            facility_location="Pune Agri-Tech Park, MH",
            license_number="NABL-LAB-01",
            is_verified=True,
        )
        db.add(lab_user)
        db.commit()
        db.refresh(lab_user)

    lab_token = create_access_token({"sub": lab_user.id, "email": lab_user.email, "role": "LAB"})
    lab_headers = {"Authorization": f"Bearer {lab_token}"}

    lab_res = client.post("/api/lab-reports", json={
        "batchId": batch_id,
        "labId": lab_user.id,
        "qualityScore": 99.4,
        "moistureContent": 16.2,
        "hmfValue": 11.0,
        "diastaseValue": 16.0,
        "contaminantsFound": "None",
        "purityGrade": "Grade A+ (99.8% Pure)",
        "remarks": "Purity certified.",
    }, headers=lab_headers)
    assert lab_res.status_code == 200
    lab_data = lab_res.json()
    assert lab_data["status"] == "APPROVED"
    print(f"[7] Lab Certification: APPROVED (Report: {lab_data['reportId']}, Moisture: 16.2%)")

    # 9. Packaging & Final QR Generation
    pkg_user = db.query(User).filter(User.role == "PACKAGING").first()
    if not pkg_user:
        pkg_user = User(
            name="Packager 01",
            email="packager_s49@honeychain.io",
            phone="+919876543203",
            role="PACKAGING",
            organization_name="Cleanroom Bottling Facility",
            facility_location="Packaging Depot, MH",
            license_number="FSSAI-PKG-01",
            is_verified=True,
        )
        db.add(pkg_user)
        db.commit()
        db.refresh(pkg_user)

    pkg_token = create_access_token({"sub": pkg_user.id, "email": pkg_user.email, "role": "PACKAGING"})
    pkg_headers = {"Authorization": f"Bearer {pkg_token}"}

    pkg_res = client.post("/api/packaging", json={
        "batchId": batch_id,
        "packagerId": pkg_user.id,
        "finalQuantity": 29.0,
        "numberOfPackages": 58,
        "packageSize": "500g Glass Jar",
    }, headers=pkg_headers)
    assert pkg_res.status_code == 200
    pkg_data = pkg_res.json()
    verification_url = pkg_data["verificationUrl"]
    print(f"[8] Packaging Completed: 58 units sealed. QR Verification URL: {verification_url}")

    # 10. Public QR Verification
    verify_res = client.get(f"/api/verify/{batch_id}")
    assert verify_res.status_code == 200
    v = verify_res.json()
    assert v["found"] is True
    assert v["isFullyVerified"] is True
    assert v["product"]["batchCode"] == batch_id
    assert v["harvester"]["hiveCode"] == hive_code

    print(f"[9] Public Verification Verified:")
    print(f"    Product     : {v['product']['productName']}")
    print(f"    Batch       : {v['product']['batchCode']}")
    print(f"    Hive Source : {v['harvester']['hiveCode']}")
    print(f"    Lab Status  : {v['labVerification']['status']}")
    print(f"    Blockchain  : {v['blockchainVerification']['ledgerStatus']}")
    print("=" * 70)
    print(" [SUCCESS] SECTION 49 SCENARIO TEST COMPLETED AND VERIFIED 100%!")
    print("=" * 70)


run_section_49_scenario = test_section_49_scenario

if __name__ == "__main__":
    test_section_49_scenario()
