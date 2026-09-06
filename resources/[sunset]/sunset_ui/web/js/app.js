const App = {
    currentScreen: null,
    data: {},
};
window.App = App;

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

function post(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
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

function notify(message, type = 'info', duration = 4000) {
    const container = $('#notifications');
    if (!container) return;
    const safeType = ['info', 'success', 'warning', 'error'].includes(type) ? type : 'info';
    const labels = {
        info: 'NOTICE',
        success: 'CONFIRMED',
        warning: 'ATTENTION',
        error: 'ALERT',
    };
    const el = document.createElement('div');
    el.className = `notification notification--${safeType}`;
    el.setAttribute('role', safeType === 'error' ? 'alert' : 'status');
    const signal = document.createElement('span');
    signal.className = 'notification__signal';
    signal.setAttribute('aria-hidden', 'true');
    const body = document.createElement('div');
    body.className = 'notification__body';
    const title = document.createElement('strong');
    title.className = 'notification__title';
    title.textContent = labels[safeType];
    const copy = document.createElement('span');
    copy.className = 'notification__message';
    copy.textContent = String(message ?? '');
    body.append(title, copy);
    el.append(signal, body);
    container.appendChild(el);

    const maxVisible = 5;
    while (container.children.length > maxVisible) {
        container.firstElementChild?.remove();
    }

    setTimeout(() => {
        el.classList.add('is-leaving');
        setTimeout(() => el.remove(), 280);
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
    return '$' + amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

// NUI message handler
window.addEventListener('message', (event) => {
    const { action, screen, data, message, type, duration, label } = event.data;

    switch (action) {
        case 'show':
            showApp(true);
            showHud(false);
            App.data = data || {};
            if (screen === 'auth') {
                showScreen('auth');
                if (window.Panels) Panels.showAuth();
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

        case 'pauseState':
            document.body.classList.toggle('game-paused', Boolean(data?.paused));
            break;

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
            if (window.Chat) Chat.setInput((data || event.data.data)?.text);
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
        case 'shopShow':
            if (window.Panels) Panels.showShop(data || event.data.data);
            break;
        case 'shopHide':
            if (window.Panels) Panels.hideShop();
            break;
        case 'atmShow':
            if (window.Panels) Panels.showAtm();
            break;
        case 'atmHide':
            if (window.Panels) Panels.hideAtm();
            break;
        case 'mdcShow':
            if (window.Panels) Panels.showMdc(data || event.data.data);
            break;
        case 'mdcUpdate':
            if (window.Panels) Panels.updateMdcLookup((data || event.data.data)?.lookup);
            break;
        case 'mdcHide':
            if (window.Panels) Panels.hideMdc();
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
            if (window.FactionPanels) FactionPanels.showDashboard(data || event.data.data);
            break;
        case 'factionDirectoryShow':
            if (window.FactionPanels) FactionPanels.showDirectory(data || event.data.data);
            break;
        case 'factionPanelsHide':
            if (window.FactionPanels) FactionPanels.hide();
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
        case 'clanPanelsHide':
            if (window.ClanPanels) ClanPanels.hide();
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
        case 'radarShow':
            if (window.RadarHud) RadarHud.show(data || event.data.data);
            break;
        case 'radarUpdate':
            if (window.RadarHud) RadarHud.update(data || event.data.data);
            break;
        case 'radarHide':
            if (window.RadarHud) RadarHud.hide();
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
    const qa = new URLSearchParams(window.location.search).get('qa');
    if (qa === 'spawn') {
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
            avatar: 'assets/logo.png', jobId: 'fisherman', job: 'Fisherman',
            jobGradeLabel: 'Angler', jobSalary: 120, completedTasks: 17,
            careerEarnings: 28400, combinedSkillLevels: 4,
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
