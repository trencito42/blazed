/**
 * Scenario definitions — pure data. The runner core stays generic; domain
 * scenarios (Fleeca) are just step lists against registered BRIDGE tools
 * (the names in TestAgentTools on the server, e.g. find_object — NOT the
 * MCP-facing names like fivem_find_object_by_model).
 *
 * HONESTY RULE: descriptions state exactly what is and is not exercised.
 * No scenario may imply physical key input — FiveM cannot inject it;
 * interaction steps are semantic bypasses and say so.
 *
 * Coordinates come from the repo configs (verified statically):
 *  - Fleeca Legion:     147.05, -1044.88, 29.37  (sunset_robbery/shared/config.lua)
 *  - Fleeca entrance:   149.20, -1040.50, 29.37
 *  - Fleeca vault door: 147.30, -1044.86, 29.36  (v_ilev_gb_vauldoor)
 *  - Race hub:          -1060.00, -2580.00, 20.00 (sunset_racing/shared/config.lua)
 */
import type { Scenario } from './tools/scenarios-runner.js';

export const builtinScenarios: Scenario[] = [
  {
    id: 'player_connect_smoke',
    description: 'Bridge health + player list + test player state + core resources started. No world interaction.',
    steps: [
      { kind: 'tool', tool: 'health', label: 'bridge health' },
      { kind: 'tool', tool: 'get_players', label: 'player list' },
      { kind: 'tool', tool: 'get_player_state', args: { target: 'test' }, label: 'test player state' },
      { kind: 'assert', condition: 'resource_started', params: { name: 'sunset_core' }, label: 'sunset_core started' },
      { kind: 'assert', condition: 'resource_started', params: { name: 'sunset_ui' }, label: 'sunset_ui started' },
    ],
  },
  {
    id: 'teleport_and_state',
    description: 'Teleport to Legion Square, assert arrival within 8m, read full state back.',
    steps: [
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: 147.05, y: -1044.88, z: 29.37 } }, label: 'tp Legion Square' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'assert', condition: 'player_position', params: { x: 147.05, y: -1044.88, z: 29.37, radius: 8 }, label: 'arrived' },
      { kind: 'tool', tool: 'get_player_state', args: { target: 'test' }, label: 'state after tp' },
    ],
  },
  {
    id: 'vehicle_spawn_and_network',
    description:
      'Spawn a TAGGED test vehicle (sultan), wait for network propagation, assert the player is driver, read vehicle state (networked flag OBSERVED, not inferred). Deletion needs the spawned netId: the generic runner does not chain results, so the cleanup step deletes any tagged entity reported in the step results — otherwise call fivem_delete_test_entity manually with the netId. Agent-stop/disconnect cleanup also reclaims it.',
    steps: [
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: -1060.0, y: -2580.0, z: 20.0 } }, label: 'tp LS Customs area' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'tool', tool: 'spawn_test_vehicle', args: { target: 'test', args: { model: 'sultan', warp: true } }, label: 'spawn sultan (tagged)' },
      { kind: 'wait', ms: 2500, label: 'network propagation' },
      { kind: 'assert', condition: 'player_in_vehicle', params: { isDriver: true }, label: 'player driving spawned vehicle' },
      { kind: 'tool', tool: 'get_player_vehicle', args: { target: 'test' }, label: 'vehicle state (observe networked=true)' },
      { kind: 'assert', condition: 'vehicle_networked', params: {}, label: 'vehicle actually networked' },
    ],
    cleanup: [
      { kind: 'tool', tool: 'cleanup_test_entities', args: { target: 'test' }, label: 'delete all tagged entities spawned for the test player' },
    ],
  },
  {
    id: 'nui_inspection_smoke',
    description:
      'NUI INSPECTION ONLY (renamed from nui_open_close — this does NOT open/close any panel, because opening panels requires input injection which FiveM does not support): reads focus state before, does an allowlisted callback roundtrip, reads message/callback history, asserts no JS errors.',
    steps: [
      { kind: 'tool', tool: 'get_nui_state', args: { target: 'test' }, label: 'nui state before' },
      { kind: 'assert', condition: 'nui_focus', params: { expected: false }, label: 'focus off before' },
      { kind: 'tool', tool: 'invoke_callback', args: { target: 'test', args: { name: 'sunset:getInventory', args: [] } }, label: 'callback roundtrip (inventory)' },
      { kind: 'tool', tool: 'get_nui_callback_history', args: { target: 'test', args: { limit: 20 } }, label: 'nui history' },
      { kind: 'assert', condition: 'no_nui_errors', params: {}, label: 'no js errors' },
    ],
  },
  {
    id: 'callback_roundtrip',
    description: 'Invoke every allowlisted status callback and assert non-null structured results.',
    steps: [
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:racing:status' }, label: 'racing status' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:drugs:status' }, label: 'drugs status' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:events:status' }, label: 'events status' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:robbery:doorSync' }, label: 'robbery doorSync' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:getInventory' }, label: 'inventory' },
    ],
  },
  {
    id: 'screenshot_test',
    description: 'Take a screenshot through the full pipeline (client capture → base64 → authed upload → store). FAILS with SCREENSHOT_FAILED if screenshot_basic is not installed — that is an honest failure, not a skip.',
    steps: [
      { kind: 'tool', tool: 'take_screenshot', args: { target: 'test' }, label: 'screenshot capture+store' },
    ],
  },
  {
    id: 'resource_restart_test',
    description: 'Restart sunset_drugs, WAIT for the actual started state, then prove its callbacks answer again (no silent parse-death).',
    steps: [
      { kind: 'tool', tool: 'get_resource_state', args: { args: { name: 'sunset_drugs' } }, label: 'pre-state' },
      { kind: 'tool', tool: 'restart_resource', args: { args: { name: 'sunset_drugs' } }, label: 'restart sunset_drugs (immediateState not final by design)' },
      { kind: 'assert', condition: 'resource_started', params: { name: 'sunset_drugs', timeoutMs: 10000 }, label: 'wait for actually-started' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:drugs:status' }, label: 'drugs callbacks alive after restart' },
    ],
  },
  {
    id: 'mcp_bridge_self_test',
    description:
      'Full bridge self-test: health → coords → teleport+assert → NUI state → inventory+money reads → spawn tagged vehicle → networked assert → client+server logs → protected-resource restart REJECTION (assert OPERATION_NOT_ALLOWED) → unknown tool rejection. Screenshot step is included but its failure (screenshot_basic missing) does not fail the scenario. Cleanup deletes tagged entities even on failure.',
    steps: [
      { kind: 'tool', tool: 'health', label: 'health (expect testPlayer.connected=true)' },
      { kind: 'tool', tool: 'get_player_coords', args: { target: 'test' }, label: 'coords readable' },
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: -1060.0, y: -2580.0, z: 20.0 } }, label: 'teleport LS Customs' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'assert', condition: 'player_position', params: { x: -1060.0, y: -2580.0, z: 20.0, radius: 8 }, label: 'arrived' },
      { kind: 'tool', tool: 'get_nui_state', args: { target: 'test' }, label: 'nui state' },
      { kind: 'tool', tool: 'get_player_inventory', args: { target: 'test' }, label: 'inventory read' },
      { kind: 'tool', tool: 'get_player_money', args: { target: 'test' }, label: 'money read' },
      { kind: 'tool', tool: 'spawn_test_vehicle', args: { target: 'test', args: { model: 'sultan', warp: false } }, label: 'spawn tagged vehicle' },
      { kind: 'wait', ms: 2500, label: 'propagation' },
      { kind: 'tool', tool: 'get_client_logs', args: { target: 'test', args: { limit: 50 } }, label: 'client logs readable' },
      { kind: 'tool', tool: 'get_server_logs', args: { args: { limit: 50 } }, label: 'server logs readable' },
      { kind: 'assert', condition: 'tool_rejected', params: { tool: 'restart_resource', args: { name: 'sunset_core' }, expectCode: 'OPERATION_NOT_ALLOWED' }, label: 'protected resource restart REJECTED' },
      { kind: 'assert', condition: 'tool_rejected', params: { tool: 'nonexistent_tool', args: {}, expectCode: 'INVALID_ARGUMENT' }, label: 'unknown tool REJECTED with INVALID_ARGUMENT' },
      { kind: 'assert', condition: 'no_nui_errors', params: {}, label: 'no NUI js errors accumulated' },
    ],
    cleanup: [
      { kind: 'tool', tool: 'cleanup_test_entities', args: { target: 'test' }, label: 'delete tagged entities' },
    ],
  },
  {
    id: 'fleeca_robbery',
    description:
      'DOMAIN: Fleeca Legion. LIMITATIONS STATED: (1) start uses interact_semantic = documented BYPASS of the E marker (physical input impossible); (2) the hack minigame is server-owned and NOT auto-completed here — the scenario verifies gating, vault-closed-while-hacking, prop resolution and heading, not a full heist; (3) screenshots fail if screenshot_basic is missing. Answers the vault-debug questions: prop exists? coords/heading before vs during? doorSync state? robbery stage transitions?',
    steps: [
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: 149.2, y: -1040.5, z: 29.37 } }, label: 'tp Fleeca entrance' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'assert', condition: 'player_position', params: { x: 149.2, y: -1040.5, z: 29.37, radius: 6 }, label: 'at entrance' },
      { kind: 'tool', tool: 'find_object', args: { target: 'test', args: { name: 'v_ilev_gb_vauldoor', coords: { x: 147.3, y: -1044.86, z: 29.36 }, radius: 4 } }, label: 'vault door prop resolvable' },
      { kind: 'tool', tool: 'get_robbery_state', args: { target: 'test' }, label: 'robbery state before start' },
      { kind: 'tool', tool: 'interact_semantic', args: { target: 'test', args: { event: 'sunset:robbery:tryStart', arg: 'fleeca_legion' } }, label: 'semantic start (BYPASS — not a real E press)' },
      { kind: 'wait', ms: 1200, label: 'start settle' },
      { kind: 'assert', condition: 'robbery_stage', params: { value: 'HACKING' }, label: 'stage HACKING (gates may legitimately reject — read result)' },
      { kind: 'tool', tool: 'find_object', args: { target: 'test', args: { name: 'v_ilev_gb_vauldoor', coords: { x: 147.3, y: -1044.86, z: 29.36 }, radius: 4 } }, label: 'vault heading WHILE HACKING (must equal closed baseline)' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:robbery:doorSync' }, label: 'doorSync readable (vault must be locked while hacking)' },
      { kind: 'tool', tool: 'get_nui_state', args: { target: 'test' }, label: 'nui state during robbery' },
      { kind: 'tool', tool: 'get_robbery_state', args: { target: 'test' }, label: 'robbery state during HACKING' },
    ],
  },
];
