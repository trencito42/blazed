const AuthForza = {
    started: false,

    reset() {
        this.started = false;
        const intro = document.getElementById('auth-intro');
        const panel = document.getElementById('auth-panel');
        intro?.classList.remove('hidden');
        panel?.classList.remove('active');
    },

    dismissIntro() {
        if (this.started) return;
        if (document.getElementById('screen-auth')?.classList.contains('hidden')) return;
        this.started = true;
        document.getElementById('auth-intro')?.classList.add('hidden');
        window.setTimeout(() => {
            document.getElementById('auth-panel')?.classList.add('active');
            const user = document.getElementById('auth-login-user');
            user?.focus({ preventScroll: true });
        }, 300);
    },

    bind() {
        if (this._bound) return;
        this._bound = true;
        document.addEventListener('keydown', (event) => {
            const authScreen = document.getElementById('screen-auth');
            if (!authScreen || authScreen.classList.contains('hidden')) return;
            if (AuthForza.started) return;
            if (event.key === 'Tab' || event.key === 'Escape') return;
            AuthForza.dismissIntro();
        });
    },
};

window.AuthForza = AuthForza;
