const TRUCKER_CATEGORY_DEFS = {
    convenience: { label: 'Convenience', icon: 'ph-storefront' },
    fuel:        { label: 'Fuel',        icon: 'ph-gas-pump'   },
    restaurant:  { label: 'Restaurant',  icon: 'ph-fork-knife' },
    industrial:  { label: 'Industrial',  icon: 'ph-factory'    },
    general:     { label: 'General',     icon: 'ph-package'    },
};

const TruckerLaptop = {
    _el:         null,
    _catList:    null,
    _routeList:  null,
    _acceptBtn:  null,
    _rankBadge:  null,
    _xpFill:     null,
    _xpLabel:    null,
    _state:      null,

    init() {
        if (this._el) return;
        this._el        = document.getElementById('trucker-laptop');
        this._catList   = document.getElementById('tl-cat-list');
        this._routeList = document.getElementById('tl-route-list');
        this._acceptBtn = document.getElementById('tl-accept-btn');
        this._rankBadge = document.getElementById('tl-rank-badge');
        this._xpFill    = document.getElementById('tl-xp-fill');
        this._xpLabel   = document.getElementById('tl-xp-label');
        if (this._acceptBtn) {
            this._acceptBtn.addEventListener('click', () => this._acceptRoute());
        }
    },

    open(data) {
        this.init();
        if (!this._el) return;
        this._state = {
            rank:          data.rank   || 1,
            xp:            data.xp     || 0,
            xpNext:        data.xpNext || 100,
            routes:        Array.isArray(data.routes) ? data.routes : [],
            selectedRoute: null,
            activeCategory: null,
        };
        this._renderRank();
        this._buildCategories();
        this._el.classList.remove('hidden');
        this._el.removeAttribute('aria-hidden');
    },

    close() {
        if (!this._el) return;
        this._el.classList.add('hidden');
        this._el.setAttribute('aria-hidden', 'true');
        this._state = null;
        post('truckerLaptopClose');
    },

    // Silent hide: visually close the laptop WITHOUT emitting truckerLaptopClose.
    // Used by _acceptRoute so the Lua side owns the gameplay transition and
    // focus cleanup via truckerPickRoute — no double-close race.
    _silentHide() {
        if (!this._el) return;
        this._el.classList.add('hidden');
        this._el.setAttribute('aria-hidden', 'true');
        this._state = null;
    },

    // ── Rank / XP display ────────────────────────────────────

    _renderRank() {
        if (!this._state) return;
        const { rank, xp, xpNext } = this._state;
        if (this._rankBadge) this._rankBadge.textContent = `Rank ${rank}`;
        const pct = xpNext > 0 ? Math.min(100, Math.round((xp / xpNext) * 100)) : 0;
        if (this._xpFill)  this._xpFill.style.width = pct + '%';
        if (this._xpLabel) this._xpLabel.textContent = `${xp} / ${xpNext} XP`;
    },

    // ── Categories ───────────────────────────────────────────

    _getCategories() {
        const seen   = [];
        const result = [];
        for (const route of (this._state?.routes || [])) {
            const cat = route.category || 'general';
            if (!seen.includes(cat)) {
                seen.push(cat);
                const def = TRUCKER_CATEGORY_DEFS[cat] || { label: cat, icon: 'ph-package' };
                result.push({ id: cat, ...def });
            }
        }
        return result;
    },

    _buildCategories() {
        if (!this._catList) return;
        const cats = this._getCategories();
        this._catList.innerHTML = '';
        for (const cat of cats) {
            const btn = document.createElement('button');
            btn.type      = 'button';
            btn.className = 'st-cat-item';
            btn.dataset.cat = cat.id;
            btn.innerHTML = `<i class="ph-bold ${cat.icon}"></i><span>${cat.label}</span>`;
            btn.addEventListener('click', () => this._selectCategory(cat.id));
            this._catList.appendChild(btn);
        }
        if (cats.length > 0) this._selectCategory(cats[0].id);
    },

    _selectCategory(catId) {
        if (!this._state) return;
        this._state.activeCategory = catId;
        this._state.selectedRoute  = null;
        if (this._catList) {
            for (const btn of this._catList.querySelectorAll('.st-cat-item')) {
                btn.classList.toggle('is-active', btn.dataset.cat === catId);
            }
        }
        this._renderRoutes(catId);
        this._updateAcceptBtn();
    },

    // ── Routes ───────────────────────────────────────────────

    _renderRoutes(catId) {
        if (!this._routeList) return;
        const routes = (this._state?.routes || []).filter(
            (r) => (r.category || 'general') === catId
        );
        this._routeList.innerHTML = '';
        if (routes.length === 0) {
            this._routeList.innerHTML = '<div class="tl-empty">No routes in this category</div>';
            return;
        }
        for (const route of routes) {
            const bonus     = route.bonusPct || 0;
            const hasBonus  = bonus > 0;
            const el        = document.createElement('div');
            el.className        = 'tl-route-item';
            el.dataset.routeIdx = route.index;
            el.innerHTML = `
                <div class="tl-route-main">
                    <div class="tl-route-label">${route.label}</div>
                    <div class="tl-route-meta">
                        ${hasBonus
                            ? `<span class="tl-rank-bonus"><i class="ph-bold ph-trend-up"></i> +${bonus}% rank bonus</span>`
                            : `<span class="tl-rank-base"><i class="ph-bold ph-check-circle"></i> Available</span>`
                        }
                    </div>
                </div>
                <div class="tl-route-pay">
                    $${Number(route.pay).toLocaleString()}
                    ${hasBonus ? `<span class="tl-base-pay">base $${Number(route.basePay).toLocaleString()}</span>` : ''}
                </div>
            `;
            el.addEventListener('click', () => this._selectRoute(route));
            this._routeList.appendChild(el);
        }
    },

    _selectRoute(route) {
        if (!this._state) return;
        this._state.selectedRoute = route;
        if (this._routeList) {
            for (const el of this._routeList.querySelectorAll('.tl-route-item')) {
                el.classList.toggle('is-active', Number(el.dataset.routeIdx) === route.index);
            }
        }
        this._updateAcceptBtn();
    },

    _updateAcceptBtn() {
        if (!this._acceptBtn) return;
        const sel = this._state?.selectedRoute;
        this._acceptBtn.disabled = !sel;
        this._acceptBtn.querySelector('.st-btn-text').textContent =
            sel ? `ACCEPT ROUTE` : 'SELECT A ROUTE';
    },

    // ── Accept ───────────────────────────────────────────────

    _acceptRoute() {
        if (!this._state?.selectedRoute) return;
        const route = this._state.selectedRoute;
        post('truckerPickRoute', { routeIndex: route.index });
        // Silent hide: Lua owns the transition + focus cleanup via
        // truckerPickRoute. No truckerLaptopClose emitted — no double-close.
        this._silentHide();
    },
};

window.TruckerLaptop = TruckerLaptop;
