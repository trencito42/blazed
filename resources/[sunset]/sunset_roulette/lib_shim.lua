-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Roulette Compatibility Shim (lib_shim.lua)
--  Replaces external ox_lib dependencies with native FiveM helpers.
-- ═══════════════════════════════════════════════════════════════

lib = lib or {}
lib.callback = lib.callback or {}

if IsDuplicityVersion() then
    local nextSeq = 0
    local pending = {}

    RegisterNetEvent('sunset:roulette:cb:resp', function(seq, res)
        local cb = pending[seq]
        if cb then
            pending[seq] = nil
            cb(res)
        end
    end)

    function lib.callback.await(name, src, ...)
        if not src or src <= 0 then return nil end
        nextSeq = nextSeq + 1
        local seq = nextSeq
        local p = promise.new()
        pending[seq] = function(res) p:resolve(res) end
        TriggerClientEvent('sunset:roulette:cb:req', src, name, seq, ...)
        SetTimeout(15000, function()
            if pending[seq] then
                pending[seq] = nil
                p:resolve(nil)
            end
        end)
        return Citizen.Await(p)
    end
else
    cache = cache or {}
    setmetatable(cache, {
        __index = function(t, k)
            if k == 'ped' then return PlayerPedId() end
            if k == 'playerId' then return PlayerId() end
            if k == 'serverId' then return GetPlayerServerId(PlayerId()) end
            return rawget(t, k)
        end
    })

    function lib.requestModel(model, timeout)
        local hash = type(model) == 'number' and model or joaat(model)
        if not HasModelLoaded(hash) then
            RequestModel(hash)
            local start = GetGameTimer()
            while not HasModelLoaded(hash) and (GetGameTimer() - start < (timeout or 8000)) do
                Wait(10)
            end
        end
        return HasModelLoaded(hash)
    end

    function lib.requestAnimDict(dict, timeout)
        if not HasAnimDictLoaded(dict) then
            RequestAnimDict(dict)
            local start = GetGameTimer()
            while not HasAnimDictLoaded(dict) and (GetGameTimer() - start < (timeout or 8000)) do
                Wait(10)
            end
        end
        return HasAnimDictLoaded(dict)
    end

    function lib.showTextUI(text, options)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(text:gsub('\\n', '\n'))
        EndTextCommandDisplayHelp(0, false, false, -1)
    end

    function lib.hideTextUI()
        ClearAllHelpMessages()
    end

    function lib.notify(data)
        exports.sunset_ui:Notify(data.description or data.title or 'Roulette', data.type or 'info')
    end

    local handlers = {}
    function lib.callback.register(name, fn)
        handlers[name] = fn
    end

    RegisterNetEvent('sunset:roulette:cb:req', function(name, seq, ...)
        local fn = handlers[name]
        local res = fn and fn(...) or nil
        TriggerServerEvent('sunset:roulette:cb:resp', seq, res)
    end)
end