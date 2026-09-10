const SPAWN_META = {
    last: { status: 'Safe', risk: 'Low', statusClass: 'val-safe', riskClass: '' },
    default: { status: 'Public', risk: 'Medium', statusClass: '', riskClass: '' },
    house: { status: 'Property', risk: 'None', statusClass: 'val-safe', riskClass: '' },
    hq: { status: 'Faction', risk: 'Low', statusClass: 'val-safe', riskClass: '' },
};

const SpawnSelector = {
    selected: 'last',
    busy: false,
    dismissible: false,

    activeItems() {
        return [...document.querySelectorAll('.spawn-loc-item:not(.hidden)')].filter((item) => !item.disabled);
    },

    reset() {
        this.busy = false;
        const ui = document.getElementById('spawn-main-ui');
        const fade = document.getElementById('spawn-fade-overlay');
        ui?.classList.remove('exit');
        fade?.classList.remove('active');
        document.querySelectorAll('.spawn-loc-item').forEach((item) => {
            if (item.classList.contains('hidden')) return;
            if (item.dataset.spawn === 'last' && item.hasAttribute('data-force-disabled')) {
                item.disabled = true;
                item.classList.add('is-locked');
                return;
            }
            item.disabled = false;
            item.classList.remove('is-locked');
        });
        const btn = document.getElementById('spawn-btn-confirm');
        if (btn) btn.disabled = false;
    },

    updateDetails(item) {
        const statusEl = document.getElementById('spawn-info-status');
        const riskEl = document.getElementById('spawn-info-risk');
        if (!item || !statusEl || !riskEl) return;
        const status = item.dataset.status || 'Safe';
        const risk = item.dataset.risk || 'Low';
        statusEl.textContent = status;
        riskEl.textContent = risk;
        statusEl.className = 'spawn-detail-value ' + (status === 'Public' ? '' : 'val-safe');
        riskEl.className = 'spawn-detail-value ' + (risk === 'High' ? 'val-danger' : '');
    },

    select(location) {
        const target = document.querySelector(`.spawn-loc-item[data-spawn="${location}"]`);
        if (!target || target.disabled || target.classList.contains('hidden')) return;
        this.selected = location;
        document.querySelectorAll('.spawn-loc-item').forEach((item) => {
            item.classList.toggle('active', item === target);
        });
        this.updateDetails(target);
    },

    move(direction) {
        const items = this.activeItems();
        if (!items.length) return;
        const current = Math.max(0, items.findIndex((item) => item.dataset.spawn === this.selected));
        const next = items[(current + direction + items.length) % items.length];
        this.select(next.dataset.spawn);
    },

    show(data = {}) {
        this.dismissible = data.dismissible === true;
        this.reset();

        const last = document.querySelector('.spawn-loc-item[data-spawn="last"]');
        if (last) {
            const disabled = data.hasLastLocation === false;
            last.disabled = disabled;
            last.classList.toggle('is-locked', disabled);
            if (disabled) last.setAttribute('data-force-disabled', '1');
            else last.removeAttribute('data-force-disabled');
        }

        const home = Array.isArray(data.homes) ? data.homes[0] : null;
        const house = document.querySelector('.spawn-loc-item[data-spawn="house"]');
        if (house) {
            house.classList.toggle('hidden', !home);
            house.disabled = !home;
            house.dataset.propertyId = home?.id || '';
            const label = house.querySelector('.spawn-loc-label');
            if (label) label.textContent = home?.label || 'Property';
            const meta = SPAWN_META.house;
            house.dataset.status = home?.access_type === 'owner' ? 'Property' : 'Rental';
            house.dataset.risk = meta.risk;
        }

        const hq = data.factionHq;
        const hqItem = document.querySelector('.spawn-loc-item[data-spawn="hq"]');
        if (hqItem) {
            const hasHq = Boolean(hq && hq.label);
            hqItem.classList.toggle('hidden', !hasHq);
            hqItem.disabled = !hasHq;
            const label = hqItem.querySelector('.spawn-loc-label');
            if (label) label.textContent = hq?.label || 'Faction HQ';
            hqItem.dataset.status = hq?.hidden ? 'Hidden HQ' : 'Faction HQ';
            hqItem.dataset.risk = SPAWN_META.hq.risk;
        }

        const first = this.activeItems()[0];
        this.select(first ? first.dataset.spawn : 'default');
    },

    confirm(location = this.selected) {
        if (this.busy) return;
        const target = document.querySelector(`.spawn-loc-item[data-spawn="${location}"]`);
        if (!target || target.disabled || target.classList.contains('hidden')) return;

        this.busy = true;
        const ui = document.getElementById('spawn-main-ui');
        const fade = document.getElementById('spawn-fade-overlay');
        const btn = document.getElementById('spawn-btn-confirm');
        if (btn) btn.disabled = true;
        document.querySelectorAll('.spawn-loc-item').forEach((item) => { item.disabled = true; });

        ui?.classList.add('exit');
        setTimeout(() => fade?.classList.add('active'), 300);
        setTimeout(() => {
            post('spawnSelect', {
                location,
                propertyId: Number(target.dataset.propertyId || 0) || null,
            });
        }, 420);
    },

    close() {
        if (!this.dismissible || this.busy) return;
        this.reset();
        post('spawnClose');
    },
};

document.getElementById('spawn-btn-confirm')?.addEventListener('click', () => SpawnSelector.confirm());

document.querySelectorAll('.spawn-loc-item').forEach((item) => {
    item.addEventListener('click', () => {
        if (item.disabled || item.classList.contains('hidden')) return;
        if (SpawnSelector.selected === item.dataset.spawn) SpawnSelector.confirm();
        else SpawnSelector.select(item.dataset.spawn);
    });
});

document.addEventListener('keydown', (event) => {
    if (window.App?.currentScreen !== 'spawn') return;
    if (event.key === 'Escape' && SpawnSelector.dismissible) {
        event.preventDefault();
        SpawnSelector.close();
        return;
    }
    if (['ArrowDown', 'ArrowRight', 'd', 'D'].includes(event.key)) {
        event.preventDefault();
        SpawnSelector.move(1);
    }
    if (['ArrowUp', 'ArrowLeft', 'a', 'A'].includes(event.key)) {
        event.preventDefault();
        SpawnSelector.move(-1);
    }
    if (event.key === 'Enter') {
        event.preventDefault();
        SpawnSelector.confirm();
    }
});

window.SpawnSelector = SpawnSelector;
