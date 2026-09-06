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

    setMode(mode) {
        this.mode = 'form';
        const hasAccounts = this.accounts.length > 0;
        $('#auth-panel')?.classList.toggle('has-saved-accounts', hasAccounts);
        $('#auth-account-chooser')?.classList.toggle('hidden', !hasAccounts);
        $('#auth-login-stack')?.classList.remove('hidden');
        $('#auth-back-to-accounts')?.classList.add('hidden');
        $('#screen-auth .auth-tabs')?.classList.remove('hidden');
    },

    render() {
        const list = $('#auth-account-list');
        if (!list) return;
        list.innerHTML = '';

        this.accounts.forEach((acc) => {
            const username = String(acc.username || '').trim();
            if (!username) return;

            const card = document.createElement('div');
            card.className = 'auth-account-card';

            const pick = document.createElement('button');
            pick.type = 'button';
            pick.className = 'auth-account-card__pick';
            const avatar = typeof acc.avatar === 'string' && acc.avatar.startsWith('data:image/')
                ? `<img src="${this.escape(acc.avatar)}" alt="">`
                : `<span>${this.escape(this.initials(acc.characterName || username))}</span>`;
            const identity = String(acc.characterName || username).trim();
            const id = Number(acc.characterId) > 0 ? `CID ${Number(acc.characterId)}` : 'Saved account';
            pick.innerHTML = `
                <span class="auth-account-card__avatar">${avatar}</span>
                <span class="auth-account-card__body">
                    <strong class="auth-account-card__name">${this.escape(identity)}</strong>
                    <span class="auth-account-card__meta">${this.escape(id)} · ${this.escape(username)}</span>
                </span>
            `;
            pick.addEventListener('click', () => {
                post('authPickAccount', { username });
            });

            const remove = document.createElement('button');
            remove.type = 'button';
            remove.className = 'auth-account-card__remove';
            remove.setAttribute('aria-label', `Remove ${username}`);
            remove.textContent = '×';
            remove.addEventListener('click', (event) => {
                event.stopPropagation();
                post('authRemoveAccount', { username });
            });

            card.append(pick, remove);
            list.appendChild(card);
        });

        this.setMode('form');
    },

    init(data = {}) {
        this.accounts = Array.isArray(data.accounts) ? data.accounts : [];
        this.quickLogin = data.quickLogin === true;
        this.syncRememberCheckboxes();
        this.setMode('form');
        this.render();
    },

    update(data = {}) {
        this.accounts = Array.isArray(data.accounts) ? data.accounts : [];
        if (typeof data.quickLogin === 'boolean') {
            this.quickLogin = data.quickLogin;
            this.syncRememberCheckboxes();
        }
        if (this.accounts.length === 0) {
            this.setMode('form');
        }
        this.render();
    },

    showForm(data = {}) {
        this.setMode('form');
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
                    avatar: canvas.toDataURL('image/jpeg', 0.78),
                });
            } catch (_) {
                post('authSavePortrait', {
                    username,
                    characterName: data.characterName,
                    characterId: data.characterId,
                });
            }
        };
        image.onerror = () => post('authSavePortrait', {
            username,
            characterName: data.characterName,
            characterId: data.characterId,
        });
        image.crossOrigin = 'anonymous';
        image.src = source;
    },

    bind() {
        if (this._ready) return;
        this._ready = true;

        const chooser = $('#auth-account-chooser');
        const stack = $('#auth-login-stack');
        if (chooser && stack) stack.after(chooser);
        const chooserTitle = chooser?.querySelector('.auth-chooser__title');
        if (chooserTitle) chooserTitle.textContent = 'Saved identities — select to enter';

        $('#auth-use-other-account')?.addEventListener('click', () => {
            this.setMode('form');
            Panels?.setAuthTab?.('login');
            $('#auth-login-user')?.focus({ preventScroll: true });
        });

        $('#auth-back-to-accounts')?.addEventListener('click', () => {
            if (this.accounts.length > 0) {
                this.setMode('chooser');
            }
        });

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
