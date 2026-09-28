/* ═══════════════════════════════════════════════════════════════════
   SUNSETMP — Dynamic UI Module Loader (module-loader.js)
   True on-demand feature loading. Eliminates monolithic CEF parsing,
   FOUC, and permanent style recalculation overhead.
   ═══════════════════════════════════════════════════════════════════ */

(function () {
    'use strict';

    const MODULE_VERSION = '8';
    const versioned = (url) => `${url}${url.includes('?') ? '&' : '?'}v=${MODULE_VERSION}`;

    const MODULE_REGISTRY = {
        chat: {
            html: 'modules/chat/index.html',
            css: ['css/chat.css', 'css/premium-chat.css'],
            js: ['js/chat_settings.js', 'js/chat.js']
        },
        hud_core: {
            html: 'modules/hud/index.html',
            css: ['css/hud.css', 'css/premium-hud.css', 'css/premium-wanted.css', 'css/gameplay_glass.css', 'css/world-tooltip.css', 'css/fuel_pump.css', 'css/fuel-pump-forza.css', 'css/fishing.css'],
            js: ['js/forza_speedometer.js', 'js/hud.js', 'js/hud_editor.js', 'js/overlays.js', 'js/player_identity.js', 'js/world-tooltip.js', 'js/fuel_pump.js', 'js/job_icons.js', 'js/fishing.js']
        },
        radar: {
            css: ['css/radar.css'],
            js: ['js/radar.js']
        },
        damage_indicators: {
            css: ['css/damage-indicators.css'],
            js: ['js/damage-indicators.js']
        },
        inventory: {
            html: 'modules/inventory/index.html',
            css: ['css/inventory-forza.css', 'css/quick-hotbar.css'],
            js: ['js/hotbar.js', 'js/inventory-forza.js', 'js/panels.js']
        },
        trade: {
            html: 'modules/trade/index.html',
            css: ['css/trade-forza.css'],
            js: ['js/trade-forza.js']
        },
        menu: {
            html: 'modules/menu/index.html',
            css: ['css/menu.css', 'css/premium-menu.css', 'css/premium-vehicle-menu.css'],
            js: ['js/menu.js']
        },
        phone: {
            html: 'modules/phone/index.html',
            css: ['css/phone.css'],
            js: ['js/phone-taxi-map.js', 'js/phone.js']
        },
        mdc: {
            html: 'modules/mdc/index.html',
            css: ['css/mdc_tablet.css'],
            js: ['js/mdc_tablet.js']
        },
        factions: {
            html: 'modules/factions/index.html',
            css: ['css/factions.css', 'css/premium-factions.css'],
            js: ['js/factions.js']
        },
        clans: {
            html: 'modules/clans/index.html',
            css: ['css/clans.css', 'css/clanwar.css', 'css/premium-factions.css'],
            js: ['js/clans.js', 'js/clanwar.js']
        },
        businesses: {
            html: 'modules/businesses/index.html',
            css: ['css/panels.css'],
            js: ['js/businesses.js']
        },
        properties: {
            html: 'modules/properties/index.html',
            css: ['css/premium-properties.css'],
            js: ['js/properties-ui.js', 'js/panels.js']
        },
        dealership: {
            html: 'modules/dealership/index.html',
            css: ['css/dealership-forza.css'],
            js: ['js/dealership.js']
        },
        wardrobe: {
            html: 'modules/wardrobe/index.html',
            css: ['css/wardrobe-forza.css'],
            js: ['js/wardrobe.js']
        },
        atm: {
            html: 'modules/atm/index.html',
            css: ['css/atm.css', 'css/fleeca-bank.css'],
            js: ['js/atm.js']
        },
        store: {
            html: 'modules/store/index.html',
            css: ['css/store-forza.css'],
            js: ['js/store247.js']
        },
        trucker: {
            html: 'modules/trucker/index.html',
            css: ['css/store-forza.css', 'css/trucker-laptop.css'],
            js: ['js/trucker-laptop.js']
        },
        fishing: {
            html: 'modules/fishing/index.html',
            css: ['css/fishing.css'],
            js: ['js/fishing.js']
        },
        jobcenter: {
            html: 'modules/jobcenter/index.html',
            css: ['css/panels.css', 'css/jobcenter.css'],
            js: ['js/job_shift.js', 'js/job_icons.js', 'js/panels.js']
        },
        garage: {
            html: 'modules/garage/index.html',
            css: ['css/panels.css'],
            js: ['js/panels.js']
        },
        scoreboard: {
            html: 'modules/scoreboard/index.html',
            css: ['css/scoreboard-forza.css', 'css/scoreboard.css'],
            js: ['js/scoreboard.js']
        },
        helpdesk: {
            css: ['css/helpdesk.css'],
            js: ['js/helpdesk.js']
        },
        battlepass: {
            html: 'modules/battlepass/index.html',
            css: ['css/battlepass.css'],
            js: ['js/battlepass.js']
        },
        casino: {
            html: 'modules/casino/index.html',
            css: ['css/casino.css'],
            js: ['js/casino.js']
        },
        racing: {
            html: 'modules/racing/index.html',
            css: ['css/racing.css'],
            js: ['js/racing.js']
        },
        drugs: {
            html: 'modules/drugs/index.html',
            css: ['css/drugs.css'],
            js: ['js/drugs.js']
        },
        marriage: {
            html: 'modules/marriage/index.html',
            css: ['css/marriage.css'],
            js: ['js/marriage.js']
        },
        impound: {
            html: 'modules/impound/index.html',
            css: ['css/impound.css'],
            js: ['js/impound.js']
        },
        player_interaction: {
            html: 'modules/player_interaction/index.html',
            css: ['css/player_interaction.css', 'css/interactions.css'],
            js: ['js/player_interaction.js']
        },
        licenses: {
            html: 'modules/licenses/index.html',
            css: ['css/license_test.css', 'css/license_quiz.css'],
            js: ['js/license_test.js', 'js/license_quiz.js']
        },
        quests: {
            html: 'modules/quests/index.html',
            css: ['css/quests.css'],
            js: ['js/quests.js']
        },
        courier: {
            html: 'modules/courier/index.html',
            css: ['css/courier.css'],
            js: ['js/courier.js']
        },
        studio: {
            html: 'modules/studio/index.html',
            css: ['css/studio.css'],
            js: ['js/panels.js']
        },
        characters: {
            html: 'modules/characters/index.html',
            css: ['css/spawn.css', 'css/screens.css'],
            js: ['js/characters.js', 'js/spawn.js']
        },
        panels: {
            html: 'modules/panels/index.html',
            css: ['css/panels.css', 'css/org-panels.css', 'css/gameplay_glass.css'],
            js: ['js/panels.js', 'js/overlays.js', 'js/player_identity.js', 'js/world-tooltip.js', 'js/fuel_pump.js']
        }
    };

    const loadedModules = new Set();
    const loadedStylesheets = new Set();
    const loadedScripts = new Set();
    const activeLoadingPromises = new Map();
    const pendingModuleQueues = new Map();

    function loadStylesheet(href) {
        if (loadedStylesheets.has(href)) {
            return Promise.resolve();
        }

        // Check if already in DOM
        const existing = document.querySelector(`link[href*="${href}"]`);
        if (existing) {
            loadedStylesheets.add(href);
            return Promise.resolve();
        }

        return new Promise((resolve, reject) => {
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = versioned(href);
            link.onload = () => {
                loadedStylesheets.add(href);
                resolve();
            };
            link.onerror = () => {
                link.remove();
                reject(new Error(`Failed to load stylesheet ${href}`));
            };
            document.head.appendChild(link);
        });
    }

    function loadScript(src) {
        if (loadedScripts.has(src)) {
            return Promise.resolve();
        }

        const existing = document.querySelector(`script[src*="${src}"]`);
        if (existing) {
            loadedScripts.add(src);
            return Promise.resolve();
        }

        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = versioned(src);
            script.async = false;
            script.onload = () => {
                loadedScripts.add(src);
                resolve();
            };
            script.onerror = (err) => {
                console.error(`[ModuleLoader] Failed to load script: ${src}`, err);
                reject(new Error(`Failed to load script ${src}`));
            };
            document.body.appendChild(script);
        });
    }

    async function loadScriptsSequential(scripts) {
        for (const src of scripts) {
            await loadScript(src);
        }
    }

    async function ensureModule(name) {
        if (!name) return Promise.resolve(false);
        if (loadedModules.has(name)) return Promise.resolve(true);
        if (activeLoadingPromises.has(name)) return activeLoadingPromises.get(name);

        const def = MODULE_REGISTRY[name];
        if (!def) {
            console.warn(`[ModuleLoader] Unknown module: ${name}`);
            return Promise.resolve(false);
        }

        const t0 = performance.now();
        const promise = (async () => {
            try {
                // 1. Load all CSS first (Guarantees NO FOUC!)
                if (Array.isArray(def.css) && def.css.length > 0) {
                    await Promise.all(def.css.map(loadStylesheet));
                }

                // 2. Fetch and insert HTML fragment
                let mountedWrapper = null;
                if (def.html) {
                    const res = await fetch(versioned(def.html));
                    if (!res.ok) throw new Error(`Failed to fetch ${def.html} (${res.status})`);
                    const htmlText = await res.text();
                    const root = document.getElementById('ui-root');
                    if (!root) throw new Error('UI mount root is missing');
                    if (!htmlText.trim()) throw new Error(`Empty HTML fragment ${def.html}`);
                    mountedWrapper = document.createElement('div');
                    mountedWrapper.id = `module-${name}`;
                    mountedWrapper.className = 'ui-module-container';
                    mountedWrapper.innerHTML = htmlText;
                    root.appendChild(mountedWrapper);
                }

                // 3. Load JS scripts sequentially
                if (Array.isArray(def.js) && def.js.length > 0) {
                    await loadScriptsSequential(def.js);
                }

                // Dynamic scripts are loaded after DOMContentLoaded. Explicit
                // lifecycle hooks replace listeners that can no longer fire.
                if (name === 'chat') window.ChatSettings?.init?.();
                if (name === 'hud_core') window.Hud?.init?.();
                if (name === 'mdc') window.MdcTablet?.init?.();
                if (name === 'atm') window.AtmMachine?.init?.();

                loadedModules.add(name);
                const dt = Math.round(performance.now() - t0);
                if (window.SunsetDebug || window.__btrace) {
                    console.log(`[ModuleLoader] module [${name}] loaded in ${dt}ms`);
                }

                // 4. Drain queued messages for this module
                const queue = pendingModuleQueues.get(name);
                if (queue && queue.length > 0) {
                    pendingModuleQueues.delete(name);
                    for (const msg of queue) {
                        if (window.App && typeof window.App.dispatchDirect === 'function') {
                            window.App.dispatchDirect(msg);
                        } else if (typeof window.dispatchNuiMessage === 'function') {
                            window.dispatchNuiMessage(msg);
                        }
                    }
                }

                return true;
            } catch (err) {
                console.error(`[ModuleLoader] Error mounting module [${name}]:`, err);
                document.getElementById(`module-${name}`)?.remove();
                pendingModuleQueues.delete(name);
                if (window.App && typeof window.App.notify === 'function') {
                    window.App.notify('An interface failed to load. Please reopen it or reconnect.', 'error');
                }
                return false;
            } finally {
                activeLoadingPromises.delete(name);
            }
        })();

        activeLoadingPromises.set(name, promise);
        return promise;
    }

    function queueMessage(moduleName, data) {
        if (!pendingModuleQueues.has(moduleName)) {
            pendingModuleQueues.set(moduleName, []);
        }
        pendingModuleQueues.get(moduleName).push(data);
    }

    function isModuleLoaded(name) {
        return loadedModules.has(name);
    }

    function preload(name) {
        if (typeof window.requestIdleCallback === 'function') {
            window.requestIdleCallback(() => ensureModule(name));
        } else {
            setTimeout(() => ensureModule(name), 100);
        }
    }

    window.ModuleLoader = {
        registry: MODULE_REGISTRY,
        ensure: ensureModule,
        isLoaded: isModuleLoaded,
        preload: preload,
        queue: queueMessage,
    };
})();
