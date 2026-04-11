import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../models/property.dart';
import '../maintenance/screens/maintenance_list_screen.dart';
import '../property/screens/add_property_screen.dart';
import '../property/screens/property_detail_screen.dart';
import '../org/create_org_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/screens/finance_dashboard_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String? _displayName;
  String? _organizationId;
  String? _organizationName;
  List<Property> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadDashboardData() async {
    try {
      final authState = ref.read(authProvider).value;
      final displayName = authState?.displayName ?? 'Landlord';
      final orgId = authState?.profile?.organizationId;

      setState(() {
        _displayName = displayName;
        _organizationId = orgId;
        _organizationName = orgId == null ? null : 'Your Organization';
        _properties = const [];
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _displayName = 'Landlord';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load dashboard data: $error',
              style: const TextStyle(fontFamily: AppTheme.appFontFamily),
            ),
          ),
        );
      }
    }
  }

  Widget _buildPropertiesTab(String displayName) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Text(
                      'Welcome to ${_organizationName ?? 'Your Organization'}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.appFontFamily,
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Center(
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: AppTheme.appFontFamily,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _properties.isEmpty
                  ? Center(
                      child: Text(
                        'No plots yet. Tap "Add New Plot" to start.',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontFamily: AppTheme.appFontFamily),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _properties.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final property = _properties[index];

                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 20, end: 0),
                          duration: Duration(milliseconds: 320 + (index * 55)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, value),
                              child: Opacity(
                                opacity: ((20 - value) / 20).clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: Card(
                            child: ListTile(
                              title: Text(
                                property.name,
                                style: const TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                property.location ?? 'No location set',
                                style: const TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 20),
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PropertyDetailScreen(property: property),
                                  ),
                                );
                                await _loadDashboardData();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_organizationId != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryColor,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddPropertyScreen(
                        organizationId: _organizationId!,
                      ),
                    ),
                  );

                  if (!mounted) return;
                  if (created == true) {
                    await _loadDashboardData();
                  }
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add New Plot',
                  style: TextStyle(fontFamily: AppTheme.appFontFamily),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final displayName = authState?.displayName ?? _displayName ?? 'Landlord';
    final organizationId = authState?.profile?.organizationId ?? _organizationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Manager'),
        bottom: _organizationId != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    text: 'Overview',
                    icon: Icon(LucideIcons.home),
                  ),
                  Tab(
                    text: 'Finance',
                    icon: Icon(LucideIcons.barChart3),
                  ),
                ],
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Maintenance',
            icon: const Icon(LucideIcons.wrench, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MaintenanceListScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(LucideIcons.cog, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(LucideIcons.logOut, size: 20),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
              : (organizationId == null)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Setup Required',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: AppTheme.appFontFamily,
                            ),
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'Please create an organization to continue.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32.0),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CreateOrgScreen(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                        child: const Text('Create Organization'),
                      ),
                    ],
                  ),
                )
              : PageTransitionSwitcher(
                  duration: const Duration(milliseconds: 360),
                  reverse: _tabController.index == 0,
                  transitionBuilder: (child, animation, secondaryAnimation) {
                    return SharedAxisTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: SharedAxisTransitionType.horizontal,
                      child: child,
                    );
                  },
                  child: _tabController.index == 0
                      ? KeyedSubtree(
                          key: const ValueKey('overview-tab'),
                          child: _buildPropertiesTab(displayName),
                        )
                      : const KeyedSubtree(
                          key: ValueKey('finance-tab'),
                          child: FinanceDashboardScreen(),
                        ),
                ),
    );
  }
}

