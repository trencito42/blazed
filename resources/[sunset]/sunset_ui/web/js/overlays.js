const Overlays = {
    _policeTimer: null,

    init() {
        if (this._ready) return;
        this._ready = true;
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
        this._policeTimer = setTimeout(() => this.hidePoliceOrder(), duration);
    },

    hidePoliceOrder() {
        clearTimeout(this._policeTimer);
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
        const el = $('#job-objective');
        if (!el) return;

        $('#job-objective-tag').textContent = data?.tag || data?.jobLabel || 'JOB';
        $('#job-objective-title').textContent = data?.title || data?.objective || '—';
        const desc = $('#job-objective-desc');
        if (desc) {
            desc.textContent = data?.description || data?.hint || '';
            desc.classList.toggle('hidden', !(data?.description || data?.hint));
        }

        const progress = data?.progress;
        const wrap = $('#job-objective-progress-wrap');
        if (wrap) {
            if (progress !== undefined && progress !== null) {
                const pct = Math.max(0, Math.min(100, Math.round(progress)));
                wrap.classList.remove('hidden');
                $('#job-objective-fill').style.width = `${pct}%`;
                $('#job-objective-pct').textContent = `${pct}%`;
            } else {
                wrap.classList.add('hidden');
            }
        }

        el.classList.remove('hidden');
    },

    updateJobObjective(data) {
        if ($('#job-objective')?.classList.contains('hidden')) {
            this.showJobObjective(data);
        } else {
            this.showJobObjective(data);
        }
    },

    hideJobObjective() {
        $('#job-objective')?.classList.add('hidden');
    },
};

window.Overlays = Overlays;
