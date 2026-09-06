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

const state = {
    tab: 'rewards',
    data: null,
};

function post(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((res) => res.json()).catch(() => ({}));
}

function setTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.pass-tab').forEach((btn) => {
        btn.classList.toggle('is-active', btn.dataset.tab === tab);
    });
    document.querySelectorAll('.pass-panel').forEach((panel) => {
        panel.classList.toggle('is-active', panel.id === `tab-${tab}`);
    });
    post('passSetTab', { tab });
}

function renderReward(reward, track) {
    if (!reward) {
        return '<div class="pass-empty">—</div>';
    }

    const classes = [
        'pass-reward',
        `pass-reward--${track}`,
        reward.claimed ? 'is-claimed' : '',
        reward.locked ? 'is-locked' : '',
    ].filter(Boolean).join(' ');

    const lock = reward.locked ? '<span class="pass-reward__lock">LOCK</span>' : '';

    return `
        <button type="button" class="${classes}" data-level="${reward.level}" data-track="${track}" ${reward.canClaim ? '' : 'disabled'}>
            <span class="pass-reward__stamp">CLAIMED</span>
            ${lock}
            <span class="pass-reward__icon">${rewardArt(reward)}</span>
            <span class="pass-reward__name">${reward.label || 'Reward'}</span>
        </button>
    `;
}

function renderTiers(data) {
    const container = document.getElementById('pass-tiers');
    const fill = document.getElementById('pass-track-fill');
    if (!container || !data) return;

    const tiers = data.tiers || [];
    let fillPct = 0;
    if (tiers.length > 1) {
        const currentIdx = Math.max(0, (data.tier || 1) - 1);
        fillPct = (currentIdx / (tiers.length - 1)) * 100;
    }

    container.innerHTML = tiers.map((tier) => {
        const classes = [
            'pass-tier-col',
            tier.unlocked ? 'is-unlocked' : '',
            tier.current ? 'is-current' : '',
        ].filter(Boolean).join(' ');

        return `
            <article class="${classes}">
                <div class="pass-slot pass-slot--free">${renderReward(tier.free, 'free')}</div>
                <div class="pass-slot-label">Free</div>
                <div class="pass-marker">${tier.level}</div>
                <div class="pass-slot-label is-premium">Premium</div>
                <div class="pass-slot pass-slot--premium">${renderReward(tier.premium, 'premium')}</div>
            </article>
        `;
    }).join('');

    if (fill) fill.style.width = `${fillPct}%`;

    const line = document.querySelector('.pass-track__line');
    if (line && container) {
        line.style.width = `${container.scrollWidth}px`;
    }

    container.querySelectorAll('.pass-reward__icon img').forEach((img) => {
        img.addEventListener('error', () => {
            if (!img.src.endsWith('backpack.webp')) img.src = ITEM_ICON_FALLBACK;
        }, { once: true });
    });

    container.querySelectorAll('.pass-reward[data-level]').forEach((btn) => {
        btn.addEventListener('click', async () => {
            if (btn.disabled || btn.classList.contains('is-claimed') || btn.classList.contains('is-locked')) return;
            await post('passClaim', {
                level: Number(btn.dataset.level),
                track: btn.dataset.track,
            });
        });
    });

    const track = document.getElementById('pass-track');
    if (track && data.tier > 2) {
        track.scrollLeft = (data.tier - 2) * 176;
    }
}

function renderMissions(data) {
    const container = document.getElementById('pass-missions');
    if (!container || !data) return;

    container.innerHTML = (data.missions || []).map((mission) => {
        const pct = mission.goal > 0 ? Math.min(100, (mission.progress / mission.goal) * 100) : 0;
        const xpLabel = mission.completed ? 'COMPLETED' : `+${mission.xp} XP`;
        return `
            <article class="pass-mission ${mission.completed ? 'is-complete' : ''}">
                <div class="pass-mission__head">
                    <div>
                        <div class="pass-mission__title">${mission.title}</div>
                        <div class="pass-mission__desc">${mission.description}</div>
                    </div>
                    <div class="pass-mission__xp">${xpLabel}</div>
                </div>
                <div class="pass-mission__progress-text">${mission.progress} / ${mission.goal}</div>
                <div class="pass-mission__bar">
                    <div class="pass-mission__fill" style="width:${pct}%"></div>
                </div>
            </article>
        `;
    }).join('');
}

function renderHeader(data) {
    document.getElementById('pass-season').textContent = data.seasonLabel || 'Season';
    document.getElementById('pass-tier').textContent = `Lvl. ${data.tier || 1}`;
    document.getElementById('pass-tier-xp').textContent = `${data.tierXp || 0} / ${data.tierGoal || 500} XP`;
    const tierFill = document.getElementById('pass-tier-fill');
    const tierPct = data.tierGoal > 0 ? ((data.tierXp || 0) / data.tierGoal) * 100 : 0;
    if (tierFill) tierFill.style.width = `${tierPct}%`;

    const premiumBtn = document.getElementById('pass-buy-premium');
    if (!premiumBtn) return;
    if (data.premium) {
        premiumBtn.textContent = 'Premium Active';
        premiumBtn.classList.add('is-owned');
    } else {
        premiumBtn.textContent = `Upgrade Pass (${data.premiumCost || 0} Coins)`;
        premiumBtn.classList.remove('is-owned');
        premiumBtn.title = `You have ${data.accountCoins || 0} Sunset Coins`;
    }
}

function renderAll(data) {
    state.data = data;
    renderHeader(data);
    renderTiers(data);
    renderMissions(data);
}

function show(payload) {
    document.getElementById('pass-root').classList.remove('hidden');
    renderAll(payload.state || {});
    setTab(payload.tab || 'rewards');
}

function hide() {
    document.getElementById('pass-root').classList.add('hidden');
    state.data = null;
}

document.getElementById('pass-close')?.addEventListener('click', () => post('passClose'));
document.getElementById('pass-buy-premium')?.addEventListener('click', () => post('passBuyPremium'));

document.querySelectorAll('.pass-tab').forEach((btn) => {
    btn.addEventListener('click', () => setTab(btn.dataset.tab));
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
            if (data?.tab) setTab(data.tab);
            break;
        default:
            break;
    }
});
