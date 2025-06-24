local vaultBalance = 100
local inflation = Config.InitialInflation
local oxmysql = exports.oxmysql
local debts = {}

local function UpdateDatabase()
    oxmysql:execute('UPDATE space_economy SET vault = ?, inflation = ? WHERE id = 1', {
        vaultBalance, inflation
    })
end

local function SetVaultBalance(amount)
    vaultBalance = vaultBalance + amount
    UpdateDatabase()
end

local function SaveDebt(identifier, amount, reason)
    debts[identifier] = (debts[identifier] or 0) + amount
    oxmysql:execute([=[
        INSERT INTO space_economy_debts (citizenid, amount, reason) 
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount), reason = VALUES(reason)
    ]=], { identifier, amount, reason })
end

function CalculateTax(identifier, amount, reason)
    local tax = Config.CalculateProgressiveTax(amount)
    local player = exports['qbx_core']:GetPlayerByCitizenId(identifier)
    if player then
        TriggerClientEvent('space_economy:openTaxPanel', player.PlayerData.source, amount, tax, reason)
    else
        SaveDebt(identifier, tax, reason or "Offline")
    end
    return amount + tax, tax
end
exports('CalculateTax', CalculateTax)

RegisterNetEvent('space_economy:payOnlyTax', function(identifier, taxAmount, reason)
    local player = exports['qbx_core']:GetPlayerByCitizenId(identifier)
    if not player then return end
    local source = player.PlayerData.source
    if player.Functions.RemoveMoney('bank', taxAmount, reason or 'Pagamento taxa') then
        SetVaultBalance(taxAmount)
        TriggerClientEvent('space_economy:paymentResult', source, true, taxAmount)
    else
        SaveDebt(identifier, taxAmount, reason or 'Falha no pagamento da taxa')
        TriggerClientEvent('space_economy:paymentResult', source, false, taxAmount)
    end
end)

RegisterNetEvent('space_economy:taxPaymentResponse', function(paid, identifier, taxAmount, reason)
    local player = exports['qbx_core']:GetPlayerByCitizenId(identifier)
    if not player then return end
    local tax = taxAmount
    if paid then
        local paidSuccessfully = false
        local methods = { 'cash', 'bank', 'crypto' }
        for _, method in ipairs(methods) do
            if player.Functions.GetMoney(method) >= tax then
                if player.Functions.RemoveMoney(method, tax, 'Pagamento taxa compra') then
                    paidSuccessfully = true
                    break
                end
            end
        end
        if paidSuccessfully then
            SetVaultBalance(tax)
            debts[identifier] = nil
            oxmysql:execute('DELETE FROM space_economy_debts WHERE citizenid = ?', { identifier })
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, { title = 'Taxa Paga', description = ('Você pagou $%s de taxa.'):format(tax), type = 'success' })
        else
            SaveDebt(identifier, tax, reason or 'Sem saldo para taxa')
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, { title = 'Taxa não paga', description = 'Saldo insuficiente. Dívida registrada.', type = 'error' })
        end
    else
        SaveDebt(identifier, tax, reason or 'Recusa em pagar taxa')
        TriggerClientEvent('ox_lib:notify', player.PlayerData.source, { title = 'Dívida registrada', description = 'Você recusou pagar a taxa. Dívida registrada.', type = 'warning' })
    end
    TriggerClientEvent('space_economy:closeTaxMenu', player.PlayerData.source)
end)

local function notify(source, title, description, type)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = description,
        type = type or 'inform'
    })
end

local function hasPermission(player)
    if not player or not player.PlayerData then return false end
    local jobName = player.PlayerData.job and player.PlayerData.job.name and string.lower(player.PlayerData.job.name)
    local jobGrade = player.PlayerData.job and player.PlayerData.job.grade and player.PlayerData.job.grade.level
    local aceGroup = player.PlayerData.group and string.lower(player.PlayerData.group)
    if aceGroup and Config.Permissions[aceGroup] then
        return true
    end
    if jobName and jobGrade ~= nil and Config.Permissions[jobName] then
        local requiredGrade = Config.Permissions[jobName].min_grade
        if jobGrade >= requiredGrade then
            return true
        end
    end
    return false
end

function issueWarrant(player, citizenid, debtAmount)
    local playerName = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    local playerPed = GetPlayerPed(player.PlayerData.source)
    local coords = GetEntityCoords(playerPed)
    if exports['ps-dispatch'] then
        exports['ps-dispatch']:CreateDispatchAlert({
            title = 'Mandado de Captura por Dívida',
            message = ('Indivíduo procurado por evasão de dívida no valor de $%s.'):format(debtAmount),
            details = { ['Nome do Procurado'] = playerName, ['ID do Cidadão'] = citizenid },
            job = { Config.WarrantAlert.police_job_name },
            coords = coords,
            dispatchCode = '10-99',
            icon = 'fas fa-gavel',
            color = '#ff3c3c'
        })
    end
    if exports['ps-mdt'] then
        exports['ps-mdt']:CreateBolo({
            title = 'Mandado - Dívida Governamental',
            plate = 'N/A',
            owner = playerName,
            description = ('Indivíduo procurado por se recusar a pagar uma dívida governamental obrigatória no valor de $%s.'):format(debtAmount),
            reason = 'Dívida Governamental Não Paga',
            officer = 'Sistema Central de Dívidas'
        })
    end
    local description = (Config.WarrantAlert.description):format(playerName, citizenid, debtAmount)
    TriggerClientEvent('space_economy:issueWarrantAlert', -1, Config.WarrantAlert.title, description)
end

RegisterCommand('vercofre', function(source)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not hasPermission(Player) then return notify(source, 'Permissão Negada', 'Você não tem autorização.', 'error') end
    TriggerClientEvent('space_economy:openVaultPanel', source, vaultBalance)
end, false)

RegisterCommand('addcofre', function(source)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not hasPermission(Player) then return notify(source, 'Permissão Negada', 'Você não tem autorização.', 'error') end
    TriggerClientEvent('space_economy:openAddVaultPanel', source)
end, false)

RegisterCommand('sacarcofre', function(source)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not hasPermission(Player) then return notify(source, 'Permissão Negada', 'Você não tem autorização.', 'error') end
    TriggerClientEvent('space_economy:openWithdrawVaultPanel', source)
end, false)

RegisterCommand('verdividas', function(source, args)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not hasPermission(Player) then return notify(source, 'Permissão Negada', 'Você não tem autorização.', 'error') end
    local targetCitizenId = args[1]
    local query
    local params
    if targetCitizenId then
        query = 'SELECT d.citizenid, d.amount, d.reason, p.charinfo FROM space_economy_debts d LEFT JOIN players p ON d.citizenid = p.citizenid WHERE d.citizenid = ? ORDER BY d.amount DESC'
        params = { targetCitizenId }
    else
        query = 'SELECT d.citizenid, d.amount, d.reason, p.charinfo FROM space_economy_debts d LEFT JOIN players p ON d.citizenid = p.citizenid ORDER BY d.amount DESC LIMIT 20'
        params = {}
    end
    exports.oxmysql:fetch(query, params, function(result)
        if not result or #result == 0 then
            local message = targetCitizenId and ('Nenhuma dívida para o ID: %s'):format(targetCitizenId) or 'Nenhuma dívida registrada.'
            return notify(source, 'Dívidas', message, 'inform')
        end
        for i, debt in ipairs(result) do
            local playerName = "Não Encontrado"
            if debt.charinfo then
                local charInfoTable = json.decode(debt.charinfo)
                if charInfoTable and charInfoTable.firstname and charInfoTable.lastname then
                    playerName = charInfoTable.firstname .. " " .. charInfoTable.lastname
                end
            end
            result[i].playerName = playerName
            result[i].charinfo = nil
        end
        TriggerClientEvent('space_economy:openDebtListPanel', source, result)
    end)
end, false)

RegisterCommand('verdivida', function(source, args)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not hasPermission(Player) then return notify(source, 'Permissão Negada', 'Você não tem autorização.', 'error') end
    local targetCitizenId = args[1]
    if not targetCitizenId then return notify(source, 'Argumento Inválido', 'Uso: /verdivida [citizenid]', 'error') end
    exports.oxmysql:fetch('SELECT d.citizenid, d.amount, d.reason, p.charinfo FROM space_economy_debts d LEFT JOIN players p ON d.citizenid = p.citizenid WHERE d.citizenid = ?', { targetCitizenId }, function(result)
        if not result or #result == 0 then
            return notify(source, 'Consulta', ('O cidadão %s não possui dívidas.'):format(targetCitizenId), 'inform')
        end
        local debtInfo = result[1]
        local playerName = "Não Encontrado"
        if debtInfo.charinfo then
            local charInfoTable = json.decode(debtInfo.charinfo)
            if charInfoTable and charInfoTable.firstname and charInfoTable.lastname then
                playerName = charInfoTable.firstname .. " " .. charInfoTable.lastname
            end
        end
        debtInfo.playerName = playerName
        debtInfo.charinfo = nil
        TriggerClientEvent('space_economy:openDebtDetails', source, debtInfo)
    end)
end, false)

RegisterCommand('cobrardivida', function(source, args)
    local Player = exports['qbx_core']:GetPlayer(source)
    if not hasPermission(Player) then return notify(source, 'Permissão Negada', 'Você não tem autorização.', 'error') end
    local targetCitizenId = args[1]
    if not targetCitizenId then return notify(source, 'Argumento Inválido', 'Uso: /cobrardivida [citizenid]', 'error') end
    local targetPlayer = exports['qbx_core']:GetPlayerByCitizenId(targetCitizenId)
    if not targetPlayer then
        return notify(source, 'Cobrança Falhou', 'O jogador com este Citizen ID não está online.', 'error')
    end
    exports.oxmysql:fetch('SELECT amount FROM space_economy_debts WHERE citizenid = ?', { targetCitizenId }, function(result)
        if not result or #result == 0 then
            return notify(source, 'Cobrança Falhou', 'Este jogador não possui dívidas registradas.', 'error')
        end
        local debtAmount = result[1].amount
        TriggerClientEvent('space_economy:promptDebtPayment', targetPlayer.PlayerData.source, debtAmount)
        notify(source, 'Cobrança Enviada', ('Aviso de cobrança de $%s enviado. Aguardando resposta.'):format(debtAmount), 'inform')
    end)
end, false)

RegisterNetEvent('space_economy:server_addCofre', function(amount)
    local src = source
    local Player = exports['qbx_core']:GetPlayer(src)
    if not hasPermission(Player) then return end
    if not amount or amount <= 0 then return notify(src, 'Operação Falhou', 'Valor inválido.', 'error') end
    SetVaultBalance(amount)
    notify(src, 'Cofre Atualizado', ('Você adicionou $%s ao cofre. Novo saldo: $%s'):format(amount, vaultBalance), 'success')
end)

RegisterNetEvent('space_economy:server_sacarCofre', function(amount)
    local src = source
    local Player = exports['qbx_core']:GetPlayer(src)
    if not hasPermission(Player) then return end
    if not amount or amount <= 0 then return notify(src, 'Operação Falhou', 'Valor inválido.', 'error') end
    if amount > vaultBalance then return notify(src, 'Operação Falhou', 'Saldo insuficiente no cofre.', 'error') end
    vaultBalance = vaultBalance - amount
    Player.Functions.AddMoney('cash', amount, 'sacar-cofre-gov')
    UpdateDatabase()
    notify(src, 'Saque Realizado', ('Você sacou $%s do cofre. Novo saldo: $%s'):format(amount, vaultBalance), 'success')
end)

RegisterNetEvent('space_economy:server_debtPaymentResponse', function(didPay)
    local source = source
    local Player = exports['qbx_core']:GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    exports.oxmysql:fetch('SELECT amount FROM space_economy_debts WHERE citizenid = ?', { citizenid }, function(result)
        if not result or #result == 0 then return end
        local debtAmount = result[1].amount
        if didPay then
            if Player.Functions.RemoveMoney('bank', debtAmount, 'pagamento_divida_gov') then
                exports.oxmysql:execute('DELETE FROM space_economy_debts WHERE citizenid = ?', { citizenid })
                SetVaultBalance(debtAmount)
                notify(source, 'Dívida Paga', 'Sua dívida com o governo foi quitada.', 'success')
            else
                notify(source, 'Pagamento Falhou', 'Você não tem saldo. Um mandado de prisão foi emitido.', 'error')
                issueWarrant(Player, citizenid, debtAmount)
            end
        else
            notify(source, 'Dívida Recusada', 'Você se recusou a pagar. Um mandado de prisão foi emitido.', 'error')
            issueWarrant(Player, citizenid, debtAmount)
        end
    end)
end)

CreateThread(function()
    local result = oxmysql:executeSync('SELECT * FROM space_economy WHERE id = 1')
    if result and result[1] then
        vaultBalance = result[1].vault
        inflation = result[1].inflation
    else
        oxmysql:execute('INSERT INTO space_economy (id, vault, inflation) VALUES (1, 0, ?)', { Config.InitialInflation })
    end
end)