/* ═══════════════════════════════════════════════════════════════════
   SUNSETMP — Modular UI Core Shell (app.js)
   Clean action routing, on-demand module dispatching, and core runtime.
   ═══════════════════════════════════════════════════════════════════ */

(function () {
    'use strict';

    const $ = (sel) => document.querySelector(sel);
    const $$ = (sel) => document.querySelectorAll(sel);
    window.$ = $;
    window.$$ = $$;

    function post(action, data = {}) {
        const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : '';
        if (!resource) return Promise.resolve({ ok: true, qa: true, action, data });
        return fetch(`https://${resource}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => ({}));
    }
    window.post = post;

    const ACTION_MODULE_MAP = {
        // Chat
        chatMessage: 'chat',
        chatOpen: 'chat',
        chatClose: 'chat',
        showChat: 'chat',
        hideChat: 'chat',
        chatSettings: 'chat',
        chatClear: 'chat',
        chatUpdateSuggestions: 'chat',
        chatAddSuggestion: 'chat',
        chatRemoveSuggestion: 'chat',

        // HUD & Speedometer
        showHud: 'hud',
        hideHud: 'hud',
        hudUpdate: 'hud',
        updateHud: 'hud',
        speedometerUpdate: 'hud',
        hudEditor: 'hud',
        hudVoice: 'hud',
        hudVitals: 'hud',
        hudMoney: 'hud',
        hudWanted: 'hud',
        radarUpdate: 'hud',
        damageIndicator: 'hud',

        // Inventory & Hotbar
        inventoryShow: 'inventory',
        inventoryHide: 'inventory',
        inventoryUpdate: 'inventory',
        hotbarUpdate: 'inventory',
        hotbarShow: 'inventory',
        hotbarHide: 'inventory',

        // Trade
        tradeShow: 'trade',
        tradeHide: 'trade',
        tradeUpdate: 'trade',
        tradeInvitation: 'trade',

        // Menu (M)
        menuShow: 'menu',
        menuHide: 'menu',
        menuUpdate: 'menu',
        vehicleMenuShow: 'menu',

        // Phone
        phoneShow: 'phone',
        phoneHide: 'phone',
        phoneUpdate: 'phone',
        phoneIncomingCall: 'phone',
        phoneCallState: 'phone',
        phoneMessage: 'phone',

        // MDC Tablet
        mdcShow: 'mdc',
        mdcHide: 'mdc',
        mdcUpdate: 'mdc',
        dispatch112Show: 'mdc',

        // Factions
        factionPanelShow: 'factions',
        factionPanelHide: 'factions',
        factionDirectoryShow: 'factions',
        factionUpdate: 'factions',

        // Clans
        clanPanelShow: 'clans',
        clanPanelHide: 'clans',
        clanDirectoryShow: 'clans',
        clanUpdate: 'clans',
        clanWarShow: 'clans',

        // Businesses
        businessPanelShow: 'businesses',
        businessPanelHide: 'businesses',
        businessUpdate: 'businesses',

        // Properties / Housing
        propertiesShow: 'properties',
        propertiesHide: 'properties',
        propertyManageRefresh: 'properties',
        propertyRenters: 'properties',

        // Dealership
        dealershipShow: 'dealership',
        dealershipHide: 'dealership',
        dealershipUpdate: 'dealership',

        // Wardrobe / Clothing
        wardrobeShow: 'wardrobe',
        wardrobeHide: 'wardrobe',
        wardrobeUpdate: 'wardrobe',
        clothingShow: 'wardrobe',
        clothingHide: 'wardrobe',

        // ATM
        atmShow: 'atm',
        atmHide: 'atm',
        atmUpdate: 'atm',
        fleecaShow: 'atm',

        // 24/7 Store
        storeShow: 'store',
        storeHide: 'store',
        store247Show: 'store',

        // Trucker
        truckerShow: 'trucker',
        truckerHide: 'trucker',

        // Fishing
        fishingShopShow: 'fishing',
        fishingHudShow: 'fishing',
        fishingHudUpdate: 'fishing',

        // Jobcenter
        jobCenterShow: 'jobcenter',
        jobCenterHide: 'jobcenter',

        // Garage
        garageShow: 'garage',
        garageHide: 'garage',
        fleetGarageShow: 'garage',

        // Scoreboard
        scoreboardShow: 'scoreboard',
        scoreboardHide: 'scoreboard',

        // Helpdesk
        helpdeskShow: 'helpdesk',
        helpdeskHide: 'helpdesk',
        helpShow: 'helpdesk',

        // Battlepass
        battlepassShow: 'battlepass',
        battlepassHide: 'battlepass',

        // Casino
        casinoShow: 'casino',
        casinoHide: 'casino',

        // Racing
        racingShow: 'racing',
        racingHide: 'racing',

        // Drugs
        drugsShow: 'drugs',
        drugsHide: 'drugs',

        // Marriage
        marriageShow: 'marriage',
        marriageHide: 'marriage',

        // Impound
        impoundShow: 'impound',
        impoundHide: 'impound',

        // Player Interaction
        playerInteractionShow: 'player_interaction',
        playerInteractionHide: 'player_interaction',

        // Licenses
        licenseTestShow: 'licenses',
        licenseTestHide: 'licenses',
        licenseQuizShow: 'licenses',
        licenseQuizHide: 'licenses',

        // Quests
        questsShow: 'quests',
        questsHide: 'quests',

        // Courier
        courierShow: 'courier',
        courierHide: 'courier',

        // Appearance Studio
        appearanceShow: 'studio',
        appearanceHide: 'studio',
        appearanceCamera: 'studio',

        // Characters & Spawn
        charactersShow: 'characters',
        spawnShow: 'characters',
        spawnHide: 'characters',

        // Generic Overlay Panels
        ticketShow: 'panels',
        ticketReceiveShow: 'panels',
        documentsShow: 'panels',
        serviceCallsShow: 'panels',
        skillsShow: 'panels',
        emotesShow: 'panels',
        craftingShow: 'panels',
        fuelPumpShow: 'panels',
    };

    const App = {
        currentScreen: 'gameplay',
        isGameplayReady: false,

        init() {
            // Send boot epoch calibration to Lua
            post('bootEpoch', { epoch: performance.now() });

            // Global Escape key handler
            window.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    this.handleEscape();
                }
            });
        },

        handleEscape() {
            // Check if any open modal/panel can be closed
            if (window.Menu && typeof Menu.close === 'function') Menu.close();
            if (window.Phone && typeof Phone.close === 'function') Phone.close();
            if (window.Panels && typeof Panels.closeActive === 'function') Panels.closeActive();
            if (window.MDC && typeof MDC.close === 'function') MDC.close();
            if (window.ClanPanels && typeof ClanPanels.close === 'function') ClanPanels.close();
            if (window.WardrobeShop && typeof WardrobeShop.close === 'function') WardrobeShop.close();
        },

        notify(message, kind = 'info', duration = 4000) {
            const root = document.getElementById('notifications-root');
            if (!root) return;

            const toast = document.createElement('div');
            toast.className = `notification-toast toast--${kind}`;

            const iconMap = {
                success: '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>',
                error: '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>',
                warning: '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>',
                info: '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>',
            };

            toast.innerHTML = `
                <span class="toast-icon">${iconMap[kind] || iconMap.info}</span>
                <span class="toast-message">${String(message || '')}</span>
            `;

            root.appendChild(toast);

            setTimeout(() => {
                toast.classList.add('toast--hiding');
                setTimeout(() => toast.remove(), 300);
            }, duration);
        },

        progressBar(label, duration = 3000) {
            const root = document.getElementById('progress-root');
            const labelEl = document.getElementById('progress-label');
            const fillEl = document.getElementById('progress-fill');
            if (!root || !fillEl) return;

            if (labelEl) labelEl.textContent = label || 'In progress...';
            fillEl.style.transition = 'none';
            fillEl.style.width = '0%';
            root.classList.remove('hidden');

            requestAnimationFrame(() => {
                fillEl.style.transition = `width ${duration}ms linear`;
                fillEl.style.width = '100%';
            });

            if (this._progressTimeout) clearTimeout(this._progressTimeout);
            this._progressTimeout = setTimeout(() => {
                root.classList.add('hidden');
                post('progressComplete', {});
            }, duration + 50);
        },

        cancelProgressBar() {
            const root = document.getElementById('progress-root');
            if (root) root.classList.add('hidden');
            if (this._progressTimeout) clearTimeout(this._progressTimeout);
        },

        onEnterGameplay() {
            this.isGameplayReady = true;
            // Cleanly hide any remaining entry/loading/character screens
            const appEl = document.getElementById('app');
            if (appEl) {
                appEl.classList.add('hidden');
                appEl.style.display = 'none';
            }
            document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));

            // Eagerly mount core essential gameplay modules: HUD and Chat
            if (window.ModuleLoader) {
                ModuleLoader.ensure('hud').then(() => {
                    if (window.HUD && typeof HUD.show === 'function') HUD.show({});
                });
                ModuleLoader.ensure('chat');
            }
        },

        async dispatchDirect(data) {
            const action = data.action;
            const payload = data.data || {};

            // Global shell actions
            if (action === 'notify' || action === 'notification') {
                this.notify(payload.message || payload.text, payload.type || payload.kind, payload.duration || payload.dur);
                return;
            }
            if (action === 'progressBar') {
                this.progressBar(payload.label || payload.text, payload.duration || payload.dur);
                return;
            }
            if (action === 'cancelProgressBar') {
                this.cancelProgressBar();
                return;
            }
            if (action === 'enterGameplay' || action === 'playerSpawned' || action === 'playerReady') {
                this.onEnterGameplay();
                return;
            }
            if (action === 'hide') {
                const appEl = document.getElementById('app');
                if (appEl) {
                    appEl.classList.add('hidden');
                    appEl.style.display = 'none';
                }
                document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
                return;
            }
            if (action === 'show') {
                const screen = data.screen;
                if (screen === 'characters' || screen === 'create' || screen === 'spawn') {
                    if (window.ModuleLoader) {
                        await ModuleLoader.ensure('characters');
                        const appEl = document.getElementById('app');
                        if (appEl) {
                            appEl.classList.remove('hidden');
                            appEl.style.display = '';
                        }
                        document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
                        const screenEl = document.getElementById(`screen-${screen}`);
                        if (screenEl) screenEl.classList.remove('hidden');

                        if (screen === 'characters' && window.Characters && typeof Characters.init === 'function') {
                            Characters.init(payload);
                        } else if (screen === 'create' && window.Characters && typeof Characters.initCreate === 'function') {
                            Characters.initCreate(payload);
                        } else if (screen === 'spawn' && window.Spawn && typeof Spawn.init === 'function') {
                            Spawn.init(payload);
                        }
                    }
                } else if (screen === 'loading' || screen === 'handoff') {
                    // Minimal loading placeholder if needed
                }
                return;
            }
            if (action === 'showHud') {
                if (window.ModuleLoader) {
                    await ModuleLoader.ensure('hud');
                }
                if (window.HUD && typeof HUD.show === 'function') HUD.show(payload);
                return;
            }

            // Legacy window handler routing
            const legacyEvent = new CustomEvent(`sunset:ui:${action}`, { detail: payload });
            window.dispatchEvent(legacyEvent);

            // Directly invoke module functions if bound on window
            if (window.Chat && action.startsWith('chat') && typeof window.Chat[action] === 'function') {
                window.Chat[action](payload);
            } else if (window.HUD && action.startsWith('hud') && typeof window.HUD[action] === 'function') {
                window.HUD[action](payload);
            } else if (window.Menu && action.startsWith('menu') && typeof window.Menu[action] === 'function') {
                window.Menu[action](payload);
            } else if (window.Phone && action.startsWith('phone') && typeof window.Phone[action] === 'function') {
                window.Phone[action](payload);
            } else if (window.Panels && typeof window.Panels.handleAction === 'function') {
                window.Panels.handleAction(action, payload);
            }
        }
    };

    window.App = App;

    // Root Message Dispatcher
    window.addEventListener('message', async (event) => {
        const data = event.data || {};
        const action = data.action;
        if (!action) return;

        const targetModule = ACTION_MODULE_MAP[action];

        if (targetModule && window.ModuleLoader) {
            if (ModuleLoader.isLoaded(targetModule)) {
                App.dispatchDirect(data);
            } else {
                ModuleLoader.queue(targetModule, data);
                await ModuleLoader.ensure(targetModule);
            }
        } else {
            App.dispatchDirect(data);
        }
    });

    document.addEventListener('DOMContentLoaded', () => {
        App.init();
    });
})();
