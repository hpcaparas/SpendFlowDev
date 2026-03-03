import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import 'approval_service.dart';
import 'models/approval_models.dart';

class ApprovalHistoryScreen extends StatefulWidget {
  const ApprovalHistoryScreen({super.key});

  @override
  State<ApprovalHistoryScreen> createState() => _ApprovalHistoryScreenState();
}

class _ApprovalHistoryScreenState extends State<ApprovalHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ApprovalService _svc = ApprovalService();

  bool _loading = true;
  String? _error;

  int? _userId;
  List<String> _roles = [];
  List<PendingApprovalDto> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  bool get _isProcessor =>
      _roles.map((e) => e.toUpperCase()).contains("PROCESSOR");

  String _money(double? v) => '\$${(v ?? 0).toStringAsFixed(2)}';

  Color _statusColor(String codeOrDesc) {
    final s = codeOrDesc.toUpperCase();
    switch (s) {
      case 'APPROVED':
      case 'PROCESSED':
        return Colors.green;
      case 'DECLINED':
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
      case 'FOR_PROCESSING':
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

  String _receiptUrl(String filename) =>
      '${AppConfig.baseUrl}/uploads/$filename';

  Future<void> _openReceipt(String filename) async {
    if (!mounted) return;
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
      final history = await _svc.fetchApprovalHistory(userId);

      // Optional: sort newest first if your API doesn't
      history.sort((a, b) => b.id.compareTo(a.id));

      setState(() {
        _userId = userId;
        _roles = roles;
        _items = history;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final title = _isProcessor ? "Request History" : "Approval History";

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
                "No approval history found.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ] else ...[
            ..._items.map(
              (r) => _HistoryCard(
                item: r,
                money: _money,
                statusColor: _statusColor,
                onViewReceipt:
                    (r.imageFilename == null || r.imageFilename!.trim().isEmpty)
                    ? null
                    : () => _openReceipt(r.imageFilename!),
                onError: _toast,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.money,
    required this.statusColor,
    required this.onError,
    this.onViewReceipt,
  });

  final PendingApprovalDto item;
  final String Function(double?) money;
  final Color Function(String) statusColor;
  final VoidCallback? onViewReceipt;
  final void Function(String) onError;

  @override
  Widget build(BuildContext context) {
    final hasReceipt =
        item.imageFilename != null && item.imageFilename!.trim().isNotEmpty;

    // React uses status.description; your API gives status.code + description.
    final statusText = (item.status?.description ?? item.status?.code ?? "N/A")
        .toUpperCase();
    final chipColor = statusColor(statusText);

    final remarks = (item.remarks?.trim().isNotEmpty == true)
        ? item.remarks!.trim()
        : "No remarks";

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
            // Header: applicant + status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.applicantName?.trim().isNotEmpty == true
                        ? item.applicantName!.trim()
                        : "Applicant",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _chip(statusText, chipColor),
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
                _mini("Remarks", remarks),

                // optional fields (handy)
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

/// Simple full-screen receipt viewer by URL.
/// If you already have a shared receipt viewer widget, feel free to replace this.
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
