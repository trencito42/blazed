/**
 * Police Toughbook MDT (Mobile Data Terminal) & 112 Automated Dispatcher
 * Modern, rugged, authentic law enforcement computer system with full interactive actions.
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
        reasons: [],
        violations: [],
        hasActiveBackup: false,
        activeBackupId: null,
        radarActive: false,
        radarLimit: 90,
        clockInterval: null,
        current112Data: null,
        selected112Category: 'shots',
        currentCitizen: null,
        currentBoloTarget: null,
        selectedChargeCode: null,
        selectedViolationCode: null,

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

            // Header: 10-99 Panic Button
            $('#mdc-header-panic')?.addEventListener('click', () => {
                post('mdcRequestBackup', { priority: 'panic' });
            });

            // Header: Backup Dropdown Toggle
            $('#mdc-header-backup')?.addEventListener('click', (e) => {
                e.stopPropagation();
                $('#mdc-backup-menu')?.classList.toggle('hidden');
            });

            // Close backup dropdown on click outside
            document.addEventListener('click', (e) => {
                if (!e.target.closest('.mdc-backup-dropdown-wrap')) {
                    $('#mdc-backup-menu')?.classList.add('hidden');
                }
            });

            // Header: Backup Options (Code 2, Code 3, Panic)
            $$('.mdc-backup-opt:not(#mdc-backup-cancel-btn)').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const priority = btn.dataset.priority || 'code2';
                    post('mdcRequestBackup', { priority });
                    $('#mdc-backup-menu')?.classList.add('hidden');
                });
            });

            // Header: Cancel Backup Option
            $('#mdc-backup-cancel-btn')?.addEventListener('click', () => {
                post('mdcCancelBackup');
                $('#mdc-backup-menu')?.classList.add('hidden');
            });

            // Citizen Actions Toolbar
            $('#mdc-act-wanted')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    this.openWantedModal(this.currentCitizen.serverId || this.currentCitizen.id, this.currentCitizen.name);
                }
            });

            $('#mdc-act-ticket')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    this.openTicketModal(this.currentCitizen.serverId || this.currentCitizen.id, this.currentCitizen.name);
                }
            });

            $('#mdc-act-license')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    this.openLicenseModal(this.currentCitizen.serverId || this.currentCitizen.id, this.currentCitizen.name);
                }
            });

            $('#mdc-act-so')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    const targetId = this.currentCitizen.serverId || this.currentCitizen.id;
                    post('mdcSummon', { targetId });
                }
            });

            $('#mdc-act-find')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    const targetId = this.currentCitizen.serverId || this.currentCitizen.id;
                    post('mdcFindWanted', { targetId });
                }
            });

            $('#mdc-act-clear')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    const targetId = this.currentCitizen.serverId || this.currentCitizen.id;
                    post('mdcClearWanted', { targetId });
                }
            });

            $('#mdc-act-unjail')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    const targetId = this.currentCitizen.serverId || this.currentCitizen.id;
                    post('mdcUnjail', { targetId });
                }
            });

            $('#mdc-act-bolo')?.addEventListener('click', () => {
                if (this.currentCitizen) {
                    if (this.currentCitizen.bolo) {
                        post('mdcToggleBolo', { type: 'citizen', key: this.currentCitizen.name });
                    } else {
                        this.openBoloModal('citizen', this.currentCitizen.name, 'Suspect wanted in connection with felony investigation');
                    }
                }
            });

            // Speed Radar Controls
            $$('.mdc-preset-chip').forEach((chip) => {
                chip.addEventListener('click', () => {
                    $$('.mdc-preset-chip').forEach((c) => c.classList.remove('is-active'));
                    chip.classList.add('is-active');
                    const limit = Number(chip.dataset.limit) || 90;
                    const input = $('#mdc-radar-custom-input');
                    if (input) input.value = limit;
                    const display = $('#mdc-radar-limit-val');
                    if (display) display.innerHTML = `${limit} <small>KM/H</small>`;
                });
            });

            $('#mdc-btn-radar-start')?.addEventListener('click', () => {
                const limit = Number($('#mdc-radar-custom-input')?.value) || 90;
                post('mdcStartRadar', { limitKmh: limit });
            });

            $('#mdc-btn-radar-stop')?.addEventListener('click', () => {
                post('mdcStopRadar');
            });

            $$('.btn-fixed-radar-gps').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const x = Number(btn.dataset.x);
                    const y = Number(btn.dataset.y);
                    if (x && y) post('mdcSetWaypoint', { x, y });
                });
            });

            // Dialog Modals Close buttons
            $$('.mdc-dialog-close, [data-close]').forEach((btn) => {
                btn.addEventListener('click', () => this.closeDialogs());
            });

            $('#mdc-dialog-overlay')?.addEventListener('click', (e) => {
                if (e.target === $('#mdc-dialog-overlay')) this.closeDialogs();
            });

            // BOLO Modal Preset Chips
            $$('#mdc-bolo-chips .mdc-chip').forEach((chip) => {
                chip.addEventListener('click', () => {
                    $$('#mdc-bolo-chips .mdc-chip').forEach((c) => c.classList.remove('is-active'));
                    chip.classList.add('is-active');
                    const reason = chip.dataset.reason;
                    const input = $('#mdc-bolo-custom-reason');
                    if (input) input.value = reason;
                });
            });

            // BOLO Modal Confirm
            $('#mdc-bolo-confirm')?.addEventListener('click', () => {
                if (!this.currentBoloTarget) return;
                const reason = $('#mdc-bolo-custom-reason')?.value?.trim() || 'Active law enforcement BOLO broadcast';
                post('mdcToggleBolo', {
                    type: this.currentBoloTarget.type,
                    key: this.currentBoloTarget.key,
                    reason: reason,
                });
                this.closeDialogs();
            });

            // Wanted Modal Confirm
            $('#mdc-wanted-confirm')?.addEventListener('click', () => {
                if (!this.selectedChargeCode || !this.targetModalPlayerId) return;
                post('mdcSetWanted', {
                    targetId: this.targetModalPlayerId,
                    reasonCode: this.selectedChargeCode,
                });
                this.closeDialogs();
            });

            // Ticket Modal Confirm
            $('#mdc-ticket-confirm')?.addEventListener('click', () => {
                if (!this.selectedViolationCode || !this.targetModalPlayerId) return;
                const viol = this.violations.find((v) => v.code === this.selectedViolationCode);
                if (!viol) return;
                post('mdcIssueCitation', {
                    targetId: this.targetModalPlayerId,
                    amount: viol.amount,
                    reason: viol.label,
                    reasonCode: viol.code,
                });
                this.closeDialogs();
            });

            // License Modal Chips & Confirm
            $$('#mdc-license-type-chips .mdc-chip').forEach((chip) => {
                chip.addEventListener('click', () => {
                    $$('#mdc-license-type-chips .mdc-chip').forEach((c) => c.classList.remove('is-active'));
                    chip.classList.add('is-active');
                    this.selectedLicenseType = chip.dataset.lic || 'driver';
                });
            });

            $$('#mdc-license-reason-chips .mdc-chip').forEach((chip) => {
                chip.addEventListener('click', () => {
                    $$('#mdc-license-reason-chips .mdc-chip').forEach((c) => c.classList.remove('is-active'));
                    chip.classList.add('is-active');
                    const reason = chip.dataset.reason;
                    const input = $('#mdc-license-custom-reason');
                    if (input) input.value = reason;
                });
            });

            $('#mdc-license-confirm')?.addEventListener('click', () => {
                if (!this.targetModalPlayerId) return;
                const reason = $('#mdc-license-custom-reason')?.value?.trim() || 'Viteză excesivă (+50 km/h) / Conducere pe contrasens';
                const licType = this.selectedLicenseType || 'driver';
                post('mdcSuspendLicense', {
                    targetId: this.targetModalPlayerId,
                    licenseType: licType,
                    reason: reason,
                });
                this.closeDialogs();
            });

            // 112 Dispatch Modal
            $('#dispatch-112-cancel')?.addEventListener('click', () => this.close112());
            $('#dispatch-112-submit')?.addEventListener('click', () => this.submit112());
            $('#dispatch-112-details')?.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.submit112();
                }
            });

            $('#dispatch-112-modal')?.addEventListener('click', (e) => {
                if (e.target === $('#dispatch-112-modal')) this.close112();
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
                    if (!$('#mdc-dialog-overlay')?.classList.contains('hidden')) {
                        this.closeDialogs();
                    } else if (!$('#dispatch-112-modal')?.classList.contains('hidden')) {
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
            this.reasons = data.reasons || [];
            this.violations = data.violations || [];
            this.hasActiveBackup = data.hasActiveBackup || false;
            this.activeBackupId = data.activeBackupId || null;
            this.radarActive = data.radarActive || false;
            this.radarLimit = data.radarLimit || 90;

            // Apply Department Theme
            const tabletEl = $('#mdc-tablet-box');
            if (tabletEl) {
                tabletEl.className = 'mdc-tablet';
                const dept = (this.officer.department || 'police').toLowerCase();
                if (dept === 'sheriff') tabletEl.classList.add('theme--sheriff');
                else if (dept === 'fib') tabletEl.classList.add('theme--fib');
                else tabletEl.classList.add('theme--police');
            }

            // Update Department Badge
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

            // Update Officer Profile
            const offName = $('#mdc-officer-name');
            if (offName) offName.textContent = this.officer.name || 'Officer';

            const offRank = $('#mdc-officer-rank');
            if (offRank) offRank.textContent = `${this.officer.rank || 'Officer'} · ${this.officer.shortDept || 'LSPD'}`;

            const statusSelect = $('#mdc-status-selector');
            if (statusSelect) statusSelect.value = this.officer.status || '10-8';

            // Update Backup State
            this.updateBackupState();

            // Update Radar State
            this.updateRadarState();

            // Live Clock
            this.startClock();

            // Render Views
            this.renderCalls();
            this.renderWanted();
            this.renderUnits();

            // Default to calls tab
            this.setTab('calls');

            $('#mdc')?.classList.remove('hidden');
        },

        refresh(data = {}) {
            if (data.calls) this.calls = data.calls;
            if (data.wanted) this.wanted = data.wanted;
            if (data.units) this.units = data.units;
            if (data.bolos) this.bolos = data.bolos;
            if (data.reasons) this.reasons = data.reasons;
            if (data.violations) this.violations = data.violations;
            if (typeof data.hasActiveBackup !== 'undefined') this.hasActiveBackup = data.hasActiveBackup;
            if (data.activeBackupId) this.activeBackupId = data.activeBackupId;
            if (typeof data.radarActive !== 'undefined') this.radarActive = data.radarActive;
            if (data.radarLimit) this.radarLimit = data.radarLimit;
            if (data.officer) this.officer = data.officer;

            this.updateBackupState();
            this.updateRadarState();
            this.renderCalls();
            this.renderWanted();
            this.renderUnits();
        },

        updateBackupState() {
            const badge = $('#mdc-backup-badge');
            const cancelBtn = $('#mdc-backup-cancel-btn');
            if (badge) {
                if (this.hasActiveBackup) badge.classList.remove('hidden');
                else badge.classList.add('hidden');
            }
            if (cancelBtn) {
                if (this.hasActiveBackup) cancelBtn.classList.remove('hidden');
                else cancelBtn.classList.add('hidden');
            }
        },

        updateRadarState() {
            const indicator = $('#mdc-radar-indicator');
            const stateText = $('#mdc-radar-state-text');
            const startBtn = $('#mdc-btn-radar-start');
            const stopBtn = $('#mdc-btn-radar-stop');
            const limitVal = $('#mdc-radar-limit-val');

            if (indicator) {
                if (this.radarActive) indicator.classList.add('is-active');
                else indicator.classList.remove('is-active');
            }
            if (stateText) {
                stateText.textContent = this.radarActive ? 'RADAR ACTIVE & SCANNING' : 'RADAR INACTIVE';
            }
            if (startBtn && stopBtn) {
                if (this.radarActive) {
                    startBtn.classList.add('hidden');
                    stopBtn.classList.remove('hidden');
                } else {
                    startBtn.classList.remove('hidden');
                    stopBtn.classList.add('hidden');
                }
            }
            if (limitVal) {
                limitVal.innerHTML = `${this.radarLimit || 90} <small>KM/H</small>`;
            }
        },

        hide() {
            $('#mdc')?.classList.add('hidden');
            this.closeDialogs();
            if (this.clockInterval) clearInterval(this.clockInterval);
            this.clockInterval = null;
        },

        close() {
            this.hide();
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
                if (cat.includes('shot') || cat.includes('robbery') || cat.includes('assault') || cat.includes('distress') || cat.includes('panic')) return 'mdc-call-card--shots';
                if (cat.includes('medical') || cat.includes('injury')) return 'mdc-call-card--medical';
                if (cat.includes('fire') || cat.includes('explosion')) return 'mdc-call-card--fire';
                return 'mdc-call-card--traffic';
            };

            container.innerHTML = openCalls.map((call) => {
                const catClass = getCategoryStyle(call.category);
                const isAssigned = call.status === 'ASSIGNED' || call.status === 'IN_PROGRESS';
                return `
                    <div class="mdc-call-card ${catClass} ${call.isPanic ? 'mdc-call-card--panic' : ''}">
                        <div class="mdc-call-card__head">
                            <div style="display: flex; align-items: center; gap: 8px;">
                                <span class="mdc-call-id">#${call.id}</span>
                                <span class="mdc-call-category">${call.category || 'Emergency'}</span>
                                ${call.isPanic ? '<span class="mdc-pill mdc-pill--wanted" style="animation: mdcBlink 0.8s infinite;">🚨 10-99 PANIC</span>' : ''}
                            </div>
                            <span class="mdc-call-status ${isAssigned ? 'is-assigned' : 'is-pending'}">
                                ${call.status || 'PENDING'}
                            </span>
                        </div>
                        <div class="mdc-call-desc">${call.description || 'No details provided'}</div>
                        <div class="mdc-call-meta">
                            <span>📍 <strong>${call.street}</strong>, ${call.area}</span>
                            <span>👤 Caller: <strong>${call.callerName}</strong> (${call.callerPhone})</span>
                            ${call.responderName ? `<span>🚔 Unit: <strong>${call.responderName}</strong></span>` : ''}
                        </div>
                        <div class="mdc-call-actions">
                            <button type="button" class="mdc-btn mdc-btn--outline mdc-btn--sm btn-call-waypoint" data-x="${call.coords.x}" data-y="${call.coords.y}">
                                <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="12 8 8 12 12 16 12 8"/></svg>
                                SET GPS
                            </button>
                            ${!call.isResponder ? `
                                <button type="button" class="mdc-btn mdc-btn--primary mdc-btn--sm btn-call-respond" data-call-id="${call.id}">
                                    <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                                    RESPOND (10-97)
                                </button>
                            ` : `
                                <button type="button" class="mdc-btn mdc-btn--success mdc-btn--sm btn-call-clear" data-call-id="${call.id}">
                                    <svg class="mdc-btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                                    COMPLETE (10-98)
                                </button>
                            `}
                        </div>
                    </div>
                `;
            }).join('');

            // Attach event listeners
            container.querySelectorAll('.btn-call-waypoint').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const x = Number(btn.dataset.x);
                    const y = Number(btn.dataset.y);
                    if (x && y) post('mdcSetWaypoint', { x, y });
                });
            });

            container.querySelectorAll('.btn-call-respond').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const id = Number(btn.dataset.callId);
                    post('mdcSetCallStatus', { callId: id, action: 'respond' });
                });
            });

            container.querySelectorAll('.btn-call-clear').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const id = Number(btn.dataset.callId);
                    post('mdcSetCallStatus', { callId: id, action: 'clear' });
                });
            });
        },

        // ======================================================================
        // TAB 2: CITIZEN LOOKUP & CRIMINAL DOSSIER
        // ======================================================================
        searchCitizen(query) {
            $('#mdc-citizen-loading')?.classList.remove('hidden');
            $('#mdc-citizen-empty')?.classList.add('hidden');
            $('#mdc-citizen-content')?.classList.add('hidden');
            post('mdcSearch', { query });
        },

        updateCitizen(citizen) {
            $('#mdc-citizen-loading')?.classList.add('hidden');
            if (!citizen || !citizen.found) {
                $('#mdc-citizen-empty')?.classList.remove('hidden');
                $('#mdc-citizen-content')?.classList.add('hidden');
                this.currentCitizen = null;
                return;
            }

            this.currentCitizen = citizen;
            $('#mdc-citizen-empty')?.classList.add('hidden');
            $('#mdc-citizen-content')?.classList.remove('hidden');

            // ID Details
            $('#mdc-cit-name').textContent = citizen.name || 'Unknown';
            $('#mdc-cit-doc-id').textContent = `DOC ID: SA-${String(citizen.id).padStart(4, '0')}`;
            $('#mdc-cit-id').textContent = `#${citizen.id}`;
            $('#mdc-cit-server-id').textContent = citizen.isOnline ? `ONLINE (#${citizen.serverId})` : 'OFFLINE';
            $('#mdc-cit-server-id').style.color = citizen.isOnline ? '#10b981' : '#64748b';
            $('#mdc-cit-dob').textContent = citizen.dob || '—';
            $('#mdc-cit-gender').textContent = citizen.gender || '—';
            $('#mdc-cit-nat').textContent = citizen.nationality || 'San Andreas';
            $('#mdc-cit-phone').textContent = citizen.phone || '—';
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

            // Update Action Buttons State
            const boloBtn = $('#mdc-act-bolo');
            if (boloBtn) {
                boloBtn.textContent = citizen.bolo ? '🚨 CLEAR BOLO' : '🚨 FLAG BOLO';
            }

            const unjailBtn = $('#mdc-act-unjail');
            if (unjailBtn) {
                unjailBtn.style.opacity = citizen.jailed ? '1' : '0.5';
            }

            const clearBtn = $('#mdc-act-clear');
            if (clearBtn) {
                clearBtn.style.opacity = citizen.wanted ? '1' : '0.5';
            }

            // Licenses
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

            // Personal Vehicles
            const vehContainer = $('#mdc-cit-vehicles');
            if (vehContainer) {
                const vehicles = citizen.vehicles || [];
                if (vehicles.length === 0) {
                    vehContainer.innerHTML = '<div style="color: #64748b; font-size: 12px;">No vehicles registered to this citizen.</div>';
                } else {
                    vehContainer.innerHTML = vehicles.map((v) => `
                        <div class="mdc-veh-row btn-view-veh-plate" data-plate="${v.plate}" style="cursor: pointer;">
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

                    vehContainer.querySelectorAll('.btn-view-veh-plate').forEach((row) => {
                        row.addEventListener('click', () => {
                            const plate = row.dataset.plate;
                            if (plate) {
                                this.setTab('vehicles');
                                const input = $('#mdc-input-veh');
                                if (input) input.value = plate;
                                this.searchVehicle(plate);
                            }
                        });
                    });
                }
            }

            // Cazier History
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

            // Citations History
            const finesTotal = $('#mdc-cit-unpaid-fines');
            if (finesTotal) finesTotal.textContent = `$${(citizen.unpaidFines || 0).toLocaleString()}`;

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
                const tune = v.tuningInfo;
                let tuningHtml = '';
                if (tune && tune.tuned) {
                    const chips = (tune.chips || []).slice(0, 6).map((c) => `<span class="mdc-chip-tune">${c}</span>`).join('');
                    const lines = (tune.lines || []).slice(0, 8).map((l) => `<div class="mdc-tune-line"><span>${l.label}:</span><strong>${l.value}</strong></div>`).join('');
                    const mods = (tune.hardwareMods || []).map((m) => `<div class="mdc-tune-line mdc-tune-mod"><span>🔧 Mod:</span><strong>${m}</strong></div>`).join('');
                    tuningHtml = `
                        <div class="mdc-dmv-tuning-box is-tuned">
                            <div class="mdc-tuning-header">
                                <span class="mdc-tuning-badge is-tuned">⚡ VEHICUL MODIFICAT / STAGE TUNE</span>
                                <button type="button" class="mdc-tuning-toggle-btn" data-plate="${v.plate}">Fișă RAR ▼</button>
                            </div>
                            <div class="mdc-tuning-chips">${chips}</div>
                            <div class="mdc-tuning-details hidden" id="tune-details-${v.plate}">
                                <div class="mdc-tuning-summary">${tune.summary || 'Modificări ECU / Motor'}</div>
                                <div class="mdc-tuning-grid">
                                    ${lines}
                                    ${mods}
                                </div>
                            </div>
                        </div>
                    `;
                } else if (tune) {
                    const mods = (tune.hardwareMods || []).map((m) => `<div class="mdc-tune-line mdc-tune-mod"><span>🔧 Mod:</span><strong>${m}</strong></div>`).join('');
                    tuningHtml = `
                        <div class="mdc-dmv-tuning-box is-stock">
                            <div class="mdc-tuning-header">
                                <span class="mdc-tuning-badge is-stock">✓ FACTORY STOCK (OMOLOGAT RAR)</span>
                            </div>
                            ${mods ? `<div class="mdc-tuning-grid" style="margin-top: 4px;">${mods}</div>` : ''}
                        </div>
                    `;
                } else {
                    tuningHtml = `
                        <div class="mdc-dmv-tuning-box is-stock">
                            <div class="mdc-tuning-header">
                                <span class="mdc-tuning-badge is-stock">✓ FACTORY STOCK (OMOLOGAT RAR)</span>
                            </div>
                        </div>
                    `;
                }

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
                        ${tuningHtml}
                        <div style="display: flex; gap: 8px; margin-top: 6px;">
                            <button type="button" class="mdc-btn ${v.bolo ? 'mdc-btn--danger' : 'mdc-btn--warning'} mdc-btn--sm btn-toggle-veh-bolo" data-plate="${v.plate}" data-has-bolo="${v.bolo ? '1' : '0'}">
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

            // Toggle Tuning Details
            grid.querySelectorAll('.mdc-tuning-toggle-btn').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const plate = btn.dataset.plate;
                    const details = $(`#tune-details-${plate}`);
                    if (details) {
                        const isHidden = details.classList.toggle('hidden');
                        btn.textContent = isHidden ? 'Fișă RAR ▼' : 'Închide ▲';
                    }
                });
            });

            // Attach In-UI BOLO Toggle (NO PROMPT EVER)
            grid.querySelectorAll('.btn-toggle-veh-bolo').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const plate = btn.dataset.plate;
                    const hasBolo = btn.dataset.hasBolo === '1';
                    if (hasBolo) {
                        post('mdcToggleBolo', { type: 'vehicle', key: plate });
                    } else {
                        this.openBoloModal('vehicle', plate, 'Stolen vehicle reported by owner');
                    }
                });
            });

            grid.querySelectorAll('.btn-goto-owner, .btn-dossier-owner').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const owner = btn.dataset.owner;
                    if (owner && owner !== 'Unknown / Impounded') {
                        this.setTab('citizen');
                        const input = $('#mdc-input-citizen');
                        if (input) input.value = owner;
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
                            <button type="button" class="mdc-btn mdc-btn--danger mdc-btn--sm btn-clear-wanted" data-target-id="${row.id}">
                                ✕ CLEAR
                            </button>
                        </div>
                    </div>
                `;
            }).join('');

            container.querySelectorAll('.btn-locate-wanted').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const id = Number(btn.dataset.targetId);
                    if (id) post('mdcFindWanted', { targetId: id });
                });
            });

            container.querySelectorAll('.btn-clear-wanted').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const id = Number(btn.dataset.targetId);
                    if (id) post('mdcClearWanted', { targetId: id });
                });
            });

            container.querySelectorAll('.btn-view-wanted-cit').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const name = btn.dataset.name;
                    this.setTab('citizen');
                    const input = $('#mdc-input-citizen');
                    if (input) input.value = name;
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
                const hasCoords = unit.coords && unit.coords.x && unit.coords.y;
                return `
                    <div class="mdc-unit-card" style="display: flex; align-items: center; justify-content: space-between;">
                        <div>
                            <div style="font-size: 14px; font-weight: 700; color: #f8fafc;">
                                ${unit.name} ${unit.isMe ? '<span style="color: #38bdf8; font-size: 11px;">(YOU)</span>' : ''}
                            </div>
                            <div style="font-size: 11px; color: #94a3b8; text-transform: uppercase;">
                                ${unit.rank} · ${unit.shortDept || 'LSPD'}
                            </div>
                        </div>
                        <div style="display: flex; align-items: center; gap: 10px;">
                            ${hasCoords && !unit.isMe ? `
                                <button type="button" class="mdc-btn mdc-btn--outline mdc-btn--sm btn-unit-gps" data-x="${unit.coords.x}" data-y="${unit.coords.y}" data-name="${unit.name}">
                                    📍 GPS
                                </button>
                            ` : ''}
                            <span class="mdc-unit-status-tag ${statusClass}">
                                ${unit.status || '10-8'}
                            </span>
                        </div>
                    </div>
                `;
            }).join('');

            container.querySelectorAll('.btn-unit-gps').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const x = Number(btn.dataset.x);
                    const y = Number(btn.dataset.y);
                    const name = btn.dataset.name;
                    if (x && y) post('mdcSetUnitWaypoint', { x, y, name });
                });
            });
        },

        // ======================================================================
        // IN-UI DIALOG MODALS (NO PROMPT EVER)
        // ======================================================================
        closeDialogs() {
            $('#mdc-dialog-overlay')?.classList.add('hidden');
            $$('.mdc-dialog-card').forEach((c) => c.classList.add('hidden'));
            this.currentBoloTarget = null;
            this.selectedChargeCode = null;
            this.selectedViolationCode = null;
            this.targetModalPlayerId = null;
        },

        openBoloModal(type, key, defaultReason = '') {
            this.currentBoloTarget = { type, key };
            const overlay = $('#mdc-dialog-overlay');
            const card = $('#mdc-dialog-bolo');
            const title = $('#mdc-bolo-title');
            const targetLabel = $('#mdc-bolo-target-label');
            const customInput = $('#mdc-bolo-custom-reason');

            if (title) title.textContent = type === 'vehicle' ? `🚨 Flag Vehicle BOLO: ${key}` : `🚨 Flag Citizen BOLO: ${key}`;
            if (targetLabel) targetLabel.textContent = `Target: ${key} (${type.toUpperCase()})`;
            if (customInput) customInput.value = defaultReason || '';

            $$('#mdc-bolo-chips .mdc-chip').forEach((c) => c.classList.remove('is-active'));

            overlay?.classList.remove('hidden');
            card?.classList.remove('hidden');
        },

        openWantedModal(targetId, targetName) {
            this.targetModalPlayerId = targetId;
            this.selectedChargeCode = null;

            const overlay = $('#mdc-dialog-overlay');
            const card = $('#mdc-dialog-wanted');
            const label = $('#mdc-wanted-target-label');
            const confirmBtn = $('#mdc-wanted-confirm');
            const listContainer = $('#mdc-charges-list');

            if (label) label.textContent = `Suspect: ${targetName} (#${targetId})`;
            if (confirmBtn) confirmBtn.disabled = true;

            const charges = this.reasons.length > 0 ? this.reasons : [
                { code: 'speeding', label: 'Speeding', stars: 1, jailMinutes: 4 },
                { code: 'reckless', label: 'Reckless Driving', stars: 2, jailMinutes: 8 },
                { code: 'assault', label: 'Assault', stars: 2, jailMinutes: 8 },
                { code: 'robbery', label: 'Armed Robbery', stars: 5, jailMinutes: 25 },
                { code: 'evading', label: 'Runner / Evading Police', stars: 5, jailMinutes: 25 },
                { code: 'murder', label: 'Homicide / Murder', stars: 5, jailMinutes: 50 },
            ];

            if (listContainer) {
                listContainer.innerHTML = charges.map((ch) => {
                    const stars = '★'.repeat(Math.min(5, ch.stars || 1));
                    return `
                        <div class="mdc-select-item" data-code="${ch.code}">
                            <div>
                                <div style="font-weight: 700; color: #f8fafc;">${ch.label}</div>
                                <div style="font-size: 11px; color: #94a3b8;">Sentence: ~${ch.jailMinutes || 5} min jail · ${ch.surrenderable !== false ? 'Surrender Allowed' : 'No Surrender'}</div>
                            </div>
                            <span style="font-size: 14px; font-weight: 800; color: #f59e0b;">${stars}</span>
                        </div>
                    `;
                }).join('');

                listContainer.querySelectorAll('.mdc-select-item').forEach((item) => {
                    item.addEventListener('click', () => {
                        listContainer.querySelectorAll('.mdc-select-item').forEach((i) => i.classList.remove('is-selected'));
                        item.classList.add('is-selected');
                        this.selectedChargeCode = item.dataset.code;
                        if (confirmBtn) confirmBtn.disabled = false;
                    });
                });
            }

            overlay?.classList.remove('hidden');
            card?.classList.remove('hidden');
        },

        openTicketModal(targetId, targetName) {
            this.targetModalPlayerId = targetId;
            this.selectedViolationCode = null;

            const overlay = $('#mdc-dialog-overlay');
            const card = $('#mdc-dialog-ticket');
            const label = $('#mdc-ticket-target-label');
            const confirmBtn = $('#mdc-ticket-confirm');
            const listContainer = $('#mdc-violations-list');

            if (label) label.textContent = `Citizen: ${targetName} (#${targetId})`;
            if (confirmBtn) confirmBtn.disabled = true;

            const violations = this.violations.length > 0 ? this.violations : [
                { code: 'speeding', label: 'Exceeding Speed Limit', amount: 180 },
                { code: 'redlight', label: 'Running Red Traffic Light', amount: 240 },
                { code: 'reckless', label: 'Reckless Driving', amount: 420 },
                { code: 'parking', label: 'Illegal Vehicle Parking', amount: 90 },
                { code: 'noinsurance', label: 'Operating Without Insurance', amount: 600 },
                { code: 'disturbance', label: 'Public Peace Disturbance', amount: 300 },
            ];

            if (listContainer) {
                listContainer.innerHTML = violations.map((v) => {
                    return `
                        <div class="mdc-select-item" data-code="${v.code}">
                            <div>
                                <div style="font-weight: 700; color: #f8fafc;">${v.label}</div>
                                <div style="font-size: 11px; color: #94a3b8;">Violation Code: ${v.code}</div>
                            </div>
                            <span style="font-size: 14px; font-weight: 800; color: #10b981;">$${(v.amount || 100).toLocaleString()}</span>
                        </div>
                    `;
                }).join('');

                listContainer.querySelectorAll('.mdc-select-item').forEach((item) => {
                    item.addEventListener('click', () => {
                        listContainer.querySelectorAll('.mdc-select-item').forEach((i) => i.classList.remove('is-selected'));
                        item.classList.add('is-selected');
                        this.selectedViolationCode = item.dataset.code;
                        if (confirmBtn) confirmBtn.disabled = false;
                    });
                });
            }

            overlay?.classList.remove('hidden');
            card?.classList.remove('hidden');
        },

        openLicenseModal(targetId, targetName) {
            this.targetModalPlayerId = targetId;
            this.selectedLicenseType = 'driver';

            const overlay = $('#mdc-dialog-overlay');
            const card = $('#mdc-dialog-license');
            const label = $('#mdc-license-target-label');
            const customInput = $('#mdc-license-custom-reason');

            if (label) label.textContent = `Cetățean: ${targetName} (#${targetId})`;
            if (customInput) customInput.value = '';

            // Reset chips
            $$('#mdc-license-type-chips .mdc-chip').forEach((c, idx) => {
                if (idx === 0) c.classList.add('is-active');
                else c.classList.remove('is-active');
            });
            $$('#mdc-license-reason-chips .mdc-chip').forEach((c) => c.classList.remove('is-active'));

            overlay?.classList.remove('hidden');
            card?.classList.remove('hidden');
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
            const defaultCat = $('.dispatch-cat-btn[data-category="medical"]') || $('.dispatch-cat-btn[data-category="shots"]');
            if (defaultCat) defaultCat.classList.add('is-active');
            this.selected112Category = defaultCat ? (defaultCat.dataset.category || 'medical') : 'medical';

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
