import 'package:flutter/material.dart';

class FullscreenImagePreview extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;
  final String? caption;

  const FullscreenImagePreview({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.caption,
  });

  @override
  State<FullscreenImagePreview> createState() => _FullscreenImagePreviewState();
}

class _FullscreenImagePreviewState extends State<FullscreenImagePreview>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Offset>? _dismissAnimation;

  double _dragOffset = 0;
  double _opacity = 1.0;
  bool _isDragging = false;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
      // Don't dismiss if zoomed in
      return;
    }

    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dy;
      // Calculate opacity based on drag offset (max 300 pixels for full transparency)
      _opacity = (1 - (_dragOffset.abs() / 400)).clamp(0.5, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    if (_dragOffset.abs() > 150) {
      // Dismiss the screen
      Navigator.of(context).pop();
    } else {
      // Snap back to center
      _dismissAnimation =
          Tween<Offset>(
            begin: Offset(0, _dragOffset),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOut,
            ),
          );

      _animationController.reset();
      _animationController.forward().then((_) {
        setState(() {
          _dragOffset = 0;
          _opacity = 1.0;
          _isDragging = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_opacity),
      body: Stack(
        children: [
          // Background - allows closing when clicking outside the image
          GestureDetector(
            onTap: () {
              setState(() => _showUI = !_showUI);
            },
            child: Container(color: Colors.transparent),
          ),

          // The Image with dismissal logic
          Center(
            child: GestureDetector(
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              onTap: () {
                setState(() => _showUI = !_showUI);
              },
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final offset = _isDragging
                      ? Offset(0, _dragOffset)
                      : (_dismissAnimation?.value ?? Offset.zero);

                  return Transform.translate(
                    offset: offset,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.1,
                      maxScale: 4.0,
                      child: Hero(
                        tag: widget.heroTag ?? widget.imageUrl,
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Close button
          if (_showUI)
            Positioned(
              top: 50,
              left: 20,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

          // Caption
          if (_showUI && widget.caption != null && widget.caption!.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Text(
                    widget.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
