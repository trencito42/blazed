const RadarHud = {
    _panel: null,
    _title: null,
    _meta: null,
    _message: null,
    _speed: null,
    _plate: null,
    _driver: null,
    _fill: null,
    _hits: null,

    init() {
        if (this._panel) return;
        this._panel = document.getElementById('radar-panel');
        this._title = document.getElementById('radar-title');
        this._meta = document.getElementById('radar-meta');
        this._message = document.getElementById('radar-message');
        this._speed = document.getElementById('radar-speed');
        this._plate = document.getElementById('radar-plate');
        this._driver = document.getElementById('radar-driver');
        this._fill = document.getElementById('radar-progress');
        this._hits = document.getElementById('radar-hits');
    },

    _esc(text) {
        return String(text ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[ch]));
    },

    _setHits(hits) {
        if (!this._hits) return;
        const rows = Array.isArray(hits) ? hits.slice(0, 5) : [];
        if (!rows.length) {
            this._hits.classList.add('hidden');
            this._hits.innerHTML = '';
            return;
        }
        this._hits.classList.remove('hidden');
        this._hits.innerHTML = rows.map((hit) => {
            const over = Number(hit.over) || 0;
            return `<div class="radar__hit">
                <span>${this._esc(hit.plate || '--------')}  ${this._esc(hit.name || 'Unknown')}</span>
                <span class="radar__hit-over">${this._esc(hit.speed || 0)} km/h  +${over}</span>
            </div>`;
        }).join('');
    },

    show(data = {}) {
        this.init();
        if (!this._panel) return;

        const state = data.state || 'scan';
        const limit = Math.max(0, Number(data.limit) || 0);
        const speed = Math.max(0, Number(data.speed) || 0);
        this._panel.className = `radar-shell state-${state} is-visible`;
        this._panel.classList.remove('hidden');

        if (this._title) this._title.textContent = data.title || 'Mobile Radar';
        if (this._meta) this._meta.textContent = `Limit ${limit} km/h`;
        if (this._message) this._message.textContent = data.message || 'Scanning lane…';
        if (this._speed) this._speed.textContent = String(speed).padStart(3, '0');
        if (this._plate) this._plate.textContent = data.plate || '--------';
        if (this._driver) this._driver.textContent = data.name || '—';

        if (this._fill) {
            const pct = limit > 0 ? Math.min(100, Math.round((speed / (limit * 1.35)) * 100)) : 0;
            this._fill.style.width = `${pct}%`;
        }
        this._setHits(data.hits);
    },

    update(data = {}) {
        this.show(data);
    },

    hide() {
        this.init();
        if (!this._panel) return;
        this._panel.className = 'radar-shell hidden';
        this._setHits([]);
        if (this._fill) this._fill.style.width = '0%';
    },
};

const RadarAlert = {
    _panel: null,
    _title: null,
    _meta: null,
    _badge: null,
    _speedHero: null,
    _sub: null,
    _statSpeed: null,
    _statLimit: null,
    _statOver: null,
    _statFine: null,
    _statFineLabel: null,
    _fill: null,
    _timeout: null,
    _audioCtx: null,

    init() {
        if (this._panel) return;
        this._panel = document.getElementById('radar-alert-panel');
        this._title = document.getElementById('radar-alert-title');
        this._meta = document.getElementById('radar-alert-meta');
        this._badge = document.getElementById('radar-alert-badge');
        this._speedHero = document.getElementById('radar-alert-speed');
        this._sub = document.getElementById('radar-alert-sub');
        this._statSpeed = document.getElementById('radar-alert-stat-speed');
        this._statLimit = document.getElementById('radar-alert-stat-limit');
        this._statOver = document.getElementById('radar-alert-stat-over');
        this._statFine = document.getElementById('radar-alert-stat-fine');
        this._statFineLabel = document.getElementById('radar-alert-stat-fine-label');
        this._fill = document.getElementById('radar-alert-progress');
    },

    playChime() {
        try {
            const AudioCtx = window.AudioContext || window.webkitAudioContext;
            if (!AudioCtx) return;
            if (!this._audioCtx) this._audioCtx = new AudioCtx();
            if (this._audioCtx.state === 'suspended') this._audioCtx.resume();

            const t = this._audioCtx.currentTime;
            const osc = this._audioCtx.createOscillator();
            const gain = this._audioCtx.createGain();

            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(880, t);
            osc.frequency.exponentialRampToValueAtTime(440, t + 0.28);

            gain.gain.setValueAtTime(0.18, t);
            gain.gain.exponentialRampToValueAtTime(0.001, t + 0.35);

            osc.connect(gain);
            gain.connect(this._audioCtx.destination);
            osc.start(t);
            osc.stop(t + 0.36);

            // Second pulse
            const osc2 = this._audioCtx.createOscillator();
            const gain2 = this._audioCtx.createGain();
            osc2.type = 'triangle';
            osc2.frequency.setValueAtTime(660, t + 0.12);
            osc2.frequency.exponentialRampToValueAtTime(330, t + 0.4);

            gain2.gain.setValueAtTime(0.15, t + 0.12);
            gain2.gain.exponentialRampToValueAtTime(0.001, t + 0.45);

            osc2.connect(gain2);
            gain2.connect(this._audioCtx.destination);
            osc2.start(t + 0.12);
            osc2.stop(t + 0.46);
        } catch (_) {}
    },

    show(data = {}) {
        this.init();
        if (!this._panel) return;

        if (this._timeout) {
            clearTimeout(this._timeout);
            this._timeout = null;
        }

        const speed = Math.max(0, Number(data.speed) || 0);
        const limit = Math.max(0, Number(data.limit) || 0);
        const over = Math.max(0, Number(data.over) || Math.max(0, speed - limit));
        const fine = Number(data.fine) || 0;
        const paid = !!data.paid;
        const duration = Math.max(2500, Number(data.duration) || 7500);

        if (this._title) {
            this._title.textContent = data.title || (data.type === 'mobile' ? 'POLIȚIA RUTIERĂ — RADAR' : 'RADAR FIX — SPEED CAMERA');
        }
        if (this._meta) {
            this._meta.textContent = data.location ? `${String(data.location).toUpperCase()} · LIMITĂ ${limit} KM/H` : `LIMITĂ LEGALĂ: ${limit} KM/H`;
        }
        if (this._badge) {
            this._badge.textContent = `+${over} KM/H`;
        }
        if (this._speedHero) {
            this._speedHero.textContent = `${speed} KM/H`;
        }
        if (this._sub) {
            if (fine > 0) {
                this._sub.textContent = paid
                    ? `AMENDĂ AUTOMATĂ: -$${fine.toLocaleString('en-US')} (DEBITAT DIN CONT)`
                    : `AMENDĂ AUTOMATĂ: $${fine.toLocaleString('en-US')} (NEACHITAT)`;
                this._sub.style.display = 'inline-block';
            } else if (data.officer) {
                this._sub.textContent = `ÎNREGISTRAT DE ${String(data.officer).toUpperCase()}`;
                this._sub.style.display = 'inline-block';
            } else {
                this._sub.textContent = 'VITEZĂ EXCESIVĂ ÎNREGISTRATĂ';
                this._sub.style.display = 'inline-block';
            }
        }

        if (this._statSpeed) this._statSpeed.textContent = `${speed} km/h`;
        if (this._statLimit) this._statLimit.textContent = `${limit} km/h`;
        if (this._statOver) this._statOver.textContent = `+${over} km/h`;
        if (this._statFine) {
            if (fine > 0) {
                this._statFine.textContent = paid ? `-$${fine.toLocaleString('en-US')}` : `$${fine.toLocaleString('en-US')}`;
                this._statFine.className = paid ? 'radar-alert__stat-value is-paid' : 'radar-alert__stat-value is-fine';
                if (this._statFineLabel) this._statFineLabel.textContent = paid ? 'Debitat Cont' : 'Amendă Neachitată';
            } else {
                this._statFine.textContent = 'Avertisment';
                this._statFine.className = 'radar-alert__stat-value is-danger';
                if (this._statFineLabel) this._statFineLabel.textContent = 'Sancțiune';
            }
        }

        // Reset and trigger progress bar countdown drain
        if (this._fill) {
            this._fill.style.transition = 'none';
            this._fill.style.width = '100%';
            // Force reflow
            void this._fill.offsetWidth;
            this._fill.style.transition = `width ${duration}ms linear`;
            this._fill.style.width = '0%';
        }

        this._panel.classList.remove('hidden');
        this._panel.classList.add('is-visible');

        this.playChime();

        this._timeout = setTimeout(() => {
            this.hide();
        }, duration);
    },

    hide() {
        this.init();
        if (this._timeout) {
            clearTimeout(this._timeout);
            this._timeout = null;
        }
        if (!this._panel) return;
        this._panel.classList.remove('is-visible');
        setTimeout(() => {
            if (!this._panel.classList.contains('is-visible')) {
                this._panel.classList.add('hidden');
            }
        }, 260);
    },
};

window.RadarHud = RadarHud;
window.RadarAlert = RadarAlert;
