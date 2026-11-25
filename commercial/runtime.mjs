import { createLocalServer } from './core/local-server.mjs';
import { createEngineLanGateway } from './lan/engine-lan-bridge.mjs';

export async function startCommercialRuntime({
  lanHost = '127.0.0.1', lanPort = 0, ...engineOptions
} = {}) {
  const engine = await createLocalServer({ ...engineOptions, host: '127.0.0.1' });
  let gateway;
  let address;
  try {
    gateway = createEngineLanGateway(engine, { host: lanHost });
    address = await gateway.listen(lanPort);
  } catch (startupError) {
    try {
      await engine.close();
    } catch (cleanupError) {
      throw new AggregateError([startupError, cleanupError], 'COMMERCIAL_RUNTIME_STARTUP_FAILED');
    }
    throw startupError;
  }

  const host = address.family === 'IPv6' ? `[${address.address}]` : address.address;
  let closing;
  return {
    engine,
    mobileUrl: `http://${host}:${address.port}/mobile`,
    // Call only after the local operator approves on the desktop.
    approvePhonePairing() {
      if (closing) throw new Error('COMMERCIAL_RUNTIME_CLOSING');
      return gateway.pairing.issue({ localOperatorApproved: true });
    },
    close() {
      return closing ??= (async () => {
        try {
          await new Promise((resolve, reject) => {
            gateway.server.close(error => error ? reject(error) : resolve());
          });
        } finally {
          await engine.close();
        }
      })();
    },
  };
}
