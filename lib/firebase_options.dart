// GENERATED FILE — Replace with your own Firebase project config.
// Run: flutterfire configure
// (requires FlutterFire CLI: dart pub global activate flutterfire_cli)
//
// Steps:
// 1. Create a free Firebase project at https://console.firebase.google.com
// 2. Install FlutterFire CLI: dart pub global activate flutterfire_cli
// 3. Run: flutterfire configure
// 4. This file will be auto-generated and replace this placeholder.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run: flutterfire configure',
        );
    }
  }

  // Replace all values below with your actual Firebase project config.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBF1rXPu-eRI0InCQKdFX7auG09L7pcPXE',
    appId: '1:1000027219280:web:ee4206784ebc5f71b13855',
    messagingSenderId: '1000027219280',
    projectId: 'soilsampleapp1',
    storageBucket: 'soilsampleapp1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBF1rXPu-eRI0InCQKdFX7auG09L7pcPXE',
    appId: '1:1000027219280:android:ee4206784ebc5f71b13855',
    messagingSenderId: '1000027219280',
    projectId: 'soilsampleapp1',
    storageBucket: 'soilsampleapp1.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDjyPu-SZFhdHi_DX51RdCjkToFN-L_Na4',
    appId: '1:1000027219280:ios:f67628ba4289d711b13855',
    messagingSenderId: '1000027219280',
    projectId: 'soilsampleapp1',
    storageBucket: 'soilsampleapp1.firebasestorage.app',
    iosClientId: '1000027219280-0mohfj93otmqet29bipjjsb7u3iv5omd.apps.googleusercontent.com',
    iosBundleId: 'com.gardenergrid.gardenergrid',
  );
}
