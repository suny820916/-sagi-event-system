import { createLanGateway } from './lan-gateway.mjs';

// Bridge only to the authoritative loopback engine. Never expose its token to phones.
export function createEngineLanGateway(engine, options = {}) {
  if (engine?.address?.address !== '127.0.0.1' || !Number.isInteger(engine.address.port) ||
      typeof engine.token !== 'string' || engine.token.length < 32) throw new Error('LOOPBACK_ENGINE_REQUIRED');
  const base = 'http://127.0.0.1:' + engine.address.port;
  async function request(path, command) {
    const response = await fetch(base + path, {
      method: command ? 'POST' : 'GET',
      headers: { authorization: 'Bearer ' + engine.token, 'content-type': 'application/json' },
      body: command ? JSON.stringify(command) : undefined,
      redirect: 'error', signal: AbortSignal.timeout(5000),
    });
    const body = await response.json();
    if (!response.ok) {
      const error = new Error('ENGINE_REQUEST_FAILED');
      error.code = response.status === 409 && body.error === 'COMMAND_ID_CONFLICT' ? 'COMMAND_ID_CONFLICT' :
        response.status === 409 ? 'REVISION_CONFLICT' :
        response.status === 400 ? 'INVALID_COMMAND' : 'ENGINE_UNAVAILABLE';
      error.revision = body.revision;
      throw error;
    }
    return body;
  }
  return createLanGateway({
    ...options,
    getState: async () => (await request('/api/v1/state')).state,
    submitCommand: command => request('/api/v1/commands', command),
  });
}
