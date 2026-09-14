#!/usr/bin/env node
// Detects the PendingRefunds-class bug: a callback/function body references an
// identifier that is declared as `local X` LATER in the same file. In Lua the
// function compiles it as a GLOBAL (nil at runtime) instead of an upvalue.
// Heuristic scan: collect `local NAME` declaration lines; for each reference to
// NAME at a line BEFORE its declaration, inside a function-ish context, flag it.
'use strict';
const fs = require('fs');
const path = require('path');

const root = process.argv[2] || '.';
let fail = 0, count = 0;

// words that are never the bug (Lua keywords / very common globals)
const SKIP = new Set(['Sunset', 'MySQL', 'SunsetClothing', 'SunsetAppearance', 'TorsoData',
    'SunsetContainers', 'SunsetJobs', 'Police', 'Detention', 'FactionCore', 'SunsetTurfs',
    'SunsetTuning', 'RobberyLoot', 'ServiceCore', 'HotbarUI', 'WardrobeShop']);

function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        // [FIXED] Skip vendored FiveM runtime artifacts (gitignored) — their
        // doc-comment mentions look like forward refs and they are not part of
        // the gamemode.
        if (e.isDirectory() && ['citizen', 'cache', 'crashes', 'node_modules', '.git', 'server redesign'].includes(e.name)) continue;
        if (e.isDirectory()) walk(p);
        else if (e.name.endsWith('.lua')) check(p);
    }
}

function check(file) {
    count++;
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    // map: local name -> first declaration line
    const decls = new Map();
    // [FIXED] Collect every function parameter name in the file. This scan is
    // line-based (no scope analysis), so a reference inside a function body to
    // one of that function's own parameters looked like a forward reference
    // (false positive on sunset_licenses 'charId'). A name that is EVER a
    // parameter anywhere in the file is skipped — the real bug pattern
    // (fisherman.lua 'lastInventoryClose') is a file-scope local that is never
    // a parameter, so this keeps true positives.
    const paramNames = new Set();
    lines.forEach((ln) => {
        const noStr = ln.replace(/'[^']*'/g, "''").replace(/"[^"]*"/g, '""');
        const m = noStr.match(/function\s*[A-Za-z_.:0-9]*\s*\(([^)]*)\)/)
            || noStr.match(/function\s*\(([^)]*)\)/);
        if (m) m[1].split(',').forEach((p) => { const t = p.trim(); if (t) paramNames.add(t); });
    });
    lines.forEach((ln, i) => {
        const m = ln.match(/^local\s+(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)/);
        if (m && !decls.has(m[1])) decls.set(m[1], i + 1);
        // also local a, b = ...
        const m2 = ln.match(/^local\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)+)/);
        if (m2) m2[1].split(',').forEach((n) => { const t = n.trim(); if (t && !decls.has(t)) decls.set(t, i + 1); });
    });
    for (const [name, declLine] of decls) {
        if (SKIP.has(name) || name.length < 3) continue;
        if (paramNames.has(name)) continue;
        const re = new RegExp('(^|[^.:%w_"\'])' + name.replace(/[$]/g, '\\$') + '\\s*(\\[|\\.|=|\\)|,|\\s)', 'g');
        for (let i = 0; i < declLine - 1; i++) {
            const ln = lines[i];
            if (ln.trim().startsWith('--')) continue;
            // skip strings crudely
            const noStr = ln.replace(/'[^']*'/g, "''").replace(/"[^"]*"/g, '""').replace(/\[\[[\s\S]*?\]\]/g, '``');
            // A parameter in this line's own function definition is not a
            // forward reference (false positive, e.g. `function f(source, charId)`).
            const params = noStr.match(/function\s+[A-Za-z_.:]*\s*\(([^)]*)\)/)
                || noStr.match(/function\s*\(([^)]*)\)/);
            const isParam = params && params[1].split(',').some((p) => p.trim() === name);
            if (re.test(noStr) && !isParam) {
                // [FIXED] The old rule only flagged `name[`, `name=` and `name(`,
                // so an ARITHMETIC read like `(GetGameTimer() - lastInventoryClose)`
                // slipped through — exactly the fisherman.lua regression that
                // compiled the local as a nil global and killed the shift thread.
                // Now also flag reads followed by a binary operator, a closing
                // paren/bracket, a comma, or end-of-expression.
                const use = noStr.match(new RegExp(
                    '(^|[^.:%w_"\'])' + name + '\\s*(\\[|=[^=~]|\\(|[-+*/%%<>~]=?|\\)|\\]|,|$|\\s+and\\b|\\s+or\\b|\\s+then\\b)'));
                if (use) {
                    fail++;
                    console.log(`FORWARD-REF ${file}:${i + 1} uses '${name}' declared later at line ${declLine}`);
                    console.log(`    ${ln.trim().slice(0, 120)}`);
                }
                re.lastIndex = 0;
                break; // one report per name per file
            }
            re.lastIndex = 0;
        }
    }
}

walk(root);
console.log(`\nChecked ${count} files. ${fail} forward-reference issue(s).`);
process.exit(fail ? 1 : 0);
