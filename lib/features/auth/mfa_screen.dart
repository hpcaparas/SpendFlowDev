import 'package:flutter/material.dart';
import '../mfa/mfa_service.dart';
import 'models/auth_models.dart';
import 'token_store.dart';
import '../../app_router.dart';
import '../auth/push_bootstrap.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key, required this.challenge});

  final MfaChallenge challenge;

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _svc = MfaService();

  bool _loading = false;
  String? _error;

  // For TOTP
  TotpEnrollBeginResponse? _totpBegin;
  final _totpCtrl = TextEditingController();

  @override
  void dispose() {
    _totpCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishLoginFromAuthResponse(Map<String, dynamic> resp) async {
    await TokenStore.saveFromAuthResponse(resp);

    // ✅ Register push AFTER tokens + user/company are saved
    await PushBootstrap.registerAfterLogin();

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.shell, (route) => false);
  }

  // ---------------- PASSKEY ----------------
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
            "No passkey found on this device for this account. Please enroll a passkey on this phone (or use TOTP).";
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

  // ---------------- TOTP ----------------
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
    final code = _totpCtrl.text.trim();
    if (code.length != 6) {
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
        code: code,
      );

      // After enrollment, verify to get tokens (or backend can return tokens in enroll/finish if you prefer)
      final resp = await _svc.totpVerify(
        preAuthToken: widget.challenge.preAuthToken,
        code: code,
      );

      await _finishLoginFromAuthResponse(resp);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _totpVerifyOnly() async {
    final code = _totpCtrl.text.trim();
    if (code.length != 6) {
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
        code: code,
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

    // ✅ This is the key fix:
    final needsTotpEnroll = supportsTotp && (ch.hasTotp == false);

    return Scaffold(
      appBar: AppBar(title: const Text("Multi-factor authentication")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],

                if (_loading) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                ],

                // ---------------- PASSKEY SECTION ----------------
                if (supportsPasskey) ...[
                  const Text(
                    "Passkey",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text("Use biometrics / device lock."),
                  const SizedBox(height: 12),

                  if (!_loading) ...[
                    if (ch.mode == "enroll") ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _enrollPasskeyThenVerify,
                          child: const Text("Enroll + Verify passkey"),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _verifyPasskey,
                        child: const Text("Verify with passkey"),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ],

                // ---------------- TOTP SECTION ----------------
                if (supportsTotp) ...[
                  const Text(
                    "Authenticator App (TOTP)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  if (needsTotpEnroll) ...[
                    const Text(
                      "You have not enrolled an authenticator app yet. Start setup below.",
                    ),
                    const SizedBox(height: 10),

                    if (_totpBegin == null && !_loading)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _totpBeginEnroll,
                          child: const Text("Start TOTP setup"),
                        ),
                      ),

                    if (_totpBegin != null) ...[
                      const SizedBox(height: 12),
                      const Text("Secret (Base32):"),
                      SelectableText(_totpBegin!.secretB32),
                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () =>
                                    _svc.copyToClipboard(_totpBegin!.secretB32),
                          child: const Text("Copy secret"),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        "Add this secret to Google Authenticator / Microsoft Authenticator, then enter the 6-digit code below to confirm.",
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _totpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "6-digit code",
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 6,
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : _totpFinishEnrollAndVerify,
                          child: const Text("Confirm + Verify"),
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      "Enter the 6-digit code from your authenticator app.",
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _totpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "6-digit code",
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 6,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _totpVerifyOnly,
                        child: const Text("Verify code"),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 18),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.shell,
                          (route) => false,
                        ),
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
