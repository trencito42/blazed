# Interaction HUD (fishing-panel) — preserved UI

Civilian jobs and Job Creator were removed from the server, but the **bottom-center interaction HUD** is kept for future activities (fishing, mining, zone prompts, jail timer, etc.).

## Visual reference

Screenshot from production (Fisherman / Job Creator):

- **Title row:** icon + `FISHERMAN` (cyan)
- **Counter:** `TASK 0/4` (or `Bag 2/5`)
- **Prompt:** `PRESS [E] TO FISH · TASK 0/4` with styled `E` keycap
- **Progress bar** under the message (bite timer, work duration, jail sentence)

Prototype HTML: `docs/prototypes/fishing_minigame_ui.html`

## Files to keep (do not delete)

| File | Purpose |
|------|---------|
| `sunset_ui/web/index.html` | `#fishing-panel` markup |
| `sunset_ui/web/css/fishing.css` | All `.fishing-*` styles + state classes |
| `sunset_ui/web/js/fishing.js` | `window.Fishing` — show/update/hide |
| `sunset_ui/web/js/job_icons.js` | `window.JobIcons` — SVG icons in header |
| `sunset_ui/web/js/app.js` | Routes `fishingShow`, `fishingUpdate`, `fishingHide` |

## Lua API (from any client script)

```lua
exports.sunset_ui:Send('fishingShow', {
    title = 'Fisherman',
    message = 'Press {key} to fish',  -- {key} or literal E → keycap
    icon = 'fish',                    -- job_icons.js id
    bagLabel = 'Task',                -- counter prefix (default: Bag)
    carried = 0,
    capacity = 4,
    state = 'shift',                  -- see states below
    windowMs = 1500,                  -- progress bar duration (bite/work)
})

exports.sunset_ui:Send('fishingUpdate', { state = 'bite', windowMs = 1200 })
exports.sunset_ui:Send('fishingHide', {})
```

### States (`data.state`)

| State | Use |
|-------|-----|
| `idle` | Default prompt |
| `shift` | On shift, go to marker |
| `work` | Timed action (progress bar fills) |
| `bite` | Reaction window — press E fast |
| `waiting` | Line cast / waiting |
| `success` / `failed` | Feedback flash |
| `full` | Capacity reached |
| `jail` | Prison timer (`remainingSec`, `totalSec`) |

### Still using this HUD

- `sunset_factions/client/police.lua` — jail sentence display (`state = 'jail'`)

## Removed (not part of preserved UI)

- `sunset_jobs`, `sunset_jobcreator` resources (not started)
- `#job-shift-panel`, `#courier-panel`, `#job-creator-panel`
- `#jobs-browser`, `#jobcenter`, `#jobs-panel`
- `#job-objective` corner overlay (legacy trucker/garbage)

## Re-adding fishing later

1. New resource (e.g. `sunset_fishing`) with client zones + server validation
2. Call `fishingShow` / `fishingUpdate` / `fishingHide` only — no Job Creator needed
3. Copy gameplay logic from git history: `sunset_jobs/client/fisherman.lua` + `server/fisherman.lua`
