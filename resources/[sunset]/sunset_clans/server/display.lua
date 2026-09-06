ClanDisplay = {}

local membershipCache = {}

local function getChar(source)
    return exports.sunset_core:GetCharacter(source)
end

local function charId(source)
    local char = getChar(source)
    return char and tonumber(char.id)
end

function ClanDisplay.getMembership(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end
    return MySQL.single.await([[
        SELECT cm.clan_id, cm.character_id, cm.rank, cm.joined_at,
               c.name, c.tag, c.tag_color, c.tag_style, c.description, c.motd,
               c.owner_character_id, c.max_members
        FROM clan_members cm
        INNER JOIN clans c ON c.id = cm.clan_id
        WHERE cm.character_id = ?
    ]], { characterId })
end

function ClanDisplay.baseName(source)
    local char = getChar(source)
    if char then
        local full = ((char.firstname or '') .. (char.lastname and char.lastname ~= '' and (' ' .. char.lastname) or ''))
            :gsub('^%s+', ''):gsub('%s+$', '')
        if full ~= '' then return full end
    end
    local player = exports.sunset_core:GetPlayer(source)
    if player and player.name and player.name ~= '' then return player.name end
    return GetPlayerName(source) or 'Player'
end

function ClanDisplay.sync(source)
    local cid = charId(source)
    if not cid then return end

    local row = ClanDisplay.getMembership(cid)
    membershipCache[source] = row

    local base = ClanDisplay.baseName(source)
    local tag, color, style = '', '#FFFFFF', 'brackets'
    if row then
        tag = tostring(row.tag or '')
        color = tostring(row.tag_color or '#FF8C00')
        style = tostring(row.tag_style or 'brackets')
    end

    local displayName = base
    if tag ~= '' then
        displayName = SunsetClans.formatTaggedName(tag, base, style)
    end

    local state = Player(source).state
    state:set('clanTag', tag ~= '' and tag or nil, true)
    state:set('clanTagColor', tag ~= '' and color or nil, true)
    state:set('clanTagStyle', tag ~= '' and style or nil, true)
    state:set('sunsetName', base, true)
    state:set('sunsetDisplayName', displayName, true)
    state:set('sunsetClanId', row and tonumber(row.clan_id) or nil, true)
end

function ClanDisplay.formatPublicName(source, baseName)
    baseName = baseName or ClanDisplay.baseName(source)
    local row = membershipCache[source]
    if not row or not row.tag or row.tag == '' then return baseName end
    return SunsetClans.formatTaggedName(row.tag, baseName, row.tag_style)
end

function ClanDisplay.getChatMeta(source)
    local row = membershipCache[source]
    if not row or not row.tag or row.tag == '' then return nil end
    return {
        clanTag = row.tag,
        clanTagColor = row.tag_color,
        clanTagStyle = row.tag_style,
    }
end

function ClanDisplay.clear(source)
    membershipCache[source] = nil
end

function FormatDisplayName(source, baseName)
    return ClanDisplay.formatPublicName(source, baseName)
end
exports('FormatDisplayName', FormatDisplayName)

function GetClanChatMeta(source)
    return ClanDisplay.getChatMeta(source)
end
exports('GetClanChatMeta', GetClanChatMeta)

function SyncPlayerClan(source)
    ClanDisplay.sync(source)
end
exports('SyncPlayerClan', SyncPlayerClan)

function GetPlayerBaseName(source)
    return ClanDisplay.baseName(source)
end
exports('GetPlayerBaseName', GetPlayerBaseName)

AddEventHandler('sunset:server:characterSelected', function(source)
    ClanDisplay.sync(source)
end)

AddEventHandler('playerDropped', function()
    ClanDisplay.clear(source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do
        ClanDisplay.sync(tonumber(id))
    end
end)
