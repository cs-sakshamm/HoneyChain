"""
SQLAlchemy database models for HoneyChain.
Represents the complete end-to-end supply chain:
Harvester -> Hive -> IoT -> AI/ML Analysis -> Collection -> Lab -> Packaging -> Blockchain -> QR Code.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    Float,
    Integer,
    Boolean,
    DateTime,
    ForeignKey,
    Text,
    Index,
)
from sqlalchemy.orm import relationship
try:
    from backend.database import Base
except ImportError:
    from database import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    firebase_id = Column(String(128), nullable=True)
    name = Column(String(128), nullable=False)
    email = Column(String(128), nullable=False)
    password_hash = Column(String(256), nullable=True)
    phone = Column(String(32), nullable=True)
    avatar_url = Column(String(512), nullable=True)
    google_photo_url = Column(String(512), nullable=True)
    auth_provider = Column(String(32), default="local")
    role = Column(String(32), default="HARVESTER")  # HARVESTER, COLLECTION_PROCESSING, LAB_TESTING, PACKAGING, ADMIN
    beekeeper_id = Column(String(64), unique=True, nullable=True)
    bsid = Column(String(64), unique=True, nullable=True)
    organization_name = Column(String(128), nullable=True)
    facility_location = Column(String(256), nullable=True)
    license_number = Column(String(128), nullable=True)
    designation = Column(String(128), nullable=True)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    profile = relationship("Profile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    hives = relationship("Hive", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_users_email_role", "email", "role", unique=True),
        Index("ix_users_role", "role"),
    )


class Profile(Base):
    __tablename__ = "profiles"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    user_id = Column(String(64), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    full_name = Column(String(128), nullable=True)
    mobile_number = Column(String(32), nullable=True)
    mobile_verified = Column(String(32), default="Not Started")
    mobile_verified_at = Column(DateTime, nullable=True)
    government_id_type = Column(String(64), nullable=True)  # AADHAAR, PAN, PASSPORT
    government_id_reference = Column(String(128), nullable=True)
    government_id_doc_hash = Column(String(128), nullable=True)
    kyc_provider = Column(String(32), default="sandbox")
    kyc_status = Column(String(32), default="Not Started")
    kyc_verified_at = Column(DateTime, nullable=True)
    verification_status = Column(String(32), default="Not Started")  # Not Started, In Progress, Verified
    verified_at = Column(DateTime, nullable=True)
    review_notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="profile")


class Hive(Base):
    __tablename__ = "hives"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    user_id = Column(String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    device_id = Column(String(64), unique=True, nullable=True)  # Unique hardware mapping: SIH_HIVE_MVP_01
    name = Column(String(128), nullable=False)
    hive_code = Column(String(64), unique=True, nullable=False)
    apiary_location = Column(String(256), nullable=False)
    hive_type = Column(String(64), default="Langstroth")
    queen_status = Column(String(64), default="Mated")
    total_frames = Column(Integer, default=10)
    brood_frames = Column(Integer, default=0)
    colony_strength = Column(String(64), default="Strong")
    queen_age_months = Column(Integer, default=0)
    bee_breed = Column(String(64), default="Italian")
    expected_production_kg = Column(Float, default=0.0)
    previous_year_production_kg = Column(Float, default=0.0)
    current_year_production_kg = Column(Float, default=0.0)
    honey_type = Column(String(64), default="Wildflower")
    last_inspection_date = Column(DateTime, default=datetime.utcnow)
    mite_status = Column(String(64), default="None")
    disease_status = Column(String(64), default="None")
    feeding_required = Column(Boolean, default=False)
    queen_condition = Column(String(64), default="Good")
    overall_health = Column(String(64), default="Healthy")
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="hives")
    telemetry = relationship("HiveTelemetry", back_populates="hive", cascade="all, delete-orphan")
    ai_analysis = relationship("HiveAIAnalysis", back_populates="hive", cascade="all, delete-orphan")
    alerts = relationship("HiveAlert", back_populates="hive", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_hives_user_id", "user_id"),
        Index("ix_hives_device_id", "device_id"),
        Index("ix_hives_hive_code", "hive_code"),
    )


class HiveTelemetry(Base):
    __tablename__ = "hive_telemetry"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    hive_id = Column(String(64), ForeignKey("hives.id", ondelete="CASCADE"), nullable=False)
    device_id = Column(String(64), nullable=False)
    timestamp = Column(Integer, nullable=True)  # Unix epoch from sensor
    temperature_c = Column(Float, nullable=False)
    humidity_pct = Column(Float, nullable=False)
    weight_kg = Column(Float, nullable=False)
    acoustics_hz = Column(Float, nullable=False)
    battery_v = Column(Float, nullable=True, default=4.12)
    wifi_rssi_dbm = Column(Float, nullable=True, default=-68.0)
    bee_activity = Column(Float, nullable=True, default=85.0)
    recorded_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    hive = relationship("Hive", back_populates="telemetry")

    __table_args__ = (
        Index("ix_telemetry_hive_id", "hive_id"),
        Index("ix_telemetry_device_id", "device_id"),
        Index("ix_telemetry_recorded_at", "recorded_at"),
        Index("ix_telemetry_device_id_timestamp", "device_id", "timestamp"),
    )


class HiveAIAnalysis(Base):
    __tablename__ = "hive_ai_analysis"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    hive_id = Column(String(64), ForeignKey("hives.id", ondelete="CASCADE"), nullable=False)
    telemetry_id = Column(String(64), nullable=True)
    device_id = Column(String(64), nullable=False)
    timestamp = Column(Integer, nullable=True)
    risk_level = Column(String(32), default="LOW")  # LOW, MEDIUM, HIGH
    status = Column(String(32), default="HEALTHY")  # HEALTHY, ATTENTION, ALERT
    anomaly_detected = Column(Boolean, default=False)
    anomaly_score = Column(Float, default=0.0)
    temperature_status = Column(String(32), default="NORMAL")
    humidity_status = Column(String(32), default="NORMAL")
    weight_status = Column(String(32), default="STABLE")
    weight_trend = Column(String(32), default="STABLE")
    acoustic_status = Column(String(32), default="NORMAL")
    reasons_json = Column(Text, nullable=True)  # JSON string of reasons
    alerts_json = Column(Text, nullable=True)  # JSON string of generated alerts
    raw_output_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    hive = relationship("Hive", back_populates="ai_analysis")

    __table_args__ = (
        Index("ix_ai_analysis_hive_id", "hive_id"),
        Index("ix_ai_analysis_device_id", "device_id"),
    )


class HiveAlert(Base):
    __tablename__ = "hive_alerts"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    hive_id = Column(String(64), ForeignKey("hives.id", ondelete="CASCADE"), nullable=False)
    hive_code = Column(String(64), nullable=True)
    device_id = Column(String(64), nullable=True)
    parameter = Column(String(64), nullable=False)  # Temperature, Humidity, Weight, Anomaly
    previous_value = Column(String(64), nullable=True)
    current_value = Column(String(64), nullable=True)
    change_value = Column(String(64), nullable=True)
    unit = Column(String(32), default="°C")
    severity = Column(String(32), default="CRITICAL")  # CRITICAL, WARNING, MEDIUM
    message = Column(Text, nullable=False)
    status = Column(String(32), default="ACTIVE")  # ACTIVE, ACKNOWLEDGED
    detected_at = Column(DateTime, default=datetime.utcnow)
    acknowledged_at = Column(DateTime, nullable=True)
    acknowledged_by = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    hive = relationship("Hive", back_populates="alerts")

    __table_args__ = (
        Index("ix_alerts_hive_id", "hive_id"),
        Index("ix_alerts_status", "status"),
        Index("ix_alerts_detected_at", "detected_at"),
    )


class CollectionCentre(Base):
    __tablename__ = "collection_centres"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    name = Column(String(128), nullable=False)
    location = Column(String(256), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    contact_phone = Column(String(32), nullable=True)
    contact_email = Column(String(128), nullable=True)
    license_number = Column(String(128), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Harvest(Base):
    __tablename__ = "harvests"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    harvester_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    hive_id = Column(String(64), ForeignKey("hives.id", ondelete="SET NULL"), nullable=True)
    quantity_kg = Column(Float, default=0.0)
    unit = Column(String(16), default="kg")
    location = Column(String(256), nullable=True)
    status = Column(String(32), default="HARVESTED")
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class CollectionRequest(Base):
    __tablename__ = "collection_requests"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    request_id = Column(String(64), unique=True, nullable=False)  # REQ-COL-2026-XXXX
    harvester_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    hive_id = Column(String(64), ForeignKey("hives.id", ondelete="SET NULL"), nullable=True)
    harvest_id = Column(String(64), nullable=True)
    collection_centre_id = Column(String(64), nullable=True)
    collection_centre_name = Column(String(128), nullable=True)
    batch_id = Column(String(64), nullable=True)
    status = Column(String(32), default="PENDING")  # PENDING, ACCEPTED, REJECTED, COLLECTED, PROCESSING, COMPLETED
    requested_quantity_kg = Column(Float, default=0.0)
    actual_quantity_kg = Column(Float, default=0.0)
    location = Column(String(256), nullable=True)
    notes = Column(Text, nullable=True)
    accepted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("ix_col_requests_request_id", "request_id"),
        Index("ix_col_requests_harvester_id", "harvester_id"),
        Index("ix_col_requests_status", "status"),
    )


class CollectionBatch(Base):
    __tablename__ = "collection_batches"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    batch_id = Column(String(64), unique=True, nullable=False)  # HC-BATCH-2026-XXXX
    harvest_id = Column(String(64), nullable=True)
    request_id = Column(String(64), nullable=True)
    harvester_id = Column(String(64), nullable=False)
    hive_id = Column(String(64), nullable=True)
    quantity_kg = Column(Float, default=0.0)
    current_stage = Column(String(32), default="COLLECTED")  # HARVESTED, COLLECTED, PROCESSING, LAB_TESTING, PACKAGING, COMPLETED
    status = Column(String(32), default="COLLECTED")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ProcessingBatch(Base):
    __tablename__ = "processing_batches"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    batch_id = Column(String(64), nullable=False)
    processor_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    quantity_received = Column(Float, default=0.0)
    quantity_after = Column(Float, default=0.0)
    method = Column(String(128), default="Cold Extraction & Centrifugation")
    moisture_at_receipt = Column(Float, default=17.0)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Lab(Base):
    __tablename__ = "labs"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    user_id = Column(String(64), ForeignKey("users.id"), unique=True, nullable=False)
    lab_name = Column(String(128), nullable=False)
    facility_location = Column(String(256), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    contact_phone = Column(String(32), nullable=True)
    contact_email = Column(String(128), nullable=True)
    registration_number = Column(String(128), nullable=True)
    accreditation = Column(String(128), default="NABL / FSSAI / ISO 17025")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class PackagingFacility(Base):
    __tablename__ = "packaging_facilities"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    name = Column(String(128), nullable=False)
    location = Column(String(256), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    contact_phone = Column(String(32), nullable=True)
    contact_email = Column(String(128), nullable=True)
    license_number = Column(String(128), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class LabRequest(Base):
    __tablename__ = "lab_requests"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    request_id = Column(String(64), unique=True, nullable=False)
    batch_id = Column(String(64), nullable=False)
    requested_by_id = Column(String(64), nullable=False)
    lab_id = Column(String(64), nullable=True)
    harvest_id = Column(String(64), nullable=True)
    hive_id = Column(String(64), nullable=True)
    collection_center_id = Column(String(64), nullable=True)
    processing_id = Column(String(64), nullable=True)
    sample_code = Column(String(64), nullable=True)
    status = Column(String(32), default="PENDING")  # PENDING, TESTING, COMPLETED, REJECTED
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class LabReport(Base):
    __tablename__ = "lab_reports"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    report_id = Column(String(64), unique=True, nullable=False)  # LAB-RPT-2026-XXXX
    batch_id = Column(String(64), nullable=False)
    lab_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    sample_code = Column(String(64), nullable=True)
    quality_score = Column(Float, default=98.5)
    moisture_content = Column(Float, default=17.2)
    purity_grade = Column(String(32), default="Grade A (99.2%)")
    hmf_value = Column(Float, default=12.4)
    diastase_value = Column(Float, default=14.2)
    f_g_ratio = Column(Float, default=1.15)
    contaminants_found = Column(String(128), default="None")
    pollen_origin = Column(String(128), default="Authentic Floral Matrix (Apis mellifera)")
    overall_result = Column(String(32), default="PASS")  # PASS, FAIL
    status = Column(String(32), default="APPROVED")  # APPROVED, REJECTED
    remarks = Column(Text, nullable=True)
    test_date = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)


class PackagingBatch(Base):
    __tablename__ = "packaging_batches"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    batch_id = Column(String(64), nullable=False)
    packager_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    final_quantity = Column(Float, default=0.0)
    number_of_packages = Column(Integer, default=1)
    package_size = Column(String(64), default="500g Glass Jar")
    seal_type = Column(String(128), default="Induction Tamper-Evident Seal with Batch QR")
    qr_code_url = Column(String(512), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class BlockchainRecord(Base):
    __tablename__ = "blockchain_records"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    batch_id = Column(String(64), nullable=False)
    event_type = Column(String(64), nullable=False)
    actor_id = Column(String(64), nullable=False)
    data_hash = Column(String(128), nullable=False)
    previous_event_hash = Column(String(128), default="")
    tx_hash = Column(String(128), nullable=True)
    block_number = Column(Integer, nullable=True)
    network = Column(String(64), default="Hardhat Localhost (Chain ID: 31337)")
    contract_address = Column(String(128), nullable=True)
    status = Column(String(32), default="PENDING")  # PENDING, CONFIRMED, FAILED
    timestamp = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("ix_blockchain_batch_id", "batch_id"),
        Index("ix_blockchain_tx_hash", "tx_hash"),
    )


class QRCode(Base):
    __tablename__ = "qr_codes"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    batch_id = Column(String(64), unique=True, nullable=False)
    verification_url = Column(String(512), nullable=False)
    qr_image_data_uri = Column(Text, nullable=True)  # data:image/png;base64,...
    created_at = Column(DateTime, default=datetime.utcnow)


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    user_id = Column(String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(32), default="HARVESTER")
    type = Column(String(32), default="NORMAL")  # NORMAL, CRITICAL
    category = Column(String(64), default="SYSTEM")
    title = Column(String(128), nullable=False)
    message = Column(Text, nullable=False)
    severity = Column(String(32), default="INFO")  # INFO, WARNING, CRITICAL
    is_unignorable = Column(Boolean, default=False)
    resource_id = Column(String(64), nullable=True)
    details_json = Column(Text, nullable=True)
    status = Column(String(32), default="ACTIVE")  # ACTIVE, ACKNOWLEDGED
    acknowledged_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="notifications")

    __table_args__ = (
        Index("ix_notif_user_id", "user_id"),
        Index("ix_notif_status", "status"),
    )


class OTPVerification(Base):
    __tablename__ = "otp_verifications"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    phone = Column(String(32), nullable=True)
    email = Column(String(128), nullable=True)
    otp_code = Column(String(16), nullable=False)
    session_id = Column(String(64), nullable=True)
    is_verified = Column(Boolean, default=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
