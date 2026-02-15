import 'package:flutter/material.dart';
import 'package:finishd/models/report_model.dart';
import 'package:finishd/services/community_service.dart';

class ReportBottomSheet extends StatefulWidget {
  final ReportType type;
  final String contentId;
  final String reportedUserId;
  final String? communityId;
  final String? parentContentId;

  const ReportBottomSheet({
    Key? key,
    required this.type,
    required this.contentId,
    required this.reportedUserId,
    this.communityId,
    this.parentContentId,
  }) : super(key: key);

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final CommunityService _communityService = CommunityService();
  ReportReason? _selectedReason;
  final TextEditingController _additionalInfoController =
      TextEditingController();
  bool _isLoading = false;

  void _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isLoading = true);

    try {
      await _communityService.reportContent(
        type: widget.type,
        reason: _selectedReason!,
        contentId: widget.contentId,
        reportedUserId: widget.reportedUserId,
        communityId: widget.communityId,
        additionalInfo: _additionalInfoController.text.trim(),
        // contentSnapshot could be passed, but backend can fetch it or we rely on ID
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted. Thank you for making the community safer.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Report Content',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Reason for report:', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...ReportReason.values.map((reason) {
            String label =
                reason.name[0].toUpperCase() + reason.name.substring(1);
            if (reason == ReportReason.inappropriate)
              label = 'Inappropriate Content';

            return RadioListTile<ReportReason>(
              title: Text(label),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (val) => setState(() => _selectedReason = val),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
          if (_selectedReason == ReportReason.other) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _additionalInfoController,
              decoration: const InputDecoration(
                hintText: 'Please provide more details...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason == null || _isLoading
                  ? null
                  : _submitReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }
}
