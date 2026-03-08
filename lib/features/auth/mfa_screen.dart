import 'package:flutter/material.dart';
import '../mfa/mfa_service.dart';
import 'models/auth_models.dart';
import 'token_store.dart';
import '../../app_router.dart';
import '../auth/push_bootstrap.dart';

enum MfaMethod { passkey, email, totp }

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key, required this.challenge});

  final MfaChallenge challenge;

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _svc = MfaService();

  bool _loading = false;
  bool sending = false;
  bool verifying = false;
  String? _error;

  MfaMethod? _selectedMethod;

  String code = "";
  String? maskedEmail;
  bool _emailCodeSent = false;
  final _emailCtrl = TextEditingController();

  TotpEnrollBeginResponse? _totpBegin;
  final _totpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _autoSelectIfSingleMethod();
  }

  void _autoSelectIfSingleMethod() {
    final methods = widget.challenge.methods;

    if (methods.length == 1) {
      final only = methods.first;
      if (only == "webauthn") {
        _selectedMethod = MfaMethod.passkey;
      } else if (only == "email") {
        _selectedMethod = MfaMethod.email;
      } else if (only == "totp") {
        _selectedMethod = MfaMethod.totp;
      }
    }
  }

  @override
  void dispose() {
    _totpCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _busy => _loading || sending || verifying;

  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  void _selectMethod(MfaMethod method) {
    setState(() {
      _selectedMethod = method;
      _error = null;
    });
  }

  void _backToMethodSelection() {
    setState(() {
      _selectedMethod = null;
      _error = null;
      sending = false;
      verifying = false;
      _loading = false;
    });
  }

  Future<void> _finishLoginFromAuthResponse(Map<String, dynamic> resp) async {
    await TokenStore.saveFromAuthResponse(resp);
    await PushBootstrap.registerAfterLogin();

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.shell, (route) => false);
  }

  Future<void> onChooseEmail(MfaChallenge ch) async {
    setState(() {
      sending = true;
      _error = null;
      _emailCodeSent = false;
      maskedEmail = null;
      _emailCtrl.clear();
      code = "";
    });

    try {
      final resp = await _svc.emailSendCode(preAuthToken: ch.preAuthToken);
      setState(() {
        maskedEmail = resp.emailMasked.isEmpty ? null : resp.emailMasked;
        _emailCodeSent = true;
        sending = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        sending = false;
      });
    }
  }

  Future<void> onVerifyEmail(MfaChallenge ch) async {
    final enteredCode = _emailCtrl.text.trim();
    if (enteredCode.length != 6) {
      setState(() => _error = "Enter the 6-digit code from your email.");
      return;
    }

    setState(() {
      verifying = true;
      _error = null;
      code = enteredCode;
    });

    try {
      final resp = await _svc.emailVerify(
        preAuthToken: ch.preAuthToken,
        code: enteredCode,
      );
      await _finishLoginFromAuthResponse(resp);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        verifying = false;
      });
    } finally {
      if (mounted) {
        setState(() => verifying = false);
      }
    }
  }

  Future<void> _verifyPasskey() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _svc.verifyPasskey(
        preAuthToken: widget.challenge.preAuthToken,
      );
      await _finishLoginFromAuthResponse(resp);
    } catch (e) {
      setState(() {
        _error =
            "No passkey found on this device for this account. Please enroll a passkey on this phone or use another verification method.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enrollPasskeyThenVerify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _svc.enrollPasskey(preAuthToken: widget.challenge.preAuthToken);
      final resp = await _svc.verifyPasskey(
        preAuthToken: widget.challenge.preAuthToken,
      );
      await _finishLoginFromAuthResponse(resp);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _totpBeginEnroll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final begin = await _svc.totpEnrollBegin(
        preAuthToken: widget.challenge.preAuthToken,
      );
      setState(() => _totpBegin = begin);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _totpFinishEnrollAndVerify() async {
    final enteredCode = _totpCtrl.text.trim();
    if (enteredCode.length != 6) {
      setState(
        () => _error = "Enter the 6-digit code from your authenticator app.",
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _svc.totpEnrollFinish(
        preAuthToken: widget.challenge.preAuthToken,
        code: enteredCode,
      );

      final resp = await _svc.totpVerify(
        preAuthToken: widget.challenge.preAuthToken,
        code: enteredCode,
      );

      await _finishLoginFromAuthResponse(resp);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _totpVerifyOnly() async {
    final enteredCode = _totpCtrl.text.trim();
    if (enteredCode.length != 6) {
      setState(
        () => _error = "Enter the 6-digit code from your authenticator app.",
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _svc.totpVerify(
        preAuthToken: widget.challenge.preAuthToken,
        code: enteredCode,
      );
      await _finishLoginFromAuthResponse(resp);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.challenge;
    final supportsPasskey = ch.methods.contains("webauthn");
    final supportsTotp = ch.methods.contains("totp");
    final supportsEmail = ch.methods.contains("email");
    final needsTotpEnroll = supportsTotp && (ch.hasTotp == false);

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
                    Colors.black.withOpacity(0.48),
                    Colors.black.withOpacity(0.62),
                    Colors.black.withOpacity(0.76),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  children: [
                    _PremiumTopBar(
                      showBack: _selectedMethod != null,
                      onBack: _busy ? null : _backToMethodSelection,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _selectedMethod == null
                            ? _buildMethodSelection(
                                supportsPasskey: supportsPasskey,
                                supportsEmail: supportsEmail,
                                supportsTotp: supportsTotp,
                                needsTotpEnroll: needsTotpEnroll,
                              )
                            : _buildMethodStep(
                                ch: ch,
                                needsTotpEnroll: needsTotpEnroll,
                              ),
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

  Widget _buildMethodSelection({
    required bool supportsPasskey,
    required bool supportsEmail,
    required bool supportsTotp,
    required bool needsTotpEnroll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Verify it’s you",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Choose one verification method to continue.",
          style: TextStyle(
            fontSize: 14.5,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          _PremiumErrorBanner(
            message: _error!,
            onClose: () => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
        ],
        if (_busy) ...[const _PremiumBusy(), const SizedBox(height: 14)],
        if (supportsPasskey) ...[
          _MethodChoiceCard(
            icon: Icons.fingerprint,
            title: "Passkey",
            subtitle: "Use biometrics or your device lock.",
            onTap: _busy ? null : () => _selectMethod(MfaMethod.passkey),
          ),
          const SizedBox(height: 12),
        ],
        if (supportsEmail) ...[
          _MethodChoiceCard(
            icon: Icons.email_outlined,
            title: "Email OTP",
            subtitle: "Receive a one-time code in your email.",
            onTap: _busy ? null : () => _selectMethod(MfaMethod.email),
          ),
          const SizedBox(height: 12),
        ],
        if (supportsTotp) ...[
          _MethodChoiceCard(
            icon: Icons.shield_outlined,
            title: "Authenticator app",
            subtitle: needsTotpEnroll
                ? "Set up your authenticator app first."
                : "Use the 6-digit code from your app.",
            onTap: _busy ? null : () => _selectMethod(MfaMethod.totp),
          ),
        ],
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false),
            child: Text(
              "Back to login",
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodStep({
    required MfaChallenge ch,
    required bool needsTotpEnroll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getStepTitle(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _getStepSubtitle(needsTotpEnroll),
          style: TextStyle(
            fontSize: 14.5,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          _PremiumErrorBanner(
            message: _error!,
            onClose: () => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
        ],
        if (_busy) ...[const _PremiumBusy(), const SizedBox(height: 14)],
        _buildSelectedMethodCard(ch, needsTotpEnroll),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _backToMethodSelection,
            child: Text(
              "Choose another method",
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
      ],
    );
  }

  String _getStepTitle() {
    switch (_selectedMethod) {
      case MfaMethod.passkey:
        return "Verify with passkey";
      case MfaMethod.email:
        return "Verify with email";
      case MfaMethod.totp:
        return "Verify with authenticator";
      default:
        return "Verify it’s you";
    }
  }

  String _getStepSubtitle(bool needsTotpEnroll) {
    switch (_selectedMethod) {
      case MfaMethod.passkey:
        return "Use your biometrics or device screen lock to continue.";
      case MfaMethod.email:
        return "We’ll send you a 6-digit code by email.";
      case MfaMethod.totp:
        return needsTotpEnroll
            ? "Set up your authenticator app, then enter the 6-digit code."
            : "Enter the 6-digit code from your authenticator app.";
      default:
        return "";
    }
  }

  Widget _buildSelectedMethodCard(MfaChallenge ch, bool needsTotpEnroll) {
    switch (_selectedMethod) {
      case MfaMethod.passkey:
        return _MfaCard(
          icon: Icons.fingerprint,
          title: "Passkey",
          subtitle: "Use biometrics or your device lock.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ch.mode == "enroll") ...[
                _PrimaryButton(
                  label: "Enroll & verify",
                  onPressed: _busy ? null : _enrollPasskeyThenVerify,
                ),
                const SizedBox(height: 10),
              ],
              _SecondaryButton(
                label: "Verify with passkey",
                onPressed: _busy ? null : _verifyPasskey,
              ),
            ],
          ),
        );

      case MfaMethod.email:
        return _MfaCard(
          icon: Icons.email_outlined,
          title: "Email OTP",
          subtitle: maskedEmail != null
              ? "Code will be sent to $maskedEmail"
              : "Get a one-time code by email.",
          trailing: _emailCodeSent ? const _MiniChip(label: "Code sent") : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PrimaryButton(
                label: sending
                    ? "Sending..."
                    : (_emailCodeSent ? "Resend code" : "Send code"),
                onPressed: _busy && !sending ? null : () => onChooseEmail(ch),
              ),
              if (_emailCodeSent) ...[
                const SizedBox(height: 14),
                _PremiumTextField(
                  controller: _emailCtrl,
                  hintText: "Enter the 6-digit code",
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => _clearError(),
                ),
                const SizedBox(height: 10),
                _PrimaryButton(
                  label: verifying ? "Verifying..." : "Verify & continue",
                  onPressed: verifying ? null : () => onVerifyEmail(ch),
                ),
              ],
            ],
          ),
        );

      case MfaMethod.totp:
        return _MfaCard(
          icon: Icons.shield_outlined,
          title: "Authenticator (TOTP)",
          subtitle: needsTotpEnroll
              ? "Set up Google or Microsoft Authenticator on this account."
              : "Enter the 6-digit code from your authenticator app.",
          trailing: needsTotpEnroll
              ? const _MiniChip(label: "Setup")
              : const _MiniChip(label: "Code"),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsTotpEnroll) ...[
                if (_totpBegin == null) ...[
                  _PrimaryButton(
                    label: "Start setup",
                    onPressed: _busy ? null : _totpBeginEnroll,
                  ),
                ] else ...[
                  const Text(
                    "Secret (Base32)",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SelectableText(_totpBegin!.secretB32),
                  ),
                  const SizedBox(height: 10),
                  _SecondaryButton(
                    label: "Copy secret",
                    onPressed: _busy
                        ? null
                        : () => _svc.copyToClipboard(_totpBegin!.secretB32),
                  ),
                  const SizedBox(height: 14),
                  _PremiumTextField(
                    controller: _totpCtrl,
                    hintText: "Enter the 6-digit code from your app",
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryButton(
                    label: "Confirm & continue",
                    onPressed: _busy ? null : _totpFinishEnrollAndVerify,
                  ),
                ],
              ] else ...[
                _PremiumTextField(
                  controller: _totpCtrl,
                  hintText: "Enter the 6-digit code",
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => _clearError(),
                ),
                const SizedBox(height: 10),
                _PrimaryButton(
                  label: "Verify & continue",
                  onPressed: _busy ? null : _totpVerifyOnly,
                ),
              ],
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _PremiumTopBar extends StatelessWidget {
  const _PremiumTopBar({required this.showBack, required this.onBack});

  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}

class _MethodChoiceCard extends StatelessWidget {
  const _MethodChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _MfaCard extends StatelessWidget {
  const _MfaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0369A1),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        counterText: "",
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF34D399)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.24),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

class _PremiumErrorBanner extends StatelessWidget {
  const _PremiumErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFECACA)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFECACA),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            splashRadius: 18,
            color: const Color(0xFFFECACA),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _PremiumBusy extends StatelessWidget {
  const _PremiumBusy();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: const [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Processing...",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
