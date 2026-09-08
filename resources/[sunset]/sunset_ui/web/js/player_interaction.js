(() => {
    const root = document.getElementById('player-interaction');
    const nameEl = document.getElementById('player-interaction-name');
    const metaEl = document.getElementById('player-interaction-meta');
    const groupsEl = document.getElementById('player-interaction-groups');
    const closeEl = document.getElementById('player-interaction-close');
    let state = null;

    const esc = (value) => String(value ?? '').replace(/[&<>'"]/g, (char) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
    })[char]);

    const postNui = (name, payload = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    });

    function inputMarkup(action) {
        const input = action.input;
        if (!input) return '';
        if (input.type === 'select') {
            return `<label class="player-action__field"><span>${esc(input.label)}</span><select data-action-value>
                ${(input.options || []).map((option) => `<option value="${esc(option.value)}">${esc(option.label)}</option>`).join('')}
            </select></label>`;
        }
        return `<label class="player-action__field"><span>${esc(input.label)}</span><input data-action-value type="number"
            min="${Number(input.min) || 1}" max="${Number(input.max) || 999999}" placeholder="${esc(input.placeholder || '')}"></label>`;
    }

    function render(payload) {
        state = payload || {};
        const target = state.target || {};
        nameEl.textContent = target.name || `Player #${target.id || '?'}`;
        const chips = [`ID ${target.id || '?'}`, `LEVEL ${target.level || 1}`];
        if (target.faction) chips.push(target.faction);
        if (target.detention && target.detention !== 'FREE') chips.push(target.detention.replace('_', ' '));
        if (target.wanted?.level) chips.push(`${'★'.repeat(Math.min(5, Number(target.wanted.level) || 0))} ${target.wanted.surrenderable === false ? 'NO SURRENDER' : 'WANTED'}`);
        metaEl.innerHTML = chips.map((chip) => `<span>${esc(chip)}</span>`).join('');

        const grouped = new Map();
        (state.actions || []).forEach((action) => {
            const key = action.group || 'ACTIONS';
            if (!grouped.has(key)) grouped.set(key, []);
            grouped.get(key).push(action);
        });
        groupsEl.innerHTML = [...grouped.entries()].map(([group, actions]) => `
            <section class="player-action-group">
                <h3>${esc(group)}</h3>
                <div class="player-action-group__grid">
                    ${actions.map((action) => `
                        <article class="player-action${action.danger ? ' player-action--danger' : ''}" data-action="${esc(action.id)}">
                            <div class="player-action__copy"><strong>${esc(action.label)}</strong><p>${esc(action.description)}</p></div>
                            ${inputMarkup(action)}
                            <button type="button" data-action-submit>${action.danger ? 'CONFIRM' : 'SELECT'}<i></i></button>
                        </article>`).join('')}
                </div>
            </section>`).join('');

        groupsEl.querySelectorAll('[data-action-submit]').forEach((button) => {
            button.addEventListener('click', () => {
                const card = button.closest('[data-action]');
                const input = card.querySelector('[data-action-value]');
                const value = input ? input.value : null;
                if (input && !value) {
                    card.classList.remove('is-invalid');
                    void card.offsetWidth;
                    card.classList.add('is-invalid');
                    input.focus();
                    return;
                }
                button.disabled = true;
                postNui('playerInteractionAction', { action: card.dataset.action, value })
                    .catch(() => {})
                    .finally(() => { window.setTimeout(() => { button.disabled = false; }, 450); });
            });
        });
    }

    function show(payload) {
        render(payload);
        root.classList.remove('hidden');
        root.setAttribute('aria-hidden', 'false');
        document.body.classList.add('player-interaction-open');
    }

    function hide() {
        root.classList.add('hidden');
        root.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('player-interaction-open');
        state = null;
    }

    closeEl?.addEventListener('click', () => postNui('playerInteractionClose'));
    document.addEventListener('keydown', (event) => {
        if (!root || root.classList.contains('hidden')) return;
        if (event.key === 'Escape' || event.key.toLowerCase() === 'g') {
            event.preventDefault();
            postNui('playerInteractionClose');
        }
    });

    window.PlayerInteraction = { show, update: render, hide };

    // Local browser-only visual fixture; FiveM never opens the NUI with this URL.
    if (new URLSearchParams(location.search).get('qa') === 'interaction') {
        show({
            target: { id: 42, name: 'ANDREI POPESCU', level: 18, faction: 'LSPD', detention: 'CUFFED', wanted: { level: 3, surrenderable: true } },
            actions: [
                { id: 'give_cash', group: 'CIVILIAN', label: 'Give cash', description: 'Hand money directly to this player.', input: { type: 'number', label: 'Amount', min: 1, max: 50000, placeholder: '$ amount' } },
                { id: 'add_friend', group: 'CIVILIAN', label: 'Add to contacts', description: 'Save this player in your phone contacts.' },
                { id: 'uncuff', group: 'POLICE', label: 'Remove cuffs', description: 'Release the player from restraints.' },
                { id: 'escort', group: 'POLICE', label: 'Escort suspect', description: 'Attach or release the restrained player.' },
                { id: 'frisk', group: 'POLICE', label: 'Search player', description: 'Inspect carried items and contraband.' },
                { id: 'ticket', group: 'POLICE', label: 'Issue citation', description: 'Open the official violation selector.' },
                { id: 'set_wanted', group: 'POLICE', label: 'Add wanted charge', description: 'Select the offence committed by this player.', danger: true, input: { type: 'select', label: 'Offence', options: [{ value: 'speeding', label: 'Speeding — 1 star' }, { value: 'robbery', label: 'Robbery — 5 stars / no surrender' }] } },
                { id: 'arrest', group: 'POLICE', label: 'Book into jail', description: 'Requires cuffs, active wanted and a booking location.', danger: true },
            ],
        });
    }
})();
