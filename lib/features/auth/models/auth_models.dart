class LoginRequest {
  final String companyName;
  final String username;
  final String password;

  LoginRequest({
    required this.companyName,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    "companyName": companyName,
    "username": username,
    "password": password,
  };
}

class MfaChallenge {
  final List<String> methods; // e.g. ["webauthn","totp","email"]
  final String preAuthToken;
  final String mode; // "verify" or "enroll"

  final bool hasPasskey;
  final bool hasTotp;

  // ✅ NEW
  final bool hasEmail;

  MfaChallenge({
    required this.methods,
    required this.preAuthToken,
    required this.mode,
    required this.hasPasskey,
    required this.hasTotp,
    required this.hasEmail,
  });

  bool get canPasskey => hasPasskey && methods.contains("webauthn");
  bool get canTotp => hasTotp && methods.contains("totp");
  bool get canEmail => hasEmail && methods.contains("email");
}

class Role {
  final int id;
  final String name;
  final String description;

  Role({required this.id, required this.name, required this.description});

  factory Role.fromJson(Map<String, dynamic> json) => Role(
    id: json["id"],
    name: (json["name"] ?? "").toString(),
    description: (json["description"] ?? "").toString(),
  );
}

class Company {
  final int id;
  final String name;
  final String domain;
  final String config;

  Company({
    required this.id,
    required this.name,
    required this.domain,
    required this.config,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json["id"],
    name: (json["name"] ?? "").toString(),
    domain: (json["domain"] ?? "").toString(),
    config: (json["config"] ?? "").toString(),
  );
}

class UserProfile {
  final int id;
  final String name;
  final String email;
  final List<Role> roles;
  final Company company;
  final String? profilePicture;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.company,
    required this.profilePicture,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json["id"],
    name: (json["name"] ?? "").toString(),
    email: (json["email"] ?? "").toString(),
    roles: ((json["roles"] ?? []) as List)
        .map((r) => Role.fromJson(r as Map<String, dynamic>))
        .toList(),
    company: Company.fromJson(json["company"] as Map<String, dynamic>),
    profilePicture: json["profilePicture"]?.toString(),
  );
}

class LoginSuccess {
  final String accessToken;
  final String refreshToken;
  final UserProfile user;

  LoginSuccess({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

/// Result union
abstract class LoginResult {}

class LoginResultSuccess extends LoginResult {
  final LoginSuccess success;
  LoginResultSuccess(this.success);
}

class LoginResultMfaRequired extends LoginResult {
  final MfaChallenge challenge;
  LoginResultMfaRequired(this.challenge);
}

LoginSuccess parseLoginSuccess(Map<String, dynamic> json) {
  return LoginSuccess(
    accessToken: (json["accessToken"] ?? "").toString(),
    refreshToken: (json["refreshToken"] ?? "").toString(),
    user: UserProfile.fromJson(json["user"] as Map<String, dynamic>),
  );
}
