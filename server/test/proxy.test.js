import { test } from 'node:test';
import assert from 'node:assert/strict';

import { addisNowIso, buildRequest, parseResponse, INTENTS } from '../lib/gemini.js';
import { healthHandler, registerHandler, understandHandler } from '../lib/handlers.js';
import { createLimiter } from '../lib/ratelimit.js';
import { issueToken, signingSecret, verifyToken } from '../lib/token.js';

const ENV = { GEMINI_API_KEY: 'test-key-not-real' };

function mockRes() {
  return {
    statusCode: 200, headers: {}, body: undefined,
    setHeader(k, v) { this.headers[k.toLowerCase()] = v; },
    end(b) { this.body = b ? JSON.parse(b) : undefined; },
  };
}
function req({ method = 'POST', headers = {}, body } = {}) {
  return { method, headers: { 'content-type': 'application/json', ...headers }, body, socket: { remoteAddress: '1.2.3.4' } };
}
const geminiOk = (payload) => async () => ({
  ok: true, status: 200,
  json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(payload) }] } }] }),
});

test('tokens: issue/verify, tamper and wrong secret rejected', () => {
  const secret = signingSecret(ENV);
  const tok = issueToken(secret);
  assert.match(verifyToken(tok, secret), /^[0-9a-f-]{36}$/);
  assert.equal(verifyToken(tok + 'x', secret), null);
  assert.equal(verifyToken(tok, 'other'), null);
  assert.equal(verifyToken('nope', secret), null);
  assert.equal(verifyToken(undefined, secret), null);
  assert.equal(signingSecret({}), null);
  assert.equal(signingSecret({ APP_TOKEN_SECRET: 's', GEMINI_API_KEY: 'k' }), 's');
});

test('rate limiter: blocks over limit, resets after window', () => {
  let t = 0;
  const check = createLimiter({ limit: 2, windowMs: 1000, now: () => t });
  assert.ok(check('a').allowed);
  assert.ok(check('a').allowed);
  const third = check('a');
  assert.equal(third.allowed, false);
  assert.equal(third.retryAfterSec, 1);
  assert.ok(check('b').allowed);
  t = 1000;
  assert.ok(check('a').allowed);
});

test('gemini: request uses structured output and inline audio', () => {
  const r = buildRequest({ audioBase64: 'AAAA', mimeType: 'audio/mp4' }, new Date('2026-11-09T09:00:00Z'));
  assert.equal(r.generationConfig.responseMimeType, 'application/json');
  assert.deepEqual(r.generationConfig.responseSchema.properties.intent.enum, INTENTS);
  assert.equal(r.contents[0].parts[0].inlineData.data, 'AAAA');
  assert.match(r.systemInstruction.parts[0].text, /2026-11-09T12:00:00\+03:00/);
  assert.equal(addisNowIso(new Date('2026-11-09T22:30:00Z')), '2026-11-10T01:30:00+03:00');
});

test('gemini: parseResponse validates intent and slots', () => {
  const body = (o) => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(o) }] } }] });
  const ok = parseResponse(body({ transcript_am: 'ሰላም', intent: 'set_timer', slots: { duration_seconds: 60 }, reply_am: 'እሺ' }));
  assert.equal(ok.intent, 'set_timer');
  assert.equal(ok.slots.duration_seconds, 60);
  assert.equal(parseResponse(body({ intent: 'hack', slots: [] })).intent, 'chat');
  assert.deepEqual(parseResponse(body({ intent: 'news', slots: [] })).slots, {});
  assert.throws(() => parseResponse({}), /empty_response/);
  assert.throws(() => parseResponse({ candidates: [{ content: { parts: [{ text: '{oops' }] } }] }), /invalid_json/);
});

test('health reports configured state', () => {
  const r1 = mockRes(); healthHandler({ env: {} })(req({ method: 'GET' }), r1);
  assert.equal(r1.body.configured, false);
  const r2 = mockRes(); healthHandler({ env: ENV })(req({ method: 'GET' }), r2);
  assert.equal(r2.body.configured, true);
});

test('not configured -> 503 not_configured on register and understand', async () => {
  const r1 = mockRes(); registerHandler({ env: {} })(req(), r1);
  assert.equal(r1.statusCode, 503);
  assert.equal(r1.body.error, 'not_configured');
  const r2 = mockRes(); await understandHandler({ env: {} })(req({ body: { text: 'hi' } }), r2);
  assert.equal(r2.statusCode, 503);
  assert.equal(r2.body.error, 'not_configured');
});

test('browsers are refused (CORS guard) and no ACAO header is sent', async () => {
  const r = mockRes();
  await understandHandler({ env: ENV })(req({ headers: { origin: 'https://evil.example' }, body: { text: 'x' } }), r);
  assert.equal(r.statusCode, 403);
  assert.equal(r.headers['access-control-allow-origin'], undefined);
  const r2 = mockRes(); registerHandler({ env: ENV })(req({ method: 'OPTIONS' }), r2);
  assert.equal(r2.statusCode, 403);
});

test('understand: token required, guards, success path', async () => {
  const reg = mockRes(); registerHandler({ env: ENV })(req(), reg);
  const token = reg.body.token;
  const h = understandHandler({ env: ENV, fetchImpl: geminiOk({ transcript_am: 'ሰላም', intent: 'chat', slots: {}, reply_am: 'ሰላም!' }) });

  const noTok = mockRes(); await h(req({ body: { text: 'ሰላም' } }), noTok);
  assert.equal(noTok.statusCode, 401);

  const auth = { 'x-app-token': token };
  const empty = mockRes(); await h(req({ headers: auth, body: {} }), empty);
  assert.equal(empty.statusCode, 400);
  const long = mockRes(); await h(req({ headers: auth, body: { text: 'x'.repeat(501) } }), long);
  assert.equal(long.statusCode, 413);
  const badMime = mockRes(); await h(req({ headers: auth, body: { audio_base64: 'AAAA', mime_type: 'video/mp4' } }), badMime);
  assert.equal(badMime.statusCode, 415);
  const badB64 = mockRes(); await h(req({ headers: auth, body: { audio_base64: 'not base64!' } }), badB64);
  assert.equal(badB64.statusCode, 400);
  const notJson = mockRes(); await h(req({ headers: { ...auth, 'content-type': 'text/plain' }, body: 'x' }), notJson);
  assert.equal(notJson.statusCode, 415);
  const get = mockRes(); await h(req({ method: 'GET', headers: auth }), get);
  assert.equal(get.statusCode, 405);

  const ok = mockRes(); await h(req({ headers: auth, body: { audio_base64: 'AAAA', mime_type: 'audio/m4a' } }), ok);
  assert.equal(ok.statusCode, 200);
  assert.deepEqual(ok.body, { transcript_am: 'ሰላም', intent: 'chat', slots: {}, reply_am: 'ሰላም!' });
});

test('understand: rate limit per token and upstream errors are masked', async () => {
  const secret = signingSecret(ENV);
  const auth = { 'x-app-token': issueToken(secret) };
  const h = understandHandler({
    env: ENV,
    tokenLimiter: createLimiter({ limit: 1, windowMs: 60_000 }),
    fetchImpl: async () => ({ ok: false, status: 400, json: async () => ({ error: { message: 'API key not valid: secret-ish detail' } }) }),
  });
  const first = mockRes(); await h(req({ headers: auth, body: { text: 'a' } }), first);
  assert.equal(first.statusCode, 502);
  assert.deepEqual(first.body, { error: 'upstream_error' });
  const second = mockRes(); await h(req({ headers: auth, body: { text: 'a' } }), second);
  assert.equal(second.statusCode, 429);
  assert.ok(Number(second.headers['retry-after']) > 0);
});
