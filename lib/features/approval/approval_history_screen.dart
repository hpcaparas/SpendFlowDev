import 'package:flutter/material.dart';

import '../../shared/receipt/receipt_viewer.dart';
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
        return const Color(0xFF16A34A);
      case 'DECLINED':
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'PENDING':
      case 'FOR_PROCESSING':
        return const Color(0xFFF59E0B);
      case 'RETURNED':
      case 'RETURNED_BY_FINANCE':
        return const Color(0xFF9333EA);
      case 'CANCELLED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF475569);
    }
  }

  Future<void> _openReceipt(String filename) async {
    if (!mounted) return;
    await ReceiptViewer.openReceipt(context, imageFilename: filename);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
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
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFF3F7FB)],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            _HeaderCard(
              title: title,
              totalItems: _items.length,
              isProcessor: _isProcessor,
            ),
            const SizedBox(height: 14),
            if (_items.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 52,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No approval history found.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Completed requests will appear here once actions are taken.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ..._items.map(
                (r) => _HistoryCard(
                  item: r,
                  money: _money,
                  statusColor: _statusColor,
                  onViewReceipt:
                      (r.imageFilename == null ||
                          r.imageFilename!.trim().isEmpty)
                      ? null
                      : () => _openReceipt(r.imageFilename!),
                  onError: _toast,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.totalItems,
    required this.isProcessor,
  });

  final String title;
  final int totalItems;
  final bool isProcessor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isProcessor ? "Processing History" : "Approval History",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isProcessor
                ? "Review requests that you have already processed."
                : "Review requests that you have already approved or declined.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "History Items",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalItems",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
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

    final statusText = (item.status?.description ?? item.status?.code ?? "N/A")
        .toUpperCase();
    final chipColor = statusColor(statusText);

    final remarks = (item.remarks?.trim().isNotEmpty == true)
        ? item.remarks!.trim()
        : "No remarks";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      color: Color(0xFF0F172A),
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
                if (item.approver?.trim().isNotEmpty == true)
                  _mini("Approver", item.approver!.trim()),
                if (item.sequenceOrder > 0)
                  _mini("Step", item.sequenceOrder.toString()),
                if (item.visaApplicationId > 0)
                  _mini("App ID", item.visaApplicationId.toString()),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasReceipt ? onViewReceipt : null,
                icon: const Icon(Icons.receipt_long),
                label: Text(hasReceipt ? "View Receipt" : "No Image"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            v,
            style: const TextStyle(
              color: Color(0xFF334155),
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
