const Overlays = {
    _policeTimer: null,
    _announceTimer: null,
    _policeExpiresAt: 0,
    _announceExpiresAt: 0,

    init() {
        if (this._ready) return;
        this._ready = true;
        // [ALT-TAB FIX] CEF throttles timers and freezes rAF while the game is
        // unfocused; overlay hide timers can fire late/never, leaving banners
        // stuck on screen after alt-tabbing back. Track expiry timestamps and
        // force-hide expired overlays when the page becomes visible again.
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState !== 'visible') return;
            const now = Date.now();
            if (this._announceExpiresAt && now > this._announceExpiresAt) this.hideAnnouncement();
            if (this._policeExpiresAt && now > this._policeExpiresAt) this.hidePoliceOrder();
        });
    },

    showAnnouncement(data) {
        this.init();
        const el = $('#server-announce');
        if (!el) return;

        $('#server-announce-badge').textContent = data?.badge || 'ANNOUNCEMENT';
        $('#server-announce-msg').textContent = data?.message || '';
        $('#server-announce-meta').textContent = data?.meta || '';

        el.classList.remove('hidden');
        clearTimeout(this._announceTimer);
        const duration = data?.duration || 6500;
        this._announceExpiresAt = Date.now() + duration;
        this._announceTimer = setTimeout(() => this.hideAnnouncement(), duration);
    },

    hideAnnouncement() {
        clearTimeout(this._announceTimer);
        this._announceExpiresAt = 0;
        $('#server-announce')?.classList.add('hidden');
    },

    showPoliceOrder(data) {
        this.init();
        const el = $('#police-order');
        if (!el) return;

        $('#police-order-msg').textContent = data?.message || 'Stop and comply with law enforcement';
        const meta = [];
        if (data?.officer) meta.push(data.officer);
        if (data?.officerId) meta.push(`#${data.officerId}`);
        $('#police-order-meta').textContent = meta.join(' · ');

        el.classList.remove('hidden');

        clearTimeout(this._policeTimer);
        const duration = data?.duration || 12000;
        this._policeExpiresAt = Date.now() + duration;
        this._policeTimer = setTimeout(() => this.hidePoliceOrder(), duration);
    },

    hidePoliceOrder() {
        clearTimeout(this._policeTimer);
        this._policeExpiresAt = 0;
        $('#police-order')?.classList.add('hidden');
    },

    showTaxiMeter(data) {
        this.init();
        $('#taxi-meter')?.classList.remove('hidden');
        this.updateTaxiMeter(data || {});
    },

    updateTaxiMeter(data) {
        if (!data) return;
        const fareEl = $('#taxi-meter-fare');
        const distEl = $('#taxi-meter-dist');
        const timeEl = $('#taxi-meter-time');
        const statusEl = $('#taxi-meter-status');

        if (data.fare !== undefined && fareEl) {
            fareEl.textContent = formatMoney(Math.floor(data.fare));
        }
        if (data.distanceKm !== undefined && distEl) {
            const km = Number(data.distanceKm);
            distEl.textContent = km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(1)} km`;
        }
        if (data.elapsedSec !== undefined && timeEl) {
            const s = Math.max(0, Math.floor(data.elapsedSec));
            const m = Math.floor(s / 60);
            timeEl.textContent = `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
        }
        if (data.status && statusEl) {
            statusEl.textContent = data.status.toUpperCase();
            statusEl.classList.toggle('is-active', data.status === 'active' || data.status === 'in_progress');
        }
        if (data.visible === false) {
            this.hideTaxiMeter();
        }
    },

    hideTaxiMeter() {
        $('#taxi-meter')?.classList.add('hidden');
    },

    showJobObjective(data) {
        this.init();
        if (!window.Hud) return;

        const tag = data?.tag || data?.jobLabel || 'JOB';
        const title = data?.title || data?.objective || '—';
        const desc = data?.description || data?.subtitle || data?.hint || '';
        const progress = data?.progress;
        const current = data?.current;
        const total = data?.total;
        let progressText = '';
        if (current != null && total) progressText = `${current} / ${total}`;
        else if (progress !== undefined && progress !== null) progressText = `${Math.round(progress)}%`;

        Hud.showTask({
            icon: 'job',
            title: `JOB ACTIV: ${tag}`,
            desc: desc || title,
            progress: progress,
            progressText,
        });

        $('#job-objective')?.classList.add('hidden');
    },

    updateJobObjective(data) {
        this.showJobObjective(data);
    },

    hideJobObjective() {
        if (window.Hud) Hud.hideTask();
        $('#job-objective')?.classList.add('hidden');
    },
};

window.Overlays = Overlays;
