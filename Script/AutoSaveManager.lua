--[[
AutoSaveManager.lua - Gestionnaire automatique de sauvegarde
Ce script serveur gère:
- Sauvegarde automatique quand un joueur quitte
- Sauvegardes périodiques toutes les 5 minutes
- Chargement des données quand un joueur arrive
- Commandes de sauvegarde manuelle
- Protection contre les pertes de données

À placer dans ServerScriptService
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Charger le gestionnaire de sauvegarde
local SaveDataManager = require(ReplicatedStorage:WaitForChild("SaveDataManager"))

-- Configuration
local AUTO_SAVE_INTERVAL = 300  -- 5 minutes en secondes
local SAVE_ON_SHUTDOWN = true   -- Sauvegarder lors de l'arrêt du serveur

-- Variables de gestion
local activePlayers = {}
local lastAutoSave = {}
local isShuttingDown = false

-- Statistiques
local saveStats = {
    totalSaves = 0,
    successfulSaves = 0,
    failedSaves = 0,
    totalLoads = 0,
    successfulLoads = 0
}

print("🔄 [AUTOSAVE] AutoSaveManager initialisé")

--[[
GESTION DE L'ARRIVÉE DES JOUEURS
--]]
local function onPlayerAdded(player)
    print("👋 [AUTOSAVE] Joueur connecté:", player.Name)
    
    -- Attendre que le personnage soit chargé
    local function onCharacterAdded(character)
        -- Petit délai pour s'assurer que PlayerData existe
        task.wait(2)
        
        -- 👍 GameManager gère déjà le chargement des données
        -- Ne pas dupliquer ici pour éviter les doublons d'items
        print("🎮 [AUTOSAVE] Joueur prêt:", player.Name, "- Chargement géré par GameManager")
        
        -- Ajouter aux joueurs actifs
        activePlayers[player.UserId] = {
            player = player,
            joinTime = os.time(),
            lastSave = os.time()
        }
        
        lastAutoSave[player.UserId] = os.time()
    end
    
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
end

--[[
GESTION DU DÉPART DES JOUEURS
--]]
local function onPlayerRemoving(player)
    print("👋 [AUTOSAVE] Joueur en déconnexion:", player.Name)
    
    if not isShuttingDown then
        -- 🚨 NOUVEAU: Utiliser la sauvegarde spéciale de déconnexion avec déséquipement
        saveStats.totalSaves = saveStats.totalSaves + 1
        
        local success = SaveDataManager.savePlayerDataOnDisconnect(player)
        
        if success then
            saveStats.successfulSaves = saveStats.successfulSaves + 1
            print("✅ [AUTOSAVE] Sauvegarde de déconnexion réussie pour", player.Name)
        else
            saveStats.failedSaves = saveStats.failedSaves + 1
            warn("❌ [AUTOSAVE] Échec sauvegarde de déconnexion pour", player.Name)
        end
    end
    
    -- Nettoyer les références
    activePlayers[player.UserId] = nil
    lastAutoSave[player.UserId] = nil
end

--[[
SAUVEGARDE AUTOMATIQUE PÉRIODIQUE
--]]
local function performAutoSave()
    if isShuttingDown then return end
    
    local currentTime = os.time()
    local savedCount = 0
    
    for userId, playerData in pairs(activePlayers) do
        local player = playerData.player
        
        -- Vérifier si c'est l'heure de sauvegarder ce joueur
        if currentTime - (lastAutoSave[userId] or 0) >= AUTO_SAVE_INTERVAL then
            saveStats.totalSaves = saveStats.totalSaves + 1
            
            -- Utiliser la sauvegarde normale (SANS déséquipement) pour les sauvegardes automatiques
            local success = SaveDataManager.savePlayerData(player)
            
            if success then
                saveStats.successfulSaves = saveStats.successfulSaves + 1
                savedCount = savedCount + 1
                lastAutoSave[userId] = currentTime
                playerData.lastSave = currentTime
            else
                saveStats.failedSaves = saveStats.failedSaves + 1
                warn("❌ [AUTOSAVE] Échec sauvegarde auto pour", player.Name)
            end
        end
    end
    
    if savedCount > 0 then
        print("💾 [AUTOSAVE] Sauvegarde automatique effectuée pour", savedCount, "joueur(s) (sans déséquipement)")
    end
end

--[[
GESTION DE L'ARRÊT DU SERVEUR
--]]
local function onServerShutdown()
    isShuttingDown = true
    print("🛑 [AUTOSAVE] Arrêt du serveur détecté - Sauvegarde d'urgence...")
    
    local shutdownSaves = 0
    
    for userId, playerData in pairs(activePlayers) do
        local player = playerData.player
        
        if player and player.Parent then
            -- 🚨 NOUVEAU: Utiliser la sauvegarde spéciale avec déséquipement même à l'arrêt
            local success = SaveDataManager.savePlayerDataOnDisconnect(player)
            
            if success then
                shutdownSaves = shutdownSaves + 1
                print("✅ [AUTOSAVE] Sauvegarde d'urgence pour", player.Name)
            else
                warn("❌ [AUTOSAVE] Échec sauvegarde d'urgence pour", player.Name)
            end
        end
    end
    
    print("💾 [AUTOSAVE] Sauvegarde d'urgence terminée:", shutdownSaves, "joueur(s)")
end

--[[
COMMANDES DE SAUVEGARDE MANUELLE
--]]

-- Événement pour sauvegarder manuellement
local manualSaveEvent = Instance.new("RemoteEvent")
manualSaveEvent.Name = "ManualSaveEvent"
manualSaveEvent.Parent = ReplicatedStorage

manualSaveEvent.OnServerEvent:Connect(function(player)
    print("🔧 [AUTOSAVE] Sauvegarde manuelle demandée par", player.Name)
    
    local success = SaveDataManager.savePlayerData(player)
    
    if success then
        print("✅ [AUTOSAVE] Sauvegarde manuelle réussie pour", player.Name)
        manualSaveEvent:FireClient(player, true, "Sauvegarde réussie!")
    else
        warn("❌ [AUTOSAVE] Échec sauvegarde manuelle pour", player.Name)
        manualSaveEvent:FireClient(player, false, "Échec de la sauvegarde")
    end
end)

-- Événement pour obtenir les statistiques
local saveStatsEvent = Instance.new("RemoteEvent")
saveStatsEvent.Name = "SaveStatsEvent"
saveStatsEvent.Parent = ReplicatedStorage

saveStatsEvent.OnServerEvent:Connect(function(player)
    local playerStats = SaveDataManager.getPlayerStats(player)
    
    local combinedStats = {
        global = saveStats,
        player = playerStats,
        activePlayers = 0
    }
    
    -- Compter les joueurs actifs
    for _ in pairs(activePlayers) do
        combinedStats.activePlayers = combinedStats.activePlayers + 1
    end
    
    saveStatsEvent:FireClient(player, combinedStats)
end)

--[[
COMMANDES ADMINISTRATEUR (pour tester)
--]]
local function setupAdminCommands()
    -- Commande pour sauvegarder tous les joueurs
    game.Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(message)
            -- Vérifier si c'est un admin (remplacez par votre système)
            local isAdmin = player.Name == "Maxim" or player.UserId == 123456789  -- Remplacez par votre UserID
            
            if isAdmin then
                if message:lower() == "/saveall" then
                    print("🔧 [ADMIN] Commande /saveall par", player.Name)
                    
                    local savedCount = 0
                    for _, playerData in pairs(activePlayers) do
                        local success = SaveDataManager.savePlayerData(playerData.player)
                        if success then
                            savedCount = savedCount + 1
                        end
                    end
                    
                    print("💾 [ADMIN] Sauvegarde forcée terminée:", savedCount, "joueur(s)")
                    
                elseif message:lower() == "/savestats" then
                    print("📊 [ADMIN] Statistiques de sauvegarde:")
                    print("   Total sauvegardes:", saveStats.totalSaves)
                    print("   Sauvegardes réussies:", saveStats.successfulSaves)
                    print("   Sauvegardes échouées:", saveStats.failedSaves)
                    print("   Total chargements:", saveStats.totalLoads)
                    print("   Chargements réussis:", saveStats.successfulLoads)
                    print("   Joueurs actifs:", #activePlayers)
                end
            end
        end)
    end)
end

--[[
INITIALISATION
--]]

-- Connecter les événements
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Gérer les joueurs déjà connectés (si le script est chargé en cours de partie)
for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- Démarrer la sauvegarde automatique périodique
task.spawn(function()
    while not isShuttingDown do
        task.wait(60) -- Vérifier toutes les minutes
        performAutoSave()
    end
end)

-- Gérer l'arrêt du serveur
if SAVE_ON_SHUTDOWN then
    game:BindToClose(function()
        onServerShutdown()
        task.wait(3) -- Laisser le temps aux sauvegardes
    end)
end

-- Configurer les commandes admin
setupAdminCommands()

-- Afficher les statistiques périodiquement
task.spawn(function()
    while not isShuttingDown do
        task.wait(600) -- Toutes les 10 minutes
        
        if saveStats.totalSaves > 0 then
            local successRate = math.floor((saveStats.successfulSaves / saveStats.totalSaves) * 100)
            print("📊 [AUTOSAVE] Statistiques: " .. saveStats.successfulSaves .. "/" .. saveStats.totalSaves .. 
                  " sauvegardes réussies (" .. successRate .. "%)")
        end
    end
end)

print("✅ [AUTOSAVE] Système de sauvegarde automatique activé")
print("💡 [AUTOSAVE] Commandes admin disponibles: /saveall, /savestats")