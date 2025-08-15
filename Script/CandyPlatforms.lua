--[[
    🏭 PLATEFORMES À BONBONS - SYSTÈME SIMPLE
    Plateformes physiques sur l'île où poser directement les bonbons
    
    Utilisation: Cliquez sur une plateforme vide avec un bonbon équipé
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Configuration
local CONFIG = {
	GENERATION_INTERVAL = 5,    -- Génère argent toutes les 5 secondes
	BASE_GENERATION = 10,       -- Argent de base généré
	PICKUP_DISTANCE = 8,        -- Distance pour ramasser l'argent
	LEVITATION_HEIGHT = 3,      -- Hauteur de lévitation du bonbon
	ROTATION_SPEED = 2,         -- Vitesse de rotation (radians par seconde)
	-- Déblocage des plateformes
	UNLOCK_BASE_COST = 200,     -- Prix de base pour débloquer la 1ère plateforme payante
	UNLOCK_COST_GROWTH = 1.5,   -- Multiplicateur de coût pour chaque plateforme suivante
}

-- Variables globales
local activePlatforms = {}
local moneyDrops = {}

-- 🔧 Utilitaires déblocage plateformes
local function getPlayerIslandModel(player)
	if not player then return nil end
	local islandByName = workspace:FindFirstChild("Ile_" .. player.Name)
	if islandByName and islandByName:IsA("Model") then return islandByName end
	local slot = player:GetAttribute("IslandSlot")
	if slot then
		local islandBySlot = workspace:FindFirstChild("Ile_Slot_" .. tostring(slot))
		if islandBySlot and islandBySlot:IsA("Model") then return islandBySlot end
	end
	return nil
end

local function findIslandContainerForPart(part)
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") and typeof(current.Name) == "string" and string.match(current.Name, "^Ile_") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isPlatformInPlayersIsland(platform, player)
	local platformIsland = findIslandContainerForPart(platform)
	local playerIsland = getPlayerIslandModel(player)
	return platformIsland ~= nil and playerIsland ~= nil and platformIsland == playerIsland
end

local function getPlatformIndex(platform)
	if not platform or not platform.Name then return nil end
	local index = string.match(platform.Name, "^Platform(%d+)$")
	return index and tonumber(index) or nil
end

local function getPlayerUnlockedCount(player)
	local pd = player and player:FindFirstChild("PlayerData")
	local pu = pd and pd:FindFirstChild("PlatformsUnlocked")
	return (pu and pu.Value) or 1
end

local function getUnlockCostForIndex(index)
	if not index or index <= 1 then return CONFIG.UNLOCK_BASE_COST end -- Platform1 payante désormais
	local n = index
	local cost = math.floor(CONFIG.UNLOCK_BASE_COST * (CONFIG.UNLOCK_COST_GROWTH ^ (n - 1)))
	-- Arrondir à la dizaine supérieure pour lisibilité
	return math.max(0, cost - (cost % 10) + 10)
end

local function _isPlatformUnlockedForPlayer(player, platform)
	local idx = getPlatformIndex(platform)
	if not idx then return true end
	return idx <= getPlayerUnlockedCount(player)
end

-- 🔄 Fonction pour mettre à jour le texte des ProximityPrompt
local function updatePlatformPromptText(platform, player)
	local proximityPrompt = platform:FindFirstChild("ProximityPrompt")
	if not proximityPrompt then return end

	-- Si la plateforme n'appartient pas à l'île du joueur, indiquer indisponible
	if not isPlatformInPlayersIsland(platform, player) then
		proximityPrompt.ActionText = "Indisponible"
		proximityPrompt.ObjectText = "Autre île"
		return
	end

	-- Calculer index et état de déblocage
	local idx = getPlatformIndex(platform)
	local unlockedCount = getPlayerUnlockedCount(player)
	local isUnlocked = not idx or (idx <= unlockedCount)

	-- Vérifier si la plateforme a déjà un bonbon
	local isOccupied = activePlatforms[platform] ~= nil

	-- Vérifier si le joueur a un bonbon équipé
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local tool = humanoid and (humanoid:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool"))
	local hasCandy = tool and tool:GetAttribute("IsCandy")

	-- Déterminer le texte selon la situation
	if not isUnlocked then
		-- Verrouillée pour ce joueur
		if idx and idx > unlockedCount + 1 then
			proximityPrompt.ActionText = "Locked"
			proximityPrompt.ObjectText = "Unlock First Plateform " .. (unlockedCount + 1)
		else
			local cost = getUnlockCostForIndex(idx or (unlockedCount + 1))
			proximityPrompt.ActionText = "Unlock"
			proximityPrompt.ObjectText = "Plateform " .. (idx or "?") .. " (" .. cost .. "$)"
		end
	elseif isOccupied then
		-- Il y a déjà un bonbon sur la plateforme
		if hasCandy then
			proximityPrompt.ActionText = "Replace"
			proximityPrompt.ObjectText = "Candy on Platform"
		else
			proximityPrompt.ActionText = "Remove"
			proximityPrompt.ObjectText = "Platform Candy"
		end
	else
		-- Plateforme vide
		if hasCandy then
			proximityPrompt.ActionText = "Place"
			proximityPrompt.ObjectText = "Candy on Platform"
		else
			proximityPrompt.ActionText = "Place"
			proximityPrompt.ObjectText = "Candy (Equip first)"
		end
	end
end



-- 🕱️ Gestion du clic sur une plateforme
function handlePlatformClick(player, platform)
	print("🕱️ [DEBUG] Clic détecté par", player.Name, "sur plateforme", platform.Name)

	-- Bloquer toute interaction si ce n'est pas l'île du joueur
	if not isPlatformInPlayersIsland(platform, player) then
		print("🔒 [DEBUG] Interaction refusée: plateforme d'une autre île")
		updatePlatformPromptText(platform, player)
		return
	end

	-- Gestion du déblocage si nécessaire
	local idx = getPlatformIndex(platform)
	local unlockedCount = getPlayerUnlockedCount(player)
	if idx and idx > unlockedCount then
		-- Autoriser uniquement le prochain index
		if idx > unlockedCount + 1 then
			print("🔒 [DEBUG] Tentative de débloquer une plateforme hors ordre. Prochaine requise:", unlockedCount + 1)
			updatePlatformPromptText(platform, player)
			return
		end
		local cost = getUnlockCostForIndex(idx)
		local canPay = false
		if _G.GameManager and _G.GameManager.getArgent and _G.GameManager.retirerArgent then
			local current = _G.GameManager.getArgent(player)
			if current >= cost then
				canPay = _G.GameManager.retirerArgent(player, cost)
			end
		else
			-- Fallback minimaliste
			local ls = player:FindFirstChild("leaderstats")
			if ls and ls:FindFirstChild("Argent") and ls.Argent.Value >= cost then
				ls.Argent.Value -= cost
				canPay = true
			end
		end
		if canPay then
			local pd = player:FindFirstChild("PlayerData")
			local pu = pd and pd:FindFirstChild("PlatformsUnlocked")
			if pu then pu.Value = math.max(pu.Value, idx) end
			print("✅ [DEBUG] Plateforme", idx, "débloquée pour", player.Name, "(payé", cost, ")")
		else
			print("❌ [DEBUG] Fonds insuffisants pour débloquer la plateforme", idx, "(coût:", cost, ")")
		end
		-- Mettre à jour le prompt et arrêter ici (2 clics: un pour acheter, un pour placer)
		task.wait(0.05)
		updatePlatformPromptText(platform, player)
		return
	end

	-- Vérifier si la plateforme est occupée
	local isOccupied = activePlatforms[platform] ~= nil

	-- Gérer les différents cas selon la situation
	local character = player.Character
	if not character then 
		print("❌ [DEBUG] Pas de personnage")
		return 
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then 
		print("❌ [DEBUG] Pas d'humanoïde")
		return 
	end

	-- Chercher l'outil équipé (peut être dans humanoid ou character)
	local tool = humanoid:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
	local hasCandy = tool and tool:GetAttribute("IsCandy")

	if isOccupied then
		-- Il y a déjà un bonbon sur la plateforme
		if hasCandy then
			-- REMPLACER : Retirer l'ancien et placer le nouveau
			print("🔄 [DEBUG] Remplacement du bonbon en cours...")
			removeCandyFromPlatform(platform)
			placeCandyOnPlatform(player, platform, tool)
		else
			-- RETIRER : Juste retirer le bonbon existant
			print("🗑️ [DEBUG] Retrait du bonbon en cours...")
			removeCandyFromPlatform(platform)
		end
	else
		-- Plateforme vide
		if hasCandy then
			-- PLACER : Placer le bonbon
			print("✅ [DEBUG] Placement du bonbon en cours...")
			placeCandyOnPlatform(player, platform, tool)
		else
			-- Pas de bonbon équipé
			print("💡 [DEBUG] Équipez un bonbon d'abord!")
			return
		end
	end
end

-- 🍬 Placer un bonbon sur une plateforme
function placeCandyOnPlatform(player, platform, tool)
	local candyName = tool.Name
	local stackSize = tool:GetAttribute("StackSize") or 1

	print("🔧 [DEBUG] === DÉBUT PLACEMENT BONBON ===")
	print("🔧 [DEBUG] Tool original:", tool.Name, "Type:", tool.ClassName)

	-- Trouver la partie Handle du tool original
	local originalHandle = tool:FindFirstChildOfClass("BasePart") or tool:FindFirstChild("Handle")
	if not originalHandle then
		print("❌ [DEBUG] Pas de Handle trouvé dans le tool!")
		return
	end

	print("🔧 [DEBUG] Handle original trouvé:", originalHandle.Name, "Taille:", originalHandle.Size)

	-- Créer un nouveau Model et transférer tout le contenu du Tool
	local candyModel = Instance.new("Model")
	candyModel.Name = "FloatingCandy_" .. candyName

	-- Cloner le Tool complet temporairement
	local tempTool = tool:Clone()

	-- Transférer tous les enfants du Tool vers le Model
	for _, child in pairs(tempTool:GetChildren()) do
		child.Parent = candyModel
		print("🔧 [DEBUG] Transféré:", child.Name, "Type:", child.ClassName)
	end

	-- Supprimer le tool temporaire
	tempTool:Destroy()

	-- Trouver la vraie partie visible du bonbon (pas le Handle générique)
	local mainPart = nil
	local handlePart = nil

	-- D'abord, chercher une MeshPart ou une partie avec un Mesh (la vraie apparence)
	for _, child in pairs(candyModel:GetChildren()) do
		if child:IsA("MeshPart") then
			mainPart = child
			print("🔧 [DEBUG] MeshPart trouvé comme partie principale:", child.Name)
			break
		elseif child:IsA("BasePart") and child:FindFirstChildOfClass("SpecialMesh") then
			mainPart = child
			print("🔧 [DEBUG] BasePart avec SpecialMesh trouvé:", child.Name)
			break
		elseif child:IsA("BasePart") and child.Name == "Handle" then
			handlePart = child
		end
	end

	-- Si pas de MeshPart, utiliser le Handle mais cacher les autres parties
	if not mainPart then
		mainPart = handlePart or candyModel:FindFirstChildOfClass("BasePart")
		print("🔧 [DEBUG] Utilisation du Handle comme partie principale:", mainPart and mainPart.Name or "AUCUN")
	end

	if not mainPart then
		print("❌ [DEBUG] Impossible de trouver une partie principale dans le model!")
		candyModel:Destroy()
		return
	end

	-- Cacher toutes les autres parties pour éviter les doublons visuels
	for _, child in pairs(candyModel:GetChildren()) do
		if child:IsA("BasePart") and child ~= mainPart then
			child.Transparency = 1 -- Rendre invisible
			child.CanCollide = false
			print("🔧 [DEBUG] Partie cachée:", child.Name)
		end
	end

	-- Définir la PrimaryPart pour que le Model soit bien géré
	candyModel.PrimaryPart = mainPart

	-- Maintenant placer le Model dans workspace
	candyModel.Parent = workspace

	print("🔧 [DEBUG] Model créé avec contenu complet:", candyModel.Name, "avec PrimaryPart:", candyModel.PrimaryPart.Name)
	print("🔧 [DEBUG] Enfants du model:", #candyModel:GetChildren())
	for _, child in pairs(candyModel:GetChildren()) do
		print("  - ", child.Name, ":", child.ClassName)
		if child:IsA("BasePart") then
			print("    Enfants de", child.Name, ":")
			for _, subChild in pairs(child:GetChildren()) do
				print("      - ", subChild.Name, ":", subChild.ClassName)
			end
		end
	end

	-- Configurer la partie principale AVANT de la positionner
	mainPart.Anchored = true
	mainPart.CanCollide = false

	-- S'assurer que le bonbon est visible
	mainPart.Transparency = 0  -- Complètement opaque
	if mainPart.Size.Magnitude < 1 then
		mainPart.Size = Vector3.new(2, 2, 2)  -- Taille minimum pour être visible
		print("🔧 [DEBUG] Taille du bonbon agrandie à:", mainPart.Size)
	end

	-- Positionner au-dessus de la plateforme
	local platformTop = platform.Position.Y + (platform.Size.Y / 2)
	local targetPosition = Vector3.new(platform.Position.X, platformTop + CONFIG.LEVITATION_HEIGHT, platform.Position.Z)

	mainPart.Position = targetPosition

	print("🔧 [DEBUG] Position calculée:")
	print("  - Plateforme:", platform.Position)
	print("  - Dessus plateforme:", platformTop)
	print("  - Position cible:", targetPosition)
	print("  - Position réelle:", mainPart.Position)
	print("  - Ancré:", mainPart.Anchored)
	print("  - Parent du bonbon:", candyModel.Parent)
	print("  - Parent de la partie:", mainPart.Parent)

	-- Vérifier que le bonbon est bien visible
	if not candyModel.Parent or not mainPart.Parent then
		print("❌ [DEBUG] ERREUR: Le bonbon n'est pas correctement parent!")
		print("  - candyModel.Parent:", candyModel.Parent)
		print("  - mainPart.Parent:", mainPart.Parent)
		candyModel:Destroy()
		return
	end

	print("✅ [DEBUG] Bonbon 3D créé avec succès:", candyName, "sur plateforme")
	print("✅ [DEBUG] Le bonbon devrait être visible à la position:", mainPart.Position)
	print("🔍 [DEBUG] Propriétés de visibilité:")
	print("  - Transparency:", mainPart.Transparency)
	print("  - Size:", mainPart.Size)
	print("  - Material:", mainPart.Material)
	print("  - Color:", mainPart.Color)
	print("  - Type:", mainPart.ClassName)
	if mainPart:IsA("BasePart") and not mainPart:IsA("MeshPart") then
		print("  - Shape:", mainPart.Shape)
	end

	-- Sauvegarder une copie du tool original AVANT de le supprimer
	local originalToolCopy = tool:Clone()

	-- Debug avant suppression
	print("🔧 [DEBUG] Tool avant suppression:")
	print("  - Parent:", tool.Parent and tool.Parent.Name or "NIL")
	print("  - Dans character:", tool.Parent == player.Character)
	print("  - Dans backpack:", tool.Parent == player.Backpack)

	-- Retirer le bonbon original du joueur (équipé ou dans backpack)
	tool.Parent = nil

	print("🔧 [DEBUG] Tool supprimé de l'inventaire")

	-- Éclairage du bonbon
	local candyLight = Instance.new("PointLight")
	candyLight.Color = mainPart.Color
	candyLight.Brightness = 1.5
	candyLight.Range = 10
	candyLight.Parent = mainPart

	-- Particules
	local attachment = Instance.new("Attachment")
	attachment.Parent = mainPart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(mainPart.Color)
	particles.Size = NumberSequence.new(0.2, 0.5)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 20
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Speed = NumberRange.new(2, 5)
	particles.Parent = attachment

	print("✨ [DEBUG] Effets ajoutés à la partie:", mainPart.Name)

	-- ProximityPrompt pour retirer le bonbon
	local removePrompt = Instance.new("ProximityPrompt")
	removePrompt.ActionText = "Retirer Bonbon"
	removePrompt.ObjectText = candyName
	removePrompt.HoldDuration = 0
	removePrompt.MaxActivationDistance = 10
	removePrompt.RequiresLineOfSight = false
	removePrompt.Parent = mainPart

	removePrompt.Triggered:Connect(function(clickingPlayer)
		if clickingPlayer == player then
			removeCandyFromPlatform(platform)
		end
	end)

	print("🔘 [DEBUG] ProximityPrompt retrait ajouté à:", mainPart.Name)

	-- Sauvegarder les données
	activePlatforms[platform] = {
		player = player,
		candy = candyName,
		candyModel = candyModel,
		mainPart = mainPart, -- Sauvegarder la référence vers la partie principale
		originalTool = originalToolCopy, -- Sauvegarder une copie du tool original pour le retour
		lastGeneration = tick(),
		stackSize = stackSize,
		totalGenerated = 0,
		moneyStack = nil -- Référence vers la boule d'argent stackée
	}

	-- Debug final
	print("✅ [DEBUG] Bonbon placé avec succès:")
	print("  - Type de candyModel:", candyModel.ClassName)
	print("  - Type de mainPart:", mainPart.ClassName)
	print("  - Position finale:", mainPart.Position)
	print("  - Ancré:", mainPart.Anchored)

	print("✅ [DEBUG] Bonbon placé:", candyName, "par", player.Name, "Stack:", stackSize)
end

-- 🗑️ Retirer un bonbon d'une plateforme
function removeCandyFromPlatform(platform)
	local data = activePlatforms[platform]
	if not data then return end

	-- Rendre le bonbon au joueur s'il est encore connecté
	if data.player and data.player.Parent and data.originalTool then
		local backpack = data.player:FindFirstChild("Backpack")
		if backpack then
			local restoredTool = data.originalTool:Clone()
			restoredTool.Parent = backpack
			print("✅ [DEBUG] Bonbon", data.candy, "rendu à", data.player.Name)
		else
			print("⚠️ [DEBUG] Impossible de trouver le Backpack de", data.player.Name)
		end
	else
		print("⚠️ [DEBUG] Joueur déconnecté ou tool original manquant")
	end

	-- Supprimer le modèle visuel
	if data.candyModel then
		data.candyModel:Destroy()
	end

	-- Nettoyer la stack d'argent aussi
	if data.moneyStack and data.moneyStack.Parent then
		moneyDrops[data.moneyStack] = nil
		data.moneyStack:Destroy()
	end

	activePlatforms[platform] = nil
	print("🗑️ Bonbon retiré de la plateforme et rendu au joueur")
end

-- 💰 Générer de l'argent (système de stack)
function generateMoney(platform, data)
	local currentTime = tick()
	-- Passif: EssenceCommune → fréquence x2 (intervalle ÷2)
	local interval = CONFIG.GENERATION_INTERVAL
	do
		local pd = data.player and data.player:FindFirstChild("PlayerData")
		local su = pd and pd:FindFirstChild("ShopUnlocks")
		local com = su and su:FindFirstChild("EssenceCommune")
		if com and com.Value == true then
			interval = math.max(1, interval / 2)
		end
	end
	if currentTime - data.lastGeneration < interval then
		return
	end

	local amount = CONFIG.BASE_GENERATION * data.stackSize
	-- Passif: EssenceLegendaire → gains x2
	do
		local pd = data.player and data.player:FindFirstChild("PlayerData")
		local su = pd and pd:FindFirstChild("ShopUnlocks")
		local leg = su and su:FindFirstChild("EssenceLegendaire")
		if leg and leg.Value == true then
			amount = amount * 2
		end
	end

	-- Si pas de boule d'argent existante, en créer une
	if not data.moneyStack or not data.moneyStack.Parent then
		local money = Instance.new("Part")
		money.Name = "MoneyStack_" .. data.player.Name
		money.Material = Enum.Material.Neon
		money.BrickColor = BrickColor.new("Bright yellow")
		money.Shape = Enum.PartType.Ball
		money.Size = Vector3.new(1, 1, 1)
		money.Position = platform.Position + Vector3.new(2, 2, 0) -- À côté de la plateforme
		money.Anchored = true
		money.CanCollide = false
		money.Parent = workspace

		-- Éclairage de l'argent
		local moneyLight = Instance.new("PointLight")
		moneyLight.Color = Color3.fromRGB(255, 255, 0)
		moneyLight.Brightness = 2
		moneyLight.Range = 8
		moneyLight.Parent = money

		-- GUI avec montant
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Size = UDim2.new(0, 120, 0, 60)
		billboardGui.StudsOffset = Vector3.new(0, 2, 0)
		billboardGui.Parent = money

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "💰 " .. amount .. "$"
		label.TextColor3 = Color3.fromRGB(255, 255, 0)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Name = "AmountLabel"
		label.Parent = billboardGui

		-- Animation bobbing
		local bobTween = TweenService:Create(money, 
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Position = money.Position + Vector3.new(0, 1, 0)}
		)
		bobTween:Play()

		-- Sauvegarder la référence
		data.moneyStack = money

		-- Sauvegarder pour ramassage
		moneyDrops[money] = {
			player = data.player,
			amount = amount,
			created = currentTime,
			platform = platform -- Référence vers la plateforme
		}

	else
		-- Mettre à jour le montant existant
		local currentAmount = moneyDrops[data.moneyStack].amount
		local newAmount = currentAmount + amount
		moneyDrops[data.moneyStack].amount = newAmount

		-- Mettre à jour le texte
		local billboardGui = data.moneyStack:FindFirstChild("BillboardGui")
		if billboardGui then
			local label = billboardGui:FindFirstChild("AmountLabel")
			if label then
				label.Text = "💰 " .. newAmount .. "$"
			end
		end

		-- Effet visuel de stack (agrandir légèrement)
		local currentSize = data.moneyStack.Size
		local maxSize = Vector3.new(2, 2, 2)
		if currentSize.X < maxSize.X then
			data.moneyStack.Size = currentSize + Vector3.new(0.1, 0.1, 0.1)
		end
	end

	data.lastGeneration = currentTime
	data.totalGenerated = data.totalGenerated + amount

	print("💰 Argent stacké:", amount, "$ Total sur stack:", moneyDrops[data.moneyStack].amount)
end

-- 🚶 Ramassage automatique par proximité
function checkMoneyPickup(player)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local playerPos = rootPart.Position

	for money, data in pairs(moneyDrops) do
		if data.player == player and money.Parent then
			local distance = (playerPos - money.Position).Magnitude
			if distance <= CONFIG.PICKUP_DISTANCE then
				-- Ajouter l'argent au joueur
				if _G.GameManager and _G.GameManager.ajouterArgent then
					_G.GameManager.ajouterArgent(player, data.amount)
				else
					-- Fallback
					local playerData = player:FindFirstChild("PlayerData")
					if playerData and playerData:FindFirstChild("Argent") then
						playerData.Argent.Value = playerData.Argent.Value + data.amount
					end
				end

				-- Effet de ramassage
				local effect = money:Clone()
				effect.Parent = workspace

				local pickupTween = TweenService:Create(effect,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Position = playerPos + Vector3.new(0, 5, 0),
						Size = Vector3.new(0.1, 0.1, 0.1),
						Transparency = 1
					}
				)
				pickupTween:Play()
				Debris:AddItem(effect, 0.5)

				-- Supprimer l'argent et nettoyer la référence dans la plateforme
				money:Destroy()
				moneyDrops[money] = nil

				-- Nettoyer la référence dans activePlatforms
				if data.platform and activePlatforms[data.platform] then
					activePlatforms[data.platform].moneyStack = nil
				end

				print("💰 Ramassé:", data.amount, "$ par", player.Name)
			end
		end
	end
end

-- 🔄 Rotation des bonbons
function rotateCandies()
	for platform, data in pairs(activePlatforms) do
		if data.candyModel and data.candyModel.Parent and data.mainPart and data.mainPart.Parent then
			-- Sauvegarder la position pour éviter les déplacements
			local fixedPosition = data.mainPart.Position

			-- Rotation simple de la partie principale seulement
			local currentOrientation = data.mainPart.Orientation
			data.mainPart.Orientation = Vector3.new(
				currentOrientation.X,
				currentOrientation.Y + 2, -- 2 degrés par frame
				currentOrientation.Z
			)

			-- Forcer la position à rester fixe
			data.mainPart.Position = fixedPosition

			-- Debug occasionnel pour vérifier
			if math.random(1, 60) == 1 then -- 1 fois par seconde environ
				print("🔄 [DEBUG] Rotation bonbon:", data.candy, "Position:", data.mainPart.Position)
				print("  - Orientation:", data.mainPart.Orientation)
				print("  - Ancré:", data.mainPart.Anchored)
				print("  - Parent:", data.mainPart.Parent and data.mainPart.Parent.Name or "NIL")
			end
		else
			-- Debug si la rotation ne peut pas se faire
			if math.random(1, 120) == 1 then -- Plus rare
				print("⚠️ [DEBUG] Rotation impossible pour:", data and data.candy or "INCONNU")
				print("  - candyModel existe:", data and data.candyModel and "OUI" or "NON")
				print("  - candyModel parent:", data and data.candyModel and data.candyModel.Parent and data.candyModel.Parent.Name or "NIL")
				print("  - mainPart existe:", data and data.mainPart and "OUI" or "NON")
				print("  - mainPart parent:", data and data.mainPart and data.mainPart.Parent and data.mainPart.Parent.Name or "NIL")
			end
		end
	end
end

-- 🔄 Boucle principale
RunService.Heartbeat:Connect(function()
	rotateCandies()

	for platform, data in pairs(activePlatforms) do
		if data.player.Parent then
			generateMoney(platform, data)
			checkMoneyPickup(data.player)
		else
			-- Nettoyer joueur déconnecté
			removeCandyFromPlatform(platform)
		end
	end
end)

-- 🔄 Mise à jour périodique des textes des ProximityPrompt
task.spawn(function()
	while true do
		task.wait(1) -- Toutes les secondes

		-- Mettre à jour les textes pour tous les joueurs près des plateformes
		for _, player in pairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local playerPos = player.Character.HumanoidRootPart.Position

				-- Chercher les plateformes proches
				for platform, _ in pairs(activePlatforms) do
					if (playerPos - platform.Position).Magnitude <= 15 then
						updatePlatformPromptText(platform, player)
					end
				end

				-- Chercher aussi les plateformes vides (avec le nouveau système)
				local function searchEmptyPlatforms(parent, depth)
					depth = depth or 0
					if depth > 10 then return end

					for _, child in pairs(parent:GetChildren()) do
						if child:IsA("BasePart") and string.match(child.Name, "^Platform%d+$") and not activePlatforms[child] then
							if (playerPos - child.Position).Magnitude <= 15 then
								updatePlatformPromptText(child, player)
							end
						elseif child:IsA("Model") or child:IsA("Folder") then
							searchEmptyPlatforms(child, depth + 1)
						end
					end
				end

				searchEmptyPlatforms(workspace)
			end
		end
	end
end)

-- 🧹 Nettoyage à la déconnexion
Players.PlayerRemoving:Connect(function(player)
	for platform, data in pairs(activePlatforms) do
		if data.player == player then
			removeCandyFromPlatform(platform)
		end
	end

	-- Supprimer l'argent du joueur
	for money, data in pairs(moneyDrops) do
		if data.player == player then
			money:Destroy()
			moneyDrops[money] = nil
		end
	end
end)

-- 🔧 Configurer une plateforme existante (au lieu de la créer)
local function setupPlatform(platform)
	print("🔧 [DEBUG] Configuration de la plateforme:", platform.Name)

	-- Vérifier que c'est bien une Part
	if not platform:IsA("BasePart") then
		print("⚠️ [DEBUG] L'objet n'est pas une BasePart:", platform.Name)
		return
	end

	-- Appliquer le style des plateformes (optionnel, vous pouvez garder votre style)
	platform.Material = Enum.Material.Neon
	platform.BrickColor = BrickColor.new("Bright blue")
	platform.Anchored = true
	platform.CanCollide = true

	-- Ajouter l'éclairage s'il n'existe pas déjà
	if not platform:FindFirstChild("PointLight") then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(0, 162, 255)
		light.Brightness = 2
		light.Range = 15
		light.Parent = platform
	end

	-- Ajouter le ProximityPrompt s'il n'existe pas déjà
	if not platform:FindFirstChild("ProximityPrompt") then
		local proximityPrompt = Instance.new("ProximityPrompt")
		proximityPrompt.ActionText = "Placer Bonbon"
		proximityPrompt.ObjectText = "Plateforme"
		proximityPrompt.HoldDuration = 0
		proximityPrompt.MaxActivationDistance = 10
		proximityPrompt.RequiresLineOfSight = false
		proximityPrompt.Parent = platform

		-- Gestion de l'interaction
		proximityPrompt.Triggered:Connect(function(player)
			handlePlatformClick(player, platform)
			-- Mettre à jour le texte après l'action
			task.wait(0.1)
			updatePlatformPromptText(platform, player)
		end)

		-- Mettre à jour le texte quand un joueur s'approche
		proximityPrompt.PromptShown:Connect(function(player)
			updatePlatformPromptText(platform, player)
		end)
	end

	print("✅ [DEBUG] Plateforme configurée:", platform.Name, "à", platform.Position)
end

-- 🏭 Configurer les plateformes personnalisées existantes
local function setupCustomPlatforms()
	print("🔍 [DEBUG] Recherche des plateformes personnalisées...")

	-- Fonction récursive pour chercher dans tous les modèles/dossiers
	local function searchForPlatforms(parent, depth)
		depth = depth or 0
		if depth > 10 then return end -- Éviter les boucles infinies

		for _, child in pairs(parent:GetChildren()) do
			-- Chercher les Parts nommées Platform1, Platform2, etc.
			if child:IsA("BasePart") and string.match(child.Name, "^Platform%d+$") then
				print("✅ [DEBUG] Plateforme trouvée:", child.Name, "à", child.Position)
				setupPlatform(child)
			elseif child:IsA("Model") or child:IsA("Folder") then
				-- Chercher récursivement dans les modèles et dossiers
				searchForPlatforms(child, depth + 1)
			end
		end
	end

	-- Chercher dans workspace
	searchForPlatforms(workspace)

	print("🏭 [DEBUG] Configuration des plateformes personnalisées terminée!")
end

-- Initialisation
setupCustomPlatforms()

-- 🔄 Détection de nouvelles plateformes (pour les îles qui se créent dynamiquement)
local function watchForNewPlatforms()
	workspace.ChildAdded:Connect(function(child)
		task.wait(1) -- Attendre que l'objet soit complètement chargé
		if child:IsA("Model") or child:IsA("Folder") then
			-- Chercher des plateformes dans le nouveau modèle
			for _, subChild in pairs(child:GetDescendants()) do
				if subChild:IsA("BasePart") and string.match(subChild.Name, "^Platform%d+$") then
					print("🆕 [DEBUG] Nouvelle plateforme détectée:", subChild.Name)
					setupPlatform(subChild)
				end
			end
		elseif child:IsA("BasePart") and string.match(child.Name, "^Platform%d+$") then
			print("🆕 [DEBUG] Nouvelle plateforme détectée:", child.Name)
			setupPlatform(child)
		end
	end)
end

watchForNewPlatforms()

-- 🔍 Fonction de diagnostic
local function diagnosticCandies()
	print("🔍 === DIAGNOSTIC DES BONBONS ===")
	local count = 0
	for platform, data in pairs(activePlatforms) do
		count = count + 1
		print("Bonbon", count, ":", data.candy)
		print("  - Model existe:", data.candyModel and "OUI" or "NON")
		print("  - Model parent:", data.candyModel and data.candyModel.Parent and data.candyModel.Parent.Name or "NIL")
		print("  - Part existe:", data.mainPart and "OUI" or "NON")
		if data.mainPart then
			print("  - Part parent:", data.mainPart.Parent and data.mainPart.Parent.Name or "NIL")
			print("  - Position:", data.mainPart.Position)
			print("  - Transparency:", data.mainPart.Transparency)
			print("  - Size:", data.mainPart.Size)
		end
		print("---")
	end
	if count == 0 then
		print("Aucun bonbon actif trouvé")
	end
	print("🔍 === FIN DIAGNOSTIC ===")
end

-- Debug périodique
task.spawn(function()
	while true do
		task.wait(10) -- Toutes les 10 secondes
		diagnosticCandies()
	end
end)

print("🏭 Système de plateformes simples initialisé!")
print("💡 Cliquez sur une plateforme bleue avec un bonbon équipé!")
print("💡 Cliquez sur le bonbon flottant pour le retirer!")
