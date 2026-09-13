/**
 * GTA V map for Downtown Cab — Leaflet + RiceaRaul CRS (same coords as in-game).
 */
const TaxiPhoneMap = {
    map: null,
    layer: null,
    youMarker: null,
    destMarker: null,
    container: null,
    onPick: null,

    // Los Santos bounds (game Y = lat, game X = lng)
    // Lazy: leaflet.js is loaded on demand (boot perf), so L may be absent at parse time.
    _bounds: null,
    get bounds() {
        if (!this._bounds) {
            this._bounds = L.latLngBounds(L.latLng(-5500, -4000), L.latLng(8000, 6000));
        }
        return this._bounds;
    },

    // Load leaflet on first use instead of at boot (144KB off the login critical path).
    _leafletLoading: null,
    ensureLeaflet() {
        if (typeof L !== 'undefined') return Promise.resolve();
        if (!this._leafletLoading) {
            this._leafletLoading = new Promise((resolve, reject) => {
                const s = document.createElement('script');
                s.src = 'vendor/leaflet/leaflet.js';
                s.onload = resolve;
                s.onerror = () => { this._leafletLoading = null; reject(new Error('leaflet load failed')); };
                document.head.appendChild(s);
            });
        }
        return this._leafletLoading;
    },

    crs: null,

    getCrs() {
        if (this.crs) return this.crs;
        this.crs = L.extend({}, L.CRS.Simple, {
            projection: L.Projection.LonLat,
            scale(zoom) {
                return Math.pow(2, zoom);
            },
            zoom(scale) {
                return Math.log(scale) / Math.LN2;
            },
            distance(pos1, pos2) {
                return Math.hypot(pos2.lng - pos1.lng, pos2.lat - pos1.lat);
            },
            transformation: new L.Transformation(0.02072, 117.3, -0.0205, 172.8),
            infinite: true,
        });
        return this.crs;
    },

    icon(className) {
        return L.divIcon({
            className,
            iconSize: [14, 14],
            iconAnchor: [7, 7],
        });
    },

    invalidate() {
        if (this.map) {
            requestAnimationFrame(() => {
                if (this.map) this.map.invalidateSize();
            });
        }
    },

    mount(container, options = {}) {
        if (!container) return;
        // Leaflet may still be loading (lazy). Retry the mount once it arrives —
        // callers (phone.js) need no changes.
        if (typeof L === 'undefined') {
            this.ensureLeaflet()
                .then(() => this.mount(container, options))
                .catch(() => {});
            return;
        }
        if (this.container === container && this.map) {
            this.onPick = options.onPick || this.onPick;
            if (options.player) this.setPlayer(options.player);
            if (options.destination) this.setDestination(options.destination.x, options.destination.y);
            this.invalidate();
            return;
        }

        this.destroy();
        this.container = container;
        this.onPick = options.onPick || null;

        const map = L.map(container, {
            crs: this.getCrs(),
            minZoom: 2,
            maxZoom: 5,
            zoomControl: false,
            attributionControl: false,
            preferCanvas: true,
            maxBounds: this.bounds,
            maxBoundsViscosity: 1,
        });

        this.layer = L.imageOverlay('assets/gta-map.webp?v=4', this.bounds, {
            interactive: false,
        }).addTo(map);

        map.fitBounds(this.bounds, { animate: false, padding: [4, 4] });

        map.on('click', (e) => {
            const x = e.latlng.lng;
            const y = e.latlng.lat;
            if (this.onPick) this.onPick(x, y);
        });

        this.map = map;

        requestAnimationFrame(() => {
            map.invalidateSize();
            map.fitBounds(this.bounds, { animate: false, padding: [4, 4] });
        });

        if (options.player) this.setPlayer(options.player);
        if (options.destination) this.setDestination(options.destination.x, options.destination.y);
    },

    setPlayer(x, y) {
        if (!this.map) return;
        const px = typeof x === 'object' && x !== null ? x.x : x;
        const py = typeof x === 'object' && x !== null ? x.y : y;
        if (px == null || py == null) return;
        const latlng = L.latLng(py, px);
        if (!this.youMarker) {
            this.youMarker = L.marker(latlng, { icon: this.icon('phone-taxi-map-marker phone-taxi-map-marker--you'), interactive: false }).addTo(this.map);
        } else {
            this.youMarker.setLatLng(latlng);
        }
    },

    setDestination(x, y) {
        if (!this.map || x == null || y == null) return;
        const latlng = L.latLng(y, x);
        if (!this.destMarker) {
            this.destMarker = L.marker(latlng, { icon: this.icon('phone-taxi-map-marker phone-taxi-map-marker--dest'), interactive: false }).addTo(this.map);
        } else {
            this.destMarker.setLatLng(latlng);
        }
    },

    clearDestination() {
        if (this.destMarker && this.map) {
            this.map.removeLayer(this.destMarker);
            this.destMarker = null;
        }
    },

    update(player, destination) {
        if (!this.map) return;
        if (player) this.setPlayer(player);
        if (destination && destination.x != null) this.setDestination(destination.x, destination.y);
        else this.clearDestination();
    },

    destroy() {
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
        this.layer = null;
        this.youMarker = null;
        this.destMarker = null;
        this.container = null;
        this.onPick = null;
    },
};

window.TaxiPhoneMap = TaxiPhoneMap;
