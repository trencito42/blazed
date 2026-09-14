/* ═══ MARRIAGE PROPOSAL — NUI controller ═══ */

const Marriage = {
    esc(value) {
        return String(value ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    },

    showProposal(data) {
        const el = $('#marriage-overlay');
        if (!el) return;
        el.classList.remove('hidden');
        const text = $('#marriage-text');
        if (text) {
            text.innerHTML = `<strong>${this.esc(data?.fromName || 'Someone')}</strong> wants to marry you!<br>Do you accept?`;
        }
    },

    hide() {
        const el = $('#marriage-overlay');
        if (el) el.classList.add('hidden');
    },
};

window.Marriage = Marriage;

// ── Handlers ──
$('#marriage-accept')?.addEventListener('click', () => post('marriageRespond', { accept: true }));
$('#marriage-decline')?.addEventListener('click', () => post('marriageRespond', { accept: false }));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const overlay = $('#marriage-overlay');
    if (!overlay || overlay.classList.contains('hidden')) return;
    e.preventDefault();
    post('marriageClose');
}, true);
