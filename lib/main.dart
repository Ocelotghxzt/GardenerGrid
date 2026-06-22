import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/soil_provider.dart';
import 'providers/crop_provider.dart';
import 'providers/market_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/encyclopedia_provider.dart';
import 'providers/ai_assistant_provider.dart';
import 'providers/almanac_provider.dart';
import 'providers/mesh_provider.dart';
import 'services/firestore_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/offline_ai_service.dart';
import 'services/online_ai_service.dart';
import 'services/bluetooth_service.dart';
import 'services/market_service.dart';
import 'services/mesh_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  String? firebaseError;

  try {
    final opts = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: opts);
    await NotificationService().init();
    firebaseReady = true;
  } catch (e) {
    firebaseError = 'Firebase initialisation failed:\n$e';
  }

  runApp(GardenerGridApp(
    firebaseReady: firebaseReady,
    firebaseError: firebaseError,
  ));
}

class GardenerGridApp extends StatefulWidget {
  final bool firebaseReady;
  final String? firebaseError;

  const GardenerGridApp({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  @override
  State<GardenerGridApp> createState() => _GardenerGridAppState();
}

class _GardenerGridAppState extends State<GardenerGridApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Both objects must be created once so the router holds a stable
    // reference to the same AuthProvider instance that Provider exposes.
    _authProvider = AuthProvider();
    _router = makeRouter(_authProvider);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseReady) {
      return MaterialApp(
        title: 'GardenerGrid',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: _FirebaseSetupScreen(message: widget.firebaseError ?? 'Unknown error'),
      );
    }

    final firestoreService = FirestoreService();
    final localStorageService = LocalStorageService();
    final encyclopediaProvider = EncyclopediaProvider(localStorageService);
    final onlineAiService = OnlineAiService();
    final bluetoothService = BluetoothService();
    final meshService = MeshService();
    final marketService = MarketService(localStorage: localStorageService);

    return MultiProvider(
      providers: [
        // Provide the same AuthProvider instance that the router uses.
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(
          create: (_) => SoilProvider(firestoreService, localStorageService),
        ),
        ChangeNotifierProvider(create: (_) => CropProvider(firestoreService)),
        ChangeNotifierProvider(create: (_) => MarketProvider(marketService)),
        ChangeNotifierProvider(
          create: (_) => BluetoothProvider(bluetoothService: bluetoothService),
        ),
        ChangeNotifierProvider<EncyclopediaProvider>.value(
          value: encyclopediaProvider..load(),
        ),
        ChangeNotifierProxyProvider<EncyclopediaProvider, AiAssistantProvider>(
          create: (_) => AiAssistantProvider(onlineAiService),
          update: (_, encyclopedia, aiAssistant) {
            final provider = aiAssistant ?? AiAssistantProvider(onlineAiService);
            if (encyclopedia.plants.isNotEmpty ||
                encyclopedia.foragingEntries.isNotEmpty) {
              provider.setOfflineService(
                OfflineAiService(
                  plants: encyclopedia.plants,
                  foraging: encyclopedia.foragingEntries,
                ),
              );
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => MeshProvider(
            meshService,
            localStorageService,
            bluetoothService: bluetoothService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => AlmanacProvider()),
      ],
      child: MaterialApp.router(
        title: 'GardenerGrid',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Shown when Firebase credentials are missing or invalid so the developer
/// (or user in production) sees a clear error rather than a crash.
class _FirebaseSetupScreen extends StatelessWidget {
  final String message;
  const _FirebaseSetupScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Firebase Setup Required',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

