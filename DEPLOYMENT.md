# 📱 SoilSmart Deployment Checklist

## Pre-Deployment

### ✅ Code Complete
- [x] All screens implemented
- [x] All providers/services complete
- [x] Firebase integration done
- [x] Navigation routes configured
- [x] Theme and branding applied
- [x] Error handling in place

### 🔧 Configuration

#### Firebase Setup
- [ ] Create Firebase project (free Spark plan)
- [ ] Enable Authentication (Email/Password)
- [ ] Enable Cloud Firestore
- [ ] Enable Cloud Storage
- [ ] Enable Cloud Messaging (FCM)
- [ ] Configure Firestore security rules
- [ ] Configure Storage security rules
- [ ] Import default_crops.json to Firestore

#### FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
cd SoilSmart
flutterfire configure
```

### 📝 Branding & Assets

- [ ] Add app logo to `assets/images/logo.png`
- [ ] Update app name in `pubspec.yaml`
- [ ] Update Android package name in `android/app/build.gradle`
- [ ] Update iOS bundle ID in Xcode
- [ ] Create launcher icons (use flutter_launcher_icons package)
- [ ] Create splash screen (use flutter_native_splash package)

### 🧪 Testing

#### Functional Testing
- [ ] User registration works
- [ ] User login/logout works
- [ ] Soil sample submission saves to Firestore
- [ ] Crop recommendations display correctly
- [ ] Market prices fetch from USDA API
- [ ] Maintenance tasks CRUD operations work
- [ ] Bluetooth scanning works (on real device)
- [ ] File upload works (if testing Phase 2)

#### Platform Testing
- [ ] Android emulator
- [ ] Android physical device
- [ ] iOS simulator
- [ ] iOS physical device (requires Apple Developer account)
- [ ] Web browser (Chrome/Edge/Safari)

#### Edge Cases
- [ ] Network offline behavior
- [ ] Empty states display correctly
- [ ] Error messages are user-friendly
- [ ] Loading indicators show during async operations
- [ ] Firebase quota limits handled gracefully

### 🔒 Security Review

- [ ] Firestore rules tested (use Firebase emulator suite)
- [ ] Storage rules tested
- [ ] No API keys hardcoded (except Firebase config)
- [ ] User data properly isolated by userId
- [ ] Auth state changes handled correctly

## Android Deployment

### 1. Update Build Configuration

`android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.yourcompany.soilsmart"  // ← Change this
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

### 2. Configure Signing

`android/key.properties` (create file, add to .gitignore):
```
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

Generate keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Update `android/app/build.gradle` to use signing config.

### 3. Build Release APK/AAB

```bash
flutter build apk --release          # APK for sideloading
flutter build appbundle --release    # AAB for Play Store
```

### 4. Google Play Console

- [ ] Create app listing
- [ ] Upload screenshots (phone + tablet)
- [ ] Write app description
- [ ] Set content rating
- [ ] Configure pricing (free)
- [ ] Upload AAB to internal testing track
- [ ] Test internal release
- [ ] Promote to production

## iOS Deployment

### 1. Xcode Configuration

Open `ios/Runner.xcworkspace` in Xcode:
- [ ] Set bundle ID: `com.yourcompany.soilsmart`
- [ ] Set version: 1.0.0
- [ ] Set build number: 1
- [ ] Configure signing (requires Apple Developer account)
- [ ] Add app icon
- [ ] Configure Info.plist permissions

### 2. Build Archive

```bash
flutter build ios --release
```

Or in Xcode: Product → Archive

### 3. App Store Connect

- [ ] Create app record
- [ ] Upload build via Xcode or Transporter
- [ ] Add screenshots (iPhone + iPad)
- [ ] Write app description
- [ ] Set keywords
- [ ] Configure pricing (free)
- [ ] Submit for review

**Note**: Apple review takes 1-3 days typically.

## Web Deployment

### 1. Build Web Version

```bash
flutter build web --release
```

Output: `build/web/`

### 2. Firebase Hosting (Recommended)

```bash
firebase login
firebase init hosting
firebase deploy
```

Or use:
- GitHub Pages
- Netlify
- Vercel
- AWS S3 + CloudFront

### 3. Configure CORS (if using external APIs)

Ensure Firebase Storage CORS allows your web domain.

## Post-Deployment

### Monitoring

- [ ] Set up Firebase Crashlytics (optional)
- [ ] Monitor Firestore usage in Firebase Console
- [ ] Track app analytics (Firebase Analytics)
- [ ] Monitor USDA API response times

### User Support

- [ ] Create support email/contact form
- [ ] Prepare FAQ document
- [ ] Monitor app store reviews
- [ ] Set up bug reporting system

### Marketing

- [ ] Create landing page
- [ ] Social media announcement
- [ ] Submit to agricultural tech blogs/forums
- [ ] Reach out to farming communities
- [ ] Create demo video/screenshots

## Free Tier Limits

**Firebase Spark Plan** (monthly):
- Firestore: 1 GB storage, 50k reads/day, 20k writes/day
- Storage: 5 GB, 1 GB downloads/day
- Auth: Unlimited users
- Hosting: 10 GB transfer

**USDA AMS API**:
- No official rate limit
- Use reasonable caching

### Upgrade Triggers
- If exceeding daily read/write limits
- If need >5 GB storage
- If need advanced Firebase features

Upgrade to **Blaze** (pay-as-you-go) - very affordable for small apps.

## Version Bumping

For future updates:

1. Update `pubspec.yaml`: `version: 1.0.1+2`
2. Update Android: `versionCode` and `versionName`
3. Update iOS: Version and Build number in Xcode
4. Update CHANGELOG.md
5. Rebuild and redeploy

---

## Quick Commands Reference

```bash
# Setup
flutter pub get
flutterfire configure

# Development
flutter run
flutter run -d chrome  # web
flutter run -d <device-id>

# Testing
flutter test
flutter analyze

# Building
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web --release

# Cleaning
flutter clean
flutter pub get

# Firebase
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

---

**Status**: Ready for deployment! 🚀

Complete all checklist items, then launch to app stores and Firebase Hosting.
