const ClanPanels = {
    dashboard: null,
    directory: [],

    init() {
        if (this.ready) return;
        this.ready = true;

        document.querySelectorAll('[data-clan-close]').forEach((button) => {
            button.addEventListener('click', () => post('clanPanelsClose'));
        });

        document.querySelectorAll('[data-clan-detail-back]').forEach((button) => {
            button.addEventListener('click', () => this.closeDirectoryDetail());
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
        this.closeDirectoryDetail();
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
            parts.prefix ? `<span class="clan-identity__tag" style="color:${this.escape(col)}">${this.escape(parts.prefix)}</span>` : '',
            `<span class="clan-identity__name">${this.escape(parts.name)}</span>`,
            parts.suffix ? `<span class="clan-identity__tag" style="color:${this.escape(col)}">${this.escape(parts.suffix)}</span>` : '',
        ].join('');
    },

    identityPreviewHtml(clan, baseName = 'Player') {
        const wrap = document.createElement('div');
        wrap.className = 'clan-identity-preview';
        this.paintPreview(wrap, clan.tag, baseName, clan.tagStyle, clan.tagColor);
        return wrap.innerHTML;
    },

    detailContext(listEl) {
        if (listEl?.id === 'clan-browse-list') {
            return {
                layout: $('#clan-browse-layout'),
                detail: $('#clan-browse-detail'),
            };
        }
        return {
            layout: $('#clan-browse-layout'),
            detail: $('#clan-browse-detail'),
        };
    },

    closeDirectoryDetail() {
        $('#clan-browse-detail')?.classList.add('hidden');
        $('#clan-browse-layout')?.classList.remove('is-detail-open');
        document.querySelectorAll('.clan-directory-card.is-selected').forEach((el) => {
            el.classList.remove('is-selected');
        });
        this._selectedClanId = null;
    },

    renderDetailBody(detailEl, clan, members) {
        const body = detailEl?.querySelector('.clan-detail__body');
        if (!body || !clan) return;

        const motd = String(clan.motd || '').trim();
        const description = String(clan.description || '').trim() || 'No public description has been set.';
        const roster = Array.isArray(members) ? members : (clan.members || []);
        const rosterHtml = roster.length
            ? roster.map((member) => `
                <article class="clan-detail-member${member.online ? ' is-online' : ''}${member.leader ? ' is-leader' : ''}">
                    <div>
                        <strong>${this.escape(member.name || 'Unknown')}</strong>
                        <span>${this.escape(member.rank ? `R${member.rank} · ` : '')}${this.escape(member.rankLabel || 'Member')}${member.warns ? ` · ${member.warns}/3 warns` : ''}${member.serverId ? ` · ID ${member.serverId}` : ''}</span>
                    </div>
                    <em>${member.leader ? 'LEADER' : (member.online ? 'ONLINE' : 'OFFLINE')}</em>
                </article>
            `).join('')
            : '<p class="clan-empty">No members listed.</p>';

        body.innerHTML = `
            <h3>${this.escape(clan.name || 'Clan')}</h3>
            <div class="clan-detail__identity">${this.identityPreviewHtml(clan)}</div>
            <div class="clan-detail__meta-line">Tag <strong style="color:${this.escape(clan.tagColor || '#FF8C00')}">${this.escape(clan.tag || '?')}</strong> · Style ${this.escape(clan.tagStyleLabel || clan.tagStyle || '—')}</div>
            <div class="clan-detail__stats">
                <div class="clan-detail__stat"><strong>${Number(clan.online) || 0}</strong><span>Online</span></div>
                <div class="clan-detail__stat"><strong>${Number(clan.total) || 0}</strong><span>Members</span></div>
                <div class="clan-detail__stat"><strong>${Number(clan.maxMembers) || 25}</strong><span>Capacity</span></div>
            </div>
            <div class="clan-detail__block"><span>Leader</span><p>${this.escape(clan.leader || 'Unknown')}</p></div>
            <div class="clan-detail__block"><span>MOTD</span><p>${this.escape(motd || 'No MOTD posted. Officers use /cmotd.')}</p></div>
            <div class="clan-detail__block"><span>Unit intel</span><p>${this.escape(description)}</p></div>
            <div class="clan-detail__block"><span>Recruitment</span><p>Contact the leader in-character or wait for an in-game invite via <code>/clan</code>.</p></div>
            <div class="clan-detail__block"><span>Crew roster</span><div class="clan-detail-roster">${rosterHtml}</div></div>
        `;
    },

    openClanDetail(clan, cardEl, listEl) {
        const ctx = this.detailContext(listEl);
        if (!ctx.detail || !clan) return;

        document.querySelectorAll('.clan-directory-card.is-selected').forEach((el) => {
            el.classList.remove('is-selected');
        });
        cardEl?.classList.add('is-selected');
        this._selectedClanId = clan.id;

        this.renderDetailBody(ctx.detail, clan, clan.members || []);
        ctx.layout?.classList.add('is-detail-open');
        ctx.detail.classList.remove('hidden');

        if (!clan.members || !clan.members.length) {
            post('clanProfile', { clanId: clan.id });
        }
    },

    showClanProfile(profile = {}) {
        if (!profile || !profile.id) return;
        const clanId = profile.id;
        this.directory = (this.directory || []).map((row) => (row.id === clanId ? { ...row, ...profile } : row));

        const contexts = [
            { detail: $('#clan-browse-detail'), list: $('#clan-browse-list') },
        ];
        contexts.forEach(({ detail, list }) => {
            if (this._selectedClanId === clanId && detail && !detail.classList.contains('hidden')) {
                const clan = this.directory.find((row) => row.id === clanId) || profile;
                this.renderDetailBody(detail, clan, profile.members || clan.members);
            }
        });
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

    renderRoster(members, permissions, viewerCharacterId) {
        const roster = $('#clan-roster');
        if (!roster) return;
        roster.innerHTML = '';
        const perms = permissions || this.dashboard?.permissions || {};
        const viewerId = Number(viewerCharacterId || this.dashboard?.viewerCharacterId) || 0;
        const viewerRank = Number(this.dashboard?.rank) || 0;
        const canKick = Boolean(perms.kick);
        const canPromote = Boolean(perms.promote);
        const canWarn = Boolean(perms.warn);
        const isLeader = Boolean(perms.leader);

        (members || []).forEach((member) => {
            const row = document.createElement('article');
            row.className = `clan-member faction-member${member.online ? ' is-online' : ''}${member.leader ? ' is-leader' : ''}`;

            const identity = document.createElement('div');
            identity.className = 'faction-member__identity';
            const name = document.createElement('strong');
            name.textContent = member.name || `CID ${member.characterId || '?'}`;
            const rank = document.createElement('span');
            rank.textContent = `${member.rank ? `R${member.rank}` : 'R?'} · ${member.rankLabel || 'Member'}${member.warns ? ` · ${member.warns}/3 strikes` : ''}${member.serverId ? ` · ID ${member.serverId}` : ''}`;
            identity.append(name, rank);

            const state = document.createElement('div');
            state.className = 'faction-member__state';
            const badge = document.createElement('span');
            badge.className = 'org-member-badge';
            if (member.leader) {
                badge.classList.add('is-leader');
                badge.textContent = 'LEADER';
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
            const manageable = !isSelf && !member.leader && member.online && (canKick || canPromote || canWarn);
            const lowerRank = isLeader || (Number(member.rank) < viewerRank);

            if (manageable && canPromote && lowerRank) {
                const up = document.createElement('button');
                up.type = 'button';
                up.className = 'faction-btn';
                up.textContent = '▲';
                up.title = 'Promote';
                up.addEventListener('click', () => post('clanManage', { action: 'rankUp', targetId: member.serverId }));
                const down = document.createElement('button');
                down.type = 'button';
                down.className = 'faction-btn';
                down.textContent = '▼';
                down.title = 'Demote';
                down.addEventListener('click', () => post('clanManage', { action: 'rankDown', targetId: member.serverId }));
                actions.append(up, down);
            }
            if (manageable && canKick && lowerRank) {
                const kick = document.createElement('button');
                kick.type = 'button';
                kick.className = 'faction-btn is-danger';
                kick.textContent = 'KICK';
                kick.addEventListener('click', () => post('clanManage', { action: 'kick', targetId: member.serverId }));
                actions.append(kick);
            }
            if (manageable && canWarn && lowerRank) {
                const warn = document.createElement('button');
                warn.type = 'button';
                warn.className = 'faction-btn is-warn';
                warn.textContent = 'STRIKE';
                warn.addEventListener('click', () => {
                    const reason = window.prompt('Strike reason:', 'No reason given');
                    if (reason === null) return;
                    post('clanManage', { action: 'warn', targetId: member.serverId, reason });
                });
                actions.append(warn);
            }

            row.append(identity, state, actions);
            roster.appendChild(row);
        });
        if (!members?.length) roster.innerHTML = '<p class="clan-empty">No crew members found.</p>';
    },

    renderRankLabelEditor(labels) {
        const wrap = document.getElementById('clan-rank-label-fields');
        if (!wrap) return;
        wrap.innerHTML = '';
        const source = labels || {};
        for (let i = 1; i <= 7; i += 1) {
            const field = document.createElement('label');
            field.className = 'clan-rank-label-field';
            field.innerHTML = `
                <span>Rank ${i}</span>
                <input type="text" data-rank-label="${i}" maxlength="48" value="${this.escape(source[i] || source[String(i)] || '')}" placeholder="Rank ${i}">
            `;
            wrap.appendChild(field);
        }
    },

    renderDirectoryCards(list, clans) {
        if (!list) return;
        list.innerHTML = '';
        (clans || []).forEach((clan) => {
            const card = document.createElement('button');
            card.type = 'button';
            card.className = 'org-directory-row clan-directory-card';
            card.dataset.clanId = String(clan.id || '');

            const main = document.createElement('div');
            main.className = 'org-directory-row__main';
            const title = document.createElement('strong');
            title.textContent = clan.name || 'Clan';
            const tagLine = document.createElement('span');
            tagLine.textContent = `[${clan.tag || '?'}] · ${clan.tagStyleLabel || 'tag'}`;
            const identity = document.createElement('div');
            identity.className = 'clan-directory-card__identity';
            identity.innerHTML = this.identityPreviewHtml(clan);
            const description = document.createElement('p');
            description.textContent = String(clan.description || '').trim() || 'No public intel yet.';
            main.append(title, tagLine, identity, description);

            const stats = document.createElement('div');
            stats.className = 'org-directory-row__stats';
            const online = document.createElement('b');
            online.textContent = `${clan.online || 0}/${clan.total || 0}`;
            const leader = document.createElement('em');
            leader.textContent = clan.leader || 'Unknown';
            stats.append(online, leader);

            card.append(main, stats);
            card.addEventListener('click', () => this.openClanDetail(clan, card, list));
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
        this.closeDirectoryDetail();
        this.renderDirectoryCards($('#clan-browse-list'), this.directory);
        this.setTab('browse');
    },

    tagStyleLabel(styleId) {
        const styles = this.dashboard?.tagStyles || [];
        const row = styles.find((entry) => entry.id === styleId);
        return row?.label || styleId || '—';
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
            if (inClan) {
                const color = this.escape(this.dashboard.tagColor || '#FF8C00');
                const clanName = this.escape(this.dashboard.name || 'Clan');
                const clanTag = this.escape(this.dashboard.tag || '');
                title.innerHTML = clanTag
                    ? `CLAN <span><span style="color:${color}">${clanName}</span> · <span style="color:${color}">${clanTag}</span></span>`
                    : `CLAN <span style="color:${color}">${clanName}</span>`;
            } else {
                title.innerHTML = 'CREATE <span>CLAN</span>';
            }
        }
        $('#clan-panel')?.classList.toggle('clan-panel--guest', !inClan);

        document.querySelector('.clan-tab--overview')?.classList.toggle('hidden', !inClan);
        document.querySelector('.clan-tab--roster')?.classList.toggle('hidden', !inClan);
        document.querySelector('.clan-tab--manage')?.classList.toggle('hidden', !inClan || !(
            perms.invite || perms.motd || perms.settings || perms.promote || perms.warn || perms.rankLabels || perms.dissolve || perms.leave
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
            else if (action === 'rankUp' || action === 'rankDown') allowed = perms.promote;
            else if (action === 'warn') allowed = perms.warn;
            else if (action === 'rankLabels') allowed = perms.rankLabels;
            else if (action === 'leave') allowed = perms.leave;
            else if (action === 'dissolve') allowed = perms.dissolve;
            else if (action === 'create') allowed = false;
            form.classList.toggle('hidden', action !== 'create' && !allowed);
        });

        if (inClan) {
            const rankEl = $('#clan-rank');
            if (rankEl) {
                rankEl.textContent = this.dashboard.rank
                    ? `R${this.dashboard.rank} · ${this.dashboard.rankLabel || 'Member'}`
                    : (this.dashboard.rankLabel || 'Member');
            }
            const countEl = $('#clan-member-count');
            if (countEl) {
                countEl.textContent = `${this.dashboard.memberCount || 0} / ${this.dashboard.maxMembers || 25}`;
            }
            const motdEl = $('#clan-motd');
            if (motdEl) motdEl.textContent = this.dashboard.motd || 'No MOTD posted. Officers use /cmotd.';
            const descEl = $('#clan-description');
            if (descEl) descEl.textContent = this.dashboard.description || 'No unit intel on file.';
            const preview = $('#clan-overview-preview');
            this.paintPreview(
                preview,
                this.dashboard.tag,
                'Player',
                this.dashboard.tagStyle,
                this.dashboard.tagColor
            );
            const styleLabel = $('#clan-tag-style-label');
            if (styleLabel) styleLabel.textContent = this.tagStyleLabel(this.dashboard.tagStyle);

            this.renderRoster(this.dashboard.members, perms, this.dashboard.viewerCharacterId);

            const rosterMeta = $('#clan-roster-meta');
            if (rosterMeta) {
                const members = this.dashboard.members || [];
                const online = members.filter((m) => m.online).length;
                rosterMeta.textContent = `${online} online · ${this.dashboard.memberCount || 0}/${this.dashboard.maxMembers || 25} slots`;
            }

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
            const motdForm = document.querySelector('[data-clan-action="motd"]');
            if (motdForm) {
                const motdInput = motdForm.querySelector('[name="message"]');
                if (motdInput) motdInput.value = this.dashboard.motd || '';
            }
            this.updateSettingsPreview();
            this.renderRankLabelEditor(this.dashboard.rankLabels);
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
                    costEl.textContent = `Cost: ${Number(this.dashboard.creationCost || 500).toLocaleString()} Blaze Points — you have ${Number(this.dashboard.accountCoins || 0).toLocaleString()} BP`;
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
        return this.openBrowsePanel(payload);
    },

    openBrowsePanel(payload = {}) {
        this.init();
        this.directory = Array.isArray(payload.clans) ? payload.clans : [];
        this.closeDirectoryDetail();
        this._browseLoaded = true;
        this._browseLoading = false;

        $('#clan-directory')?.classList.add('hidden');
        this.renderDirectoryCards($('#clan-browse-list'), this.directory);

        const panel = $('#clan-panel');
        const panelWasHidden = panel?.classList.contains('hidden');
        if (panelWasHidden && !this.dashboard) {
            document.querySelector('.clan-tab--overview')?.classList.add('hidden');
            document.querySelector('.clan-tab--roster')?.classList.add('hidden');
            document.querySelector('.clan-tab--manage')?.classList.add('hidden');
            document.querySelector('.clan-tab--create')?.classList.remove('hidden');
            const title = $('#clan-panel-title');
            if (title) title.innerHTML = 'SERVER <span>CLANS</span>';
        }

        panel?.classList.remove('hidden');
        this.setTab('browse');
        this.setBodyOpen(true);
        if (panelWasHidden) this.focusReady();
        return true;
    },

    submitForm(form) {
        const action = form.dataset.clanAction;
        const payload = { action };
        if (action === 'rankLabels') {
            const labels = {};
            form.querySelectorAll('[data-rank-label]').forEach((field) => {
                labels[field.dataset.rankLabel] = field.value;
            });
            payload.labels = labels;
        } else {
            form.querySelectorAll('input, textarea, select').forEach((field) => {
                if (!field.name) return;
                payload[field.name] = field.value;
            });
        }
        post('clanManage', payload);
    },
};

window.ClanPanels = ClanPanels;
