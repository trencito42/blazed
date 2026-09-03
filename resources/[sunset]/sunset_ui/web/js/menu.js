const Menu = {
    activeTab: 'player',

    init() {
        if (this._ready) return;
        this._ready = true;

        $('#menu-close-btn')?.addEventListener('click', () => this.close());
        $('#menu-exit-btn')?.addEventListener('click', () => this.close());

        $$('.menu-tab').forEach((tab) => {
            tab.addEventListener('click', () => this.setTab(tab.dataset.tab));
        });

        $$('.menu-action').forEach((btn) => {
            btn.addEventListener('click', () => {
                post('menuAction', { action: btn.dataset.action });
            });
        });
    },

    setTab(tab) {
        if (!tab) return;
        this.activeTab = tab;
        $$('.menu-tab').forEach((el) => el.classList.toggle('is-active', el.dataset.tab === tab));
        $$('.menu-panel-view').forEach((el) => el.classList.toggle('is-active', el.dataset.panel === tab));
    },

    formatXp(n) {
        return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    },

    update(data) {
        if (!data) return;
        this.init();

        $('#menu-name').textContent = (data.name || '—').toUpperCase();
        $('#menu-id').textContent = 'ID: ' + (data.id || 0);
        $('#menu-rank').textContent = data.rank || 'LOYAL PLAYER';
        $('#menu-cash').textContent = formatMoney(data.cash || 0);
        $('#menu-bank').textContent = formatMoney(data.bank || 0);
        $('#menu-premium').textContent = String(data.premium ?? 0);
        $('#menu-playtime').textContent = data.playtime || '0H 0M';
        $('#menu-lastlogin').textContent = data.lastLogin || '—';

        const xp = data.xp || 0;
        const xpMax = data.xpMax || 5000;
        const level = data.level || 1;
        $('#menu-xp-text').textContent = `${this.formatXp(xp)} / ${this.formatXp(xpMax)} XP`;
        $('#menu-level').textContent = `LEVEL ${level}`;
        const xpBar = $('#menu-xp-bar');
        if (xpBar) xpBar.style.width = `${Math.min(100, (xp / xpMax) * 100)}%`;

        const job = data.job || '—';
        $('#menu-job-vehicle').textContent = job;
        $('#menu-job-full').textContent = job;
        $('#menu-faction').textContent = data.faction || '—';
        $('#menu-payday').textContent = data.payday || '—';

        $('#menu-hunger-pct').textContent = `${Math.round(data.hunger ?? 100)}%`;
        $('#menu-thirst-pct').textContent = `${Math.round(data.thirst ?? 100)}%`;
        $('#menu-stamina-pct').textContent = `${Math.round(data.stamina ?? 100)}%`;
        $('#menu-fuel-pct').textContent = data.fuel != null ? `${Math.round(data.fuel)}%` : '—';

        const avatar = $('#menu-avatar');
        if (avatar && data.avatar) {
            avatar.style.backgroundImage = `url(${data.avatar})`;
        }
    },

    show(data) {
        this.init();
        this.setTab('player');
        $('#menu').classList.remove('hidden');
        this.update(data);
    },

    hide() {
        $('#menu').classList.add('hidden');
    },

    close() {
        post('menuClose');
    },
};

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#menu').classList.contains('hidden')) {
        Menu.close();
    }
});

window.Menu = Menu;
