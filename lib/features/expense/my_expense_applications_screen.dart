import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../shared/receipt/receipt_viewer.dart';

final Dio _dio = Dio(
  BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ),
);

class MyExpenseApplicationsScreen extends StatefulWidget {
  const MyExpenseApplicationsScreen({super.key});

  @override
  State<MyExpenseApplicationsScreen> createState() =>
      _MyExpenseApplicationsScreenState();
}

class _MyExpenseApplicationsScreenState
    extends State<MyExpenseApplicationsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;
  List<List<VisaApplicationDto>> _groups = [];
  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await _readUserIdFromLocalStorageOrToken();
      if (userId == null) {
        setState(() {
          _error = 'No logged-in user found.';
          _loading = false;
        });
        return;
      }

      final resp = await _dio.get('/api/visa/user/$userId');
      final raw = resp.data;

      final List<dynamic> list = raw is List ? raw : [];
      final apps = list
          .map((e) => VisaApplicationDto.fromJson(e as Map<String, dynamic>))
          .toList();

      final byId = {for (final a in apps) a.id: a};

      int resolveRootId(VisaApplicationDto a) {
        final visited = <int>{};
        int current = a.id;
        int? parent = a.parentApplicationId;

        while (parent != null && !visited.contains(parent)) {
          visited.add(parent);
          current = parent;
          final parentObj = byId[parent];
          parent = parentObj?.parentApplicationId;
        }
        return current;
      }

      final Map<int, List<VisaApplicationDto>> grouped = {};
      for (final app in apps) {
        final rootId = resolveRootId(app);
        grouped.putIfAbsent(rootId, () => []);
        grouped[rootId]!.add(app);
      }

      final groups = grouped.values.toList()
        ..forEach((g) => g.sort((a, b) => b.createdAt.compareTo(a.createdAt)));

      groups.sort((a, b) => b.first.createdAt.compareTo(a.first.createdAt));

      final expanded = <int>{};
      for (final g in groups) {
        if (g.length > 1) {
          expanded.add(g.first.id);
        }
      }

      setState(() {
        _groups = groups;
        _expanded
          ..clear()
          ..addAll(expanded);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _prettyDioError(e);
        _loading = false;
      });
    }
  }

  Future<void> _cancelApplication(VisaApplicationDto app) async {
    final userId = await _readUserIdFromLocalStorageOrToken();
    if (userId == null) {
      _toast('No logged-in user found.');
      return;
    }

    final ok = await _confirm(
      title: 'Cancel application?',
      message: 'Are you sure you want to cancel #${app.id}?',
      confirmText: 'Cancel Application',
    );
    if (!ok) return;

    try {
      await _dio.post(
        '/api/approval/cancel/${app.id}',
        queryParameters: {'userId': userId},
      );

      _toast('Application cancelled.');
      await _fetch();
    } catch (e) {
      _toast(_prettyDioError(e));
    }
  }

  void _toggleExpanded(int groupKey) {
    setState(() {
      if (_expanded.contains(groupKey)) {
        _expanded.remove(groupKey);
      } else {
        _expanded.add(groupKey);
      }
    });
  }

  Color _statusColor(String code) {
    switch (code.toUpperCase()) {
      case 'APPROVED':
      case 'PROCESSED':
        return const Color(0xFF16A34A);
      case 'DECLINED':
        return const Color(0xFFDC2626);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'FOR_PROCESSING':
        return const Color(0xFF7C3AED);
      case 'RETURNED':
      case 'RETURNED_BY_FINANCE':
        return const Color(0xFF9333EA);
      case 'CANCELLED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF475569);
    }
  }

  bool _canCancel(String code) {
    final c = code.toUpperCase();
    return c == 'PENDING' || c == 'FOR_PROCESSING';
  }

  String _money(double? v) {
    final val = v ?? 0.0;
    return '\$${val.toStringAsFixed(2)}';
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _currentApprover(List<VisaApprovalDto> approvals) {
    for (final a in approvals) {
      if ((a.status?.code ?? '').toUpperCase() == 'PENDING') {
        return a.approverName ?? a.approverRoleName ?? 'Pending (unassigned)';
      }
    }
    return 'N/A';
  }

  String _approvedBy(List<VisaApprovalDto> approvals) {
    final names = approvals
        .where((a) => (a.status?.code ?? '').toUpperCase() == 'APPROVED')
        .map((a) => a.approverName ?? a.approverRoleName)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) return 'N/A';
    return names.join(', ');
  }

  String _allApprovers(List<VisaApprovalDto> approvals) {
    final names = approvals
        .map((a) => a.approverName ?? a.approverRoleName)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) return 'N/A';
    return names.join(', ');
  }

  String _declineRemarks(List<VisaApprovalDto> approvals) {
    final declined = approvals.firstWhere(
      (a) => (a.status?.code ?? '').toUpperCase() == 'DECLINED',
      orElse: () => const VisaApprovalDto.empty(),
    );
    if (declined.id == null) return 'N/A';
    final who = declined.approverName ?? declined.approverRoleName ?? 'Unknown';
    final msg = declined.remarks?.trim().isNotEmpty == true
        ? declined.remarks!.trim()
        : 'No remarks';
    return '$who - $msg';
  }

  Future<void> _openReceipt(String filename) async {
    if (!mounted) return;
    await ReceiptViewer.openReceipt(context, imageFilename: filename);
  }

  Future<void> _showMore(VisaApplicationDto app) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      builder: (_) {
        final approvals = app.approvals;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application #${app.id}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        'Status',
                        app.statusLabel ?? app.statusCode ?? 'N/A',
                        color: _statusColor(app.statusCode ?? ''),
                      ),
                      _pill('Amount', _money(app.priceWithTax)),
                      _pill('Dept', app.department?.name ?? 'N/A'),
                      _pill('Type', app.type?.name ?? 'N/A'),
                      _pill('Method', app.purchaseMethod?.description ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('Timeline'),
                  const SizedBox(height: 8),
                  _kv('Created', _fmtDate(app.createdAt)),
                  _kv('Current Approver', _currentApprover(approvals)),
                  _kv('Approved By', _approvedBy(approvals)),
                  _kv('All Approvers', _allApprovers(approvals)),
                  _kv('Decline Remarks', _declineRemarks(approvals)),
                  const SizedBox(height: 12),
                  _kv(
                    'Remarks',
                    (app.remarks?.trim().isNotEmpty == true)
                        ? app.remarks!.trim()
                        : 'N/A',
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('Approvals'),
                  const SizedBox(height: 10),
                  if (approvals.isEmpty)
                    const Text('No approval steps found.')
                  else
                    Column(
                      children: approvals
                          .map((a) => _approvalTile(a))
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: app.imageFilename == null
                              ? null
                              : () => _openReceipt(app.imageFilename!),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('View Receipt'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _canCancel(app.statusCode ?? '')
                              ? () async {
                                  Navigator.of(context).pop();
                                  await _cancelApplication(app);
                                }
                              : null,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel Application'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _approvalTile(VisaApprovalDto a) {
    final code = (a.status?.code ?? 'N/A').toUpperCase();
    final color = _statusColor(code);
    final who = a.approverName ?? a.approverRoleName ?? 'Unassigned';
    final role = a.approverRoleName;
    final processor = a.isProcessor == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(
            processor ? Icons.settings_suggest : Icons.how_to_reg,
            color: color,
          ),
        ),
        title: Text(who, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role != null && role.trim().isNotEmpty) Text('Role: $role'),
            if (a.remarks != null && a.remarks!.trim().isNotEmpty)
              Text('Remarks: ${a.remarks}'),
            if (processor) const Text('Processor step'),
          ],
        ),
        trailing: _chip(code, color),
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
          fontWeight: FontWeight.w700,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _pill(String label, String value, {Color? color}) {
    final c = color ?? const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
                  label: const Text('Retry'),
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

    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 110),
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
                    Icons.inbox_outlined,
                    size: 52,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "No applications found.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "You haven't submitted any expenses yet.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
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
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          itemCount: _groups.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              final totalApps = _groups.fold<int>(
                0,
                (sum, g) => sum + g.length,
              );
              return _HeaderCard(
                totalGroups: _groups.length,
                totalApplications: totalApps,
              );
            }

            final group = _groups[index - 1];
            final latest = group.first;
            final others = group.length > 1
                ? group.sublist(1)
                : <VisaApplicationDto>[];
            final groupKey = latest.id;
            final isExpanded = _expanded.contains(groupKey);

            return _GroupCard(
              latest: latest,
              others: others,
              expanded: isExpanded,
              onToggle: () => _toggleExpanded(groupKey),
              onViewReceipt: latest.imageFilename == null
                  ? null
                  : () => _openReceipt(latest.imageFilename!),
              onShowMore: () => _showMore(latest),
              onCancel: _canCancel(latest.statusCode ?? '')
                  ? () => _cancelApplication(latest)
                  : null,
              statusColor: _statusColor(latest.statusCode ?? ''),
              money: _money,
              fmtDate: _fmtDate,
            );
          },
        ),
      ),
    );
  }

  Future<int?> _readUserIdFromLocalStorageOrToken() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("userId");
    if (userId != null) return userId;

    final userJson = prefs.getString("user");
    if (userJson == null || userJson.isEmpty) return null;

    try {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      final rawId = map["id"];
      if (rawId == null) return null;
      return (rawId as num).toInt();
    } catch (_) {
      return null;
    }
  }

  String _prettyDioError(Object e) {
    if (e is DioException) {
      final msg = e.response?.data;
      if (msg is String && msg.trim().isNotEmpty) return msg;
      if (msg is Map && msg['message'] is String) {
        return msg['message'] as String;
      }
      return e.message ?? 'Request failed.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalGroups,
    required this.totalApplications,
  });

  final int totalGroups;
  final int totalApplications;

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
            child: const Text(
              "Expense Tracking",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "My Expense Applications",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Review submitted requests, check resubmissions, and manage pending applications.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderMetric(label: "Request Chains", value: "$totalGroups"),
              _HeaderMetric(label: "Applications", value: "$totalApplications"),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.latest,
    required this.others,
    required this.expanded,
    required this.onToggle,
    required this.onShowMore,
    required this.statusColor,
    required this.money,
    required this.fmtDate,
    this.onViewReceipt,
    this.onCancel,
  });

  final VisaApplicationDto latest;
  final List<VisaApplicationDto> others;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onShowMore;
  final VoidCallback? onViewReceipt;
  final VoidCallback? onCancel;
  final Color statusColor;
  final String Function(double?) money;
  final String Function(DateTime) fmtDate;

  @override
  Widget build(BuildContext context) {
    final hasChildren = others.isNotEmpty;
    final statusText = latest.statusLabel ?? latest.statusCode ?? 'N/A';
    final hasReceipt =
        latest.imageFilename != null && latest.imageFilename!.trim().isNotEmpty;

    return Container(
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
                    'Application #${latest.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                _statusChip(statusText.toUpperCase(), statusColor),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              runSpacing: 8,
              spacing: 10,
              children: [
                _mini('Department', latest.department?.name ?? 'N/A'),
                _mini('Type', latest.type?.name ?? 'N/A'),
                _mini('Method', latest.purchaseMethod?.description ?? 'N/A'),
                _mini('Amount', money(latest.priceWithTax)),
                _mini('Created', fmtDate(latest.createdAt)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: hasReceipt ? onViewReceipt : null,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Receipt'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onShowMore,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Show more'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (onCancel != null)
                  FilledButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
              ],
            ),
            if (hasChildren) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 8),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        expanded
                            ? 'Hide resubmissions (${others.length})'
                            : 'Show resubmissions (${others.length})',
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 6),
                Column(
                  children: others
                      .map(
                        (c) => _ChildRow(
                          child: c,
                          statusColor: _statusColorFor(c),
                          money: money,
                          fmtDate: fmtDate,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColorFor(VisaApplicationDto app) {
    final code = (app.statusCode ?? '').toUpperCase();
    switch (code) {
      case 'APPROVED':
      case 'PROCESSED':
        return const Color(0xFF16A34A);
      case 'DECLINED':
        return const Color(0xFFDC2626);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'FOR_PROCESSING':
        return const Color(0xFF7C3AED);
      case 'RETURNED':
      case 'RETURNED_BY_FINANCE':
        return const Color(0xFF9333EA);
      case 'CANCELLED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF475569);
    }
  }

  Widget _statusChip(String text, Color color) {
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
      constraints: const BoxConstraints(minWidth: 140),
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
          ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.child,
    required this.statusColor,
    required this.money,
    required this.fmtDate,
  });

  final VisaApplicationDto child;
  final Color statusColor;
  final String Function(double?) money;
  final String Function(DateTime) fmtDate;

  @override
  Widget build(BuildContext context) {
    final statusText = child.statusLabel ?? child.statusCode ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.subdirectory_arrow_right,
              color: Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${child.id} (resubmission)',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${fmtDate(child.createdAt)} • ${money(child.priceWithTax)}',
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withOpacity(0.25)),
              ),
              child: Text(
                statusText.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class VisaApplicationDto {
  const VisaApplicationDto({
    required this.id,
    required this.createdAt,
    this.statusCode,
    this.statusLabel,
    this.remarks,
    this.imageFilename,
    this.department,
    this.type,
    this.priceWithTax,
    this.parentApplicationId,
    this.purchaseMethod,
    this.approvals = const [],
  });

  final int id;
  final String? statusCode;
  final String? statusLabel;
  final String? remarks;
  final String? imageFilename;
  final DepartmentDto? department;
  final TypeDto? type;
  final double? priceWithTax;
  final int? parentApplicationId;
  final PurchaseMethodDto? purchaseMethod;
  final DateTime createdAt;
  final List<VisaApprovalDto> approvals;

  factory VisaApplicationDto.fromJson(Map<String, dynamic> json) {
    return VisaApplicationDto(
      id: (json['id'] as num).toInt(),
      statusCode: json['statusCode'] as String?,
      statusLabel: json['statusLabel'] as String?,
      remarks: json['remarks'] as String?,
      imageFilename: json['imageFilename'] as String?,
      department: json['department'] is Map<String, dynamic>
          ? DepartmentDto.fromJson(json['department'] as Map<String, dynamic>)
          : null,
      type: json['type'] is Map<String, dynamic>
          ? TypeDto.fromJson(json['type'] as Map<String, dynamic>)
          : null,
      priceWithTax: (json['priceWithTax'] as num?)?.toDouble(),
      parentApplicationId: (json['parentApplicationId'] as num?)?.toInt(),
      purchaseMethod: json['purchaseMethod'] is Map<String, dynamic>
          ? PurchaseMethodDto.fromJson(
              json['purchaseMethod'] as Map<String, dynamic>,
            )
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      approvals:
          (json['approvals'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(VisaApprovalDto.fromJson)
              .toList() ??
          const [],
    );
  }
}

@immutable
class DepartmentDto {
  const DepartmentDto({required this.id, required this.name});

  final int id;
  final String name;

  factory DepartmentDto.fromJson(Map<String, dynamic> json) {
    return DepartmentDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'N/A',
    );
  }
}

@immutable
class TypeDto {
  const TypeDto({required this.id, required this.name});

  final int id;
  final String name;

  factory TypeDto.fromJson(Map<String, dynamic> json) {
    return TypeDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'N/A',
    );
  }
}

@immutable
class PurchaseMethodDto {
  const PurchaseMethodDto({
    required this.id,
    required this.name,
    required this.description,
  });

  final int id;
  final String name;
  final String description;

  factory PurchaseMethodDto.fromJson(Map<String, dynamic> json) {
    return PurchaseMethodDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'N/A',
      description:
          (json['description'] as String?) ??
          (json['name'] as String?) ??
          'N/A',
    );
  }
}

@immutable
class VisaApprovalDto {
  const VisaApprovalDto({
    required this.id,
    this.status,
    this.remarks,
    this.approverName,
    this.approverRoleName,
    this.isProcessor,
  });

  const VisaApprovalDto.empty()
    : id = null,
      status = null,
      remarks = null,
      approverName = null,
      approverRoleName = null,
      isProcessor = null;

  final int? id;
  final ApprovalStatusDto? status;
  final String? remarks;
  final String? approverName;
  final String? approverRoleName;
  final bool? isProcessor;

  factory VisaApprovalDto.fromJson(Map<String, dynamic> json) {
    return VisaApprovalDto(
      id: (json['id'] as num?)?.toInt(),
      status: json['status'] is Map<String, dynamic>
          ? ApprovalStatusDto.fromJson(json['status'] as Map<String, dynamic>)
          : null,
      remarks: json['remarks'] as String?,
      approverName: json['approverName'] as String?,
      approverRoleName: json['approverRoleName'] as String?,
      isProcessor: json['isProcessor'] as bool?,
    );
  }
}

@immutable
class ApprovalStatusDto {
  const ApprovalStatusDto({required this.id, required this.code});

  final int id;
  final String code;

  factory ApprovalStatusDto.fromJson(Map<String, dynamic> json) {
    return ApprovalStatusDto(
      id: (json['id'] as num).toInt(),
      code: (json['code'] as String?) ?? 'N/A',
    );
  }
}
