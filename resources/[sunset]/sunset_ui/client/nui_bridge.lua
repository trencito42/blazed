-- NUI callbacks must live in sunset_ui (ui_page owner).
-- Forward to sunset_characters via local events.

local function forward(name)
    RegisterNUICallback(name, function(data, cb)
        TriggerEvent('sunset:nui:' .. name, data)
        cb('ok')
    end)
end

forward('select')
forward('create')
forward('delete')
forward('characterCreate')
forward('characterBack')
forward('chatSend')
forward('chatClose')
forward('menuClose')
