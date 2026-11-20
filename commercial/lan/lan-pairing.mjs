import { randomBytes, randomInt, createHash, timingSafeEqual } from 'node:crypto';

// Memory-only pairing: restart invalidates pending codes and active sessions.
export class LanPairing {
  constructor({ now = () => Date.now(), ttlMs = 120_000, sessionTtlMs = 8 * 60 * 60_000, maxAttempts = 5, maxSessions = 16 } = {}) {
    if (!Number.isSafeInteger(ttlMs) || ttlMs < 10_000 || !Number.isSafeInteger(sessionTtlMs) || sessionTtlMs < 60_000 || !Number.isSafeInteger(maxAttempts) || maxAttempts < 1 || !Number.isSafeInteger(maxSessions) || maxSessions < 1) throw new TypeError('invalid pairing policy');
    this.now = now; this.ttlMs = ttlMs; this.sessionTtlMs = sessionTtlMs; this.maxAttempts = maxAttempts; this.maxSessions = maxSessions;
    this.pending = null; this.sessions = new Map();
  }
  issue({ localOperatorApproved = false } = {}) {
    if (localOperatorApproved !== true) throw new Error('LOCAL_APPROVAL_REQUIRED');
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    this.pending = { digest: this.#hash(code), expiresAt: this.now() + this.ttlMs, attempts: 0 };
    return { code, expiresAt: this.pending.expiresAt };
  }
  redeem(code) {
    const p = this.pending;
    if (!p || this.now() >= p.expiresAt || p.attempts >= this.maxAttempts) { this.pending = null; throw new Error('PAIRING_UNAVAILABLE'); }
    p.attempts += 1;
    const supplied = typeof code === 'string' && /^\d{6}$/.test(code) ? this.#hash(code) : Buffer.alloc(32);
    if (!timingSafeEqual(p.digest, supplied)) {
      if (p.attempts >= this.maxAttempts) this.pending = null;
      throw new Error('PAIRING_INVALID');
    }
    this.pending = null;
    this.#pruneExpiredSessions();
    if (this.sessions.size >= this.maxSessions) throw new Error('SESSION_LIMIT_REACHED');
    const token = randomBytes(32).toString('base64url');
    const expiresAt = this.now() + this.sessionTtlMs;
    this.sessions.set(this.#hash(token).toString('hex'), expiresAt);
    return { token, expiresAt };
  }
  verify(token) {
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) return false;
    const key = this.#hash(token).toString('hex');
    const expiry = this.sessions.get(key);
    if (!expiry) return false;
    if (this.now() >= expiry) { this.sessions.delete(key); return false; }
    return true;
  }
  revoke(token) {
    if (typeof token !== 'string') return false;
    return this.sessions.delete(this.#hash(token).toString('hex'));
  }
  revokeAll() { this.pending = null; this.sessions.clear(); }
  #pruneExpiredSessions() {
    const now = this.now();
    for (const [key, expiry] of this.sessions) if (now >= expiry) this.sessions.delete(key);
  }
  #hash(value) { return createHash('sha256').update(value).digest(); }
}
