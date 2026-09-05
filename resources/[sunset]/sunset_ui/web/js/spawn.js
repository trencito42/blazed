const SpawnSelector = {
    selected: 'last',
    busy: false,

    show(data = {}) {
        this.busy = false;
        const hasLast = data.hasLastLocation !== false;
        const last = document.querySelector('[data-spawn="last"]');
        if (last) last.disabled = !hasLast;
        this.select(hasLast ? 'last' : 'default');
    },

    select(location) {
        const target = document.querySelector(`[data-spawn="${location}"]`);
        if (!target || target.disabled) return;
        this.selected = location;
        document.querySelectorAll('.spawn-option').forEach((card) => {
            card.classList.toggle('is-selected', card === target);
        });
    },

    confirm(location = this.selected) {
        if (this.busy) return;
        const target = document.querySelector(`[data-spawn="${location}"]`);
        if (!target || target.disabled) return;
        this.busy = true;
        document.querySelectorAll('.spawn-option').forEach((card) => { card.disabled = true; });
        post('spawnSelect', { location });
    },
};

document.querySelectorAll('.spawn-option').forEach((card) => {
    card.addEventListener('mouseenter', () => SpawnSelector.select(card.dataset.spawn));
    card.addEventListener('focus', () => SpawnSelector.select(card.dataset.spawn));
    card.addEventListener('click', () => SpawnSelector.confirm(card.dataset.spawn));
});

document.addEventListener('keydown', (event) => {
    if (window.App?.currentScreen !== 'spawn') return;
    if (['ArrowLeft', 'a', 'A'].includes(event.key)) SpawnSelector.select('last');
    if (['ArrowRight', 'd', 'D'].includes(event.key)) SpawnSelector.select('default');
    if (event.key === 'Enter') SpawnSelector.confirm();
});

window.SpawnSelector = SpawnSelector;
