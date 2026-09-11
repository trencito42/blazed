const AuthForza = {
    started: false,

    openLogin() {
        if (document.getElementById('screen-auth')?.classList.contains('hidden')) return;
        this.started = true;
        document.getElementById('auth-intro')?.classList.add('hidden');
        document.getElementById('auth-panel')?.classList.add('active');
        window.setTimeout(() => {
            const active = document.activeElement;
            if (active && (active.id === 'auth-login-pass' || active.id === 'auth-login-user' || active.tagName === 'INPUT')) return;
            const user = document.getElementById('auth-login-user');
            user?.focus({ preventScroll: true });
        }, 80);
    },

    reset() {
        this.started = false;
        this.openLogin();
    },

    bind() {
        if (this._bound) return;
        this._bound = true;
    },
};

window.AuthForza = AuthForza;
