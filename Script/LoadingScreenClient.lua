-- LoadingScreenClient.lua
-- Displays a loading screen until player data is ready

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Paramètres visuels
local DISPLAY_ORDER = 10000
local FADE_DURATION = 0.35
local MAX_WAIT_SECONDS = 20

-- Création de l'overlay (ScreenGui + Frame + Label)
local function createLoadingOverlay()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoadingOverlay"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = DISPLAY_ORDER
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Image de fond avec léger mouvement gauche-droite
	local bg = Instance.new("ImageLabel")
	bg.Name = "BG"
	bg.BackgroundTransparency = 1
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.Position = UDim2.new(0.5, 0, 0.5, 0)
	bg.Size = UDim2.fromScale(1.08, 1.08)
	bg.Image = "rbxassetid://139536727049201"
	bg.ScaleType = Enum.ScaleType.Crop
	bg.ZIndex = 0
	bg.Parent = screenGui

	local amplitudePx = 20
	local duration = 3
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0)
	TweenService:Create(bg, tweenInfo, { Position = UDim2.new(0.5, amplitudePx, 0.5, 0) }):Play()

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.ZIndex = 1
	container.Parent = screenGui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 10, 30))
	})
	gradient.Rotation = 45
	gradient.Parent = container

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Status"
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Position = UDim2.new(0.5, 0, 0.55, 0)
	textLabel.Size = UDim2.new(0, 500, 0, 60)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Loading data..."
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextTransparency = 0
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = container

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Hint"
	subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	subLabel.Position = UDim2.new(0.5, 0, 0.62, 0)
	subLabel.Size = UDim2.new(0, 420, 0, 30)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "This should only take a moment"
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	subLabel.TextTransparency = 0.1
	subLabel.TextScaled = true
	subLabel.Font = Enum.Font.Gotham
	subLabel.Parent = container

	-- Barre de chargement (plus grosse et stylée)
	local barContainer = Instance.new("Frame")
	barContainer.Name = "BarContainer"
	barContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	barContainer.Position = UDim2.new(0.5, 0, 0.7, 0)
	barContainer.Size = UDim2.new(0, 600, 0, 20)  -- Plus large et plus haute
	barContainer.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
	barContainer.BorderSizePixel = 0
	barContainer.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 10)
	barCorner.Parent = barContainer

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(130, 90, 200)  -- Bordure violette
	barStroke.Thickness = 2
	barStroke.Transparency = 0.4
	barStroke.Parent = barContainer

	-- Barre de progression
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
	progressBar.BorderSizePixel = 0
	progressBar.Parent = barContainer

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 10)
	progressCorner.Parent = progressBar

	-- Gradient violet-bleu sur la barre
	local progressGradient = Instance.new("UIGradient")
	progressGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 220)),   -- Violet foncé
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 120, 255)), -- Violet clair
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 180, 255))    -- Bleu-violet
	})
	progressGradient.Parent = progressBar

	-- Effet de brillance qui se déplace
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.3, 0, 1, 0)
	shine.Position = UDim2.new(-0.3, 0, 0, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 1  -- Complètement transparent par défaut
	shine.BorderSizePixel = 0
	shine.Parent = progressBar

	local shineGradient = Instance.new("UIGradient")
	shineGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
	})
	shineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),      -- Invisible sur les bords
		NumberSequenceKeypoint.new(0.5, 0.5),  -- Semi-visible au centre
		NumberSequenceKeypoint.new(1, 1)       -- Invisible sur les bords
	})
	shineGradient.Rotation = 90
	shineGradient.Parent = shine

	-- Conteneur pour les particules (plus grand)
	local particleContainer = Instance.new("Frame")
	particleContainer.Name = "ParticleContainer"
	particleContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	particleContainer.Position = UDim2.new(0.5, 0, 0.7, 0)
	particleContainer.Size = UDim2.new(0, 600, 0, 80)
	particleContainer.BackgroundTransparency = 1
	particleContainer.ClipsDescendants = false
	particleContainer.Parent = container

	-- Pourcentage (avec effet violet)
	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "Percent"
	percentLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	percentLabel.Position = UDim2.new(0.5, 0, 0.77, 0)
	percentLabel.Size = UDim2.new(0, 120, 0, 30)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Text = "0%"
	percentLabel.TextColor3 = Color3.fromRGB(200, 180, 255)  -- Violet clair
	percentLabel.TextSize = 20
	percentLabel.Font = Enum.Font.GothamBold
	percentLabel.Parent = container
	
	-- Effet de lueur sur le texte
	local percentStroke = Instance.new("UIStroke")
	percentStroke.Color = Color3.fromRGB(150, 100, 255)
	percentStroke.Thickness = 1
	percentStroke.Transparency = 0.5
	percentStroke.Parent = percentLabel

	-- Light breathing effect on the text
	spawn(function()
		local dir = 1
		while screenGui.Parent do
			local newTransparency = (dir == 1) and 0.25 or 0.05
			TweenService:Create(subLabel, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextTransparency = newTransparency }):Play()
			dir = 1 - dir
			wait(1.2)
		end
	end)

	return screenGui, container, textLabel, subLabel, progressBar, percentLabel, barContainer, particleContainer, shine
end

local function destroyOverlay(screenGui, container, textLabel, subLabel, progressBar, percentLabel)
	if not screenGui or not screenGui.Parent then return end
	pcall(function()
		TweenService:Create(container, TweenInfo.new(FADE_DURATION), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(textLabel, TweenInfo.new(FADE_DURATION), { TextTransparency = 1 }):Play()
		if subLabel then
			TweenService:Create(subLabel, TweenInfo.new(FADE_DURATION), { TextTransparency = 1 }):Play()
		end
		if percentLabel then
			TweenService:Create(percentLabel, TweenInfo.new(FADE_DURATION), { TextTransparency = 1 }):Play()
		end
		wait(FADE_DURATION)
		screenGui:Destroy()
	end)
end

-- Determines if data is ready via attribute or remote event
local function areDataReady()
	local ok, value = pcall(function()
		return localPlayer:GetAttribute("DataReady")
	end)
	return ok and value == true
end

-- Entry point
do
	-- If already ready, don't display anything
	if areDataReady() then
		print("[LoadingScreen] Data already ready, skipping loading screen")
		return
	end

	print("[LoadingScreen] Creating loading overlay...")
	local overlayGui, container, label, hint, progressBar, percentLabel, barContainer, particleContainer, shine = createLoadingOverlay()
	print("[LoadingScreen] Overlay created successfully")
	print("[LoadingScreen] ProgressBar parent:", progressBar.Parent)
	print("[LoadingScreen] ProgressBar size:", progressBar.Size)

	local ready = false
	local currentProgress = 0

	-- Animation de la barre de chargement
	local animationRunning = true
	task.spawn(function()
		print("[LoadingBar] Animation started")
		local startTime = tick()
		local lastParticleTime = 0
		local frameCount = 0
		
		while animationRunning and overlayGui and overlayGui.Parent do
			frameCount = frameCount + 1
			local elapsed = tick() - startTime
			
			-- Progression lente au début, puis accélère quand ready = true
			local targetProgress
			if ready then
				-- Accélérer vers 100%
				targetProgress = 1
			else
				-- Progression lente (atteint 90% en MAX_WAIT_SECONDS)
				targetProgress = math.min((elapsed / MAX_WAIT_SECONDS) * 0.9, 0.9)
			end
			
			-- Interpolation douce vers la cible
			currentProgress = currentProgress + (targetProgress - currentProgress) * 0.1
			
			-- Debug toutes les 30 frames
			if frameCount % 30 == 0 then
				print(string.format("[LoadingBar] Progress: %.1f%% (target: %.1f%%, ready: %s)", 
					currentProgress * 100, targetProgress * 100, tostring(ready)))
			end
			
			-- Mise à jour de la barre
			if progressBar and progressBar.Parent then
				progressBar.Size = UDim2.new(currentProgress, 0, 1, 0)
			end
			
			-- Mise à jour du pourcentage
			if percentLabel and percentLabel.Parent then
				percentLabel.Text = math.floor(currentProgress * 100) .. "%"
			end
			
			-- Animation de brillance
			if shine and shine.Parent then
				local shinePos = (currentProgress * 1.3) - 0.3
				shine.Position = UDim2.new(shinePos, 0, 0, 0)
			end
			
			-- Créer des particules périodiquement
			if tick() - lastParticleTime > 0.15 and currentProgress > 0.01 and currentProgress < 0.98 then
				lastParticleTime = tick()
				
				-- Créer 3-5 particules stylées
				for i = 1, math.random(3, 5) do
					local particle = Instance.new("Frame")
					particle.Name = "Particle"
					local particleSize = 6 + (math.random() * 8)  -- 6 à 14
					particle.Size = UDim2.new(0, particleSize, 0, particleSize)
					local offsetX = (math.random() * 30) - 15  -- -15 à 15
					local offsetY = (math.random() * 20) - 10  -- -10 à 10
					particle.Position = UDim2.new(currentProgress, offsetX, 0.5, offsetY)
					particle.AnchorPoint = Vector2.new(0.5, 0.5)
					particle.Rotation = math.random() * 360
					
					-- Couleurs violet-bleu variées
					local colorChoice = math.random()
					if colorChoice < 0.4 then
						-- Violet
						particle.BackgroundColor3 = Color3.fromRGB(
							150 + math.random(0, 80),
							100 + math.random(0, 50),
							200 + math.random(0, 55)
						)
					elseif colorChoice < 0.7 then
						-- Bleu-violet
						particle.BackgroundColor3 = Color3.fromRGB(
							100 + math.random(0, 80),
							150 + math.random(0, 80),
							220 + math.random(0, 35)
						)
					else
						-- Blanc brillant
						particle.BackgroundColor3 = Color3.fromRGB(
							220 + math.random(0, 35),
							220 + math.random(0, 35),
							255
						)
					end
					
					particle.BorderSizePixel = 0
					particle.BackgroundTransparency = 0
					particle.ZIndex = 5
					particle.Parent = particleContainer
					
					local particleCorner = Instance.new("UICorner")
					particleCorner.CornerRadius = UDim.new(1, 0)
					particleCorner.Parent = particle
					
					-- Effet de lueur sur certaines particules
					if math.random() > 0.5 then
						local particleGlow = Instance.new("UIStroke")
						particleGlow.Color = Color3.fromRGB(200, 150, 255)
						particleGlow.Thickness = 2
						particleGlow.Transparency = 0.3
						particleGlow.Parent = particle
					end
					
					-- Animation de la particule avec rotation
					local endY = -50 - (math.random() * 40)  -- -50 à -90
					local endX = currentProgress + ((math.random() * 120) - 60) / 600
					local particleDuration = 1.0 + (math.random() * 0.6)  -- 1.0 à 1.6
					local endRotation = particle.Rotation + (180 + math.random() * 180)  -- Rotation supplémentaire
					local endSize = particleSize * (0.3 + math.random() * 0.4)  -- Rétrécit en montant
					
					local tweenInfo = TweenInfo.new(
						particleDuration,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					)
					
					TweenService:Create(particle, tweenInfo, {
						Position = UDim2.new(endX, 0, 0.5, endY),
						BackgroundTransparency = 1,
						Rotation = endRotation,
						Size = UDim2.new(0, endSize, 0, endSize)
					}):Play()
					
					-- Détruire après l'animation
					task.delay(particleDuration, function()
						if particle and particle.Parent then
							particle:Destroy()
						end
					end)
				end
			end
			
			-- Si on a atteint 100%, arrêter l'animation
			if currentProgress >= 0.99 and ready then
				if progressBar and progressBar.Parent then
					progressBar.Size = UDim2.new(1, 0, 1, 0)
				end
				if percentLabel and percentLabel.Parent then
					percentLabel.Text = "100%"
				end
				print("[LoadingBar] Animation complete at 100%")
				animationRunning = false
			end
			
			task.wait(0.03)
		end
		print("[LoadingBar] Animation loop ended")
	end)

	-- 1) Listen to DataReady attribute
	local attributeConn
	attributeConn = localPlayer.AttributeChanged:Connect(function(attrName)
		if attrName == "DataReady" and areDataReady() and not ready then
			ready = true
			if attributeConn then attributeConn:Disconnect() end
			-- Attendre que la barre atteigne 100%
			task.wait(0.5)
			destroyOverlay(overlayGui, container, label, hint, progressBar, percentLabel)
		end
	end)

	-- 2) Listen to PlayerDataReady RemoteEvent
	spawn(function()
		local evt = ReplicatedStorage:WaitForChild("PlayerDataReady", 10)
		if evt and evt:IsA("RemoteEvent") then
			evt.OnClientEvent:Connect(function()
				if not ready then
					ready = true
					if attributeConn then attributeConn:Disconnect() end
					-- Attendre que la barre atteigne 100%
					task.wait(0.5)
					destroyOverlay(overlayGui, container, label, hint, progressBar, percentLabel)
				end
			end)
		end
	end)

	-- 3) Safety: timeout
	spawn(function()
		wait(MAX_WAIT_SECONDS)
		if not ready then
			ready = true
			if attributeConn then attributeConn:Disconnect() end
			task.wait(0.5)
			destroyOverlay(overlayGui, container, label, hint, progressBar, percentLabel)
		end
	end)
end


