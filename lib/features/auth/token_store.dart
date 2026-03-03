import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/secure_storage.dart';

class TokenStore {
  static Future<void> saveFromAuthResponse(Map<String, dynamic> data) async {
    final accessToken = (data["accessToken"] ?? "").toString();
    final refreshToken = (data["refreshToken"] ?? "").toString();

    await SecureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final prefs = await SharedPreferences.getInstance();

    final userId = data["id"];
    if (userId != null) {
      await prefs.setInt("userId", (userId as num).toInt());
    }

    // ✅ store companyId for push registration
    final company = data["company"];
    if (company is Map && company["id"] != null) {
      await prefs.setInt("companyId", (company["id"] as num).toInt());
    }

    await prefs.setString(
      "user",
      jsonEncode({
        "id": data["id"],
        "name": data["name"],
        "email": data["email"],
        "roles": data["roles"],
        "company": data["company"],
        "profilePicture": data["profilePicture"],
      }),
    );
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("userId");
  }

  static Future<int?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getInt("companyId");
    if (id != null) return id;

    final raw = prefs.getString("user");
    if (raw == null) return null;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final company = m["company"];
      if (company is Map && company["id"] != null) {
        return (company["id"] as num).toInt();
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> getAccessToken() async {
    // ✅ assumes your SecureStorage has a getter
    return SecureStorage.getAccessToken();
  }
}
