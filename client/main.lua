local amountToPay, taxAmount, reasonData
local citizenid = nil

local function closeNUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

CreateThread(function()
    while not citizenid do
        local player = exports['qbx_core']:GetPlayerData()
        if player and player.citizenid then
            citizenid = player.citizenid
        end
        Wait(500)
    end
end)

RegisterNetEvent('space_economy:openTaxPanel', function(amount, tax, reason)
    amountToPay = amount
    taxAmount = tax
    reasonData = reason
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        tax = tax,
        reason = reason or 'Sem motivo informado'
    })
end)

RegisterNetEvent('space_economy:paymentResult', function(success, paidAmount)
    if success then
        SendNUIMessage({
            action = 'paymentSuccess',
            tax = paidAmount
        })
    else
        closeNUI()
        exports.ox_lib:notify({
            title = 'Falha no Pagamento',
            description = 'Você não tem saldo suficiente para pagar a taxa.',
            type = 'error'
        })
    end
end)

RegisterNUICallback('payTax', function(data, cb)
    if not citizenid then cb('erro'); return end
    TriggerServerEvent('space_economy:payOnlyTax', citizenid, taxAmount, reasonData)
    cb('ok')
end)

RegisterNUICallback('refuseTax', function(data, cb)
    if not citizenid then cb('erro'); return end
    local totalDue = amountToPay + taxAmount
    TriggerServerEvent('space_economy:taxPaymentResponse', false, citizenid, totalDue, reasonData)
    closeNUI() 
    cb('ok')
end)

RegisterNetEvent('space_economy:openVaultPanel', function(balance)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openVaultPanel', balance = balance })
end)

RegisterNetEvent('space_economy:openAddVaultPanel', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAddVaultPanel' })
end)

RegisterNetEvent('space_economy:openWithdrawVaultPanel', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openWithdrawVaultPanel' })
end)

RegisterNetEvent('space_economy:openDebtListPanel', function(debts)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showDebtList', debts = debts })
end)

RegisterNetEvent('space_economy:openDebtDetails', function(debtInfo)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showDebtDetails', debt = debtInfo })
end)

RegisterNetEvent('space_economy:promptDebtPayment', function(debtAmount)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openDebtCollectPrompt',
        amount = debtAmount
    })
end)

RegisterNUICallback('debtResponse', function(data, cb)
    TriggerServerEvent('space_economy:server_debtPaymentResponse', data.paid)
    cb('ok')
end)

RegisterNetEvent('space_economy:issueWarrantAlert', function(title, description)
    local player = exports['qbx_core']:GetPlayerData()
    if player.job.name == Config.WarrantAlert.police_job_name then
        exports.ox_lib:notify({
            title = title,
            description = description,
            type = 'error',
            duration = 15000
        })
    end
end)

RegisterNUICallback('forceClose', function(data, cb)
    closeNUI()
    cb('ok')
end)

RegisterNUICallback('admin_addCofre', function(data, cb)
    TriggerServerEvent('space_economy:server_addCofre', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('admin_sacarCofre', function(data, cb)
    TriggerServerEvent('space_economy:server_sacarCofre', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('admin_cobrarDivida', function(data, cb)
    TriggerServerEvent('space_economy:server_cobrarDivida', data.citizenid)
    cb('ok')
end)