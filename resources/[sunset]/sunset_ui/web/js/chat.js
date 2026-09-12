const Chat = {
    messages: [],
    settingsOpen: false,
    playerId: 0,
    playerName: '',
    channel: 'all',
    suggestions: [],
    suggestionPick: 0,
    channelPrefixes: {
        me: '/me ',
        do: '/do ',
        faction: '/f ',
        clan: '/c ',
        dept: '/d ',
        radio: '/r ',
    },

    defaultChannels: [
        { id: 'all', label: 'LOCAL', placeholder: 'Local message — nearby players hear you' },
        { id: 'ooc', label: 'OOC', placeholder: 'Out of Character — global (( message ))' },
        { id: 'me', label: 'ME', placeholder: 'RP action (/me searches the trunk...)' },
        { id: 'do', label: 'DO', placeholder: 'RP action (/do the trunk opens)' },
    ],

    availableChannels: [],

    pageSize() {
        const maxH = ChatSettings?.settings?.maxHeight || 350;
        const font = ChatSettings?.settings?.fontSize || 13.5;
        return Math.max(4, Math.floor(maxH / (font * 1.45)));
    },

    maxMessages() {
        return Math.max(80, this.pageSize() * 8);
    },

    setSuggestions(rows) {
        this.suggestions = Array.isArray(rows) ? rows : [];
        this.suggestionPick = 0;
        this.renderSuggestions();
    },

    parseCommandInput(text) {
        const raw = String(text || '');
        if (!raw.startsWith('/')) return null;
        const body = raw.slice(1);
        const trimmed = body.trimStart();
        const space = trimmed.indexOf(' ');
        const cmdPart = (space === -1 ? trimmed : trimmed.slice(0, space)).toLowerCase();
        const argsPart = space === -1 ? '' : trimmed.slice(space + 1);
        const args = argsPart.trim() ? argsPart.trim().split(/\s+/) : [];
        return {
            cmd: cmdPart ? `/${cmdPart}` : '/',
            args,
            partial: space === -1 ? cmdPart : '',
        };
    },

    suggestionMatches(text) {
        const parsed = this.parseCommandInput(text);
        if (!parsed) return [];
        if (parsed.args.length > 0) {
            const exact = this.suggestions.find((row) => String(row.name || '').toLowerCase() === parsed.cmd);
            return exact ? [exact] : [];
        }
        const needle = parsed.partial.toLowerCase();
        if (!needle) {
            return this.suggestions.slice(0, 8);
        }
        return this.suggestions.filter((row) => {
            const name = String(row.name || '').toLowerCase();
            const cmd = name.startsWith('/') ? name.slice(1) : name;
            return cmd.startsWith(needle) || name.startsWith(`/${needle}`);
        }).slice(0, 8);
    },

    formatSuggestionParams(params, argCount) {
        const list = Array.isArray(params) ? params : [];
        if (!list.length) return '';
        return list.map((param, index) => {
            const name = String(param?.name || param || '').trim();
            if (!name) return '';
            const cls = index === argCount ? ' is-active' : (index < argCount ? ' is-filled' : '');
            return `<span class="chat-suggestion-param${cls}">[${this.escapeHtml(name)}]</span>`;
        }).filter(Boolean).join(' ');
    },

    renderSuggestions() {
        const box = $('#chat-suggestions');
        const input = $('#chat-input');
        if (!box || !input) return;

        const text = input.value;
        if (!text.startsWith('/')) {
            box.classList.add('hidden');
            box.innerHTML = '';
            return;
        }

        const parsed = this.parseCommandInput(text);
        const matches = this.suggestionMatches(text);
        const exact = this.suggestions.find((row) => String(row.name || '').toLowerCase() === parsed?.cmd);
        const picked = matches[this.suggestionPick] || exact || null;

        if (!picked && matches.length === 0) {
            box.classList.add('hidden');
            box.innerHTML = '';
            return;
        }

        box.classList.remove('hidden');
        let html = '';

        if (matches.length > 1 && (!exact || parsed?.args.length === 0)) {
            html += '<div class="chat-suggestion-list">';
            matches.forEach((row, index) => {
                const active = index === this.suggestionPick ? ' is-active' : '';
                const help = String(row.help || '').trim();
                html += `<button type="button" class="chat-suggestion-item${active}" data-index="${index}">`
                    + `<span class="chat-suggestion-cmd">${this.escapeHtml(row.name || '')}</span>`
                    + (help ? `<span class="chat-suggestion-help">${this.escapeHtml(help)}</span>` : '')
                    + '</button>';
            });
            html += '</div>';
        }

        const activeRow = exact || picked;
        if (activeRow) {
            const params = this.formatSuggestionParams(activeRow.params, parsed?.args.length || 0);
            const help = String(activeRow.help || '').trim();
            html += '<div class="chat-suggestion-active">';
            html += `<span class="chat-suggestion-cmd">${this.escapeHtml(activeRow.name || '')}</span>`;
            if (params) html += `<span class="chat-suggestion-params">${params}</span>`;
            if (help) html += `<span class="chat-suggestion-desc">${this.escapeHtml(help)}</span>`;
            html += '</div>';
        }

        box.innerHTML = html;
        box.querySelectorAll('.chat-suggestion-item').forEach((btn) => {
            btn.addEventListener('mousedown', (e) => {
                e.preventDefault();
                const index = Number(btn.dataset.index) || 0;
                const row = matches[index];
                if (!row) return;
                const parsed = this.parseCommandInput(input.value);
                const argsSuffix = parsed?.args?.length ? ` ${parsed.args.join(' ')}` : ' ';
                input.value = `${row.name}${argsSuffix}`;
                this.suggestionPick = 0;
                this.renderSuggestions();
                input.focus({ preventScroll: true });
            });
        });
    },

    applySuggestionPick() {
        const input = $('#chat-input');
        if (!input) return false;
        const parsed = this.parseCommandInput(input.value);
        const matches = this.suggestionMatches(input.value);
        const row = matches[this.suggestionPick];
        if (!row) return false;
        const argsSuffix = parsed?.args?.length ? ` ${parsed.args.join(' ')}` : ' ';
        input.value = `${row.name}${argsSuffix}`;
        this.suggestionPick = 0;
        this.renderSuggestions();
        return true;
    },

    hideSuggestions() {
        const box = $('#chat-suggestions');
        if (!box) return;
        box.classList.add('hidden');
        box.innerHTML = '';
        this.suggestionPick = 0;
    },

    add(msg) {
        this.messages.push(msg);
        const cap = this.maxMessages();
        let trimmed = false;
        while (this.messages.length > cap) {
            this.messages.shift();
            trimmed = true;
        }
        if (this.isChatOpen()) {
            if (this.hasMessageSelection()) {
                this._pendingRender = true;
                return;
            }
            if (trimmed) {
                this.render();
                return;
            }
            this.appendMessage(msg);
            return;
        }
        this.render();
    },

    onSettingsChange() {
        const cap = this.maxMessages();
        while (this.messages.length > cap) this.messages.shift();
        this.render();
    },

    formatTime(m) {
        const raw = String(m?.time ?? '').trim();
        if (!raw) return '';
        if (raw.startsWith('[')) return raw;
        return `[${raw}]`;
    },

    premiumTime(m) {
        const raw = String(m?.time ?? '').trim().replace(/^\[|\]$/g, '');
        if (!raw) return '';
        const parts = raw.split(':');
        if (parts.length >= 2) return `${parts[0]}:${parts[1]}`;
        return raw;
    },

    createBadge(label, className) {
        const badge = document.createElement('span');
        badge.className = `msg-badge ${className}`;
        badge.textContent = label;
        return badge;
    },

    createAuthor(html, className = '') {
        const author = document.createElement('span');
        author.className = `msg-author${className ? ` ${className}` : ''}`;
        author.innerHTML = html;
        return author;
    },

    createContent(html, className = '') {
        const content = document.createElement('span');
        content.className = `msg-content${className ? ` ${className}` : ''}`;
        // premiumMeta always HTML-escapes player-controlled fields. Rendering the
        // escaped string as textContent exposed entities such as &quot; and &amp;
        // instead of the characters the player typed.
        content.innerHTML = html;
        return content;
    },

    premiumMeta(type, m) {
        const esc = (v) => this.escapeHtml(v);
        const name = String(m.name || 'Player').trim();
        const id = Number(m.id) || 0;
        const msg = String(m.message ?? '');
        const faction = String(m.factionLabel || '').trim();
        const rank = String(m.rank || '').trim();

        if (type === 'command_error' || type === 'command_warn' || type === 'command_info') {
            const label = type === 'command_error' ? 'ERROR' : (type === 'command_warn' ? 'WARN' : 'SYSTEM');
            const badgeClass = type === 'command_error' ? 'badge-error' : (type === 'command_warn' ? 'badge-warn' : 'badge-system');
            return {
                badge: { label, className: badgeClass },
                author: null,
                content: { html: `${esc(name || 'SYSTEM')}: ${esc(msg)}`, className: type === 'command_error' ? 'color-error' : '' },
            };
        }

        if (type === 'r' || type === 'd' || type === 'f') {
            const channel = type === 'r' ? 'RADIO' : (type === 'd' ? 'DEPT' : 'FACTION');
            let text = msg;
            if ((type === 'r' || type === 'd') && text && !/over\.?$/i.test(text.trim())) {
                text = `${text.replace(/[.,\s]+$/, '')}, over.`;
            }
            const header = [esc(faction), esc(rank), this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
            return {
                badge: { label: channel, className: type === 'f' ? 'badge-peace' : (type === 'd' ? 'badge-dept' : 'badge-radio') },
                author: { html: `${header}:`, className: 'color-dept' },
                content: { html: esc(text), className: '' },
            };
        }

        if (type === 'announce') {
            const from = name || 'SERVER';
            const idPart = id > 0 ? ` (${id})` : '';
            return {
                badge: { label: 'ADMIN', className: 'badge-admin' },
                author: { html: `${esc(from)}${esc(idPart)}:`, className: 'color-admin' },
                content: { html: esc(msg), className: 'text-admin' },
            };
        }

        if (type === 'gov') {
            const dept = String(m.factionLabel || m.name || 'GOVERNMENT').trim();
            const rankLabel = String(m.issuerRank || m.rank || '').trim();
            const header = [dept, rankLabel].filter(Boolean).join(' · ');
            return {
                badge: { label: 'GOV', className: 'badge-gov' },
                author: { html: `${esc(header)}:`, className: 'color-gov' },
                content: { html: esc(msg), className: 'text-gov' },
            };
        }

        if (type === 'c' || type === 'clan_action') {
            const rankNum = m.clanRank ? `R${m.clanRank}` : '';
            const rankTitle = String(m.clanRankLabel || '').trim();
            const who = [rankNum, rankTitle, this.formatClanNameHtml(m)].filter(Boolean).join(' ');
            return {
                badge: { label: type === 'clan_action' ? 'CLAN' : 'CLAN', className: 'badge-mafia' },
                author: { html: `${who}:`, className: 'color-mafia' },
                content: { html: esc(msg), className: '' },
            };
        }

        if (type === 'faction_action' || type === 'faction_info') {
            const header = [esc(faction), esc(rank), this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
            return {
                badge: { label: 'FACTION', className: 'badge-peace' },
                author: { html: `${header}:`, className: 'color-peace' },
                content: { html: esc(msg), className: '' },
            };
        }

        if (type === 'sms' || m.smsNotify) {
            const from = name || 'Unknown';
            return {
                badge: { label: 'SMS', className: 'badge-sms' },
                author: { html: `From "${esc(from)}":`, className: 'color-sms' },
                content: { html: esc(msg || 'You got a new message.'), className: '' },
            };
        }

        if (type === 'me') {
            const who = (m.clanTag || m.factionId) ? this.formatPlayerNameHtml(m) : esc(this.nameWithId(name, id));
            return {
                badge: { label: 'ME', className: 'badge-rp' },
                author: { html: who, className: 'color-accent' },
                content: { html: esc(msg), className: 'text-rp' },
            };
        }

        if (type === 'do') {
            const who = (m.clanTag || m.factionId) ? this.formatPlayerNameHtml(m) : esc(this.nameWithId(name, id));
            return {
                badge: { label: 'DO', className: 'badge-rp' },
                author: { html: who, className: 'color-accent' },
                content: { html: esc(msg), className: 'text-rp' },
            };
        }

        if (type === 'ooc') {
            const who = (m.clanTag || m.factionId)
                ? this.formatPlayerNameHtml(m)
                : esc(this.nameWithId(name, id));
            return {
                badge: { label: 'OOC', className: 'badge-ooc' },
                author: { html: `${who}:`, className: 'color-ooc' },
                content: { html: `(( ${esc(msg)} ))`, className: 'text-ooc' },
            };
        }

        if (type === 'say' || type === '') {
            const who = (m.clanTag || m.factionId)
                ? this.formatPlayerNameHtml(m)
                : esc(this.nameWithId(name, id));
            return {
                badge: { label: 'LOCAL', className: 'badge-local' },
                author: { html: `${who} says:`, className: 'color-accent' },
                content: { html: esc(msg), className: '' },
            };
        }

        if (type === 'megaphone' || type === 'police_alert' || type === 'hq' || type === 'radar' || type === 'radar_alert') {
            const tag = type === 'megaphone' ? 'ADVERT' : (type === 'police_alert' ? 'ALERT' : 'SYSTEM');
            const badgeClass = type === 'megaphone' ? 'badge-ad' : 'badge-system';
            const header = type === 'megaphone'
                ? this.formatPlayerNameHtml(m, name.replace(/^\[MEGAPHONE\]\s*/i, '').trim() || name)
                : esc(name || 'SYSTEM');
            return {
                badge: { label: tag, className: badgeClass },
                author: { html: `${header}:`, className: 'color-accent' },
                content: { html: esc(msg), className: type === 'megaphone' ? 'text-ad' : '' },
            };
        }

        return {
            badge: { label: 'SYSTEM', className: 'badge-system' },
            author: name ? { html: `${esc(name)}:`, className: '' } : null,
            content: { html: esc(msg || name), className: '' },
        };
    },

    splitClanParts(m) {
        const tag = String(m.clanTag || '').trim();
        const style = String(m.clanTagStyle || 'brackets');
        const color = String(m.clanTagColor || '#00ffcc');
        const name = SunsetPlayerIdentity?.stripTaggedName?.(m.name, tag, style)
            || String(m.name || 'Player').trim();
        if (!tag) return { prefix: '', name, suffix: '', color };
        switch (style) {
            case 'prefix_dot': return { prefix: `${tag}.`, name, suffix: '', color };
            case 'suffix_brackets': return { prefix: '', name, suffix: `[${tag}]`, color };
            case 'suffix_dot': return { prefix: '', name, suffix: `.${tag}`, color };
            case 'glued_prefix': return { prefix: tag, name, suffix: '', color };
            case 'glued_suffix': return { prefix: '', name, suffix: tag, color };
            default: return { prefix: `[${tag}]`, name, suffix: '', color };
        }
    },

    formatClanNameHtml(m, options = {}) {
        const parts = this.splitClanParts(m);
        const esc = (v) => this.escapeHtml(v);
        let name = window.SunsetPlayerIdentity
            ? SunsetPlayerIdentity.stripServerId(parts.name)
            : String(parts.name || 'Player').trim().replace(/\s*\(\d+\)\s*$/, '');
        const sid = Number(m.id) || 0;
        const idPart = options.showId !== false && sid > 0 ? ` (${sid})` : '';
        return [
            parts.prefix ? `<span class="chat-clan-tag" style="color:${esc(parts.color)}">${esc(parts.prefix)}</span>` : '',
            esc(name),
            parts.suffix ? `<span class="chat-clan-tag" style="color:${esc(parts.color)}">${esc(parts.suffix)}</span>` : '',
            esc(idPart),
        ].join('');
    },

    formatClanChannelHtml(m, action = false) {
        const esc = (v) => this.escapeHtml(v);
        const time = this.formatTime(m);
        const prefix = time ? `${esc(time)} ` : '';
        const rankNum = m.clanRank ? `R${m.clanRank}` : '';
        const rankTitle = String(m.clanRankLabel || '').trim();
        const msg = esc(String(m.message ?? ''));
        const tagColor = esc(String(m.clanTagColor || '#00ffcc'));
        const nameHtml = this.formatClanNameHtml(m);

        const rankBits = [];
        if (rankNum) rankBits.push(`<span class="chat-clan-rank">${esc(rankNum)}</span>`);
        if (rankTitle) rankBits.push(`<span class="chat-clan-rank-label">${esc(rankTitle)}</span>`);

        const label = action ? 'CLAN' : 'CLAN';
        const header = [
            `<strong class="chat-clan-channel__label" style="color:${tagColor}">${label}</strong>`,
            ...rankBits,
            `<span class="chat-clan-channel__name">${nameHtml}</span>`,
        ].filter(Boolean).join(' ');

        if (action) {
            return `${prefix}<span class="chat-clan-channel chat-clan-channel--action">${header} ${msg}</span>`;
        }
        return `${prefix}<span class="chat-clan-channel"><strong class="chat-clan-channel__edge">**</strong> ${header}: ${msg} <strong class="chat-clan-channel__edge">**</strong></span>`;
    },

    escapeHtml(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    formatPlayerNameHtml(m, nameOverride) {
        const row = {
            ...m,
            name: nameOverride != null ? nameOverride : m.name,
        };
        if (window.SunsetPlayerIdentity && (row.clanTag || row.factionId)) {
            return SunsetPlayerIdentity.formatNameHtml(row);
        }
        return this.escapeHtml(this.nameWithId(row.name, row.id));
    },

    lineUsesHtml(m, type) {
        if (['c', 'clan_action', 'gov', 'say', 'ooc', 'me', ''].includes(type)) return true;
        if (['f', 'r', 'd', 'do', 'megaphone', 'faction_action', 'radar_alert'].includes(type)) {
            return Boolean(m.clanTag || m.factionId);
        }
        return false;
    },

    formatRadioCardHtml(m, type) {
        const esc = (v) => this.escapeHtml(v);
        const time = this.formatTime(m);
        const timeHtml = time ? `<span class="chat-meta-time">${esc(time)}</span>` : '';
        const channel = type === 'r' ? 'RADIO' : (type === 'd' ? 'DEPT' : 'FACTION');
        const faction = String(m.factionLabel || '').trim();
        const rank = String(m.rank || '').trim();
        let text = String(m.message ?? '');
        if (type === 'r' || type === 'd') {
            if (text && !/over\.?$/i.test(text.trim())) {
                text = `${text.replace(/[.,\s]+$/, '')}, over.`;
            }
        }
        const spyTag = m.spy
            ? `<span class="chat-spy-tag">SPY ${esc(String(m.spyChannel || 'CHAT'))}</span> `
            : '';
        const header = [spyTag, this.escapeHtml(faction), this.escapeHtml(rank), this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
        return `${timeHtml}<span class="chat-pill chat-pill--radio">${channel}</span> <span class="chat-row__who">${header}</span>: <span class="chat-row__msg">${esc(text)}</span>`;
    },

    formatSystemCardHtml(m, type) {
        const esc = (v) => this.escapeHtml(v);
        const time = this.formatTime(m);
        const timeHtml = time ? `<span class="chat-meta-time">${esc(time)}</span>` : '';
        const tag = String(m.name || 'SYSTEM').trim();
        const label = type === 'command_error' ? 'ERROR' : (type === 'command_warn' ? 'WARN' : 'SYSTEM');
        const pillClass = type === 'command_error' ? 'chat-pill--error' : (type === 'command_warn' ? 'chat-pill--warn' : 'chat-pill--system');
        return `${timeHtml}<span class="chat-pill ${pillClass}">${label}</span> <span class="chat-row__tag">${esc(tag)}</span>: <span class="chat-row__msg">${esc(String(m.message ?? ''))}</span>`;
    },

    formatGovCardHtml(m) {
        const esc = (v) => this.escapeHtml(v);
        const dept = String(m.factionLabel || m.name || 'GOVERNMENT').trim();
        const rankLabel = String(m.issuerRank || m.rank || '').trim();
        const header = [dept, rankLabel].filter(Boolean).join(' · ');
        const time = this.formatTime(m);
        const timeHtml = time ? `<span class="chat-meta-time">${esc(time)}</span>` : '';
        return `${timeHtml}<span class="chat-pill chat-pill--gov">GOV</span> <span class="chat-gov-dept">${esc(header)}</span>: <span class="chat-row__msg">${esc(String(m.message ?? ''))}</span>`;
    },

    formatClanCardHtml(m, action = false) {
        const esc = (v) => this.escapeHtml(v);
        const time = this.formatTime(m);
        const timeHtml = time ? `<span class="chat-meta-time">${esc(time)}</span>` : '';
        const rankNum = m.clanRank ? `R${m.clanRank}` : '';
        const rankTitle = String(m.clanRankLabel || '').trim();
        const msg = esc(String(m.message ?? ''));
        const tagColor = esc(String(m.clanTagColor || '#00ffcc'));
        const nameHtml = this.formatClanNameHtml(m);
        const rankBits = [];
        if (rankNum) rankBits.push(`<span class="chat-clan-rank">${esc(rankNum)}</span>`);
        if (rankTitle) rankBits.push(`<span class="chat-clan-rank-label">${esc(rankTitle)}</span>`);
        const who = [...rankBits, `<span class="chat-clan-channel__name">${nameHtml}</span>`].filter(Boolean).join(' ');
        const pill = action ? 'ACTION' : 'CLAN';
        return `${timeHtml}<span class="chat-pill chat-pill--clan" style="border-color:${tagColor};color:${tagColor}">${pill}</span> <span class="chat-row__who">${who}</span>: <span class="chat-row__msg">${msg}</span>`;
    },

    formatRadioHeaderHtml(m, text) {
        const faction = String(m.factionLabel || '').trim();
        const rank = String(m.rank || '').trim();
        const spyTag = m.spy
            ? `<span class="chat-spy-tag">[SPY ${this.escapeHtml(String(m.spyChannel || 'CHAT'))}]</span> `
            : '';
        const header = [spyTag, this.escapeHtml(faction), this.escapeHtml(rank), this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
        const time = this.formatTime(m);
        const prefix = time ? `${this.escapeHtml(time)} ` : '';
        const body = this.escapeHtml(text);
        return `${prefix}<strong class="chat-channel__edge">**</strong> ${header}: ${body} <strong class="chat-channel__edge">**</strong>`;
    },

    nameWithId(name, id) {
        const strip = window.SunsetPlayerIdentity?.stripServerId
            || ((value) => String(value || 'Player').trim().replace(/\s*\(\d+\)\s*$/, '') || 'Player');
        const label = strip(name);
        const sid = Number(id) || 0;
        if (sid <= 0) return label;
        return `${label} (${sid})`;
    },

    formatMotdBannerHtml(m, type) {
        const time = this.formatTime(m);
        const prefix = time ? `${this.escapeHtml(time)} ` : '';
        const msg = this.escapeHtml(String(m.message ?? ''));
        const command = this.escapeHtml(String(m.command || ''));
        const rule = `<span class="chat-motd-rule">${prefix}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</span>`;
        const cmdLine = command
            ? `<span class="chat-motd-cmd">${prefix}${command} to read again</span>`
            : '';

        if (type === 'clan_motd') {
            const tag = String(m.clanTag || '').trim();
            const clanName = String(m.clanName || m.name || 'CLAN').trim();
            const title = tag ? `[${tag}] ${clanName}` : clanName;
            return [
                rule,
                `<span class="chat-motd-label">${prefix}CLAN MOTD</span>`,
                `<span class="chat-motd-org">${prefix}${this.escapeHtml(title)}</span>`,
                `<span class="chat-motd-body">${prefix}${msg}</span>`,
                cmdLine,
                rule,
            ].filter(Boolean).join('<br>');
        }

        const label = String(m.factionLabel || m.name || 'FACTION').trim();
        return [
            rule,
            `<span class="chat-motd-label">${prefix}FACTION MOTD</span>`,
            `<span class="chat-motd-org">${prefix}${this.escapeHtml(label)}</span>`,
            `<span class="chat-motd-body">${prefix}${msg}</span>`,
            cmdLine,
            rule,
        ].filter(Boolean).join('<br>');
    },

    formatPassEventHtml(m) {
        const time = this.formatTime(m);
        const prefix = time ? `${this.escapeHtml(time)} ` : '';
        const title = this.escapeHtml(String(m.passTitle || 'BLAZE PASS'));
        const body = this.escapeHtml(String(m.message ?? ''));
        const icon = [
            '<svg class="chat-pass__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" aria-hidden="true">',
            '<path d="M12 2l2.4 7.4H22l-6 4.6 2.3 7-6.3-4.6L5.7 21l2.3-7-6-4.6h7.6z"/>',
            '</svg>',
        ].join('');
        return [
            `<span class="chat-pass">${icon}<span class="chat-pass__wrap">`,
            `<span class="chat-pass__title">${prefix}${title}</span>`,
            `<span class="chat-pass__body">${prefix}${body}</span>`,
            '</span></span>',
        ].join('');
    },

    formatLine(m) {
        const type = String(m.type || 'say').toLowerCase().replace(/[^a-z_]/g, '') || 'say';
        const time = this.formatTime(m);
        const id = Number(m.id) || 0;
        const name = String(m.name || 'Player').trim();
        const msg = String(m.message ?? '');
        const faction = String(m.factionLabel || '').trim();
        const rank = String(m.rank || '').trim();
        const prefix = time ? `${time} ` : '';

        if (type === 'sms' || m.smsNotify) {
            const from = name || 'Unknown';
            return `${prefix}SMS from ${from}${id > 0 ? ` (${id})` : ''}: You got a new message.`;
        }

        if (type === 'announce') {
            const from = name || 'SERVER';
            return `${prefix}Public announcement from ${from}${id > 0 ? ` (${id})` : ''}: ${msg}`;
        }

        if (type === 'hq') {
            return `${prefix}HQ: ${msg}`;
        }

        if (type === 'r' || type === 'd') {
            let text = msg;
            if (text && !/over\.?$/i.test(text.trim())) {
                text = `${text.replace(/[.,\s]+$/, '')}, over.`;
            }
            return this.formatRadioHeaderHtml(m, text);
        }

        if (type === 'gov') {
            const dept = String(m.factionLabel || m.name || 'GOVERNMENT').trim();
            const rankLabel = String(m.issuerRank || m.rank || '').trim();
            const header = [dept, rankLabel].filter(Boolean).join(' · ');
            return `${prefix}[GOVERNMENT] ${header}: ${msg}`;
        }

        if (type === 'faction_motd' || type === 'clan_motd') {
            return this.formatMotdBannerHtml(m, type);
        }

        if (type === 'blaze_pass') {
            return this.formatPassEventHtml(m);
        }

        if (type === 'f') {
            return this.formatRadioHeaderHtml(m, msg);
        }

        if (type === 'c') {
            return this.formatClanChannelHtml(m, false);
        }

        if (type === 'clan_action') {
            return this.formatClanChannelHtml(m, true);
        }

        if (type === 'faction_action') {
            const header = [faction, rank, this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
            return `${prefix}${header} ${this.escapeHtml(msg)}`.trim();
        }

        if (type === 'ooc') {
            const idPart = id > 0 ? ` (${id})` : '';
            const who = (m.clanTag || m.factionId) ? this.formatPlayerNameHtml(m) : `${this.escapeHtml(name)}${idPart}`;
            return `${prefix}(( OOC )) ${who}: ${this.escapeHtml(msg)}`;
        }

        if (type === 'say' || type === '') {
            if (m.clanTag || m.factionId) {
                return `${prefix}${this.formatPlayerNameHtml(m)} says: ${this.escapeHtml(msg)}`;
            }
            const idPart = id > 0 ? ` (${id})` : '';
            return `${prefix}${name}${idPart} says: ${msg}`;
        }

        if (type === 'me') {
            if (m.clanTag || m.factionId) {
                return `${prefix}* ${this.formatPlayerNameHtml(m)} ${this.escapeHtml(msg)}`;
            }
            const idPart = id > 0 ? ` (${id})` : '';
            return `${prefix}* ${name}${idPart} ${msg}`;
        }

        if (type === 'do') {
            if (m.clanTag || m.factionId) {
                return `${prefix}** ${this.escapeHtml(msg)} (( ${this.formatPlayerNameHtml(m)} )) **`;
            }
            const idPart = id > 0 ? ` (${id})` : '';
            return `${prefix}** ${msg} (( ${name}${idPart} )) **`;
        }

        if (type === 'megaphone') {
            const speaker = name.replace(/^\[MEGAPHONE\]\s*/i, '').trim() || name;
            if (m.clanTag || m.factionId) {
                return `${prefix}[MEGAPHONE] ${this.formatPlayerNameHtml(m, speaker)}: ${this.escapeHtml(msg)}`;
            }
            return `${prefix}[MEGAPHONE] ${speaker}: ${msg}`;
        }

        if (type === 'radar') {
            return `${prefix}HQ: ${msg}`;
        }

        if (type === 'radar_alert') {
            const header = [faction, rank, this.formatPlayerNameHtml(m)].filter(Boolean).join(' ');
            return `${prefix}${header}: ${this.escapeHtml(msg)}`;
        }

        if (type === 'police_alert') {
            const tag = name || 'POLICE';
            return `${prefix}${tag}: ${msg}`;
        }

        if (type === 'command_error' || type === 'command_warn' || type === 'command_info') {
            const tag = name || 'SYSTEM';
            return `${prefix}${tag}: ${msg}`;
        }

        if (name && msg) return `${prefix}${name}: ${msg}`;
        return `${prefix}${msg || name}`;
    },

    buildMessageElement(m, options = {}) {
        const el = document.createElement('div');
        const type = String(m.type || 'say').toLowerCase().replace(/[^a-z_]/g, '') || 'say';
        const factionId = String(m.factionId || '').toLowerCase().replace(/[^a-z0-9_]/g, '');
        const classes = ['chat-msg', `chat-msg--${type}`];
        if (factionId) classes.push(`chat-msg--faction-${factionId}`);
        if (m.spy) classes.push('chat-msg--spy');

        if (type === 'faction_motd' || type === 'clan_motd' || type === 'blaze_pass') {
            el.className = [...classes, 'chat-msg--block'].join(' ');
            const time = document.createElement('span');
            time.className = 'msg-time';
            time.textContent = this.premiumTime(m);
            el.appendChild(time);
            const block = document.createElement('div');
            block.className = 'msg-content';
            block.innerHTML = type === 'blaze_pass'
                ? this.formatPassEventHtml(m)
                : this.formatMotdBannerHtml(m, type);
            el.appendChild(block);
            if (!options.animate) el.style.animation = 'none';
            return el;
        }

        el.className = classes.join(' ');
        const time = document.createElement('span');
        time.className = 'msg-time';
        time.textContent = this.premiumTime(m);
        el.appendChild(time);

        const meta = this.premiumMeta(type, m);
        if (meta.badge) el.appendChild(this.createBadge(meta.badge.label, meta.badge.className));
        if (meta.author) el.appendChild(this.createAuthor(meta.author.html, meta.author.className));
        el.appendChild(this.createContent(meta.content.html, meta.content.className));
        if (!options.animate) el.style.animation = 'none';
        return el;
    },

    isChatOpen() {
        return Boolean($('#chat')?.classList.contains('chat-open'));
    },

    hasMessageSelection() {
        const container = $('#chat-messages');
        const sel = window.getSelection?.();
        if (!container || !sel || sel.isCollapsed || !sel.anchorNode) return false;
        const node = sel.anchorNode.nodeType === Node.TEXT_NODE
            ? sel.anchorNode.parentNode
            : sel.anchorNode;
        return container.contains(node);
    },

    render() {
        const container = $('#chat-messages');
        if (!container) return;
        container.innerHTML = '';
        const open = this.isChatOpen();
        const visible = open ? this.messages : this.messages.slice(-this.pageSize());
        visible.forEach((m) => container.appendChild(this.buildMessageElement(m, { animate: false })));
        container.scrollTop = container.scrollHeight;
    },

    appendMessage(msg) {
        const container = $('#chat-messages');
        if (!container) return;
        container.appendChild(this.buildMessageElement(msg, { animate: true }));
        container.scrollTop = container.scrollHeight;
    },

    toggleSettings(force) {
        const panel = $('#chat-settings-panel');
        const btn = $('#chat-settings-btn');
        if (!panel) return;
        const next = typeof force === 'boolean' ? force : !this.settingsOpen;
        this.settingsOpen = next;
        panel.classList.toggle('show', next);
        btn?.classList.toggle('active', next);
        if (next) {
            ChatSettings.init();
            ChatSettings.syncControls();
        }
    },

    closeChannelDropdown() {
        $('#chat-channel-dropdown')?.classList.remove('show');
        $('#chat-channel-toggle')?.classList.remove('open');
    },

    setChannel(channelId, label, placeholder) {
        const row = this.availableChannels.find((ch) => ch.id === channelId);
        this.channel = channelId || 'all';
        const labelEl = $('#chat-channel-label');
        const input = $('#chat-input');
        if (labelEl) labelEl.textContent = label || row?.label || 'LOCAL';
        if (input) input.placeholder = placeholder || row?.placeholder || 'Type a message...';
        document.querySelectorAll('#chat-channel-dropdown .dropdown-item').forEach((item) => {
            item.classList.toggle('active', item.dataset.channel === this.channel);
        });
    },

    applyChannels(channels) {
        const list = Array.isArray(channels) && channels.length ? channels : this.defaultChannels;
        this.availableChannels = list;
        const dropdown = $('#chat-channel-dropdown');
        if (!dropdown) return;

        dropdown.innerHTML = list.map((ch) => {
            const id = this.escapeHtml(ch.id || 'all');
            const label = this.escapeHtml(ch.label || id.toUpperCase());
            const placeholder = this.escapeHtml(ch.placeholder || '');
            const optClass = `opt-${id.replace(/[^a-z0-9_-]/gi, '')}`;
            return `<div class="dropdown-item ${optClass}" data-channel="${id}" data-placeholder="${placeholder}">${label}</div>`;
        }).join('');

        const active = list.some((ch) => ch.id === this.channel) ? this.channel : 'all';
        const activeRow = list.find((ch) => ch.id === active) || list[0];
        this.setChannel(activeRow.id, activeRow.label, activeRow.placeholder);
    },

    initChannelSelector() {
        if (this._channelReady) return;
        this._channelReady = true;
        const toggle = $('#chat-channel-toggle');
        const dropdown = $('#chat-channel-dropdown');
        toggle?.addEventListener('click', (e) => {
            e.stopPropagation();
            dropdown?.classList.toggle('show');
            toggle.classList.toggle('open');
        });
        dropdown?.addEventListener('click', (e) => {
            const item = e.target.closest('.dropdown-item');
            if (!item) return;
            e.stopPropagation();
            this.setChannel(item.dataset.channel, item.textContent.trim(), item.dataset.placeholder);
            this.closeChannelDropdown();
            $('#chat-input')?.focus({ preventScroll: true });
        });
        document.addEventListener('click', (e) => {
            if (!toggle?.contains(e.target) && !dropdown?.contains(e.target)) {
                this.closeChannelDropdown();
            }
        });
        this.applyChannels(this.defaultChannels);
    },

    setContext(data) {
        const row = data || {};
        this.playerId = Number(row.playerId) || 0;
        this.playerName = String(row.playerName || '').trim();
    },

    toggle(open, data) {
        const chat = $('#chat');
        const app = $('#chat-app');
        const wrap = $('#chat-input-wrap');
        const input = $('#chat-input');
        const backdrop = $('#chat-backdrop');
        if (open) {
            this.setContext(data);
            ChatSettings.init();
            this.initChannelSelector();
            if (data?.channels) {
                this.applyChannels(data.channels);
            } else if (!this.availableChannels.length) {
                this.applyChannels(this.defaultChannels);
            }
            document.body.classList.add('chat-ui-open');
            chat?.classList.add('chat-open');
            app?.classList.add('is-active');
            backdrop?.classList.remove('hidden');
            wrap?.classList.remove('hidden');
            this._pendingRender = false;
            this.render();
            requestAnimationFrame(() => {
                if (!this.isChatOpen()) return;
                input?.focus({ preventScroll: true });
            });
        } else {
            this.toggleSettings(false);
            this.closeChannelDropdown();
            this.hideSuggestions();
            backdrop?.classList.add('hidden');
            document.body.classList.remove('chat-ui-open');
            chat?.classList.remove('chat-open');
            app?.classList.remove('is-active');
            wrap?.classList.add('hidden');
            this._pendingRender = false;
            this.render();
            if (input) {
                input.value = '';
                input.blur();
            }
        }
    },

    setInput(text, options = {}) {
        const input = $('#chat-input');
        if (!input) return;
        const next = String(text ?? '');
        if (input.value !== next) input.value = next;
        this.suggestionPick = 0;
        this.renderSuggestions();
        if (options.fromHistory) {
            input.focus({ preventScroll: true });
            const end = input.value.length;
            input.setSelectionRange(end, end);
        }
    },

    send() {
        const input = $('#chat-input');
        const raw = input.value.trim();
        if (!raw) { post('chatClose'); return; }
        let msg = raw;
        if (!msg.startsWith('/')) {
            const prefix = this.channelPrefixes[this.channel];
            if (prefix) msg = `${prefix}${msg}`;
        }
        post('chatSend', { message: msg, channel: this.channel || 'all' });
        input.value = '';
        this.hideSuggestions();
    },
};

$('#chat-backdrop')?.addEventListener('click', () => {
    if (Chat.settingsOpen) {
        Chat.toggleSettings(false);
    }
    $('#chat-input')?.focus({ preventScroll: true });
});

$('#chat-messages')?.addEventListener('mouseup', () => {
    if (!Chat._pendingRender) return;
    Chat._pendingRender = false;
    Chat.render();
});

$('#chat-settings-btn')?.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    Chat.toggleSettings();
});

$('#chat-settings-close')?.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    Chat.toggleSettings(false);
});

$('#chat-input')?.addEventListener('input', () => {
    Chat.suggestionPick = 0;
    Chat.renderSuggestions();
});

$('#chat-input')?.addEventListener('keydown', (e) => {
    const input = $('#chat-input');
    const hasSuggestions = !$('#chat-suggestions')?.classList.contains('hidden');
    const matches = input ? Chat.suggestionMatches(input.value) : [];

    if (e.key === 'Tab' && input?.value.startsWith('/') && matches.length > 0) {
        e.preventDefault();
        Chat.applySuggestionPick();
        return;
    }

    const parsed = input ? Chat.parseCommandInput(input.value) : null;
    const typingArgs = (parsed?.args?.length || 0) > 0;
    if (hasSuggestions && matches.length > 1 && !typingArgs) {
        if (e.key === 'ArrowUp') {
            e.preventDefault();
            Chat.suggestionPick = Math.max(0, Chat.suggestionPick - 1);
            Chat.renderSuggestions();
            return;
        }
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            Chat.suggestionPick = Math.min(matches.length - 1, Chat.suggestionPick + 1);
            Chat.renderSuggestions();
            return;
        }
    }

    if (e.key === 'Enter') { e.preventDefault(); Chat.send(); return; }
    if (e.key === 'ArrowUp') {
        e.preventDefault();
        post('chatHistory', { direction: 'up' });
        return;
    }
    if (e.key === 'ArrowDown') {
        e.preventDefault();
        post('chatHistory', { direction: 'down' });
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const chat = $('#chat');
    if (!chat || !chat.classList.contains('chat-open')) return;
    e.preventDefault();
    e.stopPropagation();
    if (Chat.settingsOpen) {
        Chat.toggleSettings(false);
        $('#chat-input')?.focus();
        return;
    }
    post('chatClose');
}, true);

window.Chat = Chat;
