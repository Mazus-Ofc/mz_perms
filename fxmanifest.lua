fx_version 'cerulean'
game 'gta5'

name 'mz_perms'
author 'Mazus & ChatGPT'
description 'Sistema de grupos/flags (Staff, VIPs e Grupos normais) com comandos separados e persistência via oxmysql.'
version '1.0.0'

lua54 'yes'

-- Dependências
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/perms.lua',
    'server/staff.lua',
    'server/vips.lua'
}

-- Exports para outros scripts
server_export 'HasGroup'
server_export 'HasVip'
server_export 'HasStaff'
server_export 'GetPlayerGroups'
