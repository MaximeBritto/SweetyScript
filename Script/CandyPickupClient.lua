-- CandyPickupClient.lua
-- Script côté client pour ramasser automatiquement les bonbons
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pickupEvent = ReplicatedStorage:WaitForChild("PickupCandyEvent")

-- Dossier local pour les effets visuels (uniquement sur ce client)
local FX_FOLDER = workspace:FindFirstChild("ClientCandyFX") or Instance.new("Folder")
FX_FOLDER.Name = "ClientCandyFX"
FX_FOLDER.Parent = workspace

-- Distance maximale pour ramasser un bonbon
local PICKUP_DISTANCE = 8

-- Table pour éviter de ramasser plusieurs fois le même bonbon
local alreadyPickedUp = {}

-- 🍬 Flag pour désactiver temporairement le ramassage pendant la restauration
local pickupEnabled = false

-- 🚀 Cache des bonbons pour éviter GetDescendants() répétés
local candyCache = {}
local CACHE_UPDATE_INTERVAL = 1 -- Mettre à jour le cache toutes les 1 seconde

-- 🚀 OPTIMISATION: Limiter le nombre d'animations simultanées
local activeAnimations = 0
local MAX_CONCURRENT_ANIMATIONS = 10 -- Maximum 10 animations en même temps
local animationQueue = {} -- File d'attente pour les animations

-- Attendre que les données du joueur soient prêtes avant d'activer le ramassage
local function waitForPlayerDataReady()
	print("🍬 [PICKUP] Attente des données du joueur...")
	
	-- Attendre l'attribut DataReady ou le RemoteEvent
	local dataReadyEvent = ReplicatedStorage:FindFirstChild("PlayerDataReady")
	if dataReadyEvent then
		dataReadyEvent.OnClientEvent:Wait()
		print("✅ [PICKUP] Données du joueur prêtes (via RemoteEvent)")
	else
		-- Fallback: attendre l'attribut
		repeat
			task.wait(0.5)
		until player:GetAttribute("DataReady") == true
		print("✅ [PICKUP] Données du joueur prêtes (via Attribute)")
	end
	
	-- 🔧 FIX: Attendre seulement 1 seconde au lieu de 5 pour permettre le ramassage des bonbons offline
	print("⏳ [PICKUP] Attente de 1 seconde pour le chargement des bonbons...")
	task.wait(1)
	
	pickupEnabled = true
	print("✅ [PICKUP] Ramassage automatique activé!")
end

task.spawn(waitForPlayerDataReady)

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

-- Vérifie qu'un objet porte bien la marque d'un bonbon
local function isCandyModel(obj)
	return obj and obj:FindFirstChild("CandyType")
end

-- Vérifie si le joueur peut ramasser ce bonbon (propriétaire uniquement)
local function canPickupCandy(candyModel)
	if not isCandyModel(candyModel) then
		return false
	end
	
	local ownerTag = candyModel:FindFirstChild("CandyOwner")
	if not ownerTag or not ownerTag:IsA("IntValue") then
		-- 🔧 SÉCURITÉ RENFORCÉE: Bloquer TOUS les bonbons sans propriétaire
		-- Plus de rétrocompatibilité - tous les nouveaux bonbons DOIVENT avoir un propriétaire
		warn("🚫 [PICKUP] Bonbon sans propriétaire BLOQUÉ:", candyModel.Name)
		return false -- BLOQUER au lieu de permettre
	end
	
	-- Vérifier si c'est le bonbon du joueur actuel
	local isOwner = ownerTag.Value == player.UserId
	if not isOwner then
		-- Debug: afficher qui est le propriétaire
		print("🚫 [PICKUP] Bonbon appartient à UserId:", ownerTag.Value, "| Joueur actuel:", player.UserId)
	end
	return isOwner
end

-- Crée une copie locale du modèle d'origine pour jouer l'animation sans
-- craindre que le serveur détruise l'objet avant la fin du tween.
local function createVisualClone(original)
	local clone = original:Clone()
	clone.Parent = FX_FOLDER -- Ne remonte pas au serveur (FilteringEnabled)

	-- S'assurer que les parties ne gênent pas la physique
	if clone:IsA("Model") then
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.Massless = true
			end
		end
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.Massless = true
	end

	-- Empêche de recliquer le clone
	alreadyPickedUp[clone] = true
	return clone
end

---------------------------------------------------------------------
-- Animation & pickup
---------------------------------------------------------------------

-- Son de ramassage (configurable)
local function playPickupSound()
	local baseSound = SoundService:FindFirstChild("CandyPickup")
	local sound
	if baseSound and baseSound:IsA("Sound") then
		sound = baseSound:Clone()
	else
		local cfg = ReplicatedStorage:FindFirstChild("CandyPickupSoundId")
		sound = Instance.new("Sound")
		if cfg and cfg:IsA("StringValue") and cfg.Value ~= "" then
			sound.SoundId = cfg.Value
		else
			sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		end
		sound.Volume = 0.6
	end
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function playCandyAnimation(model)
	-- 🚀 OPTIMISATION: Si trop d'animations en cours, simplifier
	if activeAnimations >= MAX_CONCURRENT_ANIMATIONS then
		-- Animation simplifiée instantanée
		model:Destroy()
		return
	end
	
	activeAnimations = activeAnimations + 1
	
	local character = player.Character
	if not character then
		model:Destroy()
		activeAnimations = activeAnimations - 1
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		model:Destroy()
		activeAnimations = activeAnimations - 1
		return
	end

	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	else
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	
	-- 🚀 OPTIMISATION: Limiter le nombre de parts animées
	local MAX_PARTS_TO_ANIMATE = 5
	if #parts > MAX_PARTS_TO_ANIMATE then
		-- Ne garder que les plus grosses parts
		table.sort(parts, function(a, b)
			return (a.Size.X * a.Size.Y * a.Size.Z) > (b.Size.X * b.Size.Y * b.Size.Z)
		end)
		local limitedParts = {}
		for i = 1, math.min(MAX_PARTS_TO_ANIMATE, #parts) do
			table.insert(limitedParts, parts[i])
		end
		parts = limitedParts
	end

	-- Anime chaque part avec suivi en temps réel
	local animationsCompleted = 0
	local totalAnimations = #parts
	
	for _, part in parts do
		local originalColor = part.Color
		local originalSize = part.Size
		local startPosition = part.Position
		local startTime = tick()
		local animationDuration = 0.8

		-- Animation manuelle avec suivi du joueur
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local currentCharacter = player.Character
			local currentHRP = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")

			if not currentHRP or not part.Parent then
				connection:Disconnect()
				return
			end

			local elapsed = tick() - startTime
			local progress = math.min(elapsed / animationDuration, 1)

			-- Easing: Quart In (accélération vers la fin)
			local easedProgress = progress * progress * progress * progress

			-- Position cible mise à jour en temps réel
			local currentTargetPosition = currentHRP.Position

			-- Interpolation de position, taille et couleur
			local currentPos = Vector3.new(startPosition.X, startPosition.Y, startPosition.Z):Lerp(currentTargetPosition, easedProgress)
			local currentSize = originalSize:Lerp(originalSize * 0.4, progress)
			local currentColor = originalColor:Lerp(Color3.fromRGB(51,51,51), progress * 0.5)
			local currentTransparency = progress * 0.2

			-- Appliquer les changements
			part.Position = currentPos
			part.Size = currentSize
			part.Color = currentColor
			part.Transparency = currentTransparency

			-- Fin de la phase 1
			if progress >= 1 then
				connection:Disconnect()
				animationsCompleted = animationsCompleted + 1

				-- Phase 2: Absorption avec suivi continu
				local absorbStartTime = tick()
				local absorbDuration = 0.3

				local absorbConnection
				absorbConnection = RunService.Heartbeat:Connect(function()
					local currentCharacter2 = player.Character
					local currentHRP2 = currentCharacter2 and currentCharacter2:FindFirstChild("HumanoidRootPart")

					if not currentHRP2 or not part.Parent then
						absorbConnection:Disconnect()
						return
					end

					local absorbElapsed = tick() - absorbStartTime
					local absorbProgress = math.min(absorbElapsed / absorbDuration, 1)

					-- Easing: Quart In pour l'absorption
					local absorbEasedProgress = absorbProgress * absorbProgress * absorbProgress * absorbProgress

					-- Position mise à jour pour l'absorption
					local finalTargetPosition = currentHRP2.Position
					local absorbPos = currentPos:Lerp(finalTargetPosition, absorbEasedProgress)

					-- Interpolation finale
					local finalSize = (originalSize * 0.4):Lerp(originalSize * 0.05, absorbProgress)
					local finalColor = part.Color:Lerp(originalColor:Lerp(Color3.new(1,1,1), 0.8), absorbProgress)
					local finalTransparency = 0.2 + (absorbProgress * 0.7)

					-- Appliquer les changements d'absorption
					part.Position = absorbPos
					part.Size = finalSize
					part.Color = finalColor
					part.Transparency = finalTransparency

					-- Fin de l'absorption
					if absorbProgress >= 1 then
						absorbConnection:Disconnect()
						animationsCompleted = animationsCompleted + 1

						-- Phase 3: Disparition finale
						local finalTween = TweenService:Create(
							part,
							TweenInfo.new(0.15, Enum.EasingStyle.Quad),
							{
								Transparency = 1,
								Size = Vector3.new(0,0,0)
							}
						)
						finalTween:Play()
						finalTween.Completed:Connect(function()
							part:Destroy()
							
							-- 🚀 Décrémenter le compteur quand l'animation est vraiment terminée
							if animationsCompleted >= totalAnimations then
								activeAnimations = activeAnimations - 1
							end
						end)

						-- 🚀 OPTIMISATION: Réduire les étincelles quand beaucoup d'animations
						local sparkleCount = activeAnimations > 5 and 2 or 5
						
						-- Étincelles à la position finale du joueur
						task.spawn(function()
							local finalCharacter = player.Character
							local finalHRP = finalCharacter and finalCharacter:FindFirstChild("HumanoidRootPart")
							local particlePosition = finalHRP and finalHRP.Position or finalTargetPosition

							for i = 1, sparkleCount do
								local sparkle = Instance.new("Part")
								sparkle.Size = Vector3.new(0.15, 0.15, 0.15)
								sparkle.Position = particlePosition + Vector3.new(
									math.random(-1,1), math.random(-1,1), math.random(-1,1)
								)
								sparkle.Anchored = true
								sparkle.CanCollide = false
								sparkle.Color = Color3.new(1, 0.8, 0.2)
								sparkle.Material = Enum.Material.Neon
								sparkle.Shape = Enum.PartType.Ball
								sparkle.Parent = FX_FOLDER

								local sparkleTween = TweenService:Create(
									sparkle,
									TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
									{
										Position = sparkle.Position + Vector3.new(
											math.random(-3,3), math.random(2,4), math.random(-3,3)
										),
										Transparency = 1,
										Size = Vector3.new(0.05,0.05,0.05)
									}
								)
								sparkleTween:Play()
								sparkleTween.Completed:Connect(function()
									sparkle:Destroy()
								end)
								
								-- 🚀 Pas de délai entre les étincelles si beaucoup d'animations
								if activeAnimations <= 5 then
									task.wait(0.03)
								end
							end
						end)
					end
				end)
			end
		end)
	end
end

local function pickupCandy(candyModel)
	if alreadyPickedUp[candyModel] then return end
	if not canPickupCandy(candyModel) then return end

	alreadyPickedUp[candyModel] = true

	-- Crée le clone visuel AVANT d'informer le serveur afin que l'animation
	-- soit toujours disponible même si le serveur détruit l'original.
	local visualCandy = createVisualClone(candyModel)

	-- Envoie l'event au serveur (déclaration de pickup) immédiatement.
	print("🍭 [CLIENT] Envoi PickupEvent au serveur pour:", candyModel.Name)
	pickupEvent:FireServer(candyModel)


	playCandyAnimation(visualCandy)
end

---------------------------------------------------------------------
-- Cache des bonbons pour optimisation
---------------------------------------------------------------------

-- 🚀 Mettre à jour le cache des bonbons (appelé moins souvent)
local function updateCandyCache()
	local newCache = {}
	
	for _, obj in workspace:GetDescendants() do
		if isCandyModel(obj) then
			table.insert(newCache, obj)
		end
	end
	
	candyCache = newCache
	print("🔄 [PICKUP] Cache mis à jour:", #candyCache, "bonbons trouvés")
end

-- Écouter l'ajout de nouveaux bonbons en temps réel
workspace.DescendantAdded:Connect(function(obj)
	if isCandyModel(obj) then
		table.insert(candyCache, obj)
	end
end)

-- Nettoyer le cache quand un bonbon est supprimé
workspace.DescendantRemoving:Connect(function(obj)
	if isCandyModel(obj) then
		local index = table.find(candyCache, obj)
		if index then
			table.remove(candyCache, index)
		end
	end
end)

---------------------------------------------------------------------
-- Détection de proximité
---------------------------------------------------------------------

local function checkForNearbyCandy()
	-- 🍬 Ne pas ramasser si le système n'est pas encore activé
	if not pickupEnabled then return end
	
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerPosition = humanoidRootPart.Position

	-- 🚀 Utiliser le cache au lieu de GetDescendants()
	for i = #candyCache, 1, -1 do
		local obj = candyCache[i]
		
		-- Nettoyer les bonbons détruits du cache
		if not obj.Parent then
			table.remove(candyCache, i)
		elseif canPickupCandy(obj) and not alreadyPickedUp[obj] then
			local candyPosition

			if obj:IsA("Model") then
				local base = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
				candyPosition = base and base.Position or nil
			elseif obj:IsA("BasePart") then
				candyPosition = obj.Position
			end

			if candyPosition then
				local distance = (playerPosition - candyPosition).Magnitude
				if distance <= PICKUP_DISTANCE then
					pickupCandy(obj)
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Fallback pour bonbons immobiles
---------------------------------------------------------------------
local function forceDetectImmobileCandies()
	-- 🍬 Ne pas ramasser si le système n'est pas encore activé
	if not pickupEnabled then return end
	
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerPosition = humanoidRootPart.Position

	-- 🚀 Utiliser le cache au lieu de GetDescendants()
	for _, obj in candyCache do
		if obj.Parent and canPickupCandy(obj) and not alreadyPickedUp[obj] then
			-- Vérifier si c'est un bonbon immobile depuis longtemps
			local candyPosition
			local isImmobile = false

			if obj:IsA("Model") then
				local base = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
				if base then
					candyPosition = base.Position
					-- Considérer comme immobile si la vélocité est très faible
					isImmobile = base.AssemblyLinearVelocity.Magnitude < 0.5
				end
			elseif obj:IsA("BasePart") then
				candyPosition = obj.Position
				isImmobile = obj.AssemblyLinearVelocity.Magnitude < 0.5
			end

			if candyPosition and isImmobile then
				local distance = (playerPosition - candyPosition).Magnitude
				if distance <= PICKUP_DISTANCE then
					pickupCandy(obj)
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Maintenance
---------------------------------------------------------------------

local function cleanupPickedUpTable()
	for candy in pairs(alreadyPickedUp) do
		if not candy.Parent then
			alreadyPickedUp[candy] = nil
		end
	end
end

---------------------------------------------------------------------
-- Boucle principale
---------------------------------------------------------------------

-- 🚀 Initialiser le cache au démarrage
task.spawn(function()
	task.wait(1) -- Attendre que le monde soit chargé
	updateCandyCache()
end)

local lastCheck = 0
local lastFallbackCheck = 0
local lastCacheUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()

	-- 🚀 Mettre à jour le cache périodiquement (moins souvent)
	if now - lastCacheUpdate >= CACHE_UPDATE_INTERVAL then
		updateCandyCache()
		lastCacheUpdate = now
	end

	if now - lastCheck >= 0.1 then
		checkForNearbyCandy()
		lastCheck = now

		if now % 5 < 0.1 then
			cleanupPickedUpTable()
		end
	end

	-- Fallback toutes les 2 secondes pour les bonbons immobiles
	if now - lastFallbackCheck >= 2 then
		forceDetectImmobileCandies()
		lastFallbackCheck = now
	end
end)

-- Jouer un son à la confirmation serveur du ramassage
pickupEvent.OnClientEvent:Connect(function()
	task.spawn(playPickupSound)
end)



