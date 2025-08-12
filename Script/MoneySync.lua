-- MoneySync.lua
-- Script serveur pour synchroniser l'argent en temps réel
-- À placer dans ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Créer RemoteFunction pour obtenir l'argent en temps réel
local getMoneyFunction = Instance.new("RemoteFunction")
getMoneyFunction.Name = "GetMoneyFunction"
getMoneyFunction.Parent = ReplicatedStorage

-- Fonction pour obtenir l'argent depuis le serveur
getMoneyFunction.OnServerInvoke = function(player)
    local pd = player:FindFirstChild("PlayerData")
    if pd and pd:FindFirstChild("Argent") then
        local money = pd.Argent.Value
        print("💰 [MONEY SYNC] Argent demandé pour", player.Name, ":", money)
        return money
    end
    warn("❌ [MONEY SYNC] PlayerData.Argent introuvable pour", player.Name)
    return 0
end

print("✅ [MONEY SYNC] RemoteFunction créée - L'argent sera lu depuis le serveur")
