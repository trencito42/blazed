# SunsetMP / Blazed — Ghid colaborare (pentru echipă + Claude Code)

> **Pentru prietenul care lucrează cu Claude Code:** deschide acest fișier în proiect și spune lui Claude:
> *„Citește `docs/COLLABORATION.md` și lucrează după regulile de aici.”*
>
> Documentul e scris simplu (ELI5) — nu trebuie să fii developer ca să contribui.

---

## 1. Ce este proiectul (în 30 secunde)

- **Ce:** server **FiveM RPG** custom (GTA Online multiplayer), brand **blaze.mp / SunsetMP**
- **Nu folosim** QBCore / ESX — tot gamemode-ul e făcut de noi (`sunset_*`)
- **Repo GitHub (public):** https://github.com/trencito42/blazed
- **Branch principal:** `main`
- **Server live:** VPS cu **Coolify** + Docker (FiveM + MariaDB)

---

## 2. Unde rulează serverul

| Ce | Valoare |
|----|---------|
| **IP public** | `193.33.167.216` |
| **Port joc** | `30120` (TCP + UDP) |
| **Conectare în GTA** | `F8` → `connect 193.33.167.216:30120` |
| **txAdmin** (setup/admin web) | `http://193.33.167.216:40120` (dacă e deschis) |
| **Panel deploy** | **Coolify** pe același VPS (Stefan are acces) |

### Unde stă codul pe VPS (important pentru SSH)

Deploy-ul Coolify pentru SunsetMP rulează aici (doar **root** are acces complet):

```
/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i/
```

În acel folder găsești: `deploy.sh`, `docker-compose.yml`, `resources/`, `sql/`, `.env` (parole — **nu** e în Git).

Containerul FiveM live (nume tipic):

```
b0n1oc2fcrzbgdco838ezm1i-fivem-1
```

---

## 3. Cum te conectezi la VPS (SSH)

### Ce îți trebuie de la Stefan (one-time)

1. **Cheie SSH** — fie îți dă cheia privată `sshxodo`, fie îți pui **cheia ta publică** în `/root/.ssh/authorized_keys` pe server
2. **Confirmare** că userul `root@193.33.167.216` merge cu cheia ta
3. Parolele din `.env` (LICENSE_KEY, MariaDB) — **nu** sunt în repo; le primești separat, nu le pui în chat public

### Test conexiune (Windows PowerShell / Mac / Linux)

```bash
ssh -i ~/.ssh/sshxodo root@193.33.167.216
```

Dacă intri, ești ok. Dacă „Permission denied”, Stefan trebuie să adauge cheia ta pe root (vezi `README.md` secțiunea „autorizează cheia pe root”).

### După SSH — comenzi utile

```bash
# Mergi la proiectul de pe server
cd /data/coolify/services/b0n1oc2fcrzbgdco838ezm1i

# Deploy complet (pull GitHub + build Docker + migrări SQL + restart FiveM)
./deploy.sh

# Loguri server FiveM
docker logs -f b0n1oc2fcrzbgdco838ezm1i-fivem-1

# Restart doar container FiveM
docker restart b0n1oc2fcrzbgdco838ezm1i-fivem-1

# Consolă în container (txAdmin / comenzi server)
docker exec -it b0n1oc2fcrzbgdco838ezm1i-fivem-1 bash
```

**Notă:** userii `loadport` / `blipmade-*` pot avea SSH, dar **nu** au acces la folderul Coolify de deploy. Pentru deploy ai nevoie de **root** sau de scriptul de pe PC-ul lui Stefan.

---

## 4. Clone repo pe PC-ul tău (lucru local)

```bash
git clone https://github.com/trencito42/blazed.git
cd blazed
```

Deschide folderul în **Cursor** (sau VS Code) și folosește **Claude Code** în chat.

### Structură simplă

```
blazed/
├── resources/[sunset]/     ← TOATE resursele gamemode (Lua + uneori web)
│   ├── sunset_core/        ← framework (personaje, items, callbacks)
│   ├── sunset_ui/          ← interfață NUI (HTML/CSS/JS) — inventar, HUD, chat
│   ├── sunset_inventory/   ← inventar + trade
│   ├── sunset_jobs/        ← joburi
│   ├── sunset_jobcreator/  ← editor joburi in-game
│   ├── sunset_hud/         ← logică HUD client
│   ├── sunset_factions/    ← poliție, EMS, etc.
│   └── ... (~35 resurse sunset_*)
├── sql/                    ← migrări baza de date (01-23+)
├── deploy.sh               ← script deploy pe VPS
├── docker-compose.yml
├── config/                 ← server.cfg template
├── docs/                   ← documentație
└── scripts/
    ├── remote-deploy.ps1   ← deploy de pe Windows (Stefan)
    ├── push-live-vps.sh
    └── hotfix-sync-vps.sh
```

### Unde se modifică ce (cheat sheet)

| Vrei să schimbi… | Unde |
|------------------|------|
| Butoane, inventar, HUD vizual | `resources/[sunset]/sunset_ui/web/` (`index.html`, `js/`, `css/`) |
| Logică inventar / trade | `sunset_inventory/client/` + `server/` |
| Comenzi chat `/f`, `/help` | `sunset_chat/`, `sunset_factions/server/chat.lua` |
| Joburi (miner, trucker…) | `sunset_jobcreator/`, `sunset_jobs/` |
| Iteme noi | `sunset_core/shared/items.lua` + icon în `sunset_ui/web/assets/items/` |
| SQL tabele noi | `sql/XX-nume.sql` (număr următor liber) |

### UI / NUI — cache în joc

După modificări CSS/JS, mărește versiunea în `index.html`, ex.:

```html
<link rel="stylesheet" href="css/hud.css?v=10">
<script src="js/panels.js?v=10"></script>
```

Apoi în consola txAdmin (fără restart container):

```
refresh
ensure sunset_ui
```

Pentru logică Lua (nu doar NUI): `restart sunset_inventory` etc. — tot din txAdmin, fără `docker compose restart`.

**Notă:** txAdmin e dezactivat pe producție (`TXADMIN_ENABLE=0`) până la deploy cu entrypoint reparat — altfel serverul intra în crash loop. Fără txAdmin, după `push-live-vps.ps1` poți reîncărca o resursă cu:

```bash
docker exec -it b0n1oc2fcrzbgdco838ezm1i-fivem-1 sh -c 'printf "ensure sunset_ui\n" > /proc/1/fd/0'
```

Deploy complet (`./deploy.sh` / `remote-deploy.ps1`) când schimbi Docker, SQL migrations noi, sau dependențe.

---

## 5. Workflow-ul nostru (colaborare în timp real)

```
┌─────────────┐     git push      ┌──────────────┐     deploy.sh      ┌─────────────┐
│  Stefan PC  │ ───────────────►  │ GitHub main  │ ────────────────►  │  VPS live   │
│  (Cursor)   │                   │ trencito42/  │                    │  FiveM      │
└─────────────┘                   │   blazed     │                    └─────────────┘
       ▲                          └──────────────┘                           ▲
       │                                 ▲                                    │
       │         git push                │                                    │
┌─────────────┐                         │                                    │
│  Prieten PC │ ────────────────────────┘                                    │
│ (Claude Code)│         (coordonați cine face deploy)                       │
└─────────────┘ ─────────────────────────────────────────────────────────────┘
```

### Reguli de echipă

1. **Lucrați pe `main`** (sau branch scurt + merge rapid) — comunicați pe Discord/WhatsApp cine lucrează la ce
2. **Înainte de push:** `git pull` ca să nu suprascrieți munca celuilalt
3. **Deploy pe live:** vorbiți — „fac push, deploy acum?” — evitați 2 deploy-uri simultan
4. **Nu faceți** `git push --force` pe `main`
5. **Nu comiteți** `.env`, parole, `SETUP.local.md`, chei private
6. **Commit-uri:** mesaj scurt în engleză sau română, ex. `fix: trade drag drop in inventory UI`
7. După deploy: reconectare în joc + test rapid la ce ați schimbat

### Deploy de pe Windows (Stefan)

```powershell
cd C:\Users\stefan\Documents\sunsetmp
git add ...
git commit -m "descriere"
git push origin main
.\scripts\remote-deploy.ps1
```

### Deploy manual pe VPS (dacă ai root)

```bash
cd /data/coolify/services/b0n1oc2fcrzbgdco838ezm1i
./deploy.sh
```

`deploy.sh` face: pull de pe GitHub → build imagine FiveM → migrări SQL → restart containere.

### Restart rapid o resursă (fără deploy complet)

În consola server / txAdmin / F8 admin:

```
restart sunset_ui
restart sunset_inventory
restart sunset_jobcreator
```

Sau restart container întreg: `docker restart b0n1oc2fcrzbgdco838ezm1i-fivem-1`

---

## 6. Dev local (opțional, pe PC)

Pentru test fără VPS:

1. Instalează **FiveM FXServer** + **MariaDB**
2. Copiază `server.cfg` din root, setează DB local (vezi `SETUP.local.md` — doar local, nu în Git)
3. Pornește DB + `FXServer.exe +exec server.cfg`

Majoritatea echipei testează direct pe **serverul live** după deploy — e mai simplu dacă nu ai FXServer configurat.

---

## 7. Instrucțiuni pentru Claude Code (paste la începutul sesiunii)

Copiază blocul de mai jos în chat-ul Claude Code când lucrezi la proiect:

---

```
Ești asistentul meu pe proiectul SunsetMP (FiveM RPG), repo: https://github.com/trencito42/blazed, branch main.

Citește docs/COLLABORATION.md din repo pentru infrastructură și workflow.

CONTEXT TEHNIC:
- Server live: 193.33.167.216:30120, deploy Coolify Docker, path VPS: /data/coolify/services/b0n1oc2fcrzbgdco838ezm1i/
- Gamemode în resources/[sunset]/sunset_* (Lua client/server + NUI în sunset_ui/web)
- UI: HTML/CSS/JS în sunset_ui; după edit CSS/JS bump ?v= în index.html
- Deploy: git push main → ./deploy.sh pe VPS (sau scripts/remote-deploy.ps1 de pe Windows)
- Nu comite secrete; nu force push main; git pull înainte de lucru

STIL LUCRU (utilizator non-developer):
- Explică simplu ce faci și de ce
- Schimbări mici, focalizate — nu refactoriza tot
- După edit UI, spune ce resursă să restart (ex. restart sunset_ui)
- Când e gata, dă pașii exacți: ce fișiere, ce commit message, cine face push/deploy
- Răspunde în română dacă utilizatorul scrie în română
- Rulează tu comenzile (git, teste) când ai acces la terminal; nu doar „rulează X”

DOCUMENTAȚIE EXTRA: docs/COMMANDS.md, docs/JOBS.md, docs/JOB_CREATOR_ARCHITECTURE.md, README.md, DEPLOY.md
```

---

## 8. Primul admin în joc

După ce intri pe server, în consola server (txAdmin):

```
sunset_setowner 1
```

(`1` = ID-ul tău de pe server când ești conectat)

---

## 9. Probleme frecvente

| Problemă | Soluție |
|----------|---------|
| UI vechi în joc după deploy | Bump `?v=` la CSS/JS + `restart sunset_ui` |
| SSH „Permission denied” | Cheia nu e pe `root` — cere lui Stefan să o adauge |
| Deploy eșuează la SQL | Migrarea poate fi deja aplicată; vorbește cu Stefan, nu șterge DB |
| Modificările nu apar pe live | Ai făcut push? A rulat cineva `deploy.sh`? Coolify Restart singur **nu** face git pull |
| Conflict git | `git pull`, rezolvă conflictele, apoi push |

---

## 10. Contact / acces

- **Repo:** https://github.com/trencito42/blazed
- **Acces GitHub:** Stefan te adaugă ca collaborator (Settings → Collaborators) ca să poți push
- **SSH VPS:** cheie + root authorized_keys — cere lui Stefan
- **Parole .env / txAdmin:** private, doar între voi

---

*Ultima actualizare: martie 2026 — întreabă-l pe Stefan dacă IP-ul sau path-ul Coolify s-a schimbat.*
