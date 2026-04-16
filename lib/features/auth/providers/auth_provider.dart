import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_config.dart';
import '../../../models/user_profile.dart';
import '../../../models/user_role.dart';

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  factory AuthUser.fromSupabase(User user, UserProfile? profile) {
    final metadata = user.userMetadata;
    final metadataFullName = metadata?['full_name']?.toString() ?? metadata?['name']?.toString();
    final metadataRole = UserRole.fromString(metadata?['role']?.toString());

    return AuthUser(
      id: user.id,
      fullName: profile?.fullName ?? metadataFullName ?? user.email ?? 'User',
      email: user.email ?? '',
      role: profile?.role ?? metadataRole,
    );
  }
}

class AuthController extends AsyncNotifier<AuthState> {
  StreamSubscription<dynamic>? _authSubscription;

  @override
  Future<AuthState> build() async {
    final client = SupabaseConfig.getClient();

    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      final user = session?.user ?? client.auth.currentUser;

      if (session == null || user == null) {
        state = AsyncData(AuthState.empty());
        return;
      }

      _syncAuthStateFromSession(session, user);
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    final session = client.auth.currentSession;
    final user = client.auth.currentUser;

    if (session == null || user == null) {
      return AuthState.empty();
    }

    return _buildStateFromSession(session, user);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final client = SupabaseConfig.getClient();
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final session = response.session ?? client.auth.currentSession;
    final user = response.user ?? client.auth.currentUser;

    if (session == null || user == null) {
      throw Exception('Login did not return an authenticated session.');
    }

    await _syncAuthStateFromSession(session, user);
  }

  Future<void> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final client = SupabaseConfig.getClient();
    final response = await client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user ?? client.auth.currentUser;
    if (user == null) {
      throw Exception('Account creation did not return a user.');
    }

    await _loadOrCreateProfile(
      user,
      fullNameFallback: fullName,
    );

    final session = response.session ?? client.auth.currentSession;
    if (session == null) {
      state = AsyncData(AuthState.empty());
      return;
    }

    await _syncAuthStateFromSession(session, user);
  }

  Future<void> logout() async {
    final client = SupabaseConfig.getClient();
    await client.auth.signOut();
    state = AsyncData(AuthState.empty());
  }

  Future<void> refresh() async {
    try {
      final client = SupabaseConfig.getClient();
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;

      if (session == null || user == null) {
        await logout();
        return;
      }

      await _syncAuthStateFromSession(session, user);
    } catch (_) {
      await logout();
    }
  }

  Future<AuthState> _buildStateFromSession(Session session, User user) async {
    try {
      final profile = await _loadOrCreateProfile(user);
      return AuthState.fromSupabase(
        session: session,
        user: AuthUser.fromSupabase(user, profile),
        profile: profile,
      );
    } catch (_) {
      return AuthState.fromSupabase(
        session: session,
        user: AuthUser.fromSupabase(user, null),
        profile: null,
      );
    }
  }

  Future<void> _syncAuthStateFromSession(Session session, User user) async {
    final resolved = await _buildStateFromSession(session, user);
    state = AsyncData(resolved);
  }

  Future<UserProfile?> _loadProfile(String userId) async {
    final client = SupabaseConfig.getClient();
    final row = await client
        .from('profiles')
        .select('id, full_name, organization_id, role, unit_id')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<UserProfile> _loadOrCreateProfile(
    User user, {
    String? fullNameFallback,
  }) async {
    final existing = await _loadProfile(user.id);
    if (existing != null) {
      return existing;
    }

    final client = SupabaseConfig.getClient();
    final metadata = user.userMetadata;
    final fullName = fullNameFallback ?? metadata?['full_name']?.toString() ?? user.email ?? 'User';
    final role = UserRole.fromString(metadata?['role']?.toString());

    await client.from('profiles').insert({
      'id': user.id,
      'full_name': fullName,
      'role': role.value,
      'organization_id': null,
      'unit_id': null,
    });

    return UserProfile(
      id: user.id,
      fullName: fullName,
      role: role,
      organizationId: null,
      unitId: null,
    );
  }
}

class AuthState {
  const AuthState({
    required this.token,
    required this.user,
    required this.profile,
  });

  final String? token;
  final AuthUser? user;
  final UserProfile? profile;

  const AuthState.empty()
      : token = null,
        user = null,
        profile = null;

  factory AuthState.fromSupabase({
    required Session session,
    required AuthUser user,
    required UserProfile? profile,
  }) {
    return AuthState(
      token: session.accessToken,
      user: user,
      profile: profile,
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
