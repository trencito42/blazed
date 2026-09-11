const FuelPump = (() => {
    const root = () => document.getElementById('fuel-pump');
    const get = (id) => document.getElementById(id);

    let state = null;
    let pumping = false;

    function post(action, data = {}) {
        if (typeof window.post === 'function') return window.post(action, data);
        const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : '';
        if (!resource) return Promise.resolve();
        return fetch(`https://${resource}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(() => {});
    }

    function formatLiters(value) {
        return (Number(value) || 0).toFixed(2).padStart(5, '0');
    }

    function formatMoney(value) {
        return (Number(value) || 0).toFixed(2).padStart(5, '0');
    }

    function updateTankGauge(pct) {
        const fill = get('fp-tank-fill');
        const pctText = get('fp-tank-pct');
        const icon = get('fp-tank-icon');
        const clamped = Math.max(0, Math.min(100, Number(pct) || 0));
        if (fill) fill.style.height = `${clamped}%`;
        if (pctText) pctText.textContent = `${Math.floor(clamped)}%`;
        if (!fill || !icon) return;
        if (clamped < 25) {
            fill.style.background = 'var(--fp-danger)';
            fill.style.boxShadow = '0 0 15px rgba(255, 51, 102, 0.4)';
            icon.style.color = 'var(--fp-danger)';
        } else if (clamped > 80) {
            fill.style.background = 'var(--fp-accent)';
            fill.style.boxShadow = '0 0 15px rgba(0, 255, 204, 0.4)';
            icon.style.color = 'var(--fp-accent)';
        } else {
            fill.style.background = 'var(--fp-text-main)';
            fill.style.boxShadow = '0 0 10px rgba(255, 255, 255, 0.4)';
            icon.style.color = 'var(--fp-text-muted)';
        }
    }

    function setPumpButton(active) {
        const btn = get('fp-btn-pump');
        if (!btn) return;
        btn.classList.toggle('is-pumping', active);
    }

    function bindEvents() {
        if (root()?.dataset.bound === '1') return;
        const panel = root();
        if (!panel) return;
        panel.dataset.bound = '1';

        const pumpBtn = get('fp-btn-pump');
        pumpBtn?.addEventListener('mousedown', () => post('fuelPumpPumpStart'));
        pumpBtn?.addEventListener('mouseup', () => post('fuelPumpPumpStop'));
        pumpBtn?.addEventListener('mouseleave', () => post('fuelPumpPumpStop'));

        get('fp-btn-checkout')?.addEventListener('click', () => post('fuelPumpCheckout'));

        document.addEventListener('keydown', (event) => {
            if (!root()?.classList.contains('is-visible') || !state?.interactive) return;
            if (event.code === 'Space' && !event.repeat) {
                event.preventDefault();
                post('fuelPumpPumpStart');
            }
        });
        document.addEventListener('keyup', (event) => {
            if (!root()?.classList.contains('is-visible')) return;
            if (event.code === 'Space') post('fuelPumpPumpStop');
        });
    }

    function update(data = {}) {
        state = { ...state, ...data };
        const panel = root();
        if (!panel) return;

        if (data.station !== undefined && get('fp-station-label')) {
            get('fp-station-label').textContent = data.station || 'Gas Station';
        }
        const pumpLabel = get('fp-pump-label');
        if (pumpLabel) {
            pumpLabel.textContent = data.pumpLabel || '';
            pumpLabel.style.display = data.pumpLabel ? 'flex' : 'none';
        }
        if (data.vehicleName !== undefined && get('fp-vehicle-name')) {
            get('fp-vehicle-name').textContent = data.vehicleName || 'Vehicle';
        }
        if (data.fuelType !== undefined && get('fp-fuel-type')) {
            get('fp-fuel-type').textContent = data.fuelType || 'Premium Gasoline';
        }
        if (data.pricePerLiter !== undefined && get('fp-price-line')) {
            get('fp-price-line').textContent = `$${formatMoney(data.pricePerLiter)} / Liter`;
        }
        if (data.sessionLiters !== undefined && get('fp-val-liters')) {
            get('fp-val-liters').textContent = formatLiters(data.sessionLiters);
        }
        if (data.cost !== undefined && get('fp-val-price')) {
            get('fp-val-price').textContent = formatMoney(data.cost);
        }
        if (data.tankPct !== undefined) updateTankGauge(data.tankPct);

        const mode = data.mode || state?.mode;
        const checkout = get('fp-btn-checkout');
        const pumpBtn = get('fp-btn-pump');
        if (mode === 'ready') {
            panel.classList.remove('is-interactive');
            if (pumpBtn) pumpBtn.disabled = true;
            if (checkout) checkout.disabled = true;
            const pumpText = get('fp-btn-pump')?.querySelector('.fp-pump-text');
            if (pumpText) {
                const isCan = (data.vehicleName || state?.vehicleName) === 'Gas Can';
                pumpText.innerHTML = isCan
                    ? '<span class="fp-key-hint">E</span> Start Fill'
                    : '<span class="fp-key-hint">G</span> Start Pump';
            }
        } else if (mode === 'pumping') {
            panel.classList.add('is-interactive');
            if (pumpBtn) pumpBtn.disabled = data.canPump === false;
            if (checkout) checkout.disabled = (Number(data.sessionLiters) || 0) <= 0;
            const pumpText = get('fp-btn-pump')?.querySelector('.fp-pump-text');
            if (pumpText) pumpText.innerHTML = '<span class="fp-key-hint">SPACE</span> Press Pump';
        } else if (mode === 'full' || mode === 'complete') {
            panel.classList.add('is-interactive');
            if (pumpBtn) pumpBtn.disabled = true;
            if (checkout) checkout.disabled = mode === 'complete';
        }

        if (data.pumping !== undefined) {
            pumping = data.pumping === true;
            setPumpButton(pumping);
        }
    }

    function show(data = {}) {
        bindEvents();
        state = { ...data };
        const panel = root();
        if (!panel) return;
        update(data);
        document.body.classList.add('fuel-pump-open');
        panel.classList.remove('hidden');
        requestAnimationFrame(() => panel.classList.add('is-visible'));
        panel.setAttribute('aria-hidden', 'false');
    }

    function hide() {
        const panel = root();
        if (!panel) return;
        state = null;
        pumping = false;
        setPumpButton(false);
        document.body.classList.remove('fuel-pump-open');
        panel.classList.remove('is-visible', 'is-interactive');
        panel.setAttribute('aria-hidden', 'true');
        setTimeout(() => {
            if (!panel.classList.contains('is-visible')) panel.classList.add('hidden');
        }, 240);
    }

    return { show, hide, update };
})();

window.FuelPump = FuelPump;
