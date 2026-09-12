#!/usr/bin/env node
// [AUDIT P2.5] Cross-domain DB write detector.
// Flags UPDATE/INSERT/DELETE statements in a resource that target tables owned
// by ANOTHER domain (docs/architecture/DOMAIN_OWNERSHIP.md §4), unless the
// write site carries an explicit allowlist marker comment: [DB-WRITE-OK:<reason>]
// Exit code 1 on new violations.
//
// Usage: node scripts/check-db-writes.js
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const sunset = path.join(root, 'resources', '[sunset]');

// Canonical owners (DOMAIN_OWNERSHIP.md). Tables not listed are free-for-owner.
const TABLE_OWNER = {
    accounts: 'sunset_core', players: 'sunset_core', characters: 'sunset_core',
    money_transactions: 'sunset_core',
    character_inventory: 'sunset_inventory', container_inventory: 'sunset_inventory',
    vehicles: 'sunset_vehicles',
    properties: 'sunset_properties', property_rentals: 'sunset_properties',
    player_businesses: 'sunset_businesses',
    clans: 'sunset_clans', clan_members: 'sunset_clans', clan_invites: 'sunset_clans', clan_audit_log: 'sunset_clans',
    turfs: 'sunset_turfs',
    wanted_records: 'sunset_factions', jail_sentences: 'sunset_factions',
    admins: 'sunset_admin', bans: 'sunset_admin', admin_checkpoints: 'sunset_admin', admin_stat_audit: 'sunset_admin',
    licenses: 'sunset_licenses', lssi_exam_reviews: 'sunset_licenses',
    service_calls: 'sunset_dispatch',
    auth_quick_tokens: 'sunset_auth',
    job_progress: 'sunset_jobs',
    dealership_vehicles: 'sunset_dealership', dealership_sales: 'sunset_dealership',
    taxi_rides: 'sunset_taxi',
    character_pass_progress: 'sunset_pass',
    phone_messages: 'sunset_phone', phone_contacts: 'sunset_phone',
    payday_runs: 'sunset_economy', lottery_state: 'sunset_economy',
    lottery_tickets: 'sunset_economy', lottery_draws: 'sunset_economy',
};

// Documented cross-domain writers (RESOURCE_MAP.md §4 "Other writers" + audit fixes).
// Format: `${resource}:${table}` allowlisted sites.
const ALLOWED = new Set([
    // multi-domain settlement transactions (ledger-consistent, atomic)
    'sunset_inventory:characters',      // trade cash delta in txn + ledger
    'sunset_inventory:vehicles',        // trade asset transfer in txn
    'sunset_inventory:properties',      // trade asset transfer in txn
    'sunset_inventory:property_rentals',// trade clears rentals in txn
    'sunset_inventory:player_businesses',// trade asset transfer in txn
    'sunset_tuning:characters',         // ECU save bank debit in txn + ledger
    'sunset_tuning:vehicles',           // props/plate save in txn
    'sunset_dealership:characters',     // purchase debit in txn + ledger
    'sunset_dealership:vehicles',       // purchase INSERT in txn
    'sunset_economy:characters',        // payday salary/tax/rent in txn + ledger
    'sunset_economy:properties',        // rent collection in txn
    'sunset_jobs:characters',           // fisherman sell cash credit in txn + ledger
    'sunset_core:clans',                // character deletion dissolve
    'sunset_core:turfs',                // character deletion release
    'sunset_core:properties',           // character deletion release
    'sunset_core:player_businesses',    // character deletion release
    'sunset_core:lottery_tickets',      // character deletion cleanup
    'sunset_clans:turfs',               // clan dissolve releases turfs
    'sunset_admin:characters',          // admin setstat commands (level-gated)
    // ledger-consistent in-transaction writes (audit-verified patterns)
    'sunset_dealership:money_transactions', // ledger row inside purchase txn
    'sunset_jobs:money_transactions',       // ledger row inside fisherman sell txn
    'sunset_jobs:character_inventory',      // fish deletion inside sell txn
    'sunset_crafting:character_inventory',  // consume+output inside craft txn (P5-01)
    'sunset_economy:money_transactions',    // payday ledger rows inside txn
    'sunset_economy:property_rentals',      // rent collection inside payday txn
    'sunset_tuning:money_transactions',     // ECU save ledger row inside txn
    'sunset_inventory:money_transactions',  // trade cash ledger rows post-commit
    // auth is the accounts-domain operator on behalf of core (handshake design)
    'sunset_auth:accounts',
    // appearance persists editor output (validated WHERE id AND player_id)
    'sunset_appearance:characters',
    // starter items grant inside character creation txn in core
    'sunset_core:character_inventory',
]);

// KNOWN violations — real cross-domain writes that need remediation (Phase 3).
// Listed explicitly so this script passes as a CI gate while tracking the debt.
// Remove an entry here ONLY after fixing the write to go through the owner API.
const KNOWN_VIOLATIONS = new Set([
    'sunset_admin:job_progress',        // DOMAIN_OWNERSHIP #1: use sunset_jobs:AddJobProgress
    'sunset_interactions:characters',   // phone_number assignment: move to core API
    'sunset_interactions:phone_contacts', // contact add: use sunset_phone exports
    'sunset_phone:characters',          // phone_number derivation: move to core API
    'sunset_properties:characters',     // rent income + purchase debits: route via core money API / ledger helper
    'sunset_carjack:job_progress',      // DOMAIN_OWNERSHIP #1: use sunset_jobs:AddJobProgress
    'sunset_vehicles:money_transactions', // gas-station ledger rows inside fuel txns (acceptable interim)
    'sunset_factions:characters',       // if any appear: route via core
    // in-transaction guarded debits (audit-verified atomic; consolidate via
    // core Ledger helper in Phase 3, functionally safe today)
    'sunset_vehicles:characters',       // gas-can/refuel payment inside fuel txn
    'sunset_vehicles:character_inventory', // gas-can liter updates inside fuel txn
    'sunset_robbery:character_inventory',  // fence sale item consumption in txn
    'sunset_robbery:characters',        // fence payout credit in txn
    'sunset_admin:accounts',            // setadmin level write (level-5 gated)
]);

function walk(dir, out = []) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, ent.name);
        if (ent.isDirectory()) walk(p, out);
        else if (ent.name.endsWith('.lua')) out.push(p);
    }
    return out;
}

const WRITE_RE = /\b(UPDATE\s+`?(\w+)`?|INSERT\s+(?:IGNORE\s+)?INTO\s+`?(\w+)`?|DELETE\s+FROM\s+`?(\w+)`?)/gi;

let violations = 0;
let knownHits = new Set();
let checked = 0;
for (const f of walk(sunset)) {
    const rel = path.relative(sunset, f);
    const resource = rel.split(path.sep)[0];
    const src = fs.readFileSync(f, 'utf8');
    const lines = src.split('\n');
    checked++;
    lines.forEach((line, i) => {
        WRITE_RE.lastIndex = 0;
        let m;
        while ((m = WRITE_RE.exec(line))) {
            const table = (m[2] || m[3] || m[4] || '').toLowerCase();
            const owner = TABLE_OWNER[table];
            if (!owner || owner === resource) continue;
            const key = `${resource}:${table}`;
            if (ALLOWED.has(key)) continue;
            // inline marker escape hatch
            const ctx = lines.slice(Math.max(0, i - 2), i + 1).join(' ');
            if (ctx.includes('[DB-WRITE-OK:')) continue;
            if (KNOWN_VIOLATIONS.has(key)) { knownHits.add(key); continue; }
            violations++;
            console.log(`VIOLATION ${path.relative(root, f)}:${i + 1}  ${resource} writes '${table}' (owned by ${owner})`);
            console.log(`    ${line.trim().slice(0, 140)}`);
        }
    });
}
if (knownHits.size) {
    console.log(`\nKnown debt (tracked for Phase 3 remediation, does not fail the gate):`);
    for (const k of knownHits) console.log(`  ${k}`);
}
console.log(`\nChecked ${checked} lua files. ${violations} NEW cross-domain write violation(s).`);
process.exit(violations ? 1 : 0);
