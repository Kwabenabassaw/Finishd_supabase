import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:uuid/uuid.dart';

/// Stages the upload pipeline moves through.
enum UploadStage {
  idle,
  compressing,
  uploadingVideo,
  uploadingThumbnail,
  insertingRecord,
  done,
  failed,
}

/// Background video upload manager.
///
/// Owns the full compress → upload → insert lifecycle so the UI can pop
/// immediately and the user continues using the app while the upload runs.
class VideoUploadProvider extends ChangeNotifier {
  UploadStage _stage = UploadStage.idle;
  double _progress = 0.0; // 0.0 – 1.0
  String? _errorMessage;

  UploadStage get stage => _stage;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  bool get isUploading =>
      _stage != UploadStage.idle &&
      _stage != UploadStage.done &&
      _stage != UploadStage.failed;

  /// Human-readable label for the current stage.
  String get stageLabel {
    switch (_stage) {
      case UploadStage.idle:
        return '';
      case UploadStage.compressing:
        return 'Compressing video…';
      case UploadStage.uploadingVideo:
        return 'Uploading video…';
      case UploadStage.uploadingThumbnail:
        return 'Uploading thumbnail…';
      case UploadStage.insertingRecord:
        return 'Finalizing…';
      case UploadStage.done:
        return 'Upload complete!';
      case UploadStage.failed:
        return 'Upload failed';
    }
  }

  Subscription? _compressSubscription;

  // Cached params for retry.
  File? _lastVideoFile;
  File? _lastThumbnailFile;
  Map<String, dynamic>? _lastMetadata;

  /// Kick off the upload pipeline.
  ///
  /// Call this from the upload screen then immediately pop the screen.
  /// The provider will run everything in the background and update its
  /// stage / progress so the overlay widget can reflect it.
  Future<void> startUpload({
    required File videoFile,
    required File thumbnailFile,
    required String caption,
    required String title,
    required List<String> tags,
    required int? tmdbId,
    required String? mediaType,
    required bool containsSpoilers,
    required int durationSeconds,
  }) async {
    // Guard against double-starts.
    if (isUploading) return;

    // Cache for retry.
    _lastVideoFile = videoFile;
    _lastThumbnailFile = thumbnailFile;
    _lastMetadata = {
      'caption': caption,
      'title': title,
      'tags': tags,
      'tmdbId': tmdbId,
      'mediaType': mediaType,
      'containsSpoilers': containsSpoilers,
      'durationSeconds': durationSeconds,
    };

    await _runPipeline(videoFile, thumbnailFile);
  }

  /// Retry the last failed upload with the same parameters.
  Future<void> retry() async {
    if (_lastVideoFile == null ||
        _lastThumbnailFile == null ||
        _lastMetadata == null)
      return;
    await _runPipeline(_lastVideoFile!, _lastThumbnailFile!);
  }

  /// Dismiss the done/failed banner so the overlay hides.
  void dismiss() {
    _stage = UploadStage.idle;
    _progress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Core Pipeline ──────────────────────────────────────────────────────

  Future<void> _runPipeline(File videoFile, File thumbnailFile) async {
    _errorMessage = null;
    _progress = 0.0;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final meta = _lastMetadata!;
      const uuid = Uuid();

      // ── Step 1: Compress ──────────────────────────────────────────────
      _setStage(UploadStage.compressing);

      File fileToUpload = videoFile;
      try {
        // Listen to the compression progress stream.
        _compressSubscription = VideoCompress.compressProgress$.subscribe((
          pct,
        ) {
          _progress = (pct / 100.0).clamp(0.0, 1.0);
          notifyListeners();
        });

        final info = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        _compressSubscription?.unsubscribe();
        _compressSubscription = null;

        if (info != null && info.file != null) {
          fileToUpload = info.file!;
        } else {
          // Compression returned null — treat as failure.
          throw Exception('Compression returned no output');
        }
      } catch (compressError) {
        _compressSubscription?.unsubscribe();
        _compressSubscription = null;

        // Compression failed → surface to user instead of silently uploading
        // the raw file (which could be 200 MB+).
        debugPrint('[Upload] Compression failed: $compressError');
        _stage = UploadStage.failed;
        _errorMessage =
            'Video compression failed. Please try a shorter or smaller video.';
        notifyListeners();
        return;
      }

      // ── Step 2: Upload Video ──────────────────────────────────────────
      _setStage(UploadStage.uploadingVideo);

      final videoFileName = '${uuid.v4()}.mp4';
      final videoPath = '${user.id}/$videoFileName';

      await Supabase.instance.client.storage
          .from('creator-videos')
          .upload(videoPath, fileToUpload, retryAttempts: 3);

      // ── Step 3: Upload Thumbnail ──────────────────────────────────────
      _setStage(UploadStage.uploadingThumbnail);

      final ext = thumbnailFile.path.split('.').last.toLowerCase();
      final thumbFileName = '${uuid.v4()}.$ext';
      final thumbPath = '${user.id}/$thumbFileName';

      await Supabase.instance.client.storage
          .from('creator-thumbnails')
          .upload(thumbPath, thumbnailFile, retryAttempts: 3);

      final thumbUrl = Supabase.instance.client.storage
          .from('creator-thumbnails')
          .getPublicUrl(thumbPath);

      // ── Step 4: Insert DB Record ──────────────────────────────────────
      _setStage(UploadStage.insertingRecord);

      await Supabase.instance.client.from('creator_videos').insert({
        'creator_id': user.id,
        'video_url': videoPath,
        'thumbnail_url': thumbUrl,
        'title': (meta['title'] as String).isNotEmpty
            ? meta['title']
            : 'New Post',
        'description': meta['caption'],
        'tags': meta['tags'],
        'tmdb_id': meta['tmdbId'],
        'tmdb_type': meta['mediaType'],
        'spoiler': meta['containsSpoilers'],
        'duration_seconds': meta['durationSeconds'],
        'status': 'pending',
      });

      // ── Done ──────────────────────────────────────────────────────────
      _setStage(UploadStage.done);
    } catch (e) {
      debugPrint('[Upload] Pipeline error: $e');
      _stage = UploadStage.failed;
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      // Always clean up compression cache.
      VideoCompress.deleteAllCache();
    }
  }

  void _setStage(UploadStage s) {
    _stage = s;
    // Reset progress for non-compression stages (we don't have byte-level
    // progress from Supabase storage, so those stages show an indeterminate
    // indicator).
    if (s != UploadStage.compressing) _progress = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _compressSubscription?.unsubscribe();
    super.dispose();
  }
}
