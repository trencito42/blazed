/* ==========================================================================
   FLEECA BANK 24/7 ATM KIOSK — CLIENT LOGIC & PROCEDURAL SYNTHESIZER
   ========================================================================== */

(() => {
    'use strict';

    const $ = (sel) => document.querySelector(sel);
    const $$ = (sel) => Array.from(document.querySelectorAll(sel));

    const post = (event, data = {}) => {
        const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'sunset_ui';
        fetch(`https://${resource}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => {});
    };

    const showNotify = (msg, type = 'info') => {
        if (typeof notify === 'function') {
            notify(msg, type);
        } else if (window.SunsetUi?.Notify) {
            window.SunsetUi.Notify(msg, type);
        }
    };

    // --------------------------------------------------------------------------
    // PROCEDURAL WEB AUDIO SYNTHESIZER FOR ATM SOUNDS
    // --------------------------------------------------------------------------
    class AtmSoundFx {
        constructor() {
            this.ctx = null;
            this.muted = false;
        }

        ensureContext() {
            if (!this.ctx) {
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                if (AudioCtx) this.ctx = new AudioCtx();
            }
            if (this.ctx && this.ctx.state === 'suspended') {
                this.ctx.resume().catch(() => {});
            }
            return this.ctx;
        }

        // Crisp ATM keypad button beep
        playBeep(freq = 1400) {
            if (this.muted) return;
            const ctx = this.ensureContext();
            if (!ctx) return;

            try {
                const now = ctx.currentTime;
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();

                osc.type = 'sine';
                osc.frequency.setValueAtTime(freq, now);
                osc.frequency.exponentialRampToValueAtTime(freq * 0.85, now + 0.04);

                gain.gain.setValueAtTime(0.08, now);
                gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.045);

                osc.connect(gain);
                gain.connect(ctx.destination);

                osc.start(now);
                osc.stop(now + 0.05);
            } catch (e) {}
        }

        // Mechanical ATM note dispenser motor & bill counting flutter
        playCashCounting(durationMs = 1200) {
            if (this.muted) return;
            const ctx = this.ensureContext();
            if (!ctx) return;

            try {
                const now = ctx.currentTime;
                const bufferSize = ctx.sampleRate * (durationMs / 1000);
                const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
                const data = buffer.getChannelData(0);

                // Generate filtered rhythmic pulses (paper bills flipping through rollers)
                for (let i = 0; i < bufferSize; i++) {
                    const t = i / ctx.sampleRate;
                    const pulse = Math.sin(2 * Math.PI * 24 * t); // 24 bills per second
                    const noise = (Math.random() * 2 - 1) * (pulse > 0 ? pulse : 0.05);
                    data[i] = noise;
                }

                const noiseNode = ctx.createBufferSource();
                noiseNode.buffer = buffer;

                const filter = ctx.createBiquadFilter();
                filter.type = 'bandpass';
                filter.frequency.setValueAtTime(1200, now);
                filter.Q.setValueAtTime(2.5, now);

                const gain = ctx.createGain();
                gain.gain.setValueAtTime(0.12, now);
                gain.gain.linearRampToValueAtTime(0.14, now + (durationMs / 1000) * 0.8);
                gain.gain.exponentialRampToValueAtTime(0.001, now + (durationMs / 1000));

                noiseNode.connect(filter);
                filter.connect(gain);
                gain.connect(ctx.destination);

                noiseNode.start(now);
                noiseNode.stop(now + (durationMs / 1000));
            } catch (e) {}
        }

        // Card eject / Servo motor sound
        playCardEject() {
            if (this.muted) return;
            const ctx = this.ensureContext();
            if (!ctx) return;

            try {
                const now = ctx.currentTime;
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();

                osc.type = 'triangle';
                osc.frequency.setValueAtTime(420, now);
                osc.frequency.linearRampToValueAtTime(220, now + 0.12);

                gain.gain.setValueAtTime(0.09, now);
                gain.gain.exponentialRampToValueAtTime(0.001, now + 0.13);

                osc.connect(gain);
                gain.connect(ctx.destination);

                osc.start(now);
                osc.stop(now + 0.14);
            } catch (e) {}
        }

        // Transaction success banking confirmation chime
        playChime() {
            if (this.muted) return;
            const ctx = this.ensureContext();
            if (!ctx) return;

            try {
                const now = ctx.currentTime;
                const playTone = (f, start, dur) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(f, now + start);
                    gain.gain.setValueAtTime(0.09, now + start);
                    gain.gain.exponentialRampToValueAtTime(0.0001, now + start + dur);
                    osc.connect(gain);
                    gain.connect(ctx.destination);
                    osc.start(now + start);
                    osc.stop(now + start + dur);
                };
                playTone(880, 0, 0.15);     // A5
                playTone(1318.5, 0.1, 0.3); // E6
            } catch (e) {}
        }
    }

    // --------------------------------------------------------------------------
    // MAIN ATM MACHINE SINGLETON
    // --------------------------------------------------------------------------
    const AtmMachine = {
        isOpen: false,
        sound: new AtmSoundFx(),
        currentMode: 'DASHBOARD', // DASHBOARD, WITHDRAW, DEPOSIT, CUSTOM, PROCESSING, RECEIPT
        customAction: 'withdraw', // 'withdraw' or 'deposit'
        customAmount: '',
        lastTxData: null,
        clockTimer: null,

        data: {
            name: 'Citizen',
            cash: 0,
            bank: 0,
            cid: 1,
            account: 'LS82-FLCA-0042',
            card: '4532 •••• •••• 8291',
        },

        init() {
            if (this._initialized) return;
            this._initialized = true;

            this.bindEvents();
            this.startClock();
        },

        startClock() {
            const updateClock = () => {
                const now = new Date();
                const hh = String(now.getHours()).padStart(2, '0');
                const mm = String(now.getMinutes()).padStart(2, '0');
                const ss = String(now.getSeconds()).padStart(2, '0');
                const clockEl = $('#atm-clock');
                if (clockEl) clockEl.textContent = `${hh}:${mm}:${ss}`;

                const dateEl = $('#atm-date');
                if (dateEl) {
                    const day = String(now.getDate()).padStart(2, '0');
                    const month = String(now.getMonth() + 1).padStart(2, '0');
                    const year = now.getFullYear();
                    dateEl.textContent = `${day}.${month}.${year}`;
                }
            };
            updateClock();
            this.clockTimer = setInterval(updateClock, 1000);
        },

        bindEvents() {
            // Audio toggle button
            $('#atm-audio-toggle')?.addEventListener('click', () => {
                this.sound.muted = !this.sound.muted;
                const icon = $('#atm-audio-icon');
                if (icon) icon.textContent = this.sound.muted ? '🔇' : '🔊';
                this.sound.playBeep(800);
            });

            // Side FDK buttons
            $$('.atm-fdk-btn').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const slot = btn.dataset.fdk;
                    this.triggerFdkAction(slot);
                    this.animateButtonPress(btn);
                });
            });

            // Metallic Keypad buttons
            $$('.atm-key').forEach((key) => {
                key.addEventListener('click', () => {
                    const k = key.dataset.key;
                    this.handleKeypadInput(k);
                    this.animateButtonPress(key);
                });
            });

            // Physical Card Click -> Eject card
            $('#atm-phys-card')?.addEventListener('click', () => {
                this.close();
            });

            // Receipt modal close
            $('#atm-receipt-close')?.addEventListener('click', () => {
                this.sound.playBeep(1200);
                this.switchPane('DASHBOARD');
            });

            // Custom amount input direct change
            $('#atm-custom-amount-input')?.addEventListener('input', (e) => {
                const val = e.target.value.replace(/\D/g, '').slice(0, 12);
                this.customAmount = val;
                e.target.value = val ? Number(val).toLocaleString('en-US') : '';
            });

            // Global Keyboard Handler while ATM is open
            window.addEventListener('keydown', (e) => {
                if (!this.isOpen) return;

                if (e.key === 'Escape') {
                    e.preventDefault();
                    this.close();
                    return;
                }

                if (this.currentMode === 'CUSTOM') {
                    if (e.key >= '0' && e.key <= '9') {
                        e.preventDefault();
                        this.handleKeypadInput(e.key);
                    } else if (e.key === 'Backspace') {
                        e.preventDefault();
                        this.handleKeypadInput('CLEAR');
                    } else if (e.key === 'Enter') {
                        e.preventDefault();
                        this.handleKeypadInput('ENTER');
                    }
                } else {
                    if (e.key === 'Enter') {
                        e.preventDefault();
                    }
                }
            });
        },

        animateButtonPress(el) {
            el.classList.add('is-pressed');
            setTimeout(() => el.classList.remove('is-pressed'), 120);
        },

        // Format currency helper
        fmt(amount) {
            const n = Math.floor(Number(amount) || 0);
            return '$' + n.toLocaleString('en-US');
        },

        // ----------------------------------------------------------------------
        // OPEN & CLOSE MODAL
        // ----------------------------------------------------------------------
        open(payload = {}) {
            this.init();
            this.isOpen = true;

            // Merge incoming character/balance data
            this.data.name = payload.name || this.data.name || 'Citizen';
            this.data.cash = Number(payload.cash !== undefined ? payload.cash : this.data.cash || 0);
            this.data.bank = Number(payload.bank !== undefined ? payload.bank : this.data.bank || 0);
            this.data.cid = payload.cid || this.data.cid || 1;
            this.data.account = payload.account || this.data.account || `LS${this.data.cid}-FLCA-4082`;
            this.data.card = payload.card || this.data.card || '4532 •••• •••• 8291';

            this.updateUiBalances();
            this.switchPane('DASHBOARD');

            const modal = $('#atm-modal');
            if (modal) {
                modal.classList.remove('hidden');
                modal.setAttribute('aria-hidden', 'false');
            }

            // Play card inserted sound
            this.sound.playBeep(900);
            setTimeout(() => this.sound.playBeep(1400), 80);
        },

        close() {
            if (!this.isOpen) return;
            this.isOpen = false;

            this.sound.playCardEject();

            const modal = $('#atm-modal');
            if (modal) {
                modal.classList.add('hidden');
                modal.setAttribute('aria-hidden', 'true');
            }

            post('atmClose');
        },

        update(payload = {}) {
            if (payload.cash !== undefined) this.data.cash = Number(payload.cash);
            if (payload.bank !== undefined) this.data.bank = Number(payload.bank);
            if (payload.name) this.data.name = payload.name;

            this.updateUiBalances();

            if (payload.ok) {
                this.lastTxData = payload;
                this.sound.playChime();
                this.showDispenseAnimation(payload.action, payload.amount);
            } else if (payload.error) {
                this.sound.playBeep(400);
                setTimeout(() => this.sound.playBeep(300), 90);
                this.switchPane('DASHBOARD');
            }
        },

        updateUiBalances() {
            $('#atm-bank-balance').textContent = this.fmt(this.data.bank);
            $('#atm-cash-balance').textContent = this.fmt(this.data.cash);
            $('#atm-cardholder-name').textContent = this.data.name;
            $('#atm-cardholder-num').textContent = this.data.card;
            $('#atm-cardholder-iban').textContent = this.data.account;

            // Physical card in reader slot
            $('#atm-phys-card-name').textContent = this.data.name;
            $('#atm-phys-card-num').textContent = this.data.card;
        },

        // ----------------------------------------------------------------------
        // SWITCH SCREENS / VIEWS
        // ----------------------------------------------------------------------
        switchPane(paneName) {
            this.currentMode = paneName;

            $$('.atm-pane').forEach((p) => p.classList.add('hidden'));
            $('#atm-receipt-modal')?.classList.add('hidden');

            const target = $(`#atm-pane-${paneName.toLowerCase()}`);
            if (target) target.classList.remove('hidden');

            // Reset custom amount state
            if (paneName === 'CUSTOM') {
                this.customAmount = '';
                const input = $('#atm-custom-amount-input');
                if (input) {
                    input.value = '';
                    setTimeout(() => input.focus(), 60);
                }
            }
        },

        // ----------------------------------------------------------------------
        // FDK SIDE BUTTONS DISPATCHER
        // ----------------------------------------------------------------------
        triggerFdkAction(slot) {
            this.sound.playBeep(1200);

            // Based on current active screen, map FDK slot to action
            switch (this.currentMode) {
                case 'DASHBOARD':
                    if (slot === 'l1') this.switchPane('WITHDRAW');
                    else if (slot === 'l2') this.switchPane('DEPOSIT');
                    else if (slot === 'l3') this.showReceipt();
                    else if (slot === 'l4') this.close();
                    else if (slot === 'r1') this.executeQuickCash(50);
                    else if (slot === 'r2') this.executeQuickCash(100);
                    else if (slot === 'r3') this.executeQuickCash(500);
                    else if (slot === 'r4') this.openCustomAmount('withdraw');
                    break;

                case 'WITHDRAW':
                    if (slot === 'l1') this.executeQuickCash(50);
                    else if (slot === 'l2') this.executeQuickCash(100);
                    else if (slot === 'l3') this.executeQuickCash(250);
                    else if (slot === 'l4') this.executeQuickCash(500);
                    else if (slot === 'r1') this.executeQuickCash(1000);
                    else if (slot === 'r2') this.executeQuickCash(2500);
                    else if (slot === 'r3') this.openCustomAmount('withdraw');
                    else if (slot === 'r4') this.switchPane('DASHBOARD');
                    break;

                case 'DEPOSIT':
                    if (slot === 'l1') this.executeDeposit(100);
                    else if (slot === 'l2') this.executeDeposit(500);
                    else if (slot === 'l3') this.executeDeposit(1000);
                    else if (slot === 'l4') this.executeDepositAll();
                    else if (slot === 'r1') this.executeDeposit(2500);
                    else if (slot === 'r2') this.executeDeposit(5000);
                    else if (slot === 'r3') this.openCustomAmount('deposit');
                    else if (slot === 'r4') this.switchPane('DASHBOARD');
                    break;

                case 'CUSTOM':
                    if (slot === 'l4' || slot === 'r4') this.switchPane('DASHBOARD');
                    else if (slot === 'r1') this.submitCustomAmount();
                    break;

                default:
                    if (slot === 'l4' || slot === 'r4') this.switchPane('DASHBOARD');
                    break;
            }
        },

        // ----------------------------------------------------------------------
        // METALLIC KEYPAD INPUT HANDLER
        // ----------------------------------------------------------------------
        handleKeypadInput(key) {
            this.sound.playBeep(1500);

            if (key === 'CANCEL') {
                if (this.currentMode === 'CUSTOM' || this.currentMode === 'WITHDRAW' || this.currentMode === 'DEPOSIT') {
                    this.switchPane('DASHBOARD');
                } else {
                    this.close();
                }
                return;
            }

            if (key === 'CLEAR') {
                if (this.currentMode === 'CUSTOM') {
                    this.customAmount = '';
                    const input = $('#atm-custom-amount-input');
                    if (input) input.value = '';
                }
                return;
            }

            if (key === 'ENTER') {
                if (this.currentMode === 'CUSTOM') {
                    this.submitCustomAmount();
                }
                return;
            }

            // Numeric keys 0-9
            if (key >= '0' && key <= '9') {
                if (this.currentMode !== 'CUSTOM') {
                    // Open custom amount directly with this digit
                    this.openCustomAmount('withdraw');
                }

                if (this.customAmount.length < 12) {
                    this.customAmount += key;
                    const input = $('#atm-custom-amount-input');
                    if (input) {
                        input.value = Number(this.customAmount).toLocaleString('en-US');
                    }
                }
            }
        },

        // ----------------------------------------------------------------------
        // TRANSACTION ACTIONS
        // ----------------------------------------------------------------------
        executeQuickCash(amount) {
            if (this.data.bank < amount) {
                this.sound.playBeep(400);
                showNotify('Sold insuficient în contul bancar.', 'error');
                return;
            }
            this.startTransaction('withdraw', amount);
        },

        executeDeposit(amount) {
            if (this.data.cash < amount) {
                this.sound.playBeep(400);
                showNotify('Nu ai suficiente bancnote în numerar.', 'error');
                return;
            }
            this.startTransaction('deposit', amount);
        },

        executeDepositAll() {
            const amount = this.data.cash;
            if (amount < 1) {
                this.sound.playBeep(400);
                showNotify('Nu ai numerar disponibil pentru depunere.', 'warning');
                return;
            }
            this.startTransaction('deposit', amount);
        },

        openCustomAmount(action) {
            this.customAction = action;
            $('#atm-custom-title').textContent = action === 'withdraw' ? 'RETRAGERE NUMERAR — SUMĂ PERSONALIZATĂ' : 'DEPUNERE NUMERAR — SUMĂ PERSONALIZATĂ';
            $('#atm-custom-submit-label').textContent = action === 'withdraw' ? 'Confirmă Retragerea' : 'Confirmă Depunerea';
            this.switchPane('CUSTOM');
        },

        submitCustomAmount() {
            const amount = Number(this.customAmount || 0);
            if (amount < 1) {
                this.sound.playBeep(400);
                showNotify('Introdu o sumă validă mai mare decât $0.', 'warning');
                return;
            }

            if (this.customAction === 'withdraw' && this.data.bank < amount) {
                this.sound.playBeep(400);
                showNotify('Sold insuficient în contul bancar.', 'error');
                return;
            }

            if (this.customAction === 'deposit' && this.data.cash < amount) {
                this.sound.playBeep(400);
                showNotify('Nu ai suficient numerar în portofel.', 'error');
                return;
            }

            this.startTransaction(this.customAction, amount);
        },

        startTransaction(action, amount) {
            this.switchPane('PROCESSING');

            $('#atm-proc-action').textContent = action === 'withdraw' ? 'RETRAGERE NUMERAR' : 'DEPUNERE NUMERAR';
            $('#atm-proc-amount').textContent = this.fmt(amount);
            $('#atm-proc-status').textContent = 'Se contactează banca... Numărare bancnote în curs...';

            this.sound.playCashCounting(1300);

            // Shutter lighting animation
            const shutter = $('#atm-dispenser-shutter');
            shutter?.classList.add('is-active');

            // Send NUI action
            post('atmAction', { action: action, amount: amount });
        },

        showDispenseAnimation(action, amount) {
            const shutter = $('#atm-dispenser-shutter');
            shutter?.classList.add('is-dispensing');

            $('#atm-proc-status').textContent = action === 'withdraw'
                ? 'Tranzacție Aprobată! Vă rugăm ridicați numerarul din fanta de eliberare.'
                : 'Depunere Efectuată cu Succes! Fondurile au fost creditate în cont.';

            setTimeout(() => {
                shutter?.classList.remove('is-active', 'is-dispensing');
                this.switchPane('DASHBOARD');
            }, 2400);
        },

        showReceipt() {
            this.sound.playBeep(1300);

            const tx = this.lastTxData || {
                txId: 'TX-' + Math.floor(100000 + Math.random() * 900000),
                action: 'Inquiry',
                amount: 0,
            };

            const now = new Date();
            const timeStr = now.toLocaleTimeString('ro-RO');
            const dateStr = now.toLocaleDateString('ro-RO');

            $('#rcpt-date').textContent = `${dateStr} ${timeStr}`;
            $('#rcpt-txid').textContent = tx.txId || 'TX-902144';
            $('#rcpt-name').textContent = this.data.name;
            $('#rcpt-account').textContent = this.data.account;
            $('#rcpt-action').textContent = (tx.action || 'INTEROGARE SOLD').toUpperCase();
            $('#rcpt-amount').textContent = tx.amount ? this.fmt(tx.amount) : '—';
            $('#rcpt-bank-balance').textContent = this.fmt(this.data.bank);
            $('#rcpt-cash-balance').textContent = this.fmt(this.data.cash);

            $('#atm-receipt-modal')?.classList.remove('hidden');
        },
    };

    window.AtmMachine = AtmMachine;
    document.addEventListener('DOMContentLoaded', () => AtmMachine.init());
})();
