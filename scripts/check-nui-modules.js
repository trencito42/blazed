#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const uiWebDir = path.join(repoRoot, 'resources', '[sunset]', 'sunset_ui', 'web');
const authUiWebDir = path.join(repoRoot, 'resources', '[sunset]', 'sunset_auth_ui', 'web');
const sunsetResourcesDir = path.join(repoRoot, 'resources', '[sunset]');

console.log('--- Checking NUI Modular Architecture ---');
let errors = 0;

// 1. Check sunset_ui index.html
const indexHtmlPath = path.join(uiWebDir, 'index.html');
if (!fs.existsSync(indexHtmlPath)) {
    console.error('ERROR: sunset_ui/web/index.html not found!');
    process.exit(1);
}

const indexHtml = fs.readFileSync(indexHtmlPath, 'utf8');

// Check size
const indexSizeKb = (Buffer.byteLength(indexHtml, 'utf8') / 1024).toFixed(2);
console.log(`sunset_ui index.html size: ${indexSizeKb} KB (Target < 20 KB)`);
if (parseFloat(indexSizeKb) > 20) {
    console.error(`ERROR: sunset_ui index.html exceeds 20 KB! (${indexSizeKb} KB)`);
    errors++;
}

// Check for forbidden legacy lazy loading attributes
if (indexHtml.includes('data-lazy-src')) {
    console.error('ERROR: index.html contains data-lazy-src!');
    errors++;
}
if (indexHtml.includes('data-deferred-style')) {
    console.error('ERROR: index.html contains data-deferred-style!');
    errors++;
}

// Check for forbidden gameplay panels in base DOM
const FORBIDDEN_DOM_IDS = [
    'chat',
    'chat-app',
    'chat-settings-panel',
    'inventory',
    'phone-device',
    'mdc',
    'casino-overlay',
    'clan-panel',
    'business-panel',
    'faction-panel',
    'atm-modal',
    'dealership',
    'wardrobe',
    'store-forza',
];

for (const id of FORBIDDEN_DOM_IDS) {
    const pattern = new RegExp(`id=["']${id}["']`, 'i');
    if (pattern.test(indexHtml)) {
        console.error(`ERROR: Base index.html contains forbidden gameplay DOM id="${id}"!`);
        errors++;
    }
}

// 2. Check ModuleLoader registry and files
const moduleLoaderPath = path.join(uiWebDir, 'js', 'module-loader.js');
if (!fs.existsSync(moduleLoaderPath)) {
    console.error('ERROR: module-loader.js not found!');
    errors++;
} else {
    const mlContent = fs.readFileSync(moduleLoaderPath, 'utf8');
    const modulesDir = path.join(uiWebDir, 'modules');

    // Extract module names from registry
    const modMatch = mlContent.match(/MODULE_REGISTRY\s*=\s*\{([\s\S]*?)\n\s*\};/);
    if (!modMatch) {
        console.error('ERROR: Could not parse MODULE_REGISTRY from module-loader.js!');
        errors++;
    } else {
        const moduleDefs = [...modMatch[1].matchAll(/([a-zA-Z0-9_]+)\s*:\s*\{([\s\S]*?)\n\s*\}(?:,|$)/g)]
            .map((match) => ({
                name: match[1],
                html: match[2].match(/html:\s*['"]([^'"]+)['"]/)?.[1] || null,
                assets: [...match[2].matchAll(/['"]((?:css|js)\/[^'"]+)['"]/g)].map((asset) => asset[1]),
            }));
        const modKeys = moduleDefs.map((row) => row.name);
        console.log(`Registered modules in ModuleLoader (${modKeys.length}):`, modKeys.join(', '));

        for (const mod of moduleDefs) {
            if (mod.html) {
                const modHtml = path.join(uiWebDir, mod.html);
                if (!fs.existsSync(modHtml)) {
                    console.error(`ERROR: Module [${mod.name}] missing fragment at ${modHtml}!`);
                    errors++;
                }
            }
            for (const asset of mod.assets) {
                const assetPath = path.join(uiWebDir, asset);
                if (!fs.existsSync(assetPath)) {
                    console.error(`ERROR: Module [${mod.name}] missing asset at ${assetPath}!`);
                    errors++;
                }
            }
        }
    }
}

// 4. Critical boot/auth contracts that previously passed syntax checks while
// failing at runtime in CEF.
const appJs = fs.readFileSync(path.join(uiWebDir, 'js', 'app.js'), 'utf8');
const authJs = fs.readFileSync(path.join(authUiWebDir, 'auth.js'), 'utf8');
if (!/post\(['"]bootEpoch['"],\s*\{\s*now:\s*Date\.now\(\)/.test(appJs)) {
    console.error('ERROR: bootEpoch must post { now: Date.now() }.');
    errors++;
}
if (!/passwordConfirm:\s*pass2/.test(authJs) || /confirmPassword:\s*pass2/.test(authJs)) {
    console.error('ERROR: registration must use canonical passwordConfirm.');
    errors++;
}
if (/post\(['"]authRendered['"]/.test(authJs)) {
    console.error('ERROR: premature authRendered callback is forbidden.');
    errors++;
}
if (/window\.HUD|\bHUD\./.test(appJs)) {
    console.error('ERROR: HUD dispatcher must use the actual window.Hud export.');
    errors++;
}
const chatFragment = fs.readFileSync(path.join(uiWebDir, 'modules', 'chat', 'index.html'), 'utf8');
if (chatFragment.includes('v-menu-close-hint')) {
    console.error('ERROR: chat fragment contains the vehicle-menu close hint.');
    errors++;
}

// A dynamically loaded script cannot receive the message that triggered its
// own load. Every literal action sent through exports.sunset_ui:Send must
// therefore be known by the shell dispatcher, which replays queued messages.
function walk(dir, extension, out = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full, extension, out);
        else if (entry.name.endsWith(extension)) out.push(full);
    }
    return out;
}
const exportedActions = new Set();
for (const luaFile of walk(sunsetResourcesDir, '.lua')) {
    const source = fs.readFileSync(luaFile, 'utf8');
    for (const match of source.matchAll(/exports\.sunset_ui:Send\s*\(\s*['"]([A-Za-z0-9_]+)['"]/g)) {
        exportedActions.add(match[1]);
    }
}
for (const action of [...exportedActions].sort()) {
    const pattern = new RegExp(`['"]${action}['"]`);
    if (!pattern.test(appJs)) {
        console.error(`ERROR: NUI action ${action} is sent by Lua but unknown to app.js.`);
        errors++;
    }
}

const criticalDom = {
    hud: ['server-announce', 'police-order', 'taxi-meter', 'world-tooltip-layer', 'fuel-pump', 'fishing-panel', 'radar-panel', 'radar-alert-panel'],
    panels: ['ticket', 'servicecalls', 'jobs-panel', 'skills', 'help', 'documents', 'emotes', 'crafting'],
    courier: ['courier-panel'],
};
for (const [moduleName, ids] of Object.entries(criticalDom)) {
    const fragment = fs.readFileSync(path.join(uiWebDir, 'modules', moduleName, 'index.html'), 'utf8');
    for (const id of ids) {
        if (!new RegExp(`id=["']${id}["']`).test(fragment)) {
            console.error(`ERROR: Module [${moduleName}] is missing required DOM id="${id}".`);
            errors++;
        }
    }
}

// 3. Check sunset_auth_ui
const authIndex = path.join(authUiWebDir, 'index.html');
if (!fs.existsSync(authIndex)) {
    console.error('ERROR: sunset_auth_ui/web/index.html not found!');
    errors++;
} else {
    const authHtml = fs.readFileSync(authIndex, 'utf8');
    for (const id of FORBIDDEN_DOM_IDS) {
        const pattern = new RegExp(`id=["']${id}["']`, 'i');
        if (pattern.test(authHtml)) {
            console.error(`ERROR: sunset_auth_ui contains gameplay DOM id="${id}"!`);
            errors++;
        }
    }
    const authSizeKb = (Buffer.byteLength(authHtml, 'utf8') / 1024).toFixed(2);
    console.log(`sunset_auth_ui index.html size: ${authSizeKb} KB`);
}

if (errors === 0) {
    console.log('SUCCESS: All NUI modular architecture checks passed cleanly!');
    process.exit(0);
} else {
    console.error(`FAILED: ${errors} error(s) found during validation.`);
    process.exit(1);
}
