import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final client = SupabaseClient(
    'https://lihaddxlyychswpkswbp.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGFkZHhseXljaHN3cGtzd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA5MzQsImV4cCI6MjA4NDkxNjkzNH0.DrBUuz2ayMRCIicYAFNqH2ws3gbRu8ycsbATF54BuFM',
  );

  try {
    final response = await client.rpc(
      'get_personalized_feed',
      params: {
        'p_limit': 6,
        'p_cold_start': false,
        'p_session_id': null,
        'p_user_id':
            '1b5af1af-d048-40ee-a2a0-311e4e3f61c3', // Simulated logged in user
      },
    );

    final List<dynamic> data = response as List<dynamic>;
    print('RPC fetched \${data.length} records.');

    if (data.isNotEmpty) {
      final first = data.first as Map<String, dynamic>;
      for (final key in first.keys) {
        print('\$key: \${first[key]} (\${first[key].runtimeType})');
      }
    }
  } catch (e) {
    print('RPC Error: \$e');
  }
}
