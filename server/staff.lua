local QBCore = exports['qb-core']:GetCoreObject()

-- /addstaff [id/cid/license] [cargo]
QBCore.Commands.Add('addstaff', 'Adicionar cargo de Staff a um jogador', {{name='alvo', help='id/citizenid/license'}, {name='cargo', help='ex: helper, mod, admin'}}, true, function(source, args)
    if not PermsCore.IsManager(source) then return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error') end
    local target = args[1]
    local cargo = args[2] and tostring(args[2]):lower() or nil
    local ok, err = PermsCore.Add(source, target, 'staff', cargo, nil)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('Staff %s adicionada.'):format(cargo or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, err or 'Falha ao adicionar staff', 'error')
    end
end, 'admin')

-- /removestaff [id/cid/license] [cargo]
QBCore.Commands.Add('removestaff', 'Remover cargo de Staff de um jogador', {{name='alvo', help='id/citizenid/license'}, {name='cargo', help='ex: helper, mod, admin'}}, true, function(source, args)
    if not PermsCore.IsManager(source) then return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error') end
    local target = args[1]
    local cargo = args[2] and tostring(args[2]):lower() or nil
    local ok = PermsCore.Remove(source, target, 'staff', cargo)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('Staff %s removida.'):format(cargo or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Nada removido (verifique o nome)', 'error')
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
