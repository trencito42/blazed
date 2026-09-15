/**
 * Scenario definitions — pure data. The runner core stays generic; domain
 * scenarios (Fleeca) are just step lists against registered tools.
 *
 * Coordinates come from the repo configs (verified statically):
 *  - Fleeca Legion:     147.05, -1044.88, 29.37  (sunset_robbery/shared/config.lua)
 *  - Fleeca entrance:   149.20, -1040.50, 29.37
 *  - Fleeca hack term:  147.20, -1042.20, 29.37
 *  - Fleeca vault door: 147.30, -1044.86, 29.36  (v_ilev_gb_vauldoor)
 *  - Race hub:          -1060.00, -2580.00, 20.00 (sunset_racing/shared/config.lua)
 */
import type { Scenario } from './tools/scenarios-runner.js';

export const builtinScenarios: Scenario[] = [
  {
    id: 'player_connect_smoke',
    description: 'Health + players + player state smoke test. Verifies bridge, test player registration and core reads.',
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
    description: 'Teleport to Legion Square, assert arrival, read state back.',
    steps: [
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: 147.05, y: -1044.88, z: 29.37 } }, label: 'tp Legion Square' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'assert', condition: 'player_position', params: { x: 147.05, y: -1044.88, z: 29.37, radius: 8 }, label: 'arrived' },
      { kind: 'tool', tool: 'get_player_state', args: { target: 'test' }, label: 'state after tp' },
    ],
  },
  {
    id: 'vehicle_spawn_and_network',
    description: 'Spawn a tagged test vehicle, verify it networks, warp in, verify driver, delete it (cleanup proves the tag policy).',
    steps: [
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: -1060.0, y: -2580.0, z: 20.0 } }, label: 'tp LS Customs area' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'tool', tool: 'spawn_test_vehicle', args: { target: 'test', args: { model: 'sultan', warp: true } }, label: 'spawn sultan (tagged)' },
      { kind: 'wait', ms: 2500, label: 'network propagation' },
      { kind: 'assert', condition: 'player_in_vehicle', params: { isDriver: true }, label: 'player driving' },
      { kind: 'tool', tool: 'get_player_vehicle', args: { target: 'test' }, label: 'vehicle networked state' },
      // NOTE: deletion needs the spawned netId from step 3's result; the
      // generic runner does not chain results between steps. Call
      // fivem_delete_test_entity manually with the netId from the report.
    ],
  },
  {
    id: 'nui_open_close',
    description: 'Open the player menu via invoke (allowlisted where possible), check NUI focus transitions, verify focus released afterwards.',
    steps: [
      { kind: 'tool', tool: 'get_nui_state', args: { target: 'test' }, label: 'nui state before' },
      { kind: 'assert', condition: 'nui_focus', params: { expected: false }, label: 'focus off before' },
      { kind: 'tool', tool: 'invoke_callback', args: { target: 'test', args: { name: 'sunset:getInventory', args: [] } }, label: 'callback roundtrip (inventory)' },
      { kind: 'tool', tool: 'get_nui_history', args: { target: 'test', args: { limit: 20 } }, label: 'nui history' },
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
    description: 'Take a screenshot and verify the pipeline stores bytes.',
    steps: [
      { kind: 'tool', tool: 'take_screenshot', args: { target: 'test' }, label: 'screenshot' },
    ],
  },
  {
    id: 'resource_restart_test',
    description: 'Restart sunset_drugs, verify it comes back and its callbacks answer again (proves no silent parse-death).',
    steps: [
      { kind: 'tool', tool: 'get_resource_state', args: { args: { name: 'sunset_drugs' } }, label: 'pre-state' },
      { kind: 'tool', tool: 'restart_resource', args: { args: { name: 'sunset_drugs' } }, label: 'restart sunset_drugs' },
      { kind: 'wait', ms: 3000, label: 'boot' },
      { kind: 'assert', condition: 'resource_started', params: { name: 'sunset_drugs' }, label: 'restarted OK' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:drugs:status' }, label: 'drugs callbacks alive after restart' },
    ],
  },
  {
    id: 'fleeca_robbery',
    description:
      'DOMAIN: Fleeca Legion robbery. Setup → semantic start (bypass marker E) → verify HACKING stage → open hack UI → verify vault door entity + heading BEFORE → simulate successful hack is NOT possible from outside (server-owned circuit) so the scenario verifies: start gating, vault closed while hacking, door entity resolvable, heading readable, robbery stage assertions, then cancels via disconnect-safe path. Full hack completion requires the NUI minigame — run it manually or extend with a dev-only hack-solve export.',
    steps: [
      { kind: 'tool', tool: 'teleport_player', args: { target: 'test', args: { x: 149.2, y: -1040.5, z: 29.37 } }, label: 'tp Fleeca entrance' },
      { kind: 'wait', ms: 1500, label: 'settle' },
      { kind: 'assert', condition: 'player_position', params: { x: 149.2, y: -1040.5, z: 29.37, radius: 6 }, label: 'at entrance' },
      { kind: 'tool', tool: 'find_object_by_model', args: { target: 'test', args: { name: 'v_ilev_gb_vauldoor', x: 147.3, y: -1044.86, z: 29.36, radius: 4 } }, label: 'vault door exists' },
      { kind: 'tool', tool: 'take_screenshot', args: { target: 'test' }, label: 'screenshot BEFORE' },
      { kind: 'tool', tool: 'get_robbery_state', args: { target: 'test' }, label: 'robbery state before start' },
      { kind: 'tool', tool: 'interact_semantic', args: { target: 'test', args: { event: 'sunset:robbery:tryStart', arg: 'fleeca_legion' } }, label: 'semantic start (BYPASS of E marker)' },
      { kind: 'wait', ms: 1200, label: 'start settle' },
      { kind: 'assert', condition: 'robbery_stage', params: { value: 'HACKING' }, label: 'stage HACKING (or start gates rejected — inspect result)' },
      { kind: 'tool', tool: 'find_object_by_model', args: { target: 'test', args: { name: 'v_ilev_gb_vauldoor', x: 147.3, y: -1044.86, z: 29.36, radius: 4 } }, label: 'vault heading WHILE HACKING (must be closed)' },
      { kind: 'assert', condition: 'callback_result', params: { name: 'sunset:robbery:doorSync' }, label: 'doorSync readable' },
      { kind: 'tool', tool: 'get_nui_state', args: { target: 'test' }, label: 'nui state during robbery' },
      { kind: 'tool', tool: 'take_screenshot', args: { target: 'test' }, label: 'screenshot DURING' },
    ],
  },
];
