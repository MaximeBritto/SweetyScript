--[[
    🏭 SCRIPT HELPER: Configurer les IDs des Incubateurs
    
    Ce script ajoute automatiquement un attribut "IncubatorID" unique à chaque incubateur
    pour permettre le tracking des bonbons créés par chaque incubateur.
    
    UTILISATION:
    1. Colle ce script dans ServerScriptService
    2. Lance le jeu
    3. Les IDs seront configurés automatiquement
    4. Supprime ce script après utilisation
    
    OU utilise la fonction manuelle:
    _G.SetupIncubatorIDs()
--]]

local Workspace = game:GetService("Workspace")

-- Fonction pour trouver tous les incubateurs (via les Parcels)
local function findAllIncubators()
    local incubators = {}
    
    print("🔍 [INCUBATOR-ID] Recherche des Parcels dans le Workspace...")
    
    -- Chercher tous les Parcels (Parcel_1, Parcel_2, etc.)
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name:match("^Parcel_") then
            print("   📦 Parcel trouvé:", obj.Name)
            
            -- Chercher l'IncubatorMesh dans ce Parcel
            local incubatorMesh = obj:FindFirstChild("IncubatorMesh")
            if incubatorMesh then
                table.insert(incubators, incubatorMesh)
                print("      ✅ IncubatorMesh trouvé dans", obj.Name)
            else
                print("      ⚠️ Pas d'IncubatorMesh dans", obj.Name)
            end
        end
    end
    
    if #incubators == 0 then
        warn("⚠️ [INCUBATOR-ID] Aucun incubateur trouvé!")
        warn("⚠️ [INCUBATOR-ID] Vérifie que tes Parcels contiennent bien un 'IncubatorMesh'")
    else
        print("🏭 [INCUBATOR-ID] Trouvé", #incubators, "incubateur(s)")
    end
    
    return incubators
end

-- Fonction pour générer un ID unique basé sur la position de l'incubateur
local function generateIncubatorID(incubator, index)
    -- Essayer de trouver le ParcelID dans le parent (Parcel)
    local parent = incubator.Parent
    if parent then
        local parcelID = parent:FindFirstChild("ParcelID")
        if parcelID and parcelID:IsA("StringValue") and parcelID.Value ~= "" then
            return parcelID.Value
        end
        
        -- Utiliser le nom du Parcel comme ID
        if parent.Name:match("^Parcel_") then
            return parent.Name
        end
    end
    
    -- Sinon, utiliser la position de l'incubateur
    if incubator:IsA("BasePart") then
        local pos = incubator.Position
        -- Format: "Inc_X_Y_Z" (arrondi à l'unité)
        return string.format("Inc_%d_%d_%d", 
            math.floor(pos.X + 0.5), 
            math.floor(pos.Y + 0.5), 
            math.floor(pos.Z + 0.5)
        )
    end
    
    -- Fallback: utiliser l'index
    return "Incubator_" .. tostring(index)
end

-- Fonction principale pour configurer tous les IDs
local function setupAllIncubatorIDs()
    print("🚀 [INCUBATOR-ID] Début de la configuration des IDs...")
    
    local incubators = findAllIncubators()
    local configuredCount = 0
    local skippedCount = 0
    
    for index, incubator in ipairs(incubators) do
        -- Vérifier si l'ID existe déjà
        local existingID = incubator:GetAttribute("IncubatorID")
        
        if existingID and existingID ~= "" then
            print("⚠️ [INCUBATOR-ID] ID déjà configuré:", existingID)
            skippedCount = skippedCount + 1
        else
            -- Générer et assigner un nouvel ID
            local newID = generateIncubatorID(incubator, index)
            incubator:SetAttribute("IncubatorID", newID)
            print("✅ [INCUBATOR-ID] ID configuré:", newID)
            configuredCount = configuredCount + 1
        end
    end
    
    print("🏁 [INCUBATOR-ID] Terminé!")
    print("   ✅ Configurés:", configuredCount)
    print("   ⚠️ Ignorés:", skippedCount)
    print("   📊 Total incubateurs:", #incubators)
    
    return configuredCount, skippedCount
end

-- Fonction pour lister tous les IDs d'incubateurs
local function listAllIncubatorIDs()
    print("📋 [INCUBATOR-ID] Liste des IDs d'incubateurs:")
    
    local incubators = findAllIncubators()
    local idsFound = {}
    
    for _, incubator in ipairs(incubators) do
        local id = incubator:GetAttribute("IncubatorID")
        if id then
            table.insert(idsFound, id)
            print("   🏭", id)
        else
            print("   ⚠️ Incubateur sans ID à", incubator:GetPivot().Position)
        end
    end
    
    print("📊 Total IDs trouvés:", #idsFound)
    return idsFound
end

-- Fonction pour réinitialiser tous les IDs (utile pour reset)
local function resetAllIncubatorIDs()
    print("🗑️ [INCUBATOR-ID] Réinitialisation de tous les IDs...")
    
    local incubators = findAllIncubators()
    local resetCount = 0
    
    for _, incubator in ipairs(incubators) do
        local existingID = incubator:GetAttribute("IncubatorID")
        if existingID then
            incubator:SetAttribute("IncubatorID", nil)
            resetCount = resetCount + 1
        end
    end
    
    print("✅ [INCUBATOR-ID] Réinitialisé", resetCount, "ID(s)")
    return resetCount
end

-- Fonction pour vérifier les doublons d'IDs
local function checkForDuplicateIDs()
    print("🔍 [INCUBATOR-ID] Vérification des doublons...")
    
    local incubators = findAllIncubators()
    local idCounts = {}
    local duplicates = {}
    
    for _, incubator in ipairs(incubators) do
        local id = incubator:GetAttribute("IncubatorID")
        if id then
            idCounts[id] = (idCounts[id] or 0) + 1
            if idCounts[id] > 1 then
                table.insert(duplicates, id)
            end
        end
    end
    
    if #duplicates > 0 then
        warn("⚠️ [INCUBATOR-ID] Doublons détectés:")
        for _, id in ipairs(duplicates) do
            warn("   ❌", id, "utilisé", idCounts[id], "fois")
        end
        return false
    else
        print("✅ [INCUBATOR-ID] Aucun doublon détecté")
        return true
    end
end

-- Exposer les fonctions globalement pour utilisation manuelle
_G.SetupIncubatorIDs = setupAllIncubatorIDs
_G.ListIncubatorIDs = listAllIncubatorIDs
_G.ResetIncubatorIDs = resetAllIncubatorIDs
_G.CheckDuplicateIncubatorIDs = checkForDuplicateIDs

-- Exécution automatique au démarrage
print("🏭 [INCUBATOR-ID] Script chargé!")
print("📝 Commandes disponibles:")
print("   _G.SetupIncubatorIDs()           - Configurer les IDs des incubateurs")
print("   _G.ListIncubatorIDs()            - Lister tous les IDs")
print("   _G.ResetIncubatorIDs()           - Réinitialiser tous les IDs")
print("   _G.CheckDuplicateIncubatorIDs()  - Vérifier les doublons")

-- 🚀 Exécution automatique après 5 secondes
task.wait(5)
print("🚀 [INCUBATOR-ID] Démarrage automatique de la configuration...")
setupAllIncubatorIDs()
task.wait(1)
checkForDuplicateIDs()
