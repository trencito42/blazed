const AuthEmail = {
    open(username) {
        const modal = $('#auth-email-modal');
        const label = $('#auth-email-username');
        const input = $('#auth-email-input');
        const error = $('#auth-email-error');
        if (!modal) return;

        if (label) label.textContent = username || 'your account';
        if (input) {
            input.value = '';
            input.disabled = false;
        }
        this.setError('');
        modal.classList.remove('hidden');
        document.getElementById('auth-panel')?.classList.add('is-hidden');
        setTimeout(() => input?.focus({ preventScroll: true }), 40);
    },

    close() {
        $('#auth-email-modal')?.classList.add('hidden');
        document.getElementById('auth-panel')?.classList.remove('is-hidden');
    },

    setError(message) {
        const error = $('#auth-email-error');
        if (!error) return;
        const text = String(message || '').trim();
        error.textContent = text;
        error.classList.toggle('hidden', !text);
    },

    submit() {
        const input = $('#auth-email-input');
        const button = $('#auth-email-submit');
        const email = String(input?.value || '').trim();
        if (!email) {
            this.setError('Enter your email address.');
            input?.focus({ preventScroll: true });
            return;
        }
        if (button) button.disabled = true;
        if (input) input.disabled = true;
        this.setError('');
        if (window.AuthLoading) AuthLoading.beginSubmit();
        post('authSetEmail', { email });
    },

    bind() {
        if (this._ready) return;
        this._ready = true;

        $('#auth-email-submit')?.addEventListener('click', () => this.submit());
        $('#auth-email-input')?.addEventListener('keydown', (event) => {
            if (event.key === 'Enter') {
                event.preventDefault();
                this.submit();
            }
        });
    },

    onNeedsEmail(data = {}) {
        if (window.AuthLoading) AuthLoading.reset();
        this.bind();
        this.open(data.username);
    },

    onError(data = {}) {
        if (window.AuthLoading) AuthLoading.reset();
        const button = $('#auth-email-submit');
        const input = $('#auth-email-input');
        if (button) button.disabled = false;
        if (input) input.disabled = false;
        this.setError(data.message || 'Could not save your email.');
    },

    onSaved() {
        this.close();
    },
};

window.AuthEmail = AuthEmail;
