const FuelPump = (() => {
    const root = () => document.getElementById('fuel-pump');
    const els = {
        station: () => document.getElementById('fuel-pump-station'),
        liters: () => document.getElementById('fuel-pump-liters'),
        cost: () => document.getElementById('fuel-pump-cost'),
        tank: () => document.getElementById('fuel-pump-tank'),
        fill: () => document.getElementById('fuel-pump-fill'),
    };

    function formatMoney(value) {
        const n = Number(value) || 0;
        return `$${n.toFixed(2)}`;
    }

    function formatLiters(value) {
        const n = Number(value) || 0;
        return n.toFixed(1);
    }

    function show(data = {}) {
        const el = root();
        if (!el) return;
        update(data);
        el.classList.add('is-visible');
        el.classList.remove('hidden');
    }

    function hide() {
        const el = root();
        if (!el) return;
        el.classList.remove('is-visible');
        el.classList.add('hidden');
    }

    function update(data = {}) {
        const liters = Number(data.liters) || 0;
        const cost = Number(data.cost) || 0;
        const fuel = Number(data.fuel) || 0;

        if (els.station()) els.station().textContent = data.station || 'Gas Station';
        if (els.liters()) els.liters().textContent = formatLiters(liters);
        if (els.cost()) els.cost().textContent = formatMoney(cost);
        if (els.tank()) els.tank().textContent = `${Math.round(fuel)}%`;
        if (els.fill()) els.fill().style.width = `${Math.max(0, Math.min(100, fuel))}%`;
    }

    return { show, hide, update };
})();

window.FuelPump = FuelPump;
