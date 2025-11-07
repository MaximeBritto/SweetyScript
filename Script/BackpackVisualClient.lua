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
	maxSize = Vector3.new(3.5, 4.0, 2.0),  -- Taille maximale BEAUCOUP plus grosse
	maxCandies = 300,                       -- Nombre de bonbons pour la taille max (300 bonbons)
	animationSpeed = 0.6,                   -- Vitesse d'animation du changement de taille
	glowIntensity = 0.5                     -- Intensité de la lueur selon la rareté
}

local currentBackpack = nil
local currentCandyCount = 0
local rainbowConnection = nil -- Pour l'animation arc-en-ciel
local isInitializing = false -- Flag pour éviter les animations au spawn
local displayedCandies = {} -- Table pour stocker les bonbons 3D affichés

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
	gui.Size = UDim2.new(0, 120, 0, 30)
	gui.StudsOffset = Vector3.new(0, 0, 0) -- Au centre du sac, pas au-dessus
	gui.Adornee = main
	gui.AlwaysOnTop = true -- Pour éviter qu'il soit caché
	gui.Parent = backpack

	-- Frame de fond (un seul fond pour tout le texte)
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	background.BackgroundTransparency = 0.3
	background.BorderSizePixel = 0
	background.Parent = gui

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 8)
	corner2.Parent = background

	-- Container pour les chiffres avec UIListLayout
	local digitsContainer = Instance.new("Frame")
	digitsContainer.Name = "DigitsContainer"
	digitsContainer.Size = UDim2.new(1, 0, 1, 0)
	digitsContainer.BackgroundTransparency = 1 -- Pas de fond sur le container
	digitsContainer.Parent = background

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = digitsContainer

	backpack.PrimaryPart = main
	
	-- Dossier pour les bonbons 3D miniatures
	local candiesFolder = Instance.new("Folder")
	candiesFolder.Name = "MiniCandies"
	candiesFolder.Parent = backpack
	
	return backpack
end

-- Fonction pour obtenir un échantillon de bonbons du joueur
local function getSampleCandies(maxCount)
	local candySamples = {}
	local backpack = player:FindFirstChild("Backpack")
	
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
				local candyName = tool:GetAttribute("BaseName") or tool.Name
				-- Ajouter seulement si pas déjà dans la liste
				local alreadyAdded = false
				for _, sample in pairs(candySamples) do
					if sample == candyName then
						alreadyAdded = true
						break
					end
				end
				
				if not alreadyAdded then
					table.insert(candySamples, candyName)
					if #candySamples >= maxCount then
						break
					end
				end
			end
		end
	end
	
	return candySamples
end

-- Fonction pour créer un bonbon 3D miniature
local function createMiniCandy(candyName, position, parent)
	-- Chercher le modèle du bonbon dans ReplicatedStorage
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local candyModels = ReplicatedStorage:FindFirstChild("BonbonModels")
	
	if not candyModels then return nil end
	
	local originalModel = candyModels:FindFirstChild(candyName)
	if not originalModel then return nil end
	
	-- Cloner et réduire la taille
	local miniCandy = originalModel:Clone()
	
	-- Réduire toutes les parts
	for _, part in pairs(miniCandy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = part.Size * 0.15 -- 15% de la taille originale
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end
	
	-- Créer une part invisible pour attacher le bonbon
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = false
	anchor.CanCollide = false
	anchor.Parent = parent
	
	-- Weld le bonbon à l'ancre
	if miniCandy.PrimaryPart then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = miniCandy.PrimaryPart
		weld.Parent = anchor
	end
	
	miniCandy.Parent = parent
	
	-- Rotation aléatoire pour varier
	if miniCandy.PrimaryPart then
		miniCandy:SetPrimaryPartCFrame(miniCandy.PrimaryPart.CFrame * CFrame.Angles(
			math.random() * math.pi * 2,
			math.random() * math.pi * 2,
			math.random() * math.pi * 2
		))
	end
	
	return anchor
end

-- Définition de la fonction pour mettre à jour les bonbons 3D affichés
updateDisplayedCandies = function()
	if not currentBackpack then 
		print("⚠️ [3D] Pas de backpack")
		return 
	end
	
	local main = currentBackpack:FindFirstChild("BackpackMain")
	local candiesFolder = currentBackpack:FindFirstChild("MiniCandies")
	if not main or not candiesFolder then 
		print("⚠️ [3D] Main ou folder manquant")
		return 
	end
	
	-- Nettoyer les anciens bonbons
	for _, candy in pairs(displayedCandies) do
		if candy then candy:Destroy() end
	end
	displayedCandies = {}
	candiesFolder:ClearAllChildren()
	
	-- Calculer combien de bonbons afficher selon le stade
	local candyCount = getTotalCandyCount()
	local displayCount = 0
	
	if candyCount >= 226 then
		displayCount = 12
	elseif candyCount >= 151 then
		displayCount = 9
	elseif candyCount >= 76 then
		displayCount = 6
	elseif candyCount > 0 then
		displayCount = 3
	end
	
	print("🍬 [3D] Affichage de", displayCount, "bonbons pour", candyCount, "bonbons totaux")
	
	if displayCount == 0 then return end
	
	-- Obtenir un échantillon de bonbons
	local candySamples = getSampleCandies(displayCount)
	print("🍬 [3D] Échantillons trouvés:", #candySamples)
	
	-- Positions prédéfinies sur le sac (réparties proprement)
	local positions = {
		Vector3.new(-0.3, 0.4, 0.2),
		Vector3.new(0.3, 0.4, 0.2),
		Vector3.new(0, 0.6, 0.2),
		Vector3.new(-0.4, 0, 0.25),
		Vector3.new(0.4, 0, 0.25),
		Vector3.new(0, 0.2, 0.3),
		Vector3.new(-0.2, -0.3, 0.2),
		Vector3.new(0.2, -0.3, 0.2),
		Vector3.new(0, -0.5, 0.25),
		Vector3.new(-0.35, 0.2, 0.15),
		Vector3.new(0.35, 0.2, 0.15),
		Vector3.new(0, 0, 0.35),
	}
	
	-- Créer les bonbons miniatures
	for i = 1, math.min(displayCount, #candySamples) do
		local candyName = candySamples[i]
		local position = positions[i]
		
		if position then
			local miniCandy = createMiniCandy(candyName, position, candiesFolder)
			if miniCandy then
				-- Weld à la partie principale du sac
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = main
				weld.Part1 = miniCandy
				weld.Parent = main
				
				-- Positionner
				miniCandy.CFrame = main.CFrame * CFrame.new(position)
				
				table.insert(displayedCandies, miniCandy)
			end
		end
	end
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

-- Fonction pour calculer le nombre total de bonbons
local function getTotalCandyCount()
	local total = 0
	
	-- COMPTER LES BONBONS DANS LA HOTBAR (Tools)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
				local stackSize = tool:GetAttribute("StackSize") or 1
				total = total + stackSize
			end
		end
	end

	-- COMPTER AUSSI DANS LA HOTBAR ACTIVE (si le joueur tient un bonbon)
	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
				local stackSize = tool:GetAttribute("StackSize") or 1
				total = total + stackSize
			end
		end
	end
	
	return total
end

-- Déclaration forward de la fonction (définie plus tard)
local updateDisplayedCandies

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
	local motor = main and main:FindFirstChild("BackpackMotor")

	if not main then return end

	local candyCount = getTotalCandyCount()
	local averageRarity = getAverageRarity()

	-- Calculer la nouvelle taille avec une progression plus visible
	local progress = math.min(candyCount / BACKPACK_CONFIG.maxCandies, 1)
	local newSize = BACKPACK_CONFIG.baseSize:Lerp(BACKPACK_CONFIG.maxSize, progress)

	-- 🎒 Calculer le décalage en Z pour que le sac recule quand il grossit
	-- Plus le sac est gros, plus il doit être loin du dos
	local character = player.Character
	local isR6 = character and character:FindFirstChild("Torso") ~= nil
	
	local baseZOffset = isR6 and -0.8 or -0.6
	local baseYOffset = isR6 and 0.2 or 0.1
	
	-- Calculer le décalage supplémentaire basé sur la profondeur du sac (axe Z)
	local sizeIncrease = newSize.Z - BACKPACK_CONFIG.baseSize.Z
	local newZOffset = baseZOffset - (sizeIncrease / 2) - 0.15 -- Reculer encore plus (ajout de 0.15)
	
	-- Mettre à jour la position du Motor6D
	if motor then
		motor.C1 = CFrame.new(0, baseYOffset, newZOffset)
	end

	-- Animation de changement de taille (plus rapide et smooth)
	-- Toujours appliquer la taille, même si petite différence
	if not isInitializing then
		-- Animation normale
		local sizeTween = TweenService:Create(
			main,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = newSize }
		)
		sizeTween:Play()
	else
		-- Appliquer directement sans animation pendant l'initialisation
		main.Size = newSize
	end

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
	local digitsContainer = gui and gui:FindFirstChild("Background") and gui.Background:FindFirstChild("DigitsContainer")
	if digitsContainer then
		-- Nettoyer les anciens chiffres
		for _, child in digitsContainer:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		
		-- Créer l'emoji en premier (ne bouge pas)
		local emojiLabel = Instance.new("TextLabel")
		emojiLabel.Name = "Emoji"
		emojiLabel.Size = UDim2.new(0, 22, 1, 0)
		emojiLabel.BackgroundTransparency = 1
		emojiLabel.BorderSizePixel = 0
		emojiLabel.Text = "🍬"
		emojiLabel.TextColor3 = Color3.new(1, 1, 1)
		emojiLabel.TextScaled = true
		emojiLabel.Font = Enum.Font.GothamBold
		emojiLabel.LayoutOrder = 0
		emojiLabel.Parent = digitsContainer
		
		-- Espace
		local spaceLabel = Instance.new("TextLabel")
		spaceLabel.Name = "Space"
		spaceLabel.Size = UDim2.new(0, 6, 1, 0)
		spaceLabel.BackgroundTransparency = 1
		spaceLabel.BorderSizePixel = 0
		spaceLabel.Text = ""
		spaceLabel.LayoutOrder = 1
		spaceLabel.Parent = digitsContainer
		
		-- Créer un TextLabel pour chaque chiffre (qui bougera)
		local numberText = tostring(candyCount)
		for i = 1, #numberText do
			local char = numberText:sub(i, i)
			local charLabel = Instance.new("TextLabel")
			charLabel.Name = "Digit" .. i
			charLabel.Size = UDim2.new(0, 14, 1, 0)
			charLabel.BackgroundTransparency = 1
			charLabel.BorderSizePixel = 0
			charLabel.Text = char
			charLabel.TextColor3 = Color3.new(1, 1, 1)
			charLabel.TextScaled = true
			charLabel.Font = Enum.Font.GothamBold
			charLabel.LayoutOrder = i + 1
			charLabel.Parent = digitsContainer
		end

		-- 🌈 Si on atteint la taille max, activer l'animation arc-en-ciel
		if candyCount >= BACKPACK_CONFIG.maxCandies then
			-- Arrêter l'ancienne animation si elle existe
			if rainbowConnection then
				rainbowConnection:Disconnect()
			end
			
			-- Animation arc-en-ciel continue avec chaque chiffre indépendant
			rainbowConnection = RunService.Heartbeat:Connect(function()
				if not digitsContainer or not digitsContainer.Parent then
					if rainbowConnection then
						rainbowConnection:Disconnect()
					end
					return
				end
				
				local chars = digitsContainer:GetChildren()
				for i, charLabel in pairs(chars) do
					if charLabel:IsA("TextLabel") and charLabel.Name:match("^Digit") then
						-- Effet arc-en-ciel avec décalage pour chaque chiffre (pas l'emoji)
						local digitIndex = tonumber(charLabel.Name:match("%d+"))
						local offset = (digitIndex - 1) * 0.1 -- Décalage de phase
						local hue = ((tick() * 0.5) + offset) % 1
						charLabel.TextColor3 = Color3.fromHSV(hue, 1, 1)
						
						-- Animation de rebond indépendante (vague)
						local bounce = math.sin((tick() * 3) + (digitIndex * 0.5)) * 0.15 + 1
						charLabel.TextScaled = false
						charLabel.TextSize = 16 * bounce
					end
				end
			end)
			
			-- Effet de pulsation sur le sac lui-même
			if main then
				local pulseSize = newSize * 1.05
				local pulseTween = TweenService:Create(
					main,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
					{ Size = pulseSize }
				)
				pulseTween:Play()
			end
		else
			-- Arrêter l'animation arc-en-ciel si on n'est plus au max
			if rainbowConnection then
				rainbowConnection:Disconnect()
				rainbowConnection = nil
			end
			
			-- Remettre le texte normal
			local chars = digitsContainer:GetChildren()
			for _, charLabel in pairs(chars) do
				if charLabel:IsA("TextLabel") then
					charLabel.TextScaled = true
					
					-- Changer la couleur selon le nombre (seulement pour les chiffres)
					if charLabel.Name:match("^Digit") then
						local color = Color3.new(1, 1, 1) -- Blanc par défaut
						if candyCount > 200 then
							color = Color3.new(1, 0.8, 0.2) -- Doré
						elseif candyCount > 100 then
							color = Color3.new(0.2, 1, 0.2) -- Vert
						end
						
						charLabel.TextColor3 = color
					end
				end
			end
		end
	end

	-- Effet visuel si le nombre a augmenté (seulement si pas en initialisation)
	if candyCount > currentCandyCount and not isInitializing then
		-- Petit effet de pulsation
		local pulseTween = TweenService:Create(
			main,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Size = newSize * 1.15 }
		)
		pulseTween:Play()
	end

	currentCandyCount = candyCount
	
	-- Mettre à jour les bonbons 3D affichés (désactivé temporairement)
	-- local newStage = math.floor(candyCount / 75)
	-- local oldStage = math.floor(currentCandyCount / 75)
	-- if newStage ~= oldStage and not isInitializing then
	-- 	print("🍬 [3D] Changement de stade:", oldStage, "->", newStage)
	-- 	updateDisplayedCandies()
	-- end
end

-- Fonction appelée quand le personnage spawn
local function onCharacterAdded(character)
	-- Activer le mode initialisation
	isInitializing = true
	
	-- Attendre que le personnage soit complètement chargé
	character:WaitForChild("HumanoidRootPart")
	
	-- Nettoyer l'ancien sac si il existe
	if currentBackpack then
		currentBackpack:Destroy()
	end

	-- Créer le nouveau sac
	currentBackpack = createBackpack()
	attachBackpackToCharacter(character, currentBackpack)
	
	-- 🔧 Attendre que le Backpack soit chargé avec les Tools
	task.spawn(function()
		-- Attendre le Backpack
		local backpack = player:WaitForChild("Backpack", 10)
		
		if backpack then
			-- Attendre activement qu'au moins 1 Tool de bonbon soit chargé (max 5 secondes)
			local startTime = tick()
			local candyCount = 0
			
			repeat
				task.wait(0.2)
				candyCount = getTotalCandyCount()
				print("🎒 [SPAWN] Vérification... Bonbons:", candyCount)
			until candyCount > 0 or (tick() - startTime) > 5
			
			print("🎒 [SPAWN] Nombre final de bonbons détecté:", candyCount)
			
			if candyCount > 0 then
				local progress = math.min(candyCount / BACKPACK_CONFIG.maxCandies, 1)
				local initialSize = BACKPACK_CONFIG.baseSize:Lerp(BACKPACK_CONFIG.maxSize, progress)
				
				-- Appliquer la taille initiale directement (sans animation)
				local main = currentBackpack and currentBackpack:FindFirstChild("BackpackMain")
				if main then
					main.Size = initialSize
					print("🎒 [SPAWN] Taille appliquée:", initialSize)
					
					-- Ajuster aussi la position immédiatement
					local motor = main:FindFirstChild("BackpackMotor")
					if motor then
						local isR6 = character:FindFirstChild("Torso") ~= nil
						local baseZOffset = isR6 and -0.8 or -0.6
						local baseYOffset = isR6 and 0.2 or 0.1
						local sizeIncrease = initialSize.Z - BACKPACK_CONFIG.baseSize.Z
						local newZOffset = baseZOffset - (sizeIncrease / 2) - 0.15
						motor.C1 = CFrame.new(0, baseYOffset, newZOffset)
					end
				end
				
				-- Mise à jour complète (pour les effets visuels)
				updateBackpack()
			end
		end
		
		-- Désactiver le mode initialisation après 0.5 seconde supplémentaire
		task.wait(0.5)
		isInitializing = false
		print("🎒 [SPAWN] Initialisation terminée, animations activées")
	end)
end

-- Fonction pour surveiller les changements dans le sac à bonbons
local function setupCandyListener()
	local playerData = player:WaitForChild("PlayerData")
	local sacBonbons = playerData:WaitForChild("SacBonbons")

	local function connectCandySlot(slot)
		if slot:IsA("IntValue") then
			slot.Changed:Connect(function(newValue)
				updateBackpack() -- Pas de délai
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
		updateBackpack() -- Pas de délai
	end)

	sacBonbons.ChildRemoved:Connect(function(removedSlot)
		updateBackpack() -- Pas de délai
	end)
	
	-- Écouter la suppression de Tools (vente) - IMMÉDIAT
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		backpack.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("IsCandy") then
				updateBackpack() -- Pas de délai
			end
		end)
	end
	
	-- Écouter aussi dans le Character (si le joueur tient un bonbon)
	if player.Character then
		player.Character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("IsCandy") then
				updateBackpack() -- Pas de délai
			end
		end)
	end

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
			print("🎒 SAC VISUEL: Rafraîchissement demandé")
			if currentBackpack then
				updateBackpack()
				print("🎒 SAC VISUEL: Rafraîchissement effectué")
			end
		end)
		print("🎒 SAC VISUEL: Écoute des rafraîchissements activée")
	else
		warn("⚠️ SAC VISUEL: BackpackRefreshEvent introuvable")
	end
end)

-- 🍬 Écouter l'événement de ramassage pour mettre à jour instantanément
task.spawn(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local pickupEvent = ReplicatedStorage:WaitForChild("PickupCandyEvent", 10)
	if pickupEvent then
		-- Quand le serveur confirme le ramassage, mettre à jour immédiatement
		pickupEvent.OnClientEvent:Connect(function()
			if currentBackpack then
				-- Petit délai pour laisser le temps au serveur de mettre à jour les données
				task.wait(0.05)
				updateBackpack()
				print("🍬 SAC VISUEL: Mise à jour après ramassage de bonbon")
			end
		end)
		print("🍬 SAC VISUEL: Écoute des ramassages activée")
	end
end)

-- Fonction de test manuel
local function testBackpack()
	print("🧪 TEST MANUEL: Forçage de mise à jour du sac")
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