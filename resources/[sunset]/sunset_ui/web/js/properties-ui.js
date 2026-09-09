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

    createButton(label, action, propertyId, payload = {}, primary = false, iconSvg = '', extraClass = '') {
        const el = document.createElement('button');
        el.type = 'button';
        el.className = `prop-btn ${primary ? 'is-primary' : ''} ${extraClass}`.trim();
        if (iconSvg) {
            el.innerHTML = `${iconSvg}<span>${label}</span>`;
        } else {
            el.textContent = label;
        }
        el.addEventListener('click', (e) => {
            e.stopPropagation();
            this.dispatch(propertyId, action, payload);
        });
        return el;
    },

    createOwnerTools(p, container) {
        const meta = this.meta || {};
        const tools = document.createElement('div');
        tools.className = 'house-owner-tools';

        const head = document.createElement('div');
        head.className = 'house-owner-tools__head';
        head.innerHTML = `
            <div class="house-owner-tools__title">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
                <span>PROPERTY MANAGEMENT</span>
            </div>
            <span class="house-owner-tools__sub">Configure residence settings, rental rates, interior style and view tenants</span>
        `;
        tools.appendChild(head);

        const grid = document.createElement('div');
        grid.className = 'house-owner-tools__grid';

        // 1. Visitor Note Card
        const descCard = document.createElement('div');
        descCard.className = 'owner-panel-card';
        descCard.innerHTML = `
            <div class="owner-panel-card__label">
                <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
                <span>VISITOR NOTE / NAME</span>
            </div>
        `;
        const descInput = document.createElement('textarea');
        descInput.className = 'owner-field-textarea';
        descInput.maxLength = 160;
        descInput.placeholder = 'House description shown to visitors (max 160 chars)...';
        descInput.value = this.cleanText(p.description || '');

        const descActions = document.createElement('div');
        descActions.className = 'owner-actions-row';
        const saveDesc = this.createButton(
            'Save Note',
            'description',
            p.id,
            {},
            true,
            '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>'
        );
        saveDesc.addEventListener('click', () => this.dispatch(p.id, 'description', { text: descInput.value.trim() }));
        const clearDesc = this.createButton(
            'Clear',
            'description',
            p.id,
            { clear: true },
            false,
            '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>'
        );
        descActions.append(saveDesc, clearDesc);
        descCard.append(descInput, descActions);
        grid.appendChild(descCard);

        // 2. Rental Settings Card
        const rentCard = document.createElement('div');
        rentCard.className = 'owner-panel-card';
        rentCard.innerHTML = `
            <div class="owner-panel-card__label">
                <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"/><path d="M12 6v12M8 10h8"/></svg>
                <span>RENTAL &amp; CAPACITY</span>
            </div>
        `;
        const rentFieldsRow = document.createElement('div');
        rentFieldsRow.className = 'owner-fields-columns';

        const rentCol = document.createElement('div');
        rentCol.className = 'owner-subfield';
        rentCol.innerHTML = '<span class="owner-subfield__title">Rent ($/payday)</span>';
        const rentInput = document.createElement('input');
        rentInput.type = 'number';
        rentInput.className = 'owner-field-input';
        rentInput.min = meta.rentMin || 50;
        rentInput.max = meta.rentMax || 5000;
        rentInput.value = String(p.rentPrice || meta.rentMin || 50);
        rentCol.appendChild(rentInput);

        const slotsCol = document.createElement('div');
        slotsCol.className = 'owner-subfield';
        slotsCol.innerHTML = '<span class="owner-subfield__title">Max Tenants</span>';
        const slotsInput = document.createElement('input');
        slotsInput.type = 'number';
        slotsInput.className = 'owner-field-input';
        slotsInput.min = meta.maxRentersMin || 1;
        slotsInput.max = meta.maxRentersMax || 10;
        slotsInput.value = String(p.maxRenters || 1);
        slotsCol.appendChild(slotsInput);

        rentFieldsRow.append(rentCol, slotsCol);

        const rentActions = document.createElement('div');
        rentActions.className = 'owner-actions-row';
        const rentToggleIcon = p.rentEnabled 
            ? '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>'
            : '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>';
        const rentOn = this.createButton(
            p.rentEnabled ? 'Update Rent' : 'Enable Rent',
            'rent_on',
            p.id,
            {},
            !p.rentEnabled,
            rentToggleIcon
        );
        rentOn.addEventListener('click', () => this.dispatch(p.id, 'rent_on', { price: Number(rentInput.value) }));
        
        const saveSlots = this.createButton(
            'Save Capacity',
            'max_renters',
            p.id,
            {},
            false,
            '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>'
        );
        saveSlots.addEventListener('click', () => this.dispatch(p.id, 'max_renters', { count: Number(slotsInput.value) }));

        rentActions.append(rentOn, saveSlots);

        if (p.rentEnabled) {
            const rentOff = this.createButton(
                'Disable Rent',
                'rent_off',
                p.id,
                {},
                false,
                '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
                'is-danger-glass'
            );
            rentActions.appendChild(rentOff);
        }

        const rentHint = document.createElement('div');
        rentHint.className = 'owner-field-hint';
        rentHint.textContent = `Rent: $${rentInput.min}–$${rentInput.max}/payday · Slots: ${slotsInput.min}–${slotsInput.max}`;
        rentCard.append(rentFieldsRow, rentActions, rentHint);
        grid.appendChild(rentCard);

        // 3. Interior Selector Card
        const interiorCard = document.createElement('div');
        interiorCard.className = 'owner-panel-card';
        interiorCard.innerHTML = `
            <div class="owner-panel-card__label">
                <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                <span>INTERIOR THEME</span>
            </div>
        `;
        const interiorSelect = document.createElement('select');
        interiorSelect.className = 'owner-field-select';
        (meta.interiors || []).forEach((item) => {
            const opt = document.createElement('option');
            opt.value = item.id;
            opt.textContent = item.label;
            if (item.id === p.interior) opt.selected = true;
            interiorSelect.appendChild(opt);
        });
        const interiorBtn = this.createButton(
            'Change Interior',
            'interior',
            p.id,
            {},
            false,
            '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>'
        );
        interiorBtn.addEventListener('click', () => this.dispatch(p.id, 'interior', { key: interiorSelect.value }));
        const interiorHint = document.createElement('div');
        interiorHint.className = 'owner-field-hint';
        interiorHint.textContent = 'Switch layout and decor instantly';
        interiorCard.append(interiorSelect, interiorBtn, interiorHint);
        grid.appendChild(interiorCard);

        tools.appendChild(grid);

        // 4. Active Renters Roster
        const rentersSection = document.createElement('div');
        rentersSection.className = 'house-owner-tools__renters-section';
        rentersSection.innerHTML = `
            <div class="renters-section-head">
                <div class="renters-section-title">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
                    <span>ACTIVE TENANTS ROSTER</span>
                    <span class="renters-count-chip">${p.renterCount || 0} / ${p.maxRenters || 1}</span>
                </div>
            </div>
        `;
        const rentersHeadRight = document.createElement('div');
        rentersHeadRight.className = 'renters-head-actions';
        const loadRenters = this.createButton(
            'Refresh List',
            'renters_refresh',
            p.id,
            {},
            false,
            '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M23 4v6h-6"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>',
            'prop-btn--sm'
        );
        rentersHeadRight.appendChild(loadRenters);
        rentersSection.querySelector('.renters-section-head').appendChild(rentersHeadRight);

        const rentersList = document.createElement('div');
        rentersList.className = 'house-owner-tools__renter-list';
        rentersList.innerHTML = '<span class="renter-loading"><svg class="spin" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10"/></svg> Loading tenants list...</span>';
        loadRenters.addEventListener('click', () => {
            rentersList.innerHTML = '<span class="renter-loading"><svg class="spin" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10"/></svg> Fetching tenants...</span>';
            post('propertyRenters', { propertyId: p.id });
        });
        rentersSection.appendChild(rentersList);
        tools.appendChild(rentersSection);
        container._rentersList = rentersList;
        container._propertyId = p.id;

        // 5. Liquidation / Sell Section
        const sellRefund = Math.floor((Number(p.price) || 0) * ((meta.sellRefundPercent || 70) / 100));
        const sellCard = document.createElement('div');
        sellCard.className = 'house-owner-tools__sell-card';
        sellCard.innerHTML = `
            <div class="sell-card-info">
                <div class="sell-card-title">
                    <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                    <span>LIQUIDATE PROPERTY</span>
                </div>
                <span class="sell-card-desc">Sell residence back to the state for a 70% refund (${this.money(sellRefund)}). All active tenants will be immediately evicted.</span>
            </div>
        `;
        const sellBtn = document.createElement('button');
        sellBtn.type = 'button';
        sellBtn.className = 'prop-btn prop-btn--danger-action';
        sellBtn.innerHTML = `
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
            <span>Sell House (${this.money(sellRefund)})</span>
        `;
        sellBtn.addEventListener('click', (event) => {
            event.stopPropagation();
            const key = String(p.id);
            if (!this.sellPending[key]) {
                this.sellPending[key] = true;
                sellBtn.classList.add('is-confirming');
                sellBtn.innerHTML = `
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    <span>Confirm Sale (${this.money(sellRefund)})</span>
                `;
                return;
            }
            this.sellPending[key] = false;
            this.dispatch(p.id, 'sell', { confirm: true });
        });
        sellCard.appendChild(sellBtn);
        tools.appendChild(sellCard);

        return tools;
    },

    createRow(p, selectedId) {
        const li = document.createElement('li');
        const isSelected = Number(selectedId) === Number(p.id);
        const statusClass = p.owned 
            ? 'is-owned' 
            : (p.rented 
                ? 'is-rented' 
                : (p.owner_character_id 
                    ? (p.rentEnabled ? 'is-rentable' : 'is-occupied') 
                    : (p.forSale ? 'is-for-sale' : 'is-unavailable')));

        li.className = `house-row ${isSelected ? 'is-selected' : ''} ${statusClass}`;
        li.dataset.propertyId = String(p.id);
        li.dataset.forSale = String(Boolean(!p.owner_character_id && p.forSale));
        li.dataset.owned = String(Boolean(p.owned));
        li.dataset.rent = String(Boolean(p.rentEnabled || p.rented));
        li.dataset.name = String(p.label || '').toLowerCase();

        // Main horizontal bar of the card
        const mainBar = document.createElement('div');
        mainBar.className = 'house-row__main';

        // Main info section (left)
        const details = document.createElement('div');
        details.className = 'house-row__details';

        // Title Row
        const titleWrap = document.createElement('div');
        titleWrap.className = 'house-row__title-wrap';
        titleWrap.innerHTML = `
            <span class="prop-id-badge">#${p.id}</span>
            <strong class="prop-address">${this.escape(p.label || 'Residence')}</strong>
        `;
        details.appendChild(titleWrap);

        // Clean description quote (if provided)
        const cleanDesc = this.cleanText(p.description);
        if (cleanDesc) {
            const descEl = document.createElement('div');
            descEl.className = 'house-row__quote';
            descEl.innerHTML = `
                <svg class="quote-svg" viewBox="0 0 24 24" width="13" height="13" fill="currentColor"><path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h3.983v10h-9.983z"/></svg>
                <span>“${this.escape(cleanDesc)}”</span>
            `;
            details.appendChild(descEl);
        }

        // Feature chips
        const chipsWrap = document.createElement('div');
        chipsWrap.className = 'house-row__chips';

        // Level
        const levelChip = `
            <span class="prop-chip prop-chip--lvl">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                <span>LVL ${p.minimumLevel || 1}</span>
            </span>
        `;
        // Interior
        const interiorChip = `
            <span class="prop-chip prop-chip--interior">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
                <span>${this.escape(p.interior || 'Standard')}</span>
            </span>
        `;
        // Lock
        const lockChip = p.locked
            ? `<span class="prop-chip prop-chip--locked">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                <span>LOCKED</span>
               </span>`
            : `<span class="prop-chip prop-chip--open">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>
                <span>OPEN</span>
               </span>`;

        // Owner
        const ownerChip = p.ownerName
            ? `<span class="prop-chip prop-chip--owner">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                <span>${this.escape(p.ownerName)}</span>
               </span>`
            : '';

        // Renters
        const rentersChip = p.owner_character_id
            ? `<span class="prop-chip prop-chip--renters">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                <span>${p.renterCount || 0}/${p.maxRenters || 1} Renters</span>
               </span>`
            : '';

        // Rental pricing chip if active
        const rentRateChip = (p.owner_character_id && p.rentEnabled)
            ? `<span class="prop-chip prop-chip--rent-price">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><path d="M12 6v12M8 10h8"/></svg>
                <span>${this.money(p.rentPrice)}/payday</span>
               </span>`
            : '';

        chipsWrap.innerHTML = `${levelChip}${interiorChip}${lockChip}${ownerChip}${rentersChip}${rentRateChip}`;
        details.appendChild(chipsWrap);

        // Side action section (right)
        const side = document.createElement('div');
        side.className = 'house-row__side';

        // Top status badge
        const badge = document.createElement('div');
        badge.className = 'prop-status-badge';
        if (p.owned) {
            badge.classList.add('is-owned');
            badge.innerHTML = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg><span>YOUR PROPERTY</span>`;
        } else if (p.rented) {
            badge.classList.add('is-rented');
            badge.innerHTML = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg><span>RENTING</span>`;
        } else if (p.owner_character_id) {
            if (p.rentEnabled) {
                badge.classList.add('is-rentable');
                badge.innerHTML = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg><span>RENT ${this.money(p.rentPrice)}/PAYDAY</span>`;
            } else {
                badge.classList.add('is-occupied');
                badge.innerHTML = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg><span>OCCUPIED</span>`;
            }
        } else {
            if (p.forSale) {
                badge.classList.add('is-for-sale');
                badge.innerHTML = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><circle cx="7" cy="7" r="1.5"/></svg><span>${this.money(p.price)}</span>`;
            } else {
                badge.classList.add('is-unavailable');
                badge.innerHTML = `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg><span>UNAVAILABLE</span>`;
            }
        }
        side.appendChild(badge);

        // Actions container
        const actions = document.createElement('div');
        actions.className = 'house-row__actions';

        // Enter
        if (p.access || !p.locked) {
            actions.appendChild(this.createButton(
                'Enter',
                'enter',
                p.id,
                {},
                true,
                '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>'
            ));
        }

        // Purchase
        if (!p.owner_character_id && p.forSale) {
            actions.appendChild(this.createButton(
                'Purchase',
                'buy',
                p.id,
                {},
                true,
                '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>'
            ));
        }

        // Rent Room
        if (p.owner_character_id && !p.access && p.rentEnabled && Number(p.renterCount) < Number(p.maxRenters)) {
            actions.appendChild(this.createButton(
                'Rent Room',
                'rent',
                p.id,
                {},
                true,
                '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 2l-2 2m-1.5 1.5L14 9l-3-3 2.5-2.5 1.5 1.5L16.5 3.5 19 6l-1.5 1.5M3 21l9-9"/></svg>'
            ));
        } else if (p.owner_character_id && !p.access && !p.rentEnabled) {
            const hint = document.createElement('div');
            hint.className = 'house-row__rent-hint';
            hint.innerHTML = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg><span>Owner not accepting renters</span>';
            details.appendChild(hint);
        } else if (p.owner_character_id && !p.access && p.rentEnabled && Number(p.renterCount) >= Number(p.maxRenters)) {
            const hint = document.createElement('div');
            hint.className = 'house-row__rent-hint';
            hint.innerHTML = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg><span>Rental slots full</span>';
            details.appendChild(hint);
        }

        // Set Home
        if (p.access) {
            actions.appendChild(this.createButton(
                'Set Home',
                'sethome',
                p.id,
                {},
                false,
                '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>'
            ));
        }

        // End lease
        if (p.rented) {
            actions.appendChild(this.createButton(
                'End Lease',
                'unrent',
                p.id,
                {},
                false,
                '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
                'is-danger-glass'
            ));
        }

        // Lock / Unlock
        if (p.owned) {
            actions.appendChild(this.createButton(
                p.locked ? 'Unlock' : 'Lock',
                'lock',
                p.id,
                {},
                false,
                p.locked 
                    ? '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>'
                    : '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>'
            ));
        }

        // Manage (Owner only)
        if (p.owned) {
            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.className = 'prop-btn prop-btn--manage';
            toggle.innerHTML = `
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/></svg>
                <span>Manage</span>
            `;
            toggle.addEventListener('click', (event) => {
                event.stopPropagation();
                const existing = li.querySelector('.house-owner-tools');
                if (existing) {
                    existing.remove();
                    toggle.classList.remove('is-active');
                    toggle.querySelector('span').textContent = 'Manage';
                    return;
                }
                toggle.classList.add('is-active');
                toggle.querySelector('span').textContent = 'Close Tools';
                const tools = this.createOwnerTools(p, li);
                li.appendChild(tools);
                post('propertyRenters', { propertyId: p.id });
            });
            actions.appendChild(toggle);
        }

        side.appendChild(actions);
        mainBar.append(details, side);
        li.appendChild(mainBar);
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
        if (empty) {
            empty.style.display = visibleCount === 0 ? 'flex' : 'none';
        } else if (visibleCount === 0 && rows.length > 0) {
            const list = document.querySelector('#properties-list');
            if (list) {
                const tempEmpty = document.createElement('li');
                tempEmpty.className = 'house-empty';
                tempEmpty.innerHTML = `
                    <div class="house-empty-icon">
                        <svg viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
                    </div>
                    <strong>No Matching Residences</strong>
                    <span>Try changing your search term or select another category filter.</span>
                `;
                list.appendChild(tempEmpty);
            }
        }
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
            container.innerHTML = `
                <li class="house-empty">
                    <div class="house-empty-icon">
                        <svg viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="currentColor" stroke-width="1.8"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                    </div>
                    <strong>No Properties Available</strong>
                    <span>No residences have been created yet. An administrator can create one using /acreatehouse.</span>
                </li>
            `;
        }
        this.applyFilters();
    },

    updateRenters(propertyId, renters) {
        document.querySelectorAll('.house-owner-tools__renter-list').forEach((list) => {
            const host = list.closest('.house-row');
            if (!host || Number(host.dataset.propertyId) !== Number(propertyId)) return;
            list.replaceChildren();
            if (!(renters || []).length) {
                list.innerHTML = `
                    <div class="renter-empty">
                        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                        <span>No active tenants registered to this residence</span>
                    </div>
                `;
                return;
            }
            renters.forEach((row) => {
                const item = document.createElement('div');
                item.className = 'house-owner-tools__renter';
                item.innerHTML = `
                    <div class="renter-info">
                        <span class="renter-id">#${row.character_id}</span>
                        <strong class="renter-name">${this.escape(row.name || 'Resident')}</strong>
                        <span class="renter-rate">${this.money(row.rent_price)}/payday</span>
                    </div>
                `;
                const kickBtn = this.createButton(
                    'Evict',
                    'kick_renter',
                    propertyId,
                    { characterId: row.character_id },
                    false,
                    '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="23" y1="11" x2="17" y2="11"/></svg>',
                    'prop-btn--danger-glass prop-btn--sm'
                );
                item.appendChild(kickBtn);
                list.appendChild(item);
            });
        });
    },
};

window.PropertyUI = PropertyUI;
