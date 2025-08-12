--[[
    👀 Client: Halo rouge autour des plateformes verrouillées + hints de coût
    - Affiche un Highlight rouge autour des `PlatformX` que le joueur n'a pas encore débloquées
    - Le halo s'affiche uniquement à proximité pour éviter le bruit visuel
    - Se met à jour si le joueur débloque une plateforme (PlayerData.PlatformsUnlocked)
]]

local Players = game:GetService("Players")
local _RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer

-- Configuration d'affichage
local VISUAL = {
    NEAR_DISTANCE = 40,               -- distance pour afficher un halo
    HIGHLIGHT_OUTLINE = Color3.fromRGB(255, 64, 64),
    HIGHLIGHT_FILL = Color3.fromRGB(255, 0, 0),
    HIGHLIGHT_FILL_TRANSPARENCY = 1,  -- 1 = invisible (juste contour)
}

-- Références et état
local highlightsFolder = nil
local platformToHighlight = {} -- [BasePart] = Highlight

local function ensureHighlightsFolder()
    if highlightsFolder and highlightsFolder.Parent then return highlightsFolder end
    local pg = LOCAL_PLAYER:WaitForChild("PlayerGui")
    local folder = pg:FindFirstChild("CandyPlatformHighlights")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "CandyPlatformHighlights"
        folder.Parent = pg
    end
    highlightsFolder = folder
    return highlightsFolder
end

local function getCharacterRoot()
    local char = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function getPlatformIndex(part)
    if not part or not part.Name then return nil end
    local idx = string.match(part.Name, "^Platform(%d+)$")
    return idx and tonumber(idx) or nil
end

local function getUnlockedCount()
    local pd = LOCAL_PLAYER:FindFirstChild("PlayerData")
    local pu = pd and pd:FindFirstChild("PlatformsUnlocked")
    return (pu and pu.Value) or 0
end

-- Trouver le modèle d'île du joueur
local function getMyIslandModel()
    local byName = workspace:FindFirstChild("Ile_" .. LOCAL_PLAYER.Name)
    if byName and byName:IsA("Model") then return byName end
    local slot = LOCAL_PLAYER:GetAttribute("IslandSlot")
    if slot then
        local bySlot = workspace:FindFirstChild("Ile_Slot_" .. tostring(slot))
        if bySlot and bySlot:IsA("Model") then return bySlot end
    end
    return nil
end

local function _isLockedForLocal(part)
    local idx = getPlatformIndex(part)
    if not idx then return false end
    return idx > getUnlockedCount()
end

local function inRange(part, root)
    local ok, mag = pcall(function()
        return (root.Position - part.Position).Magnitude
    end)
    return ok and mag <= VISUAL.NEAR_DISTANCE
end

local function addOrUpdateHighlight(part)
    ensureHighlightsFolder()
    local hl = platformToHighlight[part]
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "LockedPlatformHighlight"
        hl.Adornee = part
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.OutlineColor = VISUAL.HIGHLIGHT_OUTLINE
        hl.FillColor = VISUAL.HIGHLIGHT_FILL
        hl.FillTransparency = VISUAL.HIGHLIGHT_FILL_TRANSPARENCY
        hl.Parent = highlightsFolder
        platformToHighlight[part] = hl
    else
        hl.Adornee = part
    end
    hl.Enabled = true
end

local function removeHighlight(part)
    local hl = platformToHighlight[part]
    if hl then
        platformToHighlight[part] = nil
        hl:Destroy()
    end
end

local function refreshHighlights()
    local root = getCharacterRoot()
    local unlocked = getUnlockedCount()
    -- Nettoyer les highlights pour des parties supprimées
    for p, _ in pairs(platformToHighlight) do
        if not p or not p.Parent then
            removeHighlight(p)
        end
    end

    -- Limiter au modèle d'île du joueur
    local myIsland = getMyIslandModel()
    if not myIsland then return end

    -- Scanner les plateformes uniquement dans l'île du joueur
    for _, part in ipairs(myIsland:GetDescendants()) do
        if part:IsA("BasePart") then
            local idx = getPlatformIndex(part)
            if idx then
                if idx > unlocked and inRange(part, root) then
                    addOrUpdateHighlight(part)
                else
                    removeHighlight(part)
                end
            end
        end
    end
end

-- Rafraîchissement périodique
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(refreshHighlights)
    end
end)

-- Réagir au changement du nombre de plateformes débloquées
task.spawn(function()
    local pd = LOCAL_PLAYER:WaitForChild("PlayerData", 60)
    if not pd then return end
    local pu = pd:WaitForChild("PlatformsUnlocked", 60)
    if not pu then return end
    pu.Changed:Connect(function()
        pcall(refreshHighlights)
    end)
end)

-- Rafraîchir aussi sur respawn
LOCAL_PLAYER.CharacterAdded:Connect(function()
    task.wait(1)
    pcall(refreshHighlights)
end)

-- Première passe
task.delay(1, function()
    pcall(refreshHighlights)
end)

print("👀 Client CandyPlatforms: halo rouge actif pour plateformes verrouillées")


