import 'package:dio/dio.dart';
import 'dart:io';

void main() async {
  final file = File('.env');
  final contents = await file.readAsString();
  String clientId = '';
  for (var line in contents.split('\n')) {
    if (line.trim().startsWith('TRAKT_CLIENT_ID=')) {
      clientId = line.split('=')[1].trim();
      break;
    }
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.trakt.tv',
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': clientId,
      },
    ),
  );

  try {
    final now = DateTime.now().toUtc();
    final startDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    print('Testing Trakt API for Start Date: $startDate');
    final response = await dio.get('/calendars/all/shows/new/$startDate/30');
    print('Status: ${response.statusCode}');
    if ((response.data as List).isNotEmpty) {
      print('Response Data (1 item): ${response.data.first}');
    } else {
      print('No data returned from Trakt.');
    }
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
