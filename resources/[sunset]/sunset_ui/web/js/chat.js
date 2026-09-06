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
        const name = String(m.name || 'Player').trim();
        const style = String(m.clanTagStyle || 'brackets');
        const color = String(m.clanTagColor || '#FF8C00');
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

    formatClanNameHtml(m) {
        const parts = this.splitClanParts(m);
        const esc = (v) => this.escapeHtml(v);
        return [
            parts.prefix ? `<span class="chat-clan-tag" style="color:${esc(parts.color)}">${esc(parts.prefix)}</span>` : '',
            esc(parts.name),
            parts.suffix ? `<span class="chat-clan-tag" style="color:${esc(parts.color)}">${esc(parts.suffix)}</span>` : '',
        ].join('');
    },

    escapeHtml(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
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

        if (type === 'r' || type === 'd' || type === 'gov') {
            let text = msg;
            if ((type === 'r' || type === 'd') && text && !/over\.?$/i.test(text.trim())) {
                text = `${text.replace(/[.,\s]+$/, '')}, over.`;
            }
            const header = [faction, rank, this.nameWithId(name, id)].filter(Boolean).join(' ');
            return `${prefix}** ${header}: ${text} **`;
        }

        if (type === 'f') {
            const header = [faction, rank, this.nameWithId(name, id)].filter(Boolean).join(' ');
            return `${prefix}** ${header}: ${msg} **`;
        }

        if (type === 'faction_action') {
            const header = [faction, rank, this.nameWithId(name, id)].filter(Boolean).join(' ');
            return `${prefix}${header} ${msg}`.trim();
        }

        if (type === 'say' || type === '') {
            const idPart = id > 0 ? ` (${id})` : '';
            if (m.clanTag || m.factionId) {
                return `${prefix}${SunsetPlayerIdentity.formatNameHtml(m)} says: ${this.escapeHtml(msg)}`;
            }
            if (m.clanTag) {
                return `${prefix}${this.formatClanNameHtml(m)}${idPart} says: ${this.escapeHtml(msg)}`;
            }
            return `${prefix}${name}${idPart} says: ${msg}`;
        }

        if (type === 'me') {
            const idPart = id > 0 ? ` (${id})` : '';
            if (m.clanTag || m.factionId) {
                return `${prefix}* ${SunsetPlayerIdentity.formatNameHtml(m)} ${this.escapeHtml(msg)}`;
            }
            if (m.clanTag) {
                return `${prefix}* ${this.formatClanNameHtml(m)}${idPart} ${this.escapeHtml(msg)}`;
            }
            return `${prefix}* ${name}${idPart} ${msg}`;
        }

        if (type === 'do') {
            return `${prefix}** ${msg} (( ${name} )) **`;
        }

        if (type === 'megaphone') {
            const speaker = name.replace(/^\[MEGAPHONE\]\s*/i, '').trim() || name;
            return `${prefix}[MEGAPHONE] ${speaker}: ${msg}`;
        }

        if (type === 'radar') {
            return `${prefix}HQ: ${msg}`;
        }

        if (type === 'radar_alert') {
            const header = [faction, rank, this.nameWithId(name, id)].filter(Boolean).join(' ');
            return `${prefix}${header}: ${msg}`;
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
            'say', 'me', 'do', 'f', 'r', 'd', 'gov', 'announce', 'sms', 'hq',
            'megaphone', 'police_alert', 'faction_info', 'faction_action', 'radar', 'radar_alert',
            'command_error', 'command_warn', 'command_info',
        ]);
        const classes = ['chat-msg'];
        if (highlighted.has(type)) classes.push(`chat-msg--${type}`);
        if (factionId) classes.push(`chat-msg--faction-${factionId}`);
        el.className = classes.join(' ');

        const line = document.createElement('span');
        line.className = 'chat-msg__line';
        const formatted = this.formatLine(m);
        if (m.clanTag && (type === 'say' || type === 'me' || type === '')) {
            line.innerHTML = formatted;
        } else if ((type === 'say' || type === 'me' || type === '') && m.factionId) {
            line.innerHTML = formatted;
        } else {
            line.textContent = formatted;
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
