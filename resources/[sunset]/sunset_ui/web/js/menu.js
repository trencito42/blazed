const Menu = {
    activeTab: 'player',

    init() {
        if (this._ready) return;
        this._ready = true;

        $('#menu-close-btn')?.addEventListener('click', () => this.close());
        $('#menu-exit-btn')?.addEventListener('click', () => this.close());

        $$('.menu-tab').forEach((tab) => {
            tab.addEventListener('click', () => this.setTab(tab.dataset.tab));
        });

        $$('.menu-action').forEach((btn) => {
            btn.addEventListener('click', () => {
                if (btn.dataset.action === 'statistics') {
                    this.setTab('statistics');
                    return;
                }
                post('menuAction', { action: btn.dataset.action });
            });
        });

        if (window.ChatSettings) ChatSettings.init();
    },

    setTab(tab) {
        if (!tab) return;
        this.activeTab = tab;
        $$('.menu-tab').forEach((el) => el.classList.toggle('is-active', el.dataset.tab === tab));
        $$('.menu-panel-view').forEach((el) => el.classList.toggle('is-active', el.dataset.panel === tab));
        if (tab === 'settings' && window.ChatSettings) {
            ChatSettings.init();
            ChatSettings.syncControls();
        }
        const activePanel = $(`.menu-panel-view[data-panel="${tab}"]`);
        const profile = $('.menu-profile');
        [activePanel, profile].forEach((panel) => {
            if (!panel) return;
            panel.classList.remove('glitch-effect');
            void panel.offsetWidth;
            panel.classList.add('glitch-effect');
        });
    },

    formatXp(n) {
        return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    },

    escape(value) {
        return String(value ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        })[ch]);
    },

    factionTips(jobId) {
        const common = [
            '<li>Civilian jobs are hired at the Job Center.</li>',
            '<li>Factions (LSPD, EMS, Taxi, gangs) join at HQ — press <strong>[E]</strong> for duty.</li>',
        ];
        const perJob = {
            police: [
                '<li>Fleet garage at MRPD — spawn patrol car on duty.</li>',
                '<li><strong>/fine</strong> <strong>/cuff</strong> <strong>/uncuff</strong> — Sergeant+ can uncuff.</li>',
                '<li>LSPD Armory crafting inside MRPD (rank 1+).</li>',
            ],
            medic: [
                '<li>Ambulance bay at Pillbox — spawn on duty.</li>',
                '<li><strong>/heal</strong> and <strong>/revive</strong> (Paramedic+).</li>',
                '<li>EMS Supply Room crafting at hospital.</li>',
            ],
            taxi: [
                '<li>Depot marker spawns your cab when on duty.</li>',
                '<li>Passengers use Downtown Cab phone app.</li>',
                '<li><strong>/fare [id] [amount]</strong> for manual street fares.</li>',
            ],
            mechanic: [
                '<li>Drive into HQ in a vehicle for $250 repair.</li>',
                '<li><strong>/repairveh [id]</strong> on duty for player repairs.</li>',
                '<li>Parts bench at shop — craft repair kits.</li>',
            ],
            lsfd: [
                '<li>Fire truck garage at the station.</li>',
                '<li><strong>/heal</strong> all ranks; <strong>/revive</strong> Engineer+.</li>',
                '<li>Field rescue — stabilize before EMS arrives.</li>',
            ],
            sunset_cartel: [
                '<li>Hidden HQ blip — members only.</li>',
                '<li>Cartel Lab crafting (Soldier+).</li>',
                '<li><strong>/sellpouch</strong> at HQ stash marker.</li>',
            ],
            night_syndicate: [
                '<li>Hidden HQ — recruit via <strong>/finvite</strong>.</li>',
                '<li>Workshop crafting — shiv, ammo (ranked).</li>',
                '<li><strong>/fence</strong> contraband at HQ stash.</li>',
            ],
            trucker: [
                '<li>Haul cargo routes across San Andreas.</li>',
                '<li>Keep your civilian job while in a faction.</li>',
            ],
            fisherman: [
                '<li>Catch and sell fish for extra income.</li>',
                '<li>Works alongside any faction membership.</li>',
            ],
            unemployed: [
                '<li>Visit the Job Center for trucker or fisherman work.</li>',
                '<li>Or join a faction at HQ markers on the map.</li>',
            ],
        };
        const tips = [...common, ...(perJob[jobId] || ['<li>Use <strong>/faction</strong> to see your commands.</li>'])];
        return tips.join('');
    },

    vehicleImage(model) {
        const m = (model || 'sultan').toLowerCase().replace(/[^a-z0-9_]/g, '');
        return `https://docs.fivem.net/vehicles/${m}.webp`;
    },

    renderVehicles(data) {
        const grid = $('#menu-vehicle-grid');
        if (!grid) return;
        const vehicles = data.vehicles || [];

        if (!vehicles.length) {
            grid.innerHTML = `<div class="menu-mgmt-empty">
                <p>No vehicles yet.</p>
                <span>Starter cars and purchases get a unique plate automatically.</span>
            </div>`;
            return;
        }

        grid.innerHTML = vehicles.map((v) => {
            const stored = v.stored === true || v.stored === 1 || v.stored === '1' || Number(v.stored) === 1;
            const inWorld = v.inWorld === true;
            const status = stored ? 'In garage' : (inWorld ? 'Out' : 'Missing');
            const statusClass = stored ? 'stored' : (inWorld ? 'out' : 'missing');
            const fuelValue = Number(v.fuel);
            const engineValue = Number(v.engine);
            const bodyValue = Number(v.body);
            const fuel = Math.max(0, Math.min(100, Math.round(Number.isFinite(fuelValue) ? fuelValue : 100)));
            const engine = Math.max(0, Math.min(100, Math.round((Number.isFinite(engineValue) ? engineValue : 1000) / 10)));
            const body = Math.max(0, Math.min(100, Math.round((Number.isFinite(bodyValue) ? bodyValue : 1000) / 10)));
            const model = this.escape((v.model || 'vehicle').toUpperCase());
            const plate = this.escape(v.plate || '—');
            const garage = this.escape(v.garage || 'legion');

            let actions = '';
            if (stored) {
                actions = `<button type="button" class="menu-vcard__btn menu-vcard__btn--primary" data-v-action="spawn" data-v-id="${Number(v.id) || 0}">Spawn</button>`;
            } else if (inWorld) {
                actions = `
                    <button type="button" class="menu-vcard__btn" data-v-action="gps" data-v-plate="${plate}" data-v-id="${Number(v.id) || 0}">GPS</button>
                    <button type="button" class="menu-vcard__btn menu-vcard__btn--primary" data-v-action="store" data-v-id="${Number(v.id) || 0}">Store</button>`;
            } else {
                actions = `
                    <button type="button" class="menu-vcard__btn" data-v-action="gps" data-v-plate="${plate}" data-v-id="${Number(v.id) || 0}">GPS</button>
                    <button type="button" class="menu-vcard__btn menu-vcard__btn--primary" data-v-action="spawn" data-v-id="${Number(v.id) || 0}">Respawn</button>
                    <button type="button" class="menu-vcard__btn" data-v-action="store" data-v-id="${Number(v.id) || 0}">Store</button>`;
            }

            return `<article class="menu-vcard">
                <div class="menu-vcard__img-wrap">
                    <img class="menu-vcard__img" src="${this.vehicleImage(v.model)}" alt="${model}" loading="lazy"
                        onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">
                    <div class="menu-vcard__img-fallback" style="display:none">${model.charAt(0)}</div>
                </div>
                <div class="menu-vcard__body">
                    <div class="menu-vcard__top">
                        <strong>${model}</strong>
                        <span class="menu-vcard__status menu-vcard__status--${statusClass}">${status}</span>
                    </div>
                    <div class="menu-vcard__plate">${plate}</div>
                    <div class="menu-vcard__meta">${garage}</div>
                    <div class="menu-vcard__diag">
                        <span>FUEL <i><b style="width:${fuel}%"></b></i><em>${fuel}%</em></span>
                        <span>ENGINE <i><b style="width:${engine}%"></b></i><em>${engine}%</em></span>
                        <span>BODY <i><b style="width:${body}%"></b></i><em>${body}%</em></span>
                    </div>
                    <div class="menu-vcard__actions">${actions}</div>
                </div>
            </article>`;
        }).join('');

        grid.querySelectorAll('[data-v-action]').forEach((btn) => {
            btn.addEventListener('click', () => {
                post('menuVehicleAction', {
                    action: btn.dataset.vAction,
                    vehicleId: btn.dataset.vId,
                    plate: btn.dataset.vPlate,
                });
            });
        });
    },

    renderJob(data) {
        const card = $('#menu-job-card');
        const side = $('#menu-job-side');
        if (!card || !side) return;

        const unemployed = !data.jobId || data.jobId === 'unemployed';
        const hasFaction = !!data.factionId;
        const dutyBadge = data.hasDuty
            ? (data.onDuty ? '<span class="menu-job-badge menu-job-badge--on">ON DUTY</span>' : '<span class="menu-job-badge menu-job-badge--off">OFF DUTY</span>')
            : '';

        const jobLine = this.escape(hasFaction
            ? (data.factionLabel || data.factionId)
            : (unemployed ? 'Unemployed' : (data.job || 'Unemployed')));

        const rankLine = this.escape(hasFaction
            ? (data.factionGradeLabel || '—')
            : (data.jobGradeLabel || '—'));

        const salaryLine = hasFaction ? (data.factionSalary || 0) : (data.jobSalary || 0);

        const civilianSub = hasFaction
            ? `<p class="menu-job-sub">Civilian job: ${this.escape(data.job || 'Unemployed')}</p>`
            : '';

        card.innerHTML = `
            <div class="menu-job-card__header">
                <div>
                    <div class="menu-job-card__label">${hasFaction ? 'FACTION' : 'CIVILIAN JOB'}</div>
                    <h4>${jobLine}</h4>
                    ${civilianSub}
                </div>
                ${dutyBadge}
            </div>
            <div class="menu-job-stats">
                <div><span>Rank</span><strong>${rankLine}</strong></div>
                <div><span>Salary</span><strong>$${salaryLine}/hr</strong></div>
                <div><span>Next payday</span><strong>${data.payday || '—'}</strong></div>
                <div><span>Server time</span><strong>${data.serverTime || '—'}</strong></div>
            </div>`;

        let actions = '';
        if (!unemployed || hasFaction) {
            if (data.hasDuty) {
                actions += `<button type="button" class="menu-job-btn menu-job-btn--primary" data-j-action="duty">${data.onDuty ? 'Go off duty' : 'Go on duty'}</button>`;
            }
            if (hasFaction) {
                actions += `<button type="button" class="menu-job-btn" data-j-action="faction">Faction info</button>`;
                actions += `<button type="button" class="menu-job-btn menu-job-btn--danger" data-j-action="leave">Leave faction</button>`;
            }
            if (!unemployed) {
                actions += `<button type="button" class="menu-job-btn menu-job-btn--danger" data-j-action="quit_civilian">Quit civilian job</button>`;
            }
        } else {
            actions = `<p class="menu-mgmt-empty">Get a <strong>civilian job</strong> at the Job Center, or join a <strong>faction</strong> at HQ on the map (LSPD, EMS, Taxi...).</p>`;
        }

        if (data.factionId === 'taxi') {
            actions += `<button type="button" class="menu-job-btn menu-job-btn--cab" data-j-action="phone">Open Downtown Cab app</button>`;
        }

        side.innerHTML = `
            <div class="menu-job-side__box">
                <h5>Quick tips</h5>
                <ul>${this.factionTips(data.factionId || data.jobId)}</ul>
            </div>
            <div class="menu-job-actions">${actions}</div>`;

        side.querySelectorAll('[data-j-action]').forEach((btn) => {
            btn.addEventListener('click', () => {
                const action = btn.dataset.jAction;
                if (action === 'phone') {
                    post('menuAction', { action: 'phone' });
                    return;
                }
                post('menuJobAction', { action });
            });
        });
    },

    update(data) {
        if (!data) return;
        this.init();

        $('#menu-name').textContent = (data.name || '—').toUpperCase();
        $('#menu-id').textContent = `ID: ${Number(data.id) || 0}`;
        const cidEl = $('#menu-cid');
        if (cidEl) cidEl.textContent = data.cid ? ('CID: ' + data.cid) : 'CID: —';
        $('#menu-rank').textContent = data.rank || 'PLAYER';
        $('#menu-cash').textContent = formatMoney(data.cash || 0);
        $('#menu-bank').textContent = formatMoney(data.bank || 0);
        $('#menu-premium').textContent = `${this.formatXp(data.premium ?? 0)} SC`;
        $('#menu-playtime').textContent = data.playtime || '0H 0M';
        $('#menu-lastlogin').textContent = data.lastLogin || '—';

        $('#menu-stats-level').textContent = String(data.level || 1);
        $('#menu-stats-xp').textContent = `${this.formatXp(data.respectPoints || 0)} / ${this.formatXp(data.respectRequired || 4)} RP`;
        $('#menu-stats-paydays').textContent = String(data.paydaysReceived || 0);
        $('#menu-buy-level').textContent = `BUY LEVEL ${Number(data.level || 1) + 1} · ${this.formatXp(data.respectRequired || 4)} RP · ${formatMoney(data.levelPrice || 2500)}`;
        $('#menu-stats-playtime').textContent = data.playtime || '0H 0M';
        $('#menu-stats-session').textContent = data.sessionTime || '0H 0M';
        $('#menu-stats-created').textContent = data.characterCreated || '—';
        $('#menu-stats-lastlogin').textContent = `Last login ${data.lastLogin || '—'}`;
        $('#menu-stats-tasks').textContent = String(data.completedTasks || 0);
        $('#menu-stats-earned').textContent = formatMoney(data.careerEarnings || 0);
        $('#menu-stats-skills').textContent = String(data.combinedSkillLevels || 0);
        $('#menu-stats-assets').textContent = `${data.vehicleCount || 0} vehicles · ${data.propertyCount || 0} properties`;
        $('#menu-stats-home').textContent = `Home: ${data.homeLabel || 'None'}`;

        const xp = data.respectPoints || 0;
        const xpMax = data.respectRequired || 4;
        const level = data.level || 1;
        $('#menu-xp-text').textContent = `${this.formatXp(xp)} / ${this.formatXp(xpMax)} RP`;
        $('#menu-level').textContent = `LEVEL ${level}`;
        const xpBar = $('#menu-xp-bar');
        if (xpBar) xpBar.style.width = `${Math.min(100, (xp / xpMax) * 100)}%`;

        const health = Math.max(0, Math.min(100, Math.round(data.health ?? 100)));
        const armor = Math.max(0, Math.min(100, Math.round(data.armor ?? 0)));
        const hunger = Math.max(0, Math.min(100, Math.round(data.hunger ?? 100)));
        const thirst = Math.max(0, Math.min(100, Math.round(data.thirst ?? 100)));
        const stress = Math.max(0, Math.min(100, Math.round(data.stress ?? 0)));
        const fuel = data.fuel != null ? Math.max(0, Math.min(100, Math.round(data.fuel))) : null;
        $('#menu-health-pct').textContent = `${health}%`;
        $('#menu-armor-pct').textContent = `${armor}%`;
        $('#menu-hunger-pct').textContent = `${hunger}%`;
        $('#menu-thirst-pct').textContent = `${thirst}%`;
        $('#menu-stress-pct').textContent = `${stress}%`;
        $('#menu-fuel-pct').textContent = fuel != null ? `${fuel}%` : '—';
        $('#menu-health-bar').style.width = `${health}%`;
        $('#menu-armor-bar').style.width = `${armor}%`;
        $('#menu-hunger-bar').style.width = `${hunger}%`;
        $('#menu-thirst-bar').style.width = `${thirst}%`;
        $('#menu-stress-bar').style.width = `${stress}%`;
        $('#menu-fuel-bar').style.width = `${fuel ?? 0}%`;

        $('#menu-property-count').textContent = String(data.propertyCount ?? 0);
        $('#menu-home-label').textContent = data.homeLabel || 'None';

        this.renderVehicles(data);
        this.renderJob(data);

        const avatar = $('#menu-avatar');
        if (avatar) {
            if (data.avatar) {
                avatar.style.backgroundImage = `url("${data.avatar}")`;
                avatar.style.backgroundSize = 'cover';
                avatar.textContent = '';
            } else {
                avatar.style.backgroundImage = '';
                avatar.textContent = (data.name || '?').charAt(0).toUpperCase();
            }
        }
    },

    show(data) {
        this.init();
        document.body.classList.add('menu-open');
        $('#menu').classList.remove('hidden');
        this.update(data);
        this.setTab(data?.initialTab || 'player');
    },

    hide() {
        $('#menu').classList.add('hidden');
        document.body.classList.remove('menu-open');
    },

    close() {
        post('menuClose');
    },
};

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#menu').classList.contains('hidden')) {
        Menu.close();
    }
});

window.Menu = Menu;
