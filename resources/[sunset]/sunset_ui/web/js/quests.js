// Quest log panel (sunset_quests). Reuses overlay-panel design system.
(() => {
    const $ = (sel) => document.querySelector(sel);
    const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
    const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).catch(() => {});

    const body = $('#quest-body');
    const root = $('#quest-log');
    const sub = $('#quest-sub');

    function render(quests) {
        if (!body) return;
        if (!quests || !quests.length) {
            body.innerHTML = '<div style="padding:16px;color:#94a3b8;">No active quests. Visit the Job Center to begin.</div>';
            return;
        }
        body.innerHTML = quests.map((q) => {
            const pct = q.target > 0 ? Math.min(100, Math.floor(((q.progress || 0) / q.target) * 100)) : 0;
            const statusBadge = q.status === 'claimed'
                ? '<span style="color:#22c55e;">CLAIMED</span>'
                : q.status === 'complete'
                    ? '<span style="color:#facc15;">READY TO CLAIM</span>'
                    : '<span style="color:#38bdf8;">ACTIVE</span>';
            const reward = q.reward
                ? `<div style="font-size:11px;color:#64748b;margin-top:4px;">Reward: ${q.reward.money ? '$' + esc(q.reward.money) + ' ' : ''}${q.reward.xp ? esc(q.reward.xp) + ' XP ' : ''}${q.reward.rp ? esc(q.reward.rp) + ' RP' : ''}</div>`
                : '';
            const claimBtn = q.status === 'complete'
                ? `<button type="button" class="mdc-btn mdc-btn--primary mdc-btn--sm quest-claim" data-key="${esc(q.questKey)}" style="margin-top:6px;">CLAIM</button>`
                : '';
            return `
                <div style="border:1px solid #1e293b;border-radius:8px;padding:10px 12px;margin-bottom:8px;background:#0b1220;">
                    <div style="display:flex;justify-content:space-between;align-items:center;">
                        <strong style="color:#e2e8f0;">${esc(q.label)}</strong>
                        ${statusBadge}
                    </div>
                    <div style="font-size:11px;color:#64748b;margin:2px 0 6px;">${esc(q.chainLabel)}</div>
                    <div style="font-size:12px;color:#94a3b8;">${esc(q.description)}</div>
                    <div style="font-size:11px;color:#cbd5e1;margin-top:4px;">${esc(q.objectiveLabel)} — ${q.progress || 0}/${q.target || 1}</div>
                    <div style="height:4px;background:#1e293b;border-radius:2px;margin-top:4px;overflow:hidden;">
                        <div style="height:100%;width:${pct}%;background:#38bdf8;"></div>
                    </div>
                    ${reward}
                    ${claimBtn}
                </div>`;
        }).join('');

        body.querySelectorAll('.quest-claim').forEach((btn) => {
            btn.addEventListener('click', () => {
                btn.disabled = true;
                post('questClaim', { questKey: btn.dataset.key });
            });
        });
    }

    window.addEventListener('message', (event) => {
        const { action, data } = event.data || {};
        if (action === 'questLogShow') {
            if (!root) return;
            render((data || event.data.data || {}).quests || []);
            root.classList.remove('hidden');
            if (sub) sub.textContent = 'Your progression';
        } else if (action === 'questLogHide') {
            if (root) root.classList.add('hidden');
        }
    });

    $('#quest-close')?.addEventListener('click', () => post('questLogClose'));
})();
