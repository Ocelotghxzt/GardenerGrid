# GardenerGrid

A cross-platform Flutter app (iOS & Android) for soil analysis, crop recommendations,
maintenance scheduling, market pricing, and Bluetooth sensor integration — for USA farmers,
with internationalization-ready architecture for worldwide expansion.

## Free Stack (No Server Required)
| Service | Why |
|---|---|
| Flutter | Single codebase, great iOS + Android UI |
| Firebase Auth | Free user accounts (Spark plan) |
| Cloud Firestore | Free NoSQL database (Spark plan) |
| Firebase Storage | Free file uploads (Spark plan) |
| Firebase Messaging | Free push notifications |
| USDA AMS API | Free public market price data |
| flutter_blue_plus | Generic BLE — works with any sensor |

## Firebase Free Tier Limits (Spark Plan)
- Firestore: 1 GB storage, 50k reads/day, 20k writes/day
- Storage: 5 GB
- Auth: Unlimited users
- Hosting: 10 GB/month

More than sufficient for development and early farm users.

## Setup

### 1. Install Flutter
https://docs.flutter.dev/get-started/install

### 2. Create a Firebase Project
1. Go to https://console.firebase.google.com
2. Create a new project (free Spark plan)
3. Enable: Authentication (Email/Password), Firestore, Storage, Cloud Messaging

### 3. Configure Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This replaces `lib/firebase_options.dart` with your real config.

### 4. Seed Default Crops
In Firestore console, import `assets/data/default_crops.json` into a `crops` collection.
Or add a one-time seed function using the Firebase Admin SDK.

### 5. Run the App
```bash
flutter pub get
flutter run
```

## Project Structure
```
lib/
  main.dart                   # App entry point, provider setup
  firebase_options.dart       # Firebase config (replace with flutterfire configure)
  theme/app_theme.dart        # App-wide colors, typography, component styles
  router/app_router.dart      # GoRouter navigation
  models/                     # Data models (Firestore serialization)
  services/                   # Business logic, API calls, BLE
  providers/                  # State management (Provider pattern)
  screens/
    auth/                     # Login, Register
    home_screen.dart          # Dashboard
    soil/                     # Soil input + history + charts
    crops/                    # Recommendations, detail, add custom crop
    maintenance/              # Task list, add task
    market/                   # USDA price dashboard + alerts
    bluetooth/                # BLE scan, connect, mesh node placeholder
  widgets/                    # Reusable UI components
assets/
  data/default_crops.json     # Default US crop database seed
```

## Bluetooth / Sensor Support
- Works with **any generic BLE sensor** using standard GATT characteristics
- Sensor UUID mapping is in `lib/services/bluetooth_service.dart` — extend per device
- **Mesh node integration** is stubbed and ready to build:
  - `IMeshNodeService` interface in `bluetooth_service.dart`
  - `MeshNode` model in `lib/models/mesh_node.dart`
  - Reserved UI section in the Bluetooth screen
  - Provide hardware specs to complete the mesh implementation

## Market Data
Powered by the **USDA Agricultural Marketing Service (AMS) Market News API** — 100% free,
no API key required for public endpoints.
- Endpoint: `https://marsapi.ams.usda.gov/services/v1.2/reports`
- Covers: local farmers market prices, terminal market prices, by crop and state

## Internationalization
- All strings use Flutter's standard `intl` package infrastructure
- Region/state code is captured at login for market data filtering
- USA is the initial market; worldwide expansion is architecture-ready

## Roadmap
- [ ] Phase 1: Core soil + crops + Firebase (current)
- [ ] Phase 2: PDF/CSV OCR lab report parsing, Wi-Fi/MQTT sensor support
- [ ] Phase 3: Market profitability estimator, price alert push notifications
- [ ] Phase 4: Bluetooth mesh node full implementation (pending hardware specs)
- [ ] Phase 5: Offline mode, App Store + Play Store launch

## Website + Web App Deployment

This repository now includes:

- Professional marketing website at `website/`
- Flutter web app under `webapp/` path when deployed
- GitHub Pages workflow: `.github/workflows/pages-site-and-webapp.yml`

### How it deploys

1. Builds Flutter web with `flutter build web --release --base-href /webapp/`
2. Publishes `website/` as the root site
3. Publishes Flutter web app at `/webapp/`

### Enable GitHub Pages

1. In GitHub repo settings, open Pages.
2. Set Source to GitHub Actions.
3. Push to `main` (or run the workflow manually).

## Zero-Touch Automation

This repo now includes hands-off automation in GitHub Actions:

- `.github/workflows/pages-site-and-webapp.yml`
  - Auto-deploys professional site + Flutter web app to GitHub Pages on every push to `main`
- `.github/workflows/autopilot-builds.yml`
  - Runs analyze + tests automatically on pull requests and pushes to `main`
  - Builds Android APK + AAB automatically
  - Builds Flutter web bundle automatically
  - Uploads build artifacts to each workflow run

### One-time setup required (then no manual intervention)

1. Enable GitHub Actions for the repository.
2. Enable GitHub Pages with source set to GitHub Actions.
3. Keep working on `main` (or merge PRs to `main`) and automation will run end-to-end.

## iPhone-Compatible Build Pipeline

Windows cannot produce an IPA directly, so the repo includes macOS CI workflow:

- `.github/workflows/ios-build.yml`

This workflow provides two jobs:

- `ios-unsigned`: builds iOS app bundle without codesigning
- `ios-signed-ipa`: builds signed IPA when required secrets are present

### Required secrets for signed IPA

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`
- `IOS_BUNDLE_ID`
- `APPLE_TEAM_ID`
- Optional: `IOS_EXPORT_METHOD` (`app-store`, `ad-hoc`, `development`, etc.)

After these are configured, run the iOS workflow from Actions to generate IPA artifacts.
