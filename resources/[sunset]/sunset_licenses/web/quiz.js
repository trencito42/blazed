const KEYS = ['A', 'B', 'C', 'D'];

const state = {
    licenseType: null,
    questions: [],
    answers: {},
    index: 0,
};

const quizEl = document.getElementById('quiz');
const titleEl = document.getElementById('quiz-title');
const introEl = document.getElementById('quiz-intro');
const progressEl = document.getElementById('quiz-progress');
const questionEl = document.getElementById('quiz-question');
const optionsEl = document.getElementById('quiz-options');
const prevBtn = document.getElementById('quiz-prev');
const nextBtn = document.getElementById('quiz-next');
const submitBtn = document.getElementById('quiz-submit');

function renderQuestion() {
    const total = state.questions.length;
    const idx = state.index;
    const q = state.questions[idx];
    if (!q) return;

    progressEl.textContent = `Question ${idx + 1} / ${total}`;
    questionEl.textContent = q.q || '';
    optionsEl.innerHTML = '';

    (q.options || []).forEach((opt, oi) => {
        const value = oi + 1;
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'quiz-option';
        if (state.answers[idx + 1] === value) btn.classList.add('selected');
        btn.innerHTML = `<span class="quiz-option-key">${KEYS[oi] || value}</span><span class="quiz-option-text">${opt}</span>`;
        btn.addEventListener('click', () => {
            state.answers[idx + 1] = value;
            renderQuestion();
            updateNav();
        });
        optionsEl.appendChild(btn);
    });

    prevBtn.classList.toggle('hidden', idx === 0);
    nextBtn.classList.toggle('hidden', idx >= total - 1);
    submitBtn.classList.toggle('hidden', idx < total - 1);
    updateNav();
}

function updateNav() {
    const hasAnswer = state.answers[state.index + 1] != null;
    nextBtn.disabled = !hasAnswer;
    submitBtn.disabled = !state.questions.every((_, i) => state.answers[i + 1] != null);
}

function openQuiz(data) {
    state.licenseType = data.licenseType;
    state.questions = data.questions || [];
    state.answers = {};
    state.index = 0;
    titleEl.textContent = data.title || 'Theory Exam';
    introEl.textContent = data.intro || '';
    quizEl.classList.remove('hidden');
    renderQuestion();
}

function closeQuiz() {
    quizEl.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') openQuiz(data);
    if (data.action === 'hide') closeQuiz();
});

document.getElementById('quiz-close').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/licenseQuizClose`, { method: 'POST', body: '{}' });
});

prevBtn.addEventListener('click', () => {
    if (state.index > 0) {
        state.index -= 1;
        renderQuestion();
    }
});

nextBtn.addEventListener('click', () => {
    if (state.answers[state.index + 1] == null) return;
    if (state.index < state.questions.length - 1) {
        state.index += 1;
        renderQuestion();
    }
});

submitBtn.addEventListener('click', () => {
    if (!state.questions.every((_, i) => state.answers[i + 1] != null)) return;
    fetch(`https://${GetParentResourceName()}/licenseQuizSubmit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ licenseType: state.licenseType, answers: state.answers }),
    });
});

document.addEventListener('keydown', (e) => {
    if (quizEl.classList.contains('hidden')) return;
    const key = e.key.toUpperCase();
    const map = { A: 1, B: 2, C: 3, D: 4 };
    if (map[key]) {
        state.answers[state.index + 1] = map[key];
        renderQuestion();
        return;
    }
    if (e.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/licenseQuizClose`, { method: 'POST', body: '{}' });
    }
});
