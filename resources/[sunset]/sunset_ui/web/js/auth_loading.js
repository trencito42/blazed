const TOTAL_SEGMENTS = 25;

const LOADING_TIPS = [
    'Stay in character at all times. Press G to open the quick interaction menu.',
    'Your voice range is shown on the HUD. Adjust voice settings in the pause menu.',
    'Vehicles left in traffic lanes may be impounded after server restarts.',
    'Press G near other players to open contextual interaction options.',
    'Need help? Use /report and describe the issue clearly.',
];

function createForzaLoadUI(screenId) {
    const root = () => document.getElementById(screenId);

    return {
        _interval: null,
        _finishTimer: null,
        _tipTimer: null,
        _segments: [],
        _tipIdx: 0,

        _els() {
            const el = root();
            if (!el) return {};
            return {
                pct: el.querySelector('.forza-load-pct'),
                status: el.querySelector('.forza-load-status'),
                files: el.querySelector('.forza-load-files'),
                rpmBar: el.querySelector('.forza-load-rpm'),
                tip: el.querySelector('.forza-load-tip'),
            };
        },

        _ensureSegments() {
            const { rpmBar } = this._els();
            if (!rpmBar || this._segments.length) return;
            rpmBar.innerHTML = '';
            for (let i = 0; i < TOTAL_SEGMENTS; i++) {
                const segment = document.createElement('div');
                segment.className = 'rpm-segment';
                if (i >= TOTAL_SEGMENTS - 3) segment.classList.add('is-redline');
                rpmBar.appendChild(segment);
            }
            this._segments = [...rpmBar.querySelectorAll('.rpm-segment')];
        },

        _updateRpmBar(pct) {
            const segmentsToLight = Math.floor((pct / 100) * TOTAL_SEGMENTS);
            this._segments.forEach((seg, idx) => {
                if (idx < segmentsToLight) {
                    seg.classList.add('active');
                    if (seg.classList.contains('is-redline')) seg.classList.add('redline');
                } else {
                    seg.classList.remove('active', 'redline');
                }
            });
        },

        // [FIX] No fake percentage, no fake MB. Show indeterminate status
        // with a pulsing RPM bar (all segments lit, gentle pulse).
        _setIndeterminate(statusText) {
            const { pct, status, files } = this._els();
            if (pct) pct.innerHTML = '<span class="forza-load-indeterminate">•••</span>';
            if (status) status.textContent = statusText || 'Authenticating...';
            if (files) files.textContent = '';
            this._segments.forEach((seg) => {
                seg.classList.add('active');
                if (seg.classList.contains('is-redline')) seg.classList.add('redline');
            });
        },

        _setComplete(statusText) {
            const { pct, status, files } = this._els();
            if (pct) pct.innerHTML = '100<span>%</span>';
            if (status) status.textContent = statusText || 'Entering session...';
            if (files) files.textContent = '';
            this._segments.forEach((seg) => {
                seg.classList.add('active');
                if (seg.classList.contains('is-redline')) seg.classList.add('redline');
            });
        },

        _stopTips() {
            clearInterval(this._tipTimer);
            this._tipTimer = null;
        },

        _startTips() {
            this._stopTips();
            const { tip } = this._els();
            if (!tip) return;
            this._tipIdx = 0;
            tip.textContent = LOADING_TIPS[0];
            tip.style.opacity = '1';
            this._tipTimer = setInterval(() => {
                tip.style.opacity = '0';
                setTimeout(() => {
                    this._tipIdx = (this._tipIdx + 1) % LOADING_TIPS.length;
                    tip.textContent = LOADING_TIPS[this._tipIdx];
                    tip.style.opacity = '1';
                }, 400);
            }, 6000);
        },

        reset() {
            clearInterval(this._interval);
            clearTimeout(this._finishTimer);
            this._stopTips();
            this._interval = null;
            this._finishTimer = null;
            this._segments = [];
            root()?.classList.remove('is-fading');
            this._setIndeterminate('Initializing session...');
        },

        showComplete(statusText = 'Entering session...') {
            this._ensureSegments();
            this._setComplete(statusText);
        },

        // [FIX] No fake 0→92% progress. Show indeterminate "Authenticating..."
        // with real status text. The server callback determines when it's done.
        start(data = {}) {
            this.reset();
            this._ensureSegments();
            this._setIndeterminate(data.startText || 'Authenticating...');
            this._startTips();
        },

        finish(callback, delay = 600) {
            this._stopTips();
            this._setComplete('Entering session...');
            clearTimeout(this._finishTimer);
            this._finishTimer = setTimeout(() => {
                this._finishTimer = null;
                if (callback) callback();
            }, delay);
        },
    };
}

const handoffUI = createForzaLoadUI('screen-handoff');
const loadingUI = createForzaLoadUI('screen-loading');

const HandoffScreen = {
    show() {
        const el = document.getElementById('screen-handoff');
        if (el) {
            el.classList.remove('hidden');
            el.setAttribute('aria-hidden', 'false');
        }
        handoffUI._ensureSegments();
        handoffUI.showComplete('Entering session...');
        handoffUI._startTips();
    },
    hide() {
        handoffUI._stopTips();
        const el = document.getElementById('screen-handoff');
        if (el) {
            el.classList.add('hidden');
            el.setAttribute('aria-hidden', 'true');
        }
    },
};

const LoadingScreen = {
    start(data = {}) {
        loadingUI.start(data);
    },
    reset() {
        loadingUI.reset();
    },
    finish(callback, delay = 900) {
        loadingUI.finish(callback, delay);
    },
};

const AuthLoading = {
    _pending: false,
    _safety: null,

    armSafety(ms) {
        clearTimeout(this._safety);
        this._safety = setTimeout(() => {
            const app = document.getElementById('app');
            if (app && !app.classList.contains('hidden') && window.App?.currentScreen === 'loading') {
                LoadingScreen.reset();
                post('loadingTimeout');
            }
        }, Math.max(30000, Number(ms) || 120000));
    },

    clearSafety() {
        clearTimeout(this._safety);
        this._safety = null;
    },

    beginSubmit() {
        if (this._pending) return;
        this._pending = true;
        document.getElementById('auth-panel')?.classList.add('is-hidden');
        if (typeof showScreen === 'function') showScreen('loading');
        LoadingScreen.start({
            duration: 3200,
            startAt: 4,
            startText: 'Securing account session...',
            holdAt: 92,
            holdText: 'Authenticating account...',
        });
        this.armSafety(120000);
    },

    reset() {
        this._pending = false;
        this.clearSafety();
        document.getElementById('auth-panel')?.classList.remove('is-hidden');
        LoadingScreen.reset();
        if (typeof showScreen === 'function') showScreen('auth');
    },

    onAuthSuccess(done) {
        if (!this._pending) {
            done();
            return;
        }
        LoadingScreen.finish(() => {
            this._pending = false;
            done();
        });
    },
};

window.HandoffScreen = HandoffScreen;
window.LoadingScreen = LoadingScreen;
window.AuthLoading = AuthLoading;
