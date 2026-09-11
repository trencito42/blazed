const app = document.getElementById('app');
const tuneCategories = document.getElementById('tuneCategories');
const tunePartsList = document.getElementById('tunePartsList');
const tunePartsTitle = document.getElementById('tunePartsTitle');
const tuneDetail = document.getElementById('tuneDetail');
const shopLabel = document.getElementById('shopLabel');
const plateLabel = document.getElementById('plateLabel');
const ecuStatus = document.getElementById('ecuStatus');
const btnCancel = document.getElementById('btnCancel');
const btnSave = document.getElementById('btnSave');
const installCostEl = document.getElementById('tune-install-cost');

const TOTAL_SEGMENTS = 10;

let tune = null;
let cosmetics = null;
let costs = { save: 750, flash: 150, dyno: 250 };
let activeTab = 'powertrain';
let activePartId = null;
let hasSavedMap = false;
let previewDirty = false;
let hardwareAvailability = {};
let previewTimer = 0;
let hardwareSlots = {};
let featureCosts = {};
let installedTune = null;
let installedCosmetics = null;
let vehicleCapabilities = null;

const categories = [
    { id: 'overview', label: 'Quick Setup', icon: 'ph-grid-four' },
    { id: 'powertrain', label: 'Engine', icon: 'ph-fill ph-engine' },
    { id: 'transmission', label: 'Transmission', icon: 'ph-bold ph-faders' },
    { id: 'brakes', label: 'Brakes', icon: 'ph-fill ph-stop-circle' },
    { id: 'suspension', label: 'Suspension', icon: 'ph-fill ph-car-profile' },
    { id: 'turbo', label: 'Turbo & ECU', icon: 'ph-fill ph-wind' },
    { id: 'handling', label: 'Handling', icon: 'ph-bold ph-steering-wheel' },
    { id: 'exhaust', label: 'Exhaust', icon: 'ph-bold ph-speaker-high' },
    { id: 'visual', label: 'Visual', icon: 'ph-bold ph-palette' },
    { id: 'dyno', label: 'Dyno', icon: 'ph-bold ph-gauge' },
    { id: 'special', label: 'Special', icon: 'ph-bold ph-fire' },
];

const categoryTitles = {
    overview: 'Quick Setup',
    powertrain: 'Engine Upgrades',
    transmission: 'Transmission',
    brakes: 'Brake Upgrades',
    suspension: 'Suspension',
    turbo: 'Turbo & ECU Map',
    handling: 'Handling Tuning',
    exhaust: 'Exhaust Profile',
    visual: 'Paint & Plate',
    dyno: 'Dyno',
    special: 'Special Features',
};

function cap(key) {
    return vehicleCapabilities && vehicleCapabilities[key] === true;
}

function powerLimit() {
    return (vehicleCapabilities && vehicleCapabilities.limits && vehicleCapabilities.limits.power) || 65;
}

function tabAllowed(itemId) {
    if (!vehicleCapabilities) return true;
    if (itemId === 'overview' || itemId === 'visual' || itemId === 'dyno') return true;
    if (itemId === 'powertrain' || itemId === 'transmission' || itemId === 'turbo') return cap('power') || cap('hardware');
    if (itemId === 'brakes' || itemId === 'suspension' || itemId === 'handling') return cap('hardware') || cap('tractionControl');
    if (itemId === 'exhaust') return cap('exhaustModes');
    if (itemId === 'special') return cap('antiLag') || cap('drift') || cap('hud');
    return true;
}

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

function stockTune() {
    return {
        profileVersion: 2,
        stage: 'civil',
        power: 0,
        torque: 0,
        throttleResponse: 0,
        topSpeed: 0,
        shiftSpeed: 0,
        regenBraking: 0,
        exhaust: 'pop_bang',
        pop: { enabled: false, rpmMax: 88, durationMs: 100, secondBurst: false, burstStage: 'civil' },
        flames: { enabled: false, color: { r: 255, g: 120, b: 40 } },
        antiLag: { enabled: false, intensity: 55 },
        drift: { enabled: false, grip: 45 },
        hardware: { engine: 0, brakes: 0, transmission: 0, suspension: 0, armor: 0, turbo: false, launchControl: false },
        handling: { steering: 100, brakePower: 100, suspension: 100, traction: 100 },
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
        hardware: { ...base.hardware, ...(src.hardware || {}) },
        handling: { ...base.handling, ...(src.handling || {}) },
        hud: { ...base.hud, ...(src.hud || {}) },
        dyno: { ...base.dyno, ...(src.dyno || {}) },
    };
}

function sameColor(a, b) {
    return ['r', 'g', 'b'].every((key) => Number(a?.[key]) === Number(b?.[key]));
}

function installQuote() {
    if (!installedTune || !tune) return Number(costs.save || 0) + Number(costs.flash || 0);
    const old = ensureTune(installedTune);
    const next = ensureTune(tune);
    const oldCos = ensureCosmetics(installedCosmetics);
    const nextCos = ensureCosmetics(cosmetics);
    let total = Number(costs.save || 0) + Number(costs.flash || 0);
    Object.entries(hardwareSlots || {}).forEach(([key, slot]) => {
        total += Math.max(0, Number(next.hardware[key] || 0) - Number(old.hardware[key] || 0)) * Number(slot.unitCost || 0);
    });
    ['turbo', 'launchControl'].forEach((key) => {
        if (next.hardware[key] && !old.hardware[key]) total += Number(featureCosts[key] || 0);
    });
    [['pop', next.pop.enabled, old.pop.enabled], ['flames', next.flames.enabled, old.flames.enabled],
        ['antiLag', next.antiLag.enabled, old.antiLag.enabled], ['drift', next.drift.enabled, old.drift.enabled],
        ['hud', next.hud.enabled, old.hud.enabled]].forEach(([key, enabled, wasEnabled]) => {
        if (enabled && !wasEnabled) total += Number(featureCosts[key] || 0);
    });
    if (next.stage !== old.stage) {
        total += Number(next.stage === 'race' ? featureCosts.raceMap : next.stage === 'sport' ? featureCosts.sportMap : 0);
    }
    const tuningKeys = [['power'], ['torque'], ['handling', 'steering'], ['handling', 'brakePower'], ['handling', 'suspension'], ['handling', 'traction']];
    tuningKeys.forEach((path) => {
        const get = (obj) => path.reduce((value, key) => value?.[key], obj);
        total += Math.abs(Number(get(next) || 0) - Number(get(old) || 0)) * Number(featureCosts.customMapStep || 0);
    });
    if (!sameColor(oldCos.primary, nextCos.primary) || !sameColor(oldCos.secondary, nextCos.secondary)
        || Number(oldCos.pearl) !== Number(nextCos.pearl) || Number(oldCos.wheel) !== Number(nextCos.wheel)) {
        total += Number(featureCosts.cosmetics || 0);
    }
    if (nextCos.plateText && nextCos.plateText !== oldCos.plateText) total += Number(featureCosts.vanityPlate || 0);
    return Math.max(0, Math.floor(total));
}

function computePerfStats(tuneObj) {
    const t = ensureTune(tuneObj);
    const accel = Math.min(10, 3 + (t.hardware.engine || 0) * 0.8 + (t.hardware.turbo ? 1.2 : 0)
        + Math.floor((t.power || 0) / 22) + (t.stage === 'race' ? 1.5 : t.stage === 'sport' ? 0.8 : 0));
    const speed = Math.min(10, 3 + (t.hardware.engine || 0) * 0.6 + Math.floor((t.topSpeed || 0) / 12)
        + (t.stage === 'race' ? 1.2 : t.stage === 'sport' ? 0.6 : 0));
    const hand = Math.min(10, Math.max(1, 5 + (t.hardware.suspension || 0) * 0.4
        - Math.floor((t.power || 0) / 35) + ((t.handling.traction || 100) - 100) / 25));
    return { accel: Math.round(accel), speed: Math.round(speed), hand: Math.round(hand) };
}

function renderStatBar(containerId, value, previewDelta = 0) {
    const container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = '';
    const base = Math.max(0, Math.min(TOTAL_SEGMENTS, Number(value) || 0));
    const preview = Number(previewDelta) || 0;
    for (let i = 1; i <= TOTAL_SEGMENTS; i++) {
        const seg = document.createElement('div');
        seg.className = 'stat-segment';
        if (i <= base) seg.classList.add('fill');
        else if (preview > 0 && i <= base + preview) seg.classList.add('fill-accent');
        else if (preview < 0 && i > base + preview && i <= base) seg.classList.add('fill-danger');
        container.appendChild(seg);
    }
}

function updateTuneLabel(elementId, base, delta) {
    const el = document.getElementById(elementId);
    if (!el) return;
    if (delta > 0) el.innerHTML = `${base} <span class="delta up">+${delta}</span>`;
    else if (delta < 0) el.innerHTML = `${base} <span class="delta down">${delta}</span>`;
    else el.textContent = String(base);
}

function renderStatsPanel() {
    const base = computePerfStats(installedTune || tune);
    const next = computePerfStats(tune);
    const delta = {
        accel: next.accel - base.accel,
        speed: next.speed - base.speed,
        hand: next.hand - base.hand,
    };
    renderStatBar('stat-accel-tune', base.accel, delta.accel);
    renderStatBar('stat-speed-tune', base.speed, delta.speed);
    renderStatBar('stat-hand-tune', base.hand, delta.hand);
    updateTuneLabel('tune-accel-val', base.accel, delta.accel);
    updateTuneLabel('tune-speed-val', base.speed, delta.speed);
    updateTuneLabel('tune-hand-val', base.hand, delta.hand);
    if (installCostEl) installCostEl.textContent = installQuote().toLocaleString('en-US');
    updatePriceLabel();
}

function updatePriceLabel() {
    const label = document.getElementById('tune-price-label');
    if (!label) return;
    if (previewDirty) label.textContent = 'Install Cost · Preview';
    else if (hasSavedMap) label.textContent = 'Install Cost · Saved';
    else label.textContent = 'Install Cost';
}

function updateInstallButton() {
    if (installCostEl) installCostEl.textContent = installQuote().toLocaleString('en-US');
    updatePriceLabel();
}

function updateStatusBanner() {
    if (!ecuStatus) return;
    if (previewDirty) {
        ecuStatus.textContent = 'PREVIEW — UNSAVED';
        ecuStatus.className = 'ecu-status ecu-status--preview';
    } else if (hasSavedMap) {
        ecuStatus.textContent = 'MAP SAVED';
        ecuStatus.className = 'ecu-status ecu-status--saved';
    } else {
        ecuStatus.textContent = 'FACTORY MAP';
        ecuStatus.className = 'ecu-status ecu-status--stock';
    }
}

function preview() {
    if (!tune) return;
    previewDirty = true;
    updateStatusBanner();
    updateInstallButton();
    renderStatsPanel();
    window.clearTimeout(previewTimer);
    previewTimer = window.setTimeout(() => {
        post('tuningPreview', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics) });
    }, 70);
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

function hwMax(key, configuredMax) {
    const available = Number(hardwareAvailability[key]);
    return Number.isFinite(available) ? Math.max(0, Math.min(configuredMax, available)) : configuredMax;
}

function hwUnitCost(key) {
    return Number(hardwareSlots[key]?.unitCost || 0);
}

function formatPartPrice(amount) {
    if (!amount || amount === 'Installed') return 'Installed';
    if (typeof amount === 'string') return amount;
    const n = Number(amount);
    if (n >= 1000) return `$${Math.round(n / 1000)}k`;
    return `$${n.toLocaleString('en-US')}`;
}

function createListItem(part, onSelect) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'list-item' + (activePartId === part.id ? ' active' : '');
    const name = document.createElement('span');
    name.textContent = part.label;
    const price = document.createElement('span');
    price.className = 'item-price';
    price.textContent = formatPartPrice(part.price);
    btn.append(name, price);
    btn.addEventListener('click', () => {
        activePartId = part.id;
        if (onSelect) onSelect(part);
        renderAll();
    });
    btn.addEventListener('mouseenter', () => {
        if (part.preview) part.preview();
    });
    return btn;
}

function hardwareParts(key, label, configuredMax) {
    const max = hwMax(key, configuredMax);
    const parts = [];
    for (let level = 0; level <= max; level++) {
        parts.push({
            id: `${key}_${level}`,
            label: level === 0 ? `Stock ${label}` : `${label} Level ${level}`,
            price: level === 0 ? 'Installed' : hwUnitCost(key) * level,
            preview: () => {},
            apply: () => { tune.hardware[key] = level; preview(); },
            isActive: () => Number(tune.hardware[key] || 0) === level,
        });
    }
    return parts;
}

function toggleParts(id, label, key, cost) {
    return [
        {
            id: `${id}_off`,
            label: `${label} — Off`,
            price: 'Installed',
            apply: () => { setTuneValue(key, false); preview(); },
            isActive: () => !getTuneValue(key),
        },
        {
            id: `${id}_on`,
            label: `${label} — On`,
            price: cost,
            apply: () => { setTuneValue(key, true); preview(); },
            isActive: () => !!getTuneValue(key),
        },
    ];
}

function applyPreset(name) {
    const dyno = { ...(tune.dyno || {}) };
    const presets = {
        stock: stockTune(),
        street: {
            ...stockTune(), stage: 'sport', power: 105, torque: 106,
            hardware: { ...stockTune().hardware, engine: 2, brakes: 1, transmission: 1, suspension: 1, turbo: true },
            handling: { steering: 104, brakePower: 110, suspension: 105, traction: 104 },
        },
        track: {
            ...stockTune(), stage: 'race', power: 112, torque: 110,
            hardware: { engine: 4, brakes: 3, transmission: 3, suspension: 3, armor: 1, turbo: true, launchControl: true },
            handling: { steering: 110, brakePower: 130, suspension: 118, traction: 112 },
            pop: { ...stockTune().pop, enabled: true, rpmMax: 84, secondBurst: true },
            flames: { ...stockTune().flames, enabled: true },
        },
        drift: {
            ...stockTune(), stage: 'sport', power: 108, torque: 112,
            hardware: { engine: 3, brakes: 2, transmission: 2, suspension: 2, armor: 0, turbo: true, launchControl: true },
            handling: { steering: 116, brakePower: 112, suspension: 108, traction: 84 },
            drift: { enabled: true, grip: 38 },
            pop: { ...stockTune().pop, enabled: true, rpmMax: 82 },
        },
    };
    tune = ensureTune(presets[name] || presets.stock);
    tune.dyno = dyno;
    preview();
    renderAll();
}

function buildPartsForCategory() {
    const parts = [];
    if (activeTab === 'overview') {
        [
            ['stock', 'Factory Setup', 'Stock map'],
            ['street', 'Street Setup', 'Daily driver'],
            ['track', 'Track Setup', 'Maximum grip'],
            ['drift', 'Drift Setup', 'Reduced grip'],
        ].forEach(([id, label, sub]) => {
            parts.push({
                id: `preset_${id}`,
                label,
                price: sub,
                apply: () => applyPreset(id),
                isActive: () => false,
            });
        });
        return parts;
    }
    if (activeTab === 'powertrain') {
        if (cap('presets')) {
            ['civil', 'sport', 'race'].forEach((stage) => {
                const labels = { civil: 'Factory ECU Map', sport: 'Sport ECU Map', race: 'Race ECU Map' };
                parts.push({
                    id: `stage_${stage}`,
                    label: labels[stage],
                    price: stage === 'civil' ? 'Installed' : (stage === 'race' ? featureCosts.raceMap : featureCosts.sportMap),
                    apply: () => { tune.stage = stage; preview(); },
                    isActive: () => tune.stage === stage,
                });
            });
        }
        if (cap('hardware')) parts.push(...hardwareParts('engine', 'Engine', 4));
        return parts;
    }
    if (activeTab === 'transmission' && cap('hardware')) return hardwareParts('transmission', 'Transmission', 3);
    if (activeTab === 'brakes' && cap('hardware')) return hardwareParts('brakes', 'Brakes', 3);
    if (activeTab === 'suspension' && cap('hardware')) {
        parts.push(...hardwareParts('suspension', 'Suspension', 4));
        parts.push(...hardwareParts('armor', 'Armor', 5));
        return parts;
    }
    if (activeTab === 'turbo') {
        if (cap('turboBoost')) parts.push(...toggleParts('turbo', 'Turbo', 'hardware.turbo', featureCosts.turbo));
        if (cap('launchControl')) parts.push(...toggleParts('lc', 'Launch Control', 'hardware.launchControl', featureCosts.launchControl));
        if (cap('power')) {
            const maxP = powerLimit();
            [0, Math.floor(maxP * 0.33), Math.floor(maxP * 0.66), maxP].forEach((val, idx) => {
                parts.push({
                    id: `power_${val}`,
                    label: val === 0 ? 'Stock Power' : `Power Boost ${idx}`,
                    price: val === 0 ? 'Installed' : featureCosts.customMapStep * val,
                    apply: () => { tune.power = val; preview(); },
                    isActive: () => Number(tune.power) === val,
                });
            });
        }
        return parts;
    }
    if (activeTab === 'exhaust' && cap('exhaustModes')) {
        [
            ['pop_bang', 'Pop & Bang'],
            ['flames', 'Flames'],
            ['diesel', 'Diesel'],
            ['extra', 'Extra Loud'],
        ].forEach(([mode, label]) => {
            parts.push({
                id: `exhaust_${mode}`,
                label,
                price: 'Installed',
                apply: () => {
                    tune.exhaust = mode;
                    if (mode === 'pop_bang' || mode === 'extra' || mode === 'diesel') tune.pop.enabled = true;
                    if (mode === 'flames' || mode === 'extra') tune.flames.enabled = true;
                    preview();
                },
                isActive: () => tune.exhaust === mode,
            });
        });
        return parts;
    }
    if (activeTab === 'dyno') {
        parts.push({
            id: 'dyno_run',
            label: 'Start Dyno Run',
            price: costs.dyno,
            apply: () => post('tuningDyno'),
            isActive: () => false,
        });
        parts.push({
            id: 'dyno_view',
            label: 'Last Run Results',
            price: `${tune?.dyno?.lastHp || 0} HP`,
            apply: () => {},
            isActive: () => true,
        });
        return parts;
    }
    if (activeTab === 'special') {
        if (cap('antiLag')) parts.push(...toggleParts('antilag', 'Anti-Lag', 'antiLag.enabled', featureCosts.antiLag));
        if (cap('drift')) parts.push(...toggleParts('drift', 'Drift Mode', 'drift.enabled', featureCosts.drift));
        if (cap('hud')) parts.push(...toggleParts('hud', 'ECU HUD', 'hud.enabled', featureCosts.hud));
        return parts;
    }
    if (activeTab === 'handling' || activeTab === 'visual') {
        parts.push({
            id: `${activeTab}_custom`,
            label: activeTab === 'handling' ? 'Fine-Tune Handling' : 'Customize Paint',
            price: 'Adjust below',
            apply: () => {},
            isActive: () => true,
        });
        return parts;
    }
    return parts;
}

function sliderField(label, key, min, max, suffix) {
    const field = document.createElement('div');
    field.className = 'field';
    const val = getTuneValue(key);
    const safeVal = Number.isFinite(Number(val)) ? Number(val) : min;
    const id = `lbl-${String(key).replace(/[^a-z0-9_-]/gi, '_')}`;
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

function renderDetailPanel() {
    if (!tuneDetail) return;
    tuneDetail.innerHTML = '';
    if (activeTab === 'handling') {
        tuneDetail.appendChild(sliderField('Steering Angle', 'handling.steering', 85, 120, '%'));
        tuneDetail.appendChild(sliderField('Brake Power', 'handling.brakePower', 85, 140, '%'));
        tuneDetail.appendChild(sliderField('Suspension Stiffness', 'handling.suspension', 80, 130, '%'));
        tuneDetail.appendChild(sliderField('Traction', 'handling.traction', 75, 120, '%'));
    }
    if (activeTab === 'visual') {
        tuneDetail.appendChild(cosmeticsColorField('Primary Color', 'primary'));
        tuneDetail.appendChild(cosmeticsColorField('Secondary Color', 'secondary'));
        const plateField = document.createElement('div');
        plateField.className = 'field';
        plateField.innerHTML = '<label><span>License Plate (max 8)</span></label>';
        const plateInput = document.createElement('input');
        plateInput.type = 'text';
        plateInput.maxLength = 8;
        plateInput.value = (cosmetics && cosmetics.plateText) || '';
        plateInput.addEventListener('input', () => {
            cosmetics = ensureCosmetics(cosmetics);
            cosmetics.plateText = plateInput.value.replace(/\s+/g, '').toUpperCase();
            preview();
        });
        plateField.appendChild(plateInput);
        tuneDetail.appendChild(plateField);
    }
    if (activeTab === 'exhaust') {
        tuneDetail.appendChild(toggleRow('Exhaust Active', 'pop.enabled'));
        tuneDetail.appendChild(sliderField('Max RPM Pop', 'pop.rpmMax', 70, 100, '%'));
        if (tune.exhaust === 'flames' || tune.exhaust === 'extra') {
            tuneDetail.appendChild(toggleRow('Exhaust Flames', 'flames.enabled'));
        }
    }
    if (activeTab === 'special' && cap('drift')) {
        tuneDetail.appendChild(sliderField('Drift Grip', 'drift.grip', 20, 80, '%'));
    }
    if (activeTab === 'special' && cap('antiLag')) {
        tuneDetail.appendChild(sliderField('Anti-Lag Intensity', 'antiLag.intensity', 0, 100, '%'));
    }
    if (activeTab === 'dyno') {
        const dyno = tune.dyno || stockTune().dyno;
        const stats = document.createElement('div');
        stats.className = 'dyno-stats';
        stats.innerHTML = `
            <div class="stat-box"><div class="val">${dyno.lastHp || 0}</div><div class="lbl">HP</div></div>
            <div class="stat-box"><div class="val">${dyno.lastTorque || 0}</div><div class="lbl">NM</div></div>
            <div class="stat-box"><div class="val">$${costs.dyno}</div><div class="lbl">RUN COST</div></div>`;
        tuneDetail.appendChild(stats);
    }
}

function renderCategories() {
    if (!tuneCategories) return;
    const title = document.createElement('div');
    title.className = 'section-title';
    title.textContent = 'Components';
    tuneCategories.innerHTML = '';
    tuneCategories.appendChild(title);
    categories.forEach((cat) => {
        if (!tabAllowed(cat.id)) return;
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'cat-item' + (activeTab === cat.id ? ' active' : '');
        btn.innerHTML = `<i class="${cat.icon}"></i> ${cat.label}`;
        btn.addEventListener('click', () => {
            activeTab = cat.id;
            activePartId = null;
            renderAll();
        });
        tuneCategories.appendChild(btn);
    });
}

function renderPartList() {
    if (!tunePartsList) return;
    if (tunePartsTitle) tunePartsTitle.textContent = categoryTitles[activeTab] || 'Upgrades';
    tunePartsList.innerHTML = '';
    const parts = buildPartsForCategory();
    if (!parts.length) {
        const empty = document.createElement('p');
        empty.className = 'item-price';
        empty.textContent = 'No upgrades available for this vehicle.';
        tunePartsList.appendChild(empty);
        return;
    }
    if (!activePartId) {
        const active = parts.find((p) => p.isActive && p.isActive());
        activePartId = active ? active.id : parts[0].id;
    }
    parts.forEach((part) => {
        if (part.isActive && part.isActive()) activePartId = part.id;
        tunePartsList.appendChild(createListItem(part, () => {
            if (part.apply) part.apply();
        }));
    });
}

function renderAll() {
    tune = ensureTune(tune);
    updateStatusBanner();
    renderCategories();
    renderPartList();
    renderDetailPanel();
    renderStatsPanel();
    updateInstallButton();
}

if (btnCancel) btnCancel.addEventListener('click', () => post('tuningClose'));
if (btnSave) btnSave.addEventListener('click', () => post('tuningSave', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics), flash: true }));

document.addEventListener('keydown', (e) => {
    if (!app || app.classList.contains('hidden')) return;
    if (e.key === 'Escape') {
        e.preventDefault();
        post('tuningClose');
    }
    if (e.key === 'Enter' && !e.repeat) {
        const tag = (e.target && e.target.tagName) || '';
        if (tag === 'INPUT' || tag === 'TEXTAREA') return;
        e.preventDefault();
        post('tuningSave', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics), flash: true });
    }
});

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    const action = payload.action;
    const data = payload.data || payload;

    if (action === 'open') {
        tune = ensureTune(data.tune);
        cosmetics = ensureCosmetics(data.cosmetics);
        hasSavedMap = data.saved === true;
        previewDirty = false;
        costs = data.costs || costs;
        hardwareSlots = data.hardwareSlots || {};
        featureCosts = data.featureCosts || {};
        installedTune = ensureTune(data.tune);
        installedCosmetics = ensureCosmetics(data.cosmetics);
        if (shopLabel) shopLabel.textContent = data.shop || 'ECU Bay';
        if (plateLabel) plateLabel.textContent = data.plate || cosmetics.plateText || '—';
        hardwareAvailability = data.hardwareAvailability || {};
        vehicleCapabilities = data.capabilities || null;
        const drivetrainLabel = document.getElementById('drivetrainLabel');
        if (drivetrainLabel) {
            drivetrainLabel.textContent = data.drivetrainLabel || (vehicleCapabilities && vehicleCapabilities.propulsion) || 'PETROL';
        }
        activeTab = 'overview';
        activePartId = null;
        if (app) app.classList.remove('hidden');
        renderAll();
    }
    if (action === 'close' && app) {
        window.clearTimeout(previewTimer);
        app.classList.add('hidden');
        previewDirty = false;
    }
    if (action === 'saved') {
        hasSavedMap = true;
        previewDirty = false;
        if (data?.tune) tune = ensureTune(data.tune);
        if (data?.cosmetics) cosmetics = ensureCosmetics(data.cosmetics);
        installedTune = ensureTune(tune);
        installedCosmetics = ensureCosmetics(cosmetics);
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
        activeTab = 'dyno';
        if (app) app.classList.remove('hidden');
        renderAll();
    }
});

if (new URLSearchParams(window.location.search).get('qa') === 'tuning') {
    window.postMessage({
        action: 'open',
        data: {
            plate: 'BLZ 2046',
            shop: 'LS Customs — ECU Bay',
            saved: true,
            tune: {
                ...stockTune(), stage: 'sport', power: 106, torque: 108,
                hardware: { engine: 2, brakes: 1, transmission: 1, suspension: 1, armor: 0, turbo: true, launchControl: false },
            },
            cosmetics: stockCosmetics(),
            costs: { save: 750, flash: 150, dyno: 250 },
            hardwareAvailability: { engine: 4, brakes: 3, transmission: 3, suspension: 4, armor: 5, turbo: true },
            hardwareSlots: {
                engine: { unitCost: 1800 }, brakes: { unitCost: 1200 }, transmission: { unitCost: 1600 },
                suspension: { unitCost: 1100 }, armor: { unitCost: 1500 },
            },
            featureCosts: {
                turbo: 4500, launchControl: 2200, pop: 950, flames: 800, antiLag: 2400, drift: 1400,
                hud: 350, sportMap: 2200, raceMap: 5200, customMapStep: 55, cosmetics: 600, vanityPlate: 1800,
            },
        },
    }, '*');
}
