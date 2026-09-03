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
        $('#auth')?.classList.remove('hidden');
        this.setAuthTab('login');
    },

    hideAuth() { $('#auth')?.classList.add('hidden'); },

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
        (data.vehicles || []).forEach((v) => {
            const li = document.createElement('li');
            const status = v.stored == 1 ? 'stored' : 'out';
            li.innerHTML = `<span>${v.model} [${v.plate}] — ${status}</span>`;
            if (v.stored == 1) {
                const btn = document.createElement('button');
                btn.textContent = 'SPAWN';
                btn.addEventListener('click', () => post('garageSpawn', { vehicleId: v.id }));
                li.appendChild(btn);
            }
            list.appendChild(li);
        });
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
        $('#clothing-title').textContent = data.type === 'barber' ? 'Barber' : 'Clothing';
        $('#clothing')?.classList.remove('hidden');
    },

    hideClothing() { $('#clothing')?.classList.add('hidden'); },
};

window.Panels = Panels;
