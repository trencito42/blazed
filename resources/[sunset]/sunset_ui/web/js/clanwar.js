// [WAR REDESIGN] Clan war UI — layout 1:1 from server redesign/clanwars.html.
// HUD (scores + timer), armory (loadout chooser), Z scoreboard, end screen,
// respawn countdown. All state is server-driven via Send() actions.
(() => {
    const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
    const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).catch(() => {});

    const WarUI = {
        active: false,
        data: null,
        armoryOpen: false,
        armoryData: null,
        selectedPkg: null,
        scoreboardVisible: false,

        ensureDom() {
            if (document.getElementById('war-hud-root')) return;
            const wrap = document.createElement('div');
            wrap.id = 'war-hud-root';
            wrap.innerHTML = `
                <div class="war-hud hidden" id="war-hud">
                    <div class="hud-panel" style="border-right: 4px solid var(--war-accent, #00ffcc);">
                        <div>
                            <div class="team-name" id="war-att-name">ATTACKERS</div>
                            <div class="team-score"><i class="ph-fill ph-shield-check" style="color: var(--war-accent, #00ffcc);"></i> <span class="score-val" id="war-att-score">0</span></div>
                        </div>
                    </div>
                    <div class="hud-panel hud-timer">
                        <div>
                            <div id="war-timer">10:00</div>
                            <div class="timer-label" id="war-turf-label">Turf</div>
                        </div>
                    </div>
                    <div class="hud-panel" style="border-left: 4px solid var(--war-enemy, #8b5cf6);">
                        <div style="text-align: right;">
                            <div class="team-name" style="color: var(--war-enemy, #8b5cf6);" id="war-def-name">DEFENDERS</div>
                            <div class="team-score" style="justify-content: flex-end;"><span class="score-val enemy" id="war-def-score">0</span> <i class="ph-fill ph-skull" style="color: var(--war-enemy, #8b5cf6);"></i></div>
                        </div>
                    </div>
                </div>

                <div class="armory-wrapper" id="war-armory">
                    <div class="sidebar">
                        <div class="sidebar-header">
                            <h1>Armurărie War</h1>
                            <p id="war-armory-sub">Alege-ți armele pentru war</p>
                        </div>
                        <div class="package-list" id="war-package-list"></div>
                    </div>
                    <div class="content">
                        <div class="content-header">
                            <h2 class="ch-title" id="war-det-name">PACHET</h2>
                        </div>
                        <div class="weapon-list" id="war-weapon-list"></div>
                        <div class="spawn-actions">
                            <button class="btn btn-equip" id="war-equip-btn"><i class="ph-bold ph-crosshair-simple"></i> Echipează Pachetul</button>
                            <button class="btn btn-close-war" id="war-armory-close"><i class="ph-bold ph-x"></i> Închide</button>
                        </div>
                    </div>
                </div>

                <div class="war-scoreboard" id="war-scoreboard">
                    <div class="sb-header">
                        <div>
                            <h2 class="sb-title">Statistici War</h2>
                            <div class="sb-subtitle" id="war-sb-turf">Turf</div>
                        </div>
                        <i class="ph-bold ph-crosshair" style="color: var(--war-accent, #00ffcc); font-size: 24px; transform: skewX(5deg);"></i>
                    </div>
                    <div class="sb-score-row"><span id="war-sb-att" style="color:var(--war-accent,#00ffcc);">ATK 0</span><span id="war-sb-target" style="color:rgba(255,255,255,0.4);">/ 300</span><span id="war-sb-def" style="color:var(--war-enemy,#8b5cf6);">0 DEF</span></div>
                    <div class="sb-list-container">
                        <div class="sb-col-headers">
                            <div class="col-name">Jucător</div>
                            <div class="col-stat">Kills</div>
                            <div class="col-stat">Deaths</div>
                        </div>
                        <div id="war-sb-list"></div>
                    </div>
                </div>

                <div class="war-end-screen" id="war-end-screen">
                    <div class="end-banner" id="war-end-banner">
                        <h1 class="end-status" id="war-end-title">TURF CUCERIT!</h1>
                        <div class="end-turf" id="war-end-turf">Turf</div>
                    </div>
                    <div class="end-content">
                        <div class="final-score-row">
                            <div class="team-final">
                                <span class="team-final-name" style="color: var(--war-accent,#00ffcc);" id="war-end-att-name">ATK</span>
                                <span class="team-final-score" style="color: var(--war-accent,#00ffcc);" id="war-end-att-score">0</span>
                            </div>
                            <div class="score-separator">VS</div>
                            <div class="team-final">
                                <span class="team-final-name" style="color: var(--war-enemy,#8b5cf6);" id="war-end-def-name">DEF</span>
                                <span class="team-final-score" style="color: var(--war-enemy,#8b5cf6);" id="war-end-def-score">0</span>
                            </div>
                        </div>
                        <div class="mvp-box" id="war-mvp-box">
                            <div class="mvp-icon"><i class="ph-fill ph-crown"></i></div>
                            <div class="mvp-details">
                                <div class="mvp-label">MVP-ul War-ului</div>
                                <div class="mvp-name" id="war-mvp-name">—</div>
                                <div class="mvp-stats">
                                    <div>Kills: <span id="war-mvp-kills">0</span></div>
                                    <div>Deaths: <span id="war-mvp-deaths">0</span></div>
                                </div>
                            </div>
                        </div>
                        <button class="btn-close" id="war-end-close">Închide Rezumatul</button>
                    </div>
                </div>

                <div class="war-respawn-box hidden" id="war-respawn">
                    <div class="rr-title">Ai căzut în war</div>
                    <div class="rr-count" id="war-respawn-count">5</div>
                    <div class="rr-hint">Revin în zona turfului…</div>
                </div>
            `;
            document.body.appendChild(wrap);

            document.getElementById('war-armory-close')?.addEventListener('click', () => post('warArmoryClose'));
            document.getElementById('war-equip-btn')?.addEventListener('click', () => {
                if (this.selectedPkg) post('warTakeLoadout', { loadoutId: this.selectedPkg });
            });
            document.getElementById('war-end-close')?.addEventListener('click', () => {
                document.getElementById('war-end-screen')?.classList.remove('active');
                post('warEndClose');
            });
        },

        showHud(data) {
            this.ensureDom();
            this.active = true;
            this.data = data;
            const hud = document.getElementById('war-hud');
            hud?.classList.remove('hidden');
            this.updateHud(data);
        },

        updateHud(data) {
            if (!data) return;
            this.data = data;
            const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
            set('war-att-name', data.attackerName || 'ATTACKERS');
            set('war-def-name', data.defenderName || 'DEFENDERS');
            set('war-att-score', String(data.attackerScore || 0));
            set('war-def-score', String(data.defenderScore || 0));
            const rem = Math.max(0, data.remainingSec || 0);
            set('war-timer', `${String(Math.floor(rem / 60)).padStart(2, '0')}:${String(rem % 60).padStart(2, '0')}`);
            const label = data.scoreTarget
                ? `Turf: ${data.turfName || ''} • ${data.scoreTarget} pts`
                : `Turf: ${data.turfName || ''}`;
            set('war-turf-label', label);
        },

        hideHud() {
            this.active = false;
            document.getElementById('war-hud')?.classList.add('hidden');
            this.hideScoreboard();
        },

        showArmory(data) {
            this.ensureDom();
            this.armoryData = data;
            const modal = document.getElementById('war-armory');
            modal?.classList.add('active');
            this.armoryOpen = true;
            const sub = document.getElementById('war-armory-sub');
            if (sub) sub.textContent = data.turfName ? `War: ${data.turfName} (${data.role === 'attacker' ? 'atacator' : 'aparare'})` : 'Alege-ți armele pentru war';
            this.renderPackages(data.packages || []);
        },

        renderPackages(packages) {
            const list = document.getElementById('war-package-list');
            if (!list) return;
            list.innerHTML = '';
            packages.forEach((p) => {
                const el = document.createElement('div');
                el.className = `package-item ${this.selectedPkg === p.id ? 'selected' : ''}`;
                const costLabel = p.cost > 0 ? `$${Number(p.cost).toLocaleString('en-US')}` : (p.rank > 1 ? `Gratuit (Rank ${p.rank}+)` : 'Gratuit');
                el.innerHTML = `
                    <div class="pkg-info">
                        <span class="pkg-name">${esc(p.name)}</span>
                        <span class="pkg-cost"><i class="ph-bold ph-coins"></i> ${esc(costLabel)}</span>
                    </div>
                    ${p.rankOk ? '' : '<span class="pkg-locked">Rank blocat</span>'}
                `;
                el.addEventListener('click', () => this.selectPackage(p.id));
                list.appendChild(el);
            });
            if (!this.selectedPkg && packages.length) this.selectPackage(packages[0].id);
        },

        selectPackage(id) {
            this.selectedPkg = id;
            const pkg = (this.armoryData?.packages || []).find((p) => p.id === id);
            document.querySelectorAll('#war-package-list .package-item').forEach((el, i) => {
                const list = this.armoryData?.packages || [];
                el.classList.toggle('selected', list[i] && list[i].id === id);
            });
            if (!pkg) return;
            const det = document.getElementById('war-det-name');
            if (det) det.textContent = pkg.name;
            const wList = document.getElementById('war-weapon-list');
            if (wList) {
                wList.innerHTML = (pkg.weapons || []).map((w) => `
                    <div class="weapon-row">
                        <div class="weapon-icon-box"><i class="ph-fill ph-crosshair"></i></div>
                        <div class="weapon-details">
                            <span class="weapon-name">${esc(w.label)}</span>
                            <span class="weapon-ammo">${esc(w.ammo)} gloanțe</span>
                        </div>
                        <div class="weapon-tag">${esc(w.tag)}</div>
                    </div>
                `).join('');
            }
        },

        hideArmory() {
            this.armoryOpen = false;
            document.getElementById('war-armory')?.classList.remove('active');
        },

        showScoreboard(data) {
            this.ensureDom();
            const sb = document.getElementById('war-scoreboard');
            sb?.classList.add('active');
            this.scoreboardVisible = true;
            if (!data) return;
            const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
            set('war-sb-turf', data.turfName || 'Turf');
            set('war-sb-att', `${data.attackerName || 'ATK'} ${data.attackerScore || 0}`);
            set('war-sb-def', `${data.defenderScore || 0} ${data.defenderName || 'DEF'}`);
            set('war-sb-target', data.scoreTarget ? `/ ${data.scoreTarget}` : '');
            const list = document.getElementById('war-sb-list');
            if (list) {
                list.innerHTML = (data.rows || []).map((r) => `
                    <div class="sb-player">
                        <div class="sb-name ${r.side === 'attacker' ? 'is-ally' : 'is-enemy'}">${esc(r.name)}</div>
                        <div class="sb-kills">${Number(r.kills) || 0}</div>
                        <div class="sb-deaths">${Number(r.deaths) || 0}</div>
                    </div>
                `).join('');
            }
        },

        hideScoreboard() {
            this.scoreboardVisible = false;
            document.getElementById('war-scoreboard')?.classList.remove('active');
        },

        showEnd(data) {
            this.ensureDom();
            const screen = document.getElementById('war-end-screen');
            const banner = document.getElementById('war-end-banner');
            const title = document.getElementById('war-end-title');
            const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
            // "won" is relative to the local player's side (server sends attackerWon + myRole)
            const won = data.myRole === 'attacker' ? !!data.attackerWon : !data.attackerWon;
            banner?.classList.toggle('lost', !won);
            if (title) {
                title.textContent = won ? 'TURF CUCERIT!' : 'TURF PIERDUT!';
                title.style.color = won ? 'var(--war-accent, #00ffcc)' : 'var(--war-danger, #ff3366)';
            }
            set('war-end-turf', `Turf #${data.turfId || '?'} • ${data.turfName || ''}`);
            set('war-end-att-name', data.attackerName || 'ATK');
            set('war-end-def-name', data.defenderName || 'DEF');
            set('war-end-att-score', String(data.attackerScore || 0));
            set('war-end-def-score', String(data.defenderScore || 0));
            const mvpBox = document.getElementById('war-mvp-box');
            if (data.mvp) {
                mvpBox?.style.setProperty('display', 'flex');
                set('war-mvp-name', data.mvp.name);
                set('war-mvp-kills', String(data.mvp.kills || 0));
                set('war-mvp-deaths', String(data.mvp.deaths || 0));
            } else {
                mvpBox?.style.setProperty('display', 'none');
            }
            screen?.classList.add('active');
        },

        hideEnd() {
            document.getElementById('war-end-screen')?.classList.remove('active');
        },

        showRespawn(seconds) {
            this.ensureDom();
            const box = document.getElementById('war-respawn');
            box?.classList.remove('hidden');
            const el = document.getElementById('war-respawn-count');
            if (el) el.textContent = String(Math.max(0, Math.ceil(seconds)));
        },

        hideRespawn() {
            document.getElementById('war-respawn')?.classList.add('hidden');
        },
    };

    window.addEventListener('message', (event) => {
        const { action, data } = event.data || {};
        switch (action) {
            case 'warHudShow': WarUI.showHud(data); break;
            case 'warHudUpdate': if (WarUI.active) WarUI.updateHud(data); break;
            case 'warHudHide': WarUI.hideHud(); break;
            case 'warArmoryShow': WarUI.showArmory(data); break;
            case 'warArmoryHide': WarUI.hideArmory(); break;
            case 'warScoreboardShow': WarUI.showScoreboard(data); break;
            case 'warScoreboardHide': WarUI.hideScoreboard(); break;
            case 'warEndShow': WarUI.showEnd(data); break;
            case 'warEndHide': WarUI.hideEnd(); break;
            case 'warRespawnShow': WarUI.showRespawn(data?.seconds || 5); break;
            case 'warRespawnHide': WarUI.hideRespawn(); break;
            case 'sessionForceClose': WarUI.hideArmory(); WarUI.hideEnd(); WarUI.hideRespawn(); WarUI.hideScoreboard(); break;
            default: break;
        }
    });

    window.WarUI = WarUI;
})();
