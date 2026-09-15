/**
 * Resource lifecycle tools + logs.
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail } from '../protocol.js';

export function registerResourceTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_get_resource_state',
    {
      title: 'Resource state',
      description: 'Get the state of any resource (started/stopped/missing).',
      inputSchema: { name: z.string() },
    },
    async ({ name }) => {
      try { return ok(await client.call('get_resource_state', { args: { name } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_list_resources',
    {
      title: 'List sunset resources',
      description: 'List every sunset_* resource and its state.',
      inputSchema: {},
    },
    async () => {
      try { return ok(await client.call('list_sunset_resources')); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_restart_resource',
    {
      title: 'Restart a sunset_* resource',
      description:
        'Restart a resource after a code fix. GUARDED: only sunset_* resources; protected infra (sunset_core, sunset_sessions, oxmysql, sunset_test_agent itself) is refused with OPERATION_NOT_ALLOWED. After restart, re-run tests to verify.',
      inputSchema: { name: z.string() },
    },
    async ({ name }) => {
      try { return ok(await client.call('restart_resource', { args: { name } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_start_resource',
    {
      title: 'Start a sunset_* resource',
      description: 'Start a stopped sunset_* resource (same guards as restart).',
      inputSchema: { name: z.string() },
    },
    async ({ name }) => {
      try { return ok(await client.call('start_resource', { args: { name } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_stop_resource',
    {
      title: 'Stop a sunset_* resource',
      description: 'Stop a running sunset_* resource (same guards as restart). Use for testing resource-stop cleanup paths.',
      inputSchema: { name: z.string() },
    },
    async ({ name }) => {
      try { return ok(await client.call('stop_resource', { args: { name } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_server_logs',
    {
      title: 'Test-agent server logs',
      description: 'Structured server-side test-agent log buffer (invocations with requestId/tool/duration/outcome, events, errors). Not the raw FXServer stdout.',
      inputSchema: { limit: z.number().min(1).max(600).optional() },
    },
    async ({ limit }) => {
      try { return ok(await client.call('get_server_logs', { args: { limit: limit ?? 200 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_recent_errors',
    {
      title: 'Recent server errors',
      description: 'Only error entries and failed tool invocations from the server log buffer.',
      inputSchema: { limit: z.number().min(1).max(300).optional() },
    },
    async ({ limit }) => {
      try { return ok(await client.call('get_recent_errors', { args: { limit: limit ?? 100 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_client_logs',
    {
      title: 'Test client logs',
      description: 'Structured ring buffer from the test client: test actions, RPC calls, errors (400 entries max).',
      inputSchema: { limit: z.number().min(1).max(400).optional(), target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ limit, target }) => {
      try { return ok(await client.call('get_client_logs', { target: target ?? 'test', args: { limit: limit ?? 200 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_clear_client_logs',
    {
      title: 'Clear client logs',
      description: 'Clear the test client log ring buffer (do this at scenario start for clean observations).',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('clear_client_logs', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );
}
