-- IncubatorMenuClient_New.lua - Interface simplifiée avec liste de recettes
-- Plus de drag & drop, juste une liste de recettes à débloquer et produire

----------------------------------------------------------------------
-- SERVICES & MODULES
----------------------------------------------------------------------
local plr = game:GetService("Players").LocalPlayer
local rep = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Modules
local RecipeManager = require(rep:WaitForChild("RecipeManager"))

-- RemoteEvents
local openEvt = rep:WaitForChild("OpenIncubatorMenu")
local unlockRecipeEvt = rep:FindFirstChild("UnlockRecipe") or Instance.new("RemoteEvent")
unlockRecipeEvt.Name = "UnlockRecipe"
unlockRecipeEvt.Parent = rep

local startProductionEvt = rep:FindFirstChild("StartProduction") or Instance.new("RemoteEvent")
startProductionEvt.Name = "StartProduction"
startProductionEvt.Parent = rep

local stopProductionEvt = rep:FindFirstChild("StopProduction") or Instance.new("RemoteEvent")
stopProductionEvt.Name = "StopProduction"
stopProductionEvt.Parent = rep

local getUnlockedRecipesFunc = rep:WaitForChild("GetUnlockedRecipes", 10)

local productionProgressEvt = rep:FindFirstChild("ProductionProgress") or Instance.new("RemoteEvent")
productionProgressEvt.Name = "ProductionProgress"
productionProgressEvt.Parent = rep

local addToQueueEvt = rep:FindFirstChild("AddToQueue") or Instance.new("RemoteEvent")
addToQueueEvt.Name = "AddToQueue"
addToQueueEvt.Parent = rep

local removeFromQueueEvt = rep:FindFirstChild("RemoveFromQueue") or Instance.new("RemoteEvent")
removeFromQueueEvt.Name = "RemoveFromQueue"
removeFromQueueEvt.Parent = rep

local finishNowRobuxEvt = rep:FindFirstChild("FinishNowRobux") or Instance.new("RemoteEvent")
finishNowRobuxEvt.Name = "FinishNowRobux"
finishNowRobuxEvt.Parent = rep

local getQueueFunc = rep:WaitForChild("GetQueue", 10)

-- RemoteEvent pour les erreurs de production
local productionErrorEvt = rep:FindFirstChild("ProductionError") or Instance.new("RemoteEvent")
productionErrorEvt.Name = "ProductionError"
productionErrorEvt.Parent = rep

-- RemoteEvent pour le succès de production
local productionSuccessEvt = rep:FindFirstChild("ProductionSuccess") or Instance.new("RemoteEvent")
productionSuccessEvt.Name = "ProductionSuccess"
productionSuccessEvt.Parent = rep

-- RemoteEvents pour déblocage d'incubateurs
local requestUnlockIncubatorEvt = rep:FindFirstChild("RequestUnlockIncubator") or Instance.new("RemoteEvent")
requestUnlockIncubatorEvt.Name = "RequestUnlockIncubator"
requestUnlockIncubatorEvt.Parent = rep

local requestUnlockIncubatorMoneyEvt = rep:FindFirstChild("RequestUnlockIncubatorMoney") or Instance.new("RemoteEvent")
requestUnlockIncubatorMoneyEvt.Name = "RequestUnlockIncubatorMoney"
requestUnlockIncubatorMoneyEvt.Parent = rep

local unlockIncubatorPurchasedEvt = rep:FindFirstChild("UnlockIncubatorPurchased") or Instance.new("RemoteEvent")
unlockIncubatorPurchasedEvt.Name = "UnlockIncubatorPurchased"
unlockIncubatorPurchasedEvt.Parent = rep

-- NOTE: L'événement unlockIncubatorPurchasedEvt.OnClientEvent est connecté plus bas,
-- après la définition des fonctions hideUnlockPanel() et loadRecipeList()

-- RemoteEvent pour les erreurs de déblocage
local unlockIncubatorErrorEvt = rep:FindFirstChild("UnlockIncubatorError") or Instance.new("RemoteEvent")
unlockIncubatorErrorEvt.Name = "UnlockIncubatorError"
unlockIncubatorErrorEvt.Parent = rep

-- Gérer les erreurs de déblocage
unlockIncubatorErrorEvt.OnClientEvent:Connect(function(errorMessage)
	if not gui then return end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local unlockPanel = mainFrame:FindFirstChild("UnlockPanel")
	if not unlockPanel then return end
	
	local moneyBtn = unlockPanel:FindFirstChild("MoneyButton")
	if moneyBtn then
		local originalText = moneyBtn.Text
		local originalColor = moneyBtn.BackgroundColor3
		local originalPos = moneyBtn.Position
		
		-- Changer en rouge
		moneyBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		moneyBtn.Text = errorMessage or "❌ Error!"
		moneyBtn.Active = true
		
		-- Animation de vibration (shake)
		local shakeAmount = 10
		local shakeDuration = 0.05
		for i = 1, 6 do
			local offsetX = (i % 2 == 0) and shakeAmount or -shakeAmount
			moneyBtn.Position = originalPos + UDim2.new(0, offsetX, 0, 0)
			task.wait(shakeDuration)
		end
		moneyBtn.Position = originalPos
		
		-- Attendre 1.5 secondes puis revenir à la normale
		task.wait(1.5)
		moneyBtn.Text = originalText
		moneyBtn.BackgroundColor3 = originalColor
	end
end)

-- Gérer les erreurs de production
productionErrorEvt.OnClientEvent:Connect(function(errorMessage)
	print("❌ [CLIENT] Production error:", errorMessage)
	
	-- Afficher un message d'erreur visuel
	if gui and gui.Enabled then
		local mainFrame = gui:FindFirstChild("MainFrame")
		if mainFrame then
			-- Créer un message d'erreur temporaire
			local errorLabel = Instance.new("TextLabel")
			errorLabel.Name = "ErrorMessage"
			errorLabel.Size = UDim2.new(0, 300, 0, 50)
			errorLabel.Position = UDim2.new(0.5, -150, 0, -60)
			errorLabel.AnchorPoint = Vector2.new(0.5, 0)
			errorLabel.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			errorLabel.Text = "❌ " .. (errorMessage or "Error!")
			errorLabel.TextColor3 = Color3.new(1, 1, 1)
			errorLabel.Font = Enum.Font.GothamBold
			errorLabel.TextSize = 16
			errorLabel.TextWrapped = true
			errorLabel.Parent = mainFrame
			
			local errorCorner = Instance.new("UICorner", errorLabel)
			errorCorner.CornerRadius = UDim.new(0, 8)
			
			-- Animation d'apparition
			errorLabel.Position = UDim2.new(0.5, -150, 0, -60)
			TweenService:Create(errorLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -150, 0, 10)
			}):Play()
			
			-- Disparaître après 2 secondes
			task.delay(2, function()
				if errorLabel and errorLabel.Parent then
					TweenService:Create(errorLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Position = UDim2.new(0.5, -150, 0, -60),
						BackgroundTransparency = 1,
						TextTransparency = 1
					}):Play()
					task.wait(0.3)
					errorLabel:Destroy()
				end
			end)
		end
		
		-- Rafraîchir la liste des recettes pour remettre les boutons à jour
		loadRecipeList()
	end
end)

-- Gérer le succès de production
productionSuccessEvt.OnClientEvent:Connect(function()
	print("✅ [CLIENT] Production started successfully")
	
	-- Rafraîchir l'UI
	if gui and gui.Enabled then
		updateQueue()
		loadRecipeList()
	end
end)

----------------------------------------------------------------------
-- VARIABLES GLOBALES
----------------------------------------------------------------------
local gui = nil
local currentIncID = nil
local isMenuOpen = false
local unlockedRecipes = {}
local incubatorBillboards = {} -- Stocke les barres de progression
local currentQueue = {} -- Queue actuelle
local purchaseInProgress = false -- Empêche la fermeture pendant un achat
local lastProductionRequest = 0 -- Timestamp du dernier clic (cooldown 0.5s)

----------------------------------------------------------------------
-- DÉCLARATIONS ANTICIPÉES (Forward declarations)
----------------------------------------------------------------------
local createGUI
local hideUnlockPanel
local loadRecipeList

----------------------------------------------------------------------
-- FONCTIONS UTILITAIRES
----------------------------------------------------------------------

-- Trouve l'incubateur par son ID
local function getIncubatorByID(id)
	for _, p in ipairs(workspace:GetDescendants()) do
		if p:IsA("StringValue") and p.Name == "ParcelID" and p.Value == id then
			local partWithPrompt = p.Parent
			if partWithPrompt then
				local model = partWithPrompt:FindFirstAncestorOfClass("Model")
				if model and model.Name == "Incubator" then
					return model
				end
				if model then return model end
				if partWithPrompt:IsA("BasePart") then
					return partWithPrompt
				end
			end
		end
	end
	return nil
end

-- Crée ou récupère la barre de progression au-dessus de l'incubateur
local function ensureBillboard(incID)
	local incModel = getIncubatorByID(incID)
	if not incModel then return nil end
	
	local billboardPart = incModel:FindFirstChild("BillboardPart")
	if not billboardPart then 
		-- Fallback: utiliser la première BasePart
		billboardPart = incModel:FindFirstChildWhichIsA("BasePart", true)
		if not billboardPart then return nil end
	end
	
	local bb = incubatorBillboards[incID]
	if bb and bb.Parent then return bb end
	
	bb = Instance.new("BillboardGui")
	bb.Name = "IncubatorProgress"
	bb.Adornee = billboardPart
	bb.AlwaysOnTop = true
	bb.MaxDistance = 100
	bb.Size = UDim2.new(0, 240, 0, 60)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.Parent = incModel

	local title = Instance.new("TextLabel", bb)
	title.Name = "Title"
	-- Taille réduite sur mobile
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile then
		title.Size = UDim2.new(1, 0, 0.3, 0)
	else
		title.Size = UDim2.new(1, 0, 0.45, 0)
	end
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Production"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true

	local bg = Instance.new("Frame", bb)
	bg.Name = "BG"
	-- Taille réduite sur mobile
	if isMobile then
		bg.Size = UDim2.new(0, 180, 0.35, 0)
		bg.Position = UDim2.new(0, 0, 0.4, 0)
	else
		bg.Size = UDim2.new(0, 180, 0.45, 0)
		bg.Position = UDim2.new(0, 0, 0.6, 0)
	end
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	local bgCorner = Instance.new("UICorner", bg)
	bgCorner.CornerRadius = UDim.new(0, 6)

	local fill = Instance.new("Frame", bg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner", fill)
	fillCorner.CornerRadius = UDim.new(0, 6)

	local uiStroke = Instance.new("UIStroke", bg)
	uiStroke.Thickness = 1
	uiStroke.Color = Color3.fromRGB(20, 20, 20)

	local timer = Instance.new("TextLabel", bb)
	timer.Name = "Timer"
	timer.Size = UDim2.new(0, 180, 0, 16)
	timer.Position = UDim2.new(0, 0, 0.95, 0)
	timer.BackgroundTransparency = 1
	timer.TextColor3 = Color3.fromRGB(230, 230, 230)
	timer.Font = Enum.Font.GothamBold
	timer.TextScaled = false
	timer.TextSize = 14
	timer.TextWrapped = false
	timer.TextXAlignment = Enum.TextXAlignment.Left
	timer.Text = "--:--"

	incubatorBillboards[incID] = bb
	return bb
end

-- Récupère les ingrédients disponibles dans l'inventaire
local function getAvailableIngredients()
	local ingredients = {}
	local backpack = plr:FindFirstChildOfClass("Backpack")
	local character = plr.Character

	local function addFromTool(tool)
		if not tool:IsA("Tool") then return end
		local isCandy = tool:GetAttribute("IsCandy")
		if isCandy then return end -- Filtrer les bonbons
		
		local baseName = tool:GetAttribute("BaseName")
		if baseName then
			local count = tool:FindFirstChild("Count")
			if count and count.Value > 0 then
				-- Normaliser le nom (minuscules)
				local normalizedName = baseName:lower()
				ingredients[normalizedName] = (ingredients[normalizedName] or 0) + count.Value
			end
		end
	end

	-- Vérifier les outils équipés
	if character then
		for _, tool in pairs(character:GetChildren()) do
			addFromTool(tool)
		end
	end

	-- Vérifier le sac
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			addFromTool(tool)
		end
	end

	return ingredients
end

-- Vérifie si le joueur a les ingrédients pour une recette
local function hasIngredientsForRecipe(recipeDef)
	local available = getAvailableIngredients()
	
	for ingredient, needed in pairs(recipeDef.ingredients) do
		local have = available[ingredient] or 0
		if have < needed then
			return false
		end
	end
	
	return true
end

-- Crée un ViewportFrame pour afficher un modèle 3D
local function createModelViewport(parent, modelName)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightDirection = Vector3.new(0, -1, -0.5)
	viewport.Parent = parent

	-- Chercher le modèle
	local candyModels = rep:FindFirstChild("CandyModels")
	if not candyModels then return viewport end
	
	local template = candyModels:FindFirstChild(modelName)
	if not template then return viewport end

	-- Cloner le modèle
	local model = template:Clone()
	if model:IsA("Tool") then
		local m = Instance.new("Model")
		for _, ch in ipairs(model:GetChildren()) do
			ch.Parent = m
		end
		model:Destroy()
		model = m
	end
	model.Parent = viewport

	-- Créer la caméra
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	-- Positionner la caméra
	local function positionCamera()
		local center, size
		if model:IsA("BasePart") then
			center = model.Position
			size = model.Size
		else
			local cf, sz = model:GetBoundingBox()
			center, size = cf.Position, sz
		end
		local radius = size.Magnitude * 0.5
		local distance = (radius / math.tan(math.rad(cam.FieldOfView * 0.5))) * 1.25
		local dir = Vector3.new(1, 0.8, 1).Unit
		cam.CFrame = CFrame.new(center + dir * distance, center)
	end

	positionCamera()

	-- Rotation
	RunService.RenderStepped:Connect(function(dt)
		if model and model.Parent then
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CFrame = p.CFrame * CFrame.Angles(0, dt * 0.8, 0)
				end
			end
		end
	end)

	return viewport
end

-- Crée une carte de recette dans la liste
local function createRecipeCard(parent, recipeName, recipeDef, isUnlocked)
	local card = Instance.new("Frame")
	card.Name = "RecipeCard_" .. recipeName
	card.Size = UDim2.new(1, -20, 0, 120)
	card.BackgroundColor3 = Color3.fromRGB(60, 44, 28)
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner", card)
	corner.CornerRadius = UDim.new(0, 8)
	
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = recipeDef.couleurRarete or Color3.fromRGB(150, 150, 150)
	stroke.Thickness = 2

	-- Icône/Viewport du bonbon (gauche)
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(0, 100, 1, -10)
	iconFrame.Position = UDim2.new(0, 5, 0, 5)
	iconFrame.BackgroundTransparency = 1
	iconFrame.Parent = card

	if recipeDef.modele then
		createModelViewport(iconFrame, recipeDef.modele)
	end

	-- Informations (centre)
	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(0, 250, 1, -10)
	infoFrame.Position = UDim2.new(0, 115, 0, 5)
	infoFrame.BackgroundTransparency = 1
	infoFrame.Parent = card

	-- Nom de la recette
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 25)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = (recipeDef.emoji or "🍬") .. " " .. (recipeDef.nom or recipeName)
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = infoFrame

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, 0, 0, 20)
	descLabel.Position = UDim2.new(0, 0, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = recipeDef.description or ""
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = infoFrame

	-- Ingrédients requis
	local ingredientsLabel = Instance.new("TextLabel")
	ingredientsLabel.Size = UDim2.new(1, 0, 0, 60)
	ingredientsLabel.Position = UDim2.new(0, 0, 0, 52)
	ingredientsLabel.BackgroundTransparency = 1
	ingredientsLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	ingredientsLabel.Font = Enum.Font.Gotham
	ingredientsLabel.TextSize = 11
	ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
	ingredientsLabel.TextYAlignment = Enum.TextYAlignment.Top
	ingredientsLabel.TextWrapped = true
	ingredientsLabel.Parent = infoFrame

	-- Construire le texte des ingrédients
	local ingredientsText = "Ingredients:\n"
	local available = getAvailableIngredients()
	for ingredient, needed in pairs(recipeDef.ingredients) do
		local have = available[ingredient] or 0
		local color = have >= needed and "✓" or "✗"
		local ingDef = RecipeManager.Ingredients[ingredient:sub(1,1):upper() .. ingredient:sub(2)]
		local displayName = ingDef and ingDef.nom or ingredient
		ingredientsText = ingredientsText .. string.format("%s %s: %d/%d  ", color, displayName, have, needed)
	end
	ingredientsLabel.Text = ingredientsText

	-- Boutons (droite)
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.new(0, 120, 1, -10)
	buttonFrame.Position = UDim2.new(1, -125, 0, 5)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = card

	-- Plus besoin de vérifier si débloqué, on affiche toujours le bouton PRODUCE
	if true then
		-- Bouton Production unique (gère production ET queue)
		local prodBtn = Instance.new("TextButton")
		prodBtn.Name = "ProduceButton"
		-- Taille réduite sur mobile
		local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		if isMobile then
			prodBtn.Size = UDim2.new(1, 0, 0, 38)
			prodBtn.Position = UDim2.new(0, 0, 0.5, -19)
		else
			prodBtn.Size = UDim2.new(1, 0, 0, 50)
			prodBtn.Position = UDim2.new(0, 0, 0.5, -25)
		end
		prodBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		prodBtn.Text = "▶ PRODUCE"
		prodBtn.TextColor3 = Color3.new(1, 1, 1)
		prodBtn.Font = Enum.Font.GothamBold
		-- Taille de texte réduite sur mobile
		if isMobile then
			prodBtn.TextSize = 13
		else
			prodBtn.TextSize = 16
		end
		prodBtn.Parent = buttonFrame

		local prodCorner = Instance.new("UICorner", prodBtn)
		prodCorner.CornerRadius = UDim.new(0, 8)

		-- 🎓 TUTORIEL: Highlight du bouton PRODUCE si on est à cette étape
		local tutorialStep = _G.CurrentTutorialStep
		print("🔍 [TUTORIAL] Création bouton PRODUCE, étape actuelle:", tutorialStep)
		if tutorialStep == "OPEN_INCUBATOR" or tutorialStep == "VIEW_RECIPE" then
				task.spawn(function()
					task.wait(0.1)
					-- Créer un highlight sur le bouton
					local highlight = Instance.new("Frame")
					highlight.Name = "TutorialHighlight_PRODUCE"
					highlight.Size = UDim2.new(1, 8, 1, 8)
					highlight.Position = UDim2.new(0, -4, 0, -4)
					highlight.BackgroundTransparency = 1
					highlight.BorderSizePixel = 0
					highlight.ZIndex = prodBtn.ZIndex + 1
					highlight.Parent = prodBtn
					
					local stroke = Instance.new("UIStroke")
					stroke.Color = Color3.fromRGB(255, 215, 0)
					stroke.Thickness = 4
					stroke.Transparency = 0.2
					stroke.Parent = highlight
					
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 8)
					corner.Parent = highlight
					
					-- Animation de pulsation
					local pulse = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
						Thickness = 5,
						Transparency = 0
					})
					pulse:Play()
					
					-- Ajouter un texte "CLICK HERE" en dessous du bouton
					local clickLabel = Instance.new("TextLabel")
					clickLabel.Name = "ClickHereLabel"
					clickLabel.Size = UDim2.new(0, 200, 0, 40)
					clickLabel.Position = UDim2.new(0.5, -100, 1, 5)
					clickLabel.BackgroundTransparency = 1
					clickLabel.Text = "☝️ CLICK HERE"
					clickLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
					clickLabel.TextSize = 20
					clickLabel.Font = Enum.Font.GothamBold
					clickLabel.TextStrokeTransparency = 0.3
					clickLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					clickLabel.ZIndex = prodBtn.ZIndex + 2
					clickLabel.Parent = highlight
					
					-- Animation de rebond pour le texte
					local bounce = TweenService:Create(clickLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
						Position = UDim2.new(0.5, -100, 1, 10)
					})
					bounce:Play()
					
					print("✅ [TUTORIAL] Bouton PRODUCE highlighted dans IncubatorMenuClient")
				end)
		end

		-- Compter combien de fois cette recette est dans la queue
		local queueCount = 0
		for _, item in ipairs(currentQueue) do
			if item == recipeName then
				queueCount = queueCount + 1
			end
		end
		
		-- Afficher le nombre dans la queue si > 0
		if queueCount > 0 then
			prodBtn.Text = string.format("▶ PRODUCE (%d)", queueCount)
		end

		-- Vérifier si on a les ingrédients
		local canProduce = hasIngredientsForRecipe(recipeDef)
		if not canProduce then
			prodBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			prodBtn.Active = false
		else
			prodBtn.MouseButton1Click:Connect(function()
				-- Protection anti-spam avec debounce de 0.5 seconde (correspond au serveur)
				local now = tick()
				
				-- Vérifier le cooldown simple (pas de flag bloquant)
				if now - lastProductionRequest < 0.5 then
					print("⚠️ [CLIENT] Too fast! Wait", string.format("%.1f", 0.5 - (now - lastProductionRequest)), "second(s)")
					-- Animation de vibration pour montrer qu'on ne peut pas cliquer
					local originalPos = prodBtn.Position
					for i = 1, 3 do
						prodBtn.Position = originalPos + UDim2.new(0, (i % 2 == 0) and 3 or -3, 0, 0)
						task.wait(0.05)
					end
					prodBtn.Position = originalPos
					return
				end
				
				-- Mettre à jour le timestamp
				lastProductionRequest = now
				
				-- Animation visuelle temporaire
				local originalText = prodBtn.Text
				prodBtn.Text = "..."
				
				print("🔍 [TUTORIAL] Clic sur PRODUCE, étape actuelle:", _G.CurrentTutorialStep)
				print("📤 [CLIENT] Sending production request:", currentIncID, recipeName)
				
				-- Envoyer au serveur (le serveur décide si c'est production ou queue)
				addToQueueEvt:FireServer(currentIncID, recipeName)
				
				-- Restaurer le texte rapidement
				task.delay(0.2, function()
					if prodBtn and prodBtn.Text == "..." then
						prodBtn.Text = originalText
					end
				end)
				
				-- 🎓 TUTORIEL: Fermer le menu automatiquement après avoir cliqué sur PRODUCE
				if _G.CurrentTutorialStep == "OPEN_INCUBATOR" or _G.CurrentTutorialStep == "VIEW_RECIPE" then
					print("🎓 [TUTORIAL] Fermeture du menu dans 0.3s...")
					task.wait(0.3)
					if gui then
						print("🎓 [TUTORIAL] Fermeture du menu maintenant")
						gui.Enabled = false
						isMenuOpen = false
						currentIncID = nil
						print("✅ [TUTORIAL] Menu incubateur fermé automatiquement")
					else
						print("❌ [TUTORIAL] gui est nil!")
					end
				else
					-- Rafraîchir l'UI normalement (hors tutoriel)
					task.wait(0.5)
					if gui and gui.Enabled then
						updateQueue()
						loadRecipeList()
					end
				end
			end)
		end
	end

	return card
end

-- Met à jour la queue depuis le serveur
function updateQueue()
	if not getQueueFunc then
		currentQueue = {}
		return
	end
	
	local ok, result = pcall(function()
		return getQueueFunc:InvokeServer(currentIncID)
	end)
	
	if ok and result then
		currentQueue = result
	else
		currentQueue = {}
	end
end

-- Charge la liste des recettes
function loadRecipeList()
	if not gui then return end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local recipeList = mainFrame:FindFirstChild("RecipeList")
	if not recipeList then return end

	for _, child in ipairs(recipeList:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^RecipeCard_") then
			child:Destroy()
		elseif child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	-- Récupérer les recettes débloquées
	local ok, result = pcall(function()
		return getUnlockedRecipesFunc:InvokeServer(currentIncID)
	end)
	
	if ok and result then
		unlockedRecipes = result
	end

	-- Mettre à jour la queue
	updateQueue()

	-- Récupérer les ingrédients disponibles
	local available = getAvailableIngredients()

	-- Filtrer et trier les recettes
	local sortedRecipes = {}
	for recipeName, recipeDef in pairs(RecipeManager.Recettes) do
		-- Vérifier si le joueur a les ingrédients pour cette recette
		local canMake = true
		for ingredient, needed in pairs(recipeDef.ingredients) do
			local have = available[ingredient] or 0
			if have < needed then
				canMake = false
				break
			end
		end
		
		-- Afficher seulement:
		-- 1. Les recettes déjà débloquées
		-- 2. Les recettes qu'on peut débloquer (avec les bons ingrédients)
		local isUnlocked = unlockedRecipes[recipeName] == true
		if isUnlocked or canMake then
			table.insert(sortedRecipes, {name = recipeName, def = recipeDef, canMake = canMake})
		end
	end
	
	table.sort(sortedRecipes, function(a, b)
		local rarityOrder = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5}
		local rarityA = rarityOrder[a.def.rarete] or 0
		local rarityB = rarityOrder[b.def.rarete] or 0
		
		if rarityA ~= rarityB then
			return rarityA < rarityB
		end
		
		return (a.def.ordre or 0) < (b.def.ordre or 0)
	end)

	-- Créer les cartes
	print(string.format("📋 [INCUBATOR] Displaying %d recipes (out of %d total)", #sortedRecipes, #RecipeManager.Recettes))
	for _, recipe in ipairs(sortedRecipes) do
		local isUnlocked = unlockedRecipes[recipe.name] == true
		createRecipeCard(recipeList, recipe.name, recipe.def, isUnlocked)
	end
	
	-- Message si aucune recette disponible
	if #sortedRecipes == 0 then
		local noRecipeLabel = Instance.new("TextLabel")
		noRecipeLabel.Size = UDim2.new(1, -20, 0, 100)
		noRecipeLabel.Position = UDim2.new(0, 10, 0, 10)
		noRecipeLabel.BackgroundTransparency = 1
		noRecipeLabel.Text = "No recipes available.\nCollect more ingredients!"
		noRecipeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		noRecipeLabel.Font = Enum.Font.Gotham
		noRecipeLabel.TextSize = 18
		noRecipeLabel.TextWrapped = true
		noRecipeLabel.Parent = recipeList
	end
end

----------------------------------------------------------------------
-- SYSTÈME DE DÉBLOCAGE D'INCUBATEURS
----------------------------------------------------------------------
local function showUnlockPanel(incubatorIndex)
	if not gui then return end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local recipeList = mainFrame:FindFirstChild("RecipeList")
	if recipeList then
		recipeList.Visible = false
	end
	
	-- Créer ou récupérer le panneau de déblocage
	local unlockPanel = mainFrame:FindFirstChild("UnlockPanel")
	if not unlockPanel then
		unlockPanel = Instance.new("Frame")
		unlockPanel.Name = "UnlockPanel"
		unlockPanel.Size = UDim2.new(1, -20, 1, -70)
		unlockPanel.Position = UDim2.new(0, 10, 0, 60)
		unlockPanel.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
		unlockPanel.BorderSizePixel = 0
		unlockPanel.Parent = mainFrame
		
		local corner = Instance.new("UICorner", unlockPanel)
		corner.CornerRadius = UDim.new(0, 12)
		
		-- Icône de cadenas
		local lockIcon = Instance.new("TextLabel")
		lockIcon.Size = UDim2.new(0, 100, 0, 100)
		lockIcon.Position = UDim2.new(0.5, -50, 0.2, 0)
		lockIcon.BackgroundTransparency = 1
		lockIcon.Text = "🔒"
		lockIcon.TextSize = 80
		lockIcon.Parent = unlockPanel
		
		-- Titre
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -40, 0, 40)
		title.Position = UDim2.new(0, 20, 0.4, 0)
		title.BackgroundTransparency = 1
		title.Text = "Incubator Locked"
		title.TextColor3 = Color3.fromRGB(255, 220, 150)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 28
		title.Parent = unlockPanel
		
		-- Description
		local desc = Instance.new("TextLabel")
		desc.Name = "Description"
		desc.Size = UDim2.new(1, -40, 0, 60)
		desc.Position = UDim2.new(0, 20, 0.5, 0)
		desc.BackgroundTransparency = 1
		desc.Text = "Unlock this incubator to produce more candies!"
		desc.TextColor3 = Color3.fromRGB(200, 200, 200)
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 18
		desc.TextWrapped = true
		desc.Parent = unlockPanel
		
		-- Bouton déblocage avec argent
		local moneyBtn = Instance.new("TextButton")
		moneyBtn.Name = "MoneyButton"
		moneyBtn.Size = UDim2.new(0, 280, 0, 60)
		moneyBtn.Position = UDim2.new(0.5, -140, 0.65, 0)
		moneyBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
		moneyBtn.Text = "Unlock with $"
		moneyBtn.TextColor3 = Color3.new(1, 1, 1)
		moneyBtn.Font = Enum.Font.GothamBold
		moneyBtn.TextSize = 20
		moneyBtn.Parent = unlockPanel
		
		local moneyCorner = Instance.new("UICorner", moneyBtn)
		moneyCorner.CornerRadius = UDim.new(0, 10)
		
		local moneyStroke = Instance.new("UIStroke", moneyBtn)
		moneyStroke.Color = Color3.fromRGB(40, 80, 40)
		moneyStroke.Thickness = 2
		
		-- Bouton déblocage avec Robux
		local robuxBtn = Instance.new("TextButton")
		robuxBtn.Name = "RobuxButton"
		robuxBtn.Size = UDim2.new(0, 280, 0, 60)
		robuxBtn.Position = UDim2.new(0.5, -140, 0.8, 0)
		robuxBtn.BackgroundColor3 = Color3.fromRGB(65, 130, 200)
		robuxBtn.Text = "Unlock with Robux"
		robuxBtn.TextColor3 = Color3.new(1, 1, 1)
		robuxBtn.Font = Enum.Font.GothamBold
		robuxBtn.TextSize = 20
		robuxBtn.Parent = unlockPanel
		
		local robuxCorner = Instance.new("UICorner", robuxBtn)
		robuxCorner.CornerRadius = UDim.new(0, 10)
		
		local robuxStroke = Instance.new("UIStroke", robuxBtn)
		robuxStroke.Color = Color3.fromRGB(30, 60, 90)
		robuxStroke.Thickness = 2
		
		-- Stocker l'index dans le bouton pour éviter les problèmes de closure
		moneyBtn:SetAttribute("IncubatorIndex", incubatorIndex)
		robuxBtn:SetAttribute("IncubatorIndex", incubatorIndex)
		
		-- Événements des boutons
		moneyBtn.MouseButton1Click:Connect(function()
			-- Récupérer l'index depuis l'attribut du bouton (évite les problèmes de closure)
			local btnIndex = moneyBtn:GetAttribute("IncubatorIndex")
			print("💰 [CLIENT] Button clicked for incubator", btnIndex)
			
			-- Vérifier l'argent du joueur avant d'envoyer la requête
			local playerData = plr:FindFirstChild("PlayerData")
			local argent = playerData and playerData:FindFirstChild("Argent")
			local currentMoney = argent and argent.Value or 0
			
			local price = (btnIndex == 2) and 100000000000 or 1000000000000
			
			if currentMoney < price then
				-- Pas assez d'argent - Animation de vibration et rouge
				local originalText = moneyBtn.Text
				local originalColor = moneyBtn.BackgroundColor3
				local originalPos = moneyBtn.Position
				
				-- Changer en rouge
				moneyBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
				moneyBtn.Text = "❌ Not enough money!"
				
				-- Animation de vibration (shake)
				local shakeAmount = 10
				local shakeDuration = 0.05
				for i = 1, 6 do
					local offsetX = (i % 2 == 0) and shakeAmount or -shakeAmount
					moneyBtn.Position = originalPos + UDim2.new(0, offsetX, 0, 0)
					task.wait(shakeDuration)
				end
				moneyBtn.Position = originalPos
				
				-- Attendre 1.5 secondes puis revenir à la normale
				task.wait(1.5)
				moneyBtn.Text = originalText
				moneyBtn.BackgroundColor3 = originalColor
				return
			end
			
			-- Assez d'argent - Envoyer la requête
			local originalText = moneyBtn.Text
			moneyBtn.Text = "..."
			moneyBtn.Active = false
			
			-- Bloquer la fermeture du menu pendant l'achat
			purchaseInProgress = true
			lastPurchasedIncubatorID = currentIncID
			lastPurchasedIncubatorIndex = btnIndex
			print("� [CLIENNT] Purchase in progress, menu cannot be closed")
			print("📝 [CLIENT] Saved incubator info:", lastPurchasedIncubatorID, "index:", lastPurchasedIncubatorIndex)
			
			print("💰 [CLIENT] Sending unlock request for incubator", btnIndex)
			requestUnlockIncubatorMoneyEvt:FireServer(btnIndex)
			
			-- Timeout de sécurité : débloquer après 3 secondes max
			task.spawn(function()
				task.wait(3)
				if purchaseInProgress then
					purchaseInProgress = false
					print("⏱️ [CLIENT] Purchase timeout - menu can be closed again")
				end
			end)
			
			task.wait(1)
			moneyBtn.Active = true
			moneyBtn.Text = originalText
			print("⏱️ [CLIENT] Waiting for server response...")
		end)
		
		robuxBtn.MouseButton1Click:Connect(function()
			-- Récupérer l'index depuis l'attribut du bouton
			local btnIndex = robuxBtn:GetAttribute("IncubatorIndex")
			print("💎 [CLIENT] Robux button clicked for incubator", btnIndex)
			
			robuxBtn.Text = "..."
			robuxBtn.Active = false
			requestUnlockIncubatorEvt:FireServer(btnIndex)
			task.wait(1)
			robuxBtn.Active = true
			robuxBtn.Text = "Unlock with Robux"
		end)
	end
	
	-- Mettre à jour les textes selon l'index ET reset l'état du bouton
	local moneyBtn = unlockPanel:FindFirstChild("MoneyButton")
	local robuxBtn = unlockPanel:FindFirstChild("RobuxButton")
	local desc = unlockPanel:FindFirstChild("Description")
	
	-- Reset complet de l'état des boutons (au cas où une animation était en cours)
	if moneyBtn then
		moneyBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
		moneyBtn.Active = true
		moneyBtn.Position = UDim2.new(0.5, -140, 0.65, 0) -- Position originale
		-- IMPORTANT: Mettre à jour l'attribut avec le nouvel index
		moneyBtn:SetAttribute("IncubatorIndex", incubatorIndex)
		print("🔧 [INCUBATOR] Money button index updated to:", incubatorIndex)
	end
	
	if robuxBtn then
		robuxBtn.BackgroundColor3 = Color3.fromRGB(65, 130, 200)
		robuxBtn.Active = true
		robuxBtn.Text = "Unlock with Robux"
		-- IMPORTANT: Mettre à jour l'attribut avec le nouvel index
		robuxBtn:SetAttribute("IncubatorIndex", incubatorIndex)
		print("🔧 [INCUBATOR] Robux button index updated to:", incubatorIndex)
	end
	
	-- Mettre à jour les textes selon l'index
	if incubatorIndex == 2 then
		if moneyBtn then moneyBtn.Text = "Unlock for 100B $" end
		if desc then desc.Text = "Unlock Incubator #2 to double your production capacity!" end
	elseif incubatorIndex == 3 then
		if moneyBtn then moneyBtn.Text = "Unlock for 1T $" end
		if desc then desc.Text = "Unlock Incubator #3 for maximum production power!" end
	end
	
	unlockPanel.Visible = true
end

local function hideUnlockPanel()
	if not gui then return end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local unlockPanel = mainFrame:FindFirstChild("UnlockPanel")
	if unlockPanel then
		unlockPanel.Visible = false
	end
	
	local recipeList = mainFrame:FindFirstChild("RecipeList")
	if recipeList then
		recipeList.Visible = true
	end
end

----------------------------------------------------------------------
-- CRÉATION DE L'INTERFACE
----------------------------------------------------------------------
createGUI = function()
	if gui then
		gui:Destroy()
	end
	
	-- Réinitialiser l'overlay aussi
	productionOverlay = nil

	gui = Instance.new("ScreenGui")
	gui.Name = "IncubatorMenuNew"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2000 -- Z-Index TRÈS élevé pour passer au-dessus de TOUT (même l'argent)
	gui.Parent = plr:WaitForChild("PlayerGui")

	-- Frame principale avec taille responsive
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 700, 0, 500)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = gui
	
	-- UIScale pour adapter automatiquement à la taille de l'écran
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = mainFrame
	
	-- UISizeConstraint pour limiter la taille min/max
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(350, 250)
	sizeConstraint.MaxSize = Vector2.new(1000, 800)
	sizeConstraint.Parent = mainFrame
	
	-- Fonction pour ajuster le scale selon la taille de l'écran
	local function updateScale()
		local viewportSize = workspace.CurrentCamera.ViewportSize
		local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local isPortrait = viewportSize.Y > viewportSize.X
		
		-- Calcul du scale basé sur la résolution
		local scaleX = viewportSize.X / 1920 -- Référence 1920x1080
		local scaleY = viewportSize.Y / 1080
		local scale = math.min(scaleX, scaleY, 1.2) -- Max 120%
		
		-- Ajustements spécifiques pour mobile/tablette
		if isMobile then
			if isPortrait then
				-- Téléphone en mode portrait : utiliser toute la largeur
				scale = math.max(scale, viewportSize.X / 750)
			else
				-- Téléphone/tablette en mode paysage
				scale = math.max(scale, 0.5)
			end
		end
		
		-- Limites finales
		scale = math.max(scale, 0.45) -- Min 45% pour très petits écrans
		scale = math.min(scale, 1.3) -- Max 130% pour très grands écrans
		
		uiScale.Scale = scale
	end
	
	-- Mettre à jour au démarrage
	updateScale()
	
	-- Mettre à jour quand la taille de l'écran change
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	local mainCorner = Instance.new("UICorner", mainFrame)
	mainCorner.CornerRadius = UDim.new(0, 12)

	local mainStroke = Instance.new("UIStroke", mainFrame)
	mainStroke.Color = Color3.fromRGB(100, 80, 60)
	mainStroke.Thickness = 3

	-- Titre
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 40)
	titleLabel.Position = UDim2.new(0, 10, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🍬 Candy Recipes"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 24
	titleLabel.Parent = mainFrame

	-- Bouton fermer
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner", closeBtn)
	closeCorner.CornerRadius = UDim.new(0, 8)

	closeBtn.MouseButton1Click:Connect(function()
		-- Ne pas fermer si un achat est en cours
		if purchaseInProgress then
			print("⚠️ [CLIENT] Cannot close menu - purchase in progress")
			-- Faire vibrer le bouton pour montrer qu'on ne peut pas fermer
			local originalPos = closeBtn.Position
			for i = 1, 3 do
				closeBtn.Position = originalPos + UDim2.new(0, (i % 2 == 0) and 5 or -5, 0, 0)
				task.wait(0.05)
			end
			closeBtn.Position = originalPos
			return
		end
		
		gui.Enabled = false
		isMenuOpen = false
		currentIncID = nil
	end)

	-- ScrollingFrame pour la liste des recettes (avec marges confortables)
	local recipeList = Instance.new("ScrollingFrame")
	recipeList.Name = "RecipeList"
	local scrollMargin = 30 -- Marges horizontales
	local scrollTopOffset = 60
	local scrollBottomMargin = 15
	recipeList.Size = UDim2.new(1, -(scrollMargin * 2), 1, -(scrollTopOffset + scrollBottomMargin))
	recipeList.Position = UDim2.new(0, scrollMargin, 0, scrollTopOffset)
	recipeList.BackgroundColor3 = Color3.fromRGB(30, 22, 15)
	recipeList.BorderSizePixel = 0
	recipeList.ScrollBarThickness = 12
	recipeList.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100) -- Scrollbar plus visible
	recipeList.CanvasSize = UDim2.new(0, 0, 0, 0) -- Sera mis à jour automatiquement
	recipeList.ScrollingDirection = Enum.ScrollingDirection.Y -- Scroll vertical uniquement
	recipeList.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	recipeList.ElasticBehavior = Enum.ElasticBehavior.Never -- Pas d'élasticité (important!)
	recipeList.ScrollingEnabled = true -- S'assurer que le scroll est activé
	recipeList.AutomaticCanvasSize = Enum.AutomaticSize.Y -- Ajustement automatique du canvas!
	recipeList.Parent = mainFrame

	local listCorner = Instance.new("UICorner", recipeList)
	listCorner.CornerRadius = UDim.new(0, 10)

	-- Padding interne pour éviter que le contenu touche les bords
	local recipePadding = Instance.new("UIPadding", recipeList)
	recipePadding.PaddingLeft = UDim.new(0, 10)
	recipePadding.PaddingRight = UDim.new(0, 10)
	recipePadding.PaddingTop = UDim.new(0, 10)
	recipePadding.PaddingBottom = UDim.new(0, 10)

	-- Layout pour la liste
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = recipeList

	-- Le canvas s'ajuste automatiquement grâce à AutomaticCanvasSize
	-- On garde juste un debug pour voir la taille
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		print(string.format("📏 [INCUBATOR] Content size: %d pixels (for %d items)", listLayout.AbsoluteContentSize.Y, #recipeList:GetChildren() - 3))
	end)

	return gui
end

-- Variable globale pour l'overlay (créé une seule fois)
local productionOverlay = nil

-- Crée l'overlay de production (affiché pendant la production)
local function createProductionOverlay()
	if not gui then return nil end
	
	-- Si l'overlay existe déjà, le retourner
	if productionOverlay and productionOverlay.Parent then
		return productionOverlay
	end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return nil end
	
	local overlay = Instance.new("Frame")
	overlay.Name = "ProductionOverlay"
	overlay.Size = UDim2.new(0, 400, 0, 350)
	overlay.AnchorPoint = Vector2.new(0, 0)
	overlay.Position = UDim2.new(1, 10, 0, 0) -- 10 pixels à droite du mainFrame
	overlay.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = mainFrame -- Parent = mainFrame au lieu de gui
	
	-- Sauvegarder la référence
	productionOverlay = overlay

	local overlayCorner = Instance.new("UICorner", overlay)
	overlayCorner.CornerRadius = UDim.new(0, 12)

	local overlayStroke = Instance.new("UIStroke", overlay)
	overlayStroke.Color = Color3.fromRGB(255, 180, 50)
	overlayStroke.Thickness = 3

	-- Titre
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 35)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "🏭 Production Active"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.Parent = overlay

	-- Info production actuelle
	local currentInfo = Instance.new("Frame")
	currentInfo.Name = "CurrentInfo"
	currentInfo.Size = UDim2.new(1, -20, 0, 80)
	currentInfo.Position = UDim2.new(0, 10, 0, 50)
	currentInfo.BackgroundColor3 = Color3.fromRGB(30, 22, 15)
	currentInfo.BorderSizePixel = 0
	currentInfo.Parent = overlay

	local currentCorner = Instance.new("UICorner", currentInfo)
	currentCorner.CornerRadius = UDim.new(0, 8)

	local currentLabel = Instance.new("TextLabel")
	currentLabel.Name = "CurrentLabel"
	currentLabel.Size = UDim2.new(1, -10, 0, 25)
	currentLabel.Position = UDim2.new(0, 5, 0, 5)
	currentLabel.BackgroundTransparency = 1
	currentLabel.Text = "Current: Basic Gelatin"
	currentLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	currentLabel.Font = Enum.Font.GothamBold
	currentLabel.TextSize = 16
	currentLabel.TextXAlignment = Enum.TextXAlignment.Left
	currentLabel.Parent = currentInfo

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(1, -10, 0, 20)
	progressLabel.Position = UDim2.new(0, 5, 0, 30)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "Progress: 15/60 candies"
	progressLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	progressLabel.Font = Enum.Font.Gotham
	progressLabel.TextSize = 14
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Parent = currentInfo

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = UDim2.new(1, -10, 0, 20)
	timeLabel.Position = UDim2.new(0, 5, 0, 52)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = "Time: 00:45"
	timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	timeLabel.Font = Enum.Font.Gotham
	timeLabel.TextSize = 14
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.Parent = currentInfo

	-- Liste de la queue
	local queueTitle = Instance.new("TextLabel")
	queueTitle.Name = "QueueTitle"
	queueTitle.Size = UDim2.new(1, -20, 0, 25)
	queueTitle.Position = UDim2.new(0, 10, 0, 140)
	queueTitle.BackgroundTransparency = 1
	queueTitle.Text = "Queue (0):"
	queueTitle.TextColor3 = Color3.new(1, 1, 1)
	queueTitle.Font = Enum.Font.GothamBold
	queueTitle.TextSize = 16
	queueTitle.TextXAlignment = Enum.TextXAlignment.Left
	queueTitle.Parent = overlay

	local queueList = Instance.new("ScrollingFrame")
	queueList.Name = "QueueList"
	queueList.Size = UDim2.new(1, -20, 0, 100)
	queueList.Position = UDim2.new(0, 10, 0, 170)
	queueList.BackgroundColor3 = Color3.fromRGB(30, 22, 15)
	queueList.BorderSizePixel = 0
	queueList.ScrollBarThickness = 8
	queueList.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100) -- Scrollbar visible
	queueList.ScrollingEnabled = true -- Activer le scroll
	queueList.CanvasSize = UDim2.new(0, 0, 0, 0) -- Sera mis à jour automatiquement
	queueList.Parent = overlay

	local queueCorner = Instance.new("UICorner", queueList)
	queueCorner.CornerRadius = UDim.new(0, 8)

	local queueLayout = Instance.new("UIListLayout")
	queueLayout.Padding = UDim.new(0, 5)
	queueLayout.SortOrder = Enum.SortOrder.LayoutOrder
	queueLayout.Parent = queueList

	queueLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		queueList.CanvasSize = UDim2.new(0, 0, 0, queueLayout.AbsoluteContentSize.Y + 5)
	end)

	-- Boutons
	local stopBtn = Instance.new("TextButton")
	stopBtn.Name = "StopBtn"
	stopBtn.Size = UDim2.new(0.48, 0, 0, 40)
	stopBtn.Position = UDim2.new(0, 10, 1, -50)
	stopBtn.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
	stopBtn.Text = "■ STOP"
	stopBtn.TextColor3 = Color3.new(1, 1, 1)
	stopBtn.Font = Enum.Font.GothamBold
	stopBtn.TextSize = 16
	stopBtn.Parent = overlay

	local stopCorner = Instance.new("UICorner", stopBtn)
	stopCorner.CornerRadius = UDim.new(0, 8)

	stopBtn.MouseButton1Click:Connect(function()
		print("🛑 Stop production")
		stopProductionEvt:FireServer(currentIncID)
		
		-- Marquer que l'overlay a été fermé manuellement
		overlayManuallyClosed = true
		
		-- Cacher l'overlay en le cherchant dans le mainFrame (car il est parent du mainFrame)
		if gui then
			local mainFrame = gui:FindFirstChild("MainFrame")
			if mainFrame then
				-- Chercher l'overlay dans le mainFrame
				local overlayToHide = mainFrame:FindFirstChild("ProductionOverlay")
				if overlayToHide then
					overlayToHide.Visible = false
					print("✅ [CLIENT] Overlay hidden manually")
				else
					print("⚠️ [CLIENT] Overlay not found in MainFrame")
				end
				
				-- Ramener le mainFrame au centre immédiatement
				local centerPosition = UDim2.new(0.5, 0, 0.5, 0)
				TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = centerPosition
				}):Play()
			end
		end
	end)

	local finishBtn = Instance.new("TextButton")
	finishBtn.Name = "FinishBtn"
	finishBtn.Size = UDim2.new(0.48, 0, 0, 40)
	finishBtn.Position = UDim2.new(0.52, 0, 1, -50)
	finishBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	finishBtn.Text = "⚡ FINISH (50 R$)"
	finishBtn.TextColor3 = Color3.new(0, 0, 0)
	finishBtn.Font = Enum.Font.GothamBold
	finishBtn.TextSize = 14
	finishBtn.Parent = overlay

	local finishCorner = Instance.new("UICorner", finishBtn)
	finishCorner.CornerRadius = UDim.new(0, 8)

	finishBtn.MouseButton1Click:Connect(function()
		-- Protection anti-spam
		if finishBtn.Text:find("%.%.%.") then
			print("⚠️ [CLIENT] Finish already in progress")
			return
		end
		
		local originalText = finishBtn.Text
		finishBtn.Text = "..."
		finishBtn.Active = false
		
		print("⚡ [CLIENT] Requesting finish with Robux")
		finishNowRobuxEvt:FireServer(currentIncID)
		
		-- Réactiver après 2 secondes (temps pour le prompt)
		task.delay(2, function()
			if finishBtn and finishBtn.Parent then
				finishBtn.Text = originalText
				finishBtn.Active = true
			end
		end)
	end)

	return overlay
end

-- Fonction pour obtenir ou créer l'overlay (optimisé)
local function getOrCreateOverlay()
	if not gui then return nil end
	
	-- Vérifier si l'overlay existe et est valide
	if productionOverlay and productionOverlay.Parent then
		return productionOverlay
	end
	
	-- Sinon le créer
	return createProductionOverlay()
end

-- Variable pour tracker la dernière mise à jour de la queue
local lastQueueUpdate = 0
local lastQueueSize = 0
local overlayManuallyClosed = false -- Flag pour empêcher la réouverture automatique

-- Met à jour l'overlay de production
local function updateProductionOverlay(recipeName, candiesSpawned, candiesTotal)
	if not gui then return end
	
	-- Si l'overlay a été fermé manuellement, ne pas le réafficher
	if overlayManuallyClosed then
		print("⚠️ [CLIENT] Overlay was manually closed, not showing")
		return
	end
	
	-- Utiliser la fonction optimisée
	local overlay = getOrCreateOverlay()
	if not overlay then return end
	
	-- Afficher l'overlay
	overlay.Visible = true
	
	-- Animer le mainFrame vers la gauche quand l'overlay apparaît
	local mainFrame = gui:FindFirstChild("MainFrame")
	if mainFrame then
		-- Décaler le mainFrame vers la gauche avec une animation smooth
		local targetPosition = UDim2.new(0.5, -80, 0.5, 0) -- Décalé de 80px vers la gauche (encore réduit)
		TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = targetPosition
		}):Play()
	end
	
	-- Mettre à jour les infos (rapide, pas de problème)
	local currentInfo = overlay:FindFirstChild("CurrentInfo")
	if currentInfo then
		local currentLabel = currentInfo:FindFirstChild("CurrentLabel")
		if currentLabel then
			local recipeDef = RecipeManager.Recettes[recipeName]
			local displayName = recipeDef and recipeDef.nom or recipeName
			currentLabel.Text = "Current: " .. displayName
		end
		
		local progressLabel = currentInfo:FindFirstChild("ProgressLabel")
		if progressLabel then
			progressLabel.Text = string.format("Progress: %d/%d candies", candiesSpawned, candiesTotal)
		end
		
		local timeLabel = currentInfo:FindFirstChild("TimeLabel")
		if timeLabel and recipeName then
			local recipeDef = RecipeManager.Recettes[recipeName]
			if recipeDef and recipeDef.temps then
				local spawnInterval = recipeDef.temps / candiesTotal
				local remaining = (candiesTotal - candiesSpawned) * spawnInterval
				local minutes = math.floor(remaining / 60)
				local seconds = math.floor(remaining % 60)
				timeLabel.Text = string.format("Time: %02d:%02d", minutes, seconds)
			end
		end
	end
	
	-- Mettre à jour la queue SEULEMENT toutes les 2 secondes OU si la taille change
	local now = tick()
	updateQueue()
	
	local needsQueueRefresh = false
	if #currentQueue ~= lastQueueSize then
		needsQueueRefresh = true
		lastQueueSize = #currentQueue
	elseif now - lastQueueUpdate > 2 then
		needsQueueRefresh = true
	end
	
	if not needsQueueRefresh then
		-- Juste mettre à jour le titre
		local queueTitle = overlay:FindFirstChild("QueueTitle")
		if queueTitle then
			queueTitle.Text = string.format("Queue (%d):", #currentQueue)
		end
		return
	end
	
	lastQueueUpdate = now
	
	local queueTitle = overlay:FindFirstChild("QueueTitle")
	if queueTitle then
		queueTitle.Text = string.format("Queue (%d):", #currentQueue)
	end
	
	local queueList = overlay:FindFirstChild("QueueList")
	if queueList then
		-- Nettoyer la liste
		for _, child in ipairs(queueList:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		
		-- Ajouter les items de la queue
		for i, queueRecipeName in ipairs(currentQueue) do
			local item = Instance.new("Frame")
			item.Size = UDim2.new(1, -10, 0, 30)
			item.BackgroundColor3 = Color3.fromRGB(50, 40, 30)
			item.BorderSizePixel = 0
			item.Parent = queueList
			
			local itemCorner = Instance.new("UICorner", item)
			itemCorner.CornerRadius = UDim.new(0, 6)
			
			local itemLabel = Instance.new("TextLabel")
			itemLabel.Size = UDim2.new(1, -40, 1, 0)
			itemLabel.Position = UDim2.new(0, 5, 0, 0)
			itemLabel.BackgroundTransparency = 1
			itemLabel.Text = string.format("%d. %s", i, queueRecipeName)
			itemLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
			itemLabel.Font = Enum.Font.Gotham
			itemLabel.TextSize = 14
			itemLabel.TextXAlignment = Enum.TextXAlignment.Left
			itemLabel.Parent = item
			
			local removeBtn = Instance.new("TextButton")
			removeBtn.Size = UDim2.new(0, 30, 0, 25)
			removeBtn.Position = UDim2.new(1, -35, 0.5, -12.5)
			removeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
			removeBtn.Text = "✕"
			removeBtn.TextColor3 = Color3.new(1, 1, 1)
			removeBtn.Font = Enum.Font.GothamBold
			removeBtn.TextSize = 14
			removeBtn.Parent = item
			
			local removeCorner = Instance.new("UICorner", removeBtn)
			removeCorner.CornerRadius = UDim.new(0, 6)
			
			removeBtn.MouseButton1Click:Connect(function()
				print("🗑️ Remove from queue:", i)
				removeFromQueueEvt:FireServer(currentIncID, i)
				task.wait(0.2)
				updateProductionOverlay(recipeName, candiesSpawned, candiesTotal)
			end)
		end
	end
end

----------------------------------------------------------------------
-- ÉVÉNEMENTS
----------------------------------------------------------------------

openEvt.OnClientEvent:Connect(function(incubatorID, incubatorIndex)
	-- 🔧 NOUVEAU: Si le menu est déjà ouvert pour cet incubateur, le fermer
	if isMenuOpen and currentIncID == incubatorID then
		gui.Enabled = false
		isMenuOpen = false
		currentIncID = nil
		return
	end
	
	-- 🔧 Si le menu est ouvert pour un AUTRE incubateur, fermer et réinitialiser
	if isMenuOpen and currentIncID ~= incubatorID then
		print("🔄 [INCUBATOR] Switching from incubator", currentIncID, "to", incubatorID)
		gui.Enabled = false
		isMenuOpen = false
		-- Nettoyer l'overlay de production si présent
		if productionOverlay then
			productionOverlay:Destroy()
			productionOverlay = nil
		end
		task.wait(0.1) -- Petit délai pour s'assurer que tout est nettoyé
	end
	
	if not gui then
		createGUI()
	end

	currentIncID = incubatorID
	isMenuOpen = true
	
	-- Réinitialiser l'état de l'overlay
	overlayManuallyClosed = false
	
	-- Détruire l'overlay existant (il sera recréé par productionProgressEvt si nécessaire)
	if productionOverlay then
		productionOverlay:Destroy()
		productionOverlay = nil
	end
	
	gui.Enabled = true

	-- Vérifier si l'incubateur est débloqué
	local playerData = plr:FindFirstChild("PlayerData")
	local incubatorsUnlocked = playerData and playerData:FindFirstChild("IncubatorsUnlocked")
	local unlockedCount = incubatorsUnlocked and incubatorsUnlocked.Value or 1
	
	-- Debug logs
	print("🔍 [INCUBATOR] Opening incubator", incubatorIndex or "nil", "- Unlocked count:", unlockedCount)
	
	-- Si l'incubateur n'est pas débloqué, afficher le panneau de déblocage
	-- Note: Si incubatorIndex est nil, on considère que c'est l'incubateur 1 (toujours débloqué)
	local effectiveIndex = incubatorIndex or 1
	if effectiveIndex > unlockedCount then
		print("🔒 [INCUBATOR] Showing unlock panel for incubator", effectiveIndex)
		showUnlockPanel(effectiveIndex)
	else
		print("✅ [INCUBATOR] Incubator unlocked, showing recipes")
		-- Charger la liste des recettes normalement
		hideUnlockPanel()
		loadRecipeList()
	end
end)

-- Mise à jour de la progression
productionProgressEvt.OnClientEvent:Connect(function(incubatorID, progress, recipeName, candiesSpawned, candiesTotal, realDuration)
	-- Si candiesTotal = 0, c'est un signal d'arrêt
	if candiesTotal == 0 then
		local bb = incubatorBillboards[incubatorID]
		if bb then
			bb.Enabled = false
		end
		
		-- Cacher l'overlay aussi et réinitialiser le flag
		overlayManuallyClosed = false -- Réinitialiser pour permettre une nouvelle production
		
		if gui then
			local mainFrame = gui:FindFirstChild("MainFrame")
			if mainFrame then
				local overlay = mainFrame:FindFirstChild("ProductionOverlay")
				if overlay then
					overlay.Visible = false
				end
				
				-- Ramener le mainFrame au centre avec une animation smooth
				local centerPosition = UDim2.new(0.5, 0, 0.5, 0) -- Position centrée
				TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = centerPosition
				}):Play()
			end
		end
		return
	end
	
	-- Mettre à jour le billboard au-dessus de l'incubateur
	local bb = ensureBillboard(incubatorID)
	if bb then
		local bg = bb:FindFirstChild("BG")
		local fill = bg and bg:FindFirstChild("Fill")
		local timer = bb:FindFirstChild("Timer")
		local title = bb:FindFirstChild("Title")
		
		if fill then
			-- Mettre à jour la barre (progression du bonbon actuel)
			local target = math.clamp(progress, 0, 1)
			TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				Size = UDim2.new(target, 0, 1, 0)
			}):Play()
			
			-- Afficher le billboard
			bb.Enabled = true
			
			-- Mettre à jour le titre avec le nombre de bonbons
			if title and candiesSpawned and candiesTotal then
				title.Text = string.format("Production %d/%d", candiesSpawned, candiesTotal)
			end
			
			-- Mettre à jour le timer (temps restant estimé avec bonus de vitesse)
			if timer and recipeName and candiesSpawned and candiesTotal then
				-- Utiliser la durée réelle envoyée par le serveur (avec bonus) si disponible
				local duration = realDuration
				if not duration then
					-- Fallback: utiliser le temps de base de la recette
					local recipeDef = RecipeManager.Recettes[recipeName]
					duration = recipeDef and recipeDef.temps or 60
				end
				local spawnInterval = duration / candiesTotal
				local remaining = (candiesTotal - candiesSpawned) * spawnInterval
				local minutes = math.floor(remaining / 60)
				local seconds = math.floor(remaining % 60)
				timer.Text = string.format("%02d:%02d", minutes, seconds)
			end
			
			-- Cacher le billboard quand tout est terminé
			if candiesSpawned >= candiesTotal then
				task.wait(1)
				bb.Enabled = false
			end
		end
	end
	
	-- Mettre à jour l'overlay de production (si c'est notre incubateur ET que le menu est ouvert)
	if incubatorID == currentIncID and gui and gui.Enabled then
		updateProductionOverlay(recipeName, candiesSpawned, candiesTotal)
	end
	
	-- Cacher l'overlay quand tout est terminé
	if candiesSpawned >= candiesTotal then
		task.wait(1)
		if gui then
			local overlay = gui:FindFirstChild("ProductionOverlay")
			if overlay then
				overlay.Visible = false
			end
		end
	end
end)

----------------------------------------------------------------------
-- ÉVÉNEMENT DE DÉBLOCAGE (doit être après les définitions de fonctions)
----------------------------------------------------------------------
-- Afficher l'écran de production après achat réussi
unlockIncubatorPurchasedEvt.OnClientEvent:Connect(function(unlockedIndex)
	print("✅ [INCUBATOR] Unlock successful for incubator", unlockedIndex)
	
	-- Attendre un peu pour que la valeur IncubatorsUnlocked soit répliquée
	task.wait(0.3)
	
	-- Débloquer la fermeture du menu
	purchaseInProgress = false
	print("🔓 [CLIENT] Purchase complete")
	
	-- Afficher l'écran de production au lieu de fermer
	print("✅ [INCUBATOR] Incubator", unlockedIndex, "unlocked! Showing production screen...")
	
	-- Chercher le GUI dans PlayerGui au cas où la variable locale serait nil
	local playerGui = plr:WaitForChild("PlayerGui")
	local actualGui = gui or playerGui:FindFirstChild("IncubatorMenuNew")
	
	print("🔍 [DEBUG] Local gui:", gui ~= nil, "Found in PlayerGui:", actualGui ~= nil)
	
	if actualGui and actualGui.Parent and actualGui.Enabled then
		print("🎉 [INCUBATOR] GUI is open, switching to production screen")
		
		-- Mettre à jour la référence locale si nécessaire
		if not gui then
			gui = actualGui
		end
		
		-- Cacher le panneau de déblocage et afficher les recettes
		hideUnlockPanel()
		loadRecipeList()
		print("✅ [INCUBATOR] Production screen displayed!")
	else
		print("ℹ️ [INCUBATOR] Menu was closed, reopen to see the recipes")
	end
end)

----------------------------------------------------------------------
-- INITIALISATION
----------------------------------------------------------------------
createGUI()

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	
	if input.KeyCode == Enum.KeyCode.Escape then
		if isMenuOpen and gui and gui.Enabled then
			gui.Enabled = false
			isMenuOpen = false
			currentIncID = nil
		end
	end
end)

