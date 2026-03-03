import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/http/dio_client.dart';
import 'models/dashboard_models.dart';

class UserDashboardService {
  final Dio _dio = DioClient.dio;

  Future<Map<String, dynamic>> _getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user");
    if (raw == null) throw Exception("No logged-in user found. Please login.");
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<UserDashboardResponse> fetchDashboard({
    String? from,
    String? to,
    String groupBy = "DAY",
    int recentLimit = 10,
  }) async {
    final user = await _getCachedUser();
    final userId = (user["id"] as num).toInt();

    final resp = await _dio.get(
      "/api/visa/dashboard/user/$userId",
      queryParameters: {
        if (from != null) "from": from,
        if (to != null) "to": to,
        "groupBy": groupBy,
        "recentLimit": recentLimit,
      },
    );

    return UserDashboardResponse.fromJson(resp.data as Map<String, dynamic>);
  }
}
