import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'user_dashboard_service.dart';
import 'models/dashboard_models.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final UserDashboardService _service = UserDashboardService();

  UserDashboardResponse? data;
  bool loading = true;
  String? error;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  String _groupBy = "DAY";
  final int _recentLimit = 10;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  String _yyyyMmDd(DateTime d) => DateFormat("yyyy-MM-dd").format(d);

  Future<void> fetch() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final result = await _service.fetchDashboard(
        from: _yyyyMmDd(_fromDate),
        to: _yyyyMmDd(_toDate),
        groupBy: _groupBy,
        recentLimit: _recentLimit,
      );

      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    final newFrom = DateTime(picked.year, picked.month, picked.day);
    DateTime newTo = _toDate;
    if (newFrom.isAfter(newTo)) {
      newTo = newFrom;
    }

    setState(() {
      _fromDate = newFrom;
      _toDate = newTo;
    });

    fetch();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    final newTo = DateTime(picked.year, picked.month, picked.day);

    DateTime newFrom = _fromDate;
    if (newTo.isBefore(newFrom)) {
      newFrom = newTo;
    }

    setState(() {
      _toDate = newTo;
      _fromDate = newFrom;
    });

    fetch();
  }

  void _setQuickRange(int days) {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(Duration(days: days - 1));

    setState(() {
      _fromDate = DateTime(from.year, from.month, from.day);
      _toDate = to;
      _groupBy = days <= 31 ? "DAY" : "MONTH";
    });

    fetch();
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month, now.day);
      _groupBy = "DAY";
    });
    fetch();
  }

  void _setYtd() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, 1, 1);
      _toDate = DateTime(now.year, now.month, now.day);
      _groupBy = "MONTH";
    });
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFF3F7FB),
                ],
              ),
            ),
          ),
          SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text("Error: $error", textAlign: TextAlign.center),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetch,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageHeader(),
                          const SizedBox(height: 18),
                          _buildCoverage(),
                          const SizedBox(height: 16),
                          _buildKpis(),
                          const SizedBox(height: 20),
                          _buildChart(),
                          const SizedBox(height: 20),
                          _buildBreakdown(),
                          const SizedBox(height: 20),
                          _buildRecent(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
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
              "Dashboard",
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
            "Expense overview",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Track spending, monitor status counts, and review recent expense activity.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverage() {
    return _card(
      title: "Date Coverage",
      subtitle:
          "Adjust the reporting period and grouping to refine the dashboard.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickChip("7D", () => _setQuickRange(7)),
              _quickChip("30D", () => _setQuickRange(30)),
              _quickChip("This Month", _setThisMonth),
              _quickChip("YTD", _setYtd),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _outlineAction(
                  icon: Icons.date_range,
                  label:
                      "From: ${DateFormat("MMM dd, yyyy").format(_fromDate)}",
                  onTap: _pickFromDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _outlineAction(
                  icon: Icons.event,
                  label: "To: ${DateFormat("MMM dd, yyyy").format(_toDate)}",
                  onTap: _pickToDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Text(
                  "Group by:",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _groupBy,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: "DAY", child: Text("Day")),
                    DropdownMenuItem(value: "WEEK", child: Text("Week")),
                    DropdownMenuItem(value: "MONTH", child: Text("Month")),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _groupBy = val);
                    fetch();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E3A8A),
      ),
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        backgroundColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  Widget _buildKpis() {
    final k = data!.kpis;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.28,
      children: [
        _kpiCard(
          "Total Spend",
          "\$${k.totalSpend.toStringAsFixed(2)}",
          const Color(0xFF2563EB),
          Icons.payments_outlined,
        ),
        _kpiCard(
          "Submitted",
          "${k.submittedCount}",
          const Color(0xFF0F172A),
          Icons.receipt_long_outlined,
        ),
        _kpiCard(
          "Pending",
          "${k.pendingCount}",
          const Color(0xFFF59E0B),
          Icons.schedule_outlined,
        ),
        _kpiCard(
          "Approved",
          "${k.approvedCount}",
          const Color(0xFF16A34A),
          Icons.check_circle_outline,
        ),
        _kpiCard(
          "Returned",
          "${k.returnedCount}",
          const Color(0xFFDC2626),
          Icons.reply_all_outlined,
        ),
        _kpiCard(
          "Processing",
          "${k.forProcessingCount}",
          const Color(0xFF7C3AED),
          Icons.settings_suggest_outlined,
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final trend = data!.trend;

    return _card(
      title: "Spending Trend",
      subtitle: "Visualize total expense movement across the selected period.",
      child: SizedBox(
        height: 240,
        child: trend.isEmpty
            ? const Center(
                child: Text(
                  "No trend data available.",
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              )
            : LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: null,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: _leftInterval(trend),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _bottomInterval(trend.length),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= trend.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _shortLabel(trend[index].bucket),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3.5,
                      color: const Color(0xFF2563EB),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF60A5FA).withOpacity(0.16),
                      ),
                      spots: List.generate(
                        trend.length,
                        (i) => FlSpot(i.toDouble(), trend[i].total),
                      ),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  double _leftInterval(List<TrendPoint> trend) {
    final max = trend.fold<double>(0, (p, e) => e.total > p ? e.total : p);
    if (max <= 100) return 20;
    if (max <= 500) return 100;
    if (max <= 2000) return 500;
    return (max / 4).ceilToDouble();
  }

  double _bottomInterval(int count) {
    if (count <= 6) return 1;
    if (count <= 12) return 2;
    return 3;
  }

  String _shortLabel(String bucket) {
    if (bucket.isEmpty) return "";
    try {
      if (bucket.length == 7) {
        final parsed = DateFormat("yyyy-MM").parse(bucket);
        return DateFormat("MMM").format(parsed);
      }
      if (bucket.length == 10) {
        final parsed = DateFormat("yyyy-MM-dd").parse(bucket);
        return DateFormat("MMM d").format(parsed);
      }
    } catch (_) {}
    return bucket.length <= 6 ? bucket : bucket.substring(0, 6);
  }

  Widget _buildBreakdown() {
    return Column(
      children: [
        _buildBreakdownCard("By Type", data!.byType, Icons.category_outlined),
        const SizedBox(height: 12),
        _buildBreakdownCard(
          "By Purchase Method",
          data!.byPurchaseMethod,
          Icons.credit_card_outlined,
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(
    String title,
    List<BreakdownItem> items,
    IconData icon,
  ) {
    return _card(
      title: title,
      subtitle: "See where spending is concentrated.",
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "No breakdown data available.",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : Column(
              children: items.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: const Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        "\$${e.total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecent() {
    return _card(
      title: "Recent Expenses",
      subtitle: "Latest submitted records within the selected date coverage.",
      child: data!.recent.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "No recent expenses found.",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : Column(
              children: data!.recent.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.typeName ?? "-",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${e.departmentName ?? ""} • ${_formatDate(e.createdAt)}",
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "\$${e.priceWithTax.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _statusChip(e.statusCode),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    String text = status ?? "";

    switch (status) {
      case "APPROVED":
        color = const Color(0xFF16A34A);
        break;
      case "DECLINED":
      case "RETURNED":
        color = const Color(0xFFDC2626);
        break;
      case "FOR_PROCESSING":
        color = const Color(0xFF7C3AED);
        break;
      case "PENDING":
        color = const Color(0xFF64748B);
        break;
      default:
        color = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
    return DateFormat("MMM dd").format(date);
  }
}
