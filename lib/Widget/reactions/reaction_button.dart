import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finishd/Model/reaction_data.dart';
import 'package:finishd/services/reaction_service.dart';
import 'package:finishd/Widget/reactions/reaction_bar.dart';

/// Instagram-style reaction button
///
/// Features:
/// - Tap → quick heart reaction
/// - Long-press → open reaction bar for selection
/// - Shows current user's emoji or empty heart
/// - Animated transitions
/// - Real-time updates from Firestore
class ReactionButton extends StatefulWidget {
  final String videoId;
  final String userId;
  final double size;
  final Color? color;
  final bool showCount;

  const ReactionButton({
    super.key,
    required this.videoId,
    required this.userId,
    this.size = 28,
    this.color,
    this.showCount = true,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  final ReactionService _reactionService = ReactionService();

  ReactionData? _currentReaction;
  int _totalCount = 0;
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      }
    });

    _loadReaction();
    _loadCount();
  }

  @override
  void dispose() {
    _removeOverlay();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadReaction() async {
    if (widget.userId.isEmpty) return;

    final reaction = await _reactionService.getUserReaction(
      videoId: widget.videoId,
      userId: widget.userId,
    );

    if (mounted) {
      setState(() {
        _currentReaction = reaction;
      });
    }
  }

  Future<void> _loadCount() async {
    final count = await _reactionService.getTotalReactionCount(widget.videoId);
    if (mounted) {
      setState(() {
        _totalCount = count;
      });
    }
  }

  /// Handle quick tap - toggle heart reaction
  Future<void> _onTap() async {
    if (_isLoading || widget.userId.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final wasAdded = await _reactionService.toggleReaction(
        videoId: widget.videoId,
        userId: widget.userId,
        reactionType: 'heart',
        emoji: '❤️',
      );

      if (mounted) {
        setState(() {
          if (wasAdded) {
            _currentReaction = ReactionData(
              type: 'heart',
              emoji: '❤️',
              timestamp: DateTime.now(),
              userId: widget.userId,
              videoId: widget.videoId,
            );
            _totalCount++;
          } else {
            _totalCount = (_totalCount > 0) ? _totalCount - 1 : 0;
            _currentReaction = null;
          }
        });
        _pulseController.forward();
      }
    } catch (e) {
      print('Error toggling reaction: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle long press - show reaction bar
  void _onLongPress() {
    HapticFeedback.mediumImpact();
    _showReactionBar();
  }

  void _showReactionBar() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Calculate position for the reaction bar
    // Center it above the button
    final barWidth = 280.0; // Approximate width of reaction bar
    final screenWidth = MediaQuery.of(context).size.width;

    double left = position.dx + (size.width / 2) - (barWidth / 2);
    // Keep within screen bounds
    if (left < 16) left = 16;
    if (left + barWidth > screenWidth - 16) left = screenWidth - barWidth - 16;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss area
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Reaction bar
          Positioned(
            left: left,
            top: position.dy - 70, // Position above the button
            child: Material(
              color: Colors.transparent,
              child: DraggableReactionBar(
                currentReaction: _currentReaction?.type,
                anchorPosition: position,
                onSelect: _onReactionSelected,
                onDismiss: _removeOverlay,
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _onReactionSelected(String emoji, String type) async {
    _removeOverlay();

    if (_isLoading || widget.userId.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final hadReaction = _currentReaction != null;

      await _reactionService.reactToVideo(
        videoId: widget.videoId,
        userId: widget.userId,
        reactionType: type,
        emoji: emoji,
      );

      if (mounted) {
        setState(() {
          _currentReaction = ReactionData(
            type: type,
            emoji: emoji,
            timestamp: DateTime.now(),
            userId: widget.userId,
            videoId: widget.videoId,
          );
          if (!hadReaction) {
            _totalCount++;
          }
        });
        _pulseController.forward();
      }
    } catch (e) {
      print('Error setting reaction: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayEmoji = _currentReaction?.emoji ?? '🤍';

    return GestureDetector(
      onTap: _onTap,
      onLongPress: _onLongPress,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                displayEmoji,
                key: ValueKey(displayEmoji),
                style: TextStyle(fontSize: widget.size),
              ),
            ),
            if (widget.showCount && _totalCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatCount(_totalCount),
                  style: TextStyle(
                    color: widget.color ?? Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// Compact reaction button for use in feed items
class CompactReactionButton extends StatelessWidget {
  final String videoId;
  final String userId;
  final double size;

  const CompactReactionButton({
    super.key,
    required this.videoId,
    required this.userId,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ReactionButton(
      videoId: videoId,
      userId: userId,
      size: size,
      showCount: true,
      color: Colors.white,
    );
  }
}
