import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../models/property.dart';
import '../../services/supabase_service.dart';
import '../reports/screens/finance_dashboard_screen.dart';
import '../maintenance/screens/maintenance_list_screen.dart';
import '../property/screens/add_property_screen.dart';
import '../property/screens/property_detail_screen.dart';
import '../org/create_org_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _displayName;
  String? _organizationId;
  String? _organizationName;
  List<Property> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final client = SupabaseConfig.getClient();
      final user = client.auth.currentUser;

      if (user != null) {
        final metadata = user.userMetadata;
        final String displayName = metadata?['full_name'] ?? user.email ?? 'Landlord';

        final profileResponse = await client
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .maybeSingle();

        final String? orgId = profileResponse?['organization_id'] as String?;

        String? orgName;
        List<Property> properties = [];

        if (orgId != null) {
          orgName = await SupabaseService.instance.getOrganizationName(orgId);
          properties = await SupabaseService.instance.fetchPropertiesByOrganization(orgId);
        }

        setState(() {
          _displayName = displayName;
          _organizationId = orgId;
          _organizationName = orgName;
          _properties = properties;
          _isLoading = false;
        });
      }
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

  Future<void> _openFinanceDashboard() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const FinanceDashboardScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Unable to open finance dashboard: $error',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Manager'),
        actions: [
          IconButton(
            tooltip: 'Finance',
            icon: const Icon(LucideIcons.barChart3),
            onPressed: () {
              _openFinanceDashboard();
            },
          ),
          IconButton(
            tooltip: 'Maintenance',
            icon: const Icon(LucideIcons.wrench),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MaintenanceListScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(LucideIcons.cog),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () async {
              await SupabaseConfig.getClient().auth.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: _organizationId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              onPressed: () async {
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
              icon: const Icon(Icons.add),
              label: const Text(
                'Add New Plot',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : (_organizationId == null)
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      color: AppTheme.surfaceColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to ${_organizationName ?? 'Your Organization'}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppTheme.appFontFamily,
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            '$_displayName',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: AppTheme.appFontFamily,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Card(
                        color: AppTheme.surfaceColor,
                        child: ListTile(
                          leading: const Icon(LucideIcons.barChart3),
                          title: const Text(
                            'Finance Dashboard',
                            style: TextStyle(
                              fontFamily: AppTheme.appFontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Profit, revenue, expenses, and rent analytics',
                            style: TextStyle(fontFamily: AppTheme.appFontFamily),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openFinanceDashboard,
                        ),
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
                              padding: const EdgeInsets.all(16),
                              itemCount: _properties.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final property = _properties[index];

                                return Card(
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
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PropertyDetailScreen(property: property),
                                        ),
                                      );
                                      await _loadDashboardData();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
