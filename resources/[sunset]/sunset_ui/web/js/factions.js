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
            tab.addEventListener('click', () => this.setTab(tab.dataset.factionTab));
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

    hide() {
        $('#faction-panel')?.classList.add('hidden');
        $('#faction-directory')?.classList.add('hidden');
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

    renderGrades(grades) {
        const select = $('#faction-grade-select');
        if (!select) return;
        select.innerHTML = '';
        (grades || []).forEach((row) => {
            const option = document.createElement('option');
            option.value = String(row.grade);
            option.textContent = `${row.label} (${row.grade})`;
            select.appendChild(option);
        });
    },

    renderRoster(members) {
        const roster = $('#faction-roster');
        if (!roster) return;
        roster.innerHTML = '';
        (members || []).forEach((member) => {
            const row = document.createElement('article');
            row.className = `faction-member${member.online ? ' is-online' : ''}${member.leader ? ' is-leader' : ''}`;
            const identity = document.createElement('div');
            const name = document.createElement('strong');
            name.textContent = member.name || `CID ${member.characterId || '?'}`;
            const rank = document.createElement('span');
            rank.textContent = `${member.gradeLabel || 'Member'}${member.serverId ? ` (${member.serverId})` : ''}`;
            identity.append(name, rank);
            const state = document.createElement('em');
            state.textContent = member.leader ? 'LEADER' : (member.onDuty ? 'ON DUTY' : (member.online ? 'ONLINE' : 'OFFLINE'));
            row.append(identity, state);
            roster.appendChild(row);
        });
        if (!members?.length) roster.innerHTML = '<p class="faction-empty">No roster entries found.</p>';
    },

    showDashboard(data = {}) {
        this.init();
        this.hide();
        this.dashboard = data;
        const members = Array.isArray(data.members) ? data.members : [];
        const report = data.report || {};
        const current = Math.max(0, Number(report.current) || 0);
        const target = Math.max(0, Number(report.target) || 0);
        const percent = target > 0 ? Math.min(100, (current / target) * 100) : 100;

        const title = $('#faction-panel-title');
        if (title) {
            const label = data.label || 'Faction';
            title.innerHTML = `${this.escape(label)} <span>CONTROL</span>`;
        }

        $('#faction-rank').textContent = `${data.gradeLabel || 'Member'}${data.leader ? ' · LEADER' : ''}`;
        $('#faction-duty').textContent = data.onDuty ? 'ON DUTY' : 'OFF DUTY';
        $('#faction-duty').classList.toggle('is-active', Boolean(data.onDuty));
        $('#faction-salary').textContent = `$${Number(data.salary || 0).toLocaleString()}/HR`;
        $('#faction-member-count').textContent = String(members.length);
        $('#faction-motd').textContent = data.motd || 'No message of the day has been set.';
        $('#faction-description').textContent = data.description || 'No department description available.';
        $('#faction-depot').textContent = `Fleet: ${data.depot || 'No garage configured'}`;
        $('#faction-report-value').textContent = target > 0 ? `${current} / ${target} activities` : `${current} activities`;
        $('#faction-report-bar').style.width = `${percent}%`;

        this.renderRoster(members);
        this.renderCommands(data.commands);
        this.renderGrades(data.grades);

        const perms = data.permissions || {};
        const canManage = Boolean(
            perms.leader || perms.invite || perms.motd || perms.giverank
            || perms.uninvite || perms.promote || perms.warn
        );
        document.querySelector('.faction-tab--manage')?.classList.toggle('hidden', !canManage);
        document.querySelectorAll('[data-faction-action]').forEach((form) => {
            const action = form.dataset.factionAction;
            let allowed = false;
            if (action === 'invite') allowed = perms.leader || perms.invite;
            else if (action === 'motd') allowed = perms.leader || perms.motd;
            else if (action === 'rank') allowed = perms.leader || perms.giverank || perms.promote;
            else if (action === 'kick') allowed = perms.leader || perms.uninvite;
            else if (action === 'warn') allowed = perms.leader || perms.warn;
            form.classList.toggle('hidden', !allowed);
        });

        this.setTab('overview');
        $('#faction-panel')?.classList.remove('hidden');
    },

    showDirectory(payload = {}) {
        this.init();
        this.hide();
        this.directory = Array.isArray(payload.factions) ? payload.factions : [];
        const list = $('#faction-directory-list');
        if (!list) return;
        list.innerHTML = '';

        this.directory.forEach((faction) => {
            const card = document.createElement('button');
            card.type = 'button';
            card.className = `faction-directory-card faction-directory-card--${faction.type === 'illegal' ? 'illegal' : 'legal'}`;
            card.dataset.factionId = faction.id || '';

            const top = document.createElement('div');
            top.className = 'faction-directory-card__top';
            const title = document.createElement('div');
            const name = document.createElement('strong');
            name.textContent = faction.label || faction.id;
            const category = document.createElement('span');
            category.textContent = String(faction.factionType || faction.type || 'organization').replaceAll('_', ' ').toUpperCase();
            title.append(name, category);
            const status = document.createElement('em');
            status.className = faction.applicationsOpen ? 'is-open' : '';
            status.textContent = faction.applicationLabel || 'Applications closed';
            top.append(title, status);

            const description = document.createElement('p');
            description.textContent = faction.description || 'No public information.';
            const meta = document.createElement('div');
            meta.className = 'faction-directory-card__meta';
            const leaders = Array.isArray(faction.leaders) && faction.leaders.length ? faction.leaders.join(', ') : 'Vacant';
            meta.textContent = `Leader: ${leaders} · ${faction.online || 0}/${faction.total || 0} online · ${faction.onDuty || 0} on duty`;

            card.append(top, description, meta);
            card.addEventListener('click', () => this.openDirectoryDetail(faction, card));
            list.appendChild(card);
        });

        if (!list.children.length) list.innerHTML = '<p class="faction-empty">No factions are configured.</p>';
        $('#faction-directory')?.classList.remove('hidden');
    },

    closeDirectoryDetail() {
        $('#faction-directory-detail')?.classList.add('hidden');
        document.querySelector('.faction-directory-layout')?.classList.remove('is-detail-open');
        document.querySelectorAll('.faction-directory-card.is-selected').forEach((el) => {
            el.classList.remove('is-selected');
        });
    },

    openDirectoryDetail(faction, cardEl) {
        const layout = document.querySelector('.faction-directory-layout');
        const detail = $('#faction-directory-detail');
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
            <div class="faction-detail__block"><span>Description</span><p>${this.escape(faction.description || 'No public information.')}</p></div>
            <div class="faction-detail__block"><span>Leadership</span><p>${this.escape(leaders)}</p></div>
            <div class="faction-detail__block"><span>How to join</span><p>${faction.type === 'illegal' ? 'Invite only — contact leadership in character.' : (faction.applicationsOpen ? 'Apply on Discord or the website. After acceptance, the leader invites you in-game with /finvite.' : 'Applications are currently closed. Only the appointed leader can invite members.')}</p></div>
        `;

        layout.classList.toggle('is-detail-open', window.matchMedia('(max-width: 900px)').matches);
        detail.classList.remove('hidden');
    },

    submitManageForm(form) {
        const action = form.dataset.factionAction;
        const data = new FormData(form);
        const payload = { action };
        if (action === 'invite' || action === 'kick' || action === 'warn') {
            payload.targetId = Number(data.get('targetId'));
        }
        if (action === 'motd') payload.message = String(data.get('message') || '').trim();
        if (action === 'rank') {
            payload.targetId = Number(data.get('targetId'));
            payload.grade = Number(data.get('grade'));
        }
        if (action === 'warn') payload.reason = String(data.get('reason') || '').trim();
        post('factionManage', payload);
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
