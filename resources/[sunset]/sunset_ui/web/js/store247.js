const StoreUI = {
    state: null,
    buyProgress: 0,
    buyRaf: null,
    buyComplete: false,
    ready: false,

    CAT_ICONS: {
        all: 'ph-storefront',
        food: 'ph-hamburger',
        drinks: 'ph-coffee',
        medical: 'ph-first-aid',
        supplies: 'ph-package',
        materials: 'ph-cube',
        tools: 'ph-wrench',
        ammo: 'ph-crosshair',
        electronics: 'ph-device-mobile',
        utility: 'ph-flashlight',
        melee: 'ph-sword',
        handguns: 'ph-crosshair',
        shotguns: 'ph-target',
        misc: 'ph-shopping-bag',
    },

    CAT_LABELS: {
        all: 'All Items',
        food: 'Food',
        drinks: 'Drinks',
        medical: 'Medical',
        supplies: 'Supplies',
        materials: 'Materials',
        tools: 'Tools',
        ammo: 'Ammo',
        electronics: 'Electronics',
        utility: 'Safety & Utility',
        melee: 'Melee',
        handguns: 'Handguns',
        shotguns: 'Shotguns',
        misc: 'Misc',
    },

    init() {
        if (this.ready) return;
        this.ready = true;

        document.getElementById('store-cat-list')?.addEventListener('click', (event) => {
            const btn = event.target.closest('[data-store-cat]');
            if (!btn || !this.state) return;
            this.selectCategory(btn.dataset.storeCat);
        });

        document.getElementById('store-qty-dec')?.addEventListener('click', () => this.changeQty(-1));
        document.getElementById('store-qty-inc')?.addEventListener('click', () => this.changeQty(1));
        document.querySelectorAll('[data-store-qty]').forEach((btn) => {
            btn.addEventListener('click', () => this.setQty(Number(btn.dataset.storeQty)));
        });

        const buyBtn = document.getElementById('store-buy');
        buyBtn?.addEventListener('mousedown', () => this.startBuy());
        buyBtn?.addEventListener('mouseup', () => this.stopBuy());
        buyBtn?.addEventListener('mouseleave', () => this.stopBuy());

        document.addEventListener('keydown', (event) => {
            if (document.getElementById('store-forza')?.classList.contains('hidden')) return;
            if (event.key === 'Escape') {
                event.preventDefault();
                this.close();
                return;
            }
            if (event.key === 'Enter' && !event.repeat && this.state?.selected) this.startBuy();
        });
        document.addEventListener('keyup', (event) => {
            if (document.getElementById('store-forza')?.classList.contains('hidden')) return;
            if (event.key === 'Enter') this.stopBuy();
        });
    },

    post(action, data = {}) {
        if (typeof window.post === 'function') return window.post(action, data);
        const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : '';
        if (!resource) return Promise.resolve();
        return fetch(`https://${resource}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(() => {});
    },

    itemIconHtml(row) {
        const icon = String(row.icon || 'backpack');
        const src = /^[a-z0-9_-]+$/i.test(icon) ? `assets/items/${icon}.webp` : 'assets/items/backpack.webp';
        const cat = row.category || 'misc';
        const ph = this.CAT_ICONS[cat] || 'ph-package';
        return `<img src="${src}" alt="" onerror="this.style.display='none';this.nextElementSibling.style.display='block'"><i class="ph-fill ${ph} st-si-icon" style="display:none"></i>`;
    },

    previewIconHtml(row) {
        const icon = String(row.icon || 'backpack');
        const src = /^[a-z0-9_-]+$/i.test(icon) ? `assets/items/${icon}.webp` : 'assets/items/backpack.webp';
        const cat = row.category || 'misc';
        const ph = this.CAT_ICONS[cat] || 'ph-package';
        return `<img src="${src}" alt="" onerror="this.outerHTML='<i class=\\'ph-fill ${ph}\\'></i>'">`;
    },

    formatMoney(amount) {
        const n = Math.floor(Number(amount) || 0);
        return `$${n.toLocaleString('en-US')}`;
    },

    show(data = {}) {
        this.init();
        const isFishing = data.mode === 'buy' || data.mode === 'sell';
        const shop = data.shop || {};
        const items = isFishing ? (data.items || []) : (shop.items || []);
        const categories = ['all'];
        const seen = new Set();
        items.forEach((row) => {
            const cat = row.category || 'misc';
            if (!seen.has(cat)) {
                seen.add(cat);
                categories.push(cat);
            }
        });

        const uiMode = data.mode === 'sell' ? 'fishing-sell' : (data.mode === 'buy' ? 'fishing-buy' : 'shop');
        this.state = {
            shopId: data.shopId,
            businessId: data.businessId,
            label: isFishing ? (data.title || 'Fishing Shop') : (shop.label || '24/7 Supermarket'),
            items: items.map((row) => ({
                ...row,
                price: uiMode === 'fishing-sell' ? (row.unitValue || row.price || 0) : (row.price || 0),
            })),
            categories,
            activeCategory: 'all',
            selected: null,
            qty: 1,
            maxQty: uiMode === 'fishing-sell' ? 1 : (uiMode === 'fishing-buy' ? 500 : 100),
            uiMode,
            cash: data.cash,
        };

        const panel = document.getElementById('store-forza');
        panel?.classList.remove('hidden');
        panel?.setAttribute('aria-hidden', 'false');
        document.body.classList.add('store-open');

        const title = document.getElementById('store-title');
        if (title) title.textContent = this.state.label;

        this.renderCategories();
        this.renderItems();
        this.renderCheckout();
    },

    hide() {
        this.stopBuy(true);
        document.getElementById('store-forza')?.classList.add('hidden');
        document.getElementById('store-forza')?.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('store-open');
        this.state = null;
    },

    close() {
        const mode = this.state?.uiMode;
        this.hide();
        if (mode === 'fishing-buy' || mode === 'fishing-sell') this.post('fishingShopClose');
        else this.post('shopClose');
    },

    renderCategories() {
        const list = document.getElementById('store-cat-list');
        if (!list || !this.state) return;
        list.innerHTML = '';
        this.state.categories.forEach((cat) => {
            if (cat === 'all') return;
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'st-cat-item' + (this.state.activeCategory === cat ? ' is-active' : '');
            btn.dataset.storeCat = cat;
            const icon = this.CAT_ICONS[cat] || 'ph-package';
            const label = this.CAT_LABELS[cat] || cat;
            btn.innerHTML = `<i class="ph-fill ${icon}"></i> <span>${label}</span>`;
            list.appendChild(btn);
        });
        if (this.state.activeCategory === 'all' && this.state.categories[1]) {
            this.state.activeCategory = this.state.categories[1];
            this.renderCategories();
        }
    },

    filteredItems() {
        if (!this.state) return [];
        if (this.state.activeCategory === 'all') return this.state.items;
        return this.state.items.filter((row) => (row.category || 'misc') === this.state.activeCategory);
    },

    renderItems() {
        const grid = document.getElementById('store-items-grid');
        if (!grid || !this.state) return;
        grid.innerHTML = '';
        const rows = this.filteredItems();
        if (!rows.length) {
            grid.innerHTML = '<div class="st-empty-state" style="grid-column:1/-1;min-height:200px"><span>No items in this category</span></div>';
            return;
        }
        rows.forEach((row) => {
            const el = document.createElement('button');
            el.type = 'button';
            el.className = 'st-store-item' + (this.state.selected?.item === row.item ? ' is-active' : '');
            el.innerHTML = `
                <div class="st-si-price">${this.formatMoney(row.price)}</div>
                <div class="st-si-icon">${this.itemIconHtml(row)}</div>
                <div class="st-si-name">${row.label || row.item}</div>
            `;
            el.addEventListener('click', () => this.selectItem(row));
            grid.appendChild(el);
        });
    },

    selectItem(row) {
        if (!this.state) return;
        this.state.selected = row;
        this.state.qty = 1;
        if (this.state.uiMode === 'fishing-sell') {
            this.state.maxQty = Math.max(1, Number(row.count) || 1);
        } else if (this.state.uiMode === 'shop') {
            this.state.maxQty = Math.max(1, Number(row.maxAmount) || 100);
        }
        this.renderItems();
        this.renderCheckout();
    },

    selectCategory(catId) {
        if (!this.state || catId === this.state.activeCategory) return;
        this.state.activeCategory = catId;
        this.state.selected = null;
        this.state.qty = 1;
        this.renderCategories();
        this.renderItems();
        this.renderCheckout();
    },

    changeQty(delta) {
        if (!this.state?.selected) return;
        let next = this.state.qty + delta;
        next = Math.max(1, Math.min(this.state.maxQty, next));
        this.state.qty = next;
        this.renderCheckout();
    },

    setQty(amount) {
        if (!this.state?.selected) return;
        if (amount >= 9999) amount = this.state.maxQty;
        this.state.qty = Math.max(1, Math.min(this.state.maxQty, amount));
        this.renderCheckout();
    },

    renderCheckout() {
        const content = document.getElementById('store-checkout-content');
        const empty = document.getElementById('store-checkout-empty');
        const buyBtn = document.getElementById('store-buy');
        if (!content || !empty) return;

        if (!this.state?.selected) {
            content.style.display = 'none';
            empty.style.display = 'flex';
            if (buyBtn) buyBtn.disabled = true;
            return;
        }

        const row = this.state.selected;
        const total = (Number(row.price) || 0) * this.state.qty;
        content.style.display = 'flex';
        empty.style.display = 'none';
        if (buyBtn) buyBtn.disabled = false;
        const buyText = document.getElementById('store-buy-text');
        if (buyText) {
            buyText.innerHTML = this.state.uiMode === 'fishing-sell'
                ? '<span class="st-key-hint">ENTER</span> Sell'
                : '<span class="st-key-hint">ENTER</span> Pay';
        }

        const icon = document.getElementById('store-preview-icon');
        if (icon) icon.innerHTML = this.previewIconHtml(row);
        const name = document.getElementById('store-preview-name');
        if (name) name.textContent = row.label || row.item;
        const price = document.getElementById('store-preview-price');
        const unitLabel = this.state.uiMode === 'fishing-sell' ? 'each (sell)' : 'each';
        if (price) {
            price.textContent = `${this.formatMoney(row.price)} / ${unitLabel}`;
            price.style.color = this.state.uiMode === 'fishing-sell' ? 'var(--st-success)' : '';
        }
        const weight = document.getElementById('store-preview-weight');
        if (weight) {
            const requirements = [];
            if (row.minLevel) requirements.push(`Level ${row.minLevel}`);
            if (row.requiredLicense === 'weapon') requirements.push('Firearm License');
            const weightText = row.weight != null ? `Weight: ${Number(row.weight).toFixed(1)} kg` : '';
            weight.textContent = [weightText, requirements.join(' · ')].filter(Boolean).join(' — ');
        }
        const qty = document.getElementById('store-qty-value');
        if (qty) qty.textContent = String(this.state.qty);
        const totalEl = document.getElementById('store-total-value');
        if (totalEl) totalEl.textContent = total.toLocaleString('en-US');
    },

    startBuy() {
        if (!this.state?.selected || this.buyComplete || this.buyPending) return;
        if (this.buyRaf) cancelAnimationFrame(this.buyRaf);
        const tick = () => {
            this.buyProgress += 2.5;
            const bar = document.getElementById('store-buy-progress');
            if (bar) bar.style.width = `${this.buyProgress}%`;
            if (this.buyProgress >= 100) {
                this.buyComplete = true;
                // [GUNSHOP FIX] Block re-buy until the SERVER answers (shopBuyResult).
                // The old 1200ms auto-reset re-armed the button while a slow purchase
                // was still processing; the second click hit the server rate limit
                // ("action failed") even though the first purchase later succeeded.
                this.buyPending = true;
                const text = document.getElementById('store-buy-text');
                if (text) {
                    text.innerHTML = 'Processing...';
                    text.style.color = '#000';
                }
                const btn = document.getElementById('store-buy');
                if (btn) btn.style.background = 'var(--st-accent)';
                const row = this.state.selected;
                const amount = this.state.qty;
                if (this.state.uiMode === 'fishing-buy') {
                    this.post('fishingShopBuy', {
                        cart: [{ item: row.item, amount, price: row.price }],
                    });
                } else if (this.state.uiMode === 'fishing-sell') {
                    this.post('fishingShopSell', {
                        cart: [{ item: row.item, amount, price: row.price }],
                    });
                } else {
                    this.post('shopBuy', {
                        shopId: this.state.shopId,
                        businessId: this.state.businessId,
                        item: row.item,
                        amount,
                    });
                }
                // Safety net: if the result message never arrives (NUI hiccup),
                // unblock after 6s instead of 1.2s.
                setTimeout(() => {
                    if (this.buyPending) {
                        this.buyPending = false;
                        this.resetBuyUi();
                    }
                }, 6000);
                return;
            }
            this.buyRaf = requestAnimationFrame(tick);
        };
        this.buyRaf = requestAnimationFrame(tick);
    },

    // [GUNSHOP FIX] Server-authoritative purchase result from Lua.
    onBuyResult() {
        this.buyPending = false;
        this.resetBuyUi();
    },

    resetBuyUi() {
        this.buyProgress = 0;
        this.buyComplete = false;
        this.buyPending = false;
        const bar = document.getElementById('store-buy-progress');
        if (bar) bar.style.width = '0%';
        const text = document.getElementById('store-buy-text');
        if (text) {
            const isSell = this.state?.uiMode === 'fishing-sell';
            text.innerHTML = isSell
                ? '<span class="st-key-hint">ENTER</span> Sell'
                : '<span class="st-key-hint">ENTER</span> Pay';
            text.style.color = '';
        }
        const btn = document.getElementById('store-buy');
        if (btn) btn.style.background = '';
        if (this.state) {
            this.state.qty = 1;
            this.renderCheckout();
        }
    },

    stopBuy(force) {
        if (this.buyRaf) {
            cancelAnimationFrame(this.buyRaf);
            this.buyRaf = null;
        }
        if (force || this.buyProgress < 100) this.resetBuyUi();
    },
};

window.StoreUI = StoreUI;
