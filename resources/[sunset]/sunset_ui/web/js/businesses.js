const BusinessPanels = {
    dashboard: null,
    ready: false,

    init() {
        if (this.ready) return;
        this.ready = true;

        document.querySelectorAll('[data-business-tab]').forEach((tab) => {
            tab.addEventListener('click', () => this.setTab(tab.dataset.businessTab));
        });

        $('#business-admin-save')?.addEventListener('click', () => this.saveAdminBusiness());
        $('#business-admin-clear-owner')?.addEventListener('click', () => this.clearOwner());
        $('#business-admin-teleport')?.addEventListener('click', () => this.teleportToBusiness());
        $('#business-panel-close')?.addEventListener('click', () => post('businessPanelsClose'));

        $('#business-admin-list')?.addEventListener('click', (event) => {
            const row = event.target.closest('[data-business-id]');
            if (!row) return;
            post('businessSelect', { businessId: Number(row.dataset.businessId) });
        });

        $('#business-owner-list')?.addEventListener('click', (event) => {
            const withdrawBtn = event.target.closest('[data-business-withdraw]');
            if (withdrawBtn) {
                post('businessManage', {
                    mode: 'owner',
                    action: 'withdraw',
                    businessId: Number(withdrawBtn.dataset.businessWithdraw),
                });
                return;
            }
            const teleportBtn = event.target.closest('[data-business-teleport]');
            if (teleportBtn) {
                post('businessManage', {
                    mode: 'owner',
                    action: 'teleport',
                    businessId: Number(teleportBtn.dataset.businessTeleport),
                });
            }
        });

        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            if ($('#business-panel')?.classList.contains('hidden')) return;
            event.preventDefault();
            post('businessPanelsClose');
        });
    },

    hide() {
        const panel = $('#business-panel');
        panel?.classList.add('hidden');
        panel?.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('business-panels-open');
    },

    ownerRows() {
        if (!this.dashboard) return [];
        if (this.dashboard.mode === 'owner') return this.dashboard.businesses || [];
        return this.dashboard.ownedBusinesses || [];
    },

    ownerTotal() {
        if (!this.dashboard) return 0;
        if (this.dashboard.mode === 'owner') return this.dashboard.totalBalance;
        return this.dashboard.ownedTotalBalance;
    },

    setTab(tabId) {
        document.querySelectorAll('[data-business-tab]').forEach((tab) => {
            tab.classList.toggle('is-active', tab.dataset.businessTab === tabId);
        });
        document.querySelectorAll('[data-business-panel]').forEach((panel) => {
            panel.classList.toggle('is-active', panel.dataset.businessPanel === tabId);
        });

        if (tabId === 'owner') {
            if (this.dashboard?.mode === 'admin') {
                post('businessOwnerRefresh');
            } else {
                this.renderOwnerList(this.ownerRows(), this.ownerTotal());
            }
            return;
        }

        if (tabId === 'admin') {
            if (this.dashboard?.mode !== 'admin') {
                post('businessAdminRefresh');
            } else {
                this.renderAdminList(this.dashboard.businesses || []);
                this.renderAdminForm(this.dashboard.selected || null, this.dashboard.defaultProfitPercent);
            }
        }
    },

    formatMoney(amount) {
        return `$${Number(amount || 0).toLocaleString('en-US')}`;
    },

    typeLabel(type) {
        if (type === 'gas') return 'Gas Station';
        if (type === 'shop') return 'Store';
        return 'Business';
    },

    escape(text) {
        return String(text || '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[ch]));
    },

    showDashboard(data = {}) {
        this.init();
        this.dashboard = data;
        const panel = $('#business-panel');
        if (!panel) return;
        panel.classList.remove('hidden');
        panel.setAttribute('aria-hidden', 'false');
        document.body.classList.add('business-panels-open');

        const canAdmin = data.permissions?.admin === true;
        const isAdminView = data.mode === 'admin';
        $('#business-panel-title').textContent = isAdminView ? 'BUSINESS ADMIN' : 'MY BUSINESSES';
        $('#business-panel-type').textContent = isAdminView ? 'Location Management' : 'Profits & Withdrawals';

        $('#business-tab-admin')?.classList.toggle('hidden', !canAdmin);
        $('#business-tab-owner')?.classList.remove('hidden');
        this.setTab(isAdminView ? 'admin' : 'owner');

        if (isAdminView) {
            this.renderAdminList(data.businesses || []);
            this.renderAdminForm(data.selected || null, data.defaultProfitPercent);
        } else {
            this.renderOwnerList(data.businesses || [], data.totalBalance);
        }
    },

    updateOwnerPanel(data = {}) {
        if (!this.dashboard) this.dashboard = {};
        this.dashboard.ownedBusinesses = data.businesses || [];
        this.dashboard.ownedTotalBalance = data.totalBalance;
        if (this.dashboard.mode !== 'admin') {
            this.dashboard.businesses = data.businesses || [];
            this.dashboard.totalBalance = data.totalBalance;
        }
        this.renderOwnerList(this.ownerRows(), this.ownerTotal());
    },

    updateAdminPanel(data = {}) {
        if (!this.dashboard) this.dashboard = {};
        this.dashboard.mode = 'admin';
        this.dashboard.businesses = data.businesses || [];
        this.dashboard.selected = data.selected || null;
        this.dashboard.defaultProfitPercent = data.defaultProfitPercent ?? this.dashboard.defaultProfitPercent ?? 70;
        this.dashboard.ownedBusinesses = data.ownedBusinesses || this.dashboard.ownedBusinesses || [];
        this.dashboard.ownedTotalBalance = data.ownedTotalBalance ?? this.dashboard.ownedTotalBalance;
        this.dashboard.permissions = { ...(this.dashboard.permissions || {}), admin: true };
        this.renderAdminList(this.dashboard.businesses);
        this.renderAdminForm(this.dashboard.selected, this.dashboard.defaultProfitPercent);
    },

    renderAdminList(rows) {
        const list = $('#business-admin-list');
        if (!list) return;
        list.innerHTML = '';
        if (!rows.length) {
            list.innerHTML = '<p class="premium-clan__empty">No business locations registered yet. Restart sunset_businesses to bootstrap locations.</p>';
            return;
        }
        rows.forEach((row) => {
            const item = document.createElement('button');
            item.type = 'button';
            item.className = 'premium-clan__roster-item business-admin-row';
            item.dataset.businessId = String(row.id);
            if (this.dashboard?.selected?.id === row.id) item.classList.add('is-selected');
            const owner = row.ownerName || (row.ownerCharacterId ? `CID #${row.ownerCharacterId}` : 'For sale');
            item.innerHTML = `
                <div>
                    <strong>${this.escape(row.label)}</strong>
                    <small>${this.escape(this.typeLabel(row.businessType))} · ${this.escape(owner)}</small>
                </div>
                <span>${this.formatMoney(row.balance)}</span>
            `;
            list.appendChild(item);
        });
    },

    renderAdminForm(selected, defaultProfit) {
        const empty = $('#business-admin-empty');
        const form = $('#business-admin-form');
        if (!selected) {
            empty?.classList.remove('hidden');
            form?.classList.add('hidden');
            return;
        }
        empty?.classList.add('hidden');
        form?.classList.remove('hidden');

        $('#business-admin-selected-label').textContent = `${selected.label} (#${selected.id})`;
        $('#business-admin-label').value = selected.label || '';
        $('#business-admin-price').value = selected.price || 0;
        $('#business-admin-profit').value = selected.profitPercent ?? defaultProfit ?? 70;
        $('#business-admin-balance').textContent = this.formatMoney(selected.balance);
        $('#business-admin-owner').textContent = selected.ownerName
            ? `${selected.ownerName} (#${selected.ownerCharacterId})`
            : 'No owner';
        $('#business-admin-type').textContent = this.typeLabel(selected.businessType);
        $('#business-admin-catalog').textContent = selected.catalogKey || '—';
        $('#business-admin-for-sale').checked = selected.forSale === true;
        $('#business-admin-enabled').checked = selected.enabled !== false;
        form.dataset.businessId = String(selected.id);
    },

    renderOwnerList(rows, totalBalance) {
        const list = $('#business-owner-list');
        const total = $('#business-owner-total');
        if (total) total.textContent = this.formatMoney(totalBalance);
        if (!list) return;
        list.innerHTML = '';
        if (!rows.length) {
            list.innerHTML = `
                <div class="business-owner-empty">
                    <strong>You do not own any businesses yet.</strong>
                    <p>Go to a <b>24/7</b>, <b>Ammunation</b>, or <b>gas station</b>, open the interaction menu, and choose <b>Buy Business</b>.</p>
                    <p>After purchase, your stores appear here with profit balance, teleport, and withdraw.</p>
                </div>
            `;
            return;
        }
        rows.forEach((row) => {
            const card = document.createElement('article');
            card.className = 'premium-clan__card business-owner-card';
            const catalog = row.catalogKey ? ` · ${this.escape(row.catalogKey)}` : '';
            const balance = Number(row.balance) || 0;
            card.innerHTML = `
                <div class="business-owner-card__head">
                    <strong>${this.escape(row.label)}</strong>
                    <span>${this.escape(this.typeLabel(row.businessType))}${catalog}</span>
                </div>
                <p>Accumulated profit: <b>${this.formatMoney(balance)}</b></p>
                <p>Your share: <b>${Number(row.profitPercent || 0)}%</b> of customer sales</p>
                <div class="business-owner-card__actions">
                    <button type="button" class="premium-clan__btn premium-clan__btn--secondary" data-business-teleport="${row.id}">
                        GO TO LOCATION
                    </button>
                    <button type="button" class="premium-clan__btn premium-clan__btn--primary" data-business-withdraw="${row.id}" ${balance > 0 ? '' : 'disabled'}>
                        WITHDRAW TO BANK
                    </button>
                </div>
            `;
            list.appendChild(card);
        });
    },

    saveAdminBusiness() {
        const form = $('#business-admin-form');
        const businessId = Number(form?.dataset.businessId || 0);
        if (!businessId) return;
        post('businessManage', {
            mode: 'admin',
            action: 'update',
            businessId,
            label: $('#business-admin-label')?.value,
            price: Number($('#business-admin-price')?.value || 0),
            profitPercent: Number($('#business-admin-profit')?.value || 70),
            forSale: $('#business-admin-for-sale')?.checked === true,
            enabled: $('#business-admin-enabled')?.checked === true,
        });
    },

    clearOwner() {
        const form = $('#business-admin-form');
        const businessId = Number(form?.dataset.businessId || 0);
        if (!businessId || !confirm('Remove the owner and list this business for sale again?')) return;
        post('businessManage', { mode: 'admin', action: 'clearOwner', businessId });
    },

    teleportToBusiness() {
        const form = $('#business-admin-form');
        const businessId = Number(form?.dataset.businessId || 0);
        if (!businessId) return;
        post('businessManage', { mode: 'admin', action: 'teleport', businessId });
    },
};

window.BusinessPanels = BusinessPanels;
