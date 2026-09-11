-- ═══════════════════════════════════════════════════════════════
--  SUNSETMP — Discord Webhook Surveillance Engine
--  Rich embed logging for economy, staff, combat log, and anti-cheat
-- ═══════════════════════════════════════════════════════════════

Sunset = Sunset or {}
Sunset.Discord = Sunset.Discord or {}

local COLORS = {
    cyan    = 65532,    -- #00ffcc (Normal info)
    green   = 3066993,  -- #2ecc71 (Success, money in)
    red     = 15158332, -- #e74c3c (Alerts, combat log, bans)
    orange  = 15105570, -- #e67e22 (Admin commands, warnings)
    purple  = 10181046, -- #9b59b6 (Wars, lotto)
}

function Sunset.Discord.Send(channelType, title, description, colorName, fields)
    channelType = tostring(channelType or 'general'):lower()
    local webhookUrl = GetConvar('discord_webhook_' .. channelType, '')
    if webhookUrl == '' then
        webhookUrl = GetConvar('discord_webhook_all', '')
    end

    if webhookUrl == '' or not webhookUrl:find('^https://') then
        -- Silently skip if webhook not configured in server.cfg
        return
    end

    local embed = {
        title = title or 'SunsetMP Log',
        description = description or '',
        color = COLORS[colorName] or COLORS.cyan,
        fields = fields or {},
        footer = {
            text = 'SunsetMP Security & Audit Engine · ' .. os.date('%Y-%m-%d %H:%M:%S'),
        }
    }

    local payload = json.encode({
        username = 'SunsetMP Audit Bot',
        avatar_url = 'https://i.imgur.com/8Q5Yv8O.png',
        embeds = { embed }
    })

    PerformHttpRequest(webhookUrl, function(status, text, headers)
        if status < 200 or status >= 300 then
            -- Error logged once
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

exports('SendDiscordLog', Sunset.Discord.Send)

-- Hook automatic large money alerts to Discord
local oldLogMoney = Sunset.LogMoneyTransaction
Sunset.LogMoneyTransaction = function(characterId, account, direction, amount, reason, balanceAfter)
    if oldLogMoney then
        oldLogMoney(characterId, account, direction, amount, reason, balanceAfter)
    end

    if amount and amount >= 15000 then
        local dirStr = direction == 'in' and 'DEPOZIT / PRIMIT (+)' or 'RETRAS / PLATIT (-)'
        local color = direction == 'in' and 'green' or 'orange'
        Sunset.Discord.Send('economy', 'Tranzactie Financiara Semnificativa', ('Caracterul #%d a inregistrat o miscare de fonduri.'):format(characterId), color, {
            { name = 'Caracter ID', value = tostring(characterId), inline = true },
            { name = 'Tip Cont', value = tostring(account):upper(), inline = true },
            { name = 'Operatiune', value = dirStr, inline = true },
            { name = 'Suma', value = ('$%s'):format(string.format('%\'d', amount):gsub('\'', ',')), inline = true },
            { name = 'Motiv', value = tostring(reason), inline = true },
            { name = 'Sold Dupa', value = ('$%s'):format(string.format('%\'d', balanceAfter):gsub('\'', ',')), inline = true },
        })
    end
end
