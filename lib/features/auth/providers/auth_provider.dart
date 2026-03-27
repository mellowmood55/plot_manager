import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';

final authProvider = StreamProvider<AuthState>((ref) {
  final client = SupabaseConfig.getClient();

  return Stream<AuthState>.multi((controller) {
    final initialSession = client.auth.currentSession;
    controller.add(
      AuthState(
        session: initialSession,
        user: initialSession?.user,
      ),
    );

    final subscription = client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      controller.add(
        AuthState(
          session: session,
          user: session?.user,
        ),
      );
    });

    ref.onDispose(subscription.cancel);
  });
});

class AuthState {
  final Session? session;
  final User? user;

  AuthState({
    this.session,
    this.user,
  });

  bool get isAuthenticated => session != null && user != null;
}
