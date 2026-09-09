/**
 * Job shift HUD icons — SVG presets + emoji / short custom text.
 * In Job Creator set icon to: truck, axe, fish, package, trash, pickaxe, hardhat, box, wheat, briefcase, tree
 * Or paste an emoji: 🪓 🚚 🎣
 */
const JobIcons = {
    SVG_ATTR: 'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square"',

    presets: {
        fish: '<path d="M16.5 7.5L5.5 18.5"/><path d="M12.5 11.5L9.5 8.5"/><path d="M21 3L16.5 7.5"/><path d="M16 11l5 5c1 1 1 2.5 0 3.5s-2.5 1-3.5 0l-5-5"/><circle cx="17.5" cy="17.5" r="2.5"/><path d="M8.5 15.5l-3-3"/>',
        truck: '<path d="M3 17h2"/><path d="M19 17h2"/><path d="M5 17H3V8h11v9"/><path d="M16 17h3V11l-3-4h-5v10"/><circle cx="7.5" cy="17.5" r="1.5"/><circle cx="17.5" cy="17.5" r="1.5"/>',
        package: '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9L12 3z"/><path d="M12 12l8-4.5"/><path d="M12 12v9"/><path d="M12 12L4 7.5"/>',
        trash: '<path d="M4 7h16"/><path d="M9 7V5h6v2"/><path d="M7 7l1 12h8l1-12"/>',
        axe: '<path d="M14 3l7 7-3 3-4-4-6 6-2-2 6-6-4-4z"/><path d="M5 19l2 2"/>',
        pickaxe: '<path d="M4 20l5-5"/><path d="M14 4l6 6"/><path d="M12 6l2 2"/><path d="M9 9l-2 2"/>',
        hardhat: '<path d="M4 14h16"/><path d="M6 14V11a6 6 0 0112 0v3"/><path d="M9 18h6"/>',
        box: '<path d="M4 8l8-4 8 4v8l-8 4-8-4V8z"/><path d="M12 4v16"/><path d="M4 8l8 4 8-4"/>',
        wheat: '<path d="M12 21V11"/><path d="M8 14c0-3 2-5 4-5s4 2 4 5"/><path d="M6 11c0-2 1.5-3.5 3-3.5"/><path d="M18 11c0-2-1.5-3.5-3-3.5"/>',
        tree: '<path d="M12 21V12"/><path d="M6 12c0-4 2.5-7 6-7s6 3 6 7"/><path d="M4 14c0-3 2-5 4-5"/><path d="M20 14c0-3-2-5-4-5"/>',
        briefcase: '<path d="M4 8h16v11H4z"/><path d="M9 8V6h6v2"/><path d="M4 12h16"/>',
        car: '<path d="M4 17h16M6 11l2-5h8l2 5"/><circle cx="7.5" cy="17" r="1.5"/><circle cx="16.5" cy="17" r="1.5"/>',
        wrench: '<path d="M14 4l6 6-8 8H8v-4l8-8z"/><path d="M6 18l-2 2"/>',
        jail: '<path d="M4 4h16v16H4z"/><path d="M8 4v16"/><path d="M16 4v16"/><path d="M4 10h16"/><path d="M4 14h16"/>',
    },

    normalize(key) {
        return String(key || 'briefcase').trim().toLowerCase();
    },

    isEmoji(text) {
        if (!text || text.length > 4) return false;
        return /[\u{1F300}-\u{1FAFF}\u2600-\u27BF]/u.test(text);
    },

    render(key) {
        const raw = String(key || 'briefcase').trim();
        const id = this.normalize(raw);
        const paths = this.presets[id] || this.presets.briefcase;
        if (this.isEmoji(raw)) {
            return `<span class="fishing__icon fishing__icon-emoji" aria-hidden="true">${raw}</span>`;
        }
        if (this.presets[id]) {
            return `<svg class="fishing__icon" ${this.SVG_ATTR} aria-hidden="true">${paths}</svg>`;
        }
        return `<svg class="fishing__icon" ${this.SVG_ATTR} aria-hidden="true">${this.presets.briefcase}</svg>`;
    },

    apply(slot, key) {
        if (!slot) return;
        slot.innerHTML = this.render(key);
    },
};

window.JobIcons = JobIcons;
