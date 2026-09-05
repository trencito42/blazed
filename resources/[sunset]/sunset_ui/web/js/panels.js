const ITEM_ICON_ROOT = 'assets/items/';
const ITEM_ICON_FALLBACK = `${ITEM_ICON_ROOT}backpack.webp`;

function itemIconUrl(icon) {
    const basename = String(icon || 'backpack').trim();
    return /^[a-z0-9_-]+$/i.test(basename)
        ? `${ITEM_ICON_ROOT}${basename}.webp`
        : ITEM_ICON_FALLBACK;
}

function createItemArtwork(row, className) {
    const wrap = document.createElement('div');
    wrap.className = className;
    wrap.setAttribute('aria-hidden', 'true');

    const image = document.createElement('img');
    image.src = itemIconUrl(row?.icon);
    image.alt = '';
    image.loading = 'eager';
    image.addEventListener('error', () => {
        if (!image.src.endsWith('/backpack.webp')) image.src = ITEM_ICON_FALLBACK;
    }, { once: true });
    wrap.appendChild(image);
    return wrap;
}

const Panels = {
    init() {
        if (this._ready) return;
        this._ready = true;

        $('#auth-tab-login')?.addEventListener('click', () => this.setAuthTab('login'));
        $('#auth-tab-register')?.addEventListener('click', () => this.setAuthTab('register'));
        $('#auth-login-btn')?.addEventListener('click', () => {
            if (window.AuthLoading) AuthLoading.beginSubmit();
            post('authLogin', {
                username: $('#auth-login-user')?.value,
                password: $('#auth-login-pass')?.value,
            });
        });
        $('#auth-register-btn')?.addEventListener('click', () => {
            if (window.AuthLoading) AuthLoading.beginSubmit();
            post('authRegister', {
                username: $('#auth-reg-user')?.value,
                password: $('#auth-reg-pass')?.value,
                passwordConfirm: $('#auth-reg-pass2')?.value,
            });
        });

        $('#inventory-close')?.addEventListener('click', () => post('inventoryClose'));
        $('#shop-close')?.addEventListener('click', () => post('shopClose'));
        $('#atm-close')?.addEventListener('click', () => post('atmClose'));
        $('#mdc-close')?.addEventListener('click', () => post('mdcClose'));
        $('#mdc-search-btn')?.addEventListener('click', () => {
            const id = Number($('#mdc-search-id')?.value || 0);
            if (id > 0) post('mdcSearch', { targetId: id });
        });
        $('#mdc-search-id')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') $('#mdc-search-btn')?.click();
        });
        $$('.mdc-tab').forEach((tab) => {
            tab.addEventListener('click', () => this.setMdcTab(tab.dataset.mdcTab));
        });

        $('#ticket-close')?.addEventListener('click', () => post('ticketClose'));
        $('#ticket-issue')?.addEventListener('click', () => {
            post('ticketIssue', {
                targetId: Number($('#ticket-target')?.value || 0),
                reason: $('#ticket-reason')?.value || '',
                violationCode: $('#ticket-violation')?.value || '',
            });
        });
        $('#ticket-pay')?.addEventListener('click', () => post('ticketPay', { ticketId: this._ticketId }));
        $('#ticket-refuse')?.addEventListener('click', () => post('ticketRefuse', { ticketId: this._ticketId }));

        $('#servicecalls-close')?.addEventListener('click', () => post('serviceCallsClose'));
        $('#jobs-close')?.addEventListener('click', () => post('jobsClose'));
        $('#skills-close')?.addEventListener('click', () => post('skillsClose'));
        $('#help-close')?.addEventListener('click', () => post('helpClose'));

        document.addEventListener('keydown', (e) => {
            if (e.key !== 'Escape') return;
            const panels = ['#shop', '#mdc', '#ticket', '#servicecalls', '#jobs-browser', '#skills', '#help', '#properties'];
            for (const sel of panels) {
                const el = $(sel);
                if (el && !el.classList.contains('hidden')) {
                    const map = {
                        '#shop': 'shopClose',
                        '#mdc': 'mdcClose',
                        '#ticket': 'ticketClose',
                        '#servicecalls': 'serviceCallsClose',
                        '#jobs-browser': 'jobsClose',
                        '#skills': 'skillsClose',
                        '#help': 'helpClose',
                        '#properties': 'propertiesClose',
                    };
                    post(map[sel]);
                    e.preventDefault();
                    return;
                }
            }
        });
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
        $('#auth-form-login')?.classList.toggle('is-active', tab === 'login');
        $('#auth-form-login')?.classList.toggle('hidden', tab !== 'login');
        $('#auth-form-register')?.classList.toggle('is-active', tab === 'register');
        $('#auth-form-register')?.classList.toggle('hidden', tab !== 'register');
    },

    showAuth() {
        this.init();
        this.setAuthTab('login');
        document.getElementById('auth-panel')?.classList.remove('is-hidden');
        if (window.LoadingScreen) LoadingScreen.reset();
    },

    hideAuth() {
        $('#screen-auth')?.classList.add('hidden');
        document.getElementById('auth-panel')?.classList.remove('is-hidden');
        if (window.AuthLoading) AuthLoading._pending = false;
    },

    showInventory(data) {
        this.init();
        const list = $('#inventory-list');
        if (!list) return;
        list.innerHTML = '';
        (data.items || []).forEach((row) => {
            const def = row.item || 'unknown';
            let label = row.label || def;
            if (def === 'gas_can' && row.metadata) {
                const maxL = 20;
                let liters = Number(row.metadata.liters);
                if (Number.isNaN(liters) && row.metadata.fuel != null) {
                    liters = (Number(row.metadata.fuel) / 100) * maxL;
                }
                if (!Number.isNaN(liters)) {
                    label = `Gas Can (${Math.round(liters)}/${maxL} L)`;
                }
            }
            if (def === 'fresh_fish' && row.metadata) {
                const value = Math.max(0, Number(row.metadata.value) || 0);
                label = `${row.label || 'Fresh Fish'} ($${Math.round(value)})`;
            }
            const li = document.createElement('li');
            li.className = 'inventory-row';
            li.appendChild(createItemArtwork(row, 'inventory-row__icon'));

            const details = document.createElement('div');
            details.className = 'inventory-row__details';
            const name = document.createElement('strong');
            name.textContent = label;
            const meta = document.createElement('span');
            meta.textContent = `${Math.max(0, Number(row.count) || 0)} unit${Number(row.count) === 1 ? '' : 's'}`;
            details.append(name, meta);
            li.appendChild(details);

            if (row.usable) {
                const useButton = document.createElement('button');
                useButton.type = 'button';
                useButton.textContent = 'USE';
                useButton.addEventListener('click', () => post('inventoryUse', { item: def }));
                li.appendChild(useButton);
            }
            list.appendChild(li);
        });
        const currentWeight = Number(data.weight) || 0;
        $('#inventory-weight').textContent = `${currentWeight.toFixed(1)} / ${Number(data.maxWeight) || 30} KG`;
        $('#inventory')?.classList.remove('hidden');
    },

    hideInventory() { $('#inventory')?.classList.add('hidden'); },

    _shopCategoryLabels: {
        all: 'All',
        food: 'Food',
        drinks: 'Drinks',
        medical: 'Medical',
        supplies: 'Supplies',
        materials: 'Materials',
        tools: 'Tools',
        ammo: 'Ammo',
        misc: 'Misc',
    },

    showShop(data) {
        this.init();
        const shop = data.shop || {};
        const items = shop.items || [];
        this._shopData = data;

        $('#shop-title').textContent = shop.label || 'Shop';
        const sub = $('#shop-subtitle');
        if (sub) sub.textContent = `${items.length} item${items.length === 1 ? '' : 's'} available`;

        const categories = ['all'];
        const seen = new Set();
        items.forEach((row) => {
            const cat = row.category || 'misc';
            if (!seen.has(cat)) {
                seen.add(cat);
                categories.push(cat);
            }
        });

        const tabs = $('#shop-categories');
        const grid = $('#shop-grid');
        if (!tabs || !grid) return;

        const renderItems = (filter) => {
            grid.innerHTML = '';
            const filtered = filter === 'all'
                ? items
                : items.filter((row) => (row.category || 'misc') === filter);

            if (!filtered.length) {
                grid.innerHTML = '<p class="shop-empty">No items in this category</p>';
                return;
            }

            filtered.forEach((row) => {
                const card = document.createElement('article');
                card.className = 'shop-card';
                const weight = row.weight != null ? `${Number(row.weight).toFixed(1)} kg` : '';
                card.appendChild(createItemArtwork(row, 'shop-card__icon'));

                const body = document.createElement('div');
                body.className = 'shop-card__body';
                const name = document.createElement('span');
                name.className = 'shop-card__name';
                name.textContent = row.label || row.item || 'Unknown item';
                body.appendChild(name);
                if (weight) {
                    const meta = document.createElement('span');
                    meta.className = 'shop-card__meta';
                    meta.textContent = `${weight} • ${(row.category || 'misc').toUpperCase()}`;
                    body.appendChild(meta);
                }
                card.appendChild(body);

                const price = document.createElement('span');
                price.className = 'shop-card__price';
                price.textContent = formatMoney(row.price);
                card.appendChild(price);

                const buy = document.createElement('button');
                buy.type = 'button';
                buy.className = 'shop-card__buy';
                buy.textContent = 'BUY';
                buy.setAttribute('aria-label', `Buy ${name.textContent}`);
                buy.addEventListener('click', () => {
                    post('shopBuy', { shopId: data.shopId, item: row.item, amount: 1 });
                });
                card.appendChild(buy);
                grid.appendChild(card);
            });
        };

        tabs.innerHTML = '';
        categories.forEach((cat, idx) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = `shop-tab${idx === 0 ? ' is-active' : ''}`;
            btn.dataset.category = cat;
            btn.textContent = this._shopCategoryLabels[cat] || cat;
            btn.addEventListener('click', () => {
                $$('.shop-tab').forEach((el) => el.classList.toggle('is-active', el === btn));
                renderItems(cat);
            });
            tabs.appendChild(btn);
        });

        if (categories.length <= 2) {
            tabs.classList.add('hidden');
        } else {
            tabs.classList.remove('hidden');
        }

        renderItems('all');
        $('#shop')?.classList.remove('hidden');
    },

    hideShop() { $('#shop')?.classList.add('hidden'); },

    showAtm() { this.init(); $('#atm')?.classList.remove('hidden'); },
    hideAtm() { $('#atm')?.classList.add('hidden'); },

    setMdcTab(tab) {
        $$('.mdc-tab').forEach((el) => el.classList.toggle('is-active', el.dataset.mdcTab === tab));
        $$('.mdc-pane').forEach((el) => el.classList.toggle('is-active', el.dataset.mdcPane === tab));
    },

    showMdc(data) {
        this.init();
        this.setMdcTab('wanted');
        const list = $('#mdc-wanted-list');
        if (!list) return;
        list.innerHTML = '';
        const rows = data?.wanted || [];
        if (rows.length === 0) {
            const li = document.createElement('li');
            li.className = 'mdc-empty';
            li.textContent = 'No active wanted players online';
            list.appendChild(li);
        } else {
            rows.forEach((row) => {
                const li = document.createElement('li');
                const mins = Math.ceil((row.remainingSec || 0) / 60);
                li.innerHTML = `
                    <div>
                        <strong>#${row.id} ${row.name || 'Unknown'}</strong>
                        <div class="mdc-time">${row.reason || '—'} · ${mins}m left</div>
                    </div>
                    <span class="mdc-stars">★${row.level || 1}</span>`;
                list.appendChild(li);
            });
        }

        if (data?.lookup) this.updateMdcLookup(data.lookup);
        $('#mdc')?.classList.remove('hidden');
    },

    updateMdcLookup(data) {
        const result = $('#mdc-result');
        const empty = $('#mdc-lookup-empty');
        if (!data || data.error) {
            result?.classList.add('hidden');
            if (empty) {
                empty.textContent = data?.error || 'No record found.';
                empty.classList.remove('hidden');
            }
            return;
        }

        empty?.classList.add('hidden');
        result?.classList.remove('hidden');
        $('#mdc-result-name').textContent = data.name || 'Unknown';
        $('#mdc-result-id').textContent = `#${data.id || 0}`;
        $('#mdc-result-wanted').textContent = data.wanted
            ? `★${data.wantedLevel || 1} — ${data.wantedReason || 'Active'}`
            : 'Clear';
        $('#mdc-result-jail').textContent = data.jailed
            ? `${data.jailMinutes || 0} min remaining`
            : 'Not jailed';
        $('#mdc-result-fines').textContent = data.finesOwed
            ? formatMoney(data.finesOwed)
            : '$0';

        const charges = $('#mdc-charges-list');
        if (!charges) return;
        charges.innerHTML = '';
        const rows = data.charges || [];
        if (!rows.length) {
            const li = document.createElement('li');
            li.textContent = 'No charges on record';
            charges.appendChild(li);
        } else {
            rows.forEach((row) => {
                const li = document.createElement('li');
                li.innerHTML = `<span>${row.reason || row.label || '—'}</span><span>${row.date || formatMoney(row.amount || 0)}</span>`;
                charges.appendChild(li);
            });
        }
    },

    hideMdc() { $('#mdc')?.classList.add('hidden'); },

    showTicket(data = {}) {
        this.init();
        const target = $('#ticket-target');
        const violation = $('#ticket-violation');
        const amount = $('#ticket-amount');
        const reason = $('#ticket-reason');
        target.value = data.targetId || '';
        violation.innerHTML = '<option value="">Select a violation...</option>';
        (data.violations || []).forEach((row) => {
            const option = document.createElement('option');
            option.value = row.code;
            option.textContent = `${row.label} — $${Number(row.amount || 0).toLocaleString()} (${row.code})`;
            option.dataset.amount = row.amount || 0;
            option.dataset.label = row.label || row.code;
            violation.appendChild(option);
        });
        const syncViolation = () => {
            const option = violation.options[violation.selectedIndex];
            amount.value = option?.value ? option.dataset.amount : '';
            reason.value = option?.value ? option.dataset.label : '';
        };
        violation.onchange = syncViolation;
        syncViolation();
        $('#ticket')?.classList.remove('hidden');
    },
    hideTicket() { $('#ticket')?.classList.add('hidden'); },

    showTicketReceive(data) {
        this.init();
        this._ticketId = data?.ticketId || data?.id;
        $('#ticket-receive-officer').textContent = data?.officer
            ? `Issued by ${data.officer}${data.officerId ? ` #${data.officerId}` : ''}`
            : 'Issued by Law Enforcement';
        $('#ticket-receive-amount').textContent = formatMoney(data?.amount || 0);
        $('#ticket-receive-reason').textContent = data?.reason || 'Traffic violation';
        $('#ticket-receive')?.classList.remove('hidden');
    },

    hideTicketReceive() { $('#ticket-receive')?.classList.add('hidden'); },

    showServiceCalls(data) {
        this.init();
        const list = $('#servicecalls-list');
        const calls = data?.calls || [];
        $('#servicecalls-count').textContent = `${calls.length} active`;
        list.innerHTML = '';

        if (!calls.length) {
            list.innerHTML = '<li class="servicecalls-empty">No active service calls</li>';
        } else {
            calls.forEach((call) => {
                const li = document.createElement('li');
                const statusClass = `sc-status--${call.status || 'open'}`;
                const canAccept = call.canAccept === true && call.status === 'open';
                li.innerHTML = `
                    <div>
                        <div class="sc-type">${call.typeLabel || call.type || 'CALL'}</div>
                        <div class="sc-title">${call.title || call.message || 'Service request'}</div>
                        <div class="sc-meta">${call.location || call.zone || ''}${call.caller ? ` · ${call.caller}` : ''}</div>
                    </div>
                    <span class="sc-status ${statusClass}">${call.status || 'open'}</span>
                    ${canAccept ? `<button type="button" data-call-id="${call.id}">ACCEPT</button>` : ''}`;
                li.querySelector('button')?.addEventListener('click', () => {
                    post('serviceCallsAccept', { callId: call.id });
                });
                list.appendChild(li);
            });
        }
        $('#servicecalls')?.classList.remove('hidden');
    },

    hideServiceCalls() { $('#servicecalls')?.classList.add('hidden'); },

    showJobsBrowser(data) {
        this.init();
        const grid = $('#jobs-grid');
        const currentWrap = $('#jobs-current');
        const currentJob = data?.currentJob;

        if (currentJob) {
            currentWrap?.classList.remove('hidden');
            $('#jobs-current-label').textContent = currentJob.label || currentJob.id || '—';
        } else {
            currentWrap?.classList.add('hidden');
        }

        grid.innerHTML = '';
        (data?.jobs || []).forEach((job) => {
            const isCurrent = currentJob && (currentJob.id === job.id);
            const card = document.createElement('div');
            card.className = `job-card${isCurrent ? ' is-current' : ''}`;
            const xpText = job.xp !== undefined ? `Lv ${job.level || 1} · ${job.xp || 0} XP` : '';
            card.innerHTML = `
                <div class="job-card__top">
                    <span class="job-card__name">${job.label || job.id}</span>
                    <span class="job-card__pay">$${job.salary || 0}/hr</span>
                </div>
                <p class="job-card__desc">${job.description || 'No description'}</p>
                ${xpText ? `<span class="job-card__xp">${xpText}</span>` : ''}
                <button type="button" class="job-card__btn${isCurrent ? ' job-card__btn--active' : ''}" ${isCurrent ? 'disabled' : ''}>
                    ${isCurrent ? 'CURRENT JOB' : (job.canSelect === false ? 'LOCKED' : 'SELECT')}
                </button>`;
            const btn = card.querySelector('button');
            if (!isCurrent && job.canSelect !== false) {
                btn?.addEventListener('click', () => post('jobsSelect', { jobId: job.id, jobLabel: job.label }));
            }
            grid.appendChild(card);
        });

        if (!(data?.jobs || []).length) {
            grid.innerHTML = '<p class="mdc-empty">No jobs available</p>';
        }
        $('#jobs-browser')?.classList.remove('hidden');
    },

    hideJobsBrowser() { $('#jobs-browser')?.classList.add('hidden'); },

    showSkills(data) {
        this.init();
        const list = $('#skills-list');
        list.innerHTML = '';
        const skills = data?.skills || [];

        if (!skills.length) {
            list.innerHTML = '<li class="skills-empty">No skills tracked yet. Start a job to earn XP.</li>';
        } else {
            skills.forEach((skill) => {
                const li = document.createElement('li');
                const xp = skill.xp || 0;
                const xpNext = skill.xpNext || 100;
                const pct = xpNext > 0 ? Math.min(100, Math.round((xp / xpNext) * 100)) : 0;
                li.innerHTML = `
                    <div class="skill-row__head">
                        <span class="skill-row__name">${skill.label || skill.id}</span>
                        <span class="skill-row__level">LEVEL ${skill.level || 1}</span>
                    </div>
                    <div class="skill-row__bar"><div class="skill-row__fill" style="width:${pct}%"></div></div>
                    <div class="skill-row__xp">${xp.toLocaleString()} / ${xpNext.toLocaleString()} XP</div>`;
                list.appendChild(li);
            });
        }
        $('#skills')?.classList.remove('hidden');
    },

    hideSkills() { $('#skills')?.classList.add('hidden'); },

    showHelp(data) {
        this.init();
        const body = $('#help-body');
        const sub = $('#help-sub');
        if (!body) return;

        const categories = data?.categories || [];
        if (sub) {
            const bits = [];
            if (data?.onDuty) bits.push('On duty');
            if (data?.adminLevel && data.adminLevel > 0) bits.push('Admin L' + data.adminLevel);
            sub.textContent = bits.length ? bits.join(' · ') : 'Available for you right now';
        }

        body.innerHTML = '';
        if (!categories.length) {
            body.innerHTML = '<p class="help-empty">No commands available.</p>';
        } else {
            categories.forEach((cat) => {
                const section = document.createElement('section');
                section.className = 'help-section';
                section.innerHTML = `<h3 class="help-section__title">${cat.title || 'Commands'}</h3>`;
                const list = document.createElement('ul');
                list.className = 'help-list';
                (cat.entries || []).forEach((row) => {
                    const li = document.createElement('li');
                    li.innerHTML = `<span class="help-cmd">${row.cmd || '—'}</span><span class="help-desc">${row.desc || ''}</span>`;
                    list.appendChild(li);
                });
                if (!(cat.entries || []).length) {
                    const li = document.createElement('li');
                    li.className = 'help-empty';
                    li.textContent = 'No commands in this category';
                    list.appendChild(li);
                }
                section.appendChild(list);
                body.appendChild(section);
            });
        }
        $('#help')?.classList.remove('hidden');
    },

    hideHelp() { $('#help')?.classList.add('hidden'); },

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
                addBtn(actions, 'GPS', '', () => post('garageLocate', { plate: v.plate, vehicleId: v.id }));
                addBtn(actions, 'Store', 'menu-vcard__btn--primary', () => post('garageStore', { vehicleId: v.id }));
            } else {
                addBtn(actions, 'GPS', '', () => post('garageLocate', { plate: v.plate, vehicleId: v.id }));
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
            const li = document.createElement('li');
            li.className = `house-row${Number(data.selectedId) === Number(p.id) ? ' is-selected' : ''}`;
            const status = p.owned ? 'YOUR HOUSE' : p.rented ? 'YOUR RENTAL'
                : p.owner_character_id ? (p.rentEnabled ? `RENT $${Number(p.rentPrice).toLocaleString()}/PAYDAY` : 'OWNED')
                : (p.forSale ? `$${Number(p.price).toLocaleString()}` : 'NOT FOR SALE');
            const details = document.createElement('div');
            details.className = 'house-row__details';
            const name = document.createElement('strong');
            name.textContent = `#${p.id} ${p.label || 'House'}`;
            const meta = document.createElement('span');
            meta.textContent = `Level ${p.minimumLevel || 1} · ${p.interior || 'standard'} · ${p.locked ? 'Locked' : 'Unlocked'}${p.ownerName ? ` · Owner: ${p.ownerName}` : ''}`;
            const rental = document.createElement('small');
            rental.textContent = p.owner_character_id
                ? `${p.renterCount || 0}/${p.maxRenters || 1} rental slots used` : 'Available for purchase';
            details.append(name, meta, rental);
            const side = document.createElement('div');
            side.className = 'house-row__side';
            const badge = document.createElement('b');
            badge.textContent = status;
            side.appendChild(badge);
            const actions = document.createElement('div');
            actions.className = 'house-row__actions';
            const button = (label, action, primary = false) => {
                const el = document.createElement('button');
                el.type = 'button'; el.textContent = label;
                if (primary) el.className = 'is-primary';
                el.addEventListener('click', () => post('propertyAction', { propertyId: p.id, action }));
                actions.appendChild(el);
            };
            if (p.access || !p.locked) button('Enter', 'enter', true);
            if (!p.owner_character_id && p.forSale) button('Buy', 'buy', true);
            if (p.owner_character_id && !p.access && p.rentEnabled && Number(p.renterCount) < Number(p.maxRenters)) button('Rent', 'rent', true);
            if (p.access) button('Set spawn', 'sethome');
            if (p.owned) button(p.locked ? 'Unlock' : 'Lock', 'lock');
            side.appendChild(actions);
            li.append(details, side);
            list.appendChild(li);
        });
        if (!(data.properties || []).length) list.innerHTML = '<li class="house-empty">No houses have been created yet. An administrator can use /acreatehouse.</li>';
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
            if (hint) hint.textContent = 'Choose a hairstyle. $50 per change.';
            this.barberHair = data.hair ?? this.barberHair ?? 0;

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
        } else {
            if (hint) hint.textContent = 'Choose a top (torso). $50 per change.';
            this.clothingDrawable = data.drawable ?? this.clothingDrawable ?? 0;

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

    showJobsPanel(data) {
        this.init();
        const d = data || {};
        $('#jobs-panel-title').textContent = 'Jobs';
        $('#jobs-panel-current').textContent = `Current: ${d.currentJobLabel || d.currentJob || 'Unemployed'}`;

        const sessionEl = $('#jobs-panel-session');
        if (d.session) {
            sessionEl.textContent = `Active shift: ${d.session.jobId} (${d.session.state})`;
            sessionEl.classList.remove('hidden');
        } else {
            sessionEl.classList.add('hidden');
        }

        const list = $('#jobs-panel-list');
        list.innerHTML = '';
        (d.jobs || []).forEach((job) => {
            const prog = job.progress;
            const skill = prog ? `Lv.${prog.level} · ${prog.completedTasks || 0} tasks` : 'No XP yet';
            const li = document.createElement('li');
            li.innerHTML = `<div class="craft-row"><strong>${job.label}</strong><span class="craft-meta">$${job.salary || 0}/hr · ${skill}</span><span class="craft-meta">${job.description || ''}</span></div>`;
            list.appendChild(li);
        });

        $('#jobs-panel-work').onclick = () => post('jobsStartWork');
        $('#jobs-panel-cancel').onclick = () => post('jobsCancelWork');
        $('#jobs-panel-close').onclick = () => post('jobsClose');
        $('#jobs-panel')?.classList.remove('hidden');
    },
    hideJobsPanel() { $('#jobs-panel')?.classList.add('hidden'); },

    showCrafting(data) {
        this.init();
        this._craftStation = data.stationId;
        $('#crafting-title').textContent = data.stationLabel || 'Crafting';
        const list = $('#crafting-list');
        list.innerHTML = '';
        if (data.stationHint) {
            const hint = document.createElement('li');
            hint.className = 'craft-meta';
            hint.textContent = data.stationHint;
            list.appendChild(hint);
        }
        (data.recipes || []).forEach((recipe) => {
            const li = document.createElement('li');
            const row = document.createElement('div');
            row.className = 'craft-row';
            const title = document.createElement('strong');
            title.textContent = recipe.label || recipe.id;
            row.appendChild(title);
            (recipe.inputList || []).forEach((input) => {
                const need = document.createElement('span');
                need.className = `craft-meta ${(Number(input.owned) || 0) >= (Number(input.count) || 0) ? 'craft-meta--ok' : 'craft-meta--missing'}`;
                need.textContent = `${input.label}: ${input.owned || 0}/${input.count || 0}`;
                row.appendChild(need);
            });
            const outLabel = recipe.outputLabel || recipe.output?.item || '?';
            const outCount = recipe.output?.count || 1;
            const output = document.createElement('span');
            output.className = 'craft-meta';
            output.textContent = `Produces: ${outLabel} x${outCount}`;
            row.appendChild(output);
            if (recipe.lockedReason) {
                const locked = document.createElement('span');
                locked.className = 'craft-lock';
                locked.textContent = recipe.lockedReason;
                row.appendChild(locked);
            }
            const button = document.createElement('button');
            button.textContent = recipe.canCraft ? 'CRAFT' : 'REQUIREMENTS NOT MET';
            button.disabled = !recipe.canCraft;
            button.addEventListener('click', () => post('craftingCraft', {
                stationId: this._craftStation,
                recipeId: recipe.id,
            }));
            row.appendChild(button);
            li.appendChild(row);
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

    showDealership(data) {
        this.init();
        const opening = $('#dealership')?.classList.contains('hidden');
        this._dealerData = { ...(this._dealerData || {}), ...(data || {}) };
        this._dealerVehicles = this._dealerData.vehicles || [];
        if (opening) this._dealerSelected = null;
        $('#dealership-title').textContent = this._dealerData.dealership || 'Vehicle Dealership';
        const money = this._dealerData.money;
        $('#dealership-balance').textContent = money
            ? `BANK ${formatMoney(Number(money.bank) || 0)}  ·  CASH ${formatMoney(Number(money.cash) || 0)}`
            : (this._dealerData.admin ? 'Administrative catalog — every change is audited' : 'Select a vehicle to inspect it');
        $('#dealership-admin')?.classList.toggle('hidden', !this._dealerData.admin);

        const category = $('#dealership-category');
        const brand = $('#dealership-brand');
        const selectedCategory = category.value;
        const selectedBrand = brand.value;
        const fillOptions = (select, values, first) => {
            select.innerHTML = '';
            const base = document.createElement('option');
            base.value = '';
            base.textContent = first;
            select.appendChild(base);
            [...new Set(values.filter(Boolean))].sort().forEach((value) => {
                const option = document.createElement('option');
                option.value = value;
                option.textContent = value;
                select.appendChild(option);
            });
        };
        fillOptions(category, this._dealerVehicles.map((v) => v.category), 'All categories');
        fillOptions(brand, this._dealerVehicles.map((v) => v.brand), 'All brands');
        category.value = selectedCategory;
        brand.value = selectedBrand;

        const render = () => this._renderDealership();
        $('#dealership-search').oninput = render;
        category.onchange = render;
        brand.onchange = render;
        $('#dealership-instock').onchange = render;
        $('#dealership-close').onclick = () => post('dealershipClose');
        $('#dealership-rotate-left').onclick = () => post('dealershipRotate', { direction: -1 });
        $('#dealership-rotate-right').onclick = () => post('dealershipRotate', { direction: 1 });
        $('#dealership-admin-new').onclick = () => this._fillDealerAdmin(null);
        $('#dealership-admin-save').onclick = () => post('dealershipAdminSave', {
            model: $('#dealer-model').value,
            label: $('#dealer-label').value,
            brand: $('#dealer-brand').value,
            category: $('#dealer-category').value,
            price: Number($('#dealer-price').value),
            stock: Number($('#dealer-stock').value),
            displayOrder: Number($('#dealer-order').value),
            available: $('#dealer-available').checked,
            testDriveEnabled: $('#dealer-testdrive').checked,
        });
        $('#dealership-admin-delete').onclick = () => {
            const model = $('#dealer-model').value;
            if (model && window.confirm(`Remove ${model} from the dealership catalog?`)) {
                post('dealershipAdminDelete', { model });
            }
        };
        this._renderDealership();
        $('#dealership')?.classList.remove('hidden');
        if (opening && this._dealerSelected) {
            post('dealershipSelect', { model: this._dealerSelected });
        }
    },

    _renderDealership() {
        const list = $('#dealership-list');
        if (!list) return;
        const query = ($('#dealership-search').value || '').trim().toLowerCase();
        const category = $('#dealership-category').value;
        const brand = $('#dealership-brand').value;
        const inStock = $('#dealership-instock').checked;
        const rows = (this._dealerVehicles || []).filter((v) => {
            const haystack = `${v.model} ${v.label} ${v.brand}`.toLowerCase();
            return (!query || haystack.includes(query))
                && (!category || v.category === category)
                && (!brand || v.brand === brand)
                && (!inStock || Number(v.stock) > 0);
        });
        list.innerHTML = '';
        rows.forEach((vehicle) => {
            const card = document.createElement('button');
            card.type = 'button';
            card.className = `dealership-card ${this._dealerSelected === vehicle.model ? 'is-active' : ''}`;
            const top = document.createElement('div');
            top.className = 'dealership-card__top';
            const name = document.createElement('span');
            name.textContent = vehicle.label || vehicle.model;
            const price = document.createElement('span');
            price.textContent = formatMoney(Number(vehicle.price) || 0);
            top.append(name, price);
            const meta = document.createElement('div');
            meta.className = 'dealership-card__meta';
            const identity = document.createElement('span');
            identity.textContent = `${vehicle.brand || 'Other'} · ${vehicle.category || 'other'}`;
            const stock = document.createElement('span');
            stock.className = Number(vehicle.stock) > 0 ? '' : 'dealership-card__stock--out';
            stock.textContent = Number(vehicle.stock) > 0 ? `${vehicle.stock} in stock` : 'sold out';
            meta.append(identity, stock);
            card.append(top, meta);
            card.onclick = () => {
                this._dealerSelected = vehicle.model;
                post('dealershipSelect', { model: vehicle.model });
                this._renderDealership();
                if (this._dealerData.admin) this._fillDealerAdmin(vehicle);
            };
            list.appendChild(card);
        });
        if (!rows.length) {
            const empty = document.createElement('p');
            empty.className = 'craft-meta';
            empty.textContent = 'No vehicles match these filters.';
            list.appendChild(empty);
        }
        let selected = rows.find((v) => v.model === this._dealerSelected);
        if (!selected && rows.length) {
            selected = rows[0];
            this._dealerSelected = selected.model;
        }
        this._renderDealerDetail(selected);
    },

    _renderDealerDetail(vehicle) {
        const detail = $('#dealership-detail');
        detail.innerHTML = '';
        if (!vehicle) {
            detail.textContent = 'Select a vehicle from the catalog.';
            return;
        }
        const brand = document.createElement('div');
        brand.className = 'dealership__detail-brand';
        brand.textContent = `${vehicle.brand || 'Other'} · ${vehicle.category || 'other'} · ${vehicle.model}`;
        const name = document.createElement('h3');
        name.textContent = vehicle.label || vehicle.model;
        const price = document.createElement('div');
        price.className = 'dealership__detail-price';
        price.textContent = formatMoney(Number(vehicle.price) || 0);
        const stock = document.createElement('div');
        stock.className = 'dealership__detail-stock';
        stock.textContent = Number(vehicle.stock) > 0 ? `${vehicle.stock} vehicle(s) currently available` : 'Currently sold out';
        detail.append(brand, name, price, stock);
        if (!this._dealerData.admin) {
            const actions = document.createElement('div');
            actions.className = 'dealership__detail-actions';
            const buy = document.createElement('button');
            buy.textContent = Number(vehicle.stock) > 0 ? 'BUY — STORED AT LEGION' : 'SOLD OUT';
            buy.disabled = Number(vehicle.stock) <= 0;
            buy.onclick = () => post('dealershipBuy', { model: vehicle.model });
            const test = document.createElement('button');
            test.className = 'secondary';
            test.textContent = `TEST DRIVE — ${this._dealerData.testDriveSeconds || 60}s`;
            test.disabled = !(vehicle.test_drive_enabled === true || Number(vehicle.test_drive_enabled) === 1);
            test.onclick = () => post('dealershipTestDrive', { model: vehicle.model });
            actions.append(buy, test);
            detail.appendChild(actions);
        }
    },

    _fillDealerAdmin(vehicle) {
        const value = (id, val = '') => { $(id).value = val; };
        value('#dealer-model', vehicle?.model || '');
        value('#dealer-label', vehicle?.label || '');
        value('#dealer-brand', vehicle?.brand || '');
        value('#dealer-category', vehicle?.category || '');
        value('#dealer-price', vehicle?.price || '');
        value('#dealer-stock', vehicle?.stock ?? 0);
        value('#dealer-order', vehicle?.display_order ?? 100);
        $('#dealer-model').readOnly = Boolean(vehicle);
        $('#dealer-available').checked = vehicle ? Number(vehicle.available) === 1 : true;
        $('#dealer-testdrive').checked = vehicle ? Number(vehicle.test_drive_enabled) === 1 : true;
    },

    hideDealership() {
        $('#dealership')?.classList.add('hidden');
        this._dealerSelected = null;
    },

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
