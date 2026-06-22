import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/soil_provider.dart';
import '../providers/crop_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/soil_health_gauge.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final uid = auth.userId;
      if (uid != null) {
        context.read<SoilProvider>().loadField(uid, 'default');
        context.read<CropProvider>().loadCrops(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final soil = context.watch<SoilProvider>();
    final crops = context.watch<CropProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GardenerGrid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final router = GoRouter.of(context);
              await auth.signOut();
              if (!mounted) return;
              router.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.userId != null) {
            await crops.loadCrops(auth.userId!);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Welcome, ${auth.displayName}!',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Your field at a glance',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.forest, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Botany, soil, foraging & mesh tools',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use soil readings to guide crops, explore the encyclopedia, chat with AI, and coordinate with nearby growers.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Soil health
            if (soil.latestSample != null && soil.latestSample!.healthScore != null)
              SoilHealthGauge(score: soil.latestSample!.healthScore!)
            else
              _QuickActionCard(
                icon: Icons.science,
                title: 'Add Your First Soil Sample',
                subtitle: 'Get crop recommendations instantly',
                onTap: () => context.push('/soil/input'),
              ),
            const SizedBox(height: 20),

            // Quick actions grid
            const SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _QuickActionCard(
                  icon: Icons.science,
                  title: 'Soil Sample',
                  subtitle: 'Add or upload',
                  onTap: () => context.push('/soil/input'),
                ),
                _QuickActionCard(
                  icon: Icons.eco,
                  title: 'Crops',
                  subtitle: '${crops.recommendations.length} recommended',
                  onTap: () => context.push('/crops'),
                ),
                _QuickActionCard(
                  icon: Icons.calendar_today,
                  title: 'Maintenance',
                  subtitle: 'Tasks & schedules',
                  onTap: () => context.push('/maintenance'),
                ),
                _QuickActionCard(
                  icon: Icons.trending_up,
                  title: 'Market Prices',
                  subtitle: 'Local & national',
                  onTap: () => context.push('/market'),
                ),
                _QuickActionCard(
                  icon: Icons.bluetooth,
                  title: 'BLE Sensors',
                  subtitle: 'Connect device',
                  onTap: () => context.push('/bluetooth'),
                ),
                _QuickActionCard(
                  icon: Icons.history,
                  title: 'Soil History',
                  subtitle: 'View trends',
                  onTap: () => context.push('/soil/history'),
                ),
                _QuickActionCard(
                  icon: Icons.menu_book,
                  title: 'Encyclopedia',
                  subtitle: 'Plants & foraging',
                  onTap: () => context.push('/encyclopedia'),
                ),
                _QuickActionCard(
                  icon: Icons.auto_awesome,
                  title: 'AI Assistant',
                  subtitle: 'Online or offline',
                  onTap: () => context.push('/ai'),
                ),
                _QuickActionCard(
                  icon: Icons.forum,
                  title: 'Mesh Chat',
                  subtitle: 'Local farmer channels',
                  onTap: () => context.push('/mesh/chat'),
                ),
                _QuickActionCard(
                  icon: Icons.storefront,
                  title: 'Local Market',
                  subtitle: 'Farmer exchange',
                  onTap: () => context.push('/mesh/market'),
                ),
                _QuickActionCard(
                  icon: Icons.brightness_7,
                  title: 'Almanac',
                  subtitle: 'Moon phases & frost',
                  onTap: () => context.push('/almanac'),
                ),
                _QuickActionCard(
                  icon: Icons.camera_alt,
                  title: 'Plant ID',
                  subtitle: 'Identify species',
                  onTap: () => context.push('/plant-id'),
                ),
              ],
            ),

            // Latest deficiencies
            if (soil.latestSample != null &&
                soil.latestSample!.deficiencies.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: 'Active Soil Alerts'),
              const SizedBox(height: 8),
              ...soil.latestSample!.deficiencies.map((d) => Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: AppTheme.accent),
                      title: Text(d),
                      dense: true,
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const Spacer(flex: 1),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
