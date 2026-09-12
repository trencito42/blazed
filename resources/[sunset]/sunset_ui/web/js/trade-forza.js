const TradeForza = {
    _catalog: null,
    _cashDraft: 0,
    _selectedItems: new Set(),
    _selectedAsset: null,
    _activeTab: 'cash',

    formatMoney(value) {
        const amount = Math.max(0, Math.floor(Number(value) || 0));
        return '$' + amount.toLocaleString('en-US');
    },

    showInvite(data = {}) {
        const modal = document.getElementById('trade-invite-modal');
        const desc = document.getElementById('trade-invite-desc');
        if (!modal) return;
        const name = data.requesterName || 'Juctor';
        const id = data.requesterId || '?';
        if (desc) {
            // [AUDIT P8-04] Escape the requester name: it can fall back to the raw
            // Steam display name which may contain HTML-significant characters.
            const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({
                '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
            }[c]));
            desc.innerHTML = `Juctorul <span>${esc(name)}</span> (ID: ${esc(Number(id) || '?')})<br>vrea s iniE>ieze un Trade.`;
        }
        modal.classList.remove('hidden');
        modal.setAttribute('aria-hidden', 'false');
    },

    hideInvite() {
        const modal = document.getElementById('trade-invite-modal');
        modal?.classList.add('hidden');
        modal?.setAttribute('aria-hidden', 'true');
        this.setInviteHold('accept', 0, true);
        this.setInviteHold('decline', 0, true);
    },

    setInviteHold(key, progress, release) {
        const side = key === 'decline' ? 'decline' : 'accept';
        const fill = document.getElementById(`trade-invite-${side}-hold`);
        const text = document.querySelector(`#trade-invite-${side} .bh-text`);
        if (!fill) return;
        const pct = Math.max(0, Math.min(100, Number(progress) || 0));
        fill.style.width = `${pct}%`;
        if (text) text.style.color = pct >= 100 ? '#000' : '';
        if (release || pct >= 100) {
            fill.style.width = '0%';
            if (text) text.style.color = '';
        }
    },

    showTrade() {
        const inventory = document.getElementById('inventory');
        inventory?.classList.add('hidden');
        inventory?.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('inventory-open');
        document.getElementById('trade-window')?.classList.remove('hidden');
        document.body.classList.add('trade-forza-active');
    },

    hideTrade() {
        document.getElementById('trade-window')?.classList.add('hidden');
        document.getElementById('trade-countdown-screen')?.classList.add('hidden');
        document.body.classList.remove('trade-forza-active');
    },

    setCountdown(value) {
        const overlay = document.getElementById('trade-countdown-screen');
        const timer = document.getElementById('trade-cd-timer');
        if (!overlay || !timer) return;
        if (value > 0) {
            overlay.classList.remove('hidden');
            timer.textContent = String(value);
        } else {
            overlay.classList.add('hidden');
            timer.textContent = '5';
        }
    },

    _offerIcon(row) {
        if (row.cash) return { cls: 'cash', icon: 'ph-fill ph-currency-dollar' };
        if (row.assetType === 'vehicle') return { cls: 'car', icon: 'ph-fill ph-car-profile' };
        if (row.assetType === 'property') return { cls: 'house', icon: 'ph-fill ph-house' };
        if (row.assetType === 'business') return { cls: 'biz', icon: 'ph-fill ph-storefront' };
        return { cls: 'item', icon: 'ph-fill ph-package' };
    },

    _renderOfferList(container, rows, cashAmount, removable) {
        if (!container) return;
        container.innerHTML = '';
        const items = [];
        const cash = Math.max(0, Math.floor(Number(cashAmount) || 0));
        if (cash > 0) items.push({ cash, amount: cash });
        (Array.isArray(rows) ? rows : []).forEach((row) => items.push(row));
        if (!items.length) {
            const empty = document.createElement('div');
            empty.className = 'offer-empty';
            empty.textContent = 'Nicio ofertă adăugată';
            container.appendChild(empty);
            return;
        }
        items.forEach((row) => {
            const el = document.createElement('div');
            el.className = 'offer-item';
            const meta = this._offerIcon(row);
            const icon = document.createElement('i');
            icon.className = `${meta.icon} oi-icon ${meta.cls}`;
            const details = document.createElement('div');
            details.className = 'oi-details';
            const name = document.createElement('div');
            name.className = 'oi-name';
            const sub = document.createElement('div');
            sub.className = 'oi-sub';
            if (row.cash) {
                name.textContent = 'Bani Cash';
                sub.textContent = `${this.formatMoney(row.amount)} USD`;
                if (removable) {
                    el.classList.add('is-removable');
                    el.addEventListener('click', () => post('inventoryTradeRemoveCash', {}));
                }
            } else if (row.assetType) {
                name.textContent = row.label || 'Asset';
                sub.textContent = row.detail || row.assetType.toUpperCase();
                if (removable) {
                    el.classList.add('is-removable');
                    el.addEventListener('click', () => post('inventoryTradeRemoveAsset', { assetType: row.assetType }));
                }
            } else {
                name.textContent = row.label || row.item || 'Item';
                sub.textContent = `Cantitate: x${Number(row.count) || 0}`;
                if (removable) {
                    el.classList.add('is-removable');
                    el.addEventListener('click', () => post('inventoryTradeRemove', { rowId: row.id }));
                }
            }
            details.append(name, sub);
            el.append(icon, details);
            container.appendChild(el);
        });
    },

    syncTradeState(data = {}) {
        if (!data.active) {
            this.hideTrade();
            return;
        }
        this.showTrade();
        const targetName = data.target?.name || `PLAYER #${data.target?.id || '?'}`;
        const theirTitle = document.getElementById('trade-their-title');
        if (theirTitle) theirTitle.textContent = targetName;

        const mergeOffer = (offer, assets) => {
            const rows = [...(Array.isArray(offer) ? offer : [])];
            (Array.isArray(assets) ? assets : []).forEach((asset) => rows.push(asset));
            return rows;
        };
        this._renderOfferList(
            document.getElementById('trade-my-offer'),
            mergeOffer(data.myOffer, data.myAssets),
            data.myCash,
            !data.myAccepted && data.finalizing !== true,
        );
        this._renderOfferList(
            document.getElementById('trade-their-offer'),
            mergeOffer(data.theirOffer, data.theirAssets),
            data.theirCash,
            false,
        );

        const myPanel = document.getElementById('trade-panel-mine');
        const theirPanel = document.getElementById('trade-panel-their');
        const myStatus = document.getElementById('trade-status-mine');
        const theirStatus = document.getElementById('trade-status-their');
        const lockBtn = document.getElementById('trade-lock-mine');
        const addBtn = document.getElementById('trade-add-offer');

        myPanel?.classList.toggle('is-locked', data.myAccepted === true);
        theirPanel?.classList.toggle('is-locked-their', data.theirAccepted === true);

        if (myStatus) {
            myStatus.textContent = data.myAccepted ? 'Pregătit' : 'Modificare...';
        }
        if (theirStatus) {
            theirStatus.textContent = data.theirAccepted ? 'Ofertă Blocată' : 'În Modificare';
            theirStatus.style.background = data.theirAccepted ? '' : 'var(--text-muted, rgba(255,255,255,0.4))';
        }
        if (lockBtn) {
            lockBtn.classList.toggle('is-locked', data.myAccepted === true);
            lockBtn.disabled = data.myAccepted === true || data.finalizing === true;
            lockBtn.innerHTML = data.myAccepted
                ? '<i class="ph-bold ph-lock-key-open"></i> Ofertă Blocată'
                : '<i class="ph-bold ph-lock-key"></i> Blochează Oferta';
        }
        if (addBtn) {
            const canEdit = !data.myAccepted && data.finalizing !== true;
            addBtn.style.opacity = canEdit ? '1' : '0.3';
            addBtn.style.pointerEvents = canEdit ? 'all' : 'none';
        }

        if (data.finalizing && Number(data.countdown) > 0) {
            this.setCountdown(data.countdown);
        } else {
            this.setCountdown(0);
        }
    },

    switchSelectorTab(tabId, btnEl) {
        this._activeTab = tabId;
        document.querySelectorAll('#trade-selector-modal .cat-item').forEach((el) => el.classList.remove('active'));
        btnEl?.classList.add('active');

        const titles = {
            cash: 'Adaugă Sumă',
            items: 'Selectează Obiecte',
            vehicles: 'Selectează Vehicul',
            properties: 'Selectează Proprietate',
            businesses: 'Selectează Afacere',
        };
        const titleEl = document.getElementById('trade-sc-title');
        if (titleEl) titleEl.textContent = titles[tabId] || 'Alege Sursa';

        const balance = document.getElementById('trade-sc-balance');
        if (balance) balance.style.display = tabId === 'cash' ? 'flex' : 'none';

        ['cash', 'items', 'vehicles', 'properties', 'businesses'].forEach((id) => {
            const pane = document.getElementById(`trade-tab-${id}`);
            if (pane) pane.style.display = id === tabId ? 'block' : 'none';
        });
    },

    _resetSelectorState() {
        this._cashDraft = 0;
        this._selectedItems.clear();
        this._selectedAsset = null;
        this._activeTab = 'cash';
        const cashVal = document.getElementById('trade-cash-value');
        if (cashVal) cashVal.textContent = '0';
    },

    openSelector(catalog = {}, inventoryItems = [], maxCash = 0) {
        this._catalog = catalog;
        this._maxCash = Math.max(0, Math.floor(Number(maxCash) || 0));
        this._resetSelectorState();

        const balance = document.getElementById('trade-sc-balance');
        if (balance) {
            balance.innerHTML = `<span>Disponibil:</span> ${this.formatMoney(this._maxCash)}`;
        }

        this._renderSelectorItems(inventoryItems);
        this._renderSelectorAssets('vehicles', catalog.vehicles || [], 'vehicle');
        this._renderSelectorAssets('properties', catalog.properties || [], 'property');
        this._renderSelectorAssets('businesses', catalog.businesses || [], 'business');

        const firstTab = document.querySelector('#trade-selector-modal .cat-item.money');
        this.switchSelectorTab('cash', firstTab);

        const modal = document.getElementById('trade-selector-modal');
        modal?.classList.remove('hidden');
        modal?.setAttribute('aria-hidden', 'false');
    },

    hideSelector() {
        const modal = document.getElementById('trade-selector-modal');
        modal?.classList.add('hidden');
        modal?.setAttribute('aria-hidden', 'true');
        this._resetSelectorState();
    },

    addCashDraft(amount) {
        this._cashDraft += Number(amount) || 0;
        if (this._cashDraft > this._maxCash) this._cashDraft = this._maxCash;
        const el = document.getElementById('trade-cash-value');
        if (el) el.textContent = this._cashDraft.toLocaleString('en-US');
    },

    clearCashDraft() {
        this._cashDraft = 0;
        const el = document.getElementById('trade-cash-value');
        if (el) el.textContent = '0';
    },

    _renderSelectorItems(items) {
        const grid = document.getElementById('trade-tab-items-grid');
        if (!grid) return;
        grid.innerHTML = '';
        const rows = Array.isArray(items) ? items.filter((row) => row && row.item) : [];
        if (!rows.length) {
            grid.innerHTML = '<div class="selector-empty">Niciun obiect în buzunar</div>';
            return;
        }
        rows.forEach((row) => {
            const el = document.createElement('div');
            el.className = 'asset-item';
            el.dataset.rowId = String(row.id);
            const qty = document.createElement('div');
            qty.className = 'ai-qty';
            qty.textContent = `${Number(row.count) || 0}x`;
            const icon = document.createElement('i');
            icon.className = 'ph-fill ph-package ai-icon';
            const name = document.createElement('div');
            name.className = 'ai-name';
            name.textContent = row.label || row.item;
            el.append(qty, icon, name);
            el.addEventListener('click', () => {
                grid.querySelectorAll('.asset-item').forEach((n) => n.classList.remove('selected'));
                el.classList.add('selected');
                this._selectedAsset = null;
                this._selectedItems = new Set([row.id]);
            });
            grid.appendChild(el);
        });
    },

    _renderSelectorAssets(tabId, items, assetType) {
        const grid = document.getElementById(`trade-tab-${tabId}-grid`);
        if (!grid) return;
        grid.innerHTML = '';
        const rows = Array.isArray(items) ? items : [];
        if (!rows.length) {
            grid.innerHTML = '<div class="selector-empty">Nimic disponibil</div>';
            return;
        }
        rows.forEach((asset) => {
            const el = document.createElement('div');
            el.className = 'asset-card';
            el.dataset.assetType = assetType;
            el.dataset.assetId = String(asset.id);
            const icon = document.createElement('i');
            icon.className = assetType === 'property'
                ? 'ph-fill ph-house ac-icon'
                : assetType === 'business'
                    ? 'ph-fill ph-storefront ac-icon'
                    : 'ph-fill ph-car-profile ac-icon';
            const info = document.createElement('div');
            info.className = 'ac-info';
            const title = document.createElement('div');
            title.className = 'ac-title';
            title.textContent = asset.label || 'Asset';
            const sub = document.createElement('div');
            sub.className = 'ac-sub';
            sub.textContent = asset.detail || '';
            info.append(title, sub);
            el.append(icon, info);
            el.addEventListener('click', () => {
                grid.querySelectorAll('.asset-card').forEach((n) => n.classList.remove('selected'));
                el.classList.add('selected');
                this._selectedItems.clear();
                this._selectedAsset = { assetType, id: asset.id };
            });
            grid.appendChild(el);
        });
    },

    confirmSelector() {
        if (this._activeTab === 'cash' && this._cashDraft > 0) {
            post('inventoryTradeOfferCash', { amount: this._cashDraft });
            this.hideSelector();
            return;
        }
        if (this._activeTab === 'items' && this._selectedItems.size === 1) {
            const rowId = [...this._selectedItems][0];
            const row = (window.Panels?._inventoryItems || []).find((item) => item.id === rowId);
            if (row) {
                if ((Number(row.count) || 0) <= 1) {
                    post('inventoryTradeOffer', { rowId, count: 1 });
                    this.hideSelector();
                } else if (window.Panels?.openQuantityModal) {
                    window.Panels.openQuantityModal(row, 'offer', (count) => {
                        post('inventoryTradeOffer', { rowId, count });
                    });
                    this.hideSelector();
                }
            }
            return;
        }
        if (this._selectedAsset) {
            post('inventoryTradeOfferAsset', {
                assetType: this._selectedAsset.assetType,
                id: this._selectedAsset.id,
            });
            this.hideSelector();
        }
    },

    bind() {
        if (this._bound) return;
        this._bound = true;

        document.getElementById('trade-lock-mine')?.addEventListener('click', () => {
            post('inventoryTradeConfirm', {});
        });
        document.getElementById('trade-cancel-mine')?.addEventListener('click', () => {
            post('inventoryTradeCancel', {});
        });
        document.getElementById('trade-add-offer')?.addEventListener('click', () => {
            post('inventoryTradeCatalog', {});
        });
        document.getElementById('trade-selector-close')?.addEventListener('click', () => this.hideSelector());
        document.getElementById('trade-selector-confirm')?.addEventListener('click', () => this.confirmSelector());

        document.querySelectorAll('#trade-selector-modal .cat-item').forEach((btn) => {
            btn.addEventListener('click', () => {
                const tab = btn.dataset.tab;
                if (tab) this.switchSelectorTab(tab, btn);
            });
        });

        document.querySelectorAll('[data-cash-add]').forEach((btn) => {
            btn.addEventListener('click', () => this.addCashDraft(Number(btn.dataset.cashAdd) || 0));
        });
        document.getElementById('trade-cash-clear')?.addEventListener('click', () => this.clearCashDraft());
    },
};

window.TradeForza = TradeForza;
document.addEventListener('DOMContentLoaded', () => TradeForza.bind());
