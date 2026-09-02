const fill = document.getElementById('progress-fill');
const percent = document.getElementById('progress-percent');
const statusText = document.getElementById('status-text');
const loadscreen = document.getElementById('loadscreen');

let current = 0;

function setProgress(value) {
    current = Math.min(100, Math.max(0, value));
    fill.style.width = current + '%';
    percent.textContent = Math.round(current) + '%';
}

let simulated = 0;
const sim = setInterval(() => {
    if (current < 85 && simulated < 85) {
        simulated += Math.random() * 2.5;
        setProgress(simulated);
    }
}, 350);

window.addEventListener('message', (e) => {
    const data = e.data;
    if (data.eventName === 'loadProgress') {
        clearInterval(sim);
        setProgress((data.loadFraction || 0) * 100);
        statusText.textContent = 'Loading';
    }
});

setProgress(1);
