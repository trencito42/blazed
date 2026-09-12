// Lua syntax gate for all sunset resources (FiveM CfxLua).
// Usage: node scripts/check-lua-syntax.js [dir]   (default resources/[sunset])
// Requires luaparse: npm install luaparse (already present in temp dir; install locally if missing).
// CfxLua backtick joaat literals (`WEAPON_X`) are not understood by luaparse,
// so they are replaced with a numeric literal before parsing.
const fs = require('fs');
const path = require('path');

let luaparse;
try {
    luaparse = require('luaparse');
} catch (_) {
    const fallback = path.join(process.env.TEMP || '/tmp', 'opencode', 'node_modules', 'luaparse');
    luaparse = require(fallback);
}

function walk(d, out) {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
        const p = path.join(d, e.name);
        if (e.isDirectory()) walk(p, out);
        else if (e.name.endsWith('.lua')) out.push(p);
    }
    return out;
}

const root = process.argv[2] || path.join('resources', '[sunset]');
const files = walk(root, []);
let ok = 0, bad = 0;
for (const f of files) {
    // Strip CfxLua backtick literals -> joaat hash placeholder (number).
    const src = fs.readFileSync(f, 'utf8').replace(/`[^`\n]+`/g, '0');
    try {
        luaparse.parse(src, { luaVersion: '5.3' });
        ok++;
    } catch (err) {
        bad++;
        console.log(`SYNTAX ERROR: ${f}`);
        console.log(`   ${err.message}`);
    }
}
console.log(`\nParsed ${files.length} lua files: ${ok} OK, ${bad} with syntax errors.`);
process.exit(bad > 0 ? 1 : 0);
