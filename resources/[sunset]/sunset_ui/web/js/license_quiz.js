const LicenseQuiz = {
    KEYS: ['A', 'B', 'C', 'D'],
    _panel: null,
    _title: null,
    _intro: null,
    _progress: null,
    _meta: null,
    _timer: null,
    _feedback: null,
    _question: null,
    _options: null,
    _prev: null,
    _next: null,
    _submit: null,
    _timerHandle: null,
    _state: {
        licenseType: null,
        questions: [],
        answers: {},
        results: {},
        index: 0,
        deadlineAt: 0,
        locked: false,
        examFee: 0,
    },

    init() {
        if (this._panel) return;
        this._panel = document.getElementById('license-quiz-panel');
        this._title = document.getElementById('license-quiz-title');
        this._intro = document.getElementById('license-quiz-intro');
        this._progress = document.getElementById('license-quiz-progress');
        this._meta = document.getElementById('license-quiz-meta');
        this._timer = document.getElementById('license-quiz-timer');
        this._feedback = document.getElementById('license-quiz-feedback');
        this._question = document.getElementById('license-quiz-question');
        this._options = document.getElementById('license-quiz-options');
        this._prev = document.getElementById('license-quiz-prev');
        this._next = document.getElementById('license-quiz-next');
        this._submit = document.getElementById('license-quiz-submit');

        document.getElementById('license-quiz-close')?.addEventListener('click', () => this.close());
        this._prev?.addEventListener('click', () => {
            if (this._state.locked || this._state.index <= 0) return;
            this._state.index -= 1;
            this._renderQuestion();
        });
        this._next?.addEventListener('click', () => this._goNext());
        this._submit?.addEventListener('click', () => this._submitExam());
        document.addEventListener('keydown', (e) => this._onKey(e));
    },

    _escape(text) {
        return String(text ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[ch]));
    },

    _formatTime(totalSec) {
        const left = Math.max(0, Number(totalSec) || 0);
        const m = Math.floor(left / 60);
        const s = left % 60;
        return `${m}:${String(s).padStart(2, '0')}`;
    },

    _stopTimer() {
        if (this._timerHandle) {
            clearInterval(this._timerHandle);
            this._timerHandle = null;
        }
    },

    _startTimer() {
        this._stopTimer();
        this._timerHandle = setInterval(() => {
            const left = Math.max(0, (this._state.deadlineAt || 0) - Math.floor(Date.now() / 1000));
            if (this._timer) {
                this._timer.textContent = this._formatTime(left);
                this._timer.classList.toggle('is-low', left > 0 && left <= 60);
                this._timer.classList.toggle('is-critical', left > 0 && left <= 15);
            }
            if (left <= 0) {
                this._stopTimer();
                this._showFeedback('TIME EXPIRED — EXAM FAILED', false, true);
                setTimeout(() => this.close(), 1400);
            }
        }, 250);
    },

    _showFeedback(text, correct, neutral = false) {
        if (!this._feedback) return;
        this._feedback.textContent = text;
        this._feedback.classList.remove('hidden', 'is-correct', 'is-wrong', 'is-neutral');
        if (neutral) this._feedback.classList.add('is-neutral');
        else this._feedback.classList.add(correct ? 'is-correct' : 'is-wrong');
    },

    _hideFeedback() {
        if (!this._feedback) return;
        this._feedback.classList.add('hidden');
        this._feedback.classList.remove('is-correct', 'is-wrong', 'is-neutral');
    },

    _updateNav() {
        const answered = this._state.answers[this._state.index + 1] != null;
        if (this._next) this._next.disabled = !answered || this._state.locked;
        if (this._submit) {
            this._submit.disabled = !this._state.questions.every((_, i) => this._state.answers[i + 1] != null)
                || this._state.locked;
        }
    },

    async _pickAnswer(value) {
        if (this._state.locked) return;
        const idx = this._state.index;
        if (this._state.answers[idx + 1] != null) return;

        this._state.locked = true;
        this._state.answers[idx + 1] = value;
        this._renderQuestion();

        try {
            const res = await fetch(`https://${GetParentResourceName()}/licenseQuizAnswer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    licenseType: this._state.licenseType,
                    questionIndex: idx + 1,
                    answer: value,
                }),
            });
            const payload = await res.json();
            const correct = payload && payload.ok && payload.correct === true;
            this._state.results[idx + 1] = correct;
            this._showFeedback(correct ? 'CORRECT' : 'WRONG', correct);
            setTimeout(() => {
                this._hideFeedback();
                this._state.locked = false;
                if (idx >= this._state.questions.length - 1) {
                    this._submitExam();
                    return;
                }
                this._state.index += 1;
                this._renderQuestion();
            }, 1300);
        } catch (_) {
            this._state.locked = false;
            this._showFeedback('COULD NOT VERIFY ANSWER', false, true);
        }
    },

    _goNext() {
        if (this._state.locked || this._state.answers[this._state.index + 1] == null) return;
        if (this._state.index < this._state.questions.length - 1) {
            this._state.index += 1;
            this._renderQuestion();
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
            const picked = this._state.answers[idx + 1];
            if (picked === value) btn.classList.add('selected');
            const result = this._state.results[idx + 1];
            if (picked === value && result === true) btn.classList.add('is-correct');
            if (picked === value && result === false) btn.classList.add('is-wrong');
            btn.disabled = this._state.locked || (picked != null && picked !== value);
            btn.innerHTML = `<span class="license-quiz-option-key">${this.KEYS[oi] || value}</span><span class="license-quiz-option-text">${this._escape(opt)}</span>`;
            btn.addEventListener('click', () => this._pickAnswer(value));
            this._options.appendChild(btn);
        });

        this._prev?.classList.toggle('hidden', idx === 0);
        this._next?.classList.toggle('hidden', idx >= total - 1);
        this._submit?.classList.toggle('hidden', idx < total - 1);
        this._updateNav();
    },

    _submitExam() {
        if (!this._state.questions.every((_, i) => this._state.answers[i + 1] != null)) return;
        this._stopTimer();
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
        if (!this._panel || this._panel.classList.contains('hidden') || this._state.locked) return;
        const key = e.key.toUpperCase();
        const map = { A: 1, B: 2, C: 3, D: 4 };
        if (map[key]) {
            this._pickAnswer(map[key]);
            return;
        }
        if (e.key === 'Escape') this.close();
    },

    close() {
        this._stopTimer();
        fetch(`https://${GetParentResourceName()}/licenseQuizClose`, { method: 'POST', body: '{}' });
    },

    show(data = {}) {
        this.init();
        if (!this._panel) return;
        this._state.licenseType = data.licenseType;
        this._state.questions = data.questions || [];
        this._state.answers = {};
        this._state.results = {};
        this._state.index = 0;
        this._state.locked = false;
        this._state.examFee = Number(data.examFee) || 0;
        this._state.deadlineAt = Number(data.deadlineAt)
            || Math.floor(Date.now() / 1000) + (Number(data.theoryTimeSec) || 600);
        if (this._title) this._title.textContent = data.title || 'Theory Exam';
        if (this._intro) this._intro.textContent = data.intro || '';
        if (this._meta) {
            const fee = this._state.examFee;
            this._meta.textContent = fee > 0 ? `Fee paid: $${fee}` : '';
        }
        if (this._timer) this._timer.textContent = this._formatTime(this._state.deadlineAt - Math.floor(Date.now() / 1000));
        this._hideFeedback();
        this._panel.classList.remove('hidden');
        this._renderQuestion();
        this._startTimer();
    },

    hide() {
        this.init();
        if (!this._panel) return;
        this._stopTimer();
        this._panel.classList.add('hidden');
    },
};

window.LicenseQuiz = LicenseQuiz;
