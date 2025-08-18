local QBCore = exports['qb-core']:GetCoreObject()

local function _calcExpiry(days)
    days = tonumber(days or Config.DefaultVipDays) or Config.DefaultVipDays
    local now = os.time()
    local expires = now + (days * 24 * 60 * 60)
    return os.date('%Y-%m-%d %H:%M:%S', expires)
end

-- /addvip [id/cid/license] [nome] [dias?]
QBCore.Commands.Add('addvip', 'Adicionar VIP a um jogador', {{name='alvo', help='id/citizenid/license'}, {name='vip', help='ex: vip, vipplus, vipgold'}, {name='dias', help='opcional, padrão Config.DefaultVipDays'}}, true, function(source, args)
    if not PermsCore.IsManager(source) then return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error') end
    local target, vip, days = args[1], args[2] and tostring(args[2]):lower() or nil, args[3]
    local expiresAt = _calcExpiry(days)
    local ok, err = PermsCore.Add(source, target, 'vip', vip, expiresAt)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('VIP %s adicionado até %s.'):format(vip or '?', expiresAt), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, err or 'Falha ao adicionar vip', 'error')
    end
end, 'admin')

-- /removevip [id/cid/license] [nome]
QBCore.Commands.Add('removevip', 'Remover VIP de um jogador', {{name='alvo', help='id/citizenid/license'}, {name='vip', help='ex: vip, vipplus, vipgold'}}, true, function(source, args)
    if not PermsCore.IsManager(source) then return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error') end
    local target, vip = args[1], args[2] and tostring(args[2]):lower() or nil
    local ok = PermsCore.Remove(source, target, 'vip', vip)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('VIP %s removido.'):format(vip or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Nada removido (verifique o nome)', 'error')
    end
end, 'admin')

-- /listvip [id]
QBCore.Commands.Add('listvip', 'Listar VIPs do jogador', {{name='alvo', help='id/citizenid/license'}}, true, function(source, args)
    local ident = PermsCore.GetIdentity(args[1])
    if not ident.citizenid then return TriggerClientEvent('QBCore:Notify', source, 'Alvo não encontrado', 'error') end
    local rows = MySQL.query.await('SELECT group_name, expires_at FROM '..Config.Table..' WHERE citizenid = ? AND type = "vip"', { ident.citizenid })
    local list = {}
    for _, r in ipairs(rows or {}) do
        table.insert(list, (r.group_name or '?') .. (r.expires_at and (' (até '..tostring(r.expires_at)..')') or ''))
    end
    TriggerClientEvent('chat:addMessage', source, { args = { '^6VIP', ('%s: %s'):format(ident.citizenid, (#list>0 and table.concat(list, ', ') or 'nenhum')) } })
end, 'admin')

-- GRUPOS NORMAIS (/addgroup, /removegroup, /listgroup)
QBCore.Commands.Add('addgroup', 'Adicionar grupo normal a um jogador', {{name='alvo', help='id/citizenid/license'}, {name='grupo', help='nome do grupo'}}, true, function(source, args)
    if not PermsCore.IsManager(source) then return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error') end
    local target, name = args[1], args[2] and tostring(args[2]):lower() or nil
    local ok, err = PermsCore.Add(source, target, 'group', name, nil)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('Grupo %s adicionado.'):format(name or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, err or 'Falha ao adicionar grupo', 'error')
    end
end, 'admin')

QBCore.Commands.Add('removegroup', 'Remover grupo normal de um jogador', {{name='alvo', help='id/citizenid/license'}, {name='grupo', help='nome do grupo'}}, true, function(source, args)
    if not PermsCore.IsManager(source) then return TriggerClientEvent('QBCore:Notify', source, 'Sem permissão', 'error') end
    local target, name = args[1], args[2] and tostring(args[2]):lower() or nil
    local ok = PermsCore.Remove(source, target, 'group', name)
    if ok then
        TriggerClientEvent('QBCore:Notify', source, ('Grupo %s removido.'):format(name or '?'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Nada removido (verifique o nome)', 'error')
    end
end, 'admin')

QBCore.Commands.Add('listgroup', 'Listar grupos normais do jogador', {{name='alvo', help='id/citizenid/license'}}, true, function(source, args)
    local ident = PermsCore.GetIdentity(args[1])
    if not ident.citizenid then return TriggerClientEvent('QBCore:Notify', source, 'Alvo não encontrado', 'error') end
    local rows = MySQL.query.await('SELECT group_name FROM '..Config.Table..' WHERE citizenid = ? AND type = "group"', { ident.citizenid })
    local names = {}
    for _, r in ipairs(rows or {}) do table.insert(names, r.group_name) end
    TriggerClientEvent('chat:addMessage', source, { args = { '^5GRUPOS', ('%s: %s'):format(ident.citizenid, (#names>0 and table.concat(names, ', ') or 'nenhum')) } })
end, 'admin')
