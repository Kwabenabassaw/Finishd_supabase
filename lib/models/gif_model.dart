/// Platform-agnostic GIF model
/// Decouples the app from any specific GIF API provider
class GifModel {
  final String id;
  final String gifUrl; // Original or optimized GIF URL
  final String previewUrl; // Lightweight thumbnail for fast loading
  final int width;
  final int height;
  final int? fileSize; // Optional file size in bytes

  GifModel({
    required this.id,
    required this.gifUrl,
    required this.previewUrl,
    required this.width,
    required this.height,
    this.fileSize,
  });

  /// Create GifModel from Klipy API response
  factory GifModel.fromKlipy(Map<String, dynamic> json) {
    // Klipy API v2 response structure (Tenor-compatible)
    final media = json['media_formats'] as Map<String, dynamic>? ?? {};
    final gif = media['gif'] as Map<String, dynamic>? ?? {};
    final tinygif = media['tinygif'] as Map<String, dynamic>? ?? {};

    return GifModel(
      id: json['id']?.toString() ?? '',
      gifUrl: gif['url']?.toString() ?? '',
      previewUrl: tinygif['url']?.toString() ?? gif['url']?.toString() ?? '',
      width: (gif['dims']?[0] as num?)?.toInt() ?? 0,
      height: (gif['dims']?[1] as num?)?.toInt() ?? 0,
      fileSize: (gif['size'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gifUrl': gifUrl,
      'previewUrl': previewUrl,
      'width': width,
      'height': height,
      'fileSize': fileSize,
    };
  }

  factory GifModel.fromJson(Map<String, dynamic> json) {
    return GifModel(
      id: json['id'] as String,
      gifUrl: json['gifUrl'] as String,
      previewUrl: json['previewUrl'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      fileSize: json['fileSize'] as int?,
    );
  }
}
