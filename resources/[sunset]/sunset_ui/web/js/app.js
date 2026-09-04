const App = {
    currentScreen: null,
    data: {},
};

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
    const el = document.createElement('div');
    el.className = `notification notification--${safeType}`;
    el.setAttribute('role', safeType === 'error' ? 'alert' : 'status');
    const signal = document.createElement('span');
    signal.className = 'notification__signal';
    const body = document.createElement('div');
    body.className = 'notification__body';
    const title = document.createElement('strong');
    title.className = 'notification__title';
    title.textContent = safeType === 'error' ? 'SYSTEM ERROR' : safeType === 'warning' ? 'ATTENTION' : safeType === 'success' ? 'CONFIRMED' : 'SYSTEM MESSAGE';
    const copy = document.createElement('span');
    copy.className = 'notification__message';
    copy.textContent = String(message ?? '');
    body.append(title, copy);
    el.append(signal, body);
    container.appendChild(el);

    setTimeout(() => {
        el.style.opacity = '0';
        el.style.transform = 'translateX(40px)';
        el.style.transition = 'all 0.3s ease';
        setTimeout(() => el.remove(), 300);
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
                LoadingScreen.start(data);
            }
            break;

        case 'hide':
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
            const app = $('#app');
            const transitionMs = Math.max(250, Number(data?.duration) || 800);
            if (app) {
                app.style.setProperty('--enter-duration', `${transitionMs}ms`);
                app.classList.add('app--enter-game');
                setTimeout(() => showApp(false), transitionMs);
            }
            break;
        }

        case 'updateHud':
            if (window.Hud) Hud.update(data || event.data.data);
            break;

        case 'showScoreboard':
            if (window.Scoreboard) Scoreboard.show(event.data.data || data);
            break;

        case 'hideScoreboard':
            if (window.Scoreboard) Scoreboard.hide();
            $('#hud')?.classList.remove('scoreboard-open');
            break;

        case 'chatToggle':
            if (window.Chat) Chat.toggle(data?.open);
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
            if (window.Panels) Panels.showJobsBrowser(data || event.data.data);
            break;
        case 'jobsHide':
            if (window.Panels) Panels.hideJobsBrowser();
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
        case 'policeOrderShow':
            if (window.Overlays) Overlays.showPoliceOrder(data || event.data.data);
            break;
        case 'policeOrderHide':
            if (window.Overlays) Overlays.hidePoliceOrder();
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
        case 'jobsShow':
            if (window.Panels) Panels.showJobsPanel(data || event.data.data);
            break;
        case 'jobsHide':
            if (window.Panels) Panels.hideJobsPanel();
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
            if (window.Panels) {
                Panels.hideAuth();
                showApp(false);
            }
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

// Loading screen helper
const LoadingScreen = {
    start(data) {
        const fill = $('#loading-fill');
        const text = $('#loading-text');
        const steps = data?.steps || [
            { progress: 30, text: 'Connecting to server...' },
            { progress: 60, text: 'Loading character...' },
            { progress: 90, text: 'Preparing world...' },
            { progress: 100, text: 'Ready!' },
        ];

        let i = 0;
        const next = () => {
            if (i >= steps.length) return;
            const step = steps[i++];
            fill.style.width = step.progress + '%';
            text.textContent = step.text;
            setTimeout(next, data?.stepDelay || 600);
        };
        next();
    },
};

// Close character screens on ESC (not menu/chat)
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
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
