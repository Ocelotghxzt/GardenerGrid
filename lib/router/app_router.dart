import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/soil/soil_input_screen.dart';
import '../screens/soil/soil_history_screen.dart';
import '../screens/crops/crop_recommendations_screen.dart';
import '../screens/crops/add_crop_screen.dart';
import '../screens/crops/crop_detail_screen.dart';
import '../screens/maintenance/maintenance_screen.dart';
import '../screens/market/market_dashboard_screen.dart';
import '../screens/bluetooth/bluetooth_screen.dart';
import '../screens/encyclopedia/encyclopedia_screen.dart';
import '../screens/encyclopedia/library_mode_screen.dart';
import '../screens/ai/ai_assistant_screen.dart';
import '../screens/almanac/almanac_screen.dart';
import '../screens/plant_id/plant_id_screen.dart';
import '../screens/mesh/mesh_chat_screen.dart';
import '../screens/mesh/mesh_marketplace_screen.dart';
import '../screens/bluetooth/mesh_settings_screen.dart';

/// Creates the app router wired to [auth] so that any change in auth state
/// (login, logout, or the initial Firebase session restore) automatically
/// re-evaluates the redirect.
GoRouter makeRouter(AuthProvider auth) => GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        // Wait until Firebase has resolved the persisted auth state.
        if (auth.isLoading) return null;

        final hasSession = auth.isLoggedIn;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!hasSession && !isAuthRoute) return '/login';
        if (hasSession && isAuthRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/soil/input', builder: (_, __) => const SoilInputScreen()),
        GoRoute(
            path: '/soil/history', builder: (_, __) => const SoilHistoryScreen()),
        GoRoute(
            path: '/crops',
            builder: (_, __) => const CropRecommendationsScreen()),
        GoRoute(path: '/crops/add', builder: (_, __) => const AddCropScreen()),
        GoRoute(
          path: '/crops/detail/:id',
          builder: (_, state) =>
              CropDetailScreen(cropId: state.pathParameters['id']!),
        ),
        GoRoute(
            path: '/maintenance',
            builder: (_, __) => const MaintenanceScreen()),
        GoRoute(
            path: '/market', builder: (_, __) => const MarketDashboardScreen()),
        GoRoute(
            path: '/bluetooth', builder: (_, __) => const BluetoothScreen()),
        GoRoute(
            path: '/bluetooth/mesh-settings',
            builder: (_, __) => const MeshSettingsScreen()),
        GoRoute(
            path: '/encyclopedia', builder: (_, __) => const EncyclopediaScreen()),
        GoRoute(
            path: '/encyclopedia/library', builder: (_, __) => const LibraryModeScreen()),
        GoRoute(
          path: '/encyclopedia/plant/:id',
          builder: (_, state) =>
              PlantDetailScreen(plantId: state.pathParameters['id']!),
        ),
        GoRoute(
            path: '/ai', builder: (_, __) => const AiAssistantScreen()),
        GoRoute(
            path: '/almanac', builder: (_, __) => const AlmanacScreen()),
        GoRoute(
            path: '/plant-id', builder: (_, __) => const PlantIdScreen()),
        GoRoute(
            path: '/mesh/chat', builder: (_, __) => const MeshChatScreen()),
        GoRoute(
            path: '/mesh/market', builder: (_, __) => const MeshMarketplaceScreen()),
      ],
    );
