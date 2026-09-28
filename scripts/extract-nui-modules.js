const fs = require('fs');
const path = require('path');

const webDir = path.join(__dirname, '..', 'resources', '[sunset]', 'sunset_ui', 'web');
const modulesDir = path.join(webDir, 'modules');
const html = fs.readFileSync(path.join(webDir, 'index.html'), 'utf8');

const modules = [
    {
        name: 'trade',
        startComment: '<!-- TRADE INVITATION (Hold Y / N) -->',
        endComment: '<!-- SERVER ANNOUNCEMENT -->',
        css: ['css/trade-forza.css'],
        js: ['js/trade-forza.js']
    },
    {
        name: 'characters',
        startComment: '<!-- CHARACTER SCREENS -->',
        endComment: '<!-- Premium HUD -->',
        css: ['css/spawn.css', 'css/screens.css'],
        js: ['js/characters.js', 'js/spawn.js']
    },
    {
        name: 'hud',
        startComment: '<!-- Premium HUD -->',
        endComment: '<!-- SCOREBOARD (hold Z) -->',
        css: ['css/hud.css', 'css/premium-hud.css', 'css/radar.css', 'css/damage-indicators.css'],
        js: ['js/forza_speedometer.js', 'js/hud.js', 'js/hud_editor.js', 'js/radar.js', 'js/damage-indicators.js']
    },
    {
        name: 'scoreboard',
        startComment: '<!-- SCOREBOARD (hold Z) -->',
        endComment: '<!-- CHAT (premium) -->',
        css: ['css/scoreboard-forza.css', 'css/scoreboard.css'],
        js: ['js/scoreboard.js']
    },
    {
        name: 'chat',
        startComment: '<!-- CHAT (premium) -->',
        endComment: '<!-- PLAYER MENU (M) — premium_player_dashboard_m_menu.html -->',
        css: ['css/chat.css', 'css/premium-chat.css'],
        js: ['js/chat_settings.js', 'js/chat.js']
    },
    {
        name: 'menu',
        startComment: '<!-- PLAYER MENU (M) — premium_player_dashboard_m_menu.html -->',
        endComment: '<!-- INVENTORY (I) — iinventory.html Forza port -->',
        css: ['css/menu.css', 'css/premium-menu.css', 'css/premium-vehicle-menu.css'],
        js: ['js/menu.js']
    },
    {
        name: 'inventory',
        startComment: '<!-- INVENTORY (I) — iinventory.html Forza port -->',
        endComment: '<!-- 24/7 STORE (Forza) -->',
        css: ['css/inventory-forza.css', 'css/quick-hotbar.css'],
        js: ['js/hotbar.js', 'js/inventory-forza.js']
    },
    {
        name: 'store',
        startComment: '<!-- 24/7 STORE (Forza) -->',
        endComment: '<!-- TRUCKER LAPTOP — delivery route selector -->',
        css: ['css/store-forza.css'],
        js: ['js/store247.js']
    },
    {
        name: 'trucker',
        startComment: '<!-- TRUCKER LAPTOP — delivery route selector -->',
        endComment: '<!-- FISHING SHOP (buy bait / sell fish) — premium inventory layout -->',
        css: ['css/trucker-laptop.css'],
        js: ['js/trucker-laptop.js']
    },
    {
        name: 'fishing',
        startComment: '<!-- FISHING SHOP (buy bait / sell fish) — premium inventory layout -->',
        endComment: '<!-- JOB CENTER — premium inventory layout -->',
        css: ['css/fishing.css'],
        js: ['js/fishing.js']
    },
    {
        name: 'jobcenter',
        startComment: '<!-- JOB CENTER — premium inventory layout -->',
        endComment: '<!-- FLEECA BANK 24/7 ATM KIOSK — AUTHENTIC REAL-WORLD BANCOMAT -->',
        css: ['css/panels.css'],
        js: ['js/job_shift.js', 'js/job_icons.js']
    },
    {
        name: 'atm',
        startComment: '<!-- FLEECA BANK 24/7 ATM KIOSK — AUTHENTIC REAL-WORLD BANCOMAT -->',
        endComment: '<!-- POLICE TOUGHBOOK MDT (MOBILE DATA TERMINAL) -->',
        css: ['css/atm.css', 'css/fleeca-bank.css'],
        js: ['js/atm.js']
    },
    {
        name: 'mdc',
        startComment: '<!-- POLICE TOUGHBOOK MDT (MOBILE DATA TERMINAL) -->',
        endComment: '<!-- TICKET ISSUE (officer) -->',
        css: ['css/mdc_tablet.css'],
        js: ['js/mdc_tablet.js']
    },
    {
        name: 'panels',
        startComment: '<!-- TICKET ISSUE (officer) -->',
        endComment: '<!-- FACTION DASHBOARD (/faction) -->',
        css: ['css/panels.css', 'css/org-panels.css', 'css/gameplay_glass.css', 'css/interactions.css'],
        js: ['js/panels.js', 'js/overlays.js', 'js/player_identity.js', 'js/world-tooltip.js', 'js/fuel_pump.js']
    },
    {
        name: 'factions',
        startComment: '<!-- FACTION DASHBOARD (/faction) -->',
        endComment: '<!-- CLAN DASHBOARD (/clan) -->',
        css: ['css/factions.css', 'css/premium-factions.css'],
        js: ['js/factions.js']
    },
    {
        name: 'clans',
        startComment: '<!-- CLAN DASHBOARD (/clan) -->',
        endComment: '<!-- HELP -->',
        css: ['css/clans.css', 'css/clanwar.css'],
        js: ['js/clans.js', 'js/clanwar.js']
    },
    {
        name: 'helpdesk',
        startComment: '<!-- HELP -->',
        endComment: '<!-- GARAGE -->',
        css: ['css/helpdesk.css'],
        js: ['js/helpdesk.js']
    },
    {
        name: 'garage',
        startComment: '<!-- GARAGE -->',
        endComment: '<!-- PROPERTIES -->',
        css: ['css/panels.css'],
        js: ['js/panels.js']
    },
    {
        name: 'properties',
        startComment: '<!-- PROPERTIES -->',
        endComment: '<!-- EMOTES -->',
        css: ['css/premium-properties.css'],
        js: ['js/properties-ui.js']
    },
    {
        name: 'wardrobe',
        startComment: '<!-- CLOTHING (barber legacy panel) -->',
        endComment: '<!-- iPHONE -->',
        css: ['css/wardrobe-forza.css'],
        js: ['js/wardrobe.js']
    },
    {
        name: 'phone',
        startComment: '<!-- iPHONE -->',
        endComment: '<!-- DOCUMENTS -->',
        css: ['css/phone.css'],
        js: ['js/phone-taxi-map.js', 'js/phone.js']
    },
    {
        name: 'dealership',
        startComment: '<!-- VEHICLE DEALERSHIP (Forza / NFS style — dealership-tuning.html) -->',
        endComment: '<!-- PREMIUM INTERACTION MENU (1:1 premium-interaction-menu.html) -->',
        css: ['css/dealership-forza.css'],
        js: ['js/dealership.js']
    },
    {
        name: 'player_interaction',
        startComment: '<!-- PREMIUM INTERACTION MENU (1:1 premium-interaction-menu.html) -->',
        endComment: '<!-- CRAFTING -->',
        css: ['css/player_interaction.css', 'css/interactions.css'],
        js: ['js/player_interaction.js']
    },
    {
        name: 'studio',
        startComment: '<!-- APPEARANCE STUDIO (3D preview — transparent left side) -->',
        endComment: '<!-- BATTLEPASS & MISSIONS 1:1 PORT (from premium_battlepass_missions.html) -->',
        css: ['css/studio.css'],
        js: ['js/appearance.js']
    },
    {
        name: 'battlepass',
        startComment: '<!-- BATTLEPASS & MISSIONS 1:1 PORT (from premium_battlepass_missions.html) -->',
        endComment: '<!-- BUSINESS PANEL (/abusiness admin, /mybusiness owner) -->',
        css: ['css/battlepass.css'],
        js: ['js/battlepass.js']
    },
    {
        name: 'businesses',
        startComment: '<!-- BUSINESS PANEL (/abusiness admin, /mybusiness owner) -->',
        endComment: '<!-- ═══ CASINO ═══ -->',
        css: ['css/panels.css'],
        js: ['js/businesses.js']
    },
    {
        name: 'casino',
        startComment: '<!-- ═══ CASINO ═══ -->',
        endComment: '<!-- ═══ IMPOUND ═══ -->',
        css: ['css/casino.css'],
        js: ['js/casino.js']
    },
    {
        name: 'impound',
        startComment: '<!-- ═══ IMPOUND ═══ -->',
        endComment: '<!-- ═══ RACING ═══ -->',
        css: ['css/impound.css'],
        js: ['js/impound.js']
    },
    {
        name: 'racing',
        startComment: '<!-- ═══ RACING ═══ -->',
        endComment: '<!-- ═══ DRUGS ═══ -->',
        css: ['css/racing.css'],
        js: ['js/racing.js']
    },
    {
        name: 'drugs',
        startComment: '<!-- ═══ DRUGS ═══ -->',
        endComment: '<!-- ═══ MARRIAGE PROPOSAL ═══ -->',
        css: ['css/drugs.css'],
        js: ['js/drugs.js']
    },
    {
        name: 'marriage',
        startComment: '<!-- ═══ MARRIAGE PROPOSAL ═══ -->',
        endComment: '<!-- ═══ AUTH-ONLY SCRIPTS (loaded at boot) ═══ -->',
        css: ['css/marriage.css'],
        js: ['js/marriage.js']
    },
    {
        name: 'licenses',
        startComment: null, // Will extract from license panels in html if present
        endComment: null,
        css: ['css/license_test.css', 'css/license_quiz.css'],
        js: ['js/license_test.js', 'js/license_quiz.js']
    },
    {
        name: 'quests',
        startComment: null,
        endComment: null,
        css: ['css/quests.css'],
        js: ['js/quests.js']
    },
    {
        name: 'courier',
        startComment: null,
        endComment: null,
        css: ['css/courier.css'],
        js: ['js/courier.js']
    }
];

// Extract fragments
for (const mod of modules) {
    const targetDir = path.join(modulesDir, mod.name);
    if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });

    let fragment = '';
    if (mod.startComment && mod.endComment) {
        const startIdx = html.indexOf(mod.startComment);
        const endIdx = html.indexOf(mod.endComment);
        if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
            fragment = html.substring(startIdx + mod.startComment.length, endIdx).trim();
        } else {
            console.warn(`Could not find boundary comments for module ${mod.name}`);
        }
    }

    if (fragment) {
        fs.writeFileSync(path.join(targetDir, 'index.html'), fragment, 'utf8');
        console.log(`Extracted module [${mod.name}]: index.html (${fragment.length} bytes)`);
    } else if (!fs.existsSync(path.join(targetDir, 'index.html'))) {
        fs.writeFileSync(path.join(targetDir, 'index.html'), '<!-- Empty fragment -->\n', 'utf8');
        console.log(`Created placeholder module [${mod.name}]: index.html`);
    }
}

console.log('Module extraction completed successfully.');
