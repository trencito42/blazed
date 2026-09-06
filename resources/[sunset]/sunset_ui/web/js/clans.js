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
            tab.addEventListener('click', () => {
                const tabId = tab.dataset.clanTab;
                this.setTab(tabId);
                if (tabId === 'browse') this.requestBrowse();
            });
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

    setBodyOpen(open) {
        document.body.classList.toggle('clan-panels-open', open);
    },

    hide() {
        $('#clan-panel')?.classList.add('hidden');
        $('#clan-directory')?.classList.add('hidden');
        this.setBodyOpen(false);
    },

    focusReady() {
        post('clanPanelsReady');
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

    renderDirectoryCards(list, clans) {
        if (!list) return;
        list.innerHTML = '';
        (clans || []).forEach((clan) => {
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
    },

    requestBrowse() {
        if (this._browseLoading) return;
        const list = $('#clan-browse-list');
        if (!list) return;
        if (this._browseLoaded) return;
        this._browseLoading = true;
        list.innerHTML = '<p class="clan-empty">Loading clans...</p>';
        post('clanBrowse');
    },

    showBrowseInline(payload = {}) {
        this.init();
        this._browseLoading = false;
        this._browseLoaded = true;
        this.directory = Array.isArray(payload.clans) ? payload.clans : [];
        this.renderDirectoryCards($('#clan-browse-list'), this.directory);
        this.setTab('browse');
    },

    showDashboard(data = {}) {
        this.init();
        const panel = $('#clan-panel');
        if (!panel) {
            console.error('[ClanPanels] #clan-panel is missing from index.html');
            return false;
        }

        $('#clan-directory')?.classList.add('hidden');
        this._browseLoaded = false;
        this._browseLoading = false;
        this.dashboard = data || {};
        const inClan = Boolean(this.dashboard.inClan);
        const perms = this.dashboard.permissions || {};

        const title = $('#clan-panel-title');
        if (title) {
            title.innerHTML = inClan
                ? `${this.escape(this.dashboard.name || 'Clan')} <span>${this.escape(this.dashboard.tag || '')}</span>`
                : 'CREATE <span>CLAN</span>';
        }
        $('#clan-panel')?.classList.toggle('clan-panel--guest', !inClan);

        document.querySelector('.clan-tab--overview')?.classList.toggle('hidden', !inClan);
        document.querySelector('.clan-tab--roster')?.classList.toggle('hidden', !inClan);
        document.querySelector('.clan-tab--manage')?.classList.toggle('hidden', !inClan || !(
            perms.invite || perms.motd || perms.settings || perms.promote || perms.dissolve || perms.leave
        ));
        document.querySelector('.clan-tab--create')?.classList.toggle('hidden', inClan);
        document.querySelector('.clan-tab--browse')?.classList.toggle('hidden', false);

        document.querySelectorAll('[data-clan-action]').forEach((form) => {
            const action = form.dataset.clanAction;
            if (!inClan) {
                form.classList.toggle('hidden', action !== 'create');
                return;
            }
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

        if (inClan) {
            const rankEl = $('#clan-rank');
            if (rankEl) rankEl.textContent = this.dashboard.rankLabel || 'Member';
            const countEl = $('#clan-member-count');
            if (countEl) {
                countEl.textContent = `${this.dashboard.memberCount || 0} / ${this.dashboard.maxMembers || 25}`;
            }
            const motdEl = $('#clan-motd');
            if (motdEl) motdEl.textContent = this.dashboard.motd || 'No message of the day has been set.';
            const descEl = $('#clan-description');
            if (descEl) descEl.textContent = this.dashboard.description || 'No clan description.';
            const preview = $('#clan-overview-preview');
            this.paintPreview(
                preview,
                this.dashboard.tag,
                'Player',
                this.dashboard.tagStyle,
                this.dashboard.tagColor
            );

            this.renderRoster(this.dashboard.members);

            const settingsForm = document.querySelector('[data-clan-action="settings"]');
            if (settingsForm) {
                const descInput = settingsForm.querySelector('[name="description"]');
                if (descInput) descInput.value = this.dashboard.description || '';
                const colorInput = settingsForm.querySelector('[name="tagColor"]');
                if (colorInput) colorInput.value = this.dashboard.tagColor || '#FF8C00';
                this.fillStyleSelect(
                    settingsForm.querySelector('[name="tagStyle"]'),
                    this.dashboard.tagStyles,
                    this.dashboard.tagStyle
                );
            }
            this.updateSettingsPreview();
            this.setTab('overview');
        } else {
            const createForm = document.querySelector('[data-clan-action="create"]');
            if (createForm) {
                this.fillStyleSelect(
                    createForm.querySelector('[name="tagStyle"]'),
                    this.dashboard.tagStyles,
                    'brackets'
                );
                const costEl = $('#clan-create-cost');
                if (costEl) {
                    costEl.textContent = `Cost: ${Number(this.dashboard.creationCost || 500).toLocaleString()} Sunset Coins — you have ${Number(this.dashboard.accountCoins || 0).toLocaleString()} SC`;
                }
            }
            this.updateCreatePreview();
            this.setTab('create');
        }

        panel.classList.remove('hidden');
        this.setBodyOpen(true);
        this.focusReady();
        return true;
    },

    showDirectory(payload = {}) {
        this.init();
        const directory = $('#clan-directory');
        if (!directory) {
            console.error('[ClanPanels] #clan-directory is missing from index.html');
            return false;
        }

        $('#clan-panel')?.classList.add('hidden');
        this.directory = Array.isArray(payload.clans) ? payload.clans : [];
        const list = $('#clan-directory-list');
        if (!list) return false;
        this.renderDirectoryCards(list, this.directory);
        directory.classList.remove('hidden');
        this.setBodyOpen(true);
        this.focusReady();
        return true;
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
