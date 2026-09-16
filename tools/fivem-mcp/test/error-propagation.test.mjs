#!/usr/bin/env node
/**
 * Static regression test: error propagation in sunset_test_agent.
 *
 * Proves (structurally) that no RpcClient.await / requireResource result
 * can degrade to `nil, nil`:
 *  - every `RpcClient.await` call site MUST capture two locals
 *  - the failure branch MUST return the second captured local (rpcRes/res),
 *    never an unrelated variable (the old `return nil, err` bug)
 *  - every requireResource call site must capture its error and return it
 *  - no tool may `return nil` bare (loses the error entirely)
 *
 * Run: node tools/fivem-mcp/test/error-propagation.test.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert';
import { test } from 'node:test';

// Resolve the repo root from this file (tools/fivem-mcp/test → repo root),
// so the test works regardless of cwd. Uses fileURLToPath for Windows safety.
import { fileURLToPath } from 'node:url';
const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, '../../..');
const ROOT = path.join(REPO_ROOT, 'resources', '[sunset]', 'sunset_test_agent', 'server');
const FILES = ['tools.lua', 'domains.lua', 'http.lua', 'auth.lua', 'rpc.lua', 'main.lua'];

function loadFile(name) {
  const p = path.join(ROOT, name);
  return { name, text: fs.readFileSync(p, 'utf8'), lines: fs.readFileSync(p, 'utf8').split('\n') };
}

test('every RpcClient.await captures both results', () => {
  for (const f of FILES.map(loadFile)) {
    f.lines.forEach((line, i) => {
      if (!line.includes('RpcClient.await(')) return;
      if (line.trim().startsWith('--')) return;
      // Skip the DEFINITION of RpcClient.await itself (rpc.lua).
      if (/function\s+RpcClient\.await/.test(line)) return;
      // Must be `local X, Y = RpcClient.await(...)` — two locals.
      const m = line.match(/local\s+([A-Za-z_][\w]*)\s*,\s*([A-Za-z_][\w]*)\s*=\s*RpcClient\.await/);
      assert.ok(m, `${f.name}:${i + 1} RpcClient.await must capture two locals: ${line.trim()}`);
    });
  }
});

test('RPC failure branches return the captured error, not a foreign one', () => {
  for (const f of FILES.map(loadFile)) {
    for (let i = 0; i < f.lines.length; i++) {
      const m = f.lines[i].match(/local\s+([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*=\s*RpcClient\.await/);
      if (!m) continue;
      const [, okVar, resVar] = m;
      // Find the next `if not <okVar> then` within 6 lines and check the return.
      for (let j = i + 1; j < Math.min(i + 7, f.lines.length); j++) {
        if (f.lines[j].includes(`if not ${okVar} then`)) {
          const ret = f.lines[j];
          assert.ok(
            ret.includes(`return nil, ${resVar}`) || ret.includes(`PendingScreenshots[requestId] = nil`),
            `${f.name}:${j + 1} failure branch must return ${resVar}: ${ret.trim()}`,
          );
          // The very next line (or same line) is the return — ensure no foreign var
          assert.ok(!/return nil, err\b/.test(ret), `${f.name}:${j + 1} returns foreign 'err' (nil,nil bug): ${ret.trim()}`);
          break;
        }
      }
    }
  }
});

test('requireResource errors are captured and propagated', () => {
  for (const f of FILES.map(loadFile)) {
    f.lines.forEach((line, i) => {
      if (!line.includes('requireResource(')) return;
      if (line.trim().startsWith('--') || line.includes('local function requireResource')) return;
      const m = line.match(/local\s+([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*=\s*requireResource/);
      assert.ok(m, `${f.name}:${i + 1} requireResource must capture error: ${line.trim()}`);
      const [, okVar, errVar] = m;
      // next non-empty line must return the captured error
      let j = i + 1;
      while (j < f.lines.length && f.lines[j].trim() === '') j++;
      assert.ok(
        f.lines[j].includes(`if not ${okVar}`) && f.lines[j].includes(`return nil, ${errVar}`),
        `${f.name}:${j + 1} requireResource failure must return ${errVar}: ${f.lines[j].trim()}`,
      );
    });
  }
});

test('resolveTarget errors are propagated under the same name', () => {
  for (const f of FILES.map(loadFile)) {
    f.lines.forEach((line, i) => {
      const m = line.match(/local\s+(\w+)\s*,\s*(\w+)\s*=\s*TestAgentAuth\.(resolveTarget|resolveMutationTarget)/);
      if (!m) return;
      const [, srcVar, errVar] = m;
      let j = i + 1;
      while (j < f.lines.length && f.lines[j].trim() === '') j++;
      assert.ok(
        f.lines[j].includes(`if not ${srcVar}`) && f.lines[j].includes(`return nil, ${errVar}`),
        `${f.name}:${j + 1} resolveTarget failure must return ${errVar}: ${f.lines[j].trim()}`,
      );
    });
  }
});

test('no bare "return nil" inside tool functions (would lose the error)', () => {
  // Predicate helpers legitimately use nil-as-absence (no error to propagate).
  const PREDICATES = new Set([
    'resourceGuard', 'requireResource', 'testPlayer', 'loadToken', 'licenseOf',
    'tokenConfigured', 'findVaultEntity', 'enabled', 'hasTestPlayer',
    'TestAgentAuth.testPlayer', 'TestAgentAuth.tokenConfigured', 'TestAgentAuth.licenseOf',
    'TestAgentAuth.hasTestPlayer', 'TestAgentAuth.enabled', 'TestAgentAuth.loadToken',
  ]);
  for (const f of FILES.map(loadFile)) {
    // Track the enclosing function name so predicates are exempt.
    let enclosing = '';
    f.lines.forEach((line, i) => {
      const decl = line.match(/^\s*(?:local\s+)?function\s+([\w.]+)/);
      if (decl) enclosing = decl[1];
      if (/return nil\s*$/.test(line) && !line.trim().startsWith('--')) {
        assert.ok(
          PREDICATES.has(enclosing),
          `${f.name}:${i + 1} bare 'return nil' inside ${enclosing || '?'} loses structured errors: ${line.trim()}`,
        );
      }
    });
  }
});
