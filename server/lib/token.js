import { createHmac, createHash, randomUUID, timingSafeEqual } from 'node:crypto';

// Per-install app tokens: "<installId>.<hmac>". The app calls /api/register
// once, stores the token, and sends it as X-App-Token on every request.
// Signing secret: APP_TOKEN_SECRET if set, otherwise derived from the Gemini
// key (so Kaleab only has one env var to set). Rotating either revokes tokens.

export function signingSecret(env = process.env) {
  if (env.APP_TOKEN_SECRET) return env.APP_TOKEN_SECRET;
  if (env.GEMINI_API_KEY) {
    return createHash('sha256').update(`selam-app-token:${env.GEMINI_API_KEY}`).digest('hex');
  }
  return null;
}

function sign(id, secret) {
  return createHmac('sha256', secret).update(id).digest('base64url');
}

export function issueToken(secret, id = randomUUID()) {
  return `${id}.${sign(id, secret)}`;
}

const ID_RE = /^[0-9a-f-]{36}$/;

/** Returns the install id when the token is valid, else null. */
export function verifyToken(token, secret) {
  if (typeof token !== 'string' || !secret) return null;
  const dot = token.indexOf('.');
  if (dot < 0) return null;
  const id = token.slice(0, dot);
  const mac = token.slice(dot + 1);
  if (!ID_RE.test(id)) return null;
  const expected = Buffer.from(sign(id, secret));
  const given = Buffer.from(mac);
  if (expected.length !== given.length) return null;
  return timingSafeEqual(expected, given) ? id : null;
}
