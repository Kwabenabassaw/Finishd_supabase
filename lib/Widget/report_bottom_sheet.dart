import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finishd/models/report_model.dart';
import 'package:finishd/services/report_service.dart';

class ReportBottomSheet extends StatefulWidget {
  final ReportType type;
  final String contentId; // postId, commentId, or messageId
  final String reportedUserId;
  final String? communityId; // required for post/comment
  final String? chatId; // required for message

  // For hierarchical contexts (e.g. comment needs postId)
  final String? parentContentId;

  const ReportBottomSheet({
    super.key,
    required this.type,
    required this.contentId,
    required this.reportedUserId,
    this.communityId,
    this.chatId,
    this.parentContentId,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final _reportService = ReportService();
  ReportReason? _selectedReason;
  final _additionalInfoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isLoading = true);

    try {
      switch (widget.type) {
        case ReportType.communityPost:
          await _reportService.reportCommunityPost(
            postId: widget.contentId,
            communityId: widget.communityId!,
            authorId: widget.reportedUserId,
            reason: _selectedReason!,
            additionalInfo: _additionalInfoController.text.trim(),
          );
          break;

        case ReportType.communityComment:
          await _reportService.reportCommunityComment(
            commentId: widget.contentId,
            postId: widget.parentContentId!,
            communityId: widget.communityId!,
            authorId: widget.reportedUserId,
            reason: _selectedReason!,
            additionalInfo: _additionalInfoController.text.trim(),
          );
          break;

        case ReportType.chatMessage:
          await _reportService.reportChatMessage(
            messageId: widget.contentId,
            chatId: widget.chatId!,
            senderId: widget.reportedUserId,
            reason: _selectedReason!,
            additionalInfo: _additionalInfoController.text.trim(),
          );
          break;
      }

      if (mounted) {
        context.pop(); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted. Thank you for helping keep our community safe.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.report_gmailerrorred_rounded,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Report ${_getContentTypeName()}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
                style: IconButton.styleFrom(
                  backgroundColor: theme.dividerColor.withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Instruction Text
          Text(
            'Why are you reporting this?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Reasons List
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ReportReason.values.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 52,
                  color: theme.dividerColor.withOpacity(0.05),
                ),
                itemBuilder: (context, index) {
                  final reason = ReportReason.values[index];
                  final isSelected = _selectedReason == reason;
                  return RadioListTile<ReportReason>(
                    title: Text(
                      _getReasonText(reason),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : null,
                        color: isSelected
                            ? null
                            : theme.textTheme.bodyMedium?.color?.withOpacity(
                                0.8,
                              ),
                      ),
                    ),
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (val) => setState(() => _selectedReason = val),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    activeColor: theme.colorScheme.error,
                    controlAffinity: ListTileControlAffinity.trailing,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                },
              ),
            ),
          ),

          // Additional Info (Animated Visibility)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _selectedReason != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _additionalInfoController,
                          decoration: InputDecoration(
                            hintText: 'Anything else we should know?',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: theme.cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.dividerColor.withOpacity(0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error.withOpacity(0.5),
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 3,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedReason != null && !_isLoading)
                  ? _submitReport
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.colorScheme.error.withOpacity(
                  0.3,
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Submit Report',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getContentTypeName() {
    switch (widget.type) {
      case ReportType.communityPost:
        return 'Post';
      case ReportType.communityComment:
        return 'Comment';
      case ReportType.chatMessage:
        return 'Message';
    }
  }

  String _getReasonText(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'It\'s spam';
      case ReportReason.harassment:
        return 'Harassment or bullying';
      case ReportReason.inappropriate:
        return 'Nudity or sexual activity';
      case ReportReason.misinformation:
        return 'False information';
      case ReportReason.hate:
        return 'Hate speech or symbols';
      case ReportReason.copyright:
        return 'Intellectual property violation';
      case ReportReason.other:
        return 'Something else';
    }
  }
}
