const Fishing = {
    _panel: null,
    _title: null,
    _bag: null,
    _message: null,
    _progress: null,
    _state: null,

    init() {
        if (this._panel) return;
        this._panel = document.getElementById('fishing-panel');
        this._title = document.getElementById('fishing-title');
        this._bag = document.getElementById('fishing-bag');
        this._message = document.getElementById('fishing-message');
        this._progress = document.getElementById('fishing-progress');
    },

    _keyHtml() {
        return '<span class="fishing__key">E</span>';
    },

    _setBag(carried, capacity) {
        if (!this._bag) return;
        const c = Math.max(0, Number(carried) || 0);
        const cap = Math.max(1, Number(capacity) || 2);
        this._bag.textContent = `Bag ${c}/${cap}`;
        this._bag.classList.toggle('hidden', carried === undefined && capacity === undefined);
    },

    _applyState(stateClass, title, messageHtml) {
        if (!this._panel) return;
        this._panel.className = `fishing-shell ${stateClass} is-visible`;
        this._state = stateClass.replace('state-', '');
        if (this._title) this._title.textContent = title;
        if (this._message) this._message.innerHTML = messageHtml;
    },

    _resolveState(data = {}) {
        const c = Math.max(0, Number(data.carried) || 0);
        const cap = Math.max(1, Number(data.capacity) || 2);
        let state = data.state || 'idle';
        if ((state === 'idle' || state === 'shift') && c >= cap) {
            return 'full';
        }
        return state;
    },

    _fullMessage(data = {}) {
        const c = Math.max(0, Number(data.carried) || 0);
        const cap = Math.max(1, Number(data.capacity) || 2);
        return data.message || `Bag full ${c}/${cap} — yellow marker or /sellfish to sell`;
    },

    show(data = {}) {
        this.init();
        if (!this._panel) return;

        this._setBag(data.carried, data.capacity);
        this._panel.classList.remove('hidden');

        const state = this._resolveState(data);
        if (state === 'waiting') {
            this._applyState('state-waiting', data.title || 'Line cast', data.message || 'Waiting for a bite…');
            if (this._progress) {
                this._progress.style.transition = 'none';
                this._progress.style.width = '0%';
            }
        } else if (state === 'bite') {
            this.startBite(data.windowMs || 1500, data);
        } else if (state === 'success') {
            this._applyState('state-success', data.title || 'Success', data.message || 'You caught a fish!');
            if (this._progress) {
                this._progress.style.transition = 'width 0.3s ease';
                this._progress.style.width = '100%';
            }
        } else if (state === 'failed') {
            this._applyState('state-failed', data.title || 'Missed', data.message || 'The fish escaped');
            if (this._progress) {
                this._progress.style.transition = 'none';
                this._progress.style.width = '0%';
            }
        } else if (state === 'full') {
            this._applyState(
                'state-full',
                data.title || 'Bag Full',
                this._fullMessage(data)
            );
            if (this._progress) {
                this._progress.style.transition = 'none';
                this._progress.style.width = '100%';
            }
        } else if (state === 'shift') {
            this._applyState(
                'state-shift',
                data.title || 'Fisherman',
                data.message || 'Blue marker: E or /fish · /sellfish marks the buyer'
            );
            if (this._progress) {
                this._progress.style.transition = 'none';
                this._progress.style.width = '0%';
            }
        } else {
            this._applyState(
                'state-idle',
                data.title || 'Fishing',
                data.message || `Press ${this._keyHtml()} to cast`
            );
            if (this._progress) {
                this._progress.style.transition = 'none';
                this._progress.style.width = '0%';
            }
        }
    },

    update(data = {}) {
        this.init();
        if (!this._panel) return;

        const hasBag = data.carried !== undefined || data.capacity !== undefined;
        if (hasBag) {
            this._setBag(data.carried, data.capacity);
        }

        const hasContent = data.state || data.message || data.title || data.windowMs;
        if (!hasContent) return;

        if (this._panel.classList.contains('hidden')) {
            this.show(data);
            return;
        }
        if (data.state === 'bite') {
            this.startBite(data.windowMs || 1500, data);
            return;
        }
        const resolved = this._resolveState(data);
        this.show({ ...data, state: resolved });
    },

    startBite(windowMs, data = {}) {
        this.init();
        if (!this._panel) return;

        this._setBag(data.carried, data.capacity);
        this._panel.classList.remove('hidden');
        this._applyState(
            'state-bite',
            data.title || 'Bite!',
            data.message || `Press ${this._keyHtml()} now!`
        );

        const ms = Math.max(300, Number(windowMs) || 1500);
        if (!this._progress) return;

        this._progress.style.transition = 'none';
        this._progress.style.width = '100%';
        void this._progress.offsetWidth;
        this._progress.style.transition = `width ${ms}ms linear`;
        this._progress.style.width = '0%';
    },

    hide() {
        this.init();
        if (!this._panel) return;
        this._panel.className = 'fishing-shell hidden';
        this._state = null;
        if (this._progress) {
            this._progress.style.transition = 'none';
            this._progress.style.width = '0%';
        }
    },
};

window.Fishing = Fishing;
