import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/http/dio_client.dart';
import 'models/approval_models.dart';

class ApprovalService {
  final Dio _dio = DioClient.dio;

  Future<Map<String, dynamic>> _getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user");
    if (raw == null || raw.isEmpty) {
      throw Exception("No logged-in user found. Please login.");
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<int> getUserId() async {
    final user = await _getCachedUser();
    return (user["id"] as num).toInt();
  }

  Future<List<String>> getUserRoleNames() async {
    final user = await _getCachedUser();
    final roles = user["roles"];

    if (roles is List) {
      return roles
          .whereType<Map>()
          .map((r) => (r["name"] ?? "").toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  /// React: GET `/approval/pending/${user.id}`
  /// Your backend might be `/api/approval/pending/{userId}`
  Future<List<PendingApprovalDto>> fetchPendingApprovals(int userId) async {
    final resp = await _dio.get("/api/approval/pending/$userId");
    final data = resp.data;

    final List list = (data is List) ? data : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PendingApprovalDto.fromJson)
        .toList();
  }

  /// React: POST `/approval/approve` body { approvalId, userId, remarks }
  Future<void> approve({
    required int approvalId,
    required int userId,
    String remarks = "Approved by user",
  }) async {
    await _dio.post(
      "/api/approval/approve",
      data: {"approvalId": approvalId, "userId": userId, "remarks": remarks},
    );
  }

  /// React: POST `/approval/decline` body { approvalId, userId, remarks }
  Future<void> decline({
    required int approvalId,
    required int userId,
    required String remarks,
  }) async {
    await _dio.post(
      "/api/approval/decline",
      data: {"approvalId": approvalId, "userId": userId, "remarks": remarks},
    );
  }

  Future<List<PendingApprovalDto>> fetchApprovalHistory(int userId) async {
    final resp = await _dio.get("/api/approval/history/$userId");
    final data = resp.data;

    final List list = (data is List) ? data : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PendingApprovalDto.fromJson)
        .toList();
  }
}
