const JobShift = {
    _panel: null,
    init() {
        if (this._panel) return;
        this._panel = document.getElementById('job-shift-panel');
    },
    _highlight(text, key) {
        const k = key || 'E';
        const marker = '{key}';
        const raw = String(text || '');
        const idx = raw.indexOf(marker);
        if (idx < 0) return raw.replace(/\bE\b/g, `<span class="job-shift__key">${k}</span>`);
        return raw.slice(0, idx) + `<span class="job-shift__key">${k}</span>` + raw.slice(idx + marker.length);
    },
    show(data = {}) {
        this.init();
        if (!this._panel) return;
        this._panel.classList.remove('hidden');
        const title = document.getElementById('job-shift-title');
        const counter = document.getElementById('job-shift-counter');
        const message = document.getElementById('job-shift-message');
        const detail = document.getElementById('job-shift-detail');
        const progress = document.getElementById('job-shift-progress');
        if (title) title.textContent = data.title || 'Work';
        if (counter) counter.textContent = data.counter || '';
        if (message) message.innerHTML = this._highlight(data.message, data.key);
        if (detail) detail.textContent = data.detail || '';
        if (progress) progress.style.width = `${Math.max(0, Math.min(100, Number(data.progress) || 0))}%`;
    },
    hide() {
        this.init();
        if (this._panel) this._panel.classList.add('hidden');
    },
    showSkill(data = {}) {
        const panel = document.getElementById('job-skill-panel');
        const msg = document.getElementById('job-skill-message');
        const fill = document.getElementById('job-skill-fill');
        if (!panel || !fill) return;
        panel.classList.remove('hidden');
        if (msg) msg.innerHTML = this._highlight(data.message || 'Press {key} in time!', data.key);
        const windowMs = Math.max(500, Number(data.windowMs) || 1500);
        fill.style.width = '100%';
        const start = performance.now();
        const tick = () => {
            const elapsed = performance.now() - start;
            const pct = Math.max(0, 100 - (elapsed / windowMs) * 100);
            fill.style.width = `${pct}%`;
            if (pct > 0 && panel && !panel.classList.contains('hidden')) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
    },
    hideSkill() {
        const panel = document.getElementById('job-skill-panel');
        if (panel) panel.classList.add('hidden');
    },
};
window.JobShift = JobShift;
