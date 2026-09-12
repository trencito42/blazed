-- 24/7 cashier NPCs (Gheorghe) + store interaction

local CASHIER_MODEL = 'mp_m_shopkeep_01'
local CASHIER_NAME = 'Gheorghe (Casier)'
local INTERACT_DIST = 2.35
local PROMPT_DIST = 5.0
local INTERACT_KEY = 38

local cashiers = {}
local menuOpen = false
local shopOpen = false
local storeContext = nil
local promptId = nil

local function notify(msg, typ)
    exports.sunset_ui:Notify(msg, typ or 'info')
end

local function formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return '$' .. formatted
end

local SHIRT_BY_STORE = {
    legion = 2,
    strawberry = 4,
    littleseoul = 1,
    mirrorpark = 3,
    vinewood = 5,
    rockford = 0,
    sandy = 6,
    paleto = 7,
}

local function spawnCashier(store, index)
    local pos = store.cashier
    if not pos then return end

    local shirt = SHIRT_BY_STORE[store.id] or ((index or 1) % 8)
    local ped = SunsetWorld.Npc.spawn({
        model = CASHIER_MODEL,
        coords = pos,
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        components = {
            { 3, 0, 0 },
            { 4, 0, 0 },
            { 6, 1, 0 },
            { 8, 15, 0 },
            { 11, 13, shirt },
        },
    })
    if not ped then return end

    cashiers[#cashiers + 1] = {
        ped = ped,
        store = store,
        promptId = ('cashier_%s'):format(store.id or #cashiers),
    }
end

local function buildStoreActions(ctx)
    local actions = {}
    local shopLabel = (ctx and ctx.shopLabel) or '24/7 Store'
    actions[#actions + 1] = {
        id = 'open_shop_247',
        label = ('Open %s'):format(shopLabel),
        group = 'STORE',
    }
    actions[#actions + 1] = {
        id = 'sell_fish_247',
        label = 'Sell Fish',
        group = 'STORE',
    }

    local biz = ctx and ctx.business
    if biz and not biz.owned and biz.forSale then
        actions[#actions + 1] = {
            id = 'buy_business',
            label = ('Buy Business (%s)'):format(formatMoney(biz.price)),
            group = 'BUSINESS',
        }
    elseif biz and biz.mine then
        actions[#actions + 1] = {
            id = 'manage_business',
            label = 'Manage Business',
            group = 'BUSINESS',
        }
    end
    return actions
end

local function closeStoreMenu()
    if not menuOpen then return end
    menuOpen = false
    storeContext = nil
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('playerInteractionHide', {})
end

local function openStoreMenu(ctx)
    storeContext = ctx
    exports.sunset_ui:Send('playerInteractionShow', {
        menuTitle = ctx.shopLabel or '24/7 Store',
        target = { name = CASHIER_NAME, id = '' },
        actions = buildStoreActions(ctx),
    })
    exports.sunset_ui:SetFocus(true, true)
    menuOpen = true
end

local function nearestCashier(maxDist)
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, maxDist or PROMPT_DIST
    for _, row in ipairs(cashiers) do
        if row.ped and DoesEntityExist(row.ped) then
            local dist = #(pos - GetEntityCoords(row.ped))
            if dist < bestDist then
                bestDist = dist
                best = row
            end
        end
    end
    return best, bestDist
end

CreateThread(function()
    Wait(1500)
    for index, store in ipairs(Sunset.TwentyFourSevenStores or {}) do
        spawnCashier(store, index)
    end
end)

CreateThread(function()
    while true do
        local row, dist = nearestCashier(PROMPT_DIST)
        if row and dist < PROMPT_DIST and not menuOpen and not shopOpen and not IsNuiFocused() then
            SunsetWorld.Npc.showTooltip(row.promptId, row.ped, {
                badge = row.store.label or 'BUSINESS 24/7',
                badgeClass = 'npc',
                bodyClass = 'npc',
                icon = 'ph-storefront',
                title = CASHIER_NAME,
                desc = 'Store / Sell fish',
                key = 'E',
            })
            promptId = row.promptId

            if dist < INTERACT_DIST and IsControlJustPressed(0, INTERACT_KEY) and SunsetWorld.tryInteract() then
                CreateThread(function()
                    local ctx = Sunset.AwaitCallback('sunset:getStoreContext')
                    if not ctx then
                        notify('Store unavailable right now.', 'error')
                        return
                    end
                    openStoreMenu(ctx)
                end)
            end
            Wait(0)
        else
            if promptId then
                SunsetWorld.Npc.hideTooltip(promptId)
                promptId = nil
            end
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        if menuOpen then
            local row = nearestCashier(INTERACT_DIST + 1.0)
            if not row then closeStoreMenu() end
            Wait(300)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('sunset:nui:playerInteractionClose', function()
    if menuOpen then closeStoreMenu() end
end)

AddEventHandler('sunset:nui:playerInteractionAction', function(data)
    if not menuOpen or not data or not data.action then return end
    local action = data.action
    local ctx = storeContext
    closeStoreMenu()

    if action == 'open_shop_247' then
        local shopId = (ctx and ctx.shopId) or 'twentyfour7'
        local shop = Sunset.Shops and Sunset.Shops[shopId]
        if not shop then
            notify('Shop unavailable.', 'error')
            return
        end
        TriggerEvent('sunset:world:openShop', shopId, shop)

    elseif action == 'sell_fish_247' then
        CreateThread(function()
            local invData, err = Sunset.AwaitCallback('sunset:fishingshop:getFishInventory')
            if invData then
                if not invData.items or #invData.items == 0 then
                    notify('You have no fish in your inventory.', 'info')
                else
                    exports.sunset_ui:Send('fishingShopShow', {
                        mode = 'sell',
                        title = '24/7 — SELL FISH',
                        cash = invData.cash,
                        items = invData.items,
                    })
                    exports.sunset_ui:SetFocus(true, true)
                    shopOpen = true
                end
            else
                notify(err or 'Failed to load inventory.', 'error')
            end
        end)

    elseif action == 'buy_business' then
        local biz = ctx and ctx.business
        if not biz or not biz.id then
            notify('This business is not for sale.', 'error')
            return
        end
        CreateThread(function()
            local ok, err = Sunset.AwaitCallback('sunset:buyBusiness', biz.id)
            if ok then
                notify(err or 'Business purchased.', 'success')
            else
                notify(err or 'Could not buy business.', 'error')
            end
        end)

    elseif action == 'manage_business' then
        TriggerEvent('sunset:businesses:openOwner')
    end
end)

AddEventHandler('sunset:nui:shopClose', function()
    shopOpen = false
end)

AddEventHandler('sunset:nui:fishingShopClose', function()
    shopOpen = false
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, row in ipairs(cashiers) do
        if row.ped and DoesEntityExist(row.ped) then
            DeleteEntity(row.ped)
        end
    end
    SunsetWorld.Tooltips.clear()
end)
