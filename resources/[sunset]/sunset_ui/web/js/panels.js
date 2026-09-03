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
        list.className = 'menu-vehicle-grid';

        const vehicleImage = (model) => {
            const m = (model || 'sultan').toLowerCase().replace(/[^a-z0-9_]/g, '');
            return `https://docs.fivem.net/vehicles/${m}.webp`;
        };

        const addBtn = (parent, label, className, onClick) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.textContent = label;
            btn.className = `menu-vcard__btn ${className || ''}`;
            btn.addEventListener('click', onClick);
            parent.appendChild(btn);
        };

        (data.vehicles || []).forEach((v) => {
            const stored = v.stored === true || v.stored === 1 || v.stored === '1' || Number(v.stored) === 1;
            const inWorld = v.inWorld === true;
            const status = stored ? 'In garage' : (inWorld ? 'Out' : 'Missing');
            const statusClass = stored ? 'stored' : (inWorld ? 'out' : 'missing');
            const model = (v.model || 'vehicle').toUpperCase();

            const li = document.createElement('li');
            li.className = 'menu-vcard';
            li.innerHTML = `
                <div class="menu-vcard__img-wrap">
                    <img class="menu-vcard__img" src="${vehicleImage(v.model)}" alt="${model}" loading="lazy"
                        onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">
                    <div class="menu-vcard__img-fallback" style="display:none">${model.charAt(0)}</div>
                </div>
                <div class="menu-vcard__body">
                    <div class="menu-vcard__top">
                        <strong>${model}</strong>
                        <span class="menu-vcard__status menu-vcard__status--${statusClass}">${status}</span>
                    </div>
                    <div class="menu-vcard__plate">${v.plate}</div>
                    <div class="menu-vcard__meta">${v.garage || 'legion'}</div>
                    <div class="menu-vcard__actions"></div>
                </div>`;

            const actions = li.querySelector('.menu-vcard__actions');
            if (stored) {
                addBtn(actions, 'Spawn', 'menu-vcard__btn--primary', () => post('garageSpawn', { vehicleId: v.id }));
            } else if (inWorld) {
                addBtn(actions, 'GPS', '', () => post('garageLocate', { plate: v.plate }));
                addBtn(actions, 'Store', 'menu-vcard__btn--primary', () => post('garageStore', { vehicleId: v.id }));
            } else {
                addBtn(actions, 'Respawn', 'menu-vcard__btn--primary', () => post('garageSpawn', { vehicleId: v.id }));
                addBtn(actions, 'Store', '', () => post('garageStore', { vehicleId: v.id }));
            }

            list.appendChild(li);
        });

        if (!(data.vehicles || []).length) {
            list.className = 'panel-list';
            list.innerHTML = '<li class="garage-empty">You have no vehicles. Plates are assigned when you receive a car.</li>';
        }

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
        const type = data.type || 'clothing';
        this.clothingType = type;
        const options = $('#clothing-options');
        const hint = $('#clothing-hint');
        if (!options) return;
        options.innerHTML = '';

        $('#clothing-title').textContent = type === 'barber' ? 'Barber' : 'Clothing';

        if (type === 'barber') {
            if (hint) hint.textContent = 'Alege coafura. $50 per schimbare.';
            if (this.barberHair == null) this.barberHair = 0;

            const picker = document.createElement('div');
            picker.className = 'clothing-picker';
            picker.innerHTML = `
                <button type="button" class="btn" id="barber-prev">◀</button>
                <span id="barber-label">Hair #0</span>
                <button type="button" class="btn" id="barber-next">▶</button>`;
            options.appendChild(picker);

            const apply = document.createElement('button');
            apply.type = 'button';
            apply.className = 'btn btn--primary clothing-apply';
            apply.textContent = 'Apply — $50';
            options.appendChild(apply);

            const label = () => {
                const el = $('#barber-label');
                if (el) el.textContent = `Hair #${this.barberHair}`;
            };
            const preview = () => post('clothingPreview', { type: 'barber', hair: this.barberHair });

            picker.querySelector('#barber-prev')?.addEventListener('click', () => {
                this.barberHair = Math.max(0, this.barberHair - 1);
                label();
                preview();
            });
            picker.querySelector('#barber-next')?.addEventListener('click', () => {
                this.barberHair = Math.min(36, this.barberHair + 1);
                label();
                preview();
            });
            apply.addEventListener('click', () => {
                post('clothingApply', { type: 'barber', hair: this.barberHair, pay: true });
            });
            label();
            preview();
        } else {
            if (hint) hint.textContent = 'Alege haina (torso). $50 per schimbare.';
            if (this.clothingDrawable == null) this.clothingDrawable = 0;

            const picker = document.createElement('div');
            picker.className = 'clothing-picker';
            picker.innerHTML = `
                <button type="button" class="btn" id="cloth-prev">◀</button>
                <span id="cloth-label">Outfit #0</span>
                <button type="button" class="btn" id="cloth-next">▶</button>`;
            options.appendChild(picker);

            const apply = document.createElement('button');
            apply.type = 'button';
            apply.className = 'btn btn--primary clothing-apply';
            apply.textContent = 'Apply — $50';
            options.appendChild(apply);

            const label = () => {
                const el = $('#cloth-label');
                if (el) el.textContent = `Outfit #${this.clothingDrawable}`;
            };
            const preview = () => post('clothingPreview', {
                type: 'clothing',
                component: 11,
                drawable: this.clothingDrawable,
            });

            picker.querySelector('#cloth-prev')?.addEventListener('click', () => {
                this.clothingDrawable = Math.max(0, this.clothingDrawable - 1);
                label();
                preview();
            });
            picker.querySelector('#cloth-next')?.addEventListener('click', () => {
                this.clothingDrawable = Math.min(40, this.clothingDrawable + 1);
                label();
                preview();
            });
            apply.addEventListener('click', () => {
                post('clothingApply', {
                    type: 'clothing',
                    component: 11,
                    drawable: this.clothingDrawable,
                    pay: true,
                });
            });
            label();
            preview();
        }

        $('#clothing')?.classList.remove('hidden');
    },

    hideClothing() { $('#clothing')?.classList.add('hidden'); },

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
