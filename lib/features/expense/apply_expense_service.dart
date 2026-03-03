import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/http/dio_client.dart';
import 'models/expense_models.dart';

class ApplyExpenseService {
  final Dio _dio = DioClient.dio;

  Future<Map<String, dynamic>> _getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user");
    if (raw == null) throw Exception("No logged-in user found. Please login.");
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<Department>> fetchDepartments() async {
    final user = await _getCachedUser();
    final companyName = (user["company"]?["name"] ?? "").toString();
    final resp = await _dio.get(
      "/api/departments/company",
      queryParameters: {"companyName": companyName},
    );
    final list = (resp.data ?? []) as List;
    return list.map((e) => Department.fromJson(e)).toList();
  }

  Future<List<ExpenseType>> fetchTypes() async {
    final resp = await _dio.get("/api/types");
    final list = (resp.data ?? []) as List;
    return list.map((e) => ExpenseType.fromJson(e)).toList();
  }

  Future<List<PurchaseMethod>> fetchPurchaseMethods() async {
    final user = await _getCachedUser();
    final companyName = (user["company"]?["name"] ?? "").toString();
    final resp = await _dio.get(
      "/api/purchase-methods",
      queryParameters: {"companyName": companyName},
    );
    final list = (resp.data ?? []) as List;
    return list.map((e) => PurchaseMethod.fromJson(e)).toList();
  }

  Future<List<WorkflowStep>> fetchWorkflowSteps(int departmentId) async {
    final resp = await _dio.get(
      "/api/departments/$departmentId/workflow",
      queryParameters: {"approvalType": "EXPENSE_APPROVAL"},
    );
    final list = (resp.data ?? []) as List;
    return list.map((e) => WorkflowStep.fromJson(e)).toList();
  }

  Future<void> submitExpense({
    required int userId,
    required int departmentId,
    required int typeId,
    required int purchaseMethodId,
    required String priceWithTax,
    required String tax,
    required String remarks,
    required File receiptFile,
    required List<Map<String, dynamic>> approvalSteps,
  }) async {
    final form = FormData.fromMap({
      "userId": userId.toString(),
      "departmentId": departmentId.toString(),
      "typeId": typeId.toString(),
      "purchaseMethodId": purchaseMethodId.toString(),
      "priceWithTax": priceWithTax,
      "tax": tax,
      "remarks": remarks,
      "approvalSteps": jsonEncode(approvalSteps),
      "image": await MultipartFile.fromFile(
        receiptFile.path,
        filename: receiptFile.uri.pathSegments.last,
      ),
    });

    await _dio.post(
      "/api/visa",
      data: form,
      // Let Dio set Content-Type + boundary automatically
    );
  }
}
