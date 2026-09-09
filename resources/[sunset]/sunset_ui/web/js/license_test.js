const LicenseTestHud = {
    _metaLine(data = {}) {
        const parts = [];
        if (data.step != null && data.total) parts.push(`Step ${data.step}/${data.total}`);
        if (data.checkpoints) parts.push(`Checkpoint ${data.checkpoint ?? 0}/${data.checkpoints}`);
        if (data.penalties !== undefined && data.maxPenalties !== undefined) {
            parts.push(`Penalties ${data.penalties}/${data.maxPenalties}`);
        } else if (data.collisions !== undefined && data.maxCollisions !== undefined) {
            parts.push(`Hits ${data.collisions}/${data.maxCollisions}`);
        }
        if (data.speed !== undefined && data.speedLimit !== undefined) {
            parts.push(`${data.speed}/${data.speedLimit} km/h`);
        }
        if (data.timeLeftSec != null) {
            const left = Math.max(0, Number(data.timeLeftSec) || 0);
            const m = Math.floor(left / 60);
            const s = left % 60;
            parts.push(`Time ${m}:${String(s).padStart(2, '0')}`);
        }
        return parts.join(' · ') || (data.meta || '');
    },

    _tone(data = {}) {
        if (data.state === 'warning') return 'danger';
        if (String(data.message || '').startsWith('REDUCE SPEED')
            || String(data.message || '').startsWith('PENALTY')) {
            return 'danger';
        }
        if (data.state === 'success') return 'success';
        return 'default';
    },

    _title(data = {}) {
        if (data.licenseType === 'driver') return 'EXAMEN AUTO PRACTIC';
        return (data.title || 'LICENSE TEST').toUpperCase();
    },

    show(data = {}) {
        if (!window.Hud) return;
        const plainMessage = data.state === 'warning'
            || String(data.message || '').startsWith('REDUCE SPEED')
            || String(data.message || '').startsWith('PENALTY');
        Hud.showTask({
            icon: data.licenseType === 'driver' ? 'driver' : 'license',
            title: this._title(data),
            message: data.message || 'Follow the examiner instructions.',
            plainDesc: plainMessage,
            progress: data.progress,
            progressText: this._metaLine(data),
            tone: this._tone(data),
            licenseType: data.licenseType,
        });
    },

    update(data = {}) {
        this.show(data);
    },

    hide() {
        if (window.Hud) Hud.hideTask();
    },
};

window.LicenseTestHud = LicenseTestHud;
