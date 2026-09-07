const app = document.getElementById('app');
const rail = document.getElementById('rail');
const panels = document.getElementById('panels');
const shopLabel = document.getElementById('shopLabel');
const plateLabel = document.getElementById('plateLabel');
const btnCancel = document.getElementById('btnCancel');
const btnSave = document.getElementById('btnSave');

let tune = null;
let costs = { save: 750, flash: 150, dyno: 250 };
let activeTab = 'exhaust_pop';

const tabs = [
    { group: 'EVACUARE', items: [
        { id: 'exhaust_pop', label: 'POP & BANG' },
        { id: 'exhaust_flames', label: 'FLAMMEN' },
        { id: 'exhaust_diesel', label: 'DIESEL' },
        { id: 'exhaust_extra', label: 'EXTRA' },
    ]},
    { group: 'TUNING', items: [{ id: 'tuning', label: 'TUNING' }] },
    { group: 'DYNO', items: [
        { id: 'dyno_power', label: 'PUTERE' },
        { id: 'dyno_rank', label: 'CLASAMENT' },
        { id: 'dyno_stand', label: 'STAND' },
    ]},
    { group: 'SPECIAL', items: [
        { id: 'drift', label: 'DRIFT' },
        { id: 'antilag', label: 'ANTI-LAG' },
        { id: 'hud', label: 'HUD' },
    ]},
];

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => ({}));
}

function defaultTune() {
    return {
        stage: 'sport',
        power: 100,
        torque: 100,
        exhaust: 'pop_bang',
        pop: { enabled: true, rpmMax: 92, durationMs: 100, secondBurst: true, burstStage: 'sport' },
        antiLag: { enabled: false, intensity: 55 },
        drift: { enabled: false, grip: 45 },
        hud: { enabled: true },
        dyno: { lastHp: 0, lastTorque: 0, lastRunAt: 0 },
    };
}

function exhaustForTab(tab) {
    if (tab === 'exhaust_flames') return 'flames';
    if (tab === 'exhaust_diesel') return 'diesel';
    if (tab === 'exhaust_extra') return 'extra';
    return 'pop_bang';
}

function preview() {
    post('tuningPreview', { tune });
}

function renderRail() {
    rail.innerHTML = '';
    tabs.forEach(group => {
        const wrap = document.createElement('div');
        wrap.className = 'rail-group';
        const title = document.createElement('div');
        title.className = 'rail-group__title';
        title.textContent = group.group;
        wrap.appendChild(title);
        group.items.forEach(item => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'rail-btn' + (activeTab === item.id ? ' is-active' : '');
            btn.textContent = item.label;
            btn.onclick = () => {
                activeTab = item.id;
                if (item.id.startsWith('exhaust_')) {
                    tune.exhaust = exhaustForTab(item.id);
                    preview();
                }
                renderAll();
            };
            wrap.appendChild(btn);
        });
        rail.appendChild(wrap);
    });
}

function sliderField(label, key, min, max, suffix, onInput) {
    const field = document.createElement('div');
    field.className = 'field';
    const val = key.split('.').reduce((o, k) => o[k], tune);
    const lbl = document.createElement('label');
    lbl.innerHTML = `<span>${label}</span><span id="lbl-${key}">${val}${suffix || ''}</span>`;
    const input = document.createElement('input');
    input.type = 'range';
    input.min = min;
    input.max = max;
    input.value = val;
    input.oninput = () => {
        const parts = key.split('.');
        let ref = tune;
        for (let i = 0; i < parts.length - 1; i++) ref = ref[parts[i]];
        ref[parts[parts.length - 1]] = Number(input.value);
        document.getElementById(`lbl-${key}`).textContent = `${input.value}${suffix || ''}`;
        onInput && onInput();
        preview();
    };
    field.appendChild(lbl);
    field.appendChild(input);
    return field;
}

function toggleRow(label, key, onChange) {
    const row = document.createElement('div');
    row.className = 'toggle-row';
    const span = document.createElement('span');
    span.textContent = label;
    const sw = document.createElement('label');
    sw.className = 'switch';
    const input = document.createElement('input');
    input.type = 'checkbox';
    const parts = key.split('.');
    let ref = tune;
    for (let i = 0; i < parts.length - 1; i++) ref = ref[parts[i]];
    input.checked = !!ref[parts[parts.length - 1]];
    input.onchange = () => {
        ref[parts[parts.length - 1]] = input.checked;
        onChange && onChange();
        preview();
    };
    const slider = document.createElement('span');
    slider.className = 'slider';
    sw.appendChild(input);
    sw.appendChild(slider);
    row.appendChild(span);
    row.appendChild(sw);
    return row;
}

function stageCards(key, title) {
    const parts = key.split('.');
    const getVal = () => parts.reduce((o, k) => o[k], tune);
    const setVal = (v) => {
        let ref = tune;
        for (let i = 0; i < parts.length - 1; i++) ref = ref[parts[i]];
        ref[parts[parts.length - 1]] = v;
    };
    const wrap = document.createElement('div');
    wrap.className = 'field';
    const h = document.createElement('label');
    h.innerHTML = `<span>${title}</span>`;
    wrap.appendChild(h);
    const grid = document.createElement('div');
    grid.className = 'stage-grid';
    const stages = [
        { id: 'civil', title: 'SILENȚIOS', sub: '(CIVIL)' },
        { id: 'sport', title: 'NORMAL', sub: '(SPORT)' },
        { id: 'race', title: 'AGRESIV', sub: '(RACE)' },
    ];
    stages.forEach(s => {
        const card = document.createElement('div');
        card.className = 'stage-card' + (getVal() === s.id ? ' is-active' : '');
        card.innerHTML = `<h3>${s.title}</h3><p>${s.sub}</p>`;
        card.onclick = () => {
            setVal(s.id);
            if (key === 'stage') preview();
            renderPanels();
        };
        grid.appendChild(card);
    });
    wrap.appendChild(grid);
    return wrap;
}

function panelExhaust() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>POP &amp; BANG</h2><p class="subtitle">Configurează caracteristica evacuării</p>`;
    el.appendChild(toggleRow('POP & BANG ACTIV', 'pop.enabled'));
    el.appendChild(sliderField('RPM MAX', 'pop.rpmMax', 70, 100, '%'));
    el.appendChild(sliderField('DURATĂ POP', 'pop.durationMs', 40, 250, 'ms'));
    el.appendChild(toggleRow('AL DOILEA INTERVAL POP & BANG', 'pop.secondBurst'));
    el.appendChild(stageCards('pop.burstStage', 'AL DOILEA INTERVAL STAGE'));
    return el;
}

function panelTuning() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>TUNING</h2><p class="subtitle">Mapă ECU — putere și cuplu</p>`;
    el.appendChild(stageCards('stage', 'STAGE ECU'));
    el.appendChild(sliderField('PUTERE', 'power', 85, 120, '%'));
    el.appendChild(sliderField('CUPLU', 'torque', 85, 120, '%'));
    return el;
}

function panelDynoPower() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>DYNO — PUTERE</h2><p class="subtitle">Ultima rulare salvată pe vehicul</p>`;
    const stats = document.createElement('div');
    stats.className = 'dyno-stats';
    stats.innerHTML = `
        <div class="stat-box"><div class="val">${tune.dyno.lastHp || 0}</div><div class="lbl">CP</div></div>
        <div class="stat-box"><div class="val">${tune.dyno.lastTorque || 0}</div><div class="lbl">NM</div></div>
        <div class="stat-box"><div class="val">$${costs.dyno}</div><div class="lbl">COST RUN</div></div>`;
    el.appendChild(stats);
    return el;
}

function panelDynoRank() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>CLASAMENT DYNO</h2><p class="subtitle">Top 15 vehicule pe server</p>`;
    const table = document.createElement('table');
    table.className = 'leaderboard';
    table.innerHTML = '<thead><tr><th>#</th><th>PLATE</th><th>MODEL</th><th>CP</th><th>NM</th></tr></thead><tbody id="lbBody"><tr><td colspan="5">Se încarcă...</td></tr></tbody>';
    el.appendChild(table);
    post('tuningLeaderboard').then(res => {
        const body = table.querySelector('#lbBody');
        const rows = res.rows || [];
        if (!rows.length) {
            body.innerHTML = '<tr><td colspan="5">Nicio rulare încă</td></tr>';
            return;
        }
        body.innerHTML = rows.map((r, i) => `<tr><td>${i + 1}</td><td>${r.plate || '—'}</td><td>${r.model || '—'}</td><td>${r.hp}</td><td>${r.torque}</td></tr>`).join('');
    });
    return el;
}

function panelDynoStand() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>STAND DYNO</h2><p class="subtitle">Pornește testul — accelerează la maxim 12 secunde</p>`;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'btn btn-secondary';
    btn.textContent = `START DYNO ($${costs.dyno})`;
    btn.onclick = () => post('tuningDyno');
    el.appendChild(btn);
    return el;
}

function panelDrift() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>DRIFT</h2><p class="subtitle">Reduce aderența pentru slide controlat</p>`;
    el.appendChild(toggleRow('DRIFT MODE', 'drift.enabled'));
    el.appendChild(sliderField('ADERENȚĂ', 'drift.grip', 20, 80, '%'));
    return el;
}

function panelAntilag() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>ANTI-LAG</h2><p class="subtitle">Pop-uri la accelerație în regim mediu</p>`;
    el.appendChild(toggleRow('ANTI-LAG ACTIV', 'antiLag.enabled'));
    el.appendChild(sliderField('INTENSITATE', 'antiLag.intensity', 0, 100, '%'));
    return el;
}

function panelHud() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>HUD ECU</h2><p class="subtitle">Overlay RPM / boost în stil Sunset</p>`;
    el.appendChild(toggleRow('HUD ECU ACTIV', 'hud.enabled'));
    return el;
}

function renderPanels() {
    panels.innerHTML = '';
    const map = {
        exhaust_pop: panelExhaust,
        exhaust_flames: panelExhaust,
        exhaust_diesel: panelExhaust,
        exhaust_extra: panelExhaust,
        tuning: panelTuning,
        dyno_power: panelDynoPower,
        dyno_rank: panelDynoRank,
        dyno_stand: panelDynoStand,
        drift: panelDrift,
        antilag: panelAntilag,
        hud: panelHud,
    };
    const builder = map[activeTab] || panelExhaust;
    panels.appendChild(builder());
}

function renderAll() {
    renderRail();
    renderPanels();
}

btnCancel.onclick = () => post('tuningClose');
btnSave.onclick = () => post('tuningSave', { tune, flash: true });

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    if (action === 'open') {
        tune = { ...defaultTune(), ...(data.tune || {}) };
        tune.pop = { ...defaultTune().pop, ...(data.tune?.pop || {}) };
        tune.antiLag = { ...defaultTune().antiLag, ...(data.tune?.antiLag || {}) };
        tune.drift = { ...defaultTune().drift, ...(data.tune?.drift || {}) };
        tune.hud = { ...defaultTune().hud, ...(data.tune?.hud || {}) };
        tune.dyno = { ...defaultTune().dyno, ...(data.tune?.dyno || {}) };
        costs = data.costs || costs;
        shopLabel.textContent = data.shop || 'ECU Bay';
        plateLabel.textContent = data.plate || '—';
        activeTab = 'exhaust_pop';
        app.classList.remove('hidden');
        renderAll();
    }
    if (action === 'close') {
        app.classList.add('hidden');
    }
    if (action === 'dynoResult' && data?.dyno) {
        tune.dyno = data.dyno;
        activeTab = 'dyno_power';
        renderAll();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('tuningClose');
});
