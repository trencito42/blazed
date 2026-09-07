const LicenseQuiz = {
    KEYS: ['A', 'B', 'C', 'D'],
    _panel: null,
    _title: null,
    _intro: null,
    _progress: null,
    _question: null,
    _options: null,
    _prev: null,
    _next: null,
    _submit: null,
    _state: {
        licenseType: null,
        questions: [],
        answers: {},
        index: 0,
    },

    init() {
        if (this._panel) return;
        this._panel = document.getElementById('license-quiz-panel');
        this._title = document.getElementById('license-quiz-title');
        this._intro = document.getElementById('license-quiz-intro');
        this._progress = document.getElementById('license-quiz-progress');
        this._question = document.getElementById('license-quiz-question');
        this._options = document.getElementById('license-quiz-options');
        this._prev = document.getElementById('license-quiz-prev');
        this._next = document.getElementById('license-quiz-next');
        this._submit = document.getElementById('license-quiz-submit');

        document.getElementById('license-quiz-close')?.addEventListener('click', () => this.close());
        this._prev?.addEventListener('click', () => {
            if (this._state.index > 0) {
                this._state.index -= 1;
                this._renderQuestion();
            }
        });
        this._next?.addEventListener('click', () => {
            if (this._state.answers[this._state.index + 1] == null) return;
            if (this._state.index < this._state.questions.length - 1) {
                this._state.index += 1;
                this._renderQuestion();
            }
        });
        this._submit?.addEventListener('click', () => this._submitExam());
        document.addEventListener('keydown', (e) => this._onKey(e));
    },

    _escape(text) {
        return String(text ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[ch]));
    },

    _updateNav() {
        const hasAnswer = this._state.answers[this._state.index + 1] != null;
        if (this._next) this._next.disabled = !hasAnswer;
        if (this._submit) {
            this._submit.disabled = !this._state.questions.every((_, i) => this._state.answers[i + 1] != null);
        }
    },

    _renderQuestion() {
        const total = this._state.questions.length;
        const idx = this._state.index;
        const q = this._state.questions[idx];
        if (!q || !this._options) return;

        if (this._progress) this._progress.textContent = `Question ${idx + 1} / ${total}`;
        if (this._question) this._question.textContent = q.q || '';
        this._options.innerHTML = '';

        (q.options || []).forEach((opt, oi) => {
            const value = oi + 1;
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'license-quiz-option';
            if (this._state.answers[idx + 1] === value) btn.classList.add('selected');
            btn.innerHTML = `<span class="license-quiz-option-key">${this.KEYS[oi] || value}</span><span class="license-quiz-option-text">${this._escape(opt)}</span>`;
            btn.addEventListener('click', () => {
                this._state.answers[idx + 1] = value;
                this._renderQuestion();
            });
            this._options.appendChild(btn);
        });

        this._prev?.classList.toggle('hidden', idx === 0);
        this._next?.classList.toggle('hidden', idx >= total - 1);
        this._submit?.classList.toggle('hidden', idx < total - 1);
        this._updateNav();
    },

    _submitExam() {
        if (!this._state.questions.every((_, i) => this._state.answers[i + 1] != null)) return;
        fetch(`https://${GetParentResourceName()}/licenseQuizSubmit`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                licenseType: this._state.licenseType,
                answers: this._state.answers,
            }),
        });
    },

    _onKey(e) {
        if (!this._panel || this._panel.classList.contains('hidden')) return;
        const key = e.key.toUpperCase();
        const map = { A: 1, B: 2, C: 3, D: 4 };
        if (map[key]) {
            this._state.answers[this._state.index + 1] = map[key];
            this._renderQuestion();
            return;
        }
        if (e.key === 'Escape') this.close();
    },

    close() {
        fetch(`https://${GetParentResourceName()}/licenseQuizClose`, { method: 'POST', body: '{}' });
    },

    show(data = {}) {
        this.init();
        if (!this._panel) return;
        this._state.licenseType = data.licenseType;
        this._state.questions = data.questions || [];
        this._state.answers = {};
        this._state.index = 0;
        if (this._title) this._title.textContent = data.title || 'Theory Exam';
        if (this._intro) this._intro.textContent = data.intro || '';
        this._panel.classList.remove('hidden');
        this._renderQuestion();
    },

    hide() {
        this.init();
        if (!this._panel) return;
        this._panel.classList.add('hidden');
    },
};

window.LicenseQuiz = LicenseQuiz;
