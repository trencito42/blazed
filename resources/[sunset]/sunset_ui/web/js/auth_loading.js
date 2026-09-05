const LoadingScreen = {
    _interval: null,
    _finishTimer: null,
    _progress: 0,

    _els() {
        return {
            fill: document.getElementById('loading-fill'),
            status: document.getElementById('loading-status'),
            pct: document.getElementById('loading-pct'),
        };
    },

    _statusMessages() {
        return [
            'Connecting to server instance...',
            'Downloading map assets...',
            'Loading Sunset custom vehicles...',
            'Initializing UI systems...',
            'Fetching character data...',
            'Synchronizing weather protocols...',
            'Awaiting game state...',
        ];
    },

    reset() {
        clearInterval(this._interval);
        clearTimeout(this._finishTimer);
        this._interval = null;
        this._finishTimer = null;
        this._progress = 0;
        const { fill, status, pct } = this._els();
        if (fill) {
            fill.style.transition = 'none';
            fill.style.width = '0%';
        }
        if (status) status.textContent = 'Connecting to server instance...';
        if (pct) pct.textContent = '0%';
    },

    _setProgress(value, statusText) {
        const { fill, status, pct } = this._els();
        this._progress = Math.max(0, Math.min(100, value));
        if (fill) fill.style.width = `${this._progress}%`;
        if (pct) pct.textContent = `${Math.floor(this._progress)}%`;
        if (statusText && status) status.textContent = statusText;
    },

    start(data = {}) {
        this.reset();
        const steps = data.steps;
        if (steps && steps.length) {
            let i = 0;
            const next = () => {
                if (i >= steps.length) return;
                const step = steps[i++];
                this._setProgress(step.progress, step.text);
                setTimeout(next, data.stepDelay || 600);
            };
            next();
            return;
        }

        const messages = this._statusMessages();
        const totalMs = Math.max(2000, Number(data.duration) || 5000);
        const tickMs = 50;
        const increment = 100 / (totalMs / tickMs);

        this._interval = setInterval(() => {
            let next = this._progress + increment;
            if (Math.random() > 0.82) next -= increment * 0.75;
            if (next >= 100) {
                next = 100;
                clearInterval(this._interval);
                this._interval = null;
                this._setProgress(100, data.completeText || 'Entering Los Santos...');
                return;
            }
            const msgIndex = Math.min(messages.length - 1, Math.floor((next / 100) * messages.length));
            this._setProgress(next, messages[msgIndex]);
        }, tickMs);
    },

    finish(callback, delay = 900) {
        clearInterval(this._interval);
        this._interval = null;
        this._setProgress(100, 'Entering Los Santos...');
        clearTimeout(this._finishTimer);
        this._finishTimer = setTimeout(() => {
            this._finishTimer = null;
            if (callback) callback();
        }, delay);
    },
};

const AuthLoading = {
    _pending: false,

    beginSubmit() {
        this._pending = true;
        document.getElementById('auth-panel')?.classList.add('is-hidden');
        if (typeof showScreen === 'function') showScreen('loading');
        LoadingScreen.start({ duration: 4500 });
    },

    reset() {
        this._pending = false;
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

window.LoadingScreen = LoadingScreen;
window.AuthLoading = AuthLoading;
