import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_router.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  // ================= EMAIL LOGIN =================
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
    } catch (e) {
      setState(() => _error = _prettyErr(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _prettyErr(Object e) => e.toString().replaceFirst('Exception: ', '');

  /// ✅ แก้ “กดกากบาทแล้วยังเด้งเข้าแอป”:
  /// - ต้องมี token จริงเท่านั้นถึงถือว่า login สำเร็จ
  /// - มี timeout กันค้าง
Future<void> _runSocial(String name, Future<void> Function() action) async {
  if (_loading) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  debugPrint('[SOCIAL] $name: start');

  bool isCanceled(Object e) {
    final s = e.toString().toLowerCase();

    // ✅ กลุ่ม “ผู้ใช้ยกเลิก/ปิดหน้า/กดกากบาท”
    if (s.contains('canceled') || s.contains('cancelled')) return true;
    if (s.contains('dismissed') || s.contains('closed')) return true;

    // ✅ GitHub บางเคส
    if (s.contains('state mismatch')) return true;

    // ✅ timeout ที่มาจากผู้ใช้ปิดหน้า auth แล้วไม่กลับมา
    // (ถ้าคุณอยากให้ timeout ถือเป็น error จริง ให้ลบบรรทัดนี้)
    if (s.contains('timeout') && s.contains('canceled')) return true;

    return false;
  }

  try {
    await action().timeout(
      const Duration(seconds: 25),
      onTimeout: () {
        // ถ้าอยากให้ timeout = เงียบ ๆ เหมือนยกเลิก ให้ใช้ข้อความ canceled
        throw Exception('$name canceled (timeout)');
      },
    );

    // ✅ กันพลาด: ต้องมี token จริงเท่านั้น
    final token = await AuthService.instance.getTokenOrNull();
    if (token == null || token.trim().isEmpty) {
      // ถือว่าเป็นการยกเลิก/ไม่ได้ล็อกอินจริง → ไม่โชว์แดง
      throw Exception('$name canceled (no token returned)');
    }

    debugPrint('[SOCIAL] $name: done (token ok)');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
  } catch (e) {
    debugPrint('[SOCIAL] $name: error => $e');

    if (isCanceled(e)) {
      // ✅ ผู้ใช้ยกเลิก: เงียบ ๆ ไม่ขึ้นแถบแดง
      setState(() => _error = null);
    } else {
      // ✅ error จริง: โชว์แถบแดง
      setState(() => _error = _prettyErr(e));
    }
  } finally {
    if (mounted) setState(() => _loading = false);
    debugPrint('[SOCIAL] $name: finally (loading=false)');
  }
}


  Future<void> _loginGoogle() => _runSocial('Google', () async {
        debugPrint('[SOCIAL] Google: calling SocialAuthService.loginWithGoogle()');
        await SocialAuthService.instance.loginWithGoogle();
        debugPrint('[SOCIAL] Google: SocialAuthService returned');
      });

  Future<void> _loginFacebook() => _runSocial('Facebook', () async {
        debugPrint('[SOCIAL] Facebook: calling SocialAuthService.loginWithFacebook()');
        await SocialAuthService.instance.loginWithFacebook();
        debugPrint('[SOCIAL] Facebook: SocialAuthService returned');
      });

  Future<void> _loginGithub() => _runSocial('GitHub', () async {
        debugPrint('[SOCIAL] GitHub: calling SocialAuthService.loginWithGithub()');
        await SocialAuthService.instance.loginWithGithub();
        debugPrint('[SOCIAL] GitHub: SocialAuthService returned');
      });

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const ink = Color(0xFF0F0F10);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black.withOpacity(0.07)),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Welcome back — please login to continue',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ink.withOpacity(0.55),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 16),

                          const _FieldLabel('Email'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              hint: 'you@example.com',
                              icon: Icons.alternate_email_rounded,
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Please enter email';
                              if (!s.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          const _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecoration(
                              hint: 'Password',
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _showPassword = !_showPassword),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) return 'Please enter password';
                              return null;
                            },
                          ),

                          const SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : () {},
                              style: TextButton.styleFrom(
                                foregroundColor: ink.withOpacity(0.65),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: ink,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.black.withOpacity(0.10),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ink.withOpacity(0.45),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.black.withOpacity(0.10),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'เข้าสู่ระบบด้วย',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LogoOnlyButton(
                                semanticsLabel: 'Facebook',
                                assetPath: 'assets/logos/facebook.png',
                                size: 44,
                                onTap: _loading ? null : _loginFacebook,
                              ),
                              const SizedBox(width: 28),
                              _LogoOnlyButton(
                                semanticsLabel: 'Google',
                                assetPath: 'assets/logos/google.svg',
                                size: 44,
                                onTap: _loading ? null : _loginGoogle,
                              ),
                              const SizedBox(width: 28),
                              _LogoOnlyButton(
                                semanticsLabel: 'GitHub',
                                assetPath: 'assets/logos/github.svg',
                                size: 44,
                                onTap: _loading ? null : _loginGithub,
                              ),
                            ],
                          ),

                          if (_loading) ...[
                            const SizedBox(height: 12),
                            const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(color: Colors.black.withOpacity(0.12)),
                              ),
                              onPressed: _loading ? null : () => Navigator.pushNamed(context, AppRouter.registerRoute),
                              child: const Text(
                                'Create an account',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "By continuing, you agree to QuakeLink's Terms & Privacy.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ink.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'QuakeLink • Earthquake Alerts & Safety',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ink.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.35)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFB42318)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFB42318)),
      ),
    );
  }
}

// ================== Helper Widgets ==================

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.10),
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
        ),
        const SizedBox(height: 10),
        const Text(
          'QuakeLink',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Real-time earthquake alerts for safer decisions',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.50),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FF3B30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFB42318)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A271A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoOnlyButton extends StatelessWidget {
  final String semanticsLabel;
  final String assetPath;
  final double size;
  final VoidCallback? onTap;

  const _LogoOnlyButton({
    required this.semanticsLabel,
    required this.assetPath,
    required this.onTap,
    this.size = 44,
  });

  bool get _isSvg => assetPath.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Opacity(
        opacity: disabled ? 0.55 : 1.0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _isSvg
                ? SvgPicture.asset(
                    assetPath,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  )
                : Image.asset(
                    assetPath,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
