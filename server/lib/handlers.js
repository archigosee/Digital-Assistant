import { callGemini, DEFAULT_MODEL } from './gemini.js';
import { clientIp, rejectBrowsers, send } from './http.js';
import { createLimiter } from './ratelimit.js';
import { issueToken, signingSecret, verifyToken } from './token.js';

export const MAX_AUDIO_B64 = 1_500_000; // ~1.1 MB of audio (> 4 min at 32 kbps)
export const MAX_TEXT = 500;
const AUDIO_TYPES = new Set(['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/wav', 'audio/x-wav', 'audio/ogg', 'audio/mpeg', 'audio/webm']);
const B64_RE = /^[A-Za-z0-9+/]+={0,2}$/;

export function healthHandler({ env = process.env } = {}) {
  return (req, res) => {
    if (rejectBrowsers(req, res)) return;
    send(res, 200, { ok: true, service: 'selam-proxy', configured: Boolean(env.GEMINI_API_KEY) });
  };
}

export function registerHandler({ env = process.env, limiter = createLimiter({ limit: 5, windowMs: 3600_000 }) } = {}) {
  return (req, res) => {
    if (rejectBrowsers(req, res)) return;
    if (req.method !== 'POST') return send(res, 405, { error: 'method_not_allowed' }, { Allow: 'POST' });
    const secret = signingSecret(env);
    if (!secret) return send(res, 503, { error: 'not_configured', message: 'GEMINI_API_KEY is not set on the proxy.' });
    const rl = limiter(`reg:${clientIp(req)}`);
    if (!rl.allowed) return send(res, 429, { error: 'rate_limited' }, { 'Retry-After': String(rl.retryAfterSec) });
    send(res, 200, { token: issueToken(secret) });
  };
}

export function understandHandler({
  env = process.env,
  fetchImpl = fetch,
  tokenLimiter = createLimiter({ limit: 20, windowMs: 60_000 }),
  dailyLimiter = createLimiter({ limit: 300, windowMs: 86_400_000 }),
  ipLimiter = createLimiter({ limit: 60, windowMs: 60_000 }),
} = {}) {
  return async (req, res) => {
    if (rejectBrowsers(req, res)) return;
    if (req.method !== 'POST') return send(res, 405, { error: 'method_not_allowed' }, { Allow: 'POST' });

    const apiKey = env.GEMINI_API_KEY;
    if (!apiKey) return send(res, 503, { error: 'not_configured', message: 'GEMINI_API_KEY is not set on the proxy.' });

    const installId = verifyToken(req.headers['x-app-token'], signingSecret(env));
    if (!installId) return send(res, 401, { error: 'invalid_token' });

    for (const [lim, key] of [[ipLimiter, `ip:${clientIp(req)}`], [tokenLimiter, `t:${installId}`], [dailyLimiter, `d:${installId}`]]) {
      const rl = lim(key);
      if (!rl.allowed) return send(res, 429, { error: 'rate_limited' }, { 'Retry-After': String(rl.retryAfterSec) });
    }

    const ct = String(req.headers['content-type'] ?? '');
    if (!ct.startsWith('application/json')) return send(res, 415, { error: 'json_required' });
    const body = req.body && typeof req.body === 'object' ? req.body : null;
    if (!body) return send(res, 400, { error: 'invalid_body' });

    const input = {};
    if (typeof body.text === 'string' && body.text.trim()) {
      if (body.text.length > MAX_TEXT) return send(res, 413, { error: 'text_too_long' });
      input.text = body.text.trim();
    } else if (typeof body.audio_base64 === 'string' && body.audio_base64) {
      if (body.audio_base64.length > MAX_AUDIO_B64) return send(res, 413, { error: 'audio_too_large' });
      if (!B64_RE.test(body.audio_base64)) return send(res, 400, { error: 'invalid_audio' });
      const mime = String(body.mime_type ?? 'audio/mp4').toLowerCase();
      if (!AUDIO_TYPES.has(mime)) return send(res, 415, { error: 'unsupported_audio_type' });
      input.audioBase64 = body.audio_base64;
      input.mimeType = mime === 'audio/m4a' ? 'audio/mp4' : mime;
    } else {
      return send(res, 400, { error: 'text_or_audio_required' });
    }

    try {
      const result = await callGemini(input, { apiKey, model: env.GEMINI_MODEL || DEFAULT_MODEL, fetchImpl });
      send(res, 200, result);
    } catch (e) {
      // Never echo upstream details (could include request info); log server-side only.
      console.error('gemini error', e.message, e.status ?? '', e.detail ?? '');
      const status = e.status === 429 ? 429 : 502;
      send(res, status, { error: status === 429 ? 'upstream_busy' : 'upstream_error' });
    }
  };
}
