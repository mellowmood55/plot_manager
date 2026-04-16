import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../auth/providers/auth_provider.dart';
import '../home/dashboard_screen.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _orgNameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _orgNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authState = ref.read(authProvider).value;
      final client = SupabaseConfig.getClient();
      final userId = authState?.user?.id ?? client.auth.currentUser?.id;

      if (authState == null || !authState.isAuthenticated || userId == null) {
        throw Exception('User not authenticated');
      }

      if (_orgNameController.text.trim().isEmpty) {
        throw Exception('Organization name is required');
      }

      if (_locationController.text.trim().isEmpty) {
        throw Exception('Business location is required');
      }

      final created = await client.from('organizations').insert({
        'name': _orgNameController.text.trim(),
        'location': _locationController.text.trim(),
        'created_by': userId,
      }).select('id').single();

      final organizationId = (created['id'] ?? '').toString();
      if (organizationId.isEmpty) {
        throw Exception('Failed to create organization');
      }

      await client.from('profiles').upsert({
        'id': userId,
        'full_name': authState.displayName,
        'organization_id': organizationId,
        'role': 'landlord',
      });

      await ref.read(authProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization created successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Setup Organization',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: AppTheme.appFontFamily,
              ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Property Management Setup',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.appFontFamily,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Create your organization to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                          fontFamily: AppTheme.appFontFamily,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32.0),
                  TextField(
                    controller: _orgNameController,
                    decoration: const InputDecoration(
                      hintText: 'Organization Name',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: 'Business Location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createOrganization,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20.0,
                            width: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Create Organization',
                            style: TextStyle(
                              fontFamily: AppTheme.appFontFamily,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
