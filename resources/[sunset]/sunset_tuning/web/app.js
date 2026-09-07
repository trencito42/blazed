const app = document.getElementById('app');
const rail = document.getElementById('rail');
const panels = document.getElementById('panels');
const shopLabel = document.getElementById('shopLabel');
const plateLabel = document.getElementById('plateLabel');
const ecuStatus = document.getElementById('ecuStatus');
const btnCancel = document.getElementById('btnCancel');
const btnSave = document.getElementById('btnSave');

let tune = null;
let cosmetics = null;
let costs = { save: 750, flash: 150, dyno: 250 };
let activeTab = 'exhaust_pop';
let hasSavedMap = false;
let previewDirty = false;

const tabs = [
    { group: 'EVACUARE', items: [
        { id: 'exhaust_pop', label: 'POP & BANG' },
        { id: 'exhaust_flames', label: 'FLAMMEN' },
        { id: 'exhaust_diesel', label: 'DIESEL' },
        { id: 'exhaust_extra', label: 'EXTRA' },
    ]},
    { group: 'TUNING', items: [{ id: 'tuning', label: 'TUNING' }] },
    { group: 'VIZUAL', items: [{ id: 'visual', label: 'CULORI' }] },
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

function stockTune() {
    return {
        stage: 'civil',
        power: 100,
        torque: 100,
        exhaust: 'pop_bang',
        pop: { enabled: false, rpmMax: 88, durationMs: 100, secondBurst: false, burstStage: 'civil' },
        flames: { enabled: false, color: { r: 255, g: 120, b: 40 } },
        antiLag: { enabled: false, intensity: 55 },
        drift: { enabled: false, grip: 45 },
        hud: { enabled: false },
        dyno: { lastHp: 0, lastTorque: 0, lastRunAt: 0 },
    };
}

function stockCosmetics() {
    return {
        primary: { r: 0, g: 0, b: 0 },
        secondary: { r: 111, g: 111, b: 111 },
        pearl: 0,
        wheel: 0,
        plateText: '',
    };
}

function ensureCosmetics(raw) {
    const base = stockCosmetics();
    const src = raw && typeof raw === 'object' ? raw : {};
    return {
        ...base,
        ...src,
        primary: { ...base.primary, ...(src.primary || {}) },
        secondary: { ...base.secondary, ...(src.secondary || {}) },
    };
}

function ensureTune(raw) {
    const base = stockTune();
    const src = raw && typeof raw === 'object' ? raw : {};
    return {
        ...base,
        ...src,
        pop: { ...base.pop, ...(src.pop || {}) },
        flames: { ...base.flames, ...(src.flames || {}), color: { ...(base.flames.color || {}), ...((src.flames && src.flames.color) || {}) } },
        antiLag: { ...base.antiLag, ...(src.antiLag || {}) },
        drift: { ...base.drift, ...(src.drift || {}) },
        hud: { ...base.hud, ...(src.hud || {}) },
        dyno: { ...base.dyno, ...(src.dyno || {}) },
    };
}

function updateStatusBanner() {
    if (!ecuStatus) return;
    if (previewDirty) {
        ecuStatus.textContent = 'PREVIEW — NESALVAT';
        ecuStatus.className = 'ecu-status ecu-status--preview';
    } else if (hasSavedMap) {
        ecuStatus.textContent = 'MAPA SALVATA';
        ecuStatus.className = 'ecu-status ecu-status--saved';
    } else {
        ecuStatus.textContent = 'FACTORY MAP';
        ecuStatus.className = 'ecu-status ecu-status--stock';
    }
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
    previewDirty = true;
    updateStatusBanner();
    post('tuningPreview', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics) });
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
                    if (item.id === 'exhaust_pop') tune.pop.enabled = true;
                    if (item.id === 'exhaust_flames' || item.id === 'exhaust_extra') {
                        tune.flames.enabled = true;
                        tune.pop.enabled = true;
                    }
                    if (item.id === 'exhaust_diesel') tune.pop.enabled = true;
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

function colorRgbField(label, key) {
    const field = document.createElement('div');
    field.className = 'field color-field';
    const parts = String(key).split('.');
    const getColor = () => {
        let ref = tune;
        for (const p of parts) ref = ref && ref[p];
        return ref || { r: 255, g: 120, b: 40 };
    };
    const setChannel = (ch, val) => {
        let ref = tune;
        for (let i = 0; i < parts.length - 1; i++) {
            if (!ref[parts[i]]) ref[parts[i]] = {};
            ref = ref[parts[i]];
        }
        if (!ref[parts[parts.length - 1]]) ref[parts[parts.length - 1]] = { r: 255, g: 120, b: 40 };
        ref[parts[parts.length - 1]][ch] = Number(val);
        preview();
    };
    const c = getColor();
    const lbl = document.createElement('label');
    lbl.innerHTML = `<span>${label}</span><span class="color-swatch" style="background:rgb(${c.r},${c.g},${c.b})"></span>`;
    field.appendChild(lbl);
    ['r', 'g', 'b'].forEach((ch) => {
        const row = document.createElement('div');
        row.className = 'color-row';
        row.innerHTML = `<span>${ch.toUpperCase()}</span>`;
        const input = document.createElement('input');
        input.type = 'range';
        input.min = 0;
        input.max = 255;
        input.value = c[ch] || 0;
        input.addEventListener('input', () => {
            setChannel(ch, input.value);
            const col = getColor();
            const sw = lbl.querySelector('.color-swatch');
            if (sw) sw.style.background = `rgb(${col.r},${col.g},${col.b})`;
        });
        row.appendChild(input);
        field.appendChild(row);
    });
    return field;
}

function cosmeticsColorField(label, key) {
    const field = document.createElement('div');
    field.className = 'field color-field';
    const parts = String(key).split('.');
    const getColor = () => {
        let ref = cosmetics;
        for (const p of parts) ref = ref && ref[p];
        return ref || { r: 0, g: 0, b: 0 };
    };
    const setChannel = (ch, val) => {
        cosmetics = ensureCosmetics(cosmetics);
        let ref = cosmetics;
        for (let i = 0; i < parts.length - 1; i++) {
            if (!ref[parts[i]]) ref[parts[i]] = {};
            ref = ref[parts[i]];
        }
        if (!ref[parts[parts.length - 1]]) ref[parts[parts.length - 1]] = { r: 0, g: 0, b: 0 };
        ref[parts[parts.length - 1]][ch] = Number(val);
        preview();
    };
    const c = getColor();
    const lbl = document.createElement('label');
    lbl.innerHTML = `<span>${label}</span><span class="color-swatch" style="background:rgb(${c.r},${c.g},${c.b})"></span>`;
    field.appendChild(lbl);
    ['r', 'g', 'b'].forEach((ch) => {
        const row = document.createElement('div');
        row.className = 'color-row';
        row.innerHTML = `<span>${ch.toUpperCase()}</span>`;
        const input = document.createElement('input');
        input.type = 'range';
        input.min = 0;
        input.max = 255;
        input.value = c[ch] || 0;
        input.addEventListener('input', () => {
            setChannel(ch, input.value);
            const col = getColor();
            const sw = lbl.querySelector('.color-swatch');
            if (sw) sw.style.background = `rgb(${col.r},${col.g},${col.b})`;
        });
        row.appendChild(input);
        field.appendChild(row);
    });
    return field;
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
        el.appendChild(toggleRow('FLĂCĂRI LA EVACUARE', 'flames.enabled'));
        el.appendChild(colorRgbField('CULOARE FLĂCĂRI', 'flames.color'));
        const presets = document.createElement('div');
        presets.className = 'flame-presets';
        const presetList = [
            { name: 'Portocaliu', r: 255, g: 120, b: 40 },
            { name: 'Albastru', r: 80, g: 160, b: 255 },
            { name: 'Violet', r: 180, g: 60, b: 255 },
            { name: 'Verde', r: 80, g: 255, b: 120 },
            { name: 'Roșu', r: 255, g: 40, b: 40 },
            { name: 'Alb', r: 255, g: 255, b: 255 },
        ];
        presetList.forEach((p) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'preset-btn';
            btn.style.background = `rgb(${p.r},${p.g},${p.b})`;
            btn.title = p.name;
            btn.addEventListener('click', () => {
                tune.flames.color = { r: p.r, g: p.g, b: p.b };
                preview();
                renderPanels();
            });
            presets.appendChild(btn);
        });
        el.appendChild(presets);
        const testBtn = document.createElement('button');
        testBtn.type = 'button';
        testBtn.className = 'btn btn-secondary';
        testBtn.textContent = 'TEST FLĂCĂRI';
        testBtn.addEventListener('click', () => post('tuningTestFlame'));
        el.appendChild(testBtn);
    }
    if (activeTab === 'exhaust_diesel') {
        el.appendChild(sliderField('INTENSITATE DIESEL', 'pop.rpmMax', 25, 80, '%'));
    }
    return el;
}

function panelVisual() {
    const el = document.createElement('div');
    el.className = 'panel';
    el.innerHTML = '<h2>CULORI & PLĂCUȚĂ</h2><p class="subtitle">Vopsea custom și număr de înmatriculare</p>';
    el.appendChild(cosmeticsColorField('CULOARE PRIMARĂ', 'primary'));
    el.appendChild(cosmeticsColorField('CULOARE SECUNDARĂ', 'secondary'));
    const plateField = document.createElement('div');
    plateField.className = 'field';
    plateField.innerHTML = '<label><span>PLĂCUȚĂ (max 8)</span></label>';
    const plateInput = document.createElement('input');
    plateInput.type = 'text';
    plateInput.maxLength = 8;
    plateInput.className = 'plate-input';
    plateInput.value = (cosmetics && cosmetics.plateText) || '';
    plateInput.addEventListener('input', () => {
        cosmetics = ensureCosmetics(cosmetics);
        cosmetics.plateText = plateInput.value.replace(/\s+/g, '').toUpperCase();
        preview();
    });
    plateField.appendChild(plateInput);
    el.appendChild(plateField);
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
    const dyno = tune.dyno || stockTune().dyno;
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
    el.innerHTML = `
        <h2>STAND DYNO</h2>
        <p class="subtitle">Testul se face pe loc — masina nu se muta.</p>
        <div class="dyno-steps">
            <p><strong>1.</strong> Apasă START — mașina se blochează pe loc (în garaj)</p>
            <p><strong>2.</strong> Meniul se închide temporar (normal)</p>
            <p><strong>3.</strong> Countdown 3…2…1</p>
            <p><strong>4.</strong> Ține <strong>W</strong> apăsat 10 secunde</p>
            <p><strong>5.</strong> Mașina rămâne pe loc — doar dai gaz</p>
        </div>`;
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
        visual: panelVisual,
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
    updateStatusBanner();
    renderRail();
    renderPanels();
}

if (btnCancel) btnCancel.addEventListener('click', () => post('tuningClose'));
if (btnSave) btnSave.addEventListener('click', () => post('tuningSave', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics), flash: true }));

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (lscApp && !lscApp.classList.contains('hidden')) post('lscClose');
        else post('tuningClose');
    }
});

const lscApp = document.getElementById('lsc-app');
const lscTitle = document.getElementById('lscTitle');
const lscSub = document.getElementById('lscSub');
const lscRepair = document.getElementById('lscRepair');
const lscTune = document.getElementById('lscTune');
const lscCancel = document.getElementById('lscCancel');

if (lscRepair) lscRepair.addEventListener('click', () => post('lscRepair'));
if (lscTune) lscTune.addEventListener('click', () => post('lscTune'));
if (lscCancel) lscCancel.addEventListener('click', () => post('lscClose'));

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    const action = payload.action;
    const data = payload.data || payload;

    if (action === 'lscOpen' && lscApp) {
        if (lscTitle) lscTitle.textContent = data.title || 'LS CUSTOMS';
        if (lscSub) lscSub.textContent = data.shopLabel || 'Alege serviciul dorit';
        if (lscRepair) {
            lscRepair.style.display = data.repairAvailable ? 'block' : 'none';
            lscRepair.textContent = `Reparație vehicul — $${data.repairPrice || 250}`;
        }
        lscApp.classList.remove('hidden');
        if (app) app.classList.add('hidden');
    }
    if (action === 'lscClose' && lscApp) {
        lscApp.classList.add('hidden');
    }

    if (action === 'open') {
        if (lscApp) lscApp.classList.add('hidden');
        tune = ensureTune(data.tune);
        cosmetics = ensureCosmetics(data.cosmetics);
        hasSavedMap = data.saved === true;
        previewDirty = false;
        costs = data.costs || costs;
        if (shopLabel) shopLabel.textContent = data.shop || 'ECU Bay';
        if (plateLabel) plateLabel.textContent = data.plate || cosmetics.plateText || '—';
        activeTab = 'exhaust_pop';
        if (app) app.classList.remove('hidden');
        renderAll();
    }
    if (action === 'close' && app) {
        app.classList.add('hidden');
        previewDirty = false;
    }
    if (action === 'saved') {
        hasSavedMap = true;
        previewDirty = false;
        if (data?.tune) tune = ensureTune(data.tune);
        if (data?.cosmetics) cosmetics = ensureCosmetics(data.cosmetics);
        if (data?.plate && plateLabel) plateLabel.textContent = data.plate;
        renderAll();
    }
    if (action === 'dynoRunning') {
        if (app) app.classList.add('hidden');
    }
    if (action === 'dynoDone' && data?.ok === false && app) {
        app.classList.remove('hidden');
    }
    if (action === 'dynoResult' && data?.dyno) {
        tune = ensureTune(tune);
        tune.dyno = { ...tune.dyno, ...data.dyno };
        hasSavedMap = true;
        previewDirty = false;
        activeTab = 'dyno_power';
        if (app) app.classList.remove('hidden');
        renderAll();
    }
});
