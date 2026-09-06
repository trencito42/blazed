const PropertyUI = {
    meta: null,
    sellPending: {},

    setMeta(meta) {
        this.meta = meta || null;
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
        if (p.owned) return 'YOUR HOUSE';
        if (p.rented) return 'YOUR RENTAL';
        if (p.owner_character_id) {
            return p.rentEnabled
                ? `RENT ${this.money(p.rentPrice)}/PAYDAY`
                : 'OWNED';
        }
        return p.forSale ? this.money(p.price) : 'NOT FOR SALE';
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
        title.textContent = 'OWNER SETTINGS';
        tools.appendChild(title);

        const descRow = document.createElement('div');
        descRow.className = 'house-owner-tools__row';
        const descInput = document.createElement('textarea');
        descInput.className = 'house-owner-tools__textarea';
        descInput.maxLength = 160;
        descInput.placeholder = 'House description shown to visitors (max 160 chars)';
        descInput.value = p.description || '';
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
        li.className = `house-row${Number(selectedId) === Number(p.id) ? ' is-selected' : ''}`;
        li.dataset.propertyId = String(p.id);

        const details = document.createElement('div');
        details.className = 'house-row__details';
        const name = document.createElement('strong');
        name.textContent = `#${p.id} ${p.label || 'House'}`;
        const meta = document.createElement('span');
        meta.textContent = `Level ${p.minimumLevel || 1} · ${p.interior || 'standard'} · ${p.locked ? 'Locked' : 'Unlocked'}${p.ownerName ? ` · Owner: ${p.ownerName}` : ''}`;
        const rental = document.createElement('small');
        rental.textContent = p.owner_character_id
            ? `${p.renterCount || 0}/${p.maxRenters || 1} rental slots used`
            : (p.forSale ? `Available for purchase · requires level ${p.minimumLevel || 1}` : 'Sale disabled by administrator');
        details.append(name, meta, rental);
        if (p.description) {
            const description = document.createElement('small');
            description.className = 'house-row__description';
            description.textContent = `“${p.description}”`;
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
        if (!p.owner_character_id && p.forSale) button('Buy', 'buy', true);
        if (p.owner_character_id && !p.access && p.rentEnabled && Number(p.renterCount) < Number(p.maxRenters)) {
            button('Rent', 'rent', true);
        }
        if (p.access) button('Set spawn', 'sethome');
        if (p.rented) button('End rental', 'unrent');
        if (p.owned) button(p.locked ? 'Unlock' : 'Lock', 'lock');

        if (p.owned) {
            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.textContent = 'Owner settings';
            toggle.addEventListener('click', (event) => {
                event.stopPropagation();
                const existing = li.querySelector('.house-owner-tools');
                if (existing) {
                    existing.remove();
                    toggle.textContent = 'Owner settings';
                    return;
                }
                toggle.textContent = 'Hide settings';
                details.appendChild(this.createOwnerTools(p, details));
                post('propertyRenters', { propertyId: p.id });
            });
            actions.appendChild(toggle);
        }

        side.appendChild(actions);
        li.append(details, side);
        return li;
    },

    renderList(container, data) {
        if (!container) return;
        container.innerHTML = '';
        this.setMeta(data.meta);
        const properties = data.properties || [];
        properties.forEach((p) => container.appendChild(this.createRow(p, data.selectedId)));
        if (!properties.length) {
            container.innerHTML = '<li class="house-empty">No houses have been created yet. An administrator can use /acreatehouse.</li>';
        }
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
