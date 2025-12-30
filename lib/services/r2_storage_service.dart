import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Service for uploading files to Cloudflare R2 via presigned URLs.
///
/// This replaces Firebase Storage with a more cost-effective solution.
/// The flow is:
/// 1. Request a presigned URL from our backend.
/// 2. Upload the file directly to R2 using HTTP PUT.
/// 3. Return the public URL for storage in Firestore.
class R2StorageService {
  static const String _baseUrl = 'https://finishdbackend.onrender.com';

  /// Upload a file to R2 and return the public URL.
  ///
  /// [file] - The file to upload.
  /// [folder] - The destination folder (e.g., 'profile_images', 'gallery').
  /// [contentType] - MIME type (default: 'image/jpeg').
  Future<String> uploadFile(
    File file, {
    String folder = 'profile_images',
    String contentType = 'image/jpeg',
  }) async {
    // 1. Get auth token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final token = await user.getIdToken();

    // 2. Request presigned URL from backend
    final urlResponse = await http.post(
      Uri.parse('$_baseUrl/storage/upload-url'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'folder': folder, 'content_type': contentType}),
    );

    if (urlResponse.statusCode != 200) {
      throw Exception('Failed to get upload URL: ${urlResponse.body}');
    }

    final urlData = jsonDecode(urlResponse.body);
    final uploadUrl = urlData['upload_url'] as String;
    final publicUrl = urlData['public_url'] as String;

    // 3. Upload file directly to R2
    final fileBytes = await file.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: fileBytes,
    );

    if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 204) {
      throw Exception('Failed to upload file: ${uploadResponse.statusCode}');
    }

    return publicUrl;
  }

  /// Upload a profile image and return the public URL.
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    return uploadFile(
      imageFile,
      folder: 'profile_images',
      contentType: _getContentType(imageFile.path),
    );
  }

  /// Upload multiple gallery images and return their public URLs.
  Future<List<String>> uploadGalleryImages(
    String uid,
    List<File> imageFiles,
  ) async {
    final urls = <String>[];
    for (final file in imageFiles) {
      final url = await uploadFile(
        file,
        folder: 'gallery/$uid',
        contentType: _getContentType(file.path),
      );
      urls.add(url);
    }
    return urls;
  }

  /// Determine content type from file extension.
  String _getContentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
