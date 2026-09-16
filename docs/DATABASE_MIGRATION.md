# HoneyChain Database Migration Guide

## Overview
HoneyChain utilizes Alembic alongside SQLAlchemy 2.0 to maintain authoritative relational schemas on PostgreSQL and Supabase.

## Migration Files
- `backend/alembic.ini`: Configuration file defining logging and script directory.
- `backend/alembic/env.py`: Migration environment importing SQLAlchemy `Base.metadata` from `backend.models` and resolving `DATABASE_URL`.
- `backend/alembic/versions/eb21531004d8_initial_honeychain_schema.py`: Baseline migration establishing the complete HoneyChain schema.

## Schema Entities
1. `users`: Identity and profiles with bcrypt-hashed credentials, RBAC roles, contact data, and verification flags.
2. `hives`: Physical beehive registry linked to harvesters and IoT hardware device IDs.
3. `telemetry_readings`: Raw and AI-processed time-series metrics (temp, humidity, weight, acoustics, anomaly scores, health scores).
4. `collection_batches`: Honey harvest lots recording beekeeper source, quantities, and current workflow status.
5. `processing_logs`: Refining, moisture reduction, filtration, and processing metrics.
6. `lab_reports`: NABL laboratory test results (purity, moisture content, HMF, sucrose, pollen analysis).
7. `packaging_batches`: Final retail packaging, container counts, and public QR verification endpoints.
8. `blockchain_records`: On-chain transaction receipts, block numbers, and SHA-256 tamper-evident hashes.

## Running Migrations
To upgrade the database to the latest schema:
```bash
cd backend
alembic upgrade head
```

To roll back a migration:
```bash
cd backend
alembic downgrade -1
```
