-- CandyPickupClient.lua
-- Script côté client pour ramasser automatiquement les bonbons
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

-- Vérifie qu'un objet porte bien la marque d'un bonbon
local function isCandyModel(obj)
	return obj and obj:FindFirstChild("CandyType")
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

local function playCandyAnimation(model)
	local character = player.Character
	if not character then
		model:Destroy()
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		model:Destroy()
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

	-- Anime chaque part avec suivi en temps réel
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
						end)
						
						-- Étincelles à la position finale du joueur
						task.spawn(function()
							local finalCharacter = player.Character
							local finalHRP = finalCharacter and finalCharacter:FindFirstChild("HumanoidRootPart")
							local particlePosition = finalHRP and finalHRP.Position or finalTargetPosition
							
							for i = 1, 5 do
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
								task.wait(0.03)
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
	if not isCandyModel(candyModel) then return end

	print("🔍 DEBUG CLIENT - Tentative de ramassage:", candyModel:GetFullName())
	
	alreadyPickedUp[candyModel] = true

	-- Crée le clone visuel AVANT d'informer le serveur afin que l'animation
	-- soit toujours disponible même si le serveur détruit l'original.
	local visualCandy = createVisualClone(candyModel)

	-- Envoie l'event au serveur (déclaration de pickup) immédiatement.
	print("🔍 DEBUG CLIENT - Envoi de l'événement au serveur...")
	pickupEvent:FireServer(candyModel)
	print("✅ DEBUG CLIENT - Événement envoyé!")

	playCandyAnimation(visualCandy)
end

---------------------------------------------------------------------
-- Détection de proximité
---------------------------------------------------------------------

local function checkForNearbyCandy()
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerPosition = humanoidRootPart.Position
	local candiesFound = 0
	local candiesInRange = 0

	for _, obj in workspace:GetDescendants() do
		if isCandyModel(obj) and not alreadyPickedUp[obj] then
			candiesFound = candiesFound + 1
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
					candiesInRange = candiesInRange + 1
					print("🔍 DEBUG CLIENT - Bonbon détecté à proximité:", obj:GetFullName(), "Distance:", distance)
					pickupCandy(obj)
				end
			else
				print("⚠️ Bonbon sans position valide:", obj:GetFullName())
			end
		end
	end
	
	if candiesFound > 0 then
		print("🔍 DEBUG CLIENT - Bonbons trouvés:", candiesFound, "À portée:", candiesInRange)
	end
end

---------------------------------------------------------------------
-- Fallback pour bonbons immobiles
---------------------------------------------------------------------
local function forceDetectImmobileCandies()
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerPosition = humanoidRootPart.Position

	for _, obj in workspace:GetDescendants() do
		if isCandyModel(obj) and not alreadyPickedUp[obj] then
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

local lastCheck = 0
local lastFallbackCheck = 0
RunService.Heartbeat:Connect(function()
	local now = tick()

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

print("✅ Système de ramassage automatique des bonbons activé !")
print("💡 Approchez-vous des bonbons pour les ramasser automatiquement")
