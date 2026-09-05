const CHAT_SETTINGS_KEY = 'sunset_chat_settings';

const ChatSettings = {
    defaults: {
        fontSize: 13,
        pageSize: 10,
    },
    settings: null,

    load() {
        let stored = {};
        try {
            const raw = localStorage.getItem(CHAT_SETTINGS_KEY);
            if (raw) stored = JSON.parse(raw) || {};
        } catch (_) {
            stored = {};
        }
        this.settings = this.normalize({ ...this.defaults, ...stored });
        this.apply();
        return this.settings;
    },

    normalize(input = {}) {
        const fontSize = Math.round(Number(input.fontSize) || this.defaults.fontSize);
        const pageSize = Math.round(Number(input.pageSize) || this.defaults.pageSize);
        return {
            fontSize: Math.min(20, Math.max(10, fontSize)),
            pageSize: Math.min(20, Math.max(4, pageSize)),
        };
    },

    save(partial = {}) {
        this.settings = this.normalize({ ...this.settings, ...partial });
        try {
            localStorage.setItem(CHAT_SETTINGS_KEY, JSON.stringify(this.settings));
        } catch (_) {
            /* ignore quota errors */
        }
        this.apply();
        this.syncControls();
        if (window.Chat && typeof Chat.onSettingsChange === 'function') {
            Chat.onSettingsChange();
        }
    },

    reset() {
        this.settings = { ...this.defaults };
        try {
            localStorage.removeItem(CHAT_SETTINGS_KEY);
        } catch (_) {
            /* ignore */
        }
        this.apply();
        this.syncControls();
        if (window.Chat && typeof Chat.onSettingsChange === 'function') {
            Chat.onSettingsChange();
        }
    },

    apply() {
        const s = this.settings || this.defaults;
        const lineHeight = 1.35;
        const rowHeight = s.fontSize * lineHeight + 6;
        const pageHeight = Math.ceil(s.pageSize * rowHeight + 10);
        const vars = {
            '--chat-font-size': `${s.fontSize}px`,
            '--chat-time-size': `${Math.max(9, s.fontSize - 2)}px`,
            '--chat-input-size': `${s.fontSize + 1}px`,
            '--chat-page-height': `${pageHeight}px`,
            '--chat-line-height': String(lineHeight),
        };
        const targets = [document.documentElement, document.getElementById('chat')].filter(Boolean);
        targets.forEach((el) => {
            Object.entries(vars).forEach(([name, value]) => el.style.setProperty(name, value));
        });
    },

    syncControls() {
        const s = this.settings || this.defaults;
        const pairs = [
            ['#chat-setting-font', 'fontSize', '#chat-setting-font-val', 'px'],
            ['#chat-setting-page', 'pageSize', '#chat-setting-page-val', ' rows'],
            ['#chat-popover-font', 'fontSize', '#chat-popover-font-val', 'px'],
            ['#chat-popover-page', 'pageSize', '#chat-popover-page-val', ' rows'],
        ];

        pairs.forEach(([inputSel, key, labelSel, suffix]) => {
            const input = $(inputSel);
            const label = $(labelSel);
            if (input) input.value = String(s[key]);
            if (label) label.textContent = `${s[key]}${suffix}`;
        });
    },

    bindControls(root = document) {
        const bind = (inputSel, key, labelSel, suffix) => {
            const input = root.querySelector(inputSel);
            if (!input || input.dataset.chatBound === '1') return;
            input.dataset.chatBound = '1';
            input.addEventListener('input', () => {
                const value = Number(input.value);
                this.save({ [key]: value });
                const label = $(labelSel);
                if (label) label.textContent = `${this.settings[key]}${suffix}`;
            });
            input.addEventListener('change', () => {
                const chatInput = document.getElementById('chat-input');
                if (document.body.classList.contains('chat-ui-open') && chatInput) {
                    chatInput.focus();
                }
            });
        };

        bind('#chat-setting-font', 'fontSize', '#chat-setting-font-val', 'px');
        bind('#chat-setting-page', 'pageSize', '#chat-setting-page-val', ' rows');
        bind('#chat-popover-font', 'fontSize', '#chat-popover-font-val', 'px');
        bind('#chat-popover-page', 'pageSize', '#chat-popover-page-val', ' rows');

        root.querySelector('#chat-setting-reset')?.addEventListener('click', () => this.reset());
        root.querySelector('#chat-popover-reset')?.addEventListener('click', () => this.reset());
    },

    init() {
        if (this._ready) return;
        this._ready = true;
        if (!this.settings) this.load();
        this.bindControls();
        this.syncControls();
    },
};

window.ChatSettings = ChatSettings;

document.addEventListener('DOMContentLoaded', () => ChatSettings.init());
