import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';

/// Screen for creating a new post in a community
class CreatePostScreen extends StatefulWidget {
  final int showId;
  final String showTitle;
  final String? posterPath;
  final String mediaType;

  const CreatePostScreen({
    super.key,
    required this.showId,
    required this.showTitle,
    this.posterPath,
    required this.mediaType,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  List<XFile> _selectedMedia = [];
  bool _isSpoiler = false;
  bool _isPosting = false;
  List<String> _hashtags = [];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty && _selectedMedia.length < 4) {
      setState(() {
        _selectedMedia.addAll(images.take(4 - _selectedMedia.length));
      });
    }
  }

  Future<void> _pickVideo() async {
    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video != null && _selectedMedia.isEmpty) {
      setState(() {
        _selectedMedia = [video];
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  void _extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(text);
    setState(() {
      _hashtags = matches.map((m) => m.group(1)!).toList();
    });
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write something'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<CommunityProvider>(context, listen: false);

    // Show initial toast
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Uploading your post...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );

    // Pop the screen immediately
    Navigator.pop(context);

    // Perform the upload in the background
    try {
      final postId = await provider.createPost(
        showId: widget.showId,
        showTitle: widget.showTitle,
        posterPath: widget.posterPath,
        mediaType: widget.mediaType,
        content: content,
        mediaFiles: List.from(_selectedMedia),
        hashtags: List.from(_hashtags),
        isSpoiler: _isSpoiler,
      );

      if (postId != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Post uploaded successfully!'),
            backgroundColor: const Color(0xFF1A8927),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      print('Error creating post: $e');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to upload post: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
        ),
        leadingWidth: 80,
        title: Text(
          'New Post',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Consumer<CommunityProvider>(
              builder: (context, provider, child) {
                final isUploading = provider.isUploadingMedia || _isPosting;
                return ElevatedButton(
                  onPressed: isUploading ? null : _createPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post'),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Posting to indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group, color: primaryGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Posting to: /${widget.mediaType == 'tv' ? 'Shows' : 'Movies'}',
                    style: TextStyle(color: primaryGreen),
                  ),
                  Icon(Icons.expand_more, color: primaryGreen),
                ],
              ),
            ),
          ),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User avatar and text field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.hintColor.withOpacity(0.3),
                        child: Icon(Icons.person, color: theme.hintColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          maxLines: null,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText:
                                'Share your thoughts or start a discussion...',
                            hintStyle: TextStyle(color: theme.hintColor),
                            border: InputBorder.none,
                          ),
                          onChanged: _extractHashtags,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Selected media preview
                  if (_selectedMedia.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedMedia.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_selectedMedia[index].path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 20,
                                child: GestureDetector(
                                  onTap: () => _removeMedia(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  // Spoiler toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isSpoiler,
                          onChanged: (value) {
                            setState(() => _isSpoiler = value ?? false);
                          },
                          activeColor: primaryGreen,
                        ),
                        Text(
                          'Mark as spoiler',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                _buildToolbarButton(
                  Icons.image,
                  'Photo',
                  _pickImage,
                  primaryGreen,
                ),
                _buildToolbarButton(Icons.gif_box, 'GIF', () {}, primaryGreen),
                _buildToolbarButton(
                  Icons.videocam,
                  'Video',
                  _pickVideo,
                  primaryGreen,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                _buildToolbarButton(Icons.tag, 'Tag', () {}, primaryGreen),
                _buildToolbarButton(
                  Icons.location_on,
                  'Location',
                  () {},
                  primaryGreen,
                ),
                const Spacer(),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.hintColor, width: 2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}
