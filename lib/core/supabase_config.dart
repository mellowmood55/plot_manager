import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://seipqulkybnhspwgoqak.supabase.co';
  static const String supabaseKey = 'sb_publishable_86eVExwYB_eEBxxqXJgD8Q_4P98nLq6';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  static SupabaseClient getClient() {
    return Supabase.instance.client;
  }
}
