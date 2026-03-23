local QBCore = exports['qb-core']:GetCoreObject()

local function _now()
    return os.time()
end

local function _trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function _toLower(value)
    return _trim(value):lower()
end

local function _isManager(src)
    for _, g in ipairs(Config.ManagerGroups) do
        if QBCore.Functions.HasPermission(src, g) then
            return true
        end

        if IsPlayerAceAllowed(src, g) then
            return true
        end

        if IsPlayerAceAllowed(src, 'group.' .. g) then
            return true
        end

        if IsPlayerAceAllowed(src, 'qbcore.' .. g) then
            return true
        end
    end
    return false
end

local function _parseExpiryToTimestamp(value)
    if not value or value == 0 or value == '' then return nil end
    if type(value) == 'number' then return value end

    local y, mo, d, h, mi, s = tostring(value):match('^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$')
    if y then
        return os.time({
            year = tonumber(y),
            month = tonumber(mo),
            day = tonumber(d),
            hour = tonumber(h),
            min = tonumber(mi),
            sec = tonumber(s)
        })
    end

    return nil
end

local function _isExpired(expiresAt)
    local ts = _parseExpiryToTimestamp(expiresAt)
    return ts ~= nil and ts > 0 and ts <= _now()
end

local function _fetchPlayerRow(whereClause, value)
    local tableName = tostring(Config.PlayersTable or 'players')
    local query = ('SELECT citizenid, license, charinfo FROM `%s` WHERE %s LIMIT 1'):format(tableName, whereClause)
    local ok, row = pcall(function()
        return MySQL.single.await(query, { value })
    end)
    if ok and row then return row end
    return nil
end

local function _decodeNameFromCharinfo(charinfo)
    if type(charinfo) == 'table' then
        local first = tostring(charinfo.firstname or '')
        local last = tostring(charinfo.lastname or '')
        local full = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
        return full ~= '' and full or 'Offline Player'
    end

    if type(charinfo) == 'string' and charinfo ~= '' then
        local ok, decoded = pcall(json.decode, charinfo)
        if ok and type(decoded) == 'table' then
            return _decodeNameFromCharinfo(decoded)
        end
    end

    return 'Offline Player'
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
        name = _trim(name)
        if name == '' then
            name = GetPlayerName(player.PlayerData.source) or ('ID ' .. tostring(player.PlayerData.source))
        end
    else
        local tgt = tostring(target or '')
        local row = nil

        if tgt:find('license:') then
            identifier = tgt
            row = _fetchPlayerRow('license = ?', identifier)
            if not row then
                row = MySQL.single.await('SELECT citizenid FROM '..Config.Table..' WHERE identifier = ? LIMIT 1', { identifier })
            end
            if row then
                citizenid = row.citizenid
                identifier = row.license or identifier
                name = _decodeNameFromCharinfo(row.charinfo)
            end
        else
            citizenid = tgt ~= '' and tgt or nil
            if citizenid then
                row = _fetchPlayerRow('citizenid = ?', citizenid)
                if not row then
                    row = MySQL.single.await('SELECT identifier FROM '..Config.Table..' WHERE citizenid = ? LIMIT 1', { citizenid })
                end
                if row then
                    identifier = row.license or row.identifier or identifier
                    name = _decodeNameFromCharinfo(row.charinfo)
                end
            end
        end

        name = name or 'Offline Player'
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
    name = _toLower(name)
    if name == '' then return false end

    local list = {}
    if kind == 'vip' then list = Config.AllowedVipNames
    elseif kind == 'staff' then list = Config.AllowedStaffNames
    else list = Config.AllowedGroupNames end

    if not list or #list == 0 then return true end

    for _, n in ipairs(list) do
        if _toLower(n) == name then
            return true
        end
    end

    return false
end

local function _getMetaPerms(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return {} end
    return (player.PlayerData.metadata and player.PlayerData.metadata.perms) or {}
end

local function _getDirectSet(src, kind)
    local meta = _getMetaPerms(src)
    return meta[kind] or {}
end

local function _setPlayerState(src, perms)
    local player = Player(src)
    if player and player.state then
        player.state:set('mz_perms', perms, true)
    end
end

local function _cleanupExpiredRowsForCitizen(citizenid)
    if not citizenid or citizenid == '' then return end
    MySQL.query.await(('DELETE FROM `%s` WHERE citizenid = ? AND expires_at IS NOT NULL AND expires_at < NOW()'):format(Config.Table), { citizenid })
end

function _refreshPlayerMeta(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    _cleanupExpiredRowsForCitizen(player.PlayerData.citizenid)

    local data = MySQL.query.await('SELECT type, group_name, expires_at FROM '..Config.Table..' WHERE citizenid = ?', { player.PlayerData.citizenid })
    local perms = { staff = {}, vip = {}, group = {} }

    for _, r in ipairs(data or {}) do
        local groupName = _toLower(r.group_name)
        if groupName ~= '' and not _isExpired(r.expires_at) then
            perms[r.type] = perms[r.type] or {}
            perms[r.type][groupName] = true
        end
    end

    player.Functions.SetMetaData('perms', perms)
    _setPlayerState(src, perms)
end

local function _numericHierarchyHas(map, ownedSet, requiredName)
    requiredName = requiredName and _toLower(requiredName) or nil
    if not requiredName then
        for _ in pairs(ownedSet or {}) do return true end
        return false
    end

    local reqLvl = tonumber(map[requiredName] or 0) or 0
    if reqLvl <= 0 then
        return ownedSet[requiredName] == true
    end

    for name in pairs(ownedSet or {}) do
        local lvl = tonumber(map[name] or 0) or 0
        if lvl >= reqLvl then
            return true
        end
    end

    return false
end

local function _getStaffRule(role)
    role = _toLower(role)
    return (Config.StaffRoleRules or {})[role]
end

local function _getStaffPower(role)
    role = _toLower(role)
    local rule = _getStaffRule(role)
    if rule and tonumber(rule.power or 0) > 0 then
        return tonumber(rule.power or 0)
    end
    return tonumber((Config.StaffHierarchy or {})[role] or 0) or 0
end

local function _getStaffParents(role)
    role = _toLower(role)
    local rule = _getStaffRule(role)
    if not rule or type(rule.parents) ~= 'table' then
        return {}
    end

    local out = {}
    for _, parent in ipairs(rule.parents) do
        local normalized = _toLower(parent)
        if normalized ~= '' then
            out[#out + 1] = normalized
        end
    end
    return out
end

local function _staffRoleInherits(role, requiredRole, visited)
    role = _toLower(role)
    requiredRole = _toLower(requiredRole)

    if role == '' or requiredRole == '' then return false end
    if role == requiredRole then return true end

    visited = visited or {}
    if visited[role] then return false end
    visited[role] = true

    for _, parent in ipairs(_getStaffParents(role)) do
        if _staffRoleInherits(parent, requiredRole, visited) then
            return true
        end
    end

    return false
end

local function _staffSetHas(ownedSet, requiredRole)
    requiredRole = requiredRole and _toLower(requiredRole) or nil
    if not requiredRole then
        for _ in pairs(ownedSet or {}) do return true end
        return false
    end

    for name, enabled in pairs(ownedSet or {}) do
        if enabled and _staffRoleInherits(name, requiredRole) then
            return true
        end
    end

    return false
end

local function _getHighestStaffRoleFromSet(staffSet)
    local bestName, bestPower = nil, 0
    for name, enabled in pairs(staffSet or {}) do
        if enabled then
            local power = _getStaffPower(name)
            if power > bestPower then
                bestPower = power
                bestName = name
            elseif power == bestPower and bestName and tostring(name) < tostring(bestName) then
                bestName = name
            elseif power == bestPower and not bestName then
                bestName = name
            end
        end
    end
    return bestName, bestPower
end

local function _getStaffSnapshotFromSet(staffSet)
    local roles = {}
    for role, enabled in pairs(staffSet or {}) do
        if enabled then
            roles[#roles + 1] = role
        end
    end
    table.sort(roles)

    local highestRole, highestPower = _getHighestStaffRoleFromSet(staffSet or {})
    return {
        roles = roles,
        roleSet = staffSet or {},
        highestRole = highestRole,
        highestLevel = highestPower or 0,
        highestPower = highestPower or 0
    }
end

local function _getStaffSnapshot(target)
    local ident = _getPlayerIdentity(target)
    if not ident.citizenid then
        return { ok = false, error = 'Alvo não encontrado.', identity = ident }
    end

    local roleSet = {}

    if ident.player then
        roleSet = _getDirectSet(ident.player.PlayerData.source, 'staff') or {}
    else
        _cleanupExpiredRowsForCitizen(ident.citizenid)
        local rows = MySQL.query.await('SELECT group_name FROM '..Config.Table..' WHERE citizenid = ? AND type = "staff" ORDER BY group_name ASC', { ident.citizenid }) or {}
        for _, row in ipairs(rows) do
            local role = _toLower(row.group_name)
            if role ~= '' then
                roleSet[role] = true
            end
        end
    end

    local snapshot = _getStaffSnapshotFromSet(roleSet)
    snapshot.ok = true
    snapshot.identity = ident
    return snapshot
end

local function _canActorAssignRole(actorSrc, role)
    role = _toLower(role)
    if role == '' then return false, 'Cargo inválido.' end

    if _isManager(actorSrc) then
        return true
    end

    local actorSet = _getDirectSet(actorSrc, 'staff')
    local actorHighestRole, actorPower = _getHighestStaffRoleFromSet(actorSet)
    if not actorHighestRole or actorPower <= 0 then
        return false, 'Você não possui autoridade de staff.'
    end

    local rolePower = _getStaffPower(role)
    if rolePower <= 0 then
        return false, 'Cargo inválido.'
    end

    if actorPower <= rolePower then
        return false, 'Você só pode definir cargos abaixo do seu nível.'
    end

    if not _staffSetHas(actorSet, role) then
        return false, 'Você não pode definir esse cargo fora da sua árvore.'
    end

    return true
end

local function _canActorTouchTarget(actorSrc, target, actionName)
    if _isManager(actorSrc) then
        return true
    end

    local actorSnapshot = _getStaffSnapshot(actorSrc)
    if not actorSnapshot.ok or actorSnapshot.highestPower <= 0 then
        return false, 'Você não possui autoridade de staff.'
    end

    local targetSnapshot = _getStaffSnapshot(target)
    if not targetSnapshot.ok then
        return false, targetSnapshot.error or 'Alvo não encontrado.'
    end

    if targetSnapshot.identity and targetSnapshot.identity.player and actorSrc == targetSnapshot.identity.player.PlayerData.source then
        return true
    end

    if targetSnapshot.highestPower <= 0 then
        return true
    end

    if actorSnapshot.highestPower <= targetSnapshot.highestPower then
        return false, 'Você não pode agir em alguém do mesmo nível ou acima do seu.'
    end

    if targetSnapshot.highestRole and not _staffSetHas(actorSnapshot.roleSet, targetSnapshot.highestRole) then
        return false, 'Você não pode agir em um cargo de outra árvore da staff.'
    end

    return true
end

local function _addGroup(src, target, kind, name, expiresAt)
    local ident = _getPlayerIdentity(target)
    if not ident.citizenid then
        return false, 'Jogador/alvo não encontrado (use ID online, citizenid ou license:...)'
    end

    kind = _normalizeType(kind)
    name = _toLower(name)

    if not _allowedName(kind, name) then
        return false, ('Nome inválido para %s.'):format(kind)
    end

    local exists = MySQL.single.await('SELECT id FROM '..Config.Table..' WHERE citizenid = ? AND type = ? AND group_name = ? LIMIT 1', {
        ident.citizenid, kind, name
    })
    if exists then
        return false, 'Esse grupo já foi setado para o jogador.'
    end

    local ok, result = pcall(function()
        return MySQL.insert.await('INSERT INTO '..Config.Table..' (identifier, citizenid, type, group_name, added_by, added_at, expires_at) VALUES (?, ?, ?, ?, ?, NOW(), ?)', {
            ident.identifier or '', ident.citizenid, kind, name, GetPlayerName(src) or 'console', expiresAt
        })
    end)

    if not ok then
        local msg = tostring(result or '')
        if msg:lower():find('duplicate') then
            return false, 'Esse grupo já foi setado para o jogador.'
        end
        return false, 'Falha ao salvar permissão.'
    end

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
    name = _toLower(name)

    local rows = MySQL.update.await('DELETE FROM '..Config.Table..' WHERE citizenid = ? AND type = ? AND group_name = ?', {
        ident.citizenid, kind, name
    })

    if rows > 0 and ident.player then
        TriggerClientEvent('chat:addMessage', ident.player.PlayerData.source, { args = { '^1PERMS', ('Você perdeu %s: ^3%s^7.'):format(kind, name) } })
        _refreshPlayerMeta(ident.player.PlayerData.source)
    end

    return rows > 0
end

-- EXPORTS ---------------------------------------------------------------
exports('HasGroup', function(src, groupName)
    local groupSet = _getDirectSet(src, 'group') or {}
    groupName = groupName and _toLower(groupName) or nil

    if Config.EnableGroupHierarchy and next(Config.GroupHierarchy) ~= nil then
        return _numericHierarchyHas(Config.GroupHierarchy, groupSet, groupName)
    end

    if not groupName then
        for _ in pairs(groupSet) do return true end
        return false
    end

    return groupSet[groupName] == true
end)

exports('HasVip', function(src, vipName)
    local vipSet = _getDirectSet(src, 'vip') or {}
    vipName = vipName and _toLower(vipName) or nil

    if Config.EnableVipHierarchy and next(Config.VipHierarchy) ~= nil then
        return _numericHierarchyHas(Config.VipHierarchy, vipSet, vipName)
    end

    if not vipName then
        for _ in pairs(vipSet) do return true end
        return false
    end

    return vipSet[vipName] == true
end)

exports('HasStaff', function(src, staffName)
    local staffSet = _getDirectSet(src, 'staff') or {}
    staffName = staffName and _toLower(staffName) or nil

    if Config.EnableStaffHierarchy then
        return _staffSetHas(staffSet, staffName)
    end

    if not staffName then
        for _ in pairs(staffSet) do return true end
        return false
    end

    return staffSet[staffName] == true
end)

exports('GetPlayerGroups', function(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return {} end
    return player.PlayerData.metadata and player.PlayerData.metadata.perms or {}
end)

exports('GetStaffConfig', function()
    return {
        table = Config.Table,
        allowed = Config.AllowedStaffNames or {},
        hierarchy = Config.StaffHierarchy or {},
        rules = Config.StaffRoleRules or {}
    }
end)

exports('GetStaffSnapshot', function(target)
    return _getStaffSnapshot(target)
end)

exports('GetAssignableStaffRoles', function(src)
    local roles = {}
    if _isManager(src) then
        for _, role in ipairs(Config.AllowedStaffNames or {}) do
            roles[#roles + 1] = { name = _toLower(role), level = _getStaffPower(role) }
        end
        table.sort(roles, function(a, b)
            if a.level == b.level then return a.name < b.name end
            return a.level < b.level
        end)
        return { roles = roles, actorLevel = 9999 }
    end

    local actorSet = _getDirectSet(src, 'staff') or {}
    local _, actorPower = _getHighestStaffRoleFromSet(actorSet)
    if actorPower <= 0 then
        return { roles = {}, actorLevel = 0 }
    end

    for _, role in ipairs(Config.AllowedStaffNames or {}) do
        role = _toLower(role)
        local rolePower = _getStaffPower(role)
        if rolePower > 0 and actorPower > rolePower and _staffSetHas(actorSet, role) then
            roles[#roles + 1] = { name = role, level = rolePower }
        end
    end

    table.sort(roles, function(a, b)
        if a.level == b.level then return a.name < b.name end
        return a.level < b.level
    end)

    return { roles = roles, actorLevel = actorPower }
end)

exports('GetPlayerStaffRoles', function(target)
    local snapshot = _getStaffSnapshot(target)
    return {
        ok = snapshot.ok == true,
        error = snapshot.error,
        identity = snapshot.identity,
        roles = snapshot.roles or {},
        highestRole = snapshot.highestRole,
        highestLevel = snapshot.highestLevel or 0
    }
end)

exports('CanActOnTarget', function(actorSrc, target, actionName)
    local ok, err = _canActorTouchTarget(actorSrc, target, actionName)
    return ok, err
end)

exports('ManageStaffRole', function(actorSrc, target, action, role)
    action = _toLower(action)
    role = _toLower(role)

    if action ~= 'add' and action ~= 'remove' then
        return false, 'Ação inválida.'
    end

    if actorSrc and tonumber(actorSrc) and tonumber(actorSrc) > 0 then
        local targetIdentity = _getPlayerIdentity(target)
        if targetIdentity.player and tonumber(targetIdentity.player.PlayerData.source) == tonumber(actorSrc) then
            return false, 'Você não pode alterar os próprios cargos.'
        end
    end

    if not _allowedName('staff', role) then
        return false, 'Cargo inválido.'
    end

    local canAssign, assignErr = _canActorAssignRole(actorSrc, role)
    if not canAssign then
        return false, assignErr or 'Você não pode definir esse cargo.'
    end

    local canTouchTarget, targetErr = _canActorTouchTarget(actorSrc, target, 'manage_staff')
    if not canTouchTarget then
        return false, targetErr or 'Você não pode alterar esse alvo.'
    end

    local ident = _getPlayerIdentity(target)
    if not ident.citizenid then
        return false, 'Jogador/alvo não encontrado.'
    end

    if action == 'add' then
        local ok, err = _addGroup(actorSrc, target, 'staff', role, nil)
        if ok and ident.player then _refreshPlayerMeta(ident.player.PlayerData.source) end
        return ok, err
    end

    local ok = _removeGroup(actorSrc, target, 'staff', role)
    if ok and ident.player then _refreshPlayerMeta(ident.player.PlayerData.source) end
    return ok, ok and nil or 'Nada removido.'
end)

PermsCore = {
    IsManager = _isManager,
    Add = _addGroup,
    Remove = _removeGroup,
    Refresh = _refreshPlayerMeta,
    GetIdentity = _getPlayerIdentity,
    GetStaffSnapshot = _getStaffSnapshot,
    CanActOnTarget = _canActorTouchTarget,
    GetStaffPower = _getStaffPower
}

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(Player)
    if Player and Player.PlayerData and Player.PlayerData.source then
        _refreshPlayerMeta(Player.PlayerData.source)
    end
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    _refreshPlayerMeta(src)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    pcall(function()
        MySQL.query.await(('ALTER TABLE `%s` ADD UNIQUE KEY `uniq_player_group` (`citizenid`, `type`, `group_name`)'):format(Config.Table))
    end)

    for _, src in ipairs(GetPlayers()) do
        _refreshPlayerMeta(tonumber(src))
    end
end)

CreateThread(function()
    local every = tonumber(Config.CleanupExpiredEveryMinutes or 0) or 0
    if every <= 0 then return end

    while true do
        Wait(every * 60 * 1000)
        pcall(function()
            MySQL.query.await(('DELETE FROM `%s` WHERE expires_at IS NOT NULL AND expires_at < NOW()'):format(Config.Table))
        end)
        for _, src in ipairs(GetPlayers()) do
            _refreshPlayerMeta(tonumber(src))
        end
    end
end)
