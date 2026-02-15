import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for uploading files to Cloudinary using Unsigned Uploads.
///
/// Configuration:
/// Replace YOUR_CLOUD_NAME and YOUR_UPLOAD_PRESET with your Cloudinary values.
/// Get these from: https://console.cloudinary.com/settings/upload
class StorageService {
  // ============================================================
  // CONFIGURATION - Replace with your Cloudinary values
  // ============================================================
  static const String _cloudName = 'dqt7y3agl';
  static const String _uploadPreset = 'profile';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload a profile image and return the secure URL.
  ///
  /// Matches the method signature of the old Firebase StorageService.
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // Add required fields for unsigned upload
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'profile_images/$uid';

      // Attach the file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.body}');
      }

      // Parse response and return secure URL
      final data = jsonDecode(response.body);
      return data['secure_url'] as String;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  /// Upload any file and return the secure URL.
  Future<String> uploadFile(File file, {String folder = 'uploads'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['secure_url'] as String;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  /// Upload multiple gallery images and return their secure URLs.
  Future<List<String>> uploadGalleryImages(
    String uid,
    List<File> imageFiles,
  ) async {
    final urls = <String>[];
    for (final file in imageFiles) {
      final url = await uploadFile(file, folder: 'gallery/$uid');
      urls.add(url);
    }
    return urls;
  }

  // ============================================================
  // URL TRANSFORMATION HELPERS
  // ============================================================

  /// Get an optimized thumbnail URL (200x200 cropped).
  ///
  /// Transforms:
  /// https://res.cloudinary.com/demo/image/upload/v123/profile.jpg
  /// Into:
  /// https://res.cloudinary.com/demo/image/upload/w_200,h_200,c_fill/v123/profile.jpg
  static String getOptimizedUrl(
    String url, {
    int width = 200,
    int height = 200,
  }) {
    // Find the /upload/ part and insert transformations after it
    const uploadMarker = '/upload/';
    final uploadIndex = url.indexOf(uploadMarker);

    if (uploadIndex == -1) {
      return url; // Not a Cloudinary URL, return as-is
    }

    final insertPosition = uploadIndex + uploadMarker.length;
    final transformations = 'w_$width,h_$height,c_fill/';

    return url.substring(0, insertPosition) +
        transformations +
        url.substring(insertPosition);
  }

  /// Get a blurred placeholder URL for progressive loading.
  static String getBlurredPlaceholder(String url) {
    const uploadMarker = '/upload/';
    final uploadIndex = url.indexOf(uploadMarker);

    if (uploadIndex == -1) return url;

    final insertPosition = uploadIndex + uploadMarker.length;
    const transformations = 'w_50,h_50,c_fill,e_blur:1000,q_auto:low/';

    return url.substring(0, insertPosition) +
        transformations +
        url.substring(insertPosition);
  }

  // ============================================================
  // CHAT MEDIA UPLOADS
  // ============================================================

  /// Upload a chat image.
  Future<String> uploadChatImage(String chatId, File imageFile) async {
    return uploadFile(imageFile, folder: 'chat_images/$chatId');
  }

  /// Upload a chat video.
  Future<String> uploadChatVideo(String chatId, File videoFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload'),
      );

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'chat_videos/$chatId';

      request.files.add(
        await http.MultipartFile.fromPath('file', videoFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Video upload failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['secure_url'] as String;
    } catch (e) {
      print('Error uploading chat video: $e');
      rethrow;
    }
  }

  /// Get video thumbnail URL from Cloudinary video URL.
  static String getVideoThumbnail(String videoUrl) {
    return videoUrl
        .replaceFirst(
          '/video/upload/',
          '/video/upload/so_0,w_400,h_300,c_fill/',
        )
        .replaceFirst(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');
  }

  // ============================================================
  // COMMUNITY MEDIA UPLOADS
  // ============================================================

  /// Upload a community post image or video.
  Future<String> uploadCommunityMedia(
    String communityId,
    String uid,
    File file,
  ) async {
    final isVideo =
        file.path.endsWith('.mp4') ||
        file.path.endsWith('.mov') ||
        file.path.endsWith('.avi');

    if (isVideo) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload'),
        );

        request.fields['upload_preset'] = _uploadPreset;
        request.fields['folder'] = 'community_media/$communityId/$uid';

        request.files.add(await http.MultipartFile.fromPath('file', file.path));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          throw Exception('Community video upload failed: ${response.body}');
        }

        final data = jsonDecode(response.body);
        return data['secure_url'] as String;
      } catch (e) {
        print('Error uploading community video: $e');
        rethrow;
      }
    } else {
      return uploadFile(file, folder: 'community_media/$communityId/$uid');
    }
  }

  /// Upload multiple community post files and return their secure URLs.
  Future<List<String>> uploadMultipleCommunityMedia(
    String communityId,
    String uid,
    List<File> files,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadCommunityMedia(communityId, uid, file);
      urls.add(url);
    }
    return urls;
  }
  // ============================================================
  // CREATOR VIDEO SYSTEM (Supabase Storage)
  // ============================================================

  /// Upload a creator video to Supabase Storage.
  Future<String> uploadCreatorVideo(File videoFile, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = '$userId/$fileName';

      await Supabase.instance.client.storage
          .from('creator-videos')
          .upload(path, videoFile);

      // Get public URL (or signed URL if private - buckets are private by policy for uploads, public for reads?)
      // Plan said: "Read: public (approved only via signed URLs or Edge Function)"
      // Actually, standard pattern is to store the path or get a public URL if the bucket is public.
      // The instructions said "creator-videos" (Private).
      // So we should probably store the path. Or get a signed URL.
      // For simplicity in the app, let's assume we store the full path or public URL.
      // If the bucket is private, we need signedURL.
      // However, usually detailed implementation stores the path.
      // Let's return the path for now, or the key.
      return path;
    } catch (e) {
      print('Error uploading creator video: $e');
      rethrow;
    }
  }

  /// Upload a creator thumbnail to Supabase Storage.
  Future<String> uploadCreatorThumbnail(File imageFile, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await Supabase.instance.client.storage
          .from('creator-thumbnails')
          .upload(path, imageFile);

      // Thumbnails are public bucket
      final url = Supabase.instance.client.storage
          .from('creator-thumbnails')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      print('Error uploading creator thumbnail: $e');
      rethrow;
    }
  }
}
