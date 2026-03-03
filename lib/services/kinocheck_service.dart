import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';
import '../models/trailer_item.dart';

class KinocheckService {
  static const String _baseUrl = 'https://api.kinocheck.de';

  /// Fetches trailers from the Kinocheck API.
  /// Kinocheck returns a dictionary of trailers with string indices.
  ///
  ///
  ///
  ///
  ///
  ///
  Future <List<TrailerItem>>Trailerstoday() async{
    try{
      final url = Uri.parse('$_baseUrl/trailers/lastest');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200){
        final Map<String,dynamic> data = jsonDecode(response.body);
        final List<TrailerItem> lastest =[];

        for (var key in data.keys){
          final item = data[key];
          if (item is Map<String,dynamic>){
            if (item['youtube_video_id'] != null){
              lastest.add(_mapToTrailerItem(item));
            }
          }
        }
        return  lastest;
      }
    }catch(e){
      print('Error fetching Kinocheck trailers: $e');


    }
    return [];

  }
  Future<List<TrailerItem>> getTrailers({

    int page = 1,
    String language = 'en',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/trailers?language=$language&page=$page');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<TrailerItem> trailers = [];

        // Kinocheck returns a JSON object with keys "0", "1", "2"...
        for (var key in data.keys) {
          final item = data[key];
          if (item is Map<String, dynamic>) {
            // Only add if it has a youtube video id
            if (item['youtube_video_id'] != null) {
              trailers.add(_mapToTrailerItem(item));
            }
          }
        }
        return trailers;
      }
    } catch (e) {
      print('Error fetching Kinocheck trailers: $e');
    }
    return [];
  }


  /// Maps a Kinocheck trailer JSON object to our app's TrailerItem model.
  TrailerItem _mapToTrailerItem(Map<String, dynamic> json) {
    final resource = json['resource'] as Map<String, dynamic>? ?? {};

    return TrailerItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      posterUrl: json['thumbnail'] ?? '',
      backdropUrl: json['youtube_thumbnail'] ?? json['thumbnail'] ?? '',
      description:
          '', // Kinocheck usually doesn't provide overview in this endpoint
      youtubeKey: json['youtube_video_id'] ?? '',
      voteAverage: 0.0,
      mediaType: resource['type'] ?? 'movie', // 'movie' or 'show'
      releaseDate: json['published'] != null
          ? DateTime.tryParse(json['published'])
          : null,
    );
  }
}
