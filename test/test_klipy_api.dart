import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String apiKey = 'rut7Q1CHHEPpJ8EMb47E00Dfx3281cqViVjx3pgc1ylLMan1MEobFn9yrZq7qLqo';
  
  final logFile = File('klipy_debug.log');
  String totalOutput = '';
  
  // Per Tenor migration guide, Klipy is a drop-in replacement at api.klipy.com
  // Tenor v2 uses /v2/search and /v2/featured
  // Tenor v1 uses /search and /trending
  
  final configs = [
    {'baseUrl': 'https://api.klipy.com/v2', 'path': '/search', 'keyParam': 'key'},
    {'baseUrl': 'https://api.klipy.com/v2', 'path': '/featured', 'keyParam': 'key'},
    {'baseUrl': 'https://api.klipy.com', 'path': '/v1/search', 'keyParam': 'api_key'},
    {'baseUrl': 'https://api.klipy.com', 'path': '/search', 'keyParam': 'key'},
  ];
  
  for (final config in configs) {
    final baseUrl = config['baseUrl']!;
    final path = config['path']!;
    final keyParam = config['keyParam']!;
    
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        keyParam: apiKey,
        if (path.contains('search')) 'q': 'happy',
        'limit': '1',
      },
    );
    
    print('Testing $uri...');
    
    try {
      final response = await http.get(
        uri, 
        headers: {
          'X-API-Key': apiKey,
          'Accept': 'application/json',
        },
      );
      totalOutput += 'URL: $uri\n';
      totalOutput += 'Status: ${response.statusCode}\n';
      totalOutput += 'Body: ${response.body}\n\n';
    } catch (e) {
      totalOutput += 'Error testing $uri: $e\n\n';
    }
  }
  
  await logFile.writeAsString(totalOutput);
  print('Detailed results written to klipy_debug.log');
}
