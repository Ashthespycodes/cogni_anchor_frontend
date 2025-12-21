import 'package:cogni_anchor/models/reminder_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReminderSupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 📥 GET ALL REMINDERS FOR A PAIR
  Future<List<Reminder>> getReminders(String pairId) async {
    final response = await _client
        .from('reminders')
        .select()
        .eq('pair_id', pairId)
        .order('date', ascending: true)
        .order('time', ascending: true);

    return (response as List).map((json) => Reminder.fromJson(json)).toList();
  }

  /// ➕ CREATE REMINDER
  /// NOTE: DB auto-generates INTEGER id
  Future<void> createReminder({
    required Reminder reminder,
    required String pairId,
  }) async {
    await _client.from('reminders').insert({
      'title': reminder.title,
      'date': reminder.date,
      'time': reminder.time,
      'pair_id': pairId,
    });
  }

  /// ❌ DELETE REMINDER (CRITICAL FIX)
  /// DB id is INTEGER, reminder.id is STRING
  Future<void> deleteReminder(String reminderId) async {
    final id = int.parse(reminderId); // 🔴 REQUIRED

    await _client.from('reminders').delete().eq('id', id);
  }
}
