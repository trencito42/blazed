/* ═══ VEHICLE IMPOUND — NUI controller ═══ */

const Impound = {
    vehicles: [],

    esc(value) {
        return String(value ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    },

    show(data) {
        this.vehicles = data?.vehicles || [];
        const el = $('#impound-overlay');
        if (!el) return;
        el.classList.remove('hidden');
        this.render();
    },

    hide() {
        const el = $('#impound-overlay');
        if (el) el.classList.add('hidden');
    },

    update(data) {
        this.vehicles = data?.vehicles || [];
        this.render();
    },

    render() {
        const body = $('#impound-body');
        if (!body) return;

        if (!this.vehicles.length) {
            body.innerHTML = `
                <div class="impound-empty">
                    <i class="ph-bold ph-car"></i>
                    No impounded vehicles.<br>Your vehicles are safe!
                </div>
            `;
            return;
        }

        body.innerHTML = this.vehicles.map((v) => `
            <div class="impound-vehicle">
                <div class="impound-vehicle__icon"><i class="ph-fill ph-car-profile"></i></div>
                <div class="impound-vehicle__info">
                    <div class="impound-vehicle__plate">${this.esc(v.plate)}</div>
                    <div class="impound-vehicle__meta">
                        <span>${this.esc(v.model)}</span>
                        <span>Reason: ${this.esc(v.reason)}</span>
                        <span>${v.daysHeld > 0 ? `${v.daysHeld} day(s) held` : 'Today'}</span>
                        <span>By: ${this.esc(v.impoundedBy)}</span>
                    </div>
                </div>
                <div class="impound-vehicle__fee">$${Number(v.fee).toLocaleString()}</div>
                <button type="button" class="impound-vehicle__btn" data-impound-recover="${v.impoundId}">Recover</button>
            </div>
        `).join('');

        $$('[data-impound-recover]').forEach((btn) => {
            btn.addEventListener('click', () => {
                post('impoundRecover', { impoundId: Number(btn.dataset.impoundRecover) });
            });
        });
    },
};

window.Impound = Impound;

// ── Close handlers ──
$('#impound-close')?.addEventListener('click', () => post('impoundClose'));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const overlay = $('#impound-overlay');
    if (!overlay || overlay.classList.contains('hidden')) return;
    e.preventDefault();
    post('impoundClose');
}, true);
