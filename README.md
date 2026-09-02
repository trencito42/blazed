# Blazed / SunsetMP — FiveM RPG

Server FiveM RPG custom (framework propriu, UI Sunset, HUD, chat SAMP-style, admin).

## Deploy pe Coolify (VPS)

### 1. Environment variables (obligatorii)

| Variabilă | Descriere |
|-----------|-----------|
| `LICENSE_KEY` | Cheia FiveM de pe [keymaster.fivem.net](https://keymaster.fivem.net) |
| `MARIADB_ROOT_PASSWORD` | Parolă root MariaDB |
| `MARIADB_PASSWORD` | Parolă user `sunset` (folosită și de oxmysql) |
| `MARIADB_USER` | `sunset` (default) |
| `MARIADB_DATABASE` | `sunsetmp` (default) |

### 2. Porturi de deschis pe firewall

- **30120** TCP + UDP — joc FiveM
- **40120** TCP — txAdmin (opțional, setup inițial)

### 3. Conectare în joc

```
F8 → connect 193.33.167.216:30120
```

### 4. Primul admin (consolă container FiveM / Coolify logs)

```
sunset_setowner 1
```

### 5. txAdmin (prima pornire)

Accesează `http://IP_VPS:40120` pentru setup txAdmin dacă e prima rulare.

## Structură

```
docker-compose.yml      # FiveM + MariaDB
config/                 # server.cfg.template
docker/fivem/           # Dockerfile + entrypoint
resources/[sunset]/     # Gamemode
resources/oxmysql/        # MySQL driver
sql/                    # Schema DB (auto-import la prima pornire)
```

## Dev local (Windows)

Folosește `server.cfg` din root + FXServer local + MariaDB pe PC.

## Licență

Proprietate privată © 2026
