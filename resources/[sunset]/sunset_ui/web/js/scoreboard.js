const Scoreboard = {
    myId: null,

    show(data) {
        const sb = $('#scoreboard');
        sb.classList.remove('hidden');
        $('#hud')?.classList.add('scoreboard-open');

        $('#sb-count').textContent = (data.count || 0) + '/' + (data.max || 48);
        $('#sb-tab-players').textContent = 'PLAYERS (' + (data.count || 0) + '/' + (data.max || 48) + ')';

        const body = $('#sb-body');
        body.innerHTML = '';

        (data.players || []).forEach(p => {
            const tr = document.createElement('tr');
            if (p.id === this.myId) tr.classList.add('is-self');

            const pingClass = p.ping < 80 ? 'ping-good' : p.ping < 150 ? 'ping-mid' : 'ping-bad';
            const adminDot = p.admin >= 5 ? '<span class="admin-badge admin-badge--5"></span>'
                : p.admin >= 3 ? '<span class="admin-badge admin-badge--3"></span>'
                : p.admin >= 2 ? '<span class="admin-badge admin-badge--2"></span>'
                : p.admin >= 1 ? '<span class="admin-badge admin-badge--1"></span>' : '';

            tr.innerHTML = `
                <td class="col-id">${p.id}</td>
                <td>${adminDot}${p.name}</td>
                <td class="col-ping ${pingClass}">${p.ping}</td>
                <td>${p.job}</td>
                <td>${p.level || 1}</td>
                <td class="col-money">${formatMoney(p.money)}</td>
            `;
            body.appendChild(tr);
        });
    },

    hide() {
        $('#scoreboard').classList.add('hidden');
        $('#hud')?.classList.remove('scoreboard-open');
    },
};

window.Scoreboard = Scoreboard;
