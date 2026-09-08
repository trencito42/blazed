const ITEM_ICON_ROOT = 'nui://sunset_ui/web/assets/items/';
const ITEM_ICON_FALLBACK = `${ITEM_ICON_ROOT}backpack.webp`;

const ICON_ALIASES = {
    cash: 'cash_stack',
    bank: 'bank_card',
    coins: 'casinochips',
};

function itemIconUrl(icon, rewardType) {
    let key = String(icon || '').trim();
    if (key === 'cash' && rewardType === 'bank') key = 'bank';
    key = ICON_ALIASES[key] || key;
    if (!key) return ITEM_ICON_FALLBACK;
    return `${ITEM_ICON_ROOT}${key}.webp`;
}

function rewardArt(reward) {
    if (!reward) return '';
    const src = itemIconUrl(reward.icon, reward.type);
    return `<img src="${src}" alt="" loading="eager" onerror="this.onerror=null;this.src='${ITEM_ICON_FALLBACK}'">`;
}

function missionIconArt(icon) {
    const src = itemIconUrl(icon);
    return `<img src="${src}" alt="" loading="eager" onerror="this.onerror=null;this.src='${ITEM_ICON_FALLBACK}'">`;
}

const state = {
    tab: 'battlepass',
    data: null,
};

function post(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((res) => res.json()).catch(() => ({}));
}

function showNotify(msg) {
    const el = document.getElementById('notify');
    const msgEl = document.getElementById('notify-msg');
    if (msgEl) msgEl.innerText = msg;
    if (el) {
        el.classList.add('show');
        setTimeout(() => el.classList.remove('show'), 3000);
    }
}

function switchTab(tabId) {
    let normalizedTab = tabId;
    if (tabId === 'rewards') normalizedTab = 'battlepass';
    if (tabId === 'missions') normalizedTab = 'daily';

    state.tab = normalizedTab;

    document.querySelectorAll('.nav-item').forEach((el) => {
        el.classList.toggle('active', el.dataset.tab === normalizedTab);
    });

    document.querySelectorAll('.tab-section').forEach((el) => {
        el.classList.toggle('active', el.id === `tab-${normalizedTab}`);
    });

    post('passSetTab', { tab: normalizedTab });
}

function updatePlayerStats(data) {
    if (!data) return;

    const lvlEl = document.getElementById('ui-lvl');
    if (lvlEl) lvlEl.innerText = data.tier || 1;

    const xpTextEl = document.getElementById('ui-xp-text');
    const xpBarEl = document.getElementById('ui-xp-bar');
    const tierXp = data.tierXp || 0;
    const tierGoal = data.tierGoal || 500;

    if (xpTextEl) xpTextEl.innerText = `${tierXp} / ${tierGoal} XP`;
    if (xpBarEl) {
        const pct = Math.min(100, Math.max(0, (tierXp / tierGoal) * 100));
        xpBarEl.style.width = `${pct}%`;
    }

    const seasonTitle = document.getElementById('season-title');
    if (seasonTitle && data.seasonLabel) seasonTitle.innerText = data.seasonLabel.toUpperCase();

    const premiumBox = document.getElementById('premium-box');
    if (premiumBox) {
        if (data.premium) {
            premiumBox.innerHTML = `
                <div style="text-align:center; color:var(--premium); font-weight:800; font-size:12px; letter-spacing:1px; padding:15px; background:rgba(184, 41, 255, 0.1); border:1px solid rgba(184, 41, 255, 0.3); border-radius:var(--radius-md);">
                    ✔️ PREMIUM ACTIVAT
                </div>`;
        } else {
            const costLabel = data.premiumCostLabel || `${data.premiumCost || 250} BP`;
            premiumBox.innerHTML = `
                <button class="btn-upgrade" id="btn-upgrade" onclick="buyPremium()">
                    <svg viewBox="0 0 24 24" style="width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:2;"><path d="M2.5 2v6h13V2zM2.5 13v6h13v-6z"></path><path d="M18.5 2l3 6-3 6"></path></svg>
                    <span>Cumpără Premium (${costLabel})</span>
                </button>`;
        }
    }
}

async function buyPremium() {
    const res = await post('passBuyPremium');
    if (res?.state) {
        showNotify('Premium Activat!');
        renderAll(res.state);
        return;
    }
    if (res?.error) {
        showNotify(res.error);
    }
}

async function claimBP(level, track) {
    const res = await post('passClaim', { level: Number(level), track });
    if (res?.state) {
        showNotify(`Recompensă Nivel ${level} Colectată!`);
        renderAll(res.state);
    }
}

function renderBattlepass(data) {
    const track = document.getElementById('bp-track');
    if (!track || !data) return;

    track.innerHTML = '';
    const tiers = data.tiers || [];
    const currentTier = data.tier || 1;
    const hasPremium = !!data.premium;

    let fillWidth = 0;
    if (tiers.length > 1) {
        const currentIdx = Math.max(0, currentTier - 1);
        fillWidth = Math.min(100, (currentIdx / (tiers.length - 1)) * 100);
    }

    track.innerHTML += `
        <div class="bp-line-bg"></div>
        <div class="bp-line-fill" style="width: ${fillWidth}%;"></div>
    `;

    tiers.forEach((tier) => {
        const isCompleted = currentTier > tier.level;
        const isCurrent = currentTier === tier.level;

        let classState = '';
        if (isCompleted) classState = 'completed';
        if (isCurrent) classState = 'current';

        // Free Reward
        let freeBtnHtml = '';
        if (tier.free) {
            if (tier.free.claimed) {
                freeBtnHtml = `<button class="btn-claim claimed">Luat</button>`;
            } else if (currentTier >= tier.level) {
                freeBtnHtml = `<button class="btn-claim" onclick="claimBP(${tier.level}, 'free')">Revendică</button>`;
            }
        }

        // Premium Reward
        let premBtnHtml = '';
        let premLockHtml = '';

        if (tier.premium) {
            if (!hasPremium) {
                premLockHtml = `
                    <div class="reward-locked-overlay">
                        <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
                        <span class="lock-text">LOCKED</span>
                    </div>`;
            } else {
                if (tier.premium.claimed) {
                    premBtnHtml = `<button class="btn-claim claimed">Luat</button>`;
                } else if (currentTier >= tier.level) {
                    premBtnHtml = `<button class="btn-claim btn-premium" onclick="claimBP(${tier.level}, 'premium')">Revendică</button>`;
                }
            }
        }

        const tierEl = document.createElement('div');
        tierEl.className = `bp-tier ${classState}`;

        tierEl.innerHTML = `
            <!-- FREE REWARD (TOP) -->
            <div class="reward-card">
                <span class="reward-type-label">FREE</span>
                <div class="reward-icon">${rewardArt(tier.free)}</div>
                <div class="reward-name">${tier.free ? tier.free.label : '—'}</div>
                ${freeBtnHtml}
            </div>

            <!-- LEVEL MARKER (MIDDLE) -->
            <div class="bp-level-marker">${tier.level}</div>

            <!-- PREMIUM REWARD (BOTTOM) -->
            <div class="reward-card reward-premium">
                <span class="reward-type-label label-premium">PREMIUM</span>
                ${premLockHtml}
                <div class="reward-icon">${rewardArt(tier.premium)}</div>
                <div class="reward-name">${tier.premium ? tier.premium.label : '—'}</div>
                ${premBtnHtml}
            </div>
        `;

        track.appendChild(tierEl);
    });

    const currentEl = track.querySelector('.bp-tier.current');
    if (currentEl) {
        currentEl.scrollIntoView({ inline: 'center', behavior: 'smooth' });
    }
}

function renderMissions(data) {
    const dailyList = document.getElementById('daily-list');
    const weeklyList = document.getElementById('weekly-list');
    if (!dailyList || !weeklyList || !data) return;

    dailyList.innerHTML = '';
    weeklyList.innerHTML = '';

    const missions = data.missions || [];

    missions.forEach((m) => {
        const goal = m.goal || 1;
        const progress = m.progress || 0;
        const pct = Math.min(100, (progress / goal) * 100);
        const isDone = m.completed || progress >= goal;

        const isWeekly = m.type === 'weekly';

        const cardHtml = `
            <div class="mission-info">
                <div class="mission-icon">
                    ${missionIconArt(m.icon)}
                </div>
                <div class="mission-details">
                    <div class="mission-title">${m.title || m.id}</div>
                    <div class="mission-desc">${m.description || ''}</div>
                </div>
            </div>
            
            <div class="mission-progress-container">
                <div class="mission-progress-text">${progress} / ${goal}</div>
                <div class="mission-bar-bg">
                    <div class="mission-bar-fill" style="width: ${pct}%;"></div>
                </div>
            </div>
            
            <div class="mission-reward">
                <span class="mission-reward-val">
                    <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                    +${m.xp} XP
                </span>
                <button class="btn ${isDone ? '' : 'btn-primary'}" disabled>${isDone ? 'COLECTAT' : 'ÎN CURS'}</button>
            </div>
        `;

        const el = document.createElement('div');
        el.className = `mission-card ${isDone ? 'completed' : ''} ${isWeekly ? 'weekly' : ''}`;
        el.innerHTML = cardHtml;

        if (isWeekly) {
            weeklyList.appendChild(el);
        } else {
            dailyList.appendChild(el);
        }
    });

    if (!dailyList.hasChildNodes()) {
        dailyList.innerHTML = `<div style="color:var(--text-muted); text-align:center; padding:30px; font-size:12px;">Nu există misiuni zilnice active.</div>`;
    }

    if (!weeklyList.hasChildNodes()) {
        weeklyList.innerHTML = `<div style="color:var(--text-muted); text-align:center; padding:30px; font-size:12px;">Nu există misiuni săptămânale active.</div>`;
    }
}

function renderAll(data) {
    state.data = data;
    updatePlayerStats(data);
    renderBattlepass(data);
    renderMissions(data);
}

function show(payload) {
    const wrapper = document.getElementById('bp-wrapper');
    if (!wrapper) return;

    wrapper.classList.remove('hidden');
    setTimeout(() => wrapper.classList.add('visible'), 50);

    renderAll(payload.state || {});
    switchTab(payload.tab || 'battlepass');
}

function hide() {
    const wrapper = document.getElementById('bp-wrapper');
    if (!wrapper) return;

    wrapper.classList.remove('visible');
    setTimeout(() => wrapper.classList.add('hidden'), 200);
    state.data = null;
}

// Nav items click listener
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.nav-item').forEach((el) => {
        el.addEventListener('click', () => {
            switchTab(el.dataset.tab);
        });
    });
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') post('passClose');
});

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    switch (action) {
        case 'passShow':
            show(data || {});
            break;
        case 'passHide':
            hide();
            break;
        case 'passUpdate':
            if (data?.state) renderAll(data.state);
            break;
        case 'passSetTab':
            if (data?.tab) switchTab(data.tab);
            break;
        default:
            break;
    }
});

window.switchTab = switchTab;
window.buyPremium = buyPremium;
window.claimBP = claimBP;

// Demo QA Mode
if (new URLSearchParams(window.location.search).get('qa') === '1') {

    show({
        tab: 'battlepass',
        state: {
            seasonLabel: 'Season 01',
            tier: 4,
            tierXp: 800,
            tierGoal: 1000,
            premium: false,
            premiumCost: 250,
            accountCoins: 100,
            tiers: Array.from({ length: 10 }, (_, i) => ({
                level: i + 1,
                unlocked: i < 4,
                current: i === 3,
                free: { level: i + 1, type: 'cash', label: `$${(i + 1) * 1000}`, icon: 'cash', claimed: i < 2 },
                premium: { level: i + 1, type: 'item', label: i % 3 === 0 ? 'VIP Vehicle' : `Crate Lvl ${i + 1}`, icon: i % 3 === 0 ? 'veh_engine' : 'backpack', claimed: false },
            })),
            missions: [
                { id: '1', type: 'daily', title: 'Șofer Model', description: 'Condu un total de 15km fără a lovi vehiculul.', progress: 15, goal: 15, xp: 500, icon: 'veh_engine', completed: true },
                { id: '2', type: 'daily', title: 'Harnic', description: 'Completează 3 ture la jobul de Livrator.', progress: 1, goal: 3, xp: 300, icon: 'backpack', completed: false },
                { id: '3', type: 'daily', title: 'Timp cu Prietenii', description: 'Petrece 2 ore activ pe server.', progress: 120, goal: 120, xp: 400, icon: 'cash_stack', completed: true },
                { id: '4', type: 'weekly', title: 'Magnat Local', description: 'Câștigă un total de $50,000.', progress: 32000, goal: 50000, xp: 2500, icon: 'bank_card', completed: false },
                { id: '5', type: 'weekly', title: 'Infractor Căutat', description: 'Evadează cu succes din 3 jafuri auto.', progress: 3, goal: 3, xp: 3000, icon: 'golden_watch', completed: true },
            ],
        },
    });
}
