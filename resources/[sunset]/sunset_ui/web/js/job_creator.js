/**
 * Job Creator — editor ghidat (putere completă, zero coding).
 * Variabile, branch, pool-uri: totul prin liste predefinite + opțiune custom.
 */

const STAGE_META = {
    goto_zone: { icon: '📍', cat: 'lume', label: 'Du-te la loc', hint: 'Jucătorul primește GPS + marker la destinație.' },
    zone_interact: { icon: '👆', cat: 'interact', label: 'Apasă E în zonă', hint: 'Stă în cerc și apasă E (încarcă, livrează, colectează).' },
    talk_to_npc: { icon: '💬', cat: 'interact', label: 'Vorbește cu NPC', hint: 'Interacțiune cu un personaj spawnat anterior.' },
    pick_random: { icon: '🎲', cat: 'logica', label: 'Alege destinație random', hint: 'Ia un punct din o listă (pool) — ideal pentru livrări.' },
    branch: { icon: '🔀', cat: 'logica', label: 'Condiție (dacă / altfel)', hint: 'Ex: dacă done < total, repetă; altfel termină.' },
    set_variable: { icon: '🔢', cat: 'logica', label: 'Setează variabilă', hint: 'Schimbă o valoare internă (contoare, flag-uri).' },
    scale_from_level: { icon: '📈', cat: 'logica', label: 'Număr sarcini după level', hint: 'Câte livrări/task-uri: mai mult la level mare.' },
    wait: { icon: '⏱️', cat: 'gameplay', label: 'Așteaptă', hint: 'Pauză în secunde înainte de pasul următor.' },
    progress: { icon: '⏳', cat: 'gameplay', label: 'Bară de progres', hint: 'Animație de încărcare (E sau automat în zonă).' },
    skill_check: { icon: '🎯', cat: 'gameplay', label: 'Test de reflex', hint: 'Apasă E în fereastra de timp.' },
    spawn_vehicle: { icon: '🚗', cat: 'vehicul', label: 'Spawn vehicul', hint: 'Apare mașina jobului la un loc setat.' },
    delete_vehicle: { icon: '🗑️', cat: 'vehicul', label: 'Șterge vehicul', hint: 'Elimină vehiculul salvat în variabilă.' },
    attach_trailer: { icon: '🔗', cat: 'vehicul', label: 'Atașează remorcă', hint: 'Pune remorca la camion.' },
    enter_vehicle: { icon: '🪑', cat: 'vehicul', label: 'Intră în vehicul', hint: 'Jucătorul trebuie să fie în mașină.' },
    require_vehicle: { icon: '🔒', cat: 'vehicul', label: 'Trebuie în vehicul', hint: 'Verifică că e în vehiculul jobului.' },
    return_vehicle: { icon: '🏁', cat: 'vehicul', label: 'Înapoi cu vehiculul', hint: 'Adu mașina la depozit / punct de return.' },
    spawn_npc: { icon: '🧑', cat: 'lume', label: 'Spawn NPC', hint: 'Apare un personaj la un loc.' },
    spawn_prop: { icon: '🌲', cat: 'lume', label: 'Spawn obiect (copac)', hint: 'Apare un copac/obiect la locul marcat — vizibil în joc.' },
    chop_prop: { icon: '🪓', cat: 'gameplay', label: 'Taie / lovește obiect', hint: 'Topor în mână + animație chop. Șterge obiectul după.' },
    remove_npc: { icon: '👋', cat: 'lume', label: 'Elimină NPC', hint: 'Șterge NPC-ul din variabilă.' },
    require_item: { icon: '📦', cat: 'item', label: 'Necesită obiect', hint: 'Verifică că are itemul în inventar.' },
    give_item: { icon: '🎁', cat: 'item', label: 'Dă obiect', hint: 'Adaugă item în inventar.' },
    remove_item: { icon: '➖', cat: 'item', label: 'Ia obiect', hint: 'Scoate item din inventar.' },
    party_gate: { icon: '👥', cat: 'echipa', label: 'Verifică echipă', hint: 'Câți jucători trebuie lângă tine.' },
    give_reward: { icon: '💰', cat: 'final', label: 'Plată + XP', hint: 'Dă bani și experiență (sau folosește pay din progresie).' },
    complete: { icon: '✅', cat: 'final', label: 'Termină jobul', hint: 'Shift reușit — jucătorul a terminat.' },
    fail: { icon: '❌', cat: 'final', label: 'Eșuează jobul', hint: 'Shift picat (timeout, regulă încălcată).' },
};

const CAT_LABEL = {
    lume: 'Lume & locuri', interact: 'Interacțiuni', logica: 'Logică & variabile',
    gameplay: 'Gameplay', vehicul: 'Vehicule', item: 'Obiecte', echipa: 'Echipă', final: 'Final',
};

const COMMON_VARS = [
    { id: 'done', label: 'done — câte ai terminat' },
    { id: 'total', label: 'total — câte trebuie total' },
    { id: 'target', label: 'target — destinația curentă' },
    { id: 'leg', label: 'leg — etapa / runda curentă' },
    { id: 'caught', label: 'caught — prins / colectat' },
    { id: 'logs', label: 'logs — lemne tăiate' },
    { id: 'truck', label: 'truck — vehiculul jobului' },
    { id: 'trailer', label: 'trailer — remorca' },
    { id: 'npc', label: 'npc — personaj spawnat' },
];

const VEHICLE_PRESETS = [
    { id: 'phantom', label: 'Camion Phantom' }, { id: 'hauler', label: 'Hauler' },
    { id: 'packer', label: 'Packer' }, { id: 'trash', label: 'Gunoi (trash)' },
    { id: 'burrito3', label: 'Dubă Burrito' }, { id: 'boxville2', label: 'Dubă curier' },
    { id: 'mule', label: 'Mule' }, { id: 'rebel', label: 'Rebel pickup' },
];

const TRAILER_PRESETS = [
    { id: 'trailers2', label: 'Remorcă standard' }, { id: 'trailerlogs', label: 'Remorcă lemne' },
    { id: 'tanker', label: 'Cisternă' }, { id: 'trailers', label: 'Remorcă mică' },
];

const NPC_PRESETS = [
    { id: 's_m_m_dockwork_01', label: 'Muncitor doc' }, { id: 's_m_y_construct_01', label: 'Constructor' },
    { id: 's_m_m_trucker_01', label: 'Trucker' }, { id: 'a_m_m_farmer_01', label: 'Fermier' },
];

const ITEM_PRESETS = [
    { id: 'fish', label: 'Pește' }, { id: 'package', label: 'Colet' },
    { id: 'wood', label: 'Lemn' }, { id: 'ore', label: 'Minereu' },
];

const BRANCH_OPS = [
    { v: '<', label: 'mai mic decât' }, { v: '<=', label: 'mai mic sau egal' },
    { v: '>', label: 'mai mare decât' }, { v: '>=', label: 'mai mare sau egal' },
    { v: '==', label: 'egal cu' },
];

const PROP_PRESETS = [
    { id: 'prop_tree_pine_02', label: 'Pin mare' },
    { id: 'prop_tree_pine_01', label: 'Pin mic' },
    { id: 'prop_logpile_06', label: 'Grămadă lemne' },
    { id: 'prop_rock_4_c', label: 'Rocă (miner)' },
];

const JOB_ICON_PRESETS = [
    { id: 'truck', label: 'Camion' },
    { id: 'fish', label: 'Pescuit' },
    { id: 'axe', label: 'Topor' },
    { id: 'package', label: 'Colet' },
    { id: 'trash', label: 'Gunoi' },
    { id: 'pickaxe', label: 'Târnăcop' },
    { id: 'hardhat', label: 'Șantier' },
    { id: 'box', label: 'Cutie' },
    { id: 'wheat', label: 'Fermă' },
    { id: 'tree', label: 'Copac' },
    { id: 'briefcase', label: 'Job' },
    { id: 'car', label: 'Mașină' },
    { id: 'wrench', label: 'Service' },
];

const JobCreator = {
    _jobs: [], _selectedId: null, _draft: null, _tab: 'general',
    _selectedStageIdx: 0, _dragFromIdx: null, _inited: false,
    _autoFlow: false, _placeMode: 'location', _placePool: 'deliveries',
    _modules: null, _moduleCategories: {},

    init() {
        if (this._inited) return;
        this._inited = true;
        this._panel = document.getElementById('job-creator-panel');
        document.getElementById('jc-close')?.addEventListener('click', () => this.close());
        document.getElementById('jc-new')?.addEventListener('click', () => this.newJob());
        document.getElementById('jc-sidebar-seed')?.addEventListener('click', () => this.seedTemplates());
        document.getElementById('jc-save')?.addEventListener('click', () => this.save());
        document.getElementById('jc-publish')?.addEventListener('click', () => this.publish());
        document.getElementById('jc-test')?.addEventListener('click', () => this.test());
        document.getElementById('jc-place')?.addEventListener('click', () => this.place());
        document.getElementById('jc-delete')?.addEventListener('click', () => this.delete());
        document.getElementById('jc-export')?.addEventListener('click', () => this.exportJob());
        document.getElementById('jc-import-toggle')?.addEventListener('click', () => {
            document.getElementById('jc-import-box')?.classList.toggle('hidden');
        });
        document.getElementById('jc-import')?.addEventListener('click', () => this.importJob());
        this._panel?.querySelectorAll('.jc-tab').forEach((btn) => {
            btn.addEventListener('click', () => {
                if (this._draft) this._collectDraft();
                this._tab = btn.dataset.tab || 'general';
                this._panel.querySelectorAll('.jc-tab').forEach((b) => b.classList.toggle('active', b === btn));
                this.renderEditor();
            });
        });
    },

    async _post(action, body = {}) {
        const res = await fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });
        return res.json();
    },

    async _loadModules() {
        if (this._modules) return;
        const res = await this._post('jobCreatorModules', {});
        if (res.ok) {
            this._modules = res.modules || [];
            this._moduleCategories = res.categories || {};
        } else {
            this._modules = [];
            this._moduleCategories = {};
        }
    },

    _insertModule(mod) {
        if (!this._draft || !mod) return;
        this._collectStagesFromDom();
        const def = this._def();
        const suffix = `_${Date.now().toString(36).slice(-4)}`;
        const stages = def.stages || [];
        const existingIds = new Set(stages.map((s) => s.id));
        const idMap = {};
        (mod.stages || []).forEach((s) => {
            let newId = s.id;
            if (existingIds.has(newId)) newId = `${s.id}${suffix}`;
            idMap[s.id] = newId;
            existingIds.add(newId);
        });
        const remap = (target) => {
            if (!target) return undefined;
            if (target === 'next') return undefined;
            if (target === 'complete' || target === 'fail') return target;
            return idMap[target] || target;
        };
        const newStages = (mod.stages || []).map((s) => {
            const copy = JSON.parse(JSON.stringify(s));
            copy.id = idMap[s.id];
            ['onSuccess', 'onFailure'].forEach((k) => {
                if (copy[k]) {
                    const r = remap(copy[k]);
                    if (r) copy[k] = r; else delete copy[k];
                }
            });
            if (copy.ifTrue) copy.ifTrue = remap(copy.ifTrue) || copy.ifTrue;
            if (copy.ifFalse) copy.ifFalse = remap(copy.ifFalse) || copy.ifFalse;
            return copy;
        });
        if (mod.variables) {
            def.variables = def.variables || {};
            Object.entries(mod.variables).forEach(([k, v]) => {
                if (def.variables[k] === undefined) def.variables[k] = v;
            });
        }
        if (mod.locations) {
            def.locations = def.locations || {};
            Object.entries(mod.locations).forEach(([k, v]) => {
                if (!def.locations[k]) def.locations[k] = JSON.parse(JSON.stringify(v));
            });
        }
        if (mod.pools) {
            def.pools = def.pools || {};
            Object.entries(mod.pools).forEach(([k, v]) => {
                if (!def.pools[k] || !def.pools[k].length) def.pools[k] = JSON.parse(JSON.stringify(v));
            });
        }
        const prevLast = stages[stages.length - 1];
        const firstNew = newStages[0];
        if (prevLast && firstNew && !['complete', 'fail', 'branch'].includes(prevLast.type)) {
            if (!prevLast.onSuccess || prevLast.onSuccess === 'next') prevLast.onSuccess = firstNew.id;
        }
        def.stages = [...stages, ...newStages];
        this._selectedStageIdx = Math.max(0, def.stages.length - newStages.length);
        this.renderEditor();
        this.setStatus(`✅ Modul „${mod.label}” — ${newStages.length} pași. Verifică locurile/pool-urile în tab Locuri.`);
    },

    _showModulePicker() {
        const picker = document.getElementById('jc-module-picker');
        if (!picker) return;
        picker.classList.remove('hidden');
        const cats = this._moduleCategories || {};
        const byCat = {};
        (this._modules || []).forEach((m) => {
            const c = m.category || 'gameplay';
            if (!byCat[c]) byCat[c] = [];
            byCat[c].push(m);
        });
        let grid = '';
        Object.entries(byCat).forEach(([cat, items]) => {
            grid += `<div class="jc-picker-cat"><h4>${this._esc(cats[cat] || cat)}</h4><div class="jc-picker-grid">`;
            grid += items.map((m) =>
                `<button type="button" class="jc-module-item" data-mod="${this._esc(m.id)}" title="${this._esc(m.hint || m.description)}">
                    <span class="jc-picker-icon">${m.icon || '🧩'}</span>
                    <span class="jc-module-label">${this._esc(m.label)}</span>
                    <small>${this._esc(m.description || '')}</small>
                </button>`
            ).join('');
            grid += '</div></div>';
        });
        picker.innerHTML = `<div class="jc-picker-head"><strong>Inserează modul Lego (bloc gata făcut):</strong>
            <button type="button" class="jc-close-picker">✕</button></div>
            <p class="jc-hint">Modulele adaugă pași + variabile + locuri/pool-uri. Leagă-le în ordine sau cu „🔗 Leagă pașii”.</p>${grid}`;
        picker.querySelector('.jc-close-picker')?.addEventListener('click', () => picker.classList.add('hidden'));
        picker.querySelectorAll('.jc-module-item').forEach((btn) => {
            btn.addEventListener('click', () => {
                const mod = (this._modules || []).find((m) => m.id === btn.dataset.mod);
                if (mod) this._insertModule(mod);
                picker.classList.add('hidden');
            });
        });
    },

    async show(data = {}) {
        this.init();
        await this._loadModules();
        const resumeDraft = this._draft;
        const resumeId = this._selectedId;
        this._jobs = data.jobs || [];

        if (!this._jobs.length) {
            await this.seedTemplates();
            if (!this._jobs.length) {
                this._panel?.classList.remove('hidden');
                this._draft = null;
                this.renderList();
                this.renderEditor();
                return;
            }
        }

        this._panel?.classList.remove('hidden');

        if (resumeDraft && resumeId) {
            this._selectedId = resumeId;
            this.renderList();
            this.renderWizard();
            this.renderEditor();
            return;
        }

        const preferred = this._jobs.find((j) => j.id === 'jc_tpl_route')
            || this._jobs.find((j) => j.id === 'jc_tpl_courier')
            || this._jobs[0];
        this._selectedId = preferred?.id || null;
        this.renderList();
        if (this._selectedId) await this.loadSelected();
        else { this._draft = null; this.renderEditor(); }
    },

    _jobProgress() {
        if (!this._draft) return { name: false, locs: false, stages: false, published: false };
        const def = this._def();
        return {
            name: !!(this._draft.label && this._draft.label !== 'Jobul meu'),
            locs: Object.keys(def.locations || {}).length > 0 || Object.values(def.pools || {}).some((p) => p.length > 0),
            stages: (def.stages || []).length > 1,
            published: this._draft.status === 'published',
        };
    },

    renderWizard() {
        const el = document.getElementById('jc-wizard');
        const chk = document.getElementById('jc-checklist');
        if (!this._draft) {
            if (el) el.innerHTML = '';
            if (chk) chk.innerHTML = '';
            return;
        }
        const p = this._jobProgress();
        const steps = [
            { key: 'name', label: '1. Nume', done: p.name, tab: 'general' },
            { key: 'locs', label: '2. Locuri', done: p.locs, tab: 'locations' },
            { key: 'stages', label: '3. Pași', done: p.stages, tab: 'stages' },
            { key: 'pub', label: '4. Publică', done: p.published, tab: 'general' },
        ];
        if (el) {
            el.innerHTML = `<div class="jc-wizard-track">${steps.map((s) =>
                `<button type="button" class="jc-wizard-step ${s.done ? 'done' : ''} ${this._tab === s.tab ? 'current' : ''}" data-tab="${s.tab}">
                    <span class="jc-wizard-dot">${s.done ? '✓' : '○'}</span>${s.label}</button>`
            ).join('<span class="jc-wizard-arrow">→</span>')}</div>`;
            el.querySelectorAll('.jc-wizard-step').forEach((btn) => {
                btn.addEventListener('click', () => {
                    if (this._draft) this._collectDraft();
                    this._tab = btn.dataset.tab;
                    this._panel?.querySelectorAll('.jc-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === this._tab));
                    this.renderWizard();
                    this.renderEditor();
                });
            });
        }
        if (chk) {
            chk.innerHTML = `<div class="jc-checklist-title">Progres job</div>${steps.map((s) =>
                `<div class="jc-check-item ${s.done ? 'done' : ''}">${s.done ? '✓' : '○'} ${s.label.replace(/^\d+\.\s/, '')}</div>`
            ).join('')}`;
        }
    },

    _flowStripHtml() {
        const stages = this._stages();
        if (stages.length < 2) return '';
        return `<div class="jc-flow-strip">${stages.map((s, i) => {
            const m = this._meta(s.type);
            const arrow = i < stages.length - 1 ? '<span class="jc-flow-arrow">→</span>' : '';
            const active = i === this._selectedStageIdx ? ' active' : '';
            const next = s.onSuccess && s.type === 'branch'
                ? `? ${s.ifTrue || '?'}` : (s.onSuccess ? `→ ${s.onSuccess}` : '');
            return `<span class="jc-flow-chip${active}" data-idx="${i}" title="${s.id}">${m.icon} ${this._esc(s.label || m.label)}<small>${next}</small></span>${arrow}`;
        }).join('')}</div>`;
    },

    _variablesEditorHtml(vars) {
        const rows = Object.entries(vars || { done: 0, total: 3 }).map(([k, v]) =>
            `<div class="jc-var-row">
                <input class="jc-var-key" value="${this._esc(k)}" placeholder="nume" />
                <input class="jc-var-val" type="number" value="${Number(v) || 0}" />
                <button type="button" class="jc-var-del" title="Șterge">×</button>
            </div>`
        ).join('');
        return `<div class="jc-vars-block">
            <label>Contoare / variabile (pentru repetări și condiții)</label>
            <div id="jc-vars-list">${rows}</div>
            <button type="button" class="jc-btn ghost" id="jc-var-add">+ Adaugă variabilă</button>
            <small class="jc-hint">Folosite la „Condiție dacă/altfel” și la +1 done după livrare.</small>
        </div>`;
    },

    _bindVariablesEditor(mount) {
        mount.querySelector('#jc-var-add')?.addEventListener('click', () => {
            const list = mount.querySelector('#jc-vars-list');
            if (!list) return;
            const row = document.createElement('div');
            row.className = 'jc-var-row';
            row.innerHTML = '<input class="jc-var-key" placeholder="nume" /><input class="jc-var-val" type="number" value="0" /><button type="button" class="jc-var-del">×</button>';
            list.appendChild(row);
            row.querySelector('.jc-var-del')?.addEventListener('click', () => row.remove());
        });
        mount.querySelectorAll('.jc-var-del').forEach((btn) => {
            btn.addEventListener('click', () => btn.closest('.jc-var-row')?.remove());
        });
    },

    _readVariablesFromDom() {
        const out = {};
        document.querySelectorAll('#jc-vars-list .jc-var-row').forEach((row) => {
            const k = row.querySelector('.jc-var-key')?.value?.trim();
            const v = row.querySelector('.jc-var-val')?.value;
            if (k) out[k] = Number(v) || 0;
        });
        return out;
    },
    update(data = {}) {
        this._jobs = data.jobs || this._jobs;
        this.renderList();
        this.renderWizard();
    },
    hide() { this._panel?.classList.add('hidden'); },
    close() { this._post('jobCreatorClose'); },

    _stages() { return this._draft?.definition?.stages || []; },
    _stage() { return this._stages()[this._selectedStageIdx] || null; },
    _def() { return this._draft?.definition || {}; },
    _locations() { return this._def().locations || {}; },
    _pools() { return this._def().pools || {}; },
    _esc(s) { return String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;'); },

    _meta(type) { return STAGE_META[type] || { icon: '▸', cat: 'logica', label: type, hint: '' }; },

    _resolveJobIcon(d, def) {
        const cur = String(d.icon || def.ui?.icon || 'briefcase').trim();
        if (window.JobIcons && JobIcons.isEmoji(cur)) return { preset: '', custom: cur };
        const known = JOB_ICON_PRESETS.some((p) => p.id === cur);
        return { preset: known ? cur : 'briefcase', custom: '' };
    },

    _iconPickerHtml(d, def) {
        const { preset, custom } = this._resolveJobIcon(d, def);
        const opts = JOB_ICON_PRESETS.map((p) =>
            `<option value="${p.id}" ${p.id === preset ? 'selected' : ''}>${p.label}</option>`
        ).join('');
        return `
            <div class="jc-field-row jc-icon-row">
                <div class="jc-field">
                    <label>Iconă HUD (în joc)</label>
                    <select id="jc-f-icon">${opts}</select>
                </div>
                <div class="jc-field">
                    <label>Sau emoji (ex: 🪓 🚚)</label>
                    <input id="jc-f-icon-custom" maxlength="4" value="${this._esc(custom)}" placeholder="🪓" />
                </div>
                <div class="jc-icon-preview-wrap">
                    <label>Preview</label>
                    <div class="jc-icon-preview" id="jc-f-icon-preview"></div>
                </div>
            </div>
            <p class="jc-hint">Iconița apare în panoul de job (jos-centru). Poți folosi preset sau un emoji.</p>`;
    },

    _bindIconPicker(mount) {
        const updatePreview = () => {
            const slot = mount.querySelector('#jc-f-icon-preview');
            if (!slot || !window.JobIcons) return;
            const custom = mount.querySelector('#jc-f-icon-custom')?.value?.trim();
            const preset = mount.querySelector('#jc-f-icon')?.value || 'briefcase';
            JobIcons.apply(slot, custom || preset);
        };
        mount.querySelector('#jc-f-icon')?.addEventListener('change', updatePreview);
        mount.querySelector('#jc-f-icon-custom')?.addEventListener('input', updatePreview);
        updatePreview();
    },

    /** Toate variabilele folosite în job + preset-uri comune. */
    _allVarNames() {
        const set = new Set(COMMON_VARS.map((v) => v.id));
        const vars = this._def().variables || {};
        Object.keys(vars).forEach((k) => set.add(k));
        this._stages().forEach((st) => {
            if (st.var) set.add(st.var);
            if (st.resetVar) set.add(st.resetVar);
            if (st.storeAs) set.add(st.storeAs);
            if (st.vehicleVar) set.add(st.vehicleVar);
            if (st.npcVar) set.add(st.npcVar);
            if (st.locationVar) set.add(st.locationVar);
            if (st.condition?.var) set.add(st.condition.var);
            if (st.condition?.valueRef) set.add(st.condition.valueRef);
        });
        return [...set].sort();
    },

    _varSelect(id, value, extra = '') {
        const names = this._allVarNames();
        const known = new Set(names);
        let opts = COMMON_VARS.filter((v) => names.includes(v.id) || !value)
            .map((v) => `<option value="${v.id}" ${v.id === value ? 'selected' : ''}>${v.label}</option>`);
        names.filter((n) => !COMMON_VARS.some((c) => c.id === n)).forEach((n) => {
            opts.push(`<option value="${this._esc(n)}" ${n === value ? 'selected' : ''}>${this._esc(n)}</option>`);
        });
        if (value && !known.has(value)) {
            opts.push(`<option value="${this._esc(value)}" selected>${this._esc(value)} (custom)</option>`);
        }
        opts.push(`<option value="__new__">+ Variabilă nouă...</option>`);
        return `
            <div class="jc-field">
                <label>${extra || 'Variabilă'}</label>
                <select id="${id}">${opts.join('')}</select>
                <input type="text" id="${id}-custom" class="hidden" placeholder="Nume variabilă (ex: done, target)" style="margin-top:4px">
            </div>`;
    },

    _stageSelect(id, value, label, allowEnd = true) {
        const stages = this._stages();
        let opts = stages.map((s) =>
            `<option value="${this._esc(s.id)}" ${s.id === value ? 'selected' : ''}>${this._esc(s.label || s.id)} (${s.id})</option>`
        );
        if (allowEnd) {
            opts += `<option value="complete" ${value === 'complete' ? 'selected' : ''}>✅ Termină jobul</option>`;
            opts += `<option value="fail" ${value === 'fail' ? 'selected' : ''}>❌ Eșuează jobul</option>`;
        }
        opts += `<option value="__custom__" ${value && !stages.some((s) => s.id === value) && value !== 'complete' && value !== 'fail' ? 'selected' : ''}>Alt pas (ID manual)...</option>`;
        const customVal = value && !stages.some((s) => s.id === value) && value !== 'complete' && value !== 'fail' ? value : '';
        return `
            <div class="jc-field"><label>${label}</label>
                <select id="${id}">${opts}</select>
                <input id="${id}-custom" class="jc-custom-input ${customVal ? '' : 'hidden'}" value="${this._esc(customVal)}" placeholder="ID pas, ex: to_hub" />
            </div>`;
    },

    _locationModeSelect(st) {
        const mode = st.locationVar ? 'var' : (st.locationField ? 'field' : 'fixed');
        const keys = Object.keys(this._locations());
        const poolKeys = Object.keys(this._pools());
        return `
            <div class="jc-field"><label>📍 Unde se întâmplă?</label>
                <select id="jc-s-loc-mode">
                    <option value="fixed" ${mode === 'fixed' ? 'selected' : ''}>Loc fix din tab Locuri</option>
                    <option value="var" ${mode === 'var' ? 'selected' : ''}>Unde spune variabila (ex: target)</option>
                    <option value="field" ${mode === 'field' ? 'selected' : ''}>Câmp din variabilă (pickup/delivery)</option>
                </select>
            </div>
            <div class="jc-field jc-loc-fixed ${mode !== 'fixed' ? 'hidden' : ''}">
                <label>Loc</label>
                <select id="jc-s-location">${keys.length ? keys.map((k) => {
                    const loc = this._locations()[k];
                    return `<option value="${this._esc(k)}" ${k === st.location ? 'selected' : ''}>${this._esc(loc?.label || k)}</option>`;
                }).join('') : '<option value="">— adaugă locuri în tab Locuri —</option>'}</select>
            </div>
            <div class="jc-field jc-loc-var ${mode !== 'var' ? 'hidden' : ''}">
                ${this._varSelect('jc-s-locationVar', st.locationVar, 'Variabilă cu coordonate')}
            </div>
            <div class="jc-field jc-loc-field ${mode !== 'field' ? 'hidden' : ''}">
                <label>Câmp coordonate</label>
                <select id="jc-s-locationField">
                    <option value="pickup" ${st.locationField === 'pickup' ? 'selected' : ''}>pickup — ridicare</option>
                    <option value="delivery" ${st.locationField === 'delivery' ? 'selected' : ''}>delivery — livrare</option>
                    <option value="dropoff" ${st.locationField === 'dropoff' ? 'selected' : ''}>dropoff — predare</option>
                    <option value="__custom__" ${st.locationField && !['pickup','delivery','dropoff'].includes(st.locationField) ? 'selected' : ''}>Alt nume...</option>
                </select>
                <input id="jc-s-locationField-custom" class="jc-custom-input ${st.locationField && !['pickup','delivery','dropoff'].includes(st.locationField) ? '' : 'hidden'}" value="${this._esc(st.locationField || '')}" />
            </div>`;
    },

    _poolSelect(value) {
        const keys = Object.keys(this._pools());
        if (!keys.length) {
            return `<div class="jc-field"><label>Listă destinații (pool)</label>
                <input id="jc-s-pool" value="${this._esc(value || 'deliveries')}" placeholder="deliveries" />
                <small class="jc-hint">Creează lista în tab Locuri → Liste livrări.</small></div>`;
        }
        return `<div class="jc-field"><label>Listă destinații (pool)</label>
            <select id="jc-s-pool">${keys.map((k) =>
                `<option value="${this._esc(k)}" ${k === value ? 'selected' : ''}>${this._esc(k)} (${(this._pools()[k] || []).length} puncte)</option>`
            ).join('')}</select></div>`;
    },

    _presetSelect(id, list, value, label) {
        const hit = list.find((x) => x.id === value);
        let html = list.map((x) => `<option value="${x.id}" ${x.id === value ? 'selected' : ''}>${x.label}</option>`).join('');
        if (value && !hit) html += `<option value="${this._esc(value)}" selected>${this._esc(value)}</option>`;
        html += '<option value="__custom__">Alt model...</option>';
        return `<div class="jc-field"><label>${label}</label>
            <select id="${id}">${html}</select>
            <input id="${id}-custom" class="jc-custom-input ${!hit && value ? '' : 'hidden'}" value="${this._esc(value || '')}" />
        </div>`;
    },

    _flowFields(st) {
        return `
            <div class="jc-flow-box">
                <div class="jc-flow-title">Ce urmează după acest pas?</div>
                ${this._stageSelect('jc-s-onSuccess', st.onSuccess, '✅ Dacă reușește →')}
                ${this._stageSelect('jc-s-onFailure', st.onFailure, '❌ Dacă eșuează →', true)}
            </div>`;
    },

    _renderStepForm(st) {
        const type = st.type || 'goto_zone';
        const m = this._meta(type);
        let body = `<p class="jc-step-hint">${m.hint}</p>`;

        body += `
            <div class="jc-field"><label>Titlu pas (în listă)</label>
                <input id="jc-s-label" value="${this._esc(st.label || '')}" placeholder="Ex: Du-te la depozit" /></div>
            <div class="jc-field"><label>Mesaj pe ecran pentru jucător</label>
                <input id="jc-s-message" value="${this._esc(st.message || '')}" placeholder="Folosește {key} pentru tasta E" /></div>
            <div class="jc-field"><label>Tip acțiune</label>
                <select id="jc-s-type">${Object.entries(STAGE_META).map(([t, meta]) =>
                    `<option value="${t}" ${t === type ? 'selected' : ''}>${meta.icon} ${meta.label}</option>`
                ).join('')}</select></div>`;

        switch (type) {
        case 'goto_zone':
        case 'zone_interact':
        case 'progress':
        case 'skill_check':
        case 'return_vehicle':
            body += this._locationModeSelect(st);
            if (type === 'zone_interact') {
                const inc = st.actions?.[0]?.type === 'increment';
                body += `<div class="jc-field jc-check"><label>
                    <input id="jc-s-increment-done" type="checkbox" ${inc ? 'checked' : ''} />
                    După E, adaugă +1 la variabila „done”</label></div>`;
            }
            if (type === 'progress') {
                body += `<div class="jc-field"><label>Durată (secunde)</label>
                    <input id="jc-s-seconds" type="number" min="1" value="${st.seconds || Math.round((st.durationMs || 5000) / 1000)}" /></div>`;
            }
            if (type === 'skill_check') {
                body += `<div class="jc-field"><label>Fereastră reacție (sec)</label>
                    <input id="jc-s-windowSec" type="number" min="1" max="15" value="${Math.round((st.windowMs || 3000) / 1000)}" /></div>`;
            }
            break;
        case 'pick_random':
            body += this._poolSelect(st.pool);
            body += this._varSelect('jc-s-storeAs', st.storeAs || 'target', 'Salvează destinația în variabila');
            break;
        case 'branch':
            body += `<div class="jc-branch-box">
                <div class="jc-flow-title">Dacă...</div>
                <div class="jc-field-row">
                    ${this._varSelect('jc-s-branchVar', st.condition?.var || 'done', 'Variabilă')}
                    <div class="jc-field"><label>Comparație</label>
                        <select id="jc-s-branchOp">${BRANCH_OPS.map((o) =>
                            `<option value="${o.v}" ${st.condition?.op === o.v ? 'selected' : ''}>${o.label}</option>`
                        ).join('')}</select></div>
                </div>
                <div class="jc-field"><label>Compară cu</label>
                    <select id="jc-s-branchValType">
                        <option value="ref" ${st.condition?.valueRef ? 'selected' : ''}>Altă variabilă</option>
                        <option value="num" ${st.condition?.value != null && !st.condition?.valueRef ? 'selected' : ''}>Număr fix</option>
                    </select></div>
                <div class="jc-field jc-branch-ref ${st.condition?.valueRef ? '' : 'hidden'}">
                    ${this._varSelect('jc-s-branchValRef', st.condition?.valueRef || 'total', 'Variabilă țintă')}
                </div>
                <div class="jc-field jc-branch-num ${st.condition?.valueRef ? 'hidden' : ''}">
                    <label>Număr</label><input id="jc-s-branchValNum" type="number" value="${st.condition?.value ?? 0}" />
                </div>
                <div class="jc-flow-title" style="margin-top:10px">Atunci...</div>
                ${this._stageSelect('jc-s-ifTrue', st.ifTrue, '✅ Dacă DA →')}
                ${this._stageSelect('jc-s-ifFalse', st.ifFalse, '➡️ Dacă NU →')}
            </div>`;
            break;
        case 'scale_from_level':
            body += this._varSelect('jc-s-var', st.var || 'total', 'Ce numărăm (total sarcini)');
            body += this._varSelect('jc-s-resetVar', st.resetVar || 'done', 'Resetează la 0 la start');
            body += `<div class="jc-field-row">
                <div class="jc-field"><label>Bază (level 0)</label><input id="jc-s-base" type="number" value="${st.base ?? 4}" /></div>
                <div class="jc-field"><label>+ per level</label><input id="jc-s-perLevel" type="number" value="${st.perLevel ?? 1}" /></div>
                <div class="jc-field"><label>Maxim</label><input id="jc-s-max" type="number" value="${st.max ?? 10}" /></div>
            </div>`;
            break;
        case 'set_variable':
            body += `<div class="jc-flow-title">Schimbă variabile (fără E)</div>`;
            body += this._varSelect('jc-s-actionVar', st.actions?.[0]?.var || 'done', 'Variabilă');
            body += `<div class="jc-field-row">
                <div class="jc-field"><label>Operație</label>
                    <select id="jc-s-actionType">
                        <option value="increment" ${st.actions?.[0]?.type === 'increment' ? 'selected' : ''}>Adaugă (+)</option>
                        <option value="set" ${st.actions?.[0]?.type === 'set' ? 'selected' : ''}>Setează la</option>
                        <option value="decrement" ${st.actions?.[0]?.type === 'decrement' ? 'selected' : ''}>Scade (-)</option>
                    </select></div>
                <div class="jc-field"><label>Valoare</label><input id="jc-s-actionVal" type="number" value="${st.actions?.[0]?.value ?? 1}" /></div>
            </div>`;
            body += `<p class="jc-hint">Rulează instant la intrarea în pas — folosit după plată pentru +1 done.</p>`;
            break;
        case 'wait':
            body += `<div class="jc-field"><label>Secunde</label><input id="jc-s-seconds" type="number" min="1" value="${st.seconds || 3}" /></div>`;
            break;
        case 'spawn_vehicle':
            body += this._presetSelect('jc-s-vehicle', VEHICLE_PRESETS, st.model, 'Vehicul');
            body += this._locationModeSelect(st);
            body += this._varSelect('jc-s-storeAs', st.storeAs || 'truck', 'Salvează vehiculul în');
            body += `<div class="jc-field jc-check"><label><input id="jc-s-warp" type="checkbox" ${st.warp ? 'checked' : ''} /> Pune jucătorul în mașină</label></div>`;
            break;
        case 'attach_trailer':
            body += this._varSelect('jc-s-vehicleVar', st.vehicleVar || 'truck', 'Camionul (variabilă)');
            body += this._presetSelect('jc-s-trailer', TRAILER_PRESETS, st.trailerModel, 'Remorcă');
            body += this._locationModeSelect(st);
            break;
        case 'enter_vehicle':
        case 'require_vehicle':
        case 'delete_vehicle':
        case 'return_vehicle':
            if (type !== 'return_vehicle') body += this._varSelect('jc-s-vehicleVar', st.vehicleVar || 'truck', 'Vehicul (variabilă)');
            if (type === 'return_vehicle') { body += this._locationModeSelect(st); }
            break;
        case 'spawn_npc':
            body += this._presetSelect('jc-s-npc', NPC_PRESETS, st.model, 'Model NPC');
            body += this._locationModeSelect(st);
            body += this._varSelect('jc-s-storeAs', st.storeAs || 'npc', 'Salvează NPC în');
            break;
        case 'spawn_prop':
            body += this._presetSelect('jc-s-prop', PROP_PRESETS, st.model, 'Model obiect');
            body += this._locationModeSelect(st);
            body += this._varSelect('jc-s-storeAs', st.storeAs || 'treeProp', 'Salvează obiectul în');
            break;
        case 'chop_prop':
            body += this._locationModeSelect(st);
            body += this._varSelect('jc-s-propVar', st.propVar || 'treeProp', 'Obiect spawnat (variabilă)');
            body += this._presetSelect('jc-s-prop', PROP_PRESETS, st.model, 'Model fallback');
            body += `<div class="jc-field-row">
                <div class="jc-field"><label>Loveituri (swings)</label><input id="jc-s-swings" type="number" min="1" value="${st.swings ?? 5}" /></div>
                <div class="jc-field"><label>Regenerare (sec)</label><input id="jc-s-regen" type="number" min="0" value="${st.regenerateSec ?? 45}" /></div>
            </div>`;
            body += `<div class="jc-field"><label>Durată totală (sec)</label>
                <input id="jc-s-seconds" type="number" min="1" value="${st.seconds || Math.round((st.durationMs || 6000) / 1000)}" /></div>`;
            break;
        case 'talk_to_npc':
            body += this._varSelect('jc-s-npcVar', st.npcVar || 'npc', 'NPC (variabilă)');
            break;
        case 'remove_npc':
            body += this._varSelect('jc-s-npcVar', st.npcVar || 'npc', 'NPC de eliminat');
            break;
        case 'require_item':
        case 'give_item':
        case 'remove_item':
            body += this._presetSelect('jc-s-item', ITEM_PRESETS, st.item, 'Obiect');
            body += `<div class="jc-field"><label>Cantitate</label><input id="jc-s-count" type="number" min="1" value="${st.count ?? 1}" /></div>`;
            break;
        case 'give_reward':
            body += `<div class="jc-field-row">
                <div class="jc-field"><label>💵 Bani (0 = din setări job)</label><input id="jc-s-pay" type="number" value="${st.pay ?? ''}" placeholder="auto" /></div>
                <div class="jc-field"><label>⭐ XP (0 = auto)</label><input id="jc-s-xp" type="number" value="${st.xp ?? ''}" placeholder="auto" /></div>
            </div>`;
            break;
        case 'party_gate':
            body += `<div class="jc-field-row">
                <div class="jc-field"><label>Minim jucători</label><input id="jc-s-minPlayers" type="number" min="1" value="${st.minPlayers ?? 2}" /></div>
                <div class="jc-field"><label>Rază (metri)</label><input id="jc-s-radius" type="number" value="${st.radius ?? 25}" /></div>
            </div>`;
            break;
        case 'complete':
        case 'fail':
            body += `<p class="jc-hint">Pas final — nu necesită setări extra.</p>`;
            break;
        default:
            body += this._locationModeSelect(st);
        }

        if (type !== 'branch' && type !== 'complete' && type !== 'fail') {
            body += this._flowFields(st);
        }

        body += `
            <details class="jc-advanced-box">
                <summary>ID tehnic pas (opțional)</summary>
                <input id="jc-s-id" value="${this._esc(st.id || '')}" placeholder="ex: to_hub" />
                <small class="jc-hint">Template-urile folosesc ID-uri ca to_hub, check_done. Lasă gol pentru auto.</small>
            </details>`;

        return body;
    },

    _bindFormHelpers(mount) {
        const bindMode = (sel, panels) => {
            mount.querySelector(sel)?.addEventListener('change', (e) => {
                panels.forEach(([mode, cls]) => mount.querySelector(cls)?.classList.toggle('hidden', e.target.value !== mode));
            });
        };
        bindMode('#jc-s-loc-mode', [['fixed', '.jc-loc-fixed'], ['var', '.jc-loc-var'], ['field', '.jc-loc-field']]);
        bindMode('#jc-s-branchValType', [['ref', '.jc-branch-ref'], ['num', '.jc-branch-num']]);

        const bindCustom = (sel, inputSel) => {
            mount.querySelector(sel)?.addEventListener('change', (e) => {
                const inp = mount.querySelector(inputSel);
                if (!inp) return;
                inp.classList.toggle('hidden', e.target.value !== '__custom__' && e.target.value !== '__new__');
            });
        };
        ['jc-s-onSuccess', 'jc-s-onFailure', 'jc-s-ifTrue', 'jc-s-ifFalse'].forEach((id) => bindCustom(`#${id}`, `#${id}-custom`));
        bindCustom('#jc-s-vehicle', '#jc-s-vehicle-custom');
        bindCustom('#jc-s-trailer', '#jc-s-trailer-custom');
        bindCustom('#jc-s-npc', '#jc-s-npc-custom');
        bindCustom('#jc-s-prop', '#jc-s-prop-custom');
        bindCustom('#jc-s-item', '#jc-s-item-custom');
        bindCustom('#jc-s-locationField', '#jc-s-locationField-custom');
        ['jc-s-locationVar', 'jc-s-storeAs', 'jc-s-branchVar', 'jc-s-branchValRef', 'jc-s-var', 'jc-s-resetVar', 'jc-s-actionVar', 'jc-s-propVar', 'jc-s-vehicleVar', 'jc-s-npcVar', 'jc-f-progress-var', 'jc-f-progress-total'].forEach((id) => bindCustom(`#${id}`, `#${id}-custom`));

        mount.querySelector('#jc-s-type')?.addEventListener('change', () => {
            this._collectStagesFromDom();
            this.renderEditor();
        });
    },

    _readStageSelect(id) {
        const sel = document.getElementById(id);
        if (!sel) return undefined;
        if (sel.value === '__custom__') return document.getElementById(`${id}-custom`)?.value || undefined;
        return sel.value || undefined;
    },

    _readPreset(id) {
        const sel = document.getElementById(id);
        if (!sel) return undefined;
        if (sel.value === '__custom__') return document.getElementById(`${id}-custom`)?.value || undefined;
        return sel.value || undefined;
    },

    _collectStagesFromDom() {
        if (!this._draft || this._tab !== 'stages') return;
        const st = this._stage();
        if (!st) return;
        const g = (id) => document.getElementById(id);

        st.label = g('jc-s-label')?.value || st.label;
        st.message = g('jc-s-message')?.value || undefined;
        if (g('jc-s-type')) st.type = g('jc-s-type').value;

        const locMode = g('jc-s-loc-mode')?.value;
        delete st.location; delete st.locationVar; delete st.locationField;
        if (locMode === 'fixed') st.location = g('jc-s-location')?.value || undefined;
        else if (locMode === 'var') st.locationVar = this._readVarSelect('jc-s-locationVar');
        else if (locMode === 'field') {
            const f = g('jc-s-locationField')?.value;
            st.locationField = f === '__custom__' ? g('jc-s-locationField-custom')?.value : f;
        }

        if (g('jc-s-increment-done')?.checked) {
            st.actions = [{ type: 'increment', var: 'done', value: 1 }];
        } else if (st.actions) delete st.actions;

        if (g('jc-s-pool')) st.pool = g('jc-s-pool').value;
        if (g('jc-s-storeAs')) st.storeAs = this._readVarSelect('jc-s-storeAs') || g('jc-s-storeAs')?.value;

        if (st.type === 'branch') {
            const bVar = this._readVarSelect('jc-s-branchVar');
            if (bVar) {
                st.condition = { var: bVar, op: g('jc-s-branchOp')?.value || '<' };
                if (g('jc-s-branchValType')?.value === 'ref') {
                    st.condition.valueRef = this._readVarSelect('jc-s-branchValRef');
                    delete st.condition.value;
                } else {
                    st.condition.value = Number(g('jc-s-branchValNum')?.value) || 0;
                    delete st.condition.valueRef;
                }
            }
            st.ifTrue = this._readStageSelect('jc-s-ifTrue');
            st.ifFalse = this._readStageSelect('jc-s-ifFalse');
        } else {
            delete st.ifTrue; delete st.ifFalse; delete st.condition;
            const os = this._readStageSelect('jc-s-onSuccess');
            const of = this._readStageSelect('jc-s-onFailure');
            if (os) st.onSuccess = os; else delete st.onSuccess;
            if (of) st.onFailure = of; else delete st.onFailure;
        }

        if (g('jc-s-var')) st.var = this._readVarSelect('jc-s-var');
        if (g('jc-s-resetVar')) st.resetVar = this._readVarSelect('jc-s-resetVar');
        if (st.type === 'set_variable' && g('jc-s-actionVar')) {
            const v = this._readVarSelect('jc-s-actionVar');
            const t = g('jc-s-actionType')?.value || 'increment';
            const val = Number(g('jc-s-actionVal')?.value) || 1;
            if (v) st.actions = [{ type: t, var: v, value: val }];
        }
        if (g('jc-s-base')) st.base = Number(g('jc-s-base').value);
        if (g('jc-s-perLevel')) st.perLevel = Number(g('jc-s-perLevel').value);
        if (g('jc-s-max')) st.max = Number(g('jc-s-max').value);

        const sec = g('jc-s-seconds')?.value;
        if (sec) {
            st.seconds = Number(sec);
            if (st.type === 'progress' || st.type === 'chop_prop') st.durationMs = Number(sec) * 1000;
        }
        const win = g('jc-s-windowSec')?.value;
        if (win) st.windowMs = Number(win) * 1000;

        const model = this._readPreset('jc-s-vehicle') || this._readPreset('jc-s-npc') || this._readPreset('jc-s-prop');
        if (model) st.model = model;
        if (g('jc-s-propVar')) st.propVar = this._readVarSelect('jc-s-propVar');
        if (g('jc-s-swings')) st.swings = Number(g('jc-s-swings').value);
        if (g('jc-s-regen')) st.regenerateSec = Number(g('jc-s-regen').value);
        const trailer = this._readPreset('jc-s-trailer');
        if (trailer) st.trailerModel = trailer;
        if (g('jc-s-warp')) st.warp = g('jc-s-warp').checked || undefined;
        if (g('jc-s-vehicleVar')) st.vehicleVar = this._readVarSelect('jc-s-vehicleVar');
        if (g('jc-s-npcVar')) st.npcVar = this._readVarSelect('jc-s-npcVar');

        const pay = g('jc-s-pay')?.value;
        if (pay !== '') st.pay = pay === '' ? undefined : Number(pay);
        const xp = g('jc-s-xp')?.value;
        if (xp !== '') st.xp = xp === '' ? undefined : Number(xp);

        const item = this._readPreset('jc-s-item');
        if (item) st.item = item;
        if (g('jc-s-count')) st.count = Number(g('jc-s-count').value);
        if (g('jc-s-minPlayers')) st.minPlayers = Number(g('jc-s-minPlayers').value);
        if (g('jc-s-radius')) st.radius = Number(g('jc-s-radius').value);

        const newId = g('jc-s-id')?.value?.trim();
        if (newId) st.id = newId;

        if (this._autoFlow) this._rewireLinearFlow();
        if (this._def().stages?.[0]) this._def().startStage = this._def().stages[0].id;
    },

    _readVarSelect(id) {
        const sel = document.getElementById(id);
        if (!sel) return undefined;
        if (sel.value === '__new__') {
            const customInp = document.getElementById(`${id}-custom`);
            const name = (customInp?.value || '').trim();
            if (name) {
                this._def().variables = this._def().variables || {};
                this._def().variables[name] = 0;
                return name;
            }
            return undefined;
        }
        return sel.value || undefined;
    },

    _rewireLinearFlow() {
        const stages = this._stages().filter((s) => s.type !== 'complete' && s.type !== 'fail');
        stages.forEach((st, i) => {
            if (st.type === 'branch') return;
            if (i < stages.length - 1) st.onSuccess = stages[i + 1].id;
        });
    },

    renderList() {
        const list = document.getElementById('jc-job-list');
        if (!list) return;
        list.innerHTML = '';
        if (!this._jobs.length && !this._draft) {
            list.innerHTML = '<div class="jc-empty-list"><p>Niciun job.</p></div>';
            return;
        }
        const rows = [...this._jobs];
        if (this._draft && !rows.some((j) => j.id === this._draft.id)) {
            rows.unshift({ id: this._draft.id, label: this._draft.label || 'Job nou', status: 'draft',
                stageCount: this._draft.definition?.stages?.length || 0, unsaved: true });
        }
        rows.forEach((job) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'jc-job-item' + (job.id === this._selectedId ? ' active' : '');
            btn.innerHTML = `<strong>${this._esc(job.label)}</strong><small>${job.stageCount || 0} pași · ${job.status === 'published' ? 'activ' : 'draft'}${job.unsaved ? ' · nesalvat' : ''}</small>`;
            btn.addEventListener('click', () => {
                this._selectedId = job.id;
                this.renderList();
                job.unsaved ? this.renderEditor() : this.loadSelected();
            });
            list.appendChild(btn);
        });
    },

    async loadSelected() {
        if (!this._selectedId) { this._draft = null; this.renderEditor(); return; }
        const res = await this._post('jobCreatorGet', { id: this._selectedId });
        if (!res.ok) { this.setStatus(res.error || 'Eroare'); return; }
        this._draft = res.job;
        this._autoFlow = false;
        this._selectedStageIdx = 0;
        this.renderWizard();
        this.renderEditor();
    },

    newJob() {
        this._draft = {
            id: `jc_${Date.now().toString(36)}`, label: 'Jobul meu', description: '', category: 'civilian', icon: 'briefcase', status: 'draft',
            definition: {
                startStage: 'pas_1', timeoutSec: 1800, salary: 140, ui: { title: 'Muncă', key: 'E' },
                progression: { xpPerTask: 15, payPerTask: 75 },
                party: { soloEnabled: true, partyEnabled: false, minPlayers: 1, maxPlayers: 4 },
                variables: { done: 0, total: 3 },
                locations: {}, pools: { deliveries: [] },
                stages: [
                    { id: 'pas_1', type: 'goto_zone', label: 'Mergi la punct', message: 'Urmează markerul', location: 'start', onSuccess: 'pas_2' },
                    { id: 'pas_2', type: 'zone_interact', label: 'Fă treaba', message: 'Apasă {key}', location: 'start', onSuccess: 'complete' },
                    { id: 'complete', type: 'complete', label: 'Gata' },
                ],
            },
        };
        this._selectedId = this._draft.id;
        this._selectedStageIdx = 0;
        this._tab = 'general';
        this._autoFlow = true;
        this._panel?.querySelectorAll('.jc-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === 'general'));
        this.renderList();
        this.renderWizard();
        this.renderEditor();
        this.setStatus('Job nou creat. Urmează pașii 1→4 de sus.');
    },

    async seedTemplates() {
        this.setStatus('Încarc template-uri...');
        const res = await this._post('jobCreatorSeed', {});
        if (!res.ok) { this.setStatus(res.error || 'Eroare'); return; }
        this._jobs = res.jobs || [];
        const preferred = this._jobs.find((j) => j.id === 'jc_tpl_route')
            || this._jobs.find((j) => j.id === 'jc_tpl_courier')
            || this._jobs[0];
        this._selectedId = preferred?.id || null;
        this.renderList();
        if (this._selectedId) await this.loadSelected();
        this.setStatus('✅ Template-uri încărcate. Deschide Trucker (Creator) și uită-te la pași ca exemplu.');
    },

    _bindEditorActions(mount) {
        mount.querySelector('#jc-seed')?.addEventListener('click', () => this.seedTemplates());
        mount.querySelector('#jc-new-inline')?.addEventListener('click', () => this.newJob());
        mount.querySelector('#jc-auto-flow')?.addEventListener('click', () => {
            this._autoFlow = true;
            this._rewireLinearFlow();
            this.renderEditor();
            this.setStatus('Pașii legați în ordine (branch-urile rămân custom).');
        });
    },

    renderEditor() {
        const mount = document.getElementById('jc-editor');
        this.renderWizard();
        if (!mount || !this._draft) {
            if (!mount) return;
            const empty = {
                general: ['<h3>Job Creator</h3><p>Încarcă un template (Trucker, Curier...) sau creează de la zero.</p>',
                    '<button type="button" class="jc-btn" id="jc-seed">📦 Template-uri gata făcute</button>',
                    '<button type="button" class="jc-btn ghost" id="jc-new-inline">+ Job nou</button>'],
                stages: ['<h3>Pași</h3><p>Selectează un job din stânga.</p>'],
                locations: ['<h3>Locuri</h3><p>Selectează un job din stânga.</p>'],
            };
            mount.innerHTML = `<div class="jc-empty-state">${(empty[this._tab] || empty.general).join('')}</div>`;
            this._bindEditorActions(mount);
            return;
        }

        const d = this._draft;
        const def = d.definition || {};

        if (this._tab === 'general') {
            const prog = def.progression || {};
            mount.innerHTML = `
                <div class="jc-arch-box">
                    <div class="jc-arch-title">🧩 Cum funcționează un job (4 piese Lego)</div>
                    <div class="jc-arch-grid">
                        <div class="jc-arch-card"><strong>📍 Loc fix</strong><span>Hub, depozit, vânzare — tab <em>Locuri</em></span></div>
                        <div class="jc-arch-card"><strong>📋 Pool</strong><span>Listă puncte random — livrări, vene, copaci</span></div>
                        <div class="jc-arch-card"><strong>🔢 Variabile</strong><span><code>done</code> / <code>total</code> / <code>target</code> — contoare</span></div>
                        <div class="jc-arch-card"><strong>▶ Pași</strong><span>Lanț de acțiuni — tab <em>Pași</em> sau <em>module Lego</em></span></div>
                    </div>
                    <p class="jc-hint">Exemplu curier: <em>Init level</em> → <em>Du-te hub</em> → <em>Loop livrări</em> → <em>Final vânzare</em>. Deschide template Trucker/Miner și uită-te la flow.</p>
                </div>
                <div class="jc-field"><label>Nume job</label><input id="jc-f-label" value="${this._esc(d.label)}" placeholder="Ex: Trucker, Curier..." /></div>
                <div class="jc-field"><label>Descriere (Job Center)</label><input id="jc-f-desc" value="${this._esc(d.description || '')}" placeholder="Ce face jucătorul?" /></div>
                <div class="jc-field-row">
                    <div class="jc-field"><label>💵 Plată / sarcină</label><input id="jc-f-pay" type="number" value="${prog.payPerTask || 75}" /></div>
                    <div class="jc-field"><label>⭐ XP / sarcină</label><input id="jc-f-xp" type="number" value="${prog.xpPerTask || 15}" /></div>
                </div>
                <div class="jc-field-row">
                    <div class="jc-field"><label>Salariu afișat</label><input id="jc-f-salary" type="number" value="${def.salary || 140}" /></div>
                    <div class="jc-field"><label>Titlu pe ecran</label><input id="jc-f-ui-title" value="${this._esc(def.ui?.title || d.label)}" /></div>
                    <div class="jc-field"><label>Etichetă contor HUD</label><input id="jc-f-bag-label" value="${this._esc(def.ui?.bagLabel || 'Task')}" placeholder="Ore, Colete, Lemne..." /></div>
                </div>
                <div class="jc-field-row">
                    ${this._varSelect('jc-f-progress-var', prog.progressVar || 'done', 'Variabilă progres (done)')}
                    ${this._varSelect('jc-f-progress-total', prog.progressTotalVar || 'total', 'Variabilă total')}
                </div>
                ${this._iconPickerHtml(d, def)}
                ${this._variablesEditorHtml(def.variables)}
                <details class="jc-advanced-box"><summary>Mai multe setări</summary>
                    <div class="jc-field-row">
                        <div class="jc-field jc-check"><label><input id="jc-f-party" type="checkbox" ${def.party?.partyEnabled ? 'checked' : ''} /> Job în echipă</label></div>
                        <div class="jc-field"><label>Min jucători</label><input id="jc-f-party-min" type="number" value="${def.party?.minPlayers || 1}" /></div>
                        <div class="jc-field"><label>Max</label><input id="jc-f-party-max" type="number" value="${def.party?.maxPlayers || 4}" /></div>
                    </div>
                    <div class="jc-field"><label>ID intern</label><input id="jc-f-id" value="${d.id || ''}" /></div>
                </details>`;
            this._bindVariablesEditor(mount);
            this._bindIconPicker(mount);
            return;
        }

        if (this._tab === 'locations') {
            const locs = def.locations || {};
            const pools = def.pools || {};
            const locCards = Object.keys(locs).map((key) => {
                const loc = locs[key];
                return `<div class="jc-loc-card"><strong>${this._esc(loc.label || key)}</strong> <code>${key}</code>
                    <small class="jc-loc-coords">${loc.x?.toFixed(1)}, ${loc.y?.toFixed(1)}, ${loc.z?.toFixed(1)}</small>
                    <button type="button" class="jc-btn danger jc-loc-del" data-key="${this._esc(key)}">Șterge</button></div>`;
            }).join('') || '<p class="jc-hint">Niciun loc fix. Apasă <strong>📍 Pune loc aici</strong> jos.</p>';

            const poolBlocks = Object.keys(pools).map((pname) => {
                const pts = pools[pname] || [];
                const ptsHtml = pts.map((p, i) => `<li>${i + 1}. ${this._esc(p.label || 'Punct')} — ${p.x?.toFixed(0)}, ${p.y?.toFixed(0)}</li>`).join('');
                return `<div class="jc-pool-card"><strong>📋 Lista: ${this._esc(pname)}</strong> (${pts.length} puncte)
                    <ul class="jc-pool-list">${ptsHtml || '<li class="jc-hint">Gol — adaugă puncte cu butonul de mai jos</li>'}</ul>
                    <button type="button" class="jc-btn ghost jc-pool-add" data-pool="${this._esc(pname)}">+ Punct în această listă (din joc)</button>
                    </div>`;
            }).join('') || '<p class="jc-hint">Nicio listă livrări. Apasă „+ Listă nouă”.</p>';

            mount.innerHTML = `
                <div class="jc-simple-intro"><strong>Locuri fixe</strong> = depozit, spawn mașină. <strong>Liste</strong> = puncte random (curier, trucker).</div>
                <h4 class="jc-section-title">Locuri fixe</h4>
                <div class="jc-loc-grid">${locCards}</div>
                <h4 class="jc-section-title">Liste destinații (pool)</h4>
                <div class="jc-pool-grid">${poolBlocks}</div>
                <div class="jc-new-pool-row" style="display:flex; gap:8px; margin-top:8px; align-items:center;">
                    <input type="text" id="jc-new-pool-name" placeholder="Nume listă (ex: deliveries, routes)" style="max-width:240px;">
                    <button type="button" class="jc-btn ghost" id="jc-new-pool">+ Adaugă listă</button>
                </div>
                <p class="jc-hint">În pași, la „Alege destinație random”, alegi lista de aici.</p>`;

            mount.querySelectorAll('.jc-loc-del').forEach((btn) => {
                btn.addEventListener('click', () => { delete def.locations[btn.dataset.key]; this.renderEditor(); });
            });
            mount.querySelector('#jc-new-pool')?.addEventListener('click', () => {
                const nameInput = mount.querySelector('#jc-new-pool-name');
                const name = (nameInput?.value || '').trim() || 'deliveries';
                def.pools = def.pools || {};
                if (!def.pools[name]) def.pools[name] = [];
                this.renderEditor();
            });
            mount.querySelectorAll('.jc-pool-add').forEach((btn) => {
                btn.addEventListener('click', () => {
                    this._placeMode = 'pool';
                    this._placePool = btn.dataset.pool;
                    this.place();
                });
            });
            return;
        }

        this.renderStagesEditor(mount, def);
    },

    renderStagesEditor(mount, def) {
        const stages = def.stages || [];
        if (this._selectedStageIdx >= stages.length) this._selectedStageIdx = Math.max(0, stages.length - 1);
        const st = stages[this._selectedStageIdx] || {};

            mount.innerHTML = `
            ${this._flowStripHtml()}
            <div class="jc-stages-layout">
                <div class="jc-stages-list-wrap">
                    <button type="button" class="jc-btn" id="jc-add-module">🧩 Inserează modul Lego</button>
                    <button type="button" class="jc-btn ghost" id="jc-add-stage">+ Adaugă pas singular</button>
                    <button type="button" class="jc-btn ghost" id="jc-auto-flow">🔗 Leagă pașii în ordine</button>
                    <div class="jc-field"><label>Pas de start</label>
                        <select id="jc-f-start">${stages.map((s) =>
                            `<option value="${this._esc(s.id)}" ${s.id === def.startStage ? 'selected' : ''}>${this._esc(s.label || s.id)}</option>`
                        ).join('')}</select></div>
                    <ul class="jc-stage-list" id="jc-stage-list"></ul>
                </div>
                <div class="jc-stage-form">
                    <h3 class="jc-stage-form-title">${this._meta(st.type).icon} Pas ${this._selectedStageIdx + 1}: ${this._esc(st.label || '')}</h3>
                    ${this._renderStepForm(st)}
                    <button type="button" class="jc-btn danger" id="jc-del-stage">Șterge pasul</button>
                </div>
            </div>
            <div id="jc-step-picker" class="jc-step-picker hidden"></div>
            <div id="jc-module-picker" class="jc-step-picker jc-module-picker hidden"></div>`;

        mount.querySelector('#jc-add-module')?.addEventListener('click', () => this._showModulePicker());

        const list = mount.querySelector('#jc-stage-list');
        stages.forEach((stage, idx) => {
            const li = document.createElement('li');
            li.className = 'jc-stage-row' + (idx === this._selectedStageIdx ? ' active' : '');
            li.draggable = true;
            const meta = this._meta(stage.type);
            li.innerHTML = `<span class="jc-drag">☰</span><span class="jc-stage-num">${idx + 1}</span>
                <span class="jc-stage-name">${this._esc(stage.label || meta.label)}</span>
                <small>${meta.icon} ${meta.label}${stage.onSuccess ? ' → ' + stage.onSuccess : ''}</small>`;
            li.addEventListener('click', () => { this._collectStagesFromDom(); this._selectedStageIdx = idx; this.renderEditor(); });
            li.addEventListener('dragstart', () => { this._dragFromIdx = idx; });
            li.addEventListener('dragover', (e) => { e.preventDefault(); li.classList.add('drag-over'); });
            li.addEventListener('dragleave', () => li.classList.remove('drag-over'));
            li.addEventListener('drop', (e) => {
                e.preventDefault(); li.classList.remove('drag-over');
                const from = this._dragFromIdx;
                if (from === null || from === idx) return;
                this._collectStagesFromDom();
                const arr = this._stages();
                const [moved] = arr.splice(from, 1);
                arr.splice(idx, 0, moved);
                this._selectedStageIdx = idx;
                this.renderEditor();
            });
            list.appendChild(li);
        });

        mount.querySelector('#jc-add-stage')?.addEventListener('click', () => this._openStepPicker(mount));
        mount.querySelector('#jc-auto-flow')?.addEventListener('click', () => {
            this._autoFlow = true; this._rewireLinearFlow(); this.renderEditor();
            this.setStatus('Flux liniar aplicat.');
        });
        mount.querySelector('#jc-del-stage')?.addEventListener('click', () => {
            this._collectStagesFromDom();
            if (this._stages().length <= 1) return;
            this._stages().splice(this._selectedStageIdx, 1);
            this._selectedStageIdx = Math.max(0, this._selectedStageIdx - 1);
            this.renderEditor();
        });
        this._bindFormHelpers(mount);
        this._bindEditorActions(mount);
        mount.querySelectorAll('.jc-flow-chip').forEach((chip) => {
            chip.addEventListener('click', () => {
                this._collectStagesFromDom();
                this._selectedStageIdx = Number(chip.dataset.idx) || 0;
                this.renderEditor();
            });
        });
    },

    _openStepPicker(mount) {
        const picker = mount.querySelector('#jc-step-picker');
        if (!picker) return;
        picker.classList.remove('hidden');
        const byCat = {};
        Object.entries(STAGE_META).forEach(([type, meta]) => {
            if (type === 'complete' || type === 'fail') return;
            const c = meta.cat || 'logica';
            (byCat[c] = byCat[c] || []).push({ type, ...meta });
        });
        let grid = '';
        Object.entries(byCat).forEach(([cat, items]) => {
            grid += `<div class="jc-picker-cat"><h4>${CAT_LABEL[cat] || cat}</h4><div class="jc-picker-grid">`;
            grid += items.map((s) =>
                `<button type="button" class="jc-picker-item" data-type="${s.type}" title="${s.hint}">
                    <span class="jc-picker-icon">${s.icon}</span><span>${s.label}</span></button>`
            ).join('');
            grid += '</div></div>';
        });
        picker.innerHTML = `<div class="jc-picker-head"><strong>Alege tipul de pas:</strong>
            <button type="button" class="jc-close-picker">✕</button></div>${grid}`;
        picker.querySelector('.jc-close-picker')?.addEventListener('click', () => picker.classList.add('hidden'));
        picker.querySelectorAll('.jc-picker-item').forEach((btn) => {
            btn.addEventListener('click', () => {
                this._collectStagesFromDom();
                const type = btn.dataset.type;
                const meta = this._meta(type);
                const n = this._stages().filter((s) => !['complete', 'fail'].includes(s.type)).length + 1;
                const newStage = { id: `pas_${n}`, type, label: meta.label, message: 'Apasă {key}' };
                const ci = this._stages().findIndex((s) => s.type === 'complete');
                if (ci >= 0) this._stages().splice(ci, 0, newStage);
                else this._stages().push(newStage);
                this._selectedStageIdx = ci >= 0 ? ci : this._stages().length - 1;
                picker.classList.add('hidden');
                this.renderEditor();
            });
        });
    },

    _collectDraft() {
        if (!this._draft) return null;
        const d = { ...this._draft, definition: { ...this._draft.definition } };
        const def = d.definition;

        if (this._tab === 'stages') {
            this._collectStagesFromDom();
            const start = document.getElementById('jc-f-start');
            if (start) def.startStage = start.value;
        } else if (document.getElementById('jc-f-label')) {
            d.label = document.getElementById('jc-f-label').value || d.label;
            d.description = document.getElementById('jc-f-desc')?.value || '';
            d.id = document.getElementById('jc-f-id')?.value || d.id;
            const iconCustom = document.getElementById('jc-f-icon-custom')?.value?.trim();
            const iconPreset = document.getElementById('jc-f-icon')?.value || 'briefcase';
            const icon = iconCustom || iconPreset;
            d.icon = icon;
            def.salary = Number(document.getElementById('jc-f-salary')?.value) || 140;
            const prevUi = def.ui || {};
            def.ui = {
                title: document.getElementById('jc-f-ui-title')?.value || d.label,
                key: prevUi.key || 'E',
                icon,
                bagLabel: prevUi.bagLabel,
            };
            def.progression = {
                payPerTask: Number(document.getElementById('jc-f-pay')?.value) || 75,
                xpPerTask: Number(document.getElementById('jc-f-xp')?.value) || 15,
                progressVar: this._readVarSelect('jc-f-progress-var') || 'done',
                progressTotalVar: this._readVarSelect('jc-f-progress-total') || 'total',
            };
            const bagLabel = document.getElementById('jc-f-bag-label')?.value?.trim();
            if (bagLabel) def.ui.bagLabel = bagLabel;
            def.variables = this._readVariablesFromDom();
            if (document.getElementById('jc-f-party')) {
                def.party = {
                    soloEnabled: true,
                    partyEnabled: document.getElementById('jc-f-party').checked,
                    minPlayers: Number(document.getElementById('jc-f-party-min')?.value) || 1,
                    maxPlayers: Number(document.getElementById('jc-f-party-max')?.value) || 4,
                };
            }
        }
        this._draft = d;
        return d;
    },

    setStatus(msg) { const el = document.getElementById('jc-status'); if (el) el.textContent = msg || ''; },

    async save() {
        const payload = this._collectDraft();
        if (!payload) return;
        const res = await this._post('jobCreatorSave', payload);
        if (res.ok && res.job) {
            this._draft = res.job; this._selectedId = res.job.id;
            this.setStatus('✅ Salvat!');
            const listRes = await this._post('jobCreatorList', {});
            if (listRes.ok) { this._jobs = listRes.jobs; this.renderList(); this.renderEditor(); }
        } else this.setStatus(res.error || 'Eroare la salvare');
    },

    async publish() {
        const p = this._collectDraft();
        if (p) await this._post('jobCreatorSave', p);
        const res = await this._post('jobCreatorPublish', { id: this._selectedId, status: 'published' });
        this.setStatus(res.ok ? '✅ Publicat la Job Center!' : (res.error || 'Eroare'));
    },

    async test() { if (this._selectedId) await this._post('jobCreatorTest', { id: this._selectedId }); },
    async place() { await this._post('jobCreatorPlace'); },

    async delete() {
        if (!this._selectedId) return;
        const btn = document.getElementById('jc-delete');
        if (btn) {
            if (!btn.dataset.confirming) {
                btn.dataset.confirming = 'true';
                const origText = btn.textContent;
                btn.textContent = 'Confirmi ștergerea?';
                setTimeout(() => {
                    btn.dataset.confirming = '';
                    btn.textContent = origText;
                }, 3500);
                return;
            }
            btn.dataset.confirming = '';
            btn.textContent = 'Șterge';
        }
        const res = await this._post('jobCreatorDelete', { id: this._selectedId });
        if (res.ok) { this._selectedId = null; this._draft = null; this.renderList(); this.renderEditor(); }
    },

    async exportJob() {
        const res = await this._post('jobCreatorExport', { id: this._selectedId });
        if (res.ok && res.payload) {
            const a = document.createElement('a');
            a.href = URL.createObjectURL(new Blob([JSON.stringify(res.payload, null, 2)]));
            a.download = `${this._selectedId}.json`; a.click();
        }
    },

    async importJob() {
        const textarea = document.getElementById('jc-import-text');
        const text = (textarea?.value || '').trim();
        if (!text) {
            this.setStatus('Lipește JSON-ul în căsuță mai întâi.');
            return;
        }
        try {
            const res = await this._post('jobCreatorImport', { payload: JSON.parse(text) });
            if (res.ok && res.job) {
                this._selectedId = res.job.id;
                this._draft = res.job;
                this.renderList();
                this.renderEditor();
                if (textarea) textarea.value = '';
                document.getElementById('jc-import-box')?.classList.add('hidden');
            }
            this.setStatus(res.ok ? 'Importat.' : (res.error || 'Eroare la import.'));
        } catch (_) {
            this.setStatus('JSON invalid.');
        }
    },

    onPlacement(point) {
        if (!point || !this._draft) return;
        this._panel?.classList.remove('hidden');
        this._tab = 'locations';
        this._panel?.querySelectorAll('.jc-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === 'locations'));
        const def = this._draft.definition;
        if (this._placeMode === 'pool') {
            def.pools = def.pools || {};
            const pname = this._placePool || 'deliveries';
            if (!def.pools[pname]) def.pools[pname] = [];
            const n = def.pools[pname].length + 1;
            def.pools[pname].push({ ...point, label: `Punct ${n}`, weight: 1 });
            this._placeMode = 'location';
            this.setStatus(`✅ Punct adăugat în lista „${pname}".`);
        } else {
            def.locations = def.locations || {};
            const n = Object.keys(def.locations).length + 1;
            const key = n === 1 ? 'start' : `loc_${n}`;
            def.locations[key] = { ...point, label: `Loc ${n}`, radius: 3.5, zTolerance: 5, blip: { sprite: 478, color: 47, scale: 0.85 } };
            this.setStatus(`✅ Loc „${key}" salvat unde stai.`);
        }
        this.renderWizard();
        this.renderEditor();
    },
};

window.JobCreator = JobCreator;
