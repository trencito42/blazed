const Menu = {
    activeTab: 'player',
    selectedVehicleId: null,
    openEcuVehicleId: null,

    init() {
        if (this._ready) return;
        this._ready = true;

        $('#menu-close-btn')?.addEventListener('click', () => this.close());

        $$('.menu-tab').forEach((tab) => {
            tab.addEventListener('click', () => this.setTab(tab.dataset.tab));
        });

        $$('.menu-action').forEach((btn) => {
            btn.addEventListener('click', () => {
                if (btn.disabled) return;
                if (btn.dataset.action === 'statistics') {
                    this.setTab('statistics');
                    return;
                }
                post('menuAction', { action: btn.dataset.action });
            });
        });

        $('#menu-profile-buy-level')?.addEventListener('click', () => {
            const btn = $('#menu-profile-buy-level');
            if (!btn || btn.disabled) return;
            post('menuAction', { action: 'buy_level' });
        });

        $('#menu-property-browse')?.addEventListener('click', () => {
            post('menuAction', { action: 'properties' });
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
    },

    formatXp(n) {
        return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    },

    buyLevelState(data) {
        const level = Number(data?.level || 1);
        const rp = Number(data?.respectPoints || 0);
        const rpNeed = Number(data?.respectRequired || 4);
        const price = Number(data?.levelPrice || 2500);
        const money = Number(data?.cash || 0) + Number(data?.bank || 0);
        const canBuy = rp >= rpNeed && money >= price;
        let reason = '';
        if (!canBuy) {
            if (rp < rpNeed) {
                reason = `Need ${this.formatXp(rpNeed)} RP — you have ${this.formatXp(rp)}`;
            } else {
                reason = `Need ${formatMoney(price)} in cash or bank`;
            }
        }
        return { level, rp, rpNeed, price, canBuy, reason };
    },

    applyBuyLevelState(data) {
        const state = this.buyLevelState(data);
        const profileBtn = $('#menu-profile-buy-level');
        const statsBtn = $('#menu-buy-level');
        const nextLevel = state.level + 1;

        [profileBtn, statsBtn].forEach((btn) => {
            if (!btn) return;
            btn.disabled = !state.canBuy;
            btn.classList.toggle('is-unaffordable', !state.canBuy);
            btn.setAttribute('aria-disabled', state.canBuy ? 'false' : 'true');
        });

        if (profileBtn) {
            if (state.canBuy) {
                profileBtn.innerHTML = `BUY LEVEL ${nextLevel}<small>${this.formatXp(state.rpNeed)} RP · ${formatMoney(state.price)}</small>`;
            } else {
                profileBtn.innerHTML = `LEVEL ${nextLevel} LOCKED<small>${this.escape(state.reason)}</small>`;
            }
        }

        if (statsBtn) {
            statsBtn.textContent = state.canBuy
                ? `BUY LEVEL ${nextLevel} · ${this.formatXp(state.rpNeed)} RP · ${formatMoney(state.price)}`
                : state.reason;
        }
    },

    showAlert(message, type = 'error') {
        const el = $('#menu-level-alert');
        if (!message) {
            el?.classList.add('hidden');
            return;
        }
        if (typeof notify === 'function') notify(message, type, 7000);
        if (!el) return;
        el.textContent = String(message);
        el.className = `menu-level-alert menu-level-alert--${type}`;
        el.classList.remove('hidden');
        clearTimeout(this._alertTimer);
        this._alertTimer = setTimeout(() => el.classList.add('hidden'), 9000);
    },

    clearAlert() {
        clearTimeout(this._alertTimer);
        $('#menu-level-alert')?.classList.add('hidden');
    },

    escape(value) {
        return String(value ?? '').replace(/[&<>"']/g, (ch) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        })[ch]);
    },

    factionTips(jobId) {
        const common = [
            '<li>Factions are joined at HQ markers on the map (LSPD, EMS, Taxi…).</li>',
            '<li>Faction membership requires a leader invitation after an accepted Discord/site application. Members use <strong>[E]</strong> at HQ for duty.</li>',
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

    formatEcuBlock(info, vehicleId) {
        const ecu = info || {};
        const vid = Number(vehicleId) || 0;
        if (ecu.stock) {
            return `<div class="menu-vcard__ecu-strip menu-vcard__ecu-strip--stock">
                <span class="menu-vcard__ecu-pill">STOCK ECU</span>
            </div>`;
        }

        const chips = (ecu.chips || []).slice(0, 5);
        const dyno = (ecu.lines || []).find((line) => (line.label || '').toUpperCase() === 'DYNO');
        const chipHtml = chips.map((c) => `<span class="menu-vcard__ecu-chip">${this.escape(c)}</span>`).join('');
        const detailLines = (ecu.lines || []).map((line) => `
            <div class="menu-vcard__ecu-line">
                <span>${this.escape(line.label || '')}</span>
                <em>${this.escape(line.value || '')}</em>
            </div>`).join('');

        return `<div class="menu-vcard__ecu-strip" data-ecu-id="${vid}">
            <div class="menu-vcard__ecu-strip-main">
                <span class="menu-vcard__ecu-pill">TUNED</span>
                <span class="menu-vcard__ecu-summary">${this.escape(ecu.summary || 'Custom map')}</span>
                ${dyno ? `<span class="menu-vcard__ecu-dyno">${this.escape(dyno.value)}</span>` : ''}
                <button type="button" class="menu-vcard__ecu-toggle" data-ecu-toggle="${vid}" aria-label="ECU details">⋯</button>
            </div>
            <div class="menu-vcard__ecu-chips">${chipHtml}</div>
            <div class="menu-vcard__ecu-detail hidden" data-ecu-detail="${vid}">${detailLines}</div>
        </div>`;
    },

    bindEcuToggles(root) {
        if (!root) return;
        root.querySelectorAll('[data-ecu-toggle]').forEach((btn) => {
            const id = btn.dataset.ecuToggle;
            const detail = root.querySelector(`[data-ecu-detail="${id}"]`);
            if (!detail) return;
            const isOpen = String(this.openEcuVehicleId) === String(id);
            detail.classList.toggle('hidden', !isOpen);
            btn.classList.toggle('is-open', isOpen);
            btn.textContent = isOpen ? '−' : '⋯';
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                if (String(this.openEcuVehicleId) === String(id)) {
                    this.openEcuVehicleId = null;
                } else {
                    this.openEcuVehicleId = id;
                }
                const nowOpen = String(this.openEcuVehicleId) === String(id);
                detail.classList.toggle('hidden', !nowOpen);
                btn.classList.toggle('is-open', nowOpen);
                btn.textContent = nowOpen ? '−' : '⋯';
            });
        });
    },

    vitalsRow(label, pct) {
        const value = Math.max(0, Math.min(100, Math.round(pct)));
        return `<div class="menu-vcard__vital" title="${label} ${value}%">
            <span>${label}</span>
            <i><b style="width:${value}%"></b></i>
            <em>${value}%</em>
        </div>`;
    },

    vmenuStatClass(val) {
        const value = Math.max(0, Math.min(100, Math.round(val)));
        if (value >= 80) return 'ok';
        if (value >= 40) return 'warn';
        return 'bad';
    },

    vmenuStatusTag(key) {
        if (key === 'garage') return { cls: 'garage', label: 'Garaj' };
        if (key === 'out' || key === 'parked') return { cls: 'out', label: key === 'parked' ? 'Parcat' : 'Stradă' };
        return { cls: 'impound', label: 'Confiscat' };
    },

    vmenuTuningList(ecuInfo) {
        const ecu = ecuInfo || {};
        if (ecu.stock) {
            return '<div class="tuning-item" style="color:rgba(255,255,255,0.4)">Fără modificări</div>';
        }
        const lines = (ecu.lines || []).slice(0, 6);
        if (!lines.length) {
            const chips = (ecu.chips || []).slice(0, 6);
            if (!chips.length) {
                return `<div class="tuning-item">ECU: <span>${this.escape(ecu.summary || 'Custom')}</span></div>`;
            }
            return chips.map((chip) => `<div class="tuning-item">Chip: <span>${this.escape(chip)}</span></div>`).join('');
        }
        return lines.map((line) => `<div class="tuning-item">${this.escape(line.label || 'Mod')}: <span>${this.escape(line.value || '—')}</span></div>`).join('');
    },

    vehicleSnapshotKey(vehicles, selectedId, openEcuId) {
        const list = (vehicles || []).map((v) => [
            v.id, v.model, v.plate, v.stored, v.inWorld, v.destroyed,
            v.fuel, v.engine, v.body, v.odometer,
            v.insurancePoints, v.insuranceLevel, v.claimCost, v.renewCost,
            v.isCurrentVehicle, v.garage, v.parked_x, v.parked_y,
            JSON.stringify(v.ecuInfo || null),
        ].join('|'));
        return JSON.stringify({ selectedId, openEcuId, list });
    },

    _vehicleStateOf(v) {
        const isDestroyed = v.destroyed === true || v.destroyed === 1 || v.destroyed === '1';
        const stored = !isDestroyed && (v.stored === true || v.stored === 1 || v.stored === '1' || Number(v.stored) === 1);
        const inWorld = !isDestroyed && v.inWorld === true;
        const hasPark = Number.isFinite(Number(v.parked_x)) && Number.isFinite(Number(v.parked_y));
        if (isDestroyed) return { key: 'impound', label: 'Confiscat / Asigurare', stored: false, inWorld: false, isDestroyed: true };
        if (stored) return { key: 'garage', label: `Garaj · ${v.garage || 'Central'}`, stored, inWorld };
        if (inWorld) return { key: 'out', label: v.garage || 'Stradă', stored, inWorld };
        if (hasPark) return { key: 'parked', label: 'Parcat', stored, inWorld };
        return { key: 'impound', label: 'Indisponibil', stored, inWorld };
    },

    _bindVehicleImpoundHold(root, vehicleId, claimCost) {
        const hold = root.querySelector('[data-v-impound-hold]');
        if (!hold) return;
        let prog = 0;
        let frame = null;
        const reset = () => {
            cancelAnimationFrame(frame);
            frame = null;
            prog = 0;
            const bar = hold.querySelector('.bh-progress');
            if (bar) bar.style.width = '0%';
        };
        const tick = () => {
            prog += 2.5;
            const bar = hold.querySelector('.bh-progress');
            if (bar) bar.style.width = `${Math.min(100, prog)}%`;
            if (prog >= 100) {
                reset();
                post('menuVehicleAction', { action: 'claim_insurance', vehicleId });
                return;
            }
            frame = requestAnimationFrame(tick);
        };
        hold.onpointerdown = (e) => { e.preventDefault(); reset(); frame = requestAnimationFrame(tick); };
        hold.onpointerup = reset;
        hold.onpointerleave = reset;
        const label = hold.querySelector('.bh-text');
        if (label) label.innerHTML = `<span class="key">ENTER</span> Achită Cauțiunea (${formatMoney(claimCost)})`;
    },

    renderVehicles(data) {
        const grid = $('#menu-vehicle-grid');
        if (!grid) return;
        const vehicles = data.vehicles || [];
        const query = String(this._vehicleSearch || '').trim().toLowerCase();

        const snapKey = this.vehicleSnapshotKey(vehicles, this.selectedVehicleId, this.openEcuVehicleId) + '|' + query;
        if (snapKey === this._vehicleSnapKey && grid.classList.contains('v-menu-forza')) {
            return;
        }
        this._vehicleSnapKey = snapKey;

        grid.className = 'v-menu-forza visible';

        if (!vehicles.length) {
            this.selectedVehicleId = null;
            grid.innerHTML = '<div class="vmenu-empty"><strong>Fără Vehicule</strong><span>Mașinile tale vor apărea aici.</span></div>';
            return;
        }

        const filtered = query
            ? vehicles.filter((v) => {
                const model = String(v.model || '').toLowerCase();
                const plate = String(v.plate || '').toLowerCase();
                return model.includes(query) || plate.includes(query);
            })
            : vehicles;

        const selectedExists = filtered.some((v) => String(v.id) === String(this.selectedVehicleId));
        if (!selectedExists) this.selectedVehicleId = (filtered[0] || vehicles[0]).id;
        const selected = filtered.find((v) => String(v.id) === String(this.selectedVehicleId))
            || vehicles.find((v) => String(v.id) === String(this.selectedVehicleId))
            || vehicles[0];

        const listHtml = (filtered.length ? filtered : vehicles).map((v) => {
            const status = this._vehicleStateOf(v);
            const tag = this.vmenuStatusTag(status.key);
            const name = this.escape((v.label || v.model || 'Vehicle').toUpperCase());
            const plate = this.escape(v.plate || '—');
            const isSelected = String(v.id) === String(this.selectedVehicleId);
            return `<button type="button" class="v-item ${isSelected ? 'active' : ''}" data-v-select="${Number(v.id) || 0}">
                <i class="ph-fill ph-car-profile vi-icon"></i>
                <div class="vi-info">
                    <div class="vi-name">${name}</div>
                    <div class="vi-plate">${plate}</div>
                </div>
                <div class="vi-status ${tag.cls}">${tag.label}</div>
            </button>`;
        }).join('');

        const status = this._vehicleStateOf(selected);
        const displayName = this.escape((selected.label || selected.model || 'Vehicle').toUpperCase());
        const plate = this.escape(selected.plate || '—');
        const fuel = Math.max(0, Math.min(100, Math.round(Number(selected.fuel) || 0)));
        const engine = Math.max(0, Math.min(100, Math.round((Number(selected.engine) || 0) / 10)));
        const body = Math.max(0, Math.min(100, Math.round((Number(selected.body) || 0) / 10)));
        const odometer = Math.max(0, Number(selected.odometer) || 0);
        const claimCost = selected.claimCost != null ? Number(selected.claimCost) : 250;
        const renewCost = selected.renewCost != null ? Number(selected.renewCost) : 750;
        const insurancePts = selected.insurancePoints != null ? Number(selected.insurancePoints) : 5;

        let mainAction = '';
        let gpsAction = `<button type="button" class="btn-action secondary" data-v-action="gps" data-v-plate="${plate}" data-v-id="${Number(selected.id) || 0}"><i class="ph-bold ph-crosshair"></i> GPS</button>`;
        let impoundHold = `<div class="btn-hold hidden" data-v-impound-hold data-v-id="${Number(selected.id) || 0}"><div class="bh-progress"></div><div class="bh-text"><span class="key">ENTER</span> Achită Cauțiunea</div></div>`;

        if (status.isDestroyed) {
            mainAction = '';
            gpsAction = '';
            if (insurancePts > 0) {
                impoundHold = `<div class="btn-hold" data-v-impound-hold data-v-id="${Number(selected.id) || 0}"><div class="bh-progress"></div><div class="bh-text"><span class="key">ENTER</span> Achită Cauțiunea (${formatMoney(claimCost)})</div></div>`;
            } else {
                mainAction = `<button type="button" class="btn-action" data-v-action="renew_insurance" data-v-id="${Number(selected.id) || 0}"><i class="ph-bold ph-shield-check"></i> Reînnoiește Asigurarea (${formatMoney(renewCost)})</button>`;
                impoundHold = '';
            }
        } else if (status.stored) {
            mainAction = `<button type="button" class="btn-action" data-v-action="spawn" data-v-id="${Number(selected.id) || 0}"><i class="ph-bold ph-key"></i> Solicită Valet</button>`;
            gpsAction = '';
        } else if (status.inWorld) {
            const parkAction = selected.isCurrentVehicle ? 'park' : 'store';
            const parkLabel = selected.isCurrentVehicle ? 'Park / Garaj' : 'Trimite în Garaj';
            mainAction = `<button type="button" class="btn-action" data-v-action="${parkAction}" data-v-id="${Number(selected.id) || 0}"><i class="ph-bold ph-car"></i> ${parkLabel}</button>`;
            gpsAction = `<button type="button" class="btn-action secondary" data-v-action="gps" data-v-plate="${plate}" data-v-id="${Number(selected.id) || 0}"><i class="ph-bold ph-crosshair"></i> GPS (${this.escape(status.label)})</button>`;
        } else {
            mainAction = `<button type="button" class="btn-action" data-v-action="spawn" data-v-id="${Number(selected.id) || 0}"><i class="ph-bold ph-key"></i> Respawn Aici</button>`;
        }

        grid.innerHTML = `<div class="v-sidebar">
                <div class="v-header">
                    <h2 class="vh-title"><i class="ph-bold ph-steering-wheel"></i> Vehiculele Tale</h2>
                    <div class="v-search">
                        <i class="ph-bold ph-magnifying-glass"></i>
                        <input type="text" id="v-menu-search" placeholder="Caută model sau număr..." value="${this.escape(query)}">
                    </div>
                </div>
                <div class="v-list">${listHtml || '<div class="vmenu-empty" style="transform:skewX(5deg);border:none;background:transparent"><span>Niciun rezultat</span></div>'}</div>
            </div>
            <div class="v-details">
                <i class="ph-fill ph-car-profile vd-watermark"></i>
                <div class="vd-header">
                    <div class="vd-title-box">
                        <div class="vd-class">${this.escape(selected.vehicleClass || 'Personal Vehicle')}</div>
                        <h2 class="vd-name">${displayName}</h2>
                    </div>
                    <div class="vd-plate-box">
                        <div class="vd-plate-state">San Andreas</div>
                        <div class="vd-plate-text">${plate}</div>
                    </div>
                </div>
                <div class="vd-body">
                    <div class="vd-status-grid">
                        <div class="status-box ${this.vmenuStatClass(engine)}">
                            <div class="sb-label"><i class="ph-fill ph-engine"></i> Motor</div>
                            <div class="sb-val">${engine}%</div>
                        </div>
                        <div class="status-box ${this.vmenuStatClass(body)}">
                            <div class="sb-label"><i class="ph-fill ph-car"></i> Caroserie</div>
                            <div class="sb-val">${body}%</div>
                        </div>
                        <div class="status-box ${this.vmenuStatClass(fuel)}">
                            <div class="sb-label"><i class="ph-fill ph-gas-pump"></i> Benzină</div>
                            <div class="sb-val">${fuel}%</div>
                        </div>
                    </div>
                    <div class="vd-extra-grid">
                        <div class="vd-card">
                            <div class="vc-title"><i class="ph-fill ph-gauge"></i> Kilometraj (Odo)</div>
                            <div class="odometer-val">${odometer.toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} KM</div>
                        </div>
                        <div class="vd-card">
                            <div class="vc-title"><i class="ph-fill ph-cpu"></i> Tuning Instalat</div>
                            <div class="tuning-list">${this.vmenuTuningList(selected.ecuInfo)}</div>
                        </div>
                    </div>
                </div>
                <div class="vd-actions">
                    ${gpsAction}
                    ${mainAction}
                    ${impoundHold}
                </div>
            </div>`;

        const searchInput = grid.querySelector('#v-menu-search');
        if (searchInput) {
            searchInput.addEventListener('input', () => {
                this._vehicleSearch = searchInput.value;
                this._vehicleSnapKey = null;
                this.renderVehicles(data);
            });
            searchInput.addEventListener('keydown', (e) => e.stopPropagation());
        }

        grid.querySelectorAll('[data-v-select]').forEach((button) => {
            button.addEventListener('click', () => {
                this.selectedVehicleId = Number(button.dataset.vSelect);
                this._vehicleSnapKey = null;
                this.renderVehicles(data);
            });
        });

        grid.querySelectorAll('[data-v-action]').forEach((btn) => {
            btn.addEventListener('click', () => {
                post('menuVehicleAction', {
                    action: btn.dataset.vAction,
                    vehicleId: btn.dataset.vId,
                    plate: btn.dataset.vPlate,
                });
            });
        });

        if (status.isDestroyed && insurancePts > 0) {
            this._bindVehicleImpoundHold(grid, Number(selected.id) || 0, claimCost);
        }
    },

    renderProperties(data) {
        const list = $('#menu-property-list');
        if (!list || !window.PropertyUI) return;
        const properties = data.properties || [];
        const owned = properties.filter((p) => p.owned);
        const rented = properties.filter((p) => p.rented);
        const mine = [...owned, ...rented.filter((p) => !p.owned)];
        PropertyUI.renderList(list, {
            properties: mine.length ? mine : properties.slice(0, 6),
            selectedId: data.selectedPropertyId,
            meta: data.propertyMeta,
        });
    },

    updateProperties(data) {
        if (!data) return;
        this.renderProperties(data);
        if (data.propertyCount != null) {
            $('#menu-property-count').textContent = String(data.propertyCount);
        }
        if (data.homeLabel) {
            $('#menu-home-label').textContent = data.homeLabel;
        }
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
            actions = `<p class="menu-mgmt-empty">Join a <strong>faction</strong> at HQ on the map (LSPD, EMS, Taxi…).</p>`;
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

        if (this.soloMode === 'vehicle') {
            this.renderVehicles(data);
            return;
        }

        $('#menu-name').textContent = (data.name || '—').toUpperCase();
        $('#menu-id').textContent = String(Number(data.id) || 0);
        const jobLabel = $('#menu-job-label');
        if (jobLabel) {
            jobLabel.textContent = data.factionLabel || data.job || 'Unemployed';
        }
        const cidEl = $('#menu-cid');
        if (cidEl) cidEl.textContent = data.cid ? ('CID: ' + data.cid) : 'CID: —';
        $('#menu-rank').textContent = data.rank || 'PLAYER';
        $('#menu-cash').textContent = formatMoney(data.cash || 0);
        $('#menu-bank').textContent = formatMoney(data.bank || 0);
        $('#menu-premium').textContent = `${this.formatXp(data.premium ?? 0)} BP`;
        $('#menu-playtime').textContent = data.playtime || '0H 0M';
        $('#menu-lastlogin').textContent = data.lastLogin || '—';

        $('#menu-stats-level').textContent = String(data.level || 1);
        $('#menu-stats-xp').textContent = `${this.formatXp(data.respectPoints || 0)} / ${this.formatXp(data.respectRequired || 4)} RP`;
        $('#menu-stats-paydays').textContent = String(data.paydaysReceived || 0);
        this.applyBuyLevelState(data);
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
        $('#menu-level').textContent = `Nivel ${level}`;
        const xpBar = $('#menu-xp-bar');
        if (xpBar) xpBar.style.width = `${Math.min(100, (xp / xpMax) * 100)}%`;

        const health = Math.max(0, Math.min(100, Math.round(data.health ?? 100)));
        const armor = Math.max(0, Math.min(100, Math.round(data.armor ?? 0)));
        const hunger = Math.max(0, Math.min(100, Math.round(data.hunger ?? 100)));
        const thirst = Math.max(0, Math.min(100, Math.round(data.thirst ?? 100)));
        const stress = Math.max(0, Math.min(100, Math.round(data.stress ?? 0)));
        const setBar = (id, pct) => {
            const el = document.getElementById(id);
            if (el) el.style.width = `${pct}%`;
        };
        const setText = (id, text) => {
            const el = document.getElementById(id);
            if (el) el.textContent = text;
        };

        setText('menu-health-pct', `${health}%`);
        setText('menu-armor-pct', `${armor}%`);
        setText('menu-hunger-pct', `${hunger}%`);
        setText('menu-thirst-pct', `${thirst}%`);
        setText('menu-stress-pct', `${stress}%`);
        setBar('menu-health-bar', health);
        setBar('menu-armor-bar', armor);
        setBar('menu-hunger-bar', hunger);
        setBar('menu-thirst-bar', thirst);
        setBar('menu-stress-bar', stress);

        $('#menu-property-count').textContent = String(data.propertyCount ?? 0);
        $('#menu-home-label').textContent = data.homeLabel || 'None';

        this.renderProperties(data);
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
        const menu = $('#menu');
        menu.classList.remove('menu--solo-vehicle', 'menu--solo-inventory');
        if (data?.soloMode) {
            menu.classList.add(`menu--solo-${data.soloMode}`);
        }
        this.soloMode = data?.soloMode || null;

        const brandTitle = $('.menu-brand > div');
        if (brandTitle) {
            if (!this._brandHtml) this._brandHtml = brandTitle.innerHTML;
            if (this.soloMode === 'vehicle') {
                brandTitle.innerHTML = 'VEHICLES <span>GARAGE</span>';
            } else {
                brandTitle.innerHTML = this._brandHtml;
            }
        }

        const closeBtn = $('#menu-close-btn');
        if (closeBtn) {
            if (!this._closeHtml) this._closeHtml = closeBtn.innerHTML;
            closeBtn.innerHTML = this.soloMode === 'vehicle'
                ? '<span class="menu-keycap">V</span> CLOSE'
                : this._closeHtml;
        }

        document.body.classList.add('menu-open');
        menu.classList.remove('hidden');
        this.clearAlert();
        this.update(data);
        this.setTab(data?.initialTab || (this.soloMode === 'vehicle' ? 'vehicle' : 'player'));
    },

    hide() {
        const menu = $('#menu');
        menu.classList.add('hidden');
        menu.classList.remove('menu--solo-vehicle', 'menu--solo-inventory');
        this.soloMode = null;
        this._vehicleSnapKey = null;

        const brandTitle = $('.menu-brand > div');
        if (brandTitle && this._brandHtml) brandTitle.innerHTML = this._brandHtml;

        const closeBtn = $('#menu-close-btn');
        if (closeBtn && this._closeHtml) closeBtn.innerHTML = this._closeHtml;

        document.body.classList.remove('menu-open');
        this.clearAlert();
    },

    close() {
        post('menuClose');
    },
};

document.addEventListener('keydown', (e) => {
    if (e.repeat) return;
    const menu = $('#menu');
    if (!menu || menu.classList.contains('hidden')) return;
    const tag = (e.target && e.target.tagName) || '';
    if (tag === 'INPUT' || tag === 'TEXTAREA' || e.target?.isContentEditable) return;

    if (e.key === 'Escape' || e.key === 'm' || e.key === 'M') {
        Menu.close();
        e.preventDefault();
        return;
    }
    if (menu.classList.contains('menu--solo-vehicle') && (e.key === 'v' || e.key === 'V')) {
        Menu.close();
        e.preventDefault();
    }
});

window.Menu = Menu;
