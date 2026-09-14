/* ═══ DRUG PIPELINE — NUI controller ═══ */

const Drugs = {
    mode: null,
    status: null,

    esc(value) {
        return String(value ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    },

    show(data) {
        this.mode = data?.mode || 'harvest';
        this.status = data?.status || {};
        const el = $('#drugs-overlay');
        if (!el) return;
        el.classList.remove('hidden');
        this.render();
    },

    hide() {
        const el = $('#drugs-overlay');
        if (el) el.classList.add('hidden');
    },

    update(data) {
        this.status = data?.status || this.status;
        this.render();
    },

    render() {
        const body = $('#drugs-body');
        const title = $('#drugs-title');
        const sub = $('#drugs-sub');
        if (!body) return;

        const modeNames = { harvest: 'Harvest', process: 'Process Lab', sell: 'Dealer' };
        const modeColors = { harvest: '#00c800', process: '#ff9600', sell: '#ff0064' };
        if (title) title.textContent = modeNames[this.mode] || 'Drugs';
        if (sub) sub.textContent = this.mode === 'harvest' ? 'Pick raw materials from the field'
            : this.mode === 'process' ? 'Convert raw materials into product'
            : 'Sell your product for cash';

        const drugs = this.status.drugs || {};
        const entries = Object.entries(drugs);

        if (!entries.length) {
            body.innerHTML = '<div style="text-align:center;padding:30px;color:rgba(255,245,235,0.35);">No drug data available.</div>';
            return;
        }

        body.innerHTML = entries.map(([type, d]) => {
            let actions = '';
            if (this.mode === 'harvest') {
                actions = `<button type="button" class="drugs-btn" data-drugs-harvest="${this.esc(type)}">Harvest</button>`;
            } else if (this.mode === 'process') {
                actions = `<button type="button" class="drugs-btn drugs-btn--process" data-drugs-process="${this.esc(type)}" ${d.rawCount >= 2 ? '' : 'disabled'}>Process (2 raw → 1)</button>`;
            } else if (this.mode === 'sell') {
                actions = `<button type="button" class="drugs-btn drugs-btn--sell" data-drugs-sell="${this.esc(type)}" ${d.productCount > 0 ? '' : 'disabled'}>Sell 1 ($${d.basePrice})</button>`;
            }
            return `
                <div class="drugs-drug">
                    <div class="drugs-drug__name">${this.esc(d.label)}</div>
                    <div class="drugs-drug__meta">
                        <span>Raw: ${d.rawCount}x</span>
                        <span>Product: ${d.productCount}x</span>
                        <span>Base: $${d.basePrice}</span>
                    </div>
                    <div class="drugs-drug__actions">${actions}</div>
                </div>
            `;
        }).join('');

        $$('[data-drugs-harvest]').forEach((btn) => {
            btn.addEventListener('click', () => post('drugsHarvest', { spotIndex: 1 }));
        });
        $$('[data-drugs-process]').forEach((btn) => {
            btn.addEventListener('click', () => post('drugsProcess', { drugType: btn.dataset.drugsProcess }));
        });
        $$('[data-drugs-sell]').forEach((btn) => {
            btn.addEventListener('click', () => post('drugsSell', { drugType: btn.dataset.drugsSell, amount: 1 }));
        });
    },
};

window.Drugs = Drugs;

// ── Close handlers ──
$('#drugs-close')?.addEventListener('click', () => post('drugsClose'));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const overlay = $('#drugs-overlay');
    if (!overlay || overlay.classList.contains('hidden')) return;
    e.preventDefault();
    post('drugsClose');
}, true);
