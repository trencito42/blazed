/**
 * Police Toughbook MDT (Mobile Data Terminal) & 112 Automated Dispatcher
 * Modern, rugged, authentic law enforcement computer system.
 */

(function () {
    const $ = (sel) => document.querySelector(sel);
    const $$ = (sel) => Array.from(document.querySelectorAll(sel));

    const post = (event, data = {}) => {
        return fetch(`https://${GetParentResourceName()}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => {});
    };

    const MdcTablet = {
        activeTab: 'calls',
        officer: null,
        calls: [],
        wanted: [],
        units: [],
        bolos: [],
        clockInterval: null,
        current112Data: null,
        selected112Category: 'shots',

        init() {
            // Close button
            $('#mdc-tablet-close')?.addEventListener('click', () => this.close());

            // Navigation tabs
            $$('.mdc-nav-tab').forEach((tab) => {
                tab.addEventListener('click', () => {
                    const tabName = tab.dataset.tab;
                    if (tabName) this.setTab(tabName);
                });
            });

            // Citizen Search
            $('#mdc-btn-search-citizen')?.addEventListener('click', () => {
                const query = $('#mdc-input-citizen')?.value?.trim();
                if (query) this.searchCitizen(query);
            });
            $('#mdc-input-citizen')?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') $('#mdc-btn-search-citizen')?.click();
            });

            // Vehicle DMV Search
            $('#mdc-btn-search-veh')?.addEventListener('click', () => {
                const query = $('#mdc-input-veh')?.value?.trim();
                if (query) this.searchVehicle(query);
            });
            $('#mdc-input-veh')?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') $('#mdc-btn-search-veh')?.click();
            });

            // Unit Status Selector
            $('#mdc-status-selector')?.addEventListener('change', (e) => {
                const newStatus = e.target.value;
                if (newStatus) {
                    post('mdcSetUnitStatus', { status: newStatus });
                }
            });

            $('#dispatch-112-cancel')?.addEventListener('click', () => this.close112());
            $('#dispatch-112-submit')?.addEventListener('click', () => this.submit112());

            $('#dispatch-112-details')?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.submit112();
                }
            });

            $('#dispatch-112-modal')?.addEventListener('click', (e) => {
                if (e.target === $('#dispatch-112-modal')) {
                    this.close112();
                }
            });

            $$('.dispatch-cat-btn').forEach((btn) => {
                btn.addEventListener('click', () => {
                    $$('.dispatch-cat-btn').forEach((b) => b.classList.remove('is-active'));
                    btn.classList.add('is-active');
                    this.selected112Category = btn.dataset.category || 'shots';
                });
            });

            // Global ESC key to close
            window.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    if (!$('#dispatch-112-modal')?.classList.contains('hidden')) {
                        this.close112();
                    } else if (!$('#mdc')?.classList.contains('hidden')) {
                        this.close();
                    }
                }
            });
        },

        open(data = {}) {
            this.officer = data.officer || {
                department: 'police',
                departmentLabel: 'Los Santos Police Department',
                shortDept: 'LSPD',
                rank: 'Officer',
                callsign: '1-UNIT-01',
                name: 'Officer',
                status: '10-8',
            };
            this.calls = data.calls || [];
            this.wanted = data.wanted || [];
            this.units = data.units || [];
            this.bolos = data.bolos || [];

            // Apply Department Theme
            const tabletEl = $('#mdc-tablet-box');
            if (tabletEl) {
                tabletEl.className = 'mdc-tablet';
                const dept = (this.officer.department || 'police').toLowerCase();
                if (dept === 'sheriff') tabletEl.classList.add('theme--sheriff');
                else if (dept === 'fib') tabletEl.classList.add('theme--fib');
                else tabletEl.classList.add('theme--police');
            }

            // Update Header
            const badgeMap = {
                police: '<svg style="width:20px;height:20px;display:block;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
                sheriff: '<svg style="width:20px;height:20px;display:block;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>',
                fib: '<svg style="width:20px;height:20px;display:block;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>',
            };
            const dept = (this.officer.department || 'police').toLowerCase();
            const badgeIcon = badgeMap[dept] || badgeMap.police;

            const deptBadge = $('#mdc-dept-badge');
            if (deptBadge) deptBadge.innerHTML = badgeIcon;

            const deptTitle = $('#mdc-dept-title');
            if (deptTitle) deptTitle.textContent = this.officer.departmentLabel || 'Police Department';

            const deptSub = $('#mdc-dept-sub');
            if (deptSub) deptSub.textContent = `${this.officer.shortDept || 'LSPD'} MOBILE DATA TERMINAL v4.8`;

            const callsignTag = $('#mdc-callsign-tag');
            if (callsignTag) callsignTag.textContent = this.officer.callsign || 'PATROL-UNIT';

            // Update Officer Sidebar Profile
            const offName = $('#mdc-officer-name');
            if (offName) offName.textContent = this.officer.name || 'Officer';

            const offRank = $('#mdc-officer-rank');
            if (offRank) offRank.textContent = `${this.officer.rank || 'Officer'} · ${this.officer.shortDept || 'LSPD'}`;

            const statusSelect = $('#mdc-status-selector');
            if (statusSelect) statusSelect.value = this.officer.status || '10-8';

            // Live Clock
            this.startClock();

            // Render Views
            this.renderCalls();
            this.renderWanted();
            this.renderUnits();

            // Default to 112 calls tab
            this.setTab('calls');

            $('#mdc')?.classList.remove('hidden');
        },

        refresh(data = {}) {
            if (data.calls) this.calls = data.calls;
            if (data.wanted) this.wanted = data.wanted;
            if (data.units) this.units = data.units;
            if (data.bolos) this.bolos = data.bolos;
            if (data.officer) this.officer = data.officer;

            this.renderCalls();
            this.renderWanted();
            this.renderUnits();
        },

        close() {
            $('#mdc')?.classList.add('hidden');
            if (this.clockInterval) clearInterval(this.clockInterval);
            post('mdcClose');
        },

        startClock() {
            if (this.clockInterval) clearInterval(this.clockInterval);
            const updateTime = () => {
                const now = new Date();
                const pad = (n) => String(n).padStart(2, '0');
                const timeStr = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())} UTC`;
                const clockEl = $('#mdc-clock');
                if (clockEl) clockEl.textContent = timeStr;
            };
            updateTime();
            this.clockInterval = setInterval(updateTime, 1000);
        },

        setTab(tabName) {
            this.activeTab = tabName;

            $$('.mdc-nav-tab').forEach((tab) => {
                tab.classList.toggle('is-active', tab.dataset.tab === tabName);
            });

            $$('.mdc-view').forEach((view) => {
                view.classList.toggle('is-active', view.dataset.view === tabName);
            });
        },

        // ======================================================================
        // TAB 1: 112 EMERGENCY CALLS
        // ======================================================================
        renderCalls() {
            const container = $('#mdc-calls-list');
            const badgeCount = $('#mdc-calls-count');
            if (!container) return;

            const openCalls = this.calls.filter((c) => c.status !== 'COMPLETED' && c.status !== 'CANCELLED');
            if (badgeCount) {
                badgeCount.textContent = openCalls.length;
                badgeCount.style.display = openCalls.length > 0 ? 'inline-block' : 'none';
            }

            if (openCalls.length === 0) {
                container.innerHTML = `
                    <div style="text-align: center; padding: 48px 16px; color: #64748b;">
                        <div style="display: flex; justify-content: center; margin-bottom: 8px;">
                            <svg style="width: 36px; height: 36px; stroke: #475569;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><circle cx="12" cy="12" r="2"/><path d="M16.24 7.76a6 6 0 0 1 0 8.49m-8.48-.01a6 6 0 0 1 0-8.49m11.31-2.82a10 10 0 0 1 0 14.14m-14.14 0a10 10 0 0 1 0-14.14"/></svg>
                        </div>
                        <div style="font-size: 15px; font-weight: 700; color: #94a3b8;">NO ACTIVE 112 DISPATCH CALLS</div>
                        <div style="font-size: 12px; margin-top: 4px;">Emergency frequency clear · Units on routine patrol</div>
                    </div>
                `;
                return;
            }

            const getCategoryStyle = (cat) => {
                cat = String(cat || '').toLowerCase();
                if (cat.includes('shot') || cat.includes('robbery') || cat.includes('assault')) return 'mdc-call-card--shots';
                if (cat.includes('traffic') || cat.includes('accident')) return 'mdc-call-card--traffic';
                if (cat.includes('theft') || cat.includes('stolen')) return 'mdc-call-card--theft';
                if (cat.includes('medic')) return 'mdc-call-card--medical';
                return '';
            };

            container.innerHTML = openCalls.map((call) => {
                const isShots = String(call.category || '').toLowerCase().includes('shot');
                const badgeClass = isShots ? 'mdc-call-badge--shots' : 'mdc-call-badge';
                const cardModifier = getCategoryStyle(call.category);

                const coords = call.coords || { x: 0, y: 0 };
                const coordsStr = `${Math.round(coords.x)}, ${Math.round(coords.y)}`;

                return `
                    <div class="mdc-call-card ${cardModifier}" data-call-id="${call.id}">
                        <div class="mdc-call-card__header">
                            <span class="${badgeClass}">
                                <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                                ${call.category || '112 EMERGENCY'}
                            </span>
                            <span class="mdc-call-time">CALL #${call.id} · ${call.status || 'OPEN'}</span>
                        </div>
                        <div class="mdc-call-location">
                            <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                            <span>${call.street || 'Unknown Street'}, ${call.area || 'Los Santos'}</span>
                            <span style="font-size: 11px; color: #64748b; font-family: monospace;">(${coordsStr})</span>
                        </div>
                        <div class="mdc-call-caller">
                            <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                            Caller: <strong>${call.callerName || 'Anonymous'}</strong> · 
                            <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
                            Phone: <strong>${call.callerPhone || 'N/A'}</strong>
                        </div>
                        <div class="mdc-call-desc">
                            "${call.description || 'Citizen reported emergency'}"
                        </div>
                        <div class="mdc-call-actions">
                            <div class="mdc-call-responder">
                                ${call.responderName ? `<svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="3" width="22" height="13" rx="2"/><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/></svg> Assigned: ${call.responderName}` : '⚠️ Unassigned · Units available'}
                            </div>
                            <div class="mdc-call-btn-group">
                                <button type="button" class="mdc-btn mdc-btn--outline mdc-btn--sm btn-call-gps" data-x="${coords.x}" data-y="${coords.y}">
                                    <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="12 8 8 12 12 16 12 8"/></svg>
                                    SET GPS
                                </button>
                                ${call.status === 'ASSIGNED' ? `
                                    <button type="button" class="mdc-btn mdc-btn--success mdc-btn--sm btn-call-clear" data-call-id="${call.id}">
                                        <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                                        CLEAR (10-98)
                                    </button>
                                ` : `
                                    <button type="button" class="mdc-btn mdc-btn--primary mdc-btn--sm btn-call-respond" data-call-id="${call.id}">
                                        <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                                        RESPOND (10-97)
                                    </button>
                                `}
                            </div>
                        </div>
                    </div>
                `;
            }).join('');

            // Attach Call Actions
            container.querySelectorAll('.btn-call-gps').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const x = Number(btn.dataset.x);
                    const y = Number(btn.dataset.y);
                    post('mdcSetWaypoint', { x, y });
                });
            });

            container.querySelectorAll('.btn-call-respond').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const callId = Number(btn.dataset.callId);
                    post('mdcSetCallStatus', { callId, action: 'respond' });
                });
            });

            container.querySelectorAll('.btn-call-clear').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const callId = Number(btn.dataset.callId);
                    post('mdcSetCallStatus', { callId, action: 'clear' });
                });
            });
        },

        // ======================================================================
        // TAB 2: CITIZEN LOOKUP (CAZIER, VEHICLES, LICENSES, FINES)
        // ======================================================================
        searchCitizen(query) {
            $('#mdc-citizen-loading')?.classList.remove('hidden');
            $('#mdc-citizen-content')?.classList.add('hidden');
            $('#mdc-citizen-empty')?.classList.add('hidden');
            post('mdcSearch', { query });
        },

        updateCitizen(citizen) {
            $('#mdc-citizen-loading')?.classList.add('hidden');

            if (!citizen || !citizen.found) {
                const empty = $('#mdc-citizen-empty');
                if (empty) {
                    empty.textContent = citizen?.error || 'No citizen record found.';
                    empty.classList.remove('hidden');
                }
                $('#mdc-citizen-content')?.classList.add('hidden');
                return;
            }

            $('#mdc-citizen-empty')?.classList.add('hidden');
            $('#mdc-citizen-content')?.classList.remove('hidden');

            // Citizen ID Photo & Fallback
            const photoImg = $('#mdc-cit-photo');
            const photoFallback = $('#mdc-cit-avatar-fallback');
            const docIdEl = $('#mdc-cit-doc-id');

            if (docIdEl) {
                const paddedId = String(citizen.id || 0).padStart(4, '0');
                docIdEl.textContent = `DOC ID: SA-${paddedId}`;
            }

            if (citizen.photoUrl) {
                if (photoImg) {
                    photoImg.src = citizen.photoUrl;
                    photoImg.classList.remove('hidden');
                }
                if (photoFallback) {
                    photoFallback.classList.add('hidden');
                }
            } else {
                if (photoImg) {
                    photoImg.src = '';
                    photoImg.classList.add('hidden');
                }
                if (photoFallback) {
                    photoFallback.classList.remove('hidden');
                }
            }

            // Identity Profile
            $('#mdc-cit-name').textContent = citizen.name || 'Unknown';
            $('#mdc-cit-id').textContent = `#${citizen.id || 0}`;
            $('#mdc-cit-server-id').textContent = citizen.serverId ? `SERVER ID #${citizen.serverId}` : 'OFFLINE';
            $('#mdc-cit-dob').textContent = citizen.dob || 'Unknown';
            $('#mdc-cit-gender').textContent = citizen.gender || 'Unknown';
            $('#mdc-cit-nat').textContent = citizen.nationality || 'San Andreas';
            $('#mdc-cit-phone').textContent = citizen.phone || 'N/A';
            $('#mdc-cit-job').textContent = citizen.job || 'Unemployed';

            // Wanted Status Pill
            const wantedPill = $('#mdc-cit-wanted-pill');
            if (wantedPill) {
                if (citizen.wanted) {
                    wantedPill.className = 'mdc-pill mdc-pill--wanted';
                    wantedPill.textContent = `★ WANTED LEVEL ${citizen.wantedLevel || 1}`;
                } else {
                    wantedPill.className = 'mdc-pill mdc-pill--clean';
                    wantedPill.textContent = 'NO ACTIVE WARRANTS';
                }
            }

            // Incarceration Status Pill
            const jailPill = $('#mdc-cit-jail-pill');
            if (jailPill) {
                if (citizen.jailed) {
                    jailPill.className = 'mdc-pill mdc-pill--jailed';
                    jailPill.textContent = `SERVING JAIL (${citizen.jailMinutes || 1}m remaining)`;
                } else {
                    jailPill.className = 'mdc-pill mdc-pill--clean';
                    jailPill.textContent = 'STATUS: AT LARGE / FREE';
                }
            }

            // BOLO Pill
            const boloPill = $('#mdc-cit-bolo-pill');
            if (boloPill) {
                if (citizen.bolo) {
                    boloPill.className = 'mdc-pill mdc-pill--wanted';
                    boloPill.textContent = 'ACTIVE BOLO: SUSPECT';
                    boloPill.style.display = 'inline-block';
                } else {
                    boloPill.style.display = 'none';
                }
            }

            // Licenses Badges
            const licContainer = $('#mdc-cit-licenses');
            if (licContainer) {
                const licenses = citizen.licenses || [];
                if (licenses.length === 0) {
                    licContainer.innerHTML = '<span class="mdc-lic-badge mdc-lic-badge--none">NO LICENSES ON RECORD</span>';
                } else {
                    licContainer.innerHTML = licenses.map((lic) => `
                        <span class="mdc-lic-badge">✓ ${lic.type || 'License'}</span>
                    `).join('');
                }
            }

            // Personal Vehicles List
            const vehContainer = $('#mdc-cit-vehicles');
            if (vehContainer) {
                const vehicles = citizen.vehicles || [];
                if (vehicles.length === 0) {
                    vehContainer.innerHTML = '<div style="color: #64748b; font-size: 12px;">No vehicles registered to this citizen.</div>';
                } else {
                    vehContainer.innerHTML = vehicles.map((v) => `
                        <div class="mdc-veh-row">
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <span class="mdc-plate-badge">${v.plate}</span>
                                <span class="mdc-veh-model">${v.model}</span>
                            </div>
                            <div style="display: flex; align-items: center; gap: 8px;">
                                <span class="mdc-veh-status">${v.stored ? 'IN GARAGE' : 'OUT IN CITY'}</span>
                                ${v.bolo ? '<span class="mdc-pill mdc-pill--wanted">BOLO STOLEN</span>' : ''}
                            </div>
                        </div>
                    `).join('');
                }
            }

            // Criminal Cazier History (Past jail sentences)
            const cazierTable = $('#mdc-cit-cazier-body');
            if (cazierTable) {
                const cazier = citizen.cazier || [];
                if (cazier.length === 0) {
                    cazierTable.innerHTML = '<tr><td colspan="4" style="text-align: center; color: #64748b; padding: 14px;">Clean Record — No prior convictions or sentences on file.</td></tr>';
                } else {
                    cazierTable.innerHTML = cazier.map((s) => `
                        <tr>
                            <td>${s.date || '—'}</td>
                            <td><strong style="color: #f87171;">${s.reason || 'Charge'}</strong></td>
                            <td>${s.duration || 0} min</td>
                            <td><span class="mdc-pill ${s.status === 'served' ? 'mdc-pill--clean' : 'mdc-pill--jailed'}">${s.status || 'served'}</span></td>
                        </tr>
                    `).join('');
                }
            }

            // Citations / Tickets History & Unpaid Fines
            const finesTotal = $('#mdc-cit-unpaid-fines');
            if (finesTotal) {
                finesTotal.textContent = `$${(citizen.unpaidFines || 0).toLocaleString()}`;
            }

            const ticketsTable = $('#mdc-cit-tickets-body');
            if (ticketsTable) {
                const tickets = citizen.tickets || [];
                if (tickets.length === 0) {
                    ticketsTable.innerHTML = '<tr><td colspan="4" style="text-align: center; color: #64748b; padding: 14px;">No traffic citations or fines on file.</td></tr>';
                } else {
                    ticketsTable.innerHTML = tickets.map((t) => `
                        <tr>
                            <td>${t.date || '—'}</td>
                            <td>${t.reason || 'Violation'}</td>
                            <td><strong>$${(t.amount || 0).toLocaleString()}</strong></td>
                            <td><span class="mdc-pill ${t.paid ? 'mdc-pill--clean' : 'mdc-pill--wanted'}">${t.paid ? 'PAID' : 'UNPAID'}</span></td>
                        </tr>
                    `).join('');
                }
            }
        },

        // ======================================================================
        // TAB 3: VEHICLE DMV & BOLO SYSTEM
        // ======================================================================
        searchVehicle(query) {
            $('#mdc-dmv-loading')?.classList.remove('hidden');
            $('#mdc-dmv-grid')?.classList.add('hidden');
            $('#mdc-dmv-empty')?.classList.add('hidden');
            post('mdcVehicleSearch', { query });
        },

        updateVehicles(vehicles = []) {
            $('#mdc-dmv-loading')?.classList.add('hidden');
            const grid = $('#mdc-dmv-grid');
            const empty = $('#mdc-dmv-empty');

            if (!grid) return;

            if (vehicles.length === 0) {
                if (empty) empty.classList.remove('hidden');
                grid.classList.add('hidden');
                return;
            }

            if (empty) empty.classList.add('hidden');
            grid.classList.remove('hidden');

            grid.innerHTML = vehicles.map((v) => {
                return `
                    <div class="mdc-dmv-card ${v.bolo ? 'is-bolo' : ''}">
                        ${v.bolo ? '<div class="mdc-bolo-banner">SUSPECT VEHICLE · ACTIVE BOLO BROADCAST</div>' : ''}
                        <div class="mdc-dmv-card__head">
                            <span class="mdc-plate-badge">${v.plate}</span>
                            <span class="mdc-veh-model">${v.model}</span>
                        </div>
                        <div class="mdc-dmv-card__owner">
                            <div>Registered Owner: <strong class="btn-goto-owner" data-owner="${v.ownerName}">${v.ownerName}</strong></div>
                            <div style="font-size: 11px; margin-top: 2px;">Phone: ${v.ownerPhone} · Garage: ${v.garage}</div>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #94a3b8;">
                            <span>Status: ${v.stored ? 'Stored in Garage' : 'Impounded / On Street'}</span>
                            <span>Fuel: ${v.fuel}%</span>
                        </div>
                        <div style="display: flex; gap: 8px; margin-top: 4px;">
                            <button type="button" class="mdc-btn ${v.bolo ? 'mdc-btn--danger' : 'mdc-btn--warning'} mdc-btn--sm btn-toggle-veh-bolo" data-plate="${v.plate}">
                                ${v.bolo ? `
                                    <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                                    CLEAR BOLO
                                ` : `
                                    <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 22 22 22"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                                    FLAG BOLO
                                `}
                            </button>
                            <button type="button" class="mdc-btn mdc-btn--outline mdc-btn--sm btn-dossier-owner" data-owner="${v.ownerName}">
                                <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                                VIEW OWNER
                            </button>
                        </div>
                    </div>
                `;
            }).join('');

            // Attach BOLO Toggle and Owner Dossier buttons
            grid.querySelectorAll('.btn-toggle-veh-bolo').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const plate = btn.dataset.plate;
                    const reason = prompt(`Enter reason for BOLO on plate ${plate}:`, 'Stolen vehicle reported by owner');
                    if (reason !== null) {
                        post('mdcToggleBolo', { type: 'vehicle', key: plate, reason: reason });
                    }
                });
            });

            grid.querySelectorAll('.btn-goto-owner, .btn-dossier-owner').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const owner = btn.dataset.owner;
                    if (owner && owner !== 'Unknown / Impounded') {
                        this.setTab('citizen');
                        $('#mdc-input-citizen').value = owner;
                        this.searchCitizen(owner);
                    }
                });
            });
        },

        // ======================================================================
        // TAB 4: WARRANTS & ACTIVE WANTED LIST
        // ======================================================================
        renderWanted() {
            const container = $('#mdc-wanted-grid');
            if (!container) return;

            if (this.wanted.length === 0) {
                container.innerHTML = `
                    <div style="text-align: center; padding: 48px 16px; color: #64748b;">
                        <div style="display: flex; justify-content: center; margin-bottom: 8px;">
                            <svg style="width: 36px; height: 36px; stroke: #475569;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                        </div>
                        <div style="font-size: 15px; font-weight: 700; color: #94a3b8;">NO ACTIVE ARREST WARRANTS</div>
                        <div style="font-size: 12px; margin-top: 4px;">All suspects processed · Clean warrant docket</div>
                    </div>
                `;
                return;
            }

            container.innerHTML = this.wanted.map((row) => {
                const stars = '★'.repeat(Math.max(1, Math.min(5, row.level || 1)));
                return `
                    <div class="mdc-wanted-card">
                        <div style="display: flex; align-items: center; gap: 14px;">
                            <span class="mdc-wanted-stars">${stars}</span>
                            <div>
                                <div style="font-size: 15px; font-weight: 700; color: #f8fafc;">
                                    ${row.name || 'Suspect'} <span style="font-size: 12px; color: #38bdf8;">(#${row.id})</span>
                                </div>
                                <div style="font-size: 12px; color: #94a3b8; margin-top: 2px;">
                                    Reason: <strong style="color: #cbd5e1;">${row.reason || 'Unspecified'}</strong> · 
                                    ${row.surrenderable === false ? '<span style="color: #ef4444; font-weight: 700;">NO SURRENDER</span>' : 'SURRENDER ALLOWED'}
                                </div>
                            </div>
                        </div>
                        <div style="display: flex; gap: 8px;">
                            <button type="button" class="mdc-btn mdc-btn--outline mdc-btn--sm btn-locate-wanted" data-target-id="${row.id}">
                                <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="12 8 8 12 12 16 12 8"/></svg>
                                LOCATE GPS
                            </button>
                            <button type="button" class="mdc-btn mdc-btn--primary mdc-btn--sm btn-view-wanted-cit" data-name="${row.name}">
                                <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                                DOSSIER
                            </button>
                        </div>
                    </div>
                `;
            }).join('');

            container.querySelectorAll('.btn-locate-wanted').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const id = Number(btn.dataset.targetId);
                    // Locate wanted via sunset:policeFindWanted
                    fetch(`https://${GetParentResourceName()}/policeFindWanted`, {
                        method: 'POST',
                        body: JSON.stringify({ targetId: id }),
                    }).catch(() => {});
                });
            });

            container.querySelectorAll('.btn-view-wanted-cit').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const name = btn.dataset.name;
                    this.setTab('citizen');
                    $('#mdc-input-citizen').value = name;
                    this.searchCitizen(name);
                });
            });
        },

        // ======================================================================
        // TAB 5: ACTIVE UNITS ROSTER
        // ======================================================================
        renderUnits() {
            const container = $('#mdc-units-grid');
            if (!container) return;

            if (this.units.length === 0) {
                container.innerHTML = '<div style="color: #64748b; padding: 24px;">No other law enforcement units logged on.</div>';
                return;
            }

            container.innerHTML = this.units.map((unit) => {
                const statusClass = `status--${(unit.status || '10-8').toLowerCase()}`;
                return `
                    <div class="mdc-unit-card">
                        <div>
                            <div style="font-size: 14px; font-weight: 700; color: #f8fafc;">
                                ${unit.name} ${unit.isMe ? '<span style="color: #38bdf8; font-size: 11px;">(YOU)</span>' : ''}
                            </div>
                            <div style="font-size: 11px; color: #94a3b8; text-transform: uppercase;">
                                ${unit.rank} · ${unit.shortDept || 'LSPD'}
                            </div>
                        </div>
                        <span class="mdc-unit-status-tag ${statusClass}">
                            ${unit.status || '10-8'}
                        </span>
                    </div>
                `;
            }).join('');
        },

        // ======================================================================
        // 112 AUTOMATED DISPATCHER MODAL
        // ======================================================================
        open112(data = {}) {
            this.current112Data = data;
            const street = data.street || 'Current Location';
            const area = data.area || 'Los Santos';
            $('#dispatch-112-location').textContent = `${street} · ${area}`;
            $('#dispatch-112-details').value = '';

            // Reset category
            $$('.dispatch-cat-btn').forEach((b) => b.classList.remove('is-active'));
            const defaultCat = $('.dispatch-cat-btn[data-category="shots"]');
            if (defaultCat) defaultCat.classList.add('is-active');
            this.selected112Category = 'shots';

            $('#dispatch-112-modal')?.classList.remove('hidden');
            setTimeout(() => {
                $('#dispatch-112-details')?.focus();
            }, 60);
        },

        close112() {
            $('#dispatch-112-modal')?.classList.add('hidden');
            post('close112Modal');
        },

        submit112() {
            const desc = $('#dispatch-112-details')?.value?.trim() || 'Citizen requested emergency response';
            const loc = this.current112Data || {};

            post('submit112Call', {
                category: this.selected112Category,
                description: desc,
                street: loc.street,
                area: loc.area,
                coords: loc.coords,
            });

            $('#dispatch-112-modal')?.classList.add('hidden');
        },
    };

    window.MdcTablet = MdcTablet;
    document.addEventListener('DOMContentLoaded', () => MdcTablet.init());
})();
