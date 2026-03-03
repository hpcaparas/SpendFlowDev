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
  final _companyCtrl = TextEditingController(
    text: "localhost",
  ); // default for dev
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
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
        Navigator.of(context).pushNamed(
          AppRoutes.mfa,
          arguments: result.challenge, // ✅ MfaChallenge
        );
        return; // ✅ stop here
      }

      if (result is LoginResultSuccess) {
        // If your login() already saved tokens internally, this is enough:
        await PushBootstrap.registerAfterLogin();

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.shell);
        return;
      }

      // Safety fallback (should not happen)
      setState(() => _error = "Unexpected login result. Please try again.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    if (loading) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.75),
        body: Center(
          child: Lottie.asset(
            "assets/lottie-loading-money.json",
            width: 260,
            height: 260,
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              "assets/ExpenseManagement_BGOnly.png",
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay to improve readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55), // tweak 0.45 - 0.70
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // ✅ Responsive logo sizing
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // max width available (cap it so it doesn't get huge on tablets)
                        final maxW = constraints.maxWidth > 420
                            ? 420.0
                            : constraints.maxWidth;

                        return SizedBox(
                          width: maxW,
                          child: Image.asset(
                            "assets/spendflow_title_and_logo.png",
                            height: 240,
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),

                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              hintText: "Username",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: "Password",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _companyCtrl,
                            decoration: const InputDecoration(
                              hintText: "Company Name (e.g. localhost)",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              child: const Text("Login"),
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
        ],
      ),
    );
  }
}
