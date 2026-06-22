# SoilSmart API Documentation

## Overview

SoilSmart uses a combination of Firebase services and external APIs to provide
comprehensive soil analysis, crop recommendations, and market intelligence.

## Firebase Services

### Authentication
**Provider**: Firebase Auth  
**Endpoint**: Managed by Firebase SDK  
**Authentication Methods**:
- Email/Password
- (Future: Google, Apple, Facebook)

#### Methods

**Sign Up**
```dart
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
);
```

**Sign In**
```dart
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

**Sign Out**
```dart
await FirebaseAuth.instance.signOut();
```

**Password Reset**
```dart
await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
```

---

### Cloud Firestore

**Database**: NoSQL document database  
**Endpoint**: Managed by Firebase SDK  
**Collections**:

#### 1. `crops`
Stores default and custom crop data.

**Document Structure**:
```json
{
  `"id`": `"corn`",
  `"name`": `"Corn`",
  `"category`": `"Grain`",
  `"phMin`": 5.8,
  `"phMax`": 7.0,
  `"nitrogenNeed`": 150,
  `"phosphorusNeed`": 60,
  `"potassiumNeed`": 120,
  `"tempMinF`": 50,
  `"tempMaxF`": 95,
  `"wateringFrequency`": `"Weekly`",
  `"plantingWindow`": `"April – June`",
  `"harvestWindow`": `"August – October`",
  `"companionPlants`": [`"Beans`", `"Squash`"],
  `"pestRisks`": [`"Corn earworm`", `"Aphids`"],
  `"isCustom`": false,
  `"userId`": null
}
```

**CRUD Operations**:
```dart
// Create
await FirebaseFirestore.instance.collection('crops').add(cropData);

// Read
final snapshot = await FirebaseFirestore.instance.collection('crops').get();

// Update
await FirebaseFirestore.instance.collection('crops').doc(id).update(cropData);

// Delete
await FirebaseFirestore.instance.collection('crops').doc(id).delete();
```

#### 2. `soil_samples`
User-specific soil test results.

**Document Structure**:
```json
{
  `"userId`": `"user_id_here`",
  `"timestamp`": `"2026-06-08T12:00:00Z`",
  `"ph`": 6.5,
  `"nitrogen`": 100,
  `"phosphorus`": 50,
  `"potassium`": 120,
  `"moisture`": 25,
  `"electricalConductivity`": 1.2,
  `"organicMatter`": 3.5,
  `"texture`": `"Loam`",
  `"notes`": `"Field A, north section`",
  `"location`": {`"lat`": 40.7128, `"lng`": -74.0060},
  `"deficiencies`": [`"Low Phosphorus`"],
  `"healthScore`": 78
}
```

#### 3. `maintenance_tasks`
Farm maintenance and scheduling.

**Document Structure**:
```json
{
  `"userId`": `"user_id_here`",
  `"title`": `"Fertilize Field A`",
  `"description`": `"Apply NPK 15-15-15`",
  `"category`": `"Fertilizing`",
  `"dueDate`": `"2026-06-15T09:00:00Z`",
  `"completed`": false,
  `"fieldLocation`": `"Field A`",
  `"createdAt`": `"2026-06-08T12:00:00Z`"
}
```

---

### Cloud Storage

**Service**: Firebase Storage  
**Endpoint**: Managed by Firebase SDK  
**Use Cases**: Soil report PDFs, CSVs, field photos

**Upload Example**:
```dart
final ref = FirebaseStorage.instance
    .ref('users/\/soil_reports/\');
await ref.putFile(file);
final downloadUrl = await ref.getDownloadURL();
```

---

### Cloud Messaging (FCM)

**Service**: Firebase Cloud Messaging  
**Use Cases**: Price alerts, task reminders, crop recommendations

**Setup** (already in `lib/services/notification_service.dart`):
```dart
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission();
final token = await messaging.getToken();
```

---

## External APIs

### USDA Agricultural Marketing Service (AMS)

**Official Name**: USDA Market News API  
**Base URL**: `https://marsapi.ams.usda.gov/services/v1.2`  
**Authentication**: None (public endpoint)  
**Rate Limit**: Reasonable use (no official limit)  
**Cost**: Free

#### Endpoints

**1. Search Reports**
```
GET /reports?q={cropName}&allSections=true
```

**Parameters**:
- `q` (string): Commodity name (e.g., `"Corn"`, `"Soybeans"`)
- `allSections` (boolean): Include all report sections
- `marketLocationState` (string): Two-letter state code (e.g., `"IA"`)

**Example Request**:
```bash
curl `"https://marsapi.ams.usda.gov/services/v1.2/reports?q=Corn&marketLocationState=IA&allSections=true`"
```

**Response Structure**:
```json
{
  `"results`": [
    {
      `"slug_id`": `"12345`",
      `"report_title`": `"Iowa Daily Grain Reports`",
      `"published_date`": `"2026-06-08`",
      `"market_types`": [`"Grain`"],
      `"offices`": [`"Des Moines`"],
      `"report_begin_date`": `"2026-06-08`",
      `"report_end_date`": `"2026-06-08`"
    }
  ],
  `"count`": 1
}
```

**2. Get Report Details**
```
GET /reports/{slug_id}
```

**Response**: Full report with pricing data (structure varies by report type)

#### Implementation

See `lib/services/market_service.dart`:
```dart
Future<List<MarketPrice>> fetchLocalPrices(String cropName) async {
  final uri = Uri.parse('\=\&allSections=true');
  final response = await http.get(uri);
  // Parse response...
}
```

#### Data Coverage
- **Crops**: Corn, soybeans, wheat, barley, oats, rice, peanuts, cotton
- **Fruits**: Apples, oranges, berries, grapes, melons
- **Vegetables**: Tomatoes, lettuce, potatoes, onions, carrots
- **Regions**: All US states, major terminal markets

#### Caching Strategy
- Cache prices for 1-4 hours (crop-dependent)
- Store in Firestore or local storage
- Refresh on user request

---

## Data Models

### Crop
```dart
class Crop {
  final String id;
  final String name;
  final String category;
  final double phMin;
  final double phMax;
  final double nitrogenNeed;
  final double phosphorusNeed;
  final double potassiumNeed;
  final double tempMinF;
  final double tempMaxF;
  final String wateringFrequency;
  final String? plantingWindow;
  final String? harvestWindow;
  final List<String> companionPlants;
  final List<String> pestRisks;
  final bool isCustom;
  final String? userId;
  
  double compatibilityScore(double ph, double n, double p, double k) {
    // Scoring algorithm in model
  }
}
```

### SoilSample
```dart
class SoilSample {
  final String id;
  final String userId;
  final DateTime timestamp;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double? moisture;
  final double? electricalConductivity;
  final double? organicMatter;
  final String texture;
  final String? notes;
  final GeoPoint? location;
  final List<String> deficiencies;
  final double healthScore;
}
```

### MarketPrice
```dart
class MarketPrice {
  final String id;
  final String cropName;
  final double price;
  final String unit;
  final String market;
  final String state;
  final DateTime date;
  final String source;
}
```

---

## State Management (Provider)

### AuthProvider
```dart
context.read<AuthProvider>().signIn(email, password);
context.read<AuthProvider>().signOut();
context.watch<AuthProvider>().isLoggedIn;
```

### SoilProvider
```dart
context.read<SoilProvider>().addSample(sample);
context.watch<SoilProvider>().samples;
context.watch<SoilProvider>().latestSample;
```

### CropProvider
```dart
context.read<CropProvider>().loadCrops();
context.watch<CropProvider>().recommendations;
context.watch<CropProvider>().allCrops;
```

### MarketProvider
```dart
context.read<MarketProvider>().fetchPrices(cropName);
context.watch<MarketProvider>().prices;
```

---

## Error Handling

All async operations return `Future<String?>` where:
- `null` = success
- `String` = error message

Example:
```dart
final error = await authProvider.signIn(email, password);
if (error != null) {
  // Show error to user
}
```

---

## Offline Support (Phase 5)

**Current**: Online-only  
**Future**: 
- Local SQLite cache for soil samples and crops
- Queue write operations when offline
- Sync when connection restored

---

## Security

### Firestore Rules
See `firestore.rules` for complete security rules.

**Key Principles**:
- Users can only read/write their own data
- Crops collection is read-public, write-authenticated
- Custom crops linked to userId

### Storage Rules
See `storage.rules` for file upload security.

**Key Principles**:
- User-specific folders (`/users/{userId}/`)
- File size limits (10 MB for reports, 5 MB for images)
- Content type validation

---

## Rate Limits & Quotas

### Firebase Free Tier (Spark Plan)
- **Firestore**: 50k reads, 20k writes per day
- **Storage**: 5 GB storage, 1 GB downloads/day
- **Auth**: Unlimited users
- **FCM**: Unlimited messages

### USDA AMS API
- **Rate Limit**: None officially documented
- **Best Practice**: Cache responses, use reasonable request frequency

---

## Testing APIs

### Firestore Emulator
```bash
firebase emulators:start
```

### USDA API Testing
Use Postman or curl:
```bash
curl `"https://marsapi.ams.usda.gov/services/v1.2/reports?q=Corn`"
```

---

## Support & Resources

- **Firebase Docs**: https://firebase.google.com/docs
- **USDA AMS API**: https://marsapi.ams.usda.gov/
- **Flutter Docs**: https://docs.flutter.dev/
- **FlutterFire**: https://firebase.flutter.dev/

---

**Last Updated**: 2026-06-08  
**Version**: 1.0.0
