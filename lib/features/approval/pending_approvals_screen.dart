import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../shared/receipt/receipt_viewer.dart';
import 'approval_service.dart';
import 'models/approval_models.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ApprovalService _svc = ApprovalService();

  bool _loading = true;
  String? _error;

  int? _userId;
  List<String> _roles = [];
  List<PendingApprovalDto> _items = [];

  Color _statusColor(String code) {
    switch (code.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'DECLINED':
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      case 'RETURNED':
      case 'RETURNED_BY_FINANCE':
        return Colors.purple;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  bool get _isProcessor =>
      _roles.map((e) => e.toUpperCase()).contains("PROCESSOR");

  String _money(double? v) => '\$${(v ?? 0).toStringAsFixed(2)}';

  String _receiptUrl(String filename) =>
      '${AppConfig.baseUrl}/uploads/$filename';

  Future<void> _openReceipt(String filename) async {
    if (!mounted) return;
    // If you want to reuse your ReceiptViewer helper:
    // ReceiptViewer.openReceipt(context, imageFilename: filename);
    //
    // Otherwise open via URL:
    final url = _receiptUrl(filename);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReceiptViewerScreenByUrl(imageUrl: url),
      ),
    );
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await _svc.getUserId();
      final roles = await _svc.getUserRoleNames();
      final pending = await _svc.fetchPendingApprovals(userId);

      setState(() {
        _userId = userId;
        _roles = roles;
        _items = pending;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  Future<void> _approve(PendingApprovalDto item) async {
    final userId = _userId;
    if (userId == null) {
      _toast("No logged-in user found.");
      return;
    }

    final ok = await _confirm(
      title: "Confirm Approval",
      message: "Are you sure you want to approve this request?",
      confirmText: "Approve",
    );
    if (!ok) return;

    try {
      await _svc.approve(approvalId: item.id, userId: userId);
      _toast("Approved successfully ✅");
      await _fetch();
    } catch (e) {
      _toast(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _decline(PendingApprovalDto item) async {
    final userId = _userId;
    if (userId == null) {
      _toast("No logged-in user found.");
      return;
    }

    final reason = await _promptDeclineReason();
    if (reason == null) return; // cancelled
    if (reason.trim().isEmpty) {
      _toast("Please enter a reason for declining.");
      return;
    }

    try {
      await _svc.decline(
        approvalId: item.id,
        userId: userId,
        remarks: reason.trim(),
      );
      _toast("Declined successfully ✅");
      await _fetch();
    } catch (e) {
      _toast(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _promptDeclineReason() async {
    if (!mounted) return null;

    String reason = "";

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text("Confirm Decline"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Please enter a reason for declining:"),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Enter reason...",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setLocalState(() => reason = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(null),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(reason),
                  child: const Text("Decline"),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final title = _isProcessor ? "Requests" : "Pending Approvals";

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          if (_items.isEmpty) ...[
            const SizedBox(height: 80),
            const Icon(Icons.inbox_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "No pending approvals.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ] else ...[
            ..._items.map(
              (a) => _ApprovalCard(
                item: a,
                money: _money,
                statusColor: _statusColor,
                onApprove: () => _approve(a),
                onDecline: () => _decline(a),
                onViewReceipt:
                    (a.imageFilename == null || a.imageFilename!.trim().isEmpty)
                    ? null
                    : () => _openReceipt(a.imageFilename!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.money,
    required this.statusColor,
    required this.onApprove,
    required this.onDecline,
    this.onViewReceipt,
  });

  final PendingApprovalDto item;
  final String Function(double?) money;
  final Color Function(String) statusColor;

  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback? onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final hasReceipt =
        item.imageFilename != null && item.imageFilename!.trim().isNotEmpty;

    final statusCode = (item.status?.code ?? 'PENDING').toUpperCase();
    final chipColor = statusColor(statusCode);

    final title = (item.applicantName?.trim().isNotEmpty == true)
        ? item.applicantName!.trim()
        : 'Applicant';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: applicant + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _chip(statusCode, chipColor),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              runSpacing: 8,
              spacing: 10,
              children: [
                _mini("Department", item.department ?? "N/A"),
                _mini("Type", item.type ?? "N/A"),
                _mini("Amount", money(item.priceWithTax)),
                _mini(
                  "Remarks",
                  (item.remarks?.trim().isNotEmpty == true)
                      ? item.remarks!.trim()
                      : "No remarks",
                ),

                // optional but useful
                if (item.approver?.trim().isNotEmpty == true)
                  _mini("Approver", item.approver!.trim()),
                if (item.sequenceOrder > 0)
                  _mini("Step", item.sequenceOrder.toString()),
                if (item.visaApplicationId > 0)
                  _mini("App ID", item.visaApplicationId.toString()),
              ],
            ),
            const SizedBox(height: 12),

            // Receipt
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasReceipt ? onViewReceipt : null,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(hasReceipt ? "View Receipt" : "No Image"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Approve"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text("Decline"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _mini(String k, String v) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            v,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

/// Lightweight receipt screen by URL.
/// If you already have a shared receipt viewer, feel free to delete this and use yours.
class _ReceiptViewerScreenByUrl extends StatelessWidget {
  const _ReceiptViewerScreenByUrl({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Receipt")),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              );
            },
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Failed to load receipt.\n\n$imageUrl",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
