import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'auth_service.dart';

class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  String get _baseUrl => AuthService.baseUrl;

  Map<String, String> _headers() => const {'Content-Type': 'application/json'};

  Map<String, dynamic> _decode(String body) {
    try {
      final x = jsonDecode(body);
      return x is Map<String, dynamic> ? x : {'raw': x};
    } catch (_) {
      return {'raw': body};
    }
  }

  Never _throwServerError(int status, Map<String, dynamic> data) {
    final msg = (data['message'] ??
            data['error'] ??
            data['detail'] ??
            data['raw'] ??
            'OAuth failed ($status)')
        .toString();
    throw Exception(msg);
  }

  Future<void> _exchangeAndSave({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    http.Response res;
    try {
      res = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Request timeout. Please try again.');
    }

    final data = _decode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = ((data['accessToken'] ??
                  data['token'] ??
                  data['jwt'] ??
                  data['access_token']) ??
              '')
          .toString()
          .trim();

      if (token.isEmpty) {
        throw Exception('OAuth success but missing token from server');
      }

      await AuthService.instance.saveToken(token);
      return;
    }

    _throwServerError(res.statusCode, data);
  }

  // -------------------- Google --------------------
  Future<void> loginWithGoogle() async {
    final google = GoogleSignIn(scopes: const ['email', 'profile']);

    GoogleSignInAccount? account;
    try {
      account = await google.signIn();
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }

    if (account == null) {
      throw Exception('Google sign-in canceled');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google login failed: missing idToken');
    }

    // ✅ backend ของคุณคือ POST /auth/google
    await _exchangeAndSave(
      path: '/auth/google',
      body: {'idToken': idToken},
    );
  }

  // -------------------- Facebook --------------------
  Future<void> loginWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (result.status == LoginStatus.cancelled) {
      throw Exception('Facebook login canceled');
    }

    if (result.status != LoginStatus.success) {
      throw Exception(result.message ?? 'Facebook login failed');
    }

    final accessToken = result.accessToken?.tokenString;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Facebook login failed: missing accessToken');
    }

    // ✅ backend ของคุณคือ POST /auth/facebook
    await _exchangeAndSave(
      path: '/auth/facebook',
      body: {'accessToken': accessToken},
    );
  }

  // -------------------- GitHub --------------------
  Future<void> loginWithGithub() async {
    const githubClientId =
        String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '');

    const callbackScheme = 'quakelink';
    const redirectUri = 'quakelink://auth/github';

    if (githubClientId.isEmpty) {
      throw Exception(
          'Missing GITHUB_CLIENT_ID (flutter run --dart-define=GITHUB_CLIENT_ID=...)');
    }

    final state = DateTime.now().millisecondsSinceEpoch.toString();

    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': githubClientId,
      'redirect_uri': redirectUri,
      'scope': 'read:user user:email',
      'state': state,
    }).toString();

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: callbackScheme,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('GitHub login canceled/timeout'),
      );
    } catch (_) {
      throw Exception('GitHub login canceled');
    }

    final uri = Uri.parse(result);

    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      final desc = uri.queryParameters['error_description'] ?? error;
      throw Exception('GitHub login failed: $desc');
    }

    final returnedState = uri.queryParameters['state'];
    if (returnedState != state) {
      throw Exception('GitHub login failed: state mismatch');
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('GitHub login canceled');
    }

    // ✅ backend ของคุณคือ POST /auth/github และรับแค่ { code }
    await _exchangeAndSave(
      path: '/auth/github',
      body: {'code': code},
    );
  }
}
