/**
 * World/entity inspection + test vehicle tools.
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail } from '../protocol.js';

const targetSchema = { target: z.union([z.number(), z.string()]).optional() };

export function registerWorldTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_get_nearby_entities',
    {
      title: 'Scan nearby entities',
      description:
        'Entity scan around the target player: handle, netId, model hash, type (ped/vehicle/object), coords, heading, collision, frozen, visible, networked, distance. Sorted by distance, capped at 200. Use to find vault doors, props, markers.',
      inputSchema: {
        radius: z.number().min(1).max(150).optional().describe('scan radius in meters (max 150)'),
        kind: z.enum(['all', 'objects', 'vehicles', 'peds']).optional(),
        ...targetSchema,
      },
    },
    async ({ radius, kind, target }) => {
      try { return ok(await client.call('get_nearby_entities', { target: target ?? 'test', args: { radius: radius ?? 25, kind: kind ?? 'all' } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_nearby_objects',
    {
      title: 'Scan nearby objects/props',
      description: 'Object-only scan around the player (props, doors, vault doors). Same fields as get_nearby_entities.',
      inputSchema: { radius: z.number().min(1).max(150).optional(), ...targetSchema },
    },
    async ({ radius, target }) => {
      try { return ok(await client.call('get_nearby_objects', { target: target ?? 'test', args: { radius: radius ?? 25 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_nearby_vehicles',
    {
      title: 'Scan nearby vehicles',
      description: 'Vehicle-only scan around the player.',
      inputSchema: { radius: z.number().min(1).max(150).optional(), ...targetSchema },
    },
    async ({ radius, target }) => {
      try { return ok(await client.call('get_nearby_vehicles', { target: target ?? 'test', args: { radius: radius ?? 25 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_inspect_entity',
    {
      title: 'Inspect one entity',
      description:
        'Detailed inspection of an entity by netId: model hash, coords, heading, collision enabled, frozen, visible, networked, attachedTo, health, distance from player, state-bag keys (test-spawn tag, protected-vehicle tag). Pass modelHint (a model name) to also get hashMatchesHint.',
      inputSchema: { netId: z.number(), modelName: z.string().optional(), ...targetSchema },
    },
    async ({ netId, modelName, target }) => {
      try { return ok(await client.call('inspect_entity', { target: target ?? 'test', args: { netId, modelName } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_find_object_by_model',
    {
      title: 'Find object by model name',
      description:
        'Find the closest object of a model name near coords (default: player). Returns full entity inspection or found=false with the searched hash. Essential for verifying vault/door props (e.g. v_ilev_gb_vauldoor) exist where configs claim.',
      inputSchema: {
        name: z.string().describe('model name, e.g. v_ilev_gb_vauldoor'),
        x: z.number().optional(), y: z.number().optional(), z: z.number().optional(),
        radius: z.number().optional(),
        ...targetSchema,
      },
    },
    async ({ name, x, y, z, radius, target }) => {
      try {
        const coords = (x !== undefined && y !== undefined && z !== undefined) ? { x, y, z } : undefined;
        return ok(await client.call('find_object', { target: target ?? 'test', args: { name, coords, radius: radius ?? 10 } }));
      } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_hash_model',
    {
      title: 'Hash a model name',
      description: 'Compute the joaat hash of a model/anim name (server-side, no client needed).',
      inputSchema: { name: z.string() },
    },
    async ({ name }) => {
      try { return ok(await client.call('hash_model', { args: { name } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_spawn_test_vehicle',
    {
      title: 'Spawn tagged test vehicle',
      description:
        'Spawn a vehicle next to the player, TAGGED as test-spawned (state bag) so it can later be deleted and is never confused with production entities. Optionally warp the player in as driver.',
      inputSchema: { model: z.string(), warp: z.boolean().optional(), ...targetSchema },
    },
    async ({ model, warp, target }) => {
      try { return ok(await client.call('spawn_test_vehicle', { target: target ?? 'test', args: { model, warp: warp ?? false } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_delete_test_entity',
    {
      title: 'Delete tagged test entity',
      description: 'Delete an entity BY NETID only if it carries the test-spawned tag. Refuses production entities with OPERATION_NOT_ALLOWED.',
      inputSchema: { netId: z.number(), ...targetSchema },
    },
    async ({ netId, target }) => {
      try { return ok(await client.call('delete_test_entity', { target: target ?? 'test', args: { netId } })); } catch (e) { return fail(e); }
    },
  );
}
