import http from 'node:http';
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
  pairing = new LanPairing(), getState = () => ({}),
  host = '127.0.0.1', now = () => Date.now(),
  maxAttemptsPerWindow = 8, windowMs = 60_000,
} = {}) {
  if (!isIP(host) || ['0.0.0.0', '::'].includes(host)) throw new Error('EXPLICIT_INTERFACE_REQUIRED');
  const attempts = new Map();
  const server = http.createServer(async (req, res) => {
    const path = new URL(req.url || '/', 'http://localhost').pathname;
    const ip = keyOf(req.socket.remoteAddress);
    if (req.headers.origin) return reply(res, 403, { error: 'ORIGIN_FORBIDDEN' });
    if (req.headers['content-type'] && !String(req.headers['content-type']).toLowerCase().startsWith('application/json'))
      return reply(res, 415, { error: 'JSON_REQUIRED' });
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
    if (path === '/api/v1/lan/state' && req.method === 'GET') {
      const auth = req.headers.authorization || '';
      const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
      if (!pairing.verify(token)) return reply(res, 401, { error: 'UNAUTHORIZED' });
      try { return reply(res, 200, { state: await getState() }); }
      catch { return reply(res, 503, { error: 'STATE_UNAVAILABLE' }); }
    }
    return reply(res, 404, { error: 'NOT_FOUND' });
  });
  return {
    server, pairing, host,
    listen: (port = 0) => new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(port, host, () => { server.off('error', reject); resolve(server.address()); });
    }),
  };
}
