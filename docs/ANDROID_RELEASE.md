# HoneyChain Android Release Guide

## Prerequisites
- Flutter SDK 3.47.2+
- Android SDK 34+
- Java JDK 17+

## 1. Environment & Backend Configuration
Configure the production backend URL using Flutter compile-time definitions (`--dart-define`):

```bash
cd mobile_app
flutter build apk --release --dart-define=BACKEND_URL=https://api.honeychain.io
```

## 2. Generating Release Keystore
Generate a signing keystore for production Android builds:
```bash
keytool -genkey -v -keystore android/app/honeychain-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias honeychain
```

Configure `android/key.properties`:
```properties
storePassword=<STORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=honeychain
storeFile=honeychain-release.jks
```

## 3. Building App Bundle (AAB) & APK
For Google Play Store distribution:
```bash
flutter build appbundle --release --dart-define=BACKEND_URL=https://api.honeychain.io
```

For direct APK distribution:
```bash
flutter build apk --release --split-per-abi --dart-define=BACKEND_URL=https://api.honeychain.io
```

The output artifacts will be available in `build/app/outputs/flutter-apk/`.
