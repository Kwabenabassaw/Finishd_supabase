import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://lihaddxlyychswpkswbp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGFkZHhseXljaHN3cGtzd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA5MzQsImV4cCI6MjA4NDkxNjkzNH0.DrBUuz2ayMRCIicYAFNqH2ws3gbRu8ycsbATF54BuFM',
  );

  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('creator_videos')
        .select('id, title, video_url')
        .eq('status', 'approved')
        .limit(5);

    print('Checking video URLs:');
    for (var v in response) {
      print('Title: ${v['title']}');
      print('URL: ${v['video_url']}');
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  }
}
