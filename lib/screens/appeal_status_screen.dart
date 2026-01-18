import 'dart:async';
import 'package:flutter/material.dart';
import 'package:finishd/models/appeal_model.dart';
import 'package:finishd/services/appeal_service.dart';

/// Screen for users to track the status of their appeals
class AppealStatusScreen extends StatefulWidget {
  const AppealStatusScreen({super.key});

  @override
  State<AppealStatusScreen> createState() => _AppealStatusScreenState();
}

class _AppealStatusScreenState extends State<AppealStatusScreen> {
  final _appealService = AppealService();
  StreamSubscription? _subscription;
  List<Appeal> _appeals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppeals();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppeals() async {
    try {
      final appeals = await _appealService.getMyAppeals();
      if (mounted) {
        setState(() {
          _appeals = appeals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startListening() {
    _subscription = _appealService.streamMyAppeals().listen((appeals) {
      if (mounted) {
        setState(() => _appeals = appeals);
      }
    });
  }

  Color _getStatusColor(AppealStatus status) {
    switch (status) {
      case AppealStatus.pending:
        return Colors.orange;
      case AppealStatus.approved:
        return Colors.green;
      case AppealStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(AppealStatus status) {
    switch (status) {
      case AppealStatus.pending:
        return Icons.hourglass_top_rounded;
      case AppealStatus.approved:
        return Icons.check_circle_rounded;
      case AppealStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  String _getStatusText(AppealStatus status) {
    switch (status) {
      case AppealStatus.pending:
        return 'Pending Review';
      case AppealStatus.approved:
        return 'Approved';
      case AppealStatus.rejected:
        return 'Rejected';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Appeals'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appeals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: theme.hintColor),
                  const SizedBox(height: 16),
                  Text(
                    'No Appeals Yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Any appeals you submit will appear here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAppeals,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _appeals.length,
                itemBuilder: (context, index) {
                  final appeal = _appeals[index];
                  return _buildAppealCard(appeal, theme);
                },
              ),
            ),
    );
  }

  Widget _buildAppealCard(Appeal appeal, ThemeData theme) {
    final statusColor = _getStatusColor(appeal.status);
    final actionLabel = appeal.actionType == AppealActionType.ban
        ? 'Ban Appeal'
        : 'Suspension Appeal';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(appeal.status),
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(appeal.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  actionLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Original reason
            Text(
              'Original Reason',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(appeal.originalReason, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),

            // User's appeal message
            Text(
              'Your Appeal',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(appeal.appealMessage, style: theme.textTheme.bodyMedium),

            // Admin response (if any)
            if (appeal.adminResponse != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moderator Response',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appeal.adminResponse!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Timestamp
            Text(
              'Submitted ${_formatDate(appeal.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
