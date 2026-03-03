import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_passkey_service/flutter_passkey_service.dart';
import '../../core/http/dio_client.dart';

class TotpEnrollBeginResponse {
  final String secretB32;
  final String otpauthUri;

  TotpEnrollBeginResponse({required this.secretB32, required this.otpauthUri});

  factory TotpEnrollBeginResponse.fromJson(Map<String, dynamic> json) {
    return TotpEnrollBeginResponse(
      secretB32: (json["secretB32"] ?? "").toString(),
      otpauthUri: (json["otpauthUri"] ?? "").toString(),
    );
  }
}

class MfaService {
  final Dio _dio = DioClient.dio;

  String _platformHeaderValue() {
    if (kIsWeb) return "web";
    return "android"; // when running iOS build, change to "ios" OR detect via Platform in dart:io
  }

  // -----------------------------
  // PASSKEY (keep this)
  // -----------------------------
  Future<void> enrollPasskey({required String preAuthToken}) async {
    final beginResp = await _dio.post(
      "/api/auth/mfa/webauthn/register/begin",
      data: {},
      options: Options(
        headers: {
          "Authorization": "Bearer $preAuthToken",
          "X-Client-Platform": _platformHeaderValue(),
        },
      ),
    );

    final opt = (beginResp.data ?? {}) as Map<String, dynamic>;

    final regOptions = FlutterPasskeyService.createRegistrationOptions(
      challenge: opt["challengeB64"].toString(),
      rpName: opt["rpName"].toString(),
      rpId: opt["rpId"].toString(),
      userId: opt["userIdB64"].toString(),
      username: opt["userName"].toString(),
      displayName: opt["displayName"].toString(),
      timeout: 60000,
    );

    final cred = await FlutterPasskeyService.register(regOptions);

    await _dio.post(
      "/api/auth/mfa/webauthn/register/finish",
      data: {
        "credentialIdB64": cred.rawId,
        "attestationObjectB64": cred.response.attestationObject,
        "clientDataJSONB64": cred.response.clientDataJSON,
      },
      options: Options(
        headers: {
          "Authorization": "Bearer $preAuthToken",
          "X-Client-Platform": _platformHeaderValue(),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> verifyPasskey({
    required String preAuthToken,
  }) async {
    final beginResp = await _dio.post(
      "/api/auth/mfa/webauthn/auth/begin",
      data: {},
      options: Options(
        headers: {
          "Authorization": "Bearer $preAuthToken",
          "X-Client-Platform": _platformHeaderValue(),
        },
      ),
    );

    final opt = (beginResp.data ?? {}) as Map<String, dynamic>;
    final allowIds = ((opt["allowCredentialIdsB64"] ?? []) as List)
        .map((e) => e.toString())
        .toList();

    final authOptions = FlutterPasskeyService.createAuthenticationOptions(
      challenge: opt["challengeB64"].toString(),
      rpId: opt["rpId"].toString(),
      allowedCredentialIds: allowIds,
      timeout: 60000,
    );

    final assertion = await FlutterPasskeyService.authenticate(authOptions);

    final finishResp = await _dio.post(
      "/api/auth/mfa/webauthn/auth/finish",
      data: {
        "credentialIdB64": assertion.rawId,
        "clientDataJSONB64": assertion.response.clientDataJSON,
        "authenticatorDataB64": assertion.response.authenticatorData,
        "signatureB64": assertion.response.signature,
        "userHandleB64": assertion.response.userHandle.isEmpty
            ? null
            : assertion.response.userHandle,
      },
      options: Options(
        headers: {
          "Authorization": "Bearer $preAuthToken",
          "X-Client-Platform": _platformHeaderValue(),
        },
      ),
    );

    return (finishResp.data ?? {}) as Map<String, dynamic>;
  }

  // -----------------------------
  // TOTP (new)
  // -----------------------------

  Future<TotpEnrollBeginResponse> totpEnrollBegin({
    required String preAuthToken,
  }) async {
    final resp = await _dio.post(
      "/api/auth/mfa/totp/enroll/begin",
      data: {},
      options: Options(headers: {"Authorization": "Bearer $preAuthToken"}),
    );

    return TotpEnrollBeginResponse.fromJson(
      (resp.data ?? {}) as Map<String, dynamic>,
    );
  }

  /// Confirms enrollment by validating the first code from the authenticator.
  Future<void> totpEnrollFinish({
    required String preAuthToken,
    required String code,
  }) async {
    await _dio.post(
      "/api/auth/mfa/totp/enroll/finish",
      data: {"code": code},
      options: Options(headers: {"Authorization": "Bearer $preAuthToken"}),
    );
  }

  /// Verifies code and returns final JWT response (access/refresh/user...).
  Future<Map<String, dynamic>> totpVerify({
    required String preAuthToken,
    required String code,
  }) async {
    final resp = await _dio.post(
      "/api/auth/mfa/totp/verify",
      data: {"code": code},
      options: Options(headers: {"Authorization": "Bearer $preAuthToken"}),
    );

    return (resp.data ?? {}) as Map<String, dynamic>;
  }

  // small helper if you want to copy secret
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
