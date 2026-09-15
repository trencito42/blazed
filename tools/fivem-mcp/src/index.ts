/**
 * fivem-mcp — MCP server bridging Claude Code to the Blaze/SunsetMP
 * FiveM runtime test agent (sunset_test_agent resource).
 *
 * Transport: stdio (standard for Claude Code MCP servers).
 * Bridge: HTTP JSON → FXServer game port /testagent (bearer auth).
 *
 * Env:
 *   FIVEM_TEST_HOST   (default 127.0.0.1)
 *   FIVEM_TEST_PORT   (default 30120)
 *   FIVEM_TEST_URL    (overrides host+port, e.g. via SSH tunnel)
 *   FIVEM_TEST_TOKEN  (required — same value as the server convar)
 *   FIVEM_TEST_TIMEOUT_MS (default 20000)
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { TestAgentClient } from './client.js';
import { registerCoreTools } from './tools/assertions.js';
import { registerPlayerTools } from './tools/player.js';
import { registerWorldTools } from './tools/world.js';
import { registerNuiTools } from './tools/nui.js';
import { registerScreenshotTools } from './tools/screenshots.js';
import { registerResourceTools } from './tools/resources.js';
import { registerScenarioTools } from './tools/scenarios-runner.js';

async function main(): Promise<void> {
  const client = new TestAgentClient();

  const server = new McpServer({
    name: 'fivem-test-bridge',
    version: '1.0.0',
  });

  registerCoreTools(server, client);       // health, wait_for, assert, domains
  registerPlayerTools(server, client);
  registerWorldTools(server, client);
  registerNuiTools(server, client);
  registerScreenshotTools(server, client);
  registerResourceTools(server, client);
  registerScenarioTools(server, client);

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Diagnostics to stderr ONLY (stdout is the MCP channel — never pollute it).
  console.error(`[fivem-mcp] ready. bridge=${process.env.FIVEM_TEST_URL ?? `http://${process.env.FIVEM_TEST_HOST ?? '127.0.0.1'}:${process.env.FIVEM_TEST_PORT ?? '30120'}/testagent`} token=${client.isConfigured ? 'set' : 'MISSING (FIVEM_TEST_TOKEN)'}`);
}

main().catch((e) => {
  console.error('[fivem-mcp] fatal startup error:', e);
  process.exit(1);
});
