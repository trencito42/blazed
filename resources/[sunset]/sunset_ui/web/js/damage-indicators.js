const DMG_ICONS = {
    health: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.7c-2.2 3.5-6.4 6.8-6.4 10.4a6.4 6.4 0 1 0 12.8 0c0-3.6-4.2-6.9-6.4-10.4z"/></svg>',
    armor: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2 4 5v6.1c0 4.6 3.4 8.9 8 10.9 4.6-2 8-6.3 8-10.9V5l-8-3z"/></svg>',
    crit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="12" x2="15" y2="15"/></svg>',
};

const DamageIndicators = {
    root: null,
    screenFlash: null,
    dmgContainer: null,
    markers: {},
    flashTimeout: null,
    active: false,

    init() {
        this.root = document.getElementById('damage-indicators');
        this.screenFlash = document.getElementById('dmg-screen-flash');
        this.dmgContainer = document.getElementById('dmg-container');
        this.markers = {
            top: document.getElementById('dmg-marker-top'),
            right: document.getElementById('dmg-marker-right'),
            bottom: document.getElementById('dmg-marker-bottom'),
            left: document.getElementById('dmg-marker-left'),
        };
    },

    setActive(active) {
        this.active = active === true;
        if (!this.root) this.init();
        this.root?.classList.toggle('hidden', !this.active);
    },

    takeDamage(amount, type = 'health', direction = null) {
        if (!this.active || !amount || amount < 1) return;
        if (!this.root) this.init();

        const dmgEl = document.createElement('div');
        const safeType = ['health', 'armor', 'crit'].includes(type) ? type : 'health';
        dmgEl.className = `dmg-number type-${safeType}`;
        dmgEl.innerHTML = `-${Math.floor(amount)} ${DMG_ICONS[safeType] || DMG_ICONS.health}`;

        const randomX = (Math.random() - 0.5) * 60;
        const randomY = (Math.random() - 0.5) * 40;
        dmgEl.style.left = `${randomX}px`;
        dmgEl.style.top = `${randomY}px`;
        this.dmgContainer?.appendChild(dmgEl);
        setTimeout(() => dmgEl.remove(), 800);

        clearTimeout(this.flashTimeout);
        if (this.screenFlash) {
            this.screenFlash.className = `dmg-screen-flash ${safeType}`;
            this.flashTimeout = setTimeout(() => {
                this.screenFlash.className = 'dmg-screen-flash';
            }, 150);
        }

        if (direction && this.markers[direction]) {
            const marker = this.markers[direction];
            if (safeType === 'armor') marker.style.stroke = '#3b82f6';
            else if (safeType === 'crit') marker.style.stroke = '#f59e0b';
            else marker.style.stroke = '#ff3366';
            marker.classList.remove('active');
            void marker.offsetWidth;
            marker.classList.add('active');
        }
    },
};

window.DamageIndicators = DamageIndicators;
DamageIndicators.init();

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    if (action === 'damageTaken' && data) {
        DamageIndicators.takeDamage(data.amount, data.type, data.direction);
    }
});
