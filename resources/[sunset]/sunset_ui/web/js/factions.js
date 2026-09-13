const FACTION_ICONS = {
    legal: '<svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>',
    illegal: '<svg viewBox="0 0 24 24"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>',
    service: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
};

const FACTION_FILTER_TITLES = {
    all: 'All Factions',
    legal: 'Departamente Legale',
    illegal: 'Mafii / Gang-uri',
    service: 'Servicii / Afaceri',
};

const FactionPanels = {
    dashboard: null,
    directory: [],
    dirFilter: 'all',
    dirModalOpen: false,
    activeTab: 'overview',

    init() {
        if (this.ready) return;
        this.ready = true;

        document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
            tab.addEventListener('click', () => this.setTab(tab.dataset.factionTab));
        });

        document.querySelectorAll('[data-faction-filter]').forEach((btn) => {
            btn.addEventListener('click', () => this.setDirectoryFilter(btn.dataset.factionFilter));
        });

        document.querySelectorAll('[data-faction-action]').forEach((form) => {
            form.addEventListener('submit', (event) => {
                event.preventDefault();
                this.submitManageForm(form);
            });
        });

        $('#faction-rank-save')?.addEventListener('click', () => this.saveRankNames());
        $('#faction-manage-promote')?.addEventListener('click', () => this.manageSelected('rankDelta', 1));
        $('#faction-manage-demote')?.addEventListener('click', () => this.manageSelected('rankDelta', -1));
        $('#faction-manage-kick')?.addEventListener('click', () => this.manageSelected('kick', 'online'));
        // [FP SYSTEM] kick with 60 FP + pardon buttons
        $('#faction-manage-kick-fp')?.addEventListener('click', () => this.manageSelected('kick', 'with_fp'));
        $('#faction-manage-pardon')?.addEventListener('click', () => this.manageSelected('pardonFp'));
        $('#faction-manage-select')?.addEventListener('change', () => this.renderSelectedMemberInfo());

        $('#faction-directory-modal-close')?.addEventListener('click', () => this.closeDirectoryModal());
        $('#faction-directory-close')?.addEventListener('click', () => post('factionPanelsClose'));
        $('#faction-dir-modal-btn')?.addEventListener('click', () => this.applyFaction());
        $('#faction-directory-modal')?.addEventListener('click', (e) => {
            if (e.target?.id === 'faction-directory-modal') this.closeDirectoryModal();
        });

        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            const panelOpen = !$('#faction-panel')?.classList.contains('hidden');
            const dirOpen = !$('#faction-directory')?.classList.contains('hidden');
            if (!panelOpen && !dirOpen) return;
            event.preventDefault();
            if (dirOpen && this.dirModalOpen) {
                this.closeDirectoryModal();
                return;
            }
            post('factionPanelsClose');
        });
    },

    setBodyOpen(open) {
        document.body.classList.toggle('faction-panels-open', open);
    },

    hide() {
        $('#faction-panel')?.classList.add('hidden');
        $('#faction-directory')?.classList.add('hidden');
        this.setBodyOpen(false);
        this.closeDirectoryModal();
    },

    setTab(tabId) {
        this.activeTab = tabId || 'overview';
        document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
            tab.classList.toggle('is-active', tab.dataset.factionTab === tabId);
        });
        document.querySelectorAll('[data-faction-panel]').forEach((panel) => {
            panel.classList.toggle('is-active', panel.dataset.factionPanel === tabId);
        });
    },

    formatMoney(amount) {
        return `$${Number(amount || 0).toLocaleString('en-US')}`;
    },

    factionCategory(faction) {
        if (faction?.type === 'illegal') return 'illegal';
        const ft = String(faction?.factionType || '');
        if (['transport', 'mechanic', 'education'].includes(ft)) return 'service';
        if (['law_enforcement', 'ems', 'fire_rescue'].includes(ft)) return 'legal';
        return faction?.type === 'legal' ? 'legal' : 'service';
    },

    factionTypeLabel(faction) {
        const map = {
            law_enforcement: 'Public Department',
            ems: 'Medical Service',
            fire_rescue: 'Fire / Rescue',
            transport: 'Transport',
            mechanic: 'Mechanics / Tuning',
            education: 'Education / Licenses',
            criminal_org: 'Criminal Organization',
        };
        return map[faction?.factionType] || String(faction?.factionType || 'Organization').replaceAll('_', ' ');
    },

    renderCommands(commands) {
        const list = $('#faction-commands');
        if (!list) return;
        list.innerHTML = '';
        (commands || []).forEach((row) => {
            const li = document.createElement('li');
            li.innerHTML = `<code>${this.escape(row.cmd || '')}</code> — ${this.escape(row.desc || '')}`;
            list.appendChild(li);
        });
        if (!list.children.length) {
            list.innerHTML = '<li class="premium-faction__empty">No special commands for your rank.</li>';
        }
    },

    renderRankEditor(grades, canEdit) {
        const wrap = document.getElementById('faction-rank-editor');
        const form = $('#faction-rank-names-form');
        if (!wrap || !form) return;
        wrap.classList.toggle('hidden', !canEdit);
        if (!canEdit) return;
        form.innerHTML = '';
        (grades || []).forEach((row) => {
            const field = document.createElement('label');
            field.className = 'premium-faction__rank-field';
            field.innerHTML = `
                <span>Grade ${row.grade}</span>
                <input class="premium-faction__form-control" type="text" data-grade="${row.grade}" maxlength="64" value="${this.escape(row.label || '')}" placeholder="${this.escape(row.defaultLabel || '')}">
            `;
            form.appendChild(field);
        });
    },

    updateManageForms(perms, data) {
        const manageTab = document.querySelector('[data-faction-tab="manage"]');
        const showManage = Boolean(
            perms.invite || perms.motd || perms.warn || perms.renameRanks
            || perms.rankMembers || perms.kickMembers
        );
        manageTab?.classList.toggle('hidden', !showManage);

        document.querySelectorAll('[data-faction-action]').forEach((form) => {
            const action = form.dataset.factionAction;
            let allowed = false;
            if (action === 'invite') allowed = perms.invite;
            else if (action === 'motd') allowed = perms.motd;
            else if (action === 'warn') allowed = perms.warn;
            else if (action === 'resign') allowed = !data?.leader;
            else allowed = true;
            const scope = form.closest('.premium-faction__panel') || form.closest('.premium-faction__resign');
            scope?.classList.toggle('hidden', !allowed);
        });

        const motdForm = document.querySelector('[data-faction-action="motd"]');
        const motdInput = motdForm?.querySelector('[name="message"]');
        if (motdInput && data?.motd) motdInput.value = data.motd;

        const promoteBtn = $('#faction-manage-promote');
        const demoteBtn = $('#faction-manage-demote');
        const kickBtn = $('#faction-manage-kick');
        const kickFpBtn = $('#faction-manage-kick-fp');
        const pardonBtn = $('#faction-manage-pardon');
        const memberPanel = promoteBtn?.closest('.premium-faction__panel');
        if (memberPanel) memberPanel.classList.toggle('hidden', !(perms.rankMembers || perms.kickMembers));
        if (promoteBtn) promoteBtn.disabled = !perms.rankMembers;
        if (demoteBtn) demoteBtn.disabled = !perms.rankMembers;
        if (kickBtn) kickBtn.disabled = !perms.kickMembers;
        // [FP SYSTEM]
        if (kickFpBtn) kickFpBtn.disabled = !perms.kickMembers;
        if (pardonBtn) {
            pardonBtn.disabled = !perms.pardonFp;
            pardonBtn.classList.toggle('hidden', !perms.pardonFp);
        }
    },

    populateManageSelect(members, viewerCharacterId) {
        const select = $('#faction-manage-select');
        if (!select) return;
        select.innerHTML = '<option value="" disabled selected>Select a member...</option>';
        (members || []).forEach((member) => {
            if (Number(member.characterId) === Number(viewerCharacterId)) return;
            const opt = document.createElement('option');
            opt.value = String(member.characterId);
            opt.textContent = `${member.name} (${member.gradeLabel || 'Member'})`;
            select.appendChild(opt);
        });
    },

    _memberById(characterId) {
        return (this.dashboard?.members || []).find(
            (member) => Number(member.characterId) === Number(characterId)
        );
    },

    _kickModeForMember(member) {
        return member?.online ? 'online' : 'offline';
    },

    manageSelected(action, payload) {
        const select = $('#faction-manage-select');
        const characterId = Number(select?.value);
        if (!characterId) {
            return notify('Select a member first.', 'error');
        }
        if (action === 'rankDelta') {
            this.postAction('rankDelta', { characterId, delta: payload });
        } else if (action === 'kick') {
            const member = this._memberById(characterId);
            const mode = payload === 'with_fp' ? 'with_fp' : this._kickModeForMember(member);
            this.postAction('kick', { characterId, mode });
        } else if (action === 'pardonFp') {
            this.postAction('pardonFp', { characterId });
        }
    },

    // [FP SYSTEM] Member detail line under the management select.
    renderSelectedMemberInfo() {
        const box = $('#faction-manage-info');
        if (!box) return;
        const characterId = Number($('#faction-manage-select')?.value);
        const member = characterId ? this._memberById(characterId) : null;
        if (!member) {
            box.classList.add('hidden');
            box.innerHTML = '';
            return;
        }
        const days = member.daysInFaction;
        const daysTxt = days == null ? 'joined: unknown' : `joined ${days}d ago${days < 14 ? ' (NEW - kick with FP if they leave early)' : ''}`;
        const fpTxt = member.fp > 0 ? ` · FP: ${member.fp}` : '';
        box.classList.remove('hidden');
        box.innerHTML = `<span>${this.escape(member.name)}</span> · ${this.escape(member.gradeLabel || 'Member')} · ${this.escape(daysTxt)}${fpTxt}`;
    },

    // [FP SYSTEM] Resignation requests board (leaders/managers).
    renderResignations(rows) {
        const wrap = $('#faction-resignations');
        const badge = $('#faction-req-badge');
        const list = Array.isArray(rows) ? rows : [];
        if (badge) {
            badge.textContent = String(list.length);
            badge.classList.toggle('hidden', list.length === 0);
        }
        if (!wrap) return;
        wrap.innerHTML = '';
        if (!list.length) {
            wrap.innerHTML = '<p class="premium-faction__empty">No pending resignation requests.</p>';
            return;
        }
        list.forEach((req) => {
            const row = document.createElement('article');
            row.className = 'premium-faction__roster-item';

            const info = document.createElement('div');
            info.className = 'premium-faction__roster-info';
            const text = document.createElement('div');
            const name = document.createElement('div');
            name.className = 'premium-faction__member-name';
            name.textContent = req.name || `CID ${req.characterId}`;
            const meta = document.createElement('div');
            meta.className = 'premium-faction__member-rank';
            const days = req.daysInFaction == null ? '' : ` · ${req.daysInFaction}d in faction`;
            meta.textContent = `${req.reason ? this.escape(req.reason) : 'No reason given'}${days}`;
            text.append(name, meta);
            info.appendChild(text);

            const actions = document.createElement('div');
            actions.className = 'premium-faction__member-actions';
            const ok = document.createElement('button');
            ok.type = 'button';
            ok.className = 'premium-faction__btn premium-faction__btn--primary';
            ok.textContent = 'Accept (no FP)';
            ok.addEventListener('click', () => this.postAction('resignAccept', { resignationId: req.id }));
            const okFp = document.createElement('button');
            okFp.type = 'button';
            okFp.className = 'premium-faction__btn premium-faction__btn--warn';
            okFp.textContent = 'Accept + FP';
            okFp.addEventListener('click', () => this.postAction('resignAcceptFp', { resignationId: req.id }));
            const no = document.createElement('button');
            no.type = 'button';
            no.className = 'premium-faction__btn premium-faction__btn--secondary';
            no.textContent = 'Decline';
            no.addEventListener('click', () => this.postAction('resignDecline', { resignationId: req.id }));
            actions.append(ok, okFp, no);

            row.append(info, actions);
            wrap.appendChild(row);
        });
    },

    renderRoster(members, permissions, viewerCharacterId) {
        const roster = $('#faction-roster');
        if (!roster) return;
        roster.innerHTML = '';
        const canRank = Boolean(permissions?.rankMembers);
        const canKick = Boolean(permissions?.kickMembers);
        const canWarn = Boolean(permissions?.warn);
        const viewerId = Number(viewerCharacterId) || 0;
        const viewerGrade = Number(this.dashboard?.viewerGrade) || 0;

        (members || []).forEach((member) => {
            const row = document.createElement('article');
            row.className = 'premium-faction__roster-item';

            const info = document.createElement('div');
            info.className = 'premium-faction__roster-info';

            const dot = document.createElement('div');
            dot.className = `premium-faction__status-dot ${member.online ? 'is-online' : 'is-offline'}`;
            dot.title = member.online ? 'Online' : 'Offline';

            const text = document.createElement('div');
            const name = document.createElement('div');
            name.className = 'premium-faction__member-name';
            name.textContent = member.name || `CID ${member.characterId || '?'}`;
            const rank = document.createElement('div');
            rank.className = 'premium-faction__member-rank';
            const extras = [];
            if (member.leader) extras.push('LEADER');
            if (member.onDuty) extras.push('ON SHIFT');
            if (member.warns) extras.push(`${member.warns}/3 FW`);
            // [FP SYSTEM] new-member badge + FP indicator for leaders.
            if (member.daysInFaction != null && member.daysInFaction < 14 && !member.leader) extras.push('NEW');
            if (member.fp > 0) extras.push(`FP ${member.fp}`);
            rank.textContent = `${member.gradeLabel || 'Member'} · G${member.grade ?? 0}${extras.length ? ` · ${extras.join(' · ')}` : ''}`;
            text.append(name, rank);
            info.append(dot, text);

            const idBadge = document.createElement('div');
            idBadge.className = 'premium-faction__member-id';
            idBadge.textContent = member.serverId ? `ID: ${member.serverId}` : `CID: ${member.characterId}`;

            const actions = document.createElement('div');
            actions.className = 'premium-faction__member-actions';
            const isSelf = Number(member.characterId) === viewerId;
            const manageable = !isSelf && !member.leader && (canRank || canKick || canWarn);
            const lowerRank = Number(member.grade) < viewerGrade || Boolean(this.dashboard?.permissions?.leader);

            if (manageable && canRank && lowerRank) {
                // [ICON FIX] ▲▼ arrows rendered as tofu/unstyled glyphs in CEF.
                // Phosphor icons are already loaded font-wise and used everywhere else.
                const up = document.createElement('button');
                up.type = 'button';
                up.className = 'premium-faction__btn premium-faction__btn--secondary';
                up.title = 'Promote';
                up.innerHTML = '<i class="ph-bold ph-caret-up"></i>';
                up.addEventListener('click', () => this.postAction('rankDelta', { characterId: member.characterId, delta: 1 }));
                const down = document.createElement('button');
                down.type = 'button';
                down.className = 'premium-faction__btn premium-faction__btn--secondary';
                down.title = 'Demote';
                down.innerHTML = '<i class="ph-bold ph-caret-down"></i>';
                down.addEventListener('click', () => this.postAction('rankDelta', { characterId: member.characterId, delta: -1 }));
                actions.append(up, down);
            }
            if (manageable && canKick && lowerRank) {
                const kick = document.createElement('button');
                kick.type = 'button';
                kick.className = 'premium-faction__btn premium-faction__btn--danger';
                kick.innerHTML = '<i class="ph-bold ph-sign-out"></i> Kick';
                kick.title = member.daysInFaction != null && member.daysInFaction < 14
                    ? 'New member (<14d) - consider Kick + FP'
                    : 'Remove without FP';
                kick.disabled = !canKick;
                kick.addEventListener('click', () => this.postAction('kick', {
                    characterId: member.characterId,
                    mode: this._kickModeForMember(member),
                }));
                actions.append(kick);
                const kickFp = document.createElement('button');
                kickFp.type = 'button';
                kickFp.className = 'premium-faction__btn premium-faction__btn--warn';
                kickFp.innerHTML = '<i class="ph-bold ph-gavel"></i> Kick + FP';
                kickFp.title = 'Remove and apply 60 FP (faction punish)';
                kickFp.disabled = !canKick;
                kickFp.addEventListener('click', () => this.postAction('kick', {
                    characterId: member.characterId,
                    mode: 'with_fp',
                }));
                actions.append(kickFp);
            }
            if (manageable && canWarn && lowerRank && member.online) {
                const warn = document.createElement('button');
                warn.type = 'button';
                warn.className = 'premium-faction__btn premium-faction__btn--warn';
                warn.innerHTML = '<i class="ph-bold ph-warning"></i> FW';
                warn.title = 'Faction warning';
                warn.addEventListener('click', () => this.postAction('warn', { characterId: member.characterId, reason: 'Faction disciplinary warning' }));
                actions.append(warn);
            }

            row.append(info, idBadge);
            if (actions.children.length) row.appendChild(actions);
            roster.appendChild(row);
        });

        if (!members?.length) {
            roster.innerHTML = '<p class="premium-faction__empty">No roster entries found.</p>';
        }
    },

    refreshDashboard(data = {}) {
        this.showDashboard(data, { preserveTab: true });
    },

    showDashboard(data = {}, opts = {}) {
        this.init();
        this.dashboard = data;
        $('#faction-directory')?.classList.add('hidden');

        const members = Array.isArray(data.members) ? data.members : [];
        const report = data.report || {};
        const perms = data.permissions || {};
        const current = Math.max(0, Number(report.current) || 0);
        const target = Math.max(0, Number(report.target) || 0);
        const percent = target > 0 ? Math.min(100, (current / target) * 100) : 100;
        const online = members.filter((m) => m.online).length;

        const title = $('#faction-panel-title');
        if (title) title.textContent = data.label || 'Faction';
        const typeEl = $('#faction-panel-type');
        if (typeEl) typeEl.textContent = this.factionTypeLabel(data);

        $('#faction-rank').textContent = `${data.gradeLabel || 'Member'}${data.leader ? ' · COMMAND' : ''}`;
        $('#faction-online-count').textContent = String(online);
        $('#faction-member-count').textContent = String(members.length);

        const dutyEl = $('#faction-duty');
        if (dutyEl) {
            dutyEl.textContent = data.onDuty ? 'ON SHIFT' : 'OFF SHIFT';
            dutyEl.className = data.onDuty ? 'is-duty' : 'is-off';
        }
        $('#faction-salary').textContent = `$${Number(data.salary || 0).toLocaleString()}/HR`;
        $('#faction-motd').textContent = data.motd || 'No MOTD posted. Leaders use /fmotd.';
        $('#faction-description').textContent = data.description || 'No department intel on file.';
        $('#faction-depot').textContent = `Motor pool: ${data.depot || 'Not configured'}`;
        $('#faction-report-value').textContent = target > 0 ? `${current} / ${target} ops` : `${current} ops logged`;
        const reportBar = $('#faction-report-bar');
        if (reportBar) reportBar.style.width = `${percent}%`;

        const bankCard = $('#faction-bank-card');
        const bankVal = $('#faction-society-bank');
        if (data.societyBalance !== undefined && data.societyBalance !== null) {
            bankCard?.classList.remove('hidden');
            if (bankVal) bankVal.textContent = this.formatMoney(data.societyBalance);
        } else {
            bankCard?.classList.add('hidden');
        }

        const rosterMeta = $('#faction-roster-meta');
        if (rosterMeta) {
            const onDuty = members.filter((m) => m.onDuty).length;
            rosterMeta.textContent = `${online} online · ${onDuty} on shift · ${members.length} total`;
        }

        // [FP SYSTEM] my FP card + note (any member with FP sees it).
        const myFp = Math.max(0, Number(data.myFp) || 0);
        const fpCard = $('#faction-fp-card');
        if (fpCard) {
            fpCard.classList.toggle('hidden', myFp <= 0);
            const fpVal = $('#faction-my-fp');
            if (fpVal) fpVal.textContent = String(myFp);
        }
        $('#faction-fp-note')?.classList.toggle('hidden', myFp <= 0);

        // [FP SYSTEM] resignation box: any non-leader member can resign.
        const resignBox = $('#faction-resign-box');
        if (resignBox) resignBox.classList.toggle('hidden', Boolean(data.leader));

        // [FP SYSTEM] requests tab for leaders/managers.
        const reqTab = document.querySelector('.faction-tab--requests');
        const canHandleResigns = Boolean(perms.manageResignations);
        reqTab?.classList.toggle('hidden', !canHandleResigns);
        if (canHandleResigns) this.renderResignations(data.pendingResignations);

        this.renderRoster(members, perms, data.viewerCharacterId);
        this.renderCommands(data.commands);
        this.renderRankEditor(data.grades, perms.renameRanks);
        this.updateManageForms(perms, data);
        this.populateManageSelect(members, data.viewerCharacterId);

        this.setTab(opts.preserveTab ? (this.activeTab || 'overview') : 'overview');
        $('#faction-panel')?.classList.remove('hidden');
        this.setBodyOpen(true);
    },

    showDirectory(payload = {}) {
        this.init();
        this.directory = Array.isArray(payload.factions) ? payload.factions : [];
        this.dirFilter = 'all';
        this.closeDirectoryModal();

        $('#faction-panel')?.classList.add('hidden');
        $('#faction-directory')?.classList.remove('hidden');
        this.setDirectoryFilter('all', false);
        this.setBodyOpen(true);
    },

    setDirectoryFilter(filter, updateNav = true) {
        this.dirFilter = filter || 'all';
        if (updateNav) {
            document.querySelectorAll('[data-faction-filter]').forEach((btn) => {
                btn.classList.toggle('is-active', btn.dataset.factionFilter === this.dirFilter);
            });
        }
        const title = $('#faction-dir-title');
        if (title) title.textContent = FACTION_FILTER_TITLES[this.dirFilter] || FACTION_FILTER_TITLES.all;
        this.renderDirectoryCards();
    },

    renderDirectoryCards() {
        const list = $('#faction-directory-list');
        if (!list) return;
        list.innerHTML = '';

        const filtered = this.directory.filter((faction) => {
            if (this.dirFilter === 'all') return true;
            return this.factionCategory(faction) === this.dirFilter;
        });

        filtered.forEach((faction) => {
            const cat = this.factionCategory(faction);
            const card = document.createElement('button');
            card.type = 'button';
            card.className = 'premium-factions-dir__card';
            card.dataset.factionId = faction.id || '';

            const marker = Array.isArray(faction.marker) ? faction.marker : null;
            if (marker && marker.length >= 3) {
                card.style.setProperty('--pf-card-accent', `rgb(${marker[0]}, ${marker[1]}, ${marker[2]})`);
            }

            const leaders = Array.isArray(faction.leaders) && faction.leaders.length ? faction.leaders[0] : 'Vacant';
            const recruitClass = faction.applicationsOpen ? 'is-open' : 'is-closed';
            const recruitLabel = faction.applicationsOpen ? 'Recruiting Open' : 'Recruiting Closed';

            card.innerHTML = `
                <div class="premium-factions-dir__card-head">
                    <div class="premium-factions-dir__card-icon">${FACTION_ICONS[cat] || FACTION_ICONS.service}</div>
                    <div>
                        <div class="premium-factions-dir__card-name">${this.escape(faction.label || faction.id)}</div>
                        <div class="premium-factions-dir__card-type">${this.escape(this.factionTypeLabel(faction))}</div>
                    </div>
                </div>
                <div class="premium-factions-dir__card-stats">
                    <div class="premium-factions-dir__stat-row"><span>Leader:</span><b>${this.escape(leaders)}</b></div>
                    <div class="premium-factions-dir__stat-row"><span>Members:</span><b><span class="highlight">${Number(faction.online) || 0}</span> / ${Number(faction.total) || 0}</b></div>
                </div>
                <div class="premium-factions-dir__recruit ${recruitClass}"><div class="dot"></div>${recruitLabel}</div>
            `;

            card.addEventListener('click', () => this.openDirectoryModal(faction));
            list.appendChild(card);
        });

        if (!list.children.length) {
            list.innerHTML = '<p class="premium-factions-dir__empty">No factions in this category.</p>';
        }
    },

    openDirectoryModal(faction) {
        const modal = $('#faction-directory-modal');
        if (!modal || !faction) return;
        this.selectedFaction = faction;
        this.dirModalOpen = true;
        modal.classList.add('is-open');

        const cat = this.factionCategory(faction);
        const icon = $('#faction-dir-modal-icon');
        if (icon) icon.innerHTML = FACTION_ICONS[cat] || FACTION_ICONS.service;
        $('#faction-dir-modal-title').textContent = faction.label || faction.id;
        $('#faction-dir-modal-desc').textContent = faction.description || 'No public intel.';
        $('#faction-dir-modal-motd').textContent = 'Loading...';
        $('#faction-dir-modal-leaders').innerHTML = '<li>Loading...</li>';
        $('#faction-dir-modal-roster').innerHTML = '<p class="premium-factions-dir__empty">Loading...</p>';
        $('#faction-dir-modal-recruit').innerHTML = `<li>${this.escape(faction.applicationLabel || '—')}</li>`;

        const btn = $('#faction-dir-modal-btn');
        if (btn) {
            const isIllegal = faction.type === 'illegal';
            if (isIllegal) {
                btn.disabled = true;
                btn.textContent = 'Doar In-Character (IC)';
            } else if (faction.recruiting) {
                btn.disabled = false;
                btn.textContent = 'Send Application';
            } else {
                btn.disabled = true;
                btn.textContent = 'Applications Closed';
            }
        }

        post('factionDirectoryDetail', { factionId: faction.id });
    },

    showDirectoryDetail(detail = {}) {
        if (detail.error) {
            $('#faction-dir-modal-motd').textContent = detail.error;
            return;
        }

        $('#faction-dir-modal-motd').textContent = detail.motd || 'No MOTD published.';
        const leaders = $('#faction-dir-modal-leaders');
        if (leaders) {
            leaders.innerHTML = '';
            const list = Array.isArray(detail.leaders) && detail.leaders.length ? detail.leaders : ['Vacant'];
            list.forEach((name) => {
                const li = document.createElement('li');
                li.textContent = name;
                leaders.appendChild(li);
            });
        }

        const roster = $('#faction-dir-modal-roster');
        if (roster) {
            roster.innerHTML = '';
            (detail.members || []).forEach((m) => {
                const row = document.createElement('div');
                row.className = 'premium-factions-dir__modal-member';
                row.innerHTML = `<strong>${this.escape(m.name)}</strong><span>${this.escape(m.rank || '')}${m.online ? ' · ONLINE' : ''}${m.leader ? ' · LEADER' : ''}</span>`;
                roster.appendChild(row);
            });
            if (!roster.children.length) {
                roster.innerHTML = '<p class="premium-factions-dir__empty">No members registered.</p>';
            }
        }

        const recruit = $('#faction-dir-modal-recruit');
        if (recruit) {
            recruit.innerHTML = '';
            const li = document.createElement('li');
            li.textContent = detail.type === 'illegal'
                ? 'Invite only — contact leadership in character.'
                : (detail.applicationsOpen ? 'Recruiting — apply on Discord/site, leaders invite in-game.' : 'Not recruiting — leadership invites only.');
            recruit.appendChild(li);
        }
    },

    closeDirectoryModal() {
        this.dirModalOpen = false;
        $('#faction-directory-modal')?.classList.remove('is-open');
        this.selectedFaction = null;
    },

    applyFaction() {
        if (!this.selectedFaction) return;
        this.showToast(`Application sent to ${this.selectedFaction.label || this.selectedFaction.id}!`);
        this.closeDirectoryModal();
    },

    showToast(msg) {
        const toast = $('#faction-directory-toast');
        if (!toast) return;
        toast.textContent = msg;
        toast.classList.add('is-show');
        setTimeout(() => toast.classList.remove('is-show'), 3500);
    },

    showBrowseInline(payload = {}) {
        this.directory = Array.isArray(payload.factions) ? payload.factions : [];
        this.showDirectory({ factions: this.directory });
    },

    postAction(action, payload) {
        post('factionManage', { action, ...payload });
    },

    submitManageForm(form) {
        const action = form.dataset.factionAction;
        const data = new FormData(form);
        const payload = { action };
        if (action === 'invite') {
            const targetId = Math.floor(Number(data.get('targetId')));
            if (!targetId || targetId < 1) {
                return notify('Enter a valid Server ID (hold Z for the list).', 'error');
            }
            payload.targetId = targetId;
        }
        if (action === 'motd') payload.message = String(data.get('message') || '').trim();
        if (action === 'resign') payload.reason = String(data.get('reason') || '').trim();
        if (action === 'warn') {
            const targetId = Math.floor(Number(data.get('targetId')));
            if (!targetId || targetId < 1) {
                return notify('Enter a valid Server ID (hold Z for the list).', 'error');
            }
            payload.targetId = targetId;
            payload.reason = String(data.get('reason') || 'No reason given').trim();
        }
        post('factionManage', payload);
    },

    saveRankNames() {
        const form = $('#faction-rank-names-form');
        if (!form) return;
        const labels = {};
        form.querySelectorAll('input[data-grade]').forEach((input) => {
            labels[input.dataset.grade] = String(input.value || '').trim();
        });
        post('factionManage', { action: 'gradeLabels', labels });
    },

    refreshDashboard(data) {
        if (data) this.showDashboard(data);
    },

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },
};

window.FactionPanels = FactionPanels;
