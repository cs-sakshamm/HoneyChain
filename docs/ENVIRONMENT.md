# HoneyChain Environment Variables Specification

This document details all configuration parameters across HoneyChain services.

| Variable Name | Component | Type | Default Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `PORT` | Backend | Integer | `8000` | Port on which FastAPI server listens |
| `DATABASE_URL` | Backend | String (URI) | `postgresql://...` | PostgreSQL connection URI (Supabase pooler supported) |
| `DATABASE_POOL_SIZE` | Backend | Integer | `10` | SQLAlchemy connection pool size |
| `DATABASE_MAX_OVERFLOW`| Backend | Integer | `20` | Max overflow connections above pool size |
| `DATABASE_POOL_RECYCLE` | Backend | Integer | `1800` | Pool recycle timeout in seconds |
| `SECRET_KEY` | Backend | String | *Required* | 256-bit cryptographically secure key for JWT HMAC-SHA256 signing |
| `ALGORITHM` | Backend | String | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Backend | Integer | `1440` | JWT token validity window in minutes |
| `WEB3_PROVIDER_URI` | Blockchain | String (URL) | `https://rpc-amoy.polygon.technology/` | RPC endpoint for Web3 interactions |
| `BLOCKCHAIN_CHAIN_ID` | Blockchain | Integer | `80002` | Network chain ID (Polygon Amoy) |
| `CONTRACT_ADDRESS` | Blockchain | String (Hex) | `0x...` | Deployed `HoneyChainProvenance` contract address |
| `PRIVATE_KEY` | Blockchain | String (Hex) | `0x...` | Relayer private key for signing provenance transactions |
| `BLOCKCHAIN_TIMEOUT_SECONDS` | Blockchain | Float | `2.0` | Timeout threshold before graceful fallback to offline SHA-256 |
| `MQTT_BROKER` | IoT / AI | String | `broker.hivemq.com` | Hostname or IP of MQTT broker |
| `MQTT_PORT` | IoT / AI | Integer | `1883` | Port for MQTT communications |
| `MQTT_TOPIC_TELEMETRY`| IoT / AI | String | `honeychain/hive/telemetry` | Raw telemetry publication topic |
| `MQTT_TOPIC_AI_PROCESSED` | AI / Backend | String | `honeychain/hive/processed` | Topic for AI/ML processed insights |
| `BACKEND_URL` | Mobile App | String (URL) | `http://10.0.2.2:8000` | Base URL passed via `--dart-define=BACKEND_URL` |
