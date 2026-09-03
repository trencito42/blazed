const Phone = {
    data: null,
    screen: 'home',
    chatTarget: null,

    init() {
        if (this._ready) return;
        this._ready = true;

        this.setupHomeBar();
        this.setupKeys();

        $$('[data-phone-app]').forEach((btn) => {
            btn.addEventListener('click', () => this.openApp(btn.dataset.phoneApp));
        });
        $('#phone-back-messages')?.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            this.goHome();
        });
        $('#phone-back-contacts')?.addEventListener('click', (e) => {
            e.preventDefault();
            this.goHome();
        });
        $('#phone-back-chat')?.addEventListener('click', (e) => {
            e.preventDefault();
            this.showView('messages');
        });
        $('#phone-back-bank')?.addEventListener('click', (e) => {
            e.preventDefault();
            this.goHome();
        });
        $('#phone-back-settings')?.addEventListener('click', (e) => {
            e.preventDefault();
            this.goHome();
        });
        $('#phone-chat-send')?.addEventListener('click', () => this.sendMessage());
        $('#phone-chat-input')?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') this.sendMessage();
        });
    },

    setupKeys() {
        if (this._keysBound) return;
        this._keysBound = true;
        window.addEventListener('keydown', (e) => {
            const device = $('#phone-device');
            if (!device?.classList.contains('is-open')) return;

            if (e.key === 'Escape') {
                e.preventDefault();
                e.stopPropagation();
                this.goHomeOrClose();
                return;
            }
            if (e.key === 'p' || e.key === 'P') {
                if (e.target.matches('input, textarea')) return;
                e.preventDefault();
                e.stopPropagation();
                post('phoneClose', {});
            }
        });
    },

    setupHomeBar() {
        const zone = $('#phone-home-zone');
        const bar = $('#phone-home-indicator');
        if (!zone || zone._bound) return;
        zone._bound = true;

        let startY = 0;
        let dragging = false;
        let moved = false;

        const finish = (endY) => {
            const delta = startY - endY;
            zone.classList.remove('is-dragging');
            if (bar) bar.style.transform = '';
            dragging = false;

            if (delta > 30) {
                this.goHomeOrClose();
            } else if (!moved) {
                this.goHomeOrClose();
            }
            moved = false;
        };

        zone.addEventListener('pointerdown', (e) => {
            e.preventDefault();
            zone.setPointerCapture(e.pointerId);
            startY = e.clientY;
            dragging = true;
            moved = false;
            zone.classList.add('is-dragging');
        });

        zone.addEventListener('pointermove', (e) => {
            if (!dragging) return;
            const delta = startY - e.clientY;
            if (Math.abs(delta) > 4) moved = true;
            if (delta > 0 && bar) {
                bar.style.transform = `translateY(-${Math.min(delta * 0.45, 36)}px)`;
            }
        });

        zone.addEventListener('pointerup', (e) => {
            if (!dragging) return;
            zone.releasePointerCapture(e.pointerId);
            finish(e.clientY);
        });

        zone.addEventListener('pointercancel', (e) => {
            if (!dragging) return;
            finish(e.clientY);
        });
    },

    formatMoney(n) {
        return '$' + (Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    },

    updateClock() {
        const now = new Date();
        const el = $('#phone-time');
        if (el) el.textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    },

    show(payload) {
        this.init();
        this.data = payload || {};
        this.chatTarget = null;
        this.screen = 'home';
        this.updateClock();
        if (!this._clockTimer) {
            this._clockTimer = setInterval(() => this.updateClock(), 30000);
        }
        this.renderHome();
        this.renderThreads();
        this.renderContacts();
        this.renderBank();
        this.renderSettings();
        this.showView('home');
        const device = $('#phone-device');
        device?.classList.remove('hidden');
        requestAnimationFrame(() => device?.classList.add('is-open'));
    },

    hide() {
        const device = $('#phone-device');
        device?.classList.remove('is-open');
        setTimeout(() => device?.classList.add('hidden'), 400);
        this.chatTarget = null;
    },

    update(payload) {
        this.data = payload || this.data;
        this.renderThreads();
        this.renderContacts();
        this.renderBank();
        if (this.chatTarget) {
            this.chatTarget.online = this.isContactOnline(this.chatTarget.charId);
            const sub = $('#phone-chat-subtitle');
            if (sub) sub.textContent = this.chatTarget.online ? 'Online' : 'Will deliver when online';
            this.renderChat(this.chatTarget);
        }
    },

    goHome() {
        this.chatTarget = null;
        this.showView('home');
    },

    goHomeOrClose() {
        if (this.screen === 'home') post('phoneClose', {});
        else this.goHome();
    },

    openApp(app) {
        this.showView(app);
    },

    showView(name) {
        this.screen = name;
        $$('.phone-view').forEach((v) => v.classList.toggle('is-active', v.dataset.view === name));
    },

    renderHome() {
        // wallpaper + dock already in HTML
    },

    buildThreads() {
        const d = this.data || {};
        const myId = d.myCharacterId;
        const threads = new Map();

        (d.messages || []).forEach((m) => {
            const isMine = m.sender_character_id === myId;
            const otherCharId = isMine ? m.receiver_character_id : m.sender_character_id;
            const otherName = isMine ? (m.receiver_name || 'Player') : (m.sender_name || 'Player');
            const key = String(otherCharId);
            const existing = threads.get(key) || {
                charId: otherCharId,
                name: otherName,
                preview: '',
                messages: [],
                online: false,
            };
            if (!existing.preview) existing.preview = m.message;
            existing.messages.push(m);
            threads.set(key, existing);
        });

        (d.contacts || []).forEach((c) => {
            const key = String(c.characterId);
            if (!key || key === 'undefined') return;
            if (!threads.has(key)) {
                threads.set(key, {
                    charId: c.characterId,
                    name: c.name,
                    preview: 'No messages yet',
                    messages: [],
                    online: true,
                });
            } else {
                const t = threads.get(key);
                t.online = true;
                t.name = c.name || t.name;
            }
        });

        return Array.from(threads.values()).sort((a, b) => {
            const ta = a.messages[0]?.id || 0;
            const tb = b.messages[0]?.id || 0;
            return tb - ta;
        });
    },

    isContactOnline(charId) {
        return (this.data?.contacts || []).some((c) => c.characterId === charId);
    },

    renderThreads() {
        const list = $('#phone-thread-list');
        if (!list) return;
        list.innerHTML = '';
        const threads = this.buildThreads();

        if (!threads.length) {
            list.innerHTML = '<p class="phone-empty">No conversations yet.<br>Open Contacts to message someone online.</p>';
            return;
        }

        threads.forEach((t) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'phone-thread';
            const initial = (t.name || '?').charAt(0).toUpperCase();
            btn.innerHTML = `
                <div class="phone-thread__avatar">${initial}</div>
                <div class="phone-thread__body">
                    <div class="phone-thread__name">${t.name}</div>
                    <div class="phone-thread__preview">${t.preview || ''}</div>
                </div>`;
            btn.addEventListener('click', () => this.openChat({
                name: t.name,
                charId: t.charId,
                online: this.isContactOnline(t.charId),
            }));
            list.appendChild(btn);
        });
    },

    renderContacts() {
        const list = $('#phone-contact-list');
        if (!list) return;
        list.innerHTML = '';
        const contacts = this.data?.contacts || [];

        if (!contacts.length) {
            list.innerHTML = '<p class="phone-empty">No players online right now.</p>';
            return;
        }

        contacts.forEach((c) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'phone-contact';
            const initial = (c.name || '?').charAt(0).toUpperCase();
            btn.innerHTML = `
                <div class="phone-thread__avatar">${initial}</div>
                <div class="phone-thread__body">
                    <div class="phone-thread__name">${c.name}</div>
                    <div class="phone-contact__meta">ID ${c.serverId} · Online</div>
                </div>`;
            btn.addEventListener('click', () => this.openChat({
                name: c.name,
                charId: c.characterId,
                online: true,
            }));
            list.appendChild(btn);
        });
    },

    openChat(target) {
        this.chatTarget = target;
        const online = this.isContactOnline(target.charId);
        $('#phone-chat-title').textContent = target.name || 'Chat';
        const sub = $('#phone-chat-subtitle');
        if (sub) sub.textContent = online ? 'Online' : 'Will deliver when online';
        this.renderChat(target);
        this.showView('chat');
    },

    renderChat(target) {
        const wrap = $('#phone-chat-messages');
        if (!wrap || !this.data) return;
        wrap.innerHTML = '';
        const myId = this.data.myCharacterId;

        const msgs = (this.data.messages || []).filter((m) => {
            if (target.charId) {
                return m.sender_character_id === target.charId || m.receiver_character_id === target.charId;
            }
            return false;
        }).reverse();

        if (!msgs.length) {
            wrap.innerHTML = '<p class="phone-empty">Say hi 👋</p>';
            return;
        }

        msgs.forEach((m) => {
            const mine = m.sender_character_id === myId;
            const bubble = document.createElement('div');
            bubble.className = `phone-bubble ${mine ? 'phone-bubble--out' : 'phone-bubble--in'}`;
            bubble.textContent = m.message;
            wrap.appendChild(bubble);
        });
        wrap.scrollTop = wrap.scrollHeight;
    },

    sendMessage() {
        const input = $('#phone-chat-input');
        const message = (input?.value || '').trim();
        if (!message || !this.chatTarget?.charId) {
            if (!this.chatTarget?.charId) notify('Invalid contact', 'error');
            return;
        }
        post('phoneSend', {
            targetCharacterId: this.chatTarget.charId,
            message,
        });
        if (input) input.value = '';
    },

    renderBank() {
        const d = this.data || {};
        $('#phone-bank-total').textContent = this.formatMoney((d.cash || 0) + (d.bank || 0));
        $('#phone-bank-cash').textContent = this.formatMoney(d.cash);
        $('#phone-bank-bank').textContent = this.formatMoney(d.bank);
    },

    renderSettings() {
        const d = this.data || {};
        const name = d.myName || 'Player';
        $('#phone-settings-name').textContent = name;
        $('#phone-settings-id').textContent = `Server ID: ${d.myId || '—'}`;
        const avatar = $('#phone-settings-avatar');
        if (avatar) avatar.textContent = name.charAt(0).toUpperCase();
    },
};

window.Phone = Phone;
