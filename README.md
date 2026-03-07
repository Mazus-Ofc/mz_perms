# mz_perms (QBCore + oxmysql)

Sistema de permissões simples com três categorias:
- **Staff** (ex: helper, mod, admin, gerente, diretor)
- **VIPs** (expiram por data; ex: vip, vipplus, vipgold, vipplatinum)
- **Grupos normais** (whitelists, facções, cargos livres)

## Instalação
1) Coloque a pasta `mz_perms` dentro de `resources/[standalone]` (ou onde preferir).
2) Execute o SQL em `sql/mz_perms.sql` no seu banco (usa `oxmysql`).
3) Garanta `oxmysql` e `qb-core` iniciando antes no `server.cfg`.
4) Adicione `ensure mz_perms` no `server.cfg`.

## Configuração
- Edite `config.lua` para:
  - Grupos que podem gerenciar (`Config.ManagerGroups`)
  - Lista de VIPs permitidos, Staffs permitidos e Grupos permitidos (ou deixe vazio para aceitar qualquer nome)
  - Dias padrão para VIP (`Config.DefaultVipDays`)

## Comandos (server)
### STAFF
- `/addstaff [id/citizenid/license] [cargo]`
- `/removestaff [id/citizenid/license] [cargo]`
- `/liststaff [id/citizenid/license]`

### VIP
- `/addvip [id/citizenid/license] [vip] [dias?]` (dias opcional)
- `/removevip [id/citizenid/license] [vip]`
- `/listvip [id/citizenid/license]`

### GRUPOS NORMAIS
- `/addgroup [id/citizenid/license] [grupo]`
- `/removegroup [id/citizenid/license] [grupo]`
- `/listgroup [id/citizenid/license]`

**Observações**
- Apenas quem tiver permissão em `Config.ManagerGroups` (ex.: `admin`/`god`) consegue usar os comandos.
- Alvo pode ser o ID do jogador online, o `citizenid`, ou a `license:...`.
- Quando um jogador entra, os grupos são carregados em `metadata.perms` e também em `statebag` (`mz_perms`), separados por `staff`, `vip` e `group`.

## Exports para outros scripts (server)
- `exports['mz_perms']:HasGroup(src, 'grupo')` → bool
- `exports['mz_perms']:HasVip(src, 'vip')` → bool (se `nil`, retorna se tem **qualquer** VIP válido)
- `exports['mz_perms']:HasStaff(src, 'cargo')` → bool (se `nil`, retorna se tem **qualquer** staff)
- `exports['mz_perms']:GetPlayerGroups(src)` → tabela `metadata.perms`

### Exemplo de uso (server)
```lua
if exports['mz_perms']:HasVip(src, 'vipplus') then
    print('Jogador tem VIP Plus!')
end

if exports['mz_perms']:HasGroup(src, 'mechanic') then
    print('Jogador é do grupo mechanic (externo ao job/gang).')
end
```

## Integração com Job/Gang (opcional)
Este sistema **não** altera `job`/`gang` do QBCore. É complementar. Você pode, por exemplo,
usar `HasGroup` para liberar acesso a áreas, lojinhas, comandos, etc.

---
Feito com ❤ para a base do Mazus.
