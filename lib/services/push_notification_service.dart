import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initAndRegister({
    required String baseUrl,
    required String jwt,
    required int userId,
    required int companyId,
  }) async {
    // iOS needs permission; Android is fine too.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token == null) return;

    await _registerToken(
      baseUrl: baseUrl,
      jwt: jwt,
      userId: userId,
      companyId: companyId,
      token: token,
    );

    // Token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _registerToken(
        baseUrl: baseUrl,
        jwt: jwt,
        userId: userId,
        companyId: companyId,
        token: newToken,
      );
    });
  }

  Future<void> _registerToken({
    required String baseUrl,
    required String jwt,
    required int userId,
    required int companyId,
    required String token,
  }) async {
    final platform = Platform.isAndroid ? "ANDROID" : "IOS";

    final res = await http.post(
      Uri.parse("$baseUrl/api/push/register-token"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $jwt",
      },
      body: jsonEncode({
        "userId": userId,
        "companyId": companyId,
        "token": token,
        "platform": platform,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Push token registration failed: ${res.statusCode} ${res.body}",
      );
    }
  }
}
