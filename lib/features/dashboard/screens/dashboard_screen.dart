import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final userName = authState?.displayName ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Manager'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Finance',
            icon: const Icon(LucideIcons.barChart3),
            onPressed: () {
              Navigator.of(context).pushNamed('/finance');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, $userName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32.0),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/finance');
              },
              icon: const Icon(LucideIcons.barChart3),
              label: const Text(
                'Open Finance Dashboard',
                style: TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
              ),
            ),
            const SizedBox(height: 12.0),
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
