import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

const String _defaultBackendBaseUrl = 'http://10.0.2.2:4000';
const String _sessionStorageKey = 'backend_auth_session';
const Duration _requestTimeout = Duration(seconds: 15);

String get backendBaseUrl {
  const value = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBackendBaseUrl);
  final normalized = value.trim();
  if (normalized.isNotEmpty) {
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }

  if (Platform.isAndroid) {
    return _defaultBackendBaseUrl;
  }

  return 'http://127.0.0.1:4000';
}

class BackendUser {
  const BackendUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'User').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'landlord').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
    };
  }
}

class BackendSession {
  const BackendSession({
    required this.token,
    required this.user,
    this.profile,
  });

  final String token;
  final BackendUser user;
  final UserProfile? profile;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
      'profile': profile == null
          ? null
          : {
              'id': profile!.id,
              'full_name': profile!.fullName,
              'role': profile!.role.name,
              'organization_id': profile!.organizationId,
              'unit_id': profile!.unitId,
            },
    };
  }

  factory BackendSession.fromJson(Map<String, dynamic> json) {
    final userJson = Map<String, dynamic>.from(json['user'] as Map<dynamic, dynamic>);
    final profileJson = json['profile'];

    return BackendSession(
      token: (json['token'] ?? '').toString(),
      user: BackendUser.fromJson(userJson),
      profile: profileJson is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(profileJson))
          : null,
    );
  }
}

class BackendApiException implements Exception {
  BackendApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BackendApi {
  BackendApi._();

  static final BackendApi instance = BackendApi._();

  Future<dynamic> getJson(String path, {String? token}) {
    return _request(method: 'GET', path: path, token: token);
  }

  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _request(method: 'POST', path: path, token: token, body: body);
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = _requestTimeout;

    try {
      final request = await client
          .openUrl(method, Uri.parse('$backendBaseUrl$path'))
          .timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;

      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.add(utf8.encode(jsonEncode(body)));
      }

        final response = await request.close().timeout(_requestTimeout);
        final responseText = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      final decoded = responseText.isEmpty ? null : jsonDecode(responseText);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map && decoded['error'] != null
            ? decoded['error'].toString()
            : 'Request failed with status ${response.statusCode}';
        throw BackendApiException(message, statusCode: response.statusCode);
      }

      return decoded;
    } on TimeoutException {
      throw BackendApiException(
        'Request timed out after ${_requestTimeout.inSeconds}s. '
        'Check that backend is running at $backendBaseUrl.',
      );
    } on BackendApiException {
      rethrow;
    } catch (error) {
      throw BackendApiException(
        'Failed to contact backend at $backendBaseUrl: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<BackendSession?> loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return BackendSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      await prefs.remove(_sessionStorageKey);
      return null;
    }
  }

  static Future<void> saveSession(BackendSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
  }

  static BackendSession parseSession(Map<String, dynamic> json) {
    return BackendSession.fromJson(json);
  }
}
