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

const exhaustMeta = {
    exhaust_pop: { title: 'POP & BANG', subtitle: 'Configurează pop-uri la decelerare' },
    exhaust_flames: { title: 'FLAMMEN', subtitle: 'Flăcări la evacuare + pop-uri' },
    exhaust_diesel: { title: 'DIESEL', subtitle: 'Sunet și comportament diesel' },
    exhaust_extra: { title: 'EXTRA LOUD', subtitle: 'Evacuare agresivă + flăcări' },
};

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
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

function ensureTune(raw) {
    const base = defaultTune();
    const src = raw && typeof raw === 'object' ? raw : {};
    return {
        ...base,
        ...src,
        pop: { ...base.pop, ...(src.pop || {}) },
        antiLag: { ...base.antiLag, ...(src.antiLag || {}) },
        drift: { ...base.drift, ...(src.drift || {}) },
        hud: { ...base.hud, ...(src.hud || {}) },
        dyno: { ...base.dyno, ...(src.dyno || {}) },
    };
}

function labelId(key) {
    return `lbl-${String(key).replace(/[^a-z0-9_-]/gi, '_')}`;
}

function exhaustForTab(tab) {
    if (tab === 'exhaust_flames') return 'flames';
    if (tab === 'exhaust_diesel') return 'diesel';
    if (tab === 'exhaust_extra') return 'extra';
    return 'pop_bang';
}

function preview() {
    if (!tune) return;
    post('tuningPreview', { tune });
}

function renderRail() {
    if (!rail) return;
    rail.innerHTML = '';
    tabs.forEach((group) => {
        const wrap = document.createElement('div');
        wrap.className = 'rail-group';
        const title = document.createElement('div');
        title.className = 'rail-group__title';
        title.textContent = group.group;
        wrap.appendChild(title);
        group.items.forEach((item) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'rail-btn' + (activeTab === item.id ? ' is-active' : '');
            btn.textContent = item.label;
            btn.addEventListener('click', () => {
                activeTab = item.id;
                if (item.id.startsWith('exhaust_')) {
                    tune.exhaust = exhaustForTab(item.id);
                    preview();
                }
                renderAll();
            });
            wrap.appendChild(btn);
        });
        rail.appendChild(wrap);
    });
}

function getTuneValue(key) {
    return String(key).split('.').reduce((o, k) => (o && o[k] !== undefined ? o[k] : undefined), tune);
}

function setTuneValue(key, value) {
    const parts = String(key).split('.');
    let ref = tune;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!ref[parts[i]] || typeof ref[parts[i]] !== 'object') ref[parts[i]] = {};
        ref = ref[parts[i]];
    }
    ref[parts[parts.length - 1]] = value;
}

function sliderField(label, key, min, max, suffix) {
    const field = document.createElement('div');
    field.className = 'field';
    const val = getTuneValue(key);
    const safeVal = Number.isFinite(Number(val)) ? Number(val) : min;
    const id = labelId(key);
    const lbl = document.createElement('label');
    lbl.innerHTML = `<span>${label}</span><span id="${id}">${safeVal}${suffix || ''}</span>`;
    const input = document.createElement('input');
    input.type = 'range';
    input.min = min;
    input.max = max;
    input.value = safeVal;
    input.addEventListener('input', () => {
        setTuneValue(key, Number(input.value));
        const node = document.getElementById(id);
        if (node) node.textContent = `${input.value}${suffix || ''}`;
        preview();
    });
    field.appendChild(lbl);
    field.appendChild(input);
    return field;
}

function toggleRow(label, key) {
    const row = document.createElement('div');
    row.className = 'toggle-row';
    const span = document.createElement('span');
    span.textContent = label;
    const sw = document.createElement('label');
    sw.className = 'switch';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = !!getTuneValue(key);
    input.addEventListener('change', () => {
        setTuneValue(key, input.checked);
        preview();
    });
    const slider = document.createElement('span');
    slider.className = 'slider';
    sw.appendChild(input);
    sw.appendChild(slider);
    row.appendChild(span);
    row.appendChild(sw);
    return row;
}

function stageCards(key, title) {
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
    stages.forEach((s) => {
        const card = document.createElement('div');
        card.className = 'stage-card' + (getTuneValue(key) === s.id ? ' is-active' : '');
        card.innerHTML = `<h3>${s.title}</h3><p>${s.sub}</p>`;
        card.addEventListener('click', () => {
            setTuneValue(key, s.id);
            if (key === 'stage') preview();
            renderPanels();
        });
        grid.appendChild(card);
    });
    wrap.appendChild(grid);
    return wrap;
}

function panelExhaust() {
    const meta = exhaustMeta[activeTab] || exhaustMeta.exhaust_pop;
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = `<h2>${meta.title}</h2><p class="subtitle">${meta.subtitle}</p>`;
    el.appendChild(toggleRow('EVACUARE ACTIVĂ', 'pop.enabled'));
    if (activeTab === 'exhaust_pop' || activeTab === 'exhaust_extra') {
        el.appendChild(sliderField('RPM MAX', 'pop.rpmMax', 70, 100, '%'));
        el.appendChild(sliderField('DURATĂ POP', 'pop.durationMs', 40, 250, 'ms'));
        el.appendChild(toggleRow('AL DOILEA INTERVAL POP & BANG', 'pop.secondBurst'));
        el.appendChild(stageCards('pop.burstStage', 'STAGE POP'));
    }
    if (activeTab === 'exhaust_flames' || activeTab === 'exhaust_extra') {
        el.appendChild(toggleRow('FLĂCĂRI LA EVACUARE', 'pop.enabled'));
    }
    if (activeTab === 'exhaust_diesel') {
        el.appendChild(sliderField('INTENSITATE DIESEL', 'pop.rpmMax', 25, 80, '%'));
    }
    return el;
}

function panelTuning() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>TUNING</h2><p class="subtitle">Mapă ECU — putere și cuplu</p>';
    el.appendChild(stageCards('stage', 'STAGE ECU'));
    el.appendChild(sliderField('PUTERE', 'power', 85, 120, '%'));
    el.appendChild(sliderField('CUPLU', 'torque', 85, 120, '%'));
    return el;
}

function panelDynoPower() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>DYNO — PUTERE</h2><p class="subtitle">Ultima rulare salvată pe vehicul</p>';
    const dyno = tune.dyno || defaultTune().dyno;
    const stats = document.createElement('div');
    stats.className = 'dyno-stats';
    stats.innerHTML = `
        <div class="stat-box"><div class="val">${dyno.lastHp || 0}</div><div class="lbl">CP</div></div>
        <div class="stat-box"><div class="val">${dyno.lastTorque || 0}</div><div class="lbl">NM</div></div>
        <div class="stat-box"><div class="val">$${costs.dyno}</div><div class="lbl">COST RUN</div></div>`;
    el.appendChild(stats);
    return el;
}

function panelDynoRank() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>CLASAMENT DYNO</h2><p class="subtitle">Top 15 vehicule pe server</p>';
    const table = document.createElement('table');
    table.className = 'leaderboard';
    table.innerHTML = '<thead><tr><th>#</th><th>PLATE</th><th>MODEL</th><th>CP</th><th>NM</th></tr></thead><tbody><tr><td colspan="5">Se încarcă...</td></tr></tbody>';
    el.appendChild(table);
    post('tuningLeaderboard').then((res) => {
        const body = table.querySelector('tbody');
        if (!body) return;
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
    el.innerHTML = '<h2>STAND DYNO</h2><p class="subtitle">Pornește testul — accelerează la maxim 12 secunde</p>';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'btn btn-secondary';
    btn.textContent = `START DYNO ($${costs.dyno})`;
    btn.addEventListener('click', () => post('tuningDyno'));
    el.appendChild(btn);
    return el;
}

function panelDrift() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>DRIFT</h2><p class="subtitle">Reduce aderența pentru slide controlat</p>';
    el.appendChild(toggleRow('DRIFT MODE', 'drift.enabled'));
    el.appendChild(sliderField('ADERENȚĂ', 'drift.grip', 20, 80, '%'));
    return el;
}

function panelAntilag() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>ANTI-LAG</h2><p class="subtitle">Pop-uri la accelerație în regim mediu</p>';
    el.appendChild(toggleRow('ANTI-LAG ACTIV', 'antiLag.enabled'));
    el.appendChild(sliderField('INTENSITATE', 'antiLag.intensity', 0, 100, '%'));
    return el;
}

function panelHud() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>HUD ECU</h2><p class="subtitle">Overlay RPM / boost în stil Sunset</p>';
    el.appendChild(toggleRow('HUD ECU ACTIV', 'hud.enabled'));
    return el;
}

function renderPanels() {
    if (!panels || !tune) return;
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
    const builder = map[activeTab] || panelTuning;
    panels.appendChild(builder());
}

function renderAll() {
    tune = ensureTune(tune);
    renderRail();
    renderPanels();
}

if (btnCancel) btnCancel.addEventListener('click', () => post('tuningClose'));
if (btnSave) btnSave.addEventListener('click', () => post('tuningSave', { tune: ensureTune(tune), flash: true }));

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    const action = payload.action;
    const data = payload.data || payload;
    if (action === 'open') {
        tune = ensureTune(data.tune);
        costs = data.costs || costs;
        if (shopLabel) shopLabel.textContent = data.shop || 'ECU Bay';
        if (plateLabel) plateLabel.textContent = data.plate || '—';
        activeTab = 'exhaust_pop';
        if (app) app.classList.remove('hidden');
        renderAll();
    }
    if (action === 'close' && app) {
        app.classList.add('hidden');
    }
    if (action === 'dynoResult' && data?.dyno) {
        tune = ensureTune(tune);
        tune.dyno = { ...tune.dyno, ...data.dyno };
        activeTab = 'dyno_power';
        if (app) app.classList.remove('hidden');
        renderAll();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('tuningClose');
});
