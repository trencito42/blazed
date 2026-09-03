const Hud = {
    MAX_SPEED: 320,
    ARC_LEN: 434,
    RPM_ARC_LEN: 358,
    smooth: { speed: 0, rpm: 0 },
    ticksReady: false,

    init() {
        if (this.ticksReady) return;
        const group = document.getElementById('fh-ticks');
        if (!group) return;

        const cx = 120;
        const cy = 120;
        const outerR = 98;
        const innerR = 90;
        const labelR = 82;
        const start = 135;
        const sweep = 270;
        const max = this.MAX_SPEED;
        const step = 20;

        for (let v = 0; v <= max; v += step) {
            const t = v / max;
            const angle = (start + sweep * t) * (Math.PI / 180);
            const major = v % 40 === 0;
            const len = major ? 9 : 5;
            const x1 = cx + Math.cos(angle) * (outerR - len);
            const y1 = cy + Math.sin(angle) * (outerR - len);
            const x2 = cx + Math.cos(angle) * outerR;
            const y2 = cy + Math.sin(angle) * outerR;

            const tick = document.createElementNS('http://www.w3.org/2000/svg', 'line');
            tick.setAttribute('x1', x1);
            tick.setAttribute('y1', y1);
            tick.setAttribute('x2', x2);
            tick.setAttribute('y2', y2);
            tick.setAttribute('class', 'fh-tick' + (major ? ' fh-tick--major' : ''));
            group.appendChild(tick);

            if (major && v > 0 && v < max) {
                const lx = cx + Math.cos(angle) * labelR;
                const ly = cy + Math.sin(angle) * labelR;
                const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                label.setAttribute('x', lx);
                label.setAttribute('y', ly);
                label.setAttribute('class', 'fh-tick-label fh-tick-label--major');
                label.textContent = v;
                group.appendChild(label);
            }
        }

        this.ticksReady = true;
    },

    lerp(a, b, t) {
        return a + (b - a) * t;
    },

    setArc(el, len, progress) {
        if (!el) return;
        const p = Math.max(0, Math.min(1, progress));
        el.style.strokeDashoffset = String(len * (1 - p));
    },

    update(data) {
        if (!data) return;
        this.init();

        if (data.name !== undefined) {
            const el = $('#hud-player-name');
            if (el) el.textContent = data.name || 'Player';
        }
        if (data.playerId !== undefined) {
            const el = $('#hud-player-id');
            if (el) el.textContent = '#' + (data.playerId !== undefined ? data.playerId : 0);
        }

        if (data.health !== undefined) {
            const hp = Math.round(Math.max(0, Math.min(100, data.health)));
            $('#hud-health').style.width = hp + '%';
            $('#hud-health-val').textContent = hp;
        }
        if (data.armor !== undefined) {
            const ar = Math.round(Math.max(0, Math.min(100, data.armor)));
            $('#hud-armor').style.width = ar + '%';
            $('#hud-armor-val').textContent = ar;
        }
        if (data.cash !== undefined) $('#hud-cash').textContent = formatMoney(data.cash);
        if (data.time) $('#hud-time').textContent = data.time;
        if (data.street) $('#hud-street').textContent = data.street;
        if (data.zone) $('#hud-zone').textContent = data.zone;

        const wanted = data.wanted || 0;
        const wantedEl = $('#hud-wanted');
        if (wantedEl) {
            wantedEl.classList.toggle('hidden', wanted <= 0);
            $('#hud-wanted-level').textContent = wanted;
        }

        const vehBar = $('#hud-vehicle-bar');
        const speedo = $('#hud-speedo');

        if (data.inVehicle) {
            vehBar.classList.remove('hidden');
            speedo.classList.remove('hidden');

            this.setSlot('slot-lock', data.locked);
            this.setSlot('slot-seatbelt', data.seatbelt);
            this.setSlot('slot-engine', data.engineOn);

            const lights = $('#slot-lights');
            lights.classList.remove('active', 'lights-low', 'lights-high');
            if (data.lightMode === 1) {
                lights.classList.add('active', 'lights-low');
            } else if (data.lightMode === 2) {
                lights.classList.add('active', 'lights-high');
            }

            const fuelPct = Math.round(data.fuel || 0);
            $('#hud-fuel-pct').textContent = fuelPct + '%';
            $('#hud-fuel-val').textContent = fuelPct;
            const fuelStat = speedo.querySelector('.fh-stat--fuel');
            if (fuelStat) {
                fuelStat.classList.toggle('warn', fuelPct <= 15);
            }
            const fuelSlot = $('#slot-fuel');
            fuelSlot.classList.toggle('active', fuelPct > 15);
            fuelSlot.classList.toggle('warn', fuelPct <= 15);

            const targetSpeed = data.speed || 0;
            const targetRpm = Math.max(0, Math.min(1, data.rpm || 0));
            this.smooth.speed = this.lerp(this.smooth.speed, targetSpeed, 0.22);
            this.smooth.rpm = this.lerp(this.smooth.rpm, targetRpm, 0.28);

            const displaySpeed = Math.round(this.smooth.speed);
            $('#hud-speed').textContent = displaySpeed;

            const gearEl = $('#hud-gear');
            const gearText = displaySpeed === 0 ? 'N' : (data.gear === 0 ? 'R' : String(data.gear));
            gearEl.textContent = gearText;
            gearEl.classList.toggle('fh-speedo__gear--active', displaySpeed > 0);

            const engPct = Math.round(((data.engine || 1000) / 1000) * 100);
            $('#hud-eng-val').textContent = engPct;
            const engStat = speedo.querySelector('.fh-stat--eng');
            if (engStat) {
                engStat.classList.remove('warn', 'crit');
                if (engPct <= 25) engStat.classList.add('crit');
                else if (engPct <= 50) engStat.classList.add('warn');
            }

            const speedProgress = Math.min(this.smooth.speed, this.MAX_SPEED) / this.MAX_SPEED;
            this.setArc($('#fh-speed-arc'), this.ARC_LEN, speedProgress);
            this.setArc($('#fh-rpm-arc'), this.RPM_ARC_LEN, this.smooth.rpm);

            const rpmBar = $('#fh-rpm-bar');
            if (rpmBar) rpmBar.style.width = (this.smooth.rpm * 100) + '%';
        } else {
            vehBar.classList.add('hidden');
            speedo.classList.add('hidden');
            this.smooth.speed = 0;
            this.smooth.rpm = 0;
        }
    },

    setSlot(id, active) {
        const el = document.getElementById(id);
        if (el) el.classList.toggle('active', !!active);
    },
};

window.Hud = Hud;
