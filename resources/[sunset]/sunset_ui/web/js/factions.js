const FactionPanels = {
    dashboard: null,
    directory: [],

    init() {
        if (this.ready) return;
        this.ready = true;

        document.querySelectorAll('[data-faction-close]').forEach((button) => {
            button.addEventListener('click', () => post('factionPanelsClose'));
        });

        document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
            tab.addEventListener('click', () => {
                const tabId = tab.dataset.factionTab;
                this.setTab(tabId);
                if (tabId === 'browse') this.requestBrowse();
            });
        });

        document.querySelector('[data-faction-detail-back]')?.addEventListener('click', () => {
            this.closeDirectoryDetail();
        });

        document.querySelectorAll('[data-faction-action]').forEach((form) => {
            form.addEventListener('submit', (event) => {
                event.preventDefault();
                this.submitManageForm(form);
            });
        });

        document.getElementById('faction-rank-save')?.addEventListener('click', () => {
            this.saveRankNames();
        });

        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            const panelOpen = !$('#faction-panel')?.classList.contains('hidden');
            const dirOpen = !$('#faction-directory')?.classList.contains('hidden');
            if (panelOpen || dirOpen) {
                event.preventDefault();
                post('factionPanelsClose');
            }
        });
    },

    setBodyOpen(open) {
        document.body.classList.toggle('faction-panels-open', open);
    },

    hide() {
        $('#faction-panel')?.classList.add('hidden');
        $('#faction-directory')?.classList.add('hidden');
        this.setBodyOpen(false);
        this.closeDirectoryDetail();
    },

    setTab(tabId) {
        document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
            tab.classList.toggle('is-active', tab.dataset.factionTab === tabId);
        });
        document.querySelectorAll('[data-faction-panel]').forEach((panel) => {
            panel.classList.toggle('is-active', panel.dataset.factionPanel === tabId);
        });
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
            list.innerHTML = '<li class="faction-empty">No special commands for your rank.</li>';
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
            field.className = 'faction-rank-field';
            field.innerHTML = `
                <span>Grade ${row.grade}</span>
                <input type="text" data-grade="${row.grade}" maxlength="64" value="${this.escape(row.label || '')}" placeholder="${this.escape(row.defaultLabel || '')}">
            `;
            form.appendChild(field);
        });
    },

    updateManageForms(perms, data) {
        document.querySelector('.faction-tab--manage')?.classList.toggle('hidden', !(
            perms.invite || perms.motd || perms.warn || perms.renameRanks
            || perms.rankMembers || perms.kickMembers
        ));

        document.querySelectorAll('[data-faction-action]').forEach((form) => {
            const action = form.dataset.factionAction;
            let allowed = false;
            if (action === 'invite') allowed = perms.invite;
            else if (action === 'motd') allowed = perms.motd;
            else if (action === 'warn') allowed = perms.warn;
            else allowed = true;
            form.classList.toggle('hidden', !allowed);
        });

        const motdForm = document.querySelector('[data-faction-action="motd"]');
        const motdInput = motdForm?.querySelector('[name="message"]');
        if (motdInput && data?.motd) motdInput.value = data.motd;
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
            row.className = `faction-member${member.online ? ' is-online' : ''}${member.leader ? ' is-leader' : ''}`;
            const identity = document.createElement('div');
            identity.className = 'faction-member__identity';
            const name = document.createElement('strong');
            name.textContent = member.name || `CID ${member.characterId || '?'}`;
            const rank = document.createElement('span');
            rank.textContent = `${member.gradeLabel || 'Member'} · G${member.grade ?? 0}${member.warns ? ` · ${member.warns}/3 FW` : ''}${member.serverId ? ` · ID ${member.serverId}` : ''}`;
            identity.append(name, rank);

            const state = document.createElement('div');
            state.className = 'faction-member__state';
            const badge = document.createElement('span');
            badge.className = 'org-member-badge';
            if (member.leader) {
                badge.classList.add('is-leader');
                badge.textContent = 'LEADER';
            } else if (member.onDuty) {
                badge.classList.add('is-duty');
                badge.textContent = 'ON SHIFT';
            } else if (member.online) {
                badge.classList.add('is-online');
                badge.textContent = 'ONLINE';
            } else {
                badge.classList.add('is-offline');
                badge.textContent = 'OFFLINE';
            }
            state.appendChild(badge);

            const actions = document.createElement('div');
            actions.className = 'faction-member__actions';
            const isSelf = Number(member.characterId) === viewerId;
            const manageable = !isSelf && !member.leader && (canRank || canKick || canWarn);
            const lowerRank = Number(member.grade) < viewerGrade || Boolean(this.dashboard?.permissions?.leader);

            if (manageable && canRank && lowerRank) {
                const up = document.createElement('button');
                up.type = 'button';
                up.className = 'faction-btn';
                up.textContent = '▲';
                up.title = 'Rank up';
                up.addEventListener('click', () => this.postAction('rankDelta', { characterId: member.characterId, delta: 1 }));
                const down = document.createElement('button');
                down.type = 'button';
                down.className = 'faction-btn';
                down.textContent = '▼';
                down.title = 'Rank down';
                down.addEventListener('click', () => this.postAction('rankDelta', { characterId: member.characterId, delta: -1 }));
                actions.append(up, down);
            }
            if (manageable && canKick && lowerRank) {
                const kickFp = document.createElement('button');
                kickFp.type = 'button';
                kickFp.className = 'faction-btn is-danger';
                kickFp.textContent = 'Kick +FP';
                kickFp.title = 'Remove online member with faction punishment record';
                kickFp.disabled = !member.online;
                kickFp.addEventListener('click', () => this.postAction('kick', { characterId: member.characterId, mode: 'with_fp' }));

                const kick = document.createElement('button');
                kick.type = 'button';
                kick.className = 'faction-btn is-warn';
                kick.textContent = 'Kick';
                kick.title = 'Remove online member';
                kick.disabled = !member.online;
                kick.addEventListener('click', () => this.postAction('kick', { characterId: member.characterId, mode: 'online' }));

                const kickOff = document.createElement('button');
                kickOff.type = 'button';
                kickOff.className = 'faction-btn is-muted';
                kickOff.textContent = 'Kick offline';
                kickOff.title = 'Remove member from roster while offline';
                kickOff.disabled = member.online;
                kickOff.addEventListener('click', () => this.postAction('kick', { characterId: member.characterId, mode: 'offline' }));

                actions.append(kickFp, kick, kickOff);
            }
            if (manageable && canWarn && lowerRank && member.online) {
                const warn = document.createElement('button');
                warn.type = 'button';
                warn.className = 'faction-btn is-warn';
                warn.textContent = 'FW';
                warn.title = 'Faction warning (3/3 max)';
                warn.addEventListener('click', () => {
                    const reason = 'Faction disciplinary warning';
                    this.postAction('warn', { characterId: member.characterId, reason });
                });
                actions.append(warn);
            }

            row.append(identity, state, actions);
            roster.appendChild(row);
        });
        if (!members?.length) roster.innerHTML = '<p class="faction-empty">No roster entries found.</p>';
    },

    showDashboard(data = {}) {
        this.init();
        $('#faction-directory')?.classList.add('hidden');
        this.dashboard = data;
        const members = Array.isArray(data.members) ? data.members : [];
        const report = data.report || {};
        const perms = data.permissions || {};
        const current = Math.max(0, Number(report.current) || 0);
        const target = Math.max(0, Number(report.target) || 0);
        const percent = target > 0 ? Math.min(100, (current / target) * 100) : 100;

        const title = $('#faction-panel-title');
        if (title) {
            const label = data.label || 'Faction';
            title.innerHTML = `${this.escape(label)} <span>CONTROL</span>`;
        }

        $('#faction-rank').textContent = `${data.gradeLabel || 'Member'}${data.leader ? ' · COMMAND' : ''}`;
        $('#faction-duty').textContent = data.onDuty ? 'ON SHIFT' : 'OFF SHIFT';
        $('#faction-duty').classList.toggle('is-active', Boolean(data.onDuty));
        $('#faction-salary').textContent = `$${Number(data.salary || 0).toLocaleString()}/HR`;
        $('#faction-member-count').textContent = String(members.length);
        $('#faction-motd').textContent = data.motd || 'No MOTD posted. Leaders use /fmotd.';
        $('#faction-description').textContent = data.description || 'No department intel on file.';
        $('#faction-depot').textContent = `Motor pool: ${data.depot || 'Not configured'}`;
        $('#faction-report-value').textContent = target > 0 ? `${current} / ${target} ops` : `${current} ops logged`;
        $('#faction-report-bar').style.width = `${percent}%`;

        const rosterMeta = $('#faction-roster-meta');
        if (rosterMeta) {
            const online = members.filter((m) => m.online).length;
            const onDuty = members.filter((m) => m.onDuty).length;
            rosterMeta.textContent = `${online} online · ${onDuty} on shift`;
        }

        const toolbar = $('#faction-roster-toolbar');
        toolbar?.classList.add('hidden');

        this.renderRoster(members, perms, data.viewerCharacterId);
        this.renderCommands(data.commands);
        this.renderRankEditor(data.grades, perms.renameRanks);
        this.updateManageForms(perms, data);

        document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
            tab.classList.remove('hidden');
        });
        this._browseLoaded = Boolean(this.directory?.length);

        this.setTab('overview');
        $('#faction-panel')?.classList.remove('hidden');
        this.setBodyOpen(true);
    },

    showDirectory(payload = {}) {
        this.init();
        this.directory = Array.isArray(payload.factions) ? payload.factions : [];
        this.closeDirectoryDetail();
        this.renderDirectoryCards($('#faction-browse-list'));

        const panel = $('#faction-panel');
        const panelWasHidden = panel?.classList.contains('hidden');
        if (panelWasHidden && !this.dashboard) {
            document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
                tab.classList.toggle('hidden', tab.dataset.factionTab !== 'browse');
            });
            const title = $('#faction-panel-title');
            if (title) title.innerHTML = 'SERVER <span>FACTIONS</span>';
        } else {
            document.querySelectorAll('[data-faction-tab]').forEach((tab) => {
                tab.classList.remove('hidden');
            });
        }

        panel?.classList.remove('hidden');
        $('#faction-directory')?.classList.add('hidden');
        this.setTab('browse');
        this.setBodyOpen(true);
        this._browseLoaded = true;
    },

    requestBrowse() {
        if (this._browseLoading) return;
        const list = $('#faction-browse-list');
        if (!list) return;
        if (this._browseLoaded && this.directory?.length) return;
        this._browseLoading = true;
        list.innerHTML = '<p class="faction-empty">Loading factions...</p>';
        post('factionBrowse');
    },

    showBrowseInline(payload = {}) {
        this._browseLoading = false;
        this._browseLoaded = true;
        this.directory = Array.isArray(payload.factions) ? payload.factions : [];
        this.closeDirectoryDetail();
        this.renderDirectoryCards($('#faction-browse-list'));
        this.setTab('browse');
    },

    renderDirectoryCards(listEl) {
        const list = listEl || $('#faction-browse-list');
        if (!list) return;
        list.innerHTML = '';

        this.directory.forEach((faction) => {
            const card = document.createElement('button');
            card.type = 'button';
            card.className = `org-directory-row faction-directory-card faction-directory-card--${faction.type === 'illegal' ? 'illegal' : 'legal'}`;
            card.dataset.factionId = faction.id || '';
            const marker = Array.isArray(faction.marker) ? faction.marker : null;
            if (marker && marker.length >= 3) {
                card.style.setProperty('--faction-accent', `rgb(${marker[0]}, ${marker[1]}, ${marker[2]})`);
            }

            const main = document.createElement('div');
            main.className = 'org-directory-row__main';
            const name = document.createElement('strong');
            name.textContent = faction.label || faction.id;
            const category = document.createElement('span');
            category.textContent = String(faction.factionType || faction.type || 'organization').replaceAll('_', ' ');
            const description = document.createElement('p');
            description.textContent = faction.description || 'No public intel.';
            main.append(name, category, description);

            const stats = document.createElement('div');
            stats.className = 'org-directory-row__stats';
            const status = document.createElement('em');
            status.className = faction.applicationsOpen ? 'is-open' : 'is-closed';
            status.textContent = faction.applicationsOpen ? 'RECRUITING' : 'CLOSED';
            const online = document.createElement('b');
            const leaders = Array.isArray(faction.leaders) && faction.leaders.length ? faction.leaders[0] : 'Vacant';
            online.textContent = `${faction.online || 0}/${faction.total || 0}`;
            const leader = document.createElement('em');
            leader.textContent = leaders;
            stats.append(status, online, leader);

            card.append(main, stats);
            card.addEventListener('click', () => this.openDirectoryDetail(faction, card));
            list.appendChild(card);
        });

        if (!list.children.length) list.innerHTML = '<p class="faction-empty">No factions are configured.</p>';
    },

    closeDirectoryDetail() {
        $('#faction-browse-detail')?.classList.add('hidden');
        $('#faction-browse-layout')?.classList.remove('is-detail-open', 'has-detail');
        document.querySelectorAll('.faction-directory-card.is-selected').forEach((el) => {
            el.classList.remove('is-selected');
        });
    },

    openDirectoryDetail(faction, cardEl) {
        const layout = $('#faction-browse-layout');
        const detail = $('#faction-browse-detail');
        const body = detail?.querySelector('.faction-detail__body');
        if (!layout || !detail || !body) return;

        document.querySelectorAll('.faction-directory-card.is-selected').forEach((el) => {
            el.classList.remove('is-selected');
        });
        cardEl?.classList.add('is-selected');

        const leaders = Array.isArray(faction.leaders) && faction.leaders.length ? faction.leaders.join(', ') : 'Vacant';
        const typeLabel = String(faction.factionType || faction.type || 'organization').replaceAll('_', ' ').toUpperCase();

        body.innerHTML = `
            <h3>${this.escape(faction.label || faction.id)}</h3>
            <div class="faction-detail__type">${this.escape(typeLabel)}</div>
            <span class="faction-detail__status${faction.applicationsOpen ? ' is-open' : ''}">${this.escape(faction.applicationLabel || 'Applications closed')}</span>
            <div class="faction-detail__stats">
                <div class="faction-detail__stat"><strong>${Number(faction.online) || 0}</strong><span>Online</span></div>
                <div class="faction-detail__stat"><strong>${Number(faction.total) || 0}</strong><span>Members</span></div>
                <div class="faction-detail__stat"><strong>${Number(faction.onDuty) || 0}</strong><span>On duty</span></div>
            </div>
            <div class="faction-detail__block"><span>Unit intel</span><p>${this.escape(faction.description || 'No public intel.')}</p></div>
            <div class="faction-detail__block"><span>Command</span><p>${this.escape(leaders)}</p></div>
            <div class="faction-detail__block"><span>Recruitment</span><p>${faction.type === 'illegal' ? 'Invite only — contact leadership in character.' : (faction.applicationsOpen ? 'Recruiting — get invited in-game after approval.' : 'Not recruiting — leadership invites only.')}</p></div>
        `;

        layout.classList.add('has-detail', 'is-detail-open');
        detail.classList.remove('hidden');
    },

    postAction(action, payload) {
        post('factionManage', { action, ...payload });
    },

    submitManageForm(form) {
        const action = form.dataset.factionAction;
        const data = new FormData(form);
        const payload = { action };
        if (action === 'invite') payload.targetId = Number(data.get('targetId'));
        if (action === 'motd') payload.message = String(data.get('message') || '').trim();
        if (action === 'warn') {
            payload.targetId = Number(data.get('targetId'));
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
