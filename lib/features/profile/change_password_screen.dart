import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/http/dio_client.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final Dio _dio = DioClient.dio;

  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _confirmOldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _hideOld = true;
  bool _hideConfirmOld = true;
  bool _hideNew = true;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _confirmOldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    final directId = prefs.getInt("userId");
    if (directId != null) return directId;

    final rawUser = prefs.getString("user");
    if (rawUser == null || rawUser.isEmpty) return null;

    try {
      final map = jsonDecode(rawUser) as Map<String, dynamic>;
      final rawId = map["id"];
      if (rawId == null) return null;
      return (rawId as num).toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    if (_oldCtrl.text.trim() != _confirmOldCtrl.text.trim()) {
      setState(() {
        _error = "Old password and confirm old password do not match.";
      });
      return;
    }

    final userId = await _getUserId();
    if (userId == null) {
      setState(() {
        _error = "No logged-in user found. Please login again.";
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await _dio.post(
        "/api/users/$userId/change-password",
        data: {
          "oldPassword": _oldCtrl.text.trim(),
          "newPassword": _newCtrl.text.trim(),
        },
      );

      if (!mounted) return;

      final message = response.data is Map<String, dynamic>
          ? (response.data["message"]?.toString() ??
                "Password changed successfully!")
          : "Password changed successfully!";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(message),
        ),
      );

      Navigator.of(context).pop();
    } on DioException catch (e) {
      String message = "Failed to change password. Please try again.";
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data["message"] != null) {
        message = data["message"].toString();
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      if (mounted) {
        setState(() => _error = message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = "Failed to change password. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFF3F7FB),
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1D4ED8),
                        Color(0xFF2563EB),
                        Color(0xFF14B8A6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "Account Security",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Change Password",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Update your password to keep your account secure.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Password Details",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Use your current password to authorize the change.",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: _oldCtrl,
                          label: "Old Password",
                          hidden: _hideOld,
                          onToggle: () => setState(() => _hideOld = !_hideOld),
                        ),
                        const SizedBox(height: 12),
                        _PasswordField(
                          controller: _confirmOldCtrl,
                          label: "Confirm Old Password",
                          hidden: _hideConfirmOld,
                          onToggle: () => setState(() {
                            _hideConfirmOld = !_hideConfirmOld;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _PasswordField(
                          controller: _newCtrl,
                          label: "New Password",
                          hidden: _hideNew,
                          onToggle: () => setState(() => _hideNew = !_hideNew),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "New password is required.";
                            }
                            if (value.trim().length < 8) {
                              return "New password must be at least 8 characters.";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text("Cancel"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _loading ? null : _save,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(_loading ? "Saving..." : "Save"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.28),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hidden,
    required this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool hidden;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return "$label is required.";
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
