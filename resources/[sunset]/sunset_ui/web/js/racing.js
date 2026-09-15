/* ═══ STREET RACING — NUI controller ═══ */

const Racing = {
    status: null,
    selectedRoute: null,

    esc(value) {
        return String(value ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    },

    show(data) {
        this.status = data || {};
        this.selectedRoute = null;
        const el = $('#racing-overlay');
        if (!el) return;
        el.classList.remove('hidden');
        this.render();
    },

    hide() {
        const el = $('#racing-overlay');
        if (el) el.classList.add('hidden');
    },

    render() {
        const body = $('#racing-body');
        if (!body) return;

        const routes = this.status.routes || [];
        const inLobby = this.status.inLobby;
        const lobbyInfo = this.status.lobbyInfo;
        const entryFee = this.status.entryFee || 1000;
        const minPlayers = this.status.minPlayers || 1;
        const soloAvailable = this.status.soloAvailable !== false;
        const soloReward = this.status.soloReward || 500;
        const raceNightActive = this.status.raceNightActive;
        const raceNightPoints = this.status.raceNightPoints || 0;

        // Race Night banner
        let banner = '';
        if (raceNightActive) {
            banner = `<div class="racing-banner racing-banner--active">
                <span class="racing-banner__dot"></span>
                RACE NIGHT LIVE — ${raceNightPoints} pts
            </div>`;
        }

        if (inLobby && lobbyInfo) {
            const players = (lobbyInfo.players || []).map((p) =>
                `<span class="racing-lobby-player${p.isSelf ? ' is-self' : ''}">${this.esc(p.name)}</span>`
            ).join('');
            body.innerHTML = `${banner}
                <div class="racing-route is-selected">
                    <div class="racing-route__name">Lobby — ${this.esc(lobbyInfo.routeId || '')}</div>
                    <div class="racing-route__meta">
                        <span>Players: ${lobbyInfo.count || 0}/${minPlayers}</span>
                        <span>Entry: $${entryFee.toLocaleString()}</span>
                    </div>
                    <div class="racing-lobby-players">${players}</div>
                </div>
            `;
        } else {
            body.innerHTML = `${banner}
                ${routes.map((r) => `
                    <div class="racing-route" data-racing-route="${this.esc(r.id)}">
                        <div class="racing-route__name">${this.esc(r.label)}</div>
                        <div class="racing-route__desc">${this.esc(r.description || '')}</div>
                        <div class="racing-route__meta">
                            <span>${(r.checkpoints || []).length} CP</span>
                            <span>Entry: $${entryFee.toLocaleString()}</span>
                        </div>
                    </div>
                `).join('')}
                ${soloAvailable ? `
                    <div class="racing-solo-note">
                        Solo time trial available — reward $${soloReward.toLocaleString()} (5min cooldown)
                    </div>
                ` : ''}
            `;

            $$('[data-racing-route]').forEach((el) => {
                el.addEventListener('click', () => {
                    $$('[data-racing-route]').forEach((e) => e.classList.remove('is-selected'));
                    el.classList.add('is-selected');
                    this.selectedRoute = el.dataset.racingRoute;
                    $('#racing-join').disabled = false;
                });
            });
        }

        const joinBtn = $('#racing-join');
        const leaveBtn = $('#racing-leave');
        if (joinBtn) {
            joinBtn.disabled = inLobby || !this.selectedRoute;
            joinBtn.textContent = inLobby ? 'IN LOBBY' : 'JOIN RACE';
        }
        if (leaveBtn) {
            leaveBtn.classList.toggle('hidden', !inLobby);
        }
    },

    // ── Race HUD ──
    showHud(data) {
        let hud = $('#racing-hud');
        if (!hud) {
            hud = document.createElement('div');
            hud.id = 'racing-hud';
            hud.className = 'racing-hud';
            document.body.appendChild(hud);
        }
        hud.classList.remove('hidden');
        const soloTag = data.isSolo ? ' <span class="racing-hud__solo">TIME TRIAL</span>' : '';
        hud.innerHTML = `
            <div class="racing-hud__label">${this.esc(data.label || 'Race')}${soloTag}</div>
            <div class="racing-hud__progress">${data.currentCheckpoint || 0} / ${data.totalCheckpoints || 0}</div>
        `;
    },

    showCountdown(n) {
        let hud = $('#racing-hud');
        if (!hud) return;
        const existing = hud.querySelector('.racing-hud__countdown');
        if (existing) existing.remove();
        hud.innerHTML += `<div class="racing-hud__countdown">${n}</div>`;
    },

    showGo() {
        let hud = $('#racing-hud');
        if (!hud) return;
        const cd = hud.querySelector('.racing-hud__countdown');
        if (cd) cd.remove();
        hud.innerHTML += '<div class="racing-hud__go">GO!</div>';
        setTimeout(() => {
            const go = hud.querySelector('.racing-hud__go');
            if (go) go.remove();
        }, 2000);
    },

    showFinished(data) {
        let hud = $('#racing-hud');
        if (!hud) return;
        const pos = data.position || 0;
        const timeStr = data.timeFormatted || '--:--.---';
        hud.innerHTML += `<div class="racing-hud__result">🏁 #${pos} — ${timeStr}</div>`;
        setTimeout(() => this.hideHud(), 8000);
    },

    hideHud() {
        const hud = $('#racing-hud');
        if (hud) hud.classList.add('hidden');
    },
};

window.Racing = Racing;

// ── Close handlers ──
$('#racing-close')?.addEventListener('click', () => post('racingClose'));
$('#racing-join')?.addEventListener('click', () => {
    if (Racing.selectedRoute) post('racingJoin', { routeId: Racing.selectedRoute });
});
$('#racing-leave')?.addEventListener('click', () => post('racingLeave', {}));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const overlay = $('#racing-overlay');
    if (!overlay || overlay.classList.contains('hidden')) return;
    e.preventDefault();
    post('racingClose');
}, true);
