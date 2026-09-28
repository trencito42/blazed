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

    function formatMoney(amount) {
        if (amount === undefined || amount === null || Number.isNaN(Number(amount))) return '$0';
        return '$' + Math.floor(Number(amount) || 0).toLocaleString('en-US');
    }
    window.formatMoney = formatMoney;

    function notify(message, kind = 'info', duration = 4000) {
        window.App?.notify?.(message, kind, duration);
    }
    window.notify = notify;

    const ACTION_MODULE_MAP = {
        // Chat
        chatMessage: 'chat',
        chatToggle: 'chat',
        chatSetInput: 'chat',
        chatSuggestions: 'chat',
        showChat: 'chat',
        hideChat: 'chat',
        chatSettings: 'chat',
        chatClear: 'chat',
        chatUpdateSuggestions: 'chat',
        chatAddSuggestion: 'chat',
        chatRemoveSuggestion: 'chat',

        // HUD & Speedometer
        showHud: 'hud_core',
        hideHud: 'hud_core',
        hudChromeHide: 'hud_core',
        updateHud: 'hud_core',
        updateVehicleGauges: 'hud_core',
        updateVoice: 'hud_core',
        showTask: 'hud_core',
        hideTask: 'hud_core',
        vehicleHint: 'hud_core',
        hudEditToggle: 'hud_core',
        radarShow: 'radar',
        radarUpdate: 'radar',
        radarHide: 'radar',
        radarAlertShow: 'radar',
        radarAlertHide: 'radar',
        damageTaken: 'damage_indicators',

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
        showScoreboard: 'scoreboard',
        hideScoreboard: 'scoreboard',

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
        questLogShow: 'quests',
        questLogHide: 'quests',

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

    // Compatibility aliases used by the Lua resources. The module split must
    // route the real NUI protocol, including refresh/close acknowledgements.
    Object.assign(ACTION_MODULE_MAP, {
        shopShow: 'store', shopHide: 'store', shopBuyResult: 'store',
        fishingShopShow: 'store', fishingShopRefresh: 'store', fishingShopHide: 'store',
        truckerLaptopOpen: 'trucker',
        mdcRefresh: 'mdc', mdcUpdateCitizen: 'mdc', mdcUpdateVehicles: 'mdc', dispatch112Hide: 'mdc',
        factionPanelRefresh: 'factions', factionPanelsHide: 'factions', factionBrowseInline: 'factions', factionDirectoryDetail: 'factions',
        clanBrowseInline: 'clans', clanProfileShow: 'clans', clanPanelsHide: 'clans',
        businessOwnerUpdate: 'businesses', businessAdminUpdate: 'businesses',
        playerInteractionUpdate: 'player_interaction', playerInteractionPrompt: 'player_interaction',
        inventoryTradeState: 'inventory', inventoryTradeEnded: 'inventory', inventoryTradeCatalog: 'inventory',
        inventoryTradeInvite: 'trade', inventoryTradeInviteHide: 'trade', inventoryTradeInviteHold: 'trade',
        jobsShow: 'panels', jobsHide: 'panels', skillsHide: 'panels', helpHide: 'panels', helpShow: 'panels',
        ticketHide: 'panels', ticketReceiveHide: 'panels', serviceCallsUpdate: 'panels', serviceCallsHide: 'panels',
        documentsHide: 'panels', craftingUpdate: 'panels', craftingHide: 'panels', emotesHide: 'panels',
        garageHide: 'garage', fleetGarageHide: 'garage', propertyManageRefresh: 'properties', menuPropertyUpdate: 'menu',
        clothingHide: 'wardrobe', weaponAmmoUpdate: 'inventory', emoteWheelShow: 'inventory', emoteWheelHide: 'inventory', emoteWheelRelease: 'inventory', emoteWheelSelect: 'inventory',
        phoneCaptureAvatar: 'phone', taxiUpdate: 'phone', taxiEstimate: 'phone', taxiPickResult: 'phone',
        dealershipUpdate: 'dealership', appearanceUpdate: 'studio', appearanceSaving: 'studio', appearanceSaveFailed: 'studio',
        fishingShow: 'hud_core', fishingUpdate: 'hud_core', fishingHide: 'hud_core',
        policeOrderShow: 'hud_core', policeOrderHide: 'hud_core', announcementShow: 'hud_core', announcementHide: 'hud_core',
        taxiMeterShow: 'hud_core', taxiMeterUpdate: 'hud_core', taxiMeterHide: 'hud_core',
        jobObjectiveShow: 'hud_core', jobObjectiveUpdate: 'hud_core', jobObjectiveHide: 'hud_core',
        fuelPumpShow: 'hud_core', fuelPumpUpdate: 'hud_core', fuelPumpHide: 'hud_core', worldTooltipsSync: 'hud_core',
        licenseTestUpdate: 'licenses', jobShiftShow: 'jobcenter', jobShiftHide: 'jobcenter', jobSkillShow: 'jobcenter', jobSkillHide: 'jobcenter',
        courierUpdate: 'courier',
        casinoBlackjackUpdate: 'casino', casinoSlotsResult: 'casino', casinoRouletteResult: 'casino', casinoWheelResult: 'casino', casinoCashierUpdate: 'casino', casinoBarUpdate: 'casino',
        impoundUpdate: 'impound', racingHud: 'racing', racingHudHide: 'racing', racingCountdown: 'racing', racingGo: 'racing', racingFinished: 'racing',
        drugsUpdate: 'drugs', drugsBusy: 'drugs', drugsProgress: 'drugs', marriageProposal: 'marriage',
        warHudShow: 'clans', warHudUpdate: 'clans', warHudHide: 'clans', warArmoryShow: 'clans', warArmoryHide: 'clans',
        warScoreboardShow: 'clans', warScoreboardHide: 'clans', warEndShow: 'clans', warEndHide: 'clans', warRespawnShow: 'clans', warRespawnHide: 'clans',
        helpdeskRefresh: 'helpdesk', helpdeskHistory: 'helpdesk', helpdeskTicks: 'helpdesk', shieldHud: 'helpdesk', shieldHudHide: 'helpdesk',
    });

    const App = {
        currentScreen: 'gameplay',
        isGameplayReady: false,

        init() {
            // Send boot epoch calibration to Lua
            post('bootEpoch', { now: Date.now() });

            // Global Escape key handler
            window.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    this.handleEscape();
                }
            });

            // Dynamic fragments can mount after panels.js was evaluated. Own
            // all static close controls at shell level so every modal always
            // has a working mouse escape path, independent of load order.
            const closeActions = {
                'inventory-close': 'inventoryClose', 'trade-invite-decline': 'inventoryTradeInviteDecline',
                'store-close': 'shopClose', 'trucker-close': 'truckerLaptopClose', 'jobcenter-close': 'jobCenterClose',
                'atm-close': 'atmClose', 'mdc-close': 'mdcClose', 'ticket-close': 'ticketClose',
                'ticket-receive-close': 'ticketReceiveClose', 'servicecalls-close': 'serviceCallsClose',
                'jobs-panel-close': 'jobsClose', 'skills-close': 'skillsClose', 'help-close': 'helpClose',
                'garage-close': 'garageClose', 'fleet-garage-close': 'fleetGarageClose', 'properties-close': 'propertiesClose',
                'emotes-close': 'emotesClose', 'clothing-close': 'clothingClose', 'documents-close': 'documentsClose',
                'crafting-close': 'craftingClose', 'dealership-close': 'dealershipClose',
                'dispatch-112-cancel': 'close112Modal',
            };
            document.addEventListener('click', (event) => {
                const control = event.target?.closest?.('[id]');
                const callback = control && closeActions[control.id];
                if (!callback) return;
                event.preventDefault();
                event.stopImmediatePropagation();
                post(callback, {});
            }, true);
        },

        handleEscape() {
            // Check if 112 emergency dispatch modal is open
            if (!$('#dispatch-112-modal')?.classList.contains('hidden')) {
                if (window.MdcTablet?.close112) {
                    window.MdcTablet.close112();
                } else {
                    $('#dispatch-112-modal')?.classList.add('hidden');
                    post('close112Modal', {});
                }
                return;
            }

            // Check if any open modal/panel can be closed
            if (window.Menu && typeof Menu.close === 'function') Menu.close();
            if (window.Phone && typeof Phone.close === 'function') Phone.close();
            if (window.Panels && typeof Panels.closeActive === 'function') Panels.closeActive();
            if (window.MdcTablet && typeof MdcTablet.close === 'function') MdcTablet.close();
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

        nextFrame() {
            return new Promise((resolve) => requestAnimationFrame(() => resolve()));
        },

        idle() {
            return new Promise((resolve) => {
                if (typeof requestIdleCallback === 'function') requestIdleCallback(() => resolve(), { timeout: 200 });
                else setTimeout(resolve, 16);
            });
        },

        setTransition(visible, status) {
            const root = document.getElementById('transition-root');
            if (!root) return;
            if (status) document.getElementById('transition-status').textContent = status;
            root.classList.toggle('hidden', !visible);
            root.setAttribute('aria-hidden', visible ? 'false' : 'true');
            if (visible) {
                requestAnimationFrame(() => requestAnimationFrame(() => {
                    post('transitionRendered', { now: Date.now() });
                }));
            }
        },

        async onEnterGameplay() {
            this.isGameplayReady = true;
            // Cleanly hide any remaining entry/loading/character screens
            const appEl = document.getElementById('app');
            if (appEl) {
                appEl.classList.add('hidden');
                appEl.style.display = 'none';
            }
            document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));

            // Stage the essential modules; never parse HUD and chat in one frame.
            if (window.ModuleLoader) {
                await ModuleLoader.ensure('hud_core');
                document.getElementById('hud')?.classList.remove('hidden');
                window.Hud?.init?.();
                post('uiStageReady', { stage: 'hud', now: Date.now() });
                await this.nextFrame();
                await this.idle();
                await ModuleLoader.ensure('chat');
                post('uiStageReady', { stage: 'chat', now: Date.now() });
                await this.nextFrame();
            }
            this.setTransition(false);
            post('gameplayVisible', { now: Date.now() });
            if (window.ModuleLoader) {
                await this.idle();
                ModuleLoader.preload('radar');
                await this.nextFrame();
                ModuleLoader.preload('damage_indicators');
            }
        },

        async dispatchDirect(data) {
            const action = data.action;
            const payload = data.data && typeof data.data === 'object' ? data.data : data;

            // Global shell actions
            if (action === 'notify' || action === 'notification') {
                this.notify(payload.message || payload.text, payload.type || payload.kind, payload.duration || payload.dur);
                return;
            }
            if (action === 'progressBar' || action === 'progress') {
                this.progressBar(payload.label || payload.text, payload.duration || payload.dur);
                return;
            }
            if (action === 'cancelProgressBar') {
                this.cancelProgressBar();
                return;
            }
            if (action === 'transitionShow') {
                this.setTransition(true, payload.text || payload.status || 'Loading character...');
                return;
            }
            if (action === 'transitionHide') {
                this.setTransition(false);
                return;
            }
            if (action === 'enterGameplay' || action === 'playerSpawned' || action === 'playerReady') {
                this.onEnterGameplay();
                return;
            }
            if (action === 'hide') {
                this.currentScreen = 'gameplay';
                const appEl = document.getElementById('app');
                if (appEl) {
                    appEl.classList.add('hidden');
                    appEl.style.display = 'none';
                }
                document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
                return;
            }
            if (action === 'sessionForceClose') {
                document.querySelectorAll('.overlay-panel, .store-forza, .atm-modal, .mdc, .phone-device, .wardrobe-forza, .dealership-forza, .player-interaction, .appearance-studio').forEach((root) => {
                    root.classList.add('hidden');
                    root.setAttribute('aria-hidden', 'true');
                });
                document.body.className = document.body.className.split(/\s+/).filter((name) => !name.endsWith('-open') && name !== 'hud-chrome-hidden').join(' ');
                return;
            }
            if (action === 'tuningUiOpen') {
                document.body.classList.add('tuning-ui-open', 'hud-chrome-hidden');
                return;
            }
            if (action === 'tuningUiClose') {
                document.body.classList.remove('tuning-ui-open');
                if (!document.body.classList.contains('inventory-open') && !document.body.classList.contains('emote-wheel-open')) document.body.classList.remove('hud-chrome-hidden');
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
                        this.currentScreen = screen;

                        if (screen === 'characters' && window.Characters && typeof Characters.init === 'function') {
                            Characters.init(payload);
                        } else if (screen === 'create' && window.Characters && typeof Characters.initCreate === 'function') {
                            Characters.initCreate(payload);
                        } else if (screen === 'spawn' && window.SpawnSelector && typeof SpawnSelector.show === 'function') {
                            SpawnSelector.show(payload);
                        }
                    }
                } else if (screen === 'loading' || screen === 'handoff') {
                    this.setTransition(true, payload.holdText || payload.text || 'Loading character...');
                }
                return;
            }
            if (action === 'spawnSelectFailed') {
                window.SpawnSelector?.reset?.();
                return;
            }
            if (action === 'showHud') {
                document.getElementById('hud')?.classList.remove('hidden');
                window.Hud?.init?.();
                if (payload.layout) window.HudEditor?.apply?.(payload.layout);
                window.Hud?.update?.(payload);
                return;
            }

            if (action === 'hideHud') {
                document.getElementById('hud')?.classList.add('hidden');
                return;
            }
            if (action === 'updateHud') { window.Hud?.update?.(payload); return; }
            if (action === 'updateVehicleGauges') { window.ForzaSpeedometer?.updateGauges?.(payload); return; }
            if (action === 'updateVoice') { window.Hud?.updateVoice?.(payload); return; }
            if (action === 'showTask') { window.Hud?.showTask?.(payload); return; }
            if (action === 'hideTask') { window.Hud?.hideTask?.(); return; }
            if (action === 'vehicleHint') { window.Hud?.flashVehicleHint?.(payload); return; }
            if (action === 'hudEditToggle') { window.HudEditor?.toggle?.(); return; }
            if (action === 'hudChromeHide') {
                document.body.classList.toggle('hud-chrome-hidden', !payload.show);
                return;
            }

            if (action === 'chatToggle') { window.Chat?.toggle?.(payload.open, payload); return; }
            if (action === 'chatMessage') { window.Chat?.add?.(payload); return; }
            if (action === 'chatSetInput') {
                window.Chat?.setInput?.(payload.text, { fromHistory: payload.history === true });
                return;
            }
            if (action === 'chatSuggestions') { window.Chat?.setSuggestions?.(payload.suggestions); return; }
            if (action === 'chatClear') { window.Chat?.clear?.(); return; }

            if (action === 'radarShow') { window.RadarHud?.show?.(payload); return; }
            if (action === 'radarUpdate') { window.RadarHud?.update?.(payload); return; }
            if (action === 'radarHide') { window.RadarHud?.hide?.(); return; }
            if (action === 'radarAlertShow') { window.RadarAlert?.show?.(payload); return; }
            if (action === 'radarAlertHide') { window.RadarAlert?.hide?.(); return; }
            if (action === 'damageTaken') {
                window.DamageIndicators?.setActive?.(true);
                window.DamageIndicators?.takeDamage?.(payload.amount, payload.type, payload.direction);
                return;
            }

            if (action === 'questLogShow') { window.QuestLog?.show?.(payload); return; }
            if (action === 'questLogHide') { window.QuestLog?.hide?.(); return; }

            if (action === 'showScoreboard') { window.Scoreboard?.show?.(payload); return; }
            if (action === 'hideScoreboard') { window.Scoreboard?.hide?.(); return; }
            if (action === 'scoreboardShow') { window.Scoreboard?.show?.(payload); return; }
            if (action === 'scoreboardHide') { window.Scoreboard?.hide?.(); return; }

            if (action === 'menuShow') { window.Menu?.show?.(payload); return; }
            if (action === 'menuSetTab') { window.Menu?.setTab?.(payload.tab); return; }
            if (action === 'menuUpdate') { window.Menu?.update?.(payload); return; }
            if (action === 'menuAlert') { window.Menu?.showAlert?.(payload.message, payload.type || 'error'); return; }
            if (action === 'menuHide') { window.Menu?.hide?.(); return; }

            if (action === 'phoneShow') { window.Phone?.show?.(payload); return; }
            if (action === 'phoneUpdate') { window.Phone?.update?.(payload); return; }
            if (action === 'phoneHide') { window.Phone?.hide?.(); return; }

            if (action === 'inventoryShow') { window.Panels?.showInventory?.(payload); return; }
            if (action === 'inventoryHide') { window.Panels?.hideInventory?.(); return; }
            if (action === 'inventoryUpdate') { window.Panels?.showInventory?.(payload); return; }

            if (action === 'appearanceShow') { window.Panels?.showAppearance?.(payload); return; }
            if (action === 'appearanceUpdate') { window.Panels?.updateAppearance?.(payload); return; }
            if (action === 'appearanceCamera') { window.Panels?.setAppearanceCamera?.(payload.mode); return; }
            if (action === 'appearanceHide') { window.Panels?.hideAppearance?.(); return; }
            if (action === 'appearanceSaving') { window.Panels?.setAppearanceSaving?.(true); return; }
            if (action === 'appearanceSaveFailed') { window.Panels?.setAppearanceSaving?.(false); return; }

            // Feature modules expose small globals. Route every action in the
            // server/client NUI contract here after its module has mounted.
            switch (action) {
                case 'storeShow': case 'store247Show': window.StoreUI?.show?.(payload); return;
                case 'storeHide': window.StoreUI?.hide?.(); return;
                case 'shopShow': window.StoreUI?.show?.(payload); return;
                case 'shopHide': window.StoreUI?.hide?.(); return;
                case 'shopBuyResult': window.StoreUI?.onBuyResult?.(); return;
                case 'fishingShopShow': window.StoreUI?.show?.(payload); return;
                case 'fishingShopRefresh': window.StoreUI?.refreshItems?.(payload); return;
                case 'fishingShopHide': window.StoreUI?.hide?.(); return;
                case 'truckerLaptopOpen': window.TruckerLaptop?.open?.(payload); return;

                case 'atmShow': window.AtmMachine?.open?.(payload); return;
                case 'atmUpdate': window.AtmMachine?.update?.(payload); return;
                case 'atmHide': window.AtmMachine?.close?.(); return;
                case 'mdcShow': window.MdcTablet?.open?.(payload); return;
                case 'mdcRefresh': window.MdcTablet?.refresh?.(payload); return;
                case 'mdcUpdateCitizen': window.MdcTablet?.updateCitizen?.(payload.citizen); return;
                case 'mdcUpdateVehicles': window.MdcTablet?.updateVehicles?.(payload.vehicles); return;
                case 'mdcUpdate': window.MdcTablet?.updateCitizen?.(payload.lookup || payload.citizen); return;
                case 'mdcHide': window.MdcTablet?.hide?.(); return;
                case 'dispatch112Show': window.MdcTablet?.open112?.(payload); return;
                case 'dispatch112Hide': window.MdcTablet?.close112?.(false); return;

                case 'ticketShow': window.Panels?.showTicket?.(payload); return;
                case 'ticketHide': window.Panels?.hideTicket?.(); return;
                case 'ticketReceiveShow': window.Panels?.showTicketReceive?.(payload); return;
                case 'ticketReceiveHide': window.Panels?.hideTicketReceive?.(); return;
                case 'serviceCallsShow': case 'serviceCallsUpdate': window.Panels?.showServiceCalls?.(payload); return;
                case 'serviceCallsHide': window.Panels?.hideServiceCalls?.(); return;
                case 'jobsShow': window.Panels?.showJobsPanel?.(payload); return;
                case 'jobsHide': window.Panels?.hideJobsPanel?.(); return;
                case 'skillsShow': window.Panels?.showSkills?.(payload); return;
                case 'skillsHide': window.Panels?.hideSkills?.(); return;
                case 'helpShow': window.Panels?.showHelp?.(payload); return;
                case 'helpHide': window.Panels?.hideHelp?.(); return;
                case 'documentsShow': window.Panels?.showDocuments?.(payload); return;
                case 'documentsHide': window.Panels?.hideDocuments?.(); return;
                case 'craftingShow': window.Panels?.showCrafting?.(payload); return;
                case 'craftingUpdate': window.Panels?.updateCrafting?.(payload); return;
                case 'craftingHide': window.Panels?.hideCrafting?.(); return;

                case 'factionPanelShow': window.FactionPanels?.showDashboard?.(payload); return;
                case 'factionPanelRefresh': window.FactionPanels?.refreshDashboard?.(payload); return;
                case 'factionDirectoryShow': window.FactionPanels?.showDirectory?.(payload); return;
                case 'factionBrowseInline': window.FactionPanels?.showBrowseInline?.(payload); return;
                case 'factionDirectoryDetail': window.FactionPanels?.showDirectoryDetail?.(payload); return;
                case 'factionPanelHide': case 'factionPanelsHide': window.FactionPanels?.hide?.(); return;
                case 'clanPanelShow': window.ClanPanels?.showDashboard?.(payload); return;
                case 'clanDirectoryShow': window.ClanPanels?.showDirectory?.(payload); return;
                case 'clanBrowseInline': window.ClanPanels?.showBrowseInline?.(payload); return;
                case 'clanProfileShow': window.ClanPanels?.showClanProfile?.(payload); return;
                case 'clanPanelHide': case 'clanPanelsHide': window.ClanPanels?.hide?.(); return;
                case 'businessPanelShow': window.BusinessPanels?.showDashboard?.(payload); return;
                case 'businessPanelHide': window.BusinessPanels?.hide?.(); return;
                case 'businessOwnerUpdate': window.BusinessPanels?.updateOwnerPanel?.(payload); return;
                case 'businessAdminUpdate': window.BusinessPanels?.updateAdminPanel?.(payload); return;

                case 'playerInteractionShow': window.PlayerInteraction?.show?.(payload); return;
                case 'playerInteractionUpdate': window.PlayerInteraction?.update?.(payload); return;
                case 'playerInteractionHide': window.PlayerInteraction?.hide?.(); return;
                case 'playerInteractionPrompt': window.PlayerInteraction?.showPrompt?.(payload); return;
                case 'battlepassShow': window.Battlepass?.show?.(payload); return;
                case 'battlepassHide': window.Battlepass?.hide?.(); return;

                case 'inventoryTradeState': window.Panels?.showInventoryTrade?.(payload); return;
                case 'inventoryTradeEnded': window.Panels?.hideInventoryTrade?.(); return;
                case 'inventoryTradeCatalog': window.Panels?.showTradeAssetPicker?.(payload); return;
                case 'inventoryTradeInvite': window.TradeForza?.showInvite?.(payload); return;
                case 'inventoryTradeInviteHide': window.TradeForza?.hideInvite?.(); return;
                case 'inventoryTradeInviteHold': window.TradeForza?.setInviteHold?.(payload.key, payload.progress, payload.release); return;
                case 'tradeShow': window.TradeForza?.showTrade?.(payload); return;
                case 'tradeUpdate': window.TradeForza?.syncTradeState?.(payload); return;
                case 'tradeHide': window.TradeForza?.hideTrade?.(); return;
                case 'hotbarUpdate': window.HotbarUI?.update?.(payload); return;
                case 'hotbarShow': window.HotbarUI?.show?.(payload); return;
                case 'hotbarHide': window.HotbarUI?.hide?.(); return;

                case 'phoneCaptureAvatar': {
                    if (!payload.txd || !payload.characterId) return;
                    fetch(`https://nui-img/${payload.txd}/${payload.txd}`).then((response) => response.blob()).then((blob) => {
                        const reader = new FileReader();
                        reader.onloadend = () => post('phoneAvatarCaptured', { characterId: payload.characterId, avatar: reader.result });
                        reader.readAsDataURL(blob);
                    }).catch(() => {});
                    return;
                }
                case 'taxiUpdate': window.Phone?.updateTaxi?.(payload); return;
                case 'taxiEstimate': window.Phone?.setTaxiEstimate?.(payload); return;
                case 'taxiPickResult': window.Phone?.onTaxiPick?.(payload); return;

                case 'policeOrderShow': window.Overlays?.showPoliceOrder?.(payload); return;
                case 'policeOrderHide': window.Overlays?.hidePoliceOrder?.(); return;
                case 'announcementShow': window.Overlays?.showAnnouncement?.(payload); return;
                case 'announcementHide': window.Overlays?.hideAnnouncement?.(); return;
                case 'taxiMeterShow': window.Overlays?.showTaxiMeter?.(payload); return;
                case 'taxiMeterUpdate': window.Overlays?.updateTaxiMeter?.(payload); return;
                case 'taxiMeterHide': window.Overlays?.hideTaxiMeter?.(); return;
                case 'jobObjectiveShow': case 'jobObjectiveUpdate': window.Overlays?.showJobObjective?.(payload); return;
                case 'jobObjectiveHide': window.Overlays?.hideJobObjective?.(); return;
                case 'fishingShow': window.Fishing?.show?.(payload); return;
                case 'fishingUpdate': window.Fishing?.update?.(payload); return;
                case 'fishingHide': window.Fishing?.hide?.(); return;
                case 'fuelPumpShow': window.FuelPump?.show?.(payload); return;
                case 'fuelPumpUpdate': window.FuelPump?.update?.(payload); return;
                case 'fuelPumpHide': window.FuelPump?.hide?.(); return;
                case 'worldTooltipsSync': window.WorldTooltipLayer?.sync?.(payload); return;

                case 'licenseTestShow': window.LicenseTestHud?.show?.(payload); return;
                case 'licenseTestUpdate': window.LicenseTestHud?.update?.(payload); return;
                case 'licenseTestHide': window.LicenseTestHud?.hide?.(); return;
                case 'licenseQuizShow': window.LicenseQuiz?.show?.(payload); return;
                case 'licenseQuizHide': window.LicenseQuiz?.hide?.(); return;
                case 'jobCenterShow': window.Panels?.showJobCenter?.(payload); return;
                case 'jobCenterHide': window.Panels?.hideJobCenter?.(); return;
                case 'jobShiftShow': window.JobShift?.show?.(payload); return;
                case 'jobShiftHide': window.JobShift?.hide?.(); return;
                case 'jobSkillShow': window.JobShift?.showSkill?.(payload); return;
                case 'jobSkillHide': window.JobShift?.hideSkill?.(); return;
                case 'courierShow': window.Courier?.show?.(payload); return;
                case 'courierUpdate': window.Courier?.update?.(payload); return;
                case 'courierHide': window.Courier?.hide?.(); return;

                case 'garageShow':
                    if (window.Menu) window.Menu.show({ ...payload, initialTab: 'vehicle', soloMode: 'vehicle' });
                    else window.Panels?.showGarage?.(payload);
                    return;
                case 'garageHide': window.Panels?.hideGarage?.(); return;
                case 'fleetGarageShow': window.Panels?.showFleetGarage?.(payload); return;
                case 'fleetGarageHide': window.Panels?.hideFleetGarage?.(); return;
                case 'propertiesShow': window.Panels?.showProperties?.(payload); return;
                case 'propertiesHide': window.Panels?.hideProperties?.(); return;
                case 'propertyManageRefresh': window.PropertyUI?.refreshManageView?.(payload.propertyId, payload.properties); return;
                case 'propertyRenters': window.PropertyUI?.updateRenters?.(payload.propertyId, payload.renters); return;
                case 'menuPropertyUpdate': window.Menu?.updateProperties?.(payload); return;
                case 'emotesShow': window.Panels?.showEmotes?.(); return;
                case 'emotesHide': window.Panels?.hideEmotes?.(); return;
                case 'clothingShow': window.Panels?.showClothing?.(payload); return;
                case 'clothingHide': window.Panels?.hideClothing?.(); return;
                case 'wardrobeShow': window.WardrobeUI?.show?.(payload); return;
                case 'wardrobeUpdate': window.WardrobeUI?.update?.(payload); return;
                case 'wardrobeHide': window.WardrobeUI?.hide?.(); return;
                case 'weaponAmmoUpdate': window.HotbarUI?.renderWeaponAmmo?.(payload); return;
                case 'emoteWheelShow': window.HotbarUI?.showEmoteWheel?.(payload.emotes || []); return;
                case 'emoteWheelHide': window.HotbarUI?.hideEmoteWheel?.(); return;
                case 'emoteWheelRelease': window.HotbarUI?._releaseWheel?.(); return;
                case 'emoteWheelSelect': window.HotbarUI?.selectWheelFromGame?.(Number(payload.index)); return;

                case 'dealershipShow': window.DealershipUI?.show?.(payload); return;
                case 'dealershipUpdate': window.DealershipUI?.update?.(payload); return;
                case 'dealershipHide': window.DealershipUI?.hide?.(); return;
                case 'impoundShow': window.Impound?.show?.(payload); return;
                case 'impoundUpdate': window.Impound?.update?.(payload); return;
                case 'impoundHide': window.Impound?.hide?.(); return;
                case 'casinoShow': window.Casino?.show?.(payload); return;
                case 'casinoHide': window.Casino?.hide?.(); return;
                case 'casinoBlackjackUpdate': window.Casino?.updateBlackjack?.(payload); return;
                case 'casinoSlotsResult': window.Casino?.updateSlots?.(payload); return;
                case 'casinoRouletteResult': window.Casino?.updateRoulette?.(payload); return;
                case 'casinoWheelResult': window.Casino?.wheelResult?.(payload); return;
                case 'casinoCashierUpdate': window.Casino?.cashierUpdate?.(payload); return;
                case 'casinoBarUpdate': window.Casino?.barUpdate?.(payload); return;
                case 'racingShow': window.Racing?.show?.(payload); return;
                case 'racingHide': window.Racing?.hide?.(); return;
                case 'racingHud': window.Racing?.showHud?.(payload); return;
                case 'racingHudHide': window.Racing?.hideHud?.(); return;
                case 'racingCountdown': window.Racing?.showCountdown?.(payload.count ?? payload); return;
                case 'racingGo': window.Racing?.showGo?.(); return;
                case 'racingFinished': window.Racing?.showFinished?.(payload); return;
                case 'drugsShow': window.Drugs?.show?.(payload); return;
                case 'drugsHide': window.Drugs?.hide?.(); return;
                case 'drugsUpdate': window.Drugs?.update?.(payload); return;
                case 'drugsBusy': window.Drugs?.setBusy?.(payload.busy); return;
                case 'drugsProgress': window.Drugs?.showProgress?.(payload); return;
                case 'marriageProposal': window.Marriage?.showProposal?.(payload); return;
                case 'marriageHide': window.Marriage?.hide?.(); return;
                case 'helpdeskShow': case 'helpdeskRefresh': window.Helpdesk?.show?.(payload); return;
                case 'helpdeskHide': window.Helpdesk?.hide?.(); return;
                case 'helpdeskHistory': window.Helpdesk?.renderHistory?.(payload.rows || []); return;
                case 'helpdeskTicks': window.Helpdesk?.renderTicks?.(payload.ticks || []); return;
                case 'shieldHud': if (payload.enabled !== false) window.ShieldWidget?.show?.(payload); return;
                case 'shieldHudHide': window.ShieldWidget?.hide?.(); return;
                case 'warHudShow': window.WarUI?.showHud?.(payload); return;
                case 'warHudUpdate': window.WarUI?.updateHud?.(payload); return;
                case 'warHudHide': window.WarUI?.hideHud?.(); return;
                case 'warArmoryShow': window.WarUI?.showArmory?.(payload); return;
                case 'warArmoryHide': window.WarUI?.hideArmory?.(); return;
                case 'warScoreboardShow': window.WarUI?.showScoreboard?.(payload); return;
                case 'warScoreboardHide': window.WarUI?.hideScoreboard?.(); return;
                case 'warEndShow': window.WarUI?.showEnd?.(payload); return;
                case 'warEndHide': window.WarUI?.hideEnd?.(); return;
                case 'warRespawnShow': window.WarUI?.showRespawn?.(payload.seconds || 5); return;
                case 'warRespawnHide': window.WarUI?.hideRespawn?.(); return;
            }

            // Legacy window handler routing
            const legacyEvent = new CustomEvent(`sunset:ui:${action}`, { detail: payload });
            window.dispatchEvent(legacyEvent);

            // Directly invoke module functions if bound on window
            if (window.Chat && action.startsWith('chat') && typeof window.Chat[action] === 'function') {
                window.Chat[action](payload);
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
                const loaded = await ModuleLoader.ensure(targetModule);
                if (!loaded) post('uiModuleFailed', { module: targetModule, action });
            }
        } else {
            App.dispatchDirect(data);
        }
    });

    document.addEventListener('DOMContentLoaded', () => {
        App.init();
    });
})();
