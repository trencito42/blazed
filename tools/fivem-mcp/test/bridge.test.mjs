// Bridge-level tests that don't need FiveM:
// 1. Health degrades gracefully when unreachable.
// 2. Auth: missing token → UNAUTHORIZED structured error.
// 3. Timeout: unreachable host with short timeout → TIMEOUT error.
// 4. Mock HTTP bridge: spin a local server mimicking the agent, verify
//    invoke roundtrip, error propagation, screenshot download.
import { test } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';

process.env.FIVEM_TEST_URL = 'http://127.0.0.1:1/testagent'; // port 1 — nothing listens
process.env.FIVEM_TEST_TIMEOUT_MS = '1500';
process.env.FIVEM_TEST_TOKEN = '';

const { TestAgentClient, BridgeCallError } = await import('../dist/client.js');

test('missing token → UNAUTHORIZED (no crash)', async () => {
  const c = new TestAgentClient();
  await assert.rejects(() => c.call('health'), (e) => {
    assert.ok(e instanceof BridgeCallError);
    assert.equal(e.code, 'UNAUTHORIZED');
    return true;
  });
});

test('unreachable bridge → BRIDGE_UNREACHABLE, retryable', async () => {
  process.env.FIVEM_TEST_TOKEN = 'tok';
  const c = new TestAgentClient();
  await assert.rejects(() => c.call('health'), (e) => {
    assert.ok(e instanceof BridgeCallError);
    assert.equal(e.code, 'BRIDGE_UNREACHABLE');
    assert.equal(e.retryable, true);
    return true;
  });
});

test('mock bridge: invoke roundtrip + error propagation + screenshot', async () => {
  const store = { ss_1: Buffer.from('fakejpegbytes') };
  const srv = http.createServer((req, res) => {
    const auth = req.headers['authorization'];
    if (auth !== 'Bearer goodtoken') {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, error: { code: 'UNAUTHORIZED', message: 'bad token', retryable: false } }));
      return;
    }
    if (req.method === 'GET' && req.url.startsWith('/testagent/screenshot/')) {
      const id = req.url.slice('/testagent/screenshot/'.length);
      if (store[id]) {
        res.writeHead(200, { 'Content-Type': 'image/jpeg' });
        res.end(store[id]);
      } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: { code: 'SCREENSHOT_FAILED', message: 'not found', retryable: true } }));
      }
      return;
    }
    if (req.method === 'POST' && req.url === '/testagent/invoke') {
      let body = '';
      req.on('data', (d) => (body += d));
      req.on('end', () => {
        const parsed = JSON.parse(body);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        if (parsed.tool === 'health') {
          res.end(JSON.stringify({ requestId: parsed.requestId, ok: true, result: { bridge: 'ok', testPlayer: { connected: true } } }));
        } else if (parsed.tool === 'boom') {
          res.end(JSON.stringify({ requestId: parsed.requestId, ok: false, error: { code: 'ENTITY_NOT_FOUND', message: 'gone', retryable: false } }));
        } else {
          res.end(JSON.stringify({ requestId: parsed.requestId, ok: false, error: { code: 'INVALID_ARGUMENT', message: 'Unknown tool', retryable: false } }));
        }
      });
      return;
    }
    res.writeHead(404); res.end('{}');
  });
  await new Promise((r) => srv.listen(39123, '127.0.0.1', r));

  process.env.FIVEM_TEST_URL = 'http://127.0.0.1:39123/testagent';
  process.env.FIVEM_TEST_TOKEN = 'goodtoken';
  const c = new TestAgentClient();

  const health = await c.call('health');
  assert.deepEqual(health, { bridge: 'ok', testPlayer: { connected: true } });

  await assert.rejects(() => c.call('boom'), (e) => {
    assert.equal(e.code, 'ENTITY_NOT_FOUND');
    assert.equal(e.retryable, false);
    return true;
  });

  const shot = await c.screenshot('ss_1');
  assert.equal(shot.mime, 'image/jpeg');
  assert.deepEqual(shot.bytes, Buffer.from('fakejpegbytes'));

  await assert.rejects(() => c.screenshot('missing'), (e) => e.code === 'SCREENSHOT_FAILED');

  srv.close();
});

test('timeout: slow bridge → TIMEOUT', async () => {
  const slow = http.createServer((req, res) => {
    // never respond within the client timeout
    const t = setTimeout(() => { res.writeHead(200); res.end('{}'); }, 5000);
    res.on('close', () => clearTimeout(t));
  });
  await new Promise((r) => slow.listen(39124, '127.0.0.1', r));
  process.env.FIVEM_TEST_URL = 'http://127.0.0.1:39124/testagent';
  process.env.FIVEM_TEST_TIMEOUT_MS = '800';
  const c = new TestAgentClient();
  await assert.rejects(() => c.call('health'), (e) => {
    assert.equal(e.code, 'TIMEOUT');
    return true;
  });
  slow.close();
});
