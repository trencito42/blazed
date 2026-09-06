const fill = document.getElementById('progress-fill');
const percent = document.getElementById('progress-percent');
const statusText = document.getElementById('status-text');
const loadscreen = document.getElementById('loadscreen');

const STATUS_MESSAGES = [
    'Connecting to server instance...',
    'Downloading map assets...',
    'Loading Sunset custom vehicles...',
    'Initializing UI systems...',
    'Fetching character data...',
    'Synchronizing weather protocols...',
    'Awaiting game state...',
];

let current = 0;
let simTimer = null;

function setProgress(value, status) {
    current = Math.min(100, Math.max(0, value));
    fill.style.width = `${current}%`;
    percent.textContent = `${Math.floor(current)}%`;
    if (status) statusText.textContent = status;

    const msgIndex = Math.min(STATUS_MESSAGES.length - 1, Math.floor((current / 100) * STATUS_MESSAGES.length));
    if (!status && STATUS_MESSAGES[msgIndex]) {
        statusText.textContent = STATUS_MESSAGES[msgIndex];
    }
}

function startSimulation() {
    clearInterval(simTimer);
    simTimer = setInterval(() => {
        if (current >= 88) return;
        let next = current + Math.random() * 2.2;
        if (Math.random() > 0.82) next -= 0.8;
        setProgress(next);
    }, 320);
}

window.addEventListener('message', (e) => {
    const data = e.data;
    if (data.eventName === 'sunsetHandoff') {
        clearInterval(simTimer);
        simTimer = null;
        setProgress(100, 'Welcome to Sunset Roleplay...');
        loadscreen.classList.add('is-handoff');
        setTimeout(() => loadscreen.classList.add('fade-out'), 260);
        return;
    }
    if (data.eventName === 'loadProgress') {
        clearInterval(simTimer);
        simTimer = null;
        setProgress((data.loadFraction || 0) * 100, 'Loading game assets...');
    }
});

const blockSelect = (event) => {
    event.preventDefault();
    return false;
};

document.addEventListener('selectstart', blockSelect, true);
document.addEventListener('dragstart', blockSelect, true);
document.addEventListener('copy', blockSelect, true);
window.addEventListener('keydown', (event) => {
    const key = String(event.key || '').toLowerCase();
    if ((event.ctrlKey || event.metaKey) && (key === 'a' || key === 'c' || key === 'x')) {
        event.preventDefault();
        event.stopPropagation();
    }
}, true);

setProgress(1);
startSimulation();
