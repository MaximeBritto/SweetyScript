-- BackpackVisualClient.lua
-- Script côté client pour afficher un sac à dos qui grossit avec le nombre de bonbons
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Configuration du sac
local BACKPACK_CONFIG = {
	baseSize = Vector3.new(1.2, 1.5, 0.8), -- Taille de base du sac
	maxSize = Vector3.new(2.0, 2.2, 1.2),  -- Taille maximale (réduite pour être plus visible)
	maxCandies = 20,                        -- Nombre de bonbons pour la taille max (réduit pour test)
	animationSpeed = 0.6,                   -- Vitesse d'animation du changement de taille
	glowIntensity = 0.5                     -- Intensité de la lueur selon la rareté
}

local currentBackpack = nil
local currentCandyCount = 0

-- Fonction pour créer le sac à dos
local function createBackpack()
	local backpack = Instance.new("Model")
	backpack.Name = "VisualBackpack"

	-- Corps principal du sac
	local main = Instance.new("Part")
	main.Name = "BackpackMain"
	main.Size = BACKPACK_CONFIG.baseSize
	main.Material = Enum.Material.Fabric
	main.Color = Color3.fromRGB(101, 67, 33) -- Marron cuir
	main.Shape = Enum.PartType.Block
	main.TopSurface = Enum.SurfaceType.Smooth
	main.BottomSurface = Enum.SurfaceType.Smooth
	main.Anchored = false -- NE PAS ANCRER
	main.CanCollide = false -- PAS DE COLLISION
	main.Parent = backpack

	-- Coins arrondis pour le sac
	local corner = Instance.new("SpecialMesh")
	corner.MeshType = Enum.MeshType.Brick
	corner.Scale = Vector3.new(1, 1, 1)
	corner.Parent = main

	-- Sangles du sac
	local function createStrap(name, size, position, color)
		local strap = Instance.new("Part")
		strap.Name = name
		strap.Size = size
		strap.Material = Enum.Material.Fabric
		strap.Color = color or Color3.fromRGB(61, 40, 20) -- Marron plus foncé
		strap.Anchored = false -- NE PAS ANCRER
		strap.CanCollide = false
		strap.Parent = backpack

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = main
		weld.Part1 = strap
		weld.Parent = main

		-- Position relative sera gérée par le weld
		return strap
	end

	-- Créer les sangles
	createStrap("LeftStrap", Vector3.new(0.2, 1.8, 0.1), Vector3.new(-0.4, 0.2, -0.1))
	createStrap("RightStrap", Vector3.new(0.2, 1.8, 0.1), Vector3.new(0.4, 0.2, -0.1))

	-- Boucles métalliques
	local function createBuckle(position)
		local buckle = Instance.new("Part")
		buckle.Name = "Buckle"
		buckle.Size = Vector3.new(0.15, 0.15, 0.05)
		buckle.Material = Enum.Material.Metal
		buckle.Color = Color3.fromRGB(163, 162, 165) -- Argent
		buckle.Shape = Enum.PartType.Cylinder
		buckle.Anchored = false -- NE PAS ANCRER
		buckle.CanCollide = false
		buckle.Parent = backpack

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = main
		weld.Part1 = buckle
		weld.Parent = main

		return buckle
	end

	createBuckle(Vector3.new(-0.4, 0.6, -0.45))
	createBuckle(Vector3.new(0.4, 0.6, -0.45))

	-- Effet de lueur pour les bonbons rares (invisible au début)
	local glow = Instance.new("PointLight")
	glow.Name = "CandyGlow"
	glow.Brightness = 0
	glow.Range = 5
	glow.Color = Color3.new(1, 0.8, 0.2) -- Doré
	glow.Parent = main

	-- Étiquette avec le nombre de bonbons (centrée sur le sac)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CandyCounter"
	gui.Size = UDim2.new(0, 80, 0, 25)
	gui.StudsOffset = Vector3.new(0, 0, 0) -- Au centre du sac, pas au-dessus
	gui.Adornee = main
	gui.AlwaysOnTop = true -- Pour éviter qu'il soit caché
	gui.Parent = backpack

	local label = Instance.new("TextLabel")
	label.Name = "CounterLabel" -- Nom spécifique pour le debug
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	label.BackgroundTransparency = 0.3
	label.Text = "🍬 0"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 8)
	corner2.Parent = label

	backpack.PrimaryPart = main
	return backpack
end

-- Fonction pour attacher le sac au personnage
local function attachBackpackToCharacter(character, backpack)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then return end

	local main = backpack:FindFirstChild("BackpackMain")
	if not main then return end

	-- Utiliser Motor6D pour un attachement plus propre
	local motor = Instance.new("Motor6D")
	motor.Name = "BackpackMotor"
	motor.Part0 = torso
	motor.Part1 = main
	motor.Parent = main

	-- Position sur le dos (plus sûre)
	if character:FindFirstChild("Torso") then
		-- R6
		motor.C1 = CFrame.new(0, 0.2, -0.8)
	else
		-- R15  
		motor.C1 = CFrame.new(0, 0.1, -0.6)
	end

	backpack.Parent = character
end

-- Fonction pour calculer le nombre total de bonbons (LEGACY + HOTBAR)
local function getTotalCandyCount()
	-- SYSTÈME MODERNE SEULEMENT : Compter uniquement les Tools avec IsCandy
	-- (Plus de legacy SacBonbons pour éviter la duplication)

	local totalHotbar = 0
	local detailsHotbar = {}

	-- COMPTER LES BONBONS DANS LA HOTBAR (Tools)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
				local candyName = tool:GetAttribute("BaseName") or "Inconnu"
				local stackSize = tool:GetAttribute("StackSize") or 1
				totalHotbar = totalHotbar + stackSize
				table.insert(detailsHotbar, candyName .. ":" .. stackSize)
			end
		end
	end

	-- COMPTER AUSSI DANS LA HOTBAR ACTIVE (si le joueur tient un bonbon)
	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
				local candyName = tool:GetAttribute("BaseName") or "Inconnu"
				local stackSize = tool:GetAttribute("StackSize") or 1
				totalHotbar = totalHotbar + stackSize
				table.insert(detailsHotbar, "[EQUIPÉ]" .. candyName .. ":" .. stackSize)
			end
		end
	end

	local total = totalHotbar

	-- LOGS DÉTAILLÉS (système moderne uniquement)
	return total
end

-- Fonction pour calculer la rareté moyenne des bonbons
local function getAverageRarity()
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return 1 end

	local sacBonbons = playerData:FindFirstChild("SacBonbons")
	if not sacBonbons then return 1 end

	-- Chargement du RecipeManager côté client
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

	local totalValue = 0
	local totalCandies = 0

	for _, candySlot in pairs(sacBonbons:GetChildren()) do
		if candySlot:IsA("IntValue") and candySlot.Value > 0 then
			local recipe = RecipeManager.Recettes[candySlot.Name]
			if recipe then
				totalValue = totalValue + (recipe.valeur * candySlot.Value)
				totalCandies = totalCandies + candySlot.Value
			end
		end
	end

	return totalCandies > 0 and (totalValue / totalCandies) or 1
end

-- Fonction pour mettre à jour la taille et l'apparence du sac
local function updateBackpack()
	if not currentBackpack then return end

	local main = currentBackpack:FindFirstChild("BackpackMain")
	local glow = main and main:FindFirstChild("CandyGlow")
	local gui = currentBackpack:FindFirstChild("CandyCounter")
	local label = gui and gui:FindFirstChild("CounterLabel")

	if not main then return end

	local candyCount = getTotalCandyCount()
	local averageRarity = getAverageRarity()

	-- Calculer la nouvelle taille avec une progression plus visible
	local progress = math.min(candyCount / BACKPACK_CONFIG.maxCandies, 1)
	local newSize = BACKPACK_CONFIG.baseSize:Lerp(BACKPACK_CONFIG.maxSize, progress)

	-- Animation de changement de taille
	local sizeTween = TweenService:Create(
		main,
		TweenInfo.new(BACKPACK_CONFIG.animationSpeed, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Size = newSize }
	)
	sizeTween:Play()

	-- Mettre à jour la lueur selon la rareté
	if glow then
		local glowBrightness = math.min(averageRarity / 50, 1) * BACKPACK_CONFIG.glowIntensity
		local glowTween = TweenService:Create(
			glow,
			TweenInfo.new(0.5),
			{ 
				Brightness = glowBrightness,
				Color = averageRarity > 30 and Color3.new(1, 0.2, 1) or Color3.new(1, 0.8, 0.2) -- Violet pour très rare, doré sinon
			}
		)
		glowTween:Play()
	end

	-- Mettre à jour le compteur
	if label then
		label.Text = "🍬 " .. candyCount

		-- Changer la couleur selon le nombre
		local color = Color3.new(1, 1, 1) -- Blanc par défaut
		if candyCount > 15 then
			color = Color3.new(1, 0.8, 0.2) -- Doré
		elseif candyCount > 5 then
			color = Color3.new(0.2, 1, 0.2) -- Vert
		end

		label.TextColor3 = color
	end

	-- Effet visuel si le nombre a augmenté
	if candyCount > currentCandyCount then
		-- Petit effet de pulsation
		local pulseTween = TweenService:Create(
			main,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Size = newSize * 1.15 }
		)
		pulseTween:Play()
	end

	currentCandyCount = candyCount
end

-- Fonction appelée quand le personnage spawn
local function onCharacterAdded(character)
	-- Attendre que le personnage soit complètement chargé
	character:WaitForChild("HumanoidRootPart")
	task.wait(1) -- Petit délai pour être sûr

	-- Nettoyer l'ancien sac si il existe
	if currentBackpack then
		currentBackpack:Destroy()
	end

	-- Créer le nouveau sac
	currentBackpack = createBackpack()
	attachBackpackToCharacter(character, currentBackpack)

	-- Mise à jour initiale
	updateBackpack()
end

-- Fonction pour surveiller les changements dans le sac à bonbons
local function setupCandyListener()
	local playerData = player:WaitForChild("PlayerData")
	local sacBonbons = playerData:WaitForChild("SacBonbons")

	local function connectCandySlot(slot)
		if slot:IsA("IntValue") then
			slot.Changed:Connect(function(newValue)
				task.wait(0.1)
				updateBackpack()
			end)
		end
	end

	-- Connecter les slots existants
	for _, slot in pairs(sacBonbons:GetChildren()) do
		connectCandySlot(slot)
	end

	-- Connecter les nouveaux slots
	sacBonbons.ChildAdded:Connect(function(newSlot)
		connectCandySlot(newSlot)
		task.wait(0.2)
		updateBackpack()
	end)

	sacBonbons.ChildRemoved:Connect(function(removedSlot)
		task.wait(0.2)
		updateBackpack()
	end)

	-- Mise à jour périodique pour être sûr
	task.spawn(function()
		while true do
			task.wait(5) -- Toutes les 5 secondes
			if currentBackpack then
				updateBackpack()
			end
		end
	end)
end

-- Initialisation
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Attendre que PlayerData soit disponible puis setup les listeners
task.spawn(function()
	player:WaitForChild("PlayerData")
	setupCandyListener()
end)

-- Gestion de l'événement de rafraîchissement du sac
task.spawn(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local backpackRefreshEvent = ReplicatedStorage:WaitForChild("BackpackRefreshEvent", 10)
	if backpackRefreshEvent then
		backpackRefreshEvent.OnClientEvent:Connect(function()
			if currentBackpack then
				updateBackpack()
			end
		end)
	end
end)

-- Fonction de test manuel
local function testBackpack()
	if currentBackpack then
		updateBackpack()
	else
		if player.Character then
			onCharacterAdded(player.Character)
		end
	end
end

-- Ajouter un raccourci pour tester (touche T)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.T then
		testBackpack()
	end
end)

-- Exposer la fonction de test
local testValue = Instance.new("BindableFunction")
testValue.Name = "testBackpack"
testValue.OnInvoke = testBackpack
testValue.Parent = script 