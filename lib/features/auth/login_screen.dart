import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../app_router.dart';
import 'auth_controller.dart';
import 'models/auth_models.dart';
import '../auth/push_bootstrap.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _companyCtrl = TextEditingController(text: "localhost");
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _error = null);

    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .login(
            companyName: _companyCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

      if (!mounted) return;

      if (result is LoginResultMfaRequired) {
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.mfa, arguments: result.challenge);
        return;
      }

      if (result is LoginResultSuccess) {
        await PushBootstrap.registerAfterLogin();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.shell);
        return;
      }

      setState(() => _error = "Unexpected login result. Please try again.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 380;

    if (loading) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.78),
        body: Center(
          child: Lottie.asset(
            "assets/lottie-loading-money.json",
            width: 280,
            height: 280,
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/ExpenseManagement_BGOnly2.png",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.72),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 20 : 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final logoWidth = constraints.maxWidth > 430
                              ? 430.0
                              : constraints.maxWidth;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 26),
                            child: SizedBox(
                              width: logoWidth,
                              child: Image.asset(
                                "assets/spendflow_title_and_logo_login3.png",
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmall ? 18 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome back",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Sign in to continue to SpendFlow.",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.82),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_error != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFECACA),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _PremiumTextField(
                              controller: _usernameCtrl,
                              hintText: "Username",
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            _PremiumTextField(
                              controller: _passwordCtrl,
                              hintText: "Password",
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            _PremiumTextField(
                              controller: _companyCtrl,
                              hintText: "Company Name (e.g. localhost)",
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF34D399),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF3B82F6,
                                      ).withOpacity(0.32),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputAction? textInputAction;

  const _PremiumTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
        ),
      ),
    );
  }
}
