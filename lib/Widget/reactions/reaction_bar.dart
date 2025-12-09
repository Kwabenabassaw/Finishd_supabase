import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Instagram-style sliding reaction bar
///
/// Features:
/// - Glassmorphism background with blur
/// - 5 emoji reactions: ❤️ 😂 😮 😢 😡
/// - Scale animation on hover (1.0 → 1.7x)
/// - Haptic feedback on emoji change
/// - Drag-to-select behavior
class ReactionBar extends StatefulWidget {
  final Function(String emoji, String type) onSelect;
  final VoidCallback? onDismiss;
  final String? currentReaction; // Current user's reaction type

  const ReactionBar({
    super.key,
    required this.onSelect,
    this.onDismiss,
    this.currentReaction,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar>
    with SingleTickerProviderStateMixin {
  // Reaction data
  static const List<Map<String, String>> reactions = [
    {'emoji': '❤️', 'type': 'heart'},
    {'emoji': '😂', 'type': 'laugh'},
    {'emoji': '😮', 'type': 'wow'},
    {'emoji': '😢', 'type': 'sad'},
    {'emoji': '😡', 'type': 'angry'},
  ];

  int? _hoveredIndex;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onSelect(int index) {
    final reaction = reactions[index];
    HapticFeedback.mediumImpact();
    widget.onSelect(reaction['emoji']!, reaction['type']!);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(reactions.length, (index) {
              final reaction = reactions[index];
              final isHovered = _hoveredIndex == index;
              final isCurrentReaction =
                  widget.currentReaction == reaction['type'];

              return GestureDetector(
                onTap: () => _onSelect(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  margin: EdgeInsets.symmetric(horizontal: isHovered ? 8 : 4),
                  child: AnimatedScale(
                    scale: isHovered ? 1.7 : (isCurrentReaction ? 1.2 : 1.0),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      transform: Matrix4.translationValues(
                        0,
                        isHovered ? -10 : 0,
                        0,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Text(
                            reaction['emoji']!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          // Show indicator for current reaction
                          if (isCurrentReaction && !isHovered)
                            Positioned(
                              bottom: -4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Draggable version of ReactionBar that handles long-press + drag
class DraggableReactionBar extends StatefulWidget {
  final Function(String emoji, String type) onSelect;
  final VoidCallback onDismiss;
  final String? currentReaction;
  final Offset anchorPosition;

  const DraggableReactionBar({
    super.key,
    required this.onSelect,
    required this.onDismiss,
    required this.anchorPosition,
    this.currentReaction,
  });

  @override
  State<DraggableReactionBar> createState() => _DraggableReactionBarState();
}

class _DraggableReactionBarState extends State<DraggableReactionBar>
    with SingleTickerProviderStateMixin {
  static const List<Map<String, String>> reactions = [
    {'emoji': '❤️', 'type': 'heart'},
    {'emoji': '😂', 'type': 'laugh'},
    {'emoji': '😮', 'type': 'wow'},
    {'emoji': '😢', 'type': 'sad'},
    {'emoji': '😡', 'type': 'angry'},
  ];

  int? _hoveredIndex;
  late AnimationController _appearController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Keys for calculating positions
  final List<GlobalKey> _emojiKeys = List.generate(5, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutBack),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOut),
    );
    _appearController.forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  void _updateHoverFromPosition(Offset globalPosition) {
    int? newIndex;

    for (int i = 0; i < _emojiKeys.length; i++) {
      final key = _emojiKeys[i];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final rect = Rect.fromLTWH(
          position.dx - 10, // Add some padding
          position.dy - 20,
          size.width + 20,
          size.height + 40,
        );

        if (rect.contains(globalPosition)) {
          newIndex = i;
          break;
        }
      }
    }

    if (newIndex != _hoveredIndex) {
      setState(() {
        _hoveredIndex = newIndex;
      });
      if (newIndex != null) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onPanEnd() {
    if (_hoveredIndex != null) {
      final reaction = reactions[_hoveredIndex!];
      HapticFeedback.mediumImpact();
      widget.onSelect(reaction['emoji']!, reaction['type']!);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: Listener(
        onPointerMove: (event) {
          _updateHoverFromPosition(event.position);
        },
        onPointerUp: (_) => _onPanEnd(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(reactions.length, (index) {
                  final reaction = reactions[index];
                  final isHovered = _hoveredIndex == index;
                  final isCurrentReaction =
                      widget.currentReaction == reaction['type'];

                  return Container(
                    key: _emojiKeys[index],
                    margin: EdgeInsets.symmetric(
                      horizontal: isHovered ? 10 : 6,
                    ),
                    child: AnimatedScale(
                      scale: isHovered ? 1.8 : (isCurrentReaction ? 1.2 : 1.0),
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        transform: Matrix4.translationValues(
                          0,
                          isHovered ? -15 : 0,
                          0,
                        ),
                        child: Text(
                          reaction['emoji']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
