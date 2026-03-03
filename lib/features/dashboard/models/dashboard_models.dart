class UserDashboardResponse {
  final String from;
  final String to;
  final Kpis kpis;
  final List<TrendPoint> trend;
  final List<BreakdownItem> byType;
  final List<BreakdownItem> byPurchaseMethod;
  final List<RecentExpense> recent;

  UserDashboardResponse({
    required this.from,
    required this.to,
    required this.kpis,
    required this.trend,
    required this.byType,
    required this.byPurchaseMethod,
    required this.recent,
  });

  factory UserDashboardResponse.fromJson(Map<String, dynamic> json) {
    return UserDashboardResponse(
      from: (json["from"] ?? "").toString(),
      to: (json["to"] ?? "").toString(),
      kpis: Kpis.fromJson(json["kpis"] ?? {}),
      trend: ((json["trend"] ?? []) as List)
          .map((e) => TrendPoint.fromJson(e))
          .toList(),
      byType: ((json["byType"] ?? []) as List)
          .map((e) => BreakdownItem.fromJson(e))
          .toList(),
      byPurchaseMethod: ((json["byPurchaseMethod"] ?? []) as List)
          .map((e) => BreakdownItem.fromJson(e))
          .toList(),
      recent: ((json["recent"] ?? []) as List)
          .map((e) => RecentExpense.fromJson(e))
          .toList(),
    );
  }
}

class Kpis {
  final double totalSpend;
  final int submittedCount;
  final int pendingCount;
  final int approvedCount;
  final int declinedCount;
  final int returnedCount;
  final int cancelledCount;
  final int forProcessingCount;
  final int processedCount;

  Kpis({
    required this.totalSpend,
    required this.submittedCount,
    required this.pendingCount,
    required this.approvedCount,
    required this.declinedCount,
    required this.returnedCount,
    required this.cancelledCount,
    required this.forProcessingCount,
    required this.processedCount,
  });

  factory Kpis.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse("$v") ?? 0;
    int i(dynamic v) => (v is num) ? v.toInt() : int.tryParse("$v") ?? 0;

    return Kpis(
      totalSpend: d(json["totalSpend"]),
      submittedCount: i(json["submittedCount"]),
      pendingCount: i(json["pendingCount"]),
      approvedCount: i(json["approvedCount"]),
      declinedCount: i(json["declinedCount"]),
      returnedCount: i(json["returnedCount"]),
      cancelledCount: i(json["cancelledCount"]),
      forProcessingCount: i(json["forProcessingCount"]),
      processedCount: i(json["processedCount"]),
    );
  }
}

class TrendPoint {
  final String bucket; // YYYY-MM-DD or YYYY-MM
  final double total;

  TrendPoint({required this.bucket, required this.total});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    final total = (json["total"] is num)
        ? (json["total"] as num).toDouble()
        : double.tryParse("${json["total"]}") ?? 0.0;
    return TrendPoint(bucket: (json["bucket"] ?? "").toString(), total: total);
  }
}

class BreakdownItem {
  final int id;
  final String name;
  final double total;

  BreakdownItem({required this.id, required this.name, required this.total});

  factory BreakdownItem.fromJson(Map<String, dynamic> json) {
    final id = (json["id"] as num?)?.toInt() ?? 0;
    final total = (json["total"] is num)
        ? (json["total"] as num).toDouble()
        : double.tryParse("${json["total"]}") ?? 0.0;
    return BreakdownItem(
      id: id,
      name: (json["name"] ?? "").toString(),
      total: total,
    );
  }
}

class RecentExpense {
  final int id;
  final DateTime? createdAt;
  final String? departmentName;
  final String? typeName;
  final String? purchaseMethodName;
  final double priceWithTax;
  final double tax;
  final String? remarks;
  final String? statusCode;
  final String? statusLabel;
  final String? currentApproverName;

  RecentExpense({
    required this.id,
    required this.createdAt,
    required this.departmentName,
    required this.typeName,
    required this.purchaseMethodName,
    required this.priceWithTax,
    required this.tax,
    required this.remarks,
    required this.statusCode,
    required this.statusLabel,
    required this.currentApproverName,
  });

  factory RecentExpense.fromJson(Map<String, dynamic> json) {
    DateTime? dt(String? s) =>
        (s == null || s.isEmpty) ? null : DateTime.tryParse(s);
    double d(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse("$v") ?? 0;

    return RecentExpense(
      id: (json["id"] as num?)?.toInt() ?? 0,
      createdAt: dt(json["createdAt"]?.toString()),
      departmentName: json["departmentName"]?.toString(),
      typeName: json["typeName"]?.toString(),
      purchaseMethodName: json["purchaseMethodName"]?.toString(),
      priceWithTax: d(json["priceWithTax"]),
      tax: d(json["tax"]),
      remarks: json["remarks"]?.toString(),
      statusCode: json["statusCode"]?.toString(),
      statusLabel: json["statusLabel"]?.toString(),
      currentApproverName: json["currentApproverName"]?.toString(),
    );
  }
}
