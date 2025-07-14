-- UIUtils.lua
-- Module utilitaire pour les interfaces

local UIUtils = {}

-- Fonction pour configurer un ViewportFrame avec un modèle 3D
function UIUtils.setupViewportFrame(viewportFrame, model)
    if not viewportFrame or not model then 
        return 
    end
    
    -- Cloner le modèle pour l'affichage
    local clone = model:Clone()
    clone.Parent = viewportFrame
    
    -- Créer une caméra pour le viewport
    local camera = Instance.new("Camera")
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera
    
    -- Positionner la caméra pour bien voir le modèle (zoom TRÈS proche pour les slots)
    if clone:IsA("BasePart") then
        local size = clone.Size
        local distance = math.max(size.X, size.Y, size.Z) * 0.4 -- Zoom encore plus proche
        camera.CFrame = CFrame.new(clone.Position + Vector3.new(distance, distance, distance), clone.Position)
    else
        -- Si c'est un modèle, prendre le centre
        local cf, size = clone:GetBoundingBox()
        local distance = math.max(size.X, size.Y, size.Z) * 0.4 -- Zoom encore plus proche  
        camera.CFrame = CFrame.new(cf.Position + Vector3.new(distance, distance, distance), cf.Position)
    end
end

-- Fonction pour créer un ViewportFrame d'ingrédient avec icône 3D
function UIUtils.createIngredientIcon(parent, ingredientNom, size, position)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    -- Créer le ViewportFrame
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = size or UDim2.new(0, 32, 0, 32)
    viewport.Position = position or UDim2.new(0, 0, 0, 0)
    viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115) -- Couleur bois clair
    viewport.BorderSizePixel = 0
    viewport.Parent = parent
    
    -- Bordures arrondies
    local corner = Instance.new("UICorner", viewport)
    corner.CornerRadius = UDim.new(0, 4)
    
    -- Bordure
    local stroke = Instance.new("UIStroke", viewport)
    stroke.Color = Color3.fromRGB(87, 60, 34) -- Marron foncé
    stroke.Thickness = 2
    
    -- Chercher le modèle d'ingrédient
    local ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
    if ingredientToolFolder then
        local ingredientTool = ingredientToolFolder:FindFirstChild(ingredientNom)
        if ingredientTool and ingredientTool:FindFirstChild("Handle") then
            UIUtils.setupViewportFrame(viewport, ingredientTool.Handle)
        else
            -- Fallback: afficher le nom si pas de modèle 3D
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = ingredientNom
            label.TextColor3 = Color3.new(1, 1, 1)
            label.TextScaled = true
            label.Font = Enum.Font.GothamBold
            label.Parent = viewport
        end
    end
    
    return viewport
end

return UIUtils 