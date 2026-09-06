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
        this.mode = mode;
        const hasAccounts = this.accounts.length > 0;
        const chooser = mode === 'chooser' && hasAccounts;

        $('#auth-account-chooser')?.classList.toggle('hidden', !chooser);
        $('#auth-login-stack')?.classList.toggle('hidden', chooser);
        $('#auth-back-to-accounts')?.classList.toggle('hidden', !hasAccounts || chooser);
        $('#screen-auth .auth-tabs')?.classList.toggle('hidden', chooser);
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
            pick.innerHTML = `
                <span class="auth-account-card__avatar">${this.escape(this.initials(username))}</span>
                <span class="auth-account-card__body">
                    <strong class="auth-account-card__name">${this.escape(username)}</strong>
                    <span class="auth-account-card__meta">${acc.hasPassword ? 'Quick login ready' : 'Password required'}</span>
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

        this.setMode(this.accounts.length > 0 && this.mode === 'chooser' ? 'chooser' : 'form');
    },

    init(data = {}) {
        this.accounts = Array.isArray(data.accounts) ? data.accounts : [];
        this.quickLogin = data.quickLogin === true;
        this.syncRememberCheckboxes();
        this.setMode(this.accounts.length > 0 ? 'chooser' : 'form');
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

    bind() {
        if (this._ready) return;
        this._ready = true;

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
