import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://gllyvuivhksfgyfexxmp.supabase.co';
  static const String supabaseKey = 'sb_publishable_eedqHn3r12g9OFiD3KBu7Q_SaAyygay';

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
