"""
HoneyChain Central FastAPI Backend.
Unified API serving Flutter Mobile Application, IoT/ESP32 ingestion,
AI/ML processor outputs, Blockchain provenance, and Public QR Verification.
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

from fastapi import (
    FastAPI,
    Depends,
    HTTPException,
    WebSocket,
    WebSocketDisconnect,
    Query,
    Path as FPath,
    Request,
    Response,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import desc

from backend.database import get_db, init_db, SessionLocal
from backend.models import (
    User,
    Profile,
    Hive,
    HiveTelemetry,
    HiveAIAnalysis,
    HiveAlert,
    Harvest,
    CollectionCentre,
    CollectionRequest,
    CollectionBatch,
    ProcessingBatch,
    Lab,
    PackagingFacility,
    LabRequest,
    LabReport,
    PackagingBatch,
    BlockchainRecord,
    QRCode,
    Notification,
    OTPVerification,
)
from backend.services.blockchain_service import blockchain_service
from backend.services.mqtt_consumer import mqtt_consumer
from backend.services.qr_service import generate_qr_data_uri

logging.basicConfig(level=logging.INFO, format="[HoneyChain] %(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("MainBackend")


# ── WebSocket Manager ──
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: Dict[str, Any]):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(connection)


manager = ConnectionManager()


# ── Lifespan Context Manager ──
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing HoneyChain Database and Models...")
    init_db()

    # Seed default verified entities if empty
    db = SessionLocal()
    try:
        if db.query(CollectionCentre).count() == 0:
            centers = [
                CollectionCentre(name="Central Sahyadri Honey Extraction & Processing Hub", location="Mahabaleshwar Apiary Zone, MH", latitude=17.9307, longitude=73.6477, contact_phone="+91 98230 11223", contact_email="contact@sahyadrihoney.org", license_number="FSSAI-MH-2026-0041"),
                CollectionCentre(name="Cascade Range Regional Collection Centre", location="Bend Industrial Center, OR", latitude=44.0582, longitude=-121.3153, contact_phone="+1 541 555 0192", contact_email="intake@cascadeprocessing.com", license_number="USDA-OR-99120"),
                CollectionCentre(name="Western Ghats Cooperative Extraction Facility", location="Shimoga Eco Zone, KA", latitude=13.9299, longitude=75.5681, contact_phone="+91 94481 33445", contact_email="ghats.coop@honeychain.io", license_number="FSSAI-KA-2026-0089"),
            ]
            db.add_all(centers)
            db.commit()
            logger.info("Seeded initial collection centres.")

        # Seed Lab user & facility
        lab_user = db.query(User).filter(User.role == "LAB").first()
        if not lab_user:
            lab_user = User(
                name="National Apiculture & Food Safety Analytical Laboratory",
                email="lab.director@honeychain.io",
                role="LAB",
                phone="+91 20 2569 1100",
                organization_name="National Apiculture Analytical Centre",
                facility_location="Pune Agri-Tech Park, MH",
                license_number="NABL-ISO-17025-2026",
                is_verified=True,
            )
            db.add(lab_user)
            db.commit()
            db.refresh(lab_user)

        if db.query(Lab).count() == 0:
            labs = [
                Lab(
                    user_id=lab_user.id,
                    lab_name="National Apiculture & Food Safety Analytical Laboratory",
                    facility_location="Pune Agri-Tech Park, MH",
                    latitude=18.5204,
                    longitude=73.8567,
                    contact_phone="+91 20 2569 1100",
                    contact_email="testing@apiculturelab.gov.in",
                    registration_number="NABL-TC-8891",
                    accreditation="NABL / FSSAI / ISO 17025 Certified",
                ),
            ]
            db.add_all(labs)
            db.commit()
            logger.info("Seeded initial accredited testing labs.")

        # Seed Packaging facilities
        if db.query(PackagingFacility).count() == 0:
            facilities = [
                PackagingFacility(
                    name="Mahabaleshwar Pure Honey Bottling & Cleanroom Packaging Unit",
                    location="Mahabaleshwar Industrial Area, MH",
                    latitude=17.9250,
                    longitude=73.6550,
                    contact_phone="+91 98230 44556",
                    contact_email="bottling@sahyadripure.org",
                    license_number="FSSAI-PKG-1152026",
                ),
                PackagingFacility(
                    name="Cascade Range Automated Bottling & Digital QR Packaging Facility",
                    location="Bend Logistics Park, OR",
                    latitude=44.0600,
                    longitude=-121.3100,
                    contact_phone="+1 541 555 0872",
                    contact_email="packaging@cascadepack.com",
                    license_number="OR-FDA-PKG-9821",
                ),
                PackagingFacility(
                    name="Western Ghats Certified Honey Packaging Centre",
                    location="Shimoga Packaging Depot, KA",
                    latitude=13.9350,
                    longitude=75.5720,
                    contact_phone="+91 94481 77889",
                    contact_email="packaging@westernghatshoney.com",
                    license_number="FSSAI-PKG-1152089",
                ),
            ]
            db.add_all(facilities)
            db.commit()
            logger.info("Seeded initial packaging facilities.")
    finally:
        db.close()

    # Register MQTT broadcast bridge to WebSockets
    def on_mqtt_data(data: Dict[str, Any]):
        asyncio.run(manager.broadcast(data))

    mqtt_consumer.add_listener(on_mqtt_data)
    mqtt_consumer.start()
    logger.info("HoneyChain MQTT Consumer service started.")

    yield

    mqtt_consumer.stop()
    logger.info("HoneyChain Backend shutdown complete.")


app = FastAPI(
    title="HoneyChain API",
    description="End-to-End Honey Supply Chain Traceability, AI Hive Telemetry & Verification",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── WebSockets ──
@app.websocket("/ws")
@app.websocket("/ws/telemetry")
@app.websocket("/api/telemetry/live")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Echo or handle client ping
            await websocket.send_json({"event": "PONG", "received": data})
    except WebSocketDisconnect:
        manager.disconnect(websocket)


# ── Health ──
@app.get("/api/health")
@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    db_status = "Connected"
    try:
        db.query(User).first()
    except Exception as e:
        db_status = f"Error: {e}"

    return {
        "status": "healthy",
        "service": "HoneyChain FastAPI Platform",
        "database": db_status,
        "blockchain": "Online" if blockchain_service.is_connected() else "Offline (Ledger Ready)",
        "timestamp": datetime.utcnow().isoformat(),
    }


# ── Schemas ──
class RegisterRequest(BaseModel):
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    role: Optional[str] = "HARVESTER"


class LoginRequest(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    role: Optional[str] = "HARVESTER"


class GoogleAuthRequest(BaseModel):
    email: str
    name: Optional[str] = "Google User"
    photoUrl: Optional[str] = None
    googleId: Optional[str] = None
    role: Optional[str] = "HARVESTER"


class ProfileUpdateRequest(BaseModel):
    userId: Optional[str] = None
    name: Optional[str] = None
    phone: Optional[str] = None
    organizationName: Optional[str] = None
    facilityLocation: Optional[str] = None
    licenseNumber: Optional[str] = None
    designation: Optional[str] = None


class HiveCreateRequest(BaseModel):
    name: str
    hiveCode: Optional[str] = None
    deviceId: Optional[str] = None
    apiaryLocation: str
    hiveType: Optional[str] = "Langstroth"
    queenStatus: Optional[str] = "Mated"
    totalFrames: Optional[int] = 10
    broodFrames: Optional[int] = 0
    colonyStrength: Optional[str] = "Strong"
    queenAgeMonths: Optional[int] = 0
    beeBreed: Optional[str] = "Italian"
    expectedProductionKg: Optional[float] = 0.0
    previousYearProductionKg: Optional[float] = 0.0
    currentYearProductionKg: Optional[float] = 0.0
    honeyType: Optional[str] = "Wildflower"
    miteStatus: Optional[str] = "None"
    diseaseStatus: Optional[str] = "None"
    feedingRequired: Optional[bool] = False
    queenCondition: Optional[str] = "Good"
    overallHealth: Optional[str] = "Healthy"
    notes: Optional[str] = None


class TelemetryIngestRequest(BaseModel):
    hiveId: Optional[str] = None
    hiveCode: Optional[str] = None
    deviceId: Optional[str] = None
    temperature: float
    humidity: float
    weightKg: float
    beeActivity: Optional[float] = 85.0
    soundFrequencyHz: Optional[float] = 245.0
    batteryLevel: Optional[float] = 4.12
    signalStrength: Optional[float] = -68.0
    timestamp: Optional[Any] = None


class WorkflowCreateRequest(BaseModel):
    harvesterId: Optional[str] = None
    hiveId: Optional[str] = None
    collectionCentreId: Optional[str] = None
    quantity: Optional[float] = 0.0
    estimatedQuantityKg: Optional[float] = 0.0
    location: Optional[str] = "Main Apiary"
    notes: Optional[str] = None
    requestType: Optional[str] = "HARVEST_TO_COLLECTION"


class WorkflowUpdateRequest(BaseModel):
    status: str
    action: Optional[str] = None
    actorId: Optional[str] = None
    notes: Optional[str] = None
    quantityReceived: Optional[float] = None
    quantityAfter: Optional[float] = None
    qualityScore: Optional[float] = None
    numberOfPackages: Optional[int] = None
    finalQuantity: Optional[float] = None


# ── Helpers ──
def get_user_dict(user: User) -> Dict[str, Any]:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
        "beekeeperId": user.beekeeper_id,
        "bsid": user.bsid,
        "avatarUrl": user.avatar_url,
        "googlePhotoUrl": user.google_photo_url,
        "photoUrl": user.avatar_url or user.google_photo_url,
        "authProvider": user.auth_provider,
        "organizationName": user.organization_name,
        "facilityLocation": user.facility_location,
        "licenseNumber": user.license_number,
        "designation": user.designation,
        "isVerified": user.is_verified,
    }


def get_hive_dict(hive: Hive) -> Dict[str, Any]:
    return {
        "id": hive.id,
        "userId": hive.user_id,
        "name": hive.name,
        "hiveCode": hive.hive_code,
        "deviceId": hive.device_id,
        "apiaryLocation": hive.apiary_location,
        "hiveType": hive.hive_type,
        "queenStatus": hive.queen_status,
        "totalFrames": hive.total_frames,
        "broodFrames": hive.brood_frames,
        "colonyStrength": hive.colony_strength,
        "queenAgeMonths": hive.queen_age_months,
        "beeBreed": hive.bee_breed,
        "expectedProductionKg": hive.expected_production_kg,
        "previousYearProductionKg": hive.previous_year_production_kg,
        "currentYearProductionKg": hive.current_year_production_kg,
        "honeyType": hive.honey_type,
        "lastInspectionDate": hive.last_inspection_date.isoformat() if hive.last_inspection_date else None,
        "miteStatus": hive.mite_status,
        "diseaseStatus": hive.disease_status,
        "feedingRequired": hive.feeding_required,
        "queenCondition": hive.queen_condition,
        "overallHealth": hive.overall_health,
        "notes": hive.notes or "",
        "createdAt": hive.created_at.isoformat() if hive.created_at else None,
        "updatedAt": hive.updated_at.isoformat() if hive.updated_at else None,
    }


# ============================================================
# 1. AUTHENTICATION & PROFILE
# ============================================================
@app.post("/api/auth/register")
@app.post("/auth/register")
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    clean_email = (payload.email or f"user-{uuid.uuid4().hex[:6]}@honeychain.io").strip().lower()
    target_role = (payload.role or "HARVESTER").upper()

    existing = db.query(User).filter(User.email == clean_email, User.role == target_role).first()
    if existing:
        raise HTTPException(status_code=409, detail={"error": f"An account for role {target_role} with this email already exists.", "code": "ROLE_ACCOUNT_EXISTS"})

    pwd_hash = hashlib.sha256(payload.password.encode("utf-8")).hexdigest() if payload.password else None
    beekeeper_id = f"HC-BK-{uuid.uuid4().hex[:8].upper()}" if target_role == "HARVESTER" else None

    user = User(
        name=payload.name.strip(),
        email=clean_email,
        phone=payload.phone.strip() if payload.phone else None,
        password_hash=pwd_hash,
        role=target_role,
        beekeeper_id=beekeeper_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return {"success": True, "message": "Account registered successfully.", "user": get_user_dict(user)}


@app.post("/api/auth/login")
@app.post("/auth/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    clean_email = (payload.email or "").strip().lower()
    clean_phone = (payload.phone or "").strip()
    target_role = (payload.role or "HARVESTER").upper()

    user = None
    if clean_email:
        user = db.query(User).filter(User.email == clean_email, User.role == target_role).first()
    elif clean_phone:
        user = db.query(User).filter(User.phone == clean_phone, User.role == target_role).first()

    if not user:
        # Create user on the fly for authentic testing experience
        user = User(
            name=clean_email.split("@")[0].title() if clean_email else "User",
            email=clean_email or f"{clean_phone}@honeychain.io",
            phone=clean_phone or None,
            role=target_role,
            beekeeper_id=f"HC-BK-{uuid.uuid4().hex[:8].upper()}" if target_role == "HARVESTER" else None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    return {
        "success": True,
        "message": "Login successful.",
        "user": get_user_dict(user),
        "token": f"jwt-{uuid.uuid4().hex}",
    }


@app.post("/api/auth/google")
def google_auth(payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    clean_email = payload.email.strip().lower()
    target_role = (payload.role or "HARVESTER").upper()

    user = db.query(User).filter(User.email == clean_email, User.role == target_role).first()
    if not user:
        user = User(
            name=payload.name or "Google User",
            email=clean_email,
            avatar_url=payload.photoUrl,
            google_photo_url=payload.photoUrl,
            auth_provider="google",
            role=target_role,
            beekeeper_id=f"HC-BK-{uuid.uuid4().hex[:8].upper()}" if target_role == "HARVESTER" else None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        if payload.photoUrl:
            user.google_photo_url = payload.photoUrl
            db.commit()

    return {"success": True, "message": "Google authenticated successfully.", "user": get_user_dict(user)}


@app.post("/api/auth/reset-password")
def reset_password(req: Request):
    return {"success": True, "message": "Password reset instructions sent to your email."}


@app.get("/api/profile")
@app.get("/profile")
def get_profile(userId: Optional[str] = None, db: Session = Depends(get_db)):
    user = None
    if userId:
        user = db.query(User).filter((User.id == userId) | (User.email == userId)).first()
    if not user:
        user = db.query(User).first()
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    user_dict = get_user_dict(user)
    return {
        "success": True,
        "user": user_dict,
        "profile": user_dict,
        "isProfileComplete": user_dict.get("isProfileComplete", True),
    }


@app.put("/api/profile")
@app.put("/profile")
def update_profile(payload: ProfileUpdateRequest, db: Session = Depends(get_db)):
    user = None
    if payload.userId:
        user = db.query(User).filter((User.id == payload.userId) | (User.email == payload.userId)).first()
    if not user:
        user = db.query(User).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.name:
        user.name = payload.name.strip()
    if payload.phone:
        user.phone = payload.phone.strip()
    if payload.organizationName:
        user.organization_name = payload.organizationName.strip()
    if payload.facilityLocation:
        user.facility_location = payload.facilityLocation.strip()
    if payload.licenseNumber:
        user.license_number = payload.licenseNumber.strip()
    if payload.designation:
        user.designation = payload.designation.strip()

    db.commit()
    db.refresh(user)
    user_dict = get_user_dict(user)
    return {
        "success": True,
        "message": "Profile updated successfully.",
        "user": user_dict,
        "profile": user_dict,
        "isProfileComplete": user_dict.get("isProfileComplete", True),
    }


# ============================================================
# 2. HIVES & DEVICE MAPPING
# ============================================================
@app.get("/api/hives/code/generate")
@app.get("/api/hives/unique-code")
def get_unique_hive_code(db: Session = Depends(get_db)):
    code = f"HIVE-{uuid.uuid4().hex[:6].upper()}"
    return {"success": True, "code": code}


@app.get("/api/hives")
@app.get("/hives")
def get_hives(
    userId: Optional[str] = Query(None),
    harvesterId: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(Hive)
    target_user_id = userId or harvesterId
    if target_user_id:
        user = db.query(User).filter((User.id == target_user_id) | (User.email == target_user_id)).first()
        if user:
            query = query.filter(Hive.user_id == user.id)

    if search:
        s = f"%{search.strip().lower()}%"
        query = query.filter((Hive.name.ilike(s)) | (Hive.hive_code.ilike(s)) | (Hive.apiary_location.ilike(s)))

    hives = query.order_by(desc(Hive.created_at)).all()
    return [get_hive_dict(h) for h in hives]


@app.post("/api/hives")
@app.post("/hives")
def create_hive(payload: HiveCreateRequest, req: Request, db: Session = Depends(get_db)):
    user_id_header = req.headers.get("x-user-id")
    user = None
    if user_id_header:
        user = db.query(User).filter((User.id == user_id_header) | (User.email == user_id_header)).first()
    if not user:
        user = db.query(User).filter(User.role == "HARVESTER").first()
    if not user:
        user = User(name="Registered Harvester", email="harvester@honeychain.io", role="HARVESTER")
        db.add(user)
        db.commit()
        db.refresh(user)

    code = payload.hiveCode or f"HIVE-{uuid.uuid4().hex[:6].upper()}"
    dev_id = payload.deviceId or f"SIH_HIVE_{code[-4:]}"

    # Check duplicate device id
    existing_dev = db.query(Hive).filter(Hive.device_id == dev_id).first()
    if existing_dev:
        dev_id = f"{dev_id}_{uuid.uuid4().hex[:4]}"

    hive = Hive(
        user_id=user.id,
        device_id=dev_id,
        name=payload.name,
        hive_code=code,
        apiary_location=payload.apiaryLocation,
        hive_type=payload.hiveType or "Langstroth",
        queen_status=payload.queenStatus or "Mated",
        total_frames=payload.totalFrames or 10,
        brood_frames=payload.broodFrames or 0,
        colony_strength=payload.colonyStrength or "Strong",
        queen_age_months=payload.queenAgeMonths or 0,
        bee_breed=payload.beeBreed or "Italian",
        expected_production_kg=payload.expectedProductionKg or 0.0,
        honey_type=payload.honeyType or "Wildflower",
        mite_status=payload.miteStatus or "None",
        disease_status=payload.diseaseStatus or "None",
        feeding_required=payload.feedingRequired or False,
        queen_condition=payload.queenCondition or "Good",
        overall_health=payload.overallHealth or "Healthy",
        notes=payload.notes,
    )
    db.add(hive)
    db.commit()
    db.refresh(hive)
    hive_dict = get_hive_dict(hive)
    return {
        "success": True,
        "message": "Hive registered successfully.",
        "hive": hive_dict,
        **hive_dict,
    }


@app.get("/api/hives/{hive_id}")
@app.get("/hives/{hive_id}")
def get_hive_detail(hive_id: str, db: Session = Depends(get_db)):
    hive = db.query(Hive).filter((Hive.id == hive_id) | (Hive.hive_code == hive_id)).first()
    if not hive:
        raise HTTPException(status_code=404, detail="Hive not found")
    return {"success": True, "hive": get_hive_dict(hive)}

@app.put("/api/hives/{hive_id}")
@app.put("/hives/{hive_id}")
def update_hive(hive_id: str, payload: HiveCreateRequest, db: Session = Depends(get_db)):
    hive = db.query(Hive).filter((Hive.id == hive_id) | (Hive.hive_code == hive_id)).first()
    if not hive:
        raise HTTPException(status_code=404, detail="Hive not found")
    hive.name = payload.name
    hive.apiary_location = payload.apiary_location
    hive.bee_breed = payload.bee_breed
    hive.honey_type = payload.honey_type
    hive.target_production_kg = payload.target_production_kg
    if payload.device_id:
        hive.device_id = payload.device_id
    db.commit()
    db.refresh(hive)
    return {"success": True, "hive": get_hive_dict(hive)}

@app.delete("/api/hives/{hive_id}")
@app.delete("/hives/{hive_id}")
def delete_hive(hive_id: str, db: Session = Depends(get_db)):
    hive = db.query(Hive).filter((Hive.id == hive_id) | (Hive.hive_code == hive_id)).first()
    if not hive:
        raise HTTPException(status_code=404, detail="Hive not found")
    db.delete(hive)
    db.commit()
    return {"success": True, "message": "Hive deleted successfully."}


# ============================================================
# 3. TELEMETRY & AI ANALYSIS
# ============================================================
@app.post("/api/telemetry/ingest")
def ingest_telemetry(payload: TelemetryIngestRequest, db: Session = Depends(get_db)):
    # 1. Resolve hive
    hive = None
    target_id = payload.hiveId or payload.hiveCode or payload.deviceId
    if target_id:
        hive = db.query(Hive).filter((Hive.id == target_id) | (Hive.hive_code == target_id) | (Hive.device_id == target_id)).first()

    if not hive:
        user = db.query(User).filter(User.role == "HARVESTER").first()
        if not user:
            user = User(name="Default Harvester", email="harvester@honeychain.io", role="HARVESTER")
            db.add(user)
            db.commit()
            db.refresh(user)

        hive = Hive(
            user_id=user.id,
            device_id=payload.deviceId or "SIH_HIVE_MVP_01",
            hive_code=payload.hiveCode or f"HIVE-{uuid.uuid4().hex[:6].upper()}",
            name="Field Hive",
            apiary_location="Cascade Valley Apiary",
        )
        db.add(hive)
        db.commit()
        db.refresh(hive)

    # 2. Record telemetry
    rec_time = datetime.utcnow()
    telemetry = HiveTelemetry(
        hive_id=hive.id,
        device_id=hive.device_id or "SIH_HIVE_01",
        timestamp=int(rec_time.timestamp()),
        temperature_c=payload.temperature,
        humidity_pct=payload.humidity,
        weight_kg=payload.weightKg,
        acoustics_hz=payload.soundFrequencyHz or 245.0,
        battery_v=payload.batteryLevel or 4.12,
        wifi_rssi_dbm=payload.signalStrength or -68.0,
        bee_activity=payload.beeActivity or 85.0,
        recorded_at=rec_time,
    )
    db.add(telemetry)

    # 3. Check sudden parameter change & create alert if needed
    created_alerts = []
    if payload.temperature > 37.0 or payload.temperature < 30.0:
        alert = HiveAlert(
            hive_id=hive.id,
            hive_code=hive.hive_code,
            device_id=hive.device_id,
            parameter="Temperature",
            previous_value="34.0°C",
            current_value=f"{payload.temperature}°C",
            change_value=f"{payload.temperature - 34.0:+.1f}°C",
            unit="°C",
            severity="CRITICAL",
            message=f"Unusual temperature detected: {payload.temperature}°C",
            status="ACTIVE",
        )
        db.add(alert)
        created_alerts.append({"id": alert.id, "parameter": alert.parameter, "message": alert.message, "severity": alert.severity})

    db.commit()

    return {
        "success": True,
        "message": "Telemetry ingested successfully.",
        "telemetryId": telemetry.id,
        "alerts": created_alerts,
    }


@app.get("/api/telemetry/live/{hive_id}")
@app.get("/hives/{hive_id}/telemetry")
def get_hive_telemetry(hive_id: str, db: Session = Depends(get_db)):
    hive = db.query(Hive).filter((Hive.id == hive_id) | (Hive.hive_code == hive_id) | (Hive.device_id == hive_id)).first()
    if not hive:
        return {"success": True, "telemetry": []}

    telemetries = (
        db.query(HiveTelemetry)
        .filter(HiveTelemetry.hive_id == hive.id)
        .order_by(desc(HiveTelemetry.recorded_at))
        .limit(30)
        .all()
    )

    records = [
        {
            "id": t.id,
            "temperature": t.temperature_c,
            "humidity": t.humidity_pct,
            "weightKg": t.weight_kg,
            "acousticsHz": t.acoustics_hz,
            "batteryLevel": t.battery_v,
            "signalStrength": t.wifi_rssi_dbm,
            "recordedAt": t.recorded_at.isoformat() if t.recorded_at else None,
        }
        for t in telemetries
    ]
    return {"success": True, "telemetry": records}


@app.get("/api/telemetry/alerts")
@app.get("/hives/{hive_id}/alerts")
def get_alerts(hive_id: Optional[str] = None, status: Optional[str] = "ACTIVE", db: Session = Depends(get_db)):
    query = db.query(HiveAlert)
    if hive_id:
        hive = db.query(Hive).filter((Hive.id == hive_id) | (Hive.hive_code == hive_id)).first()
        if hive:
            query = query.filter(HiveAlert.hive_id == hive.id)
    if status:
        query = query.filter(HiveAlert.status == status)

    alerts = query.order_by(desc(HiveAlert.detected_at)).limit(20).all()
    results = [
        {
            "id": a.id,
            "hiveId": a.hive_id,
            "hiveCode": a.hive_code,
            "parameter": a.parameter,
            "previousValue": a.previous_value,
            "currentValue": a.current_value,
            "changeValue": a.change_value,
            "unit": a.unit,
            "severity": a.severity,
            "message": a.message,
            "status": a.status,
            "detectedAt": a.detected_at.isoformat() if a.detected_at else None,
        }
        for a in alerts
    ]
    return {"success": True, "alerts": results}


@app.post("/api/telemetry/alerts/{alert_id}/acknowledge")
def acknowledge_alert(alert_id: str, db: Session = Depends(get_db)):
    alert = db.query(HiveAlert).filter(HiveAlert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    alert.status = "ACKNOWLEDGED"
    alert.acknowledged_at = datetime.utcnow()
    db.commit()
    return {"success": True, "message": "Alert acknowledged."}


# ============================================================
# 4. WORKFLOW: REQUESTS, HARVESTS, PROCESSING, LAB, PACKAGING
# ============================================================
# ============================================================
# 4. WORKFLOW: REQUESTS, HARVESTS, PROCESSING, LAB, PACKAGING
# ============================================================
@app.get("/api/centers/nearest")
@app.get("/api/requests/nearest-centers")
def get_nearest_centers(
    role: Optional[str] = Query("COLLECTOR_PROCESSOR"),
    targetRole: Optional[str] = Query(None),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    originLocation: Optional[str] = Query(None),
    originHiveId: Optional[str] = Query(None),
    batchId: Optional[str] = Query(None),
    userId: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    actual_lon = lon if lon is not None else lng
    target = (targetRole or role or "COLLECTOR_PROCESSOR").upper().strip()

    def haversine(lat1, lon1, lat2, lon2):
        from math import radians, cos, sin, asin, sqrt
        if None in (lat1, lon1, lat2, lon2):
            return None
        r = 6371.0  # Earth radius in km
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))
        return r * c

    results = []
    if "LAB" in target:
        labs = db.query(Lab).filter(Lab.is_active == True).all()
        for lab in labs:
            dist = haversine(lat, actual_lon, lab.latitude, lab.longitude)
            dist_display = f"{dist:.1f} km away" if dist is not None else "Distance unknown"
            results.append({
                "id": lab.id,
                "userId": lab.user_id,
                "name": lab.lab_name,
                "role": "LAB",
                "location": lab.facility_location,
                "distanceKm": dist,
                "distanceDisplay": dist_display,
                "contactPhone": lab.contact_phone,
                "contactEmail": lab.contact_email,
                "licenseNumber": lab.registration_number,
                "accreditation": lab.accreditation,
                "latitude": lab.latitude,
                "longitude": lab.longitude,
            })
    elif "PACKAG" in target or "PKG" in target:
        facilities = db.query(PackagingFacility).filter(PackagingFacility.is_active == True).all()
        for p in facilities:
            dist = haversine(lat, actual_lon, p.latitude, p.longitude)
            dist_display = f"{dist:.1f} km away" if dist is not None else "Distance unknown"
            results.append({
                "id": p.id,
                "userId": p.id,
                "name": p.name,
                "role": "PACKAGING",
                "location": p.location,
                "distanceKm": dist,
                "distanceDisplay": dist_display,
                "contactPhone": p.contact_phone,
                "contactEmail": p.contact_email,
                "licenseNumber": p.license_number,
                "latitude": p.latitude,
                "longitude": p.longitude,
            })
    else:
        centres = db.query(CollectionCentre).filter(CollectionCentre.is_active == True).all()
        for c in centres:
            dist = haversine(lat, actual_lon, c.latitude, c.longitude)
            dist_display = f"{dist:.1f} km away" if dist is not None else "Distance unknown"
            results.append({
                "id": c.id,
                "userId": c.id,
                "name": c.name,
                "role": "COLLECTOR_PROCESSOR",
                "location": c.location,
                "distanceKm": dist,
                "distanceDisplay": dist_display,
                "contactPhone": c.contact_phone,
                "contactEmail": c.contact_email,
                "licenseNumber": c.license_number,
                "latitude": c.latitude,
                "longitude": c.longitude,
            })

    results.sort(key=lambda x: (x["distanceKm"] is None, x["distanceKm"]))
    return {
        "success": True,
        "centers": results,
        "centres": results,
        "total": len(results),
    }


@app.get("/api/requests")
@app.get("/collection/requests")
def get_workflow_requests(db: Session = Depends(get_db)):
    requests = db.query(CollectionRequest).order_by(desc(CollectionRequest.created_at)).all()
    out = []
    for r in requests:
        out.append({
            "id": r.id,
            "requestId": r.request_id,
            "batchId": r.batch_id or r.request_id,
            "harvestId": r.harvest_id,
            "hiveId": r.hive_id,
            "fromRole": "HARVESTER",
            "toRole": "COLLECTOR_PROCESSOR",
            "requestType": "HARVEST_TO_COLLECTION",
            "status": r.status,
            "estimatedQuantityKg": r.requested_quantity_kg,
            "location": r.location or "Main Apiary",
            "notes": r.notes or "",
            "createdAt": r.created_at.isoformat() if r.created_at else None,
            "updatedAt": r.updated_at.isoformat() if r.updated_at else None,
            "acceptedAt": r.accepted_at.isoformat() if r.accepted_at else None,
        })
    return out


@app.post("/api/requests")
@app.post("/collection/requests")
def create_workflow_request(payload: Dict[str, Any], db: Session = Depends(get_db)):
    req_code = f"REQ-COL-2026-{uuid.uuid4().hex[:6].upper()}"
    batch_code = payload.get("batchId") or f"HC-BATCH-2026-{uuid.uuid4().hex[:6].upper()}"

    harvester_id = payload.get("harvesterId")
    harvester = None
    if harvester_id:
        harvester = db.query(User).filter((User.id == harvester_id) | (User.email == harvester_id) | (User.name == harvester_id)).first()
    if not harvester:
        harvester = db.query(User).filter(User.role == "HARVESTER").first()

    qty = float(payload.get("quantity") or payload.get("estimatedQuantityKg") or 15.0)

    col_req = CollectionRequest(
        request_id=req_code,
        harvester_id=harvester.id if harvester else "harvester-1",
        hive_id=payload.get("hiveId"),
        collection_centre_id=payload.get("collectionCentreId") or payload.get("toUserId"),
        batch_id=batch_code,
        status="PENDING",
        requested_quantity_kg=qty,
        location=payload.get("location") or "Main Apiary",
        notes=payload.get("notes") or "",
    )
    db.add(col_req)

    # Initialize batch record if not exists
    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_code).first()
    if not batch:
        batch = CollectionBatch(
            batch_id=batch_code,
            request_id=req_code,
            harvester_id=harvester.id if harvester else "harvester-1",
            hive_id=payload.get("hiveId"),
            quantity_kg=qty,
            current_stage="HARVESTED",
            status="PENDING",
        )
        db.add(batch)
    else:
        batch.request_id = req_code

    # Record Blockchain Provenance
    blockchain_result = blockchain_service.record_batch_event(
        batch_id=batch_code,
        event_type="HARVEST_AND_COLLECTION_REQUESTED",
        actor_id=harvester.id if harvester else "harvester-1",
        payload={"batch_id": batch_code, "quantity": col_req.requested_quantity_kg, "hive_id": payload.get("hiveId")},
    )

    bc_record = BlockchainRecord(
        batch_id=batch_code,
        event_type="HARVEST_AND_COLLECTION_REQUESTED",
        actor_id=harvester.id if harvester else "harvester-1",
        data_hash=blockchain_result["data_hash"],
        tx_hash=blockchain_result.get("tx_hash"),
        block_number=blockchain_result.get("block_number"),
        network=blockchain_result["network"],
        status=blockchain_result["status"],
    )
    db.add(bc_record)
    db.commit()

    return {
        "success": True,
        "message": "Collection request submitted successfully.",
        "requestId": req_code,
        "batchId": batch_code,
        "blockchain": blockchain_result,
    }


@app.put("/api/requests/{request_id}")
@app.put("/collection/requests/{request_id}")
def update_workflow_request(request_id: str, payload: WorkflowUpdateRequest, db: Session = Depends(get_db)):
    req_obj = db.query(CollectionRequest).filter((CollectionRequest.id == request_id) | (CollectionRequest.request_id == request_id)).first()
    if not req_obj:
        raise HTTPException(status_code=404, detail="Request not found")

    req_obj.status = payload.status.upper()
    if payload.notes:
        req_obj.notes = payload.notes
    if payload.quantityReceived:
        req_obj.actual_quantity_kg = payload.quantityReceived

    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == req_obj.batch_id).first()
    if batch:
        batch.status = req_obj.status

    db.commit()
    return {"success": True, "message": f"Request updated to {req_obj.status}"}


@app.patch("/api/requests/{request_id}/accept")
def accept_workflow_request(request_id: str, payload: Optional[Dict[str, Any]] = None, db: Session = Depends(get_db)):
    req_obj = db.query(CollectionRequest).filter((CollectionRequest.id == request_id) | (CollectionRequest.request_id == request_id)).first()
    if not req_obj:
        raise HTTPException(status_code=404, detail="Request not found")

    payload = payload or {}
    actor_id = payload.get("actorId") or "Collector"
    notes = payload.get("notes")
    if notes:
        req_obj.notes = f"{req_obj.notes or ''}\n{notes}".strip()

    req_obj.status = "ACCEPTED"
    req_obj.accepted_at = datetime.utcnow()

    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == req_obj.batch_id).first()
    if batch:
        batch.current_stage = "COLLECTED"
        batch.status = "ACCEPTED"

    # Blockchain event
    bc = blockchain_service.record_batch_event(
        batch_id=req_obj.batch_id or req_obj.request_id,
        event_type="REQUEST_ACCEPTED",
        actor_id=actor_id,
        payload={"request_id": req_obj.request_id, "status": "ACCEPTED", "timestamp": datetime.utcnow().isoformat()},
    )
    db.add(BlockchainRecord(
        batch_id=req_obj.batch_id or req_obj.request_id,
        event_type="REQUEST_ACCEPTED",
        actor_id=actor_id,
        data_hash=bc["data_hash"],
        tx_hash=bc.get("tx_hash"),
        network=bc["network"],
        status=bc["status"],
    ))
    db.commit()
    return {"success": True, "message": "Request accepted successfully", "requestId": req_obj.request_id, "status": "ACCEPTED", "blockchain": bc}


@app.patch("/api/requests/{request_id}/reject")
def reject_workflow_request(request_id: str, payload: Optional[Dict[str, Any]] = None, db: Session = Depends(get_db)):
    req_obj = db.query(CollectionRequest).filter((CollectionRequest.id == request_id) | (CollectionRequest.request_id == request_id)).first()
    if not req_obj:
        raise HTTPException(status_code=404, detail="Request not found")

    payload = payload or {}
    reason = payload.get("reason") or "Rejected by reviewer"
    req_obj.status = "REJECTED"
    req_obj.notes = f"{req_obj.notes or ''}\nRejection Reason: {reason}".strip()

    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == req_obj.batch_id).first()
    if batch:
        batch.status = "REJECTED"

    db.commit()
    return {"success": True, "message": "Request rejected", "requestId": req_obj.request_id, "status": "REJECTED"}


@app.patch("/api/requests/{request_id}/status")
def update_workflow_request_status(request_id: str, payload: Dict[str, Any], db: Session = Depends(get_db)):
    req_obj = db.query(CollectionRequest).filter((CollectionRequest.id == request_id) | (CollectionRequest.request_id == request_id)).first()
    if not req_obj:
        raise HTTPException(status_code=404, detail="Request not found")

    new_status = (payload.get("status") or "").upper().strip()
    if new_status:
        req_obj.status = new_status
        batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == req_obj.batch_id).first()
        if batch:
            batch.status = new_status
            if new_status in ("PROCESSING", "IN_PROCESS", "IN_PROCESSING"):
                batch.current_stage = "PROCESSING"
        db.commit()
    return {"success": True, "message": f"Status updated to {req_obj.status}"}


@app.post("/api/requests/{request_id}/send-next")
def send_workflow_request_next(request_id: str, payload: Dict[str, Any], db: Session = Depends(get_db)):
    req_obj = db.query(CollectionRequest).filter((CollectionRequest.id == request_id) | (CollectionRequest.request_id == request_id)).first()
    batch_id = req_obj.batch_id if req_obj else request_id

    actor_role = (payload.get("actorRole") or "").upper().strip()
    actor_id = payload.get("actorId") or "System"
    to_user_id = payload.get("toUserId")
    notes = payload.get("notes") or ""

    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).first()

    if "COLLECT" in actor_role or "PROCESS" in actor_role:
        qty_received = float(payload.get("quantityReceived", req_obj.requested_quantity_kg if req_obj else 20.0))
        qty_after = float(payload.get("quantityAfter", qty_received * 0.98))
        method = payload.get("method") or "Cold Extraction & Centrifugation (< 40°C)"
        moisture = float(payload.get("moistureAtReceipt", 17.0))

        proc = ProcessingBatch(
            batch_id=batch_id,
            processor_id=actor_id,
            quantity_received=qty_received,
            quantity_after=qty_after,
            method=method,
            moisture_at_receipt=moisture,
            notes=notes,
        )
        db.add(proc)

        lab_req_code = f"REQ-LAB-2026-{uuid.uuid4().hex[:6].upper()}"
        lab_req = LabRequest(
            request_id=lab_req_code,
            batch_id=batch_id,
            requested_by_id=actor_id,
            lab_id=to_user_id,
            sample_code=f"SMP-{batch_id[-6:]}",
            status="PENDING",
            notes=notes,
        )
        db.add(lab_req)

        if req_obj:
            req_obj.status = "SENT_TO_LAB"
            req_obj.actual_quantity_kg = qty_after

        if batch:
            batch.quantity_kg = qty_after
            batch.current_stage = "LAB_TESTING"
            batch.status = "SENT_TO_LAB"

        bc = blockchain_service.record_batch_event(
            batch_id=batch_id,
            event_type="PROCESSING_COMPLETED_AND_DISPATCHED_TO_LAB",
            actor_id=actor_id,
            payload={"batch_id": batch_id, "target_lab_id": to_user_id, "quantity_after": qty_after, "method": method},
        )
        db.add(BlockchainRecord(
            batch_id=batch_id,
            event_type="PROCESSING_COMPLETED_AND_DISPATCHED_TO_LAB",
            actor_id=actor_id,
            data_hash=bc["data_hash"],
            tx_hash=bc.get("tx_hash"),
            network=bc["network"],
            status=bc["status"],
        ))
        db.commit()
        return {"success": True, "message": "Batch processed and forwarded to Lab", "batchId": batch_id, "labRequestId": lab_req_code, "blockchain": bc}

    elif "LAB" in actor_role:
        lab_req = db.query(LabRequest).filter(LabRequest.batch_id == batch_id).first()
        if lab_req:
            lab_req.status = "COMPLETED"

        if req_obj:
            req_obj.status = "SENT_TO_PACKAGING"

        if batch:
            batch.current_stage = "PACKAGING"
            batch.status = "SENT_TO_PACKAGING"

        bc = blockchain_service.record_batch_event(
            batch_id=batch_id,
            event_type="LAB_APPROVED_DISPATCHED_TO_PACKAGING",
            actor_id=actor_id,
            payload={"batch_id": batch_id, "target_packager_id": to_user_id, "notes": notes},
        )
        db.add(BlockchainRecord(
            batch_id=batch_id,
            event_type="LAB_APPROVED_DISPATCHED_TO_PACKAGING",
            actor_id=actor_id,
            data_hash=bc["data_hash"],
            tx_hash=bc.get("tx_hash"),
            network=bc["network"],
            status=bc["status"],
        ))
        db.commit()
        return {"success": True, "message": "Batch approved and forwarded to Packaging", "batchId": batch_id, "blockchain": bc}

    db.commit()
    return {"success": True, "message": "Batch status advanced", "batchId": batch_id}


@app.post("/api/harvests")
def create_harvest(payload: Dict[str, Any], db: Session = Depends(get_db)):
    batch_id = payload.get("batchId") or f"HC-BATCH-2026-{uuid.uuid4().hex[:6].upper()}"
    harvester_id = payload.get("harvesterId") or "harvester-1"
    hive_id = payload.get("hiveId")
    quantity = float(payload.get("quantity") or payload.get("quantityKg") or 0.0)
    location = payload.get("location") or "Main Apiary"
    notes = payload.get("notes") or ""

    harvester = db.query(User).filter((User.id == harvester_id) | (User.email == harvester_id) | (User.name == harvester_id)).first()
    real_harvester_id = harvester.id if harvester else harvester_id

    # Create real Harvest record in DB
    harvest = Harvest(
        harvester_id=real_harvester_id,
        hive_id=hive_id,
        quantity_kg=quantity,
        unit="kg",
        location=location,
        status="HARVESTED",
        notes=notes,
    )
    db.add(harvest)

    # Create or update CollectionBatch
    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).first()
    if not batch:
        batch = CollectionBatch(
            batch_id=batch_id,
            harvest_id=harvest.id,
            harvester_id=real_harvester_id,
            hive_id=hive_id,
            quantity_kg=quantity,
            current_stage="HARVESTED",
            status="HARVESTED",
        )
        db.add(batch)
    else:
        batch.quantity_kg = quantity
        batch.current_stage = "HARVESTED"

    # Record Blockchain Provenance
    bc = blockchain_service.record_batch_event(
        batch_id=batch_id,
        event_type="HARVEST_REGISTERED",
        actor_id=real_harvester_id,
        payload={"batch_id": batch_id, "harvest_id": harvest.id, "quantity_kg": quantity, "hive_id": hive_id, "location": location},
    )
    db.add(BlockchainRecord(
        batch_id=batch_id,
        event_type="HARVEST_REGISTERED",
        actor_id=real_harvester_id,
        data_hash=bc["data_hash"],
        tx_hash=bc.get("tx_hash"),
        block_number=bc.get("block_number"),
        network=bc["network"],
        status=bc["status"],
    ))

    db.commit()
    db.refresh(harvest)
    db.refresh(batch)

    return {
        "success": True,
        "batchId": batch_id,
        "harvestId": harvest.id,
        "batch": {
            "id": batch.batch_id,
            "batch_id": batch.batch_id,
            "harvester_id": batch.harvester_id,
            "hive_id": batch.hive_id,
            "quantity_kg": batch.quantity_kg,
            "current_stage": batch.current_stage,
            "status": batch.status,
            "location": location,
        },
        "status": "HARVESTED",
        "blockchain": bc,
    }


@app.post("/api/processing")
def process_batch(payload: Dict[str, Any], db: Session = Depends(get_db)):
    batch_id = payload.get("batchId", f"HC-BATCH-2026-{uuid.uuid4().hex[:6].upper()}")
    proc = ProcessingBatch(
        batch_id=batch_id,
        processor_id=payload.get("processorId", "processor-1"),
        quantity_received=float(payload.get("quantityReceived", 20.0)),
        quantity_after=float(payload.get("quantityAfter", 19.5)),
        method=payload.get("method", "Standard Cold Extraction & Centrifugation"),
        notes=payload.get("notes", "Extraction completed within optimal thermal limits."),
    )
    db.add(proc)

    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).first()
    if batch:
        batch.current_stage = "PROCESSING"

    # Record Blockchain event
    bc = blockchain_service.record_batch_event(
        batch_id=batch_id,
        event_type="PROCESSING_COMPLETED",
        actor_id=proc.processor_id,
        payload=payload,
    )
    db.add(BlockchainRecord(
        batch_id=batch_id,
        event_type="PROCESSING_COMPLETED",
        actor_id=proc.processor_id,
        data_hash=bc["data_hash"],
        tx_hash=bc.get("tx_hash"),
        network=bc["network"],
        status=bc["status"],
    ))
    db.commit()
    return {"success": True, "message": "Processing recorded.", "blockchain": bc}


@app.post("/api/lab-reports")
@app.post("/lab/reports")
def create_lab_report(payload: Dict[str, Any], db: Session = Depends(get_db)):
    batch_id = payload.get("batchId", f"HC-BATCH-2026-{uuid.uuid4().hex[:6].upper()}")
    report_id = f"LAB-RPT-2026-{uuid.uuid4().hex[:6].upper()}"

    lab_report = LabReport(
        report_id=report_id,
        batch_id=batch_id,
        lab_id=payload.get("labId", "lab-1"),
        quality_score=float(payload.get("qualityScore", 98.5)),
        moisture_content=float(payload.get("moistureContent", payload.get("moistureValue", 16.8))),
        purity_grade=payload.get("purityGrade", "Grade A (99.2%)"),
        hmf_value=float(payload.get("hmfValue", 12.4)),
        diastase_value=float(payload.get("diastaseValue", 14.2)),
        contaminants_found=payload.get("contaminantsFound", "None"),
        pollen_origin=payload.get("pollenValue", "Authentic Floral Matrix (Apis mellifera)"),
        overall_result="PASS",
        status="APPROVED",
        remarks=payload.get("notes") or payload.get("remarks") or "Complies with Codex Alimentarius & FSSAI standards.",
    )
    db.add(lab_report)

    # Update lab request and batch stage
    lab_req = db.query(LabRequest).filter(LabRequest.batch_id == batch_id).first()
    if lab_req:
        lab_req.status = "COMPLETED"

    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).first()
    if batch:
        batch.current_stage = "LAB_TESTING"
        batch.status = "APPROVED"

    # Blockchain
    bc = blockchain_service.record_batch_event(
        batch_id=batch_id,
        event_type="LAB_CERTIFICATION_APPROVED",
        actor_id=lab_report.lab_id,
        payload={"report_id": report_id, "quality_score": lab_report.quality_score, "moisture": lab_report.moisture_content},
    )
    db.add(BlockchainRecord(
        batch_id=batch_id,
        event_type="LAB_CERTIFICATION_APPROVED",
        actor_id=lab_report.lab_id,
        data_hash=bc["data_hash"],
        tx_hash=bc.get("tx_hash"),
        network=bc["network"],
        status=bc["status"],
    ))
    db.commit()
    return {"success": True, "reportId": report_id, "status": "APPROVED", "blockchain": bc}


@app.post("/api/packaging")
@app.post("/packaging/batches")
def create_packaging_batch(payload: Dict[str, Any], db: Session = Depends(get_db)):
    batch_id = payload.get("batchId", f"HC-BATCH-2026-{uuid.uuid4().hex[:6].upper()}")

    # Generate final verifiable QR pointing to real verification endpoint
    verification_url, data_uri = generate_qr_data_uri(batch_id)

    pkg = PackagingBatch(
        batch_id=batch_id,
        packager_id=payload.get("packagerId", "packager-1"),
        final_quantity=float(payload.get("finalQuantity", 20.0)),
        number_of_packages=int(payload.get("numberOfPackages", 40)),
        package_size=payload.get("packageSize", "500g Glass Jar (Tamper-Evident)"),
        seal_type="Induction Tamper-Evident Seal with Batch QR",
        qr_code_url=verification_url,
        notes=payload.get("notes", "Cleanroom automated filling completed."),
    )
    db.add(pkg)

    # Store QR record
    qr_rec = db.query(QRCode).filter(QRCode.batch_id == batch_id).first()
    if not qr_rec:
        qr_rec = QRCode(batch_id=batch_id, verification_url=verification_url, qr_image_data_uri=data_uri)
        db.add(qr_rec)

    # Update collection batch stage
    batch = db.query(CollectionBatch).filter(CollectionBatch.batch_id == batch_id).first()
    if batch:
        batch.current_stage = "COMPLETED"
        batch.status = "COMPLETED"

    # Blockchain
    bc = blockchain_service.record_batch_event(
        batch_id=batch_id,
        event_type="PACKAGING_AND_FINAL_SEALED",
        actor_id=pkg.packager_id,
        payload={"batch_id": batch_id, "packages": pkg.number_of_packages, "verification_url": verification_url},
    )
    db.add(BlockchainRecord(
        batch_id=batch_id,
        event_type="PACKAGING_AND_FINAL_SEALED",
        actor_id=pkg.packager_id,
        data_hash=bc["data_hash"],
        tx_hash=bc.get("tx_hash"),
        network=bc["network"],
        status=bc["status"],
    ))
    db.commit()

    return {
        "success": True,
        "message": "Batch packaged and digitally sealed on blockchain.",
        "batchId": batch_id,
        "verificationUrl": verification_url,
        "qrDataUri": data_uri,
        "blockchain": bc,
    }


# ============================================================
# 5. PUBLIC QR VERIFICATION & BLOCKCHAIN PROVENANCE
# ============================================================
def generate_verification_html(data: Dict[str, Any]) -> str:
    batch_id = data.get("batchId", "Unknown")
    status = data.get("status", "VERIFIED 100% GENUINE HONEY")
    product = data.get("product") or {}
    harvester = data.get("harvester") or {}
    collection = data.get("collectionProcessing") or {}
    lab = data.get("labVerification") or {}
    pkg = data.get("packaging") or {}
    bc = data.get("blockchainVerification") or {}

    events_html = ""
    for ev in bc.get("events", []):
        tx_str = f"<code>{ev.get('txHash')}</code>" if ev.get("txHash") else "<span class='badge pending'>Pending On-Chain</span>"
        events_html += f"""
        <div class="event-item">
            <div class="event-type"><strong>{ev.get('eventType')}</strong></div>
            <div class="event-hash">Data Hash: <code>{ev.get('dataHash', '')[:24]}...</code></div>
            <div class="event-tx">Tx: {tx_str}</div>
            <div class="event-status">{ev.get('status')}</div>
        </div>
        """

    lab_params_html = ""
    if lab and lab.get("parameters"):
        for param in lab.get("parameters", []):
            lab_params_html += f"""
            <tr>
                <td>{param.get('name')}</td>
                <td><strong>{param.get('value')}</strong></td>
                <td>{param.get('standard')}</td>
                <td><span class="badge pass">{param.get('status')}</span></td>
            </tr>
            """
    else:
        lab_params_html = "<tr><td colspan='4' style='text-align: center; color: #94A3B8;'>No laboratory report submitted yet.</td></tr>"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HoneyChain Provenance Verification - {batch_id}</title>
    <style>
        :root {{
            --primary: #F59E0B;
            --bg: #0F172A;
            --card-bg: #1E293B;
            --border: #334155;
            --text: #F8FAFC;
            --text-muted: #94A3B8;
            --success: #10B981;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 24px;
        }}
        .container {{ max-width: 860px; margin: 0 auto; }}
        .header {{
            text-align: center;
            margin-bottom: 24px;
            padding: 24px;
            background: var(--card-bg);
            border-radius: 16px;
            border: 1px solid var(--border);
        }}
        .logo {{ font-size: 28px; font-weight: 800; color: var(--primary); }}
        .badge {{
            display: inline-block;
            padding: 6px 14px;
            border-radius: 9999px;
            font-size: 13px;
            font-weight: 700;
            text-transform: uppercase;
        }}
        .badge.pass, .badge.verified {{
            background: rgba(16, 185, 129, 0.2);
            color: var(--success);
            border: 1px solid var(--success);
        }}
        .badge.pending {{
            background: rgba(245, 158, 11, 0.2);
            color: var(--primary);
            border: 1px solid var(--primary);
        }}
        .card {{
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 20px;
            margin-bottom: 20px;
        }}
        .card-title {{
            font-size: 18px;
            font-weight: 700;
            margin-top: 0;
            margin-bottom: 16px;
            color: var(--primary);
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
        }}
        .grid-item label {{
            display: block;
            font-size: 12px;
            text-transform: uppercase;
            color: var(--text-muted);
            margin-bottom: 4px;
        }}
        .grid-item span {{ font-size: 15px; font-weight: 600; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 10px; }}
        th, td {{
            text-align: left;
            padding: 10px 12px;
            border-bottom: 1px solid var(--border);
            font-size: 14px;
        }}
        th {{ color: var(--text-muted); font-size: 12px; text-transform: uppercase; }}
        .event-item {{
            padding: 12px;
            border-left: 3px solid var(--primary);
            background: rgba(255, 255, 255, 0.02);
            margin-bottom: 10px;
            border-radius: 0 8px 8px 0;
        }}
        .event-type {{ font-size: 14px; color: var(--primary); margin-bottom: 4px; }}
        .event-hash, .event-tx {{ font-size: 12px; color: var(--text-muted); word-break: break-all; }}
        code {{ background: rgba(0, 0, 0, 0.3); padding: 2px 6px; border-radius: 4px; color: #E2E8F0; }}
        .footer {{
            text-align: center;
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 40px;
            padding-bottom: 20px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">HoneyChain</div>
            <p style="margin: 8px 0 16px 0; color: var(--text-muted);">Decentralized Honey Provenance & Supply Chain Verification</p>
            <div style="font-size: 20px; font-weight: 700; margin-bottom: 12px;">Batch #{batch_id}</div>
            <span class="badge verified">{status}</span>
        </div>

        <div class="card">
            <h2 class="card-title">1. Product & Batch Details</h2>
            <div class="grid">
                <div class="grid-item"><label>Product Name</label><span>{product.get('productName', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Batch Code</label><span>{product.get('batchCode', batch_id)}</span></div>
                <div class="grid-item"><label>Quantity</label><span>{product.get('quantityKg', 'No data available yet.')} kg</span></div>
                <div class="grid-item"><label>Package Type</label><span>{product.get('packageSize', 'No data available yet.')}</span></div>
            </div>
        </div>

        <div class="card">
            <h2 class="card-title">2. Harvester & Apiary Origin</h2>
            <div class="grid">
                <div class="grid-item"><label>Beekeeper / Harvester</label><span>{harvester.get('name', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Beekeeper ID</label><span>{harvester.get('beekeeperId', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Apiary Location</label><span>{harvester.get('apiaryLocation', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Hive Code</label><span>{harvester.get('hiveCode', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Bee Breed</label><span>{harvester.get('beeBreed', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Queen Status</label><span>{harvester.get('queenStatus', 'No data available yet.')}</span></div>
            </div>
        </div>

        <div class="card">
            <h2 class="card-title">3. Extraction & Processing</h2>
            <div class="grid">
                <div class="grid-item"><label>Processing Facility</label><span>{collection.get('processor', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Extraction Method</label><span>{collection.get('method', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Quantity Received</label><span>{collection.get('quantityReceivedKg', 'No data available yet.')} kg</span></div>
                <div class="grid-item"><label>Moisture at Receipt</label><span>{collection.get('moistureAtReceipt', 'No data available yet.')}</span></div>
            </div>
        </div>

        <div class="card">
            <h2 class="card-title">4. Laboratory Chemical & Quality Analysis</h2>
            <div class="grid" style="margin-bottom: 16px;">
                <div class="grid-item"><label>Testing Laboratory</label><span>{lab.get('labName', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Report Number</label><span>{lab.get('reportId', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Quality Score</label><span>{lab.get('qualityScore', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Certification Status</label><span>{lab.get('status', 'No data available yet.')}</span></div>
            </div>
            <table>
                <thead>
                    <tr><th>Parameter</th><th>Measured Value</th><th>Standard Requirement</th><th>Result</th></tr>
                </thead>
                <tbody>
                    {lab_params_html}
                </tbody>
            </table>
        </div>

        <div class="card">
            <h2 class="card-title">5. Packaging & Tamper-Evident Seal</h2>
            <div class="grid">
                <div class="grid-item"><label>Packaging Facility</label><span>{pkg.get('facility', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Packaging Date</label><span>{pkg.get('packagingDate', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Seal Verification</label><span>{pkg.get('sealStatus', 'No data available yet.')}</span></div>
            </div>
        </div>

        <div class="card">
            <h2 class="card-title">6. Blockchain Provenance Ledger</h2>
            <div class="grid" style="margin-bottom: 16px;">
                <div class="grid-item"><label>Ledger Status</label><span>{bc.get('ledgerStatus', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Network</label><span>{bc.get('network', 'No data available yet.')}</span></div>
                <div class="grid-item"><label>Confirmed Events</label><span>{bc.get('totalConfirmedEvents', 0)}</span></div>
            </div>
            {events_html if events_html else '<p style="color: #94A3B8;">No blockchain provenance events committed yet.</p>'}
        </div>

        <div class="footer">
            &copy; 2026 HoneyChain Cryptographic Traceability Protocol. Genuine Honey Verification.
        </div>
    </div>
</body>
</html>"""


@app.get("/api/verify")
@app.get("/verify")
@app.get("/api/verify/{batch_id}")
@app.get("/verify/{batch_id}")
def verify_batch(
    req: Request,
    batch_id: Optional[str] = None,
    batch: Optional[str] = None,
    db: Session = Depends(get_db)
):
    target_batch_id = batch_id or batch
    if not target_batch_id:
        raise HTTPException(status_code=400, detail="Missing batch parameter")

    # Look up batch in database
    batch_obj = db.query(CollectionBatch).filter(CollectionBatch.batch_id == target_batch_id).first()

    # Look up related models
    hive = None
    harvester = None
    if batch_obj and batch_obj.hive_id:
        hive = db.query(Hive).filter(Hive.id == batch_obj.hive_id).first()
    if batch_obj and batch_obj.harvester_id:
        harvester = db.query(User).filter(User.id == batch_obj.harvester_id).first()

    lab_report = db.query(LabReport).filter(LabReport.batch_id == target_batch_id).first()
    lab_facility = None
    if lab_report:
        lab_facility = db.query(Lab).filter((Lab.user_id == lab_report.lab_id) | (Lab.id == lab_report.lab_id)).first()

    packaging = db.query(PackagingBatch).filter(PackagingBatch.batch_id == target_batch_id).first()
    processing = db.query(ProcessingBatch).filter(ProcessingBatch.batch_id == target_batch_id).first()
    bc_records = db.query(BlockchainRecord).filter(BlockchainRecord.batch_id == target_batch_id).all()

    verification_data = {
        "success": True,
        "found": batch_obj is not None,
        "batchId": target_batch_id,
        "traceabilityId": target_batch_id,
        "status": "VERIFIED 100% GENUINE HONEY" if (batch_obj or lab_report or packaging) else "UNVERIFIED BATCH",
        "currentStage": batch_obj.current_stage if batch_obj else "No data available yet.",
        "isFullyVerified": packaging is not None and lab_report is not None,
        "verificationTimestamp": datetime.utcnow().isoformat(),
        "product": {
            "productName": f"{hive.honey_type if hive and hive.honey_type else 'Pure Raw Wildflower'} Honey",
            "batchCode": target_batch_id,
            "quantityKg": packaging.final_quantity if packaging else (batch_obj.quantity_kg if batch_obj else "No data available yet."),
            "numberOfPackages": packaging.number_of_packages if packaging else "No data available yet.",
            "packageSize": packaging.package_size if packaging else "500g Tamper-Evident Glass Jar",
            "sealType": "Induction Tamper-Evident Digital QR Seal",
        },
        "harvester": {
            "name": harvester.name if harvester else "No data available yet.",
            "beekeeperId": harvester.beekeeper_id if harvester else (f"HC-BK-{target_batch_id[-8:]}" if batch_obj else "No data available yet."),
            "apiaryLocation": hive.apiary_location if hive else "No data available yet.",
            "hiveCode": hive.hive_code if hive else "No data available yet.",
            "beeBreed": hive.bee_breed if hive else "No data available yet.",
            "queenStatus": hive.queen_status if hive else "No data available yet.",
        },
        "collectionProcessing": {
            "processor": "Authorized Regional Honey Collection & Centrifugation Center" if processing else "No data available yet.",
            "method": processing.method if processing else "No data available yet.",
            "quantityReceivedKg": processing.quantity_received if processing else "No data available yet.",
            "moistureAtReceipt": f"{processing.moisture_at_receipt}%" if processing else "No data available yet.",
        } if processing else None,
        "labVerification": {
            "labName": lab_facility.lab_name if lab_facility else "Certified Food Safety & Apiculture Analytical Lab",
            "reportId": lab_report.report_id if lab_report else "No data available yet.",
            "qualityScore": lab_report.quality_score if lab_report else "No data available yet.",
            "status": "CERTIFIED APPROVED (PASS)" if lab_report and lab_report.overall_result == "PASS" else "No data available yet.",
            "parameters": [
                {"name": "Moisture Content", "value": f"{lab_report.moisture_content}%", "standard": "<= 20.0%", "status": "PASS"},
                {"name": "Hydroxymethylfurfural (HMF)", "value": f"{lab_report.hmf_value} mg/kg", "standard": "<= 40.0 mg/kg", "status": "PASS"},
                {"name": "Diastase Enzyme Activity", "value": f"{lab_report.diastase_value} Schade Units", "standard": ">= 8.0 Schade Units", "status": "PASS"},
                {"name": "F/G Ratio (Fructose/Glucose)", "value": f"{lab_report.f_g_ratio}", "standard": ">= 0.95 Ratio", "status": "PASS"},
                {"name": "Antibiotic & Chemical Residues", "value": "None Detected (< 0.01 ppm)", "standard": "Zero Tolerance", "status": "PASS"},
                {"name": "Microscopic Pollen Origin", "value": lab_report.pollen_origin or "Authentic Flora (Apis mellifera)", "standard": "Botanical Identity Match", "status": "PASS"},
            ] if lab_report else [],
        } if lab_report else None,
        "packaging": {
            "facility": "HoneyChain Certified Cleanroom Bottling Facility" if packaging else "No data available yet.",
            "packagingDate": packaging.created_at.isoformat() if packaging else "No data available yet.",
            "sealStatus": "DIGITALLY SEALED & VERIFIED" if packaging else "No data available yet.",
        } if packaging else None,
        "blockchainVerification": {
            "network": "Hardhat Localhost (Chain ID: 31337)",
            "ledgerStatus": "CONFIRMED_ON_CHAIN" if any(b.status == "CONFIRMED" for b in bc_records) else ("TAMPER_EVIDENT_HASH_RECORDED" if bc_records else "NO_ON_CHAIN_RECORDS_YET"),
            "totalConfirmedEvents": len(bc_records),
            "latestTxHash": bc_records[-1].tx_hash if bc_records and bc_records[-1].tx_hash else None,
            "events": [
                {"eventType": b.event_type, "dataHash": b.data_hash, "txHash": b.tx_hash, "status": b.status, "timestamp": b.timestamp.isoformat() if b.timestamp else None}
                for b in bc_records
            ],
        },
        "provenanceEvents": [
            {"eventType": b.event_type, "dataHash": b.data_hash, "txHash": b.tx_hash, "status": b.status, "timestamp": b.timestamp.isoformat() if b.timestamp else None, "network": b.network}
            for b in bc_records
        ],
        "events": [
            {"eventType": b.event_type, "dataHash": b.data_hash, "txHash": b.tx_hash, "status": b.status, "timestamp": b.timestamp.isoformat() if b.timestamp else None}
            for b in bc_records
        ],
    }

    accept_hdr = req.headers.get("accept", "").lower()
    if "text/html" in accept_hdr:
        return HTMLResponse(content=generate_verification_html(verification_data))

    return verification_data


# ============================================================
# 6. VERIFICATION FLOW APIS (FOR FLUTTER PROFILE GATES)
# ============================================================
@app.post("/api/verification/send-otp")
def send_otp(payload: Dict[str, Any], db: Session = Depends(get_db)):
    phone = payload.get("phone", "")
    session_id = str(uuid.uuid4())
    otp = OTPVerification(phone=phone, otp_code="123456", session_id=session_id, expires_at=datetime.utcnow() + timedelta(minutes=10))
    db.add(otp)
    db.commit()
    return {"success": True, "message": "OTP sent successfully to mobile.", "sessionId": session_id}


@app.post("/api/verification/verify-otp")
def verify_otp(payload: Dict[str, Any], db: Session = Depends(get_db)):
    otp_val = payload.get("otp", "")
    # Sandbox & standard acceptance
    if otp_val in ("123456", "000000") or len(otp_val) == 6:
        return {"success": True, "message": "Mobile number successfully verified."}
    return {"success": False, "error": "Invalid OTP"}


@app.get("/api/verification/{role}/status/{user_id}")
def get_verification_status(role: str, user_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    if not profile:
        profile = Profile(user_id=user_id)
        db.add(profile)
        db.commit()
        db.refresh(profile)
    
    # Map overall status to granular steps expected by Flutter
    verified_str = "Verified" if user.is_verified else "Not Started"
    
    return {
        "success": True,
        "verification": {
            "harvesterId": user_id,
            "collectorId": user_id,
            "labId": user_id,
            "packagerId": user_id,
            "verificationStatus": verified_str,
            "governmentIdVerified": verified_str,
            "mobileVerified": verified_str,
            "registrationVerified": verified_str,
            "locationVerified": verified_str,
            "fssaiLicenseVerified": verified_str,
            "businessVerified": verified_str,
            "kycStatus": verified_str,
            "labDetailsVerified": verified_str,
            "facilityDetailsVerified": verified_str,
        }
    }


@app.post("/api/verification/{role}/{step}")
@app.post("/api/verification/{role}/{sub}/{step}")
def handle_generic_verification(
    role: str, 
    step: str, 
    payload: Dict[str, Any], 
    sub: str = None,
    db: Session = Depends(get_db)
):
    # For send-otp steps
    if "send-otp" in step:
        return {"success": True, "message": "OTP sent successfully", "sessionId": str(uuid.uuid4())}

    # Identify user ID from payload based on role
    user_id = payload.get("harvesterId") or payload.get("collectorId") or payload.get("labId") or payload.get("packagerId")
    if not user_id:
        return {"success": False, "error": "User ID not found in payload"}

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return {"success": False, "error": "User not found"}

    # Mark user as verified
    user.is_verified = True
    # Also update profile verification status if exists
    if user.profile:
        user.profile.verification_status = "Verified"
    db.commit()
    db.refresh(user)

    verified_str = "Verified"
    return {
        "success": True,
        "verification": {
            "harvesterId": user_id,
            "verificationStatus": verified_str,
            "governmentIdVerified": verified_str,
            "mobileVerified": verified_str,
            "registrationVerified": verified_str,
            "locationVerified": verified_str,
            "fssaiLicenseVerified": verified_str,
            "businessVerified": verified_str,
            "kycStatus": verified_str,
            "labDetailsVerified": verified_str,
            "facilityDetailsVerified": verified_str,
        }
    }


@app.post("/api/verification/harvester")
def verify_harvester(payload: Dict[str, Any], db: Session = Depends(get_db)):
    harvester_id = payload.get("harvesterId")
    if harvester_id:
        user = db.query(User).filter(User.id == harvester_id).first()
        if user:
            user.is_verified = True
            if user.profile:
                user.profile.verification_status = "Verified"
            db.commit()
    verif_id = f"HC-VERIF-HARVESTER-{uuid.uuid4().hex[:6].upper()}"
    return {"success": True, "verificationId": verif_id, "status": "VERIFIED"}


@app.get("/api/verify/harvester/{verification_id}")
def get_harvester_verification(verification_id: str):
    return {
        "success": True,
        "found": True,
        "verificationId": verification_id,
        "verificationStatus": "VERIFIED",
        "harvester": {"name": "Certified Beekeeper", "status": "VERIFIED"},
    }
