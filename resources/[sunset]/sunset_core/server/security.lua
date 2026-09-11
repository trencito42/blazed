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

                        Sunset.Discord.Send('security', 'ALERTA SECURITATE: ARMA ILEGALA DETECTATA',
                            ('Jucatorul **%s** a incercat sa foloseasca o arma interzisa.'):format(pName), 'red', {
                                { name = 'Jucator', value = pName, inline = true },
                                { name = 'Server ID', value = tostring(src), inline = true },
                                { name = 'Caracter ID', value = char and tostring(char.id) or 'N/A', inline = true },
                                { name = 'Arma Detectata', value = wepName, inline = true },
                            }
                        )

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

                        local isAdmin = exports.sunset_admin and exports.sunset_admin:IsAdmin(src, 1)

                        if dist > 350.0 and not isAdmin then
                            local char = exports.sunset_core:GetCharacter(src)
                            local pName = GetPlayerName(src) or 'Necunoscut'

                            print(('[SECURITY] Teleport anomaly flagged for %s: %.1fm in %.1fs'):format(pName, dist, dt))

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

                    LastCoords[src] = coords
                    LastCoordTimes[src] = now
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    LastCoords[source] = nil
    LastCoordTimes[source] = nil
    RateLimiters[source] = nil
end)
