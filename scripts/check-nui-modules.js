#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const uiWebDir = path.join(repoRoot, 'resources', '[sunset]', 'sunset_ui', 'web');
const authUiWebDir = path.join(repoRoot, 'resources', '[sunset]', 'sunset_auth_ui', 'web');

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
        const modKeys = [...modMatch[1].matchAll(/([a-zA-Z0-9_]+)\s*:\s*\{/g)].map(m => m[1]);
        console.log(`Registered modules in ModuleLoader (${modKeys.length}):`, modKeys.join(', '));

        for (const mod of modKeys) {
            const modDir = path.join(modulesDir, mod);
            const modHtml = path.join(modDir, 'index.html');
            if (!fs.existsSync(modHtml)) {
                console.error(`ERROR: Module [${mod}] missing fragment index.html at ${modHtml}!`);
                errors++;
            }
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
