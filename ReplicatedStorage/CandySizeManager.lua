-- CandySizeManager.lua
-- Gère les tailles variables des bonbons et leurs prix

local CandySizeManager = {}

-- Configuration des tailles et probabilités (plages plus dramatiques)
local SIZE_CONFIG = {
    -- Tailles et leurs probabilités (total = 100%)
    {minSize = 0.50, maxSize = 0.75, probability = 8,  rarity = "Minuscule", color = Color3.fromRGB(150, 150, 150)}, -- Gris
    {minSize = 0.75, maxSize = 0.90, probability = 15, rarity = "Petit", color = Color3.fromRGB(255, 200, 100)}, -- Jaune pâle
    {minSize = 0.90, maxSize = 1.10, probability = 50, rarity = "Normal", color = Color3.fromRGB(255, 255, 255)}, -- Blanc
    {minSize = 1.15, maxSize = 1.50, probability = 20, rarity = "Grand", color = Color3.fromRGB(100, 255, 100)}, -- Vert
    {minSize = 1.50, maxSize = 2.20, probability = 5,  rarity = "Géant", color = Color3.fromRGB(100, 200, 255)}, -- Bleu
    {minSize = 2.20, maxSize = 3.50, probability = 1.8, rarity = "Colossal", color = Color3.fromRGB(255, 100, 255)}, -- Magenta
    {minSize = 3.50, maxSize = 5.00, probability = 0.2, rarity = "LÉGENDAIRE", color = Color3.fromRGB(255, 215, 0)} -- Or
}

-- Fonction pour obtenir le prix de base d'un bonbon depuis RecipeManager
local function getBasePriceFromRecipeManager(candyName)
    local success, recipeManager = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        return require(ReplicatedStorage:WaitForChild("RecipeManager"))
    end)
    
    if success and recipeManager and recipeManager.Recettes then
        -- Chercher le bonbon par son nom de recette
        for recipeName, recipeData in pairs(recipeManager.Recettes) do
            if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
                return recipeData.valeur or 15 -- valeur = prix de vente
            end
        end
    end
    
    -- Prix par défaut si pas trouvé
    return 15
end

-- Génère une taille aléatoire selon les probabilités
function CandySizeManager.generateRandomSize(forceRarity)
    local random = math.random(1, 1000) -- Utilise 1000 pour plus de précision
    local cumulativeProbability = 0
    
    for _, config in ipairs(SIZE_CONFIG) do
        if not forceRarity or config.rarity == tostring(forceRarity) then
            cumulativeProbability = cumulativeProbability + (config.probability * 10) -- *10 pour ajuster à 1000
            if random <= cumulativeProbability then
                -- Générer une taille dans la plage avec plus de précision
                local randomValue = math.random()
                local size = randomValue * (config.maxSize - config.minSize) + config.minSize
                local finalSize = math.floor(size * 1000) / 1000 -- Arrondir à 3 décimales pour plus de variation
                
                -- Debug détaillé
                print("🎲 Génération:", config.rarity, "| Random:", randomValue, "| Plage:", config.minSize .. "-" .. config.maxSize, "| Taille finale:", finalSize)
                
                return {
                    size = finalSize,
                    rarity = config.rarity,
                    color = config.color,
                    config = config
                }
            end
        end
    end
    
    -- Fallback (ne devrait jamais arriver)
    return {
        size = 1.0,
        rarity = "Normal",
        color = Color3.fromRGB(255, 255, 255),
        config = SIZE_CONFIG[3]
    }
end

-- Calcule le prix d'un bonbon selon sa taille
function CandySizeManager.calculatePrice(candyName, sizeData)
    local basePrice = getBasePriceFromRecipeManager(candyName)
    local sizeMultiplier = sizeData.size ^ 2.5 -- Progression exponentielle
    
    -- Bonus de rareté
    local rarityBonus = 1
    if sizeData.rarity == "Géant" then rarityBonus = 1.2
    elseif sizeData.rarity == "Colossal" then rarityBonus = 1.5
    elseif sizeData.rarity == "LÉGENDAIRE" then rarityBonus = 2.0
    end
    
    local finalPrice = math.floor(basePrice * sizeMultiplier * rarityBonus)
    return math.max(finalPrice, 1) -- Minimum 1$
end

-- Obtient les informations de taille depuis les attributs d'un Tool
function CandySizeManager.getSizeDataFromTool(tool)
    if not tool then return nil end
    
    local size = tool:GetAttribute("CandySize") or 1.0
    local rarity = tool:GetAttribute("CandyRarity") or "Normal"
    local colorR = tool:GetAttribute("CandyColorR") or 255
    local colorG = tool:GetAttribute("CandyColorG") or 255  
    local colorB = tool:GetAttribute("CandyColorB") or 255
    
    return {
        size = size,
        rarity = rarity,
        color = Color3.fromRGB(colorR, colorG, colorB)
    }
end

-- Applique les données de taille à un Tool
function CandySizeManager.applySizeDataToTool(tool, sizeData)
    if not tool or not sizeData then return end
    
    -- Sauvegarder dans les attributs
    tool:SetAttribute("CandySize", sizeData.size)
    tool:SetAttribute("CandyRarity", sizeData.rarity)
    tool:SetAttribute("CandyColorR", math.floor(sizeData.color.R * 255))
    tool:SetAttribute("CandyColorG", math.floor(sizeData.color.G * 255))
    tool:SetAttribute("CandyColorB", math.floor(sizeData.color.B * 255))
end

-- Applique la taille visuelle au modèle 3D du bonbon
function CandySizeManager.applySizeToModel(model, sizeData)
    if not model or not sizeData then 
        print("❌ applySizeToModel: modèle ou sizeData manquant")
        return 
    end
    
    print("🔍 Recherche partie à redimensionner dans:", model.Name, "| Type:", model.ClassName)
    
    -- Chercher la partie principale du bonbon avec plus de debug
    local bonbonPart = model:FindFirstChild("BonbonSkin") or model:FindFirstChild("Handle")
    
    -- Si pas trouvé, chercher toutes les BasePart dans le Tool
    if not bonbonPart and model:IsA("Tool") then
        for _, child in pairs(model:GetDescendants()) do
            if child:IsA("BasePart") and child.Name ~= "Handle" then
                bonbonPart = child
                print("🔍 Partie trouvée:", child.Name, "| Taille actuelle:", child.Size)
                break
            end
        end
    end
    
    -- Fallback sur le model lui-même s'il est une BasePart
    if not bonbonPart and model:IsA("BasePart") then
        bonbonPart = model
    end
    
    if bonbonPart and bonbonPart:IsA("BasePart") then
        -- Sauvegarder la taille originale si pas déjà fait
        local originalSizeX = bonbonPart:GetAttribute("OriginalSizeX")
        local originalSizeY = bonbonPart:GetAttribute("OriginalSizeY")
        local originalSizeZ = bonbonPart:GetAttribute("OriginalSizeZ")
        
        if not originalSizeX then
            -- Première fois : sauvegarder les dimensions originales
            bonbonPart:SetAttribute("OriginalSizeX", bonbonPart.Size.X)
            bonbonPart:SetAttribute("OriginalSizeY", bonbonPart.Size.Y)
            bonbonPart:SetAttribute("OriginalSizeZ", bonbonPart.Size.Z)
            originalSizeX = bonbonPart.Size.X
            originalSizeY = bonbonPart.Size.Y
            originalSizeZ = bonbonPart.Size.Z
        end
        
        -- Appliquer le facteur de taille aux dimensions originales
        bonbonPart.Size = Vector3.new(
            originalSizeX * sizeData.size,
            originalSizeY * sizeData.size,
            originalSizeZ * sizeData.size
        )
        
        -- Debug pour voir la taille appliquée
        print("📜 Taille appliquée:", bonbonPart.Name, "facteur:", sizeData.size, "nouvelle size:", bonbonPart.Size)
        
        -- Effet visuel de rareté (particules, glow, etc.)
        if sizeData.rarity ~= "Normal" then
            CandySizeManager.addVisualEffects(bonbonPart, sizeData)
        end
    else
        print("❌ Aucune partie à redimensionner trouvée dans:", model.Name)
        -- Lister toutes les parties pour debug
        for _, child in pairs(model:GetDescendants()) do
            if child:IsA("BasePart") then
                print("  - Partie disponible:", child.Name, "Type:", child.ClassName, "Taille:", child.Size)
            end
        end
    end
end

-- Ajoute des effets visuels selon la rareté
function CandySizeManager.addVisualEffects(part, sizeData)
    -- Supprimer les anciens effets
    for _, child in pairs(part:GetChildren()) do
        if child.Name:find("RarityEffect") then
            child:Destroy()
        end
    end
    
    -- Effet de glow pour les bonbons rares
    if sizeData.rarity == "Géant" or sizeData.rarity == "Colossal" or sizeData.rarity == "LÉGENDAIRE" then
        local pointLight = Instance.new("PointLight")
        pointLight.Name = "RarityEffectLight"
        pointLight.Color = sizeData.color
        pointLight.Brightness = sizeData.rarity == "LÉGENDAIRE" and 2 or 1
        pointLight.Range = sizeData.size * 5
        pointLight.Parent = part
    end
    
    -- Particules pour les légendaires
    if sizeData.rarity == "LÉGENDAIRE" then
        local attachment = Instance.new("Attachment")
        attachment.Name = "RarityEffectAttachment"
        attachment.Parent = part
        
        local sparkles = Instance.new("Sparkles")
        sparkles.Name = "RarityEffectSparkles"
        sparkles.SparkleColor = sizeData.color
        sparkles.Parent = part
    end
end

-- Obtient une chaîne formatée pour afficher la taille et rareté
function CandySizeManager.getDisplayString(sizeData)
    local sizePercent = math.floor(sizeData.size * 100)
    return string.format("%s (%d%%)", sizeData.rarity, sizePercent)
end

return CandySizeManager
