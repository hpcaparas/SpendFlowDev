import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: {"Content-Type": "application/json"},
          ),
        )
        ..interceptors.add(
          LogInterceptor(
            request: true,
            requestHeader: true,
            requestBody: true,
            responseHeader: true,
            responseBody: true,
            error: true,
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final path = options.path;
              final isMfaEndpoint = path.startsWith("/api/auth/mfa/");

              final hasAuthHeader = options.headers.keys.any(
                (k) => k.toString().toLowerCase() == "authorization",
              );

              if (!hasAuthHeader && !isMfaEndpoint) {
                final accessToken = await SecureStorage.getAccessToken();
                if (accessToken != null && accessToken.isNotEmpty) {
                  options.headers["Authorization"] = "Bearer $accessToken";
                }
              }

              debugPrint("➡️ ${options.method} ${options.uri}");
              debugPrint("➡️ headers=${options.headers}");

              handler.next(options);
            },
            onResponse: (resp, handler) {
              debugPrint("✅ ${resp.statusCode} ${resp.requestOptions.uri}");
              handler.next(resp);
            },
            onError: (e, handler) {
              debugPrint("❌ ${e.response?.statusCode} ${e.requestOptions.uri}");
              debugPrint("❌ data=${e.response?.data}");
              handler.next(e);
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              debugPrint("➡️ ${options.method} ${options.uri}");
              debugPrint("headers=${options.headers}");
              handler.next(options);
            },
            onResponse: (resp, handler) {
              debugPrint("✅ ${resp.statusCode} ${resp.requestOptions.uri}");
              handler.next(resp);
            },
            onError: (e, handler) {
              debugPrint("❌ ${e.response?.statusCode} ${e.requestOptions.uri}");
              debugPrint("❌ data=${e.response?.data}");
              handler.next(e);
            },
          ),
        );
}
