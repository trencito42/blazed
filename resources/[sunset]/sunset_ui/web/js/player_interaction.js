(() => {
    const root = document.getElementById('player-interaction');
    const worldTarget = document.getElementById('pi-world-target');
    const targetNameEl = document.getElementById('pi-target-name');
    const keyLetterEl = document.getElementById('pi-key-letter');
    const progressRing = document.getElementById('pi-progress-ring');
    const screenMenu = document.getElementById('pi-screen-menu');
    const menuTitleEl = document.getElementById('pi-menu-title');
    const menuItemsEl = document.getElementById('pi-menu-items');
    const inputPanel = document.getElementById('pi-input-panel');
    const inputLabel = document.getElementById('pi-input-label');
    const inputField = document.getElementById('pi-input-field');
    const inputSubmit = document.getElementById('pi-input-submit');

    const RING_RADIUS = 16;
    const HOLD_MS = 800;
    const circumference = 2 * Math.PI * RING_RADIUS;
    let state = null;
    let pendingInputAction = null;
    let promptVisible = false;
    let holdRaf = null;
    let isHolding = false;
    let screenMenuOpen = false;

    if (progressRing) {
        progressRing.style.strokeDasharray = `${circumference} ${circumference}`;
        progressRing.style.strokeDashoffset = String(circumference);
    }

    const esc = (value) => String(value ?? '').replace(/[&<>'"]/g, (char) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
    })[char]);

    const postNui = (name, payload = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    }).catch(() => {});

    const ACTION_ICONS = {
        trade: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"></path></svg>',
        give_cash: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="2" y="6" width="20" height="12" rx="2"></rect><circle cx="12" cy="12" r="3"></circle></svg>',
        show_id: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"></rect><circle cx="9" cy="11" r="2"></circle><path d="M15 9h4M15 13h4M5 17c0-2 2-3 4-3s4 1 4 3"></path></svg>',
        add_friend: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><line x1="19" y1="8" x2="19" y2="14"></line><line x1="22" y1="11" x2="16" y2="11"></line></svg>',
        add_contact: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><line x1="19" y1="8" x2="19" y2="14"></line><line x1="22" y1="11" x2="16" y2="11"></line></svg>',
        faction_invite: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M22 11l-3 3-2-2"></path></svg>',
        cuff: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="8" rx="2"></rect><path d="M7 11V8a5 5 0 0 1 10 0v3"></path></svg>',
        uncuff: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="8" rx="2"></rect><path d="M7 11V8a5 5 0 0 1 10 0v3"></path></svg>',
        frisk: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>',
        confiscate: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M3 6h18"></path><path d="M8 6V4h8v2"></path><path d="M6 6l1 14h10l1-14"></path></svg>',
        ticket: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>',
        escort: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><circle cx="9" cy="7" r="4"></circle><path d="M3 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2"></path><path d="M16 11l2 2 4-4"></path></svg>',
        put_vehicle: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M5 17h14l-1-7H6z"></path><circle cx="7.5" cy="17.5" r="1.5"></circle><circle cx="16.5" cy="17.5" r="1.5"></circle></svg>',
        take_vehicle: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M5 17h14l-1-7H6z"></path><circle cx="7.5" cy="17.5" r="1.5"></circle><circle cx="16.5" cy="17.5" r="1.5"></circle></svg>',
        heal: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8z"></path></svg>',
        revive: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"></path></svg>',
        stabilize: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"></path></svg>',
        repair: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
        repair_vehicle: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
        lockpick_vehicle: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M21 2l-2 2m-7.6 7.6a6.5 6.5 0 1 0 2.2 2.2L21 8l-4-4-2.4 2.4z"></path></svg>',
        sell_stolen_car: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M5 17h14l-1-7H6z"></path><circle cx="7.5" cy="17.5" r="1.5"></circle><circle cx="16.5" cy="17.5" r="1.5"></circle></svg>',
        sell_fish_247: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M2 12s3-6 10-6 10 6 10 6-3 6-10 6-10-6-10-6z"></path><circle cx="14" cy="12" r="1"></circle></svg>',
        open_shop_247: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M3 9l9-6 9 6v11a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"></path><path d="M9 21V12h6v9"></path></svg>',
        buy_business: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="14" rx="2"></rect><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"></path><line x1="12" y1="12" x2="12" y2="16"></line><line x1="10" y1="14" x2="14" y2="14"></line></svg>',
        manage_business: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M12 3v18"></path><path d="M3 12h18"></path><rect x="6" y="6" width="12" height="12" rx="2"></rect></svg>',
        get_fisherman_job: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M4 14l4-2 4 2 4-4 4 2"></path><path d="M4 18h16"></path></svg>',
        start_fishing_shift: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>',
        end_fishing_shift: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg>',
        upgrade_fishing_rod: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M12 2v20M5 7l7-5 7 5"></path></svg>',
        lsc_repair: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
        lsc_tune: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"></rect><path d="M9 9h6v6H9z"></path><path d="M9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 15h3M1 9h3M1 15h3"></path></svg>',
        close: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>',
        default: '<svg class="pi-menu-icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>',
    };

    const GROUP_CONFIG = {
        CIVILIAN: { title: 'Player Actions' },
        FACTION: { title: 'Faction Actions' },
        POLICE: { title: 'Police Department' },
        MEDICAL: { title: 'Medical Service' },
        SERVICE: { title: 'Services' },
        ADMIN: { title: 'Admin Panel' },
        FISHING: { title: 'Fishing Actions' },
        STORE: { title: 'Store' },
        BUSINESS: { title: 'Business' },
        CUSTOMS: { title: 'Vehicle Services' },
    };

    function setProgress(progress) {
        if (!progressRing) return;
        const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
        const offset = circumference - clamped * circumference;
        progressRing.style.strokeDashoffset = String(offset);
    }

    function stopHoldAnimation(resetProgress = true) {
        isHolding = false;
        if (holdRaf) {
            cancelAnimationFrame(holdRaf);
            holdRaf = null;
        }
        if (resetProgress) setProgress(0);
    }

    function startHoldAnimation() {
        if (screenMenuOpen) return;
        stopHoldAnimation(false);
        isHolding = true;
        const startedAt = performance.now();
        const tick = () => {
            if (!isHolding || screenMenuOpen) {
                holdRaf = null;
                return;
            }
            const progress = Math.min(1, (performance.now() - startedAt) / HOLD_MS);
            setProgress(progress);
            if (progress >= 1) {
                isHolding = false;
                holdRaf = null;
                setProgress(1);
                postNui('playerInteractionHoldComplete');
                return;
            }
            holdRaf = requestAnimationFrame(tick);
        };
        holdRaf = requestAnimationFrame(tick);
    }

    function deriveMenuTitle(target, actions, payload) {
        if (payload?.menuTitle) return payload.menuTitle;
        if (target?.menuTitle) return target.menuTitle;

        const groups = [...new Set((actions || []).map((a) => a.group).filter(Boolean))];
        if (groups.length === 1) {
            const conf = GROUP_CONFIG[groups[0]];
            if (conf) return conf.title;
        }
        if (target?.name) return `Actions - ${String(target.name).toUpperCase()}`;
        return 'Player Actions';
    }

    function hideInputPanel() {
        pendingInputAction = null;
        inputPanel?.classList.add('hidden');
        if (inputField) inputField.value = '';
    }

    function showInputPanel(action) {
        pendingInputAction = action;
        const input = action.input || {};
        if (inputLabel) inputLabel.textContent = action.label || 'Enter value';
        if (inputField) {
            inputField.type = input.type === 'number' ? 'number' : 'text';
            inputField.placeholder = input.placeholder || input.label || '';
            if (input.min != null) inputField.min = String(input.min);
            if (input.max != null) inputField.max = String(input.max);
            inputField.value = '';
        }
        inputPanel?.classList.remove('hidden');
        setTimeout(() => inputField?.focus(), 30);
    }

    function fireInputAction() {
        if (!pendingInputAction || !inputField) return;
        const val = inputField.value.trim();
        if (!val) {
            inputField.focus();
            return;
        }
        if (inputSubmit) inputSubmit.disabled = true;
        postNui('playerInteractionAction', { action: pendingInputAction.id, value: val });
        hideInputPanel();
        setTimeout(() => {
            if (inputSubmit) inputSubmit.disabled = false;
        }, 600);
    }

    function renderMenu(payload) {
        state = payload || {};
        const actions = state.actions || [];
        const target = state.target || {};

        if (menuTitleEl) menuTitleEl.textContent = deriveMenuTitle(target, actions, state);
        if (!menuItemsEl) return;
        menuItemsEl.innerHTML = '';
        hideInputPanel();

        actions.forEach((action) => {
            const item = document.createElement('button');
            item.type = 'button';
            item.className = `pi-menu-item${action.danger ? ' danger' : ''}`;
            item.dataset.action = action.id;
            const icon = ACTION_ICONS[action.id] || (action.danger ? ACTION_ICONS.cuff : ACTION_ICONS.default);
            item.innerHTML = `<span>${esc(action.label)}</span>${icon}`;

            item.addEventListener('click', (e) => {
                e.stopPropagation();
                if (action.input) {
                    showInputPanel(action);
                    return;
                }
                postNui('playerInteractionAction', { action: action.id });
            });

            menuItemsEl.appendChild(item);
        });

        const closeBtn = document.createElement('button');
        closeBtn.type = 'button';
        closeBtn.className = 'pi-menu-item pi-menu-item--close';
        closeBtn.innerHTML = `<span>Close</span>${ACTION_ICONS.close}`;
        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            postNui('playerInteractionClose');
        });
        menuItemsEl.appendChild(closeBtn);
    }

    function showPrompt(payload) {
        payload = payload || {};
        if (!root) return;

        if (payload.visible === false) {
            promptVisible = false;
            stopHoldAnimation(true);
            worldTarget?.classList.add('hidden');
            if (!screenMenuOpen) {
                root.classList.add('hidden');
                root.setAttribute('aria-hidden', 'true');
            }
            return;
        }

        if (payload.visible === true) {
            promptVisible = true;
            root.classList.remove('hidden');
            root.setAttribute('aria-hidden', 'false');

            if (targetNameEl) targetNameEl.textContent = payload.name || 'PLAYER';
            if (keyLetterEl) keyLetterEl.textContent = payload.key || 'G';

            const x = Number(payload.x);
            const y = Number(payload.y);
            if (worldTarget) {
                worldTarget.style.left = `${Number.isFinite(x) ? x : 50}%`;
                worldTarget.style.top = `${Number.isFinite(y) ? y : 45}%`;
                worldTarget.classList.remove('hidden');
            }
        }

        if (payload.holding === true) {
            if (!isHolding) startHoldAnimation();
        } else if (payload.holding === false) {
            if (isHolding) stopHoldAnimation(true);
        } else if (payload.progress != null) {
            setProgress(payload.progress);
        }
    }

    function openScreenMenu() {
        screenMenuOpen = true;
        stopHoldAnimation(true);
        worldTarget?.classList.add('hidden');
        screenMenu?.classList.add('active');
        root?.classList.add('is-menu-open');
        document.body.classList.add('player-interaction-open');
    }

    function closeScreenMenu() {
        screenMenuOpen = false;
        screenMenu?.classList.remove('active');
        root?.classList.remove('is-menu-open');
        document.body.classList.remove('player-interaction-open');
        hideInputPanel();
        setProgress(0);
    }

    function show(payload) {
        if (!root) return;
        renderMenu(payload);
        root.classList.remove('hidden');
        root.setAttribute('aria-hidden', 'false');
        openScreenMenu();
    }

    function hide() {
        closeScreenMenu();
        worldTarget?.classList.add('hidden');
        root?.classList.add('hidden');
        root?.setAttribute('aria-hidden', 'true');
        promptVisible = false;
        state = null;
    }

    inputSubmit?.addEventListener('click', (e) => {
        e.stopPropagation();
        fireInputAction();
    });

    inputField?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            fireInputAction();
        }
        if (e.key === 'Escape') {
            e.preventDefault();
            hideInputPanel();
        }
    });

    document.addEventListener('keydown', (event) => {
        if (!root || root.classList.contains('hidden')) return;
        if (!screenMenu?.classList.contains('active')) return;
        const tag = (event.target && event.target.tagName) || '';
        if (tag === 'INPUT' || tag === 'TEXTAREA' || event.target?.isContentEditable) return;
        if (event.key === 'Escape') {
            event.preventDefault();
            postNui('playerInteractionClose');
        }
    });

    window.PlayerInteraction = {
        show,
        hide,
        render: renderMenu,
        update: renderMenu,
        showPrompt,
        setProgress,
    };
})();
