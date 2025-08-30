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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration du DataStore
local DATASTORE_NAME = "SweetyScriptPlayerData_v1.3" -- Nouvelle version pour les tailles
local SAVE_VERSION = "1.3.0" -- Version avec support amélioré des tailles de bonbons

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
        return compressedData
    end
    
    local success, decodedData = pcall(function()
        return game:GetService("HttpService"):JSONDecode(compressedData.data)
    end)
    
    if not success then
        warn("⚠️ [SAVE] Erreur de décompression:", decodedData)
        return compressedData
    end
    
    return decodedData
end

-- Fonction pour sérialiser l'inventaire (Tools avec quantités ET tailles de bonbons)
local function serializeInventory(player)
    local inventoryData = {}
    local backpack = player:FindFirstChildOfClass("Backpack")
    
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = tool:GetAttribute("BaseName") or tool.Name
                local count = tool:FindFirstChild("Count")
                local quantity = count and count.Value or 1
                local isCandy = tool:GetAttribute("IsCandy") or false
                
                -- 🍬 NOUVEAU: Capturer les données de taille des bonbons
                local sizeData = nil
                if isCandy then
                    local candySize = tool:GetAttribute("CandySize")
                    local candyRarity = tool:GetAttribute("CandyRarity")
                    local colorR = tool:GetAttribute("CandyColorR")
                    local colorG = tool:GetAttribute("CandyColorG")
                    local colorB = tool:GetAttribute("CandyColorB")
                    
                    if candySize and candyRarity then
                        sizeData = {
                            size = candySize,
                            rarity = candyRarity,
                            colorR = colorR or 255,
                            colorG = colorG or 255,
                            colorB = colorB or 255
                        }
                        print("💾 [SAVE] Taille capturée:", baseName, "|", candyRarity, "|", candySize .. "x")
                    end
                end
                
                -- Créer une clé unique basée sur le nom ET la taille (pour les bonbons)
                local itemKey = baseName
                if sizeData then
                    -- Ajouter la rareté et taille à la clé pour éviter de mélanger les tailles
                    itemKey = baseName .. "_" .. sizeData.rarity .. "_" .. tostring(sizeData.size)
                end
                
                -- Grouper les items par clé unique
                if inventoryData[itemKey] then
                    inventoryData[itemKey].quantity = inventoryData[itemKey].quantity + quantity
                else
                    inventoryData[itemKey] = {
                        baseName = baseName,
                        quantity = quantity,
                        isCandy = isCandy,
                        toolName = tool.Name,
                        sizeData = sizeData -- 🍬 Inclure les données de taille
                    }
                end
            end
        end
    end
    
    -- Inclure l'outil équipé si il y en a un
    if player.Character then
        for _, tool in pairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = tool:GetAttribute("BaseName") or tool.Name
                local count = tool:FindFirstChild("Count")
                local quantity = count and count.Value or 1
                local isCandy = tool:GetAttribute("IsCandy") or false
                
                -- 🍬 Capturer les données de taille pour l'outil équipé aussi
                local sizeData = nil
                if isCandy then
                    local candySize = tool:GetAttribute("CandySize")
                    local candyRarity = tool:GetAttribute("CandyRarity")
                    local colorR = tool:GetAttribute("CandyColorR")
                    local colorG = tool:GetAttribute("CandyColorG")
                    local colorB = tool:GetAttribute("CandyColorB")
                    
                    if candySize and candyRarity then
                        sizeData = {
                            size = candySize,
                            rarity = candyRarity,
                            colorR = colorR or 255,
                            colorG = colorG or 255,
                            colorB = colorB or 255
                        }
                    end
                end
                
                local itemKey = baseName
                if sizeData then
                    itemKey = baseName .. "_" .. sizeData.rarity .. "_" .. tostring(sizeData.size)
                end
                
                if inventoryData[itemKey] then
                    inventoryData[itemKey].quantity = inventoryData[itemKey].quantity + quantity
                else
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
    end
    
    return inventoryData
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
    
    -- Créer la structure de données à sauvegarder
    local saveData = {
        version = SAVE_VERSION,
        timestamp = os.time(),
        playerId = player.UserId,
        playerName = player.Name,
        
        -- Données principales
        money = 0,
        inventory = {},
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
        productionData = {},
        
        -- Métadonnées
        playTime = 0,
        lastLogin = os.time()
    }
    
    -- Sauvegarder l'argent
    local argentValue = playerData:FindFirstChild("Argent")
    if argentValue then
        saveData.money = argentValue.Value
    end
    
    -- Sauvegarder l'inventaire
    saveData.inventory = serializeInventory(player)
    
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
    
    -- Tentatives de sauvegarde avec retry
    for attempt = 1, CONFIG.MAX_RETRIES do
        local success, errorMessage = pcall(function()
            playerDataStore:SetAsync(dataKey, finalData)
        end)
        
        if success then
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
    
    -- 🔄 MIGRATION: Convertir ancien format vers nouveau format
    if loadedData.version and loadedData.version < "1.3.0" then
        print("🔄 [MIGRATE] Migration des données de", loadedData.version, "vers 1.3.0 pour", player.Name)
        loadedData = migrateOldSaveData(loadedData)
    end
    
    print("📥 [LOAD] Données chargées pour", player.Name, "- Version:", loadedData.version or "inconnue")
    return loadedData
end

-- Fonction pour migrer les anciens formats de sauvegarde
local function migrateOldSaveData(oldData)
    local newData = oldData
    
    -- Mise à jour de la version
    newData.version = SAVE_VERSION
    
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
                    sizeData = nil -- Pas de données de taille dans l'ancien format
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

-- Fonction pour restaurer l'inventaire (appelée séparément après le chargement)
function SaveDataManager.restoreInventory(player, loadedData)
    if not loadedData or not loadedData.inventory then
        print("📦 [RESTORE] Aucun inventaire à restaurer pour", player.Name)
        return false
    end
    
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("⚠️ [RESTORE] Backpack manquant pour", player.Name)
        return false
    end
    
    -- 🚨 CRITIQUE: Vider complètement l'inventaire avant restauration
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
    
    -- Charger les modules nécessaires
    local CandyTools = require(ReplicatedStorage:WaitForChild("CandyTools"))
    local ingredientToolsFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
    
    -- Compter le nombre d'items à restaurer (correctement)
    local itemCount = 0
    for _ in pairs(loadedData.inventory) do
        itemCount = itemCount + 1
    end
    
    print("📦 [RESTORE] Restauration de l'inventaire pour", player.Name, "- Items à restaurer:", itemCount)
    
    -- 🔍 DEBUG: Afficher le contenu de l'inventaire sauvegardé
    print("🔍 [DEBUG] Contenu inventaire sauvegardé:")
    for itemKey, itemData in pairs(loadedData.inventory) do
        local sizeInfo = ""
        if itemData.sizeData then
            sizeInfo = " (" .. itemData.sizeData.rarity .. " " .. itemData.sizeData.size .. "x)"
        end
        print("  ➤", itemKey, ":", itemData.baseName or itemKey, "x" .. (itemData.quantity or 1), sizeInfo)
    end
    
    -- Restaurer chaque item de l'inventaire
    local restoredCount = 0
    for itemKey, itemData in pairs(loadedData.inventory) do
        restoredCount = restoredCount + 1
        local baseName = itemData.baseName or itemKey -- Compatibilité ancien format
        local quantity = itemData.quantity or 1
        local isCandy = itemData.isCandy or false
        local sizeData = itemData.sizeData -- 🍬 Nouvelles données de taille
        
        print("🔄 [RESTORE] Traitement item", restoredCount .. "/" .. itemCount .. ":", itemKey)
        print("  ℹ️ BaseName:", baseName, "| Quantity:", quantity, "| IsCandy:", isCandy)
        if sizeData then
            print("  🍬 Size Data:", sizeData.rarity, "|", sizeData.size .. "x", "| Colors:", sizeData.colorR, sizeData.colorG, sizeData.colorB)
        else
            print("  ⚠️ Pas de données de taille")
        end
        
        if isCandy then
            -- 🍬 NOUVEAU: Pré-configurer les données de taille pour CandyTools
            if sizeData then
                -- Utiliser une variable globale temporaire pour transférer les données de taille
                _G.restoreCandyData = {
                    size = sizeData.size,
                    rarity = sizeData.rarity,
                    color = Color3.fromRGB(sizeData.colorR or 255, sizeData.colorG or 255, sizeData.colorB or 255)
                }
                print("📋 [RESTORE] Configuration taille pour:", baseName, "|", sizeData.rarity, "|", sizeData.size .. "x")
            else
                _G.restoreCandyData = nil
                print("⚠️ [RESTORE] Pas de données de taille - génération aléatoire")
            end
            
            -- Utiliser CandyTools pour restaurer les bonbons avec données de taille
            print("🍬 [RESTORE] Appel CandyTools.giveCandy pour:", baseName, "x" .. quantity)
            local success = CandyTools.giveCandy(player, baseName, quantity)
            
            -- Nettoyer la variable temporaire
            _G.restoreCandyData = nil
            
            if success then
                print("✅ [RESTORE] Bonbon restauré:", baseName, "x" .. quantity, sizeData and ("(" .. sizeData.rarity .. " " .. sizeData.size .. "x)") or "")
                
                -- Vérifier que la taille a été correctement appliquée
                task.wait(0.1)
                local backpack = player:FindFirstChildOfClass("Backpack")
                if backpack then
                    for _, tool in pairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("BaseName") == baseName then
                            local appliedSize = tool:GetAttribute("CandySize")
                            local appliedRarity = tool:GetAttribute("CandyRarity")
                            print("🔍 [VERIFY] Tool créé:", tool.Name, "| Applied Size:", appliedSize, "| Applied Rarity:", appliedRarity)
                            break
                        end
                    end
                end
            else
                warn("❌ [RESTORE] Échec restauration bonbon:", baseName, "x" .. quantity)
            end
        else
            -- Restaurer les ingrédients
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
                else
                    warn("❌ [RESTORE] Template introuvable pour:", baseName)
                end
            end
        end
    end
    
    print("✅ [RESTORE] Inventaire restauré pour", player.Name)
    return true
end

-- Fonction pour obtenir des statistiques de sauvegarde
function SaveDataManager.getPlayerStats(player)
    local dataKey = tostring(player.UserId)
    return {
        lastSaveTime = lastSaveTime[dataKey],
        hasCachedData = dataCache[dataKey] ~= nil,
        saveVersion = SAVE_VERSION
    }
end

-- Initialiser le système au chargement du module
if RunService:IsServer() then
    local success = initializeDataStores()
    if not success then
        warn("💥 [SAVE] Le système de sauvegarde ne sera pas disponible")
    end
end

return SaveDataManager