-- BackpackVisualServer.lua
-- Script côté serveur pour créer le sac visible par tous
-- À placer dans ServerScriptService

local Players = game:GetService("Players")

-- Configuration du sac
local BACKPACK_CONFIG = {
	baseSize = Vector3.new(1.2, 1.5, 0.8),
	maxSize = Vector3.new(3.5, 4.0, 2.0),
	maxCandies = 300
}

-- Table pour stocker les sacs de chaque joueur
local playerBackpacks = {}

-- Fonction pour créer le sac à dos (visible par tous)
local function createBackpack()
	local backpack = Instance.new("Model")
	backpack.Name = "VisualBackpack"

	-- Corps principal du sac
	local main = Instance.new("Part")
	main.Name = "BackpackMain"
	main.Size = BACKPACK_CONFIG.baseSize
	main.Material = Enum.Material.Fabric
	main.Color = Color3.fromRGB(101, 67, 33)
	main.Shape = Enum.PartType.Block
	main.TopSurface = Enum.SurfaceType.Smooth
	main.BottomSurface = Enum.SurfaceType.Smooth
	main.Anchored = false
	main.CanCollide = false
	main.Parent = backpack

	-- Coins arrondis
	local corner = Instance.new("SpecialMesh")
	corner.MeshType = Enum.MeshType.Brick
	corner.Scale = Vector3.new(1, 1, 1)
	corner.Parent = main

	-- Sangles du sac
	local function createStrap(name, size)
		local strap = Instance.new("Part")
		strap.Name = name
		strap.Size = size
		strap.Material = Enum.Material.Fabric
		strap.Color = Color3.fromRGB(61, 40, 20)
		strap.Anchored = false
		strap.CanCollide = false
		strap.Parent = backpack

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = main
		weld.Part1 = strap
		weld.Parent = main

		return strap
	end

	createStrap("LeftStrap", Vector3.new(0.2, 1.8, 0.1))
	createStrap("RightStrap", Vector3.new(0.2, 1.8, 0.1))

	-- Effet de lueur
	local glow = Instance.new("PointLight")
	glow.Name = "CandyGlow"
	glow.Brightness = 0
	glow.Range = 5
	glow.Color = Color3.new(1, 0.8, 0.2)
	glow.Parent = main

	backpack.PrimaryPart = main
	
	return backpack
end

-- Fonction pour attacher le sac au personnage
local function attachBackpackToCharacter(character, backpack)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then return end

	local main = backpack:FindFirstChild("BackpackMain")
	if not main then return end

	-- Motor6D pour l'attachement
	local motor = Instance.new("Motor6D")
	motor.Name = "BackpackMotor"
	motor.Part0 = torso
	motor.Part1 = main
	motor.Parent = main

	-- Position sur le dos
	if character:FindFirstChild("Torso") then
		motor.C1 = CFrame.new(0, 0.2, -0.8)
	else
		motor.C1 = CFrame.new(0, 0.1, -0.6)
	end

	backpack.Parent = character
end

-- Fonction appelée quand un joueur rejoint
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		-- Attendre que le personnage soit chargé
		character:WaitForChild("HumanoidRootPart")
		
		-- Nettoyer l'ancien sac si il existe
		if playerBackpacks[player.UserId] then
			playerBackpacks[player.UserId]:Destroy()
		end

		-- Créer le nouveau sac
		local backpack = createBackpack()
		attachBackpackToCharacter(character, backpack)
		playerBackpacks[player.UserId] = backpack
	end)
end

-- Fonction appelée quand un joueur quitte
local function onPlayerRemoving(player)
	if playerBackpacks[player.UserId] then
		playerBackpacks[player.UserId]:Destroy()
		playerBackpacks[player.UserId] = nil
	end
end

-- Initialisation
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Fonction pour mettre à jour la taille du sac (appelée par le client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local updateBackpackEvent = ReplicatedStorage:FindFirstChild("UpdateBackpackSize")
if not updateBackpackEvent then
	updateBackpackEvent = Instance.new("RemoteEvent")
	updateBackpackEvent.Name = "UpdateBackpackSize"
	updateBackpackEvent.Parent = ReplicatedStorage
end

updateBackpackEvent.OnServerEvent:Connect(function(player, candyCount, averageRarity)
	local backpack = playerBackpacks[player.UserId]
	if not backpack then return end
	
	local main = backpack:FindFirstChild("BackpackMain")
	local glow = main and main:FindFirstChild("CandyGlow")
	local motor = main and main:FindFirstChild("BackpackMotor")
	
	if not main then return end
	
	-- Calculer la nouvelle taille
	local progress = math.min(candyCount / BACKPACK_CONFIG.maxCandies, 1)
	local newSize = BACKPACK_CONFIG.baseSize:Lerp(BACKPACK_CONFIG.maxSize, progress)
	
	-- Appliquer la taille
	main.Size = newSize
	
	-- Ajuster la position
	local character = player.Character
	if character and motor then
		local isR6 = character:FindFirstChild("Torso") ~= nil
		local baseZOffset = isR6 and -0.8 or -0.6
		local baseYOffset = isR6 and 0.2 or 0.1
		local sizeIncrease = newSize.Z - BACKPACK_CONFIG.baseSize.Z
		local newZOffset = baseZOffset - (sizeIncrease / 2) - 0.15
		motor.C1 = CFrame.new(0, baseYOffset, newZOffset)
	end
	
	-- Mettre à jour la lueur
	if glow then
		local glowBrightness = math.min(averageRarity / 50, 1) * 0.5
		glow.Brightness = glowBrightness
		glow.Color = averageRarity > 30 and Color3.new(1, 0.2, 1) or Color3.new(1, 0.8, 0.2)
	end
end)

print("✅ BackpackVisualServer initialisé")
