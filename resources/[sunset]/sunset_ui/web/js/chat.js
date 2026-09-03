const Chat = {
    messages: [],
    maxMessages: 50,

    add(msg) {
        this.messages.push(msg);
        if (this.messages.length > this.maxMessages) this.messages.shift();
        this.render();
    },

    render() {
        const container = $('#chat-messages');
        container.innerHTML = '';
        this.messages.forEach(m => {
            const el = document.createElement('div');
            el.className = 'chat-msg' + (m.type === 'me' ? ' chat-msg--me' : m.type === 'do' ? ' chat-msg--do' : '');
            el.innerHTML = `<span class="chat-msg__time">${m.time || ''}</span><span class="chat-msg__id">[${m.id}]</span><span class="chat-msg__name">${m.name}:</span> ${m.message}`;
            container.appendChild(el);
        });
        container.scrollTop = container.scrollHeight;
    },

    toggle(open) {
        const chat = $('#chat');
        const wrap = $('#chat-input-wrap');
        const input = $('#chat-input');
        if (open) {
            chat.classList.add('chat-open');
            wrap.classList.remove('hidden');
            setTimeout(() => {
                input.focus();
                input.setSelectionRange(input.value.length, input.value.length);
            }, 50);
        } else {
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

$('#chat-input')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); Chat.send(); return; }
    if (e.key === 'Escape') { e.preventDefault(); post('chatClose'); return; }
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
