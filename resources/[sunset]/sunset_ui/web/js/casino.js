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

        const names = { blackjack: 'Blackjack', slots: 'Slot Machines', roulette: 'Roulette' };
        title.textContent = names[this.game] || 'Casino';
        sub.textContent = `Min $${(this.status.minBet || 100).toLocaleString()} · Max $${(this.status.maxBet || 50000).toLocaleString()}`;

        if (this.game === 'blackjack') this.renderBlackjack(body);
        else if (this.game === 'slots') this.renderSlots(body);
        else if (this.game === 'roulette') this.renderRoulette(body);

        this.renderStatus();
    },

    renderStatus() {
        const el = $('#casino-status');
        if (!el) return;
        const loss = this.status.dailyLoss || 0;
        const limit = this.status.dailyLimit || 500000;
        el.innerHTML = `
            <span>Daily loss: <strong>$${loss.toLocaleString()}</strong> / $${limit.toLocaleString()}</span>
            <span>Bet: <strong>$${this.bet.toLocaleString()}</strong></span>
        `;
    },

    betControls() {
        const chips = [100, 500, 1000, 5000, 10000, 25000];
        return `
            <div class="casino-bet-row">
                <span class="casino-bet-label">Bet</span>
                <input type="number" class="casino-bet-input" id="casino-bet" value="${this.bet}" min="${this.status.minBet || 100}" max="${this.status.maxBet || 50000}">
                ${chips.map((c) => `<button type="button" class="casino-bet-chip" data-casino-chip="${c}">$${(c / 1000).toFixed(c < 1000 ? 0 : 0)}${c >= 1000 ? 'K' : ''}</button>`).join('')}
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

        if (data.state === 'settled' && data.settled) {
            renderCards($('#bj-dealer-cards'), data.settled.dealerHand || []);
            $('#bj-dealer-value').textContent = data.settled.dealerValue != null ? data.settled.dealerValue : '';

            const s = data.settled;
            const resultEl = $('#bj-result');
            const labels = {
                blackjack: `🃏 BLACKJACK! +$${s.payout.toLocaleString()}`,
                win: `✅ You win! +$${s.payout.toLocaleString()}`,
                dealer_bust: `💥 Dealer busts! +$${s.payout.toLocaleString()}`,
                push: '🤝 Push — bet returned',
                lose: `❌ Dealer wins. -$${this.bet.toLocaleString()}`,
                bust: `💀 Bust! -$${this.bet.toLocaleString()}`,
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
        const resultEl = $('#slots-result');
        if (resultEl) {
            if (data.payout > 0) {
                resultEl.className = 'slots-result slots-result--win';
                resultEl.textContent = `🎉 ${data.matches} match! +$${data.payout.toLocaleString()}`;
            } else {
                resultEl.className = 'slots-result slots-result--lose';
                resultEl.textContent = 'No match. Try again!';
            }
        }
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
        const resultEl = $('#roulette-result');
        if (resultEl) {
            if (data.won) {
                resultEl.className = 'slots-result slots-result--win';
                resultEl.textContent = `🎉 ${data.result} ${data.color}! +$${data.payout.toLocaleString()}`;
            } else {
                resultEl.className = 'slots-result slots-result--lose';
                resultEl.textContent = `${data.result} ${data.color}. Better luck next time.`;
            }
        }
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
