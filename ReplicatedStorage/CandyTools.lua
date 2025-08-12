-- CandyTools.lua
-- Centralise la gestion des bonbons stockés sous forme de Tool (stackables)
-- Placé dans ReplicatedStorage pour être accessible serveur & client

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dossier contenant les modèles 3D des Tools bonbons
local TOOL_TEMPLATES_FOLDER = ReplicatedStorage:WaitForChild("CandyModels")

-- Import du gestionnaire de tailles (si disponible)
local CandySizeManager
local success, result = pcall(function()
    return require(ReplicatedStorage:WaitForChild("CandySizeManager"))
end)
if success then
    CandySizeManager = result
    print("✅ CandySizeManager chargé avec succès")
else
    print("❌ Erreur chargement CandySizeManager:", result)
end

-- Fonction utilitaire pour mettre à jour les tailles découvertes dans le Pokédex
local function updatePokedexSizes(player, candyName, rarity)
    -- S'assurer que PlayerData existe (créer si manquant pour éviter les ratés de timing)
    local playerData = player:FindFirstChild("PlayerData")
    if not playerData then
        playerData = Instance.new("Folder")
        playerData.Name = "PlayerData"
        playerData.Parent = player
        print("🧩 [CandyTools] PlayerData créé pour Pokédex:", player.Name)
    end
    
    -- Créer ou récupérer le dossier PokedexSizes
    local pokedexSizes = playerData:FindFirstChild("PokedexSizes")
    if not pokedexSizes then
        pokedexSizes = Instance.new("Folder")
        pokedexSizes.Name = "PokedexSizes"
        pokedexSizes.Parent = playerData
        print("📚 Création du dossier PokedexSizes pour", player.Name)
    end
    
    -- Créer ou récupérer le dossier de la recette
    local recipeFolder = pokedexSizes:FindFirstChild(candyName)
    if not recipeFolder then
        recipeFolder = Instance.new("Folder")
        recipeFolder.Name = candyName
        recipeFolder.Parent = pokedexSizes
        print("📜 Création du dossier recette:", candyName)
    end
    
    -- Créer ou récupérer la BoolValue de la taille
    local sizeValue = recipeFolder:FindFirstChild(rarity)
    if not sizeValue then
        sizeValue = Instance.new("BoolValue")
        sizeValue.Name = rarity
        sizeValue.Value = true
        sizeValue.Parent = recipeFolder
        print("✨ NOUVELLE TAILLE DÉCOUVERTE:", player.Name, "a obtenu", candyName, "en taille", rarity)
    elseif not sizeValue.Value then
        sizeValue.Value = true
        print("✨ TAILLE RE-DÉCOUVERTE:", player.Name, "a re-obtenu", candyName, "en taille", rarity)
    end
end

local CandyTools = {}

-- Assure qu'un Tool du bonbon existe dans le backpack, sinon le clone
local function getOrCreateTool(player: Player, candyName: string)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")

    -- Chercher un Tool existant par son BaseName (nom de recette) pour le stacking
    -- Mais aussi vérifier la taille pour éviter de mélanger différentes raretés
    local tool = nil
    local targetSizeData = nil
    
    -- Récupérer la taille du bonbon qu'on veut ajouter
    if _G.currentPickupCandy then
        local size = _G.currentPickupCandy:FindFirstChild("CandySize")
        local rarity = _G.currentPickupCandy:FindFirstChild("CandyRarity")
        if size and rarity then
            targetSizeData = {
                size = size.Value,
                rarity = rarity.Value
            }
        end
    end
    
    for _, existingTool in pairs(backpack:GetChildren()) do
        if existingTool:IsA("Tool") then
            local baseName = existingTool:GetAttribute("BaseName")
            if baseName == candyName then
                -- Vérifier si les tailles/raretés correspondent pour le stacking
                if targetSizeData then
                    local existingSize = existingTool:GetAttribute("CandySize")
                    local existingRarity = existingTool:GetAttribute("CandyRarity")
                    
                    -- Stack uniquement si même rareté ET taille similaire (différence < 0.05)
                    if existingRarity == targetSizeData.rarity and 
                       existingSize and math.abs(existingSize - targetSizeData.size) < 0.05 then
                        tool = existingTool
                        print("⚙️ STACK IDENTIQUE:", candyName, "| Rareté:", targetSizeData.rarity, "| Taille:", targetSizeData.size)
                        break
                    else
                        print("🚫 PAS DE STACK:", candyName, "| Rareté diff:", existingRarity, "vs", targetSizeData.rarity, "| Taille diff:", existingSize, "vs", targetSizeData.size)
                    end
                else
                    -- Fallback pour bonbons sans data de taille
                    tool = existingTool
                    break
                end
            end
        end
    end
    if not tool then
        print("🔍 [DEBUG] Recherche template pour:", candyName)
        print("🔍 [DEBUG] Enfants dans CandyModels:")
        for i, child in ipairs(TOOL_TEMPLATES_FOLDER:GetChildren()) do
            print("  ", i, ":", child.Name, "(", child.ClassName, ")")
        end
        
        local template = TOOL_TEMPLATES_FOLDER:FindFirstChild(candyName)
        if not template then
            -- Essayer avec préfixe "Bonbon" + nom
            template = TOOL_TEMPLATES_FOLDER:FindFirstChild("Bonbon" .. candyName)
        end
        if not template then
            -- Essayer avec préfixe "Bonbon" + nom sans espaces
            local nameWithoutSpaces = candyName:gsub(" ", "")
            template = TOOL_TEMPLATES_FOLDER:FindFirstChild("Bonbon" .. nameWithoutSpaces)
        end
        if not template then
            -- Essayer de trouver par le nom de modèle dans RecipeManager
            local success, recipeManager = pcall(function()
                return require(ReplicatedStorage:WaitForChild("RecipeManager"))
            end)
            if success and recipeManager and recipeManager.Recettes then
                local recipeDef = recipeManager.Recettes[candyName]
                if recipeDef and recipeDef.modele then
                    template = TOOL_TEMPLATES_FOLDER:FindFirstChild(recipeDef.modele)
                    print("🔍 Recherche par modèle RecipeManager:", recipeDef.modele, template and "TROUVÉ" or "INTROUVABLE")
                end
            end
        end
        if not template then
            -- Chercher un Tool dont l'attribut BaseName correspond
            for _,child in ipairs(TOOL_TEMPLATES_FOLDER:GetChildren()) do
                if child:IsA("Tool") and child:GetAttribute("BaseName") == candyName then
                    template = child
                    break
                end
            end
        end
        if not template then
            warn("❌ TEMPLATE INTROUVABLE pour bonbon:", candyName, "- Création d'un Tool générique")
            
            -- Créer un Tool générique comme fallback
            local genericTool = Instance.new("Tool")
            genericTool.Name = candyName
            genericTool.RequiresHandle = false
            genericTool.ToolTip = "Bonbon: " .. candyName
            
            -- Ajouter une description basée sur la recette si disponible
            local success, recipeManager = pcall(function()
                return require(ReplicatedStorage:WaitForChild("RecipeManager"))
            end)
            if success and recipeManager and recipeManager.Recettes then
                local recipeDef = recipeManager.Recettes[candyName]
                if recipeDef then
                    genericTool.ToolTip = (recipeDef.emoji or "🍬") .. " " .. (recipeDef.nom or candyName)
                end
            end
            
            template = genericTool
            print("🔧 Tool générique créé pour:", candyName)
        end
        local cloned = template:Clone()
        -- Certains modèles sont des Model contenant un Tool : on récupère la vraie instance Tool
        local realTool = cloned:IsA("Tool") and cloned or cloned:FindFirstChildWhichIsA("Tool", true)
        
        -- Si c'est un Model sans Tool mais avec un Handle, on le convertit en Tool
        if not realTool and cloned:IsA("Model") then
            local handle = cloned:FindFirstChild("Handle")
            if handle then
                print("🔧 Conversion Model vers Tool pour:", candyName)
                local newTool = Instance.new("Tool")
                newTool.Name = cloned.Name
                newTool.ToolTip = "Bonbon: " .. candyName
                
                -- Déplacer toutes les parts du Model vers le Tool
                for _, child in pairs(cloned:GetChildren()) do
                    if child:IsA("BasePart") or child:IsA("UnionOperation") or child:IsA("WeldConstraint") then
                        child.Parent = newTool
                    end
                end
                
                realTool = newTool
                cloned:Destroy() -- Détruire l'ancien Model vide
            end
        end
        
        if not realTool then
            warn("❌ OUTIL INTROUVABLE dans le template pour bonbon:", candyName, "- Le modèle ne contient pas de Tool ni de Handle")
            return nil
        end
        -- Si un wrapper Model existe, on peut le détruire une fois la Tool récupérée
        if realTool ~= cloned then
            cloned:Destroy()
        end
        tool = realTool
        -- Utiliser le nom du modèle pour cohérence avec incubateur
        local modelName = candyName -- Par défaut
        local success, recipeManager = pcall(function()
            return require(ReplicatedStorage:WaitForChild("RecipeManager"))
        end)
        if success and recipeManager and recipeManager.Recettes then
            local recipeDef = recipeManager.Recettes[candyName]
            if recipeDef and recipeDef.modele then
                modelName = recipeDef.modele
            end
        end
        tool.Name = modelName -- nom du modèle pour cohérence
        tool:SetAttribute("BaseName", candyName) -- garder le nom de recette pour identification
        tool:SetAttribute("IsCandy", true) -- Marquer comme bonbon pour le BackpackVisual
        tool:SetAttribute("StackSize", 1) -- Taille initiale du stack
        
        print("🔧 CREATION BONBON:", candyName, "| Tool:", tool.Name)
        
        -- Appliquer la taille (générée ou depuis un modèle physique)
        if CandySizeManager then
            print("✅ CandySizeManager disponible, application taille...")
            
            -- Essayer de récupérer la taille depuis un modèle physique
            local sizeData = nil
            local physicalCandy = _G.currentPickupCandy -- Variable globale temporaire pour transférer les données
            
            if physicalCandy then
                -- Récupérer les données depuis le modèle physique
                local size = physicalCandy:FindFirstChild("CandySize")
                local rarity = physicalCandy:FindFirstChild("CandyRarity")
                local colorR = physicalCandy:FindFirstChild("CandyColorR")
                local colorG = physicalCandy:FindFirstChild("CandyColorG")
                local colorB = physicalCandy:FindFirstChild("CandyColorB")
                
                if size and rarity and colorR and colorG and colorB then
                    sizeData = {
                        size = size.Value,
                        rarity = rarity.Value,
                        color = Color3.fromRGB(colorR.Value, colorG.Value, colorB.Value)
                    }
                    print("📦 TRANSFERT depuis modèle physique:", sizeData.rarity, "| Taille:", sizeData.size)
                end
            end
            
            -- Fallback : générer aléatoirement si pas de données physiques
            if not sizeData then
                sizeData = CandySizeManager.generateRandomSize()
                print("🎲 Génération aléatoire:", sizeData.rarity, "| Taille:", sizeData.size)
            end
            
            -- Appliquer au Tool
            CandySizeManager.applySizeDataToTool(tool, sizeData)
            CandySizeManager.applySizeToModel(tool, sizeData)
            
            -- Mettre à jour le Pokédex avec la taille découverte
            if player then
                updatePokedexSizes(player, candyName, sizeData.rarity)
            end
            
            -- Afficher les infos finales
            print("🍭 TOOL CRÉÉ:", candyName, "|", CandySizeManager.getDisplayString(sizeData), "| Prix:", CandySizeManager.calculatePrice(candyName, sizeData) .. "$")
        else
            print("❌ CandySizeManager non disponible - pas de taille appliquée")
        end
        
        if tool:IsA("Tool") then
            tool.RequiresHandle = false -- permet l'affichage sans Handle
            tool.CanBeDropped = true    -- permet d'être lâché
            
            -- Configuration minimale du Tool + Debug collisions
            local handle = tool:FindFirstChild("Handle")
            if handle then
                
            else
                warn("[CandyTools] Aucun Handle trouvé dans", tool.Name)
            end
            
            -- FORCER la désactivation des collisions sur TOUTES les parts
            
            
            -- D'abord, lister TOUS les descendants
            
            for _, descendant in pairs(tool:GetDescendants()) do
                
            end
            
            -- Corriger la physique de TOUTES les parts
            local partCount = 0
            local handle = tool:FindFirstChild("Handle")
            
            for _, descendant in pairs(tool:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    partCount = partCount + 1
                    local oldSize = descendant.Size
                    local isHandle = (descendant == handle)
                    
                    -- Configuration physique anti-bug
                    descendant.CanCollide = false
                    descendant.Anchored = false
                    descendant.TopSurface = Enum.SurfaceType.Smooth
                    descendant.BottomSurface = Enum.SurfaceType.Smooth
                    
                    if not isHandle then
                        -- Pour les parts décoratives (non-Handle) : les rendre "fantomatiques"
                        descendant.Massless = true  -- Pas de masse = pas d'impact physique
                        descendant.CanTouch = false -- Pas de trigger de touch
                        -- Garder l'apparence normale
                        
                    else
                        -- Pour le Handle : le garder fonctionnel mais petit
                        descendant.Massless = false
                        descendant.CanTouch = true
                        descendant.Transparency = 1 -- Handle invisible
                        
                    end
                    
                    -- Nettoyage des proprietes physiques problématiques
                    local bodyMovers = {"BodyPosition", "BodyVelocity", "BodyAngularVelocity", "BodyThrust", "BodyForce"}
                    for _, bodyType in pairs(bodyMovers) do
                        local badBody = descendant:FindFirstChildOfClass(bodyType)
                        if badBody then
                            badBody:Destroy()
                            
                        end
                    end
                end
            end
            
            
            
            
        end
        tool.Parent = backpack
        -- Tool ajouté au Backpack
    end

        -- Garantit la présence de Count
    local count = tool:FindFirstChild("Count")
    if not count then
        if not tool or not tool.Parent then
            -- Tool invalide
            return nil
        end
        count = Instance.new("IntValue")
        count.Name = "Count"
        count.Value = 0
        count.Parent = tool
        -- Count créé
    end

    return tool, count
end

function CandyTools.giveCandy(player: Player, candyName: string, quantity: number?)
    quantity = quantity or 1
    if quantity <= 0 then return false end
    
    -- giveCandy called
    local tool, count = getOrCreateTool(player, candyName)
    if not tool then 
        -- Echec getOrCreateTool
        return false 
    end
    if not count then
        -- Count nil
        return false
    end
    
    count.Value += quantity
    -- Mettre à jour l'attribut StackSize pour le BackpackVisual
    tool:SetAttribute("StackSize", count.Value)
    -- giveCandy réussi
    return true
end

function CandyTools.removeCandy(player: Player, candyName: string, quantity: number?)
    quantity = quantity or 1
    if quantity <= 0 then return false end

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    -- Chercher un Tool existant par son BaseName pour la suppression
    local tool = nil
    for _, existingTool in pairs(backpack:GetChildren()) do
        if existingTool:IsA("Tool") and existingTool:GetAttribute("BaseName") == candyName then
            tool = existingTool
            break
        end
    end
    if not tool then return false end

    local count = tool:FindFirstChild("Count")
    if not count or count.Value < quantity then return false end

    count.Value -= quantity
    if count.Value <= 0 then
        tool:Destroy()
    else
        -- Mettre à jour l'attribut StackSize pour le BackpackVisual
        tool:SetAttribute("StackSize", count.Value)
    end

    return true
end

function CandyTools.countCandy(player: Player, candyName: string)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end

    local tool = backpack:FindFirstChild(candyName)
    if not tool then return 0 end
    local count = tool:FindFirstChild("Count")
    return count and count.Value or 0
end

return CandyTools
