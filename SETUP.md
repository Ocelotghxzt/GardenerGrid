# GardenerGrid - Quick Start Guide

## 🚀 Quick Setup (5 Minutes)

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
3. Run: `cd SoilSmart && flutter pub get` (or your local repo folder)
4. Configure Firebase: `flutterfire configure`
5. Run: `flutter run`

## 📋 Detailed Setup

See README.md for complete architecture and features.

### Firebase Setup
1. Create project: https://console.firebase.google.com
2. Enable Auth (Email/Password), Firestore, Storage, Messaging
3. Import assets/data/default_crops.json to Firestore 'crops' collection

### Firestore Rules
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
    match /crops/{cropId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Storage Rules
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

## 🧪 Testing

1. Register: test@example.com / password123
2. Add soil sample: pH 6.5, N 100, P 50, K 120
3. View crop recommendations
4. Check market prices

## 🔧 Troubleshooting

**Firebase not configured?**
`flutterfire configure`

**No crops showing?**
Import default_crops.json to Firestore

**Build errors?**
`flutter clean && flutter pub get && flutter run`

## 📱 Platform Notes

### Android
- Requires minSdkVersion 21
- BLE permissions in AndroidManifest.xml

### iOS  
- Requires iOS 12.0+
- BLE permissions in Info.plist

### Web
- BLE features not available
- Works with Chrome/Edge/Safari

## 🌟 Key Features

✅ Soil Analysis (manual + upload ready)
✅ AI Crop Recommendations  
✅ USDA Market Pricing (free API)
✅ Bluetooth Sensor Support
✅ Maintenance Scheduling
✅ Firebase Backend (free tier)
✅ iOS + Android + Web

Enjoy growing smarter! 🌱
