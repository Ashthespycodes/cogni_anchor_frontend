import 'package:supabase_flutter/supabase_flutter.dart';

class PatientStatusService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Call when patient logs in / app opens
  static Future<void> markLoggedIn() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('patient_status').upsert({
      'patient_user_id': user.id,
      'is_logged_in': true,
      'last_active_at': DateTime.now().toIso8601String(),
    });
  }

  /// Call periodically (app resume, foreground)
  static Future<void> updateLastActive() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('patient_status').update({
      'last_active_at': DateTime.now().toIso8601String(),
    }).eq('patient_user_id', user.id);
  }

  /// Call when patient logs out
  static Future<void> markLoggedOut() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('patient_status').update({
      'is_logged_in': false,
      'last_active_at': DateTime.now().toIso8601String(),
    }).eq('patient_user_id', user.id);
  }
}
