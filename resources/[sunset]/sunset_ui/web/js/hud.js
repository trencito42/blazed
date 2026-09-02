const Hud = {
    update(data) {
        if (!data) return;

        if (data.playerId !== undefined) $('#hud-id').textContent = 'ID: ' + data.playerId;
        if (data.payday) $('#hud-payday').textContent = data.payday;

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
            $('#hud-fuel-mini').textContent = 'FUEL ' + fuelPct + '%';
            const fuelSlot = $('#slot-fuel');
            fuelSlot.classList.toggle('active', fuelPct > 15);
            fuelSlot.classList.toggle('warn', fuelPct <= 15);

            const speed = data.speed || 0;
            $('#hud-speed').textContent = speed;
            $('#hud-gear').textContent = speed === 0 ? 'N' : (data.gear === 0 ? 'R' : data.gear);

            const engPct = Math.round(((data.engine || 1000) / 1000) * 100);
            const engEl = $('#hud-engine-hp');
            engEl.textContent = 'ENG ' + engPct + '%';
            engEl.style.color = engPct > 50 ? '#6cdc6a' : engPct > 25 ? '#eb5' : '#e55';

            // Speed arc (0-240 km/h)
            const speedArc = 414;
            const speedOffset = speedArc - (Math.min(speed, 240) / 240) * speedArc;
            $('#speedo-speed').style.strokeDashoffset = speedOffset;

            const rpmArc = 340;
            const rpmOffset = rpmArc - (data.rpm || 0) * rpmArc;
            $('#speedo-rpm').style.strokeDashoffset = rpmOffset;
        } else {
            vehBar.classList.add('hidden');
            speedo.classList.add('hidden');
        }
    },

    setSlot(id, active) {
        const el = document.getElementById(id);
        if (el) el.classList.toggle('active', !!active);
    },
};

window.Hud = Hud;
