const loadscreen = document.getElementById('loadscreen');
const pctEl = document.getElementById('loading-pct');
const taskEl = document.getElementById('loading-task');
const filesEl = document.getElementById('loading-files');
const tipTextEl = document.getElementById('tip-text');
const rpmContainer = document.getElementById('rpm-bar');

// [BOOT TRACE v2] ABSOLUTE epoch-ms timestamps (Date.now()) so every context
// (loadscreen CEF, core Lua, sunset_ui NUI) can be correlated on ONE timeline.
// Lua side calibrates to the same epoch via sunset_ui's nuiEpoch handshake.
const BOOT_T0 = Date.now();
function btrace(stage, extra) {
    try {
        console.log(`[BOOT ${Date.now()} (+${Date.now() - BOOT_T0}ms)] loadscreen: ${stage}${extra ? ' | ' + extra : ''}`);
    } catch (_) { /* console unavailable */ }
}
btrace('script start');
window.addEventListener('error', (e) => {
    btrace('JS ERROR', `${e.message} @ ${e.filename}:${e.lineno}`);
});

// [FREEZE WATCHDOG] rAF frame-gap detector for the loadscreen CEF: a gap
// > 300ms means this window stopped rendering (main thread blocked).
(function frameWatchdog() {
    let last = performance.now();
    function frame() {
        const now = performance.now();
        const gap = now - last;
        last = now;
        if (gap > 300) btrace('CEF FRAME GAP', `${Math.round(gap)}ms frozen`);
        requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
})();

// [A/B NOFX MODE] Client Lua sends {eventName:'nofx'} when convar
// sv_sunset_nofx=1: kills every animation/filter and swaps the big bg for a
// flat color, so we can measure how much of the freeze is compositor work.
function applyNofx() {
    btrace('nofx mode ON (animations/filters/big bg disabled)');
    document.body.classList.add('nofx');
}

const TOTAL_SEGMENTS = 25;
const TASKS = [
    'Downloading audio packages',
    'Loading custom vehicles',
    'Syncing player data',
    'Preparing map assets',
    'Validating server connection',
];

const TIPS = [
    'Stay in character at all times. Press G to open the quick interaction menu.',
    'Your voice range is shown on the HUD. Adjust voice settings in the pause menu.',
    'Vehicles left in traffic lanes may be impounded after server restarts.',
    'Press G near other players to open contextual interaction options.',
    'Need help? Use /report and describe the issue clearly.',
];

let segments = [];
let currentPct = 0;
let simTimer = null;
let useRealProgress = false;
let initTotal = 0;
let initDone = 0;

for (let i = 0; i < TOTAL_SEGMENTS; i++) {
    const segment = document.createElement('div');
    segment.className = 'rpm-segment';
    if (i >= TOTAL_SEGMENTS - 3) segment.classList.add('is-redline');
    rpmContainer.appendChild(segment);
}
segments = [...document.querySelectorAll('.rpm-segment')];

function updateRpmBar(pct) {
    const segmentsToLight = Math.floor((pct / 100) * TOTAL_SEGMENTS);
    segments.forEach((seg, idx) => {
        if (idx < segmentsToLight) {
            seg.classList.add('active');
            if (seg.classList.contains('is-redline')) seg.classList.add('redline');
        } else {
            seg.classList.remove('active', 'redline');
        }
    });
}

function fileLabel(pct) {
    if (pct >= 90) return 'COMPLETE';
    const mbLoaded = Math.floor(pct * 14.5);
    return `${mbLoaded} MB / 1450 MB`;
}

function taskLabel(pct) {
    const taskIdx = Math.min(TASKS.length - 1, Math.floor((pct / 100) * TASKS.length));
    return `${TASKS[taskIdx]}...`;
}

function setProgress(pct, task, files) {
    currentPct = Math.min(100, Math.max(0, pct));
    pctEl.innerHTML = `${Math.floor(currentPct)}<span>%</span>`;
    taskEl.innerText = task || taskLabel(currentPct);
    if (files !== undefined) filesEl.innerText = files;
    else filesEl.innerText = fileLabel(currentPct);
    updateRpmBar(currentPct);
}

function finishHandoff() {
    btrace('handoff received -> animations off');
    clearTimeout(simTimer);
    simTimer = null;
    // [A/B NOFX] kill every animation/filter BEFORE the compositor competes
    // with the incoming NUI + world streaming.
    if (document.body.classList.contains('nofx')) {
        btrace('nofx: skipping segment animation, flat fade');
    }
    setProgress(100, 'Entering session...', '');
    segments.forEach((seg) => {
        seg.classList.add('active');
        if (seg.classList.contains('is-redline')) seg.classList.add('redline');
    });
    loadscreen.classList.add('is-handoff');
    setTimeout(() => {
        btrace('fade-out started');
        loadscreen.classList.add('fade-out');
        setTimeout(() => btrace('fade-out complete (still alive)'), 600);
    }, 90);
}

function startSimulation() {
    if (useRealProgress) return;
    function tick() {
        if (useRealProgress || currentPct >= 88) return;
        let jump = Math.random() * 2.5;
        if (Math.random() > 0.82) jump -= 0.8;
        setProgress(currentPct + jump);
        simTimer = setTimeout(tick, Math.random() * 150 + 50);
    }
    simTimer = setTimeout(tick, 500);
}

const handlers = {
    sunsetHandoff() {
        useRealProgress = true;
        finishHandoff();
    },
    nofx() {
        applyNofx();
    },
    loadProgress(data) {
        useRealProgress = true;
        clearTimeout(simTimer);
        simTimer = null;
        setProgress((data.loadFraction || 0) * 100, 'Loading game assets...');
    },
    startInitFunctionOrder(data) {
        useRealProgress = true;
        clearTimeout(simTimer);
        simTimer = null;
        initTotal = Number(data.count) || 1;
        initDone = 0;
    },
    initFunctionInvoking(data) {
        useRealProgress = true;
        if (data && data.name) taskEl.innerText = `${data.name}...`;
    },
    initFunctionInvoked() {
        useRealProgress = true;
        initDone += 1;
        const pct = initTotal > 0 ? (initDone / initTotal) * 100 : currentPct;
        setProgress(pct);
    },
    startDataFileEntries(data) {
        useRealProgress = true;
        if (data && data.count) {
            taskEl.innerText = `Downloading ${data.count} files...`;
        }
    },
    onDataFileEntry(data) {
        useRealProgress = true;
        if (data && data.name) taskEl.innerText = `${data.name}...`;
    },
    performMapLoadFunction(data) {
        useRealProgress = true;
        if (data && data.idx !== undefined && data.count) {
            const pct = (Number(data.idx) / Number(data.count)) * 100;
            setProgress(pct, 'Loading map data...');
        }
    },
};

window.addEventListener('message', (event) => {
    const data = event.data || {};
    const handler = handlers[data.eventName];
    if (handler) handler(data);
});

let tipIdx = 0;
setInterval(() => {
    tipTextEl.style.opacity = 0;
    setTimeout(() => {
        tipIdx = (tipIdx + 1) % TIPS.length;
        tipTextEl.innerText = TIPS[tipIdx];
        tipTextEl.style.opacity = 1;
    }, 400);
}, 6000);

document.addEventListener('selectstart', (event) => event.preventDefault(), true);
document.addEventListener('dragstart', (event) => event.preventDefault(), true);
document.addEventListener('copy', (event) => event.preventDefault(), true);

setProgress(1);
startSimulation();
