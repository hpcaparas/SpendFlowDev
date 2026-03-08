import 'package:dio/dio.dart';
import '../../core/http/dio_client.dart';
import 'models/auth_models.dart';

class AuthService {
  final Dio _dio = DioClient.dio;

  Future<LoginResult> login(LoginRequest request) async {
    try {
      final resp = await _dio.post("/api/auth/login", data: request.toJson());
      final data = (resp.data ?? {}) as Map<String, dynamic>;

      final status = data["status"]?.toString();

      if (status == "MFA_REQUIRED" || status == "MFA_ENROLL_REQUIRED") {
        final methods = ((data["methods"] ?? []) as List)
            .map((e) => e.toString())
            .toList();
        final preAuthToken = (data["preAuthToken"] ?? "").toString();

        // ✅ Use these to drive UI
        final hasTotp = (data["hasTotp"] == true);
        final hasPasskey = (data["hasPasskey"] == true);
        final hasEmail = (data["hasEmail"] == true);

        return LoginResultMfaRequired(
          MfaChallenge(
            methods: methods,
            preAuthToken: preAuthToken,
            mode: (status == "MFA_ENROLL_REQUIRED") ? "enroll" : "verify",
            hasTotp: hasTotp,
            hasPasskey: hasPasskey,
            hasEmail: hasEmail,
          ),
        );
      }

      final user = UserProfile.fromJson(data);
      final accessToken = (data["accessToken"] ?? "").toString();
      final refreshToken = (data["refreshToken"] ?? "").toString();

      return LoginResultSuccess(
        LoginSuccess(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        ),
      );
    } on DioException catch (e) {
      final msg = (e.response?.data is Map<String, dynamic>)
          ? (e.response?.data["message"]?.toString())
          : null;

      throw Exception(
        msg ?? "An unexpected error occurred. Please try again later.",
      );
    }
  }
}
