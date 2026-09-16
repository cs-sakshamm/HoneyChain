# HoneyChain — Cross-Platform Flutter Mobile Application

The HoneyChain mobile app provides a unified, role-based user experience for all stakeholders across the honey supply chain: beekeepers, regional collection hubs, quality testing laboratories, packaging facilities, and retail consumers.

---

## 1. Technical Overview

* **Framework:** Flutter (Dart SDK `>=3.0.0 <4.0.0`)
* **State Management:** Provider pattern (`provider: ^6.1.2`)
* **Networking:** HTTP REST client (`http: ^1.6.0`) communicating with the FastAPI backend
* **Authentication:** Role-based authentication with Firebase Auth (`firebase_auth: ^5.5.1`) & Google Sign-In (`google_sign_in: ^6.2.2`)
* **QR Rendering:** `qr_flutter: ^4.1.0` for generating dynamic high-density QR codes
* **Supported Platforms:** Android (API 21+), iOS (12.0+), and Web (Chrome/Edge/Safari)

---

## 2. Directory Structure

```text
mobile_app/
├── lib/
│   ├── main.dart                                # Application bootstrap, theme configuration, & Provider setup
│   ├── core/                                    # Shared application core
│   │   ├── constants/                           # AppConstants (API endpoints, route names, colors)
│   │   ├── controllers/                         # TelemetryAlertController, WorkflowController
│   │   ├── localization/                        # Multi-language localization utilities
│   │   ├── models/                              # HiveAlertModel, UserSessionModel
│   │   ├── services/                            # Local storage & shared preferences
│   │   ├── theme/                               # HoneyChain gold/dark amber theme & typography
│   │   ├── utils/                               # Formatters, validators, & date parsers
│   │   └── widgets/                             # Global reusable widgets (AppBar, AppLogo, StatusBadge, EmptyState)
│   │
│   └── features/                                # Feature modules by functional domain
│       ├── authentication/                      # Login, signup, role selection, & OAuth buttons
│       ├── hives/                               # Harvester dashboard, hive cards, telemetry charts, & alerts
│       ├── collection/                          # Collector dashboard, batch timeline, nearest centres, & requests
│       ├── lab/                                 # Lab tester dashboard, sample testing, reports, & certificates
│       ├── packaging/                           # Packaging dashboard, jar batching, & QR code screens
│       ├── verification/                        # Role verification models & public QR verification lookup
│       ├── profile/                             # User profile, edit screens, KYC verification, & settings
│       ├── notifications/                       # Critical hive anomaly alert modals
│       └── navigation/                          # Main bottom navigation & drawer controllers
│
├── assets/images/                               # Vector assets, logos, and illustration graphics
├── pubspec.yaml                                 # Flutter dependencies and asset configuration
├── .gitignore                                   # Ignore rules for Flutter, Dart, Android, and iOS artifacts
├── README.md                                    # Mobile app documentation (this file)
└── REQUIREMENT.txt                              # Flutter SDK and package requirements
```

---

## 3. Role-Based Dashboards & Workflows

### 1. Harvester / Beekeeper
* **Hive Monitoring:** View live hive cards with real-time temperature (°C), humidity (%), weight (kg), and acoustic frequency (Hz).
* **AI Telemetry Alerts:** Immediate visual warnings when the backend AI flags anomalies (thermal stress, high humidity, swarming risks).
* **Harvest Recording:** Start a harvest session, select the target hive, record harvested weight (kg), and specify floral source (Mustard, Acacia, Multifloral).
* **Collection Requests:** Create collection requests, select preferred nearby collection hubs with GPS distance calculation, and track acceptance status.

### 2. Collection Centre / Collector
* **Incoming Queue:** View pending collection requests submitted by registered harvesters.
* **Batch Aggregation:** Verify raw honey weights, inspect moisture, accept batches, and aggregate multiple harvests into consolidated collection batches.
* **Timeline Tracking:** Inspect batch history and verify collector cryptographic signatures.

### 3. Quality Testing Laboratory
* **Sample Testing:** Receive batches and log official laboratory metrics:
  * Moisture Content (%)
  * Pollen Count
  * Hydroxymethylfurfural (HMF in mg/kg)
  * Purity Score (0–100)
  * C4 Adulteration Test (Negative/Positive)
* **Lab Certification:** Assign quality grades (Grade A / Premium, Grade B, Grade C) and issue digitally signed certificates linked to on-chain hashes.

### 4. Packaging Facility
* **Packaging Batches:** Package refined, certified honey into standardized retail containers (250g, 500g, 1000g).
* **QR Generation:** Generate individual and batch QR codes using `qr_flutter` linking directly to the public traceability portal.

### 5. Public Consumer Verification
* **Public QR Scanner / Lookup:** Any consumer can scan a physical jar QR code or manually enter a batch code to view the complete provenance trail from apiary to shelf.

---

## 4. API Configuration & Backend Integration

The mobile application connects to the central FastAPI backend. The base URL is configured in `lib/core/constants/app_constants.dart`:

```dart
class AppConstants {
  // Use http://10.0.2.2:8000 for Android Emulator
  // Use http://localhost:8000 for Web (Chrome)
  // Use http://<YOUR_LAN_IP>:8000 for physical mobile devices
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
```

---

## 5. Build & Run Instructions

### Prerequisites
* Flutter SDK 3.x installed and added to `PATH` (`flutter doctor` must report no issues)
* Chrome (for Web testing) or Android Studio / Xcode (for mobile emulators)

### Step 1: Install Dependencies

```bash
cd mobile_app
flutter pub get
```

### Step 2: Run in Development Mode

#### Running on Chrome (Web):
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

#### Running on Android Emulator:
```bash
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### Running on Physical Android Device:
Ensure your computer and phone are connected to the same Wi-Fi network, replace `<PC_LAN_IP>` with your machine's local IP (e.g., `192.168.1.105`):
```bash
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://<PC_LAN_IP>:8000
```

---

## 6. Release Build & APK Generation

To generate an optimized release Android APK:

```bash
cd mobile_app
flutter build apk --release --dart-define=API_BASE_URL=https://api.honeychain.io
```

The compiled release APK will be located at:
```text
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

To build a web bundle for production hosting:
```bash
flutter build web --release
```
The output directory will be `mobile_app/build/web`.
