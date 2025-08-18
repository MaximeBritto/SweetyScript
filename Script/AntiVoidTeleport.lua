-- AntiVoidTeleport.lua
-- Crée une grande zone invisible sous la map. Si un joueur tombe et touche cette zone,
-- il est téléporté sur son île (RespawnLocation définie par IslandManager.lua).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PART_NAME = "AntiVoidZone"
local TOUCH_COOLDOWN = 2 -- secondes, pour éviter les téléports en boucle

-- Calcule une position Y sûre pour la zone, au-dessus du FallenPartDestroyHeight
local function computeSafeY()
    local fpd = Workspace.FallenPartsDestroyHeight
    -- Place la zone sous la map, mais AU-DESSUS du FallenPartDestroyHeight.
    -- Garantit une valeur négative raisonnable même si FPD est >= 0.
    if typeof(fpd) == "number" then
        return math.min(fpd + 100, -50)
    end
    return -300
end

local function ensureAntiVoid()
    local zone = Workspace:FindFirstChild(PART_NAME)
    if zone and zone:IsA("BasePart") then
        return zone
    end

    zone = Instance.new("Part")
    zone.Name = PART_NAME
    zone.Anchored = true
    zone.CanCollide = false -- on ne veut pas bloquer le joueur, juste détecter le contact
    zone.CanQuery = false
    zone.CanTouch = true
    zone.Transparency = 1
    zone.Size = Vector3.new(2048, 10, 2048)
    zone.Position = Vector3.new(0, computeSafeY(), 0)
    zone.Material = Enum.Material.ForceField -- invisible de toute façon, permet de bien la distinguer si on la rend visible temporairement

    -- Toujours invisible
    zone.Transparency = 1

    print(string.format("[AntiVoid] Zone créée pos=%s size=%s (FPD=%s)", tostring(zone.Position), tostring(zone.Size), tostring(Workspace.FallenPartsDestroyHeight)))
    zone.Parent = Workspace
    return zone
end

local antiVoid = ensureAntiVoid()

-- Debounce par joueur pour éviter les multiples TP en un instant
local lastTp = {}

local function teleportPlayerToIsland(player: Player)
	local character = player.Character
	if not character then return end

	local respawnLocation = player.RespawnLocation
	if not respawnLocation or not respawnLocation:IsA("BasePart") then
		warn("AntiVoidTeleport: RespawnLocation introuvable pour", player.Name, "— TP annulé.")
		return
	end

	-- On téléporte légèrement au-dessus du point pour éviter tout clipping avec le sol
	local targetCF = respawnLocation.CFrame + Vector3.new(0, 5, 0)
	-- Utiliser PivotTo pour déplacer tout le modèle du personnage proprement
	character:PivotTo(targetCF)
end

local function onAntiVoidTouched(hit: BasePart)
	-- On récupère le character via le parent de la pièce touchée
	local character = hit and hit.Parent
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local now = os.clock()
	if lastTp[player] and (now - lastTp[player] < TOUCH_COOLDOWN) then
		return
	end
	lastTp[player] = now

	teleportPlayerToIsland(player)
end

antiVoid.Touched:Connect(onAntiVoidTouched)

-- Si la map est très large ou centrée ailleurs, on recalcule la position périodiquement (optionnel)
-- Ici, on se contente de repositionner au démarrage et de laisser tel quel.

print("✅ AntiVoidTeleport initialisé: zone invisible '" .. PART_NAME .. "' prête à téléporter les joueurs.")
