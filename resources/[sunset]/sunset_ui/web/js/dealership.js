(() => {
    const TOTAL_SEGMENTS = 10;
    const CATEGORY_STATS = {
        super: { speed: 10, accel: 9, handling: 7 },
        sport: { speed: 8, accel: 7, handling: 6 },
        suv: { speed: 6, accel: 5, handling: 5 },
        sedan: { speed: 6, accel: 5, handling: 6 },
        compact: { speed: 5, accel: 5, handling: 6 },
        motorcycle: { speed: 7, accel: 8, handling: 8 },
        other: { speed: 5, accel: 5, handling: 5 },
    };

    let state = {
        vehicles: [],
        selected: null,
        admin: false,
        money: null,
        testDriveSeconds: 60,
        dealership: 'Vehicle Dealership',
    };
    let buyProgress = 0;
    let buyRaf = null;
    let buyComplete = false;
    let adminPanelOpen = true;
    let deleteConfirm = false;

    const $ = (sel) => document.querySelector(sel);

    const post = (name, payload = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    }).catch(() => {});

    const formatMoney = (amount) => {
        const n = Math.floor(Number(amount) || 0);
        return `$${n.toLocaleString('en-US')}`;
    };

    const formatShortPrice = (amount) => {
        const n = Number(amount) || 0;
        if (n >= 1000000) return `$${(n / 1000000).toFixed(1)}M`;
        if (n >= 1000) return `$${Math.round(n / 1000)}k`;
        return `$${n}`;
    };

    const vehicleStats = (vehicle) => {
        const cat = String(vehicle?.category || 'other').toLowerCase();
        const base = CATEGORY_STATS[cat] || CATEGORY_STATS.other;
        const boost = Math.min(2, Math.floor((Number(vehicle?.price) || 0) / 200000));
        return {
            speed: Math.min(10, base.speed + boost),
            accel: Math.min(10, base.accel + Math.floor(boost / 2)),
            handling: Math.min(10, base.handling),
        };
    };

    const statLabels = (stats) => ({
        speed: `${Math.round(stats.speed * 22 + 46)} KM/H`,
        accel: `${(6.2 - stats.accel * 0.38).toFixed(1)}s`,
        handling: `G ${(stats.handling / 10 * 1.2).toFixed(1)}`,
    });

    const renderStatBar = (container, value) => {
        if (!container) return;
        container.innerHTML = '';
        const v = Math.max(0, Math.min(TOTAL_SEGMENTS, Math.round(Number(value) || 0)));
        for (let i = 1; i <= TOTAL_SEGMENTS; i++) {
            const seg = document.createElement('div');
            seg.className = 'dl-stat-segment' + (i <= v ? ' fill' : '');
            container.appendChild(seg);
        }
    };

    const getSelected = () => (state.vehicles || []).find((v) => v.model === state.selected);

    const stopBuy = (reset = true) => {
        if (buyRaf) {
            cancelAnimationFrame(buyRaf);
            buyRaf = null;
        }
        if (reset && !buyComplete) {
            buyProgress = 0;
            const bar = $('#dl-buy-progress');
            const text = $('#dl-buy-text');
            if (bar) bar.style.width = '0%';
            if (text) text.innerHTML = '<span class="dl-key-hint">ENTER</span> Hold to Purchase';
        }
    };

    const tickBuy = () => {
        buyProgress += 2;
        const bar = $('#dl-buy-progress');
        const btn = $('#dl-btn-buy');
        const text = $('#dl-buy-text');
        if (bar) bar.style.width = `${buyProgress}%`;
        if (buyProgress >= 100) {
            buyComplete = true;
            if (text) {
                text.textContent = 'Purchased!';
                text.style.color = '#000';
            }
            if (btn) btn.style.background = 'var(--dl-accent)';
            const vehicle = getSelected();
            if (vehicle) {
                const color = Number($('#dl-color')?.value) || 0;
                post('dealershipBuy', { model: vehicle.model, color });
            }
            stopBuy(false);
            return;
        }
        buyRaf = requestAnimationFrame(tickBuy);
    };

    const startBuy = () => {
        const vehicle = getSelected();
        if (!state.admin && vehicle && Number(vehicle.stock) <= 0) return;
        if (state.admin) return;
        buyComplete = false;
        stopBuy(false);
        buyRaf = requestAnimationFrame(tickBuy);
    };

    const renderList = () => {
        const list = $('#dl-vehicle-list');
        const title = $('#dl-category-title');
        if (!list) return;
        const vehicle = getSelected();
        if (title) {
            title.textContent = vehicle?.category
                ? String(vehicle.category).replace(/_/g, ' ')
                : 'Catalog';
        }
        list.innerHTML = '';
        (state.vehicles || []).forEach((v) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'dl-list-item' + (state.selected === v.model ? ' active' : '');
            const name = document.createElement('span');
            name.textContent = v.label || v.model;
            const price = document.createElement('span');
            price.className = 'dl-item-price';
            price.textContent = formatShortPrice(v.price);
            btn.append(name, price);
            btn.addEventListener('click', () => {
                state.selected = v.model;
                post('dealershipSelect', { model: v.model });
                renderAll();
                if (state.admin) fillAdmin(v);
            });
            list.appendChild(btn);
        });
        if (!state.vehicles.length) {
            const empty = document.createElement('p');
            empty.className = 'dl-stock-note';
            empty.textContent = 'No vehicles in catalog.';
            list.appendChild(empty);
        }
    };

    const renderDetail = () => {
        const vehicle = getSelected();
        const stats = vehicleStats(vehicle);
        const labels = statLabels(stats);
        renderStatBar($('#dl-stat-speed'), stats.speed);
        renderStatBar($('#dl-stat-accel'), stats.accel);
        renderStatBar($('#dl-stat-handling'), stats.handling);
        const speedLbl = $('#dl-stat-speed-val');
        const accelLbl = $('#dl-stat-accel-val');
        const handLbl = $('#dl-stat-handling-val');
        if (speedLbl) speedLbl.textContent = labels.speed;
        if (accelLbl) accelLbl.textContent = labels.accel;
        if (handLbl) handLbl.textContent = labels.handling;
        const priceEl = $('#dl-price');
        if (priceEl) {
            priceEl.textContent = vehicle
                ? Number(vehicle.price || 0).toLocaleString('en-US')
                : '—';
        }
        const priceLabel = $('#dl-price-label');
        if (priceLabel) {
            if (!vehicle) priceLabel.textContent = 'Purchase Price';
            else if (Number(vehicle.stock) > 0) {
                priceLabel.textContent = `Purchase Price · ${vehicle.stock} in stock`;
            } else {
                priceLabel.textContent = 'Purchase Price · Sold out';
            }
        }
        const stockEl = $('#dl-stock-note');
        if (stockEl) stockEl.textContent = '';
        const balance = $('#dl-balance');
        if (balance) balance.textContent = '';
        const buyBtn = $('#dl-btn-buy');
        const testBtn = $('#dl-btn-test');
        const inStock = vehicle && Number(vehicle.stock) > 0;
        if (buyBtn) buyBtn.disabled = state.admin || !inStock;
        if (testBtn) {
            const enabled = vehicle && (vehicle.test_drive_enabled === true || Number(vehicle.test_drive_enabled) === 1);
            testBtn.disabled = state.admin || !enabled || !vehicle;
            testBtn.textContent = `Test Drive — ${state.testDriveSeconds || 60}s`;
        }
        buyComplete = false;
        stopBuy(true);
    };

    const fillAdmin = (vehicle) => {
        const v = vehicle || {};
        const set = (id, val) => { const el = $(id); if (el) el.value = val ?? ''; };
        set('#dealer-model', v.model || '');
        set('#dealer-label', v.label || '');
        set('#dealer-brand', v.brand || '');
        set('#dealer-category', v.category || '');
        set('#dealer-price', v.price || '');
        set('#dealer-stock', v.stock ?? 0);
        set('#dealer-order', v.display_order ?? 100);
        const modelInput = $('#dealer-model');
        if (modelInput) modelInput.readOnly = Boolean(vehicle);
        const avail = $('#dealer-available');
        const td = $('#dealer-testdrive');
        if (avail) avail.checked = vehicle ? Number(vehicle.available) === 1 : true;
        if (td) td.checked = vehicle ? Number(vehicle.test_drive_enabled) === 1 : true;
    };

    const bindAdmin = () => {
        $('#dealership-admin-new')?.addEventListener('click', () => fillAdmin(null));
        $('#dealership-admin-save')?.addEventListener('click', () => {
            post('dealershipAdminSave', {
                model: $('#dealer-model')?.value,
                label: $('#dealer-label')?.value,
                brand: $('#dealer-brand')?.value,
                category: $('#dealer-category')?.value,
                price: Number($('#dealer-price')?.value),
                stock: Number($('#dealer-stock')?.value),
                displayOrder: Number($('#dealer-order')?.value),
                available: $('#dealer-available')?.checked,
                testDriveEnabled: $('#dealer-testdrive')?.checked,
            });
        });
        $('#dealership-admin-delete')?.addEventListener('click', () => {
            const model = $('#dealer-model')?.value;
            if (!model) return;
            const btn = $('#dealership-admin-delete');
            if (!deleteConfirm) {
                deleteConfirm = true;
                if (btn) btn.textContent = `Confirm delete ${model}?`;
                setTimeout(() => {
                    deleteConfirm = false;
                    if (btn) btn.textContent = 'DELETE SELECTED';
                }, 3500);
                return;
            }
            deleteConfirm = false;
            if (btn) btn.textContent = 'DELETE SELECTED';
            post('dealershipAdminDelete', { model });
        });
        $('#dl-admin-toggle')?.addEventListener('click', () => {
            adminPanelOpen = !adminPanelOpen;
            $('#dl-admin-panel')?.classList.toggle('hidden', !adminPanelOpen);
        });
    };

    const bindStatic = () => {
        $('#dealership-rotate-left')?.addEventListener('click', () => post('dealershipRotate', { direction: -1 }));
        $('#dealership-rotate-right')?.addEventListener('click', () => post('dealershipRotate', { direction: 1 }));
        const buyBtn = $('#dl-btn-buy');
        buyBtn?.addEventListener('mousedown', startBuy);
        buyBtn?.addEventListener('mouseup', () => stopBuy(true));
        buyBtn?.addEventListener('mouseleave', () => stopBuy(true));
        buyBtn?.addEventListener('touchstart', (e) => { e.preventDefault(); startBuy(); }, { passive: false });
        buyBtn?.addEventListener('touchend', () => stopBuy(true));
        buyBtn?.addEventListener('touchcancel', () => stopBuy(true));
        $('#dl-btn-test')?.addEventListener('click', () => {
            const vehicle = getSelected();
            if (!vehicle || state.admin) return;
            post('dealershipTestDrive', { model: vehicle.model });
        });
        document.addEventListener('keydown', (e) => {
            const root = $('#dealership');
            if (!root || root.classList.contains('hidden')) return;
            if (e.key === 'Escape') {
                e.preventDefault();
                post('dealershipClose');
            }
            if (e.key === 'Enter' && !state.admin && !e.repeat) {
                const tag = (e.target && e.target.tagName) || '';
                if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
                startBuy();
            }
        });
        document.addEventListener('keyup', (e) => {
            if (e.key === 'Enter') stopBuy(true);
        });
    };

    let bound = false;
    const ensureBound = () => {
        if (bound) return;
        bound = true;
        bindStatic();
        bindAdmin();
    };

    const renderAll = () => {
        if (!state.selected && state.vehicles.length) state.selected = state.vehicles[0].model;
        renderList();
        renderDetail();
    };

    const show = (data) => {
        ensureBound();
        const opening = $('#dealership')?.classList.contains('hidden');
        state = {
            ...state,
            vehicles: data?.vehicles ?? state.vehicles ?? [],
            admin: data?.admin !== undefined ? data.admin === true : state.admin,
            money: data?.money !== undefined ? data.money : state.money,
            testDriveSeconds: data?.testDriveSeconds ?? state.testDriveSeconds ?? 60,
            dealership: data?.dealership ?? state.dealership ?? 'Vehicle Dealership',
        };
        if (opening) state.selected = null;
        $('#dl-admin-toggle')?.classList.toggle('hidden', !state.admin);
        $('#dl-admin-panel')?.classList.toggle('hidden', !state.admin || !adminPanelOpen);
        $('#dl-btn-buy')?.classList.toggle('hidden', state.admin);
        document.querySelector('.dl-bottom-tools')?.classList.toggle('hidden', state.admin);
        $('#dl-color-row')?.classList.toggle('hidden', state.admin);
        renderAll();
        if (state.admin && getSelected()) fillAdmin(getSelected());
        $('#dealership')?.classList.remove('hidden');
        if (opening && state.selected) post('dealershipSelect', { model: state.selected });
    };

    const update = (data) => show(data);

    const hide = () => {
        stopBuy(true);
        $('#dealership')?.classList.add('hidden');
        state.selected = null;
    };

    window.DealershipUI = { show, update, hide };
})();
