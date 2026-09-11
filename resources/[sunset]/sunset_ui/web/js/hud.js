const Hud = {
    smooth: { speed: 0, rpm: 0 },
    lastSpeed: null,
    lastGear: null,
    wasInVehicle: false,
    _lastStreet: null,
    _locationHideTimer: null,
    locationShowMs: 4500,
    hintTimers: {},
    hintState: {
        engine: { label: 'ENGINE OFF', key: '2', ok: false },
        lock: { label: 'UNLOCKED', key: 'U', ok: true },
        seatbelt: { label: 'SEATBELT OFF', key: 'K', ok: false },
        lights: { label: 'LIGHTS OFF', key: 'H', ok: false },
    },
    taskIcons: {
        default: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>',
        job: '<svg viewBox="0 0 24 24"><rect x="1" y="3" width="15" height="13"></rect><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon><circle cx="5.5" cy="18.5" r="2.5"></circle><circle cx="18.5" cy="18.5" r="2.5"></circle></svg>',
        license: '<svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>',
        driver: '<svg viewBox="0 0 24 24"><path d="M4 17h16M6 11l2-5h8l2 5"></path><circle cx="7.5" cy="17" r="1.5"></circle><circle cx="16.5" cy="17" r="1.5"></circle></svg>',
    },

    init() {
        if (this._ready) return;
        this._ready = true;
        this.updateDateDisplay();
        if (!this._dateTimer) {
            this._dateTimer = setInterval(() => this.updateDateDisplay(), 60000);
        }
        setTimeout(() => {
            $$('.hud-boot').forEach((el) => el.classList.remove('hud-boot'));
        }, 1500);
    },

    updateDateDisplay(dateValue) {
        const el = $('#hud-date');
        if (!el) return;
        const source = dateValue ? new Date(dateValue) : new Date();
        if (Number.isNaN(source.getTime())) return;
        const parts = source.toLocaleDateString('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
        }).toUpperCase().replace(/\./g, '');
        el.textContent = parts;
    },

    clamp(value, min = 0, max = 100) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return min;
        return Math.max(min, Math.min(max, parsed));
    },

    lerp(from, to, amount) {
        return from + (to - from) * amount;
    },

    retrigger(element, className) {
        if (!element) return;
        element.classList.remove(className);
        void element.offsetWidth;
        element.classList.add(className);
    },

    formatWantedTimer(seconds) {
        const total = Math.max(0, Math.round(Number(seconds) || 0));
        const mins = Math.floor(total / 60);
        const secs = total % 60;
        return `${mins}:${String(secs).padStart(2, '0')}`;
    },

    updateWantedDisplay(data) {
        const wanted = Math.max(0, Math.round(Number(data.wanted) || 0));
        const panel = $('#hud-wanted');
        const timerWrap = $('#hud-wanted-timer-wrap');
        const timerEl = $('#hud-wanted-timer');
        const stars = document.querySelectorAll('#hud-wanted-stars .wanted-star');
        if (!panel) return;

        panel.classList.toggle('active', wanted > 0);
        panel.setAttribute('aria-label', wanted > 0 ? `Wanted level ${wanted}` : 'Not wanted');

        stars.forEach((star, index) => {
            star.classList.toggle('active', index < Math.min(wanted, 5));
        });

        if (!timerWrap || !timerEl) return;
        if (wanted <= 0) {
            timerWrap.classList.add('hidden');
            timerEl.textContent = '';
            return;
        }

        if (data.wantedPersistent) {
            timerEl.textContent = '∞';
            timerWrap.classList.remove('hidden');
            return;
        }

        const remaining = Number(data.wantedRemainingSec);
        if (Number.isFinite(remaining) && remaining > 0) {
            timerEl.textContent = this.formatWantedTimer(remaining);
            timerWrap.classList.remove('hidden');
            return;
        }

        timerWrap.classList.add('hidden');
        timerEl.textContent = '';
    },

    updateVoice(data = {}) {
        const icon = $('#hud-voice-icon');
        const range = $('#hud-voice-range');
        const container = document.querySelector('.voice-container');
        if (!icon || !range) return;

        const display = data.voiceRangeDisplay
            || (data.voiceRangeMeters != null
                ? `${data.voiceRange || 'Normal'} · ${Number(data.voiceRangeMeters).toFixed(1)}m`
                : String(data.voiceRange || 'Normal · 3.0m'));
        range.textContent = display;
        range.title = `Voice range: ${display}`;

        if (data.voiceTalking !== undefined) {
            icon.classList.toggle('talking', data.voiceTalking === true);
        }

        if (data.voiceChanged && container) {
            container.classList.remove('voice-changed');
            void container.offsetWidth;
            container.classList.add('voice-changed');
            window.clearTimeout(this._voiceChangedTimer);
            this._voiceChangedTimer = window.setTimeout(() => {
                container?.classList.remove('voice-changed');
            }, 1400);
        }
    },

    showTask(data = {}) {
        this.init();
        const panel = $('#hud-task-panel');
        const title = $('#hud-task-title');
        const desc = $('#hud-task-desc');
        const bar = $('#hud-task-bar');
        const progressText = $('#hud-task-progress-text');
        const progressWrap = $('#hud-task-progress-wrap');
        if (!panel) return;

        const iconKey = data.icon || data.iconKey || (data.licenseType ? 'license' : 'default');
        const iconSvg = data.iconSVG || this.taskIcons[iconKey] || this.taskIcons.default;
        const titleText = data.title || data.tag || 'TASK';
        if (title) title.innerHTML = `${iconSvg} ${this.escapeHtml(titleText)}`;

        if (desc) {
            if (data.htmlDesc) {
                desc.innerHTML = data.htmlDesc;
            } else if (data.plainDesc) {
                desc.textContent = data.desc || data.description || data.message || '';
            } else {
                desc.innerHTML = this.highlightKeys(data.desc || data.description || data.message || '');
            }
        }

        panel.classList.toggle('task-panel--danger', data.tone === 'danger' || data.state === 'warning');
        panel.classList.add('active');

        const progressPct = data.progressPct ?? data.progress;
        const hasProgress = progressPct !== undefined && progressPct !== null
            || data.progressText !== undefined
            || data.meta !== undefined;

        if (progressWrap) progressWrap.classList.toggle('hidden', !hasProgress);
        if (bar && progressPct !== undefined && progressPct !== null) {
            bar.style.width = `${this.clamp(progressPct)}%`;
        }
        if (progressText) {
            progressText.textContent = data.progressText || data.meta || '';
        }
    },

    hideTask() {
        const panel = $('#hud-task-panel');
        if (!panel) return;
        panel.classList.remove('active', 'task-panel--danger');
    },

    escapeHtml(text) {
        return String(text ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[ch]));
    },

    highlightKeys(text) {
        if (text == null || text === '') return '';
        let html = this.escapeHtml(String(text));
        html = html.replace(/\b([2EKHN])\b/g, (key) => `<span class="task-key">${key}</span>`);
        return html;
    },

    revealLocationPanel(panel) {
        if (!panel) return;
        panel.classList.add('is-visible');
        this.retrigger(panel, 'location-pulse');
        if (this._locationHideTimer) window.clearTimeout(this._locationHideTimer);
        this._locationHideTimer = window.setTimeout(() => {
            panel.classList.remove('is-visible');
            this._locationHideTimer = null;
        }, this.locationShowMs);
    },

    updateLocation(data = {}) {
        const panel = document.querySelector('.location-panel');
        if (!panel) return;

        const street = data.street != null ? String(data.street) : null;
        const zone = data.zone != null ? String(data.zone) : null;
        const heading = data.heading != null ? String(data.heading) : null;

        if (street != null) $('#hud-street').textContent = street;
        if (zone != null) {
            const zoneText = $('#hud-zone-text');
            if (zoneText) zoneText.textContent = zone;
        }
        if (heading != null && panel.classList.contains('is-visible')) {
            $('#hud-heading').textContent = heading;
        }

        if (street == null || street === '' || street === '—') return;

        const streetChanged = street !== this._lastStreet;
        if (!streetChanged) return;

        this._lastStreet = street;
        if (heading != null) $('#hud-heading').textContent = heading;
        this.revealLocationPanel(panel);
    },

    update(data) {
        if (!data) return;
        this.init();

        if (data.health !== undefined) {
            const health = Math.round(this.clamp(data.health));
            $('#hud-health').style.width = `${health}%`;
        }
        if (data.armor !== undefined) {
            const armor = Math.round(this.clamp(data.armor));
            const armorWrap = document.querySelector('.vital-row--armor');
            if (armorWrap) armorWrap.classList.toggle('hidden', armor <= 0);
            $('#hud-armor').style.width = `${armor}%`;
        }
        if (data.cash !== undefined) $('#hud-cash').textContent = formatMoney(data.cash);
        if (data.bank !== undefined) $('#hud-bank').textContent = formatMoney(data.bank);
        if (data.time) $('#hud-time').textContent = data.time;
        if (data.date) this.updateDateDisplay(data.date);
        if (data.street !== undefined || data.zone !== undefined || data.heading !== undefined) {
            this.updateLocation(data);
        }

        if (data.voiceTalking !== undefined || data.voiceRange !== undefined) {
            this.updateVoice(data);
        }

        if (data.wanted !== undefined
            || data.wantedRemainingSec !== undefined
            || data.wantedDecayAt !== undefined
            || data.wantedPersistent !== undefined) {
            this.updateWantedDisplay(data);
        }

        document.body.classList.toggle('in-vehicle', !!data.inVehicle);

        const speedo = $('#hud-speedo');
        if (!speedo) return;
        if (!data.inVehicle) {
            speedo.classList.add('hidden');
            if (window.ForzaSpeedometer) window.ForzaSpeedometer.setActive(false);
            this.hideVehicleHints();
            this.wasInVehicle = false;
            this.smooth.speed = 0;
            this.smooth.rpm = 0;
            this.lastSpeed = null;
            this.lastGear = null;
            return;
        }

        this.syncHintState(data);
        if (!this.wasInVehicle) {
            this.showVehicleHints();
        }
        this.wasInVehicle = true;

        speedo.classList.remove('hidden');
        if (window.ForzaSpeedometer) {
            window.ForzaSpeedometer.setActive(true);
            window.ForzaSpeedometer.update(data);
        }
    },

    syncHintState(data = {}) {
        const lights = ['LIGHTS OFF', 'LIGHTS LOW', 'LIGHTS HIGH'];
        const mode = Math.max(0, Math.min(2, Number(data.lightMode) || 0));
        const supportsSeatbelt = data.supportsSeatbelt !== false;
        const supportsDoorLock = data.supportsDoorLock !== false;
        const noEngine = Number(data.vehicleClass) === 13;
        this.hintState.engine = {
            label: data.engineOn ? 'ENGINE ON' : 'ENGINE OFF',
            key: '2',
            ok: !!data.engineOn,
            tone: data.engineOn ? 'on' : 'off',
            hidden: noEngine,
        };
        this.hintState.lock = {
            label: data.locked ? 'LOCKED' : 'UNLOCKED',
            key: 'U',
            ok: !data.locked,
            tone: data.locked ? 'off' : 'on',
            hidden: !supportsDoorLock,
        };
        this.hintState.seatbelt = {
            label: data.seatbelt ? 'SEATBELT ON' : 'SEATBELT OFF',
            key: 'K',
            ok: !!data.seatbelt,
            tone: data.seatbelt ? 'on' : 'off',
            hidden: !supportsSeatbelt,
        };
        this.hintState.lights = {
            label: lights[mode],
            key: 'H',
            ok: mode > 0,
            tone: mode === 2 ? 'high' : (mode === 1 ? 'low' : 'off'),
            hidden: noEngine,
        };
        this.renderHintRows();
    },

    renderHintRows() {
        Object.entries(this.hintState).forEach(([id, row]) => {
            const el = document.querySelector(`[data-hint="${id}"]`);
            if (!el) return;
            el.classList.toggle('hidden', row.hidden === true);
            if (row.hidden) return;
            const label = el.querySelector('.veh-hints__label');
            const key = el.querySelector('.veh-hints__key');
            if (label) label.textContent = row.label;
            if (key) key.textContent = row.key;
            const tone = row.tone || (row.ok ? 'on' : 'off');
            el.classList.toggle('is-on', tone === 'on' || tone === 'low');
            el.classList.toggle('is-off', tone === 'off');
            el.classList.toggle('is-high', tone === 'high');
            el.classList.toggle('is-low', tone === 'low');
            el.classList.toggle('is-dim', tone === 'off' && id === 'lights');
        });
    },

    showVehicleHints() {
        this.renderHintRows();
        ['engine', 'lock', 'seatbelt', 'lights'].forEach((id) => this.armHintRow(id));
    },

    armHintRow(id) {
        const el = $('#veh-hints');
        const row = el?.querySelector(`[data-hint="${id}"]`);
        if (!row) return;
        row.classList.add('is-active');
        el.classList.add('is-visible');
        el.setAttribute('aria-hidden', 'false');
        if (this.hintTimers[id]) clearTimeout(this.hintTimers[id]);
        this.hintTimers[id] = setTimeout(() => this.hideHintRow(id), 5000);
    },

    hideHintRow(id) {
        if (this.hintTimers[id]) {
            clearTimeout(this.hintTimers[id]);
            delete this.hintTimers[id];
        }
        const row = document.querySelector(`[data-hint="${id}"]`);
        if (row) row.classList.remove('is-active');
        const wrap = $('#veh-hints');
        if (!wrap) return;
        const any = wrap.querySelector('.veh-hints__row.is-active');
        wrap.classList.toggle('is-visible', !!any);
        wrap.setAttribute('aria-hidden', any ? 'false' : 'true');
    },

    flashVehicleHint(payload = {}) {
        if (payload.rows) {
            Object.entries(payload.rows).forEach(([id, row]) => {
                this.hintState[id] = {
                    label: row.label,
                    key: row.key,
                    ok: row.ok === true,
                    tone: row.tone || (row.ok ? 'on' : 'off'),
                };
            });
        }
        this.renderHintRows();
        if (payload.id) {
            this.armHintRow(payload.id);
            return;
        }
        this.showVehicleHints();
    },

    hideVehicleHints() {
        Object.keys(this.hintTimers).forEach((id) => {
            clearTimeout(this.hintTimers[id]);
            delete this.hintTimers[id];
        });
        const el = $('#veh-hints');
        if (!el) return;
        el.querySelectorAll('.veh-hints__row').forEach((row) => row.classList.remove('is-active'));
        el.classList.remove('is-visible');
        el.setAttribute('aria-hidden', 'true');
    },
};

window.Hud = Hud;
