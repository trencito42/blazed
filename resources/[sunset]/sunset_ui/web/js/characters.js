const Characters = {
    list: [],
    selectedGender: 0,
    nationalities: [
        'Romanian', 'American', 'British', 'French', 'German',
        'Italian', 'Spanish', 'Russian', 'Turkish', 'Other'
    ],

    init(data) {
        this.list = data.characters || [];
        $('#player-name').textContent = data.playerName || 'Player';

        const container = $('#characters-list');
        container.innerHTML = '';

        this.list.forEach((char) => {
            container.appendChild(this.createSlot(char));
        });

        if (this.list.length < (data.maxSlots || 3)) {
            const empty = document.createElement('div');
            empty.className = 'slot slot--empty';
            empty.textContent = '+ Empty Slot';
            empty.addEventListener('click', () => this.openCreate());
            container.appendChild(empty);
        }

        $('#btn-create-char').onclick = () => this.openCreate();
    },

    createSlot(char) {
        const el = document.createElement('div');
        el.className = 'slot';

        const lastPlayed = char.last_played
            ? new Date(char.last_played).toLocaleDateString('ro-RO')
            : '—';

        el.innerHTML = `
            <button class="slot__delete" title="Delete">✕</button>
            <div class="slot__name">${char.firstname} ${char.lastname}</div>
            <div class="slot__meta">$${char.cash} · ${lastPlayed}</div>
        `;

        el.addEventListener('click', (e) => {
            if (e.target.closest('.slot__delete')) return;
            this.select(char.id);
        });

        el.querySelector('.slot__delete').addEventListener('click', (e) => {
            e.stopPropagation();
            this.delete(char.id);
        });

        return el;
    },

    initCreate(data = {}) {
        this.selectedGender = 0;
        this.firstLogin = data.firstLogin === true;

        const sel = $('#nationality');
        sel.innerHTML = '';
        (data.nationalities || this.nationalities).forEach(n => {
            const opt = document.createElement('option');
            opt.value = n;
            opt.textContent = n;
            sel.appendChild(opt);
        });

        const suggested = (data.suggestedName || '').trim();
        if (suggested) {
            const parts = suggested.split(/[\s_]+/);
            $('#firstname').value = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
            $('#lastname').value = parts[1]
                ? parts[1].charAt(0).toUpperCase() + parts[1].slice(1)
                : 'Player';
        } else {
            $('#firstname').value = '';
            $('#lastname').value = '';
        }

        const backBtn = $('#btn-back-select');
        if (backBtn) {
            backBtn.style.display = this.firstLogin ? 'none' : '';
        }

        $$('.toggle__btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.gender === '0');
            btn.onclick = () => {
                $$('.toggle__btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.selectedGender = parseInt(btn.dataset.gender);
            };
        });

        $('#btn-back-select').onclick = () => post('characterBack');

        $('#create-form').onsubmit = (e) => {
            e.preventDefault();
            this.submit();
        };
    },

    openCreate() {
        post('characterCreate');
    },

    select(charId) {
        post('select', { charId });
    },

    delete(charId) {
        post('delete', { charId });
    },

    submit() {
        const data = {
            firstname: $('#firstname').value.trim(),
            lastname: $('#lastname').value.trim(),
            dateofbirth: $('#dateofbirth').value,
            nationality: $('#nationality').value,
            gender: this.selectedGender,
        };

        if (!data.firstname || !data.lastname || !data.dateofbirth) {
            notify('Please fill in all fields', 'error');
            return;
        }

        post('create', data);
    },
};

window.Characters = Characters;
