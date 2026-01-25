import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:finishd/Widget/gif_picker_sheet.dart';
import 'package:finishd/models/gif_model.dart';
import 'package:sizer/sizer.dart';

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
  final List<String> _selectedGifUrls = [];
  bool _isSpoiler = false;
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

  void _removeGif(int index) {
    setState(() {
      _selectedGifUrls.removeAt(index);
    });
  }

  Future<void> _pickGif() async {
    final GifModel? gif = await showModalBottomSheet<GifModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GifPickerSheet(),
    );

    if (gif != null && gif.gifUrl.isNotEmpty) {
      if (_selectedMedia.length + _selectedGifUrls.length < 4) {
        setState(() {
          _selectedGifUrls.add(gif.gifUrl);
        });
      }
    }
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
              child: LogoLoadingScreen(),
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
        gifUrls: List.from(_selectedGifUrls),
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
                final isUploading = provider.isUploadingMedia;
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
                          child: LogoLoadingScreen(),
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
                    'Posting to: /${widget.mediaType == 'tv' ? 'Shows' : 'Movies'} ${widget.showTitle}',
                    style: TextStyle(color: primaryGreen, fontSize: 14.sp),
                    overflow: TextOverflow.ellipsis,
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
                      Builder(builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        return UserAvatar(
                          radius: 24,
                          profileImageUrl: user?.photoURL,
                          firstName: user?.displayName ??
                              user?.email?.split('@').first ??
                              'User',
                          userId: user?.uid ?? '',
                        );
                      }),
                      const SizedBox(width: 12),
                      Expanded(

                        child: TextField(
                          controller: _contentController,
                        
                          maxLines: null,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            
                          contentPadding: EdgeInsets.all(10),

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
                  if (_selectedMedia.isNotEmpty || _selectedGifUrls.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._selectedMedia.asMap().entries.map((entry) {
                            int index = entry.key;
                            XFile file = entry.value;
                            return _buildMediaPreview(
                              context,
                              Image.file(File(file.path), fit: BoxFit.cover),
                              () => _removeMedia(index),
                            );
                          }),
                          ..._selectedGifUrls.asMap().entries.map((entry) {
                            int index = entry.key;
                            String url = entry.value;
                            return _buildMediaPreview(
                              context,
                              Image.network(url, fit: BoxFit.cover),
                              () => _removeGif(index),
                            );
                          }),
                        ],
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
                _buildToolbarButton(
                  Icons.gif_box,
                  'GIF',
                  _pickGif,
                  primaryGreen,
                ),
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
             
              
                const Spacer(),
               
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

  Widget _buildMediaPreview(
    BuildContext context,
    Widget image,
    VoidCallback onRemove,
  ) {
    return Stack(
      children: [
        Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image,
          ),
        ),
        Positioned(
          top: 8,
          right: 20,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
