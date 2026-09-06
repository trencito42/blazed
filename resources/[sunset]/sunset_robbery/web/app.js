const $ = (id) => document.getElementById(id);

function post(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

function money(n) {
    return '$' + Math.max(0, Math.floor(Number(n) || 0)).toLocaleString('en-US');
}

const Hud = {
    show(data = {}) {
        $('rob-hud').classList.remove('hidden');
        const escaping = data.stage === 'ESCAPING';
        $('rob-hud-stage').textContent = escaping ? 'ESCAPE' : 'DUFFEL';
        const used = data.bagUsed ?? 0;
        const cap = data.bagCap ?? 12;
        $('rob-hud-bag').textContent = `${used} / ${cap}`;
        $('rob-hud-value').textContent = money(data.estimated);
        if (escaping) {
            const left = Math.max(0, Math.floor(Number(data.escapeLeft) || 0));
            $('rob-hud-response').textContent = left > 0 ? `${left}m OUT` : 'CLEAR';
        } else {
            const sec = Math.max(0, Number(data.response) || 0);
            $('rob-hud-response').textContent = data.policeAlerted
                ? 'LIVE'
                : `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`;
        }
        $('rob-hud-fill').style.width = `${Math.min(100, (used / Math.max(1, cap)) * 100)}%`;
    },
    hide() { $('rob-hud').classList.add('hidden'); },
};

const Hack = {
    timer: null,
    left: 26,
    show(data = {}) {
        $('hack').classList.remove('hidden');
        $('hack-trace').textContent = '0%';
        this.left = Number(data.timeLimit) || 26;
        this.tick();
        clearInterval(this.timer);
        this.timer = setInterval(() => this.tick(), 100);
        this.draw(data.nodes || []);
        post('playSound', { key: 'terminal' });
    },
    tick() {
        this.left = Math.max(0, this.left - 0.1);
        $('hack-time').textContent = this.left.toFixed(1);
    },
    draw(nodes) {
        const board = $('hack-board');
        board.innerHTML = '';
        nodes.forEach((node) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = `hack-node is-${node.kind || 'normal'}`;
            btn.style.left = `${node.x}%`;
            btn.style.top = `${node.y}%`;
            btn.dataset.id = node.id;
            btn.innerHTML = `${node.label || node.id}<small>${String(node.kind || '').toUpperCase()}</small>`;
            if (node.kind === 'source') btn.classList.add('is-on');
            btn.addEventListener('click', () => {
                post('hackClick', { nodeId: node.id });
                post('playSound', { key: 'terminal' });
            });
            board.appendChild(btn);
        });
    },
    progress(data = {}) {
        $('hack-trace').textContent = `${Math.min(100, Number(data.trace) || 0)}%`;
        if (data.nodeId) {
            const el = document.querySelector(`[data-id="${data.nodeId}"]`);
            if (el) el.classList.add('is-on');
        }
    },
    hide() {
        clearInterval(this.timer);
        $('hack').classList.add('hidden');
    },
};

const Loot = {
    displayId: null,
    show(data = {}) {
        this.displayId = data.displayId;
        $('loot').classList.remove('hidden');
        $('loot-title').textContent = (data.label || 'DISPLAY').toUpperCase();
        $('loot-bag').textContent = `${data.bagUsed || 0} / ${data.bagCap || 12}`;
        const grid = $('loot-grid');
        grid.innerHTML = '';
        (data.items || []).forEach((item) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'loot-item';
            if (item.tier === 'RARE') btn.classList.add('is-rare');
            if (item.tier === 'EPIC' || item.tier === 'VERY_RARE') btn.classList.add('is-epic');
            if (item.taken) btn.classList.add('is-taken');
            btn.dataset.uid = item.uid;
            btn.innerHTML = `${item.label}<small>${item.tier} · ${money(item.baseValue)} · w${item.weight}</small>`;
            btn.addEventListener('click', () => {
                if (item.taken) return;
                post('lootTake', { displayId: data.displayId, uid: item.uid });
            });
            grid.appendChild(btn);
        });
    },
    taken(data = {}) {
        $('loot-bag').textContent = `${data.bagUsed || 0} / ${data.bagCap || 12}`;
        const btn = $('loot-grid').querySelector(`[data-uid="${data.uid}"]`);
        if (btn) btn.classList.add('is-taken');
    },
    hide() { $('loot').classList.add('hidden'); },
};

const Fence = {
    show(data = {}) {
        $('fence').classList.remove('hidden');
        const list = $('fence-list');
        list.innerHTML = '';
        const offers = data.offers || [];
        if (!offers.length) {
            list.innerHTML = '<div class="fence-row">Nothing stolen on you.</div>';
            return;
        }
        offers.forEach((row) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'fence-row';
            btn.innerHTML = `${row.label} ×${row.count}<small>Street ${money(row.street)} · Offer ${money(row.offer)}</small>`;
            btn.addEventListener('click', () => post('fenceSell', { item: row.item }));
            list.appendChild(btn);
        });
    },
    hide() { $('fence').classList.add('hidden'); },
};

$('loot-leave')?.addEventListener('click', () => post('lootClose'));
$('fence-leave')?.addEventListener('click', () => post('fenceClose'));

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    switch (action) {
        case 'hackShow': Hack.show(data); break;
        case 'hackProgress': Hack.progress(data); break;
        case 'hackHide': Hack.hide(); break;
        case 'lootShow': Loot.show(data); break;
        case 'lootTaken': Loot.taken(data); break;
        case 'lootHide': Loot.hide(); break;
        case 'hudShow': Hud.show(data); break;
        case 'hudHide': Hud.hide(); break;
        case 'fenceShow': Fence.show(data); break;
        case 'fenceHide': Fence.hide(); break;
        default: break;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('hack').classList.contains('hidden')) post('hackClose');
    if (!$('loot').classList.contains('hidden')) post('lootClose');
    if (!$('fence').classList.contains('hidden')) post('fenceClose');
});
