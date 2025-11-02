-- ProximityPromptMobileOptimizer.lua
-- Réduit la taille des ProximityPrompts sur mobile en utilisant un UI personnalisé

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

-- Détecter si on est sur mobile
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if not isMobile then
	-- Pas sur mobile, ne rien faire
	return
end

print("📱 [MOBILE] Optimizing ProximityPrompts for mobile...")

-- Créer un ScreenGui pour afficher les prompts personnalisés
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomProximityPrompts"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.Parent = player:WaitForChild("PlayerGui")

local activePrompts = {} -- Table pour tracker les prompts actifs
local promptsBeingHidden = {} -- Table pour éviter les boucles infinies

-- Fonction pour ajouter le highlight tutoriel à un bouton
local function addTutorialHighlight(button)
	-- Vérifier si le highlight existe déjà
	if button:FindFirstChild("TutorialHighlight_INCUBATOR") then
		return
	end
	
	print("✨ [TUTORIAL] Adding highlight to incubator button")
	
	-- Créer un highlight sur le bouton
	local highlight = Instance.new("Frame")
	highlight.Name = "TutorialHighlight_INCUBATOR"
	highlight.Size = UDim2.new(1, 8, 1, 8)
	highlight.Position = UDim2.new(0, -4, 0, -4)
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.ZIndex = button.ZIndex + 1
	highlight.Parent = button
	
	local highlightStroke = Instance.new("UIStroke")
	highlightStroke.Color = Color3.fromRGB(255, 215, 0)
	highlightStroke.Thickness = 4
	highlightStroke.Transparency = 0.2
	highlightStroke.Parent = highlight
	
	local highlightCorner = Instance.new("UICorner")
	highlightCorner.CornerRadius = UDim.new(0, 10)
	highlightCorner.Parent = highlight
	
	-- Animation de pulsation
	local TweenService = game:GetService("TweenService")
	local pulse = TweenService:Create(highlightStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Thickness = 5,
		Transparency = 0
	})
	pulse:Play()
	
	-- Ajouter un texte "CLICK HERE" au-dessus du bouton
	local clickLabel = Instance.new("TextLabel")
	clickLabel.Name = "ClickHereLabel"
	clickLabel.Size = UDim2.new(0, 200, 0, 40)
	clickLabel.Position = UDim2.new(0.5, -100, 0, -45)
	clickLabel.BackgroundTransparency = 1
	clickLabel.Text = "👇 CLICK HERE"
	clickLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	clickLabel.TextSize = 20
	clickLabel.Font = Enum.Font.GothamBold
	clickLabel.TextStrokeTransparency = 0.3
	clickLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	clickLabel.ZIndex = button.ZIndex + 2
	clickLabel.Parent = highlight
	
	-- Animation de rebond pour le texte
	local bounce = TweenService:Create(clickLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0.5, -100, 0, -50)
	})
	bounce:Play()
	
	print("✅ [TUTORIAL] Incubator button highlighted")
end

-- Fonction pour retirer le highlight tutoriel
local function removeTutorialHighlight(button)
	local highlight = button:FindFirstChild("TutorialHighlight_INCUBATOR")
	if highlight then
		highlight:Destroy()
		print("🗑️ [TUTORIAL] Highlight removed from incubator button")
	end
end

-- Fonction pour créer un UI personnalisé pour un prompt
local function createCustomPromptUI(prompt)
	-- Utiliser un TextButton au lieu d'un Frame pour le rendre cliquable
	local button = Instance.new("TextButton")
	button.Name = "CustomPrompt_" .. prompt.ObjectText
	button.Size = UDim2.new(0, 180, 0, 60) -- Taille réduite pour mobile
	button.AnchorPoint = Vector2.new(1, 0.5) -- Ancrer à droite
	button.Position = UDim2.new(1, -60, 0.55, 0) -- Décalé à gauche (60px), plus haut (55%)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 0
	button.Text = "" -- Pas de texte par défaut
	button.AutoButtonColor = false
	button.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Parent = button
	
	-- Icône de main
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 35, 0, 35)
	icon.Position = UDim2.new(0, 8, 0.5, -17.5)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"
	icon.Parent = button
	
	-- Texte de l'objet
	local objectLabel = Instance.new("TextLabel")
	objectLabel.Size = UDim2.new(1, -50, 0, 20)
	objectLabel.Position = UDim2.new(0, 45, 0, 5)
	objectLabel.BackgroundTransparency = 1
	objectLabel.Text = prompt.ObjectText
	objectLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	objectLabel.Font = Enum.Font.GothamBold
	objectLabel.TextSize = 13
	objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectLabel.Parent = button
	
	-- Texte de l'action
	local actionLabel = Instance.new("TextLabel")
	actionLabel.Size = UDim2.new(1, -50, 0, 22)
	actionLabel.Position = UDim2.new(0, 45, 0, 25)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = prompt.ActionText
	actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionLabel.Font = Enum.Font.GothamBold
	actionLabel.TextSize = 15
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = button
	
	-- Variable pour éviter les clics multiples
	local clickDebounce = false
	local buttonReady = false
	
	-- Activer le bouton après un court délai
	task.delay(0.1, function()
		buttonReady = true
	end)
	
	-- Rendre le bouton cliquable pour déclencher le prompt
	button.MouseButton1Click:Connect(function()
		print("🖱️ [MOBILE] Button clicked, ready:", buttonReady, "debounce:", clickDebounce)
		
		-- Vérifier si le bouton est prêt
		if not buttonReady then
			print("⚠️ [MOBILE] Button not ready yet")
			return
		end
		
		-- Debounce pour éviter les clics multiples
		if clickDebounce then
			print("⚠️ [MOBILE] Click debounced")
			return
		end
		clickDebounce = true
		
		-- Retirer le highlight tutoriel dès qu'on clique
		removeTutorialHighlight(button)
		
		-- Feedback visuel
		button.BackgroundTransparency = 0.4
		
		print("✅ [MOBILE] Triggering prompt:", prompt.ObjectText)
		
		-- Déclencher le ProximityPrompt
		if prompt and prompt.Parent then
			prompt:InputHoldBegin()
			if prompt.HoldDuration == 0 then
				-- Si pas de hold, déclencher immédiatement
				task.wait(0.1)
				prompt:InputHoldEnd()
			end
		else
			print("❌ [MOBILE] Prompt not found or no parent")
		end
		
		-- Réinitialiser après 0.3 secondes (réduit de 0.5)
		task.wait(0.3)
		clickDebounce = false
		if button and button.Parent then
			button.BackgroundTransparency = 0.2
		end
	end)
	
	-- Animation au survol (pour feedback visuel)
	button.MouseEnter:Connect(function()
		stroke.Color = Color3.fromRGB(100, 200, 255)
		button.BackgroundTransparency = 0.1
	end)
	
	button.MouseLeave:Connect(function()
		stroke.Color = Color3.fromRGB(255, 255, 255)
		button.BackgroundTransparency = 0.2
	end)
	
	-- 🎓 TUTORIEL: Vérifier si on doit ajouter le highlight immédiatement
	local tutorialStep = _G.CurrentTutorialStep
	if tutorialStep == "OPEN_INCUBATOR" then
		task.spawn(function()
			task.wait(0.1)
			addTutorialHighlight(button)
		end)
	end
	
	return button
end

-- Écouter les prompts qui apparaissent
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	-- Vérifier si ce prompt doit être optimisé
	if not prompt:GetAttribute("MobileOptimized") then
		return
	end
	
	-- Si déjà actif, ne rien faire
	if activePrompts[prompt] then
		return
	end
	
	-- Cacher complètement l'UI par défaut en rendant le texte invisible
	prompt.UIOffset = Vector2.new(0, -10000) -- Déplacer l'UI hors de l'écran
	
	-- Créer l'UI personnalisé
	local customUI = createCustomPromptUI(prompt)
	activePrompts[prompt] = customUI
end)

-- Écouter les prompts qui disparaissent
ProximityPromptService.PromptHidden:Connect(function(prompt)
	-- Éviter les boucles infinies
	if promptsBeingHidden[prompt] then
		return
	end
	
	local customUI = activePrompts[prompt]
	if customUI then
		promptsBeingHidden[prompt] = true
		customUI:Destroy()
		activePrompts[prompt] = nil
		
		-- Réinitialiser l'offset
		if prompt and prompt.Parent then
			prompt.UIOffset = Vector2.new(0, 0)
		end
		
		task.wait(0.1)
		promptsBeingHidden[prompt] = nil
	end
end)

-- Mettre à jour le texte des prompts en temps réel ET vérifier le tutoriel
local lastTutorialStep = _G.CurrentTutorialStep
game:GetService("RunService").Heartbeat:Connect(function()
	-- Mettre à jour les textes
	for prompt, customUI in pairs(activePrompts) do
		if prompt and prompt.Parent then
			local objectLabel = customUI:FindFirstChild("TextLabel")
			local actionLabel = customUI:FindFirstChild("TextLabel", true)
			
			if objectLabel then
				objectLabel.Text = prompt.ObjectText
			end
			if actionLabel and actionLabel ~= objectLabel then
				actionLabel.Text = prompt.ActionText
			end
		end
	end
	
	-- Vérifier si l'étape du tutoriel a changé
	local currentStep = _G.CurrentTutorialStep
	if currentStep ~= lastTutorialStep then
		lastTutorialStep = currentStep
		print("🔄 [TUTORIAL] Step changed to:", currentStep)
		
		-- Mettre à jour les highlights sur tous les boutons actifs
		for prompt, customUI in pairs(activePrompts) do
			if currentStep == "OPEN_INCUBATOR" then
				-- Ajouter un délai de 0.5s avant d'afficher le highlight (uniquement en mode tutoriel)
				task.spawn(function()
					task.wait(0.5)
					-- Vérifier que l'étape n'a pas changé pendant le délai
					if _G.CurrentTutorialStep == "OPEN_INCUBATOR" then
						addTutorialHighlight(customUI)
					end
				end)
			else
				removeTutorialHighlight(customUI)
			end
		end
	end
end)

print("✅ [MOBILE] ProximityPrompt optimizer loaded")
