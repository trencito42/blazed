const InventoryForza = {
    WEIGHT_SEGMENTS: 15,
    _slotsReady: false,

    ensureWeightBar() {
        const cont = document.getElementById('weight-bar-player');
        if (!cont || cont.children.length === this.WEIGHT_SEGMENTS) return;
        cont.innerHTML = '';
        for (let i = 0; i < this.WEIGHT_SEGMENTS; i += 1) {
            const seg = document.createElement('div');
            seg.className = 'weight-segment';
            cont.appendChild(seg);
        }
    },

    updateWeight(current, max) {
        this.ensureWeightBar();
        const val = document.getElementById('weight-val-player');
        if (val) val.textContent = Number(current || 0).toFixed(1);
        const maxEl = document.getElementById('weight-max-player');
        if (maxEl) maxEl.textContent = Number(max || 30).toFixed(1);

        const segments = document.getElementById('weight-bar-player')?.children;
        if (!segments || !segments.length) return;
        const pct = Math.max(0, Number(current) || 0) / Math.max(1, Number(max) || 30);
        let fillCount = Math.ceil(pct * this.WEIGHT_SEGMENTS);
        if (fillCount > this.WEIGHT_SEGMENTS) fillCount = this.WEIGHT_SEGMENTS;

        for (let i = 0; i < this.WEIGHT_SEGMENTS; i += 1) {
            segments[i].className = 'weight-segment';
            if (i < fillCount) {
                if (i >= Math.floor(this.WEIGHT_SEGMENTS * 0.8)) segments[i].classList.add('danger');
                else segments[i].classList.add('fill');
            }
        }
    },

    itemLabel(row) {
        const def = row?.item || 'unknown';
        let label = row?.label || def;
        if (def === 'gas_can' && row?.metadata) {
            const maxL = 20;
            let liters = Number(row.metadata.liters);
            if (Number.isNaN(liters) && row.metadata.fuel != null) {
                liters = (Number(row.metadata.fuel) / 100) * maxL;
            }
            if (!Number.isNaN(liters)) label = `Gas Can (${Math.round(liters)}/${maxL} L)`;
        }
        if (def === 'fresh_fish' && row?.metadata) {
            const value = Math.max(0, Number(row.metadata.value) || 0);
            label = `${row.label || 'Fresh Fish'} ($${Math.round(value)})`;
        }
        return label;
    },

    itemWeightText(row) {
        const def = row?.item || '';
        const FISH_TYPES = ['fish_common', 'fish_uncommon', 'fish_rare', 'fish_epic', 'fish_legendary'];
        if (FISH_TYPES.includes(def) && row?.metadata) {
            const kg = Number(row.metadata.fishKg) || 0;
            if (kg > 0) return `${kg.toFixed(1)}kg`;
        }
        const w = Number(row?.weight) || 0;
        if (w > 0) return `${w.toFixed(1)}kg`;
        return '';
    },

    itemIconHtml(row) {
        const icon = row?.icon;
        if (icon && String(icon).startsWith('ph-')) {
            return `<i class="ph-fill ${icon} item-icon"></i>`;
        }
        const src = icon && /^[a-z0-9_-]+$/i.test(icon)
            ? `assets/items/${icon}.webp`
            : 'assets/items/backpack.webp';
        return `<img class="item-icon" src="${src}" alt="" draggable="false" onerror="this.src='assets/items/backpack.webp'">`;
    },

    buildItemButton(row, cell, hooks) {
        const label = this.itemLabel(row);
        const item = document.createElement('button');
        item.type = 'button';
        item.className = 'inv-item';
        item.title = row.usable ? `Select ${label}; double-click to use` : `Select ${label}`;
        item.innerHTML = `
            ${this.itemIconHtml(row)}
            <div class="item-name">${label}</div>
            <div class="item-info">
                <span class="item-qty">${Math.max(0, Number(row.count) || 0)}</span>
                <span class="item-weight">${this.itemWeightText(row)}</span>
            </div>
        `;
        item.addEventListener('click', (event) => hooks.onClick?.(row, cell, item, event));
        item.addEventListener('dblclick', () => hooks.onDblClick?.(row));
        item.addEventListener('pointerdown', (event) => hooks.onPointerDown?.(row, cell, item, event));
        cell.appendChild(item);
        return item;
    },

    renderMainGrid(items, hooks, slotCount = 30) {
        const grid = document.getElementById('grid-player');
        if (!grid) return;
        grid.innerHTML = '';
        const bySlot = new Map((items || []).map((row, index) => [Math.max(1, Number(row.slot) || index + 1), row]));
        const total = Math.max(slotCount, ...Array.from(bySlot.keys()), 0);

        for (let slot = 1; slot <= total; slot += 1) {
            const row = bySlot.get(slot);
            const cell = document.createElement('div');
            cell.className = 'inv-slot';
            cell.dataset.slot = String(slot);
            cell.dataset.grid = 'grid-player';
            if (row) this.buildItemButton(row, cell, hooks);
            grid.appendChild(cell);
        }
    },

    renderQuickSlots(quickslots, hooks) {
        const grid = document.getElementById('grid-quick');
        if (!grid) return;
        grid.innerHTML = '<div class="quick-picks-label">Quick Access</div>';
        for (let i = 1; i <= 5; i += 1) {
            const slot = quickslots?.[String(i)] || quickslots?.[i];
            const cell = document.createElement('div');
            cell.className = 'inv-slot';
            cell.dataset.slot = String(i);
            cell.dataset.grid = 'grid-quick';
            cell.dataset.hotbarSlot = String(i);
            const marker = document.createElement('div');
            marker.className = 'hotbar-marker';
            marker.textContent = String(i);
            cell.appendChild(marker);

            if (slot) {
                const pseudo = {
                    item: slot.item || slot.kind || 'quick',
                    label: slot.label || 'Quick slot',
                    count: slot.count || 1,
                    weight: slot.weight || 0,
                    icon: slot.icon,
                    usable: slot.usable,
                    id: slot.rowId || `quick-${i}`,
                    slot: i,
                };
                this.buildItemButton(pseudo, cell, {
                    onClick: () => {},
                    onDblClick: () => post('hotbarAssign', { slot: i, clear: true, fromInventory: true }),
                    onPointerDown: (row, c, el, event) => hooks.onQuickPointerDown?.(pseudo, c, el, event),
                });
            }
            grid.appendChild(cell);
        }
    },

    renderNearby(players) {
        const list = document.getElementById('inventory-nearby-list');
        if (!list) return;
        list.innerHTML = '';
        const nearby = Array.isArray(players) ? players : [];
        if (!nearby.length) {
            const empty = document.createElement('div');
            empty.className = 'prox-empty';
            empty.textContent = 'Niciun jucător în zonă (3m).';
            list.appendChild(empty);
            return;
        }
        nearby.forEach((player) => {
            const card = document.createElement('button');
            card.type = 'button';
            card.className = 'prox-player';
            card.dataset.playerId = String(player.id);
            card.innerHTML = `
                <div class="prox-id">ID Jucător: ${player.id}</div>
                <div class="prox-name">${player.name || `Player #${player.id}`}</div>
                <div class="prox-actions">
                    <div class="prox-hint"><i class="ph-bold ph-handshake"></i> Click pt. Trade</div>
                </div>
            `;
            card.addEventListener('click', () => post('inventoryTradeRequest', { targetId: player.id }));
            list.appendChild(card);
        });
    },
};

window.InventoryForza = InventoryForza;
