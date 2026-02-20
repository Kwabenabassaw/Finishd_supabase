import 'dart:io';
import 'dart:async';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/services/storage_service.dart';
import 'package:finishd/theme/app_colors.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_compress/video_compress.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final StorageService _storageService = StorageService();
  final _captionController = TextEditingController();
  final _titleController = TextEditingController(); // Search Movies placeholder

  File? _videoFile;
  File? _thumbnailFile;
  VideoPlayerController? _videoController;

  bool _isUploading = false;
  bool _containsSpoilers = false;
  int? _tmdbId; // To link to a movie (placeholder for now)
  String? _mediaType; // 'movie' or 'tv'

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60), // Match DB constraint (Max 60s)
    );

    if (video != null) {
      final file = File(video.path);
      _videoFile = file;

      // Initialize controller
      _videoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _thumbnailFile = File(image.path));
    }
  }

  Future<void> _submitVideo() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a video')));
      return;
    }
    if (_thumbnailFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cover image')),
      );
      return;
    }

    if (_videoController == null || !_videoController!.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video is not ready yet')));
      return;
    }

    final duration = _videoController!.value.duration.inSeconds;
    if (duration < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video must be at least 5 seconds long')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 0. Compress Video
      File fileToUpload = _videoFile!;
      try {
        final info = await VideoCompress.compressVideo(
          _videoFile!.path,
          quality: VideoQuality.MediumQuality, // Good balance for mobile
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info != null && info.file != null) {
          fileToUpload = info.file!;
          // Optional: Use generated thumbnail if user didn't pick one?
          // For now, we stick to user's choice or we could fallback.
        }
      } catch (e) {
        print("Compression failed: $e. Uploading original.");
      }

      // 1. Upload Video
      final videoPath = await _storageService.uploadCreatorVideo(
        fileToUpload,
        user.id,
      );

      // 2. Upload Thumbnail
      final thumbUrl = await _storageService.uploadCreatorThumbnail(
        _thumbnailFile!,
        user.id,
      );

      // 3. Parse Hashtags
      final tags = _extractHashtags(_captionController.text);

      // 4. Create DB Record
      await Supabase.instance.client.from('creator_videos').insert({
        'creator_id': user.id,
        'video_url': videoPath,
        'thumbnail_url': thumbUrl,
        'title': _titleController.text.isNotEmpty
            ? _titleController.text
            : 'New Post',
        'description': _captionController.text,
        'tags': tags, // NEW: Hashtags array
        'tmdb_id': _tmdbId,
        'tmdb_type': _mediaType,
        'spoiler': _containsSpoilers,
        'duration_seconds': _videoController?.value.duration.inSeconds ?? 0,
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video submitted for review!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Clear cache
      VideoCompress.deleteAllCache();
      if (mounted) setState(() => _isUploading = false);
    }
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r"\#\w+");
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0505),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'New Post',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Save as draft logic
              },
              child: const Text('Drafts', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Preview Area
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    image: _videoFile == null
                        ? null
                        : (_thumbnailFile != null
                              ? DecorationImage(
                                  image: FileImage(_thumbnailFile!),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.3),
                                    BlendMode.darken,
                                  ),
                                )
                              : null),
                  ),
                  child: _videoFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library,
                              color: Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tap to select video',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            // If we have a controller, show video
                            if (_videoController != null &&
                                _videoController!.value.isInitialized)
                              AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),

                            // Play icon overlay
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),

                            // Edit/Crop button
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: IconButton(
                                onPressed: _pickVideo, // Re-pick
                                icon: const Icon(Icons.crop_rotate),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Thumbnail Picker Button
              if (_videoFile != null)
                TextButton.icon(
                  onPressed: _pickThumbnail,
                  icon: const Icon(Icons.image, color: Colors.white70),
                  label: Text(
                    _thumbnailFile == null
                        ? 'Select Cover Image'
                        : 'Change Cover Image',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),

              const SizedBox(height: 24),

              // Tag Title
              _buildSectionTitle('Tag Title'),
              GestureDetector(
                onTap: () {
                  _showTmdbSearchSheet();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.movie, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _titleController.text.isEmpty
                              ? 'Search Movies or TV Shows...'
                              : _titleController.text,
                          style: TextStyle(
                            color: _titleController.text.isEmpty
                                ? Colors.white38
                                : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TMDB',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Caption
              _buildSectionTitle('Caption', trailing: '0/2200'),
              TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'What did you think? Share your review here...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Spoilers Toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contains Spoilers?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Mark to blur preview for others',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: _containsSpoilers,
                      onChanged: (v) => setState(() => _containsSpoilers = v),
                      activeColor: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Submit for Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.white),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showTmdbSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _TmdbSearchContent(
          onSelect: (item) {
            setState(() {
              _tmdbId = item.id;
              _mediaType = item.mediaType;
              _titleController.text = item.title;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _TmdbSearchContent extends StatefulWidget {
  final Function(MediaItem) onSelect;

  const _TmdbSearchContent({required this.onSelect});

  @override
  State<_TmdbSearchContent> createState() => _TmdbSearchContentState();
}

class _TmdbSearchContentState extends State<_TmdbSearchContent> {
  final TextEditingController _searchController = TextEditingController();
  final Trending _tmdbService = Trending();
  List<MediaItem> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() => _results = []);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await _tmdbService.searchMedia(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search movies & TV shows...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                )
              : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie_filter,
                        size: 48,
                        color: Colors.grey[800],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Search for a title to tag',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      onTap: () => widget.onSelect(item),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.posterPath.isNotEmpty
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w92${item.posterPath}',
                                width: 50,
                                height: 75,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 75,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 75,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.white24,
                                ),
                              ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${item.mediaType.toUpperCase()} • ${item.releaseDate.split('-').first}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white38,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
