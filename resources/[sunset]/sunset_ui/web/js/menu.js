const Menu = {
    update(data) {
        if (!data) return;
        $('#menu-name').textContent = data.name || '—';
        $('#menu-id').textContent = 'ID: ' + (data.id || 0);
        $('#menu-cash').textContent = formatMoney(data.cash || 0);
        $('#menu-bank').textContent = formatMoney(data.bank || 0);
        $('#menu-job').textContent = data.job || '—';
        $('#menu-faction').textContent = data.faction || '—';
        $('#menu-payday').textContent = data.payday || '—';

        this.setBar('menu-health', 'menu-health-val', data.health);
        this.setBar('menu-armor', 'menu-armor-val', data.armor);
        this.setBar('menu-hunger', 'menu-hunger-val', data.hunger);
        this.setBar('menu-thirst', 'menu-thirst-val', data.thirst);
    },

    setBar(barId, valId, pct) {
        const v = Math.round(Math.max(0, Math.min(100, pct || 0)));
        const bar = document.getElementById(barId);
        const val = document.getElementById(valId);
        if (bar) bar.style.width = v + '%';
        if (val) val.textContent = v + '%';
    },

    show(data) {
        $('#menu').classList.remove('hidden');
        this.update(data);
    },

    hide() {
        $('#menu').classList.add('hidden');
    },
};

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#menu').classList.contains('hidden')) {
        post('menuClose');
    }
});

window.Menu = Menu;
