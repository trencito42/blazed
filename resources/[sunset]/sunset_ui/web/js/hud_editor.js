const HudEditor = {
    panels: ['tl', 'tr', 'bl', 'bc', 'speedo'],
    positions: {},
    snapshot: null,
    active: null,
    editing: false,

    init() {
        if (this._ready) return;
        this._ready = true;

        const hud = $('#hud');
        hud?.querySelectorAll('[data-hud-panel]').forEach((el) => {
            el.addEventListener('click', (e) => {
                if (!this.editing) return;
                e.stopPropagation();
                this.select(el.dataset.hudPanel);
            });
        });

        document.addEventListener('keydown', (e) => this.onKey(e));
    },

    defaultPositions() {
        const out = {};
        this.panels.forEach((p) => { out[p] = { x: 0, y: 0 }; });
        return out;
    },

    apply(layout) {
        this.init();
        this.positions = { ...this.defaultPositions(), ...(layout || {}) };
        this.panels.forEach((id) => {
            const el = document.querySelector(`[data-hud-panel="${id}"]`);
            if (!el) return;
            const pos = this.positions[id] || { x: 0, y: 0 };
            el.style.transform = `translate(${pos.x}px, ${pos.y}px)`;
        });
    },

    select(id) {
        this.active = id;
        document.querySelectorAll('[data-hud-panel]').forEach((el) => {
            el.classList.toggle('hud-panel--selected', el.dataset.hudPanel === id);
        });
        const label = $('#hud-editor-label');
        if (label) label.textContent = `Selectat: ${id} — săgeți pentru mutare`;
    },

    move(dx, dy) {
        if (!this.active) return;
        const pos = this.positions[this.active] || { x: 0, y: 0 };
        pos.x += dx;
        pos.y += dy;
        this.positions[this.active] = pos;
        const el = document.querySelector(`[data-hud-panel="${this.active}"]`);
        if (el) el.style.transform = `translate(${pos.x}px, ${pos.y}px)`;
    },

    toggle(force) {
        this.init();
        this.editing = typeof force === 'boolean' ? force : !this.editing;
        const hud = $('#hud');
        const bar = $('#hud-editor-bar');

        hud?.classList.toggle('hud--editing', this.editing);
        bar?.classList.toggle('hidden', !this.editing);

        if (this.editing) {
            this.snapshot = JSON.parse(JSON.stringify(this.positions));
            this.select(this.active || 'tr');
            post('hudEditFocus', { focus: true });
        } else {
            document.querySelectorAll('[data-hud-panel]').forEach((el) => el.classList.remove('hud-panel--selected'));
            post('hudEditClose', {});
        }
    },

    save() {
        post('hudEditSave', this.positions);
        this.toggle(false);
    },

    reset() {
        if (this.active) {
            this.positions[this.active] = { x: 0, y: 0 };
            const el = document.querySelector(`[data-hud-panel="${this.active}"]`);
            if (el) el.style.transform = 'translate(0px, 0px)';
        }
    },

    onKey(e) {
        if (!this.editing) return;

        const step = e.shiftKey ? 5 : 1;

        if (e.key === 'Escape') {
            e.preventDefault();
            if (this.snapshot) this.apply(this.snapshot);
            this.toggle(false);
            return;
        }
        if (e.key === 'Enter') {
            e.preventDefault();
            this.save();
            return;
        }
        if (e.key === 'Backspace') {
            e.preventDefault();
            this.reset();
            return;
        }

        const map = {
            ArrowLeft: [-step, 0],
            ArrowRight: [step, 0],
            ArrowUp: [0, -step],
            ArrowDown: [0, step],
        };
        if (map[e.key]) {
            e.preventDefault();
            this.move(map[e.key][0], map[e.key][1]);
        }
    },
};

window.HudEditor = HudEditor;

// Init layout on load
document.addEventListener('DOMContentLoaded', () => HudEditor.apply());
