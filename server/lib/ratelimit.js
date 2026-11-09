// Fixed-window in-memory rate limiter. Serverless instances don't share
// memory, so this is best effort per warm instance; it still stops a single
// client hammering one instance. (A shared store such as Upstash would make it
// global, but that needs an account.)

export function createLimiter({ limit, windowMs, now = () => Date.now() }) {
  const hits = new Map();
  return function check(key) {
    const t = now();
    let entry = hits.get(key);
    if (!entry || t - entry.start >= windowMs) {
      entry = { start: t, count: 0 };
      hits.set(key, entry);
    }
    entry.count++;
    if (hits.size > 5000) {
      for (const [k, v] of hits) if (t - v.start >= windowMs) hits.delete(k);
    }
    const allowed = entry.count <= limit;
    return {
      allowed,
      remaining: Math.max(0, limit - entry.count),
      retryAfterSec: allowed ? 0 : Math.ceil((entry.start + windowMs - t) / 1000),
    };
  };
}
