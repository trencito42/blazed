const AuthAccounts = {
    accounts: [],
    quickLogin: true,
    mode: 'form',

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    initials(username) {
        const clean = String(username || '?').trim();
        if (!clean) return '?';
        return clean.slice(0, 2).toUpperCase();
    },

    money(value) {
        const amount = Number(value);
        if (!Number.isFinite(amount) || amount < 0) return '$—';
        return '$' + Math.floor(amount).toLocaleString('en-US');
    },

    syncRememberCheckboxes() {
        const checked = this.quickLogin === true;
        const login = $('#auth-remember-quick');
        const register = $('#auth-reg-remember-quick');
        if (login) login.checked = checked;
        if (register) register.checked = checked;
    },

    rememberEnabled() {
        const loginOpen = $('#auth-form-login')?.classList.contains('is-active');
        const box = loginOpen ? $('#auth-remember-quick') : $('#auth-reg-remember-quick');
        return box ? box.checked === true : this.quickLogin === true;
    },

    setMode() {
        this.mode = 'form';
        const hasAccounts = this.accounts.length > 0;
        $('#auth-panel')?.classList.toggle('has-saved-accounts', hasAccounts);
        $('#form-slider')?.classList.remove('hidden');
        $('#screen-auth .auth-tabs')?.classList.remove('hidden');
    },

    render() {
        const list = $('#auth-account-list');
        if (!list) return;
        list.innerHTML = '';

        if (this.accounts.length === 0) {
            list.innerHTML = '<div class="auth-identities-empty">Niciun cont salvat încă.</div>';
            this.setMode();
            return;
        }

        this.accounts.forEach((acc) => {
            const username = String(acc.username || '').trim();
            if (!username) return;

            const card = document.createElement('div');
            card.className = 'auth-id-card auth-account-card';

            const pick = document.createElement('button');
            pick.type = 'button';
            pick.className = 'auth-id-card__main auth-account-card__pick';
            const hasAvatar = typeof acc.avatar === 'string' && acc.avatar.startsWith('data:image/');
            const avatar = hasAvatar
                ? `<span class="auth-id-avatar__initials">${this.escape(this.initials(acc.characterName || username))}</span>`
                : `<span>${this.escape(this.initials(acc.characterName || username))}</span>`;
            const level = Number(acc.level) >= 1 ? Math.floor(Number(acc.level)) : '—';
            const availableMoney = Number(acc.cash) + Number(acc.bank);
            const totalMoney = Number.isFinite(availableMoney) ? availableMoney : acc.cash;
            pick.innerHTML = `
                <span class="auth-id-avatar auth-account-card__avatar">${avatar}</span>
                <span class="auth-id-info auth-account-card__body">
                    <span class="auth-id-name auth-account-card__account">${this.escape(username)}</span>
                    <span class="auth-id-stats auth-account-card__stats">LVL ${this.escape(level)} <span class="auth-account-card__money">FUNDS ${this.escape(this.money(totalMoney))}</span></span>
                </span>
            `;
            pick.addEventListener('click', () => {
                if (window.AuthLoading?._pending) return;
                if (window.AuthLoading) AuthLoading.beginSubmit();
                post('authPickAccount', { username });
            });

            const remove = document.createElement('button');
            remove.type = 'button';
            remove.className = 'auth-id-delete auth-account-card__remove';
            remove.setAttribute('aria-label', `Remove ${username}`);
            remove.innerHTML = '<svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';
            remove.addEventListener('click', (event) => {
                event.stopPropagation();
                post('authRemoveAccount', { username });
            });

            card.append(pick, remove);
            list.appendChild(card);

            if (hasAvatar) {
                const avatarWrap = pick.querySelector('.auth-id-avatar');
                const avatarSrc = acc.avatar;
                requestAnimationFrame(() => {
                    const img = document.createElement('img');
                    img.decoding = 'async';
                    img.alt = '';
                    img.onload = () => {
                        avatarWrap?.querySelector('.auth-id-avatar__initials')?.remove();
                        avatarWrap?.appendChild(img);
                    };
                    img.src = avatarSrc;
                });
            }
        });

        this.setMode();
    },

    init(data = {}) {
        this.accounts = Array.isArray(data.accounts) ? data.accounts : [];
        this.quickLogin = data.quickLogin === true;
        this.syncRememberCheckboxes();
        this.setMode();
        this.render();
    },

    update(data = {}) {
        this.accounts = Array.isArray(data.accounts) ? data.accounts : [];
        if (typeof data.quickLogin === 'boolean') {
            this.quickLogin = data.quickLogin;
            this.syncRememberCheckboxes();
        }
        this.render();
    },

    showForm(data = {}) {
        this.setMode();
        this.fillForm(data);
        Panels?.setAuthTab?.('login');
    },

    fillForm(data = {}) {
        const user = $('#auth-login-user');
        const pass = $('#auth-login-pass');
        if (user && data.username) user.value = data.username;
        if (pass && data.password) pass.value = data.password;
        if (user) {
            user.focus({ preventScroll: true });
            const end = user.value.length;
            user.setSelectionRange(end, end);
        }
    },

    capturePortrait(data = {}) {
        const source = String(data.source || '');
        const username = String(data.username || '');
        if (!source || !username) return;

        const image = new Image();
        image.onload = () => {
            try {
                const size = 160;
                const canvas = document.createElement('canvas');
                canvas.width = size;
                canvas.height = size;
                const ctx = canvas.getContext('2d', { alpha: false });
                ctx.fillStyle = '#111';
                ctx.fillRect(0, 0, size, size);
                const side = Math.min(image.naturalWidth, image.naturalHeight);
                const sx = Math.max(0, (image.naturalWidth - side) / 2);
                const sy = Math.max(0, (image.naturalHeight - side) / 2);
                ctx.drawImage(image, sx, sy, side, side, 0, 0, size, size);
                post('authSavePortrait', {
                    username,
                    characterName: data.characterName,
                    characterId: data.characterId,
                    level: data.level,
                    cash: data.cash,
                    bank: data.bank,
                    avatar: canvas.toDataURL('image/jpeg', 0.78),
                });
            } catch (_) {
                post('authSavePortrait', {
                    username,
                    characterName: data.characterName,
                    characterId: data.characterId,
                    level: data.level,
                    cash: data.cash,
                    bank: data.bank,
                });
            }
        };
        image.onerror = () => post('authSavePortrait', {
            username,
            characterName: data.characterName,
            characterId: data.characterId,
            level: data.level,
            cash: data.cash,
            bank: data.bank,
        });
        image.crossOrigin = 'anonymous';
        image.src = source;
    },

    bind() {
        if (this._ready) return;
        this._ready = true;

        const onRememberChange = (event) => {
            const enabled = Boolean(event.target?.checked);
            this.quickLogin = enabled;
            this.syncRememberCheckboxes();
            post('authSetQuickLogin', { enabled });
        };
        $('#auth-remember-quick')?.addEventListener('change', onRememberChange);
        $('#auth-reg-remember-quick')?.addEventListener('change', onRememberChange);
    },
};

window.AuthAccounts = AuthAccounts;
