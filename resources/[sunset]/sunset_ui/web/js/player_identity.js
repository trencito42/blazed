const SunsetPlayerIdentity = {
    factionColors: {
        police: '#8ec8ff',
        sheriff: '#d4a85a',
        fib: '#a8d4ff',
        medic: '#ff9a9a',
        lsfd: '#ff9b6a',
        taxi: '#ffe566',
        mechanic: '#ffbf66',
        sunset_cartel: '#d8b4fe',
        night_syndicate: '#c4b5fd',
    },

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    factionColor(factionId) {
        const key = String(factionId || '').toLowerCase().replace(/[^a-z0-9_]/g, '');
        return this.factionColors[key] || '#f2f2f2';
    },

    splitClanParts(row) {
        const tag = String(row.clanTag || '').trim();
        const name = String(row.name || 'Player').trim();
        const style = String(row.clanTagStyle || 'brackets');
        const color = String(row.clanTagColor || '#FF8C00');
        if (!tag) return { prefix: '', name, suffix: '', color };
        switch (style) {
            case 'prefix_dot': return { prefix: `${tag}.`, name, suffix: '', color };
            case 'suffix_brackets': return { prefix: '', name, suffix: `[${tag}]`, color };
            case 'suffix_dot': return { prefix: '', name, suffix: `.${tag}`, color };
            case 'glued_prefix': return { prefix: tag, name, suffix: '', color };
            case 'glued_suffix': return { prefix: '', name, suffix: tag, color };
            default: return { prefix: `[${tag}]`, name, suffix: '', color };
        }
    },

    formatNameHtml(row, options = {}) {
        const esc = (value) => this.escape(value);
        const name = String(row.name || 'Player').trim();
        const id = Number(row.id) || 0;
        const showId = options.showId !== false;
        const idPart = showId && id > 0 ? ` (${id})` : '';
        const factionColor = row.factionColor || this.factionColor(row.factionId);
        const nameHtml = `<span class="player-identity__name" style="color:${esc(factionColor)}">${esc(name)}</span>${esc(idPart)}`;

        if (!row.clanTag) return nameHtml;

        const parts = this.splitClanParts(row);
        return [
            parts.prefix ? `<span class="player-identity__clan" style="color:${esc(parts.color)}">${esc(parts.prefix)}</span>` : '',
            nameHtml,
            parts.suffix ? `<span class="player-identity__clan" style="color:${esc(parts.color)}">${esc(parts.suffix)}</span>` : '',
        ].join('');
    },

    formatFactionHtml(row) {
        const label = String(row.factionLabel || row.job || 'Unemployed').trim();
        const color = row.factionColor || this.factionColor(row.factionId);
        return `<span class="player-identity__faction" style="color:${this.escape(color)}">${this.escape(label)}</span>`;
    },
};

window.SunsetPlayerIdentity = SunsetPlayerIdentity;
