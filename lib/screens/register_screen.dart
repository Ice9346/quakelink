import 'package:flutter/material.dart';
import '../app_router.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _provinceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const black = Color(0xFF0F0F10);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Top back ----------
                  Row(
                    children: [
                      IconButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: "Back",
                      ),
                      const Spacer(),
                    ],
                  ),

                  // ---------- Brand header ----------
                  const SizedBox(height: 6),
                  _BrandHeaderCompact(
                    title: "Create account",
                    subtitle: "Join QuakeLink to receive alerts and safety updates",
                  ),

                  const SizedBox(height: 18),

                  // ---------- Card ----------
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 22,
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
                            "Sign up",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Create your account in a minute",
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.55),
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Name
                          const _FieldLabel("Name"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: _inputDecoration(
                              hint: "Your name",
                              icon: Icons.person_rounded,
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return "Please enter your name";
                              if (value.length < 2) return "Name is too short";
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // Email
                          const _FieldLabel("Email"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: _inputDecoration(
                              hint: "name@example.com",
                              icon: Icons.alternate_email_rounded,
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return "Please enter your email";
                              if (!value.contains('@')) return "Invalid email format";
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // Password
                          const _FieldLabel("Password"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: _inputDecoration(
                              hint: "Min 6 characters",
                              icon: Icons.lock_rounded,
                              suffix: IconButton(
                                onPressed: _loading
                                    ? null
                                    : () => setState(() => _showPassword = !_showPassword),
                                tooltip: _showPassword ? "Hide password" : "Show password",
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.black.withOpacity(0.55),
                                ),
                              ),
                            ),
                            validator: (v) {
                              final value = (v ?? '');
                              if (value.isEmpty) return "Please enter your password";
                              if (value.length < 6) return "Password must be at least 6 characters";
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // Province (optional)
                          const _FieldLabel("Province (optional)"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _provinceCtrl,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _loading ? null : _submit(),
                            decoration: _inputDecoration(
                              hint: "e.g., Chiang Mai",
                              icon: Icons.place_rounded,
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(message: _error!),
                          ],

                          const SizedBox(height: 14),

                          // Create account button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _loading
                                    ? const SizedBox(
                                        key: ValueKey('loading'),
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        "Create account",
                                        key: ValueKey('text'),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Back to login
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _loading ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: black,
                                side: BorderSide(color: Colors.black.withOpacity(0.14)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Back to login",
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "By creating an account, you agree to QuakeLink’s Terms & Privacy.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "QuakeLink • Earthquake Alerts & Safety",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.42),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
      prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.65)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F0F10), width: 1.4),
      ),
    );
  }
}

class _BrandHeaderCompact extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BrandHeaderCompact({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.16),
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withOpacity(0.58),
            fontWeight: FontWeight.w600,
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
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: Colors.black.withOpacity(0.78),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.black.withOpacity(0.70)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.black.withOpacity(0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
