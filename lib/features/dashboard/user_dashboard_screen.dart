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

  // ✅ New: filters
  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  ); // first day of month
  DateTime _toDate = DateTime.now(); // today
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

    // ensure from <= to
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

    // ensure from <= to
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
      _groupBy = days <= 31 ? "DAY" : "MONTH"; // sensible default
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Dashboard"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text("Error: $error"))
          : RefreshIndicator(
              onRefresh: fetch,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
    );
  }

  // ✅ New: Coverage card
  Widget _buildCoverage() {
    return _card(
      title: "Date Coverage",
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
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    "From: ${DateFormat("MMM dd, yyyy").format(_fromDate)}",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    "To: ${DateFormat("MMM dd, yyyy").format(_toDate)}",
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Group By dropdown (uses your existing API param)
          Row(
            children: [
              const Text("Group by: "),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _groupBy,
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
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }

  // ================= KPIs =================
  Widget _buildKpis() {
    final k = data!.kpis;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _kpiCard(
          "Total Spend",
          "\$${k.totalSpend.toStringAsFixed(2)}",
          Colors.blue,
        ),
        _kpiCard("Submitted", "${k.submittedCount}", Colors.black87),
        _kpiCard("Pending", "${k.pendingCount}", Colors.orange),
        _kpiCard("Approved", "${k.approvedCount}", Colors.green),
        _kpiCard("Returned", "${k.returnedCount}", Colors.red),
        _kpiCard("Processing", "${k.forProcessingCount}", Colors.purple),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= CHART =================
  Widget _buildChart() {
    final trend = data!.trend;

    return _card(
      title: "Spending Trend",
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(show: true),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                barWidth: 3,
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

  // ================= BREAKDOWN =================
  Widget _buildBreakdown() {
    return Column(
      children: [
        _buildBreakdownCard("By Type", data!.byType),
        const SizedBox(height: 12),
        _buildBreakdownCard("By Purchase Method", data!.byPurchaseMethod),
      ],
    );
  }

  Widget _buildBreakdownCard(String title, List<BreakdownItem> items) {
    return _card(
      title: title,
      child: Column(
        children: items.map((e) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.name),
            trailing: Text("\$${e.total.toStringAsFixed(2)}"),
          );
        }).toList(),
      ),
    );
  }

  // ================= RECENT =================
  Widget _buildRecent() {
    return _card(
      title: "Recent Expenses",
      child: Column(
        children: data!.recent.map((e) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.typeName ?? "-"),
            subtitle: Text(
              "${e.departmentName ?? ""} • ${_formatDate(e.createdAt)}",
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "\$${e.priceWithTax.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                _statusChip(e.statusCode),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;

    switch (status) {
      case "APPROVED":
        color = Colors.green;
        break;
      case "DECLINED":
      case "RETURNED":
        color = Colors.red;
        break;
      case "FOR_PROCESSING":
        color = Colors.purple;
        break;
      case "PENDING":
        color = Colors.grey;
        break;
      default:
        color = Colors.black54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status ?? "", style: TextStyle(color: color, fontSize: 12)),
    );
  }

  // ================= COMMON CARD =================
  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
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
