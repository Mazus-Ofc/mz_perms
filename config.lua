--- CONFIG ---------------------------------------------------------------
Config = {}

-- Nome da tabela no MySQL
Config.Table = 'player_groups'
Config.PlayersTable = 'players'

-- Quais grupos do QBCore podem gerenciar permissões.
Config.ManagerGroups = { 'admin', 'god' }

-- Tempo padrão de VIP quando não informado (em dias)
Config.DefaultVipDays = 30

-- Limpeza automática de permissões temporárias expiradas
Config.CleanupExpiredEveryMinutes = 5

-- Listas de nomes permitidos (vazio = aceitar qualquer)
Config.AllowedVipNames = { 'vip', 'vipplus', 'vipgold', 'vipplatinum' }

Config.AllowedStaffNames = {
    'helper',
    'suporte',
    'moderador',
    'administrador',
    'coord_hospital',
    'coord_policia',
    'coord_faccoes',
    'coord_staff',
    'gerente_administrativo',
    'diretor',
    'proprietario'
}
Config.AllowedGroupNames = {}

-- ----------------------------------------------------------------------
-- Staff: herança por árvore.
--
-- power   = peso do cargo para comparação de autoridade.
-- parents = cargos que esse cargo herda.
--
-- Exemplo prático:
-- - coord_hospital herda administrador, mas NÃO herda coord_policia.
-- - gerente_administrativo herda todos os coordenadores.
-- ----------------------------------------------------------------------
Config.EnableStaffHierarchy = true
Config.StaffRoleRules = {
    helper = {
        power = 10,
        parents = {}
    },
    suporte = {
        power = 20,
        parents = { 'helper' }
    },
    moderador = {
        power = 30,
        parents = { 'suporte' }
    },
    administrador = {
        power = 40,
        parents = { 'moderador' }
    },
    coord_hospital = {
        power = 50,
        parents = { 'administrador' }
    },
    coord_policia = {
        power = 50,
        parents = { 'administrador' }
    },
    coord_faccoes = {
        power = 50,
        parents = { 'administrador' }
    },
    coord_staff = {
        power = 60,
        parents = { 'administrador' }
    },
    gerente_administrativo = {
        power = 70,
        parents = { 'coord_staff', 'coord_hospital', 'coord_policia', 'coord_faccoes' }
    },
    diretor = {
        power = 80,
        parents = { 'gerente_administrativo' }
    },
    proprietario = {
        power = 90,
        parents = { 'diretor' }
    }
}

-- Compatibilidade: ainda expomos um mapa numérico para interfaces antigas.
Config.StaffHierarchy = {
    helper = 10,
    suporte = 20,
    moderador = 30,
    administrador = 40,
    coord_hospital = 50,
    coord_policia = 50,
    coord_faccoes = 50,
    coord_staff = 60,
    gerente_administrativo = 70,
    diretor = 80,
    proprietario = 90
}

-- VIPs com hierarquia (opcional). Ex.: vipplatinum (4) >= vipgold (3) >= vipplus (2) >= vip (1)
Config.EnableVipHierarchy = true
Config.VipHierarchy = {
    vip = 1,
    vipplus = 2,
    vipgold = 3,
    vipplatinum = 4
}

-- Grupos normais por padrão NÃO têm hierarquia. Ative se quiser.
-- Ex.: { trainee = 1, member = 2, manager = 3 }
Config.EnableGroupHierarchy = false
Config.GroupHierarchy = {}
-------------------------------------------------------------------------
