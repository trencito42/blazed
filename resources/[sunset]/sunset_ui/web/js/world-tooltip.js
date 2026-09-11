const WorldTooltipLayer = {
    root: null,
    nodes: {},

    ensureRoot() {
        if (this.root) return this.root;
        this.root = document.getElementById('world-tooltip-layer');
        return this.root;
    },

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    renderNode(row) {
        const theme = ['npc', 'gas', 'fishing', 'trucker', 'ammo'].includes(row.badgeClass)
            ? row.badgeClass
            : (['npc', 'gas', 'fishing', 'trucker', 'ammo'].includes(row.bodyClass) ? row.bodyClass : '');
        const badgeClass = theme ? ` ${theme}` : '';
        const bodyClass = theme ? ` ${theme}` : '';
        const icon = row.icon ? `ph-fill ${this.escape(row.icon)}` : 'ph-fill ph-circle';
        const key = row.key ? `<span class="wt-key">${this.escape(row.key)}</span>` : '';
        const desc = row.desc ? `${key}${this.escape(row.desc)}` : '';
        return `
            <div class="wt-badge${badgeClass}">${this.escape(row.badge || '')}</div>
            <div class="wt-body${bodyClass}">
                <i class="${icon} wt-icon"></i>
                <div class="wt-info">
                    <div class="wt-title">${this.escape(row.title || '')}</div>
                    ${desc ? `<div class="wt-desc">${desc}</div>` : ''}
                </div>
            </div>
        `;
    },

    sync(list) {
        const root = this.ensureRoot();
        if (!root) return;
        const seen = new Set();
        (list || []).forEach((row) => {
            if (!row || !row.id) return;
            seen.add(row.id);
            let el = this.nodes[row.id];
            if (!el) {
                el = document.createElement('div');
                el.className = 'world-tooltip-3d';
                el.dataset.tooltipId = row.id;
                root.appendChild(el);
                this.nodes[row.id] = el;
            }
            if (row.visible) {
                el.innerHTML = this.renderNode(row);
                el.style.left = `${Number(row.x) || 0}%`;
                el.style.top = `${Number(row.y) || 0}%`;
                el.classList.add('is-visible');
            } else {
                el.classList.remove('is-visible');
            }
        });
        Object.keys(this.nodes).forEach((id) => {
            if (!seen.has(id)) {
                this.nodes[id].classList.remove('is-visible');
            }
        });
    },

    clear() {
        Object.values(this.nodes).forEach((el) => el.classList.remove('is-visible'));
    },
};

window.WorldTooltipLayer = WorldTooltipLayer;
