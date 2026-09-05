const FuelPump = (() => {
    const root = () => document.getElementById('fuel-pump');
    const get = (id) => document.getElementById(id);

    function formatNumber(value) {
        return (Number(value) || 0).toFixed(2);
    }

    function renderPrompt(mode, label) {
        const prompt = get('fuel-pump-prompt');
        if (!prompt) return;
        prompt.replaceChildren();

        if (mode === 'full' || mode === 'complete') {
            const message = document.createElement('span');
            message.textContent = label || (mode === 'full' ? 'TANK FULL' : 'PAYMENT COMPLETE');
            prompt.append(message);
            return;
        }

        const before = document.createElement('span');
        const key = document.createElement('kbd');
        const after = document.createElement('span');
        before.textContent = mode === 'pumping' ? 'REFUELING' : 'HOLD';
        key.textContent = 'E';
        after.textContent = mode === 'pumping' ? 'RELEASE TO PAY & STOP' : (label || 'TO REFUEL');
        prompt.append(before, key, after);
    }

    function update(data = {}) {
        const panel = root();
        if (!panel) return;
        const mode = data.mode;
        if (data.station !== undefined && get('fuel-pump-station')) get('fuel-pump-station').textContent = data.station || 'Gas Station';
        if (data.liters !== undefined && get('fuel-pump-liters')) get('fuel-pump-liters').textContent = formatNumber(data.liters);
        if (data.cost !== undefined && get('fuel-pump-cost')) get('fuel-pump-cost').textContent = formatNumber(data.cost);
        if (data.pricePerLiter !== undefined && get('fuel-pump-price')) {
            get('fuel-pump-price').textContent = `$${formatNumber(data.pricePerLiter)} / ${data.priceUnit || 'UNIT'}`;
        }
        if (data.tankLabel !== undefined && get('fuel-pump-tank')) get('fuel-pump-tank').textContent = data.tankLabel;
        if (data.fuel !== undefined && get('fuel-pump-fill')) {
            const fuel = Math.max(0, Math.min(100, Number(data.fuel) || 0));
            get('fuel-pump-fill').style.width = `${fuel}%`;
        }
        if (mode) {
            panel.classList.toggle('is-pumping', mode === 'pumping');
            panel.classList.toggle('is-full', mode === 'full' || mode === 'complete');
            renderPrompt(mode, data.promptLabel);
        }
    }

    function show(data = {}) {
        const panel = root();
        if (!panel) return;
        update(data);
        panel.classList.remove('hidden');
        requestAnimationFrame(() => panel.classList.add('is-visible'));
        panel.setAttribute('aria-hidden', 'false');
    }

    function hide() {
        const panel = root();
        if (!panel) return;
        panel.classList.remove('is-visible', 'is-pumping', 'is-full');
        panel.setAttribute('aria-hidden', 'true');
        setTimeout(() => {
            if (!panel.classList.contains('is-visible')) panel.classList.add('hidden');
        }, 240);
    }

    return { show, hide, update };
})();

window.FuelPump = FuelPump;
