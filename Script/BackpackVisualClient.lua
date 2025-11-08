-- BackpackVisualClient.lua
-- Script côté client pour afficher le compteur de bonbons (BillboardGui)
-- Le sac 3D est créé côté serveur pour être visible par tous
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Configuration du sac
local BACKPACK_CONFIG = {
	baseSize = Vector3.new(1.2, 1.5, 0.8), -- Taille de base du sac
	maxSize = Vector3.new(3.5, 4.0, 2.0),  -- Taille maximale BEAUCOUP plus grosse
	maxCandies = 300,                       -- Nombre de bonbons pour la taille max (300 bonbons)
	animationSpeed = 0.6,                   -- Vitesse d'animation du changement de taille
	glowIntensity = 0.5                     -- Intensité de la lueur selon la rareté
}

local currentBillboard = nil
local currentCandyCount = 0
local rainbowConnection = nil
local isInitializing = false
local updateBackpackEvent = nil

-- Fonction pour créer le BillboardGui (visible uniquement par le propriétaire)
local function createBillboard(backpackMain)
	-- Étiquette avec le nombre de bonbons
	local gui = Instance.new("BillboardGui")
	gui.Name = "CandyCounter"
	gui.Size = UDim2.new(0, 120, 0, 30)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.Adornee = backpackMain
	gui.AlwaysOnTop = true
	gui.Parent = backpackMain

	-- Frame de fond
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	background.BackgroundTransparency = 0.3
	background.BorderSizePixel = 0
	background.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = background

	-- Container pour les chiffres
	local digitsContainer = Instance.new("Frame")
	digitsContainer.Name = "DigitsContainer"
	digitsContainer.Size = UDim2.new(1, 0, 1, 0)
	digitsContainer.BackgroundTransparency = 1
	digitsContainer.Parent = background

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = digitsContainer
	
	return gui
end

-- Fonction pour trouver le sac du joueur (créé par le serveur)
local function findPlayerBackpack()
	if not player.Character then return nil end
	return player.Character:FindFirstChild("VisualBackpack")
end

-- Fonction pour calculer le nombre total de bonbons
local function getTotalCandyCount()
	local total = 0
	
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") then
				local stackSize = tool:GetAttribute("StackSize") or 1
				total = total + stackSize
			end
		end
	end

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

-- Fonction pour calculer la rareté moyenne
local function getAverageRarity()
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return 1 end

	local sacBonbons = playerData:FindFirstChild("SacBonbons")
	if not sacBonbons then return 1 end

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

-- Fonction pour mettre à jour le sac
local function updateBackpack()
	local backpack = findPlayerBackpack()
	if not backpack then return end

	local main = backpack:FindFirstChild("BackpackMain")
	if not main then return end

	local candyCount = getTotalCandyCount()
	local averageRarity = getAverageRarity()

	-- Envoyer au serveur pour mettre à jour la taille (visible par tous)
	if updateBackpackEvent then
		updateBackpackEvent:FireServer(candyCount, averageRarity)
	end

	-- Mettre à jour le BillboardGui (visible uniquement par le propriétaire)
	local gui = main:FindFirstChild("CandyCounter")
	if not gui then
		gui = createBillboard(main)
		currentBillboard = gui
	end

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

	currentCandyCount = candyCount
end

-- Fonction appelée quand le personnage spawn
local function onCharacterAdded(character)
	isInitializing = true
	
	character:WaitForChild("HumanoidRootPart")
	
	-- Nettoyer l'ancien billboard
	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	
	-- Attendre que le sac soit créé par le serveur
	task.spawn(function()
		local backpack = player:WaitForChild("Backpack", 10)
		
		if backpack then
			-- Attendre que des bonbons soient chargés
			local startTime = tick()
			local candyCount = 0
			
			repeat
				task.wait(0.2)
				candyCount = getTotalCandyCount()
			until candyCount > 0 or (tick() - startTime) > 5
			
			-- Attendre que le sac serveur soit créé
			local visualBackpack = nil
			local waitTime = 0
			while not visualBackpack and waitTime < 5 do
				visualBackpack = findPlayerBackpack()
				if not visualBackpack then
					task.wait(0.1)
					waitTime = waitTime + 0.1
				end
			end
			
			if visualBackpack then
				updateBackpack()
			end
		end
		
		task.wait(0.5)
		isInitializing = false
	end)
end

-- Fonction pour surveiller les changements
local function setupCandyListener()
	local playerData = player:WaitForChild("PlayerData")
	local sacBonbons = playerData:WaitForChild("SacBonbons")

	local function connectCandySlot(slot)
		if slot:IsA("IntValue") then
			slot.Changed:Connect(function()
				updateBackpack()
			end)
		end
	end

	for _, slot in pairs(sacBonbons:GetChildren()) do
		connectCandySlot(slot)
	end

	sacBonbons.ChildAdded:Connect(function(newSlot)
		connectCandySlot(newSlot)
		updateBackpack()
	end)

	sacBonbons.ChildRemoved:Connect(function()
		updateBackpack()
	end)
	
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		backpack.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("IsCandy") then
				updateBackpack()
			end
		end)
	end
	
	if player.Character then
		player.Character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("IsCandy") then
				updateBackpack()
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(5)
			updateBackpack()
		end
	end)
end

-- Initialisation
task.spawn(function()
	-- Attendre l'événement du serveur
	updateBackpackEvent = ReplicatedStorage:WaitForChild("UpdateBackpackSize", 10)
	
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	player:WaitForChild("PlayerData")
	setupCandyListener()
end)

-- Événements de rafraîchissement
task.spawn(function()
	local backpackRefreshEvent = ReplicatedStorage:WaitForChild("BackpackRefreshEvent", 10)
	if backpackRefreshEvent then
		backpackRefreshEvent.OnClientEvent:Connect(function()
			updateBackpack()
		end)
	end
end)

task.spawn(function()
	local pickupEvent = ReplicatedStorage:WaitForChild("PickupCandyEvent", 10)
	if pickupEvent then
		pickupEvent.OnClientEvent:Connect(function()
			task.wait(0.05)
			updateBackpack()
		end)
	end
end)

print("✅ BackpackVisualClient initialisé") 