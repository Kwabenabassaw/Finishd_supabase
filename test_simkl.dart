import 'package:dio/dio.dart';
import 'dart:io';

void main() async {
  final file = File('.env');
  final contents = await file.readAsString();
  String apiKey = '';
  for (var line in contents.split('\n')) {
    if (line.trim().startsWith('SIMKL_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.simkl.com',
      headers: {'simkl-api-key': apiKey, 'Content-Type': 'application/json'},
    ),
  );

  try {
    print('Fetching Trending TV...');
    final response = await dio.get('/tv/trending');
    print(response.data.toString().substring(0, 500));

    print('\nFetching TV Calendar...');
    final response2 = await dio.get('/tv/calendar');
    print(response2.data.toString().substring(0, 500));

    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
