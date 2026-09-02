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
    const el = document.createElement('div');
    el.className = `notification notification--${type}`;
    el.textContent = message;
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
            if (window.Hud) Hud.update(hudData);
            break;

        case 'hideHud':
            showHud(false);
            break;

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

        case 'menuShow':
            if (window.Menu) Menu.show(data || event.data.data);
            break;

        case 'menuUpdate':
            if (window.Menu) Menu.update(data || event.data.data);
            break;

        case 'menuHide':
            if (window.Menu) Menu.hide();
            break;

        case 'notify':
            notify(message, type, duration);
            break;

        case 'progress':
            progressBar(label, duration);
            break;
    }
});

// Loading screen helper
const LoadingScreen = {
    start(data) {
        const fill = $('#loading-fill');
        const text = $('#loading-text');
        const steps = data?.steps || [
            { progress: 30, text: 'Se conectează la server...' },
            { progress: 60, text: 'Se încarcă personajul...' },
            { progress: 90, text: 'Pregătim lumea...' },
            { progress: 100, text: 'Gata!' },
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
    const app = $('#app');
    if (app && !app.classList.contains('hidden')) {
        post('close');
    }
});
