// Small request guards shared by the API routes.

export function send(res, status, body, headers = {}) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
}

/**
 * The only client is the native Android app, which sends no Origin header.
 * Browser requests (which always carry Origin on cross-site POSTs) are
 * refused, and no Access-Control-Allow-Origin header is ever returned.
 * Returns true when the request was handled (rejected).
 */
export function rejectBrowsers(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 403, { error: 'cors_forbidden' });
    return true;
  }
  if (req.headers.origin) {
    send(res, 403, { error: 'cors_forbidden' });
    return true;
  }
  return false;
}

export function clientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (typeof fwd === 'string' && fwd) return fwd.split(',')[0].trim();
  return req.socket?.remoteAddress ?? 'unknown';
}
