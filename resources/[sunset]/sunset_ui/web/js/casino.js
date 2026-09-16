/* ═══ THE DIAMOND CASINO — NUI controller ═══ */

const Casino = {
    game: null,
    status: null,
    bet: 500,
    rouletteBetType: null,
    rouletteBetValue: null,
    playing: false,

    esc(value) {
        return String(value ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    },

    show(data) {
        this.game = data?.game || 'blackjack';
        this.status = data?.status || {};
        this.bet = this.status.minBet || 500;
        this.playing = false;
        this.rouletteBetType = null;
        this.rouletteBetValue = null;

        const el = $('#casino-overlay');
        if (!el) return;
        el.classList.remove('hidden');
        this.render();
    },

    hide() {
        const el = $('#casino-overlay');
        if (el) el.classList.add('hidden');
        this.game = null;
        this.playing = false;
    },

    render() {
        const title = $('#casino-title');
        const sub = $('#casino-sub');
        const body = $('#casino-body');
        if (!title || !body) return;

        const names = {
            blackjack: 'Blackjack', slots: 'Slot Machines', roulette: 'Roulette',
            luckywheel: 'Lucky Wheel', cashier: 'Cashier', bar: 'Bar',
        };
        title.textContent = names[this.game] || 'Casino';

        if (this.game === 'cashier') {
            sub.textContent = `Cash: $${(this.status.cash || 0).toLocaleString()} · Chips: ${(this.status.chips || 0).toLocaleString()}`;
        } else if (this.game === 'bar') {
            sub.textContent = `Cash: $${(this.status.cash || 0).toLocaleString()}`;
        } else {
            sub.textContent = `Chips: ${(this.status.chips || 0).toLocaleString()} · Min ${(this.status.minBet || 100).toLocaleString()} · Max ${(this.status.maxBet || 50000).toLocaleString()}`;
        }

        if (this.game === 'blackjack') this.renderBlackjack(body);
        else if (this.game === 'slots') this.renderSlots(body);
        else if (this.game === 'roulette') this.renderRoulette(body);
        else if (this.game === 'luckywheel') this.renderWheel(body);
        else if (this.game === 'cashier') this.renderCashier(body);
        else if (this.game === 'bar') this.renderBar(body);

        this.renderStatus();
    },

    renderStatus() {
        const el = $('#casino-status');
        if (!el) return;
        const chips = this.status.chips || 0;
        const loss = this.status.dailyLoss || 0;
        const limit = this.status.dailyLimit || 500000;
        if (this.game === 'cashier' || this.game === 'bar' || this.game === 'luckywheel') {
            el.innerHTML = `<span>Chips: <strong>${chips.toLocaleString()}</strong></span>`;
        } else {
            el.innerHTML = `
                <span>Chips: <strong>${chips.toLocaleString()}</strong></span>
                <span>Bet: <strong>${this.bet.toLocaleString()} Chips</strong></span>
            `;
        }
    },

    betControls() {
        const chips = [100, 500, 1000, 5000, 10000, 25000];
        return `
            <div class="casino-bet-row">
                <span class="casino-bet-label">Bet Chips</span>
                <input type="number" class="casino-bet-input" id="casino-bet" value="${this.bet}" min="${this.status.minBet || 100}" max="${this.status.maxBet || 50000}">
                ${chips.map((c) => `<button type="button" class="casino-bet-chip" data-casino-chip="${c}">${(c / 1000).toFixed(c < 1000 ? 0 : 0)}${c >= 1000 ? 'K' : ''}</button>`).join('')}
            </div>
        `;
    },

    bindBetChips() {
        $$('[data-casino-chip]').forEach((btn) => {
            btn.addEventListener('click', () => {
                this.bet = Number(btn.dataset.casinoChip);
                const input = $('#casino-bet');
                if (input) input.value = this.bet;
                this.renderStatus();
            });
        });
        $('#casino-bet')?.addEventListener('change', (e) => {
            this.bet = Math.max(this.status.minBet || 100, Math.min(this.status.maxBet || 50000, Number(e.target.value) || this.bet));
            e.target.value = this.bet;
            this.renderStatus();
        });
    },

    // ── BLACKJACK ──
    renderBlackjack(body) {
        body.innerHTML = `
            <div class="bj-table" id="bj-table">
                <div class="bj-hand">
                    <div class="bj-hand__label">Dealer</div>
                    <div class="bj-hand__cards" id="bj-dealer-cards"></div>
                    <div class="bj-hand__value" id="bj-dealer-value"></div>
                </div>
                <div class="bj-hand">
                    <div class="bj-hand__label">You</div>
                    <div class="bj-hand__cards" id="bj-player-cards"></div>
                    <div class="bj-hand__value" id="bj-player-value"></div>
                </div>
                <div id="bj-result"></div>
                ${this.betControls()}
                <div class="bj-actions" id="bj-actions">
                    <button type="button" class="casino-btn" id="bj-deal">Deal</button>
                </div>
            </div>
        `;
        this.bindBetChips();
        $('#bj-deal')?.addEventListener('click', () => {
            this.bet = Number($('#casino-bet')?.value) || this.bet;
            post('casinoBlackjackStart', { bet: this.bet });
        });
    },

    updateBlackjack(data) {
        const renderCards = (el, cards, hideSecond) => {
            if (!el) return;
            el.innerHTML = cards.map((c, i) => {
                if (hideSecond && i === 1) return '<div class="bj-card bj-card--hidden"></div>';
                const isRed = c.suit === '♥' || c.suit === '♦';
                return `<div class="bj-card ${isRed ? 'bj-card--red' : ''}">${this.esc(c.rank)}<span class="bj-card__suit">${this.esc(c.suit)}</span></div>`;
            }).join('');
        };

        renderCards($('#bj-player-cards'), data.playerHand || []);
        $('#bj-player-value').textContent = data.playerValue != null ? data.playerValue : '';

        if (data.chips !== undefined) this.status.chips = data.chips;

        if (data.state === 'settled' && data.settled) {
            renderCards($('#bj-dealer-cards'), data.settled.dealerHand || []);
            $('#bj-dealer-value').textContent = data.settled.dealerValue != null ? data.settled.dealerValue : '';

            const s = data.settled;
            if (s.chips !== undefined) this.status.chips = s.chips;
            const resultEl = $('#bj-result');
            const labels = {
                blackjack: `🃏 BLACKJACK! +${s.payout.toLocaleString()} Chips`,
                win: `✅ You win! +${s.payout.toLocaleString()} Chips`,
                dealer_bust: `💥 Dealer busts! +${s.payout.toLocaleString()} Chips`,
                push: '🤝 Push — bet returned',
                lose: `❌ Dealer wins. -${this.bet.toLocaleString()} Chips`,
                bust: `💀 Bust! -${this.bet.toLocaleString()} Chips`,
            };
            const cls = (s.result === 'blackjack' || s.result === 'win' || s.result === 'dealer_bust') ? 'win'
                : s.result === 'push' ? 'push' : 'lose';
            if (resultEl) resultEl.innerHTML = `<div class="bj-result bj-result--${cls}">${labels[s.result] || s.result}</div>`;

            const actions = $('#bj-actions');
            if (actions) actions.innerHTML = '<button type="button" class="casino-btn" id="bj-deal">New Hand</button>';
            $('#bj-deal')?.addEventListener('click', () => {
                this.bet = Number($('#casino-bet')?.value) || this.bet;
                $('#bj-result').innerHTML = '';
                $('#bj-dealer-cards').innerHTML = '';
                $('#bj-dealer-value').textContent = '';
                $('#bj-player-cards').innerHTML = '';
                $('#bj-player-value').textContent = '';
                post('casinoBlackjackStart', { bet: this.bet });
            });
        } else {
            renderCards($('#bj-dealer-cards'), data.dealerHand || [], true);
            $('#bj-dealer-value').textContent = data.dealerValue != null ? data.dealerValue : '';

            const actions = $('#bj-actions');
            if (actions) actions.innerHTML = `
                <button type="button" class="casino-btn" id="bj-hit">Hit</button>
                <button type="button" class="casino-btn casino-btn--secondary" id="bj-stand">Stand</button>
            `;
            $('#bj-hit')?.addEventListener('click', () => post('casinoBlackjackHit', {}));
            $('#bj-stand')?.addEventListener('click', () => post('casinoBlackjackStand', {}));
        }

        const sub = $('#casino-sub');
        if (sub && this.game === 'blackjack') {
            sub.textContent = `Chips: ${(this.status.chips || 0).toLocaleString()} · Min ${(this.status.minBet || 100).toLocaleString()} · Max ${(this.status.maxBet || 50000).toLocaleString()}`;
        }
        this.renderStatus();
    },

    // ── SLOTS ──
    renderSlots(body) {
        body.innerHTML = `
            <div class="slots-machine">
                <div class="slots-reels">
                    <div class="slots-reel" id="slot-1">🎰</div>
                    <div class="slots-reel" id="slot-2">🎰</div>
                    <div class="slots-reel" id="slot-3">🎰</div>
                </div>
                <div class="slots-result" id="slots-result"></div>
                ${this.betControls()}
                <button type="button" class="casino-btn" id="slots-spin">Spin</button>
            </div>
        `;
        this.bindBetChips();
        $('#slots-spin')?.addEventListener('click', () => {
            this.bet = Number($('#casino-bet')?.value) || this.bet;
            $('#slots-result').textContent = '';
            post('casinoSlotsSpin', { bet: this.bet });
        });
    },

    updateSlots(data) {
        const reels = data.reels || [];
        for (let i = 0; i < 3; i++) {
            const el = $(`#slot-${i + 1}`);
            if (el) el.textContent = reels[i] || '?';
        }
        if (data.chips !== undefined) this.status.chips = data.chips;
        const resultEl = $('#slots-result');
        if (resultEl) {
            if (data.payout > 0) {
                resultEl.className = 'slots-result slots-result--win';
                resultEl.textContent = `🎉 ${data.matches} match! +${data.payout.toLocaleString()} Chips`;
            } else {
                resultEl.className = 'slots-result slots-result--lose';
                resultEl.textContent = 'No match. Try again!';
            }
        }
        const sub = $('#casino-sub');
        if (sub && this.game === 'slots') {
            sub.textContent = `Chips: ${(this.status.chips || 0).toLocaleString()} · Min ${(this.status.minBet || 100).toLocaleString()} · Max ${(this.status.maxBet || 50000).toLocaleString()}`;
        }
        this.renderStatus();
    },

    // ── LUCKY WHEEL ──
    renderWheel(body) {
        const prizes = this.status.prizes || [];
        body.innerHTML = `
            <div class="wheel-container">
                <div class="wheel-disc" id="wheel-disc">
                    ${prizes.map((p, i) => {
                        const angle = (i / prizes.length) * 360;
                        return `<div class="wheel-segment" style="transform: rotate(${angle}deg)"><span>${this.esc(p.label)}</span></div>`;
                    }).join('')}
                </div>
                <div class="wheel-pointer">▼</div>
            </div>
            <div class="wheel-result" id="wheel-result"></div>
            <button type="button" class="casino-btn casino-btn--primary" id="wheel-spin">SPIN THE WHEEL</button>
            <p class="casino-hint">1 spin per hour · Free to spin</p>
        `;
        $('#wheel-spin')?.addEventListener('click', () => {
            const btn = $('#wheel-spin');
            if (btn) { btn.disabled = true; btn.textContent = 'SPINNING...'; }
            post('casinoWheelSpin', {});
        });
    },

    wheelResult(data) {
        const resultEl = $('#wheel-result');
        const disc = $('#wheel-disc');
        if (disc && data.prizeIndex !== undefined) {
            const prizes = this.status.prizes || [];
            const angle = 360 - (data.prizeIndex / prizes.length) * 360;
            disc.style.transition = 'transform 4s cubic-bezier(0.17, 0.67, 0.12, 0.99)';
            disc.style.transform = `rotate(${angle + 1440}deg)`;
        }
        if (resultEl && data.prize) {
            resultEl.className = 'slots-result slots-result--win';
            resultEl.textContent = `🎉 You won: ${this.esc(data.prize.label)}!`;
        }
        const btn = $('#wheel-spin');
        if (btn) { btn.disabled = true; btn.textContent = 'SPUN — COME BACK IN 1 HOUR'; }
    },

    // ── CASHIER ──
    renderCashier(body) {
        const cash = this.status.cash || 0;
        const chips = this.status.chips || 0;
        body.innerHTML = `
            <div class="cashier-panel">
                <div class="cashier-balance">
                    <div class="cashier-balance__item"><span>Cash</span><strong>$${cash.toLocaleString()}</strong></div>
                    <div class="cashier-balance__item"><span>Chips</span><strong>${chips.toLocaleString()}</strong></div>
                </div>
                <div class="cashier-section">
                    <h3>Buy Chips</h3>
                    <div class="cashier-row">
                        <input type="number" class="casino-bet-input" id="chips-buy-amount" value="1000" min="100" max="100000">
                        <button type="button" class="casino-btn casino-btn--primary" id="chips-buy">BUY</button>
                    </div>
                </div>
                <div class="cashier-section">
                    <h3>Sell Chips</h3>
                    <div class="cashier-row">
                        <input type="number" class="casino-bet-input" id="chips-sell-amount" value="1000" min="100">
                        <button type="button" class="casino-btn casino-btn--sell" id="chips-sell">SELL</button>
                    </div>
                </div>
                <p class="casino-hint">Exchange rate: $1 = 1 chip</p>
            </div>
        `;
        $('#chips-buy')?.addEventListener('click', () => {
            const amount = Number($('#chips-buy-amount')?.value) || 1000;
            post('casinoBuyChips', { amount });
        });
        $('#chips-sell')?.addEventListener('click', () => {
            const amount = Number($('#chips-sell-amount')?.value) || 1000;
            post('casinoSellChips', { amount });
        });
    },

    cashierUpdate(data) {
        if (data.totalChips !== undefined) this.status.chips = data.totalChips;
        if (data.remainingChips !== undefined) this.status.chips = data.remainingChips;
        if (data.cash !== undefined) this.status.cash = data.cash;
        // Re-render to refresh balance cards
        const sub = $('#casino-sub');
        if (sub) sub.textContent = `Cash: $${(this.status.cash || 0).toLocaleString()} · Chips: ${(this.status.chips || 0).toLocaleString()}`;
        const body = $('#casino-body');
        if (body) this.renderCashier(body);
        this.renderStatus();
    },

    // ── BAR ──
    renderBar(body) {
        const drinks = this.status.drinks || [];
        body.innerHTML = `
            <div class="bar-panel">
                ${drinks.map((d) => `
                    <div class="bar-item">
                        <div class="bar-item__info">
                            <span class="bar-item__name">${this.esc(d.label)}</span>
                            <span class="bar-item__effect">+${d.value} thirst</span>
                        </div>
                        <div class="bar-item__action">
                            <span class="bar-item__price">$${d.price}</span>
                            <button type="button" class="casino-btn casino-btn--primary" data-bar-drink="${this.esc(d.id)}">BUY</button>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
        $$('[data-bar-drink]').forEach((btn) => {
            btn.addEventListener('click', () => {
                post('casinoBuyDrink', { drinkId: btn.dataset.barDrink });
            });
        });
    },

    barUpdate(data) {
        this.status.cash = data.cash !== undefined ? data.cash : this.status.cash;
        this.renderStatus();
    },

    // ── ROULETTE ──
    renderRoulette(body) {
        const bets = [
            { type: 'red', label: '🔴 Red', cls: 'roulette-bet-btn--red' },
            { type: 'black', label: '⚫ Black', cls: 'roulette-bet-btn--black' },
            { type: 'odd', label: 'Odd' },
            { type: 'even', label: 'Even' },
            { type: 'low', label: '1-18' },
            { type: 'high', label: '19-36' },
            { type: 'dozen', value: 1, label: '1st 12' },
            { type: 'dozen', value: 2, label: '2nd 12' },
            { type: 'dozen', value: 3, label: '3rd 12' },
        ];
        body.innerHTML = `
            <div class="roulette-layout">
                <div class="roulette-wheel" id="roulette-wheel">?</div>
                <div class="roulette-bets">
                    ${bets.map((b) => `<button type="button" class="roulette-bet-btn ${b.cls || ''}" data-roulette-bet="${b.type}" data-roulette-value="${b.value || ''}">${b.label}</button>`).join('')}
                </div>
                <div class="slots-result" id="roulette-result"></div>
                ${this.betControls()}
                <button type="button" class="casino-btn" id="roulette-spin" disabled>Spin</button>
            </div>
        `;
        this.bindBetChips();

        $$('[data-roulette-bet]').forEach((btn) => {
            btn.addEventListener('click', () => {
                $$('[data-roulette-bet]').forEach((b) => b.classList.remove('is-selected'));
                btn.classList.add('is-selected');
                this.rouletteBetType = btn.dataset.rouletteBet;
                this.rouletteBetValue = btn.dataset.rouletteValue ? Number(btn.dataset.rouletteValue) : null;
                $('#roulette-spin').disabled = false;
            });
        });

        $('#roulette-spin')?.addEventListener('click', () => {
            this.bet = Number($('#casino-bet')?.value) || this.bet;
            $('#roulette-result').textContent = '';
            post('casinoRouletteSpin', { bet: this.bet, betType: this.rouletteBetType, betValue: this.rouletteBetValue });
        });
    },

    updateRoulette(data) {
        const wheel = $('#roulette-wheel');
        if (wheel) {
            wheel.textContent = data.result;
            wheel.className = `roulette-wheel roulette-wheel--${data.color}`;
        }
        if (data.chips !== undefined) this.status.chips = data.chips;
        const resultEl = $('#roulette-result');
        if (resultEl) {
            if (data.won) {
                resultEl.className = 'slots-result slots-result--win';
                resultEl.textContent = `🎉 ${data.result} ${data.color}! +${data.payout.toLocaleString()} Chips`;
            } else {
                resultEl.className = 'slots-result slots-result--lose';
                resultEl.textContent = `${data.result} ${data.color}. Better luck next time.`;
            }
        }
        const sub = $('#casino-sub');
        if (sub && this.game === 'roulette') {
            sub.textContent = `Chips: ${(this.status.chips || 0).toLocaleString()} · Min ${(this.status.minBet || 100).toLocaleString()} · Max ${(this.status.maxBet || 50000).toLocaleString()}`;
        }
        this.renderStatus();
    },
};

window.Casino = Casino;

// ── Close handlers ──
$('#casino-close')?.addEventListener('click', () => post('casinoClose'));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const overlay = $('#casino-overlay');
    if (!overlay || overlay.classList.contains('hidden')) return;
    e.preventDefault();
    post('casinoClose');
}, true);
