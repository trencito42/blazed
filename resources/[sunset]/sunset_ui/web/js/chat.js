const Chat = {
    messages: [],
    settingsOpen: false,
    playerId: 0,
    playerName: '',

    pageSize() {
        return ChatSettings?.settings?.pageSize || 10;
    },

    maxMessages() {
        return Math.max(80, this.pageSize() * 8);
    },

    add(msg) {
        this.messages.push(msg);
        const cap = this.maxMessages();
        let trimmed = false;
        while (this.messages.length > cap) {
            this.messages.shift();
            trimmed = true;
        }
        if (this.isChatOpen()) {
            if (this.hasMessageSelection()) {
                this._pendingRender = true;
                return;
            }
            if (trimmed) {
                this.render();
                return;
            }
            this.appendMessage(msg);
            return;
        }
        this.render();
    },

    onSettingsChange() {
        const cap = this.maxMessages();
        while (this.messages.length > cap) this.messages.shift();
        this.render();
    },

    formatTime(m) {
        const raw = String(m?.time ?? '').trim();
        if (!raw) return '';
        if (raw.startsWith('[')) return raw;
        return `[${raw}]`;
    },

    splitClanParts(m) {
        const tag = String(m.clanTag || '').trim();
        const style = String(m.clanTagStyle || 'brackets');
        const color = String(m.clanTagColor || '#FF8C00');
        const name = SunsetPlayerIdentity?.stripTaggedName?.(m.name, tag, style)
            || String(m.name || 'Player').trim();
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

    formatClanNameHtml(m, options = {}) {
        const parts = this.splitClanParts(m);
        const esc = (v) => this.escapeHtml(v);
        let name = parts.name;
        const sid = Number(m.id) || 0;
        if (options.showId !== false && sid > 0 && !/\(\d+\)\s*$/.test(name)) {
            name = `${name} (${sid})`;
        }
        return [
            parts.prefix ? `<span class="chat-clan-tag" style="color:${esc(parts.color)}">${esc(parts.prefix)}</span>` : '',
            esc(name),
            parts.suffix ? `<span class="chat-clan-tag" style="color:${esc(parts.color)}">${esc(parts.suffix)}</span>` : '',
        ].join('');
    },

    formatClanChannelHtml(m, action = false) {
        const esc = (v) => this.escapeHtml(v);
        const time = this.formatTime(m);
        const prefix = time ? `${esc(time)} ` : '';
        const rankNum = m.clanRank ? `R${m.clanRank}` : '';
        const rankTitle = String(m.clanRankLabel || '').trim();
        const msg = esc(String(m.message ?? ''));
        const tagColor = esc(String(m.clanTagColor || '#FF8C00'));
        const nameHtml = this.formatClanNameHtml(m);

        const rankBits = [];
        if (rankNum) rankBits.push(`<span class="chat-clan-rank">${esc(rankNum)}</span>`);
        if (rankTitle) rankBits.push(`<span class="chat-clan-rank-label">${esc(rankTitle)}</span>`);

        const label = action ? 'CLAN' : 'CLAN';
        const header = [
            `<strong class="chat-clan-channel__label" style="color:${tagColor}">${label}</strong>`,
            ...rankBits,
            `<span class="chat-clan-channel__name">${nameHtml}</span>`,
        ].filter(Boolean).join(' ');

        if (action) {
            return `${prefix}<span class="chat-clan-channel chat-clan-channel--action">${header} ${msg}</span>`;
        }
        return `${prefix}<span class="chat-clan-channel"><strong class="chat-clan-channel__edge">**</strong> ${header}: ${msg} <strong class="chat-clan-channel__edge">**</strong></span>`;
    },

    escapeHtml(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    formatPlayerNameHtml(m, nameOverride) {
        const row = {
            ...m,
            name: nameOverride != null ? nameOverride : m.name,
        };
        if (window.SunsetPlayerIdentity && (row.clanTag || row.factionId)) {
            return SunsetPlayerIdentity.formatNameHtml(row);
        }
        return this.escapeHtml(this.nameWithId(row.name, row.id));
    },

    lineUsesHtml(m, type) {
        if (['c', 'clan_action', 'gov', 'say', 'me', ''].includes(type)) return true;
        if (['f', 'r', 'd', 'do', 'megaphone', 'faction_action', 'radar_alert'].includes(type)) {
            return Boolean(m.clanTag || m.factionId);
        }
        return false;
    },

    formatRadioHeaderHtml(m, text) {
        const faction = String(m.factionLabel || '').trim();
        const rank = String(m.rank || '').trim();
        const header = [faction, rank, this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
        const time = this.formatTime(m);
        const prefix = time ? `${this.escapeHtml(time)} ` : '';
        const body = this.escapeHtml(text);
        return `${prefix}<strong class="chat-channel__edge">**</strong> ${header}: ${body} <strong class="chat-channel__edge">**</strong>`;
    },

    nameWithId(name, id) {
        const label = String(name || 'Player').trim();
        const sid = Number(id) || 0;
        if (sid <= 0) return label;
        if (/\(\d+\)\s*$/.test(label)) return label;
        return `${label} (${sid})`;
    },

    formatLine(m) {
        const type = String(m.type || 'say').toLowerCase().replace(/[^a-z_]/g, '') || 'say';
        const time = this.formatTime(m);
        const id = Number(m.id) || 0;
        const name = String(m.name || 'Player').trim();
        const msg = String(m.message ?? '');
        const faction = String(m.factionLabel || '').trim();
        const rank = String(m.rank || '').trim();
        const prefix = time ? `${time} ` : '';

        if (type === 'sms' || m.smsNotify) {
            const from = name || 'Unknown';
            return `${prefix}SMS from ${from}${id > 0 ? ` (${id})` : ''}: You got a new message.`;
        }

        if (type === 'announce') {
            const from = name || 'SERVER';
            return `${prefix}Public announcement from ${from}${id > 0 ? ` (${id})` : ''}: ${msg}`;
        }

        if (type === 'hq') {
            return `${prefix}HQ: ${msg}`;
        }

        if (type === 'r' || type === 'd') {
            let text = msg;
            if (text && !/over\.?$/i.test(text.trim())) {
                text = `${text.replace(/[.,\s]+$/, '')}, over.`;
            }
            return this.formatRadioHeaderHtml(m, text);
        }

        if (type === 'gov') {
            const dept = String(m.factionLabel || m.name || 'GOVERNMENT').trim();
            const issuer = [m.issuerRank || m.rank, this.formatPlayerNameHtml(m, m.issuerName || m.name)].filter(Boolean).join(' — ');
            const issuerLine = issuer ? ` (${issuer})` : '';
            return `${prefix}[GOVERNMENT] ${dept}: ${msg}${issuerLine}`;
        }

        if (type === 'f') {
            return this.formatRadioHeaderHtml(m, msg);
        }

        if (type === 'c') {
            return this.formatClanChannelHtml(m, false);
        }

        if (type === 'clan_action') {
            return this.formatClanChannelHtml(m, true);
        }

        if (type === 'faction_action') {
            const header = [faction, rank, this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
            return `${prefix}${header} ${this.escapeHtml(msg)}`.trim();
        }

        if (type === 'say' || type === '') {
            if (m.clanTag || m.factionId) {
                return `${prefix}${this.formatPlayerNameHtml(m)} says: ${this.escapeHtml(msg)}`;
            }
            const idPart = id > 0 ? ` (${id})` : '';
            return `${prefix}${name}${idPart} says: ${msg}`;
        }

        if (type === 'me') {
            if (m.clanTag || m.factionId) {
                return `${prefix}* ${this.formatPlayerNameHtml(m)} ${this.escapeHtml(msg)}`;
            }
            const idPart = id > 0 ? ` (${id})` : '';
            return `${prefix}* ${name}${idPart} ${msg}`;
        }

        if (type === 'do') {
            if (m.clanTag || m.factionId) {
                return `${prefix}** ${this.escapeHtml(msg)} (( ${this.formatPlayerNameHtml(m)} )) **`;
            }
            const idPart = id > 0 ? ` (${id})` : '';
            return `${prefix}** ${msg} (( ${name}${idPart} )) **`;
        }

        if (type === 'megaphone') {
            const speaker = name.replace(/^\[MEGAPHONE\]\s*/i, '').trim() || name;
            if (m.clanTag || m.factionId) {
                return `${prefix}[MEGAPHONE] ${this.formatPlayerNameHtml(m, speaker)}: ${this.escapeHtml(msg)}`;
            }
            return `${prefix}[MEGAPHONE] ${speaker}: ${msg}`;
        }

        if (type === 'radar') {
            return `${prefix}HQ: ${msg}`;
        }

        if (type === 'radar_alert') {
            const header = [faction, rank, this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
            return `${prefix}${header}: ${this.escapeHtml(msg)}`;
        }

        if (type === 'police_alert') {
            const tag = name || 'POLICE';
            return `${prefix}${tag}: ${msg}`;
        }

        if (type === 'command_error' || type === 'command_warn' || type === 'command_info') {
            const tag = name || 'SYSTEM';
            return `${prefix}${tag}: ${msg}`;
        }

        if (name && msg) return `${prefix}${name}: ${msg}`;
        return `${prefix}${msg || name}`;
    },

    buildMessageElement(m) {
        const el = document.createElement('div');
        const type = String(m.type || 'say').toLowerCase().replace(/[^a-z_]/g, '') || 'say';
        const factionId = String(m.factionId || '').toLowerCase().replace(/[^a-z0-9_]/g, '');
        const highlighted = new Set([
            'say', 'me', 'do', 'f', 'r', 'd', 'c', 'gov', 'announce', 'sms', 'hq',
            'megaphone', 'police_alert', 'faction_info', 'faction_action', 'clan_action', 'radar', 'radar_alert',
            'command_error', 'command_warn', 'command_info',
        ]);
        const classes = ['chat-msg'];
        if (highlighted.has(type)) classes.push(`chat-msg--${type}`);
        if (factionId) classes.push(`chat-msg--faction-${factionId}`);
        el.className = classes.join(' ');

        const line = document.createElement('span');
        line.className = 'chat-msg__line';
        if (type === 'gov') {
            const dept = String(m.factionLabel || m.name || 'GOVERNMENT').trim();
            const issuerRank = m.issuerRank || m.rank;
            const issuerNameHtml = this.formatPlayerNameHtml(m, m.issuerName || m.name);
            const issuer = [issuerRank ? this.escapeHtml(String(issuerRank)) : '', issuerNameHtml].filter(Boolean).join(' — ');
            const time = this.formatTime(m);
            const prefix = time ? `${this.escapeHtml(time)} ` : '';
            line.innerHTML = [
                `<span class="chat-gov-rule">${prefix}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span>`,
                `<span class="chat-gov-label">${prefix}GOVERNMENT ANNOUNCEMENT</span>`,
                `<span class="chat-gov-dept">${prefix}${this.escapeHtml(dept)}</span>`,
                `<span class="chat-gov-body">${prefix}${this.escapeHtml(String(m.message ?? ''))}</span>`,
                issuer ? `<span class="chat-gov-issuer">${prefix}Issued by ${issuer}</span>` : '',
                `<span class="chat-gov-rule">${prefix}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span>`,
            ].join('<br>');
            el.classList.add('chat-msg--gov-banner');
        } else if (type === 'c' || type === 'clan_action' || this.lineUsesHtml(m, type)) {
            line.innerHTML = this.formatLine(m);
        } else {
            line.textContent = this.formatLine(m);
        }
        el.appendChild(line);
        return el;
    },

    isChatOpen() {
        return Boolean($('#chat')?.classList.contains('chat-open'));
    },

    hasMessageSelection() {
        const container = $('#chat-messages');
        const sel = window.getSelection?.();
        if (!container || !sel || sel.isCollapsed || !sel.anchorNode) return false;
        const node = sel.anchorNode.nodeType === Node.TEXT_NODE
            ? sel.anchorNode.parentNode
            : sel.anchorNode;
        return container.contains(node);
    },

    render() {
        const container = $('#chat-messages');
        if (!container) return;
        container.innerHTML = '';
        const open = this.isChatOpen();
        const visible = open ? this.messages : this.messages.slice(-this.pageSize());
        visible.forEach((m) => container.appendChild(this.buildMessageElement(m)));
        container.scrollTop = container.scrollHeight;
    },

    appendMessage(msg) {
        const container = $('#chat-messages');
        if (!container) return;
        container.appendChild(this.buildMessageElement(msg));
        container.scrollTop = container.scrollHeight;
    },

    toggleSettings(force) {
        const popover = $('#chat-settings-popover');
        if (!popover) return;
        const next = typeof force === 'boolean' ? force : !this.settingsOpen;
        this.settingsOpen = next;
        popover.classList.toggle('hidden', !next);
        if (next) {
            ChatSettings.init();
            ChatSettings.syncControls();
        }
    },

    setContext(data) {
        const row = data || {};
        this.playerId = Number(row.playerId) || 0;
        this.playerName = String(row.playerName || '').trim();
    },

    toggle(open, data) {
        const chat = $('#chat');
        const wrap = $('#chat-input-wrap');
        const input = $('#chat-input');
        if (open) {
            this.setContext(data);
            ChatSettings.init();
            document.body.classList.add('chat-ui-open');
            chat.classList.add('chat-open');
            wrap.classList.remove('hidden');
            this._pendingRender = false;
            this.render();
            setTimeout(() => {
                if (!this.isChatOpen()) return;
                input.focus({ preventScroll: true });
            }, 50);
        } else {
            this.toggleSettings(false);
            document.body.classList.remove('chat-ui-open');
            chat.classList.remove('chat-open');
            wrap.classList.add('hidden');
            this._pendingRender = false;
            this.render();
            input.value = '';
            input.blur();
        }
    },

    setInput(text, options = {}) {
        const input = $('#chat-input');
        if (!input) return;
        const next = String(text ?? '');
        if (input.value !== next) input.value = next;
        if (options.fromHistory) {
            input.focus({ preventScroll: true });
            const end = input.value.length;
            input.setSelectionRange(end, end);
        }
    },

    send() {
        const input = $('#chat-input');
        const msg = input.value.trim();
        if (!msg) { post('chatClose'); return; }
        post('chatSend', { message: msg });
        input.value = '';
    },
};

$('#chat-messages')?.addEventListener('mouseup', () => {
    if (!Chat._pendingRender) return;
    Chat._pendingRender = false;
    Chat.render();
});

$('#chat-settings-btn')?.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    Chat.toggleSettings();
});

$('#chat-input')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); Chat.send(); return; }
    if (e.key === 'ArrowUp') {
        e.preventDefault();
        post('chatHistory', { direction: 'up' });
        return;
    }
    if (e.key === 'ArrowDown') {
        e.preventDefault();
        post('chatHistory', { direction: 'down' });
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const chat = $('#chat');
    if (!chat || !chat.classList.contains('chat-open')) return;
    e.preventDefault();
    e.stopPropagation();
    if (Chat.settingsOpen) {
        Chat.toggleSettings(false);
        $('#chat-input')?.focus();
        return;
    }
    post('chatClose');
}, true);

window.Chat = Chat;
