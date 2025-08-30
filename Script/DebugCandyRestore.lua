-- DebugCandyRestore.lua - Test simple pour debug des tailles
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveDataManager = require(ReplicatedStorage:WaitForChild("SaveDataManager"))

-- Commande debug pour les admins
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if player.Name == "Maxim" and message:lower() == "/debugsave" then
            print("🔍 [DEBUG] Test sauvegarde/restoration pour", player.Name)
            
            -- Sauvegarder
            local success = SaveDataManager.savePlayerData(player)
            print("📤 Sauvegarde:", success and "✅ RÉUSSIE" or "❌ ÉCHOUÉE")
            
            if success then
                task.wait(1)
                
                -- Charger et restaurer
                local data = SaveDataManager.loadPlayerData(player)
                if data then
                    SaveDataManager.restoreInventory(player, data)
                end
            end
        end
    end)
end)

print("🔍 [DEBUG] Script de debug prêt - Commande: /debugsave")