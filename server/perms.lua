local QBCore = exports['qb-core']:GetCoreObject()

local function _isManager(src)
    for _, g in ipairs(Config.ManagerGroups) do
        if QBCore.Functions.HasPermission(src, g) then
            return true
        end
    end
    return false
end

local function _getPlayerIdentity(target)
    local player, identifier, citizenid, name = nil, nil, nil, nil

    if type(target) == 'number' or tonumber(target) then
        player = QBCore.Functions.GetPlayer(tonumber(target))
    end

    if player then
        citizenid = player.PlayerData.citizenid
        identifier = player.PlayerData.license or player.PlayerData.license2 or player.PlayerData.steam
        name = (player.PlayerData.charinfo and player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo and player.PlayerData.charinfo.lastname or '')
    else
        local tgt = tostring(target or '')
        if tgt:find('license:') then
            identifier = tgt
            local row = MySQL.single.await('SELECT citizenid FROM '..Config.Table..' WHERE identifier = ? LIMIT 1', { identifier })
            if row then citizenid = row.citizenid end
        else
            citizenid = tgt ~= '' and tgt or nil
            if citizenid then
                local row = MySQL.single.await('SELECT identifier FROM '..Config.Table..' WHERE citizenid = ? LIMIT 1', { citizenid })
                if row then identifier = row.identifier end
            end
        end
        name = 'Offline Player'
    end

    return { player = player, identifier = identifier, citizenid = citizenid, name = name }
end

local function _normalizeType(t)
    t = (t or ''):lower()
    if t == 'vip' or t == 'vips' then return 'vip' end
    if t == 'staff' then return 'staff' end
    return 'group'
end

local function _allowedName(kind, name)
    if not name or name == '' then return false end
    local list = {}
    if kind == 'vip' then list = Config.AllowedVipNames
    elseif kind == 'staff' then list = Config.AllowedStaffNames
    else list = Config.AllowedGroupNames
    end
    if not list or #list == 0 then return true end
    name = name:lower()
    for _, n in ipairs(list) do
        if n:lower() == name then return true end
    end
    return false
end

local function _addGroup(src, target, kind, name, expiresAt)
    local ident = _getPlayerIdentity(target)
    if not ident.citizenid then
        return false, 'Jogador/alvo não encontrado (use ID online, citizenid ou license:...)'
    end
    kind = _normalizeType(kind)
    if not _allowedName(kind, name) then
        return false, ('Nome inválido para %s.'):format(kind)
    end
    local exists = MySQL.single.await('SELECT id FROM '..Config.Table..' WHERE citizenid = ? AND type = ? AND group_name = ? LIMIT 1', {
        ident.citizenid, kind, name
    })
    if exists then
        return false, 'Esse grupo já foi setado para o jogador.'
    end
    MySQL.insert.await('INSERT INTO '..Config.Table..' (identifier, citizenid, type, group_name, added_by, added_at, expires_at) VALUES (?, ?, ?, ?, ?, NOW(), ?)', {
        ident.identifier or '', ident.citizenid, kind, name, GetPlayerName(src) or 'console', expiresAt
    })
    if ident.player then
        TriggerClientEvent('chat:addMessage', ident.player.PlayerData.source, { args = { '^2PERMS', ('Você recebeu %s: ^3%s^7.'):format(kind, name) } })
        _refreshPlayerMeta(ident.player.PlayerData.source)
    end
    return true
end

local function _removeGroup(src, target, kind, name)
    local ident = _getPlayerIdentity(target)
    if not ident.citizenid then
        return false, 'Jogador/alvo não encontrado (use ID online, citizenid ou license:...)'
    end
    kind = _normalizeType(kind)
    local rows = MySQL.update.await('DELETE FROM '..Config.Table..' WHERE citizenid = ? AND type = ? AND group_name = ?', {
        ident.citizenid, kind, name
    })
    if rows > 0 and ident.player then
        TriggerClientEvent('chat:addMessage', ident.player.PlayerData.source, { args = { '^1PERMS', ('Você perdeu %s: ^3%s^7.'):format(kind, name) } })
        _refreshPlayerMeta(ident.player.PlayerData.source)
    end
    return rows > 0
end

function _refreshPlayerMeta(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local data = MySQL.query.await('SELECT type, group_name, expires_at FROM '..Config.Table..' WHERE citizenid = ?', { player.PlayerData.citizenid })
    local perms = { staff = {}, vip = {}, group = {} }
    local now = os.time()
    for _, r in ipairs(data or {}) do
        local expired = false
        if r.expires_at and r.expires_at ~= 0 then
            local ts = 0
            if type(r.expires_at) == 'number' then
                ts = r.expires_at
            else
                local y,mo,d,h,mi,s = tostring(r.expires_at):match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$")
                if y then
                    ts = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(d), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
                end
            end
            if ts > 0 and ts < now then
                expired = true
            end
        end
        if not expired then
            perms[r.type] = perms[r.type] or {}
            perms[r.type][r.group_name:lower()] = true
        end
    end
    player.Functions.SetMetaData('perms', perms)
    Entity(GetPlayerPed(src)).state:set('mz_perms', perms, true)
end

local function _hierarchyHas(map, ownedSet, requiredName)
    -- ownedSet: tabela com chaves = nomes que o player possui
    -- map: tabela de hierarquia (nome -> nível)
    if not requiredName then
        -- qualquer um serve
        for _ in pairs(ownedSet) do return true end
        return false
    end
    local reqLvl = map[requiredName]
    if not reqLvl then
        -- se não existir no mapa, fallback: match exato
        return ownedSet[requiredName] and true or false
    end
    for name in pairs(ownedSet) do
        local lvl = map[name]
        if lvl and lvl >= reqLvl then
            return true
        end
    end
    return false
end

-- EXPORTS
exports('HasGroup', function(src, groupName)
    local player = QBCore.Functions.GetPlayer(src); if not player then return false end
    local meta = player.PlayerData.metadata and player.PlayerData.metadata.perms or {}
    local g = meta.group or {}
    groupName = groupName and groupName:lower() or nil
    if Config.EnableGroupHierarchy and next(Config.GroupHierarchy) ~= nil then
        return _hierarchyHas(Config.GroupHierarchy, g, groupName)
    end
    if not groupName then
        for _ in pairs(g) do return true end
        return false
    end
    return g[groupName] and true or false
end)

exports('HasVip', function(src, vipName)
    local player = QBCore.Functions.GetPlayer(src); if not player then return false end
    local meta = player.PlayerData.metadata and player.PlayerData.metadata.perms or {}
    local g = meta.vip or {}
    vipName = vipName and vipName:lower() or nil
    if Config.EnableVipHierarchy and next(Config.VipHierarchy) ~= nil then
        return _hierarchyHas(Config.VipHierarchy, g, vipName)
    end
    if not vipName then
        for _ in pairs(g) do return true end
        return false
    end
    return g[vipName] and true or false
end)

exports('HasStaff', function(src, staffName)
    local player = QBCore.Functions.GetPlayer(src); if not player then return false end
    local meta = player.PlayerData.metadata and player.PlayerData.metadata.perms or {}
    local g = meta.staff or {}
    staffName = staffName and staffName:lower() or nil
    if Config.EnableStaffHierarchy and next(Config.StaffHierarchy) ~= nil then
        return _hierarchyHas(Config.StaffHierarchy, g, staffName)
    end
    if not staffName then
        for _ in pairs(g) do return true end
        return false
    end
    return g[staffName] and true or false
end)

exports('GetPlayerGroups', function(src)
    local player = QBCore.Functions.GetPlayer(src); if not player then return {} end
    return player.PlayerData.metadata and player.PlayerData.metadata.perms or {}
end)

PermsCore = {
    IsManager = _isManager,
    Add = _addGroup,
    Remove = _removeGroup,
    Refresh = _refreshPlayerMeta,
    GetIdentity = _getPlayerIdentity,
}


AddEventHandler('QBCore:Server:OnPlayerLoaded', function(Player)
    if Player and Player.PlayerData and Player.PlayerData.source then
        _refreshPlayerMeta(Player.PlayerData.source)
    end
end)

-- compat caso sua base use outro nome de evento
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    _refreshPlayerMeta(src)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, src in ipairs(GetPlayers()) do
        _refreshPlayerMeta(tonumber(src))
    end
end)
