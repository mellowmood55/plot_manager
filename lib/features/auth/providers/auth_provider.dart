import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend_api.dart';
import '../../../models/user_profile.dart';

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final storedSession = await BackendApi.loadStoredSession();
    if (storedSession == null) {
      return AuthState.empty();
    }

    try {
      final refreshed = await _refreshSession(storedSession.token);
      await BackendApi.saveSession(refreshed);
      return AuthState.fromSession(refreshed);
    } catch (_) {
      await BackendApi.clearSession();
      return AuthState.empty();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await BackendApi.instance.postJson(
      '/v1/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final session = BackendApi.parseSession(Map<String, dynamic>.from(response as Map));
    await BackendApi.saveSession(session);
    state = AsyncData(AuthState.fromSession(session));
  }

  Future<void> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await BackendApi.instance.postJson(
      '/v1/auth/signup',
      body: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );

    final session = BackendApi.parseSession(Map<String, dynamic>.from(response as Map));
    await BackendApi.saveSession(session);
    state = AsyncData(AuthState.fromSession(session));
  }

  Future<void> logout() async {
    await BackendApi.clearSession();
    state = AsyncData(AuthState.empty());
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null || !current.isAuthenticated) {
      return;
    }

    final token = current.token;
    if (token == null || token.isEmpty) {
      await logout();
      return;
    }

    try {
      final refreshed = await _refreshSession(token);
      await BackendApi.saveSession(refreshed);
      state = AsyncData(AuthState.fromSession(refreshed));
    } catch (_) {
      await logout();
    }
  }

  Future<BackendSession> _refreshSession(String token) async {
    final response = await BackendApi.instance.getJson('/v1/auth/me', token: token);
    return BackendApi.parseSession(Map<String, dynamic>.from(response as Map));
  }
}

class AuthState {
  const AuthState({
    required this.token,
    required this.user,
    required this.profile,
  });

  final String? token;
  final BackendUser? user;
  final UserProfile? profile;

  const AuthState.empty()
      : token = null,
        user = null,
        profile = null;

  factory AuthState.fromSession(BackendSession session) {
    return AuthState(
      token: session.token,
      user: session.user,
      profile: session.profile,
    );
  }

  bool get isAuthenticated => token != null && token!.isNotEmpty && user != null;
  bool get isTenant => profile?.isTenant ?? false;
  bool get isLandlord => profile?.isLandlord ?? true;
  bool get hasOrganization => profile?.organizationId?.isNotEmpty == true;

  String get displayName {
    final profileName = profile?.fullName;
    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName;
    }

    final userName = user?.fullName;
    if (userName != null && userName.trim().isNotEmpty) {
      return userName;
    }

    return user?.email.isNotEmpty == true ? user!.email : 'User';
  }
}
