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
            const btn = event.target.closest('[data-business-withdraw]');
            if (!btn) return;
            post('businessManage', {
                mode: 'owner',
                action: 'withdraw',
                businessId: Number(btn.dataset.businessWithdraw),
            });
        });

        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            if ($('#business-panel')?.classList.contains('hidden')) return;
            event.preventDefault();
            post('businessPanelsClose');
        });
    },

    hide() {
        $('#business-panel')?.classList.add('hidden');
        document.body.classList.remove('business-panels-open');
    },

    setTab(tabId) {
        document.querySelectorAll('[data-business-tab]').forEach((tab) => {
            tab.classList.toggle('is-active', tab.dataset.businessTab === tabId);
        });
        document.querySelectorAll('[data-business-panel]').forEach((panel) => {
            panel.classList.toggle('is-active', panel.dataset.businessPanel === tabId);
        });
    },

    formatMoney(amount) {
        return `$${Number(amount || 0).toLocaleString('en-US')}`;
    },

    typeLabel(type) {
        if (type === 'gas') return 'Benzinărie';
        if (type === 'shop') return 'Magazin';
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
        document.body.classList.add('business-panels-open');

        const isAdmin = data.mode === 'admin';
        $('#business-panel-title').textContent = isAdmin ? 'ADMIN BUSINESS' : 'AFACERILE MELE';
        $('#business-panel-type').textContent = isAdmin ? 'Management Locații' : 'Profit & Retrageri';

        $('#business-tab-admin')?.classList.toggle('hidden', !isAdmin);
        $('#business-tab-owner')?.classList.toggle('hidden', isAdmin);
        this.setTab(isAdmin ? 'admin' : 'owner');

        if (isAdmin) {
            this.renderAdminList(data.businesses || []);
            this.renderAdminForm(data.selected || null, data.defaultProfitPercent);
        } else {
            this.renderOwnerList(data.businesses || [], data.totalBalance);
        }
    },

    renderAdminList(rows) {
        const list = $('#business-admin-list');
        if (!list) return;
        list.innerHTML = '';
        if (!rows.length) {
            list.innerHTML = '<p class="premium-clan__empty">Nicio locație înregistrată.</p>';
            return;
        }
        rows.forEach((row) => {
            const item = document.createElement('button');
            item.type = 'button';
            item.className = 'premium-clan__roster-item business-admin-row';
            item.dataset.businessId = String(row.id);
            if (this.dashboard?.selected?.id === row.id) item.classList.add('is-selected');
            const owner = row.ownerName || (row.ownerCharacterId ? `CID #${row.ownerCharacterId}` : 'De vânzare');
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
            : 'Niciun proprietar';
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
            list.innerHTML = '<p class="premium-clan__empty">Nu deții niciun business. Cumpără un 24/7, Ammunation sau benzinărie.</p>';
            return;
        }
        rows.forEach((row) => {
            const card = document.createElement('article');
            card.className = 'premium-clan__card business-owner-card';
            card.innerHTML = `
                <div class="business-owner-card__head">
                    <strong>${this.escape(row.label)}</strong>
                    <span>${this.escape(this.typeLabel(row.businessType))}</span>
                </div>
                <p>Profit acumulat: <b>${this.formatMoney(row.balance)}</b></p>
                <p>Procent profit: <b>${Number(row.profitPercent || 0)}%</b> din vânzări</p>
                <button type="button" class="premium-clan__btn premium-clan__btn--primary" data-business-withdraw="${row.id}" ${row.balance > 0 ? '' : 'disabled'}>
                    RETRAGE ÎN BANCĂ
                </button>
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
        if (!businessId || !confirm('Scoți proprietarul și pui business-ul la vânzare?')) return;
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
