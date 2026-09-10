const FACTION_ICONS = {
    legal: '<svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>',
    illegal: '<svg viewBox="0 0 24 24"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>',
    service: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>',
};

const FACTION_FILTER_TITLES = {
    all: 'Toate Facțiunile',
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
            law_enforcement: 'Departament Public',
            ems: 'Serviciu Medical',
            fire_rescue: 'Pompieri / Salvare',
            transport: 'Transport',
            mechanic: 'Mecanici / Tuning',
            education: 'Educație / Licențe',
            criminal_org: 'Organizație Criminală',
        };
        return map[faction?.factionType] || String(faction?.factionType || 'Organizație').replaceAll('_', ' ');
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
            else allowed = true;
            form.closest('.premium-faction__panel')?.classList.toggle('hidden', !allowed);
        });

        const motdForm = document.querySelector('[data-faction-action="motd"]');
        const motdInput = motdForm?.querySelector('[name="message"]');
        if (motdInput && data?.motd) motdInput.value = data.motd;

        const promoteBtn = $('#faction-manage-promote');
        const demoteBtn = $('#faction-manage-demote');
        const kickBtn = $('#faction-manage-kick');
        const memberPanel = promoteBtn?.closest('.premium-faction__panel');
        if (memberPanel) memberPanel.classList.toggle('hidden', !(perms.rankMembers || perms.kickMembers));
        if (promoteBtn) promoteBtn.disabled = !perms.rankMembers;
        if (demoteBtn) demoteBtn.disabled = !perms.rankMembers;
        if (kickBtn) kickBtn.disabled = !perms.kickMembers;
    },

    populateManageSelect(members, viewerCharacterId) {
        const select = $('#faction-manage-select');
        if (!select) return;
        select.innerHTML = '<option value="" disabled selected>Alege un membru...</option>';
        (members || []).forEach((member) => {
            if (Number(member.characterId) === Number(viewerCharacterId)) return;
            const opt = document.createElement('option');
            opt.value = String(member.characterId);
            opt.textContent = `${member.name} (${member.gradeLabel || 'Member'})`;
            select.appendChild(opt);
        });
    },

    manageSelected(action, payload) {
        const select = $('#faction-manage-select');
        const characterId = Number(select?.value);
        if (!characterId) {
            return notify('Te rog selectează un membru mai întâi!', 'error');
        }
        if (action === 'rankDelta') {
            this.postAction('rankDelta', { characterId, delta: payload });
        } else if (action === 'kick') {
            this.postAction('kick', { characterId, mode: payload });
        }
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
                const up = document.createElement('button');
                up.type = 'button';
                up.className = 'premium-faction__btn premium-faction__btn--secondary';
                up.textContent = '▲';
                up.addEventListener('click', () => this.postAction('rankDelta', { characterId: member.characterId, delta: 1 }));
                const down = document.createElement('button');
                down.type = 'button';
                down.className = 'premium-faction__btn premium-faction__btn--secondary';
                down.textContent = '▼';
                down.addEventListener('click', () => this.postAction('rankDelta', { characterId: member.characterId, delta: -1 }));
                actions.append(up, down);
            }
            if (manageable && canKick && lowerRank) {
                const kick = document.createElement('button');
                kick.type = 'button';
                kick.className = 'premium-faction__btn premium-faction__btn--danger';
                kick.textContent = 'Kick';
                kick.disabled = !member.online;
                kick.addEventListener('click', () => this.postAction('kick', { characterId: member.characterId, mode: 'online' }));
                actions.append(kick);
            }
            if (manageable && canWarn && lowerRank && member.online) {
                const warn = document.createElement('button');
                warn.type = 'button';
                warn.className = 'premium-faction__btn premium-faction__btn--warn';
                warn.textContent = 'FW';
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
        if (title) title.textContent = data.label || 'Facțiune';
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
            const recruitLabel = faction.applicationsOpen ? 'Recrutări Deschise' : 'Recrutări Închise';

            card.innerHTML = `
                <div class="premium-factions-dir__card-head">
                    <div class="premium-factions-dir__card-icon">${FACTION_ICONS[cat] || FACTION_ICONS.service}</div>
                    <div>
                        <div class="premium-factions-dir__card-name">${this.escape(faction.label || faction.id)}</div>
                        <div class="premium-factions-dir__card-type">${this.escape(this.factionTypeLabel(faction))}</div>
                    </div>
                </div>
                <div class="premium-factions-dir__card-stats">
                    <div class="premium-factions-dir__stat-row"><span>Lider:</span><b>${this.escape(leaders)}</b></div>
                    <div class="premium-factions-dir__stat-row"><span>Membri:</span><b><span class="highlight">${Number(faction.online) || 0}</span> / ${Number(faction.total) || 0}</b></div>
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
        $('#faction-dir-modal-motd').textContent = 'Se încarcă...';
        $('#faction-dir-modal-leaders').innerHTML = '<li>Se încarcă...</li>';
        $('#faction-dir-modal-roster').innerHTML = '<p class="premium-factions-dir__empty">Se încarcă...</p>';
        $('#faction-dir-modal-recruit').innerHTML = `<li>${this.escape(faction.applicationLabel || '—')}</li>`;

        const btn = $('#faction-dir-modal-btn');
        if (btn) {
            const isIllegal = faction.type === 'illegal';
            if (isIllegal) {
                btn.disabled = true;
                btn.textContent = 'Doar In-Character (IC)';
            } else if (faction.recruiting) {
                btn.disabled = false;
                btn.textContent = 'Trimite CV (Aplică)';
            } else {
                btn.disabled = true;
                btn.textContent = 'Aplicații Închise';
            }
        }

        post('factionDirectoryDetail', { factionId: faction.id });
    },

    showDirectoryDetail(detail = {}) {
        if (detail.error) {
            $('#faction-dir-modal-motd').textContent = detail.error;
            return;
        }

        $('#faction-dir-modal-motd').textContent = detail.motd || 'Niciun MOTD publicat.';
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
                roster.innerHTML = '<p class="premium-factions-dir__empty">Niciun membru înregistrat.</p>';
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
        this.showToast(`Aplicație trimisă la ${this.selectedFaction.label || this.selectedFaction.id}!`);
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
                return notify('Introdu un Server ID valid din F10.', 'error');
            }
            payload.targetId = targetId;
        }
        if (action === 'motd') payload.message = String(data.get('message') || '').trim();
        if (action === 'warn') {
            const targetId = Math.floor(Number(data.get('targetId')));
            if (!targetId || targetId < 1) {
                return notify('Introdu un Server ID valid din F10.', 'error');
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
