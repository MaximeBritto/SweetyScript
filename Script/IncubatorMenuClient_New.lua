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

----------------------------------------------------------------------
-- VARIABLES GLOBALES
----------------------------------------------------------------------
local gui = nil
local currentIncID = nil
local isMenuOpen = false
local unlockedRecipes = {}
local incubatorBillboards = {} -- Stocke les barres de progression
local currentQueue = {} -- Queue actuelle

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
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Production"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true

	local bg = Instance.new("Frame", bb)
	bg.Name = "BG"
	bg.Size = UDim2.new(0, 180, 0.45, 0)
	bg.Position = UDim2.new(0, 0, 0.6, 0)
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

	if not isUnlocked then
		-- Bouton Unlock
		local unlockBtn = Instance.new("TextButton")
		unlockBtn.Name = "UnlockButton"
		unlockBtn.Size = UDim2.new(1, 0, 0, 50)
		unlockBtn.Position = UDim2.new(0, 0, 0.5, -25)
		unlockBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		unlockBtn.Text = "UNLOCK"
		unlockBtn.TextColor3 = Color3.new(1, 1, 1)
		unlockBtn.Font = Enum.Font.GothamBold
		unlockBtn.TextSize = 16
		unlockBtn.Parent = buttonFrame

		local unlockCorner = Instance.new("UICorner", unlockBtn)
		unlockCorner.CornerRadius = UDim.new(0, 8)

		-- 🎓 TUTORIEL: Highlight du bouton UNLOCK si on est à cette étape
		local tutorialStep = _G.CurrentTutorialStep
		print("🔍 [TUTORIAL] Création bouton UNLOCK, étape actuelle:", tutorialStep)
		if tutorialStep == "UNLOCK_RECIPE" then
				task.spawn(function()
					task.wait(0.1)
					-- Créer un highlight sur le bouton
					local highlight = Instance.new("Frame")
					highlight.Name = "TutorialHighlight_UNLOCK"
					highlight.Size = UDim2.new(1, 8, 1, 8)
					highlight.Position = UDim2.new(0, -4, 0, -4)
					highlight.BackgroundTransparency = 1
					highlight.BorderSizePixel = 0
					highlight.ZIndex = unlockBtn.ZIndex + 1
					highlight.Parent = unlockBtn
					
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
					clickLabel.ZIndex = unlockBtn.ZIndex + 2
					clickLabel.Parent = highlight
					
					-- Animation de rebond pour le texte
					local bounce = TweenService:Create(clickLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
						Position = UDim2.new(0.5, -100, 1, 10)
					})
					bounce:Play()
					
					print("✅ [TUTORIAL] Bouton UNLOCK highlighted dans IncubatorMenuClient")
				end)
		end

		-- Vérifier si on peut débloquer
		local canUnlock = hasIngredientsForRecipe(recipeDef)
		if not canUnlock then
			unlockBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			unlockBtn.Text = "LOCKED"
			unlockBtn.Active = false
		else
			unlockBtn.MouseButton1Click:Connect(function()
				print("🔧 Tentative d'unlock:", recipeName)
				unlockBtn.Text = "..."
				unlockBtn.Active = false
				
				unlockRecipeEvt:FireServer(currentIncID, recipeName)
				
				-- Rafraîchir l'UI après un court délai
				task.wait(0.5)
				if gui and gui.Enabled then
					loadRecipeList()
				end
			end)
		end
	else
		-- Bouton Production unique (gère production ET queue)
		local prodBtn = Instance.new("TextButton")
		prodBtn.Name = "ProduceButton"
		prodBtn.Size = UDim2.new(1, 0, 0, 50)
		prodBtn.Position = UDim2.new(0, 0, 0.5, -25)
		prodBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		prodBtn.Text = "▶ PRODUCE"
		prodBtn.TextColor3 = Color3.new(1, 1, 1)
		prodBtn.Font = Enum.Font.GothamBold
		prodBtn.TextSize = 16
		prodBtn.Parent = buttonFrame

		local prodCorner = Instance.new("UICorner", prodBtn)
		prodCorner.CornerRadius = UDim.new(0, 8)

		-- 🎓 TUTORIEL: Highlight du bouton PRODUCE si on est à cette étape
		local tutorialStep = _G.CurrentTutorialStep
		print("🔍 [TUTORIAL] Création bouton PRODUCE, étape actuelle:", tutorialStep)
		if tutorialStep == "VIEW_RECIPE" then
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
				prodBtn.Text = "..."
				prodBtn.Active = false
				
				print("🔍 [TUTORIAL] Clic sur PRODUCE, étape actuelle:", _G.CurrentTutorialStep)
				
				-- Envoyer au serveur (le serveur décide si c'est production ou queue)
				addToQueueEvt:FireServer(currentIncID, recipeName)
				
				-- 🎓 TUTORIEL: Fermer le menu automatiquement après avoir cliqué sur PRODUCE
				if _G.CurrentTutorialStep == "VIEW_RECIPE" then
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
					print("ℹ️ [TUTORIAL] Pas en mode tutoriel, rafraîchissement normal")
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
-- CRÉATION DE L'INTERFACE
----------------------------------------------------------------------
local function createGUI()
	if gui then
		gui:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "IncubatorMenuNew"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = plr:WaitForChild("PlayerGui")

	-- Frame principale
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 700, 0, 500)
	mainFrame.Position = UDim2.new(0.5, -350, 0.5, -250)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = gui

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
		gui.Enabled = false
		isMenuOpen = false
		currentIncID = nil
	end)

	-- ScrollingFrame pour la liste des recettes
	local recipeList = Instance.new("ScrollingFrame")
	recipeList.Name = "RecipeList"
	recipeList.Size = UDim2.new(1, -20, 1, -70)
	recipeList.Position = UDim2.new(0, 10, 0, 60)
	recipeList.BackgroundColor3 = Color3.fromRGB(30, 22, 15)
	recipeList.BorderSizePixel = 0
	recipeList.ScrollBarThickness = 8
	recipeList.Parent = mainFrame

	local listCorner = Instance.new("UICorner", recipeList)
	listCorner.CornerRadius = UDim.new(0, 8)

	-- Layout pour la liste
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = recipeList

	-- Ajuster la taille du canvas automatiquement
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		recipeList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	end)

	return gui
end

-- Crée l'overlay de production (affiché pendant la production)
local function createProductionOverlay()
	local overlay = Instance.new("Frame")
	overlay.Name = "ProductionOverlay"
	overlay.Size = UDim2.new(0, 400, 0, 350)
	overlay.Position = UDim2.new(1, -420, 0, 20)
	overlay.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = gui

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
	queueList.ScrollBarThickness = 6
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
		overlay.Visible = false
	end)

	local finishBtn = Instance.new("TextButton")
	finishBtn.Name = "FinishBtn"
	finishBtn.Size = UDim2.new(0.48, 0, 0, 40)
	finishBtn.Position = UDim2.new(0.52, 0, 1, -50)
	finishBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	finishBtn.Text = "⚡ FINISH (5 R$)"
	finishBtn.TextColor3 = Color3.new(0, 0, 0)
	finishBtn.Font = Enum.Font.GothamBold
	finishBtn.TextSize = 14
	finishBtn.Parent = overlay

	local finishCorner = Instance.new("UICorner", finishBtn)
	finishCorner.CornerRadius = UDim.new(0, 8)

	finishBtn.MouseButton1Click:Connect(function()
		print("⚡ Finish with Robux")
		finishNowRobuxEvt:FireServer(currentIncID)
	end)

	return overlay
end

-- Met à jour l'overlay de production
local function updateProductionOverlay(recipeName, candiesSpawned, candiesTotal)
	if not gui then return end
	
	local overlay = gui:FindFirstChild("ProductionOverlay")
	if not overlay then
		overlay = createProductionOverlay()
	end
	
	-- Afficher l'overlay
	overlay.Visible = true
	
	-- Mettre à jour les infos
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
	
	-- Mettre à jour la queue
	updateQueue()
	
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

openEvt.OnClientEvent:Connect(function(incubatorID)
	-- 🔧 NOUVEAU: Si le menu est déjà ouvert pour cet incubateur, le fermer
	if isMenuOpen and currentIncID == incubatorID then
		gui.Enabled = false
		isMenuOpen = false
		currentIncID = nil
		return
	end
	
	-- 🔧 Si le menu est ouvert pour un AUTRE incubateur, switcher
	if isMenuOpen and currentIncID ~= incubatorID then
	end
	
	if not gui then
		createGUI()
	end

	currentIncID = incubatorID
	isMenuOpen = true
	gui.Enabled = true

	-- Charger la liste des recettes
	loadRecipeList()
end)

-- Mise à jour de la progression
productionProgressEvt.OnClientEvent:Connect(function(incubatorID, progress, recipeName, candiesSpawned, candiesTotal)
	-- Si candiesTotal = 0, c'est un signal d'arrêt
	if candiesTotal == 0 then
		local bb = incubatorBillboards[incubatorID]
		if bb then
			bb.Enabled = false
		end
		
		-- Cacher l'overlay aussi
		if gui then
			local overlay = gui:FindFirstChild("ProductionOverlay")
			if overlay then
				overlay.Visible = false
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
			
			-- Mettre à jour le timer (temps restant estimé)
			if timer and recipeName and candiesSpawned and candiesTotal then
				local recipeDef = RecipeManager.Recettes[recipeName]
				if recipeDef and recipeDef.temps then
					local spawnInterval = recipeDef.temps / candiesTotal
					local remaining = (candiesTotal - candiesSpawned) * spawnInterval
					local minutes = math.floor(remaining / 60)
					local seconds = math.floor(remaining % 60)
					timer.Text = string.format("%02d:%02d", minutes, seconds)
				end
			end
			
			-- Cacher le billboard quand tout est terminé
			if candiesSpawned >= candiesTotal then
				task.wait(1)
				bb.Enabled = false
			end
		end
	end
	
	-- Mettre à jour l'overlay de production (si c'est notre incubateur)
	if incubatorID == currentIncID then
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

