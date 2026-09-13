/* ═══════════════════════════════════════════════════════════════
   ADMIN HELPDESK + BLAZE SHIELD WIDGET (staff console)
   Standalone module: own message listener (no app.js switch edits),
   same design system (glass/teal/phosphor). Data arrives via
   sunset_ui:Send('helpdeskShow'|'helpdeskRefresh'|...) payloads.
   Actions post back to sunset_admin/client/helpdesk.lua.
   ═══════════════════════════════════════════════════════════════ */

const $hd = (sel, root) => (root || document).querySelector(sel);

const ShieldWidget = {
    el: null,
    body: null,
    modeEl: null,

    ensure() {
        if (this.el) return this.el;
        const el = document.createElement('div');
        el.id = 'shield-widget';
        el.className = 'shield-widget hidden';
        el.innerHTML = `
            <div class="shield-widget__head">
                <i class="ph-bold ph-shield-check"></i>
                <span class="shield-widget__title">Blaze Shield</span>
                <span class="shield-widget__mode" id="shield-mode">log_only</span>
            </div>
            <div class="shield-widget__body" id="shield-body"></div>
        `;
        document.body.appendChild(el);
        this.el = el;
        this.body = el.querySelector('#shield-body');
        this.modeEl = el.querySelector('#shield-mode');
        return el;
    },

    show(data) {
        this.ensure();
        this.el.classList.remove('hidden');
        const mode = String(data.mode || 'log_only');
        this.modeEl.textContent = mode;
        this.modeEl.classList.toggle('enforce', mode === 'enforce');

        const feed = Array.isArray(data.feed) ? data.feed : [];
        if (!feed.length) {
            this.body.innerHTML = `<div class="shield-widget__empty">
                <i class="ph-bold ph-shield-check"></i> All quiet — ${Number(data.watching || 0)} watched, 0 suspect+
            </div>`;
            return;
        }
        this.body.innerHTML = '';
        feed.slice(0, 6).forEach((row) => {
            const div = document.createElement('div');
            div.className = `shield-widget__row ${row.band}`;
            div.innerHTML = `
                <span class="shield-widget__band ${row.band}">${row.band === 'critical' ? 'CRIT' : 'SUSP'}</span>
                <span class="shield-widget__name">#${Number(row.src)} ${this.esc(row.name)}</span>
                <span class="shield-widget__heat">${Number(row.heat).toFixed(1)}</span>
            `;
            const sub = document.createElement('div');
            sub.className = 'shield-widget__det';
            sub.textContent = `${row.top} · ${Number(row.ticks)} tick(s)`;
            div.appendChild(sub);
            this.body.appendChild(div);
        });
    },

    hide() {
        if (this.el) this.el.classList.add('hidden');
    },

    esc(s) {
        return String(s ?? '').replace(/[&<>"']/g, (c) => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));
    },
};

const Helpdesk = {
    data: null,
    selectedSrc: null,
    open: false,

    esc(s) { return ShieldWidget.esc(s); },

    render(data) {
        this.data = data || this.data;
        if (!this.data) return;
        this.renderHead();
        this.renderReports();
        this.renderRoster();
        this.renderDetail();
        this.renderDetStats();
    },

    renderHead() {
        const d = this.data;
        const shield = d.shield || {};
        $hd('#hd-time').textContent = d.time || '';
        $hd('#hd-level').textContent = `LVL ${Number(d.myLevel || 1)} · ${this.esc(d.myName || '')}`;
        $hd('#hd-players').textContent = `${Number(d.playerCount || 0)}/${Number(d.maxPlayers || 64)}`;
        const critChip = $hd('#hd-critical');
        critChip.textContent = `${Number(shield.critical || 0)} critical`;
        critChip.classList.toggle('hidden', !shield.critical);
        const suspChip = $hd('#hd-suspect');
        suspChip.textContent = `${Number(shield.suspect || 0)} suspect`;
        suspChip.classList.toggle('hidden', !shield.suspect);
        $hd('#hd-mode').textContent = String(shield.mode || 'log_only').toUpperCase();
        $hd('#hd-mode').classList.toggle('danger', shield.mode === 'enforce');
    },

    renderReports() {
        const wrap = $hd('#hd-reports');
        const badge = $hd('#hd-reports-count');
        const rows = Array.isArray(this.data.reports) ? this.data.reports : [];
        badge.textContent = String(rows.length);
        if (!rows.length) {
            wrap.innerHTML = '<div class="hd-empty"><i class="ph-bold ph-check-circle"></i>No open reports or questions.</div>';
            return;
        }
        wrap.innerHTML = '';
        rows.slice(0, 30).forEach((r) => {
            const el = document.createElement('div');
            el.className = `hd-report${r.status === 'claimed' ? ' claimed' : ''}`;
            const age = Math.max(0, Math.floor((Date.now() / 1000 - Number(r.createdAt || 0)) / 60));
            el.innerHTML = `
                <div class="hd-report__top">
                    <span class="hd-report__id">#${Number(r.id)}</span>
                    <span class="hd-report__kind">${r.isHelpme ? 'QUESTION' : 'REPORT'}</span>
                    <span class="hd-report__by">${this.esc(r.reporterName || '?')} (#${Number(r.reporter || 0)})${r.reporterOnline === false ? ' · offline' : ''} · ${age}m</span>
                </div>
                <div class="hd-report__reason">${r.targetName ? `vs ${this.esc(r.targetName)} (#${Number(r.target)}) — ` : ''}${this.esc(r.reason || '')}</div>
                <div class="hd-report__actions">
                    <button class="hd-btn tiny primary" data-hd-act="claimReport" data-hd-target="${Number(r.id)}" ${r.status === 'claimed' ? 'disabled' : ''}><i class="ph-bold ph-hand-pointing"></i> Claim</button>
                    <button class="hd-btn tiny" data-hd-act="closeReport" data-hd-target="${Number(r.id)}"><i class="ph-bold ph-x"></i> Close</button>
                    ${r.reporterOnline !== false ? `<button class="hd-btn tiny" data-hd-act="tp" data-hd-target="${Number(r.reporter)}"><i class="ph-bold ph-map-pin"></i> TP</button>` : ''}
                </div>
            `;
            wrap.appendChild(el);
        });
    },

    renderRoster() {
        const wrap = $hd('#hd-roster');
        $hd('#hd-roster-count').textContent = String((this.data.roster || []).length);
        const rows = Array.isArray(this.data.roster) ? this.data.roster : [];
        wrap.innerHTML = '';
        rows.forEach((p) => {
            const heat = p.heat || null;
            const band = heat ? heat.band : 'clean';
            const el = document.createElement('div');
            el.className = `hd-roster-row${band !== 'clean' ? ` heat-${band}` : ''}${this.selectedSrc === p.src ? ' selected' : ''}`;
            el.dataset.hdSrc = String(p.src);

            const flags = [];
            if (Number(p.adminLevel) > 0) flags.push(`<span class="hd-staff-badge">L${Number(p.adminLevel)}</span>`);
            if (p.downed) flags.push('<span class="flag red">DOWNED</span>');
            if (p.jailed) flags.push('<span class="flag">JAILED</span>');
            if (p.frozen) flags.push('<span class="flag teal">FROZEN</span>');
            if (p.inVehicle) flags.push('<span class="flag teal">🚗</span>');

            el.innerHTML = `
                <div class="hd-roster__id">${Number(p.src)}</div>
                <div class="hd-roster__main">
                    <div class="hd-roster__name">${this.esc(p.name)} ${flags.join(' ')}</div>
                    <div class="hd-roster__sub">
                        <span>${Number(p.ping)}ms</span>
                        <span>HP ${Number(p.health)}</span>
                        ${p.money ? `<span>$${Number(p.money.cash).toLocaleString('en-US')} · $${Number(p.money.bank).toLocaleString('en-US')}</span>` : ''}
                    </div>
                </div>
                <div class="hd-roster__heat">
                    <div class="hd-heat-num ${band !== 'clean' ? band : ''}">${heat ? Number(heat.heat).toFixed(1) : '·'}</div>
                    <div class="hd-heat-band">${band !== 'clean' ? band : 'clean'}</div>
                </div>
            `;
            el.addEventListener('click', () => {
                this.selectedSrc = this.selectedSrc === p.src ? null : p.src;
                this.renderRoster();
                this.renderDetail();
            });
            wrap.appendChild(el);
        });
        if (!rows.length) {
            wrap.innerHTML = '<div class="hd-empty"><i class="ph-bold ph-users"></i>No players online.</div>';
        }
    },

    findSelected() {
        if (!this.selectedSrc) return null;
        return (this.data.roster || []).find((p) => p.src === this.selectedSrc) || null;
    },

    renderDetail() {
        const wrap = $hd('#hd-detail');
        const p = this.findSelected();
        if (!p) {
            wrap.innerHTML = '<div class="hd-empty"><i class="ph-bold ph-cursor-click"></i>Select a player from the roster to see details, heat evidence and quick actions.</div>';
            return;
        }
        const myLevel = Number(this.data.myLevel || 1);
        const heat = p.heat || { heat: 0, band: 'clean', ticks: 0 };
        const can = (minLevel) => myLevel >= minLevel;

        let html = `
            <div class="hd-detail__hero">
                <div class="hd-detail__name">#${Number(p.src)} ${this.esc(p.name)}</div>
                <div class="hd-detail__stats">
                    <span class="k">Heat</span><span class="v" style="color:${heat.band === 'critical' ? '#ff6b6b' : heat.band === 'suspect' ? '#ffb74d' : heat.band === 'watch' ? '#ffd54f' : 'inherit'}">${Number(heat.heat).toFixed(1)} (${heat.band.toUpperCase()})</span>
                    <span class="k">Active ticks</span><span class="v">${Number(heat.ticks || 0)}</span>
                    <span class="k">Ping</span><span class="v">${Number(p.ping)} ms</span>
                    <span class="k">Health</span><span class="v">${Number(p.health)}${p.downed ? ' · DOWNED' : ''}</span>
                    <span class="k">Cash / Bank</span><span class="v">${p.money ? `$${Number(p.money.cash).toLocaleString('en-US')} / $${Number(p.money.bank).toLocaleString('en-US')}` : '—'}</span>
                    <span class="k">Char ID</span><span class="v">${p.charId ? Number(p.charId) : '—'}</span>
                    ${p.coords ? `<span class="k">Position</span><span class="v">${p.coords.x.toFixed(0)}, ${p.coords.y.toFixed(0)}, ${p.coords.z.toFixed(0)}</span>` : ''}
                </div>
            </div>
            <div class="hd-actions">
                <button class="hd-btn" data-hd-act="tp" ${can(2) ? '' : 'disabled'}><i class="ph-bold ph-map-pin"></i> Teleport</button>
                <button class="hd-btn" data-hd-act="bring" ${can(2) ? '' : 'disabled'}><i class="ph-bold ph-arrows-in-line-vertical"></i> Bring</button>
                <button class="hd-btn" data-hd-act="heal" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-heartbeat"></i> Heal</button>
                <button class="hd-btn" data-hd-act="revive" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-first-aid-kit"></i> Revive</button>
                <button class="hd-btn" data-hd-act="arespawn" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-arrows-clockwise"></i> Respawn</button>
                <button class="hd-btn ${p.frozen ? 'warn' : ''}" data-hd-act="${p.frozen ? 'unfreeze' : 'freeze'}" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-snowflake"></i> ${p.frozen ? 'Unfreeze' : 'Freeze'}</button>
                <button class="hd-btn" data-hd-act="pullout" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-car-profile"></i> Pull out</button>
                <button class="hd-btn" data-hd-act="slap" ${can(2) ? '' : 'disabled'}><i class="ph-bold ph-hand"></i> Slap</button>
                <button class="hd-btn" data-hd-act="spectate" ${can(2) ? '' : 'disabled'}><i class="ph-bold ph-eye"></i> Spectate</button>
                <button class="hd-btn warn" data-hd-act="warn" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-warning"></i> Warn</button>
                <button class="hd-btn danger" data-hd-act="kick" ${can(2) ? '' : 'disabled'}><i class="ph-bold ph-sign-out"></i> Kick</button>
                <button class="hd-btn" data-hd-act="history" ${can(1) ? '' : 'disabled'}><i class="ph-bold ph-clock-counter-clockwise"></i> History</button>
                <button class="hd-btn" data-hd-act="dismissHeat" ${can(1) ? '' : 'disabled'} ${heat.ticks ? '' : 'disabled'}><i class="ph-bold ph-shield-slash"></i> Dismiss heat</button>
                <button class="hd-btn" data-hd-act="acheat" ${can(1) ? '' : 'disabled'} ${heat.ticks ? '' : 'disabled'}><i class="ph-bold ph-magnifying-glass"></i> Evidence</button>
            </div>
            <div class="hd-section-title">Heat evidence (live ticks)</div>
            <div id="hd-ticks"><div class="hd-empty"><i class="ph-bold ph-shield-check"></i>No active ticks for this player.</div></div>
            <div class="hd-section-title">Sanction history</div>
            <div id="hd-history"><div class="hd-empty"><i class="ph-bold ph-clock-counter-clockwise"></i>Click "History" to load.</div></div>
        `;
        wrap.innerHTML = html;

        // load live ticks for the selected player
        this.loadTicks(p.src);
    },

    loadTicks(src) {
        // evidence arrives async via helpdeskAction→Lua; ask Lua to fetch it
        post('helpdeskAction', { action: 'evidence', targetId: src });
    },

    renderTicks(ticks) {
        const wrap = $hd('#hd-ticks');
        if (!wrap) return;
        if (!Array.isArray(ticks) || !ticks.length) {
            wrap.innerHTML = '<div class="hd-empty"><i class="ph-bold ph-shield-check"></i>No active ticks for this player.</div>';
            return;
        }
        wrap.innerHTML = '';
        ticks.forEach((t) => {
            const ctx = t.context || {};
            const el = document.createElement('div');
            el.className = `hd-tick${Number(t.severity) >= 3 ? ' sev3' : ''}`;
            el.innerHTML = `
                <div class="hd-tick__top"><span class="hd-tick__det">${this.esc(t.detector)}</span><span>sev ${Number(t.severity)}</span><span style="margin-left:auto;opacity:0.6">${Number(t.ageSec || 0)}s ago</span></div>
                <div class="hd-tick__measured">${this.esc(t.measured)}</div>
                <div class="hd-tick__ctx">war=${this.esc(ctx.in_war)} bucket=${this.esc(ctx.bucket)} session=${this.esc(ctx.session || '-')} duty=${this.esc(ctx.on_duty)} downed=${this.esc(ctx.downed)} admin=${this.esc(ctx.admin_action || '-')} ping=${this.esc(ctx.ping)}</div>
            `;
            wrap.appendChild(el);
        });
    },

    renderDetStats() {
        const wrap = $hd('#hd-detstats');
        if (!wrap) return;
        const shield = this.data.shield || {};
        wrap.innerHTML = `
            <span class="hd-detstat">mode: ${this.esc(shield.mode || 'log_only')}</span>
            <span class="hd-detstat">watching: ${Number(shield.watching || 0)}</span>
            <span class="hd-detstat${shield.suspect ? ' hot' : ''}">suspect: ${Number(shield.suspect || 0)}</span>
            <span class="hd-detstat${shield.critical ? ' hot' : ''}">critical: ${Number(shield.critical || 0)}</span>
            <span class="hd-detstat">auto-ban: ${shield.autoBan ? 'ON (!)' : 'off'}</span>
        `;
    },

    renderHistory(rows) {
        const wrap = $hd('#hd-history');
        if (!wrap) return;
        if (!Array.isArray(rows) || !rows.length) {
            wrap.innerHTML = '<div class="hd-empty"><i class="ph-bold ph-shield-check"></i>Clean record — no sanctions.</div>';
            return;
        }
        wrap.innerHTML = '';
        rows.slice(0, 12).forEach((r) => {
            const el = document.createElement('div');
            el.className = 'hd-history-row';
            el.innerHTML = `
                <span class="act ${this.esc(String(r.action || '').toLowerCase())}">${this.esc(r.action)}</span>
                <span class="who">${this.esc(r.admin_name || '?')}: ${this.esc(r.reason || '')}${r.duration_min ? ` (${Number(r.duration_min)}m)` : ''}</span>
                <span class="when">${this.esc(String(r.created_at || '').slice(0, 16))}</span>
            `;
            wrap.appendChild(el);
        });
    },

    prompt(action, targetId, title) {
        const backdrop = $hd('#hd-prompt-backdrop');
        backdrop.classList.remove('hidden');
        $hd('#hd-prompt-title').textContent = title;
        const input = $hd('#hd-prompt-input');
        input.value = '';
        input.focus();
        $hd('#hd-prompt-ok').onclick = () => {
            const reason = String(input.value || '').trim();
            backdrop.classList.add('hidden');
            post('helpdeskAction', { action, targetId, reason });
        };
        $hd('#hd-prompt-cancel').onclick = () => backdrop.classList.add('hidden');
        input.onkeydown = (e) => {
            if (e.key === 'Enter') $hd('#hd-prompt-ok').click();
            if (e.key === 'Escape') { e.stopPropagation(); backdrop.classList.add('hidden'); }
        };
    },

    show(data) {
        this.open = true;
        this.data = data;
        const el = $hd('#helpdesk');
        el.classList.remove('hidden');
        this.render(data);
    },

    hide() {
        this.open = false;
        this.selectedSrc = null;
        $hd('#helpdesk')?.classList.add('hidden');
    },
};

// ── Bootstrap: static shell injected once ──
document.addEventListener('DOMContentLoaded', () => {
    const shell = document.createElement('div');
    shell.id = 'helpdesk';
    shell.className = 'helpdesk-panel hidden';
    shell.setAttribute('aria-hidden', 'true');
    shell.innerHTML = `
        <div class="helpdesk-panel__shell">
            <div class="helpdesk-panel__head">
                <div class="helpdesk-panel__logo"><i class="ph-bold ph-headset"></i></div>
                <div class="helpdesk-panel__title">Staff <span>Console</span></div>
                <div class="helpdesk-panel__meta">
                    <span class="hd-chip"><i class="ph-bold ph-user-circle"></i><span id="hd-level">—</span></span>
                    <span class="hd-chip"><i class="ph-bold ph-users-three"></i><span id="hd-players">—</span></span>
                    <span class="hd-chip danger hidden" id="hd-critical">0 critical</span>
                    <span class="hd-chip warn hidden" id="hd-suspect">0 suspect</span>
                    <span class="hd-chip" id="hd-mode">LOG_ONLY</span>
                    <span class="hd-chip"><i class="ph-bold ph-clock"></i><span id="hd-time">—</span></span>
                </div>
                <button class="helpdesk-panel__close" id="hd-close" title="Close (ESC)"><i class="ph-bold ph-x"></i></button>
            </div>
            <div class="helpdesk-panel__body">
                <div class="hd-col">
                    <div class="hd-col__head"><i class="ph-bold ph-megaphone-simple"></i> Reports & Questions <span class="count" id="hd-reports-count">0</span></div>
                    <div class="hd-col__scroll" id="hd-reports"></div>
                </div>
                <div class="hd-col">
                    <div class="hd-col__head"><i class="ph-bold ph-users-four"></i> Players <span class="count" id="hd-roster-count">0</span></div>
                    <div class="hd-col__scroll" id="hd-roster"></div>
                </div>
                <div class="hd-col">
                    <div class="hd-col__head"><i class="ph-bold ph-user-focus"></i> Detail & Actions</div>
                    <div class="hd-col__scroll" id="hd-detail">
                        <div class="hd-empty"><i class="ph-bold ph-cursor-click"></i>Select a player from the roster.</div>
                    </div>
                </div>
            </div>
            <div class="hd-detstats" id="hd-detstats" style="padding:8px 16px;border-top:1px solid var(--glass-border);"></div>
            <div class="hd-prompt-backdrop hidden" id="hd-prompt-backdrop">
                <div class="hd-prompt">
                    <div class="hd-prompt__title" id="hd-prompt-title">Reason</div>
                    <input id="hd-prompt-input" type="text" maxlength="200" placeholder="Reason (required, min 3 chars)">
                    <div class="hd-prompt__actions">
                        <button class="hd-btn" id="hd-prompt-cancel">Cancel</button>
                        <button class="hd-btn primary" id="hd-prompt-ok">Confirm</button>
                    </div>
                </div>
            </div>
        </div>
    `;
    document.body.appendChild(shell);

    // event delegation for all action buttons
    shell.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-hd-act]');
        if (!btn || btn.disabled) return;
        const action = btn.dataset.hdAct;
        const targetId = Number(btn.dataset.hdTarget || Helpdesk.selectedSrc || 0);
        if (action === 'warn' || action === 'kick') {
            Helpdesk.prompt(action, targetId, action === 'warn' ? `Warn #${targetId}` : `Kick #${targetId}`);
            return;
        }
        if (action === 'acheat') {
            // show evidence inline (already loaded) — scroll to ticks
            $hd('#hd-ticks')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            return;
        }
        if (!targetId && action !== 'spectateOff') return;
        post('helpdeskAction', { action, targetId });
    });

    $hd('#hd-close')?.addEventListener('click', () => post('helpdeskClose'));
});

// ESC closes the panel (universal handler in app.js also posts helpdeskClose)
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const panel = $hd('#helpdesk');
    if (!panel || panel.classList.contains('hidden')) return;
    const promptBox = $hd('#hd-prompt-backdrop');
    if (promptBox && !promptBox.classList.contains('hidden')) return; // prompt owns ESC
    e.preventDefault();
    post('helpdeskClose');
}, true);

// ── NUI messages (standalone listener; app.js untouched) ──
window.addEventListener('message', (event) => {
    const data = event?.data || {};
    switch (data.action) {
        case 'helpdeskShow': Helpdesk.show(data.data || {}); break;
        case 'helpdeskRefresh': if (Helpdesk.open) Helpdesk.render(data.data || {}); break;
        case 'helpdeskHide': Helpdesk.hide(); break;
        case 'helpdeskHistory': Helpdesk.renderHistory((data.data || {}).rows || []); break;
        case 'helpdeskTicks': Helpdesk.renderTicks((data.data || {}).ticks || []); break;
        case 'shieldHud':
            if (data.data && data.data.enabled !== false) ShieldWidget.show(data.data);
            break;
        case 'shieldHudHide': ShieldWidget.hide(); break;
        default: break;
    }
});

window.Helpdesk = Helpdesk;
window.ShieldWidget = ShieldWidget;
