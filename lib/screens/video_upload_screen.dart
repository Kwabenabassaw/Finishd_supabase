import 'dart:io';
import 'dart:async';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/provider/video_upload_provider.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _captionController = TextEditingController();
  final _titleController = TextEditingController(); // Search Movies placeholder

  File? _videoFile;
  File? _thumbnailFile;
  VideoPlayerController? _videoController;

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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Extract hashtags before popping.
    final tags = _extractHashtags(_captionController.text);

    // Kick off background upload and pop immediately.
    context.read<VideoUploadProvider>().startUpload(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile!,
      caption: _captionController.text,
      title: _titleController.text,
      tags: tags,
      tmdbId: _tmdbId,
      mediaType: _mediaType,
      containsSpoilers: _containsSpoilers,
      durationSeconds: duration,
    );

    Navigator.pop(context);
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
            icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'New Post',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Save as draft logic
              },
              child: Text(
                'Drafts',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            children: [
              // Preview Area
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 45.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(4.w),
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
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library,
                              color: Theme.of(
                                context,
                              ).iconTheme.color?.withOpacity(0.5),
                              size: 40.sp,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Tap to select video',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withOpacity(0.6),
                                  ),
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
                              padding: EdgeInsets.all(3.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 24.sp,
                              ),
                            ),

                            // Edit/Crop button
                            Positioned(
                              bottom: 2.h,
                              right: 4.w,
                              child: IconButton(
                                onPressed: _pickVideo, // Re-pick
                                icon: Icon(
                                  Icons.crop_rotate,
                                  size: 16.sp,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 2.h),

              // Thumbnail Picker Button
              if (_videoFile != null)
                TextButton.icon(
                  onPressed: _pickThumbnail,
                  icon: Icon(
                    Icons.image,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.7),
                    size: 16.sp,
                  ),
                  label: Text(
                    _thumbnailFile == null
                        ? 'Select Cover Image'
                        : 'Change Cover Image',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ),

              SizedBox(height: 3.h),

              // Tag Title
              _buildSectionTitle('Tag Title'),
              GestureDetector(
                onTap: () {
                  _showTmdbSearchSheet();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.movie,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16.sp,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          _titleController.text.isEmpty
                              ? 'Search Movies or TV Shows...'
                              : _titleController.text,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: _titleController.text.isEmpty
                                    ? Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withOpacity(0.4)
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                              ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 1.5.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(1.w),
                        ),
                        child: Text(
                          'TMDB',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 3.h),

              // Caption
              _buildSectionTitle('Caption', trailing: '0/2200'),
              TextField(
                controller: _captionController,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'What did you think? Share your review here...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.color?.withOpacity(0.4),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 3.h),

              // Spoilers Toggle
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contains Spoilers?',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Mark to blur preview for others',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _containsSpoilers,
                      onChanged: (v) => setState(() => _containsSpoilers = v),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 7.h,
                child: ElevatedButton(
                  onPressed: _submitVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.w),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Submit for Review',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors
                              .white, // Elevated button text remains explicitly light
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4.h),
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
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).textTheme.titleMedium?.color?.withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4),
              ),
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
          width: 10.w,
          height: 0.6.h,
          margin: EdgeInsets.symmetric(vertical: 1.5.h),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerTheme.color,
            borderRadius: BorderRadius.circular(1.w),
          ),
        ),

        // Search Bar
        Padding(
          padding: EdgeInsets.all(4.w),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search movies & TV shows...',
              hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
              ),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
              filled: true,
              fillColor: Theme.of(context).cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3.w),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
            ),
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                )
              : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie_filter,
                        size: 40.sp,
                        color: Theme.of(context).iconTheme.color?.withOpacity(0.2),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Search for a title to tag',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      onTap: () => widget.onSelect(item),
                      contentPadding: EdgeInsets.symmetric(vertical: 1.h),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(2.w),
                        child: item.posterPath.isNotEmpty
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w92${item.posterPath}',
                                width: 13.w,
                                height: 9.h,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 13.w,
                                  height: 9.h,
                                  color: Theme.of(context).cardTheme.color,
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 16.sp,
                                    color: Theme.of(context).iconTheme.color?.withOpacity(0.3),
                                  ),
                                ),
                              )
                            : Container(
                                width: 13.w,
                                height: 9.h,
                                color: Theme.of(context).cardTheme.color,
                                child: Icon(
                                  Icons.movie,
                                  color: Theme.of(context).iconTheme.color?.withOpacity(0.2),
                                  size: 16.sp,
                                ),
                              ),
                      ),
                      title: Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${item.mediaType.toUpperCase()} • ${item.releaseDate.split('-').first}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                      trailing: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).iconTheme.color?.withOpacity(0.4),
                        size: 20.sp,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
