const ClanPanels = {
    dashboard: null,
    directory: [],

    init() {
        if (this.ready) return;
        this.ready = true;

        document.querySelectorAll('[data-clan-close]').forEach((button) => {
            button.addEventListener('click', () => post('clanPanelsClose'));
        });

        document.querySelectorAll('[data-clan-tab]').forEach((tab) => {
            tab.addEventListener('click', () => this.setTab(tab.dataset.clanTab));
        });

        document.querySelectorAll('[data-clan-action]').forEach((form) => {
            form.addEventListener('submit', (event) => {
                event.preventDefault();
                this.submitForm(form);
            });
        });

        const createForm = document.querySelector('[data-clan-action="create"]');
        if (createForm) {
            ['input', 'change'].forEach((evt) => {
                createForm.addEventListener(evt, () => this.updateCreatePreview());
            });
        }

        const settingsForm = document.querySelector('[data-clan-action="settings"]');
        if (settingsForm) {
            ['input', 'change'].forEach((evt) => {
                settingsForm.addEventListener(evt, () => this.updateSettingsPreview());
            });
        }

        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            const panelOpen = !$('#clan-panel')?.classList.contains('hidden');
            const dirOpen = !$('#clan-directory')?.classList.contains('hidden');
            if (panelOpen || dirOpen) {
                event.preventDefault();
                post('clanPanelsClose');
            }
        });
    },

    hide() {
        $('#clan-panel')?.classList.add('hidden');
        $('#clan-directory')?.classList.add('hidden');
    },

    setTab(tabId) {
        document.querySelectorAll('[data-clan-tab]').forEach((tab) => {
            tab.classList.toggle('is-active', tab.dataset.clanTab === tabId);
        });
        document.querySelectorAll('[data-clan-panel]').forEach((panel) => {
            panel.classList.toggle('is-active', panel.dataset.clanPanel === tabId);
        });
    },

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    formatTaggedName(tag, baseName, style) {
        tag = String(tag || '').trim();
        baseName = String(baseName || 'Player').trim() || 'Player';
        if (!tag) return baseName;
        switch (style) {
            case 'prefix_dot': return `${tag}.${baseName}`;
            case 'suffix_brackets': return `${baseName}[${tag}]`;
            case 'suffix_dot': return `${baseName}.${tag}`;
            case 'glued_prefix': return `${tag}${baseName}`;
            case 'glued_suffix': return `${baseName}${tag}`;
            default: return `[${tag}]${baseName}`;
        }
    },

    renderTaggedHtml(tag, baseName, style, color) {
        const parts = this.splitTaggedParts(tag, baseName, style);
        const col = String(color || '#FF8C00');
        return `${this.escape(parts.prefix ? '' : '')}<span class="clan-tag" style="color:${this.escape(col)}">${this.escape(parts.prefix || parts.suffix ? '' : tag)}</span>`;
    },

    splitTaggedParts(tag, baseName, style) {
        tag = String(tag || '').trim();
        baseName = String(baseName || 'Player').trim() || 'Player';
        if (!tag) return { prefix: '', name: baseName, suffix: '', tag: '' };
        switch (style) {
            case 'prefix_dot': return { prefix: `${tag}.`, name: baseName, suffix: '', tag };
            case 'suffix_brackets': return { prefix: '', name: baseName, suffix: `[${tag}]`, tag };
            case 'suffix_dot': return { prefix: '', name: baseName, suffix: `.${tag}`, tag };
            case 'glued_prefix': return { prefix: tag, name: baseName, suffix: '', tag };
            case 'glued_suffix': return { prefix: '', name: baseName, suffix: tag, tag };
            default: return { prefix: `[${tag}]`, name: baseName, suffix: '', tag };
        }
    },

    paintPreview(el, tag, baseName, style, color) {
        if (!el) return;
        const parts = this.splitTaggedParts(tag, baseName, style);
        const col = color || '#FF8C00';
        el.innerHTML = [
            parts.prefix ? `<span style="color:${this.escape(col)}">${this.escape(parts.prefix)}</span>` : '',
            this.escape(parts.name),
            parts.suffix ? `<span style="color:${this.escape(col)}">${this.escape(parts.suffix)}</span>` : '',
        ].join('');
    },

    updateCreatePreview() {
        const form = document.querySelector('[data-clan-action="create"]');
        const preview = $('#clan-create-preview');
        if (!form || !preview) return;
        const tag = form.querySelector('[name="tag"]')?.value || 'uS';
        const style = form.querySelector('[name="tagStyle"]')?.value || 'brackets';
        const color = form.querySelector('[name="tagColor"]')?.value || '#FF8C00';
        this.paintPreview(preview, tag, 'YourName', style, color);
    },

    updateSettingsPreview() {
        const form = document.querySelector('[data-clan-action="settings"]');
        const preview = $('#clan-settings-preview');
        if (!form || !preview || !this.dashboard) return;
        const tag = this.dashboard.tag || 'uS';
        const style = form.querySelector('[name="tagStyle"]')?.value || this.dashboard.tagStyle || 'brackets';
        const color = form.querySelector('[name="tagColor"]')?.value || this.dashboard.tagColor || '#FF8C00';
        const base = (this.dashboard.previewName || 'YourName').replace(/\[.*?\]|\.|\w+$/g, '') || 'YourName';
        this.paintPreview(preview, tag, 'YourName', style, color);
    },

    fillStyleSelect(select, styles, selected) {
        if (!select) return;
        select.innerHTML = '';
        (styles || []).forEach((row) => {
            const option = document.createElement('option');
            option.value = row.id;
            option.textContent = row.label || row.id;
            if (row.id === selected) option.selected = true;
            select.appendChild(option);
        });
    },

    renderRoster(members) {
        const roster = $('#clan-roster');
        if (!roster) return;
        roster.innerHTML = '';
        (members || []).forEach((member) => {
            const row = document.createElement('article');
            row.className = `clan-member${member.online ? ' is-online' : ''}${member.leader ? ' is-leader' : ''}`;
            const identity = document.createElement('div');
            const name = document.createElement('strong');
            name.textContent = member.name || `CID ${member.characterId || '?'}`;
            const rank = document.createElement('span');
            rank.textContent = `${member.rankLabel || 'Member'}${member.serverId ? ` (${member.serverId})` : ''}`;
            identity.append(name, rank);
            const state = document.createElement('em');
            state.textContent = member.leader ? 'LEADER' : (member.online ? 'ONLINE' : 'OFFLINE');
            row.append(identity, state);
            roster.appendChild(row);
        });
        if (!members?.length) roster.innerHTML = '<p class="clan-empty">No members found.</p>';
    },

    showDashboard(data = {}) {
        this.init();
        this.hide();
        this.dashboard = data;
        const inClan = Boolean(data.inClan);
        const perms = data.permissions || {};

        $('#clan-panel')?.classList.toggle('clan-panel--guest', !inClan);
        $('#clan-panel-title')?.innerHTML = inClan
            ? `${this.escape(data.name || 'Clan')} <span>${this.escape(data.tag || '')}</span>`
            : 'CREATE <span>CLAN</span>';

        document.querySelector('.clan-tab--overview')?.classList.toggle('hidden', !inClan);
        document.querySelector('.clan-tab--roster')?.classList.toggle('hidden', !inClan);
        document.querySelector('.clan-tab--manage')?.classList.toggle('hidden', !inClan || !(
            perms.invite || perms.motd || perms.settings || perms.promote || perms.dissolve || perms.leave
        ));
        document.querySelector('.clan-tab--create')?.classList.toggle('hidden', inClan);
        document.querySelector('.clan-tab--browse')?.classList.toggle('hidden', false);

        if (inClan) {
            $('#clan-rank').textContent = data.rankLabel || 'Member';
            $('#clan-member-count').textContent = `${data.memberCount || 0} / ${data.maxMembers || 25}`;
            $('#clan-motd').textContent = data.motd || 'No message of the day has been set.';
            $('#clan-description').textContent = data.description || 'No clan description.';
            const preview = $('#clan-overview-preview');
            this.paintPreview(preview, data.tag, 'Player', data.tagStyle, data.tagColor);

            this.renderRoster(data.members);

            const motdForm = document.querySelector('[data-clan-action="motd"]');
            const settingsForm = document.querySelector('[data-clan-action="settings"]');
            if (settingsForm) {
                settingsForm.querySelector('[name="description"]').value = data.description || '';
                settingsForm.querySelector('[name="tagColor"]').value = data.tagColor || '#FF8C00';
                this.fillStyleSelect(settingsForm.querySelector('[name="tagStyle"]'), data.tagStyles, data.tagStyle);
            }
            this.updateSettingsPreview();

            document.querySelectorAll('[data-clan-action]').forEach((form) => {
                const action = form.dataset.clanAction;
                let allowed = false;
                if (action === 'invite') allowed = perms.invite;
                else if (action === 'motd') allowed = perms.motd;
                else if (action === 'settings') allowed = perms.settings;
                else if (action === 'kick') allowed = perms.kick;
                else if (action === 'promote') allowed = perms.promote;
                else if (action === 'leave') allowed = perms.leave;
                else if (action === 'dissolve') allowed = perms.dissolve;
                else if (action === 'create') allowed = false;
                form.classList.toggle('hidden', action !== 'create' && !allowed);
            });

            this.setTab('overview');
        } else {
            const createForm = document.querySelector('[data-clan-action="create"]');
            if (createForm) {
                this.fillStyleSelect(createForm.querySelector('[name="tagStyle"]'), data.tagStyles, 'brackets');
                $('#clan-create-cost').textContent = `Cost: ${Number(data.creationCost || 500).toLocaleString()} Sunset Coins — you have ${Number(data.accountCoins || 0).toLocaleString()} SC`;
            }
            this.updateCreatePreview();
            this.setTab('create');
        }

        $('#clan-panel')?.classList.remove('hidden');
    },

    showDirectory(payload = {}) {
        this.init();
        this.hide();
        this.directory = Array.isArray(payload.clans) ? payload.clans : [];
        const list = $('#clan-directory-list');
        if (!list) return;
        list.innerHTML = '';

        this.directory.forEach((clan) => {
            const card = document.createElement('article');
            card.className = 'clan-directory-card';
            const title = document.createElement('strong');
            title.textContent = clan.name || 'Clan';
            const tag = document.createElement('span');
            tag.className = 'clan-directory-card__tag';
            tag.style.color = clan.tagColor || '#FF8C00';
            tag.textContent = clan.preview || `[${clan.tag}]Player`;
            const description = document.createElement('p');
            description.textContent = clan.description || 'No description.';
            const meta = document.createElement('div');
            meta.className = 'clan-directory-card__meta';
            meta.textContent = `${clan.online || 0}/${clan.total || 0} online · tag ${clan.tag || '?'}`;
            card.append(title, tag, description, meta);
            list.appendChild(card);
        });

        if (!list.children.length) list.innerHTML = '<p class="clan-empty">No clans have been created yet.</p>';
        $('#clan-directory')?.classList.remove('hidden');
    },

    submitForm(form) {
        const action = form.dataset.clanAction;
        const payload = { action };
        form.querySelectorAll('input, textarea, select').forEach((field) => {
            if (!field.name) return;
            payload[field.name] = field.value;
        });
        post('clanManage', payload);
    },
};

window.ClanPanels = ClanPanels;
