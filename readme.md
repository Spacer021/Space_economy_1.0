Space Economy - Sistema Econômico Completo e Dinâmico
Space Economy é um script avançado e interativo para servidores FiveM que utilizam o framework QBX, criando um ecossistema econômico realista e cheio de funcionalidades para o roleplay. O script introduz um sistema de taxação progressiva, um cofre governamental persistente, uma mecânica de inflação dinâmica, logs de auditoria detalhados e um sistema complexo de lavagem de dinheiro atrelado a empregos.

✨ Funcionalidades
Sistema de Imposto Progressivo: Taxas calculadas com base em faixas de valor, tornando a tributação mais justa.

Tesouro Centralizado: Impostos e taxas são depositados em um cofre governamental persistente no banco de dados.

Sistema de Dívidas: Jogadores que recusam pagar taxas acumulam dívidas ativas.

Inflação Dinâmica: A economia do servidor sofre flutuações periódicas e reage a injeções de dinheiro por administradores, afetando o poder de compra.

Painel de Admin via Blip: Um painel físico no mapa permite que administradores autorizados gerenciem a economia sem o uso de comandos. Os comandos /addcofre e /sacarcofre foram removidos para incentivar o uso do painel.

Lavagem de Dinheiro por Emprego:

Sistema modular para criar múltiplos "negócios de fachada".

Apenas jogadores com o emprego e cargo corretos podem lavar dinheiro.

O dono do negócio lava seu próprio dinheiro sujo (black_money por padrão).

A taxa de lavagem é dinâmica, definida pelo jogador no painel (com mínimo e máximo configuráveis), e gera lucro para a conta da empresa (society account).

O dinheiro limpo é depositado na conta pessoal do jogador, criando um ciclo econômico fechado.

Calculadora de Taxas (Item): Um item usável (tax_calculator) para o ox_inventory que permite a qualquer jogador calcular os impostos de uma compra antes de efetuá-la.

Logs de Auditoria Híbridos: Sistema completo de logs que registra todas as ações importantes em:

Arquivo de Texto (logs/economy_logs.txt)

Webhook do Discord (com embeds coloridos por categoria)

Banco de Dados (com limpeza automática de registros antigos)

Monitoramento Global de Dinheiro: Escuta todas as transações do servidor para registrar adições de dinheiro por menus de admin e outras fontes não rastreadas.

Integração com Polícia: Emissão de alertas no ps-dispatch e criação de mandados no ps-mdt para devedores.

Permissões Granulares: Suporte a permissões por ACE (group.admin) e por cargo/grade do QBX.

🔗 Dependências
qbx_core - Framework base.

ox_lib - Biblioteca de utilidades (notificações, interface, etc.).

oxmysql - Comunicação com o banco de dados.

ox_inventory - Necessário para o item de dinheiro sujo e a calculadora.

ps-banking - Obrigatório, usado para gerenciar as contas de empresa (society accounts) no sistema de lavagem.

ps-dispatch (Opcional): Para alertas policiais em tempo real.

ps-mdt (Opcional): Para registro permanente de mandados.

🛠️ Instalação
1. Instalação Básica
Baixe o script e coloque a pasta space_economy dentro da sua pasta resources.

No seu server.cfg, adicione a linha ensure space_economy. É crucial que esta linha venha depois de todas as dependências listadas acima.

2. Banco de Dados (SQL)
Execute os seguintes comandos SQL no seu banco de dados para criar as tabelas necessárias:

-- Tabela principal de economia
CREATE TABLE IF NOT EXISTS `space_economy` (
  `id` INT NOT NULL PRIMARY KEY,
  `vault` BIGINT NOT NULL DEFAULT 0,
  `inflation` FLOAT NOT NULL DEFAULT 1.0
);
INSERT INTO `space_economy` (`id`, `vault`, `inflation`) VALUES (1, 0, 1.0)
  ON DUPLICATE KEY UPDATE id = id;

-- Tabela para dívidas dos jogadores
CREATE TABLE IF NOT EXISTS `space_economy_debts` (
  `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
  `amount` BIGINT NOT NULL,
  `reason` VARCHAR(255) DEFAULT NULL
);

-- Tabela para os logs de auditoria
CREATE TABLE IF NOT EXISTS `space_economy_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  `category` VARCHAR(50) NOT NULL,
  `message` TEXT NOT NULL,
  PRIMARY KEY (`id`)
);

🔌 Integrações com Outros Scripts
Para o space_economy funcionar em seu potencial máximo, algumas integrações e configurações em outros scripts são obrigatórias.

1. qbx_core (Modificação Obrigatória)
Para que o sistema de impostos funcione, é essencial interceptar todas as transações de dinheiro.

Abra o arquivo: [qbx]/qbx_core/server/player.lua

Localize a função RemoveMoney.

Substitua a função inteira pela versão abaixo. A única alteração é a adição do export que chama a calculadora de taxas.

---@param identifier Source | string
---@param moneyType MoneyType
---@param amount number
---@param reason? string
---@return boolean success if money was removed
function RemoveMoney(identifier, moneyType, amount, reason)
    local player = type(identifier) == 'string' and (GetPlayerByCitizenId(identifier) or GetOfflinePlayer(identifier)) or GetPlayer(identifier)

    if not player then return false end

    reason = reason or 'unknown'
    amount = qbx.math.round(tonumber(amount) --[[@as number]])

    if amount < 0 or not player.PlayerData.money[moneyType] then return false end

    if not triggerEventHooks('removeMoney', {
        source = player.PlayerData.source,
        moneyType = moneyType,
        amount = amount
    }) then return false end

    for _, mType in pairs(config.money.dontAllowMinus) do
        if mType == moneyType then
            if (player.PlayerData.money[moneyType] - amount) < 0 then
                return false
            end
        end
    end

    -- Desconta o valor da compra imediatamente
    player.PlayerData.money[moneyType] = player.PlayerData.money[moneyType] - amount

    -- // INÍCIO DA MODIFICAÇÃO - NÃO REMOVA ESTE BLOCO // --
    -- Inicia cálculo da taxa econômica
    if amount > 0 and not player.Offline and (moneyType == 'cash' or moneyType == 'bank' or moneyType == 'crypto') then
        exports['space_economy']:CalculateTax(player.PlayerData.citizenid, amount, reason)
    end
    -- // FIM DA MODIFICAÇÃO // --

    if not player.Offline then
        UpdatePlayerData(identifier)

        logger.log({
            source = GetInvokingResource() or cache.resource,
            webhook = config.logging.webhook['playermoney'],
            event = 'RemoveMoney',
            color = 'red',
            tags = amount > 100000 and config.logging.role or nil,
            message = ('**%s (citizenid: %s | id: %s)** $%s (%s) removed, new %s balance: $%s reason: %s'):format(
                GetPlayerName(player.PlayerData.source),
                player.PlayerData.citizenid,
                player.PlayerData.source,
                amount, moneyType, moneyType, player.PlayerData.money[moneyType], reason
            ),
        })

        emitMoneyEvents(player.PlayerData.source, player.PlayerData.money, moneyType, amount, 'remove', reason)
    end

    return true
end

2. ox_inventory (Itens)
Abra ox_inventory/data/items.lua e adicione os seguintes blocos:

['black_money'] = {
    label = 'Notas Marcadas',
    weight = 0,
    stack = true,
    close = true,
},
['tax_calculator'] = {
    label = 'Calculadora de Taxas',
    weight = 150,
    stack = false,
    close = true,
    client = {
        event = 'space_economy:client:openCalculator',
    },
},

Lembre-se de ter os ícones .png correspondentes na pasta de imagens do ox_inventory.

3. Atividades Ilegais (Venda de Drogas, Roubos)
Seus scripts de atividades ilegais devem recompensar os jogadores com o item black_money, em vez de dinheiro direto.

Exemplo: Encontre Player.Functions.AddMoney('cash', 10000) e substitua por Player.Functions.AddItem('black_money', 10000).

4. ps-mdt (Mandados de Prisão)
Abra o arquivo ps-mdt/config/charges.lua.

Encontre a seção referente ao Código Penal 5 (geralmente [5]).

Adicione a nova lei na lista. Exemplo completo da seção:

-- Substitua toda a sua seção [5] por esta:
[5] = {
    -- ... (suas outras leis de [1] a [18] aqui) ...
    [18] = {title = 'Resistência à Prisão', class = 'Misdemeanor', id = 'P.C. 5018', months = 5, fine = 300, color = 'orange', description = 'O ato de não permitir que os agentes da paz o prendam voluntariamente'},
    
    -- ADICIONE ESTA NOVA LEI
    [19] = {title = 'Evasão de Dívida Governamental', class = 'Felony', id = 'P.C. 5019', months = 30, fine = 0, color = 'orange', description = 'Recusa em pagar dívidas ou impostos obrigatórios ao estado após notificação formal.'},
},

No config.lua do ps-mdt, confirme que a opção Config.UsingDefaultQBApartments está definida como false se você usar apartamentos customizados.

5. ps-dispatch (Alertas)
Abra o arquivo de configuração do seu ps-dispatch (geralmente config.lua) e adicione o seguinte código à sua tabela de blips/alertas:

-- Adicionar dentro da sua tabela de alertas/blips
['GOV_DEBT_WARRANT'] = {
    radius = 0,      -- Alterado para 0 para marcar o local exato do indivíduo
    sprite = 161,    -- Ícone de uma pessoa/suspeito
    color = 1,       -- Vermelho
    scale = 1.5,
    length = 2,
    sound = 'Lose_1st',
    sound2 = 'GTAO_FM_Events_Soundset',
    offset = false,
    flash = false
}

⚙️ Configuração Principal (config.lua)
O arquivo config.lua é o coração do script. Todas as funcionalidades são controladas por ele.

Config.TaxBrackets: Defina as faixas e porcentagens para o imposto progressivo.

Config.Permissions: Configure quais grupos (ACE) e cargos/grades (jobs) têm acesso às funcionalidades de admin.

Config.Inflation: Ative/desative a inflação, defina o intervalo de atualização e o impacto da "impressão de dinheiro" por admins.

Config.Logging: Controle granular sobre os logs. Ative/desative o log para arquivo, Discord e banco de dados. Configure sua WebhookURL e adicione motivos de transação a serem ignorados.

Config.LaunderingFronts: Crie quantos negócios de fachada quiser, definindo o job_name, min_grade para operar, a localização, e os limites de taxa (min_fee_percent, max_fee_percent) e o limite diário de lavagem (max_daily_wash).

Config.DirtyMoneyItem: Defina o nome exato do item de dinheiro sujo que você usa no seu servidor.

🚀 Uso no Jogo
Painel de Admin: A gestão do cofre e de dívidas é feita exclusivamente pelo painel físico no mapa, acessível apenas por jogadores com a permissão correta.

Lavagem de Dinheiro: Jogadores com o cargo e grade corretos podem ir até o blip do seu negócio, interagir com [E], e abrir o painel de lavagem para processar seu próprio black_money.

Calculadora de Taxas: Qualquer jogador que possua o item tax_calculator pode usá-lo em seu inventário para abrir um painel e calcular os impostos de uma futura compra.
