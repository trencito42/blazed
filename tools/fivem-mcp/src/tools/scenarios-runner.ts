/**
 * Scenario runner: deterministic multi-step test flows defined as data.
 * Scenarios are generic step lists — NO domain logic hardcoded here beyond
 * the declared scenario definitions at the bottom (which are data).
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail } from '../protocol.js';
import { builtinScenarios } from '../scenarios.js';

type Step =
  | { kind: 'tool'; tool: string; args?: Record<string, unknown>; label?: string }
  | { kind: 'wait'; ms: number; label?: string }
  | { kind: 'assert'; condition: string; params: Record<string, unknown>; label?: string };

export interface Scenario {
  id: string;
  description: string;
  steps: Step[];
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function runScenario(client: TestAgentClient, scenario: Scenario) {
  const report: Array<{
    step: number;
    label: string;
    kind: string;
    ok: boolean;
    durationMs: number;
    result?: unknown;
    error?: { code: string; message: string };
  }> = [];

  for (let i = 0; i < scenario.steps.length; i++) {
    const step = scenario.steps[i];
    const label = step.label ?? `${step.kind}:${i}`;
    const t0 = Date.now();
    try {
      if (step.kind === 'wait') {
        await sleep(step.ms);
        report.push({ step: i, label, kind: 'wait', ok: true, durationMs: Date.now() - t0 });
      } else if (step.kind === 'tool') {
        const res = await client.call(step.tool, step.args ?? {});
        report.push({ step: i, label, kind: `tool:${step.tool}`, ok: true, durationMs: Date.now() - t0, result: res });
      } else if (step.kind === 'assert') {
        // Assertions reuse the fivem_assert bridge semantics via direct calls.
        const res = await runAssert(client, step.condition, step.params);
        report.push({ step: i, label, kind: `assert:${step.condition}`, ok: res.passed === true, durationMs: Date.now() - t0, result: res });
        if (res.passed !== true) {
          // Fail-fast: a broken assertion means later steps are meaningless.
          break;
        }
      }
    } catch (e) {
      const err = e instanceof Error ? e : new Error(String(e));
      const code = 'code' in err ? String((err as { code?: string }).code ?? 'INTERNAL') : 'INTERNAL';
      report.push({ step: i, label, kind: step.kind, ok: false, durationMs: Date.now() - t0, error: { code, message: err.message } });
      break; // fail-fast
    }
  }

  const passed = report.every((r) => r.ok);
  return { scenario: scenario.id, passed, steps: report };
}

async function runAssert(client: TestAgentClient, condition: string, params: Record<string, unknown>) {
  const target = params.target ?? 'test';
  switch (condition) {
    case 'resource_started': {
      const r = await client.call<{ state: string }>('get_resource_state', { args: { name: params.name } });
      return { passed: r.state === 'started', expected: 'started', actual: r.state };
    }
    case 'player_position': {
      const c = await client.call<{ x: number; y: number; z: number }>('get_player_coords', { target });
      const d = Math.hypot(c.x - Number(params.x), c.y - Number(params.y), (c.z ?? 0) - Number(params.z ?? 0));
      return { passed: d <= Number(params.radius ?? 5), expected: { within: params.radius ?? 5 }, actual: { distance: Number(d.toFixed(2)) } };
    }
    case 'player_in_vehicle': {
      const v = await client.call<{ inVehicle?: boolean; isDriver?: boolean }>('get_player_vehicle', { target });
      return { passed: !!v.inVehicle && (params.isDriver === undefined || v.isDriver === params.isDriver), expected: { inVehicle: true, isDriver: params.isDriver }, actual: v };
    }
    case 'nui_focus': {
      const n = await client.call<{ focus?: { keyboard?: boolean } }>('get_nui_state', { target });
      const want = params.expected !== false;
      return { passed: (n.focus?.keyboard ?? false) === want, expected: want, actual: n.focus ?? null };
    }
    case 'no_nui_errors': {
      const errs = await client.call<{ errors?: unknown[] }>('get_nui_errors', { target, args: { limit: 20 } });
      const list = errs.errors ?? [];
      return { passed: list.length === 0, expected: [], actual: list };
    }
    case 'robbery_stage': {
      const rb = await client.call<{ live?: { stage?: string } | null }>('get_robbery_state', { target });
      return { passed: (rb.live?.stage ?? null) === (params.value ?? null), expected: params.value ?? null, actual: rb.live?.stage ?? null };
    }
    case 'race_phase': {
      const rs = await client.call<{ activeRace?: { phase?: string } | null }>('get_race_state', { target });
      return { passed: (rs.activeRace?.phase ?? null) === (params.value ?? null), expected: params.value ?? null, actual: rs.activeRace?.phase ?? null };
    }
    case 'callback_result': {
      const res = await client.call<{ result?: unknown; error?: unknown }>('invoke_callback', { target, args: { name: params.name, args: params.args ?? [] } });
      return { passed: res.result !== null && res.result !== undefined, expected: 'non-null result', actual: res };
    }
    default:
      throw new Error(`unknown assert condition: ${condition}`);
  }
}

export function registerScenarioTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_list_scenarios',
    {
      title: 'List test scenarios',
      description: 'List the built-in smoke scenarios and domain scenarios available to fivem_run_scenario.',
      inputSchema: {},
    },
    async () => {
      return ok(builtinScenarios.map((s) => ({ id: s.id, description: s.description, steps: s.steps.length })));
    },
  );

  server.registerTool(
    'fivem_run_scenario',
    {
      title: 'Run a test scenario',
      description:
        'Execute a predefined scenario (setup → actions → observations → assertions → cleanup) against the live runtime. Returns a per-step report with timings and fail-fast on assertion/error. Screenshots inside scenarios return requestIds (fetch bytes with the screenshot download if needed).',
      inputSchema: {
        id: z.string().describe('scenario id from fivem_list_scenarios'),
      },
    },
    async ({ id }) => {
      const scenario = builtinScenarios.find((s) => s.id === id);
      if (!scenario) {
        return fail({ code: 'INVALID_ARGUMENT', message: `unknown scenario "${id}" — call fivem_list_scenarios`, retryable: false });
      }
      try {
        return ok(await runScenario(client, scenario));
      } catch (e) {
        return fail(e);
      }
    },
  );
}
