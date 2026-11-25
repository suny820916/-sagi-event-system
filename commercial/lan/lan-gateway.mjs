import http from 'node:http';
import { mobileHtml, mobileJs } from './mobile-console.mjs';
import { isIP } from 'node:net';
import { LanPairing } from './lan-pairing.mjs';

function reply(res, status, data) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    'content-security-policy': "default-src 'none'",
  });
  res.end(JSON.stringify(data));
}
const isLoopback = ip => ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(ip);
const keyOf = ip => String(ip || 'unknown').replace(/^::ffff:/, '');

async function readBody(req) {
  const chunks = []; let bytes = 0;
  for await (const chunk of req) {
    bytes += chunk.length;
    if (bytes > 2048) throw new Error('BODY_TOO_LARGE');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new Error('INVALID_JSON'); }
}

// Experimental HTTP gateway. Never bind a public wildcard interface.
// Local operator approval is deliberately NOT exposed as a remote HTTP command.
export function createLanGateway({
  pairing = new LanPairing(), getState = () => ({}), submitCommand = null,
  host = '127.0.0.1', now = () => Date.now(),
  maxAttemptsPerWindow = 8, windowMs = 60_000,
} = {}) {
  if (!isIP(host) || ['0.0.0.0', '::'].includes(host)) throw new Error('EXPLICIT_INTERFACE_REQUIRED');
  const attempts = new Map();
  const server = http.createServer(async (req, res) => {
    // Accept only origin-form request targets. Absolute-form URLs, query strings
    // and malformed encodings are not valid command routes on this LAN API.
    const target = req.url || '';
    if (!target.startsWith('/') || target.startsWith('//') ||
        /[?#\\]/.test(target) || /%[0-9a-f]{2}/i.test(target))
      return reply(res, 400, { error: 'INVALID_REQUEST_TARGET' });
    let path;
    try {
      path = new URL(target, 'http://localhost').pathname;
      if (path !== target) throw new Error('NON_CANONICAL_PATH');
    } catch {
      return reply(res, 400, { error: 'INVALID_REQUEST_TARGET' });
    }
    const ip = keyOf(req.socket.remoteAddress);
    // Reject DNS rebinding and forged Host headers. Only the explicitly bound
    // interface (or loopback aliases for a loopback listener) is acceptable.
    const hostHeader = String(req.headers.host || '');
    let requestHost;
    try {
      // Host is an authority, not a URL: reject credentials, paths and whitespace.
      if (!hostHeader || /[@\/\\?#\s]/.test(hostHeader)) throw new Error('BAD_HOST');
      const authority = /^(?:\[[0-9a-f:.]+\]|[a-z0-9.-]+):([0-9]{1,5})$/i.exec(hostHeader);
      if (!authority) throw new Error('PORT_REQUIRED');
      if (authority[1] !== String(server.address()?.port)) throw new Error('WRONG_PORT');
      const parsed = new URL('http://' + hostHeader);
      if (parsed.hostname + ':' + authority[1] !== hostHeader.toLowerCase()) throw new Error('NON_CANONICAL_HOST');
      requestHost = parsed.hostname.replace(/^\[/, '').replace(/\]$/, '');
    }
    catch { return reply(res, 400, { error: 'INVALID_HOST' }); }
    const allowedHosts = new Set([host]);
    if (host === '127.0.0.1') allowedHosts.add('localhost');
    if (host === '::1') allowedHosts.add('localhost');
    if (!allowedHosts.has(requestHost)) return reply(res, 403, { error: 'HOST_FORBIDDEN' });
    // Browsers sending a same-origin Origin are legitimate. Reject foreign origins
    // and malformed/multiple Origin values; never reflect arbitrary CORS origins.
    if (req.headers.origin) {
      const origin = String(req.headers.origin);
      let valid = false;
      try {
        const parsedOrigin = new URL(origin);
        valid = parsedOrigin.protocol === 'http:' &&
          origin === parsedOrigin.origin &&
          parsedOrigin.origin === new URL('http://' + hostHeader).origin &&
          parsedOrigin.pathname === '/' && !parsedOrigin.search && !parsedOrigin.hash &&
          !parsedOrigin.username && !parsedOrigin.password;
      } catch { /* reject */ }
      if (!valid) return reply(res, 403, { error: 'ORIGIN_FORBIDDEN' });
    }
    if (req.method === 'POST' && !/^application\/json(?:\s*;|\s*$)/i.test(String(req.headers['content-type'] || '')))
      return reply(res, 415, { error: 'JSON_REQUIRED' });
    if (req.method === 'GET' && (path === '/mobile' || path === '/mobile.js')) {
      res.writeHead(200, {
        'content-type': path === '/mobile' ? 'text/html; charset=utf-8' : 'text/javascript; charset=utf-8',
        'cache-control': 'no-store',
        'x-content-type-options': 'nosniff',
        'content-security-policy': "default-src 'none'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
      });
      return res.end(path === '/mobile' ? mobileHtml : mobileJs);
    }
    if (path === '/api/v1/lan/health' && req.method === 'GET')
      return reply(res, 200, { ok: true });
    if (path === '/api/v1/lan/issue' && req.method === 'POST') {
      if (!isLoopback(req.socket.remoteAddress)) return reply(res, 403, { error: 'LOCAL_OPERATOR_ONLY' });
      return reply(res, 403, { error: 'DESKTOP_APPROVAL_INTEGRATION_REQUIRED' });
    }
    if (path === '/api/v1/lan/redeem' && req.method === 'POST') {
      const current = now();
      for (const [k, b] of attempts) if (current - b.start >= windowMs) attempts.delete(k);
      if (!attempts.has(ip) && attempts.size >= 512) return reply(res, 429, { error: 'RATE_LIMITED' });
      const b = attempts.get(ip) || { start: current, count: 0 };
      b.count++; attempts.set(ip, b);
      if (b.count > maxAttemptsPerWindow) return reply(res, 429, { error: 'RATE_LIMITED' });
      try {
        const body = await readBody(req);
        return reply(res, 200, pairing.redeem(body?.code));
      } catch (err) {
        return reply(res, err.message === 'BODY_TOO_LARGE' ? 413 : 400, { error: err.message });
      }
    }
    if (path === '/api/v1/lan/command' && req.method === 'POST') {
      const auth = req.headers.authorization || '';
      const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
      if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
      if (typeof submitCommand !== 'function') return reply(res, 503, { error: 'COMMANDS_UNAVAILABLE' });
      try {
        const body = await readBody(req);
        if (!body || typeof body !== 'object' || Array.isArray(body) ||
            typeof body.commandId !== 'string' || !/^[a-zA-Z0-9_-]{8,128}$/.test(body.commandId) ||
            !Number.isSafeInteger(body.expectedRevision) || body.expectedRevision < 0 ||
            typeof body.type !== 'string' || !/^[A-Z_]{2,48}$/.test(body.type))
          return reply(res, 400, { error: 'INVALID_COMMAND' });
        // A session may expire or be revoked while a slow body is arriving.
        if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
        // Only football state commands may cross this mobile gateway. Never forward
        // arbitrary vMix or administrative operations from a paired phone.
        const allowed = new Set(['GOAL', 'SCORE_ADJUST', 'YELLOW', 'RED', 'SUB', 'SET_CLOCK_RUNNING', 'SET_CLOCK', 'HALF_TIME', 'FULL_TIME', 'START_PENALTIES', 'PENALTY_ATTEMPT', 'UNDO_PENALTY_ATTEMPT', 'FINISH_PENALTIES', 'SET_PERIOD']);
        if (!allowed.has(body.type)) return reply(res, 403, { error: 'COMMAND_NOT_ALLOWED' });
        const result = await submitCommand(body);
        // Revocation during an asynchronous command must not disclose the result.
        // The command may already have committed: the client must resync after re-pairing,
        // never issue a new command ID to guess whether it succeeded.
        if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
        return reply(res, 200, { result });
      } catch (err) {
        // Do not disclose command outcome or current revision to a revoked device.
        // The command might already be committed; client must resync after pairing.
        if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
        if (err.message === 'BODY_TOO_LARGE') return reply(res, 413, { error: 'BODY_TOO_LARGE' });
        if (err.message === 'INVALID_JSON') return reply(res, 400, { error: 'INVALID_JSON' });
        if (err.code === 'REVISION_CONFLICT' || err.code === 'FIXTURE_MISMATCH') {
          return reply(res, 409, { error: err.code, revision: err.revision });
        }
        if (err.code === 'COMMAND_ID_CONFLICT' || err.message === 'COMMAND_ID_CONFLICT') return reply(res, 409, { error: 'COMMAND_ID_CONFLICT' });
        if (err.code === 'INVALID_COMMAND') return reply(res, 400, { error: 'INVALID_COMMAND' });
        return reply(res, 503, { error: 'COMMAND_FAILED' });
      }
    }
    if (path === '/api/v1/lan/state' && req.method === 'GET') {
      const auth = req.headers.authorization || '';
      const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
      if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
      try {
        const state = await getState();
        // A session may be revoked while an asynchronous state read is pending.
        // Never release match data after the authorization has expired.
        if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
        return reply(res, 200, { state });
      } catch {
        if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
        return reply(res, 503, { error: 'STATE_UNAVAILABLE' });
      }
    }
    return reply(res, 404, { error: 'NOT_FOUND' });
  });
  // Bound idle and incomplete HTTP connections so an abandoned phone or
  // malicious LAN peer cannot occupy sockets indefinitely during a match.
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  server.timeout = 20_000;
  server.keepAliveTimeout = 5_000;
  server.maxRequestsPerSocket = 100;
  return {
    server, pairing, host,
    listen: (port = 0) => new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(port, host, () => { server.off('error', reject); resolve(server.address()); });
    }),
  };
}
