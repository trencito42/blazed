const Scoreboard = {
    myId: null,
    active: false,

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    },

    show(data) {
        data = data || {};
        this.active = true;
        const sb = document.getElementById('scoreboard');
        if (!sb) return;
        sb.classList.remove('hidden');
        sb.classList.add('is-active');
        sb.setAttribute('aria-hidden', 'false');
        document.body.classList.add('scoreboard-open');
        document.getElementById('hud')?.classList.add('scoreboard-open');

        const count = data.count || 0;
        const max = data.max || 48;
        const title = document.getElementById('sb-title-text');
        const countEl = document.getElementById('sb-title-count');
        if (title) title.textContent = data.serverName || 'Los Santos';
        if (countEl) countEl.textContent = `${count} / ${max}`;

        const stats = data.stats || {};
        const cops = document.getElementById('sb-stat-cops');
        const ems = document.getElementById('sb-stat-ems');
        const mech = document.getElementById('sb-stat-mech');
        if (cops) cops.textContent = `LSPD: ${stats.police || 0}`;
        if (ems) ems.textContent = `EMS: ${stats.ems || 0}`;
        if (mech) mech.textContent = `Mechanics: ${stats.mechanic || 0}`;

        const list = document.getElementById('sb-player-list');
        if (!list) return;
        list.innerHTML = '';

        (data.players || []).forEach((player) => {
            const row = document.createElement('div');
            row.className = 'sb-player' + (player.id === this.myId ? ' is-self' : '');
            const pingClass = player.ping < 80 ? '' : player.ping < 150 ? ' ping-mid' : ' ping-bad';
            const identity = window.SunsetPlayerIdentity;
            const playerName = identity
                ? identity.formatNameHtml(player)
                : this.escape(player.name || 'Player');
            row.innerHTML = `
                <div class="sb-id">${player.id}</div>
                <div class="sb-name">${playerName}</div>
                <div class="sb-ping${pingClass}"><i class="ph-bold ph-wifi-high"></i> ${player.ping}ms</div>
            `;
            list.appendChild(row);
        });
    },

    hide() {
        this.active = false;
        const sb = document.getElementById('scoreboard');
        if (sb) {
            sb.classList.add('hidden');
            sb.classList.remove('is-active');
            sb.setAttribute('aria-hidden', 'true');
        }
        document.body.classList.remove('scoreboard-open');
        document.getElementById('hud')?.classList.remove('scoreboard-open');
    },
};

window.Scoreboard = Scoreboard;
