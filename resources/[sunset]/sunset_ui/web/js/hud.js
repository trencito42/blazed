const Hud = {
    smooth: { speed: 0, rpm: 0 },
    lastSpeed: null,
    lastGear: null,
    wasInVehicle: false,
    hintTimers: {},
    hintState: {
        engine: { label: 'ENGINE OFF', key: '2', ok: false },
        lock: { label: 'UNLOCKED', key: 'N', ok: true },
        seatbelt: { label: 'SEATBELT OFF', key: 'K', ok: false },
        lights: { label: 'LIGHTS OFF', key: 'H', ok: false },
    },

    init() {
        if (this._ready) return;
        this._ready = true;
        setTimeout(() => {
            $$('.hud-boot').forEach((el) => el.classList.remove('hud-boot'));
        }, 1500);
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

    update(data) {
        if (!data) return;
        this.init();

        if (data.health !== undefined) {
            const health = Math.round(this.clamp(data.health));
            $('#hud-health').style.width = `${health}%`;
        }
        if (data.armor !== undefined) {
            const armor = Math.round(this.clamp(data.armor));
            const armorWrap = document.querySelector('.status-bar-wrapper--armor');
            if (armorWrap) armorWrap.classList.toggle('hidden', armor <= 0);
            $('#hud-armor').style.width = `${armor}%`;
        }
        if (data.cash !== undefined) $('#hud-cash').textContent = formatMoney(data.cash);
        if (data.bank !== undefined) $('#hud-bank').textContent = formatMoney(data.bank);
        if (data.time) $('#hud-time').textContent = data.time;
        if (data.street) $('#hud-street').textContent = data.street;
        if (data.zone) $('#hud-zone').textContent = data.zone;
        if (data.heading) $('#hud-heading').textContent = data.heading;

        const wanted = Math.max(0, Math.round(Number(data.wanted) || 0));
        const wantedEl = $('#hud-wanted');
        if (wantedEl) {
            wantedEl.classList.toggle('hidden', wanted <= 0);
            $('#hud-wanted-level').textContent = wanted;
        }

        const speedo = $('#hud-speedo');
        if (!speedo) return;
        if (!data.inVehicle) {
            speedo.classList.add('hidden');
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
        const targetSpeed = Math.max(0, Number(data.speed) || 0);
        const targetRpm = this.clamp(data.rpm, 0, 1);
        const speedLerp = targetSpeed >= 180 ? 0.62 : (targetSpeed >= 120 ? 0.4 : 0.28);
        this.smooth.speed = this.lerp(this.smooth.speed, targetSpeed, speedLerp);
        this.smooth.rpm = this.lerp(this.smooth.rpm, targetRpm, 0.28);

        const displaySpeed = Math.round(this.smooth.speed);
        const speedEl = $('#hud-speed');
        speedEl.textContent = displaySpeed;
        if (displaySpeed !== this.lastSpeed) {
            this.retrigger(speedEl, 'anim-speed');
            this.lastSpeed = displaySpeed;
        }

        const rawGear = Number(data.gear);
        const vehicleClass = Number(data.vehicleClass);
        const noGears = vehicleClass === 14 || vehicleClass === 15 || vehicleClass === 16;
        const gearText = noGears
            ? (displaySpeed === 0 ? 'N' : '—')
            : (displaySpeed === 0 ? 'N' : (rawGear === 0 ? 'R' : `G${Math.max(1, Math.round(rawGear || 1))}`));
        const gearEl = $('#hud-gear');
        gearEl.textContent = gearText;
        if (gearText !== this.lastGear) {
            this.retrigger(gearEl, 'anim-gear');
            this.lastGear = gearText;
        }

        $('#hud-rpm').style.width = `${this.smooth.rpm * 100}%`;

        const fuel = Math.round(this.clamp(data.fuel));
        $('#hud-fuel').style.width = `${fuel}%`;
        const fuelStat = $('#hud-fuel-stat');
        fuelStat.classList.toggle('hidden', data.showFuel === false);
        fuelStat.classList.toggle('warn', fuel <= 15);
        fuelStat.classList.toggle('crit', fuel <= 5);

        const engineRaw = Number(data.engine);
        const engine = Math.round(this.clamp(Number.isFinite(engineRaw) ? engineRaw / 10 : 100));
        $('#hud-engine').style.width = `${engine}%`;
        const engineStat = $('#hud-engine-stat');
        engineStat.classList.toggle('warn', engine <= 50);
        engineStat.classList.toggle('crit', engine <= 25);

        const odoEl = $('#hud-odometer');
        const odoWrap = document.querySelector('.speed-odo');
        if (odoWrap) odoWrap.classList.toggle('hidden', data.showOdometer === false || data.odometer === undefined);
        if (odoEl && data.odometer !== undefined && data.showOdometer !== false) {
            const km = Math.max(0, Number(data.odometer) || 0);
            odoEl.textContent = km >= 1000 ? Math.round(km).toLocaleString('en-US') : km.toFixed(1);
        }
    },

    syncHintState(data = {}) {
        const lights = ['LIGHTS OFF', 'LIGHTS LOW', 'LIGHTS HIGH'];
        const mode = Math.max(0, Math.min(2, Number(data.lightMode) || 0));
        this.hintState.engine = {
            label: data.engineOn ? 'ENGINE ON' : 'ENGINE OFF',
            key: '2',
            ok: !!data.engineOn,
            tone: data.engineOn ? 'on' : 'off',
        };
        this.hintState.lock = {
            label: data.locked ? 'LOCKED' : 'UNLOCKED',
            key: 'N',
            ok: !data.locked,
            tone: data.locked ? 'off' : 'on',
        };
        this.hintState.seatbelt = {
            label: data.seatbelt ? 'SEATBELT ON' : 'SEATBELT OFF',
            key: 'K',
            ok: !!data.seatbelt,
            tone: data.seatbelt ? 'on' : 'off',
        };
        this.hintState.lights = {
            label: lights[mode],
            key: 'H',
            ok: mode > 0,
            tone: mode === 2 ? 'high' : (mode === 1 ? 'low' : 'off'),
        };
        this.renderHintRows();
    },

    renderHintRows() {
        Object.entries(this.hintState).forEach(([id, row]) => {
            const el = document.querySelector(`[data-hint="${id}"]`);
            if (!el) return;
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
