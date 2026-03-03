import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/video_upload_provider.dart';

/// Global overlay that shows upload progress at the bottom of the screen.
///
/// Wrap this around your app's main content (inside MaterialApp's builder or
/// around the Scaffold) so it can display regardless of which screen the user
/// navigates to.
class UploadProgressOverlay extends StatelessWidget {
  final Widget child;

  const UploadProgressOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // The floating pill
        Consumer<VideoUploadProvider>(
          builder: (context, upload, _) {
            if (upload.stage == UploadStage.idle) {
              return const SizedBox.shrink();
            }

            return Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 70,
              child: _UploadPill(upload: upload),
            );
          },
        ),
      ],
    );
  }
}

class _UploadPill extends StatelessWidget {
  final VideoUploadProvider upload;

  const _UploadPill({required this.upload});

  @override
  Widget build(BuildContext context) {
    final isDone = upload.stage == UploadStage.done;
    final isFailed = upload.stage == UploadStage.failed;
    final isCompressing = upload.stage == UploadStage.compressing;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isFailed
              ? const Color(0xFF3D1517)
              : isDone
              ? const Color(0xFF153319)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFailed
                ? Colors.red.withValues(alpha: 0.4)
                : isDone
                ? Colors.green.withValues(alpha: 0.4)
                : Colors.white12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Icon
                _buildIcon(isDone, isFailed, isCompressing),
                const SizedBox(width: 12),

                // Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upload.stageLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isFailed && upload.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            upload.errorMessage!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions
                if (isDone || isFailed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFailed)
                        _PillAction(
                          label: 'Retry',
                          color: Colors.orange,
                          onTap: () => upload.retry(),
                        ),
                      const SizedBox(width: 4),
                      _PillAction(
                        label: 'Dismiss',
                        color: Colors.white54,
                        onTap: () => upload.dismiss(),
                      ),
                    ],
                  ),
              ],
            ),

            // Progress bar (only during active stages)
            if (!isDone && !isFailed) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: isCompressing
                    ? LinearProgressIndicator(
                        value: upload.progress > 0 ? upload.progress : null,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE50914),
                        ),
                        minHeight: 3,
                      )
                    : const LinearProgressIndicator(
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFE50914),
                        ),
                        minHeight: 3,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(bool isDone, bool isFailed, bool isCompressing) {
    if (isDone) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }
    if (isFailed) {
      return const Icon(Icons.error, color: Colors.red, size: 24);
    }
    if (isCompressing) {
      return const Icon(Icons.compress, color: Color(0xFFE50914), size: 24);
    }
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PillAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
