--[[
DisconnectUnequipOnly.lua - Déséquipement uniquement lors de la déconnexion
Ce script déséquipe les outils UNIQUEMENT quand le joueur se déconnecte.
Il surveille la destruction du character pour attraper les déconnexions plus tôt.

À placer dans ServerScriptService
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Attendre que SaveDataManager soit chargé
local SaveDataManager = require(ReplicatedStorage:WaitForChild("SaveDataManager"))

print("🔌 [DISCONNECT-ONLY] Script de déséquipement à la déconnexion activé")

-- Table pour surveiller les joueurs
local playerConnections = {}
local playerEquippedTools = {}

-- Fonction simple pour déséquiper les outils d'un joueur
local function unequipPlayerTools(player)
    if not player or not player.Parent then 
        return false 
    end
    
    local character = player.Character
    if not character then 
        return false 
    end
    
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then 
        return false 
    end
    
    local unequippedCount = 0
    local toolsToMove = {}
    
    -- Collecter tous les outils équipés
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(toolsToMove, tool)
            unequippedCount = unequippedCount + 1
        end
    end
    
    if unequippedCount == 0 then
        return false
    end
    
    -- Déplacer tous les outils vers le backpack
    for _, tool in pairs(toolsToMove) do
        local baseName = tool:GetAttribute("BaseName") or tool.Name
        print("📤 [DISCONNECT-ONLY] Déséquipement:", baseName)
        tool.Parent = backpack
    end
    
    print("✅ [DISCONNECT-ONLY] Déséquipé", unequippedCount, "outil(s) pour", player.Name)
    
    -- Forcer une sauvegarde immédiate après déséquipement
    task.spawn(function()
        task.wait(0.1)
        local success = SaveDataManager.savePlayerData(player)
        if success then
            print("💾 [DISCONNECT-ONLY] Sauvegarde post-déséquipement réussie pour", player.Name)
        end
    end)
    
    return true
end

-- Surveiller chaque joueur pour détecter les déconnexions plus tôt
local function setupPlayerMonitoring(player)
    playerEquippedTools[player] = {}
    playerConnections[player] = {}
    
    local function onCharacterAdded(character)
        if not character then return end
        
        print("👤 [DISCONNECT-ONLY] Surveillance character pour", player.Name)
        
        -- Surveiller les outils ajoutés au character
        local childAddedConnection = character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                local baseName = child:GetAttribute("BaseName") or child.Name
                print("⚡ [DISCONNECT-ONLY] Outil équipé:", baseName, "par", player.Name)
                playerEquippedTools[player][child] = true
            end
        end)
        
        -- Surveiller les outils retirés du character
        local childRemovedConnection = character.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                local baseName = child:GetAttribute("BaseName") or child.Name
                print("⚡ [DISCONNECT-ONLY] Outil déséquipé:", baseName, "par", player.Name)
                playerEquippedTools[player][child] = nil
            end
        end)
        
        -- 🚨 CRITIQUE: Surveiller la destruction du character
        local ancestryConnection = character.AncestryChanged:Connect(function()
            if not character.Parent then
                print("🚨 [DISCONNECT-ONLY] Character détruit pour", player.Name, "- Déséquipement d'urgence!")
                
                -- Collecter tous les outils encore équipés
                local equippedTools = {}
                for tool, _ in pairs(playerEquippedTools[player] or {}) do
                    if tool and tool.Parent == character then
                        table.insert(equippedTools, tool)
                    end
                end
                
                if #equippedTools > 0 then
                    print("🚨 [DISCONNECT-ONLY] URGENCE: Déplacement de", #equippedTools, "outil(s) avant destruction!")
                    local backpack = player:FindFirstChildOfClass("Backpack")
                    if backpack then
                        for _, tool in pairs(equippedTools) do
                            local baseName = tool:GetAttribute("BaseName") or tool.Name
                            print("📤 [DISCONNECT-ONLY] Sauvetage:", baseName)
                            tool.Parent = backpack
                        end
                        
                        -- Sauvegarde immédiate
                        task.spawn(function()
                            task.wait(0.1)
                            SaveDataManager.savePlayerData(player)
                            print("💾 [DISCONNECT-ONLY] Sauvegarde d'urgence terminée")
                        end)
                    end
                end
            end
        end)
        
        -- Stocker les connexions pour nettoyage
        playerConnections[player].childAdded = childAddedConnection
        playerConnections[player].childRemoved = childRemovedConnection
        playerConnections[player].ancestry = ancestryConnection
    end
    
    -- Surveiller le character actuel et futurs
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    local characterAddedConnection = player.CharacterAdded:Connect(onCharacterAdded)
    playerConnections[player].characterAdded = characterAddedConnection
    
    -- Surveiller aussi la déconnexion du joueur comme fallback
    local playerAncestryConnection = player.AncestryChanged:Connect(function()
        if not player.Parent then
            print("🚨 [DISCONNECT-ONLY] Joueur déconnecté détecté:", player.Name)
            
            -- Dernière chance de sauvegarder les outils équipés
            local equippedTools = {}
            for tool, _ in pairs(playerEquippedTools[player] or {}) do
                if tool and tool.Parent then
                    table.insert(equippedTools, tool)
                end
            end
            
            if #equippedTools > 0 then
                print("🔄 [DISCONNECT-ONLY] Dernière chance: sauvegarde de", #equippedTools, "outil(s)")
                local backpack = player:FindFirstChildOfClass("Backpack")
                if backpack then
                    for _, tool in pairs(equippedTools) do
                        tool.Parent = backpack
                    end
                    SaveDataManager.savePlayerData(player)
                end
            end
        end
    end)
    
    playerConnections[player].playerAncestry = playerAncestryConnection
end

-- Nettoyer les connexions
local function cleanupPlayer(player)
    -- Déconnecter toutes les connexions
    if playerConnections[player] then
        for _, connection in pairs(playerConnections[player]) do
            if connection then
                connection:Disconnect()
            end
        end
    end
    
    -- Nettoyer les tables
    playerConnections[player] = nil
    playerEquippedTools[player] = nil
end

-- Gestion des connexions
Players.PlayerAdded:Connect(function(player)
    print("👋 [DISCONNECT-ONLY] Surveillance activée pour", player.Name)
    setupPlayerMonitoring(player)
end)

-- Détecter la déconnexion comme fallback
Players.PlayerRemoving:Connect(function(player)
    print("👋 [DISCONNECT-ONLY] PlayerRemoving détecté:", player.Name)
    
    -- Essayer le déséquipement traditionnel comme fallback
    local success = unequipPlayerTools(player)
    if success then
        print("✅ [DISCONNECT-ONLY] Fallback réussi pour", player.Name)
    else
        print("ℹ️ [DISCONNECT-ONLY] Fallback - aucun outil à déséquiper pour", player.Name)
    end
    
    -- Nettoyer les connexions
    cleanupPlayer(player)
end)

-- Gérer les joueurs déjà connectés
for _, player in pairs(Players:GetPlayers()) do
    setupPlayerMonitoring(player)
end

-- Commande de test pour vérifier le déséquipement manuel
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if message:lower() == "/testdisconnect" then
            print("🧪 [DISCONNECT-ONLY] Test de déséquipement pour", player.Name)
            local success = unequipPlayerTools(player)
            if success then
                print("✅ [DISCONNECT-ONLY] Test réussi - outils déséquipés")
            else
                print("ℹ️ [DISCONNECT-ONLY] Test - aucun outil à déséquiper")
            end
        elseif message:lower() == "/checkequipped" then
            print("🔍 [DISCONNECT-ONLY] Vérification outils équipés pour", player.Name)
            local count = 0
            for tool, _ in pairs(playerEquippedTools[player] or {}) do
                if tool and tool.Parent then
                    count = count + 1
                    local baseName = tool:GetAttribute("BaseName") or tool.Name
                    print("  📋", baseName, "dans", tool.Parent.Name)
                end
            end
            print("🔍 [DISCONNECT-ONLY] Total:", count, "outil(s) équipé(s)")
        end
    end)
end)

print("✅ [DISCONNECT-ONLY] Système activé - déséquipement à la déconnexion avec surveillance avancée")
print("💡 [DISCONNECT-ONLY] Commandes de test: /testdisconnect, /checkequipped")