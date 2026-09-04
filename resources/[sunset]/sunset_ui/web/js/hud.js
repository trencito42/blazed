const Hud = {
    smooth: { speed: 0, rpm: 0 },
    lastSpeed: null,
    lastGear: null,

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
            this.smooth.speed = 0;
            this.smooth.rpm = 0;
            this.lastSpeed = null;
            this.lastGear = null;
            return;
        }

        speedo.classList.remove('hidden');
        const targetSpeed = Math.max(0, Number(data.speed) || 0);
        const targetRpm = this.clamp(data.rpm, 0, 1);
        this.smooth.speed = this.lerp(this.smooth.speed, targetSpeed, 0.22);
        this.smooth.rpm = this.lerp(this.smooth.rpm, targetRpm, 0.28);

        const displaySpeed = Math.round(this.smooth.speed);
        const speedEl = $('#hud-speed');
        speedEl.textContent = displaySpeed;
        if (displaySpeed !== this.lastSpeed) {
            this.retrigger(speedEl, 'anim-speed');
            this.lastSpeed = displaySpeed;
        }

        const rawGear = Number(data.gear);
        const gearText = displaySpeed === 0 ? 'N' : (rawGear === 0 ? 'R' : `G${Math.max(1, Math.round(rawGear || 1))}`);
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
        fuelStat.classList.toggle('warn', fuel <= 15);
        fuelStat.classList.toggle('crit', fuel <= 5);

        const engineRaw = Number(data.engine);
        const engine = Math.round(this.clamp(Number.isFinite(engineRaw) ? engineRaw / 10 : 100));
        $('#hud-engine').style.width = `${engine}%`;
        const engineStat = $('#hud-engine-stat');
        engineStat.classList.toggle('warn', engine <= 50);
        engineStat.classList.toggle('crit', engine <= 25);
    },
};

window.Hud = Hud;
