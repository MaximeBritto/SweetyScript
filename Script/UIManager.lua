-- Ce script (local) met à jour l'interface du joueur
-- VERSION V0.4 : Interface (HUD) agrandie et réorganisée
-- À placer dans ScreenGui

local player = game.Players.LocalPlayer
local playerData = player:WaitForChild("PlayerData")

-- === DONNÉES ===
local argent = playerData:WaitForChild("Argent")
local sacBonbons = playerData:WaitForChild("SacBonbons")
local enProduction = playerData:WaitForChild("EnProduction")
local recetteEnCours = playerData:WaitForChild("RecetteEnCours")

-- On trouve les labels dans le ScreenGui
local screenGui = script.Parent

-- Créer un cadre pour regrouper les informations
local hudFrame = screenGui:FindFirstChild("HudFrame")
if not hudFrame then
    hudFrame = Instance.new("Frame")
    hudFrame.Name = "HudFrame"
    hudFrame.Size = UDim2.new(0.25, 0, 0.2, 0) -- 25% largeur, 20% hauteur
    hudFrame.Position = UDim2.new(0.02, 0, 0.03, 0) -- En haut à gauche
    hudFrame.BackgroundTransparency = 0.5
    hudFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hudFrame.BorderSizePixel = 2
    hudFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    hudFrame.Parent = screenGui
end

-- Fonction pour créer un label standard
local function createLabel(name, position, text)
    local label = hudFrame:FindFirstChild(name)
    if not label then
        label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(1, -20, 0, 30)
        label.Position = position
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 20 -- Police plus grande
        label.Font = Enum.Font.SourceSansBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = hudFrame
        local padding = Instance.new("UIPadding", label)
        padding.PaddingLeft = UDim.new(0, 10)
    end
    return label
end

-- Créer les labels
local argentLabel = createLabel("ArgentLabel", UDim2.new(0, 10, 0, 10), "Argent : 0 $")
local bonbonsLabel = createLabel("BonbonsLabel", UDim2.new(0, 10, 0, 40), "Bonbons : 0")
local productionLabel = createLabel("ProductionLabel", UDim2.new(0, 10, 0, 70), "Production : Inactive")

-- Supprimer les anciens labels s'ils existent en dehors du cadre
if screenGui:FindFirstChild("ArgentLabel") and screenGui.ArgentLabel.Parent ~= hudFrame then screenGui.ArgentLabel:Destroy() end
if screenGui:FindFirstChild("StockLabel") and screenGui.StockLabel.Parent ~= hudFrame then screenGui.StockLabel:Destroy() end
if screenGui:FindFirstChild("IngredientsLabel") and screenGui.IngredientsLabel.Parent ~= hudFrame then screenGui.IngredientsLabel:Destroy() end
if screenGui:FindFirstChild("ProductionLabel") and screenGui.ProductionLabel.Parent ~= hudFrame then screenGui.ProductionLabel:Destroy() end


-- Fonction pour compter les bonbons dans le sac
local function compterBonbons()
    local total = 0
    for _, bonbon in pairs(sacBonbons:GetChildren()) do
        if bonbon:IsA("IntValue") then
            total = total + bonbon.Value
        end
    end
    return total
end

-- Fonction pour mettre à jour l'affichage
local function updateUI()
    -- AFFICHAGE DE L'ARGENT
    argentLabel.Text = "💰 Argent : " .. argent.Value .. " $"
    argentLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Or

    -- AFFICHAGE DES BONBONS
    local totalBonbons = compterBonbons()
    bonbonsLabel.Text = "🍬 Bonbons : " .. totalBonbons
    bonbonsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

    -- AFFICHAGE DU STATUT DE PRODUCTION
    if enProduction.Value then
        local recetteData = require(ReplicatedStorage.RecipeManager).Recettes[recetteEnCours.Value]
        local nomRecette = recetteData and recetteData.nom or recetteEnCours.Value
        productionLabel.Text = "⏳ " .. nomRecette .. " en cours..."
        productionLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Jaune quand en production
    else
        productionLabel.Text = "✅ Production : Inactive"
        productionLabel.TextColor3 = Color3.fromRGB(0, 255, 127) -- Vert quand inactive
    end
end

-- On met à jour l'UI une première fois au démarrage
updateUI()

-- On met à jour l'UI chaque fois que les valeurs changent
argent.Changed:Connect(updateUI)
enProduction.Changed:Connect(updateUI)
recetteEnCours.Changed:Connect(updateUI)

-- Écouter les changements dans le sac à bonbons
sacBonbons.ChildAdded:Connect(function(child)
    updateUI()
    if child:IsA("IntValue") then
        child.Changed:Connect(updateUI)
    end
end)
sacBonbons.ChildRemoved:Connect(updateUI)

-- Écouter les changements de quantité des bonbons existants
for _, bonbon in pairs(sacBonbons:GetChildren()) do
    if bonbon:IsA("IntValue") then
        bonbon.Changed:Connect(updateUI)
    end
end

print("✅ UIManager v0.4 (HUD agrandi) chargé !") 