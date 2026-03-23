local QBCore = exports['qb-core']:GetCoreObject()

local function _canUseStaffManage(source)
    if PermsCore.IsManager(source) then return true end
    local resource = GetCurrentResourceName()
    if GetResourceState(resource) == 'started' and exports[resource] and exports[resource].ManageStaffRole then
        local snap = exports[resource]:GetStaffSnapshot(source)
        return snap and snap.ok and (tonumber(snap.highestLevel or 0) or 0) > 0
    end
    return false
end

-- /addstaff [id/cid/license] [cargo]
QBCore.Commands.Add('addstaff', 'Adicionar cargo de Staff a um jogador', {{name='alvo', help='id/citizenid/license'}, {name='cargo', help='ex: helper, moderador, administrador'}}, true, function(source, args)
    if not _canUseStaffManage(source) then
        return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error')
    end

    local target = args[1]
    local cargo = args[2] and tostring(args[2]):lower() or nil
    local ok, err = exports[GetCurrentResourceName()]:ManageStaffRole(source, target, 'add', cargo)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('Staff %s adicionada.'):format(cargo or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, err or 'Falha ao adicionar staff', 'error')
    end
end, 'admin')

-- /removestaff [id/cid/license] [cargo]
QBCore.Commands.Add('removestaff', 'Remover cargo de Staff de um jogador', {{name='alvo', help='id/citizenid/license'}, {name='cargo', help='ex: helper, moderador, administrador'}}, true, function(source, args)
    if not _canUseStaffManage(source) then
        return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error')
    end

    local target = args[1]
    local cargo = args[2] and tostring(args[2]):lower() or nil
    local ok, err = exports[GetCurrentResourceName()]:ManageStaffRole(source, target, 'remove', cargo)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('Staff %s removida.'):format(cargo or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, err or 'Nada removido (verifique o nome)', 'error')
    end
end, 'admin')

-- /liststaff [id]
QBCore.Commands.Add('liststaff', 'Listar cargos de Staff do jogador', {{name='alvo', help='id/citizenid/license'}}, true, function(source, args)
    local ident = PermsCore.GetIdentity(args[1])
    if not ident.citizenid then return TriggerClientEvent('QBCore:Notify', source, 'Alvo não encontrado', 'error') end
    local rows = MySQL.query.await('SELECT group_name FROM '..Config.Table..' WHERE citizenid = ? AND type = "staff"', { ident.citizenid })
    local names = {}
    for _, r in ipairs(rows or {}) do table.insert(names, r.group_name) end
    TriggerClientEvent('chat:addMessage', source, { args = { '^3STAFF', ('%s: %s'):format(ident.citizenid, (#names>0 and table.concat(names, ', ') or 'nenhum')) } })
end, 'admin')
