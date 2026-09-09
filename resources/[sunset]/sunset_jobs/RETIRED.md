# Active — loaded on server

`sunset_jobs` is **started** via `ensure sunset_jobs` in `config/server.cfg.template`.

Hardcoded civilian jobs (config in `sunset_core/shared/jobs_config.lua`):

- trucker, garbage, courier, fisherman, mechanic

Commands: `/jobs`, `/work`, `/jobhelp`, `/fish` (fisherman). Fishing hire also via `sunset_fishingshop` NPC.

`sunset_jobcreator` is **not** started — editor/templates remain in repo for later.
