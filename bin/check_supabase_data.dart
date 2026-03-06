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
        .select('id, title, creator_id, status')
        .eq('status', 'approved')
        .limit(100);

    print('Approved videos found: \${response.length}');
    Map<String, int> creatorCounts = {};
    for (var v in response) {
      print('- \${v['title']} (Creator: \${v['creator_id']})');
      String creatorId = v['creator_id'].toString();
      creatorCounts[creatorId] = (creatorCounts[creatorId] ?? 0) + 1;
    }
    print('--- Creator Counts ---');
    creatorCounts.forEach((key, value) {
      print('Creator \${key}: \${value} videos');
    });
  } catch (e) {
    print('Error: \$e');
  }
}

