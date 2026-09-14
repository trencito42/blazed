/* ═══ SUNSET AUTH UI — minimal auth page (login/register/accounts/email) ═══
   Holds NO auth logic: every button posts to sunset_auth_ui's Lua which
   forwards it as a 'sunset:nui:<name>' event to sunset_auth. State comes
   back as window messages from sunset_auth via exports.sunset_auth_ui:Send. */

const $ = (sel) => document.querySelector(sel);

function post(action, data = {}) {
    try {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => {});
    } catch (_) { /* noop */ }
}

const AuthUI = {
    mode: 'login', // login | register | email

    init() {
        $('#auth-login-btn')?.addEventListener('click', () => this.login());
        $('#auth-pass')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.login(); });
        $('#auth-user')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') $('#auth-pass')?.focus(); });

        $('#auth-register-btn')?.addEventListener('click', () => this.register());
        $('#reg-pass2')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.register(); });

        $('#auth-go-register')?.addEventListener('click', () => this.showForm('register'));
        $('#auth-go-login')?.addEventListener('click', () => this.showForm('login'));

        $('#auth-email-btn')?.addEventListener('click', () => this.saveEmail());
        $('#auth-email')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.saveEmail(); });

        $('#auth-accounts-list')?.addEventListener('click', (e) => {
            const card = e.target.closest('.auth-account-card');
            if (!card) return;
            if (e.target.closest('.auth-account-card__remove')) {
                post('authRemoveAccount', { username: card.dataset.username });
                return;
            }
            this.showLoading(true, 'Conectare rapidă...');
            post('authPickAccount', { username: card.dataset.username });
        });

        // Tell sunset_auth the page is live so it (re)pushes saved accounts.
        post('authReady', {});
    },

    showForm(name) {
        this.mode = name;
        $('#auth-login')?.classList.toggle('hidden', name !== 'login');
        $('#auth-register')?.classList.toggle('hidden', name !== 'register');
        $('#auth-email')?.closest('.auth-form')?.classList.toggle('hidden', name !== 'email');
        this.hideError();
    },

    showError(msg) {
        const el = $('#auth-error');
        if (!el) return;
        if (msg) {
            el.textContent = msg;
            el.classList.remove('hidden');
        } else {
            el.classList.add('hidden');
        }
    },

    hideError() { this.showError(null); },

    showLoading(show, label) {
        const el = $('#auth-loading');
        if (!el) return;
        el.classList.toggle('hidden', !show);
        const p = el.querySelector('p');
        if (p && label) p.textContent = label;
    },

    login() {
        const user = ($('#auth-user')?.value || '').trim();
        const pass = $('#auth-pass')?.value || '';
        if (!user || !pass) return this.showError('Complete both fields.');
        this.hideError();
        this.showLoading(true, 'Connecting...');
        post('authLogin', {
            username: user,
            password: pass,
            rememberQuickLogin: $('#auth-remember')?.checked !== false,
        });
    },

    register() {
        const user = ($('#reg-user')?.value || '').trim();
        const email = ($('#reg-email')?.value || '').trim();
        const pass = $('#reg-pass')?.value || '';
        const pass2 = $('#reg-pass2')?.value || '';
        if (!user || !email || !pass || !pass2) return this.showError('Complete all fields.');
        if (!email.includes('@')) return this.showError('Enter a valid email.');
        if (pass !== pass2) return this.showError('Passwords do not match.');
        if (pass.length < 6) return this.showError('Password must be at least 6 characters.');
        this.hideError();
        this.showLoading(true, 'Creating account...');
        post('authRegister', {
            username: user,
            email: email,
            password: pass,
            passwordConfirm: pass2,
            rememberQuickLogin: $('#reg-remember')?.checked !== false,
        });
    },

    saveEmail() {
        const email = ($('#auth-email')?.value || '').trim();
        if (!email || !email.includes('@')) return this.showError('Enter a valid email.');
        this.hideError();
        this.showLoading(true, 'Saving email...');
        post('authSetEmail', { email });
    },

    fillAccount(data) {
        this.showForm('login');
        const u = $('#auth-user');
        if (u && data.username) u.value = data.username;
        const p = $('#auth-pass');
        if (p) { p.value = data.password || ''; if (!p.value) p.focus(); }
    },

    setAccounts(accounts) {
        const list = $('#auth-accounts-list');
        const wrap = $('#auth-accounts');
        if (!list || !wrap) return;
        const rows = Array.isArray(accounts) ? accounts : [];
        if (!rows.length) {
            wrap.classList.add('hidden');
            return;
        }
        wrap.classList.remove('hidden');
        list.innerHTML = rows.map((a) => {
            const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => (
                { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
            ));
            return `
            <div class="auth-account-card" data-username="${esc(a.username)}">
                <div class="auth-account-card__avatar">${esc((a.username || '?').charAt(0).toUpperCase())}</div>
                <div class="auth-account-card__info">
                    <div class="auth-account-card__name">${esc(a.username)}</div>
                    <div class="auth-account-card__meta">${esc(a.characterName || '')}${a.level ? ` · LVL ${esc(a.level)}` : ''}</div>
                </div>
                <button type="button" class="auth-account-card__remove" title="Remove">✕</button>
            </div>`;
        }).join('');
    },

    hide() {
        const screen = $('#auth-screen');
        if (screen) screen.classList.add('hidden');
    },
};

// ── State messages from sunset_auth ──
window.addEventListener('message', (event) => {
    const msg = event?.data || {};
    const d = msg.data || {};
    switch (msg.action) {
        case 'authAccounts':
            AuthUI.setAccounts(d.accounts || []);
            break;
        case 'authError':
            AuthUI.showLoading(false);
            AuthUI.showError(d.message || '');
            break;
        case 'authNeedsEmail':
            AuthUI.showLoading(false);
            AuthUI.showForm('email');
            AuthUI.showError(`Welcome, ${d.username || ''}! Link an email to enable Quick Login.`);
            break;
        case 'authEmailError':
            AuthUI.showLoading(false);
            AuthUI.showError(d.message || 'Could not save email.');
            break;
        case 'authEmailSaved':
            AuthUI.showLoading(true, 'Logging in...');
            break;
        case 'authQuickLoginStart':
            AuthUI.showLoading(true, `Quick login: ${d.username || ''}...`);
            break;
        case 'authAccountFill':
            AuthUI.fillAccount(d);
            break;
        case 'authShow':
            AuthUI.showLoading(false);
            break;
        case 'authHide':
            AuthUI.showLoading(false);
            AuthUI.hide();
            break;
        default:
            break;
    }
});

AuthUI.init();
