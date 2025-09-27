--[[
SaveDataManager.lua - Système de sauvegarde complet pour SweetyScript
Ce module gère la sauvegarde et le chargement de toutes les données des joueurs.

Données sauvegardées:
- Argent du joueur
- Inventaire (Tools avec quantités)
- Sac à bonbons (SacBonbons)
- Recettes découvertes
- Niveaux et déblocages
- Tailles de bonbons découvertes (Pokédex)
- Paramètres du tutoriel
- Plateformes de production

Usage:
local SaveDataManager = require(ReplicatedStorage.SaveDataManager)
local success = SaveDataManager.savePlayerData(player)
local data = SaveDataManager.loadPlayerData(player)
--]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration du DataStore
local DATASTORE_NAME = "SweetyScriptPlayerData_v1.3" -- Nouvelle version pour les tailles
local SAVE_VERSION = "1.4.0" -- 🔧 NOUVELLE VERSION: Support outils équipés séparés -- Version avec support amélioré des tailles de bonbons

-- Paramètres de sauvegarde
local CONFIG = {
    MAX_RETRIES = 3,                -- Nombre max de tentatives
    RETRY_DELAY = 2,               -- Délai entre les tentatives (secondes)
    AUTO_SAVE_INTERVAL = 300,      -- Sauvegarde automatique toutes les 5 minutes
    BACKUP_COUNT = 3,              -- Nombre de sauvegardes de secours
    MAX_DATA_SIZE = 4000000,       -- Taille max des données (4MB)
    COMPRESSION_ENABLED = true,     -- Activer la compression des données
}

-- DataStore principal
local playerDataStore = nil
local backupDataStore = nil

-- Cache des données pour éviter les sauvegardes redondantes
local dataCache = {}
local lastSaveTime = {}

-- Initialiser les DataStores (avec gestion d'erreur)
local function initializeDataStores()
    local success, errorMessage = pcall(function()
        playerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
        backupDataStore = DataStoreService:GetDataStore(DATASTORE_NAME .. "_Backup")
    end)
    
    if not success then
        warn("⚠️ [SAVE] Impossible d'initialiser les DataStores:", errorMessage)
        warn("⚠️ [SAVE] Le système de sauvegarde sera désactivé")
        return false
    end
    
    print("✅ [SAVE] DataStores initialisés avec succès")
    return true
end

local SaveDataManager = {}

-- Forward declaration to satisfy linter when referenced before definition
local _migrateOldSaveData = nil

-- 🚨 NOUVELLE FONCTION: Déséquiper tous les outils avant sauvegarde
-- Cette fonction résout le problème des bonbons en main qui ne sont pas sauvegardés
local function unequipAllTools(player)
    if not player or not player.Parent then 
        print("⚠️ [UNEQUIP] Joueur déjà déconnecté, impossible de déséquiper")
        return false 
    end
    
    local character = player.Character
    if not character then 
        print("⚠️ [UNEQUIP] Pas de character trouvé pour", player.Name)
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
        print("ℹ️ [UNEQUIP] Aucun outil équipé pour", player.Name)
        return false
    end
    
    -- Déplacer tous les outils vers le backpack
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("⚠️ [UNEQUIP] Pas de backpack trouvé pour", player.Name)
        return false
    end
    
    for _, tool in pairs(toolsToMove) do
        local baseName = tool:GetAttribute("BaseName") or tool.Name
        print("📤 [UNEQUIP] Déséquipement:", baseName)
        tool.Parent = backpack
    end
    
    print("✅ [UNEQUIP] Déséquipé", unequippedCount, "outil(s) pour", player.Name)
    return true
end

-- Fonction pour encoder/compresser les données
local function compressData(data)
    if not CONFIG.COMPRESSION_ENABLED then
        return data
    end
    
    -- Conversion en JSON puis compression simple
    local success, jsonData = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    
    if not success then
        warn("⚠️ [SAVE] Erreur de compression:", jsonData)
        return data
    end
    
    return {
        compressed = true,
        data = jsonData,
        version = SAVE_VERSION
    }
end

-- Fonction pour décoder/décompresser les données
local function decompressData(compressedData)
    if not compressedData or type(compressedData) ~= "table" then
        return compressedData
    end
    
    if not compressedData.compressed then
        -- 🛡️ SAFEGUARD: Même pour les données non compressées
        if compressedData and type(compressedData) == "table" and not compressedData.equippedTools then
            compressedData.equippedTools = {}
            print("🔧 [DECOMPRESS] equippedTools ajouté aux données non compressées")
        end
        return compressedData
    end
    
    local success, decodedData = pcall(function()
        return game:GetService("HttpService"):JSONDecode(compressedData.data)
    end)
    
    if not success then
        warn("⚠️ [SAVE] Erreur de décompression:", decodedData)
        return compressedData
    end
    
    -- 🛡️ SAFEGUARD CRITIQUE: S'assurer que equippedTools existe
    if not decodedData.equippedTools then
        decodedData.equippedTools = {}
        print("🔧 [DECOMPRESS] equippedTools ajouté aux données décompressées")
    end
    
    return decodedData
end

-- Fonction pour sérialiser l'inventaire ET les outils équipés séparément
local function serializeInventoryAndEquipped(player)
    local inventoryData = {}
    local equippedData = {}
    local backpack = player:FindFirstChildOfClass("Backpack")
    
    print("🔍 [SERIALIZE] Début sérialisation inventaire + équipés pour", player.Name)
    
    -- Sérialiser les tools du backpack
    if backpack then
        local toolCount = 0
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                toolCount = toolCount + 1
                local baseName = tool:GetAttribute("BaseName") or tool.Name
                local count = tool:FindFirstChild("Count")
                local quantity = count and count.Value or 1
                local isCandy = tool:GetAttribute("IsCandy")
                
                -- Normalisation du type et du baseName
                do
                    if isCandy ~= true then
                        if tool:GetAttribute("CandySize") or tool:GetAttribute("CandyRarity") then
                            isCandy = true
                        end
                    end
                    local okRM, RM = pcall(function()
                        return require(ReplicatedStorage:WaitForChild("RecipeManager"))
                    end)
                    if okRM and RM and RM.Recettes then
                        for recipeName, def in pairs(RM.Recettes) do
                            if recipeName == baseName or (def.modele and (def.modele == baseName or def.modele == tool.Name)) then
                                baseName = recipeName
                                isCandy = (isCandy == true) or true
                                break
                            end
                        end
                    end
                    if isCandy ~= true then
                        local CandyModels = ReplicatedStorage:FindFirstChild("CandyModels")
                        if CandyModels and (CandyModels:FindFirstChild(baseName) or CandyModels:FindFirstChild("Bonbon" .. baseName) or CandyModels:FindFirstChild("Bonbon" .. baseName:gsub(" ", ""))) then
                            isCandy = true
                        end
                    end
                    if isCandy ~= true then isCandy = false end
                end
                
                print("🔍 [SERIALIZE] Tool", toolCount .. ":", tool.Name, "| BaseName:", baseName, "| Quantity:", quantity, "| IsCandy:", isCandy)
                
                -- 🍬 Capturer les données de taille des bonbons
                local sizeData = nil
                if isCandy then
                    local candySize = tool:GetAttribute("CandySize")
                    local candyRarity = tool:GetAttribute("CandyRarity")
                    local colorR = tool:GetAttribute("CandyColorR")
                    local colorG = tool:GetAttribute("CandyColorG")
                    local colorB = tool:GetAttribute("CandyColorB")
                    
                    print("🔍 [SERIALIZE] Attributs bonbon:", "Size:", candySize, "| Rarity:", candyRarity, "| Colors:", colorR, colorG, colorB)
                    
                    if candySize and candyRarity then
                        sizeData = {
                            size = candySize,
                            rarity = candyRarity,
                            colorR = colorR or 255,
                            colorG = colorG or 255,
                            colorB = colorB or 255
                        }
                        print("💾 [SAVE] Taille capturée:", baseName, "|", candyRarity, "|", candySize .. "x")
                    else
                        print("⚠️ [SERIALIZE] Pas de données de taille valides pour:", baseName)
                    end
                end
                
                -- Créer une clé unique basée sur le nom ET la taille (pour les bonbons)
                local itemKey = baseName
                if sizeData then
                    itemKey = baseName .. "_" .. sizeData.rarity .. "_" .. tostring(sizeData.size)
                end
                
                print("🔍 [SERIALIZE] Clé générée:", itemKey)
                
                -- Grouper les items par clé unique dans l'inventaire
                if inventoryData[itemKey] then
                    print("🔍 [SERIALIZE] Fusion avec item existant:", itemKey, "| Ancienne quantité:", inventoryData[itemKey].quantity, "| Ajout:", quantity)
                    inventoryData[itemKey].quantity = inventoryData[itemKey].quantity + quantity
                else
                    print("🔍 [SERIALIZE] Création nouvelle entrée:", itemKey, "| Quantité:", quantity)
                    inventoryData[itemKey] = {
                        baseName = baseName,
                        quantity = quantity,
                        isCandy = isCandy,
                        toolName = tool.Name,
                        sizeData = sizeData
                    }
                end
            end
        end
        print("🔍 [SERIALIZE] Total tools traités dans backpack:", toolCount)
    else
        print("⚠️ [SERIALIZE] Pas de backpack trouvé")
    end
    
    -- 🔧 NOUVEAU: Sérialiser les outils équipés séparément
    print("🔍 [SERIALIZE] Vérification outils équipés...")
    if player.Character then
        local equippedCount = 0
        for _, tool in pairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                equippedCount = equippedCount + 1
                local baseName = tool:GetAttribute("BaseName") or tool.Name
                local count = tool:FindFirstChild("Count")
                local quantity = count and count.Value or 1
                local isCandy = tool:GetAttribute("IsCandy")
                
                -- Normalisation du type et du baseName (équipé)
                do
                    if isCandy ~= true then
                        if tool:GetAttribute("CandySize") or tool:GetAttribute("CandyRarity") then
                            isCandy = true
                        end
                    end
                    local okRM, RM = pcall(function()
                        return require(ReplicatedStorage:WaitForChild("RecipeManager"))
                    end)
                    if okRM and RM and RM.Recettes then
                        for recipeName, def in pairs(RM.Recettes) do
                            if recipeName == baseName or (def.modele and (def.modele == baseName or def.modele == tool.Name)) then
                                baseName = recipeName
                                isCandy = (isCandy == true) or true
                                break
                            end
                        end
                    end
                    if isCandy ~= true then
                        local CandyModels = ReplicatedStorage:FindFirstChild("CandyModels")
                        if CandyModels and (CandyModels:FindFirstChild(baseName) or CandyModels:FindFirstChild("Bonbon" .. baseName) or CandyModels:FindFirstChild("Bonbon" .. baseName:gsub(" ", ""))) then
                            isCandy = true
                        end
                    end
                    if isCandy ~= true then isCandy = false end
                end
                
                print("🔍 [SERIALIZE] Outil équipé", equippedCount .. ":", tool.Name, "| BaseName:", baseName, "| Quantity:", quantity, "| IsCandy:", isCandy)
                
                -- 🍬 Capturer les données de taille pour l'outil équipé aussi
                local sizeData = nil
                if isCandy then
                    local candySize = tool:GetAttribute("CandySize")
                    local candyRarity = tool:GetAttribute("CandyRarity")
                    local colorR = tool:GetAttribute("CandyColorR")
                    local colorG = tool:GetAttribute("CandyColorG")
                    local colorB = tool:GetAttribute("CandyColorB")
                    
                    print("🔍 [SERIALIZE] Attributs bonbon équipé:", "Size:", candySize, "| Rarity:", candyRarity, "| Colors:", colorR, colorG, colorB)
                    
                    if candySize and candyRarity then
                        sizeData = {
                            size = candySize,
                            rarity = candyRarity,
                            colorR = colorR or 255,
                            colorG = colorG or 255,
                            colorB = colorB or 255
                        }
                        print("💾 [SAVE] Taille capturée (équipé):", baseName, "|", candyRarity, "|", candySize .. "x")
                    else
                        print("⚠️ [SERIALIZE] Pas de données de taille valides pour outil équipé:", baseName)
                    end
                end
                
                local itemKey = baseName
                if sizeData then
                    itemKey = baseName .. "_" .. sizeData.rarity .. "_" .. tostring(sizeData.size)
                end
                
                print("🔍 [SERIALIZE] Clé générée (équipé):", itemKey)
                
                -- Sauvegarder comme outil équipé (pas de fusion, un seul outil peut être équipé à la fois)
                equippedData[itemKey] = {
                    baseName = baseName,
                    quantity = quantity,
                    isCandy = isCandy,
                    toolName = tool.Name,
                    sizeData = sizeData
                }
                print("🎯 [SERIALIZE] Outil équipé sauvegardé:", itemKey, "| Quantité:", quantity)
            end
        end
        print("🔍 [SERIALIZE] Total outils équipés traités:", equippedCount)
    else
        print("⚠️ [SERIALIZE] Pas de personnage trouvé")
    end
    
    -- 🔍 DEBUG: Afficher le résumé final de la sérialisation
    local inventoryCount = 0
    local equippedCount = 0
    
    print("🔍 [SERIALIZE] Résumé final des données sérialisées:")
    print("🎒 INVENTAIRE:")
    for itemKey, itemData in pairs(inventoryData) do
        inventoryCount = inventoryCount + 1
        local sizeInfo = ""
        if itemData.sizeData then
            sizeInfo = " (" .. itemData.sizeData.rarity .. " " .. itemData.sizeData.size .. "x)"
        end
        print("  ➤", itemKey, ":", itemData.baseName, "x" .. itemData.quantity, sizeInfo)
    end
    
    print("🎯 ÉQUIPÉS:")
    for itemKey, itemData in pairs(equippedData) do
        equippedCount = equippedCount + 1
        local sizeInfo = ""
        if itemData.sizeData then
            sizeInfo = " (" .. itemData.sizeData.rarity .. " " .. itemData.sizeData.size .. "x)"
        end
        print("  👍", itemKey, ":", itemData.baseName, "x" .. itemData.quantity, sizeInfo)
    end
    
    print("🔍 [SERIALIZE] Total entrées inventaire:", inventoryCount, "| Total équipés:", equippedCount)
    
    return inventoryData, equippedData
end

-- Fonction pour sérialiser les données d'un dossier
local function serializeFolder(folder)
    if not folder then return {} end
    
    local folderData = {}
    
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("IntValue") then
            folderData[child.Name] = {
                type = "IntValue",
                value = child.Value
            }
        elseif child:IsA("BoolValue") then
            folderData[child.Name] = {
                type = "BoolValue",
                value = child.Value
            }
        elseif child:IsA("StringValue") then
            folderData[child.Name] = {
                type = "StringValue",
                value = child.Value
            }
        elseif child:IsA("NumberValue") then
            folderData[child.Name] = {
                type = "NumberValue",
                value = child.Value
            }
        elseif child:IsA("Folder") then
            folderData[child.Name] = {
                type = "Folder",
                children = serializeFolder(child)
            }
        end
    end
    
    return folderData
end

-- 🔧 Fonction helper pour restaurer un outil dans le backpack
local function restoreToolToBackpack(player, baseName, quantity, isCandy, sizeData)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return false end
    
    if isCandy then
        -- Pré-configurer les données de taille pour CandyTools
        if sizeData then
            _G.restoreCandyData = {
                size = sizeData.size,
                rarity = sizeData.rarity,
                color = Color3.fromRGB(sizeData.colorR or 255, sizeData.colorG or 255, sizeData.colorB or 255)
            }
            print("📋 [RESTORE] Configuration taille pour:", baseName, "|", sizeData.rarity, "|", sizeData.size .. "x")
        else
            _G.restoreCandyData = nil
        end
        
        local CandyTools = require(ReplicatedStorage:WaitForChild("CandyTools"))
        local success = CandyTools.giveCandy(player, baseName, quantity)
        _G.restoreCandyData = nil
        
        if success then
            print("✅ [RESTORE] Bonbon restauré:", baseName, "x" .. quantity, sizeData and ("(" .. sizeData.rarity .. " " .. sizeData.size .. "x)") or "")
        end
        return success
    else
        -- Restaurer ingrédient
        local ingredientToolsFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
        if ingredientToolsFolder then
            local template = ingredientToolsFolder:FindFirstChild(baseName)
            if template then
                local newTool = template:Clone()
                newTool:SetAttribute("BaseName", baseName)
                
                local count = newTool:FindFirstChild("Count")
                if not count then
                    count = Instance.new("IntValue")
                    count.Name = "Count"
                    count.Parent = newTool
                end
                count.Value = quantity
                
                newTool.Parent = backpack
                print("🥕 [RESTORE] Ingrédient restauré:", baseName, "x" .. quantity)
                return true
            end
        end
        return false
    end
end

-- 🔧 Fonction helper pour trouver un outil dans le backpack
local function findToolInBackpack(player, baseName, sizeData)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("BaseName") == baseName then
            if sizeData then
                local appliedSize = tool:GetAttribute("CandySize")
                local appliedRarity = tool:GetAttribute("CandyRarity")
                
                -- Vérifier que la taille correspond
                if appliedRarity == sizeData.rarity and 
                   appliedSize and math.abs(appliedSize - sizeData.size) < 0.05 then
                    return tool
                end
            else
                return tool -- Pas de données de taille, prendre le premier
            end
        end
    end
    return nil
end

-- Fonction principale pour sauvegarder les données d'un joueur
function SaveDataManager.savePlayerData(player)
    if not playerDataStore then
        warn("⚠️ [SAVE] DataStore non disponible, sauvegarde ignorée pour", player.Name)
        return false
    end
    
    local playerData = player:FindFirstChild("PlayerData")
    if not playerData then
        warn("⚠️ [SAVE] PlayerData manquant pour", player.Name)
        return false
    end
    
    -- 🚨 SUPPRIMÉ: Ne plus déséquiper automatiquement lors des sauvegardes normales
    -- unequipAllTools(player) -- Cette ligne causait le déséquipement automatique
    
    -- Pas de délai pour les sauvegardes normales
    
    -- 🔧 Créer la structure de données à sauvegarder
    local saveData = {
        version = SAVE_VERSION,
        timestamp = os.time(),
        playerId = player.UserId,
        playerName = player.Name,
        
        -- Données principales
        money = 0,
        inventory = {},
        equippedTools = {}, -- 🔧 CRITIQUE: TOUJOURS initialiser ce champ
        candyBag = {},
        discoveredRecipes = {},
        discoveredIngredients = {},
        discoveredSizes = {},
        
        -- Progression et déblocages
        platformsUnlocked = 0,
        incubatorsUnlocked = 1,
        merchantLevel = 1,
        shopUnlocks = {},
        
        -- Tutoriel et paramètres
        tutorialCompleted = false,
        tutorialData = {},
        
        -- Données de production
        productionData = {}, -- { { platformIndex, candy, stackSize, sizeData={size,rarity}, ... }, ... }
        incubatorProduction = {}, -- { { incID, recipe, quantity, produced, perCandyTime, elapsed }, ... }
        
        -- Métadonnées
        playTime = 0,
        lastLogin = os.time()
    }
    
    -- 🛡️ SAFEGUARD: Double vérification equippedTools
    if not saveData.equippedTools then
        saveData.equippedTools = {}
        warn("⚠️ [SAVE] SAFEGUARD: equippedTools manquant, réinitialisé")
    end
    
    -- Sauvegarder l'argent
    local argentValue = playerData:FindFirstChild("Argent")
    if argentValue then
        saveData.money = argentValue.Value
    end
    
    -- 🔧 NOUVEAU: Sérialiser inventaire et outils équipés séparément
    local inventoryData, equippedData = serializeInventoryAndEquipped(player)
    saveData.inventory = inventoryData
    saveData.equippedTools = equippedData
    
    -- Sauvegarder le sac à bonbons
    local sacBonbons = playerData:FindFirstChild("SacBonbons")
    if sacBonbons then
        saveData.candyBag = serializeFolder(sacBonbons)
    end
    
    -- Sauvegarder les recettes découvertes
    local recettesDecouvertes = playerData:FindFirstChild("RecettesDecouvertes")
    if recettesDecouvertes then
        saveData.discoveredRecipes = serializeFolder(recettesDecouvertes)
    end
    
    -- Sauvegarder les ingrédients découverts
    local ingredientsDecouverts = playerData:FindFirstChild("IngredientsDecouverts")
    if ingredientsDecouverts then
        saveData.discoveredIngredients = serializeFolder(ingredientsDecouverts)
    end
    
    -- Sauvegarder les tailles découvertes (Pokédex)
    local pokedexSizes = playerData:FindFirstChild("PokedexSizes")
    if pokedexSizes then
        saveData.discoveredSizes = serializeFolder(pokedexSizes)
    end
    
    -- Sauvegarder les déblocages
    local platformsUnlocked = playerData:FindFirstChild("PlatformsUnlocked")
    if platformsUnlocked then
        saveData.platformsUnlocked = platformsUnlocked.Value
    end

    -- Sauvegarder la production des plateformes (CandyPlatforms)
    if _G.CandyPlatforms and _G.CandyPlatforms.snapshotProductionForPlayer then
        local prod = _G.CandyPlatforms.snapshotProductionForPlayer(player.UserId)
        if prod and #prod > 0 then
            saveData.productionData = prod
        end
    end
    
    -- Sauvegarder la production des incubateurs (IncubatorServer)
    if _G.Incubator and _G.Incubator.snapshotProductionForPlayer then
        local incSnap = _G.Incubator.snapshotProductionForPlayer(player.UserId)
        if type(incSnap) == "table" and #incSnap > 0 then
            saveData.incubatorProduction = incSnap
        end
    end
    
    local incubatorsUnlocked = playerData:FindFirstChild("IncubatorsUnlocked")
    if incubatorsUnlocked then
        saveData.incubatorsUnlocked = incubatorsUnlocked.Value
    end
    
    local merchantLevel = playerData:FindFirstChild("MerchantLevel")
    if merchantLevel then
        saveData.merchantLevel = merchantLevel.Value
    end
    
    -- Sauvegarder les déblocages du shop
    local shopUnlocks = playerData:FindFirstChild("ShopUnlocks")
    if shopUnlocks then
        saveData.shopUnlocks = serializeFolder(shopUnlocks)
    end
    
    -- Sauvegarder le statut du tutoriel
    local tutorialCompleted = playerData:FindFirstChild("TutorialCompleted")
    if tutorialCompleted then
        saveData.tutorialCompleted = tutorialCompleted.Value
    end
    
    -- Vérifier si les données ont changé
    local dataKey = tostring(player.UserId)
    local currentDataHash = game:GetService("HttpService"):JSONEncode(saveData)
    
    if dataCache[dataKey] == currentDataHash and (os.time() - (lastSaveTime[dataKey] or 0)) < 60 then
        print("📊 [SAVE] Données inchangées pour", player.Name, "- sauvegarde ignorée")
        return true
    end
    
    -- Compresser les données si nécessaire
    local finalData = compressData(saveData)
    
    -- 🔍 DEBUG: Afficher le contenu final avant sauvegarde DataStore
    print("🔍 [DATASTORE] Contenu à sauvegarder:")
    print("  📊 Version:", finalData.version or "N/A")
    local inventoryCount = 0
    local equippedCount = 0
    
    if finalData.inventory then
        for itemKey, itemData in pairs(finalData.inventory) do
            inventoryCount = inventoryCount + 1
        end
    end
    
    if finalData.equippedTools then
        for itemKey, itemData in pairs(finalData.equippedTools) do
            equippedCount = equippedCount + 1
            print("  🎯 EquippedTool sauvegardé:", itemKey, "x" .. (itemData.quantity or "N/A"))
        end
    end
    
    print("  📊 Total à sauvegarder: Inventaire:", inventoryCount, "| Équipés:", equippedCount)
    
    -- Tentatives de sauvegarde avec retry
    for attempt = 1, CONFIG.MAX_RETRIES do
        local success, errorMessage = pcall(function()
            playerDataStore:SetAsync(dataKey, finalData)
        end)
        
        if success then
            -- 🔍 VERIFICATION: Immédiatement relire ce qui a été sauvé
            task.wait(0.1)
            local verificationSuccess, verificationData = pcall(function()
                return playerDataStore:GetAsync(dataKey)
            end)
            
            if verificationSuccess and verificationData then
                local decompressedVerif = decompressData(verificationData)
                local verifEquippedCount = 0
                if decompressedVerif.equippedTools then
                    for _ in pairs(decompressedVerif.equippedTools) do
                        verifEquippedCount = verifEquippedCount + 1
                    end
                end
                print("✅ [DATASTORE] Vérification sauvegarde: Équipés persistés:", verifEquippedCount)
            else
                warn("⚠️ [DATASTORE] Impossible de vérifier la sauvegarde")
            end
            
            dataCache[dataKey] = currentDataHash
            lastSaveTime[dataKey] = os.time()
            print("💾 [SAVE] Données sauvegardées avec succès pour", player.Name, "(tentative", attempt .. ")")
            
            -- Sauvegarde de backup
            if backupDataStore then
                pcall(function()
                    backupDataStore:SetAsync(dataKey .. "_" .. os.time(), finalData)
                end)
            end
            
            return true
        else
            warn("❌ [SAVE] Tentative", attempt, "échouée pour", player.Name .. ":", errorMessage)
            if attempt < CONFIG.MAX_RETRIES then
                task.wait(CONFIG.RETRY_DELAY)
            end
        end
    end
    
    warn("💥 [SAVE] Échec définitif de sauvegarde pour", player.Name)
    return false
end

-- Fonction pour restaurer un dossier depuis les données sérialisées
local function deserializeFolder(parent, folderData, folderName)
    if not folderData or not parent then return nil end
    
    local folder = parent:FindFirstChild(folderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = folderName
        folder.Parent = parent
    end
    
    for childName, childData in pairs(folderData) do
        if childData.type == "IntValue" then
            local value = folder:FindFirstChild(childName)
            if not value then
                value = Instance.new("IntValue")
                value.Name = childName
                value.Parent = folder
            end
            value.Value = childData.value or 0
            
        elseif childData.type == "BoolValue" then
            local value = folder:FindFirstChild(childName)
            if not value then
                value = Instance.new("BoolValue")
                value.Name = childName
                value.Parent = folder
            end
            value.Value = childData.value or false
            
        elseif childData.type == "StringValue" then
            local value = folder:FindFirstChild(childName)
            if not value then
                value = Instance.new("StringValue")
                value.Name = childName
                value.Parent = folder
            end
            value.Value = childData.value or ""
            
        elseif childData.type == "NumberValue" then
            local value = folder:FindFirstChild(childName)
            if not value then
                value = Instance.new("NumberValue")
                value.Name = childName
                value.Parent = folder
            end
            value.Value = childData.value or 0
            
        elseif childData.type == "Folder" and childData.children then
            deserializeFolder(folder, childData.children, childName)
        end
    end
    
    return folder
end

-- Fonction pour charger les données d'un joueur
function SaveDataManager.loadPlayerData(player)
    if not playerDataStore then
        warn("⚠️ [LOAD] DataStore non disponible pour", player.Name)
        return nil
    end
    
    local dataKey = tostring(player.UserId)
    local loadedData = nil
    
    -- Tentatives de chargement avec retry
    for attempt = 1, CONFIG.MAX_RETRIES do
        local success, result = pcall(function()
            return playerDataStore:GetAsync(dataKey)
        end)
        
        if success then
            loadedData = result
            break
        else
            warn("❌ [LOAD] Tentative", attempt, "échouée pour", player.Name .. ":", result)
            if attempt < CONFIG.MAX_RETRIES then
                task.wait(CONFIG.RETRY_DELAY)
            end
        end
    end
    
    if not loadedData then
        print("📂 [LOAD] Aucune donnée sauvegardée trouvée pour", player.Name, "- nouveau joueur")
        return nil
    end
    
    -- Décompresser les données
    loadedData = decompressData(loadedData)
    
    -- 🔍 DEBUG: Afficher le contenu chargé depuis DataStore
    print("🔍 [DATASTORE] Contenu chargé depuis DataStore:")
    print("  📊 Version:", loadedData.version or "N/A")
    local inventoryCount = 0
    local equippedCount = 0
    
    if loadedData.inventory then
        for itemKey, itemData in pairs(loadedData.inventory) do
            inventoryCount = inventoryCount + 1
        end
    end
    
    if loadedData.equippedTools then
        for itemKey, itemData in pairs(loadedData.equippedTools) do
            equippedCount = equippedCount + 1
            print("  🎯 EquippedTool chargé:", itemKey, "x" .. (itemData.quantity or "N/A"))
        end
    else
        print("  ⚠️ equippedTools field manquant ou vide dans les données chargées!")
    end
    
    print("  📊 Total chargé: Inventaire:", inventoryCount, "| Équipés:", equippedCount)
    
    -- 🔄 MIGRATION: Convertir ancien format vers nouveau format
    if loadedData.version and loadedData.version < "1.3.0" then
        print("🔄 [MIGRATE] Migration des données de", loadedData.version, "vers 1.3.0 pour", player.Name)
        loadedData = _migrateOldSaveData(loadedData)
    end
    
    print("📥 [LOAD] Données chargées pour", player.Name, "- Version:", loadedData.version or "inconnue")
    return loadedData
end

-- Fonction pour migrer les anciens formats de sauvegarde
local function _migrateOldSaveData(oldData)
    local newData = oldData
    
    -- Mise à jour de la version
    newData.version = SAVE_VERSION
    
    -- 🔧 CRITIQUE: S'assurer que equippedTools existe TOUJOURS
    if not newData.equippedTools then
        newData.equippedTools = {}
        print("🔄 [MIGRATE] Champ equippedTools ajouté (manquant)")
    elseif type(newData.equippedTools) ~= "table" then
        newData.equippedTools = {}
        print("🔄 [MIGRATE] Champ equippedTools réinitialisé (type incorrect)")
    else
        local equippedCount = 0
        for _ in pairs(newData.equippedTools) do
            equippedCount = equippedCount + 1
        end
        print("🔄 [MIGRATE] Champ equippedTools préservé avec", equippedCount, "items")
    end
    
    -- Migration des données d'inventaire vers le nouveau format
    if oldData.inventory and type(oldData.inventory) == "table" then
        local newInventory = {}
        
        for itemKey, itemData in pairs(oldData.inventory) do
            -- Ancien format: itemKey = baseName, itemData = {quantity, isCandy, toolName}
            if type(itemData) == "table" and itemData.quantity then
                -- Créer le nouveau format avec baseName explicite
                newInventory[itemKey] = {
                    baseName = itemKey, -- Assurer la compatibilité
                    quantity = itemData.quantity,
                    isCandy = itemData.isCandy or false,
                    toolName = itemData.toolName,
                    sizeData = itemData.sizeData or nil -- Préserver les données de taille si présentes
                }
                
                print("🔄 [MIGRATE] Item migré:", itemKey, "x" .. itemData.quantity)
            end
        end
        
        newData.inventory = newInventory
        print("✅ [MIGRATE] Inventaire migré vers nouveau format")
    end
    
    print("✅ [MIGRATE] Migration terminée vers version", SAVE_VERSION)
    return newData
end

-- Fonction pour restaurer les données d'un joueur
function SaveDataManager.restorePlayerData(player, loadedData)
    if not loadedData then
        print("⚠️ [RESTORE] Aucune donnée à restaurer pour", player.Name)
        return false
    end
    
    local playerData = player:FindFirstChild("PlayerData")
    if not playerData then
        warn("⚠️ [RESTORE] PlayerData manquant pour", player.Name)
        return false
    end
    
    print("🔄 [RESTORE] Restauration des données pour", player.Name)
    
    -- Restaurer l'argent
    if loadedData.money then
        local argentValue = playerData:FindFirstChild("Argent")
        if argentValue then
            argentValue.Value = loadedData.money
            print("💰 [RESTORE] Argent restauré:", loadedData.money)
        end
    end
    
    -- Restaurer les déblocages
    if loadedData.platformsUnlocked then
        local platformsUnlocked = playerData:FindFirstChild("PlatformsUnlocked")
        if platformsUnlocked then
            platformsUnlocked.Value = loadedData.platformsUnlocked
        end
    end
    
    if loadedData.incubatorsUnlocked then
        local incubatorsUnlocked = playerData:FindFirstChild("IncubatorsUnlocked")
        if incubatorsUnlocked then
            incubatorsUnlocked.Value = loadedData.incubatorsUnlocked
        end
    end
    
    if loadedData.merchantLevel then
        local merchantLevel = playerData:FindFirstChild("MerchantLevel")
        if merchantLevel then
            merchantLevel.Value = loadedData.merchantLevel
        end
    end
    
    -- Restaurer les dossiers
    if loadedData.candyBag then
        deserializeFolder(playerData, loadedData.candyBag, "SacBonbons")
        print("🍬 [RESTORE] Sac à bonbons restauré")
    end
    
    if loadedData.discoveredRecipes then
        deserializeFolder(playerData, loadedData.discoveredRecipes, "RecettesDecouvertes")
        print("📋 [RESTORE] Recettes découvertes restaurées")
    end
    
    if loadedData.discoveredIngredients then
        deserializeFolder(playerData, loadedData.discoveredIngredients, "IngredientsDecouverts")
        print("🥕 [RESTORE] Ingrédients découverts restaurés")
    end
    
    if loadedData.discoveredSizes then
        deserializeFolder(playerData, loadedData.discoveredSizes, "PokedexSizes")
        print("📏 [RESTORE] Tailles découvertes restaurées")
    end
    
    if loadedData.shopUnlocks then
        deserializeFolder(playerData, loadedData.shopUnlocks, "ShopUnlocks")
        print("🏪 [RESTORE] Déblocages shop restaurés")
    end
    
    -- Restaurer le tutoriel
    if loadedData.tutorialCompleted then
        local tutorialCompleted = playerData:FindFirstChild("TutorialCompleted")
        if not tutorialCompleted then
            tutorialCompleted = Instance.new("BoolValue")
            tutorialCompleted.Name = "TutorialCompleted"
            tutorialCompleted.Parent = playerData
        end
        tutorialCompleted.Value = loadedData.tutorialCompleted
        print("🎓 [RESTORE] Statut tutoriel restauré:", loadedData.tutorialCompleted)
    end
    
    print("✅ [RESTORE] Restauration terminée pour", player.Name)
    return true
end

-- Fonction pour restaurer l'inventaire ET les outils équipés (appelée séparément après le chargement)
function SaveDataManager.restoreInventory(player, loadedData)
    if not loadedData then
        print("📦 [RESTORE] Aucune donnée à restaurer pour", player.Name)
        return false
    end
    
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("⚠️ [RESTORE] Backpack manquant pour", player.Name)
        return false
    end
    
    -- 🚨 CRITIQUE: Vider complètement l'inventaire ET l'équipement avant restauration
    print("🧹 [RESTORE] Nettoyage de l'inventaire existant pour", player.Name)
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            print("🗑️ [RESTORE] Suppression:", item.Name, "(Count:", item:FindFirstChild("Count") and item.Count.Value or "N/A", ")")
            item:Destroy()
        end
    end
    
    -- Aussi nettoyer l'équipement actuel
    if player.Character then
        for _, item in pairs(player.Character:GetChildren()) do
            if item:IsA("Tool") then
                print("🗑️ [RESTORE] Suppression équipé:", item.Name)
                item:Destroy()
            end
        end
    end
    
    -- 🔧 NOUVEAU: Compter les items d'inventaire ET équipés séparément
    local inventoryCount = 0
    local equippedCount = 0
    
    if loadedData.inventory then
        for _ in pairs(loadedData.inventory) do
            inventoryCount = inventoryCount + 1
        end
    end
    
    -- 🛡️ SAFEGUARD FINAL: S'assurer que equippedTools existe
    if not loadedData.equippedTools then
        loadedData.equippedTools = {}
        warn("⚠️ [RESTORE] SAFEGUARD: equippedTools manquant dans loadedData, réinitialisé")
    end
    
    if loadedData.equippedTools then
        for _ in pairs(loadedData.equippedTools) do
            equippedCount = equippedCount + 1
        end
    end
    
    print("📦 [RESTORE] Restauration pour", player.Name, "- Inventaire:", inventoryCount, "items | Équipés:", equippedCount, "items")
    
    -- 🔍 DEBUG: Afficher le contenu à restaurer
    if loadedData.inventory then
        print("🔍 [DEBUG] Contenu inventaire sauvegardé:")
        for itemKey, itemData in pairs(loadedData.inventory) do
            local sizeInfo = ""
            if itemData and itemData.sizeData then
                sizeInfo = " (" .. itemData.sizeData.rarity .. " " .. itemData.sizeData.size .. "x)"
            end
            print("  ➤", itemKey, ":", itemData.baseName, "x" .. itemData.quantity, sizeInfo)
        end
    end
    
    if loadedData.equippedTools then
        print("🔍 [DEBUG] Contenu outils équipés sauvegardés:")
        for itemKey, itemData in pairs(loadedData.equippedTools) do
            local sizeInfo = ""
            if itemData and itemData.sizeData then
                sizeInfo = " (" .. itemData.sizeData.rarity .. " " .. itemData.sizeData.size .. "x)"
            end
            print("  👍", itemKey, ":", itemData.baseName, "x" .. itemData.quantity, sizeInfo)
        end
    end
    
    local toolsToEquip = {} -- Liste des outils à équiper après restauration
    
    -- 🎒 Restaurer l'inventaire (backpack)
    if loadedData.inventory then
        print("🎒 [RESTORE] === RESTAURATION INVENTAIRE ===")
        local restoredCount = 0
        for itemKey, itemData in pairs(loadedData.inventory) do
            restoredCount = restoredCount + 1
            local baseName = itemData.baseName or itemKey
            local quantity = itemData.quantity or 1
            local isCandy = itemData.isCandy or false
            local sizeData = itemData.sizeData
            
            print("🔄 [RESTORE] Traitement inventaire", restoredCount .. "/" .. inventoryCount .. ":", itemKey)
            local success = restoreToolToBackpack(player, baseName, quantity, isCandy, sizeData)
            if not success then
                warn("❌ [RESTORE] Échec restauration item inventaire:", baseName, "x" .. quantity)
            end
        end
    end
    
    -- 🎯 Restaurer les outils équipés
    if loadedData.equippedTools then
        print("🎯 [RESTORE] === RESTAURATION OUTILS ÉQUIPÉS ===")
        local restoredCount = 0
        for itemKey, itemData in pairs(loadedData.equippedTools) do
            restoredCount = restoredCount + 1
            local baseName = itemData.baseName or itemKey
            local quantity = itemData.quantity or 1
            local isCandy = itemData.isCandy or false
            local sizeData = itemData.sizeData
            
            print("🔄 [RESTORE] Traitement équipé", restoredCount .. "/" .. equippedCount .. ":", itemKey)
            
            -- D'abord créer l'outil dans le backpack
            local success = restoreToolToBackpack(player, baseName, quantity, isCandy, sizeData)
            if success then
                -- Marquer pour équipement ultérieur
                table.insert(toolsToEquip, {baseName = baseName, sizeData = sizeData})
                print("🎯 [RESTORE] Outil équipé créé, sera équipé après restauration:", baseName)
            else
                warn("❌ [RESTORE] Échec restauration outil équipé:", baseName, "x" .. quantity)
            end
        end
    end
    
    -- 🎯 Équiper les outils qui étaient équipés
    if #toolsToEquip > 0 then
        print("🎯 [RESTORE] Équipement des outils restaurés...")
        task.wait(0.5) -- Laisser le temps aux outils d'être créés
        
        for _, toolInfo in pairs(toolsToEquip) do
            local toolToEquip = findToolInBackpack(player, toolInfo.baseName, toolInfo.sizeData)
            if toolToEquip then
                toolToEquip.Parent = player.Character
                print("✅ [RESTORE] Outil équipé:", toolInfo.baseName)
            else
                warn("⚠️ [RESTORE] Outil à équiper introuvable:", toolInfo.baseName)
            end
        end
    end
    
    print("✅ [RESTORE] Inventaire + équipement restaurés pour", player.Name)
    return true
end

-- Restauration de la production (plateformes)
function SaveDataManager.restoreProduction(player, loadedData)
    if not loadedData or not loadedData.productionData then
        -- Même si pas de plateformes, on peut tout de même appliquer l'offline incubateur si présent
        -- donc on ne return pas tout de suite; on gère incubateurs plus bas
    end
    local didSomething = false
    -- Plateformes
    if loadedData.productionData and _G.CandyPlatforms and _G.CandyPlatforms.restoreProductionForPlayer then
        _G.CandyPlatforms.restoreProductionForPlayer(player.UserId, loadedData.productionData)
        didSomething = true
    end
    
    -- Incubateurs: restauration de l'état
    if loadedData.incubatorProduction and _G.Incubator and _G.Incubator.restoreProductionForPlayer then
        _G.Incubator.restoreProductionForPlayer(player.UserId, loadedData.incubatorProduction)
        didSomething = true
    end
    
    -- Appliquer les gains hors-ligne (plateformes + incubateurs)
    local lastLogin = loadedData.lastLogin or os.time()
    local offlineSeconds = math.max(0, os.time() - lastLogin)
    if offlineSeconds > 0 then
        if _G.CandyPlatforms and _G.CandyPlatforms.applyOfflineEarningsForPlayer then
            _G.CandyPlatforms.applyOfflineEarningsForPlayer(player.UserId, offlineSeconds)
        end
        if _G.Incubator and _G.Incubator.applyOfflineForPlayer then
            -- Appliquer immédiatement
            _G.Incubator.applyOfflineForPlayer(player.UserId, offlineSeconds)
            -- Re-appliquer après des délais progressifs (map prête/téléports finis)
            for _, delaySec in ipairs({1.5, 3.0}) do
                task.delay(delaySec, function()
                    pcall(function()
                        if _G.Incubator and _G.Incubator.applyOfflineForPlayer then
                            _G.Incubator.applyOfflineForPlayer(player.UserId, offlineSeconds)
                        end
                    end)
                end)
            end
        end
    end
    
    if didSomething then
        print("✅ [RESTORE] Production (plateformes/incubateurs) restaurée pour", player.Name)
    end
    return didSomething
end

-- 🚨 FONCTION SPÉCIALE: Sauvegarde lors de la déconnexion avec déséquipement forcé
-- Cette fonction garantit que tous les outils en main sont déséquipés avant la sauvegarde
function SaveDataManager.savePlayerDataOnDisconnect(player)
    print("🚨 [DISCONNECT-SAVE] Sauvegarde de déconnexion pour", player.Name)
    
    -- 🎯 TENTATIVE PRECOCE: Essayer de déséquiper immédiatement, même avant les vérifications
    if player and player.Parent and player.Character then
        local equippedTools = {}
        for _, tool in pairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(equippedTools, tool)
            end
        end
        
        if #equippedTools > 0 then
            print("⚡ [DISCONNECT-SAVE] URGENCE: Déséquipement immédiat de", #equippedTools, "outil(s)")
            local backpack = player:FindFirstChildOfClass("Backpack")
            if backpack then
                for _, tool in pairs(equippedTools) do
                    local baseName = tool:GetAttribute("BaseName") or tool.Name
                    print("📤 [DISCONNECT-SAVE] Déplacement immédiat:", baseName)
                    tool.Parent = backpack
                end
                print("✅ [DISCONNECT-SAVE] Déséquipement immédiat réussi")
                task.wait(0.1) -- Petit délai pour que les changements prennent effet
            end
        end
    end
    
    -- 🎯 Déséquiper IMMÉDIATEMENT tous les outils (critique pour éviter la perte)
    local unequipSuccess = unequipAllTools(player)
    if unequipSuccess then
        print("✅ [DISCONNECT-SAVE] Outils déséquipés avec succès pour", player.Name)
    else
        print("ℹ️ [DISCONNECT-SAVE] Aucun outil à déséquiper pour", player.Name)
    end
    
    -- Délai supplémentaire pour garantir que les changements sont pris en compte
    task.wait(0.2)
    
    -- Procéder à la sauvegarde normale
    local saveSuccess = SaveDataManager.savePlayerData(player)
    
    if saveSuccess then
        print("✅ [DISCONNECT-SAVE] Sauvegarde de déconnexion réussie pour", player.Name)
    else
        warn("❌ [DISCONNECT-SAVE] Échec sauvegarde de déconnexion pour", player.Name)
    end
    
    return saveSuccess
end

-- Initialiser le système au chargement du module
if RunService:IsServer() then
    local success = initializeDataStores()
    if not success then
        warn("💥 [SAVE] Le système de sauvegarde ne sera pas disponible")
    end
end

return SaveDataManager