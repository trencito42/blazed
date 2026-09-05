const Chat = {
    messages: [],
    settingsOpen: false,

    maxMessages() {
        const page = ChatSettings?.settings?.pageSize || 10;
        return Math.max(60, page * 6);
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
        this.messages.forEach((m) => {
            const el = document.createElement('div');
            el.className = 'chat-msg' + (m.type === 'me' ? ' chat-msg--me' : m.type === 'do' ? ' chat-msg--do' : '');
            el.innerHTML = `<span class="chat-msg__time">${m.time || ''}</span><span class="chat-msg__id">[${m.id}]</span><span class="chat-msg__name">${m.name}:</span> ${m.message}`;
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
            setTimeout(() => {
                input.focus();
                input.setSelectionRange(input.value.length, input.value.length);
            }, 50);
        } else {
            this.toggleSettings(false);
            document.body.classList.remove('chat-ui-open');
            chat.classList.remove('chat-open');
            wrap.classList.add('hidden');
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
    if (e.key === 'Escape') {
        e.preventDefault();
        if (Chat.settingsOpen) {
            Chat.toggleSettings(false);
            return;
        }
        post('chatClose');
        return;
    }
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

window.Chat = Chat;
