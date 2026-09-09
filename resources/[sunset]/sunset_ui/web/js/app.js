const App = {
    currentScreen: null,
    data: {},
};
window.App = App;

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

function post(action, data = {}) {
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : '';
    if (!resource) return Promise.resolve({ ok: true, qa: true, action, data });
    return fetch(`https://${resource}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

const ENTRY_BACKGROUNDS = {
    auth: 'assets/bg_login.webp?v=6',
    handoff: 'assets/bg.webp?v=6',
    loading: 'assets/bg.webp?v=6',
    spawn: 'assets/bg.webp?v=6',
    default: 'assets/bg.webp?v=6',
};
let entryBackgroundRequest = 0;

function entryBackgroundLayers() {
    const app = $('#app');
    if (!app) return [];
    let layers = Array.from(app.children).filter((child) => child.classList.contains('app-bg'));
    if (layers.length === 1) {
        const secondary = layers[0].cloneNode(false);
        secondary.removeAttribute('src');
        secondary.classList.remove('is-active');
        layers[0].after(secondary);
        layers.push(secondary);
    }
    if (layers[0] && !layers.some((layer) => layer.classList.contains('is-active'))) {
        layers[0].classList.add('is-active');
    }
    return layers;
}

async function setEntryBackground(screenName) {
    const desired = ENTRY_BACKGROUNDS[screenName] || ENTRY_BACKGROUNDS.default;
    const layers = entryBackgroundLayers();
    if (layers.length < 2) return;
    const active = layers.find((layer) => layer.classList.contains('is-active')) || layers[0];
    if (active.dataset.entrySource === desired) return;

    const request = ++entryBackgroundRequest;
    const next = layers.find((layer) => layer !== active) || layers[1];
    next.dataset.entrySource = desired;
    const load = (src) => new Promise((resolve) => {
        const complete = () => resolve(next.naturalWidth > 0);
        next.onload = complete;
        next.onerror = () => resolve(false);
        next.src = src;
        if (next.complete) complete();
    });
    let loaded = await load(desired);
    if (!loaded && request === entryBackgroundRequest) {
        next.dataset.entrySource = ENTRY_BACKGROUNDS.default;
        loaded = await load(ENTRY_BACKGROUNDS.default);
    }
    if (request !== entryBackgroundRequest) return;
    if (!loaded) return;
    next.onload = null;
    next.onerror = null;
    requestAnimationFrame(() => {
        next.classList.add('is-active');
        active.classList.remove('is-active');
    });
}

function preloadEntryBackgrounds() {
    Object.values(ENTRY_BACKGROUNDS).forEach((src) => {
        const image = new Image();
        image.decoding = 'async';
        image.src = src;
    });
}

function setBrandLogo(img) {
    if (!img) return;
    img.src = 'assets/logoblaze.svg?v=1';
}

function showScreen(name) {
    $$('.screen').forEach(s => s.classList.add('hidden'));
    const screen = $(`#screen-${name}`);
    if (screen) {
        screen.classList.remove('hidden');
        App.currentScreen = name;
        const app = $('#app');
        if (app) app.dataset.screen = name;
    }
    setEntryBackground(name);
    if (window.AuthLoading) {
        if (name === 'loading') {
            AuthLoading.armSafety(120000);
        } else {
            AuthLoading.clearSafety();
        }
    }
}

function showApp(visible) {
    const app = $('#app');
    if (visible) {
        app.classList.remove('app--enter-game');
        app.classList.remove('hidden');
    } else {
        app.classList.add('hidden');
    }
}

function showHud(visible) {
    const hud = $('#hud');
    if (visible) {
        hud.classList.remove('hidden');
    } else {
        hud.classList.add('hidden');
    }
}

const NOTIFY_META = {
    info: {
        label: 'NOTICE',
        icon: '<circle cx="12" cy="12" r="9"/><path d="M12 8v1M12 11v5"/>',
    },
    success: {
        label: 'CONFIRMED',
        icon: '<path d="M5 12l5 5L19 7"/>',
    },
    warning: {
        label: 'ATTENTION',
        icon: '<path d="M12 3 2 21h20L12 3z"/><path d="M12 9v5M12 17h.01"/>',
    },
    error: {
        label: 'ALERT',
        icon: '<path d="M6 6l12 12M18 6L6 18"/>',
    },
};

function notifyIconSvg(type) {
    const meta = NOTIFY_META[type] || NOTIFY_META.info;
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 'notification__icon');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '2');
    svg.setAttribute('stroke-linecap', 'square');
    svg.setAttribute('aria-hidden', 'true');
    svg.innerHTML = meta.icon;
    return svg;
}

function notify(message, type = 'info', duration = 4000) {
    const container = $('#notifications');
    if (!container) return;
    const safeType = ['info', 'success', 'warning', 'error'].includes(type) ? type : 'info';
    const meta = NOTIFY_META[safeType];

    const el = document.createElement('div');
    el.className = `notification notification--${safeType}`;
    el.setAttribute('role', safeType === 'error' ? 'alert' : 'status');

    const wrap = document.createElement('div');
    wrap.className = 'notification__wrap';

    const title = document.createElement('div');
    title.className = 'notification__title';
    title.textContent = meta.label;

    const copy = document.createElement('div');
    copy.className = 'notification__message';
    copy.textContent = String(message ?? '');

    wrap.append(title, copy);
    el.append(notifyIconSvg(safeType), wrap);
    container.appendChild(el);

    const maxVisible = 5;
    while (container.children.length > maxVisible) {
        container.firstElementChild?.remove();
    }

    setTimeout(() => {
        el.classList.add('is-leaving');
        setTimeout(() => el.remove(), 240);
    }, duration);
}

function progressBar(label, duration) {
    const progress = $('#progress');
    if (!progress) return;
    const fill = progress.querySelector('.progress__fill');
    const labelEl = progress.querySelector('.progress__label');

    labelEl.textContent = label;
    fill.style.width = '0%';
    fill.style.transition = 'none';
    progress.classList.remove('hidden');

    requestAnimationFrame(() => {
        fill.style.transition = `width ${duration}ms linear`;
        fill.style.width = '100%';
    });

    setTimeout(() => {
        progress.classList.add('hidden');
    }, duration);
}

function formatMoney(amount) {
    if (amount === undefined || amount === null || isNaN(Number(amount))) return '$0';
    const n = Math.floor(Number(amount) || 0);
    return '$' + n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

// NUI message handler
window.addEventListener('message', (event) => {
    const { action, screen, data, message, type, duration, label } = event.data;

    switch (action) {
        case 'show':
            showApp(true);
            showHud(false);
            App.data = data || {};
            if (screen !== 'menu' && window.Menu) Menu.hide();
            if (screen === 'auth') {
                showScreen('auth');
                if (window.Panels) Panels.showAuth(data || {});
                return;
            }
            showScreen(screen);
            if (screen === 'characters' && window.Characters) {
                Characters.init(data);
            }
        if (screen === 'create' && window.Characters) {
                Characters.initCreate(data);
            }
            if (screen === 'loading') {
                if (window.LoadingScreen) LoadingScreen.start(data);
            }
            if (screen === 'spawn' && window.SpawnSelector) {
                SpawnSelector.show(data || {});
            }
            break;

        case 'spawnSelectFailed':
            if (window.SpawnSelector) SpawnSelector.reset();
            break;

        case 'hide':
            if (window.LoadingScreen) LoadingScreen.reset();
            if (window.AuthLoading) {
                AuthLoading._pending = false;
                AuthLoading.clearSafety();
            }
            showApp(false);
            break;

        case 'showHud':
            showHud(true);
            const hudData = data || {};
            if (hudData.playerId && window.Scoreboard) Scoreboard.myId = hudData.playerId;
            if (window.HudEditor && hudData.layout) HudEditor.apply(hudData.layout);
            if (window.Hud) Hud.update(hudData);
            break;

        case 'hideHud':
            showHud(false);
            break;

        case 'pauseState': {
            const paused = Boolean(data?.paused);
            document.body.classList.toggle('game-paused', paused);
            if (paused) {
                if (window.Phone) Phone.hide();
                if (window.Menu && !$('#menu')?.classList.contains('hidden')) {
                    Menu.hide();
                    post('menuClose');
                }
                if (window.Panels) {
                    if (!$('#inventory')?.classList.contains('hidden')) {
                        Panels.hideInventory();
                        post('inventoryClose');
                    }
                }
            }
            break;
        }

        case 'enterGameplay': {
            if (window.AuthLoading) {
                AuthLoading._pending = false;
                AuthLoading.clearSafety();
            }
            const app = $('#app');
            const transitionMs = Math.max(250, Number(data?.duration) || 800);
            const fadeOut = () => {
                if (!app) {
                    showApp(false);
                    return;
                }
                app.style.setProperty('--enter-duration', `${transitionMs}ms`);
                app.classList.add('app--enter-game');
                setTimeout(() => {
                    if (window.LoadingScreen) LoadingScreen.reset();
                    showApp(false);
                }, transitionMs);
            };
            if (window.LoadingScreen) {
                LoadingScreen.finish(fadeOut, 350);
            } else {
                fadeOut();
            }
            break;
        }

        case 'updateHud':
            if (window.Hud) Hud.update(data || event.data.data);
            break;

        case 'vehicleHint':
            if (window.Hud) Hud.flashVehicleHint(data || event.data.data || {});
            break;

        case 'showScoreboard':
            if (window.Scoreboard) Scoreboard.show(event.data.data || data);
            break;

        case 'hideScoreboard':
            if (window.Scoreboard) Scoreboard.hide();
            $('#hud')?.classList.remove('scoreboard-open');
            break;

        case 'chatToggle':
            if (window.Chat) Chat.toggle(data?.open, data || event.data.data);
            break;

        case 'chatMessage':
            if (window.Chat) Chat.add(data || event.data.data);
            break;

        case 'chatSetInput':
            if (window.Chat) {
                const row = data || event.data.data || {};
                Chat.setInput(row.text, { fromHistory: row.history === true });
            }
            break;

        case 'menuShow':
            if (window.Menu) Menu.show(data || event.data.data);
            break;

        case 'menuSetTab':
            if (window.Menu) Menu.setTab((data || event.data.data)?.tab);
            break;

        case 'menuUpdate':
            if (window.Menu) Menu.update(data || event.data.data);
            break;

        case 'menuAlert':
            if (window.Menu) Menu.showAlert((data || event.data.data)?.message, (data || event.data.data)?.type || 'error');
            break;

        case 'menuHide':
            if (window.Menu) Menu.hide();
            break;

        case 'inventoryShow':
            if (window.Panels) Panels.showInventory(data || event.data.data);
            break;
        case 'inventoryUpdate':
            if (window.Panels) Panels.showInventory(data || event.data.data);
            break;
        case 'inventoryHide':
            if (window.Panels) Panels.hideInventory();
            break;
        case 'inventoryTradeState':
            if (window.Panels) Panels.showInventoryTrade(data || event.data.data || {});
            break;
        case 'inventoryTradeEnded':
            if (window.Panels) Panels.hideInventoryTrade();
            break;
        case 'shopShow':
            if (window.Panels) Panels.showShop(data || event.data.data);
            break;
        case 'shopHide':
            if (window.Panels) Panels.hideShop();
            break;
        case 'atmShow':
            if (window.AtmMachine) AtmMachine.open(data || event.data.data || {});
            else if (window.Panels) Panels.showAtm(data || event.data.data);
            break;
        case 'atmHide':
            if (window.AtmMachine) AtmMachine.close();
            if (window.Panels) Panels.hideAtm();
            break;
        case 'atmUpdate':
            if (window.AtmMachine) AtmMachine.update(data || event.data.data || {});
            if (window.Panels && Panels.updateAtm) Panels.updateAtm(data || event.data.data);
            break;
        case 'mdcShow':
            if (window.MdcTablet) MdcTablet.open(data || event.data.data);
            else if (window.Panels) Panels.showMdc(data || event.data.data);
            break;
        case 'mdcRefresh':
            if (window.MdcTablet) MdcTablet.refresh(data || event.data.data);
            break;
        case 'mdcUpdateCitizen':
            if (window.MdcTablet) MdcTablet.updateCitizen((data || event.data.data)?.citizen);
            break;
        case 'mdcUpdateVehicles':
            if (window.MdcTablet) MdcTablet.updateVehicles((data || event.data.data)?.vehicles);
            break;
        case 'mdcUpdate':
            if (window.MdcTablet) MdcTablet.updateCitizen((data || event.data.data)?.lookup || (data || event.data.data)?.citizen);
            else if (window.Panels) Panels.updateMdcLookup((data || event.data.data)?.lookup);
            break;
        case 'mdcHide':
            if (window.MdcTablet) MdcTablet.hide();
            else if (window.Panels) Panels.hideMdc();
            break;
        case 'dispatch112Show':
            if (window.MdcTablet) MdcTablet.open112(data || event.data.data);
            break;
        case 'dispatch112Hide':
            // This message is already the Lua acknowledgement. Do not post a
            // second close callback or NUI focus will be cleared repeatedly.
            if (window.MdcTablet) MdcTablet.close112(false);
            break;
        case 'ticketShow':
            if (window.Panels) Panels.showTicket(data || event.data.data);
            break;
        case 'ticketHide':
            if (window.Panels) Panels.hideTicket();
            break;
        case 'ticketReceiveShow':
            if (window.Panels) Panels.showTicketReceive(data || event.data.data);
            break;
        case 'ticketReceiveHide':
            if (window.Panels) Panels.hideTicketReceive();
            break;
        case 'serviceCallsShow':
            if (window.Panels) Panels.showServiceCalls(data || event.data.data);
            break;
        case 'serviceCallsUpdate':
            if (window.Panels) Panels.showServiceCalls(data || event.data.data);
            break;
        case 'serviceCallsHide':
            if (window.Panels) Panels.hideServiceCalls();
            break;
        case 'jobsShow':
            if (window.Panels) Panels.showJobsPanel(data || event.data.data);
            break;
        case 'jobsHide':
            if (window.Panels) Panels.hideJobsPanel();
            break;
        case 'skillsShow':
            if (window.Panels) Panels.showSkills(data || event.data.data);
            break;
        case 'skillsHide':
            if (window.Panels) Panels.hideSkills();
            break;
        case 'helpShow':
            if (window.Panels) Panels.showHelp(data || event.data.data);
            break;
        case 'helpHide':
            if (window.Panels) Panels.hideHelp();
            break;
        case 'factionPanelShow':
            if (window.FactionPanels) {
                try { FactionPanels.showDashboard(data || event.data.data); }
                catch (err) { console.error('[FactionPanels] showDashboard failed', err); post('factionPanelsClose'); }
            } else {
                console.error('[FactionPanels] factions.js not loaded');
                post('factionPanelsClose');
            }
            break;
        case 'factionDirectoryShow':
            if (window.FactionPanels) {
                try { FactionPanels.showDirectory(data || event.data.data); }
                catch (err) { console.error('[FactionPanels] showDirectory failed', err); post('factionPanelsClose'); }
            } else {
                console.error('[FactionPanels] factions.js not loaded');
                post('factionPanelsClose');
            }
            break;
        case 'factionPanelsHide':
            if (window.FactionPanels) FactionPanels.hide();
            document.body.classList.remove('faction-panels-open');
            break;
        case 'playerInteractionShow':
            if (window.PlayerInteraction) PlayerInteraction.show(data || event.data.data);
            break;
        case 'playerInteractionUpdate':
            if (window.PlayerInteraction) PlayerInteraction.update(data || event.data.data);
            break;
        case 'playerInteractionHide':
            if (window.PlayerInteraction) PlayerInteraction.hide();
            break;
        case 'battlepassShow':
            if (window.Battlepass) Battlepass.show(data || event.data.data);
            break;
        case 'battlepassHide':
            if (window.Battlepass) Battlepass.hide();
            break;
        case 'inventoryTradeInvite':
            if (window.Panels && Panels.showTradeInvite) Panels.showTradeInvite(data || event.data.data);
            break;
        case 'inventoryTradeInviteHide':
            if (window.Panels && Panels.hideTradeInvite) Panels.hideTradeInvite();
            break;
        case 'inventoryTradeInviteHold':
            if (window.Panels && Panels.setTradeInviteHold) Panels.setTradeInviteHold(data || event.data.data);
            break;
        case 'factionBrowseInline':
            if (window.FactionPanels) {
                try {
                    FactionPanels.showBrowseInline(data || event.data.data);
                } catch (err) {
                    console.error('[FactionPanels] showBrowseInline failed', err);
                }
            }
            break;
        case 'factionDirectoryDetail':
            if (window.FactionPanels) {
                try {
                    FactionPanels.showDirectoryDetail(data || event.data.data);
                } catch (err) {
                    console.error('[FactionPanels] showDirectoryDetail failed', err);
                }
            }
            break;
        case 'clanPanelShow':
            if (window.ClanPanels) {
                try {
                    if (!ClanPanels.showDashboard(data || event.data.data)) {
                        post('clanPanelsClose');
                    }
                } catch (err) {
                    console.error('[ClanPanels] showDashboard failed', err);
                    post('clanPanelsClose');
                }
            } else {
                console.error('[ClanPanels] clans.js not loaded');
                post('clanPanelsClose');
            }
            break;
        case 'clanDirectoryShow':
            if (window.ClanPanels) {
                try {
                    if (!ClanPanels.showDirectory(data || event.data.data)) {
                        post('clanPanelsClose');
                    }
                } catch (err) {
                    console.error('[ClanPanels] showDirectory failed', err);
                    post('clanPanelsClose');
                }
            } else {
                console.error('[ClanPanels] clans.js not loaded');
                post('clanPanelsClose');
            }
            break;
        case 'clanBrowseInline':
            if (window.ClanPanels) {
                try {
                    ClanPanels.showBrowseInline(data || event.data.data);
                } catch (err) {
                    console.error('[ClanPanels] showBrowseInline failed', err);
                }
            }
            break;
        case 'clanProfileShow':
            if (window.ClanPanels) {
                try {
                    ClanPanels.showClanProfile(data || event.data.data);
                } catch (err) {
                    console.error('[ClanPanels] showClanProfile failed', err);
                }
            }
            break;
        case 'clanPanelsHide':
            if (window.ClanPanels) ClanPanels.hide();
            document.body.classList.remove('clan-panels-open');
            break;
        case 'policeOrderShow':
            if (window.Overlays) Overlays.showPoliceOrder(data || event.data.data);
            break;
        case 'policeOrderHide':
            if (window.Overlays) Overlays.hidePoliceOrder();
            break;
        case 'announcementShow':
            if (window.Overlays) Overlays.showAnnouncement(data || event.data.data);
            break;
        case 'announcementHide':
            if (window.Overlays) Overlays.hideAnnouncement();
            break;
        case 'taxiMeterShow':
            if (window.Overlays) Overlays.showTaxiMeter(data || event.data.data);
            break;
        case 'taxiMeterUpdate':
            if (window.Overlays) Overlays.updateTaxiMeter(data || event.data.data);
            break;
        case 'taxiMeterHide':
            if (window.Overlays) Overlays.hideTaxiMeter();
            break;
        case 'jobObjectiveShow':
            if (window.Overlays) Overlays.showJobObjective(data || event.data.data);
            break;
        case 'jobObjectiveUpdate':
            if (window.Overlays) Overlays.updateJobObjective(data || event.data.data);
            break;
        case 'jobObjectiveHide':
            if (window.Overlays) Overlays.hideJobObjective();
            break;
        case 'fishingShow':
            if (window.Fishing) Fishing.show(data || event.data.data);
            break;
        case 'fishingUpdate':
            if (window.Fishing) Fishing.update(data || event.data.data);
            break;
        case 'fishingHide':
            if (window.Fishing) Fishing.hide();
            break;
        case 'licenseTestShow':
            if (window.LicenseTestHud) LicenseTestHud.show(data || event.data.data);
            break;
        case 'licenseTestUpdate':
            if (window.LicenseTestHud) LicenseTestHud.update(data || event.data.data);
            break;
        case 'licenseTestHide':
            if (window.LicenseTestHud) LicenseTestHud.hide();
            break;
        case 'licenseQuizShow':
            if (window.LicenseQuiz) LicenseQuiz.show(data || event.data.data);
            break;
        case 'licenseQuizHide':
            if (window.LicenseQuiz) LicenseQuiz.hide();
            break;
        case 'jobCreatorShow':
            if (window.JobCreator) JobCreator.show(data || event.data.data);
            break;
        case 'jobCreatorUpdate':
            if (window.JobCreator) JobCreator.update(data || event.data.data);
            break;
        case 'jobCreatorHide':
            if (window.JobCreator) JobCreator.hide();
            break;
        case 'jobCreatorPlacement':
            if (window.JobCreator) JobCreator.onPlacement((data || event.data.data)?.point);
            break;
        case 'jobShiftShow':
            if (window.JobShift) JobShift.show(data || event.data.data);
            break;
        case 'jobShiftHide':
            if (window.JobShift) JobShift.hide();
            break;
        case 'jobSkillShow':
            if (window.JobShift) JobShift.showSkill(data || event.data.data);
            break;
        case 'jobSkillHide':
            if (window.JobShift) JobShift.hideSkill();
            break;
        case 'radarShow':
            if (window.RadarHud) RadarHud.show(data || event.data.data);
            break;
        case 'radarUpdate':
            if (window.RadarHud) RadarHud.update(data || event.data.data);
            break;
        case 'radarHide':
            if (window.RadarHud) RadarHud.hide();
            break;
        case 'radarAlertShow':
            if (window.RadarAlert) RadarAlert.show(data || event.data.data);
            break;
        case 'radarAlertHide':
            if (window.RadarAlert) RadarAlert.hide();
            break;
        case 'courierShow':
            if (window.Courier) Courier.show(data || event.data.data);
            break;
        case 'courierUpdate':
            if (window.Courier) Courier.update(data || event.data.data);
            break;
        case 'courierHide':
            if (window.Courier) Courier.hide();
            break;
        case 'garageShow':
            if (window.Panels) Panels.showGarage(data || event.data.data);
            break;
        case 'garageHide':
            if (window.Panels) Panels.hideGarage();
            break;
        case 'fleetGarageShow':
            if (window.Panels) Panels.showFleetGarage(data || event.data.data);
            break;
        case 'fleetGarageHide':
            if (window.Panels) Panels.hideFleetGarage();
            break;
        case 'propertiesShow':
            if (window.Panels) Panels.showProperties(data || event.data.data);
            break;
        case 'propertiesHide':
            if (window.Panels) Panels.hideProperties();
            break;
        case 'propertyRenters':
            if (window.PropertyUI) PropertyUI.updateRenters(
                (data || event.data.data)?.propertyId,
                (data || event.data.data)?.renters,
            );
            break;
        case 'menuPropertyUpdate':
            if (window.Menu) Menu.updateProperties(data || event.data.data);
            break;
        case 'emotesShow':
            if (window.Panels) Panels.showEmotes();
            break;
        case 'emotesHide':
            if (window.Panels) Panels.hideEmotes();
            break;
        case 'clothingShow':
            if (window.Panels) Panels.showClothing(data || event.data.data);
            break;
        case 'clothingHide':
            if (window.Panels) Panels.hideClothing();
            break;

        case 'phoneShow':
            if (window.Phone) Phone.show(data || event.data.data);
            break;
        case 'phoneUpdate':
            if (window.Phone) Phone.update(data || event.data.data);
            break;
        case 'phoneHide':
            if (window.Phone) Phone.hide();
            break;
        case 'taxiUpdate':
            if (window.Phone) Phone.updateTaxi(data || event.data.data);
            break;
        case 'taxiEstimate':
            if (window.Phone) Phone.setTaxiEstimate(data || event.data.data);
            break;
        case 'taxiPickResult':
            if (window.Phone) Phone.onTaxiPick(data || event.data.data);
            break;
        case 'documentsShow':
            if (window.Panels) Panels.showDocuments(data || event.data.data);
            break;
        case 'documentsHide':
            if (window.Panels) Panels.hideDocuments();
            break;
        case 'jobCenterShow':
            if (window.Panels) Panels.showJobCenter(data || event.data.data);
            break;
        case 'jobCenterHide':
            if (window.Panels) Panels.hideJobCenter();
            break;
        case 'craftingShow':
            if (window.Panels) Panels.showCrafting(data || event.data.data);
            break;
        case 'craftingUpdate':
            if (window.Panels) Panels.updateCrafting(data || event.data.data);
            break;
        case 'craftingHide':
            if (window.Panels) Panels.hideCrafting();
            break;
        case 'dealershipShow':
        case 'dealershipUpdate':
            if (window.Panels) Panels.showDealership(data || event.data.data);
            break;
        case 'dealershipHide':
            if (window.Panels) Panels.hideDealership();
            break;
        case 'appearanceShow':
            showApp(false);
            showHud(false);
            $('#app')?.classList.add('hidden');
            if (window.Panels) Panels.showAppearance(data || event.data.data);
            break;
        case 'appearanceUpdate':
            if (window.Panels) Panels.updateAppearance(data || event.data.data);
            break;
        case 'appearanceCamera':
            if (window.Panels) Panels.setAppearanceCamera((data || event.data.data)?.camera);
            break;
        case 'appearanceHide':
            if (window.Panels) Panels.hideAppearance();
            break;
        case 'appearanceSaving':
            if (window.Panels) Panels.setAppearanceSaving(true);
            break;
        case 'appearanceSaveFailed':
            if (window.Panels) Panels.setAppearanceSaving(false);
            break;

        case 'authHide':
            if (window.Panels) Panels.hideAuth();
            // beginSubmit already selected loading. Preserve whichever newer
            // screen the character flow may have opened in the meantime.
            showApp(true);
            showHud(false);
            if (window.AuthLoading) AuthLoading._pending = false;
            break;

        case 'authError':
            if (window.AuthLoading) AuthLoading.reset();
            break;

        case 'authAccounts':
            if (window.AuthAccounts) AuthAccounts.update(data || event.data.data || {});
            break;

        case 'authCapturePortrait':
            if (window.AuthAccounts) AuthAccounts.capturePortrait(data || event.data.data || {});
            break;

        case 'authAccountFill':
            if (window.AuthAccounts) AuthAccounts.showForm(data || event.data.data || {});
            break;

        case 'authQuickLoginStart':
            if (window.AuthLoading) AuthLoading.beginSubmit();
            break;

        case 'authNeedsEmail':
            if (window.AuthEmail) AuthEmail.onNeedsEmail(data || event.data.data || {});
            break;

        case 'authEmailError':
            if (window.AuthEmail) AuthEmail.onError(data || event.data.data || {});
            break;

        case 'authEmailSaved':
            if (window.AuthEmail) AuthEmail.onSaved();
            break;

        case 'hudEditToggle':
            if (window.HudEditor) HudEditor.toggle();
            break;

        case 'notify':
            notify(message, type, duration);
            break;

        case 'progress':
            progressBar(label, duration);
            break;

        case 'fuelPumpShow':
            if (window.FuelPump) FuelPump.show(data || event.data.data);
            break;
        case 'fuelPumpUpdate':
            if (window.FuelPump) FuelPump.update(data || event.data.data);
            break;
        case 'fuelPumpHide':
            if (window.FuelPump) FuelPump.hide();
            break;
    }
});

document.addEventListener('keydown', (e) => {
    const key = String(e.key || '').toLowerCase();
    if (!(e.ctrlKey || e.metaKey) || key !== 'a') return;
    const tag = (e.target && e.target.tagName) || '';
    if (tag === 'INPUT' || tag === 'TEXTAREA' || e.target?.isContentEditable) return;
    e.preventDefault();
}, true);

// Close character screens on ESC (not menu/chat)
document.addEventListener('keydown', (e) => {
    const passModal = $('#battlepass-modal');
    if (passModal && !passModal.classList.contains('hidden') && e.key === 'Escape') {
        e.preventDefault();
        window.Battlepass?.close();
        return;
    }

    if (e.key !== 'Escape') return;
    if (['auth', 'loading', 'spawn'].includes(App.currentScreen)) return;
    const dealership = $('#dealership');
    if (dealership && !dealership.classList.contains('hidden')) {
        post('dealershipClose');
        return;
    }
    const app = $('#app');
    if (app && !app.classList.contains('hidden')) {
        post('close');
    }
});

// Local/browser visual QA only; FiveM never supplies this query parameter.
document.addEventListener('DOMContentLoaded', () => {
    preloadEntryBackgrounds();
    entryBackgroundLayers();
    document.querySelectorAll('.auth-brand__logo, .panel-logo, .studio-logo').forEach(setBrandLogo);
    const qa = new URLSearchParams(window.location.search).get('qa');
    if (qa === 'auth') {
        showApp(true);
        showScreen('auth');
        window.Panels?.showAuth({
            quickLogin: true,
            accounts: [
                { username: 'trencito', characterName: 'Trencito Blaze', level: 32, cash: 106209, bank: 5316, hasPassword: true },
                { username: 'stefan', characterName: 'Stefan Ionescu', level: 12, cash: 18450, bank: 42100, hasPassword: true },
                { username: 'tester', characterName: 'Alex Pop', level: 4, cash: 2350, bank: 8900, hasPassword: true },
            ],
        });
    } else if (qa === 'spawn') {
        showApp(true);
        showScreen('spawn');
        window.SpawnSelector?.show({ hasLastLocation: true });
    } else if (qa === 'menu') {
        window.Menu?.show({
            id: 2, cid: 14, name: 'Trencito', rank: 'PLAYER', level: 2,
            respectPoints: 37, respectRequired: 8, levelPrice: 5000,
            cash: 106209, bank: 5316, premium: 0, playtime: '39H 41M',
            lastLogin: 'TODAY', health: 100, armor: 0, hunger: 82, thirst: 74,
            stress: 6, vehicleCount: 1, propertyCount: 0, homeLabel: 'None',
            avatar: 'assets/logoblaze.svg?v=1', jobId: 'fisherman', job: 'Fisherman',
            jobGradeLabel: 'Angler', jobSalary: 120, completedTasks: 17,
            careerEarnings: 28400, combinedSkillLevels: 4,
        });
    } else if (qa === 'vehicles') {
        window.Menu?.show({
            id: 2, cid: 14, name: 'Trencito', rank: 'PLAYER', level: 12,
            soloMode: 'vehicle', initialTab: 'vehicle',
            cash: 106209, bank: 5316, premium: 0, playtime: '39H 41M',
            health: 100, armor: 0, hunger: 82, thirst: 74, stress: 6,
            vehicles: [
                { id: 1, plate: 'B77XOD', model: 'elegy', fuel: 85, engine: 950, body: 910, stored: 1, garage: 'Central', odometer: 12504.3 },
                { id: 2, plate: 'RO10AMG', model: 'baller', fuel: 32, engine: 450, body: 670, stored: 0, inWorld: true, isCurrentVehicle: true, odometer: 8231.8 },
                { id: 3, plate: 'DR1FT', model: 'sultan', fuel: 62, engine: 820, body: 740, stored: 0, parked_x: 100, parked_y: 100, odometer: 3412.1 },
            ],
        });
        window.Menu?.setTab('vehicle');
    } else if (qa === 'inventory' || qa === 'inventory-trade' || qa === 'trade' || qa === 'inventory-empty') {
        const isEmpty = qa === 'inventory-empty' || new URLSearchParams(window.location.search).get('nearby') === '0';
        window.Panels?.showInventory({
            cash: 106209,
            weight: 15.2,
            maxWeight: 30,
            items: [
                { id: 1, slot: 1, item: 'water', label: 'Bottled Water', count: 6, usable: true, icon: 'water_bottle' },
                { id: 2, slot: 2, item: 'bread', label: 'Sandwich', count: 3, usable: true, icon: 'bread' },
                { id: 3, slot: 3, item: 'phone', label: 'Smartphone', count: 1, usable: false, icon: 'phone' },
                { id: 4, slot: 8, item: 'weapon_pistol', label: 'Pistol', count: 1, usable: false, icon: 'weaponlicense' },
            ],
            nearbyPlayers: isEmpty ? [] : [
                { id: 2, name: 'Horja', distance: 1.2 },
                { id: 45, name: 'Alexandru Popa', distance: 2.4 },
            ],
        });
        if (qa === 'inventory-trade' || qa === 'trade') {
            window.Panels?.showInventoryTrade({
                active: true,
                target: { id: 2, name: 'Horja' },
                myOffer: [{ id: 1, item: 'water', label: 'Bottled Water', count: 1, icon: 'water_bottle' }],
                theirOffer: [{ id: 11, item: 'bread', label: 'Sandwich', count: 2, icon: 'bread' }],
                myAccepted: false,
                theirAccepted: false,
                countdown: 0,
            });
        }
    } else if (qa === 'trade-invite') {
        window.Panels?.showTradeInvite({
            requesterId: 2,
            requesterName: 'HORJA',
            timeout: 30,
        });
    } else if (qa === 'interaction') {
        window.PlayerInteraction?.show({
            target: {
                id: 45,
                name: 'Mihai Dobre',
                level: 12,
                faction: 'Civilian',
            },
            actions: [
                { id: 'trade', group: 'CIVILIAN', label: 'Propune Schimb (Trade)' },
                { id: 'give_cash', group: 'CIVILIAN', label: 'Oferă Bani Cash', input: { type: 'number', placeholder: '$ Sumă', min: 1, max: 50000 } },
                { id: 'show_id', group: 'CIVILIAN', label: 'Arată Buletinul' },
                { id: 'add_contact', group: 'CIVILIAN', label: 'Adaugă la Contacte' },
                { id: 'faction_invite', group: 'FACTION', label: 'Invită în Facțiune' },
                { id: 'cuff', group: 'POLICE', label: 'Cuff Suspect', danger: true },
                { id: 'frisk', group: 'POLICE', label: 'Search Player' },
            ]
        });
    } else if (qa === 'battlepass' || qa === 'missions') {
        window.Battlepass?.show();
        if (qa === 'missions') {
            window.Battlepass?.setTab('daily');
        }
    } else if (qa === 'faction') {
        window.FactionPanels?.showDashboard({
            faction: { id: 'police', label: 'Los Santos Police Department', description: 'Law enforcement and public safety.', type: 'law' },
            grade: 5,
            gradeLabel: 'Captain',
            duty: true,
            salary: 650,
            memberCount: 12,
            motd: 'Serve and protect.',
            report: { current: 8, required: 15 },
            members: [
                { id: 1, name: 'Trencito', grade: 6, gradeLabel: 'Chief', online: true, duty: true },
                { id: 2, name: 'Alexandru Popa', grade: 2, gradeLabel: 'Officer', online: true, duty: false },
            ],
            commands: [{ cmd: '/f [message]', desc: 'Faction radio' }, { cmd: '/mdc', desc: 'Open the department computer' }],
        });
    } else if (qa === 'factions') {
        window.FactionPanels?.showDirectory({
            factions: [
                { id: 'police', label: 'Los Santos Police Department', factionType: 'law_enforcement', leader: 'Ștefan XODO', online: 15, total: 42, recruiting: true, description: 'Servim și protejăm orașul Los Santos.' },
                { id: 'ems', label: 'Pillbox Medical (EMS)', factionType: 'ems', leader: 'Dr. Mihai', online: 8, total: 28, recruiting: true, description: 'Serviciu medical de urgență.' },
                { id: 'grove', label: 'Grove Street Families', type: 'illegal', leader: 'Sweet Johnson', online: 12, total: 18, recruiting: false, description: 'Controlăm zona de sud a orașului.' },
                { id: 'bennys', label: "Benny's Motorworks", factionType: 'mechanic', leader: 'Alexandru V.', online: 5, total: 15, recruiting: true, description: 'Service de tuning și reparații autorizat.' }
            ]
        });
    } else if (qa === 'clan') {
        window.ClanPanels?.showDashboard({
            inClan: true,
            clanId: 1,
            name: 'Sunset Syndicate',
            tag: 'SS',
            tagColor: '#ff9900',
            tagStyle: 'brackets',
            rank: 5,
            rankLabel: 'Lider Suprem',
            motd: 'Ședință sâmbătă la ora 21:00 la conac!',
            description: 'Organizație privată de elită.',
            memberCount: 12,
            maxMembers: 25,
            members: [
                { characterId: 1, name: 'Ștefan XODO', rank: 5, rankLabel: 'Lider Suprem', online: true, serverId: 1, leader: true },
                { characterId: 2, name: 'Alex Popescu', rank: 3, rankLabel: 'Locotenent', online: true, serverId: 14, leader: false },
                { characterId: 3, name: 'Mihai Dobre', rank: 1, rankLabel: 'Recrut', online: false, serverId: null, leader: false }
            ],
            permissions: {
                leader: true,
                officer: true,
                invite: true,
                kick: true,
                motd: true,
                settings: true,
                promote: true,
                rankLabels: true,
                warn: true,
                dissolve: true,
                leave: true
            }
        });
    } else if (qa === 'clans') {
        window.ClanPanels?.showDirectory({
            clans: [
                { id: 1, name: 'Sunset Syndicate', tag: 'SS', tagColor: '#ff9900', tagStyle: 'brackets', leader: 'Ștefan XODO', online: 8, total: 12, maxMembers: 25, description: 'Organizație privată de elită.' },
                { id: 2, name: 'Ghost Riders', tag: 'GR', tagColor: '#00ffcc', tagStyle: 'prefix_dot', leader: 'Kane', online: 4, total: 18, maxMembers: 25, description: 'Club de motocicliști și tuning.' },
                { id: 3, name: 'Apex Predators', tag: 'APEX', tagColor: '#ff3366', tagStyle: 'brackets', leader: 'Viper', online: 10, total: 25, maxMembers: 25, description: 'Echipă competitivă.' }
            ]
        });
    } else if (qa === 'vehiclehud') {
        showApp(true);
        $('#hud')?.classList.remove('hidden');
        if (typeof Hud !== 'undefined') Hud.update({
            inVehicle: true, speed: 141, rpm: 0.72, fuel: 63, engine: 870,
            odometer: 12504.3, engineOn: true, locked: false, seatbelt: true,
            vehicleClass: 7, showFuel: true, showOdometer: true,
        });
    } else if (qa === 'jobs') {
        window.Panels?.showJobsPanel({
            currentJob: { id: 'fisherman', label: 'Fisherman' },
            currentJobLabel: 'Fisherman',
            session: { jobId: 'fisherman', state: 'ACTIVE' },
            jobs: [
                { id: 'courier', label: 'Courier', salary: 110, description: 'Pick up packages and deliver them on foot.', progress: { level: 1, xp: 20, xpToNext: 100, completedTasks: 2 } },
                { id: 'fisherman', label: 'Fisherman', salary: 120, description: 'Fish at coastal spots and sell your catch.', progress: { level: 4, xp: 72, xpToNext: 100, completedTasks: 17 } },
                { id: 'garbage', label: 'Garbage Collector', salary: 130, description: 'Collect bins on city routes and unload at the depot.', progress: { level: 1, xp: 0, xpToNext: 100, completedTasks: 0 } },
                { id: 'mechanic', label: 'Roadside Mechanic', salary: 140, description: 'Respond to service calls and repair vehicles.', progress: { level: 1, xp: 0, xpToNext: 100, completedTasks: 0 } },
                { id: 'trucker', label: 'Trucker', salary: 150, description: 'Haul cargo across San Andreas.', progress: { level: 1, xp: 0, xpToNext: 100, completedTasks: 0 } },
            ],
        });
    }
});
