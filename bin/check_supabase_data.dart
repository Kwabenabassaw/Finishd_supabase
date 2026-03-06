import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/models/creator_video.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://lihaddxlyychswpkswbp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGFkZHhseXljaHN3cGtzd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA5MzQsImV4cCI6MjA4NDkxNjkzNH0.DrBUuz2ayMRCIicYAFNqH2ws3gbRu8ycsbATF54BuFM',
  );

  final client = Supabase.instance.client;

  try {
    final response = await client.rpc(
      'get_personalized_feed',
      params: {'p_limit': 6, 'p_cold_start': true},
    );

    final List<dynamic> data = response as List<dynamic>;
    print('Fetched \${data.length} videos from RPC');

    for (var json in data) {
      try {
        final video = CreatorVideo.fromRpcJson(json);
        print('Successfully parsed: \${video.title}');
      } catch (e, stack) {
        print('Error parsing video from JSON: \$e');
        print(stack);
      }
    }
  } catch (e) {
    print('RPC Error: \$e');
  }
}
