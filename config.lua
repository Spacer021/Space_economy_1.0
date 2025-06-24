-- Inicia a tabela principal de configuração. Todas as configurações do script
-- serão armazenadas dentro desta tabela 'Config'.
Config = {}

-- Define as faixas de imposto para o sistema de taxação progressiva.
-- Cada entrada na tabela representa uma "faixa" de valor com seu respectivo imposto.
Config.TaxBrackets = {
    -- Para valores até 1000, a taxa é de 1% (0.01).
    { limit = 1000, rate = 0.01 },
    -- Para valores entre 1001 e 5000, a taxa é de 3% (0.03).
    { limit = 5000, rate = 0.03 },
    -- Para valores entre 5001 e 10000, a taxa é de 5% (0.05).
    { limit = 10000, rate = 0.05 },
    -- Para qualquer valor acima de 10000, a taxa é de 8% (0.08). 'limit = nil' representa o infinito.
    { limit = nil, rate = 0.08 },
}

-- Define as permissões para usar os comandos administrativos do script.
-- Este sistema permite especificar um cargo (job) e a grade (nível) mínima necessária.
Config.Permissions = {
    -- 'admin' é um grupo de permissão (ACE perm). Qualquer jogador neste grupo terá acesso,
    -- independentemente do seu cargo no jogo. 'min_grade = 0' significa que não há restrição de grade.
    ['admin']    = { min_grade = 0 },

    -- 'police' é um cargo do jogo. Apenas jogadores com o cargo 'police' e com grade
    -- 2 ou superior (ex: Sargento, Tenente) poderão usar os comandos.
    ['police']   = { min_grade = 2 },
    
    -- 'governor' é um cargo do jogo. Qualquer jogador com este cargo,
    -- desde a grade mais baixa (0), terá acesso.
    ['governor'] = { min_grade = 0 },
}

-- Define o valor inicial da inflação. Atualmente, esta variável é carregada,
-- mas não está sendo usada ativamente na lógica de cálculo de taxas.
Config.InitialInflation = 1.0

-- Esta é a função que calcula o valor do imposto com base em um valor de transação.
-- Ela usa as faixas definidas em 'Config.TaxBrackets' para um cálculo progressivo.
Config.CalculateProgressiveTax = function(amount)
    local tax = 0
    local remaining = amount -- 'remaining' guarda o valor que ainda precisa ser taxado.

    -- Percorre cada faixa de imposto definida na configuração.
    for _, bracket in ipairs(Config.TaxBrackets) do
        -- Verifica se a faixa atual é a última (limit = nil) ou se o valor restante
        -- se encaixa completamente dentro do limite desta faixa.
        if bracket.limit == nil or remaining <= bracket.limit then
            -- Se sim, calcula o imposto sobre o valor restante e encerra o loop.
            tax = tax + (remaining * bracket.rate)
            break
        else
            -- Se não, calcula o imposto sobre o valor total da faixa atual (ex: 3% de 5000).
            tax = tax + (bracket.limit * bracket.rate)
            -- Subtrai o valor já taxado do montante restante.
            remaining = remaining - bracket.limit
        end
    end
    -- Retorna o valor final do imposto, arredondado para o número inteiro mais próximo (para baixo).
    return math.floor(tax)
end

-- Contém as configurações para o alerta enviado à polícia quando um jogador
-- se recusa a pagar uma dívida e um mandado é emitido.
Config.WarrantAlert = {
    -- Título da notificação/alerta.
    title = "ALERTA DE MANDADO",
    -- Descrição do alerta. Os '%s' são substituídos pelo nome, ID e valor da dívida.
    description = "Mandado de prisão e apreensão de bens emitido para %s (ID: %s) por dívida governamental não paga no valor de $%s. Todas as unidades, procedam com a captura.",
    -- Nome exato do "job" da polícia (em minúsculas) para filtrar quem recebe o alerta.
    police_job_name = 'police'
}