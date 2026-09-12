-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Anti-Exploit & Security Shield (server/security.lua)
-- ═══════════════════════════════════════════════════════════════

Sunset = Sunset or {}
Sunset.Security = Sunset.Security or {}

local BANNED_WEAPONS = {
    [`WEAPON_RPG`] = 'RPG',
    [`WEAPON_HOMINGLAUNCHER`] = 'Homing Launcher',
    [`WEAPON_MINIGUN`] = 'Minigun',
    [`WEAPON_RAILGUN`] = 'Railgun',
    [`WEAPON_COMPACTLAUNCHER`] = 'Compact Launcher',
    [`WEAPON_FIREWORK`] = 'Firework Launcher',
}

local LastCoords = {}
local LastCoordTimes = {}
local RateLimiters = {}

-- [AUDIT P7-10] Per-source webhook throttle: one glitchy/griefing player could
-- re-trigger a security webhook every 5s scan (Discord 429s at ~5/min).
local LastAlertAt = {}
local function alertThrottled(src, kind, cooldownMs)
    local key = src .. ':' .. kind
    local now = GetGameTimer()
    if LastAlertAt[key] and (now - LastAlertAt[key]) < (cooldownMs or 300000) then
        return true
    end
    LastAlertAt[key] = now
    return false
end

-- Rate limiter utility for sensitive callbacks and events
function Sunset.Security.RateLimit(source, action, minDelayMs)
    local now = GetGameTimer()
    RateLimiters[source] = RateLimiters[source] or {}
    local last = RateLimiters[source][action] or 0

    if (now - last) < (minDelayMs or 300) then
        return false -- Throttled
    end

    RateLimiters[source][action] = now
    return true
end

exports('RateLimit', Sunset.Security.RateLimit)

-- Periodic integrity scanner
CreateThread(function()
    while true do
        Wait(5000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if src then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    -- 1. Blacklisted weapon check
                    local currentWep = GetSelectedPedWeapon(ped)
                    if BANNED_WEAPONS[currentWep] then
                        RemoveWeaponFromPed(ped, currentWep)
                        local wepName = BANNED_WEAPONS[currentWep]
                        local char = exports.sunset_core:GetCharacter(src)
                        local pName = GetPlayerName(src) or 'Necunoscut'

                        print(('[SECURITY ALERT] Player %s (Src: %d, Char: %s) flagged with banned weapon: %s'):format(
                            pName, src, char and tostring(char.id) or 'N/A', wepName
                        ))

                        -- [AUDIT P7-10] Webhook at most once per 5 min per player
                        -- (the weapon is still removed every scan regardless).
                        if not alertThrottled(src, 'weapon', 300000) then
                            Sunset.Discord.Send('security', 'ALERTA SECURITATE: ARMA ILEGALA DETECTATA',
                                ('Jucatorul **%s** a incercat sa foloseasca o arma interzisa.'):format(pName), 'red', {
                                    { name = 'Jucator', value = pName, inline = true },
                                    { name = 'Server ID', value = tostring(src), inline = true },
                                    { name = 'Caracter ID', value = char and tostring(char.id) or 'N/A', inline = true },
                                    { name = 'Arma Detectata', value = wepName, inline = true },
                                }
                            )
                        end

                        TriggerClientEvent('sunset:client:notify', src,
                            'Arma neautorizata confiscata automat de sistemul de securitate.', 'error', 8000)
                    end

                    -- 2. Teleport / impossible velocity check
                    local coords = GetEntityCoords(ped)
                    local last = LastCoords[src]
                    local lastTime = LastCoordTimes[src] or 0
                    local now = GetGameTimer()
                    local dt = (now - lastTime) / 1000.0

                    if last and dt >= 1.0 and dt <= 6.0 then
                        local dist = #(coords - last)
                        local speed = dist / dt
                        local inVeh = IsPedInAnyVehicle(ped, false)
                        local maxAllowedSpeed = inVeh and 140.0 or 35.0 -- m/s (140 m/s = 500 km/h)

                        -- [AUDIT P2-06] Guarded: if sunset_admin is stopped/restarting this
                        -- call errors and would kill the whole scanner thread.
                        local isAdmin = false
                        if GetResourceState('sunset_admin') == 'started' then
                            local ok, res = pcall(function() return exports.sunset_admin:IsAdmin(src, 1) end)
                            isAdmin = ok and res == true
                        end

                        -- [AUDIT P2-06] The computed speed was previously unused; flag
                        -- sustained impossible velocity as well as raw distance jumps.
                        local speedAnomaly = speed > maxAllowedSpeed * 2.5 and dt >= 2.0
                        if (dist > 350.0 or speedAnomaly) and not isAdmin then
                            local char = exports.sunset_core:GetCharacter(src)
                            local pName = GetPlayerName(src) or 'Necunoscut'

                            print(('[SECURITY] Teleport anomaly flagged for %s: %.1fm in %.1fs'):format(pName, dist, dt))

                            -- [AUDIT P7-10] Throttle the webhook (5 min per player);
                            -- console log still fires every anomaly.
                            if not alertThrottled(src, 'teleport', 300000) then
                                Sunset.Discord.Send('security', 'ANOMALIE DE MISCARE (TELEPORT SUSPECT)',
                                    ('Jucatorul **%s** s-a deplasat o distanta nefireasca intr-un interval foarte scurt.'):format(pName), 'orange', {
                                        { name = 'Jucator', value = pName, inline = true },
                                        { name = 'Distanta', value = ('%.1f metri'):format(dist), inline = true },
                                        { name = 'Timp', value = ('%.2f secunde'):format(dt), inline = true },
                                        { name = 'In Vehicul', value = inVeh and 'DA' or 'NU', inline = true },
                                    }
                                )
                            end
                        end
                    end

                    LastCoords[src] = coords
                    LastCoordTimes[src] = now
                end
            end
        end
    end
end)

-- [AUDIT 3-8.3] explosionEvent gate: previously absent, so grenades/RPG/C4 were
-- completely ungated. Allow only RP-plausible explosion types and log the rest.
-- Effective with OneSync (enabled in server.cfg as of this audit).
local ALLOWED_EXPLOSIONS = {
    [0] = true,  -- GRENADE
    [2] = true,  -- MOLOTOV
    [3] = true,  -- ROCKET
    [5] = true,  -- CAR (vehicle fuel explosion)
    [6] = true,  -- PLANE
    [7] = true,  -- PETROL PUMP
    [8] = true,  -- BIKE
    [9] = true,  -- STEAM
    [12] = true, -- FLARE
    [17] = true, -- TANKER
    [19] = true, -- VEHICLE BULLET
    [23] = true, -- VEHICLE ROCKET
    [29] = true, -- SCRIPT FIRE
}

AddEventHandler('explosionEvent', function(sender, ev)
    local expType = tonumber(ev and ev.explosionType)
    if expType == nil then CancelEvent() return end
    if not ALLOWED_EXPLOSIONS[expType] then
        local name = GetPlayerName(sender) or 'unknown'
        print(('[SECURITY] Blocked explosion type %d from %s (%d)'):format(expType, name, sender))
        -- [AUDIT P7-10] One griefer could spam blocked explosions into a 429.
        if Sunset.Discord and Sunset.Discord.Send and not alertThrottled(sender, 'explosion', 300000) then
            pcall(function()
                Sunset.Discord.Send('security', 'EXPLOZIE BLOCATA',
                    ('Tip explozie **%d** blocat de la **%s** (id %d).'):format(expType, name, sender), 'red')
            end)
        end
        CancelEvent()
    end
end)

AddEventHandler('playerDropped', function()
    LastCoords[source] = nil
    LastCoordTimes[source] = nil
    RateLimiters[source] = nil
    for key in pairs(LastAlertAt) do
        if key:sub(1, #(source .. ':')) == (source .. ':') then
            LastAlertAt[key] = nil
        end
    end
end)
