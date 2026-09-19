# HoneyChain — Flutter Mobile Application

Role-based mobile client for the HoneyChain honey traceability platform: beekeepers monitor hives and record harvests, collection centres aggregate batches, labs certify quality, packaging facilities jar and QR-tag product, and consumers verify provenance.

---

## 1. Technical Overview

* **Framework:** Flutter (Dart SDK `>=3.0.0 <4.0.0`), Material 3
* **State management:** Provider (`provider: ^6.1.2`) — controllers as `ChangeNotifier`s registered in `MultiProvider`
* **Networking:** `http: ^1.6.0` REST client against the FastAPI backend; JWT bearer tokens held in `AuthTokenStore`
* **Authentication:** Firebase Auth (`firebase_auth: ^5.5.1`, `firebase_core: ^3.12.0`) + Google Sign-In (`google_sign_in: ^6.2.2`), plus backend email/password and OTP flows
* **QR rendering:** `qr_flutter: ^4.1.0`
* **Fonts/theming:** `google_fonts`, single honey-accent design system in `core/theme/`
* **Platforms:** Android (API 21+), iOS (12.0+), Web

---

## 2. Directory Structure

```text
mobile_app/
├── lib/
│   ├── main.dart                 # Bootstrap: Firebase init, providers, routes
│   ├── app.dart                  # Root widget / navigation host
│   ├── core/
│   │   ├── constants/            # AppConstants: backend base URL, design tokens
│   │   ├── controllers/          # TelemetryAlertController, WorkflowController
│   │   ├── localization/         # Multi-language support
│   │   ├── models/               # HiveAlertModel, hive_telemetry_models, session models
│   │   ├── services/             # Auth token store, audio alerts, storage
│   │   ├── theme/                # Light/dark honey theme + BuildContext extensions
│   │   └── widgets/              # Reusable widgets incl. HiveTelemetryDashboard
│   └── features/
│       ├── authentication/       # Login, signup, Google sign-in, role selection
│       ├── hives/                # Harvester dashboard, hive CRUD, telemetry dashboard
│       ├── collection/           # Collector dashboard & requests
│       ├── lab/                  # Lab testing & reports
│       ├── packaging/            # Packaging & QR generation
│       ├── verification/         # Role verification + public QR verification
│       ├── profile/              # Profile, KYC, settings
│       ├── notifications/        # Critical alert modals
│       └── navigation/           # Bottom navigation / drawer
├── assets/                       # Images (assets/images/, hero assets)
├── test/                         # 49 Flutter tests
└── pubspec.yaml
```

---

## 3. Role-Based Screens

1. **Harvester/Beekeeper** — hive dashboard backed by real telemetry (temperature °C, humidity %, weight kg, acoustic Hz, battery V, Wi-Fi dBm), AI status/risk from the backend's stored Isolation Forest output, harvest recording, collection requests.
2. **Collector** — incoming request queue, batch aggregation, timeline.
3. **Lab tester** — sample metrics (moisture, pollen, HMF, purity, C4 adulteration), grading, certificates.
4. **Packaging** — batch packaging (250g/500g/1000g), QR generation.
5. **Public consumer** — QR scan / batch-code lookup against the public verification endpoint.

---

## 4. Hive Telemetry Dashboard (real data only)

`core/widgets/hive_telemetry_dashboard.dart` renders strictly backend-sourced data — sensor values are **never fabricated** when absent (they render as `--`). Its states, covered by widget tests:

| State | Trigger | UI |
|---|---|---|
| Waiting | No telemetry yet / backend unreachable | "Waiting for telemetry..." explainer |
| Live | Snapshot with telemetry | Real sensor + diagnostic values, "Updated" time |
| AI result | Stored analysis exists | Status pill (HEALTHY/ATTENTION/ALERT · risk), anomaly score, real alert messages |
| Collecting | AI history < ~145 readings | "Collecting telemetry history... (n/145)" + progress bar |

Data comes from `GET /api/hives/{id}/telemetry/latest` (snapshot), `/status`, and `/telemetry` (history), polled through `TelemetryAlertController` with JWT headers.

---

## 5. Configuration

Backend base URL resolution (`AppConstants.backendBaseUrl`), single source of truth for app → backend calls:

1. `--dart-define=BACKEND_URL=<url>` override (always wins)
2. Web / desktop: `http://localhost:8000`
3. Android emulator: `http://10.0.2.2:8000` (host loopback alias)
4. Physical devices: pass the host machine's LAN IP via `BACKEND_URL`

Firebase options are generated (`lib/firebase_options.dart`); API secrets are never stored in the app — all privileged operations go through the backend.

---

## 6. Install & Run

```bash
cd mobile_app
flutter pub get

# Web
flutter run -d chrome --dart-define=BACKEND_URL=http://localhost:8000

# Android emulator
flutter run -d android

# Physical device (same Wi-Fi as the backend host)
flutter run -d <DEVICE_ID> --dart-define=BACKEND_URL=http://<PC_LAN_IP>:8000
```

Release builds:

```bash
flutter build apk --release --dart-define=BACKEND_URL=https://<api-host>
flutter build web --release
```

---

## 7. Animation

```text
Framer Motion: NOT APPLICABLE — Mobile app uses Flutter/Dart.
```

No JavaScript animation library is used or needed. Motion is handled with Flutter's built-in Material 3 transitions (page navigation, modals, `CircularProgressIndicator`/`LinearProgressIndicator` for loading and AI-history progress). No custom animation system was added or replaced.

---

## 8. Testing

```bash
cd mobile_app
flutter test        # 49 tests, all passing
flutter analyze     # static analysis
```

Suites: role-image integrity & slider (31), avatar priority (7), telemetry alert model/modal (2), full-app smoke (1), telemetry dashboard states (8): waiting/live/attention/collecting/offline rendering, snapshot JSON parsing, and JWT-header request paths via a faked HTTP backend.

---

## 9. Known Limitations

* Telemetry reaches the dashboard only while the backend (and Mosquitto + the AI/ML processor) are running; there is deliberately no cached/fake offline telemetry.
* Full AI analyses require ~145 distinct readings (≈24 h at 10-minute sampling) per the existing AI/ML feature builder; until then the UI shows collection progress.
* `PUBLIC_VERIFY_URL` currently defaults to a temporary trycloudflare tunnel host in `AppConstants` — set a stable host for production QR payloads.
