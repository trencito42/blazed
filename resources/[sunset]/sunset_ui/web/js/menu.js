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
                post('menuAction', { action: btn.dataset.action });
            });
        });
    },

    setTab(tab) {
        if (!tab) return;
        this.activeTab = tab;
        $$('.menu-tab').forEach((el) => el.classList.toggle('is-active', el.dataset.tab === tab));
        $$('.menu-panel-view').forEach((el) => el.classList.toggle('is-active', el.dataset.panel === tab));
    },

    formatXp(n) {
        return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
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
            const fuel = Math.round(Number(v.fuel) || 100);
            const model = (v.model || 'vehicle').toUpperCase();

            let actions = '';
            if (stored) {
                actions = `<button type="button" class="menu-vcard__btn menu-vcard__btn--primary" data-v-action="spawn" data-v-id="${v.id}">Spawn</button>`;
            } else if (inWorld) {
                actions = `
                    <button type="button" class="menu-vcard__btn" data-v-action="gps" data-v-plate="${v.plate}" data-v-id="${v.id}">GPS</button>
                    <button type="button" class="menu-vcard__btn menu-vcard__btn--primary" data-v-action="store" data-v-id="${v.id}">Store</button>`;
            } else {
                actions = `
                    <button type="button" class="menu-vcard__btn" data-v-action="gps" data-v-plate="${v.plate}" data-v-id="${v.id}">GPS</button>
                    <button type="button" class="menu-vcard__btn menu-vcard__btn--primary" data-v-action="spawn" data-v-id="${v.id}">Respawn</button>
                    <button type="button" class="menu-vcard__btn" data-v-action="store" data-v-id="${v.id}">Store</button>`;
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
                    <div class="menu-vcard__plate">${v.plate || '—'}</div>
                    <div class="menu-vcard__meta">Fuel ${fuel}% · ${v.garage || 'legion'}</div>
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

        const jobLine = hasFaction
            ? (data.factionLabel || data.factionId)
            : (unemployed ? 'Unemployed' : (data.job || 'Unemployed'));

        const rankLine = hasFaction
            ? (data.factionGradeLabel || '—')
            : (data.jobGradeLabel || '—');

        const salaryLine = hasFaction ? (data.factionSalary || 0) : (data.jobSalary || 0);

        const civilianSub = hasFaction
            ? `<p class="menu-job-sub">Civilian job: ${data.job || 'Unemployed'}</p>`
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
        const idSuffix = data.id ? (' #' + data.id) : '';
        $('#menu-id').textContent = (data.name || 'Player') + idSuffix;
        const cidEl = $('#menu-cid');
        if (cidEl) cidEl.textContent = data.cid ? ('CID: ' + data.cid) : 'CID: —';
        $('#menu-rank').textContent = data.rank || 'PLAYER';
        $('#menu-cash').textContent = formatMoney(data.cash || 0);
        $('#menu-bank').textContent = formatMoney(data.bank || 0);
        $('#menu-premium').textContent = String(data.premium ?? 0);
        $('#menu-playtime').textContent = data.playtime || '0H 0M';
        $('#menu-lastlogin').textContent = data.lastLogin || '—';

        const xp = data.xp || 0;
        const xpMax = data.xpMax || 5000;
        const level = data.level || 1;
        $('#menu-xp-text').textContent = `${this.formatXp(xp)} / ${this.formatXp(xpMax)} XP`;
        $('#menu-level').textContent = `LEVEL ${level}`;
        const xpBar = $('#menu-xp-bar');
        if (xpBar) xpBar.style.width = `${Math.min(100, (xp / xpMax) * 100)}%`;

        $('#menu-health-pct').textContent = `${Math.round(data.health ?? 100)}%`;
        $('#menu-hunger-pct').textContent = `${Math.round(data.hunger ?? 100)}%`;
        $('#menu-thirst-pct').textContent = `${Math.round(data.thirst ?? 100)}%`;
        $('#menu-stress-pct').textContent = `${Math.round(data.stress ?? 0)}%`;
        $('#menu-fuel-pct').textContent = data.fuel != null ? `${Math.round(data.fuel)}%` : '—';

        $('#menu-property-count').textContent = String(data.propertyCount ?? 0);
        $('#menu-home-label').textContent = data.homeLabel || 'None';

        this.renderVehicles(data);
        this.renderJob(data);

        const avatar = $('#menu-avatar');
        if (avatar) {
            if (data.avatar) {
                avatar.style.backgroundImage = `url(${data.avatar})`;
                avatar.textContent = '';
            } else {
                avatar.style.backgroundImage = '';
                avatar.textContent = (data.name || '?').charAt(0).toUpperCase();
            }
        }
    },

    show(data) {
        this.init();
        this.setTab('player');
        $('#menu').classList.remove('hidden');
        this.update(data);
    },

    hide() {
        $('#menu').classList.add('hidden');
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
