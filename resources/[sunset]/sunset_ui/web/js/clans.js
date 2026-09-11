/* ═══ PREMIUM CLANS UI — Dashboard & Directory (1:1 Mockup) ═══ */

const ClanPanels = {
    dashboard: null,
    directory: [],
    selectedClanId: null,
    ready: false,

    init() {
        if (this.ready) return;
        this.ready = true;

        // Tab Switching
        document.querySelectorAll('[data-clan-tab]').forEach((tab) => {
            tab.addEventListener('click', () => {
                const tabId = tab.dataset.clanTab;
                this.setTab(tabId);
            });
        });

        // Form Submissions
        document.querySelectorAll('[data-clan-action]').forEach((form) => {
            form.addEventListener('submit', (event) => {
                event.preventDefault();
                this.submitForm(form);
            });
        });

        // Action Buttons in Management
        $('#clan-manage-promote')?.addEventListener('click', () => this.manageSelected('rankUp'));
        $('#clan-manage-demote')?.addEventListener('click', () => this.manageSelected('rankDown'));
        $('#clan-manage-kick')?.addEventListener('click', () => this.manageSelected('kick'));
        $('#clan-btn-leave')?.addEventListener('click', () => {
            if (confirm('Ești sigur că vrei să părăsești clanul?')) {
                post('clanManage', { action: 'leave' });
            }
        });
        $('#clan-btn-dissolve')?.addEventListener('click', () => {
            if (confirm('ATENȚIE: Ești sigur că vrei să desființezi clanul? Acțiunea este ireversibilă!')) {
                post('clanManage', { action: 'dissolve' });
            }
        });

        // Directory Modal Close
        $('#clan-directory-modal-close')?.addEventListener('click', () => this.closeDirectoryModal());
        $('#clan-directory-close')?.addEventListener('click', () => post('clanPanelsClose'));
        $('#clan-directory-modal')?.addEventListener('click', (e) => {
            if (e.target?.id === 'clan-directory-modal') this.closeDirectoryModal();
        });

        // Live Previews
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

        // ESC Key Handling
        document.addEventListener('keydown', (event) => {
            if (event.key !== 'Escape') return;
            const panelOpen = !$('#clan-panel')?.classList.contains('hidden');
            const dirOpen = !$('#clan-directory')?.classList.contains('hidden');
            if (!panelOpen && !dirOpen) return;
            event.preventDefault();

            if (dirOpen && $('#clan-directory-modal')?.classList.contains('is-open')) {
                this.closeDirectoryModal();
                return;
            }

            post('clanPanelsClose');
        });
    },

    setBodyOpen(open) {
        document.body.classList.toggle('clan-panels-open', open);
    },

    hide() {
        $('#clan-panel')?.classList.add('hidden');
        $('#clan-directory')?.classList.add('hidden');
        this.setBodyOpen(false);
        this.closeDirectoryModal();
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

    tagStyleLabel(style) {
        const map = {
            brackets: '[TAG]Name',
            prefix_dot: 'TAG.Name',
            suffix_brackets: 'Name[TAG]',
            suffix_dot: 'Name.TAG',
            glued_prefix: 'TAGName',
            glued_suffix: 'NameTAG',
        };
        return map[style] || '[TAG]Name';
    },

    paintPreview(el, tag, baseName, style, color) {
        if (!el) return;
        const parts = this.splitTaggedParts(tag, baseName, style);
        const col = color || '#00ffcc';
        el.innerHTML = [
            parts.prefix ? `<span style="color:${this.escape(col)}">${this.escape(parts.prefix)}</span>` : '',
            `<span>${this.escape(parts.name)}</span>`,
            parts.suffix ? `<span style="color:${this.escape(col)}">${this.escape(parts.suffix)}</span>` : '',
        ].join('');
    },

    fillStyleSelect(select, styles, selected) {
        if (!select) return;
        select.innerHTML = '';
        const rows = (styles && styles.length) ? styles : [
            { id: 'brackets', label: '[TAG]Name' },
            { id: 'prefix_dot', label: 'TAG.Name' },
            { id: 'suffix_brackets', label: 'Name[TAG]' },
            { id: 'suffix_dot', label: 'Name.TAG' },
            { id: 'glued_prefix', label: 'TAGName' },
            { id: 'glued_suffix', label: 'NameTAG' },
        ];
        rows.forEach((row) => {
            const option = document.createElement('option');
            option.value = row.id;
            option.textContent = row.label || row.id;
            if (row.id === selected) option.selected = true;
            select.appendChild(option);
        });
    },

    updateCreatePreview() {
        const form = document.querySelector('[data-clan-action="create"]');
        const preview = $('#clan-create-preview');
        if (!form || !preview) return;
        const tag = form.querySelector('[name="tag"]')?.value || 'uS';
        const style = form.querySelector('[name="tagStyle"]')?.value || 'brackets';
        const color = form.querySelector('[name="tagColor"]')?.value || '#00ffcc';
        this.paintPreview(preview, tag, 'YourName', style, color);
    },

    updateSettingsPreview() {
        const form = document.querySelector('[data-clan-action="settings"]');
        const preview = $('#clan-settings-preview');
        if (!form || !preview || !this.dashboard) return;
        const tag = form.querySelector('[name="tag"]')?.value || this.dashboard.tag || 'uS';
        const style = form.querySelector('[name="tagStyle"]')?.value || this.dashboard.tagStyle || 'brackets';
        const color = form.querySelector('[name="tagColor"]')?.value || this.dashboard.tagColor || '#00ffcc';
        this.paintPreview(preview, tag, 'YourName', style, color);
    },

    /* --- DASHBOARD DISPLAY --- */
    showDashboard(payload = {}) {
        this.init();
        this.dashboard = payload;
        const inClan = Boolean(payload && payload.inClan);
        const perms = payload?.permissions || {};
        const panel = $('#clan-panel');
        if (!panel) return false;

        $('#clan-directory')?.classList.add('hidden');

        const title = $('#clan-panel-title');
        const typeEl = $('#clan-panel-type');

        if (inClan) {
            const color = this.escape(payload.tagColor || '#00ffcc');
            const clanName = this.escape(payload.name || 'Clan');
            const clanTag = this.escape(payload.tag || '');
            if (title) {
                title.innerHTML = clanTag
                    ? `CLAN <span>${clanName} · <span style="color:${color}">[${clanTag}]</span></span>`
                    : `CLAN <span>${clanName}</span>`;
            }
            if (typeEl) typeEl.textContent = 'Organizație Privată';

            // Sidebar Tab Toggles
            document.querySelector('[data-clan-tab="overview"]')?.classList.remove('hidden');
            document.querySelector('[data-clan-tab="roster"]')?.classList.remove('hidden');
            document.querySelector('.clan-tab--tag')?.classList.toggle('hidden', !perms.settings);
            document.querySelector('.clan-tab--actions')?.classList.toggle('hidden', !perms.kick && !perms.promote && !perms.warn && !perms.motd && !perms.invite);
            document.querySelector('.clan-tab--org')?.classList.toggle('hidden', !perms.rankLabels);
            document.querySelector('.clan-tab--create')?.classList.add('hidden');

            // Overview Stats
            const rankEl = $('#clan-rank');
            if (rankEl) {
                rankEl.textContent = payload.rank
                    ? `R${payload.rank} · ${payload.rankLabel || 'Member'}`
                    : (payload.rankLabel || 'Member');
            }

            const onlineCount = (payload.members || []).filter((m) => m.online).length;
            const onlineEl = $('#clan-online-count');
            if (onlineEl) onlineEl.textContent = onlineCount;

            const memberCountEl = $('#clan-member-count');
            if (memberCountEl) memberCountEl.textContent = `${payload.memberCount || 0}/${payload.maxMembers || 25}`;

            const styleLabel = $('#clan-tag-style-label');
            if (styleLabel) styleLabel.textContent = this.tagStyleLabel(payload.tagStyle);

            const motdEl = $('#clan-motd');
            if (motdEl) motdEl.textContent = payload.motd || 'No MOTD posted. Officers use /cmotd.';

            const descEl = $('#clan-description');
            if (descEl) descEl.textContent = payload.description || 'No unit intel on file.';

            this.paintPreview(
                $('#clan-overview-preview'),
                payload.tag,
                payload.previewName ? payload.previewName.replace(/\[.*?\]|\(.*?\)/g, '').trim() : 'Player',
                payload.tagStyle,
                payload.tagColor
            );

            // Roster
            this.renderRoster(payload.members, perms, payload.viewerCharacterId);

            const rosterMeta = $('#clan-roster-meta');
            if (rosterMeta) {
                rosterMeta.textContent = `${onlineCount} online · ${payload.memberCount || 0}/${payload.maxMembers || 25} membri înregistrați`;
            }

            // Management Select
            this.fillManageSelect(payload.members, payload.viewerCharacterId);

            // Settings Form
            const settingsForm = document.querySelector('[data-clan-action="settings"]');
            if (settingsForm) {
                const tagInput = settingsForm.querySelector('[name="tag"]');
                if (tagInput) tagInput.value = payload.tag || '';
                const descInput = settingsForm.querySelector('[name="description"]');
                if (descInput) descInput.value = payload.description || '';
                const colorInput = settingsForm.querySelector('[name="tagColor"]');
                if (colorInput) colorInput.value = payload.tagColor || '#00ffcc';
                this.fillStyleSelect(
                    settingsForm.querySelector('[name="tagStyle"]'),
                    payload.tagStyles,
                    payload.tagStyle
                );
            }

            // MOTD Form
            const motdForm = document.querySelector('[data-clan-action="motd"]');
            if (motdForm) {
                const motdInput = motdForm.querySelector('[name="message"]');
                if (motdInput) motdInput.value = payload.motd || '';
            }

            this.updateSettingsPreview();
            this.renderRankLabelEditor(payload.rankLabels);

            // Show Leave / Dissolve
            $('#clan-btn-dissolve')?.classList.toggle('hidden', !perms.dissolve);

            this.setTab('overview');
        } else {
            // Guest / Registration Mode
            if (title) title.innerHTML = 'CLAN <span>ÎNREGISTRARE</span>';
            if (typeEl) typeEl.textContent = 'Înregistrează un clan';

            document.querySelector('[data-clan-tab="overview"]')?.classList.add('hidden');
            document.querySelector('[data-clan-tab="roster"]')?.classList.add('hidden');
            document.querySelector('.clan-tab--tag')?.classList.add('hidden');
            document.querySelector('.clan-tab--actions')?.classList.add('hidden');
            document.querySelector('.clan-tab--org')?.classList.add('hidden');
            document.querySelector('.clan-tab--create')?.classList.remove('hidden');

            const createForm = document.querySelector('[data-clan-action="create"]');
            if (createForm) {
                this.fillStyleSelect(
                    createForm.querySelector('[name="tagStyle"]'),
                    payload.tagStyles,
                    'brackets'
                );
                const costEl = $('#clan-create-cost');
                if (costEl) {
                    costEl.textContent = `Cost: ${Number(payload.creationCost || 500).toLocaleString()} Blaze Points — ai ${Number(payload.accountCoins || 0).toLocaleString()} BP`;
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

    renderRoster(members, permissions, viewerCharacterId) {
        const roster = $('#clan-roster');
        if (!roster) return;
        roster.innerHTML = '';

        (members || []).forEach((member) => {
            const item = document.createElement('div');
            item.className = 'premium-clan__roster-item';

            const dotClass = member.online ? 'is-online' : 'is-offline';
            const serverIdBadge = member.serverId ? `<span style="font-size:10px;color:var(--pf-text-muted);margin-left:6px;">(ID: ${member.serverId})</span>` : '';

            item.innerHTML = `
                <div class="premium-clan__roster-info">
                    <div class="premium-clan__status-dot ${dotClass}" title="${member.online ? 'Online' : 'Offline'}"></div>
                    <div>
                        <div class="premium-clan__member-name">${this.escape(member.name || 'Necunoscut')} ${serverIdBadge}</div>
                        <div class="premium-clan__member-rank">${member.leader ? '<span style="color:var(--pf-accent-orange);font-weight:800;">LIDER</span> · ' : ''}${this.escape(member.rankLabel || 'Membru')}</div>
                    </div>
                </div>
                <div class="premium-clan__member-id">R${member.rank || 1}</div>
            `;
            roster.appendChild(item);
        });

        if (!members || !members.length) {
            roster.innerHTML = '<p class="premium-clan__empty">Niciun membru înregistrat în acest clan.</p>';
        }
    },

    fillMemberSelect(select, members, viewerCharacterId, placeholder) {
        if (!select) return;
        select.innerHTML = `<option value="" disabled selected>${placeholder}</option>`;
        const viewerId = Number(viewerCharacterId) || 0;
        (members || []).forEach((m) => {
            if (Number(m.characterId) === viewerId) return;
            const opt = document.createElement('option');
            opt.value = String(m.characterId);
            const online = m.online && m.serverId ? `online · ID ${m.serverId}` : 'offline';
            const warns = Number(m.warns) > 0 ? ` · ${m.warns}/3 warn` : '';
            opt.textContent = `${m.name} (${online}) — ${m.rankLabel || 'Membru'}${warns}`;
            select.appendChild(opt);
        });
    },

    fillManageSelect(members, viewerCharacterId) {
        this.fillMemberSelect(
            $('#clan-manage-select'),
            members,
            viewerCharacterId,
            'Alege un membru...'
        );
        this.fillMemberSelect(
            $('#clan-warn-select'),
            members,
            viewerCharacterId,
            'Alege un membru...'
        );
    },

    manageSelected(action) {
        const select = $('#clan-manage-select');
        const targetCharacterId = Number(select?.value);
        if (!targetCharacterId) {
            alert('Te rog selectează un membru din listă!');
            return;
        }

        const label = select?.selectedOptions?.[0]?.textContent || 'acest membru';
        if (action === 'kick') {
            if (!confirm(`Ești sigur că vrei să concediezi ${label}?`)) return;
        }

        post('clanManage', { action, targetCharacterId });
    },

    renderRankLabelEditor(labels) {
        const wrap = document.getElementById('clan-rank-label-fields');
        if (!wrap) return;
        wrap.innerHTML = '';
        const source = labels || {};
        for (let i = 1; i <= 7; i += 1) {
            const field = document.createElement('div');
            field.className = 'clan-rank-item';
            field.innerHTML = `
                <span>GRADUL ${i}</span>
                <input type="text" class="premium-clan__form-control" data-rank-label="${i}" maxlength="48" value="${this.escape(source[i] || source[String(i)] || '')}" placeholder="Denumire Grad ${i}">
            `;
            wrap.appendChild(field);
        }
    },

    /* --- DIRECTORY DISPLAY (/clans) --- */
    showDirectory(payload = {}) {
        this.init();
        this.directory = Array.isArray(payload.clans) ? payload.clans : [];
        this.closeDirectoryModal();

        $('#clan-panel')?.classList.add('hidden');
        const dir = $('#clan-directory');
        if (!dir) return false;

        this.renderDirectoryCards(this.directory);

        dir.classList.remove('hidden');
        this.setBodyOpen(true);
        this.focusReady();
        return true;
    },

    renderDirectoryCards(clans) {
        const list = $('#clan-directory-list');
        if (!list) return;
        list.innerHTML = '';

        (clans || []).forEach((clan) => {
            const card = document.createElement('div');
            card.className = 'premium-factions-dir__card premium-clans-dir__card';

            const tagColor = this.escape(clan.tagColor || '#00ffcc');
            const total = Number(clan.total) || 0;
            const maxMembers = Number(clan.maxMembers) || 25;
            const isFull = total >= maxMembers;

            card.innerHTML = `
                <div class="premium-factions-dir__card-head">
                    <div class="premium-factions-dir__card-icon">
                        <svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                    </div>
                    <div>
                        <div class="premium-factions-dir__card-name">${this.escape(clan.name || 'Clan')}</div>
                        <div class="premium-factions-dir__card-type" style="color:${tagColor};font-weight:800;">[${this.escape(clan.tag || '')}] · ${this.escape(clan.tagStyleLabel || 'Clan Unit')}</div>
                    </div>
                </div>

                <div class="premium-factions-dir__card-stats">
                    <div class="premium-factions-dir__stat-row">
                        <span>Lider:</span>
                        <b>${this.escape(clan.leader || 'Necunoscut')}</b>
                    </div>
                    <div class="premium-factions-dir__stat-row">
                        <span>Membri:</span>
                        <b><span class="highlight">${Number(clan.online) || 0}</span> / ${total}</b>
                    </div>
                </div>

                <div class="premium-factions-dir__recruit ${isFull ? 'is-closed' : 'is-open'}">
                    <div class="dot"></div>${isFull ? 'Recrutări Închise' : 'Recrutări Deschise'}
                </div>
            `;

            card.addEventListener('click', () => this.openDirectoryModal(clan));
            list.appendChild(card);
        });

        if (!clans || !clans.length) {
            list.innerHTML = '<p class="premium-clans-dir__empty">Niciun clan activ găsit pe server.</p>';
        }
    },

    openDirectoryModal(clan) {
        const modal = $('#clan-directory-modal');
        if (!modal || !clan) return;
        this.selectedClanId = clan.id;
        modal.classList.add('is-open');

        const tagColor = this.escape(clan.tagColor || '#00ffcc');
        const icon = $('#clan-dir-modal-icon');
        if (icon) {
            icon.innerHTML = `<span style="font-size:32px;font-weight:900;color:${tagColor};">[${this.escape(clan.tag || '')}]</span>`;
        }

        const titleEl = $('#clan-dir-modal-title');
        if (titleEl) titleEl.textContent = clan.name || 'Clan';

        const descEl = $('#clan-dir-modal-desc');
        if (descEl) descEl.textContent = clan.description || 'Nicio descriere publică introdusă.';

        const leaderEl = $('#clan-dir-modal-leader');
        if (leaderEl) leaderEl.textContent = clan.leader || 'Necunoscut';

        const motdEl = $('#clan-dir-modal-motd');
        if (motdEl) motdEl.textContent = clan.motd || 'Niciun MOTD publicat.';

        const roster = $('#clan-dir-modal-roster');
        if (roster) {
            roster.innerHTML = '<p class="premium-clans-dir__empty">Se încarcă membrii...</p>';
        }

        // Request clan profile (members)
        post('clanProfile', { clanId: clan.id });
    },

    showClanProfile(profile = {}) {
        if (!profile || !profile.id) return;
        if (this.selectedClanId !== profile.id) return;

        const roster = $('#clan-dir-modal-roster');
        if (!roster) return;
        roster.innerHTML = '';

        const members = profile.members || [];
        members.forEach((m) => {
            const row = document.createElement('div');
            row.className = 'premium-clans-dir__modal-member';
            row.innerHTML = `
                <strong>${this.escape(m.name || 'Necunoscut')}</strong>
                <span>${this.escape(m.rankLabel || 'Membru')}${m.online ? ' · ONLINE' : ''}${m.leader ? ' · LIDER' : ''}</span>
            `;
            roster.appendChild(row);
        });

        if (!members.length) {
            roster.innerHTML = '<p class="premium-clans-dir__empty">Niciun membru găsit.</p>';
        }
    },

    closeDirectoryModal() {
        this.selectedClanId = null;
        $('#clan-directory-modal')?.classList.remove('is-open');
    },

    showBrowseInline(payload = {}) {
        this.directory = Array.isArray(payload.clans) ? payload.clans : [];
        this.showDirectory({ clans: this.directory });
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
        } else if (action === 'warn') {
            const warnSelect = form.querySelector('#clan-warn-select');
            payload.targetCharacterId = Number(warnSelect?.value);
            payload.reason = form.querySelector('[name="reason"]')?.value || '';
            if (!payload.targetCharacterId) {
                alert('Te rog selectează un membru pentru avertisment!');
                return;
            }
        } else {
            form.querySelectorAll('input, textarea, select').forEach((field) => {
                if (!field.name || field.id === 'clan-warn-select') return;
                payload[field.name] = field.value;
            });
        }
        post('clanManage', payload);
    },
};

window.ClanPanels = ClanPanels;
