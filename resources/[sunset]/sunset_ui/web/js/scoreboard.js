const Scoreboard = {
    myId: null,

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    },

    adminBadge(level) {
        if (level >= 5) return '<span class="sb-admin sb-admin--5" title="Owner"></span>';
        if (level >= 3) return '<span class="sb-admin sb-admin--3" title="Admin"></span>';
        if (level >= 2) return '<span class="sb-admin sb-admin--2" title="Moderator"></span>';
        if (level >= 1) return '<span class="sb-admin sb-admin--1" title="Helper"></span>';
        return '';
    },

    show(data) {
        data = data || {};
        const sb = $('#scoreboard');
        if (!sb) return;
        sb.classList.remove('hidden');
        $('#hud')?.classList.add('scoreboard-open');

        const count = data.count || 0;
        const max = data.max || 48;
        $('#sb-count').textContent = `${count}/${max}`;
        $('#sb-tab-players').textContent = `PLAYERS ${count}/${max}`;
        $('#sb-server-name').textContent = data.serverName || 'blaze.mp';

        const body = $('#sb-body');
        body.innerHTML = '';

        (data.players || []).forEach((player) => {
            const tr = document.createElement('tr');
            if (player.id === this.myId) tr.classList.add('is-self');

            const pingClass = player.ping < 80 ? 'ping-good' : player.ping < 150 ? 'ping-mid' : 'ping-bad';
            const identity = window.SunsetPlayerIdentity;
            const playerName = identity
                ? identity.formatNameHtml(player)
                : this.escape(player.name || 'Player');
            const factionName = identity
                ? identity.formatFactionHtml(player)
                : this.escape(player.factionLabel || player.job || 'Unemployed');
            const cash = Number(player.money);

            tr.innerHTML = `
                <td class="col-id">${player.id}</td>
                <td class="col-player">
                    ${this.adminBadge(player.admin)}
                    <span class="col-player__name">${playerName}</span>
                </td>
                <td class="col-faction">${factionName}</td>
                <td class="col-ping ${pingClass}">${player.ping}</td>
                <td class="col-level">${player.level || 1}</td>
                <td class="col-money">${formatMoney(Number.isFinite(cash) ? cash : 0)}</td>
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
