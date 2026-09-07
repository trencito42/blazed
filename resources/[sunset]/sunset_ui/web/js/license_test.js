const LicenseTestHud = {
    _panel: null,
    _title: null,
    _meta: null,
    _message: null,
    _progress: null,

    init() {
        if (this._panel) return;
        this._panel = document.getElementById('license-test-panel');
        this._title = document.getElementById('license-test-title');
        this._meta = document.getElementById('license-test-meta');
        this._message = document.getElementById('license-test-message');
        this._progress = document.getElementById('license-test-progress');
    },

    _escape(text) {
        return String(text ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[ch]));
    },

    _highlight(text) {
        if (text == null || text === '') return '';
        let html = this._escape(String(text));
        html = html.replace(/\b([0-9]{1,3}|E|K|H)\b/g, (key) => `<span class="license-test__key">${key}</span>`);
        return html;
    },

    _setProgress(ratio) {
        if (!this._progress) return;
        const pct = Math.max(0, Math.min(100, Number(ratio) || 0));
        this._progress.style.width = `${pct}%`;
    },

    _metaLine(data = {}) {
        const parts = [];
        if (data.step != null && data.total) parts.push(`Step ${data.step}/${data.total}`);
        if (data.checkpoints) parts.push(`Checkpoint ${data.checkpoint ?? 0}/${data.checkpoints}`);
        if (data.penalties !== undefined && data.maxPenalties !== undefined) {
            parts.push(`Penalties ${data.penalties}/${data.maxPenalties}`);
        } else if (data.collisions !== undefined && data.maxCollisions !== undefined) {
            parts.push(`Hits ${data.collisions}/${data.maxCollisions}`);
        }
        if (data.speed !== undefined && data.speedLimit !== undefined) {
            parts.push(`${data.speed}/${data.speedLimit} km/h`);
        }
        return parts.join(' · ') || (data.meta || '');
    },

    show(data = {}) {
        this.init();
        if (!this._panel) return;
        const licenseType = data.licenseType || 'driver';
        const stateClass = data.state ? `state-${data.state}` : `state-${licenseType}`;
        this._panel.className = `license-test-shell ${stateClass} is-visible`;
        this._panel.classList.remove('hidden');
        if (this._title) this._title.textContent = data.title || 'License Test';
        if (this._meta) this._meta.textContent = this._metaLine(data);
        if (this._message) this._message.innerHTML = this._highlight(data.message || '');
        this._setProgress(data.progress);
    },

    update(data = {}) {
        this.show(data);
    },

    hide() {
        this.init();
        if (!this._panel) return;
        this._panel.classList.add('hidden');
        this._panel.classList.remove('is-visible');
        this._setProgress(0);
    },
};

window.LicenseTestHud = LicenseTestHud;
