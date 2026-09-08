(() => {
    const root = document.getElementById('player-interaction');
    const nameEl = document.getElementById('player-interaction-name');
    const idEl = document.getElementById('player-interaction-id');
    const badgeEl = document.getElementById('player-interaction-badge');
    const groupsEl = document.getElementById('player-interaction-groups');
    const closeEl = document.getElementById('player-interaction-close');
    const shadeEl = root?.querySelector('.player-interaction__shade');
    let state = null;

    const esc = (value) => String(value ?? '').replace(/[&<>'"]/g, (char) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
    })[char]);

    const postNui = (name, payload = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    }).catch(() => {});

    const ACTION_ICONS = {
        trade: '<svg viewBox="0 0 24 24"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"></path></svg>',
        give_cash: '<svg viewBox="0 0 24 24"><line x1="12" y1="1" x2="12" y2="23"></line><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path></svg>',
        show_id: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>',
        add_friend: '<svg viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="8.5" cy="7" r="4"></circle><line x1="20" y1="8" x2="20" y2="14"></line><line x1="23" y1="11" x2="17" y2="11"></line></svg>',
        add_contact: '<svg viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="8.5" cy="7" r="4"></circle><line x1="20" y1="8" x2="20" y2="14"></line><line x1="23" y1="11" x2="17" y2="11"></line></svg>',
        faction_invite: '<svg viewBox="0 0 24 24"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>',
        cuff: '<svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>',
        uncuff: '<svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>',
        frisk: '<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>',
        confiscate: '<svg viewBox="0 0 24 24"><path d="M3 6h18m-2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>',
        ticket: '<svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>',
        escort: '<svg viewBox="0 0 24 24"><circle cx="12" cy="5" r="3"></circle><path d="M12 8v13m-4-7h8"></path></svg>',
        put_vehicle: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"></rect><line x1="2" y1="10" x2="22" y2="10"></line></svg>',
        take_vehicle: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"></rect><line x1="2" y1="10" x2="22" y2="10"></line></svg>',
        heal: '<svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>',
        revive: '<svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>',
        stabilize: '<svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>',
        repair: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
        repair_vehicle: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
        default: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>'
    };

    const GROUP_CONFIG = {
        CIVILIAN: { title: 'Interacțiuni', icon: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', class: '' },
        FACTION: { title: 'Acțiuni Facțiune', icon: '<svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>', class: 'group-faction' },
        POLICE: { title: 'Departament Poliție', icon: '<svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>', class: 'group-faction' },
        MEDICAL: { title: 'Serviciu Medical', icon: '<svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>', class: 'group-faction' },
        SERVICE: { title: 'Servicii', icon: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>', class: '' },
        ADMIN: { title: 'Panou Administrare', icon: '<svg viewBox="0 0 24 24"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>', class: 'group-admin' }
    };

    function render(payload) {
        state = payload || {};
        const target = state.target || {};
        if (nameEl) nameEl.textContent = target.name || `Player #${target.id || '?'}`;
        if (idEl) idEl.textContent = String(target.id || target.targetServerId || '?');

        if (badgeEl) {
            if (target.faction) {
                badgeEl.textContent = target.faction;
                badgeEl.classList.remove('hidden', 'badge--danger');
            } else if (target.wanted?.level) {
                badgeEl.textContent = `★ ${target.wanted.level}`;
                badgeEl.classList.remove('hidden');
                badgeEl.classList.add('badge--danger');
            } else {
                badgeEl.classList.add('hidden');
            }
        }

        const grouped = new Map();
        (state.actions || []).forEach((action) => {
            const groupKey = action.group || 'CIVILIAN';
            if (!grouped.has(groupKey)) grouped.set(groupKey, []);
            grouped.get(groupKey).push(action);
        });

        if (!groupsEl) return;
        groupsEl.innerHTML = '';

        grouped.forEach((actions, groupKey) => {
            const conf = GROUP_CONFIG[groupKey] || { title: groupKey, icon: GROUP_CONFIG.CIVILIAN.icon, class: '' };
            const groupSection = document.createElement('div');
            groupSection.className = `action-group ${conf.class}`;

            const titleEl = document.createElement('div');
            titleEl.className = 'group-title';
            titleEl.innerHTML = `${conf.icon} <span>${esc(conf.title)}</span>`;
            groupSection.appendChild(titleEl);

            actions.forEach((action) => {
                const btn = document.createElement('div');
                btn.className = `act-btn ${action.danger ? 'act-btn--danger' : ''}`;
                btn.dataset.action = action.id;

                const iconSvg = ACTION_ICONS[action.id] || (action.danger ? ACTION_ICONS.cuff : ACTION_ICONS.default);

                let innerHtml = `
                    <div class="act-btn__main">
                        <div class="act-icon">${iconSvg}</div>
                        <div class="act-text">${esc(action.label)}</div>
                    </div>
                `;

                if (action.input) {
                    const input = action.input;
                    innerHtml += `
                        <div class="act-input-row" onclick="event.stopPropagation()">
                            <input type="${input.type === 'number' ? 'number' : 'text'}"
                                class="act-input"
                                data-action-input
                                placeholder="${esc(input.placeholder || input.label || 'Amount')}"
                                min="${input.min || 1}"
                                max="${input.max || 999999}"
                            >
                            <button type="button" class="act-submit" data-action-submit>OK</button>
                        </div>
                    `;
                }

                btn.innerHTML = innerHtml;

                const submitBtn = btn.querySelector('[data-action-submit]');
                const inputField = btn.querySelector('[data-action-input]');

                if (inputField && submitBtn) {
                    const fireInput = () => {
                        const val = inputField.value.trim();
                        if (!val) {
                            inputField.focus();
                            return;
                        }
                        submitBtn.disabled = true;
                        postNui('playerInteractionAction', { action: action.id, value: val });
                        setTimeout(() => { submitBtn.disabled = false; }, 600);
                    };

                    submitBtn.onclick = (e) => {
                        e.stopPropagation();
                        fireInput();
                    };

                    inputField.onkeydown = (e) => {
                        if (e.key === 'Enter') {
                            e.preventDefault();
                            fireInput();
                        }
                    };
                } else {
                    btn.onclick = () => {
                        btn.style.transform = 'scale(0.96)';
                        setTimeout(() => { btn.style.transform = ''; }, 120);
                        postNui('playerInteractionAction', { action: action.id });
                    };
                }

                groupSection.appendChild(btn);
            });

            groupsEl.appendChild(groupSection);
        });
    }

    function show(payload) {
        render(payload);
        root.classList.remove('hidden');
        root.setAttribute('aria-hidden', 'false');
        document.body.classList.add('player-interaction-open');
    }

    function hide() {
        root.classList.add('hidden');
        root.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('player-interaction-open');
        state = null;
    }

    closeEl?.addEventListener('click', () => postNui('playerInteractionClose'));
    shadeEl?.addEventListener('click', () => postNui('playerInteractionClose'));

    document.addEventListener('keydown', (event) => {
        if (!root || root.classList.contains('hidden')) return;
        const tag = (event.target && event.target.tagName) || '';
        if (tag === 'INPUT' || tag === 'TEXTAREA' || event.target?.isContentEditable) return;
        if (event.key === 'Escape' || event.key.toLowerCase() === 'g') {
            event.preventDefault();
            postNui('playerInteractionClose');
        }
    });

    window.PlayerInteraction = { show, hide, render, update: render };
})();
