--- CONFIG ---------------------------------------------------------------
Config = {}

-- Nome da tabela no MySQL
Config.Table = 'player_groups'

-- Quais grupos do QBCore podem gerenciar permissões.
Config.ManagerGroups = { 'admin', 'god' }

-- Tempo padrão de VIP quando não informado (em dias)
Config.DefaultVipDays = 30

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
-- Herança (hierarquia)
-- Se habilitar, um nível MAIS ALTO herda as permissões dos níveis abaixo.
-- Ex.: diretor (5) => passa em checks de admin (3), mod (2) etc.
-- ----------------------------------------------------------------------
Config.EnableStaffHierarchy = true
Config.StaffHierarchy = {
    helper = 1,
    suporte = 2,
    moderador = 3,
    administrador = 4,
    coord_hospital = 5,
    coord_policia = 5,
    coord_faccoes = 5,
    coord_staff = 6,
    gerente_administrativo = 7,
    diretor = 8,
    proprietario = 9
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
