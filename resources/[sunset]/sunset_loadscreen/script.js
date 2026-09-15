const loadscreen = document.getElementById('loadscreen');
const pctEl = document.getElementById('loading-pct');
const taskEl = document.getElementById('loading-task');
const filesEl = document.getElementById('loading-files');
const tipTextEl = document.getElementById('tip-text');
const rpmContainer = document.getElementById('rpm-bar');

// [BOOT TRACE v2] ABSOLUTE epoch-ms timestamps (Date.now()) so every context
// (loadscreen CEF, core Lua, sunset_ui NUI) can be correlated on ONE timeline.
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

// [FREEZE WATCHDOG] rAF frame-gap detector for the loadscreen CEF.
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

// [A/B NOFX MODE]
function applyNofx() {
    btrace('nofx mode ON (animations/filters/big bg disabled)');
    document.body.classList.add('nofx');
}

const TOTAL_SEGMENTS = 25;

const TIPS = [
    'Stay in character at all times. Press G to open the quick interaction menu.',
    'Your voice range is shown on the HUD. Adjust voice settings in the pause menu.',
    'Vehicles left in traffic lanes may be impounded after server restarts.',
    'Press G near other players to open contextual interaction options.',
    'Need help? Use /report and describe the issue clearly.',
];

// ═══════════════════════════════════════════════════════════════
//  MONOTONIC PROGRESS MODEL
//  Real FiveM events are mapped to weighted phases. Progress NEVER
//  moves backwards. No fake simulation, no fake MB counter.
//
//  Phase weights:
//    0–70%  = FiveM asset load (loadProgress.loadFraction)
//    70–85% = resource init (startInitFunctionOrder / initFunctionInvoked)
//    85–95% = map load (performMapLoadFunction)
//    95–99% = waiting for NUI ready
//    100%   = handoff received
// ═══════════════════════════════════════════════════════════════

let displayedPct = 0;   // monotonic: never decreases
let initTotal = 0;
let initDone = 0;
let handoffReceived = false;

let segments = [];
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

// Monotonic: only move forward, never backwards.
function setProgress(pct, task) {
    const clamped = Math.min(100, Math.max(0, pct));
    if (clamped < displayedPct) return; // monotonic guard
    displayedPct = clamped;
    pctEl.innerHTML = `${Math.floor(displayedPct)}<span>%</span>`;
    if (task) taskEl.innerText = task;
    // No fake MB counter — show meaningful status only.
    filesEl.innerText = '';
    updateRpmBar(displayedPct);
}

function finishHandoff() {
    btrace('handoff received -> animations off');
    handoffReceived = true;
    // [CHEAP HANDOFF] Stop all animations, kill filters, simple opacity fade.
    // No blur, no slowPan — the compositor must not compete with world streaming.
    loadscreen.classList.add('is-handoff');
    setProgress(100, 'Entering session...');
    segments.forEach((seg) => {
        seg.classList.add('active');
        if (seg.classList.contains('is-redline')) seg.classList.add('redline');
    });
    // Short fade then done — the Lua side calls ShutdownLoadingScreenNui.
    setTimeout(() => {
        btrace('fade-out started');
        loadscreen.classList.add('fade-out');
        setTimeout(() => btrace('fade-out complete (still alive)'), 600);
    }, 90);
}

// ═══════════════════════════════════════════════════════════════
//  FIVE M EVENT HANDLERS — mapped to weighted phases
// ═══════════════════════════════════════════════════════════════

const handlers = {
    sunsetHandoff() {
        finishHandoff();
    },
    nofx() {
        applyNofx();
    },
    loadProgress(data) {
        // Real FiveM asset load: loadFraction 0..1 → 0..70%
        const frac = Number(data.loadFraction) || 0;
        setProgress(frac * 70, 'Loading game assets...');
    },
    startInitFunctionOrder(data) {
        initTotal = Number(data.count) || 1;
        initDone = 0;
        setProgress(70, 'Initializing resources...');
    },
    initFunctionInvoking(data) {
        if (data && data.name) taskEl.innerText = `${data.name}...`;
    },
    initFunctionInvoked() {
        initDone += 1;
        if (initTotal > 0) {
            // 70% + (initDone/initTotal) * 15% → 70..85%
            setProgress(70 + (initDone / initTotal) * 15);
        }
    },
    startDataFileEntries(data) {
        if (data && data.count) {
            taskEl.innerText = `Downloading ${data.count} files...`;
        }
    },
    onDataFileEntry(data) {
        if (data && data.name) taskEl.innerText = `${data.name}...`;
    },
    performMapLoadFunction(data) {
        if (data && data.idx !== undefined && data.count) {
            // 85% + (idx/count) * 10% → 85..95%
            const pct = 85 + (Number(data.idx) / Number(data.count)) * 10;
            setProgress(pct, 'Preparing world...');
        }
    },
};

window.addEventListener('message', (event) => {
    const data = event.data || {};
    const handler = handlers[data.eventName];
    if (handler) handler(data);
});

// Tips rotation
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

// Start at 0% with a real status. No fake simulation.
setProgress(0, 'Connecting to server...');
btrace('loadscreen ready, waiting for FiveM events');
