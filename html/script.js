// =================================================================
// SCRIPT.JS COMPLETO E FINAL
// Gerencia todos os painéis da NUI (Jogador e Admin)
// =================================================================

// Função auxiliar para fechar todos os painéis e a NUI
function closeAllPanels() {
    document.body.style.display = 'none';
    document.querySelectorAll('.card').forEach(card => card.style.display = 'none');
    fetch(`https://${GetParentResourceName()}/forceClose`, { method: "POST" });
}

// Listener principal de mensagens vindas do client.lua
window.addEventListener('message', function(event) {
    const data = event.data;

    // Garante que todos os painéis estejam ocultos antes de abrir um novo
    document.querySelectorAll('.card').forEach(card => card.style.display = 'none');
    document.body.style.display = 'flex'; // Torna a NUI visível

    switch (data.action) {
        // --- PAINÉIS DO JOGADOR ---
        case 'open': // Painel de pagamento de taxa
            document.querySelector("#tax-value").textContent = "$" + data.tax;
            document.getElementById('payment-container').style.display = 'block';
            break;
        case 'paymentSuccess':
            document.getElementById('success-message').textContent = `Sua taxa de $${data.tax} foi paga com sucesso.`;
            document.getElementById('success-container').style.display = 'block';
            break;
        case 'openDebtCollectPrompt': // Painel de cobrança de dívida para o devedor
            document.getElementById('debt-prompt-amount').textContent = '$' + data.amount;
            document.getElementById('debt-collect-prompt-container').style.display = 'block';
            break;

        // --- PAINÉIS ADMINISTRATIVOS ---
        case 'openVaultPanel':
            document.getElementById('vault-balance-value').textContent = '$' + data.balance;
            document.getElementById('vault-view-container').style.display = 'block';
            break;
        case 'openAddVaultPanel':
            document.getElementById('add-amount-input').value = '';
            document.getElementById('vault-add-container').style.display = 'block';
            break;
        case 'openWithdrawVaultPanel':
            document.getElementById('withdraw-amount-input').value = '';
            document.getElementById('vault-withdraw-container').style.display = 'block';
            break;
        case 'showDebtList':
            const tableBody = document.querySelector("#debt-table tbody");
            tableBody.innerHTML = '';
            if (data.debts && data.debts.length > 0) {
                data.debts.forEach(debt => {
                    let row = tableBody.insertRow();
                    row.insertCell(0).textContent = debt.playerName;
                    row.insertCell(1).textContent = debt.citizenid;
                    row.insertCell(2).textContent = '$' + debt.amount;
                    row.insertCell(3).textContent = debt.reason;
                });
            }
            document.getElementById('debt-list-container').style.display = 'block';
            break;
        case 'showDebtDetails':
             document.getElementById('debt-detail-name').textContent = data.debt.playerName;
             document.getElementById('debt-detail-citizenid').textContent = data.debt.citizenid;
             document.getElementById('debt-detail-amount').textContent = '$' + data.debt.amount;
             document.getElementById('debt-detail-reason').textContent = data.debt.reason;
             document.getElementById('debt-detail-container').style.display = 'block';
            break;
    }
});

// =================================================================
// LISTENERS DE BOTÕES (EVENTOS DE CLIQUE)
// =================================================================

// --- BOTÕES GERAIS E DO JOGADOR ---

// Adiciona listener para todos os botões de fechar/cancelar que tiverem o atributo 'data-close-button'
document.querySelectorAll('[data-close-button]').forEach(button => {
    button.addEventListener('click', closeAllPanels);
});

// Botão para pagar taxa (painel do jogador)
document.getElementById("pay").addEventListener("click", function () {
    fetch(`https://${GetParentResourceName()}/payTax`, { method: "POST" });
});

// Botão para recusar taxa (painel do jogador)
document.getElementById("refuse").addEventListener("click", function () {
    fetch(`https://${GetParentResourceName()}/refuseTax`, { method: "POST" });
    closeAllPanels();
});

// --- BOTÕES DO PAINEL DE COBRANÇA (DEVEDOR) ---

// Botão para PAGAR a dívida exigida
document.getElementById('debt-prompt-pay').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/debtResponse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ paid: true })
    });
    closeAllPanels();
});

// Botão para RECUSAR a dívida exigida
document.getElementById('debt-prompt-refuse').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/debtResponse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ paid: false })
    });
    closeAllPanels();
});

// --- BOTÕES DOS PAINÉIS ADMINISTRATIVOS ---

// Botão para confirmar a adição de dinheiro ao cofre
document.getElementById('add-vault-confirm').addEventListener('click', () => {
    const amount = document.getElementById('add-amount-input').value;
    fetch(`https://${GetParentResourceName()}/admin_addCofre`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ amount: amount })
    });
    closeAllPanels();
});

// Botão para confirmar o saque de dinheiro do cofre
document.getElementById('withdraw-vault-confirm').addEventListener('click', () => {
    const amount = document.getElementById('withdraw-amount-input').value;
    fetch(`httpshttps://${GetParentResourceName()}/admin_sacarCofre`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ amount: amount })
    });
    closeAllPanels();
});