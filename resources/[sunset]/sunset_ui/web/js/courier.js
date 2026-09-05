const Courier = (() => {
    const root = () => document.getElementById('courier-panel');
    const get = (id) => document.getElementById(id);

    function renderMessage(message, key) {
        const target = get('courier-message');
        if (!target) return;
        target.replaceChildren();
        const text = String(message || 'Follow the GPS route');
        const marker = '{key}';
        const index = text.indexOf(marker);
        if (!key || index < 0) {
            target.textContent = text;
            return;
        }
        target.append(document.createTextNode(text.slice(0, index)));
        const keycap = document.createElement('span');
        keycap.className = 'courier__key';
        keycap.textContent = String(key).slice(0, 4);
        target.append(keycap, document.createTextNode(text.slice(index + marker.length)));
    }

    function show(data = {}) {
        const panel = root();
        if (!panel) return;
        const state = String(data.state || 'route').replace(/[^a-z-]/gi, '').toLowerCase() || 'route';
        panel.className = `courier-shell state-${state} is-visible`;
        panel.classList.remove('hidden');
        if (get('courier-title')) get('courier-title').textContent = data.title || 'Courier';
        if (get('courier-counter')) get('courier-counter').textContent = data.counter || 'Package 0/0';
        if (get('courier-detail')) get('courier-detail').textContent = data.detail || '';
        if (get('courier-progress')) {
            const progress = Math.max(0, Math.min(100, Number(data.progress) || 0));
            get('courier-progress').style.width = `${progress}%`;
        }
        renderMessage(data.message, data.key);
    }

    function hide() {
        const panel = root();
        if (!panel) return;
        panel.className = 'courier-shell hidden state-route';
    }

    return { show, update: show, hide };
})();

window.Courier = Courier;
