# sunset_test_agent — DEV-ONLY runtime testing bridge

Lets MCP-compatible AI agents (Claude Code etc.) inspect and test the LIVE
FiveM runtime through `tools/fivem-mcp`. Full docs: `docs/testing/FIVEM_MCP.md`.

## Security model (read first)

- **Kill switch**: does nothing unless `setr sunset_test_agent_enabled true`.
- **Bearer token**: every HTTP call needs `Authorization: Bearer <token>` matching
  `set sunset_test_agent_token <random>` (constant-time compare). No token configured = bridge locked.
- **Admin gate**: in-game `/testagent register` requires `sunset_admin` level ≥ 5 (configurable).
- **No eval, no Lua execution, no raw SQL writes, no arbitrary events.** Every tool is an
  explicit allowlisted function. Callbacks invoked via `invoke_callback` come from a fixed
  allowlist (status reads + safe leaves). Semantic interactions fire only allowlisted server events.
- **Entity deletion** refuses anything not tagged test-spawned.
- **Resource control** only touches `sunset_*`, never protected infra (core/sessions/oxmysql/itself).
- Screenshots flow client → HTTP upload (auth = server-issued **one-shot requestId**, NOT the bearer token) → in-memory store (120s TTL, entry+byte bounded) → MCP download (bearer-authed).
  The master token is never handed to the game client. Nothing is written to disk on the server.

## Enable on a DEV server (never production)

```cfg
# server.cfg (dev box only)
ensure sunset_test_agent
setr sunset_test_agent_enabled true
set sunset_test_agent_token CHANGE_ME_RANDOM_64_CHARS
# optional: full NUI instrumentation
setr sv_sunset_nuidebug 1
# optional: verbose bridge logs
setr sv_sunset_testagent_debug 1
```

screenshot_basic must be installed separately (external resource, not vendored):
https://github.com/citizenfx/screenshot-basic — drop into `resources/`, the agent
starts it automatically when enabled. Without it, `take_screenshot` fails with
`SCREENSHOT_FAILED`; everything else works.

## In-game

```
/testagent register    — become THE test player (admin 5+)
/testagent status      — show kill switch/token/test player
/testagent allow <license>  — restrict registration to allowlisted licenses
/testagent debug on|off
/testagent logs [n]
/testshot              — quick screenshot (prints requestId)
```

## MCP side

```powershell
cd tools/fivem-mcp
npm install; npm run build
$env:FIVEM_TEST_TOKEN = "<same token>"
npm start
```

Claude Code: see `docs/testing/FIVEM_MCP.md` § "Connecting Claude Code".
