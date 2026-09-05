local Inside = {}

local function dbBool(value)
    return value == true or value == 1 or value == '1'
end

local function decodePos(raw)
    if type(raw) == 'table' then return raw end
    if not raw then return nil end
    local ok, value = pcall(json.decode, raw)
    return ok and value or nil
end

local function encodePos(pos, heading)
    return json.encode({ x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0, w = (heading or pos.w or 0.0) + 0.0 })
end

local function property(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await([[SELECT p.*,
      TRIM(CONCAT(COALESCE(c.firstname, ''), ' ', COALESCE(c.lastname, ''))) owner_name,
      (SELECT COUNT(*) FROM property_rentals r WHERE r.property_id=p.id AND r.active=1) renter_count
      FROM properties p LEFT JOIN characters c ON c.id=p.owner_character_id WHERE p.id=?]], { id })
end

local function activeRental(characterId, propertyId)
    local sql = 'SELECT * FROM property_rentals WHERE character_id=? AND active=1'
    local params = { characterId }
    if propertyId then sql = sql .. ' AND property_id=?'; params[2] = propertyId end
    return MySQL.single.await(sql .. ' LIMIT 1', params)
end

local function accessible(char, prop)
    return tonumber(prop.owner_character_id) == tonumber(char.id) or activeRental(char.id, prop.id) ~= nil
end

local function nearby(source, prop, distance)
    local entry, ped = decodePos(prop and prop.entry), GetPlayerPed(source)
    if not entry or not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local x, y, z = pos.x-entry.x, pos.y-entry.y, pos.z-entry.z
    return x*x+y*y+z*z <= (distance or 5.0)^2
end

local function message(source, text, kind)
    if source and source > 0 then TriggerClientEvent('sunset:client:propertyMessage', source, text, kind or 'info') end
end

local function publicRow(row, char)
    local owned = tonumber(row.owner_character_id) == tonumber(char.id)
    local rented = activeRental(char.id, row.id) ~= nil
    return {
        id=row.id, label=row.label, price=tonumber(row.price) or 0, entry=decodePos(row.entry),
        owner_character_id=row.owner_character_id, ownerName=row.owner_name ~= '' and row.owner_name or nil,
        interior=row.interior, minimumLevel=tonumber(row.minimum_level) or 1,
        locked=dbBool(row.locked), forSale=dbBool(row.for_sale),
        rentEnabled=dbBool(row.rent_enabled), rentPrice=tonumber(row.rent_price) or 0,
        renterCount=tonumber(row.renter_count) or 0, maxRenters=tonumber(row.max_renters) or 1,
        owned=owned, rented=rented, access=owned or rented,
    }
end

exports.sunset_core:RegisterCallback('sunset:getProperties', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    local rows = MySQL.query.await([[SELECT p.*,
      TRIM(CONCAT(COALESCE(c.firstname, ''), ' ', COALESCE(c.lastname, ''))) owner_name,
      (SELECT COUNT(*) FROM property_rentals r WHERE r.property_id=p.id AND r.active=1) renter_count
      FROM properties p LEFT JOIN characters c ON c.id=p.owner_character_id
      WHERE p.enabled=1 ORDER BY p.price,p.id]]) or {}
    for i,row in ipairs(rows) do rows[i]=publicRow(row,char) end
    return rows
end)

exports.sunset_core:RegisterCallback('sunset:getSpawnHomes', function(source)
    local char = exports.sunset_core:GetCharacter(source)
    if not char then return {} end
    return MySQL.query.await([[SELECT p.id,p.label,
      CASE WHEN p.owner_character_id=? THEN 'owner' ELSE 'renter' END access_type
      FROM properties p LEFT JOIN property_rentals r
        ON r.property_id=p.id AND r.character_id=? AND r.active=1
      WHERE p.enabled=1 AND (p.owner_character_id=? OR r.id IS NOT NULL)
      ORDER BY access_type,p.id]], {char.id,char.id,char.id}) or {}
end)

exports.sunset_core:RegisterCallback('sunset:resolveSpawnChoice', function(source, choice, propertyId)
    local char=exports.sunset_core:GetCharacter(source)
    if not char then return nil,'Character data is unavailable. Please reconnect.' end
    local pos
    if choice=='default' then pos=Sunset.Config.DefaultSpawn
    elseif choice=='last' then pos=char.position
    elseif choice=='house' then
        local prop=property(propertyId)
        if not prop or not dbBool(prop.enabled) then return nil,'That house is no longer available.' end
        if not accessible(char,prop) then return nil,'You no longer own or rent that house.' end
        pos=decodePos(prop.entry)
    else return nil,'Invalid spawn location.' end
    if type(pos)~='table' or not tonumber(pos.x) then return nil,'That spawn location has invalid coordinates.' end
    return {x=pos.x,y=pos.y,z=pos.z,w=pos.w or 0.0}
end)

local function charge(source, amount, reason)
    local account
    if exports.sunset_core:GetMoney(source,'bank')>=amount then account='bank'
    elseif exports.sunset_core:GetMoney(source,'cash')>=amount then account='cash' end
    if not account then return false end
    return exports.sunset_core:RemoveMoney(source,account,amount,reason)
end

local function creditOwner(characterId, amount)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local online = exports.sunset_core:GetCharacter(src)
        if online and tonumber(online.id) == tonumber(characterId) then
            exports.sunset_core:AddMoney(src, 'bank', amount, 'house_rent_income')
            return
        end
    end
    MySQL.update.await('UPDATE characters SET bank=bank+? WHERE id=?', { amount, characterId })
end

local function clearHome(characterId, propertyId, reason)
    MySQL.update.await('UPDATE characters SET home_property_id=NULL WHERE id=? AND home_property_id=?', { characterId, propertyId })
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local online = exports.sunset_core:GetCharacter(src)
        if online and tonumber(online.id) == tonumber(characterId) and tonumber(online.home_property_id) == tonumber(propertyId) then
            online.home_property_id = nil
            TriggerClientEvent('sunset:client:updateCharacter', src, online)
            if reason then message(src, reason, 'error') end
            break
        end
    end
end

exports.sunset_core:RegisterCallback('sunset:buyProperty', function(source,id)
    local char=exports.sunset_core:GetCharacter(source)
    local prop=property(id)
    if not char then return nil,'Character data is unavailable.' end
    if not prop or not dbBool(prop.enabled) then return nil,'This house does not exist or is disabled.' end
    if not nearby(source,prop) then return nil,'Stand inside this house entrance marker to buy it.' end
    if not dbBool(prop.for_sale) then return nil,'This house is not for sale. An admin can enable it with /ahouseedit '..prop.id..' sale 1.' end
    if prop.owner_character_id then return nil,'This house already has an owner.' end
    if (tonumber(char.level) or 1)<(tonumber(prop.minimum_level) or 1) then return nil,('You need level %d to buy it.'):format(prop.minimum_level) end
    if MySQL.scalar.await('SELECT 1 FROM properties WHERE owner_character_id=? LIMIT 1',{char.id}) then return nil,'You already own a house. Sell it before buying another.' end
    local price=tonumber(prop.price) or 0
    if exports.sunset_core:GetMoney(source,'bank')<price and exports.sunset_core:GetMoney(source,'cash')<price then return nil,('You need $%d in bank or cash.'):format(price) end
    local claimed=MySQL.update.await('UPDATE properties SET owner_character_id=?,locked=1 WHERE id=? AND owner_character_id IS NULL',{char.id,prop.id})
    if claimed~=1 then return nil,'Another player bought this house first.' end
    if not charge(source,price,'house_purchase') then
        MySQL.update.await('UPDATE properties SET owner_character_id=NULL WHERE id=? AND owner_character_id=?',{prop.id,char.id})
        return nil,'Payment failed; ownership was rolled back and you were not charged.'
    end
    MySQL.update.await('UPDATE property_rentals SET active=0 WHERE character_id=?',{char.id})
    char.home_property_id=prop.id
    MySQL.update.await('UPDATE characters SET home_property_id=? WHERE id=?',{prop.id,char.id})
    exports.sunset_core:SaveCharacter(source)
    TriggerClientEvent('sunset:client:propertiesChanged',-1)
    return true,('You bought %s for $%d.'):format(prop.label,price)
end)

exports.sunset_core:RegisterCallback('sunset:rentProperty', function(source,id)
    local char=exports.sunset_core:GetCharacter(source)
    local prop=property(id)
    if not char then return nil,'Character data is unavailable.' end
    if not prop or not prop.owner_character_id then return nil,'This house has no owner and cannot be rented.' end
    if not nearby(source,prop) then return nil,'Stand inside this house entrance marker to rent it.' end
    if tonumber(prop.owner_character_id)==tonumber(char.id) then return nil,'You own this house already.' end
    if not dbBool(prop.rent_enabled) then return nil,'The owner is not accepting renters.' end
    if tonumber(prop.renter_count)>=tonumber(prop.max_renters) then return nil,'This house has no free rental slots.' end
    if activeRental(char.id,prop.id) then return nil,'You already rent this house.' end
    local price=tonumber(prop.rent_price) or 0
    if exports.sunset_core:GetMoney(source,'bank')<price and exports.sunset_core:GetMoney(source,'cash')<price then return nil,('You need $%d in bank or cash for the first rent payment.'):format(price) end
    MySQL.update.await('UPDATE property_rentals SET active=0 WHERE character_id=?',{char.id})
    MySQL.query.await([[INSERT INTO property_rentals(property_id,character_id,rent_price,active,last_paid_at)
      VALUES(?,?,?,1,NOW()) ON DUPLICATE KEY UPDATE property_id=VALUES(property_id),rent_price=VALUES(rent_price),active=1,started_at=NOW(),last_paid_at=NOW()]],{prop.id,char.id,price})
    if not charge(source,price,'house_rent') then
        MySQL.update.await('UPDATE property_rentals SET active=0 WHERE character_id=? AND property_id=?',{char.id,prop.id})
        return nil,'Rent payment failed; the agreement was cancelled and you were not charged.'
    end
    creditOwner(prop.owner_character_id,price)
    char.home_property_id=prop.id
    MySQL.update.await('UPDATE characters SET home_property_id=? WHERE id=?',{prop.id,char.id})
    exports.sunset_core:SaveCharacter(source)
    TriggerClientEvent('sunset:client:propertiesChanged',-1)
    return true,('You now rent %s for $%d each payday.'):format(prop.label,price)
end)

exports.sunset_core:RegisterCallback('sunset:leaveRental', function(source)
    local char=exports.sunset_core:GetCharacter(source)
    if not char then return nil,'Character data is unavailable.' end
    local rent=activeRental(char.id)
    if not rent then return nil,'You do not currently rent a house.' end
    MySQL.update.await('UPDATE property_rentals SET active=0 WHERE id=?',{rent.id})
    if tonumber(char.home_property_id)==tonumber(rent.property_id) then char.home_property_id=nil; MySQL.update.await('UPDATE characters SET home_property_id=NULL WHERE id=?',{char.id}) end
    TriggerClientEvent('sunset:client:propertiesChanged',-1)
    return true,'Rental ended. Your civilian job and faction were not changed.'
end)

exports.sunset_core:RegisterCallback('sunset:setHome', function(source,id)
    local char=exports.sunset_core:GetCharacter(source)
    local prop=property(id)
    if not char or not prop or not accessible(char,prop) then return nil,'You must own or actively rent that house.' end
    char.home_property_id=prop.id
    MySQL.update.await('UPDATE characters SET home_property_id=? WHERE id=?',{prop.id,char.id})
    return true,('Home spawn set to %s.'):format(prop.label)
end)

local function enter(source,id)
    local char=exports.sunset_core:GetCharacter(source)
    local prop=property(id)
    if not char then return nil,'Character data is unavailable.' end
    if not prop or not dbBool(prop.enabled) then return nil,'This house is disabled. Ask an administrator to enable it.' end
    if not nearby(source,prop) then return nil,'Stand inside the entrance marker to enter.' end
    if dbBool(prop.locked) and not accessible(char,prop) then return nil,'The door is locked. Only the owner and active renters may enter.' end
    local preset=SunsetProperties.Interiors[prop.interior]
    local interior=preset and preset.coords or decodePos(prop.interior_pos)
    if not interior then return nil,'No valid interior is configured. Contact an administrator.' end
    Inside[source]=prop.id
    SetPlayerRoutingBucket(source,SunsetProperties.BucketBase+prop.id)
    local entry=decodePos(prop.entry)
    Player(source).state:set('sunsetPropertyExit',entry,false)
    TriggerClientEvent('sunset:client:propertyInterior',source,{id=prop.id,label=prop.label,interior=interior,entry=entry})
    return true,'Entering house...'
end
exports.sunset_core:RegisterCallback('sunset:enterProperty',enter)

local function ownedProperty(source,id)
    local char=exports.sunset_core:GetCharacter(source)
    if not char then return nil,nil,'Character data is unavailable.' end
    local prop=id and property(id) or (Inside[source] and property(Inside[source]))
    if not prop then
        local only=MySQL.query.await('SELECT id FROM properties WHERE owner_character_id=?',{char.id}) or {}
        if #only==1 then prop=property(only[1].id) end
    end
    if not prop then return char,nil,'Specify a house ID or stand inside your house.' end
    if tonumber(prop.owner_character_id)~=tonumber(char.id) then return char,nil,'Only the house owner can change this setting.' end
    return char,prop
end

local function toggleLock(source,id)
    local _,prop,err=ownedProperty(source,id)
    if not prop then return nil,err end
    local locked=dbBool(prop.locked) and 0 or 1
    MySQL.update.await('UPDATE properties SET locked=? WHERE id=?',{locked,prop.id})
    TriggerClientEvent('sunset:client:propertiesChanged',-1)
    return true,locked==1 and 'House door locked.' or 'House door unlocked; guests may enter.'
end

exports.sunset_core:RegisterCallback('sunset:propertyAction', function(source,action,id)
    if action=='enter' then return enter(source,id)
    elseif action=='lock' then return toggleLock(source,id)
    elseif action=='sethome' then
        local char=exports.sunset_core:GetCharacter(source); local prop=property(id)
        if not char or not prop or not accessible(char,prop) then return nil,'You do not have access to this house.' end
        char.home_property_id=prop.id; MySQL.update.await('UPDATE characters SET home_property_id=? WHERE id=?',{prop.id,char.id})
        return true,('Home spawn set to %s.'):format(prop.label)
    end
    return nil,'Unknown house action.'
end)

RegisterNetEvent('sunset:server:exitProperty',function()
    local src=source; local id=Inside[src]
    if not id then return message(src,'You are not inside a house.','error') end
    local prop=property(id); Inside[src]=nil; SetPlayerRoutingBucket(src,0); Player(src).state:set('sunsetPropertyExit',nil,false)
    if prop then TriggerClientEvent('sunset:client:propertyExited',src,{id=prop.id,entry=decodePos(prop.exit_pos) or decodePos(prop.entry)}) end
end)
AddEventHandler('playerDropped',function() Inside[source]=nil end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for player in pairs(Inside) do SetPlayerRoutingBucket(player,0) end
end)

RegisterCommand('acreatehouse',function(source,args)
    if source==0 or not exports.sunset_admin:IsAdmin(source,SunsetProperties.AdminLevel) then return message(source,'Admin level 3 is required to create houses.','error') end
    local price,interior,level=tonumber(args[1]),tostring(args[2] or ''),tonumber(args[3]); local preset=SunsetProperties.Interiors[interior]
    if not price or price<1 or not preset or not level or level<1 then return message(source,'Usage: /acreatehouse [price] [interior] [minimum level] [name]. Use /houseinteriors first.','error') end
    local label=table.concat(args,' ',4):sub(1,64)
    if #label<3 then return message(source,'Add a clear house name after the minimum level.','error') end
    local ped=GetPlayerPed(source)
    if ped==0 then return message(source,'Your player position is unavailable. Try again after spawning.','error') end
    local pos,heading=GetEntityCoords(ped),GetEntityHeading(ped)
    local id=MySQL.insert.await([[INSERT INTO properties(label,price,interior,entry,interior_pos,exit_pos,minimum_level,for_sale,enabled)
      VALUES(?,?,?,?,?,?,?,1,1)]],{label,math.floor(price),interior,encodePos(pos,heading),encodePos(preset.coords,preset.coords.w),encodePos(pos,heading),math.floor(level)})
    TriggerClientEvent('sunset:client:propertiesChanged',-1)
    message(source,('House #%d "%s" created: $%d, %s, level %d.'):format(id,label,price,interior,level),'success')
end,false)

RegisterCommand('houseinteriors',function(source)
    local list={}; for id,preset in pairs(SunsetProperties.Interiors) do list[#list+1]=id..' ('..preset.label..')' end; table.sort(list)
    message(source,'Available interiors: '..table.concat(list,', '),'info')
end,false)

RegisterCommand('houselock',function(source,args) local ok,msg=toggleLock(source,tonumber(args[1])); message(source,msg,ok and 'success' or 'error') end,false)

RegisterCommand('houserent',function(source,args)
    local price=tonumber(args[1]); local _,prop,err=ownedProperty(source,tonumber(args[2])); if not prop then return message(source,err,'error') end
    if args[1]=='off' then MySQL.update.await('UPDATE properties SET rent_enabled=0 WHERE id=?',{prop.id}); TriggerClientEvent('sunset:client:propertiesChanged',-1); return message(source,'New rentals disabled; existing renters keep access.','success') end
    if not price or price<SunsetProperties.RentMin or price>SunsetProperties.RentMax then return message(source,('Usage: /houserent [price|off] [house id]. Limit: $%d-$%d per payday.'):format(SunsetProperties.RentMin,SunsetProperties.RentMax),'error') end
    MySQL.update.await('UPDATE properties SET rent_enabled=1,rent_price=? WHERE id=?',{math.floor(price),prop.id}); TriggerClientEvent('sunset:client:propertiesChanged',-1)
    message(source,('Rent enabled at $%d per payday.'):format(price),'success')
end,false)

RegisterCommand('housemaxrenters',function(source,args)
    local count=tonumber(args[1]); local _,prop,err=ownedProperty(source,tonumber(args[2])); if not prop then return message(source,err,'error') end
    if not count or count<SunsetProperties.MaxRentersMin or count>SunsetProperties.MaxRentersMax then return message(source,('Usage: /housemaxrenters [%d-%d] [house id].'):format(SunsetProperties.MaxRentersMin,SunsetProperties.MaxRentersMax),'error') end
    MySQL.update.await('UPDATE properties SET max_renters=? WHERE id=?',{math.floor(count),prop.id}); TriggerClientEvent('sunset:client:propertiesChanged',-1); message(source,('Maximum renters set to %d.'):format(count),'success')
end,false)

RegisterCommand('houseinterior',function(source,args)
    local key=tostring(args[1] or ''); local preset=SunsetProperties.Interiors[key]
    if not preset then return message(source,'Unknown interior. Use /houseinteriors to see valid names.','error') end
    local _,prop,err=ownedProperty(source,tonumber(args[2])); if not prop then return message(source,err,'error') end
    for player,id in pairs(Inside) do if id==prop.id and tonumber(player)~=source then return message(source,'Everyone else must leave before the interior is changed.','error') end end
    MySQL.update.await('UPDATE properties SET interior=?,interior_pos=? WHERE id=?',{key,encodePos(preset.coords,preset.coords.w),prop.id})
    message(source,('Interior changed to %s. Re-enter to see it.'):format(preset.label),'success')
end,false)

RegisterCommand('houserenters',function(source,args)
    local _,prop,err=ownedProperty(source,tonumber(args[1])); if not prop then return message(source,err,'error') end
    local rows=MySQL.query.await([[SELECT r.character_id,TRIM(CONCAT(c.firstname,' ',c.lastname)) name,r.rent_price,r.last_paid_at
      FROM property_rentals r JOIN characters c ON c.id=r.character_id WHERE r.property_id=? AND r.active=1 ORDER BY r.started_at]],{prop.id}) or {}
    if #rows==0 then return message(source,'This house currently has no renters.','info') end
    local list={}; for _,row in ipairs(rows) do list[#list+1]=('#%d %s ($%d/payday)'):format(row.character_id,row.name,row.rent_price) end
    message(source,'Renters: '..table.concat(list,', '),'info')
end,false)

RegisterCommand('housekickrenter',function(source,args)
    local characterId=tonumber(args[1]); local _,prop,err=ownedProperty(source,tonumber(args[2])); if not prop then return message(source,err,'error') end
    if not characterId then return message(source,'Usage: /housekickrenter [character id] [house id]','error') end
    local changed=MySQL.update.await('UPDATE property_rentals SET active=0 WHERE property_id=? AND character_id=? AND active=1',{prop.id,characterId})
    if changed<1 then return message(source,'That character is not an active renter in this house.','error') end
    clearHome(characterId,prop.id,('The owner removed you from %s. Your job and faction were not changed.'):format(prop.label))
    TriggerClientEvent('sunset:client:propertiesChanged',-1); message(source,('Renter #%d was removed.'):format(characterId),'success')
end,false)

RegisterCommand('sellhouse',function(source,args)
    local id=tonumber(args[1]); local owner,prop,err=ownedProperty(source,id); if not prop then return message(source,err,'error') end
    if tostring(args[2] or ''):lower()~='confirm' then return message(source,('This permanently sells %s for 70%% ($%d). Use /sellhouse %d confirm.'):format(prop.label,math.floor(prop.price*0.7),prop.id),'error') end
    local refund=math.floor((tonumber(prop.price) or 0)*0.7)
    local renters=MySQL.query.await('SELECT character_id FROM property_rentals WHERE property_id=? AND active=1',{prop.id}) or {}
    MySQL.update.await('UPDATE property_rentals SET active=0 WHERE property_id=?',{prop.id})
    for _,renter in ipairs(renters) do clearHome(renter.character_id,prop.id,('Your rental at %s ended because the house was sold.'):format(prop.label)) end
    MySQL.update.await('UPDATE characters SET home_property_id=NULL WHERE home_property_id=?',{prop.id})
    MySQL.update.await('UPDATE properties SET owner_character_id=NULL,locked=1,rent_enabled=0 WHERE id=? AND owner_character_id=?',{prop.id,owner.id})
    local char=exports.sunset_core:GetCharacter(source); char.home_property_id=nil; exports.sunset_core:AddMoney(source,'bank',refund,'house_sale')
    TriggerClientEvent('sunset:client:propertiesChanged',-1); message(source,('House sold. $%d was deposited in your bank.'):format(refund),'success')
end,false)

RegisterCommand('ahouseedit',function(source,args)
    if source==0 or not exports.sunset_admin:IsAdmin(source,SunsetProperties.AdminLevel) then return message(source,'Admin level 3 is required.','error') end
    local id,field=tonumber(args[1]),tostring(args[2] or ''):lower(); local fields={price='price',level='minimum_level',name='label',sale='for_sale',enabled='enabled'}
    if not id or not fields[field] then return message(source,'Usage: /ahouseedit [id] [price|level|name|sale|enabled] [value]','error') end
    local value=table.concat(args,' ',3); if field~='name' then value=tonumber(value) end
    if value==nil or (field~='name' and value<0) or (field=='name' and #value<3) then return message(source,'Enter a valid value.','error') end
    local changed=MySQL.update.await(('UPDATE properties SET %s=? WHERE id=?'):format(fields[field]),{value,id})
    if changed<1 then return message(source,'House not found or value unchanged.','error') end
    TriggerClientEvent('sunset:client:propertiesChanged',-1); message(source,('House #%d updated: %s = %s.'):format(id,field,tostring(value)),'success')
end,false)

RegisterCommand('renthouse',function(source) message(source,'Stand at a house, press E, then choose RENT. /properties lists all houses.','info') end,false)
RegisterCommand('unrent',function(source)
    local char=exports.sunset_core:GetCharacter(source); if not char then return end; local rent=activeRental(char.id)
    if not rent then return message(source,'You do not currently rent a house.','error') end
    MySQL.update.await('UPDATE property_rentals SET active=0 WHERE id=?',{rent.id}); if tonumber(char.home_property_id)==tonumber(rent.property_id) then char.home_property_id=nil; MySQL.update.await('UPDATE characters SET home_property_id=NULL WHERE id=?',{char.id}) end
    TriggerClientEvent('sunset:client:propertiesChanged',-1); message(source,'Rental ended. Your civilian job and faction are unchanged.','success')
end,false)

function ProcessRentPayday(source)
    local char=exports.sunset_core:GetCharacter(source); if not char then return {charged=0} end
    local rent=MySQL.single.await([[SELECT r.*,p.label,p.owner_character_id FROM property_rentals r JOIN properties p ON p.id=r.property_id WHERE r.character_id=? AND r.active=1 LIMIT 1]],{char.id})
    if not rent then return {charged=0} end
    local price=tonumber(rent.rent_price) or 0
    if not charge(source,price,'house_rent_payday') then
        MySQL.update.await('UPDATE property_rentals SET active=0 WHERE id=?',{rent.id}); if tonumber(char.home_property_id)==tonumber(rent.property_id) then clearHome(char.id,rent.property_id) end
        message(source,('Rental at %s ended because you could not pay $%d.'):format(rent.label,price),'error'); return {charged=0,evicted=true}
    end
    MySQL.update.await('UPDATE property_rentals SET last_paid_at=NOW() WHERE id=?',{rent.id}); creditOwner(rent.owner_character_id,price)
    return {charged=price,label=rent.label}
end
exports('ProcessRentPayday',ProcessRentPayday)
