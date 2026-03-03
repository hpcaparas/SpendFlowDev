import 'package:dio/dio.dart';
import '../../../core/http/dio_client.dart';

class TotpService {
  final Dio _dio = DioClient.dio;

  Future<Map<String, dynamic>> enrollBegin(String preAuthToken) async {
    final resp = await _dio.post(
      "/api/auth/mfa/totp/enroll/begin",
      data: {},
      options: Options(headers: {"Authorization": "Bearer $preAuthToken"}),
    );
    return (resp.data ?? {}) as Map<String, dynamic>;
  }

  Future<void> enrollFinish(String preAuthToken, String code) async {
    await _dio.post(
      "/api/auth/mfa/totp/enroll/finish",
      data: {"code": code},
      options: Options(headers: {"Authorization": "Bearer $preAuthToken"}),
    );
  }

  Future<Map<String, dynamic>> verify(String preAuthToken, String code) async {
    final resp = await _dio.post(
      "/api/auth/mfa/totp/verify",
      data: {"code": code},
      options: Options(headers: {"Authorization": "Bearer $preAuthToken"}),
    );
    return (resp.data ?? {}) as Map<String, dynamic>;
  }
}
