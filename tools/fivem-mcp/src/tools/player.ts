/**
 * Player inspection + control tools.
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail } from '../protocol.js';

export function registerPlayerTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_get_players',
    {
      title: 'List connected players',
      description: 'List all players connected to the FiveM server, with character ids and which one is the registered test player.',
      inputSchema: {},
    },
    async () => {
      try { return ok(await client.call('get_players')); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_player_state',
    {
      title: 'Full player state snapshot',
      description: 'Comprehensive runtime state of the test player (or a specific serverId): coords, heading, health, armour, vehicle, money, character, admin level. Reads through domain owners (sunset_core etc.) — always authoritative.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional().describe('serverId or "test" (default: registered test player)') },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_player_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_player_coords',
    {
      title: 'Player coordinates',
      description: 'Current position and heading of the target player. Use after teleports or to measure distances to objectives.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_player_coords', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_teleport',
    {
      title: 'Teleport player',
      description: 'Teleport the test player to world coordinates (collision preloaded, no fall-through). Use real gameplay coordinates from configs.',
      inputSchema: {
        x: z.number(), y: z.number(), z: z.number(),
        heading: z.number().optional(),
        target: z.union([z.number(), z.string()]).optional(),
      },
    },
    async ({ x, y, z, heading, target }) => {
      try { return ok(await client.call('teleport_player', { target: target ?? 'test', args: { x, y, z, heading } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_set_health',
    {
      title: 'Set test health/armour',
      description: 'Set the test player entity health (0-1000, 100 = default alive) and armour (0-100). Real entity mutation, not fake state.',
      inputSchema: { health: z.number().min(0).max(1000).optional(), armour: z.number().min(0).max(100).optional(), target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ health, armour, target }) => {
      try { return ok(await client.call('set_test_health', { target: target ?? 'test', args: { health: health ?? 200, armour: armour ?? 0 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_vehicle_state',
    {
      title: 'Player vehicle state',
      description: 'State of the vehicle the player is in: netId, model hash, driver flag, speed, fuel, body health, plate, networked status. Use to verify vehicle spawn/networking (e.g. trucker work vehicles).',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_player_vehicle', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_player_inventory',
    {
      title: 'Player inventory',
      description: 'Full inventory rows (slot/item/count/metadata) from sunset_inventory (domain owner). Verify ammo boxes, weapon metadata, loot items.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_player_inventory', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_player_money',
    {
      title: 'Player money',
      description: 'Cash and bank balance from sunset_core (authoritative ledger). Use before/after economy actions to verify exact deltas.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_player_money', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_player_status',
    {
      title: 'Job/faction/wanted/jail/session state',
      description: 'Combined status: civilian job + job session, faction + duty, wanted level, jail state, framework sessions (sunset_sessions), Race Night activity. All read through domain owners.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try {
        const t = target ?? 'test';
        const [job, faction, wanted, jail, session] = await Promise.all([
          client.call('get_player_job', { target: t }).catch(() => null),
          client.call('get_player_faction', { target: t }).catch(() => null),
          client.call('get_player_wanted', { target: t }).catch(() => null),
          client.call('get_player_jail_state', { target: t }).catch(() => null),
          client.call('get_player_session_state', { target: t }).catch(() => null),
        ]);
        return ok({ job, faction, wanted, jail, session });
      } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_invoke_callback',
    {
      title: 'Invoke allowlisted gameplay callback (semantic bypass)',
      description:
        'Call a sunset_core gameplay callback directly from the test client, BYPASSING world interaction. This is a documented semantic bypass, NOT physical input. Only allowlisted status/leave callbacks (racing:status, drugs:status, robbery:doorSync, getInventory, etc.). Use to read domain state or trigger safe transitions deterministically.',
      inputSchema: {
        name: z.string().describe('callback name, must be on the test-agent allowlist'),
        args: z.array(z.unknown()).optional().describe('positional callback args'),
        target: z.union([z.number(), z.string()]).optional(),
      },
    },
    async ({ name, args, target }) => {
      try { return ok(await client.call('invoke_callback', { target: target ?? 'test', args: { name, args: args ?? [] } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_press_control',
    {
      title: 'Press control (SEMANTIC, not physical)',
      description:
        'HONEST LIMITATION: FiveM cannot inject physical control presses. For known interaction events this fires the same server event the E-marker would (documented bypass); otherwise it returns OPERATION_NOT_ALLOWED explaining what to use instead. Never pretends a real key was pressed.',
      inputSchema: {
        control: z.number().describe('GTA control id (38 = E/context)'),
        durationMs: z.number().optional(),
        semanticEvent: z.string().optional().describe('allowlisted server event to fire instead (e.g. sunset:robbery:tryStart)'),
        semanticArg: z.string().optional(),
        target: z.union([z.number(), z.string()]).optional(),
      },
    },
    async ({ control, durationMs, semanticEvent, semanticArg, target }) => {
      try {
        if (semanticEvent) {
          return ok(await client.call('interact_semantic', { target: target ?? 'test', args: { event: semanticEvent, arg: semanticArg } }));
        }
        return ok(await client.call('press_control', { target: target ?? 'test', args: { control, durationMs } }));
      } catch (e) { return fail(e); }
    },
  );
}
