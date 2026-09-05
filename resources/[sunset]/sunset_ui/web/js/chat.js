const Chat = {
    messages: [],
    settingsOpen: false,

    pageSize() {
        return ChatSettings?.settings?.pageSize || 10;
    },

    maxMessages() {
        return Math.max(80, this.pageSize() * 8);
    },

    add(msg) {
        this.messages.push(msg);
        const cap = this.maxMessages();
        while (this.messages.length > cap) this.messages.shift();
        this.render();
    },

    onSettingsChange() {
        const cap = this.maxMessages();
        while (this.messages.length > cap) this.messages.shift();
        this.render();
    },

    render() {
        const container = $('#chat-messages');
        if (!container) return;
        container.innerHTML = '';
        const open = $('#chat')?.classList.contains('chat-open');
        const visible = open ? this.messages : this.messages.slice(-this.pageSize());
        visible.forEach((m) => {
            const el = document.createElement('div');
            el.className = 'chat-msg' + (m.type === 'me' ? ' chat-msg--me' : m.type === 'do' ? ' chat-msg--do' : '');
            const time = document.createElement('span');
            time.className = 'chat-msg__time';
            time.textContent = String(m.time ?? '');

            const id = document.createElement('span');
            id.className = 'chat-msg__id';
            id.textContent = `[${String(m.id ?? '?')}]`;

            const name = document.createElement('span');
            name.className = 'chat-msg__name';
            name.textContent = `${String(m.name ?? 'Player')}:`;

            el.append(time, id, name, document.createTextNode(` ${String(m.message ?? '')}`));
            container.appendChild(el);
        });
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

    toggle(open) {
        const chat = $('#chat');
        const wrap = $('#chat-input-wrap');
        const input = $('#chat-input');
        if (open) {
            ChatSettings.init();
            document.body.classList.add('chat-ui-open');
            chat.classList.add('chat-open');
            wrap.classList.remove('hidden');
            this.render();
            setTimeout(() => {
                input.focus();
                input.setSelectionRange(input.value.length, input.value.length);
            }, 50);
        } else {
            this.toggleSettings(false);
            document.body.classList.remove('chat-ui-open');
            chat.classList.remove('chat-open');
            wrap.classList.add('hidden');
            this.render();
            input.value = '';
            input.blur();
        }
    },

    setInput(text) {
        const input = $('#chat-input');
        if (!input) return;
        input.value = text || '';
        input.focus();
        input.setSelectionRange(input.value.length, input.value.length);
    },

    send() {
        const input = $('#chat-input');
        const msg = input.value.trim();
        if (!msg) { post('chatClose'); return; }
        post('chatSend', { message: msg });
        input.value = '';
    },
};

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
