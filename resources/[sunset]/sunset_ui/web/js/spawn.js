const SpawnSelector = {
    selected: 'last', busy: false,
    activeCards() { return [...document.querySelectorAll('.spawn-option:not(.hidden)')].filter((card) => !card.disabled); },
    show(data = {}) {
        this.busy = false;
        const last = document.querySelector('[data-spawn="last"]');
        if (last) last.disabled = data.hasLastLocation === false;
        const home = Array.isArray(data.homes) ? data.homes[0] : null;
        const house = document.querySelector('[data-spawn="house"]');
        if (house) {
            house.classList.toggle('hidden', !home);
            house.disabled = !home;
            house.dataset.propertyId = home?.id || '';
            const name = document.getElementById('spawn-house-name');
            const access = document.getElementById('spawn-house-access');
            const description = document.getElementById('spawn-house-description');
            if (name) name.textContent = home?.label || 'House';
            if (access) access.textContent = home?.access_type === 'owner' ? 'Your house' : 'Your rental';
            if (description) description.textContent = home?.access_type === 'owner'
                ? 'Spawn outside the house you own.' : 'Spawn outside the house you currently rent.';
        }
        const hq = data.factionHq;
        const hqCard = document.querySelector('[data-spawn="hq"]');
        if (hqCard) {
            const hasHq = Boolean(hq && hq.label);
            hqCard.classList.toggle('hidden', !hasHq);
            hqCard.disabled = !hasHq;
            const hqName = document.getElementById('spawn-hq-name');
            const hqAccess = document.getElementById('spawn-hq-access');
            const hqDescription = document.getElementById('spawn-hq-description');
            if (hqName) hqName.textContent = hq?.label || 'Faction HQ';
            if (hqAccess) hqAccess.textContent = hq?.hidden ? 'Hidden HQ' : 'Faction HQ';
            if (hqDescription) {
                hqDescription.textContent = hq?.hidden
                    ? `Spawn at ${hq.label} headquarters. Not shown on the public map.`
                    : `Spawn at ${hq?.label || 'your faction'} headquarters.`;
            }
        }
        this.select(last && !last.disabled ? 'last' : 'default');
    },
    select(location) {
        const target = document.querySelector(`[data-spawn="${location}"]`);
        if (!target || target.disabled || target.classList.contains('hidden')) return;
        this.selected = location;
        const cards = this.activeCards();
        const center = cards.indexOf(target);
        const gap = cards.length > 3 ? 215 : 270;
        cards.forEach((card, index) => {
            const offset = index - center;
            card.classList.toggle('is-selected', card === target);
            card.dataset.pos = String(offset);
            const scale = offset === 0 ? 1.08 : Math.max(0.58, 1.08 - Math.abs(offset) * 0.13);
            const opacity = offset === 0 ? 1 : Math.max(0.26, 0.82 - Math.abs(offset) * 0.2);
            const x = offset * gap;
            const rotate = -offset * 11;
            card.style.transform = `translate(-50%, -50%) translateX(${x}px) scale(${scale}) rotateY(${rotate}deg)`;
            card.style.opacity = String(opacity);
            card.style.zIndex = String(10 - Math.abs(offset));
            card.style.filter = offset === 0 ? 'none' : 'saturate(0.72)';
        });
    },
    move(direction) {
        const cards = this.activeCards();
        if (!cards.length) return;
        const current = Math.max(0, cards.findIndex((card) => card.dataset.spawn === this.selected));
        this.select(cards[(current + direction + cards.length) % cards.length].dataset.spawn);
    },
    confirm(location = this.selected) {
        if (this.busy) return;
        const target = document.querySelector(`[data-spawn="${location}"]`);
        if (!target || target.disabled || target.classList.contains('hidden')) return;
        this.busy = true;
        target.classList.add('is-confirming');
        document.querySelectorAll('.spawn-option').forEach((card) => { card.disabled = true; });
        post('spawnSelect', { location, propertyId: Number(target.dataset.propertyId || 0) || null });
    },
};
document.querySelectorAll('.spawn-option').forEach((card) => {
    card.addEventListener('mouseenter', () => SpawnSelector.select(card.dataset.spawn));
    card.addEventListener('focus', () => SpawnSelector.select(card.dataset.spawn));
    card.addEventListener('click', () => SpawnSelector.selected === card.dataset.spawn
        ? SpawnSelector.confirm() : SpawnSelector.select(card.dataset.spawn));
});
document.addEventListener('keydown', (event) => {
    if (window.App?.currentScreen !== 'spawn') return;
    if (['ArrowLeft', 'a', 'A'].includes(event.key)) SpawnSelector.move(-1);
    if (['ArrowRight', 'd', 'D'].includes(event.key)) SpawnSelector.move(1);
    if (event.key === 'Enter') SpawnSelector.confirm();
});
window.SpawnSelector = SpawnSelector;
