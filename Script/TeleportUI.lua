-- TeleportUI.lua
-- Ce script crée des boutons pour se téléporter à son île et au vendeur.
-- À PLACER DANS : StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- =============================================
-- FONCTION DE TÉLÉPORTATION
-- =============================================
local function teleportPlayer(destinationCFrame)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- On téléporte le joueur un peu au-dessus pour ne pas rester coincé
    humanoidRootPart.CFrame = destinationCFrame * CFrame.new(0, 4, 0)
end

-- =============================================
-- CRÉATION DE L'INTERFACE
-- =============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "TeleportFrame"
mainFrame.Size = UDim2.new(0, 150, 0, 85)
mainFrame.Position = UDim2.new(0, 20, 0.5, -42.5) -- Côté gauche, centré verticalement
mainFrame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(150, 150, 150)
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 20)
titleLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
titleLabel.Text = "Téléportation"
titleLabel.Font = Enum.Font.SourceSansSemibold
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local islandButton = Instance.new("TextButton")
islandButton.Name = "TeleportToIslandButton"
islandButton.Size = UDim2.new(1, -10, 0, 25)
islandButton.Position = UDim2.new(0, 5, 0, 25)
islandButton.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
islandButton.TextColor3 = Color3.fromRGB(255, 255, 255)
islandButton.Font = Enum.Font.SourceSansBold
islandButton.Text = "🏠 Mon Île"
islandButton.TextSize = 14
islandButton.Parent = mainFrame

local vendorButton = Instance.new("TextButton")
vendorButton.Name = "TeleportToVendorButton"
vendorButton.Size = UDim2.new(1, -10, 0, 25)
vendorButton.Position = UDim2.new(0, 5, 0, 55)
vendorButton.BackgroundColor3 = Color3.fromRGB(220, 160, 60)
vendorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
vendorButton.Font = Enum.Font.SourceSansBold
vendorButton.Text = "🛒 Vendeur"
vendorButton.TextSize = 14
vendorButton.Parent = mainFrame

local function applyHoverEffect(button)
    local originalColor = button.BackgroundColor3
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor:Lerp(Color3.new(1,1,1), 0.2)}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
    end)
end

applyHoverEffect(islandButton)
applyHoverEffect(vendorButton)


-- =============================================
-- LOGIQUE DES BOUTONS
-- =============================================
islandButton.MouseButton1Click:Connect(function()
    -- Le RespawnLocation est défini par IslandManager.lua
    local respawnLocation = player.RespawnLocation
    if respawnLocation then
        teleportPlayer(respawnLocation.CFrame)
    else
        warn("TeleportUI: RespawnLocation non trouvée pour le joueur. L'île n'est peut-être pas encore assignée.")
    end
end)

vendorButton.MouseButton1Click:Connect(function()
    local function findVendor()
        local function getValidPart(obj)
            if obj:IsA("BasePart") then
                return obj
            end
            
            if obj:IsA("Model") then
                local torso = obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
                if torso then return torso end
                
                local head = obj:FindFirstChild("Head")
                if head then return head end
                
                local humanoidRootPart = obj:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then return humanoidRootPart end
                
                if obj.PrimaryPart then return obj.PrimaryPart end
                
                for _, child in pairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") then return child end
                end
            end
            
            return nil
        end
        
        -- Chercher par nom exact
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "Vendeur" or obj.Name == "VendeurPNJ" then
                local validPart = getValidPart(obj)
                if validPart then return validPart end
            end
        end
        
        -- Chercher par ClickDetector
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ClickDetector") then
                local parent = obj.Parent
                if parent and parent:IsA("BasePart") then
                    local grandParent = parent.Parent
                    if grandParent and (grandParent.Name:lower():find("vendeur") or 
                                       grandParent.Name:lower():find("vendor") or 
                                       grandParent.Name:lower():find("shop") or
                                       grandParent.Name:lower():find("pnj")) then
                        return getValidPart(grandParent) or parent
                    end
                end
            end
        end
        
        -- Recherche élargie : modèles avec Humanoid + ClickDetector
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChildOfClass("ClickDetector") then
                local validPart = getValidPart(obj)
                if validPart then return validPart end
            end
        end
        
        return nil
    end
    
    local vendor = findVendor()
    if vendor then
        -- Reculer de 5 studs devant le vendeur pour une approche confortable
        local vendorCFrame = vendor.CFrame
        local backwardOffset = vendorCFrame.LookVector * -5 -- 5 studs en arrière
        local teleportPosition = vendorCFrame + backwardOffset
        
        teleportPlayer(teleportPosition)

    else
        warn("⚠️ Vendeur non trouvé dans le Workspace.")
    end
end)

 