import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_storage.dart';
import 'auth_service.dart';
import 'models/auth_models.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
      (ref) => AuthController(ref),
    );

class AuthController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  AuthController(this.ref) : super(const AsyncData(null));

  Future<LoginResult> login({
    required String companyName,
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(authServiceProvider)
          .login(
            LoginRequest(
              companyName: companyName,
              username: username,
              password: password,
            ),
          );

      if (result is LoginResultSuccess) {
        final s = result.success;

        await SecureStorage.saveTokens(
          accessToken: s.accessToken,
          refreshToken: s.refreshToken,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt("userId", s.user.id);
        await prefs.setString(
          "user",
          jsonEncode({
            "id": s.user.id,
            "name": s.user.name,
            "email": s.user.email,
            "roles": s.user.roles
                .map(
                  (r) => {
                    "id": r.id,
                    "name": r.name,
                    "description": r.description,
                  },
                )
                .toList(),
            "company": {
              "id": s.user.company.id,
              "name": s.user.company.name,
              "domain": s.user.company.domain,
              "config": s.user.company.config,
            },
            "profilePicture": s.user.profilePicture,
          }),
        );
      }

      state = const AsyncData(null);
      return result;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}
