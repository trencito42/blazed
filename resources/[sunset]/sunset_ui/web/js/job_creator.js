const STAGE_CATALOG = [
    { type: 'goto_zone', category: 'world', label: 'Go to location' },
    { type: 'zone_interact', category: 'interaction', label: 'Zone interact (E)' },
    { type: 'talk_to_npc', category: 'interaction', label: 'Talk to NPC' },
    { type: 'pick_random', category: 'logic', label: 'Pick random from pool' },
    { type: 'branch', category: 'logic', label: 'Branch (if/else)' },
    { type: 'set_variable', category: 'logic', label: 'Set variable' },
    { type: 'scale_from_level', category: 'logic', label: 'Scale from job level' },
    { type: 'wait', category: 'gameplay', label: 'Wait (seconds)' },
    { type: 'progress', category: 'gameplay', label: 'Progress bar' },
    { type: 'skill_check', category: 'gameplay', label: 'Skill check' },
    { type: 'spawn_vehicle', category: 'vehicles', label: 'Spawn vehicle' },
    { type: 'delete_vehicle', category: 'vehicles', label: 'Delete vehicle' },
    { type: 'attach_trailer', category: 'vehicles', label: 'Attach trailer' },
    { type: 'enter_vehicle', category: 'vehicles', label: 'Enter vehicle' },
    { type: 'require_vehicle', category: 'vehicles', label: 'Require vehicle' },
    { type: 'return_vehicle', category: 'vehicles', label: 'Return vehicle' },
    { type: 'spawn_npc', category: 'world', label: 'Spawn NPC' },
    { type: 'remove_npc', category: 'world', label: 'Remove NPC' },
    { type: 'require_item', category: 'items', label: 'Require item' },
    { type: 'give_item', category: 'items', label: 'Give item' },
    { type: 'remove_item', category: 'items', label: 'Remove item' },
    { type: 'party_gate', category: 'party', label: 'Party size check' },
    { type: 'give_reward', category: 'rewards', label: 'Pay + XP' },
    { type: 'complete', category: 'rewards', label: 'Complete job' },
    { type: 'fail', category: 'rewards', label: 'Fail job' },
];

const JobCreator = {
    _jobs: [],
    _selectedId: null,
    _draft: null,
    _tab: 'general',
    _selectedStageIdx: 0,
    _dragFromIdx: null,

    init() {
        this._panel = document.getElementById('job-creator-panel');
        document.getElementById('jc-close')?.addEventListener('click', () => this.close());
        document.getElementById('jc-new')?.addEventListener('click', () => this.newJob());
        document.getElementById('jc-save')?.addEventListener('click', () => this.save());
        document.getElementById('jc-publish')?.addEventListener('click', () => this.publish());
        document.getElementById('jc-test')?.addEventListener('click', () => this.test());
        document.getElementById('jc-place')?.addEventListener('click', () => this.place());
        document.getElementById('jc-delete')?.addEventListener('click', () => this.delete());
        document.getElementById('jc-export')?.addEventListener('click', () => this.exportJob());
        document.getElementById('jc-import')?.addEventListener('click', () => this.importJob());
        this._panel?.querySelectorAll('.jc-tab').forEach((btn) => {
            btn.addEventListener('click', () => {
                this._tab = btn.dataset.tab || 'general';
                this._panel.querySelectorAll('.jc-tab').forEach((b) => b.classList.toggle('active', b === btn));
                this.renderEditor();
            });
        });
    },

    async _post(action, body = {}) {
        const res = await fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });
        return res.json();
    },

    show(data = {}) {
        this.init();
        this._jobs = data.jobs || [];
        this._panel?.classList.remove('hidden');
        if (!this._selectedId && this._jobs[0]) this._selectedId = this._jobs[0].id;
        this.renderList();
        this.loadSelected();
    },

    update(data = {}) {
        this._jobs = data.jobs || this._jobs;
        this.renderList();
    },

    hide() { this._panel?.classList.add('hidden'); },
    close() { this._post('jobCreatorClose'); },

    renderList() {
        const list = document.getElementById('jc-job-list');
        if (!list) return;
        list.innerHTML = '';
        this._jobs.forEach((job) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'jc-job-item' + (job.id === this._selectedId ? ' active' : '');
            btn.innerHTML = `<strong>${job.label}</strong><small>${job.id} · ${job.status} · ${job.stageCount || 0} stages</small>`;
            btn.addEventListener('click', () => {
                this._selectedId = job.id;
                this.renderList();
                this.loadSelected();
            });
            list.appendChild(btn);
        });
    },

    async loadSelected() {
        if (!this._selectedId) {
            this._draft = null;
            this.renderEditor();
            return;
        }
        const res = await this._post('jobCreatorGet', { id: this._selectedId });
        if (!res.ok) {
            this.setStatus(res.error || 'Could not load job');
            return;
        }
        this._draft = res.job;
        this._selectedStageIdx = 0;
        this.renderEditor();
    },

    newJob() {
        const id = `jc_${Date.now().toString(36)}`;
        this._draft = {
            id,
            label: 'New Job',
            description: '',
            category: 'civilian',
            icon: 'briefcase',
            status: 'draft',
            definition: {
                startStage: 'start',
                timeoutSec: 1800,
                salary: 140,
                ui: { title: 'Work', key: 'E' },
                progression: { xpPerTask: 15, payPerTask: 60 },
                party: { soloEnabled: true, partyEnabled: false, minPlayers: 1, maxPlayers: 4 },
                variables: {},
                locations: {},
                pools: {},
                stages: [{ id: 'start', type: 'complete', label: 'Finish', onSuccess: 'complete' }],
            },
        };
        this._selectedId = id;
        this._selectedStageIdx = 0;
        this.renderList();
        this.renderEditor();
    },

    _stages() {
        return this._draft?.definition?.stages || [];
    },

    _stage() {
        return this._stages()[this._selectedStageIdx] || null;
    },

    _stageTypeOptions(selected) {
        return STAGE_CATALOG.map((s) =>
            `<option value="${s.type}" ${s.type === selected ? 'selected' : ''}>${s.label} (${s.category})</option>`
        ).join('');
    },

    renderEditor() {
        const mount = document.getElementById('jc-editor');
        if (!mount) return;
        if (!this._draft) {
            mount.innerHTML = '<p>Select or create a job.</p>';
            return;
        }
        const d = this._draft;
        const def = d.definition || {};
        if (this._tab === 'general') {
            mount.innerHTML = `
                <div class="jc-field"><label>Job ID</label><input id="jc-f-id" value="${d.id || ''}" /></div>
                <div class="jc-field"><label>Label</label><input id="jc-f-label" value="${this._esc(d.label)}" /></div>
                <div class="jc-field"><label>Description</label><input id="jc-f-desc" value="${this._esc(d.description || '')}" /></div>
                <div class="jc-field"><label>Salary (grade 0)</label><input id="jc-f-salary" type="number" value="${def.salary || 140}" /></div>
                <div class="jc-field"><label>HUD Title</label><input id="jc-f-ui-title" value="${this._esc(def.ui?.title || '')}" /></div>
                <div class="jc-field"><label>Interact Key</label><input id="jc-f-ui-key" value="${def.ui?.key || 'E'}" maxlength="4" /></div>
                <div class="jc-field"><label>Pay per task</label><input id="jc-f-pay" type="number" value="${def.progression?.payPerTask || 60}" /></div>
                <div class="jc-field"><label>XP per task</label><input id="jc-f-xp" type="number" value="${def.progression?.xpPerTask || 15}" /></div>
                <div class="jc-field-row">
                    <div class="jc-field"><label>Party enabled</label><input id="jc-f-party" type="checkbox" ${def.party?.partyEnabled ? 'checked' : ''} /></div>
                    <div class="jc-field"><label>Min players</label><input id="jc-f-party-min" type="number" value="${def.party?.minPlayers || 1}" /></div>
                    <div class="jc-field"><label>Max players</label><input id="jc-f-party-max" type="number" value="${def.party?.maxPlayers || 4}" /></div>
                </div>
            `;
            return;
        }
        if (this._tab === 'locations') {
            mount.innerHTML = `
                <p>Use <strong>Place in world</strong> to add points, then edit JSON if needed.</p>
                <div class="jc-field"><label>Locations JSON</label><textarea id="jc-f-locations">${this._esc(JSON.stringify(def.locations || {}, null, 2))}</textarea></div>
                <div class="jc-field"><label>Pools JSON</label><textarea id="jc-f-pools">${this._esc(JSON.stringify(def.pools || {}, null, 2))}</textarea></div>
            `;
            return;
        }
        this.renderStagesEditor(mount, def);
    },

    renderStagesEditor(mount, def) {
        const stages = def.stages || [];
        if (this._selectedStageIdx >= stages.length) this._selectedStageIdx = Math.max(0, stages.length - 1);
        const st = stages[this._selectedStageIdx] || {};

        mount.innerHTML = `
            <div class="jc-stages-layout">
                <div class="jc-stages-list-wrap">
                    <div class="jc-stages-toolbar">
                        <button type="button" class="jc-btn ghost" id="jc-add-stage">+ Stage</button>
                        <button type="button" class="jc-btn ghost" id="jc-dup-stage">Duplicate</button>
                        <button type="button" class="jc-btn danger" id="jc-del-stage">Delete</button>
                    </div>
                    <div class="jc-field"><label>Start stage ID</label><input id="jc-f-start" value="${def.startStage || ''}" /></div>
                    <ul class="jc-stage-list" id="jc-stage-list"></ul>
                </div>
                <div class="jc-stage-form" id="jc-stage-form"></div>
            </div>
        `;

        const list = mount.querySelector('#jc-stage-list');
        stages.forEach((stage, idx) => {
            const li = document.createElement('li');
            li.className = 'jc-stage-row' + (idx === this._selectedStageIdx ? ' active' : '');
            li.draggable = true;
            li.dataset.idx = String(idx);
            const cat = STAGE_CATALOG.find((c) => c.type === stage.type);
            li.innerHTML = `<span class="jc-drag">☰</span><span class="jc-stage-num">${String(idx + 1).padStart(2, '0')}</span><span class="jc-stage-name">${this._esc(stage.label || stage.id)}</span><small>${cat?.label || stage.type}</small>`;
            li.addEventListener('click', () => {
                this._collectStagesFromDom();
                this._selectedStageIdx = idx;
                this.renderEditor();
            });
            li.addEventListener('dragstart', (e) => {
                this._dragFromIdx = idx;
                e.dataTransfer.effectAllowed = 'move';
            });
            li.addEventListener('dragover', (e) => { e.preventDefault(); li.classList.add('drag-over'); });
            li.addEventListener('dragleave', () => li.classList.remove('drag-over'));
            li.addEventListener('drop', (e) => {
                e.preventDefault();
                li.classList.remove('drag-over');
                const to = idx;
                const from = this._dragFromIdx;
                if (from === null || from === to) return;
                this._collectStagesFromDom();
                const arr = this._stages();
                const [moved] = arr.splice(from, 1);
                arr.splice(to, 0, moved);
                this._selectedStageIdx = to;
                this.renderEditor();
            });
            list.appendChild(li);
        });

        const form = mount.querySelector('#jc-stage-form');
        form.innerHTML = `
            <h3 class="jc-stage-form-title">Stage: ${this._esc(st.id || 'new')}</h3>
            <div class="jc-field"><label>Stage ID</label><input id="jc-s-id" value="${this._esc(st.id || '')}" /></div>
            <div class="jc-field"><label>Type</label><select id="jc-s-type">${this._stageTypeOptions(st.type)}</select></div>
            <div class="jc-field"><label>Label</label><input id="jc-s-label" value="${this._esc(st.label || '')}" /></div>
            <div class="jc-field"><label>Message (HUD)</label><input id="jc-s-message" value="${this._esc(st.message || '')}" /></div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Location key</label><input id="jc-s-location" value="${this._esc(st.location || '')}" placeholder="hub" /></div>
                <div class="jc-field"><label>Location var</label><input id="jc-s-locationVar" value="${this._esc(st.locationVar || '')}" placeholder="target" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Location field</label><input id="jc-s-locationField" value="${this._esc(st.locationField || '')}" placeholder="pickup" /></div>
                <div class="jc-field"><label>Pool name</label><input id="jc-s-pool" value="${this._esc(st.pool || '')}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Store as var</label><input id="jc-s-storeAs" value="${this._esc(st.storeAs || '')}" /></div>
                <div class="jc-field"><label>On success →</label><input id="jc-s-onSuccess" value="${this._esc(st.onSuccess || '')}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>On failure →</label><input id="jc-s-onFailure" value="${this._esc(st.onFailure || '')}" /></div>
                <div class="jc-field"><label>If true →</label><input id="jc-s-ifTrue" value="${this._esc(st.ifTrue || '')}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>If false →</label><input id="jc-s-ifFalse" value="${this._esc(st.ifFalse || '')}" /></div>
                <div class="jc-field"><label>Branch var</label><input id="jc-s-branchVar" value="${this._esc(st.condition?.var || '')}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Branch op</label><select id="jc-s-branchOp"><option value=">=" ${st.condition?.op === '>=' ? 'selected' : ''}>&gt;=</option><option value="<=" ${st.condition?.op === '<=' ? 'selected' : ''}>&lt;=</option><option value="==" ${st.condition?.op === '==' ? 'selected' : ''}>==</option><option value="<" ${st.condition?.op === '<' ? 'selected' : ''}>&lt;</option><option value=">" ${st.condition?.op === '>' ? 'selected' : ''}>&gt;</option></select></div>
                <div class="jc-field"><label>Branch value</label><input id="jc-s-branchVal" value="${st.condition?.valueRef ? `ref:${st.condition.valueRef}` : (st.condition?.value ?? '')}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Vehicle model</label><input id="jc-s-model" value="${this._esc(st.model || '')}" placeholder="phantom" /></div>
                <div class="jc-field"><label>Warp into vehicle</label><input id="jc-s-warp" type="checkbox" ${st.warp ? 'checked' : ''} /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Trailer model</label><input id="jc-s-trailerModel" value="${this._esc(st.trailerModel || '')}" /></div>
                <div class="jc-field"><label>Duration (ms)</label><input id="jc-s-durationMs" type="number" value="${st.durationMs || ''}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Skill window (ms)</label><input id="jc-s-windowMs" type="number" value="${st.windowMs || ''}" /></div>
                <div class="jc-field"><label>Wait (seconds)</label><input id="jc-s-seconds" type="number" value="${st.seconds || ''}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Pay</label><input id="jc-s-pay" type="number" value="${st.pay ?? ''}" /></div>
                <div class="jc-field"><label>XP</label><input id="jc-s-xp" type="number" value="${st.xp ?? ''}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>Item</label><input id="jc-s-item" value="${this._esc(st.item || '')}" /></div>
                <div class="jc-field"><label>Item count</label><input id="jc-s-count" type="number" value="${st.count ?? ''}" /></div>
            </div>
            <div class="jc-field-row">
                <div class="jc-field"><label>NPC model</label><input id="jc-s-npcModel" value="${this._esc(st.model || '')}" /></div>
                <div class="jc-field"><label>Min party</label><input id="jc-s-minPlayers" type="number" value="${st.minPlayers ?? ''}" /></div>
            </div>
            <div class="jc-field"><label>Scale: base / perLevel / max</label>
                <div class="jc-field-row">
                    <input id="jc-s-base" type="number" value="${st.base ?? ''}" placeholder="base" />
                    <input id="jc-s-perLevel" type="number" value="${st.perLevel ?? ''}" placeholder="per level" />
                    <input id="jc-s-max" type="number" value="${st.max ?? ''}" placeholder="max" />
                </div>
            </div>
        `;

        mount.querySelector('#jc-add-stage')?.addEventListener('click', () => {
            this._collectStagesFromDom();
            const n = this._stages().length + 1;
            this._stages().push({ id: `stage_${n}`, type: 'goto_zone', label: `Stage ${n}`, onSuccess: 'complete' });
            this._selectedStageIdx = this._stages().length - 1;
            this.renderEditor();
        });
        mount.querySelector('#jc-dup-stage')?.addEventListener('click', () => {
            this._collectStagesFromDom();
            const cur = this._stage();
            if (!cur) return;
            const copy = JSON.parse(JSON.stringify(cur));
            copy.id = `${cur.id}_copy`;
            this._stages().splice(this._selectedStageIdx + 1, 0, copy);
            this._selectedStageIdx += 1;
            this.renderEditor();
        });
        mount.querySelector('#jc-del-stage')?.addEventListener('click', () => {
            this._collectStagesFromDom();
            if (this._stages().length <= 1) return;
            this._stages().splice(this._selectedStageIdx, 1);
            this._selectedStageIdx = Math.max(0, this._selectedStageIdx - 1);
            this.renderEditor();
        });
    },

    _collectStagesFromDom() {
        if (!this._draft || this._tab !== 'stages') return;
        const def = this._draft.definition;
        def.startStage = document.getElementById('jc-f-start')?.value || def.startStage;
        const st = this._stage();
        if (!st) return;
        const g = (id) => document.getElementById(id);
        st.id = g('jc-s-id')?.value || st.id;
        st.type = g('jc-s-type')?.value || st.type;
        st.label = g('jc-s-label')?.value || '';
        st.message = g('jc-s-message')?.value || undefined;
        st.location = g('jc-s-location')?.value || undefined;
        st.locationVar = g('jc-s-locationVar')?.value || undefined;
        st.locationField = g('jc-s-locationField')?.value || undefined;
        st.pool = g('jc-s-pool')?.value || undefined;
        st.storeAs = g('jc-s-storeAs')?.value || undefined;
        st.onSuccess = g('jc-s-onSuccess')?.value || undefined;
        st.onFailure = g('jc-s-onFailure')?.value || undefined;
        st.ifTrue = g('jc-s-ifTrue')?.value || undefined;
        st.ifFalse = g('jc-s-ifFalse')?.value || undefined;
        const bVar = g('jc-s-branchVar')?.value;
        const bVal = g('jc-s-branchVal')?.value;
        if (bVar) {
            st.condition = { var: bVar, op: g('jc-s-branchOp')?.value || '>=' };
            if (String(bVal).startsWith('ref:')) st.condition.valueRef = bVal.slice(4);
            else if (bVal !== '') st.condition.value = Number(bVal) || bVal;
        }
        if (g('jc-s-model')?.value && ['spawn_vehicle', 'attach_trailer', 'spawn_npc'].includes(st.type)) {
            st.model = g('jc-s-model')?.value;
        }
        if (st.type === 'spawn_npc' && g('jc-s-npcModel')?.value) st.model = g('jc-s-npcModel')?.value;
        st.warp = g('jc-s-warp')?.checked || undefined;
        st.trailerModel = g('jc-s-trailerModel')?.value || undefined;
        const dur = g('jc-s-durationMs')?.value;
        if (dur) st.durationMs = Number(dur);
        const win = g('jc-s-windowMs')?.value;
        if (win) st.windowMs = Number(win);
        const sec = g('jc-s-seconds')?.value;
        if (sec) st.seconds = Number(sec);
        const pay = g('jc-s-pay')?.value;
        if (pay !== '') st.pay = Number(pay);
        const xp = g('jc-s-xp')?.value;
        if (xp !== '') st.xp = Number(xp);
        st.item = g('jc-s-item')?.value || undefined;
        const cnt = g('jc-s-count')?.value;
        if (cnt !== '') st.count = Number(cnt);
        const mp = g('jc-s-minPlayers')?.value;
        if (mp !== '') st.minPlayers = Number(mp);
        const base = g('jc-s-base')?.value;
        if (base !== '') { st.var = st.var || 'total'; st.base = Number(base); }
        const pl = g('jc-s-perLevel')?.value;
        if (pl !== '') st.perLevel = Number(pl);
        const mx = g('jc-s-max')?.value;
        if (mx !== '') st.max = Number(mx);
    },

    _collectDraft() {
        if (!this._draft) return null;
        const d = { ...this._draft };
        d.id = document.getElementById('jc-f-id')?.value || d.id;
        d.label = document.getElementById('jc-f-label')?.value || d.label;
        d.description = document.getElementById('jc-f-desc')?.value || '';
        const def = { ...(d.definition || {}) };
        if (document.getElementById('jc-f-salary')) {
            def.salary = Number(document.getElementById('jc-f-salary').value) || 140;
            def.ui = { title: document.getElementById('jc-f-ui-title')?.value || 'Work', key: document.getElementById('jc-f-ui-key')?.value || 'E' };
            def.progression = {
                payPerTask: Number(document.getElementById('jc-f-pay')?.value) || 60,
                xpPerTask: Number(document.getElementById('jc-f-xp')?.value) || 15,
            };
            def.party = {
                soloEnabled: true,
                partyEnabled: document.getElementById('jc-f-party')?.checked || false,
                minPlayers: Number(document.getElementById('jc-f-party-min')?.value) || 1,
                maxPlayers: Number(document.getElementById('jc-f-party-max')?.value) || 4,
            };
        }
        if (document.getElementById('jc-f-locations')) {
            try { def.locations = JSON.parse(document.getElementById('jc-f-locations').value || '{}'); } catch (_) {}
            try { def.pools = JSON.parse(document.getElementById('jc-f-pools').value || '{}'); } catch (_) {}
        }
        if (this._tab === 'stages') this._collectStagesFromDom();
        d.definition = def;
        return d;
    },

    setStatus(msg) {
        const el = document.getElementById('jc-status');
        if (el) el.textContent = msg || '';
    },

    async save() {
        const payload = this._collectDraft();
        if (!payload) return;
        const res = await this._post('jobCreatorSave', payload);
        if (res.ok && res.job) {
            this._draft = res.job;
            this._selectedId = res.job.id;
            this.setStatus('Saved.');
            const listRes = await this._post('jobCreatorList', {});
            if (listRes.ok && listRes.jobs) {
                this._jobs = listRes.jobs;
                this.renderList();
            }
        } else {
            this.setStatus(res.error || 'Save failed');
        }
    },

    async publish() {
        const payload = this._collectDraft();
        if (payload) await this._post('jobCreatorSave', payload);
        const res = await this._post('jobCreatorPublish', { id: this._selectedId, status: 'published' });
        this.setStatus(res.ok ? 'Published.' : (res.error || 'Publish failed'));
    },

    async test() {
        if (!this._selectedId) return;
        await this._post('jobCreatorTest', { id: this._selectedId });
    },

    async place() { await this._post('jobCreatorPlace'); },

    async delete() {
        if (!this._selectedId || !confirm('Delete this job?')) return;
        const res = await this._post('jobCreatorDelete', { id: this._selectedId });
        if (res.ok) {
            this._selectedId = null;
            this._draft = null;
            this.setStatus('Deleted.');
        }
    },

    async exportJob() {
        const res = await this._post('jobCreatorExport', { id: this._selectedId });
        if (res.ok && res.payload) {
            const blob = new Blob([JSON.stringify(res.payload, null, 2)], { type: 'application/json' });
            const a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = `${this._selectedId || 'job'}.json`;
            a.click();
        }
    },

    async importJob() {
        const text = prompt('Paste job JSON export:');
        if (!text) return;
        try {
            const payload = JSON.parse(text);
            const res = await this._post('jobCreatorImport', { payload });
            this.setStatus(res.ok ? 'Imported.' : (res.error || 'Import failed'));
            if (res.ok && res.job) {
                this._selectedId = res.job.id;
                this._draft = res.job;
                this.renderList();
                this.renderEditor();
            }
        } catch (_) {
            this.setStatus('Invalid JSON.');
        }
    },

    onPlacement(point) {
        if (!point) return;
        this._tab = 'locations';
        this._panel?.querySelectorAll('.jc-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === 'locations'));
        this.renderEditor();
        const ta = document.getElementById('jc-f-locations');
        if (!ta) return;
        let locs = {};
        try { locs = JSON.parse(ta.value || '{}'); } catch (_) {}
        const key = `point_${Object.keys(locs).length + 1}`;
        locs[key] = { ...point, label: key, blip: { sprite: 478, color: 47, scale: 0.85 } };
        ta.value = JSON.stringify(locs, null, 2);
        this.setStatus(`Added location "${key}" from world placement.`);
    },

    _esc(s) {
        return String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
    },
};
window.JobCreator = JobCreator;
