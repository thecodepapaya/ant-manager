/// Google OAuth for the built-in desktop client (#11, #76): PKCE + loopback redirect.
/// The app supplies only `openBrowser`; everything else is pure Dart.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Built-in OAuth client (owner registers it; see docs/OWNER_TODO.md). Desktop clients ship their "secret" in the
/// binary by design; PKCE is what protects the flow.
const googleClientId = 'TODO_GOOGLE_CLIENT_ID';
const googleClientSecret = 'TODO_GOOGLE_CLIENT_SECRET';
const googleCalendarScope = 'https://www.googleapis.com/auth/calendar.readonly';

final _authEndpoint = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');
final _tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');

/// What `SourceContext.secret()` holds for a Google Calendar source (JSON).
class GoogleTokens {
  const GoogleTokens({required this.accessToken, required this.refreshToken, required this.expiresAt});

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool expired(DateTime now) => !now.isBefore(expiresAt.subtract(const Duration(minutes: 1)));

  factory GoogleTokens.fromJson(Map<String, Object?> j) => GoogleTokens(
    accessToken: j['access_token'] as String? ?? '',
    refreshToken: j['refresh_token'] as String,
    expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? '') ?? DateTime.utc(1970),
  );

  factory GoogleTokens.decode(String s) => GoogleTokens.fromJson(jsonDecode(s) as Map<String, Object?>);

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());
}

class GoogleOAuth {
  GoogleOAuth({
    Dio? http,
    this.clientId = googleClientId,
    this.clientSecret = googleClientSecret,
    Uri? authEndpoint,
    Uri? tokenEndpoint,
    DateTime Function()? now,
  }) : _http = http ?? Dio(),
       authEndpoint = authEndpoint ?? _authEndpoint,
       tokenEndpoint = tokenEndpoint ?? _tokenEndpoint,
       _now = now ?? (() => DateTime.now().toUtc());

  final Dio _http;
  final String clientId;
  final String clientSecret;
  final Uri authEndpoint;
  final Uri tokenEndpoint;
  final DateTime Function() _now;

  /// Full interactive sign-in: starts a one-shot loopback server, opens the consent page, waits for the redirect,
  /// exchanges the code. Store `result.encode()` as the source's secret.
  Future<GoogleTokens> signIn(
    Future<void> Function(Uri) openBrowser, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://127.0.0.1:${server.port}';
      final verifier = randomUrlSafe(48);
      final state = randomUrlSafe(16);
      final code = _awaitCode(server, state).timeout(timeout)..ignore(); // still awaited below
      await openBrowser(authUrl(redirectUri: redirectUri, codeChallenge: codeChallenge(verifier), state: state));
      return await exchangeCode(code: await code, verifier: verifier, redirectUri: redirectUri);
    } finally {
      await server.close(force: true);
    }
  }

  Uri authUrl({required String redirectUri, required String codeChallenge, required String state}) =>
      authEndpoint.replace(
        queryParameters: {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': googleCalendarScope,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
          'state': state,
          'access_type': 'offline', // refresh token
          'prompt': 'consent', // always return a refresh token, even on re-connect
        },
      );

  Future<GoogleTokens> exchangeCode({
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    final j = await _token({
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirectUri,
    });
    return _tokens(j, null);
  }

  /// Google omits `refresh_token` on refresh; the old one stays valid.
  Future<GoogleTokens> refresh(String refreshToken) async =>
      _tokens(await _token({'grant_type': 'refresh_token', 'refresh_token': refreshToken}), refreshToken);

  Future<Map<String, Object?>> _token(Map<String, String> form) async {
    final r = await _http.postUri<Object?>(
      tokenEndpoint,
      data: {...form, 'client_id': clientId, 'client_secret': clientSecret},
      options: Options(contentType: Headers.formUrlEncodedContentType, responseType: ResponseType.json),
    );
    final d = r.data;
    return d is String ? jsonDecode(d) as Map<String, Object?> : d as Map<String, Object?>;
  }

  GoogleTokens _tokens(Map<String, Object?> j, String? previousRefresh) {
    final refresh = j['refresh_token'] as String? ?? previousRefresh;
    if (refresh == null) throw StateError('Google returned no refresh token');
    return GoogleTokens(
      accessToken: j['access_token'] as String,
      refreshToken: refresh,
      expiresAt: _now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 3600)),
    );
  }

  Future<String> _awaitCode(HttpServer server, String state) async {
    await for (final req in server) {
      final q = req.uri.queryParameters;
      if (!q.containsKey('code') && !q.containsKey('error')) {
        req.response.statusCode = HttpStatus.notFound; // favicon etc.
        await req.response.close();
        continue;
      }
      final ok = q['state'] == state && q['code'] != null;
      req.response
        ..statusCode = ok ? HttpStatus.ok : HttpStatus.badRequest
        ..headers.contentType = ContentType.html
        ..write(
          ok
              ? '<html><body>Signed in. You can close this window and return to Ant Manager.</body></html>'
              : '<html><body>Sign-in failed. Return to Ant Manager and try again.</body></html>',
        );
      await req.response.close();
      if (!ok) throw StateError('Google sign-in failed: ${q['error'] ?? 'state mismatch'}');
      return q['code']!;
    }
    throw StateError('Sign-in server closed before a redirect arrived');
  }
}

final _rand = Random.secure();

String randomUrlSafe(int bytes) => base64UrlEncode(List.generate(bytes, (_) => _rand.nextInt(256))).replaceAll('=', '');

String codeChallenge(String verifier) =>
    base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
