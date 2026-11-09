import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_result.dart';
import 'assistant_backend.dart';
import 'mock_assistant.dart';

/// Proxy base URL; override with `--dart-define=SELAM_API=https://...`.
const kSelamApi = String.fromEnvironment(
  'SELAM_API',
  defaultValue: 'https://amharic-assistant-api.vercel.app',
);

/// Talks to the Vercel proxy, which calls Gemini with the server-side key.
/// The app only ever holds a per-install token from `/api/register`.
class ProxyAssistant implements AssistantBackend {
  ProxyAssistant({
    http.Client? client,
    this.baseUrl = kSelamApi,
    Future<SharedPreferences> Function()? prefs,
    Future<List<int>> Function(String path)? readFile,
  })  : _client = client ?? http.Client(),
        _prefs = prefs ?? SharedPreferences.getInstance,
        _readFile = readFile ?? ((p) => File(p).readAsBytes());

  final http.Client _client;
  final String baseUrl;
  final Future<SharedPreferences> Function() _prefs;
  final Future<List<int>> Function(String path) _readFile;

  static const _tokenKey = 'app_token';
  static const timeout = Duration(seconds: 30);

  @override
  Future<AssistantResult> understandAudio(String audioPath) async {
    final bytes = await _readFile(audioPath);
    return _understand({
      'audio_base64': base64Encode(bytes),
      'mime_type': 'audio/mp4',
    });
  }

  @override
  Future<AssistantResult> understandText(String text) =>
      _understand({'text': text});

  Future<AssistantResult> _understand(Map<String, dynamic> body,
      {bool retried = false}) async {
    final token = await _token();
    final r = await _post('/api/understand', body, token: token);
    if (r.statusCode == 401 && !retried) {
      // Token revoked (e.g. key rotated): register again once.
      (await _prefs()).remove(_tokenKey);
      return _understand(body, retried: true);
    }
    _throwIfError(r);
    final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return AssistantResult.fromJson(json);
  }

  Future<String> _token() async {
    final p = await _prefs();
    final saved = p.getString(_tokenKey);
    if (saved != null) return saved;
    final r = await _post('/api/register', const {});
    _throwIfError(r);
    final token = (jsonDecode(r.body) as Map<String, dynamic>)['token'] as String;
    await p.setString(_tokenKey, token);
    return token;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body,
      {String? token}) async {
    try {
      return await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Token': ?token,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Exception catch (e) {
      throw AssistantException('network: $e');
    }
  }

  void _throwIfError(http.Response r) {
    if (r.statusCode == 200) return;
    String code = 'http_${r.statusCode}';
    try {
      code = (jsonDecode(r.body) as Map<String, dynamic>)['error'] as String? ?? code;
    } catch (_) {}
    throw AssistantException(code, notConfigured: code == 'not_configured');
  }
}

/// Uses Gemini via the proxy when available, the offline mock otherwise.
/// After a "not configured" answer the proxy is skipped for [backoff].
class FallbackAssistant implements AssistantBackend {
  FallbackAssistant({
    required this.primary,
    required this.fallback,
    this.backoff = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AssistantBackend primary;
  final MockAssistant fallback;
  final Duration backoff;
  final DateTime Function() _now;
  DateTime? _skipUntil;

  /// Why the last answer came from the mock (null when Gemini answered).
  String? lastFallbackReason;

  @override
  Future<AssistantResult> understandAudio(String audioPath) => _try(
      () => primary.understandAudio(audioPath),
      () => fallback.understandAudio(audioPath));

  @override
  Future<AssistantResult> understandText(String text) => _try(
      () => primary.understandText(text), () => fallback.understandText(text));

  Future<AssistantResult> _try(Future<AssistantResult> Function() a,
      Future<AssistantResult> Function() b) async {
    final skip = _skipUntil;
    if (skip != null && _now().isBefore(skip)) {
      lastFallbackReason = 'not_configured';
      return b();
    }
    try {
      final r = await a();
      lastFallbackReason = null;
      return r;
    } on AssistantException catch (e) {
      lastFallbackReason = e.message;
      if (e.notConfigured) _skipUntil = _now().add(backoff);
      return b();
    }
  }
}
