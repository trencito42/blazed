let state = { licenseType: null };

const quizEl = document.getElementById('quiz');
const formEl = document.getElementById('quiz-form');
const titleEl = document.getElementById('quiz-title');
const introEl = document.getElementById('quiz-intro');

function renderQuestions(questions) {
    formEl.innerHTML = '';
    (questions || []).forEach((q, idx) => {
        const block = document.createElement('div');
        block.className = 'question';
        const strong = document.createElement('strong');
        strong.textContent = `${idx + 1}. ${q.q}`;
        block.appendChild(strong);
        (q.options || []).forEach((opt, oi) => {
            const label = document.createElement('label');
            const input = document.createElement('input');
            input.type = 'radio';
            input.name = `q${idx}`;
            input.value = String(oi + 1);
            input.required = true;
            label.appendChild(input);
            label.appendChild(document.createTextNode(` ${opt}`));
            block.appendChild(label);
        });
        formEl.appendChild(block);
    });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') {
        state.licenseType = data.licenseType;
        titleEl.textContent = data.title || 'Theory Exam';
        introEl.textContent = data.intro || '';
        renderQuestions(data.questions);
        quizEl.classList.remove('hidden');
    }
    if (data.action === 'hide') {
        quizEl.classList.add('hidden');
    }
});

document.getElementById('quiz-close').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/licenseQuizClose`, {
        method: 'POST', body: '{}',
    });
});

formEl.addEventListener('submit', (e) => {
    e.preventDefault();
    const answers = {};
    const inputs = formEl.querySelectorAll('input[type=radio]:checked');
    inputs.forEach((input) => {
        const idx = input.name.replace('q', '');
        answers[Number(idx) + 1] = Number(input.value);
    });
    fetch(`https://${GetParentResourceName()}/licenseQuizSubmit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ licenseType: state.licenseType, answers }),
    });
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/licenseQuizClose`, {
            method: 'POST', body: '{}',
        });
    }
});
