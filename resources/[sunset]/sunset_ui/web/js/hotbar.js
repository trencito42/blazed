const HotbarUI = {
    slots: {},
    activeSlot: null,
    emotes: [],
    wheelOpen: false,
    selectedEmoteIndex: -1,
    wheelItems: [],
    wheelRadius: 200,

    init() {
        if (this._ready) return;
        this._ready = true;
        this._bindWheelMouse();
        this._bindMessages();
    },

    _bindMessages() {
        window.addEventListener('message', (event) => {
            const type = event.data?.type;
            if (type === 'emoteWheelRelease') this._releaseWheel();
        });
    },

    _slotAmmoHtml(slot) {
        if (!slot) return '';
        if (slot.ammoClip != null && slot.ammoTotal != null) {
            return `<span class="ammo-clip">${slot.ammoClip}</span><span class="ammo-sep">|</span><span class="ammo-total">${slot.ammoTotal}</span>`;
        }
        if (slot.kind === 'duty_weapon' && slot.ammo != null) return String(slot.ammo);
        if (slot.kind === 'item' && slot.weapon && slot.ammo != null) return String(slot.ammo);
        return '';
    },

    _slotQtyText(slot) {
        if (!slot) return '';
        if (this._slotAmmoHtml(slot)) return '';
        if (slot.kind === 'item' && slot.count > 1) return `${slot.count}x`;
        return '';
    },

    _slotIconHtml(slot) {
        if (!slot) return '<i class="ph-fill ph-square slot-icon-placeholder"></i>';
        if (slot.kind === 'emote' && slot.icon && slot.icon.startsWith('ph-')) {
            return `<i class="ph-fill ${slot.icon}"></i>`;
        }
        const icon = slot.icon || 'backpack';
        const src = /^[a-z0-9_-]+$/i.test(icon)
            ? `assets/items/${icon}.webp`
            : 'assets/items/backpack.webp';
        return `<img src="${src}" alt="" draggable="false" onerror="this.src='assets/items/backpack.webp'">`;
    },

    _renderSlot(container, slotIndex, slot, interactive) {
        const isActive = Number(this.activeSlot) === slotIndex;
        const isUsable = !!(slot && slot.usable);
        const el = document.createElement('div');
        el.className = `hotbar-slot${isActive ? ' active' : ''}${slot ? ' has-item' : ''}${isUsable ? ' is-usable' : ''}${isActive && isUsable ? ' is-ready' : ''}`;
        el.dataset.hotbarSlot = String(slotIndex);
        el.innerHTML = `
            <div class="hotbar-slot-key">${slotIndex}</div>
            <div class="hotbar-slot-icon">${this._slotIconHtml(slot)}</div>
            <div class="hotbar-slot-qty">${this._slotAmmoHtml(slot) || this._slotQtyText(slot)}</div>
        `;
        if (interactive === true) {
            el.title = slot ? `${slot.label || 'Quick slot'} — double-click to clear` : `Quick slot ${slotIndex}`;
            el.addEventListener('dblclick', () => {
                post('hotbarAssign', { slot: slotIndex, clear: true, fromInventory: true });
            });
        } else if (interactive === 'hud' && isUsable) {
            el.title = isActive
                ? `${slot.label} — click or press ${slotIndex} to use`
                : `${slot.label} — press ${slotIndex} to equip`;
            el.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                const activeNow = Number(HotbarUI.activeSlot) === slotIndex;
                post('hotbarUse', { slot: slotIndex, consume: activeNow });
            });
        }
        container.appendChild(el);
        return el;
    },

    renderWeaponAmmo(data = {}) {
        this.init();
        const hud = $('#weapon-ammo-hud');
        if (!hud) return;

        if (data.visible === false) {
            hud.classList.add('hidden');
            hud.setAttribute('aria-hidden', 'true');
            return;
        }

        const clip = Number(data.clip);
        const total = Number(data.total);
        if (!Number.isFinite(clip) || !Number.isFinite(total)) {
            hud.classList.add('hidden');
            return;
        }

        hud.classList.remove('hidden');
        hud.setAttribute('aria-hidden', 'false');
        const clipEl = $('#wah-clip');
        const totalEl = $('#wah-total');
        if (clipEl) clipEl.textContent = String(clip);
        if (totalEl) totalEl.textContent = String(total);
    },

    renderHud(data = {}) {
        this.init();
        if (data.slots) this.slots = data.slots;
        if (data.activeSlot !== undefined) this.activeSlot = data.activeSlot;

        const hud = $('#hotbar-hud');
        if (!hud) return;

        if (data.visible === false) {
            hud.classList.remove('is-visible');
            window.setTimeout(() => {
                if (!hud.classList.contains('is-visible')) hud.classList.add('hidden');
            }, 220);
            return;
        }
        hud.classList.remove('hidden');
        hud.innerHTML = '';
        for (let i = 1; i <= 5; i += 1) {
            const slot = this.slots[String(i)] || this.slots[i];
            this._renderSlot(hud, i, slot, slot?.usable ? 'hud' : false);
        }
        requestAnimationFrame(() => hud.classList.add('is-visible'));
    },

    renderInventory(data = {}) {
        this.init();
        if (data.quickslots) this.slots = data.quickslots;
        if (data.activeHotbarSlot !== undefined) this.activeSlot = data.activeHotbarSlot;

        const wrap = $('#inventory-hotbar');
        if (!wrap) return;
        wrap.innerHTML = '';
        for (let i = 1; i <= 5; i += 1) {
            this._renderSlot(wrap, i, this.slots[String(i)] || this.slots[i], true);
        }
    },

    markDropTarget(slotIndex, active) {
        const selector = `[data-hotbar-slot="${slotIndex}"]`;
        $$(selector).forEach((el) => el.classList.toggle('is-drop-target', active));
        $$(`.hotbar-slot[data-hotbar-slot="${slotIndex}"]`).forEach((el) => el.classList.toggle('is-drop-target', active));
    },

    clearDropTargets() {
        $$('.hotbar-slot.is-drop-target').forEach((el) => el.classList.remove('is-drop-target'));
    },

    showEmoteWheel(emotes = []) {
        this.init();
        this.emotes = Array.isArray(emotes) ? emotes : [];
        this.wheelOpen = true;
        this.selectedEmoteIndex = -1;

        const overlay = $('#emote-wheel');
        const container = $('#wheel-container');
        if (!overlay || !container) return;

        container.querySelectorAll('.wheel-item').forEach((el) => el.remove());
        if (!container.querySelector('.wheel-center')) {
            container.insertAdjacentHTML('afterbegin', `
                <div class="wheel-center">
                    <div class="wheel-center-title" id="wheel-title">Emotes</div>
                    <div class="wheel-center-desc" id="wheel-desc">Select one</div>
                </div>
            `);
        }

        this.wheelItems = [];
        const count = this.emotes.length;
        this.emotes.forEach((emote, index) => {
            const angle = (index / count) * (2 * Math.PI) - (Math.PI / 2);
            const x = Math.cos(angle) * this.wheelRadius;
            const y = Math.sin(angle) * this.wheelRadius;

            const div = document.createElement('div');
            div.className = 'wheel-item';
            div.style.transform = `translate(${x}px, ${y}px)`;
            div.setAttribute('data-transform', `translate(${x}px, ${y}px)`);
            div.innerHTML = `
                <i class="ph-fill ${emote.icon || 'ph-smiley'}"></i>
                <div class="wheel-item-label">${emote.label || emote.name}</div>
            `;
            container.appendChild(div);
            this.wheelItems.push(div);
        });

        document.body.classList.add('emote-wheel-open');
        document.body.classList.add('hud-chrome-hidden');
        overlay.classList.remove('hidden');
        overlay.classList.add('active');
        this._setWheelCenter('Emotes', 'Select one');
    },

    hideEmoteWheel() {
        this.wheelOpen = false;
        this.selectedEmoteIndex = -1;
        document.body.classList.remove('emote-wheel-open');
        if (!document.body.classList.contains('inventory-open')
            && !document.body.classList.contains('tuning-ui-open')) {
            document.body.classList.remove('hud-chrome-hidden');
        }
        const overlay = $('#emote-wheel');
        overlay?.classList.remove('active');
        overlay?.classList.add('hidden');
        this.wheelItems.forEach((el) => {
            el.classList.remove('hovered');
            el.style.transform = el.getAttribute('data-transform') || '';
        });
    },

    _setWheelCenter(title, desc) {
        const titleEl = $('#wheel-title');
        const descEl = $('#wheel-desc');
        if (titleEl) titleEl.textContent = title;
        if (descEl) descEl.textContent = desc;
    },

    _selectWheelItem(index) {
        if (this.selectedEmoteIndex === index) return;
        this.selectedEmoteIndex = index;
        this.wheelItems.forEach((el, i) => {
            const base = el.getAttribute('data-transform') || '';
            if (i === index) {
                el.classList.add('hovered');
                el.style.transform = `${base} scale(1.2)`;
            } else {
                el.classList.remove('hovered');
                el.style.transform = base;
            }
        });
        const emote = this.emotes[index];
        if (emote) this._setWheelCenter(emote.label || emote.name, 'Selected');
    },

    _clearWheelSelection() {
        if (this.selectedEmoteIndex === -1) return;
        this.selectedEmoteIndex = -1;
        this.wheelItems.forEach((el) => {
            el.classList.remove('hovered');
            el.style.transform = el.getAttribute('data-transform') || '';
        });
        this._setWheelCenter('Emotes', 'Select one');
    },

    _bindWheelMouse() {
        document.addEventListener('mousemove', (e) => {
            if (!this.wheelOpen || !this.emotes.length) return;

            const centerX = window.innerWidth / 2;
            const centerY = window.innerHeight / 2;
            const dx = e.clientX - centerX;
            const dy = e.clientY - centerY;
            const distance = Math.sqrt(dx * dx + dy * dy);
            if (distance < 50) {
                this._clearWheelSelection();
                return;
            }

            let mouseAngle = Math.atan2(dy, dx) + (Math.PI / 2);
            if (mouseAngle < 0) mouseAngle += 2 * Math.PI;

            const sliceSize = (2 * Math.PI) / this.emotes.length;
            let index = Math.floor((mouseAngle + sliceSize / 2) / sliceSize);
            if (index >= this.emotes.length) index = 0;
            this._selectWheelItem(index);
        });
    },

    _releaseWheel() {
        if (!this.wheelOpen) return;
        const emote = this.selectedEmoteIndex >= 0 ? this.emotes[this.selectedEmoteIndex]?.name : null;
        this.hideEmoteWheel();
        post('emoteWheelClose', { emote: emote || '' });
    },
};

window.HotbarUI = HotbarUI;
