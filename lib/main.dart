import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/home/dashboard_screen.dart';
import 'features/maintenance/screens/contractor_registry_screen.dart';
import 'features/reports/screens/finance_dashboard_screen.dart';
import 'features/settings/providers/theme_controller.dart';
import 'features/tenant/screens/tenant_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Plot Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: authState.when(
        data: (state) {
          if (state.isAuthenticated) {
            if (state.isTenant) {
              return const TenantDashboardScreen();
            }

            return const DashboardScreen();
          }

          return const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/tenant-dashboard': (context) => const TenantDashboardScreen(),
        '/contractors': (context) => const ContractorRegistryScreen(),
        '/finance': (context) => const FinanceDashboardScreen(),
      },
    );
  }
}
