/**
 * Screenshot tool — returns the image directly as MCP image content.
 */
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import type { TestAgentClient } from '../client.js';
import { ok, fail, imageResult } from '../protocol.js';

export function registerScreenshotTools(server: McpServer, client: TestAgentClient): void {
  server.registerTool(
    'fivem_take_screenshot',
    {
      title: 'Take a client screenshot',
      description:
        'Capture the test client screen via screenshot-basic and return the JPEG directly as MCP image content. Visually verify HUD, panels, markers, doors, vehicles, layouts. Fails with SCREENSHOT_FAILED if screenshot_basic is not installed.',
      inputSchema: { target: z.union([z.number(), z.string()]).optional() },
    },
    async ({ target }) => {
      try {
        const res = await client.call<{ requestId: string; bytes?: number; mime?: string }>(
          'take_screenshot',
          { target: target ?? 'test', args: {} },
        );
        const shot = await client.screenshot(res.requestId);
        return imageResult(
          JSON.stringify({ ok: true, result: { requestId: res.requestId, bytes: shot.bytes.length, mime: shot.mime } }, null, 2),
          shot.bytes.toString('base64'),
          shot.mime,
        );
      } catch (e) {
        return fail(e);
      }
    },
  );
}
