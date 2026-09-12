#!/usr/bin/env node
// [AUDIT P2.5] NUI bridge completeness check.
// Verifies every fetch('https://.../<name>') posted from sunset_ui JS exists as a
// RegisterNUICallback/forward in the Lua side, and lists registered callbacks
// with no JS caller (dead forwards). Exit code 1 on missing registrations.
//
// Usage: node scripts/check-nui-bridge.js
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const uiWeb = path.join(root, 'resources', '[sunset]', 'sunset_ui', 'web');
const uiClient = path.join(root, 'resources', '[sunset]', 'sunset_ui', 'client');

function walk(dir, exts, out = []) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, ent.name);
        if (ent.isDirectory()) walk(p, exts, out);
        else if (exts.some((e) => ent.name.endsWith(e))) out.push(p);
    }
    return out;
}

// 1. Collect names posted from JS
const posted = new Map(); // name -> [file:line]
const jsFiles = walk(path.join(uiWeb, 'js'), ['.js']).concat(
    fs.existsSync(path.join(uiWeb, 'index.html')) ? [path.join(uiWeb, 'index.html')] : []
);
for (const f of jsFiles) {
    const lines = fs.readFileSync(f, 'utf8').split('\n');
    lines.forEach((line, i) => {
        // fetch(`https://${...}/NAME` or post('NAME' / postNui('NAME'
        const patterns = [
            /fetch\(\s*`https:\/\/\$\{[^}]+\}\/([A-Za-z0-9_]+)/g,
            /fetch\(\s*["']https:\/\/[^"']*\/([A-Za-z0-9_]+)/g,
            /\bpost\(\s*['"]([A-Za-z0-9_]+)['"]/g,
            /\bpostNui\(\s*['"]([A-Za-z0-9_]+)['"]/g,
        ];
        for (const re of patterns) {
            let m;
            while ((m = re.exec(line))) {
                const name = m[1];
                if (!posted.has(name)) posted.set(name, []);
                posted.get(name).push(`${path.relative(root, f)}:${i + 1}`);
            }
        }
    });
}

// 2. Collect registrations in Lua (bridge + main)
const registered = new Set();
const luaFiles = walk(uiClient, ['.lua']);
for (const f of luaFiles) {
    const src = fs.readFileSync(f, 'utf8');
    for (const m of src.matchAll(/RegisterNUICallback\(\s*['"]([A-Za-z0-9_]+)['"]/g)) registered.add(m[1]);
    for (const m of src.matchAll(/forward\(\s*['"]([A-Za-z0-9_]+)['"]/g)) registered.add(m[1]);
}
// Other resources with own ui_page (pass/robbery/tuning) register their own callbacks.
const otherUi = ['sunset_pass', 'sunset_robbery', 'sunset_tuning', 'sunset_licenses'];
for (const res of otherUi) {
    const dir = path.join(root, 'resources', '[sunset]', res);
    if (!fs.existsSync(dir)) continue;
    for (const f of walk(dir, ['.lua'])) {
        const src = fs.readFileSync(f, 'utf8');
        for (const m of src.matchAll(/RegisterNUICallback\(\s*['"]([A-Za-z0-9_]+)['"]/g)) registered.add(m[1]);
    }
}

// 3. Diff
let fail = 0;
const missing = [];
for (const [name, locs] of [...posted.entries()].sort()) {
    if (!registered.has(name)) {
        missing.push({ name, locs });
        fail++;
    }
}
if (missing.length) {
    console.log('MISSING registrations (JS posts, Lua never answers -> silent 404):');
    for (const { name, locs } of missing) {
        console.log(`  ${name}`);
        locs.slice(0, 3).forEach((l) => console.log(`      ${l}`));
    }
} else {
    console.log(`OK: all ${posted.size} posted NUI callbacks are registered.`);
}

// Dead forwards (informational only)
const dead = [...registered].filter((r) => !posted.has(r)).sort();
console.log(`\nINFO: ${dead.length} registered callbacks with no JS caller in sunset_ui (may be called from other-resource NUI pages or dead):`);
console.log('  ' + dead.join(', '));

process.exit(fail ? 1 : 0);
