const PropertyUI = {
    meta: null,
    sellPending: {},
    activeFilter: 'all',
    searchQuery: '',
    _controlsBound: false,

    setMeta(meta) {
        this.meta = meta || null;
    },

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    cleanText(text) {
        if (!text) return '';
        return String(text)
            .replace(/\[\/?b\]/gi, '')
            .replace(/\[\/?i\]/gi, '')
            .replace(/\[\/?u\]/gi, '')
            .replace(/~[a-z0-9]~/gi, '')
            .trim();
    },

    money(value) {
        return `$${Number(value || 0).toLocaleString()}`;
    },

    dispatch(propertyId, action, payload) {
        post('propertyAction', {
            propertyId: Number(propertyId),
            action,
            payload: payload || {},
        });
    },

    statusLabel(p) {
        if (p.owned) return 'YOUR PROPERTY';
        if (p.rented) return 'RENTING';
        if (p.owner_character_id) {
            return p.rentEnabled
                ? `RENT ${this.money(p.rentPrice)}/PAYDAY`
                : 'OCCUPIED';
        }
        return p.forSale ? this.money(p.price) : 'UNAVAILABLE';
    },

    createButton(label, action, propertyId, payload, primary = false) {
        const el = document.createElement('button');
        el.type = 'button';
        el.textContent = label;
        if (primary) el.className = 'is-primary';
        el.addEventListener('click', () => this.dispatch(propertyId, action, payload));
        return el;
    },

    createOwnerTools(p, container) {
        const meta = this.meta || {};
        const tools = document.createElement('div');
        tools.className = 'house-owner-tools';

        const title = document.createElement('div');
        title.className = 'house-owner-tools__title';
        title.textContent = 'OWNER CONTROLS';
        tools.appendChild(title);

        const descRow = document.createElement('div');
        descRow.className = 'house-owner-tools__row';
        const descInput = document.createElement('textarea');
        descInput.className = 'house-owner-tools__textarea';
        descInput.maxLength = 160;
        descInput.placeholder = 'House description shown to visitors (max 160 chars)';
        descInput.value = this.cleanText(p.description || '');
        const descActions = document.createElement('div');
        descActions.className = 'house-owner-tools__inline-actions';
        const saveDesc = document.createElement('button');
        saveDesc.type = 'button';
        saveDesc.textContent = 'Save description';
        saveDesc.addEventListener('click', () => this.dispatch(p.id, 'description', { text: descInput.value.trim() }));
        descActions.append(saveDesc, this.createButton('Clear', 'description', p.id, { clear: true }));
        descRow.append(descInput, descActions);
        tools.appendChild(descRow);

        const rentRow = document.createElement('div');
        rentRow.className = 'house-owner-tools__row';
        const rentInput = document.createElement('input');
        rentInput.type = 'number';
        rentInput.className = 'house-owner-tools__input';
        rentInput.min = meta.rentMin || 50;
        rentInput.max = meta.rentMax || 5000;
        rentInput.value = String(p.rentPrice || meta.rentMin || 50);
        const rentActions = document.createElement('div');
        rentActions.className = 'house-owner-tools__inline-actions';
        const rentOn = document.createElement('button');
        rentOn.type = 'button';
        rentOn.textContent = p.rentEnabled ? 'Update rent' : 'Enable rent';
        rentOn.addEventListener('click', () => this.dispatch(p.id, 'rent_on', { price: Number(rentInput.value) }));
        rentActions.append(rentOn, this.createButton('Disable rent', 'rent_off', p.id, {}));
        const rentHint = document.createElement('small');
        rentHint.style.color = 'rgba(255, 255, 255, 0.45)';
        rentHint.textContent = `Rent per payday: $${rentInput.min}–$${rentInput.max}`;
        rentRow.append(rentInput, rentActions, rentHint);
        tools.appendChild(rentRow);

        const slotsRow = document.createElement('div');
        slotsRow.className = 'house-owner-tools__row';
        const slotsInput = document.createElement('input');
        slotsInput.type = 'number';
        slotsInput.className = 'house-owner-tools__input';
        slotsInput.min = meta.maxRentersMin || 1;
        slotsInput.max = meta.maxRentersMax || 10;
        slotsInput.value = String(p.maxRenters || 1);
        const slotsBtn = document.createElement('button');
        slotsBtn.type = 'button';
        slotsBtn.textContent = 'Set max renters';
        slotsBtn.addEventListener('click', () => this.dispatch(p.id, 'max_renters', { count: Number(slotsInput.value) }));
        slotsRow.append(slotsInput, slotsBtn);
        tools.appendChild(slotsRow);

        const interiorRow = document.createElement('div');
        interiorRow.className = 'house-owner-tools__row';
        const interiorSelect = document.createElement('select');
        interiorSelect.className = 'house-owner-tools__select';
        (meta.interiors || []).forEach((item) => {
            const opt = document.createElement('option');
            opt.value = item.id;
            opt.textContent = item.label;
            if (item.id === p.interior) opt.selected = true;
            interiorSelect.appendChild(opt);
        });
        const interiorBtn = document.createElement('button');
        interiorBtn.type = 'button';
        interiorBtn.textContent = 'Change interior';
        interiorBtn.addEventListener('click', () => this.dispatch(p.id, 'interior', { key: interiorSelect.value }));
        interiorRow.append(interiorSelect, interiorBtn);
        tools.appendChild(interiorRow);

        const rentersRow = document.createElement('div');
        rentersRow.className = 'house-owner-tools__row house-owner-tools__renters';
        const rentersList = document.createElement('div');
        rentersList.className = 'house-owner-tools__renter-list';
        rentersList.textContent = 'Loading renters...';
        const loadRenters = document.createElement('button');
        loadRenters.type = 'button';
        loadRenters.textContent = 'Refresh renters';
        loadRenters.addEventListener('click', () => {
            rentersList.textContent = 'Loading renters...';
            post('propertyRenters', { propertyId: p.id });
        });
        rentersRow.append(loadRenters, rentersList);
        tools.appendChild(rentersRow);
        container._rentersList = rentersList;
        container._propertyId = p.id;

        const sellRefund = Math.floor((Number(p.price) || 0) * ((meta.sellRefundPercent || 70) / 100));
        const sellBtn = this.createButton(`Sell house (${this.money(sellRefund)})`, 'sell', p.id, { confirm: false });
        sellBtn.className = 'house-owner-tools__sell';
        sellBtn.addEventListener('click', (event) => {
            event.stopPropagation();
            const key = String(p.id);
            if (!this.sellPending[key]) {
                this.sellPending[key] = true;
                sellBtn.textContent = `Confirm sell for ${this.money(sellRefund)}`;
                sellBtn.classList.add('is-danger');
                return;
            }
            this.sellPending[key] = false;
            this.dispatch(p.id, 'sell', { confirm: true });
        });
        tools.appendChild(sellBtn);

        return tools;
    },

    createRow(p, selectedId) {
        const li = document.createElement('li');
        const isSelected = Number(selectedId) === Number(p.id);
        const statusClass = p.owned ? 'is-owned' : (p.rented ? 'is-rented' : (p.owner_character_id ? 'is-occupied' : (p.forSale ? 'is-for-sale' : '')));

        li.className = `house-row${isSelected ? ' is-selected' : ''} ${statusClass}`;
        li.dataset.propertyId = String(p.id);
        li.dataset.forSale = String(Boolean(!p.owner_character_id && p.forSale));
        li.dataset.owned = String(Boolean(p.owned));
        li.dataset.rent = String(Boolean(p.rentEnabled || p.rented));
        li.dataset.name = String(p.label || '').toLowerCase();

        const details = document.createElement('div');
        details.className = 'house-row__details';

        // Title Wrap (#ID + Label)
        const titleWrap = document.createElement('div');
        titleWrap.className = 'house-row__title-wrap';
        titleWrap.innerHTML = `
            <span class="prop-chip prop-chip--lvl">#${p.id}</span>
            <strong>${this.escape(p.label || 'Residence')}</strong>
        `;
        details.appendChild(titleWrap);

        // Meta Chips (Level, Interior, Locked/Open, Owner)
        const chipsWrap = document.createElement('div');
        chipsWrap.className = 'house-row__chips';
        const levelChip = `<span class="prop-chip prop-chip--lvl">LVL ${p.minimumLevel || 1}</span>`;
        const interiorChip = `<span class="prop-chip prop-chip--interior">${this.escape(p.interior || 'Standard')}</span>`;
        const lockChip = `<span class="prop-chip prop-chip--${p.locked ? 'locked' : 'open'}">${p.locked ? '🔒 LOCKED' : '🔓 OPEN'}</span>`;
        const ownerChip = p.ownerName ? `<span class="prop-chip prop-chip--owner">👤 ${this.escape(p.ownerName)}</span>` : '';
        chipsWrap.innerHTML = `${levelChip}${interiorChip}${lockChip}${ownerChip}`;
        details.appendChild(chipsWrap);

        // Rental / Sale Info
        const rental = document.createElement('div');
        rental.className = 'house-row__rental-info';
        rental.textContent = p.owner_character_id
            ? `Renters ${p.renterCount || 0}/${p.maxRenters || 1} · ${p.rentEnabled ? `Rent: ${this.money(p.rentPrice)}/payday` : 'Rent not active'}`
            : (p.forSale ? `For sale · Requires character level ${p.minimumLevel || 1}` : 'Not listed for sale');
        details.appendChild(rental);

        // Description Quote (clean BBCode)
        const cleanDescription = this.cleanText(p.description);
        if (cleanDescription) {
            const description = document.createElement('div');
            description.className = 'house-row__description';
            description.textContent = `“${cleanDescription}”`;
            details.appendChild(description);
        }

        const side = document.createElement('div');
        side.className = 'house-row__side';
        const badge = document.createElement('b');
        badge.textContent = this.statusLabel(p);
        side.appendChild(badge);

        const actions = document.createElement('div');
        actions.className = 'house-row__actions';
        const button = (label, action, primary = false, payload = {}) => {
            actions.appendChild(this.createButton(label, action, p.id, payload, primary));
        };

        if (p.access || !p.locked) button('Enter', 'enter', true);
        if (!p.owner_character_id && p.forSale) button('Purchase', 'buy', true);
        if (p.owner_character_id && !p.access && p.rentEnabled && Number(p.renterCount) < Number(p.maxRenters)) {
            button('Rent', 'rent', true);
        } else if (p.owner_character_id && !p.access && !p.rentEnabled) {
            const hint = document.createElement('small');
            hint.className = 'house-row__rent-hint';
            hint.textContent = 'Owner is not accepting renters right now.';
            details.appendChild(hint);
        } else if (p.owner_character_id && !p.access && p.rentEnabled && Number(p.renterCount) >= Number(p.maxRenters)) {
            const hint = document.createElement('small');
            hint.className = 'house-row__rent-hint';
            hint.textContent = 'All rental slots are full.';
            details.appendChild(hint);
        }
        if (p.access) button('Set home', 'sethome');
        if (p.rented) button('End lease', 'unrent');
        if (p.owned) button(p.locked ? 'Unlock' : 'Lock', 'lock');

        if (p.owned) {
            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.textContent = 'Manage';
            toggle.addEventListener('click', (event) => {
                event.stopPropagation();
                const existing = li.querySelector('.house-owner-tools');
                if (existing) {
                    existing.remove();
                    toggle.textContent = 'Manage';
                    return;
                }
                toggle.textContent = 'Hide controls';
                details.appendChild(this.createOwnerTools(p, details));
                post('propertyRenters', { propertyId: p.id });
            });
            actions.appendChild(toggle);
        }

        side.appendChild(actions);
        li.append(details, side);
        return li;
    },

    applyFilters() {
        const query = (this.searchQuery || '').toLowerCase().trim();
        const filter = this.activeFilter || 'all';
        const rows = document.querySelectorAll('#properties-list .house-row');
        let visibleCount = 0;

        rows.forEach((row) => {
            const name = row.dataset.name || '';
            const id = row.dataset.propertyId || '';
            const forSale = row.dataset.forSale === 'true';
            const owned = row.dataset.owned === 'true';
            const rent = row.dataset.rent === 'true';

            const matchesQuery = !query || name.includes(query) || id.includes(query);
            let matchesFilter = true;

            if (filter === 'for-sale') matchesFilter = forSale;
            else if (filter === 'owned') matchesFilter = owned;
            else if (filter === 'rent') matchesFilter = rent;

            const show = matchesQuery && matchesFilter;
            row.classList.toggle('is-filtered-out', !show);
            if (show) visibleCount++;
        });

        const empty = document.querySelector('#properties-list .house-empty');
        if (empty) empty.style.display = visibleCount === 0 ? 'block' : 'none';
    },

    setupControls() {
        if (this._controlsBound) return;
        this._controlsBound = true;

        const searchInput = document.getElementById('properties-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchQuery = e.target.value;
                this.applyFilters();
            });
        }

        const filterBtns = document.querySelectorAll('.house-filter-btn');
        filterBtns.forEach((btn) => {
            btn.addEventListener('click', () => {
                filterBtns.forEach((b) => b.classList.remove('is-active'));
                btn.classList.add('is-active');
                this.activeFilter = btn.dataset.filter || 'all';
                this.applyFilters();
            });
        });
    },

    renderList(container, data) {
        if (!container) return;
        container.innerHTML = '';
        this.setMeta(data.meta);
        this.setupControls();

        const properties = data.properties || [];
        properties.forEach((p) => container.appendChild(this.createRow(p, data.selectedId)));
        if (!properties.length) {
            container.innerHTML = '<li class="house-empty">No houses have been created yet. An administrator can use /acreatehouse.</li>';
        }
        this.applyFilters();
    },

    updateRenters(propertyId, renters) {
        document.querySelectorAll('.house-owner-tools__renter-list').forEach((list) => {
            const host = list.closest('.house-row__details');
            if (!host || Number(host.closest('.house-row')?.dataset.propertyId) !== Number(propertyId)) return;
            list.replaceChildren();
            if (!(renters || []).length) {
                list.textContent = 'No active renters.';
                return;
            }
            renters.forEach((row) => {
                const item = document.createElement('div');
                item.className = 'house-owner-tools__renter';
                const label = document.createElement('span');
                label.textContent = `#${row.character_id} ${row.name || 'Resident'} · ${this.money(row.rent_price)}/payday`;
                const kick = this.createButton('Kick', 'kick_renter', propertyId, { characterId: row.character_id });
                item.append(label, kick);
                list.appendChild(item);
            });
        });
    },
};

window.PropertyUI = PropertyUI;
