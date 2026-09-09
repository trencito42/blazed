-- ============================================================
--  sunset_fishingshop  ·  client/main.lua
--  Hillbilly NPC la pontoon Paleto Bay — da jobul de Pescar
--  Magazinul (momeli + undite) e la marker-ul E din dreapta
-- ============================================================

local NPC_COORDS      = vector4(-1593.23, 5207.74, 4.31, 25.49)
local NPC_MODEL_HASH  = GetHashKey('A_M_M_Hillbilly_01')
local NPC_DIST        = 3.0   -- distanta interactiune

local hillbillyPed  = nil
local nearNpc       = false
local menuOpen      = false
local inCooldown    = false

-- ── Spawn NPC ────────────────────────────────────────────────
CreateThread(function()
    RequestModel(NPC_MODEL_HASH)
    while not HasModelLoaded(NPC_MODEL_HASH) do Wait(100) end

    hillbillyPed = CreatePed(4, NPC_MODEL_HASH,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z - 1.0, NPC_COORDS.w,
        false, true)
    SetEntityAsMissionEntity(hillbillyPed, true, true)
    FreezeEntityPosition(hillbillyPed, true)
    SetEntityInvincible(hillbillyPed, true)
    SetBlockingOfNonTemporaryEvents(hillbillyPed, true)
    TaskStartScenarioInPlace(hillbillyPed, 'WORLD_HUMAN_STAND_FISHING', 0, true)
    SetModelAsNoLongerNeeded(NPC_MODEL_HASH)

    -- Blip permanent pe harta
    local blip = AddBlipForCoord(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
    SetBlipSprite(blip, 66)         -- undita
    SetBlipColour(blip, 3)          -- albastru
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Fisherman Job')
    EndTextCommandSetBlipName(blip)
end)

-- ── Proximitate NPC ──────────────────────────────────────────
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local wasNear = nearNpc

        if hillbillyPed and DoesEntityExist(hillbillyPed) then
            nearNpc = #(pos - vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)) < NPC_DIST
        else
            nearNpc = false
        end

        -- Inchide meniu daca ne-am indepartat
        if wasNear and not nearNpc and menuOpen then
            exports.sunset_ui:Send('playerInteractionHide', {})
            exports.sunset_ui:SetFocus(false, false)
            menuOpen = false
        end

        Wait(nearNpc and 0 or 350)
    end
end)

-- ── G key → meniu interactiune ───────────────────────────────
CreateThread(function()
    while true do
        if nearNpc then
            -- Blocam G-ul de la sunset_interactions (care arata "no player nearby")
            DisableControlAction(0, 51, true)

            if IsDisabledControlJustPressed(0, 51) and not inCooldown and not menuOpen then
                exports.sunset_ui:Send('playerInteractionShow', {
                    target  = { name = 'Billy Ray', id = '' },
                    actions = {
                        { id = 'get_fisherman_job', label = 'Devino Pescar', group = 'CIVILIAN' },
                    },
                })
                exports.sunset_ui:SetFocus(true, true)
                menuOpen = true
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

-- ── Actiuni NUI ──────────────────────────────────────────────
AddEventHandler('sunset:nui:playerInteractionClose', function()
    if menuOpen then
        menuOpen = false
        -- SetFocus e deja resetat de UI
    end
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or data.action ~= 'get_fisherman_job' then return end

    menuOpen = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)

    inCooldown = true
    local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'fisherman')
    if ok then
        exports.sunset_ui:Notify(
            'Esti acum Pescar! Mergi la marker-ul albastru de pe harta si foloseste /work.', 'success', 8000)
    else
        exports.sunset_ui:Notify(err or 'Nu a functionat angajarea.', 'error')
    end
    SetTimeout(2000, function() inCooldown = false end)
end)
