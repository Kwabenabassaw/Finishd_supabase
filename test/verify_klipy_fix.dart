import 'dart:convert';
import 'package:http/http.dart' as http;

/// Final verification of the logic implemented in KlipyService
Future<void> main() async {
  const String apiKey = 'rut7Q1CHHEPpJ8EMb47E00Dfx3281cqViVjx3pgc1ylLMan1MEobFn9yrZq7qLqo';
  const String baseUrl = 'https://api.klipy.com/v2';
  
  print('Verifying Search v2 logic...');
  final searchUri = Uri.parse('$baseUrl/search').replace(
    queryParameters: {
      'key': apiKey,
      'q': 'funny',
      'limit': '1',
      'pos': '0',
    },
  );
  
  try {
    final response = await http.get(searchUri);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final first = results[0] as Map<String, dynamic>;
        print('GIF ID: ${first['id']}');
        final media = first['media_formats'] as Map?;
        final gif = media?['gif'] as Map?;
        print('GIF URL: ${gif?['url']}');
        if (gif?['url'] != null) {
          print('✅ SUCCESSFULLY PARSED GIF DATA');
        } else {
          print('❌ FAILED TO FIND GIF URL IN media_formats');
        }
      } else {
        print('❌ NO RESULTS FOUND');
      }
    } else {
      print('❌ REQUEST FAILED with ${response.statusCode}');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }

  print('\nVerifying Featured v2 logic...');
  final featuredUri = Uri.parse('$baseUrl/featured').replace(
    queryParameters: {
      'key': apiKey,
      'limit': '1',
    },
  );

  try {
    final response = await http.get(featuredUri);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
         print('✅ SUCCESSFULLY FETCHED FEATURED DATA');
      } else {
        print('❌ NO FEATURED RESULTS FOUND');
      }
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
