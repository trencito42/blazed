(() => {
    'use strict';

    const SIZE = 450;
    const CX = SIZE / 2;
    const CY = SIZE / 2 + 20;
    const RADIUS = 140;
    const START_ANGLE = 0.80 * Math.PI;
    const END_ANGLE = 2.20 * Math.PI;
    const ARC_RANGE = END_ANGLE - START_ANGLE;
    const MAX_SPEED = 320;

    const theme = {
        darkRing: 'rgba(255, 255, 255, 0.05)',
        tickBase: 'rgba(255, 255, 255, 0.15)',
        white: '#ffffff',
        redline: '#ff3366',
        success: '#00ffcc',
        warning: '#ffcc00',
        muted: 'rgba(255, 255, 255, 0.4)',
    };

    const state = {
        targetSpeed: 0,
        currentSpeed: 0,
        targetFuel: 100,
        currentFuel: 100,
        targetHealth: 100,
        currentHealth: 100,
        odo: 0,
        engineOn: false,
        locked: false,
        seatbelt: false,
    };

    let canvas = null;
    let ctx = null;
    let running = false;
    let active = false;

    function clamp(value, min, max, fallback = min) {
        const parsed = Number(value);
        return Number.isFinite(parsed) ? Math.max(min, Math.min(max, parsed)) : fallback;
    }

    function lerp(start, end, amount) {
        return (1 - amount) * start + amount * end;
    }

    function drawRoundedRect(x, y, width, height, radius, fillStyle) {
        if (width <= 0 || height <= 0) return;
        const r = Math.min(radius, width / 2, height / 2);
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + width - r, y);
        ctx.quadraticCurveTo(x + width, y, x + width, y + r);
        ctx.lineTo(x + width, y + height - r);
        ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
        ctx.lineTo(x + r, y + height);
        ctx.quadraticCurveTo(x, y + height, x, y + height - r);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
        ctx.fillStyle = fillStyle;
        ctx.fill();
    }

    function drawDashboardIcon(x, y, label, isActive, activeColor) {
        const width = 42;
        const height = 20;
        const left = x - width / 2;
        const top = y - height / 2;
        drawRoundedRect(left, top, width, height, 4,
            isActive ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.4)');
        if (isActive) drawRoundedRect(left, top, width, 2, 1, activeColor);

        ctx.fillStyle = isActive ? theme.white : theme.muted;
        ctx.font = "bold 10px Montserrat, 'Chakra Petch', sans-serif";
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(label, x, y + 1);
        if (isActive) {
            ctx.shadowBlur = 8;
            ctx.shadowColor = activeColor;
            ctx.fillText(label, x, y + 1);
            ctx.shadowBlur = 0;
        }
    }

    function render() {
        if (!ctx) return;
        if (!active) return;
        ctx.clearRect(0, 0, SIZE, SIZE);

        state.currentSpeed = lerp(state.currentSpeed, state.targetSpeed, 0.1);
        state.currentFuel = lerp(state.currentFuel, state.targetFuel, 0.05);
        state.currentHealth = lerp(state.currentHealth, state.targetHealth, 0.05);

        const speedPct = Math.min(state.currentSpeed / MAX_SPEED, 1);
        const currentAngle = START_ANGLE + ARC_RANGE * speedPct;
        const displaySpeed = Math.floor(state.currentSpeed);

        ctx.beginPath();
        ctx.arc(CX, CY, RADIUS + 15, START_ANGLE, END_ANGLE);
        ctx.lineWidth = 4;
        ctx.strokeStyle = theme.darkRing;
        ctx.lineCap = 'round';
        ctx.stroke();

        const tickCount = 70;
        for (let i = 0; i <= tickCount; i += 1) {
            const pct = i / tickCount;
            const angle = START_ANGLE + ARC_RANGE * pct;
            const isMajor = i % 10 === 0;
            const isRedline = pct > 0.85;
            const length = isMajor ? 12 : 5;
            const innerRadius = RADIUS - length;

            ctx.beginPath();
            ctx.moveTo(CX + Math.cos(angle) * innerRadius, CY + Math.sin(angle) * innerRadius);
            ctx.lineTo(CX + Math.cos(angle) * RADIUS, CY + Math.sin(angle) * RADIUS);
            ctx.lineWidth = isMajor ? 3 : 1.5;
            if (angle <= currentAngle) {
                ctx.strokeStyle = isRedline ? theme.redline : theme.white;
                if (isMajor) {
                    ctx.shadowBlur = 8;
                    ctx.shadowColor = ctx.strokeStyle;
                }
            } else {
                ctx.strokeStyle = isRedline ? 'rgba(255, 51, 102, 0.3)' : theme.tickBase;
            }
            ctx.stroke();
            ctx.shadowBlur = 0;
        }

        if (speedPct > 0.01) {
            ctx.beginPath();
            ctx.arc(CX, CY, RADIUS + 15, START_ANGLE, currentAngle);
            ctx.lineWidth = 4;
            ctx.strokeStyle = speedPct > 0.85 ? theme.redline : theme.white;
            ctx.lineCap = 'round';
            ctx.shadowBlur = 12;
            ctx.shadowColor = ctx.strokeStyle;
            ctx.stroke();
            ctx.shadowBlur = 0;
        }

        ctx.font = "italic 900 78px Montserrat, 'Chakra Petch', sans-serif";
        ctx.textAlign = 'center';
        ctx.textBaseline = 'alphabetic';
        const speedStr = Math.min(displaySpeed, 999).toString().padStart(3, '0');
        let xOffset = CX - 35;
        for (let i = 0; i < 3; i += 1) {
            const character = speedStr[i];
            ctx.fillStyle = character === '0' && displaySpeed < Math.pow(10, 2 - i) && i < 2
                ? 'rgba(255,255,255,0.15)'
                : theme.white;
            ctx.fillText(character, xOffset, CY + 10);
            xOffset += 50;
        }

        ctx.fillStyle = theme.muted;
        ctx.font = "italic 700 14px Montserrat, 'Chakra Petch', sans-serif";
        ctx.fillText('KM/H', CX, CY + 35);

        drawDashboardIcon(CX - 50, CY - 85, 'ENG', state.engineOn, theme.success);
        drawDashboardIcon(CX, CY - 100, 'LCK', state.locked, theme.warning);
        drawDashboardIcon(CX + 50, CY - 85, 'BLT', state.seatbelt, theme.success);

        const barWidth = 80;
        const barHeight = 4;
        const fuelX = CX - 95;
        const barY = CY + 80;
        ctx.fillStyle = theme.muted;
        ctx.font = "bold 10px Montserrat, 'Chakra Petch', sans-serif";
        ctx.textAlign = 'left';
        ctx.fillText('FUEL', fuelX, barY - 6);
        drawRoundedRect(fuelX, barY, barWidth, barHeight, 2, 'rgba(255,255,255,0.1)');
        drawRoundedRect(fuelX, barY, barWidth * state.currentFuel / 100, barHeight, 2,
            state.currentFuel < 20 ? theme.redline : theme.white);

        const healthX = CX + 15;
        ctx.fillStyle = theme.muted;
        ctx.textAlign = 'right';
        ctx.fillText('HLTH', healthX + barWidth, barY - 6);
        drawRoundedRect(healthX, barY, barWidth, barHeight, 2, 'rgba(255,255,255,0.1)');
        drawRoundedRect(healthX, barY, barWidth * state.currentHealth / 100, barHeight, 2,
            state.currentHealth < 35 ? theme.redline : theme.success);

        ctx.fillStyle = theme.muted;
        ctx.font = "bold 11px Montserrat, 'Chakra Petch', sans-serif";
        ctx.textAlign = 'center';
        ctx.fillText(`ODO  ${state.odo.toFixed(1).padStart(7, '0')}`, CX, CY + 125);
    }

    function frame() {
        render();
        window.requestAnimationFrame(frame);
    }

    function init() {
        if (running) return true;
        canvas = document.getElementById('forza-speedo-canvas');
        if (!canvas) return false;
        ctx = canvas.getContext('2d');
        if (!ctx) return false;

        const dpr = Math.max(1, window.devicePixelRatio || 1);
        canvas.width = SIZE * dpr;
        canvas.height = SIZE * dpr;
        canvas.style.width = `${SIZE}px`;
        canvas.style.height = `${SIZE}px`;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        running = true;
        window.requestAnimationFrame(frame);
        return true;
    }

    window.ForzaSpeedometer = {
        setActive(value) {
            if (!running) init();
            active = value === true;
            if (!active) {
                state.targetSpeed = 0;
                state.currentSpeed = 0;
                if (ctx) ctx.clearRect(0, 0, SIZE, SIZE);
            }
        },
        update(data = {}) {
            if (!running && !init()) return;
            state.targetSpeed = clamp(data.speed, 0, 999, 0);
            state.targetFuel = data.showFuel === false ? 0 : clamp(data.fuel, 0, 100, 100);
            state.targetHealth = clamp(Number(data.engine) / 10, 0, 100, 100);
            state.odo = clamp(data.odometer, 0, 9999999, 0);
            state.engineOn = data.engineOn === true;
            state.locked = data.locked === true;
            state.seatbelt = data.seatbelt === true;
        },
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init, { once: true });
    } else {
        init();
    }
})();
