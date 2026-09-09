-- ============================================================
--  sunset_fishingshop  ·  client/main.lua
--  Billy Ray (hillbilly NPC) la pontoon Paleto Bay
--  Opreste G la NPC si la zona 24/7 pentru a vinde peste
-- ============================================================

local NPC_COORDS     = vector4(-1593.23, 5207.74, 4.31, 25.49)
local NPC_DIST       = 3.5
local SELL_COORDS    = vector3(25.74, -1347.32, 29.50)
local SELL_DIST      = 3.0

local hillbillyPed   = nil
local nearNpc        = false
local nearSell       = false
local menuOpen       = false
local inCooldown     = false

-- ── Spawn NPC ────────────────────────────────────────────────
CreateThread(function()
    local hash = GetHashKey('a_m_m_hillbilly_01')
    RequestModel(hash)
    local t = GetGameTimer() + 20000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(200) end
    if not HasModelLoaded(hash) then
        print('[sunset_fishingshop] ERR: model a_m_m_hillbilly_01 nu s-a incarcat')
        return
    end

    Wait(500)  -- delay mic ca world-ul sa fie gata

    hillbillyPed = CreatePed(4, hash,
        NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z, NPC_COORDS.w,
        false, true)

    if not hillbillyPed or hillbillyPed == 0 or not DoesEntityExist(hillbillyPed) then
        print('[sunset_fishingshop] ERR: CreatePed a returnat entitate invalida')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(hillbillyPed, true, true)
    FreezeEntityPosition(hillbillyPed, true)
    SetEntityInvincible(hillbillyPed, true)
    SetBlockingOfNonTemporaryEvents(hillbillyPed, true)
    SetEntityCanBeDamaged(hillbillyPed, false)
    TaskStartScenarioInPlace(hillbillyPed, 'WORLD_HUMAN_SMOKING', 0, true)
    SetModelAsNoLongerNeeded(hash)
    print('[sunset_fishingshop] Billy Ray spawnat la', NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)

    -- Blip pe harta
    local blip = AddBlipForCoord(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)
    SetBlipSprite(blip, 66)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Billy Ray — Fishing')
    EndTextCommandSetBlipName(blip)
end)

-- ── Proximitate checker ───────────────────────────────────────
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local wasNpc  = nearNpc
        local wasSell = nearSell

        nearNpc  = hillbillyPed and DoesEntityExist(hillbillyPed)
                   and #(pos - vector3(NPC_COORDS.x, NPC_COORDS.y, NPC_COORDS.z)) < NPC_DIST
        nearSell = #(pos - SELL_COORDS) < SELL_DIST

        if (wasNpc or wasSell) and not nearNpc and not nearSell and menuOpen then
            exports.sunset_ui:Send('playerInteractionHide', {})
            exports.sunset_ui:SetFocus(false, false)
            menuOpen = false
        end

        Wait((nearNpc or nearSell) and 0 or 350)
    end
end)

-- ── G key handler ─────────────────────────────────────────────
CreateThread(function()
    while true do
        if nearNpc or nearSell then
            DisableControlAction(0, 51, true)  -- bloca G de la sunset_interactions

            if IsDisabledControlJustPressed(0, 51) and not inCooldown and not menuOpen then
                if nearNpc then
                    -- Meniu Billy Ray
                    exports.sunset_ui:Send('playerInteractionShow', {
                        target  = { name = 'Billy Ray', id = '' },
                        actions = {
                            { id = 'get_fisherman_job',  label = 'Devino Pescar',     group = 'CIVILIAN' },
                            { id = 'upgrade_fishing_rod', label = 'Upgrade Undita',   group = 'FISHING'  },
                        },
                    })
                elseif nearSell then
                    -- Meniu 24/7 sell fish
                    exports.sunset_ui:Send('playerInteractionShow', {
                        target  = { name = '24/7 Store', id = '' },
                        actions = {
                            { id = 'sell_fish_247', label = 'Vinde Pestele (cash)', group = 'STORE' },
                        },
                    })
                end
                exports.sunset_ui:SetFocus(true, true)
                menuOpen = true
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

-- ── NUI events ────────────────────────────────────────────────
AddEventHandler('sunset:nui:playerInteractionClose', function()
    menuOpen = false
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not data or not data.action then return end
    menuOpen = false
    exports.sunset_ui:Send('playerInteractionHide', {})
    exports.sunset_ui:SetFocus(false, false)

    if data.action == 'get_fisherman_job' then
        inCooldown = true
        local ok, err = Sunset.AwaitCallback('sunset:hireJob', 'fisherman')
        if ok then
            exports.sunset_ui:Notify('Esti acum Pescar! Du-te la pontoon si foloseste /fish.', 'success', 8000)
        else
            exports.sunset_ui:Notify(err or 'Nu a functionat angajarea.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'upgrade_fishing_rod' then
        inCooldown = true
        local ok, msg = Sunset.AwaitCallback('sunset:fishingshop:upgradeRod')
        if ok then
            exports.sunset_ui:Notify(msg or 'Undita upgradata!', 'success', 6000)
        else
            exports.sunset_ui:Notify(msg or 'Nu s-a putut face upgrade.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)

    elseif data.action == 'sell_fish_247' then
        inCooldown = true
        local ok, msg = Sunset.AwaitCallback('sunset:fishingshop:sellFish247')
        if ok then
            exports.sunset_ui:Notify(msg or 'Peste vandut!', 'success', 6000)
        else
            exports.sunset_ui:Notify(msg or 'Nu ai peste de vandut.', 'error')
        end
        SetTimeout(2000, function() inCooldown = false end)
    end
end)
