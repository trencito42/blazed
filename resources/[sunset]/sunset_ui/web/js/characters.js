const Characters = {
    list: [],
    selectedGender: 0,
    nationalities: [
        'Romanian', 'American', 'British', 'French', 'German',
        'Italian', 'Spanish', 'Russian', 'Turkish', 'Other'
    ],

    init(data) {
        this.list = data.characters || [];
        $('#player-name').textContent = data.playerName || 'Jucător';

        const container = $('#characters-list');
        container.innerHTML = '';

        this.list.forEach((char) => {
            container.appendChild(this.createSlot(char));
        });

        if (this.list.length < (data.maxSlots || 3)) {
            const empty = document.createElement('div');
            empty.className = 'slot slot--empty';
            empty.textContent = '+ Slot liber';
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
            <button class="slot__delete" title="Șterge">✕</button>
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

    initCreate() {
        this.selectedGender = 0;

        const sel = $('#nationality');
        sel.innerHTML = '';
        this.nationalities.forEach(n => {
            const opt = document.createElement('option');
            opt.value = n;
            opt.textContent = n;
            sel.appendChild(opt);
        });

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
            notify('Completează toate câmpurile', 'error');
            return;
        }

        post('create', data);
    },
};

window.Characters = Characters;
