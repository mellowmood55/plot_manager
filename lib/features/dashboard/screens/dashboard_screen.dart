import 'package:flutter/material.dart';
import '../../../core/supabase_config.dart';
import '../../../core/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = SupabaseConfig.getClient().auth.currentUser;
    setState(() {
      _userName = user?.userMetadata?['full_name'] as String? ??
          user?.email ??
          'User';
    });
  }

  Future<void> _logout() async {
    try {
      await SupabaseConfig.getClient().auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Manager'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, $_userName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32.0),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 12.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
