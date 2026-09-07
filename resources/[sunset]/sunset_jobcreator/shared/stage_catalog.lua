SunsetJobCreator = SunsetJobCreator or {}

--- Metadata for admin stage editor (no executable logic).
SunsetJobCreator.StageCatalog = {
    { type = 'goto_zone', category = 'world', label = 'Go to location', fields = { 'location', 'locationVar', 'locationField', 'message', 'onSuccess', 'onFailure' } },
    { type = 'zone_interact', category = 'interaction', label = 'Zone interact (E)', fields = { 'location', 'locationVar', 'locationField', 'message', 'actions', 'onSuccess', 'onFailure' } },
    { type = 'pick_random', category = 'logic', label = 'Pick random from pool', fields = { 'pool', 'storeAs', 'onSuccess' } },
    { type = 'branch', category = 'logic', label = 'Branch (if/else)', fields = { 'condition', 'ifTrue', 'ifFalse' } },
    { type = 'set_variable', category = 'logic', label = 'Set variables', fields = { 'actions', 'var', 'value', 'onSuccess' } },
    { type = 'scale_from_level', category = 'logic', label = 'Scale var from job level', fields = { 'var', 'resetVar', 'base', 'perLevel', 'max', 'onSuccess' } },
    { type = 'wait', category = 'gameplay', label = 'Wait (seconds)', fields = { 'seconds', 'onSuccess' } },
    { type = 'progress', category = 'gameplay', label = 'Progress bar', fields = { 'label', 'durationMs', 'location', 'locationVar', 'message', 'onSuccess', 'onFailure' } },
    { type = 'skill_check', category = 'gameplay', label = 'Skill check minigame', fields = { 'windowMs', 'location', 'locationVar', 'message', 'onSuccess', 'onFailure' } },
    { type = 'spawn_vehicle', category = 'vehicles', label = 'Spawn job vehicle', fields = { 'model', 'location', 'locationVar', 'warp', 'storeAs', 'onSuccess', 'onFailure' } },
    { type = 'delete_vehicle', category = 'vehicles', label = 'Delete job vehicle', fields = { 'vehicleVar', 'onSuccess' } },
    { type = 'attach_trailer', category = 'vehicles', label = 'Attach trailer', fields = { 'vehicleVar', 'trailerModel', 'location', 'locationVar', 'onSuccess', 'onFailure' } },
    { type = 'enter_vehicle', category = 'vehicles', label = 'Enter vehicle', fields = { 'vehicleVar', 'message', 'onSuccess' } },
    { type = 'require_vehicle', category = 'vehicles', label = 'Must be in job vehicle', fields = { 'vehicleVar', 'message', 'onSuccess', 'onFailure' } },
    { type = 'return_vehicle', category = 'vehicles', label = 'Return vehicle at zone', fields = { 'vehicleVar', 'location', 'locationVar', 'message', 'onSuccess', 'onFailure' } },
    { type = 'spawn_npc', category = 'world', label = 'Spawn NPC', fields = { 'model', 'location', 'locationVar', 'heading', 'storeAs', 'scenario', 'onSuccess' } },
    { type = 'remove_npc', category = 'world', label = 'Remove NPC', fields = { 'npcVar', 'onSuccess' } },
    { type = 'talk_to_npc', category = 'interaction', label = 'Talk to NPC', fields = { 'npcVar', 'message', 'onSuccess', 'onFailure' } },
    { type = 'require_item', category = 'items', label = 'Require item', fields = { 'item', 'count', 'onSuccess', 'onFailure' } },
    { type = 'give_item', category = 'items', label = 'Give item', fields = { 'item', 'count', 'onSuccess' } },
    { type = 'remove_item', category = 'items', label = 'Remove item', fields = { 'item', 'count', 'onSuccess', 'onFailure' } },
    { type = 'party_gate', category = 'party', label = 'Party size check', fields = { 'minPlayers', 'radius', 'message', 'onSuccess', 'onFailure' } },
    { type = 'give_reward', category = 'rewards', label = 'Pay + XP', fields = { 'pay', 'payVar', 'xp', 'onSuccess' } },
    { type = 'complete', category = 'rewards', label = 'Complete job', fields = {} },
    { type = 'fail', category = 'rewards', label = 'Fail job', fields = {} },
}

function SunsetJobCreator.GetStageCatalog()
    return SunsetJobCreator.StageCatalog
end
