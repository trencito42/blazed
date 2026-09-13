(() => {
    const root = document.getElementById('battlepass-modal');
    if (!root) return;

    const postNui = (name, payload = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    }).catch(() => {});

    let playerData = {
        level: 4,
        currentXP: 800,
        maxXP: 1000,
        hasPremium: false
    };

    let bpTiers = [];
    for (let i = 1; i <= 15; i++) {
        bpTiers.push({
            level: i,
            free: { name: `$${i * 1000}`, icon: '💵', claimed: i < 3 },
            premium: { name: i % 5 === 0 ? 'VIP Vehicle' : `Crate Lvl ${i}`, icon: i % 5 === 0 ? '🏎️' : '📦', claimed: false }
        });
    }

    let missions = [
        { id: 1, type: 'daily', title: 'Model Driver', desc: 'Drive a total of 15km without hitting a vehicle.', progress: 15, max: 15, reward: '500 XP', claimed: false },
        { id: 2, type: 'daily', title: 'Hard Worker', desc: 'Complete 3 shifts as a Courier.', progress: 1, max: 3, reward: '300 XP', claimed: false },
        { id: 3, type: 'daily', title: 'Time with Friends', desc: 'Spend 2 hours active on the server.', progress: 120, max: 120, reward: '400 XP', claimed: true },
        { id: 4, type: 'weekly', title: 'Local Magnate', desc: 'Earn a total of $50,000.', progress: 32000, max: 50000, reward: '2500 XP', claimed: false },
        { id: 5, type: 'weekly', title: 'Wanted Criminal', desc: 'Successfully escape from 3 car robberies.', progress: 3, max: 3, reward: '3000 XP', claimed: false }
    ];

    function updatePlayerStats() {
        const lvlEl = document.getElementById('bp-ui-lvl');
        const xpTextEl = document.getElementById('bp-ui-xp-text');
        const xpBarEl = document.getElementById('bp-ui-xp-bar');
        const premBox = document.getElementById('bp-premium-box');

        if (lvlEl) lvlEl.innerText = playerData.level;
        if (xpTextEl) xpTextEl.innerText = `${playerData.currentXP} / ${playerData.maxXP} XP`;
        if (xpBarEl) {
            const pct = Math.min(100, Math.max(0, (playerData.currentXP / playerData.maxXP) * 100));
            xpBarEl.style.width = `${pct}%`;
        }
        if (premBox) {
            if (playerData.hasPremium) {
                premBox.innerHTML = `<div style="text-align:center; color:#b829ff; font-weight:800; font-size:12px; letter-spacing:1px;">✔️ PREMIUM ACTIVE</div>`;
            } else {
                premBox.innerHTML = `
                    <button class="bp-btn-upgrade" id="bp-btn-buy-premium">
                        <svg viewBox="0 0 24 24" style="width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:2;"><path d="M2.5 2v6h13V2zM2.5 13v6h13v-6z"></path><path d="M18.5 2l3 6-3 6"></path></svg>
                        Buy Premium
                    </button>`;
                document.getElementById('bp-btn-buy-premium')?.addEventListener('click', buyPremium);
            }
        }
    }

    function renderBattlepass() {
        const track = document.getElementById('bp-track');
        if (!track) return;
        track.innerHTML = '';

        const fillWidth = Math.min(((playerData.level - 1) / Math.max(1, bpTiers.length - 1)) * 100, 100);
        track.innerHTML += `
            <div class="bp-line-bg"></div>
            <div class="bp-line-fill" style="width: ${fillWidth}%;"></div>
        `;

        bpTiers.forEach(tier => {
            const isCompleted = playerData.level > tier.level;
            const isCurrent = playerData.level === tier.level;

            let classState = '';
            if (isCompleted) classState = 'completed';
            if (isCurrent) classState = 'current';

            let freeBtnHtml = '';
            if (tier.free.claimed) {
                freeBtnHtml = `<button class="bp-btn-claim claimed">Luat</button>`;
            } else if (playerData.level >= tier.level) {
                freeBtnHtml = `<button class="bp-btn-claim" data-claim-lvl="${tier.level}" data-claim-type="free">Claim</button>`;
            } else {
                freeBtnHtml = `<button class="bp-btn-claim" style="display:none;"></button>`;
            }

            let premBtnHtml = '';
            let premLockHtml = '';
            if (!playerData.hasPremium) {
                premLockHtml = `
                    <div class="bp-reward-locked-overlay">
                        <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
                        <span class="bp-lock-text">LOCKED</span>
                    </div>`;
            } else {
                if (tier.premium.claimed) {
                    premBtnHtml = `<button class="bp-btn-claim claimed">Luat</button>`;
                } else if (playerData.level >= tier.level) {
                    premBtnHtml = `<button class="bp-btn-claim" style="background:#b829ff; color:white;" data-claim-lvl="${tier.level}" data-claim-type="premium">Claim</button>`;
                }
            }

            const tierEl = document.createElement('div');
            tierEl.className = `bp-tier ${classState}`;
            tierEl.innerHTML = `
                <div class="bp-reward-card">
                    <span class="bp-reward-type-label">FREE</span>
                    <div class="bp-reward-icon">${tier.free.icon}</div>
                    <div class="bp-reward-name">${tier.free.name}</div>
                    ${freeBtnHtml}
                </div>
                <div class="bp-level-marker">${tier.level}</div>
                <div class="bp-reward-card bp-reward-premium">
                    <span class="bp-reward-type-label bp-label-premium">PREMIUM</span>
                    ${premLockHtml}
                    <div class="bp-reward-icon">${tier.premium.icon}</div>
                    <div class="bp-reward-name">${tier.premium.name}</div>
                    ${premBtnHtml}
                </div>
            `;
            track.appendChild(tierEl);
        });

        track.querySelectorAll('[data-claim-lvl]').forEach(btn => {
            btn.addEventListener('click', () => {
                const lvl = Number(btn.dataset.claimLvl);
                const type = btn.dataset.claimType;
                claimBP(lvl, type);
            });
        });

        setTimeout(() => {
            const currentEl = track.querySelector('.bp-tier.current');
            if (currentEl) currentEl.scrollIntoView({ inline: 'center', behavior: 'smooth' });
        }, 400);
    }

    function renderMissions() {
        const dailyList = document.getElementById('bp-daily-list');
        const weeklyList = document.getElementById('bp-weekly-list');
        if (!dailyList || !weeklyList) return;
        dailyList.innerHTML = '';
        weeklyList.innerHTML = '';

        missions.forEach(m => {
            const pct = Math.min(100, Math.max(0, (m.progress / m.max) * 100));
            const isDone = m.progress >= m.max;

            let btnHtml = '';
            if (m.claimed) {
                btnHtml = `<button class="bp-btn" disabled>Colectat</button>`;
            } else if (isDone) {
                btnHtml = `<button class="bp-btn bp-btn-primary" data-mission-id="${m.id}">Collect</button>`;
            } else {
                btnHtml = `<button class="bp-btn" disabled>In Progress</button>`;
            }

            const cardHtml = `
                <div class="bp-mission-info">
                    <div class="bp-mission-title">${m.title}</div>
                    <div class="bp-mission-desc">${m.desc}</div>
                </div>
                <div class="bp-mission-progress-container">
                    <div class="bp-mission-progress-text">${m.progress} / ${m.max}</div>
                    <div class="bp-mission-bar-bg">
                        <div class="bp-mission-bar-fill" style="width: ${pct}%;"></div>
                    </div>
                </div>
                <div class="bp-mission-reward">
                    <span class="bp-mission-reward-val">
                        <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                        ${m.reward}
                    </span>
                    ${btnHtml}
                </div>
            `;

            const el = document.createElement('div');
            el.className = `bp-mission-card ${isDone ? 'completed' : ''} ${m.type === 'weekly' ? 'weekly' : ''}`;
            el.innerHTML = cardHtml;

            if (m.type === 'daily') dailyList.appendChild(el);
            else weeklyList.appendChild(el);
        });

        document.querySelectorAll('[data-mission-id]').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = Number(btn.dataset.missionId);
                claimMission(id);
            });
        });
    }

    function switchTab(tabId) {
        document.querySelectorAll('.bp-nav-item').forEach(el => el.classList.remove('active'));
        document.querySelectorAll('.bp-tab-section').forEach(el => el.classList.remove('active'));

        const targetBtn = document.querySelector(`.bp-nav-item[data-tab="${tabId}"]`);
        const targetTab = document.getElementById(`bp-tab-${tabId}`);
        if (targetBtn) targetBtn.classList.add('active');
        if (targetTab) targetTab.classList.add('active');
    }

    function claimBP(level, type) {
        const tier = bpTiers.find(t => t.level === level);
        if (tier && !tier[type].claimed) {
            tier[type].claimed = true;
            renderBattlepass();
            postNui('battlepassClaim', { level, type });
        }
    }

    function claimMission(id) {
        const m = missions.find(x => x.id === id);
        if (m && !m.claimed && m.progress >= m.max) {
            m.claimed = true;
            let xpGain = parseInt(m.reward) || 300;
            playerData.currentXP += xpGain;
            if (playerData.currentXP >= playerData.maxXP) {
                playerData.level++;
                playerData.currentXP -= playerData.maxXP;
            }
            updatePlayerStats();
            renderMissions();
            renderBattlepass();
            postNui('missionClaim', { id });
        }
    }

    function buyPremium() {
        playerData.hasPremium = true;
        updatePlayerStats();
        renderBattlepass();
        postNui('battlepassBuyPremium', {});
    }

    function show(data = {}) {
        if (data.level != null) playerData.level = Number(data.level) || playerData.level;
        if (data.currentXP != null) playerData.currentXP = Number(data.currentXP) || playerData.currentXP;
        if (data.maxXP != null) playerData.maxXP = Number(data.maxXP) || playerData.maxXP;
        if (data.hasPremium != null) playerData.hasPremium = Boolean(data.hasPremium);
        if (Array.isArray(data.tiers)) bpTiers = data.tiers;
        if (Array.isArray(data.missions)) missions = data.missions;

        updatePlayerStats();
        renderBattlepass();
        renderMissions();

        if (data.tab) switchTab(data.tab);
        root.classList.remove('hidden');
        root.setAttribute('aria-hidden', 'false');
    }

    function hide() {
        root.classList.add('hidden');
        root.setAttribute('aria-hidden', 'true');
        postNui('battlepassClose');
    }

    document.querySelectorAll('.bp-nav-item').forEach(btn => {
        btn.addEventListener('click', () => {
            const tab = btn.dataset.tab;
            if (tab) switchTab(tab);
        });
    });

    document.addEventListener('keydown', (e) => {
        if (root.classList.contains('hidden')) return;
        if (e.key === 'Escape') {
            e.preventDefault();
            hide();
        }
    });

    window.Battlepass = { show, hide, switchTab, claimBP, claimMission };

    const qa = new URLSearchParams(location.search).get('qa');
    if (qa === 'battlepass' || qa === 'pass') {
        show({ tab: 'battlepass' });
    } else if (qa === 'missions') {
        show({ tab: 'daily' });
    }
})();
