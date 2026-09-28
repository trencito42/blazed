/* ═══ SUNSET AUTH UI — Client Presentation Controller ═══
   Only handles authentication presentation and posts events to Lua.
   Double rAF ensures zero white/black flash during loadscreen handoff. */

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
    mode: 'login', // 'login' | 'register'
    pendingSubmit: false,
    visibleGeneration: 0,

    init() {
        // Form switches
        $('#auth-go-register')?.addEventListener('click', () => this.switchMode('register'));
        $('#auth-go-login')?.addEventListener('click', () => this.switchMode('login'));

        // Login
        $('#auth-login-btn')?.addEventListener('click', () => this.submitLogin());
        $('#auth-pass')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') this.submitLogin();
        });
        $('#auth-user')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') $('#auth-pass')?.focus();
        });

        // Register
        $('#auth-register-btn')?.addEventListener('click', () => this.submitRegister());
        $('#reg-pass2')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') this.submitRegister();
        });
        $('#reg-user')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') $('#reg-email')?.focus();
        });
        $('#reg-email')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') $('#reg-pass')?.focus();
        });
        $('#reg-pass')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') $('#reg-pass2')?.focus();
        });

        // Email modal
        $('#auth-email-submit')?.addEventListener('click', () => this.submitEmail());
        $('#auth-email-input')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') this.submitEmail();
        });

        // Saved accounts list delegation
        $('#auth-accounts-list')?.addEventListener('click', (e) => {
            const card = e.target.closest('.auth-account-card');
            if (!card) return;

            const username = card.dataset.username;
            if (e.target.closest('.auth-account-card__remove')) {
                e.stopPropagation();
                post('authRemoveAccount', { username });
                return;
            }

            if (this.pendingSubmit) return;
            this.showLoading(true, 'Conectare rapidă...');
            this.pendingSubmit = true;
            post('authPickAccount', { username });
        });

        // DOM readiness is not visual readiness. Lua may safely send state now,
        // but the loadscreen must remain until show() paints its final frame.
        post('authReady', {});
        post('authDomReady', { now: Date.now() });
    },

    async waitForBackground() {
        const bg = new Image();
        bg.src = 'background.webp';
        try {
            if (typeof bg.decode === 'function') await bg.decode();
        } catch (_) { /* CSS background fallback remains usable */ }
    },

    async show(data = {}) {
        const generation = ++this.visibleGeneration;
        await this.waitForBackground();
        if (generation !== this.visibleGeneration) return;
        const screen = $('#auth-screen');
        if (screen) {
            screen.classList.add('is-visible');
            screen.setAttribute('aria-hidden', 'false');
        }
        const panel = $('#auth-panel');
        if (panel) panel.classList.add('active');
        this.switchMode('login');
        if (data.accounts) {
            this.setAccounts(data.accounts);
        }
        if (data.quickLogin !== undefined) {
            const rem = $('#auth-remember');
            if (rem) rem.checked = data.quickLogin !== false;
        }
        if (data.presentation === 'quick-login') {
            this.showLoading(true, data.loadingText || 'Signing in...');
        } else {
            this.showLoading(false);
        }
        requestAnimationFrame(() => requestAnimationFrame(() => {
            if (generation !== this.visibleGeneration || !screen?.classList.contains('is-visible')) return;
            post('authVisibleRendered', { now: Date.now(), presentation: data.presentation || 'form' });
        }));
        setTimeout(() => {
            if (data.presentation === 'quick-login') return;
            const active = document.activeElement;
            if (!active || active.tagName !== 'INPUT') {
                $('#auth-user')?.focus({ preventScroll: true });
            }
        }, 100);
    },

    hide() {
        this.visibleGeneration += 1;
        const screen = $('#auth-screen');
        if (screen) {
            screen.classList.remove('is-visible');
            screen.setAttribute('aria-hidden', 'true');
        }
        const panel = $('#auth-panel');
        if (panel) panel.classList.remove('active');
        this.showLoading(false);
        this.hideError();
        this.hideEmailModal();
        this.pendingSubmit = false;
    },

    switchMode(mode) {
        this.mode = mode;
        const isLogin = mode === 'login';
        $('#auth-form-login')?.classList.toggle('hidden', !isLogin);
        $('#auth-form-register')?.classList.toggle('hidden', isLogin);
        $('#auth-main-title').textContent = isLogin ? 'Loghează-te' : 'Înregistrare';
        this.hideError();

        setTimeout(() => {
            if (isLogin) {
                $('#auth-user')?.focus({ preventScroll: true });
            } else {
                $('#reg-user')?.focus({ preventScroll: true });
            }
        }, 50);
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
        this.showLoading(false);
        this.pendingSubmit = false;
    },

    hideError() {
        this.showError(null);
    },

    showLoading(show, label) {
        const el = $('#auth-loading');
        if (!el) return;
        el.classList.toggle('hidden', !show);
        const text = $('#auth-loading-text');
        if (text && label) text.textContent = label;
    },

    submitLogin() {
        if (this.pendingSubmit) return;
        const user = ($('#auth-user')?.value || '').trim();
        const pass = $('#auth-pass')?.value || '';
        if (!user || !pass) {
            return this.showError('Completează toate câmpurile obligatorii.');
        }

        this.hideError();
        this.showLoading(true, 'Se verifică datele...');
        this.pendingSubmit = true;

        post('authLogin', {
            username: user,
            password: pass,
            rememberQuickLogin: $('#auth-remember')?.checked !== false,
        });
    },

    submitRegister() {
        if (this.pendingSubmit) return;
        const user = ($('#reg-user')?.value || '').trim();
        const email = ($('#reg-email')?.value || '').trim();
        const pass = $('#reg-pass')?.value || '';
        const pass2 = $('#reg-pass2')?.value || '';

        if (!user || !email || !pass || !pass2) {
            return this.showError('Completează toate câmpurile obligatorii.');
        }
        if (!email.includes('@') || !email.includes('.')) {
            return this.showError('Adresă de email invalidă.');
        }
        if (pass !== pass2) {
            return this.showError('Parolele introduse nu coincid.');
        }
        if (pass.length < 6) {
            return this.showError('Parola trebuie să aibă minim 6 caractere.');
        }

        this.hideError();
        this.showLoading(true, 'Se creează contul...');
        this.pendingSubmit = true;

        post('authRegister', {
            username: user,
            email: email,
            password: pass,
            passwordConfirm: pass2,
            rememberQuickLogin: $('#reg-remember')?.checked !== false,
        });
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
        const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));

        list.innerHTML = rows.map((a) => {
            const username = String(a.username || '').trim();
            const initial = (username || '?').slice(0, 2).toUpperCase();
            const level = Number(a.level) >= 1 ? `LVL ${Math.floor(Number(a.level))}` : 'NOU';
            const totalMoney = Number(a.cash || 0) + Number(a.bank || 0);
            const funds = `$${Math.floor(totalMoney).toLocaleString('en-US')}`;

            return `
            <div class="auth-account-card" data-username="${esc(username)}">
                <div class="auth-account-card__avatar">${esc(initial)}</div>
                <div class="auth-account-card__info">
                    <div class="auth-account-card__name">${esc(username)}</div>
                    <div class="auth-account-card__meta">${esc(level)} · ${esc(funds)}</div>
                </div>
                <button type="button" class="auth-account-card__remove" title="Șterge de pe acest PC">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                </button>
            </div>`;
        }).join('');
    },

    promptEmail(username) {
        this.showLoading(false);
        this.pendingSubmit = false;
        $('#auth-email-username').textContent = username || 'tău';
        $('#auth-email-input').value = '';
        $('#auth-email-error')?.classList.add('hidden');
        $('#auth-email-modal')?.classList.remove('hidden');
        setTimeout(() => $('#auth-email-input')?.focus(), 100);
    },

    hideEmailModal() {
        $('#auth-email-modal')?.classList.add('hidden');
    },

    submitEmail() {
        const email = ($('#auth-email-input')?.value || '').trim();
        const errEl = $('#auth-email-error');
        if (!email || !email.includes('@') || !email.includes('.')) {
            if (errEl) {
                errEl.textContent = 'Introdu o adresă de email validă.';
                errEl.classList.remove('hidden');
            }
            return;
        }

        if (errEl) errEl.classList.add('hidden');
        this.showLoading(true, 'Se asociază emailul...');
        post('authSetEmail', { email });
    },
};

// Listen for incoming messages from sunset_auth / Lua
window.addEventListener('message', (event) => {
    const data = event.data || {};
    const action = data.action;
    const payload = data.data || {};

    switch (action) {
        case 'authShow':
            AuthUI.show(payload);
            break;
        case 'authHide':
            AuthUI.hide();
            break;
        case 'authAccounts':
            if (payload.accounts) AuthUI.setAccounts(payload.accounts);
            break;
        case 'authError':
            AuthUI.showError(payload.message || 'A apărut o eroare la autentificare.');
            break;
        case 'authNeedsEmail':
            AuthUI.promptEmail(payload.username);
            break;
        case 'authEmailResult':
            if (payload.ok) {
                AuthUI.hideEmailModal();
            } else if (payload.message) {
                const errEl = $('#auth-email-error');
                if (errEl) {
                    errEl.textContent = payload.message;
                    errEl.classList.remove('hidden');
                }
                AuthUI.showLoading(false);
            }
            break;
        case 'authLoading':
            AuthUI.showLoading(payload.loading !== false, payload.text);
            break;
        case 'authAccountFill':
            AuthUI.showLoading(false);
            AuthUI.pendingSubmit = false;
            if ($('#auth-user')) $('#auth-user').value = payload.username || '';
            $('#auth-pass')?.focus({ preventScroll: true });
            break;
        case 'authSuccess':
            AuthUI.showLoading(true, payload.text || 'Loading character...');
            break;
        case 'authCapturePortrait':
            if (!payload.source || !payload.username) break;
            fetch(payload.source).then((response) => response.blob()).then((blob) => {
                const reader = new FileReader();
                reader.onloadend = () => post('authSavePortrait', {
                    username: payload.username,
                    characterName: payload.characterName,
                    characterId: payload.characterId,
                    level: payload.level,
                    cash: payload.cash,
                    bank: payload.bank,
                    avatar: reader.result,
                });
                reader.readAsDataURL(blob);
            }).catch(() => {});
            break;
    }
});

document.addEventListener('DOMContentLoaded', () => {
    AuthUI.init();
});
