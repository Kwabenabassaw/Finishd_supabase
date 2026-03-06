import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

Future<void> main() async {
  print('--- Supabase Feed Randomness Verification ---');
  final client = SupabaseClient(
    'https://lihaddxlyychswpkswbp.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGFkZHhseXljaHN3cGtzd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA5MzQsImV4cCI6MjA4NDkxNjkzNH0.DrBUuz2ayMRCIicYAFNqH2ws3gbRu8ycsbATF54BuFM',
  );

  try {
    const limit = 5;
    print('Fetching feed batch 1...');
    final List<dynamic> batch1 = await client.rpc(
      'get_personalized_feed',
      params: {
        'p_limit': limit,
        'p_cold_start':
            true, // Use cold start to ensure we get trending/explore hits
      },
    );

    print('Fetching feed batch 2...');
    final List<dynamic> batch2 = await client.rpc(
      'get_personalized_feed',
      params: {'p_limit': limit, 'p_cold_start': true},
    );

    if (batch1.isEmpty || batch2.isEmpty) {
      print('Warning: One of the batches is empty. Cannot compare.');
      return;
    }

    print('\nBatch 1 IDs:');
    for (var v in batch1) {
      print('  - ${v['id']} (Source: ${v['feed_source']})');
    }

    print('\nBatch 2 IDs:');
    for (var v in batch2) {
      print('  - ${v['id']} (Source: ${v['feed_source']})');
    }

    final id1 = batch1.map((v) => v['id']).toList();
    final id2 = batch2.map((v) => v['id']).toList();

    bool identical = true;
    for (int i = 0; i < min(id1.length, id2.length); i++) {
      if (id1[i] != id2[i]) {
        identical = false;
        break;
      }
    }

    if (identical) {
      print('\n[RESULT] FAIL: Batch IDs are identical across calls.');
    } else {
      print('\n[RESULT] SUCCESS: Feed order/content changed between calls!');
    }
  } catch (e) {
    print('Error: $e');
  }
}
