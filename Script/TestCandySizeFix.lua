--[[
TestCandySizeFix.lua - Script de test pour vérifier la préservation des tailles de bonbons
Ce script teste que les tailles de bonbons sont correctement sauvegardées et restaurées.

À placer dans ServerScriptService pour les tests
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Attendre que les modules soient chargés
local SaveDataManager = require(ReplicatedStorage:WaitForChild("SaveDataManager"))
local CandyTools = require(ReplicatedStorage:WaitForChild("CandyTools"))

print("🧪 [TEST] Script de test pour les tailles de bonbons initialisé")

-- Fonction de test automatique
local function testCandySizePreservation(player)
    print("\n🧪 [TEST] ========== DÉBUT TEST TAILLES BONBONS ==========")
    print("🧪 [TEST] Joueur:", player.Name)
    
    -- Attendre que le joueur soit complètement chargé
    task.wait(3)
    
    -- Test 1: Créer des bonbons avec différentes tailles
    print("🧪 [TEST] Étape 1: Création de bonbons de test")
    
    -- Simuler des données de taille différentes
    local testCandies = {
        {name = "Basique", size = 2.5, rarity = "Large"},
        {name = "Basique", size = 5.0, rarity = "Giant"},
        {name = "Fraise", size = 0.5, rarity = "Tiny"},
        {name = "Fraise", size = 1.0, rarity = "Small"},
        {name = "ChocoMenthe", size = 10.0, rarity = "Colossal"}
    }
    
    -- Créer les bonbons avec tailles spécifiques
    for i, candyData in ipairs(testCandies) do
        -- Configurer les données de restauration pour forcer la taille
        _G.restoreCandyData = {
            size = candyData.size,
            rarity = candyData.rarity,
            color = Color3.fromRGB(255, 100 + i * 30, 100 + i * 20)
        }
        
        local success = CandyTools.giveCandy(player, candyData.name, 1)
        if success then
            print("✅ [TEST] Bonbon créé:", candyData.name, "|", candyData.rarity, "|", candyData.size .. "x")
        else
            warn("❌ [TEST] Échec création bonbon:", candyData.name)
        end
        
        _G.restoreCandyData = nil
        task.wait(0.5)
    end
    
    print("🧪 [TEST] Étape 2: Vérification de l'inventaire avant sauvegarde")
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
                local size = tool:GetAttribute("CandySize")
                local rarity = tool:GetAttribute("CandyRarity")
                local baseName = tool:GetAttribute("BaseName")
                print("📋 [TEST] Inventaire:", baseName, "|", rarity or "N/A", "|", size and (size .. "x") or "N/A")
            end
        end
    end
    
    -- Test 2: Sauvegarder
    print("🧪 [TEST] Étape 3: Sauvegarde des données")
    local saveSuccess = SaveDataManager.savePlayerData(player)
    if saveSuccess then
        print("✅ [TEST] Sauvegarde réussie")
    else
        warn("❌ [TEST] Échec de sauvegarde")
        return
    end
    
    task.wait(2)
    
    -- Test 3: Vider l'inventaire
    print("🧪 [TEST] Étape 4: Vidage de l'inventaire")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                tool:Destroy()
            end
        end
    end
    
    task.wait(1)
    
    -- Test 4: Charger et restaurer
    print("🧪 [TEST] Étape 5: Chargement et restauration")
    local loadedData = SaveDataManager.loadPlayerData(player)
    if loadedData then
        print("✅ [TEST] Données chargées")
        
        local restoreSuccess = SaveDataManager.restoreInventory(player, loadedData)
        if restoreSuccess then
            print("✅ [TEST] Inventaire restauré")
        else
            warn("❌ [TEST] Échec restauration inventaire")
            return
        end
    else
        warn("❌ [TEST] Échec du chargement")
        return
    end
    
    task.wait(2)
    
    -- Test 5: Vérifier les tailles restaurées
    print("🧪 [TEST] Étape 6: Vérification des tailles restaurées")
    local sizesCorrect = true
    local restoredCount = 0
    
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
                local size = tool:GetAttribute("CandySize")
                local rarity = tool:GetAttribute("CandyRarity")
                local baseName = tool:GetAttribute("BaseName")
                
                restoredCount = restoredCount + 1
                print("📋 [TEST] Restauré:", baseName, "|", rarity or "N/A", "|", size and (size .. "x") or "N/A")
                
                -- Vérifier si la taille n'est pas "Normal" (défaut)
                if not rarity or rarity == "Normal" or not size or size == 1.0 then
                    print("❌ [TEST] Taille perdue pour:", baseName)
                    sizesCorrect = false
                end
            end
        end
    end
    
    -- Résultat du test
    print("\n🧪 [TEST] ========== RÉSULTATS ==========")
    print("🧪 [TEST] Bonbons restaurés:", restoredCount)
    print("🧪 [TEST] Tailles préservées:", sizesCorrect and "✅ OUI" or "❌ NON")
    
    if sizesCorrect and restoredCount > 0 then
        print("🎉 [TEST] TEST RÉUSSI - Les tailles de bonbons sont correctement préservées!")
    else
        print("💥 [TEST] TEST ÉCHOUÉ - Les tailles de bonbons ne sont pas préservées")
    end
    
    print("🧪 [TEST] ========== FIN TEST ==========")
end

-- Commande de test pour les admins
local function setupTestCommands()
    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(message)
            -- Vérifier si c'est un admin (remplacez par votre système)
            local isAdmin = player.Name == "Maxim" or player.UserId == 123456789  -- Remplacez par votre UserID
            
            if isAdmin and message:lower() == "/testsizes" then
                print("🔧 [ADMIN] Commande /testsizes par", player.Name)
                testCandySizePreservation(player)
            end
        end)
    end)
end

-- Auto-test quand un joueur rejoint (optionnel - commentez si pas voulu)
--[[
Players.PlayerAdded:Connect(function(player)
    if player.Character then
        task.wait(5) -- Attendre que tout soit chargé
        testCandySizePreservation(player)
    else
        player.CharacterAdded:Wait()
        task.wait(5)
        testCandySizePreservation(player)
    end
end)
--]]

-- Configurer les commandes de test
setupTestCommands()

print("✅ [TEST] Système de test des tailles de bonbons prêt")
print("💡 [TEST] Commande admin disponible: /testsizes")