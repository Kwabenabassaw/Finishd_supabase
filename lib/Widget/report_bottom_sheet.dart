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
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Report ${_getContentTypeName()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const Divider(),

          // Reasons List
          const Text(
            'Why are you reporting this?',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: ReportReason.values.map((reason) {
                return RadioListTile<ReportReason>(
                  title: Text(_getReasonText(reason)),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (val) => setState(() => _selectedReason = val),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.red,
                );
              }).toList(),
            ),
          ),

          // Additional Info
          if (_selectedReason != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _additionalInfoController,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
            ),
          ],

          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedReason != null && !_isLoading)
                  ? _submitReport
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit Report'),
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
