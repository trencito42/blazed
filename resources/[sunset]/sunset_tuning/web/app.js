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
let activeTab = 'overview';
let activePartId = null;
let hasSavedMap = false;
let previewDirty = false;
let hardwareAvailability = {};
let visualAvailability = {};
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
    { id: 'bodykit', label: 'Body & Aero', icon: 'ph-bold ph-shield' },
    { id: 'lighting', label: 'Neons & Lights', icon: 'ph-bold ph-sparkle' },
    { id: 'wheels', label: 'Wheels & Rims', icon: 'ph-bold ph-circle' },
    { id: 'visual', label: 'Paint & Tint', icon: 'ph-bold ph-palette' },
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
    bodykit: 'Body & Aerodynamics',
    lighting: 'Underglow & Headlights',
    wheels: 'Wheels, Rims & Stance',
    visual: 'Paint, Pearlescent & Tint',
    dyno: 'Dyno Testing',
    special: 'Special Features',
};

const BODYKIT_SLOTS = [
    { key: 'spoiler', label: 'Spoiler / Wing' },
    { key: 'frontBumper', label: 'Front Bumper' },
    { key: 'rearBumper', label: 'Rear Bumper' },
    { key: 'sideSkirt', label: 'Side Skirts' },
    { key: 'exhaust', label: 'Exhaust Tips' },
    { key: 'hood', label: 'Hood / Bonnet' },
    { key: 'grille', label: 'Grille' },
    { key: 'roof', label: 'Roof' },
    { key: 'leftFender', label: 'Left Fender' },
    { key: 'rightFender', label: 'Right Fender' },
    { key: 'rollCage', label: 'Roll Cage / Interior' },
    { key: 'livery', label: 'Livery / Decals' },
];

const WHEEL_TYPES = [
    { id: 0, label: 'Sport' },
    { id: 1, label: 'Muscle' },
    { id: 2, label: 'Lowrider' },
    { id: 3, label: 'SUV' },
    { id: 4, label: 'Offroad' },
    { id: 5, label: 'Tuner' },
    { id: 7, label: 'High End' },
    { id: 8, label: "Benny's Original" },
    { id: 9, label: "Benny's Bespoke" },
    { id: 10, label: 'Open Wheel' },
    { id: 11, label: 'Street' },
    { id: 12, label: 'Track' },
];

const WINDOW_TINTS = [
    { id: 0, label: 'None (Stock)' },
    { id: 1, label: 'Pure Black (5%)' },
    { id: 2, label: 'Dark Smoke (15%)' },
    { id: 3, label: 'Light Smoke (35%)' },
    { id: 4, label: 'Stock Clear' },
    { id: 5, label: 'Limo (1%)' },
    { id: 6, label: 'Green Tint' },
];

const XENON_COLORS = [
    { id: 0, label: 'White', color: '#ffffff' },
    { id: 1, label: 'Blue', color: '#0055ff' },
    { id: 2, label: 'Electric Blue', color: '#00d0ff' },
    { id: 3, label: 'Mint Green', color: '#00ffaa' },
    { id: 4, label: 'Lime Green', color: '#55ff00' },
    { id: 5, label: 'Yellow', color: '#ffea00' },
    { id: 6, label: 'Golden Shower', color: '#ffaa00' },
    { id: 7, label: 'Orange', color: '#ff5500' },
    { id: 8, label: 'Red', color: '#ff0000' },
    { id: 9, label: 'Pony Pink', color: '#ff77aa' },
    { id: 10, label: 'Hot Pink', color: '#ff007f' },
    { id: 11, label: 'Purple', color: '#8800ff' },
    { id: 12, label: 'Blacklight', color: '#3300ff' },
];

const NEON_PRESETS = [
    { label: 'Electric Blue', r: 0, g: 150, b: 255 },
    { label: 'Mint Green', r: 0, g: 255, b: 170 },
    { label: 'Lime Green', r: 50, g: 255, b: 0 },
    { label: 'Yellow', r: 255, g: 220, b: 0 },
    { label: 'Orange', r: 255, g: 100, b: 0 },
    { label: 'Crimson Red', r: 255, g: 0, b: 0 },
    { label: 'Hot Pink', r: 255, g: 20, b: 147 },
    { label: 'Purple', r: 138, g: 43, b: 226 },
    { label: 'Blacklight', r: 50, g: 0, b: 255 },
    { label: 'Ice White', r: 255, g: 255, b: 255 },
    { label: 'Gold', r: 255, g: 180, b: 0 },
];

const PAINT_PRESETS = [
    { label: 'Midnight Black', r: 10, g: 10, b: 10 },
    { label: 'Pure White', r: 255, g: 255, b: 255 },
    { label: 'Gunmetal Grey', r: 70, g: 70, b: 70 },
    { label: 'Crimson Red', r: 180, g: 10, b: 10 },
    { label: 'Sunset Orange', r: 235, g: 90, b: 15 },
    { label: 'Racing Yellow', r: 240, g: 210, b: 20 },
    { label: 'Kawasaki Green', r: 20, g: 190, b: 40 },
    { label: 'Miami Blue', r: 0, g: 150, b: 230 },
    { label: 'Midnight Blue', r: 15, g: 30, b: 90 },
    { label: 'Royal Purple', r: 100, g: 20, b: 160 },
    { label: 'Hot Pink', r: 230, g: 30, b: 130 },
    { label: 'Rose Gold', r: 200, g: 140, b: 130 },
];

const PAINT_TYPES = [
    { id: 0, label: 'Gloss / Standard' },
    { id: 1, label: 'Metallic' },
    { id: 3, label: 'Matte' },
    { id: 4, label: 'Metal' },
    { id: 5, label: 'Chrome' },
];

const TYRE_SMOKE_PRESETS = [
    { label: 'White Smoke', r: 255, g: 255, b: 255 },
    { label: 'Red Smoke', r: 255, g: 20, b: 20 },
    { label: 'Blue Smoke', r: 20, g: 80, b: 255 },
    { label: 'Yellow Smoke', r: 255, g: 220, b: 0 },
    { label: 'Green Smoke', r: 20, g: 255, b: 50 },
    { label: 'Purple Smoke', r: 180, g: 20, b: 255 },
    { label: 'Black Smoke', r: 1, g: 1, b: 1 },
];

function cap(key) {
    return vehicleCapabilities && vehicleCapabilities[key] === true;
}

function powerLimit() {
    return (vehicleCapabilities && vehicleCapabilities.limits && vehicleCapabilities.limits.power) || 65;
}

function tabAllowed(itemId) {
    if (!vehicleCapabilities) return true;
    if (itemId === 'overview' || itemId === 'bodykit' || itemId === 'lighting' || itemId === 'wheels' || itemId === 'visual' || itemId === 'dyno') return true;
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
        paintType: 0,
        primary: { r: 0, g: 0, b: 0 },
        secondary: { r: 111, g: 111, b: 111 },
        pearl: 0,
        wheel: 0,
        plateText: '',
        windowTint: 0,
        xenon: false,
        xenonColor: 0,
        neon: {
            enabled: false,
            front: true,
            back: true,
            left: true,
            right: true,
            color: { r: 0, g: 150, b: 255 },
        },
        tyreSmoke: false,
        tyreSmokeColor: { r: 255, g: 255, b: 255 },
        wheelType: 0,
        mods: {
            spoiler: -1,
            frontBumper: -1,
            rearBumper: -1,
            sideSkirt: -1,
            exhaust: -1,
            rollCage: -1,
            grille: -1,
            hood: -1,
            leftFender: -1,
            rightFender: -1,
            roof: -1,
            wheels: -1,
            livery: -1,
        },
    };
}

function ensureCosmetics(raw) {
    const base = stockCosmetics();
    const src = raw && typeof raw === 'object' ? raw : {};
    return {
        ...base,
        ...src,
        paintType: Number(src.paintType ?? base.paintType ?? 0),
        primary: { ...base.primary, ...(src.primary || {}) },
        secondary: { ...base.secondary, ...(src.secondary || {}) },
        neon: {
            ...base.neon,
            ...(src.neon || {}),
            color: { ...(base.neon.color || {}), ...((src.neon && src.neon.color) || {}) },
        },
        tyreSmoke: !!(src.tyreSmoke ?? base.tyreSmoke),
        tyreSmokeColor: { ...base.tyreSmokeColor, ...(src.tyreSmokeColor || {}) },
        mods: { ...base.mods, ...(src.mods || {}) },
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
    if (!a && !b) return true;
    if (!a || !b) return false;
    return ['r', 'g', 'b'].every((key) => Number(a[key]) === Number(b[key]));
}

function getCosmeticsValue(path) {
    return path.split('.').reduce((acc, key) => (acc ? acc[key] : undefined), cosmetics);
}

function setCosmeticsValue(path, value) {
    cosmetics = ensureCosmetics(cosmetics);
    const parts = path.split('.');
    let ref = cosmetics;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!ref[parts[i]]) ref[parts[i]] = {};
        ref = ref[parts[i]];
    }
    ref[parts[parts.length - 1]] = value;
}

function hasTuningChanges() {
    if (!installedTune || !tune) return false;
    const old = ensureTune(installedTune);
    const next = ensureTune(tune);
    const oldCos = ensureCosmetics(installedCosmetics);
    const nextCos = ensureCosmetics(cosmetics);

    for (const key of Object.keys(hardwareSlots || {})) {
        if (Number(next.hardware[key] || 0) !== Number(old.hardware[key] || 0)) return true;
    }
    if (!!next.hardware.turbo !== !!old.hardware.turbo) return true;
    if (!!next.hardware.launchControl !== !!old.hardware.launchControl) return true;
    if (next.stage !== old.stage) return true;

    if (!!next.pop.enabled !== !!old.pop.enabled) return true;
    if (!!next.flames.enabled !== !!old.flames.enabled) return true;
    if (!!next.antiLag.enabled !== !!old.antiLag.enabled) return true;
    if (!!next.drift.enabled !== !!old.drift.enabled) return true;
    if (!!next.hud.enabled !== !!old.hud.enabled) return true;
    if (next.exhaust !== old.exhaust) return true;

    const checkPaths = [['power'], ['torque'], ['handling', 'steering'], ['handling', 'brakePower'], ['handling', 'suspension'], ['handling', 'traction']];
    for (const p of checkPaths) {
        const get = (obj) => p.reduce((v, k) => v?.[k], obj);
        if (Number(get(next) || 0) !== Number(get(old) || 0)) return true;
    }

    if (Number(nextCos.paintType || 0) !== Number(oldCos.paintType || 0)) return true;
    if (!sameColor(oldCos.primary, nextCos.primary) || !sameColor(oldCos.secondary, nextCos.secondary)) return true;
    if (Number(oldCos.pearl) !== Number(nextCos.pearl) || Number(oldCos.wheel) !== Number(nextCos.wheel)) return true;
    if (Number(oldCos.windowTint) !== Number(nextCos.windowTint)) return true;
    if (nextCos.plateText && nextCos.plateText !== oldCos.plateText) return true;

    if (!!nextCos.neon?.enabled !== !!oldCos.neon?.enabled) return true;
    if (nextCos.neon?.enabled) {
        if (!sameColor(oldCos.neon?.color, nextCos.neon?.color)) return true;
        if (!!nextCos.neon.front !== !!oldCos.neon.front) return true;
        if (!!nextCos.neon.back !== !!oldCos.neon.back) return true;
        if (!!nextCos.neon.left !== !!oldCos.neon.left) return true;
        if (!!nextCos.neon.right !== !!oldCos.neon.right) return true;
    }

    if (!!nextCos.xenon !== !!oldCos.xenon) return true;
    if (nextCos.xenon && nextCos.xenonColor !== oldCos.xenonColor) return true;

    if (!!nextCos.tyreSmoke !== !!oldCos.tyreSmoke) return true;
    if (nextCos.tyreSmoke && !sameColor(oldCos.tyreSmokeColor, nextCos.tyreSmokeColor)) return true;

    if (nextCos.wheelType !== oldCos.wheelType) return true;
    if (nextCos.mods?.wheels !== oldCos.mods?.wheels) return true;
    if (nextCos.mods && oldCos.mods) {
        for (const k of Object.keys(nextCos.mods)) {
            if (nextCos.mods[k] !== oldCos.mods[k]) return true;
        }
    }

    return false;
}

function installQuote() {
    if (!installedTune || !tune) return 0;
    if (!hasTuningChanges()) return 0;

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
        || Number(oldCos.pearl) !== Number(nextCos.pearl) || Number(oldCos.wheel) !== Number(nextCos.wheel)
        || Number(oldCos.windowTint) !== Number(nextCos.windowTint) || Number(oldCos.paintType || 0) !== Number(nextCos.paintType || 0)) {
        total += Number(featureCosts.cosmetics || 600);
    }
    if (nextCos.plateText && nextCos.plateText !== oldCos.plateText) total += Number(featureCosts.vanityPlate || 1800);

    if (nextCos.neon?.enabled && !oldCos.neon?.enabled) total += 500;
    else if (nextCos.neon?.enabled && !sameColor(oldCos.neon?.color, nextCos.neon?.color)) total += 150;

    if (nextCos.xenon && !oldCos.xenon) total += 350;
    else if (nextCos.xenon && nextCos.xenonColor !== oldCos.xenonColor) total += 100;

    if (nextCos.tyreSmoke && !oldCos.tyreSmoke) total += 400;
    else if (nextCos.tyreSmoke && !sameColor(oldCos.tyreSmokeColor, nextCos.tyreSmokeColor)) total += 150;

    if (nextCos.wheelType !== oldCos.wheelType || (nextCos.mods?.wheels !== oldCos.mods?.wheels)) total += 400;

    if (nextCos.mods && oldCos.mods) {
        Object.keys(nextCos.mods).forEach((k) => {
            if (k !== 'wheels' && nextCos.mods[k] !== oldCos.mods[k]) total += 250;
        });
    }

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
        ecuStatus.textContent = 'PREVIEW';
        ecuStatus.className = 'status-preview';
    } else if (hasSavedMap) {
        ecuStatus.textContent = 'SAVED';
        ecuStatus.className = 'status-saved';
    } else {
        ecuStatus.textContent = 'FACTORY MAP';
        ecuStatus.className = 'status-factory';
    }
}

function preview() {
    previewDirty = true;
    updateStatusBanner();
    renderStatsPanel();
    updateInstallButton();
    window.clearTimeout(previewTimer);
    previewTimer = window.setTimeout(() => {
        post('tuningPreview', {
            tune: ensureTune(tune),
            cosmetics: ensureCosmetics(cosmetics),
        }).then((res) => {
            if (res && typeof res.wheelsCount === 'number' && res.wheelsCount !== visualAvailability.wheels) {
                visualAvailability.wheels = res.wheelsCount;
                if (activeTab === 'wheels' && activePartId === 'wheel_rim') {
                    renderDetailPanel();
                }
            }
        });
    }, 60);
}

function getTuneValue(path) {
    return path.split('.').reduce((acc, key) => (acc ? acc[key] : undefined), tune);
}

function setTuneValue(path, value) {
    tune = ensureTune(tune);
    const parts = path.split('.');
    let ref = tune;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!ref[parts[i]]) ref[parts[i]] = {};
        ref = ref[parts[i]];
    }
    ref[parts[parts.length - 1]] = value;
}

function hardwareParts(categoryKey, slotKey, maxLevel) {
    const slot = hardwareSlots[slotKey] || { unitCost: 1000 };
    const parts = [];
    const count = Math.min(maxLevel || 0, hardwareAvailability[slotKey] || 0);
    const current = Number(tune?.hardware?.[slotKey] || 0);
    const installed = Number(installedTune?.hardware?.[slotKey] || 0);

    parts.push({
        id: `${slotKey}_0`,
        label: 'Stock Factory',
        price: installed === 0 ? 'Installed' : '$0',
        isInstalled: installed === 0,
        apply: () => {
            tune.hardware[slotKey] = 0;
            preview();
        },
        isActive: () => current === 0,
    });

    for (let i = 1; i <= count; i++) {
        const cost = slot.unitCost * i;
        const isInst = (installed === i);
        parts.push({
            id: `${slotKey}_${i}`,
            label: `Level ${i} Upgrade`,
            price: isInst ? 'Installed' : `$${cost.toLocaleString('en-US')}`,
            isInstalled: isInst,
            apply: () => {
                tune.hardware[slotKey] = i;
                preview();
            },
            isActive: () => current === i,
        });
    }
    return parts;
}

function toggleParts(id, label, path, cost) {
    const parts = [];
    const enabled = !!getTuneValue(path);
    parts.push({
        id: `${id}_off`,
        label: `${label} (Disabled)`,
        price: 'Stock',
        apply: () => {
            setTuneValue(path, false);
            preview();
        },
        isActive: () => !enabled,
    });
    parts.push({
        id: `${id}_on`,
        label: `${label} (Enabled)`,
        price: `$${(cost || 0).toLocaleString('en-US')}`,
        apply: () => {
            setTuneValue(path, true);
            preview();
        },
        isActive: () => enabled,
    });
    return parts;
}

function renderOverviewParts() {
    const parts = [];
    ['civil', 'sport', 'race'].forEach((stage) => {
        const isInst = installedTune?.stage === stage;
        parts.push({
            id: `stage_${stage}`,
            label: `Stage ${stage.toUpperCase()} Tune`,
            price: isInst ? 'Installed' : (stage === 'civil' ? 'Stock' : `$${(stage === 'sport' ? featureCosts.sportMap : featureCosts.raceMap || 0).toLocaleString('en-US')}`),
            isInstalled: isInst,
            apply: () => {
                tune.stage = stage;
                if (stage === 'race') {
                    tune.power = Math.min(powerLimit(), 45);
                    tune.torque = Math.min(powerLimit(), 40);
                } else if (stage === 'sport') {
                    tune.power = Math.min(powerLimit(), 25);
                    tune.torque = Math.min(powerLimit(), 20);
                } else {
                    tune.power = 0;
                    tune.torque = 0;
                }
                preview();
            },
            isActive: () => tune.stage === stage,
        });
    });
    return parts;
}

function renderPartList() {
    if (!tunePartsList) return;
    tunePartsList.innerHTML = '';
    let parts = [];

    if (activeTab === 'overview') parts = renderOverviewParts();
    else if (activeTab === 'powertrain') parts = hardwareParts('powertrain', 'engine', 4);
    else if (activeTab === 'transmission') parts = hardwareParts('transmission', 'transmission', 3);
    else if (activeTab === 'brakes') parts = hardwareParts('brakes', 'brakes', 3);
    else if (activeTab === 'suspension') parts = hardwareParts('suspension', 'suspension', 4);
    else if (activeTab === 'turbo') {
        if (cap('turboBoost') || cap('factoryTurbo')) {
            parts.push(...toggleParts('turbo', 'Turbocharger', 'hardware.turbo', featureCosts.turbo));
        }
        if (cap('launchControl')) {
            parts.push(...toggleParts('launch', 'Launch Control', 'hardware.launchControl', featureCosts.launchControl));
        }
    } else if (activeTab === 'exhaust' && cap('exhaustModes')) {
        [
            ['pop_bang', 'Pop & Bang'],
            ['flames', 'Flames'],
            ['diesel', 'Diesel'],
            ['extra', 'Extra Loud'],
        ].forEach(([mode, label]) => {
            const isInst = installedTune?.exhaust === mode;
            parts.push({
                id: `exhaust_${mode}`,
                label,
                price: isInst ? 'Installed' : 'Select',
                isInstalled: isInst,
                apply: () => {
                    tune.exhaust = mode;
                    if (mode === 'pop_bang' || mode === 'extra' || mode === 'diesel') tune.pop.enabled = true;
                    if (mode === 'flames' || mode === 'extra') tune.flames.enabled = true;
                    preview();
                },
                isActive: () => tune.exhaust === mode,
            });
        });
    } else if (activeTab === 'bodykit') {
        const availableSlots = BODYKIT_SLOTS.filter((slot) => (visualAvailability[slot.key] || 0) > 0);
        if (availableSlots.length === 0) {
            parts.push({
                id: 'no_aero',
                label: 'No Aero Parts Available',
                price: 'N/A',
                isInstalled: false,
                apply: () => {},
                isActive: () => false,
            });
        } else {
            availableSlots.forEach((slot) => {
                const avail = visualAvailability[slot.key] || 0;
                const cur = cosmetics?.mods?.[slot.key] ?? -1;
                const inst = installedCosmetics?.mods?.[slot.key] ?? -1;
                const isInst = (cur === inst);
                const curLabel = cur === -1 ? 'Stock' : `Mod #${cur + 1}`;
                parts.push({
                    id: `body_${slot.key}`,
                    label: slot.label,
                    price: `${curLabel} (${avail} opts)`,
                    isInstalled: isInst,
                    apply: () => {
                        activePartId = slot.key;
                        post('tuningFocusPart', { part: slot.key });
                        renderDetailPanel();
                    },
                    isActive: () => activePartId === slot.key,
                });
            });
            if (!activePartId || !availableSlots.some((s) => s.key === activePartId)) {
                activePartId = availableSlots[0].key;
            }
        }
    } else if (activeTab === 'lighting') {
        const neonActive = cosmetics?.neon?.enabled === true;
        const neonInst = installedCosmetics?.neon?.enabled === true;
        parts.push({
            id: 'neon_underglow',
            label: 'Underglow Neons',
            price: neonActive ? (neonInst ? 'Installed' : '$500') : 'Disabled',
            isInstalled: neonInst && neonActive,
            apply: () => {
                activePartId = 'neon';
                post('tuningFocusPart', { part: 'lighting' });
                renderDetailPanel();
            },
            isActive: () => activePartId === 'neon',
        });
        const xenonActive = cosmetics?.xenon === true;
        const xenonInst = installedCosmetics?.xenon === true;
        parts.push({
            id: 'xenon_lights',
            label: 'Xenon Headlights',
            price: xenonActive ? (xenonInst ? 'Installed' : '$350') : 'Halogen (Stock)',
            isInstalled: xenonInst && xenonActive,
            apply: () => {
                activePartId = 'xenon';
                post('tuningFocusPart', { part: 'lighting' });
                renderDetailPanel();
            },
            isActive: () => activePartId === 'xenon',
        });
    } else if (activeTab === 'wheels') {
        const wt = WHEEL_TYPES.find((w) => w.id === (cosmetics?.wheelType ?? 0))?.label || 'Sport';
        parts.push({
            id: 'wheel_type',
            label: 'Wheel Category',
            price: wt,
            apply: () => {
                activePartId = 'wheel_type';
                post('tuningFocusPart', { part: 'wheels' });
                renderDetailPanel();
            },
            isActive: () => activePartId === 'wheel_type',
        });
        const rimMod = cosmetics?.mods?.wheels ?? -1;
        const instRim = installedCosmetics?.mods?.wheels ?? -1;
        parts.push({
            id: 'wheel_rim',
            label: 'Rim Model',
            price: rimMod === -1 ? 'Stock Rims' : `Rim #${rimMod + 1}`,
            isInstalled: rimMod === instRim,
            apply: () => {
                activePartId = 'wheel_rim';
                post('tuningFocusPart', { part: 'wheels' });
                renderDetailPanel();
            },
            isActive: () => activePartId === 'wheel_rim',
        });
        parts.push({
            id: 'wheel_color',
            label: 'Wheel Paint Color',
            price: 'Adjust below',
            apply: () => {
                activePartId = 'wheel_color';
                post('tuningFocusPart', { part: 'wheels' });
                renderDetailPanel();
            },
            isActive: () => activePartId === 'wheel_color',
        });
        const smokeActive = cosmetics?.tyreSmoke === true;
        const smokeInst = installedCosmetics?.tyreSmoke === true;
        parts.push({
            id: 'tyre_smoke',
            label: 'Burnout Tyre Smoke',
            price: smokeActive ? (smokeInst ? 'Installed' : '$400') : 'Stock (Off)',
            isInstalled: smokeInst && smokeActive,
            apply: () => {
                activePartId = 'smoke';
                post('tuningFocusPart', { part: 'wheels' });
                renderDetailPanel();
            },
            isActive: () => activePartId === 'smoke',
        });
    } else if (activeTab === 'visual') {
        parts.push({
            id: 'paint_primary',
            label: 'Primary Paint',
            price: 'Adjust below',
            apply: () => { activePartId = 'primary'; post('tuningFocusPart', { part: 'overview' }); renderDetailPanel(); },
            isActive: () => activePartId === 'primary',
        });
        parts.push({
            id: 'paint_secondary',
            label: 'Secondary Paint',
            price: 'Adjust below',
            apply: () => { activePartId = 'secondary'; post('tuningFocusPart', { part: 'overview' }); renderDetailPanel(); },
            isActive: () => activePartId === 'secondary',
        });
        const finishLabel = PAINT_TYPES.find((f) => f.id === (cosmetics?.paintType ?? 0))?.label || 'Gloss';
        const instFinish = (installedCosmetics?.paintType ?? 0) === (cosmetics?.paintType ?? 0);
        parts.push({
            id: 'paint_finish',
            label: 'Paint Finish / Style',
            price: finishLabel,
            isInstalled: instFinish,
            apply: () => { activePartId = 'finish'; post('tuningFocusPart', { part: 'overview' }); renderDetailPanel(); },
            isActive: () => activePartId === 'finish',
        });
        parts.push({
            id: 'paint_pearl',
            label: 'Pearlescent Coat',
            price: 'Adjust below',
            apply: () => { activePartId = 'pearl'; post('tuningFocusPart', { part: 'overview' }); renderDetailPanel(); },
            isActive: () => activePartId === 'pearl',
        });
        const tint = WINDOW_TINTS.find((t) => t.id === (cosmetics?.windowTint ?? 0))?.label || 'Stock';
        parts.push({
            id: 'window_tint',
            label: 'Window Tint',
            price: tint,
            apply: () => { activePartId = 'tint'; post('tuningFocusPart', { part: 'overview' }); renderDetailPanel(); },
            isActive: () => activePartId === 'tint',
        });
        parts.push({
            id: 'plate_text',
            label: 'Vanity License Plate',
            price: cosmetics?.plateText || 'Stock',
            apply: () => { activePartId = 'plate'; post('tuningFocusPart', { part: 'rearBumper' }); renderDetailPanel(); },
            isActive: () => activePartId === 'plate',
        });
    } else if (activeTab === 'dyno') {
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
    } else if (activeTab === 'special') {
        if (cap('antiLag')) parts.push(...toggleParts('antilag', 'Anti-Lag', 'antiLag.enabled', featureCosts.antiLag));
        if (cap('drift')) parts.push(...toggleParts('drift', 'Drift Mode', 'drift.enabled', featureCosts.drift));
        if (cap('hud')) parts.push(...toggleParts('hud', 'ECU HUD', 'hud.enabled', featureCosts.hud));
    } else if (activeTab === 'handling') {
        parts.push({
            id: 'handling_custom',
            label: 'Fine-Tune Handling',
            price: 'Adjust below',
            apply: () => {},
            isActive: () => true,
        });
    }

    parts.forEach((p) => {
        const item = document.createElement('div');
        item.className = 'list-item';
        if (p.isActive()) item.classList.add('active');
        const instBadge = p.isInstalled ? '<span class="installed-badge">INSTALLED</span>' : '';
        item.innerHTML = `<span class="item-label">${p.label}${instBadge}</span><span class="item-price">${p.price}</span>`;
        item.addEventListener('click', () => {
            p.apply();
            renderPartList();
            renderDetailPanel();
        });
        tunePartsList.appendChild(item);
    });
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

function cosmeticsToggleRow(label, path) {
    const row = document.createElement('div');
    row.className = 'toggle-row';
    const span = document.createElement('span');
    span.textContent = label;
    const sw = document.createElement('label');
    sw.className = 'switch';
    const input = document.createElement('input');
    input.type = 'checkbox';
    const curr = getCosmeticsValue(path);
    input.checked = curr === true || (curr === undefined && path !== 'neon.enabled' && path !== 'tyreSmoke');
    input.addEventListener('change', () => {
        setCosmeticsValue(path, input.checked);
        preview();
        renderPartList();
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

    const paletteGrid = document.createElement('div');
    paletteGrid.className = 'palette-grid';
    PAINT_PRESETS.forEach((preset) => {
        const swatch = document.createElement('div');
        swatch.className = 'palette-swatch';
        swatch.style.background = `rgb(${preset.r},${preset.g},${preset.b})`;
        swatch.title = preset.label;
        swatch.addEventListener('click', () => {
            cosmetics = ensureCosmetics(cosmetics);
            let ref = cosmetics;
            for (let i = 0; i < parts.length - 1; i++) ref = ref[parts[i]];
            ref[parts[parts.length - 1]] = { r: preset.r, g: preset.g, b: preset.b };
            preview();
            renderDetailPanel();
        });
        paletteGrid.appendChild(swatch);
    });
    field.appendChild(paletteGrid);

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

    if (activeTab === 'bodykit') {
        const slotKey = activePartId || 'spoiler';
        const slotInfo = BODYKIT_SLOTS.find((s) => s.key === slotKey) || BODYKIT_SLOTS[0];
        const count = visualAvailability[slotKey] || 0;

        const title = document.createElement('div');
        title.className = 'section-title section-title--compact';
        title.textContent = `${slotInfo.label} Options (${count} available)`;
        tuneDetail.appendChild(title);

        const grid = document.createElement('div');
        grid.className = 'options-grid';

        const curMod = cosmetics?.mods?.[slotKey] ?? -1;

        const stockBtn = document.createElement('button');
        stockBtn.className = `option-btn ${curMod === -1 ? 'active' : ''}`;
        stockBtn.textContent = 'Stock (OEM)';
        stockBtn.addEventListener('click', () => {
            cosmetics = ensureCosmetics(cosmetics);
            cosmetics.mods[slotKey] = -1;
            preview();
            renderPartList();
            renderDetailPanel();
        });
        grid.appendChild(stockBtn);

        for (let i = 0; i < count; i++) {
            const btn = document.createElement('button');
            btn.className = `option-btn ${curMod === i ? 'active' : ''}`;
            btn.textContent = `Option #${i + 1}`;
            btn.addEventListener('click', () => {
                cosmetics = ensureCosmetics(cosmetics);
                cosmetics.mods[slotKey] = i;
                preview();
                renderPartList();
                renderDetailPanel();
            });
            grid.appendChild(btn);
        }
        tuneDetail.appendChild(grid);
    }

    if (activeTab === 'lighting') {
        if (!activePartId || activePartId === 'neon') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Neon Underglow Controls';
            tuneDetail.appendChild(title);

            tuneDetail.appendChild(cosmeticsToggleRow('Enable Underglow', 'neon.enabled'));
            tuneDetail.appendChild(cosmeticsToggleRow('Front Tube', 'neon.front'));
            tuneDetail.appendChild(cosmeticsToggleRow('Rear Tube', 'neon.back'));
            tuneDetail.appendChild(cosmeticsToggleRow('Left Side Tube', 'neon.left'));
            tuneDetail.appendChild(cosmeticsToggleRow('Right Side Tube', 'neon.right'));

            const lbl = document.createElement('label');
            lbl.style.marginTop = '12px';
            lbl.textContent = 'NEON COLOR PRESETS';
            tuneDetail.appendChild(lbl);

            const paletteGrid = document.createElement('div');
            paletteGrid.className = 'palette-grid';
            NEON_PRESETS.forEach((preset) => {
                const swatch = document.createElement('div');
                swatch.className = 'palette-swatch';
                swatch.style.background = `rgb(${preset.r},${preset.g},${preset.b})`;
                swatch.title = preset.label;
                swatch.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.neon.enabled = true;
                    cosmetics.neon.color = { r: preset.r, g: preset.g, b: preset.b };
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                paletteGrid.appendChild(swatch);
            });
            tuneDetail.appendChild(paletteGrid);

            ['r', 'g', 'b'].forEach((ch) => {
                const row = document.createElement('div');
                row.className = 'color-row';
                row.innerHTML = `<span>${ch.toUpperCase()}</span>`;
                const input = document.createElement('input');
                input.type = 'range';
                input.min = 0;
                input.max = 255;
                input.value = cosmetics?.neon?.color?.[ch] || 0;
                input.addEventListener('input', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.neon.enabled = true;
                    cosmetics.neon.color[ch] = Number(input.value);
                    preview();
                });
                row.appendChild(input);
                tuneDetail.appendChild(row);
            });
        } else if (activePartId === 'xenon') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Xenon Headlight System';
            tuneDetail.appendChild(title);

            tuneDetail.appendChild(cosmeticsToggleRow('Xenon Headlights', 'xenon'));

            const lbl = document.createElement('label');
            lbl.style.marginTop = '12px';
            lbl.textContent = 'XENON COLOR TEMPERATURE';
            tuneDetail.appendChild(lbl);

            const grid = document.createElement('div');
            grid.className = 'options-grid';
            XENON_COLORS.forEach((xc) => {
                const btn = document.createElement('button');
                btn.className = `option-btn ${cosmetics.xenonColor === xc.id ? 'active' : ''}`;
                btn.innerHTML = `<span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:${xc.color};margin-right:6px"></span>${xc.label}`;
                btn.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.xenon = true;
                    cosmetics.xenonColor = xc.id;
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                grid.appendChild(btn);
            });
            tuneDetail.appendChild(grid);
        }
    }

    if (activeTab === 'wheels') {
        if (!activePartId || activePartId === 'wheel_type') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Select Wheel Category';
            tuneDetail.appendChild(title);

            const grid = document.createElement('div');
            grid.className = 'options-grid';
            WHEEL_TYPES.forEach((wt) => {
                const btn = document.createElement('button');
                btn.className = `option-btn ${cosmetics.wheelType === wt.id ? 'active' : ''}`;
                btn.textContent = wt.label;
                btn.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.wheelType = wt.id;
                    cosmetics.mods.wheels = -1;
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                grid.appendChild(btn);
            });
            tuneDetail.appendChild(grid);
        } else if (activePartId === 'wheel_rim') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Rim Models (Current Category)';
            tuneDetail.appendChild(title);

            const count = visualAvailability.wheels || 0;
            const grid = document.createElement('div');
            grid.className = 'options-grid';

            const curMod = cosmetics?.mods?.wheels ?? -1;
            const stockBtn = document.createElement('button');
            stockBtn.className = `option-btn ${curMod === -1 ? 'active' : ''}`;
            stockBtn.textContent = 'Stock OEM Rims';
            stockBtn.addEventListener('click', () => {
                cosmetics = ensureCosmetics(cosmetics);
                cosmetics.mods.wheels = -1;
                preview();
                renderPartList();
                renderDetailPanel();
            });
            grid.appendChild(stockBtn);

            for (let i = 0; i < count; i++) {
                const btn = document.createElement('button');
                btn.className = `option-btn ${curMod === i ? 'active' : ''}`;
                btn.textContent = `Rim #${i + 1}`;
                btn.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.mods.wheels = i;
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                grid.appendChild(btn);
            }
            tuneDetail.appendChild(grid);
        } else if (activePartId === 'wheel_color') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Rim Paint Color Index';
            tuneDetail.appendChild(title);

            const field = document.createElement('div');
            field.className = 'field';
            const lbl = document.createElement('label');
            lbl.innerHTML = `<span>Wheel Paint Index</span><span>${cosmetics.wheel || 0}</span>`;
            const input = document.createElement('input');
            input.type = 'range';
            input.min = 0;
            input.max = 159;
            input.value = cosmetics.wheel || 0;
            input.addEventListener('input', () => {
                cosmetics = ensureCosmetics(cosmetics);
                cosmetics.wheel = Number(input.value);
                lbl.lastElementChild.textContent = String(input.value);
                preview();
            });
            field.appendChild(lbl);
            field.appendChild(input);
            tuneDetail.appendChild(field);
        } else if (activePartId === 'smoke') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Tyre Smoke Burnout Controls';
            tuneDetail.appendChild(title);

            tuneDetail.appendChild(cosmeticsToggleRow('Enable Tyre Smoke', 'tyreSmoke'));

            const lbl = document.createElement('label');
            lbl.style.marginTop = '12px';
            lbl.textContent = 'SMOKE COLOR PRESETS';
            tuneDetail.appendChild(lbl);

            const paletteGrid = document.createElement('div');
            paletteGrid.className = 'palette-grid';
            TYRE_SMOKE_PRESETS.forEach((preset) => {
                const swatch = document.createElement('div');
                swatch.className = 'palette-swatch';
                swatch.style.background = `rgb(${preset.r},${preset.g},${preset.b})`;
                swatch.title = preset.label;
                swatch.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.tyreSmoke = true;
                    cosmetics.tyreSmokeColor = { r: preset.r, g: preset.g, b: preset.b };
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                paletteGrid.appendChild(swatch);
            });
            tuneDetail.appendChild(paletteGrid);

            ['r', 'g', 'b'].forEach((ch) => {
                const row = document.createElement('div');
                row.className = 'color-row';
                row.innerHTML = `<span>${ch.toUpperCase()}</span>`;
                const input = document.createElement('input');
                input.type = 'range';
                input.min = 0;
                input.max = 255;
                input.value = cosmetics?.tyreSmokeColor?.[ch] ?? 255;
                input.addEventListener('input', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.tyreSmoke = true;
                    if (!cosmetics.tyreSmokeColor) cosmetics.tyreSmokeColor = { r: 255, g: 255, b: 255 };
                    cosmetics.tyreSmokeColor[ch] = Number(input.value);
                    preview();
                });
                row.appendChild(input);
                tuneDetail.appendChild(row);
            });
        }
    }

    if (activeTab === 'visual') {
        if (!activePartId || activePartId === 'primary') {
            tuneDetail.appendChild(cosmeticsColorField('Primary Body Paint', 'primary'));
        } else if (activePartId === 'secondary') {
            tuneDetail.appendChild(cosmeticsColorField('Secondary Trim Paint', 'secondary'));
        } else if (activePartId === 'finish') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Paint Finish & Surface Style';
            tuneDetail.appendChild(title);

            const grid = document.createElement('div');
            grid.className = 'options-grid';
            PAINT_TYPES.forEach((pt) => {
                const btn = document.createElement('button');
                btn.className = `option-btn ${(cosmetics.paintType ?? 0) === pt.id ? 'active' : ''}`;
                btn.textContent = pt.label;
                btn.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.paintType = pt.id;
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                grid.appendChild(btn);
            });
            tuneDetail.appendChild(grid);
        } else if (activePartId === 'pearl') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Pearlescent Clearcoat Finish';
            tuneDetail.appendChild(title);

            const field = document.createElement('div');
            field.className = 'field';
            const lbl = document.createElement('label');
            lbl.innerHTML = `<span>Pearlescent Index</span><span>${cosmetics.pearl || 0}</span>`;
            const input = document.createElement('input');
            input.type = 'range';
            input.min = 0;
            input.max = 159;
            input.value = cosmetics.pearl || 0;
            input.addEventListener('input', () => {
                cosmetics = ensureCosmetics(cosmetics);
                cosmetics.pearl = Number(input.value);
                lbl.lastElementChild.textContent = String(input.value);
                preview();
            });
            field.appendChild(lbl);
            field.appendChild(input);
            tuneDetail.appendChild(field);
        } else if (activePartId === 'tint') {
            const title = document.createElement('div');
            title.className = 'section-title section-title--compact';
            title.textContent = 'Window Tint Level';
            tuneDetail.appendChild(title);

            const grid = document.createElement('div');
            grid.className = 'options-grid';
            WINDOW_TINTS.forEach((wt) => {
                const btn = document.createElement('button');
                btn.className = `option-btn ${cosmetics.windowTint === wt.id ? 'active' : ''}`;
                btn.textContent = wt.label;
                btn.addEventListener('click', () => {
                    cosmetics = ensureCosmetics(cosmetics);
                    cosmetics.windowTint = wt.id;
                    preview();
                    renderPartList();
                    renderDetailPanel();
                });
                grid.appendChild(btn);
            });
            tuneDetail.appendChild(grid);
        } else if (activePartId === 'plate') {
            const plateField = document.createElement('div');
            plateField.className = 'field';
            plateField.innerHTML = '<label><span>Custom Vanity License Plate (max 8)</span></label>';
            const plateInput = document.createElement('input');
            plateInput.type = 'text';
            plateInput.maxLength = 8;
            plateInput.value = (cosmetics && cosmetics.plateText) || '';
            plateInput.addEventListener('input', () => {
                cosmetics = ensureCosmetics(cosmetics);
                cosmetics.plateText = plateInput.value.replace(/\\s+/g, '').toUpperCase();
                preview();
                renderPartList();
            });
            plateField.appendChild(plateInput);
            tuneDetail.appendChild(plateField);
        }
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
        btn.className = 'cat-item';
        if (cat.id === activeTab) btn.classList.add('active');
        btn.innerHTML = `<i class="${cat.icon}"></i> <span>${cat.label}</span>`;
        btn.addEventListener('click', () => {
            activeTab = cat.id;
            activePartId = null;
            post('tuningFocusPart', { part: cat.id });
            if (tunePartsTitle) tunePartsTitle.textContent = categoryTitles[cat.id] || cat.label;
            renderCategories();
            renderPartList();
            renderDetailPanel();
        });
        tuneCategories.appendChild(btn);
    });
}

function renderAll() {
    if (tunePartsTitle) tunePartsTitle.textContent = categoryTitles[activeTab] || 'Upgrades';
    updateStatusBanner();
    renderCategories();
    renderPartList();
    renderDetailPanel();
    renderStatsPanel();
    updateInstallButton();
}

if (btnCancel) btnCancel.addEventListener('click', () => post('tuningClose'));
if (btnSave) btnSave.addEventListener('click', () => post('tuningSave', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics), flash: false }));

let isDraggingCam = false;
let lastMouseX = 0;
let lastMouseY = 0;

document.addEventListener('mousedown', (e) => {
    if (!app || app.classList.contains('hidden')) return;
    if (e.target.closest('.tuning-wrapper') || e.target.closest('.stats-panel')) return;
    isDraggingCam = true;
    lastMouseX = e.clientX;
    lastMouseY = e.clientY;
});

document.addEventListener('mousemove', (e) => {
    if (!isDraggingCam) return;
    const deltaX = e.clientX - lastMouseX;
    const deltaY = e.clientY - lastMouseY;
    lastMouseX = e.clientX;
    lastMouseY = e.clientY;
    if (Math.abs(deltaX) > 0 || Math.abs(deltaY) > 0) {
        post('tuningCamRotate', { deltaX: deltaX * 1.5, deltaY: deltaY * 1.5 });
    }
});

document.addEventListener('mouseup', () => {
    isDraggingCam = false;
});

document.addEventListener('keydown', (e) => {
    if (!app || app.classList.contains('hidden')) return;
    if (e.key === 'Escape') {
        e.preventDefault();
        post('tuningClose');
        return;
    }

    const tag = (e.target && e.target.tagName) || '';
    if (tag === 'INPUT' || tag === 'TEXTAREA') return;

    if (e.key === 'Enter' && !e.repeat) {
        e.preventDefault();
        post('tuningSave', { tune: ensureTune(tune), cosmetics: ensureCosmetics(cosmetics), flash: false });
        return;
    }

    if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') {
        post('tuningCamRotate', { deltaX: -20, deltaY: 0 });
    } else if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') {
        post('tuningCamRotate', { deltaX: 20, deltaY: 0 });
    } else if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') {
        post('tuningCamRotate', { deltaX: 0, deltaY: -15 });
    } else if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
        post('tuningCamRotate', { deltaX: 0, deltaY: 15 });
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
        hardwareAvailability = data.hardwareAvailability || data.hardware || {};
        visualAvailability = data.visualAvailability || data.visual || {};
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
    if (action === 'playSound' || event.data?.transactionType === 'playSound') {
        const soundFile = (data?.sound || event.data?.transactionFile || '1') + '.ogg';
        const volume = Math.max(0.01, Math.min(1.0, data?.volume ?? event.data?.transactionVolume ?? 0.8));
        try {
            const audio = new Audio('sounds/' + soundFile);
            audio.volume = volume;
            audio.play().catch(() => {});
        } catch (e) {}
    }
});
