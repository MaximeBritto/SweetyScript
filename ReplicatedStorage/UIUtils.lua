-- UIUtils.lua
-- Module utilitaire pour les interfaces

local UIUtils = {}

-- Formatte un nombre avec suffixes K/M/B/T à partir de 100k
function UIUtils.formatMoneyShort(n)
    n = tonumber(n) or 0
    local absn = math.abs(n)
    if absn < 100000 then
        return tostring(n)
    end
    -- Suffixes étendus: k, m, b, t, qa, qi, sx, sp, oc, no, de, ud, dd, td, qd, qid, sd, spd, od, nd, v, uv
    local SUFFIXES = {
        "k","m","b","t","qa","qi","sx","sp","oc","no",
        "de","ud","dd","td","qd","qid","sd","spd","od","nd",
        "vg","uvg","dvg","tvg","qavg","qivg","sxvg","spvg","ocvg","novg"
    }
    local tier = 0
    local v = n
    while math.abs(v) >= 1000 and tier < #SUFFIXES do
        v = v / 1000
        tier = tier + 1
    end
    if tier == 0 then
        return tostring(n)
    end
    local function roundForDisplay(x)
        local ax = math.abs(x)
        if ax < 10 then
            return math.floor(x * 10 + 0.5) / 10
        else
            return math.floor(x + 0.5)
        end
    end
    local r = roundForDisplay(v)
    -- Si l'arrondi dépasse 1000, passer au suffixe supérieur
    if math.abs(r) >= 1000 and tier < #SUFFIXES then
        r = r / 1000
        tier = tier + 1
        r = roundForDisplay(r)
    end
    local suffix = SUFFIXES[tier]
    -- Format avec 1 décimale si <10, sinon entier
    local text
    if math.abs(r) < 10 and math.abs(r) ~= math.floor(math.abs(r)) then
        text = string.format("%.1f%s", r, suffix)
    else
        text = string.format("%d%s", math.floor(r + (r >= 0 and 0.0 or 0.0)), suffix)
    end
    return text
end

-- Place la caméra pour que tout le modèle tienne dans le viewport, sans zoom excessif
local function positionCameraToFit(viewportFrame, camera, root)
    camera.FieldOfView = 40
    local center
    local size
    if root:IsA("BasePart") then
        center = root.Position
        size = root.Size
    else
        local cf, sz = root:GetBoundingBox()
        center, size = cf.Position, sz
    end
    -- Rayon de la sphère englobante
    local radius = (size.Magnitude) * 0.5
    -- Distance minimale pour contenir le rayon à la FOV choisie
    local distance = (radius / math.tan(math.rad(camera.FieldOfView * 0.5))) * 1.25 -- marge 25%
    local dir = Vector3.new(1, 0.8, 1).Unit
    camera.CFrame = CFrame.new(center + dir * distance, center)
end

-- Fonction pour configurer un ViewportFrame avec un modèle 3D
function UIUtils.setupViewportFrame(viewportFrame, model)
    if not viewportFrame or not model then 
        return 
    end
    
    -- Cloner le modèle pour l'affichage
    local clone = model:Clone()
    clone.Parent = viewportFrame
    
    -- Créer une caméra pour le viewport et l'ajuster automatiquement
    local camera = Instance.new("Camera")
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera
    positionCameraToFit(viewportFrame, camera, clone)
end

-- Variante: modèle affiché en niveaux de gris (teinte noir et blanc)
function UIUtils.setupViewportFrameGrayscale(viewportFrame, model)
    if not viewportFrame or not model then
        return
    end

    -- Cloner le modèle pour l'affichage
    local clone = model:Clone()
    clone.Parent = viewportFrame

    -- Désactiver textures/couleurs pour obtenir un rendu noir et blanc fiable
    local GRAY = Color3.fromRGB(45, 45, 45)
    local function toGrayColor(c)
        local r, g, b = c.R, c.G, c.B
        local y = 0.299 * r + 0.587 * g + 0.114 * b
        -- assombrir très fortement le niveau de gris (quasi silhouette)
        local d = math.clamp(y * 0.12, 0.04, 0.14)
        return Color3.new(d, d, d)
    end

    local function grayify(inst)
        if inst:IsA("UnionOperation") then
            pcall(function() inst.UsePartColor = true end)
            pcall(function() inst.Material = Enum.Material.SmoothPlastic end)
            pcall(function() inst.Color = GRAY end)
            pcall(function() inst.Reflectance = 0 end)
        elseif inst:IsA("MeshPart") then
            pcall(function() inst.TextureID = "" end)
            pcall(function() inst.VertexColor = Vector3.new(1, 1, 1) end)
            pcall(function() inst.UsePartColor = true end)
            pcall(function() inst.Material = Enum.Material.SmoothPlastic end)
            pcall(function() inst.Color = GRAY end)
            pcall(function() inst.Reflectance = 0 end)
        elseif inst:IsA("SpecialMesh") then
            pcall(function() inst.TextureId = "" end)
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            pcall(function() inst.Transparency = 1 end)
        elseif inst.ClassName == "SurfaceAppearance" then
            pcall(function() inst.Enabled = false end)
        elseif inst:IsA("BasePart") then
            pcall(function() inst.Material = Enum.Material.SmoothPlastic end)
            pcall(function() inst.Color = toGrayColor(inst.Color) end)
            pcall(function() inst.Reflectance = 0 end)
        end
    end

    -- Appliquer d'abord sur la racine clonée
    grayify(clone)
    -- Puis sur les descendants
    for _, d in ipairs(clone:GetDescendants()) do
        grayify(d)
    end

    -- Créer une caméra pour le viewport (identique à la version couleur)
    local camera = Instance.new("Camera")
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera
    positionCameraToFit(viewportFrame, camera, clone)
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