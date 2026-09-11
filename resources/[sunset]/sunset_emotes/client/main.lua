local Emotes = {
    wave = { dict = 'friends@frj@ig_1', anim = 'wave_a', flag = 49, label = 'Wave', icon = 'ph-hand-waving' },
    sit = { dict = 'anim@heists@fleeca_bank@ig_7_jetski_owner', anim = 'owner_idle', flag = 1, label = 'Sit', icon = 'ph-armchair' },
    dance = { dict = 'anim@amb@nightclub@dancers@solomun_entourage@', anim = 'mi_dance_facedj_17_v1_female^1', flag = 1, label = 'Dance', icon = 'ph-music-notes' },
    smoke = { dict = 'amb@world_human_smoking@male@male_a@enter', anim = 'enter', flag = 49, label = 'Smoke', icon = 'ph-cigarette' },
    drink = { dict = 'amb@world_human_drinking@coffee@male@idle_a', anim = 'idle_c', flag = 49, label = 'Drink', icon = 'ph-coffee' },
    phone = { dict = 'cellphone@', anim = 'cellphone_text_read_base', flag = 49, label = 'Phone', icon = 'ph-device-mobile-camera' },
    lean = { dict = 'amb@world_human_leaning@male@wall@back@mobile@base', anim = 'base', flag = 1, label = 'Lean', icon = 'ph-wall' },
    pushup = { dict = 'amb@world_human_push_ups@male@base', anim = 'base', flag = 1, label = 'Push Up', icon = 'ph-barbell' },
    wank = { dict = 'anim@mp_player_intupperwank', anim = 'idle_a', flag = 49, label = 'Taunt', icon = 'ph-smiley-sad' },
    surrender = { dict = 'random@arrests@busted', anim = 'idle_a', flag = 49, label = 'Surrender', icon = 'ph-hands-praying' },
}

local playing = false

local function stopEmote()
    ClearPedTasks(PlayerPedId())
    playing = false
end

local function playEmote(name)
    local emote = Emotes[name]
    if not emote then return exports.sunset_ui:Notify('Unknown emote: ' .. tostring(name), 'error') end

    local ped = PlayerPedId()
    if playing then ClearPedTasks(ped) playing = false end

    RequestAnimDict(emote.dict)
    while not HasAnimDictLoaded(emote.dict) do Wait(10) end
    TaskPlayAnim(ped, emote.dict, emote.anim, 8.0, -8.0, -1, emote.flag, 0, false, false, false)
    playing = true
end

RegisterCommand('e', function(_, args)
    local name = args[1]
    if not name or name == '' then
        playEmote('wave')
        return
    end
    if name == 'cancel' or name == 'stop' or name == 'c' then
        stopEmote()
        return
    end
    playEmote(name)
end, false)

RegisterCommand('emotes', function()
    exports.sunset_ui:Send('emotesShow', { emotes = Emotes })
    exports.sunset_ui:SetFocus(true, true)
end, false)

RegisterCommand('stopemote', function()
    stopEmote()
end, false)

AddEventHandler('sunset:nui:emotePlay', function(data)
    playEmote(data.emote)
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('emotesHide', {})
end)

AddEventHandler('sunset:nui:emotesClose', function()
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('emotesHide', {})
end)

local function getEmoteWheelList()
    local list = {}
    for name, def in pairs(Emotes) do
        list[#list + 1] = {
            name = name,
            label = def.label or name,
            icon = def.icon or 'ph-smiley',
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

exports('PlayEmote', playEmote)
exports('StopEmote', stopEmote)
exports('IsPlaying', function() return playing end)
exports('GetEmoteWheelList', getEmoteWheelList)
