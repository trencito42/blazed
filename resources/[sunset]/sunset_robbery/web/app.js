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
    deadline: 0,
    burstDeadline: 0,
    currentNode: null,
    edges: [],
    passed: new Set(),
    clickLocked: false,
    show(data = {}) {
        $('hack').classList.remove('hidden');
        $('hack-trace').textContent = '0%';
        $('hack-trace-fill').style.width = '0%';
        $('hack-status').className = 'hack__status';
        $('hack-status').textContent = 'MATCH THE REQUESTED CHANNEL AND FOLLOW A CONNECTED LINE';
        this.deadline = performance.now() + ((Number(data.timeLimit) || 34) * 1000);
        this.burstDeadline = 0;
        this.currentNode = data.currentNode || data.sourceId;
        this.edges = Array.isArray(data.edges) ? data.edges : [];
        this.passed = new Set(this.currentNode ? [this.currentNode] : []);
        this.clickLocked = false;
        this.setSignal(data.signal);
        this.tick();
        clearInterval(this.timer);
        this.timer = setInterval(() => this.tick(), 80);
        this.draw(data.nodes || []);
        this.refreshRoute();
        post('playSound', { key: 'terminal' });
    },
    tick() {
        const left = Math.max(0, (this.deadline - performance.now()) / 1000);
        $('hack-time').textContent = left.toFixed(1);
        if (left <= 5) $('hack-time').style.color = 'var(--r-red)';
        if (this.burstDeadline > 0) {
            const burst = Math.max(0, (this.burstDeadline - performance.now()) / 1000);
            $('hack-status').textContent = burst > 0
                ? `BURST RELAY ACTIVE — ${burst.toFixed(1)}s TO ROUTE NEXT NODE`
                : 'BURST WINDOW EXPIRED — SELECT TO RESYNC';
        }
    },
    draw(nodes) {
        const board = $('hack-nodes');
        const lines = $('hack-lines');
        board.innerHTML = '';
        lines.innerHTML = '';
        const positions = new Map(nodes.map((node) => [node.id, node]));
        this.edges.forEach((edge) => {
            const from = positions.get(edge.from);
            const to = positions.get(edge.to);
            if (!from || !to) return;
            const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
            line.setAttribute('x1', from.x);
            line.setAttribute('y1', from.y);
            line.setAttribute('x2', to.x);
            line.setAttribute('y2', to.y);
            line.setAttribute('class', 'hack-edge');
            line.dataset.from = edge.from;
            line.dataset.to = edge.to;
            lines.appendChild(line);
        });
        nodes.forEach((node) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = `hack-node is-${node.kind || 'normal'}`;
            btn.style.left = `${node.x}%`;
            btn.style.top = `${node.y}%`;
            btn.dataset.id = node.id;
            btn.dataset.kind = node.kind || 'normal';
            btn.dataset.frequency = String(node.frequency || 1);
            const channel = `CH ${String(node.frequency || 1).padStart(2, '0')}`;
            const type = node.kind === 'locked' ? `${channel} · LOCK`
                : (node.kind === 'timed' ? `${channel} · BURST`
                    : (node.kind === 'corrupted' ? 'CORRUPT' : `CH ${String(node.frequency || 1).padStart(2, '0')}`));
            btn.innerHTML = `${node.label || node.id}<small>${type}</small>`;
            if (node.kind === 'source') btn.classList.add('is-on');
            btn.addEventListener('click', () => {
                if (this.clickLocked || btn.disabled) return;
                this.clickLocked = true;
                setTimeout(() => { this.clickLocked = false; }, 280);
                post('hackClick', { nodeId: node.id });
                post('playSound', { key: 'terminal' });
            });
            board.appendChild(btn);
        });
    },
    setSignal(signal) {
        $('hack-signal').textContent = signal ? `CH ${String(signal).padStart(2, '0')}` : 'CORE OPEN';
    },
    refreshRoute() {
        const available = new Set(this.edges.filter((edge) => edge.from === this.currentNode).map((edge) => edge.to));
        document.querySelectorAll('.hack-node').forEach((node) => {
            const active = available.has(node.dataset.id);
            const passed = this.passed.has(node.dataset.id);
            node.disabled = !active;
            node.classList.toggle('is-available', active);
            node.classList.toggle('is-offroute', !active && !passed);
            node.classList.toggle('is-on', passed);
            if (!active) node.classList.remove('is-armed');
        });
        document.querySelectorAll('.hack-edge').forEach((edge) => {
            edge.classList.toggle('is-live', edge.dataset.from === this.currentNode);
            edge.classList.toggle('is-passed', this.passed.has(edge.dataset.from) && this.passed.has(edge.dataset.to));
        });
    },
    progress(data = {}) {
        const trace = Math.min(100, Number(data.trace) || 0);
        $('hack-trace').textContent = `${trace}%`;
        $('hack-trace-fill').style.width = `${trace}%`;
        const status = $('hack-status');
        status.textContent = data.status || 'SIGNAL ACCEPTED';
        status.classList.toggle('is-alert', Boolean(data.errorNode));
        status.classList.toggle('is-burst', Boolean(data.burstMs) && !data.lockArmed);
        this.setSignal(data.signal);
        if (data.burstMs && !data.lockArmed) this.burstDeadline = performance.now() + Number(data.burstMs);
        else if (!data.lockArmed) this.burstDeadline = 0;
        if (data.errorNode) {
            const bad = document.querySelector(`[data-id="${data.errorNode}"]`);
            if (bad) {
                bad.classList.add('is-error');
                setTimeout(() => bad.classList.remove('is-error'), 380);
            }
        }
        if (data.lockArmed && data.nodeId) {
            const armed = document.querySelector(`[data-id="${data.nodeId}"]`);
            if (armed) armed.classList.add('is-armed');
            return;
        }
        if (data.nodeId) {
            this.passed.add(data.nodeId);
            this.currentNode = data.currentNode || data.nodeId;
            this.refreshRoute();
        }
    },
    hide() {
        clearInterval(this.timer);
        this.burstDeadline = 0;
        $('hack-time').style.color = '';
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
            btn.addEventListener('click', () => post('fenceSell', { offerId: row.offerId }));
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
