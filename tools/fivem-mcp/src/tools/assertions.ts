/**
 * Health, assertions, wait_for, and domain adapters.
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail, assertionResult, deepEqual } from '../protocol.js';

interface Vec3 { x: number; y: number; z: number }

async function getPlayerCoords(client: TestAgentClient, target: unknown): Promise<Vec3> {
  const res = await client.call<Vec3>('get_player_coords', { target: target ?? 'test' });
  return res;
}

export function registerCoreTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_health',
    {
      title: 'Bridge health check',
      description:
        'Structured health of the whole test stack: MCP config, bridge reachability, FXServer, test agent resource, test player (connected/serverId/clientReady), sunset_core, sunset_ui, screenshot availability. Call this FIRST — it never crashes even when FiveM is offline.',
      inputSchema: {},
    },
    async () => {
      // Graceful degradation: if the bridge is unreachable, report it instead of throwing.
      try {
        const bridge = await client.call<Record<string, unknown>>('health');
        return ok({ mcp: 'ok', ...bridge });
      } catch (e) {
        const err = e instanceof Error ? e : new Error(String(e));
        return ok({
          mcp: 'ok',
          bridge: 'unreachable',
          fxserver: 'offline',
          detail: err.message,
          testPlayer: { connected: false, serverId: null, clientReady: false },
          hint: 'Start FXServer with sunset_test_agent enabled and FIVEM_TEST_TOKEN set, then retry.',
        });
      }
    },
  );

  // ── wait_for ──
  server.registerTool(
    'fivem_wait_for',
    {
      title: 'Wait for a runtime condition',
      description:
        'Poll until a condition holds or the timeout expires. Conditions: player_near (coords+radius), resource_state (name+state), nui_panel_open (panel name substring), robbery_stage (stage string), vehicle_networked, custom_callback (allowlisted invoke_callback name + JSON path check is NOT supported — returns the raw result for you to assert). Never hangs: bounded by timeoutMs (max 60s).',
      inputSchema: {
        condition: z.enum(['player_near', 'resource_state', 'nui_focus', 'vehicle_networked', 'robbery_stage', 'race_phase']),
        x: z.number().optional(), y: z.number().optional(), z: z.number().optional(),
        radius: z.number().optional(),
        resource: z.string().optional(),
        state: z.string().optional(),
        value: z.string().optional().describe('expected stage/phase value for robbery_stage / race_phase'),
        timeoutMs: z.number().min(500).max(60000).optional(),
        intervalMs: z.number().min(200).max(5000).optional(),
        target: z.union([z.number(), z.string()]).optional(),
      },
    },
    async (args) => {
      const timeout = args.timeoutMs ?? 15000;
      const interval = args.intervalMs ?? 1000;
      const deadline = Date.now() + timeout;
      const target = args.target ?? 'test';
      let last: unknown = null;
      try {
        while (Date.now() < deadline) {
          switch (args.condition) {
            case 'player_near': {
              if (args.x === undefined || args.y === undefined || args.z === undefined) {
                return fail(new Error('player_near requires x, y, z'));
              }
              const c = await getPlayerCoords(client, target);
              const d = Math.hypot(c.x - args.x, c.y - args.y, (c.z ?? 0) - (args.z ?? 0));
              last = { distance: Number(d.toFixed(2)), radius: args.radius ?? 5 };
              if (d <= (args.radius ?? 5)) return ok({ satisfied: true, condition: args.condition, last });
              break;
            }
            case 'resource_state': {
              if (!args.resource) return fail(new Error('resource_state requires resource'));
              const r = await client.call<{ state: string }>('get_resource_state', { args: { name: args.resource } });
              last = r;
              if (r.state === (args.state ?? 'started')) return ok({ satisfied: true, condition: args.condition, last });
              break;
            }
            case 'nui_focus': {
              const n = await client.call<{ focus?: { keyboard?: boolean } }>('get_nui_state', { target });
              last = n.focus ?? null;
              const want = (args.value ?? 'true') === 'true';
              if ((n.focus?.keyboard ?? false) === want) return ok({ satisfied: true, condition: args.condition, last });
              break;
            }
            case 'vehicle_networked': {
              const v = await client.call<{ networked?: boolean; inVehicle?: boolean }>('get_player_vehicle', { target });
              last = v;
              if (v.inVehicle && v.networked) return ok({ satisfied: true, condition: args.condition, last });
              break;
            }
            case 'robbery_stage': {
              const rb = await client.call<{ live?: { stage?: string } | null }>('get_robbery_state', { target });
              last = rb.live ?? null;
              if (rb.live && (args.value === undefined || rb.live.stage === args.value)) {
                return ok({ satisfied: true, condition: args.condition, last });
              }
              break;
            }
            case 'race_phase': {
              const rs = await client.call<{ session?: { inRace?: boolean; phase?: string } | null; activeRace?: { phase?: string } | null }>('get_race_state', { target });
              const phase = rs.activeRace?.phase ?? null;
              last = { phase, session: rs.session ?? null };
              if (phase && (args.value === undefined || phase === args.value)) {
                return ok({ satisfied: true, condition: args.condition, last });
              }
              break;
            }
          }
          await new Promise((r) => setTimeout(r, interval));
        }
        return fail({ code: 'TIMEOUT', message: `wait_for ${args.condition} timed out after ${timeout}ms`, retryable: true, last });
      } catch (e) {
        return fail(e);
      }
    },
  );

  // ── assertions ──
  const assertionConditions = z.enum([
    'player_position', 'resource_started', 'entity_exists', 'nui_focus',
    'money_equals', 'inventory_contains', 'player_in_vehicle', 'state_equals',
    'robbery_stage', 'no_nui_errors',
  ]);

  server.registerTool(
    'fivem_assert',
    {
      title: 'Runtime assertion',
      description:
        'Deterministic structured assertion against live runtime state. Returns {passed, expected, actual} — never vague prose. Conditions: player_position (x,y,z,radius), resource_started (name), entity_exists (netId), nui_focus (true/false), money_equals (account+amount), inventory_contains (item,minCount), player_in_vehicle (isDriver?), state_equals (uses invoke_callback name + expected JSON value), robbery_stage (value), no_nui_errors.',
      inputSchema: {
        condition: assertionConditions,
        x: z.number().optional(), y: z.number().optional(), z: z.number().optional(),
        radius: z.number().optional(),
        name: z.string().optional().describe('resource name / item name / callback name per condition'),
        netId: z.number().optional(),
        account: z.enum(['cash', 'bank']).optional(),
        amount: z.number().optional(),
        minCount: z.number().optional(),
        isDriver: z.boolean().optional(),
        expected: z.unknown().optional(),
        value: z.string().optional(),
        target: z.union([z.number(), z.string()]).optional(),
      },
    },
    async (args) => {
      const target = args.target ?? 'test';
      try {
        switch (args.condition) {
          case 'player_position': {
            const c = await getPlayerCoords(client, target);
            const d = Math.hypot(c.x - (args.x ?? 0), c.y - (args.y ?? 0), (c.z ?? 0) - (args.z ?? 0));
            const radius = args.radius ?? 5;
            return ok(assertionResult(d <= radius, { within: radius, of: { x: args.x, y: args.y, z: args.z } }, { distance: Number(d.toFixed(2)), coords: c }, 'player_position'));
          }
          case 'resource_started': {
            const r = await client.call<{ state: string }>('get_resource_state', { args: { name: args.name } });
            return ok(assertionResult(r.state === 'started', 'started', r.state, `resource_started(${args.name})`));
          }
          case 'entity_exists': {
            const res = await client.call('inspect_entity', { target, args: { netId: args.netId } }).then(
              (v) => ({ exists: true, v }),
              (e: { code?: string }) => ({ exists: false, code: e?.code }),
            );
            return ok(assertionResult(res.exists, 'entity resolvable', res.exists ? 'exists' : `gone (${(res as { code?: string }).code})`, 'entity_exists'));
          }
          case 'nui_focus': {
            const n = await client.call<{ focus?: { keyboard?: boolean } }>('get_nui_state', { target });
            const want = args.expected !== false && args.expected !== 'false';
            return ok(assertionResult((n.focus?.keyboard ?? false) === want, want, n.focus?.keyboard ?? false, 'nui_focus'));
          }
          case 'money_equals': {
            const m = await client.call<Record<string, number>>('get_player_money', { target });
            const acct = args.account ?? 'cash';
            return ok(assertionResult(m[acct] === args.amount, args.amount, m[acct], `money_equals(${acct})`));
          }
          case 'inventory_contains': {
            const inv = await client.call<{ items: Array<{ item: string; count: number }> }>('get_player_inventory', { target });
            const row = (inv.items ?? []).find((i) => i.item === args.name);
            const have = row?.count ?? 0;
            return ok(assertionResult(have >= (args.minCount ?? 1), { item: args.name, minCount: args.minCount ?? 1 }, { item: args.name, count: have }, 'inventory_contains'));
          }
          case 'player_in_vehicle': {
            const v = await client.call<{ inVehicle?: boolean; isDriver?: boolean }>('get_player_vehicle', { target });
            const pass = (args.isDriver === undefined ? !!v.inVehicle : (!!v.inVehicle && v.isDriver === args.isDriver)) === true;
            return ok(assertionResult(pass, { inVehicle: true, isDriver: args.isDriver ?? 'any' }, { inVehicle: v.inVehicle ?? false, isDriver: v.isDriver ?? false }, 'player_in_vehicle'));
          }
          case 'state_equals': {
            if (!args.name) return fail(new Error('state_equals requires name (callback) and expected'));
            const res = await client.call<{ result?: unknown }>('invoke_callback', { target, args: { name: args.name, args: [] } });
            return ok(assertionResult(deepEqual(res.result, args.expected), args.expected, res.result, `state_equals(${args.name})`));
          }
          case 'robbery_stage': {
            const rb = await client.call<{ live?: { stage?: string } | null }>('get_robbery_state', { target });
            return ok(assertionResult((rb.live?.stage ?? null) === (args.value ?? null), args.value ?? null, rb.live?.stage ?? null, 'robbery_stage'));
          }
          case 'no_nui_errors': {
            const errs = await client.call<{ errors?: unknown[] }>('get_nui_errors', { target, args: { limit: 20 } });
            const list = errs.errors ?? [];
            return ok(assertionResult(list.length === 0, [], list, 'no_nui_errors'));
          }
        }
        return fail(new Error('unreachable'));
      } catch (e) {
        return fail(e);
      }
    },
  );

  // ── domain adapters ──
  server.registerTool(
    'fivem_get_robbery_state',
    {
      title: 'Robbery domain state',
      description: 'Live robbery session (stage, hackResult, bag, estimated, displaysSmashed) + door/vault unlock snapshot from sunset_robbery. Use for Fleeca debugging.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_robbery_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_race_state',
    {
      title: 'Racing domain state',
      description: 'Race Night active flag, player points, lobby membership, active race (phase, checkpoint progress, DNF/finish). From sunset_racing.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_race_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_job_state',
    {
      title: 'Job domain state',
      description: 'Civilian job id/level + active work session (jobId/state/stage) from sunset_jobs.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_job_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_drug_state',
    {
      title: 'Drug pipeline state',
      description: 'Counts of all drug raw/product items (weed/coke/meth) from sunset_inventory via the drugs adapter.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_drug_pipeline_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_wanted_state',
    {
      title: 'Wanted/jail state',
      description: 'Wanted level and jail state from sunset_factions.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_wanted_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_vehicles_db',
    {
      title: 'Owned vehicles (DB read-only)',
      description: 'READ-ONLY vehicle rows owned by the test player character (model, plate, garage, parked coords).',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_vehicle_ownership_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_robbery_db',
    {
      title: 'Robbery runs (DB read-only)',
      description: 'READ-ONLY robbery_runs ledger (status/bag/value/timestamps) + active cooldowns. Verify rewards recorded exactly once per session.',
      inputSchema: { characterId: z.number().optional(), limit: z.number().optional() },
    },
    async ({ characterId, limit }) => {
      try { return ok(await client.call('get_robbery_db_state', { args: { characterId, limit } })); } catch (e) { return fail(e); }
    },
  );
}
