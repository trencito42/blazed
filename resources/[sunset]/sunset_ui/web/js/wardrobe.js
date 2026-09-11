const WardrobeUI = {
    state: null,
    buyProgress: 0,
    buyRaf: null,
    buyComplete: false,
    ready: false,

    init() {
        if (this.ready) return;
        this.ready = true;

        $('#wardrobe-cat-list')?.addEventListener('click', (event) => {
            const btn = event.target.closest('[data-wardrobe-cat]');
            if (!btn) return;
            this.selectCategory(btn.dataset.wardrobeCat);
        });

        $('#wardrobe-model-dec')?.addEventListener('click', () => this.changeItem('model', -1));
        $('#wardrobe-model-inc')?.addEventListener('click', () => this.changeItem('model', 1));
        $('#wardrobe-texture-dec')?.addEventListener('click', () => this.changeItem('texture', -1));
        $('#wardrobe-texture-inc')?.addEventListener('click', () => this.changeItem('texture', 1));

        const buyBtn = $('#wardrobe-buy');
        buyBtn?.addEventListener('mousedown', () => this.startBuy());
        buyBtn?.addEventListener('mouseup', () => this.stopBuy());
        buyBtn?.addEventListener('mouseleave', () => this.stopBuy());

        document.addEventListener('keydown', (event) => {
            if ($('#wardrobe')?.classList.contains('hidden')) return;
            if (event.key === 'Escape') {
                event.preventDefault();
                post('wardrobeClose');
                return;
            }
            if (event.key === 'Enter' && !event.repeat) this.startBuy();
        });
        document.addEventListener('keyup', (event) => {
            if ($('#wardrobe')?.classList.contains('hidden')) return;
            if (event.key === 'Enter') this.stopBuy();
        });
    },

    show(data = {}) {
        this.init();
        this.state = {
            categories: data.categories || [],
            activeCategory: data.activeCategory || 'top',
            activeDisplay: data.activeDisplay || 'Shirt / Jacket',
            drawable: Number(data.drawable) || 0,
            texture: Number(data.texture) || 0,
            maxDrawable: Number(data.maxDrawable) || 0,
            maxTexture: Number(data.maxTexture) || 0,
            cartTotal: Number(data.cartTotal) || Number(data.pricePerItem) || 50,
            hasChanges: data.hasChanges === true,
            camera: data.camera || 'full',
            isProp: data.isProp === true,
        };
        const panel = $('#wardrobe');
        panel?.classList.remove('hidden');
        panel?.setAttribute('aria-hidden', 'false');
        document.body.classList.add('wardrobe-open');
        this.renderCategories();
        this.renderValues();
    },

    update(data = {}) {
        if (!this.state) return this.show(data);
        Object.assign(this.state, {
            activeCategory: data.activeCategory ?? this.state.activeCategory,
            activeDisplay: data.activeDisplay ?? this.state.activeDisplay,
            drawable: Number(data.drawable ?? this.state.drawable),
            texture: Number(data.texture ?? this.state.texture),
            maxDrawable: Number(data.maxDrawable ?? this.state.maxDrawable),
            maxTexture: Number(data.maxTexture ?? this.state.maxTexture),
            cartTotal: Number(data.cartTotal ?? this.state.cartTotal),
            hasChanges: data.hasChanges === true,
            camera: data.camera ?? this.state.camera,
            isProp: data.isProp === true,
        });
        this.renderCategories();
        this.renderValues();
    },

    hide() {
        this.stopBuy(true);
        $('#wardrobe')?.classList.add('hidden');
        $('#wardrobe')?.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('wardrobe-open');
        this.state = null;
    },

    renderCategories() {
        const list = $('#wardrobe-cat-list');
        if (!list || !this.state) return;
        list.innerHTML = '';
        (this.state.categories || []).forEach((cat) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'wr-cat-item' + (cat.id === this.state.activeCategory ? ' is-active' : '');
            btn.dataset.wardrobeCat = cat.id;
            btn.innerHTML = `<i class="ph-fill ${cat.icon || 'ph-t-shirt'}"></i> <span>${cat.label}</span>`;
            list.appendChild(btn);
        });
        const title = $('#wardrobe-active-cat');
        if (title) title.textContent = this.state.activeDisplay || 'Clothing';
    },

    renderValues() {
        if (!this.state) return;
        const pctModel = this.state.maxDrawable > 0
            ? (Math.max(0, this.state.drawable) / this.state.maxDrawable) * 100
            : 0;
        const pctTexture = this.state.maxTexture > 0
            ? (Math.max(0, this.state.texture) / this.state.maxTexture) * 100
            : 0;

        $('#wardrobe-val-model')?.textContent = String(this.state.drawable);
        $('#wardrobe-max-model')?.textContent = String(this.state.maxDrawable);
        $('#wardrobe-val-texture')?.textContent = String(this.state.texture);
        $('#wardrobe-max-texture')?.textContent = String(this.state.maxTexture);
        $('#wardrobe-track-model')?.style.width = `${pctModel}%`;
        $('#wardrobe-track-texture')?.style.width = `${pctTexture}%`;
        $('#wardrobe-cart-price')?.textContent = `$${Number(this.state.cartTotal || 0).toLocaleString('en-US')}`;

        const buyBtn = $('#wardrobe-buy');
        if (buyBtn) buyBtn.disabled = !this.state.hasChanges;
    },

    selectCategory(categoryId) {
        if (!this.state || categoryId === this.state.activeCategory) return;
        this.state.activeCategory = categoryId;
        const cat = (this.state.categories || []).find((row) => row.id === categoryId);
        if (cat) this.state.activeDisplay = cat.display || cat.label;
        post('wardrobeCategory', { categoryId, camera: this.state.camera });
    },

    changeItem(type, direction) {
        if (!this.state) return;
        if (type === 'model') {
            let next = this.state.drawable + direction;
            const max = this.state.maxDrawable;
            const min = this.state.isProp ? -1 : 0;
            if (next < min) next = max;
            if (next > max) next = min;
            this.state.drawable = next;
            this.state.texture = 0;
        } else {
            let next = this.state.texture + direction;
            const max = this.state.maxTexture;
            if (next < 0) next = max;
            if (next > max) next = 0;
            this.state.texture = next;
        }
        post('wardrobePreview', {
            categoryId: this.state.activeCategory,
            drawable: this.state.drawable,
            texture: this.state.texture,
        });
    },

    startBuy() {
        if (!this.state?.hasChanges || this.buyComplete) return;
        if (this.buyRaf) cancelAnimationFrame(this.buyRaf);
        const tick = () => {
            this.buyProgress += 2.5;
            const bar = $('#wardrobe-buy-progress');
            if (bar) bar.style.width = `${this.buyProgress}%`;
            if (this.buyProgress >= 100) {
                this.buyComplete = true;
                const text = $('#wardrobe-buy-text');
                if (text) {
                    text.innerHTML = 'Payment Confirmed!';
                    text.style.color = '#000';
                }
                const btn = $('#wardrobe-buy');
                if (btn) btn.style.background = 'var(--wr-accent)';
                post('wardrobePurchase', { total: this.state.cartTotal });
                setTimeout(() => this.resetBuyUi(), 1500);
                return;
            }
            this.buyRaf = requestAnimationFrame(tick);
        };
        this.buyRaf = requestAnimationFrame(tick);
    },

    resetBuyUi() {
        this.buyProgress = 0;
        this.buyComplete = false;
        const bar = $('#wardrobe-buy-progress');
        if (bar) bar.style.width = '0%';
        const text = $('#wardrobe-buy-text');
        if (text) {
            text.innerHTML = '<span class="wr-key-hint">ENTER</span> Pay';
            text.style.color = '';
        }
        const btn = $('#wardrobe-buy');
        if (btn) btn.style.background = '';
    },

    stopBuy(force) {
        if (this.buyRaf) {
            cancelAnimationFrame(this.buyRaf);
            this.buyRaf = null;
        }
        if (force || this.buyProgress < 100) {
            this.resetBuyUi();
        }
    },
};

window.WardrobeUI = WardrobeUI;
