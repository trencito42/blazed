const Phone = {
    data: null,
    taxiData: null,
    taxiEstimate: null,
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
        $('#phone-back-taxi')?.addEventListener('click', (e) => {
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
        this.updateHomeDate(now);
    },

    updateHomeDate(now = new Date()) {
        const el = $('#phone-home-date');
        if (!el) return;
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        el.textContent = `${days[now.getDay()]}, ${months[now.getMonth()]} ${now.getDate()}`;
    },

    formatMsgTime(raw) {
        if (!raw) return '';
        const d = new Date(raw);
        if (Number.isNaN(d.getTime())) return '';
        const now = new Date();
        const sameDay = d.toDateString() === now.toDateString();
        if (sameDay) {
            return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
        }
        return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
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
            if (sub) sub.textContent = this.chatTarget.online ? 'iMessage' : 'Offline — message queued';
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
        if (app === 'taxi') {
            this.showView('taxi');
            this.taxiData = this.taxiData || null;
            this.renderTaxi();
            post('taxiRefresh', {});
            return;
        }
        this.showView(app);
    },

    showView(name) {
        this.screen = name;
        $$('.phone-view').forEach((v) => v.classList.toggle('is-active', v.dataset.view === name));
        const wp = $('#phone-wallpaper');
        if (wp) wp.classList.toggle('phone-wallpaper--app', name !== 'home');
        const island = $('.phone-dynamic-island');
        if (island) island.style.width = name === 'home' ? '108px' : '96px';
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
        const id = Number(charId);
        return (this.data?.contacts || []).some((c) => Number(c.characterId) === id);
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
            const lastMsg = t.messages[0];
            const timeStr = lastMsg ? this.formatMsgTime(lastMsg.created_at) : '';
            btn.innerHTML = `
                <div class="phone-thread__avatar">${initial}</div>
                <div class="phone-thread__body">
                    <div class="phone-thread__row">
                        <span class="phone-thread__name">${t.name}</span>
                        ${timeStr ? `<span class="phone-thread__time">${timeStr}</span>` : ''}
                    </div>
                    <div class="phone-thread__preview">${t.preview || ''}</div>
                </div>
                <span class="phone-thread__chevron">›</span>`;
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
            list.innerHTML = '<p class="phone-empty">No one else is online.<br>Players appear here when connected.</p>';
            return;
        }

        const header = document.createElement('div');
        header.className = 'phone-contacts__section';
        header.textContent = 'Online';
        list.appendChild(header);

        contacts.forEach((c) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'phone-contact';
            const initial = (c.name || '?').charAt(0).toUpperCase();
            btn.innerHTML = `
                <div class="phone-thread__avatar">${initial}</div>
                <div class="phone-thread__body">
                    <div class="phone-thread__name">${c.name}</div>
                    <div class="phone-contact__meta">${c.online !== false ? '● Online' : 'Offline'}</div>
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
        if (sub) sub.textContent = online ? 'iMessage' : 'Offline — message queued';
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
            const row = document.createElement('div');
            row.className = `phone-bubble-wrap ${mine ? 'phone-bubble-wrap--out' : 'phone-bubble-wrap--in'}`;
            const bubble = document.createElement('div');
            bubble.className = `phone-bubble ${mine ? 'phone-bubble--out' : 'phone-bubble--in'}`;
            bubble.textContent = m.message;
            const timeEl = document.createElement('span');
            timeEl.className = 'phone-bubble__time';
            timeEl.textContent = this.formatMsgTime(m.created_at);
            row.appendChild(bubble);
            row.appendChild(timeEl);
            wrap.appendChild(row);
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
        $('#phone-settings-id').textContent = `Player ID ${d.myId || '—'}`;
        const avatar = $('#phone-settings-avatar');
        if (avatar) avatar.textContent = name.charAt(0).toUpperCase();
    },

    updateTaxi(payload) {
        if (payload === null || payload === undefined) {
            if (this.screen === 'taxi') this.renderTaxi();
            return;
        }
        this.taxiData = payload || this.taxiData;
        if (this.screen !== 'taxi') return;
        if (this.taxiMode === 'map' && window.TaxiPhoneMap?.map && this.taxiData) {
            TaxiPhoneMap.update(this.taxiData?.playerPos, this.taxiDest);
            return;
        }
        this.renderTaxi();
    },

    taxiDest: null,
    taxiMode: 'map',
    taxiSearch: '',

    mountTaxiLeafletMap(d) {
        const el = $('#phone-taxi-leaflet');
        if (!el || !window.TaxiPhoneMap) return;
        TaxiPhoneMap.mount(el, {
            player: d?.playerPos,
            destination: this.taxiDest,
            onPick: (x, y) => post('taxiPickMap', { x, y }),
        });
    },

    onTaxiPick(dest) {
        if (!dest) return;
        this.taxiDest = dest;
        const labelEl = $('#phone-taxi-dest-label');
        if (labelEl) labelEl.textContent = dest.label || 'Selected pin';
        const requestBtn = $('#phone-taxi-request');
        if (requestBtn) requestBtn.disabled = false;
        if (window.TaxiPhoneMap?.map) TaxiPhoneMap.setDestination(dest.x, dest.y);
        this.estimateTaxiDest();
    },

    estimateTaxiDest() {
        if (!this.taxiDest) return;
        if (this.taxiDest.destinationId) {
            post('taxiEstimate', { destinationId: this.taxiDest.destinationId });
        } else {
            post('taxiEstimate', { destination: this.taxiDest });
        }
    },

    requestTaxiDest() {
        if (!this.taxiDest) return;
        if (this.taxiDest.destinationId) {
            post('taxiRequestRide', { destinationId: this.taxiDest.destinationId });
        } else {
            post('taxiRequestRide', { destination: this.taxiDest });
        }
    },

    renderTaxiPassengerBooking(d) {
        if (this.taxiMode === 'gps') this.taxiMode = 'map';
        const mode = this.taxiMode || 'map';
        const places = d.destinations || [];
        const q = (this.taxiSearch || '').toLowerCase();
        const filtered = places.filter((p) => !q || p.label.toLowerCase().includes(q) || (p.category || '').toLowerCase().includes(q));

        return `
            <div class="phone-taxi-card">
                <div class="phone-taxi-card__label">Where to?</div>
                <div class="phone-taxi-modes phone-taxi-modes--two">
                    <button type="button" class="phone-taxi-mode ${mode === 'map' ? 'is-active' : ''}" data-taxi-mode="map">Map</button>
                    <button type="button" class="phone-taxi-mode ${mode === 'list' ? 'is-active' : ''}" data-taxi-mode="list">Places</button>
                </div>

                <div class="phone-taxi-panel ${mode === 'map' ? '' : 'hidden'}" data-panel="map">
                    <p class="phone-taxi-hint">Tap the map to set your destination. Yellow pin = where you want to go.</p>
                    <div class="phone-taxi-map" id="phone-taxi-map">
                        <div class="phone-taxi-map__leaflet" id="phone-taxi-leaflet"></div>
                    </div>
                </div>

                <div class="phone-taxi-panel ${mode === 'list' ? '' : 'hidden'}" data-panel="list">
                    <input type="search" class="phone-taxi-search" id="phone-taxi-search" placeholder="Search: garage, hospital, taxi, shop..." value="${this.taxiSearch || ''}">
                    <div class="phone-taxi-places" id="phone-taxi-places">
                        ${filtered.slice(0, 40).map((p) => `
                            <button type="button" class="phone-taxi-place" data-place-id="${p.id}">
                                <span class="phone-taxi-place__name">${p.label}</span>
                                <span class="phone-taxi-place__cat">${p.category || ''}</span>
                            </button>`).join('')}
                        ${filtered.length > 40 ? `<p class="phone-taxi-hint">${filtered.length - 40} more — refine search</p>` : ''}
                        ${!filtered.length ? '<p class="phone-taxi-hint">No places found</p>' : ''}
                    </div>
                </div>

                <div class="phone-taxi-dest-summary">
                    <span>Destination</span>
                    <strong id="phone-taxi-dest-label">${this.taxiDest?.label || 'Not selected'}</strong>
                </div>
                <div class="phone-taxi-estimate">
                    <div><span>Distance</span><strong id="phone-taxi-distance">—</strong></div>
                    <div><span>Estimated fare</span><strong id="phone-taxi-fare">—</strong></div>
                </div>
                <button type="button" class="phone-taxi-btn phone-taxi-btn--primary" id="phone-taxi-request" ${this.taxiDest ? '' : 'disabled'}>Request cab</button>
            </div>
            <p class="phone-taxi-hint">Pickup is your current location. Drivers accept rides in the same app.</p>`;
    },

    setTaxiEstimate(payload) {
        this.taxiEstimate = payload;
        const fareEl = $('#phone-taxi-fare');
        const distEl = $('#phone-taxi-distance');
        if (fareEl && payload) fareEl.textContent = this.formatMoney(payload.fare);
        if (distEl && payload) distEl.textContent = `${(payload.distanceKm || 0).toFixed(1)} km`;
    },

    renderTaxi() {
        const body = $('#phone-taxi-body');
        const title = $('#phone-taxi-title');
        if (!body) return;

        const d = this.taxiData;
        if (!d || !d.destinations) {
            body.innerHTML = `<p class="phone-empty">${d?.error || 'Loading cab app...'}</p>`;
            if (title) title.textContent = 'Downtown Cab';
            return;
        }

        if (title) title.textContent = d.appName || 'Downtown Cab';

        const ride = d.activeRide;
        const isDriver = d.isDriver && d.onDuty;
        let html = '';

        if (isDriver) {
            const stats = d.driverStats || {};
            html += `<div class="phone-taxi-card">
                <div class="phone-taxi-card__label">Driver mode</div>
                <div class="phone-taxi-toggle">
                    <span>Available for rides</span>
                    <button type="button" class="phone-taxi-switch ${d.driverAvailable ? 'is-on' : ''}" id="phone-taxi-available-toggle">${d.driverAvailable ? 'ON' : 'OFF'}</button>
                </div>
                <div class="phone-taxi-estimate phone-taxi-estimate--stats">
                    <div><span>Today</span><strong>${stats.todayRides || 0} rides · ${this.formatMoney(stats.todayEarnings || 0)}</strong></div>
                    <div><span>This shift</span><strong>${stats.sessionRides || 0} rides · ${this.formatMoney(stats.sessionEarnings || 0)}</strong></div>
                </div>
                <p class="phone-taxi-hint">Spawn a cab at the depot marker, then accept rides here. Company keeps ${d.pricing?.companyCut || 12}%.</p>
            </div>`;

            if (ride) {
                html += this.renderActiveRideCard(ride, true);
            } else {
                const offers = d.pendingOffers || [];
                if (offers.length) {
                    html += `<div class="phone-taxi-section-title">Incoming requests</div>`;
                    offers.forEach((offer) => {
                        html += `<div class="phone-taxi-offer">
                            <div class="phone-taxi-offer__top">
                                <strong>${offer.passengerName || 'Passenger'}</strong>
                                <span class="phone-taxi-fare">${this.formatMoney(offer.fare)}</span>
                            </div>
                            <div class="phone-taxi-offer__route">→ ${offer.destination?.label || 'Destination'}</div>
                            <div class="phone-taxi-offer__meta">${(offer.distanceKm || 0).toFixed(1)} km</div>
                            <button type="button" class="phone-taxi-btn phone-taxi-btn--primary" data-taxi-accept="${offer.id}">Accept ride</button>
                        </div>`;
                    });
                } else {
                    html += `<p class="phone-empty">No ride requests right now.<br>Stay available and wait for passengers.</p>`;
                }
            }
        } else if (ride) {
            html += this.renderActiveRideCard(ride, false);
        } else {
            html += this.renderTaxiPassengerBooking(d);
        }

        if (window.TaxiPhoneMap) TaxiPhoneMap.destroy();
        body.innerHTML = html;
        this.bindTaxiEvents(d, ride, isDriver);
        if (!isDriver && !ride && this.taxiMode === 'map') {
            this.mountTaxiLeafletMap(d);
        }
        if (this.taxiEstimate) this.setTaxiEstimate(this.taxiEstimate);
    },

    renderActiveRideCard(ride, isDriver) {
        const statusLabels = {
            pending: 'Looking for a driver...',
            accepted: isDriver ? 'Go pick up passenger' : 'Driver on the way',
            in_progress: 'Trip in progress',
            completed: 'Completed',
            cancelled: 'Cancelled',
        };
        let actions = '';
        if (isDriver) {
            if (ride.status === 'accepted') {
                actions = `<button type="button" class="phone-taxi-btn phone-taxi-btn--primary" id="phone-taxi-pickup">Passenger picked up</button>
                           <button type="button" class="phone-taxi-btn" id="phone-taxi-cancel">Cancel ride</button>`;
            } else if (ride.status === 'in_progress') {
                actions = `<button type="button" class="phone-taxi-btn phone-taxi-btn--primary" id="phone-taxi-complete">Complete trip & charge</button>`;
            }
        } else if (ride.status === 'pending' || ride.status === 'accepted') {
            actions = `<button type="button" class="phone-taxi-btn" id="phone-taxi-cancel">Cancel ride</button>`;
        } else if (!isDriver && ride.status === 'in_progress') {
            const tips = (this.taxiData?.tipOptions || [25, 50, 100]).map((amt) =>
                `<button type="button" class="phone-taxi-btn phone-taxi-btn--tip" data-taxi-tip="${amt}">Tip $${amt}</button>`
            ).join('');
            actions = `<div class="phone-taxi-tips"><span>Tip your driver</span><div class="phone-taxi-tip-row">${tips}</div></div>`;
        }

        return `<div class="phone-taxi-card phone-taxi-card--active">
            <div class="phone-taxi-status phone-taxi-status--${ride.status}">${statusLabels[ride.status] || ride.status}</div>
            <div class="phone-taxi-row"><span>Destination</span><strong>${ride.destination?.label || '—'}</strong></div>
            <div class="phone-taxi-row"><span>Fare</span><strong>${this.formatMoney(ride.fare)}</strong></div>
            ${ride.driverName ? `<div class="phone-taxi-row"><span>Driver</span><strong>${ride.driverName}</strong></div>` : ''}
            ${ride.passengerName && isDriver ? `<div class="phone-taxi-row"><span>Passenger</span><strong>${ride.passengerName}</strong></div>` : ''}
            ${actions}
        </div>`;
    },

    bindTaxiEvents(d, ride, isDriver) {
        $('#phone-taxi-available-toggle')?.addEventListener('click', () => {
            const on = !d.driverAvailable;
            post('taxiSetAvailable', { available: on });
        });

        $$('[data-taxi-accept]').forEach((btn) => {
            btn.addEventListener('click', () => post('taxiAcceptRide', { rideId: Number(btn.dataset.taxiAccept) }));
        });

        $('#phone-taxi-cancel')?.addEventListener('click', () => post('taxiCancelRide', {}));
        $('#phone-taxi-pickup')?.addEventListener('click', () => post('taxiPickup', {}));
        $('#phone-taxi-complete')?.addEventListener('click', () => post('taxiComplete', {}));

        $$('[data-taxi-tip]').forEach((btn) => {
            btn.addEventListener('click', () => post('taxiTip', { amount: Number(btn.dataset.taxiTip) }));
        });

        $$('[data-taxi-mode]').forEach((btn) => {
            btn.addEventListener('click', () => {
                if (window.TaxiPhoneMap) TaxiPhoneMap.destroy();
                this.taxiMode = btn.dataset.taxiMode;
                this.renderTaxi();
            });
        });

        const search = $('#phone-taxi-search');
        if (search) {
            search.addEventListener('input', () => {
                this.taxiSearch = search.value;
                this.renderTaxi();
                const s2 = $('#phone-taxi-search');
                if (s2) {
                    s2.focus();
                    s2.setSelectionRange(s2.value.length, s2.value.length);
                }
            });
        }

        $$('[data-place-id]').forEach((btn) => {
            btn.addEventListener('click', () => post('taxiPickPlace', { destinationId: btn.dataset.placeId }));
        });

        $('#phone-taxi-request')?.addEventListener('click', () => this.requestTaxiDest());
    },
};

window.Phone = Phone;
