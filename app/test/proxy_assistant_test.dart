import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selam/models/assistant_result.dart';
import 'package:selam/services/assistant_backend.dart';
import 'package:selam/services/mock_assistant.dart';
import 'package:selam/services/proxy_assistant.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonRes(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('registers once, sends token, parses result', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.url.path} ${req.headers['X-App-Token'] ?? '-'}');
      if (req.url.path == '/api/register') return jsonRes({'token': 'tok1'}, 200);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['audio_base64'], base64Encode([1, 2, 3]));
      expect(body['mime_type'], 'audio/mp4');
      return jsonRes({
        'transcript_am': 'ሰላም',
        'intent': 'weather',
        'slots': {'city': 'Addis Ababa'},
        'reply_am': 'እሺ',
      }, 200);
    });
    final p = ProxyAssistant(client: client, baseUrl: 'https://x', readFile: (_) async => [1, 2, 3]);
    final r1 = await p.understandAudio('a.m4a');
    await p.understandAudio('a.m4a');
    expect(r1.intent, Intent.weather);
    expect(r1.offline, isFalse);
    expect(calls, ['/api/register -', '/api/understand tok1', '/api/understand tok1']);
  });

  test('401 clears the token and re-registers once', () async {
    SharedPreferences.setMockInitialValues({'app_token': 'old'});
    var understandCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/register') return jsonRes({'token': 'new'}, 200);
      understandCalls++;
      if (req.headers['X-App-Token'] == 'old') return jsonRes({'error': 'invalid_token'}, 401);
      return jsonRes({'transcript_am': '', 'intent': 'chat', 'slots': {}, 'reply_am': 'ok'}, 200);
    });
    final r = await ProxyAssistant(client: client, baseUrl: 'https://x').understandText('hi');
    expect(r.replyAm, 'ok');
    expect(understandCalls, 2);
  });

  test('not_configured surfaces as AssistantException(notConfigured)', () async {
    final client = MockClient((_) async => jsonRes({'error': 'not_configured'}, 503));
    final p = ProxyAssistant(client: client, baseUrl: 'https://x');
    expect(
      () => p.understandText('hi'),
      throwsA(isA<AssistantException>().having((e) => e.notConfigured, 'notConfigured', true)),
    );
  });

  test('fallback uses mock when proxy is not configured, then backs off', () async {
    var proxyCalls = 0;
    final client = MockClient((_) async {
      proxyCalls++;
      return jsonRes({'error': 'not_configured'}, 503);
    });
    final f = FallbackAssistant(
      primary: ProxyAssistant(client: client, baseUrl: 'https://x'),
      fallback: MockAssistant(latency: Duration.zero),
    );
    final r1 = await f.understandText('ለ3 ደቂቃ ሰዓት ቆጣሪ');
    final r2 = await f.understandText('ዜና');
    expect(r1.offline, isTrue);
    expect(r1.intent, Intent.setTimer);
    expect(r2.intent, Intent.news);
    expect(f.lastFallbackReason, 'not_configured');
    expect(proxyCalls, 1); // second call skipped the proxy
  });

  test('fallback recovers when the proxy answers', () async {
    final client = MockClient((req) async => req.url.path == '/api/register'
        ? jsonRes({'token': 't'}, 200)
        : jsonRes({'transcript_am': 'x', 'intent': 'news', 'slots': {}, 'reply_am': 'y'}, 200));
    final f = FallbackAssistant(
      primary: ProxyAssistant(client: client, baseUrl: 'https://x'),
      fallback: MockAssistant(latency: Duration.zero),
    );
    final r = await f.understandText('x');
    expect(r.offline, isFalse);
    expect(f.lastFallbackReason, isNull);
  });
}
