const Panels = {
    init() {
        if (this._ready) return;
        this._ready = true;

        $('#auth-tab-login')?.addEventListener('click', () => this.setAuthTab('login'));
        $('#auth-tab-register')?.addEventListener('click', () => this.setAuthTab('register'));
        $('#auth-login-btn')?.addEventListener('click', () => {
            post('authLogin', {
                username: $('#auth-login-user')?.value,
                password: $('#auth-login-pass')?.value,
            });
        });
        $('#auth-register-btn')?.addEventListener('click', () => {
            post('authRegister', {
                username: $('#auth-reg-user')?.value,
                password: $('#auth-reg-pass')?.value,
                passwordConfirm: $('#auth-reg-pass2')?.value,
            });
        });

        $('#inventory-close')?.addEventListener('click', () => post('inventoryClose'));
        $('#shop-close')?.addEventListener('click', () => post('shopClose'));
        $('#atm-close')?.addEventListener('click', () => post('atmClose'));
        $('#garage-close')?.addEventListener('click', () => post('garageClose'));
        $('#properties-close')?.addEventListener('click', () => post('propertiesClose'));
        $('#emotes-close')?.addEventListener('click', () => post('emotesClose'));
        $('#clothing-close')?.addEventListener('click', () => post('clothingClose'));

        $('#atm-deposit')?.addEventListener('click', () => {
            post('atmAction', { action: 'deposit', amount: Number($('#atm-amount')?.value || 0) });
        });
        $('#atm-withdraw')?.addEventListener('click', () => {
            post('atmAction', { action: 'withdraw', amount: Number($('#atm-amount')?.value || 0) });
        });
    },

    setAuthTab(tab) {
        $$('.auth-tab').forEach((el) => el.classList.toggle('is-active', el.dataset.tab === tab));
        $('#auth-form-login')?.classList.toggle('hidden', tab !== 'login');
        $('#auth-form-register')?.classList.toggle('hidden', tab !== 'register');
    },

    showAuth() {
        this.init();
        this.setAuthTab('login');
    },

    hideAuth() {
        $('#screen-auth')?.classList.add('hidden');
    },

    showInventory(data) {
        this.init();
        const list = $('#inventory-list');
        if (!list) return;
        list.innerHTML = '';
        (data.items || []).forEach((row) => {
            const def = row.item || 'unknown';
            const li = document.createElement('li');
            li.innerHTML = `<span>${def} x${row.count}</span><button data-item="${def}">USE</button>`;
            li.querySelector('button')?.addEventListener('click', () => post('inventoryUse', { item: def }));
            list.appendChild(li);
        });
        $('#inventory-weight').textContent = `${(data.weight || 0).toFixed(1)} / ${data.maxWeight || 30} kg`;
        $('#inventory')?.classList.remove('hidden');
    },

    hideInventory() { $('#inventory')?.classList.add('hidden'); },

    showShop(data) {
        this.init();
        const shop = data.shop || {};
        $('#shop-title').textContent = shop.label || 'Shop';
        const list = $('#shop-list');
        list.innerHTML = '';
        (shop.items || []).forEach((row) => {
            const li = document.createElement('li');
            li.innerHTML = `<span>${row.item} — $${row.price}</span><button>BUY</button>`;
            li.querySelector('button')?.addEventListener('click', () => {
                post('shopBuy', { shopId: data.shopId, item: row.item, amount: 1 });
            });
            list.appendChild(li);
        });
        $('#shop')?.classList.remove('hidden');
    },

    hideShop() { $('#shop')?.classList.add('hidden'); },

    showAtm() { this.init(); $('#atm')?.classList.remove('hidden'); },
    hideAtm() { $('#atm')?.classList.add('hidden'); },

    showGarage(data) {
        this.init();
        const list = $('#garage-list');
        list.innerHTML = '';
        (data.vehicles || []).forEach((v) => {
            const li = document.createElement('li');
            const status = v.stored == 1 ? 'stored' : 'out';
            li.innerHTML = `<span>${v.model} [${v.plate}] — ${status}</span>`;
            if (v.stored == 1) {
                const btn = document.createElement('button');
                btn.textContent = 'SPAWN';
                btn.addEventListener('click', () => post('garageSpawn', { vehicleId: v.id }));
                li.appendChild(btn);
            }
            list.appendChild(li);
        });
        $('#garage')?.classList.remove('hidden');
    },

    hideGarage() { $('#garage')?.classList.add('hidden'); },

    showProperties(data) {
        this.init();
        const list = $('#properties-list');
        list.innerHTML = '';
        (data.properties || []).forEach((p) => {
            const owned = p.owner_character_id ? 'OWNED' : `$${p.price}`;
            const li = document.createElement('li');
            li.innerHTML = `<span>${p.label}</span><span>${owned}</span>`;
            list.appendChild(li);
        });
        $('#properties')?.classList.remove('hidden');
    },

    hideProperties() { $('#properties')?.classList.add('hidden'); },

    showEmotes() {
        this.init();
        const list = $('#emotes-list');
        list.innerHTML = '';
        ['wave', 'sit', 'dance', 'smoke', 'drink', 'phone', 'lean', 'pushup', 'wank', 'surrender'].forEach((name) => {
            const li = document.createElement('li');
            li.innerHTML = `<span>${name}</span><button>PLAY</button>`;
            li.querySelector('button')?.addEventListener('click', () => post('emotePlay', { emote: name }));
            list.appendChild(li);
        });
        $('#emotes')?.classList.remove('hidden');
    },

    hideEmotes() { $('#emotes')?.classList.add('hidden'); },

    showClothing(data) {
        this.init();
        $('#clothing-title').textContent = data.type === 'barber' ? 'Barber' : 'Clothing';
        $('#clothing')?.classList.remove('hidden');
    },

    hideClothing() { $('#clothing')?.classList.add('hidden'); },

    showPhone(data) {
        this.init();
        $('#phone-myname').textContent = data.myName ? `— ${data.myName}` : '';
        const list = $('#phone-messages');
        list.innerHTML = '';
        (data.messages || []).forEach((m) => {
            const li = document.createElement('li');
            li.innerHTML = `<span>[${m.sender_character_id === data.myCharacterId ? 'You' : (m.sender_name || 'Player')}] ${m.message}</span>`;
            list.appendChild(li);
        });
        $('#phone-close').onclick = () => post('phoneClose');
        $('#phone-send').onclick = () => post('phoneSend', {
            targetId: Number($('#phone-target')?.value || 0),
            message: $('#phone-message')?.value || '',
        });
        $('#phone')?.classList.remove('hidden');
    },
    hidePhone() { $('#phone')?.classList.add('hidden'); },
    updatePhone(data) { this.showPhone(data); },

    showDocuments(data) {
        this.init();
        const body = $('#documents-body');
        const title = $('#documents-title');
        title.textContent = data.kind === 'licenses' ? 'Licenses' : 'ID Card';
        let html = '';
        if (data.id && data.kind !== 'licenses') {
            html += `<p><strong>Name:</strong> ${data.id.name}</p>`;
            html += `<p><strong>DOB:</strong> ${data.id.dob}</p>`;
            html += `<p><strong>Nationality:</strong> ${data.id.nationality}</p>`;
            html += `<p><strong>Account:</strong> ${data.id.account}</p>`;
            html += `<p><strong>CID:</strong> ${data.id.cid}</p>`;
        }
        if (data.licenses && data.licenses.length) {
            html += '<h3 style="margin-top:12px">Licenses</h3><ul>';
            data.licenses.forEach((l) => { html += `<li>${l.license_type} — ${l.issued_at || ''}</li>`; });
            html += '</ul>';
        } else if (data.kind === 'licenses') {
            html += '<p>No licenses on record.</p>';
        }
        body.innerHTML = html;
        $('#documents-close').onclick = () => post('documentsClose');
        $('#documents')?.classList.remove('hidden');
    },
    hideDocuments() { $('#documents')?.classList.add('hidden'); },

    showJobCenter(data) {
        this.init();
        $('#jobcenter-title').textContent = data.label || 'Job Center';
        const list = $('#jobcenter-list');
        list.innerHTML = '';
        (data.jobs || []).forEach((job) => {
            const li = document.createElement('li');
            li.innerHTML = `<span>${job.label}</span><button>HIRE</button>`;
            li.querySelector('button')?.addEventListener('click', () => post('jobCenterHire', {
                jobId: job.id, jobLabel: job.label,
            }));
            list.appendChild(li);
        });
        $('#jobcenter-close').onclick = () => post('jobCenterClose');
        $('#jobcenter')?.classList.remove('hidden');
    },
    hideJobCenter() { $('#jobcenter')?.classList.add('hidden'); },

    showCrafting(data) {
        this.init();
        this._craftStation = data.stationId;
        $('#crafting-title').textContent = data.stationLabel || 'Crafting';
        const list = $('#crafting-list');
        list.innerHTML = '';
        (data.recipes || []).forEach((recipe) => {
            const li = document.createElement('li');
            const needs = (recipe.inputList || []).map((row) => `${row.label} x${row.count}`).join(', ');
            const outLabel = recipe.outputLabel || recipe.output?.item || '?';
            const outCount = recipe.output?.count || 1;
            li.innerHTML = `<div class="craft-row"><strong>${recipe.label}</strong><span class="craft-meta">${needs || '—'} → ${outLabel} x${outCount}</span><button>CRAFT</button></div>`;
            li.querySelector('button')?.addEventListener('click', () => post('craftingCraft', {
                stationId: this._craftStation,
                recipeId: recipe.id,
            }));
            list.appendChild(li);
        });
        if (!(data.recipes || []).length) {
            list.innerHTML = '<li><span>No recipes available here.</span></li>';
        }
        $('#crafting-close').onclick = () => post('craftingClose');
        $('#crafting')?.classList.remove('hidden');
    },
    updateCrafting(data) { this.showCrafting(data); },
    hideCrafting() { $('#crafting')?.classList.add('hidden'); },

    showAppearance(data) {
        this.init();
        this._renderAppearance(data);
        $('#appearance-studio')?.classList.remove('hidden');
    },

    updateAppearance(data) {
        this._renderAppearance(data);
    },

    setAppearanceCamera(mode) {
        ['full', 'face', 'feet'].forEach((m) => {
            $(`#appearance-cam-${m}`)?.classList.toggle('is-active', m === mode);
        });
    },

    _renderAppearance(data) {
        const gender = Number(data?.gender) || 0;
        $$('#appearance-gender .studio-gender__btn').forEach((btn) => {
            btn.classList.toggle('is-active', Number(btn.dataset.gender) === gender);
        });

        const wrap = $('#appearance-sliders');
        if (!wrap) return;
        wrap.innerHTML = '';

        (data.fields || []).forEach((field) => {
            const row = document.createElement('div');
            row.className = 'studio-row';
            const val = field.value ?? 0;
            row.innerHTML = `
                <div class="studio-row__head">
                    <span>${field.label}</span>
                    <span class="studio-row__val">${val} / ${field.max}</span>
                </div>
                <input type="range" min="${field.min}" max="${field.max}" value="${val}">`;
            const input = row.querySelector('input');
            const valEl = row.querySelector('.studio-row__val');
            const sendChange = () => {
                const value = Number(input.value);
                valEl.textContent = `${value} / ${field.max}`;
                post('appearanceChange', {
                    type: field.type,
                    component: field.component,
                    value,
                    camera: field.camera,
                });
            };
            input.addEventListener('input', sendChange);
            input.addEventListener('focus', () => {
                if (field.camera) post('appearanceCamera', { mode: field.camera });
            });
            wrap.appendChild(row);
        });

        $$('#appearance-gender .studio-gender__btn').forEach((btn) => {
            btn.onclick = () => post('appearanceGender', { gender: Number(btn.dataset.gender) });
        });

        const setCamActive = (mode) => {
            ['full', 'face', 'feet'].forEach((m) => {
                $(`#appearance-cam-${m}`)?.classList.toggle('is-active', m === mode);
            });
        };
        setCamActive(data.camera || 'full');

        $('#appearance-cam-full').onclick = () => { post('appearanceCamera', { mode: 'full' }); setCamActive('full'); };
        $('#appearance-cam-face').onclick = () => { post('appearanceCamera', { mode: 'face' }); setCamActive('face'); };
        $('#appearance-cam-feet').onclick = () => { post('appearanceCamera', { mode: 'feet' }); setCamActive('feet'); };
        $('#appearance-rot-left').onclick = () => post('appearanceRotate', { direction: 'left' });
        $('#appearance-rot-right').onclick = () => post('appearanceRotate', { direction: 'right' });
        $('#appearance-save').onclick = () => {
            const btn = $('#appearance-save');
            if (btn?.disabled) return;
            post('appearanceSave', {});
        };
    },

    hideAppearance() {
        $('#appearance-studio')?.classList.add('hidden');
    },

    setAppearanceSaving(isSaving) {
        const btn = $('#appearance-save');
        if (!btn) return;
        btn.disabled = isSaving;
        btn.textContent = isSaving ? 'SAVING...' : 'CONFIRM & PLAY';
    },
};

window.Panels = Panels;
