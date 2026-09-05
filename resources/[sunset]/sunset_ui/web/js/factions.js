const FactionPanels = {
    init() {
        if (this.ready) return;
        this.ready = true;
        document.querySelectorAll('[data-faction-close]').forEach((button) => {
            button.addEventListener('click', () => post('factionPanelsClose'));
        });
        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            if (!$('#faction-panel')?.classList.contains('hidden') || !$('#faction-directory')?.classList.contains('hidden')) {
                event.preventDefault();
                post('factionPanelsClose');
            }
        });
    },

    hide() {
        $('#faction-panel')?.classList.add('hidden');
        $('#faction-directory')?.classList.add('hidden');
    },

    showDashboard(data = {}) {
        this.init();
        this.hide();
        const members = Array.isArray(data.members) ? data.members : [];
        const report = data.report || {};
        const current = Math.max(0, Number(report.current) || 0);
        const target = Math.max(0, Number(report.target) || 0);
        const percent = target > 0 ? Math.min(100, (current / target) * 100) : 100;
        $('#faction-panel-title').textContent = data.label || 'Faction';
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

        const roster = $('#faction-roster');
        roster.innerHTML = '';
        members.forEach((member) => {
            const row = document.createElement('article');
            row.className = `faction-member${member.online ? ' is-online' : ''}${member.leader ? ' is-leader' : ''}`;
            const identity = document.createElement('div');
            const name = document.createElement('strong');
            name.textContent = member.name || `CID ${member.characterId || '?'}`;
            const rank = document.createElement('span');
            rank.textContent = `${member.gradeLabel || 'Member'}${member.serverId ? ` · #${member.serverId}` : ''}`;
            identity.append(name, rank);
            const state = document.createElement('em');
            state.textContent = member.leader ? 'LEADER' : (member.onDuty ? 'ON DUTY' : (member.online ? 'ONLINE' : 'OFFLINE'));
            row.append(identity, state);
            roster.appendChild(row);
        });
        if (!members.length) roster.innerHTML = '<p class="faction-empty">No roster entries found.</p>';
        $('#faction-panel')?.classList.remove('hidden');
    },

    showDirectory(payload = {}) {
        this.init();
        this.hide();
        const list = $('#faction-directory-list');
        list.innerHTML = '';
        (payload.factions || []).forEach((faction) => {
            const card = document.createElement('article');
            card.className = `faction-directory-card faction-directory-card--${faction.type === 'illegal' ? 'illegal' : 'legal'}`;
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
            status.textContent = faction.applicationLabel || 'Closed';
            top.append(title, status);
            const description = document.createElement('p');
            description.textContent = faction.description || 'No public information.';
            const meta = document.createElement('div');
            meta.className = 'faction-directory-card__meta';
            const leaders = Array.isArray(faction.leaders) && faction.leaders.length ? faction.leaders.join(', ') : 'Vacant';
            meta.textContent = `Leader: ${leaders} · ${faction.online || 0}/${faction.total || 0} online · ${faction.onDuty || 0} on duty`;
            card.append(top, description, meta);
            list.appendChild(card);
        });
        if (!list.children.length) list.innerHTML = '<p class="faction-empty">No factions are configured.</p>';
        $('#faction-directory')?.classList.remove('hidden');
    },
};

window.FactionPanels = FactionPanels;
