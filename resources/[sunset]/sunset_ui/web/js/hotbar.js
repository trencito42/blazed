// HotbarUI — emote wheel + weapon ammo HUD only.
// The numbered 1-5 quick bar was REMOVED by design: GTA's weapon wheel is the
// single selector and items are used from the inventory. The dead slot-render
// code (renderHud/renderInventory/_renderSlot, hotbarAssign/hotbarUse posts)
// was deleted so nothing posts to unregistered NUI callbacks anymore.
const HotbarUI = {
    emotes: [],
    wheelOpen: false,
    selectedEmoteIndex: -1,
    wheelItems: [],
    wheelRadius: 200,

    init() {
        if (this._ready) return;
        this._ready = true;
        this._bindMessages();
    },

    _bindMessages() {
        window.addEventListener('message', (event) => {
            const action = event.data?.action;
            if (action === 'emoteWheelRelease') this._releaseWheel();
        });
        window.addEventListener('keydown', (e) => {
            if (!this.wheelOpen || !this.emotes.length) return;
            const num = Number(e.key);
            if (num >= 1 && num <= 9 && num <= this.emotes.length) {
                this._selectWheelItem(num - 1);
            }
        });
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
                    <div class="wheel-center-desc" id="wheel-desc">Select</div>
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
        overlay.classList.remove('hidden');
        overlay.classList.add('active');

        const hint = count
            ? 'Move view / 1-9 and release [X]'
            : 'No emotes loaded';
        this._setWheelCenter('Emotes', hint);
    },

    selectWheelFromGame(index) {
        if (!this.wheelOpen) return;
        if (!Number.isFinite(index) || index < 0) {
            this._clearWheelSelection();
            return;
        }
        this._selectWheelItem(index);
    },

    hideEmoteWheel() {
        this.wheelOpen = false;
        this.selectedEmoteIndex = -1;
        document.body.classList.remove('emote-wheel-open');
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
        this._setWheelCenter('Emotes', 'Select');
    },

    _releaseWheel() {
        if (!this.wheelOpen) return;
        const emote = this.selectedEmoteIndex >= 0 ? this.emotes[this.selectedEmoteIndex]?.name : null;
        this.hideEmoteWheel();
        post('emoteWheelClose', { emote: emote || '' });
    },
};

window.HotbarUI = HotbarUI;
