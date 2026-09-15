/**
 * NUI inspection tools (sunset_ui state, panels, messages, callbacks, errors).
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail } from '../protocol.js';

export function registerNuiTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_get_nui_state',
    {
      title: 'NUI runtime state',
      description:
        'sunset_ui runtime state: focus (keyboard/keepInput), current screen, focus owner, open panels, last outbound message, last inbound callback. Requires sv_sunset_nuidebug 1 on the server for the full instrumented view; a fallback focus-only view is always available.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_nui_state', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_nui_focus',
    {
      title: 'NUI focus',
      description: 'Current NUI focus flags and the sunset_ui current screen. Use to diagnose stuck-cursor bugs.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_nui_focus', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_open_panels',
    {
      title: 'Open NUI panels',
      description: 'List of currently open/visible NUI panels known to sunset_ui.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try { return ok(await client.call('get_open_panels', { target: target ?? 'test' })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_nui_history',
    {
      title: 'NUI message/callback history',
      description: 'Recent outbound NUI messages (action names) and inbound NUI callbacks (post names) — the last N of each. Requires sv_sunset_nuidebug 1.',
      inputSchema: { limit: z.number().min(1).max(60).optional(), target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ limit, target }) => {
      try { return ok(await client.call('get_nui_callback_history', { target: target ?? 'test', args: { limit: limit ?? 40 } })); } catch (e) { return fail(e); }
    },
  );

  server.registerTool(
    'fivem_get_nui_errors',
    {
      title: 'NUI JS errors',
      description: 'Recent JavaScript errors reported by the NUI page (nuiError callback). Use to catch app.js/panel crashes invisible in server logs.',
      inputSchema: { limit: z.number().min(1).max(60).optional(), target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ limit, target }) => {
      try { return ok(await client.call('get_nui_errors', { target: target ?? 'test', args: { limit: limit ?? 40 } })); } catch (e) { return fail(e); }
    },
  );
}
