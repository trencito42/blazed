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

window.RadarHud = RadarHud;
