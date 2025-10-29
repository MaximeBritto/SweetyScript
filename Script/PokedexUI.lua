-- PokedexUI.lua v3.0 - Interface Pokédex responsive
-- Interface Pokédex moderne style "simulateur" adaptée mobile
-- À placer dans ScreenGui

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- DÉTECTION PLATEFORME POUR INTERFACE RESPONSIVE
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Modules
local RecipeManager do
	local modInst = ReplicatedStorage:FindFirstChild("RecipeManager")
	if modInst and modInst:IsA("ModuleScript") then
		local ok, mod = pcall(require, modInst)
		if ok and type(mod) == "table" then
			RecipeManager = mod
		else
			RecipeManager = { Recettes = {}, Raretes = {} }
		end
	else
		RecipeManager = { Recettes = {}, Raretes = {} }
	end
end
local RECETTES = RecipeManager.Recettes
local RARETES = RecipeManager.Raretes
local UIUtils do
	local modInst = ReplicatedStorage:FindFirstChild("UIUtils")
	if modInst and modInst:IsA("ModuleScript") then
		local ok, mod = pcall(require, modInst)
		if ok and type(mod) == "table" then
			UIUtils = mod
		else
			UIUtils = nil
		end
	else
		UIUtils = nil
	end
end

-- Remote pour marquer un ingrédient comme découvert côté serveur (persistant session)
local pokedexDiscoverEvt = ReplicatedStorage:FindFirstChild("PokedexMarkIngredientDiscovered")
if not pokedexDiscoverEvt then
	pokedexDiscoverEvt = Instance.new("RemoteEvent")
	pokedexDiscoverEvt.Name = "PokedexMarkIngredientDiscovered"
	pokedexDiscoverEvt.Parent = ReplicatedStorage
end

-- Remote pour demander un achat Robux afin de valider une taille Pokédex
local requestPokedexSizeEvt = ReplicatedStorage:FindFirstChild("RequestPokedexSizePurchaseRobux")

-- Spinner (rotation) pour les ViewportFrames du Pokédex
local RunService = game:GetService("RunService")
local dexViewportSpinners = {}
local dexViewportAngles = {}
local function dexStopSpinner(viewport)
	local conn = dexViewportSpinners[viewport]
	if conn then conn:Disconnect(); dexViewportSpinners[viewport] = nil end
end
local function dexStartSpinner(viewport: ViewportFrame, rootInstance: Instance)
	local startAngle = dexViewportAngles[viewport] or 0
	dexStopSpinner(viewport)
	if not viewport or not rootInstance then return end
	local isModel = rootInstance:IsA("Model")
	local angle = startAngle
	local conn = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 1.2
		dexViewportAngles[viewport] = angle
		if isModel then
			for _, p in ipairs(rootInstance:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CFrame = p.CFrame * CFrame.Angles(0, dt * 1.2, 0)
				end
			end
		elseif rootInstance:IsA("BasePart") then
			rootInstance.CFrame = rootInstance.CFrame * CFrame.Angles(0, dt * 1.2, 0)
		end
	end)
	dexViewportSpinners[viewport] = conn
end

-- Variables
local pokedexFrame = nil
local isPokedexOpen = false
local currentFilter = nil -- Filtre par rareté (nil = TOUT)
local ingredientFilterName = nil -- Filtre par ingrédient (nil = aucun)
local ingredientFilterButton = nil
local lastIngredientAddedName = nil
local highlightIngredientName = nil
local pokedexButton = nil
local pokedexButtonNotifBadge = nil
local pokedexButtonStroke = nil

-- 🔔 Table pour tracker les notifications déjà affichées dans cette session (évite le spam)
local notifiedIngredientsThisSession = {}
local rareteButtons = {}
local rareteBadges = {}
-- Recettes mises en avant déjà consultées (pour masquer dynamiquement les badges)
local seenHighlightedRecipes = {}
-- Page courante ("Recettes" ou "Défis")
local _currentPokedexPage = "Recipes"
-- Sauvegarde du DisplayOrder de l'écran pour superposer le Pokédex au-dessus de la hotbar
local _oldScreenGuiDisplayOrder = nil
-- Référence de rafraîchissement des défis (exposée au watcher temps réel)
local _refreshChallengesPage = nil

-- Déclarations préalables
local fermerPokedex
local updatePokedexContent -- pré-déclaration pour usage anticipé
local normalizeRarete -- pré-déclaration pour usage anticipé
local recetteUsesIngredient -- pré-déclaration pour usage anticipé
-- Réinitialise l'état "vu" des recettes mises en avant
local function resetSeenHighlighted()
	for k in pairs(seenHighlightedRecipes) do
		seenHighlightedRecipes[k] = nil
	end
end


-- Utils: normaliser textes (pour comparer proprement)
local ACCENT_MAP = {
	["à"]="a", ["á"]="a", ["â"]="a", ["ä"]="a", ["ã"]="a", ["å"]="a",
	["ç"]="c",
	["è"]="e", ["é"]="e", ["ê"]="e", ["ë"]="e",
	["ì"]="i", ["í"]="i", ["î"]="i", ["ï"]="i",
	["ñ"]="n",
	["ò"]="o", ["ó"]="o", ["ô"]="o", ["ö"]="o", ["õ"]="o",
	["ù"]="u", ["ú"]="u", ["û"]="u", ["ü"]="u",
	["ý"]="y", ["ÿ"]="y"
}

local function normalizeText(s)
	if type(s) ~= "string" then return "" end
	s = s:lower()
	s = s:gsub("[àáâäãåçèéêëìíîïñòóôöõùúûüýÿ]", function(ch)
		return ACCENT_MAP[ch] or ch
	end)
	s = s:gsub("%s", "")
	s = s:gsub("_", "")
	return s
end

-- Normalisation avancée (synonymes/alias)
local function canonicalIngredientKey(name)
	return normalizeText(name or "")
end

-- Récupère l'ensemble des ingrédients possédés (BaseName des Tools non-candies)
local function getOwnedIngredientsSet()
	local owned = {}
	local function addTool(tool)
		if not tool:IsA("Tool") then return end
		local isCandy = tool:GetAttribute("IsCandy")
		if isCandy then return end
		local baseName = tool:GetAttribute("BaseName") or tool.Name
		if baseName and baseName ~= "" then
			owned[normalizeText(baseName)] = true
		end
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do addTool(child) end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do addTool(child) end
	end
	-- Fusionner avec les découvertes persistantes
	local playerData = player:FindFirstChild("PlayerData")
	local discovered = playerData and playerData:FindFirstChild("IngredientsDecouverts")
	if discovered then
		for _, flag in ipairs(discovered:GetChildren()) do
			if flag:IsA("BoolValue") and flag.Value == true then
				owned[normalizeText(flag.Name)] = true
			end
		end
	end
	return owned
end

-- Marquer un ingrédient comme découvert (persiste dans PlayerData)
local function markIngredientDiscovered(baseNameRaw)
	if not baseNameRaw or baseNameRaw == "" then return end
	-- Appel serveur idempotent
	pcall(function()
		pokedexDiscoverEvt:FireServer(baseNameRaw)
	end)
end

-- Trouver un nom d'affichage pour un ingrédient de recette (via RecipeManager.Ingredients.nom)
local function getDisplayNameForIngredientKey(ingKey)
	local target = normalizeText(ingKey)
	for k, data in pairs(RecipeManager.Ingredients or {}) do
		if normalizeText(k) == target then
			return data.nom or k
		end
	end
	-- fallback simple
	return ingKey
end

-- Résoudre un nom de Tool d'ingrédient à partir d'une clé de recette
local function resolveIngredientToolName(ingKey)
	local target = canonicalIngredientKey(ingKey)
	for k, _ in pairs(RecipeManager.Ingredients or {}) do
		if canonicalIngredientKey(k) == target then
			return k
		end
	end
	return nil
end

-- Crée une icône 3D d'ingrédient
local function createIngredientIcon(parent, ingKey, quantity, isKnown)
	local iconSize = (isMobile or isSmallScreen) and 26 or 30
	local icon = Instance.new("Frame")
	icon.Size = UDim2.new(0, iconSize, 0, iconSize)
	icon.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	icon.BorderSizePixel = 0
	icon.ZIndex = 950
	icon.Parent = parent

	local corner = Instance.new("UICorner", icon)
	corner.CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", icon)
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(87, 60, 34)

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -2, 1, -2)
	viewport.Position = UDim2.new(0, 1, 0, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 951
	viewport.Parent = icon

	if isKnown then
		local toolName = resolveIngredientToolName(ingKey)
		local folder = ReplicatedStorage:FindFirstChild("IngredientTools")
		local toolModel = folder and toolName and folder:FindFirstChild(toolName)
		local handle = toolModel and toolModel:FindFirstChild("Handle")
		if UIUtils and handle then
			UIUtils.setupViewportFrame(viewport, handle)
		else
			-- Fallback simple
			local l = Instance.new("TextLabel", viewport)
			l.Size = UDim2.new(1, 0, 1, 0)
			l.BackgroundTransparency = 1
			l.Text = (getDisplayNameForIngredientKey(ingKey):sub(1,2)):upper()
			l.TextColor3 = Color3.new(1,1,1)
			l.TextScaled = true
			l.Font = Enum.Font.GothamBold
			l.ZIndex = 952
		end
	else
		-- Inconnu: point d'interrogation
		local l = Instance.new("TextLabel", viewport)
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 0.15
		l.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		l.Text = "?"
		l.TextColor3 = Color3.new(1,1,1)
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.ZIndex = 952
		local c = Instance.new("UICorner", l)
		c.CornerRadius = UDim.new(0, 6)
	end

	-- Quantité (affichée à gauche de l'icône, sans rond)
	if tonumber(quantity) and quantity > 1 then
		local qty = Instance.new("TextLabel", icon)
		qty.Size = UDim2.new(0, 20, 0, 16)
		qty.Position = UDim2.new(0, -22, 0, 0)
		qty.BackgroundTransparency = 1
		qty.Text = "x" .. tostring(quantity)
		qty.TextColor3 = Color3.fromRGB(255, 255, 255)
		qty.TextSize = 12
		qty.TextScaled = false
		qty.Font = Enum.Font.GothamBold
		qty.ZIndex = 954
		qty.TextStrokeTransparency = 0.5
		qty.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	end

	return icon
end

-- Construire le texte partiel des ingrédients pour une recette non découverte
local function _buildMaskedIngredientsText(recetteData)
	local rawKnown = getOwnedIngredientsSet()
	local known = {}
	for k, v in pairs(rawKnown) do known[canonicalIngredientKey(k)] = v end
	local knownList, unknownCount = {}, 0
	for ingKey, _ in pairs(recetteData.ingredients or {}) do
		local norm = canonicalIngredientKey(ingKey)
		if known[norm] then
			table.insert(knownList, getDisplayNameForIngredientKey(ingKey))
		else
			unknownCount += 1
		end
	end
	table.sort(knownList)
	-- Couleurs lisibles
	local colorKnown = "#A9FF8A" -- vert clair
	local colorUnknown = "#BBBBBB" -- gris
	local parts = {}
	if #knownList > 0 then
		-- Concat connus avec style
		local knownStyled = {}
		for _, name in ipairs(knownList) do
			table.insert(knownStyled, string.format('<font color="%s"><b>%s</b></font>', colorKnown, name))
		end
		table.insert(parts, table.concat(knownStyled, " + "))
		if unknownCount > 0 then table.insert(parts, " ; ") end
	end
	for i = 1, unknownCount do
		local frag = string.format('<font color="%s">????</font>', colorUnknown)
		table.insert(parts, (i > 1) and (", " .. frag) or frag)
	end
	local text = (#parts > 0) and table.concat(parts, "") or string.format('<font color="%s">????</font>', colorUnknown)
	return text
end

-- Calculer les badges par rareté (nb de recettes non découvertes)
local function _computeUndiscoveredPerRarete()
	local res = {}
	local playerData = player:FindFirstChild("PlayerData")
	local recettesDecouvertes = playerData and playerData:FindFirstChild("RecettesDecouvertes")
	for nomRecette, donneesRecette in pairs(RECETTES) do
		local isDiscovered = recettesDecouvertes and recettesDecouvertes:FindFirstChild(nomRecette) ~= nil
		if not isDiscovered then
			local r = normalizeRarete(donneesRecette.rarete)
			res[r] = (res[r] or 0) + 1
		end
	end
	return res
end

local function updateFilterBadges()
	if not rareteButtons or not rareteButtons["ALL"] then return end

	-- Si aucun ingrédient récent n'est mis en avant, masquer tous les badges
	if not highlightIngredientName or highlightIngredientName == "" then
		local tb = rareteBadges["ALL"]
		if tb then tb.Visible = false end
		for rareteName, _ in pairs(rareteButtons) do
			if rareteName ~= "ALL" then
				local b = rareteBadges[rareteName]
				if b then b.Visible = false end
			end
		end
		return
	end

	-- Compter uniquement les recettes NON découvertes qui utilisent l'ingrédient mis en avant
	local counts = {}
	local total = 0
	local playerData = player:FindFirstChild("PlayerData")
	local recettesDecouvertes = playerData and playerData:FindFirstChild("RecettesDecouvertes")

	for nomRecette, donneesRecette in pairs(RECETTES) do
		local isDiscovered = recettesDecouvertes and recettesDecouvertes:FindFirstChild(nomRecette) ~= nil
		if not isDiscovered and recetteUsesIngredient(donneesRecette, highlightIngredientName) then
			-- Ne compter que les cartes non encore consultées (survolées)
			if not seenHighlightedRecipes[nomRecette] then
				local key = normalizeRarete(donneesRecette.rarete)
				counts[key] = (counts[key] or 0) + 1
				total += 1
			end
		end
	end

	-- Badge pour ALL
	do
		local btn = rareteButtons["ALL"]
		local badge = rareteBadges["ALL"]
		if not badge then
			badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(0, 16, 0, 16)
			badge.Position = UDim2.new(1, -6, 0, -6)
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			badge.BorderSizePixel = 0
			badge.Text = "!"
			badge.TextColor3 = Color3.new(1,1,1)
			badge.TextScaled = true
			badge.Font = Enum.Font.GothamBold
			badge.ZIndex = 1500
			badge.Parent = btn
			local c = Instance.new("UICorner", badge); c.CornerRadius = UDim.new(1, 0)
			rareteBadges["ALL"] = badge
		end
		badge.Visible = (total > 0)
	end

	-- Badges par rareté (affichés seulement si >=1 recette non découverte utilise l'ingrédient)
	for rareteName, btn in pairs(rareteButtons) do
		if rareteName ~= "ALL" then
			local key = normalizeRarete(rareteName)
			local count = counts[key] or 0
			local badge = rareteBadges[rareteName]
			if not badge then
				badge = Instance.new("TextLabel")
				badge.Size = UDim2.new(0, 16, 0, 16)
				badge.Position = UDim2.new(1, -6, 0, -6)
				badge.AnchorPoint = Vector2.new(1, 0)
				badge.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
				badge.BorderSizePixel = 0
				badge.Text = "!"
				badge.TextColor3 = Color3.new(1,1,1)
				badge.TextScaled = true
				badge.Font = Enum.Font.GothamBold
				badge.ZIndex = 1500
				badge.Parent = btn
				local c = Instance.new("UICorner", badge); c.CornerRadius = UDim.new(1, 0)
				rareteBadges[rareteName] = badge
			end
			badge.Visible = (count > 0)
		end
	end
end

normalizeRarete = function(r)
	local n = normalizeText(r or "")
	-- Normaliser vers les clés anglaises utilisées dans RecipeManager.Raretes
	if n == "commune" or n == "common" then return "Common" end
	if n == "rare" then return "Rare" end
	if n == "epique" or n == "epic" then return "Epic" end
	if n == "legendaire" or n == "legendary" then return "Legendary" end
	if n == "mythique" or n == "mythic" or n == "divin" or n == "divine" then return "Mythic" end
	return r
end

local function getRareteOrder(rarete)
	local key = normalizeRarete(rarete)
	if key and RecipeManager.Raretes[key] then
		return RecipeManager.Raretes[key].ordre
	end
	return 99
end

recetteUsesIngredient = function(recetteData, ingredientName)
	if not ingredientName or ingredientName == "" then return true end
	if not recetteData or not recetteData.ingredients then return false end
	local target = normalizeText(ingredientName)
	for ingName, _ in pairs(recetteData.ingredients) do
		if canonicalIngredientKey(ingName) == canonicalIngredientKey(target) then
			return true
		end
	end
	return false
end

-- Petite alerte visuelle (toast)
local function showPokedexToast(message)
	if not screenGui then return end
	local toast = Instance.new("TextLabel")
	toast.Name = "PokedexToast"
	toast.Size = UDim2.new(0.6, 0, 0, 36)
	toast.Position = UDim2.new(0.5, 0, 0.12, 0)
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	toast.BackgroundTransparency = 0.1
	toast.Text = message
	toast.TextColor3 = Color3.new(1,1,1)
	toast.TextSize = 18
	toast.Font = Enum.Font.GothamBold
	toast.TextWrapped = true
	toast.ZIndex = 10000  -- ✅ Z-Index très élevé pour passer devant TOUT (même la boutique)
	toast.Parent = screenGui
	local corner = Instance.new("UICorner", toast); corner.CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", toast); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(255, 215, 0)

	toast.TextTransparency = 1
	toast.BackgroundTransparency = 1
	local tweenIn = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0, BackgroundTransparency = 0.1})
	tweenIn:Play()
	task.delay(1.8, function()
		local tweenOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1, BackgroundTransparency = 1})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			if toast then toast:Destroy() end
		end)
	end)
end

local function showPokedexNotificationForIngredient(ingredientName)
	-- Nouveau focus d'ingrédient: on repart de zéro sur ce qui a été vu
	resetSeenHighlighted()
	highlightIngredientName = ingredientName
	-- Badge d'exclamation sur le bouton Pokédex
	if pokedexButton then
		if not pokedexButtonNotifBadge then
			pokedexButtonNotifBadge = Instance.new("TextLabel")
			pokedexButtonNotifBadge.Name = "NotifBadge"
			pokedexButtonNotifBadge.Size = UDim2.new(0, 18, 0, 18)
			pokedexButtonNotifBadge.Position = UDim2.new(1, -6, 0, -6)
			pokedexButtonNotifBadge.AnchorPoint = Vector2.new(1, 0)
			pokedexButtonNotifBadge.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			pokedexButtonNotifBadge.BorderSizePixel = 0
			pokedexButtonNotifBadge.Text = "!"
			pokedexButtonNotifBadge.TextColor3 = Color3.new(1,1,1)
			pokedexButtonNotifBadge.TextScaled = true
			pokedexButtonNotifBadge.Font = Enum.Font.GothamBold
			pokedexButtonNotifBadge.ZIndex = 10000  -- ✅ Z-Index très élevé pour passer devant TOUT
			pokedexButtonNotifBadge.Parent = pokedexButton
			local c = Instance.new("UICorner", pokedexButtonNotifBadge); c.CornerRadius = UDim.new(1, 0)
			-- Highlight: contour et glow
			local badgeStroke = Instance.new("UIStroke", pokedexButtonNotifBadge)
			badgeStroke.Color = Color3.fromRGB(255, 215, 0)
			badgeStroke.Thickness = 2
			pokedexButtonNotifBadge.TextStrokeColor3 = Color3.new(0,0,0)
			pokedexButtonNotifBadge.TextStrokeTransparency = 0.2

			-- Glow doux derrière le badge (non interactif)
			if pokedexButton then
				local glow = pokedexButton:FindFirstChild("NotifGlow")
				if not glow then
					glow = Instance.new("Frame")
					glow.Name = "NotifGlow"
					glow.Size = UDim2.new(0, 26, 0, 26)
					glow.Position = UDim2.new(1, -9, 0, -9)
					glow.AnchorPoint = Vector2.new(1, 0)
					glow.BackgroundColor3 = Color3.fromRGB(255, 230, 120)
					glow.BackgroundTransparency = 0.5
					glow.BorderSizePixel = 0
					glow.ZIndex = 9999  -- ✅ Juste en-dessous du badge pour passer devant tout
					glow.Parent = pokedexButton
					local gc = Instance.new("UICorner", glow); gc.CornerRadius = UDim.new(1, 0)
				end
			end
		end
		pokedexButtonNotifBadge.Visible = true

		if not pokedexButtonStroke then
			pokedexButtonStroke = Instance.new("UIStroke", pokedexButton)
			pokedexButtonStroke.Color = Color3.fromRGB(255, 215, 0)
			pokedexButtonStroke.Thickness = 3
		end
		pokedexButtonStroke.Enabled = true
		local t1 = TweenService:Create(pokedexButtonStroke, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 3, true), {Thickness = 6})
		t1:Play()

		-- Animation de pulsation du badge (grossir/rétrécir) + mise en avant
		if pokedexButtonNotifBadge and not pokedexButtonNotifBadge:GetAttribute("PulseStarted") then
			pokedexButtonNotifBadge:SetAttribute("PulseStarted", true)
			local sizePulse = TweenService:Create(
				pokedexButtonNotifBadge,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Size = UDim2.new(0, 22, 0, 22) }
			)
			sizePulse:Play()
			local stroke = pokedexButtonNotifBadge:FindFirstChildOfClass("UIStroke")
			if stroke then
				local strokePulse = TweenService:Create(
					stroke,
					TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Thickness = 4 }
				)
				strokePulse:Play()
			end
			local glow = pokedexButton and pokedexButton:FindFirstChild("NotifGlow")
			if glow then
				local glowPulse = TweenService:Create(
					glow,
					TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ BackgroundTransparency = 0.2 }
				)
				glowPulse:Play()
			end
		end
	end

	-- Toast
	showPokedexToast("NEW ingredient: " .. tostring(ingredientName) .. " • Open the CandyDex !")
end

-- Détecter la possession d'ingrédients (Backpack/Character), pour réagir aux achats
local function setupIngredientWatchers()
	local backpack = player:WaitForChild("Backpack")
	
	-- 🔑 PRÉ-REMPLIR la table avec tous les ingrédients déjà découverts (au chargement)
	local playerData = player:FindFirstChild("PlayerData")
	local discovered = playerData and playerData:FindFirstChild("IngredientsDecouverts")
	if discovered then
		for _, flag in ipairs(discovered:GetChildren()) do
			if flag:IsA("BoolValue") and flag.Value == true then
				local ingredientKey = canonicalIngredientKey(flag.Name)
				notifiedIngredientsThisSession[ingredientKey] = true
				print("🔄 [POKEDEX] Pré-rempli:", flag.Name, "→", ingredientKey)
			end
		end
		print("✅ [POKEDEX] Table de notifications pré-remplie avec les ingrédients déjà découverts")
	end
	
	local isScanningInitialBackpack = true
	local function onToolAdded(tool)
		if not tool:IsA("Tool") then return end
		local isCandy = tool:GetAttribute("IsCandy")
		if isCandy then return end
		local baseNameRaw = tool:GetAttribute("BaseName") or tool.Name
		local baseName = canonicalIngredientKey(baseNameRaw)
		-- Ignorer le scan initial pour ne pas déclencher des badges/notifications à l'ouverture
		if isScanningInitialBackpack then return end
		
		-- 🔔 Vérifier UNIQUEMENT la table locale (déjà pré-remplie au chargement)
		local alreadyNotified = notifiedIngredientsThisSession[baseName] == true
		
		lastIngredientAddedName = baseName
		-- Marquer persistantement l'ingrédient comme découvert (appel serveur)
		markIngredientDiscovered(baseNameRaw)
		
		-- ✅ Afficher la notification UNIQUEMENT si PAS encore dans la table
		if not alreadyNotified then
			print("🎉 [CandyDex] NEW ingredient discovered:", baseNameRaw, "- affichage de la notification")
			-- Marquer comme notifié dans cette session
			notifiedIngredientsThisSession[baseName] = true
			
			-- Afficher notif + badge + surlignage des recettes liées
			if ingredientFilterButton then
				ingredientFilterButton.Visible = true
				ingredientFilterButton.Text = "ING: " .. (RecipeManager.Ingredients[baseNameRaw] and RecipeManager.Ingredients[baseNameRaw].nom or baseNameRaw) .. " ✕"
			end
			showPokedexNotificationForIngredient(baseName)
		else
			print("🔇 [CandyDex] Already Known ingredient:", baseNameRaw, "- notification ignorée")
		end
		
		if isPokedexOpen then
			updatePokedexContent()
		end
		updateFilterBadges()
	end
	backpack.ChildAdded:Connect(onToolAdded)
	-- Scanner les tools existants au démarrage pour remplir la table 'known'
	for _, t in ipairs(backpack:GetChildren()) do onToolAdded(t) end
	isScanningInitialBackpack = false
end

-- Crée une carte de recette moderne (responsive)
local function createRecipeCard(parent, recetteNom, recetteData, estDecouverte, shouldHighlight)
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "Card_" .. recetteNom
	-- Taille responsive : plus petite sur mobile
	local cardHeight = (isMobile or isSmallScreen) and 84 or 140
	cardFrame.Size = UDim2.new(1, 0, 0, cardHeight)
	cardFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron clair
	cardFrame.BorderSizePixel = 0

	local corner = Instance.new("UICorner", cardFrame)
	corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 10)

	local stroke = Instance.new("UIStroke", cardFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34) -- Marron foncé
	stroke.Thickness = (isMobile or isSmallScreen) and 2 or 4

	if shouldHighlight then
		-- Contour de mise en avant (jaune) avec pulsation légère
		local hi = Instance.new("UIStroke", cardFrame)
		hi.Color = Color3.fromRGB(255, 215, 0)
		hi.Thickness = 3
		hi.Transparency = 0.15
		local tween = TweenService:Create(hi, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Thickness = 6})
		tween:Play()
		-- Badge d'exclamation
		local ex = Instance.new("TextLabel")
		ex.Size = UDim2.new(0, 18, 0, 18)
		ex.Position = UDim2.new(0, 6, 0, 6)
		ex.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
		ex.BorderSizePixel = 0
		ex.Text = "!"
		ex.TextColor3 = Color3.new(1,1,1)
		ex.TextScaled = true
		ex.Font = Enum.Font.GothamBold
		ex.ZIndex = 2000
		ex.Parent = cardFrame
		local exCorner = Instance.new("UICorner", ex); exCorner.CornerRadius = UDim.new(1, 0)
		-- Si déjà consultée précédemment, ne pas ré-afficher le badge
		if seenHighlightedRecipes[recetteNom] then
			ex.Visible = false
			local oldGlow = cardFrame:FindFirstChild("ExGlow")
			if oldGlow then oldGlow.Visible = false end
		end

		-- Disparaît au survol et boost la rotation; revient à vitesse normale au leave
		cardFrame.MouseEnter:Connect(function()
			-- Marquer comme consultée et rafraîchir les badges de catégories
			seenHighlightedRecipes[recetteNom] = true
			ex.Visible = false
			local g = cardFrame:FindFirstChild("ExGlow")
			if g then g.Visible = false end
			updateFilterBadges()
			local vp = cardFrame:FindFirstChildOfClass("ViewportFrame")
			if vp then
				local root = nil
				for _, c in ipairs(vp:GetChildren()) do
					if c:IsA("Model") or c:IsA("BasePart") then root = c; break end
				end
				if root then
					dexStopSpinner(vp)
					local conn = RunService.RenderStepped:Connect(function(dt)
						if root:IsA("Model") then
							for _, p in ipairs(root:GetDescendants()) do
								if p:IsA("BasePart") then
									p.CFrame = p.CFrame * CFrame.Angles(0, dt * 2.0, 0)
								end
							end
						elseif root:IsA("BasePart") then
							root.CFrame = root.CFrame * CFrame.Angles(0, dt * 2.0, 0)
						end
					end)
					dexViewportSpinners[vp] = conn
				end
			end
		end)
		cardFrame.MouseLeave:Connect(function()
			local vp = cardFrame:FindFirstChildOfClass("ViewportFrame")
			if vp then
				local root = nil
				for _, c in ipairs(vp:GetChildren()) do
					if c:IsA("Model") or c:IsA("BasePart") then root = c; break end
				end
				if root then
					dexStartSpinner(vp, root)
				end
			end
		end)
	end

	-- ViewportFrame pour le modèle 3D (responsive)
	local viewport = Instance.new("ViewportFrame")
	local vpSize = (isMobile or isSmallScreen) and 90 or 130
	local viewportMargin = (isMobile or isSmallScreen) and 8 or 10
	viewport.Size = UDim2.new(0, vpSize, 0, vpSize)
	if isMobile or isSmallScreen then
		-- Mobile: à gauche, centré verticalement
		viewport.Position = UDim2.new(0, viewportMargin, 0.5, -vpSize/2)
	else
		-- Desktop: centré verticalement
		viewport.Position = UDim2.new(0, viewportMargin, 0.5, -vpSize/2)
	end
	viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	viewport.BorderSizePixel = 0
	viewport.Parent = cardFrame

	local vpCorner = Instance.new("UICorner", viewport)
	vpCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)
	local vpStroke = Instance.new("UIStroke", viewport)
	vpStroke.Color = Color3.fromRGB(87, 60, 34)
	vpStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
	vpStroke.ZIndex = 900

	if estDecouverte then
		-- Modèle 3D découvert
		local candyModelsFolder = ReplicatedStorage:FindFirstChild("CandyModels")
		if candyModelsFolder then
			local candyModel = candyModelsFolder:FindFirstChild(recetteData.modele)
			if candyModel then
				local clone = candyModel:Clone()
				UIUtils.setupViewportFrame(viewport, clone)
				-- Trouver le modèle réel dans le viewport après setupViewportFrame
				task.wait()
				local modelInViewport = nil
				for _, child in ipairs(viewport:GetChildren()) do
					if child:IsA("Model") or child:IsA("BasePart") then
						modelInViewport = child
						break
					end
				end
				if modelInViewport then
					dexStartSpinner(viewport, modelInViewport)
				end
			else
				-- Fallback emoji
				local emojiLabel = Instance.new("TextLabel", viewport)
				emojiLabel.Size = UDim2.new(1, 0, 1, 0)
				emojiLabel.BackgroundTransparency = 1
				emojiLabel.Text = recetteData.emoji
				emojiLabel.TextScaled = true
				emojiLabel.Font = Enum.Font.GothamBold
			end
		end
	else
		-- Mystère
		local mysteryLabel = Instance.new("TextLabel", viewport)
		mysteryLabel.Size = UDim2.new(1, 0, 1, 0)
		mysteryLabel.BackgroundTransparency = 1
		mysteryLabel.Text = "🔒\n???"
		mysteryLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		mysteryLabel.TextSize = 32
		mysteryLabel.Font = Enum.Font.GothamBold
	end

	-- Nom du modèle supprimé (déjà affiché dans la carte)

	-- Nom de la recette (responsive)
	local nomLabel = Instance.new("TextLabel")
	local labelHeight = (isMobile or isSmallScreen) and 20 or 35
	local rightOfViewportX = viewportMargin + vpSize + ((isMobile or isSmallScreen) and 20 or 18)
	local labelLeft = rightOfViewportX
	local ingRowHeight = (isMobile or isSmallScreen) and 26 or 40
	local ingRowTopY = (isMobile or isSmallScreen) and 6 or 80
	local nameY = (isMobile or isSmallScreen) and 0 or 10
	nomLabel.Size = UDim2.new(0, 180, 0, labelHeight)
	nomLabel.Position = UDim2.new(0, labelLeft, 0, nameY)
	nomLabel.BackgroundTransparency = 1
	-- Utiliser le champ 'nom' du RecipeManager si disponible
	local displayName = estDecouverte and (recetteData.nom or recetteNom) or "????"
	nomLabel.Text = displayName
	nomLabel.TextColor3 = Color3.new(1, 1, 1)
	nomLabel.TextSize = (isMobile or isSmallScreen) and 15 or 24
	nomLabel.Font = Enum.Font.GothamBold
	nomLabel.TextXAlignment = Enum.TextXAlignment.Left
	nomLabel.TextScaled = false
	nomLabel.ZIndex = 900
	nomLabel.Parent = cardFrame

	-- Badge de rareté (taille réduite pour mobile)
	local rareteLabel = Instance.new("TextLabel")
	local badgeWidth = (isMobile or isSmallScreen) and 100 or 130
	local badgeHeight = (isMobile or isSmallScreen) and 24 or 32
	rareteLabel.Size = UDim2.new(0, badgeWidth, 0, badgeHeight)
	rareteLabel.Position = UDim2.new(1, -(badgeWidth + 10), 0, (isMobile or isSmallScreen) and 2 or 10)
	rareteLabel.BackgroundColor3 = recetteData.couleurRarete
	rareteLabel.Text = recetteData.rarete
	rareteLabel.TextColor3 = Color3.new(1, 1, 1)
	rareteLabel.TextSize = (isMobile or isSmallScreen) and 13 or 18
	rareteLabel.TextScaled = false
	rareteLabel.Font = Enum.Font.GothamBold
	rareteLabel.Parent = cardFrame
	local rCorner = Instance.new("UICorner", rareteLabel)
	rCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)
	local rStroke = Instance.new("UIStroke", rareteLabel)
	rStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
	rStroke.Color = Color3.fromHSV(0, 0, 0.2)

	-- Description (cachée sur mobile, accessible via bouton ?)
	if not (isMobile or isSmallScreen) then
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.6, 0, 0, 25)
		descLabel.Position = UDim2.new(0, rightOfViewportX, 0, 50)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = estDecouverte and recetteData.description or ""
		descLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		descLabel.TextSize = 16
		descLabel.Font = Enum.Font.SourceSans
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Parent = cardFrame
	else
		-- Bouton "?" discret pour la description (à côté du nom)
		if estDecouverte and recetteData.description and recetteData.description ~= "" then
			local infoBtn = Instance.new("TextButton")
			infoBtn.Size = UDim2.new(0, 18, 0, 18)
			infoBtn.Position = UDim2.new(0, labelLeft + 165, 0, nameY + 1)
			infoBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
			infoBtn.BackgroundTransparency = 0.3
			infoBtn.Text = "?"
			infoBtn.TextColor3 = Color3.new(1, 1, 1)
			infoBtn.TextSize = 12
			infoBtn.Font = Enum.Font.GothamBold
			infoBtn.ZIndex = 901
			infoBtn.Parent = cardFrame
			local btnCorner = Instance.new("UICorner", infoBtn)
			btnCorner.CornerRadius = UDim.new(1, 0)
			
			-- Tooltip sur PC (survol)
			local tooltip = nil
			infoBtn.MouseEnter:Connect(function()
				if not (isMobile or isSmallScreen) then
					tooltip = Instance.new("Frame", cardFrame)
					tooltip.Size = UDim2.new(0, 250, 0, 60)
					tooltip.Position = UDim2.new(0, labelLeft + 165, 0, nameY + 22)
					tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					tooltip.ZIndex = 1000
					local ttCorner = Instance.new("UICorner", tooltip)
					ttCorner.CornerRadius = UDim.new(0, 6)
					local ttStroke = Instance.new("UIStroke", tooltip)
					ttStroke.Color = Color3.fromRGB(100, 150, 200)
					ttStroke.Thickness = 1
					
					local ttText = Instance.new("TextLabel", tooltip)
					ttText.Size = UDim2.new(1, -12, 1, -12)
					ttText.Position = UDim2.new(0, 6, 0, 6)
					ttText.BackgroundTransparency = 1
					ttText.Text = recetteData.description
					ttText.TextColor3 = Color3.new(1, 1, 1)
					ttText.TextSize = 12
					ttText.Font = Enum.Font.Gotham
					ttText.TextWrapped = true
					ttText.ZIndex = 1001
				end
			end)
			
			infoBtn.MouseLeave:Connect(function()
				if tooltip then
					tooltip:Destroy()
					tooltip = nil
				end
			end)
			
			-- Clic sur mobile
			infoBtn.MouseButton1Click:Connect(function()
				if isMobile or isSmallScreen then
					local popup = Instance.new("Frame", cardFrame)
					popup.Size = UDim2.new(0.9, 0, 0, 70)
					popup.Position = UDim2.new(0.05, 0, 0.5, -35)
					popup.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					popup.ZIndex = 1000
					local popCorner = Instance.new("UICorner", popup)
					popCorner.CornerRadius = UDim.new(0, 8)
					local popStroke = Instance.new("UIStroke", popup)
					popStroke.Color = Color3.fromRGB(100, 150, 200)
					popStroke.Thickness = 2
					
					local descText = Instance.new("TextLabel", popup)
					descText.Size = UDim2.new(1, -16, 1, -16)
					descText.Position = UDim2.new(0, 8, 0, 8)
					descText.BackgroundTransparency = 1
					descText.Text = recetteData.description
					descText.TextColor3 = Color3.new(1, 1, 1)
					descText.TextSize = 13
					descText.Font = Enum.Font.Gotham
					descText.TextWrapped = true
					descText.ZIndex = 1001
					
					-- Fermer au clic
					task.delay(0.1, function()
						popup.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								popup:Destroy()
							end
						end)
					end)
				end
			end)
		end
	end

	-- Ingrédients (affichés seulement si découverts)
	-- Layout différent selon mobile/desktop
	local ingRow = Instance.new("Frame")
	if isMobile or isSmallScreen then
		-- Mobile: Grille 2x2 en dessous du titre, à droite du modèle
		ingRow.Size = UDim2.new(0, 320, 0, 70) -- Grille 2x2 compacte (élargie pour maximum d'espacement)
		ingRow.Position = UDim2.new(0, rightOfViewportX, 0, nameY + labelHeight - 4)
	else
		-- Desktop: Horizontal
		ingRow.Size = UDim2.new(0.62, 0, 0, ingRowHeight)
		ingRow.Position = UDim2.new(0, rightOfViewportX, 0, ingRowTopY)
	end
	ingRow.BackgroundTransparency = 1
	ingRow.ZIndex = 900
	ingRow.Parent = cardFrame
	
	local ingLayout
	if isMobile or isSmallScreen then
		-- Grille 2x2 sur mobile (2 colonnes, compact)
		ingLayout = Instance.new("UIGridLayout", ingRow)
		ingLayout.CellSize = UDim2.new(0, 110, 0, 32)
		ingLayout.CellPadding = UDim2.new(0, 55, 0, 1)
		ingLayout.FillDirection = Enum.FillDirection.Horizontal
		ingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		ingLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		ingLayout.SortOrder = Enum.SortOrder.LayoutOrder
	else
		-- Liste horizontale sur desktop
		ingLayout = Instance.new("UIListLayout", ingRow)
		ingLayout.FillDirection = Enum.FillDirection.Horizontal
		ingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		ingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ingLayout.Padding = UDim.new(0, 12)
	end

	-- Construire l’ordre stable: connus puis inconnus
	local rawKnown = getOwnedIngredientsSet()
	local knownSet = {}
	for k, v in pairs(rawKnown) do knownSet[canonicalIngredientKey(k)] = v end

	local knownItems, unknownItems = {}, {}
	for ingKey, qty in pairs(recetteData.ingredients or {}) do
		local isKnown = knownSet[canonicalIngredientKey(ingKey)] == true or estDecouverte
		if isKnown then
			table.insert(knownItems, {k = ingKey, q = qty})
		else
			table.insert(unknownItems, {k = ingKey, q = qty})
		end
	end
	table.sort(knownItems, function(a,b) return a.k < b.k end)
	table.sort(unknownItems, function(a,b) return a.k < b.k end)

	local function addIngredientCell(ingKey, qty, isKnown)
		local cell = Instance.new("Frame")
		if not (isMobile or isSmallScreen) then
			-- Desktop: taille fixe
			cell.Size = UDim2.new(0, 150, 0, 40)
		else
			-- Mobile: la grille gère la taille
			cell.Size = UDim2.new(1, 0, 1, 0)
		end
		cell.BackgroundTransparency = 1
		cell.ZIndex = 900
		cell.Parent = ingRow

		local icon = createIngredientIcon(cell, ingKey, qty, isKnown)
		icon.Size = UDim2.new(0, (isMobile or isSmallScreen) and 22 or icon.Size.X.Offset, 0, (isMobile or isSmallScreen) and 22 or icon.Size.Y.Offset)
		icon.Position = UDim2.new(0, 0, 0.5, -((isMobile or isSmallScreen) and 11 or icon.Size.Y.Offset/2)) -- Recentré
		icon.AnchorPoint = Vector2.new(0, 0)

		local nameLabel = Instance.new("TextLabel", cell)
		nameLabel.Size = UDim2.new(1, - ((isMobile or isSmallScreen) and (22 + 6) or (icon.Size.X.Offset + 8)), 1, 0)
		nameLabel.Position = UDim2.new(0, (isMobile or isSmallScreen) and (22 + 6) or (icon.Size.X.Offset + 8), 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = not (isMobile or isSmallScreen)
		nameLabel.TextSize = (isMobile or isSmallScreen) and 12 or nameLabel.TextSize
		if isKnown then
			nameLabel.Text = getDisplayNameForIngredientKey(ingKey)
			nameLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
		else
			nameLabel.Text = "????"
			nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
		nameLabel.ZIndex = 901
	end

	for _, it in ipairs(knownItems) do
		addIngredientCell(it.k, it.q, true)
	end
	for _, it in ipairs(unknownItems) do
		addIngredientCell(it.k, it.q, false)
	end

	-- Stats (valeur et temps) visibles uniquement si découverts
	-- Positionnés sous le badge de rareté
	if estDecouverte then
		local statsFrame = Instance.new("Frame")
		local statsWidth = (isMobile or isSmallScreen) and 110 or 140
		local statsHeight = (isMobile or isSmallScreen) and 20 or 28
		local statsTop = (isMobile or isSmallScreen) and 30 or 48
		statsFrame.Size = UDim2.new(0, statsWidth, 0, statsHeight)
		statsFrame.Position = UDim2.new(1, -(statsWidth + 10), 0, statsTop) -- Sous le badge de rareté
		statsFrame.BackgroundTransparency = 1
		statsFrame.Parent = cardFrame
		local layout = Instance.new("UIListLayout", statsFrame)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 4 or 8)
		local valeurLabel = Instance.new("TextLabel")
		valeurLabel.Size = UDim2.new(0, (isMobile or isSmallScreen) and 65 or 90, 1, 0)
		valeurLabel.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
		-- Formater la valeur avec UIUtils
		local formattedValue = UIUtils and UIUtils.formatMoneyShort and UIUtils.formatMoneyShort(recetteData.valeur) or tostring(recetteData.valeur)
		valeurLabel.Text = formattedValue .. "$"
		valeurLabel.TextColor3 = Color3.new(1, 1, 1)
		valeurLabel.TextSize = (isMobile or isSmallScreen) and 11 or 14
		valeurLabel.Font = Enum.Font.GothamBold
		valeurLabel.Parent = statsFrame
		local vCorner = Instance.new("UICorner", valeurLabel); vCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 4 or 6)
		local tempsLabel = Instance.new("TextLabel")
		tempsLabel.Size = UDim2.new(0, (isMobile or isSmallScreen) and 45 or 70, 1, 0)
		tempsLabel.BackgroundColor3 = Color3.fromRGB(65, 130, 200)
		tempsLabel.Text = recetteData.temps .. "s"
		tempsLabel.TextColor3 = Color3.new(1, 1, 1)
		tempsLabel.TextSize = (isMobile or isSmallScreen) and 11 or 14
		tempsLabel.Font = Enum.Font.GothamBold
		tempsLabel.Parent = statsFrame
		local tCorner = Instance.new("UICorner", tempsLabel); tCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 4 or 6)
	end

	return cardFrame
end

-- Met à jour le contenu du Pokédex
updatePokedexContent = function()
	if not pokedexFrame then return end

	local pageRecettes = pokedexFrame:FindFirstChild("PageRecettes")
	local scrollFrame = pageRecettes and pageRecettes:FindFirstChild("ScrollFrame")
	if not scrollFrame then return end

	-- Nettoyer
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^Card_") then
			child:Destroy()
		end
	end

	-- Données du joueur
	local playerData = player:WaitForChild("PlayerData")
	local recettesDecouvertes = playerData:WaitForChild("RecettesDecouvertes")
	local ingredientsDecouverts = playerData:FindFirstChild("IngredientsDecouverts")

	local recettesListe = {}

	-- Collecter et filtrer
	for nomRecette, donneesRecette in pairs(RECETTES) do
		local passR = true
		if currentFilter then
			passR = (normalizeRarete(donneesRecette.rarete) == normalizeRarete(currentFilter))
		end
		local passI = true
		if ingredientFilterName and ingredientFilterName ~= "" then
			-- Afficher si la recette utilise l'ingrédient filtré OU si la recette contient un ingrédient déjà découvert
			local uses = recetteUsesIngredient(donneesRecette, ingredientFilterName)
			local already = false
			if ingredientsDecouverts then
				for ingKey, _ in pairs(donneesRecette.ingredients or {}) do
					local toolName = resolveIngredientToolName(ingKey)
					if toolName and ingredientsDecouverts:FindFirstChild(toolName) then
						already = true
						break
					end
				end
			end
			passI = uses or already
		end
		if passR and passI then
			table.insert(recettesListe, {nom = nomRecette, donnees = donneesRecette})
		end
	end

	-- Trier par rareté puis par ordre personnalisé (si défini) puis par nom
	table.sort(recettesListe, function(a, b)
		local ordreA = getRareteOrder(a.donnees.rarete)
		local ordreB = getRareteOrder(b.donnees.rarete)
		
		-- Trier par rareté d'abord
		if ordreA ~= ordreB then
			return ordreA < ordreB
		end
		
		-- Si même rareté, utiliser l'ordre personnalisé (si défini dans la recette)
		local customOrderA = a.donnees.ordre or 999
		local customOrderB = b.donnees.ordre or 999
		
		if customOrderA ~= customOrderB then
			return customOrderA < customOrderB
		end
		
		-- Tri final par nom si même rareté et même ordre
		return a.nom < b.nom
	end)

	-- Créer les cartes
	for i, recetteInfo in ipairs(recettesListe) do
		local estDecouverte = recettesDecouvertes:FindFirstChild(recetteInfo.nom) ~= nil
		local shouldHighlight = false
		if highlightIngredientName and highlightIngredientName ~= "" then
			-- Harmoniser avec les badges de catégories: ne surligner que les recettes non découvertes
			shouldHighlight = (not estDecouverte) and recetteUsesIngredient(recetteInfo.donnees, highlightIngredientName)
		end
		local card = createRecipeCard(scrollFrame, recetteInfo.nom, recetteInfo.donnees, estDecouverte, shouldHighlight)
		card.LayoutOrder = i
		card.Parent = scrollFrame
	end
end

-- Crée l'interface principale du Pokédx (responsive)
local function createPokedexInterface()
	if pokedexFrame then fermerPokedex() end

	isPokedexOpen = true
	pokedexFrame = Instance.new("Frame")
	pokedexFrame.Name = "PokedexFrame"
	-- Taille fixe de base (sera scalée automatiquement)
	pokedexFrame.Size = UDim2.new(0, 1000, 0, 700)
	pokedexFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	pokedexFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	pokedexFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	pokedexFrame.BorderSizePixel = 0
	pokedexFrame.Parent = screenGui
	
	-- UIScale pour adapter automatiquement à la taille de l'écran
	local pokedexUIScale = Instance.new("UIScale")
	pokedexUIScale.Parent = pokedexFrame
	
	-- UISizeConstraint pour limiter la taille min/max
	local pokedexSizeConstraint = Instance.new("UISizeConstraint")
	pokedexSizeConstraint.MinSize = Vector2.new(400, 300)
	pokedexSizeConstraint.MaxSize = Vector2.new(1400, 1000)
	pokedexSizeConstraint.Parent = pokedexFrame
	
	-- Fonction pour ajuster le scale selon la taille de l'écran
	local function updatePokedexScale()
		local viewportSize = workspace.CurrentCamera.ViewportSize
		local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local isPortrait = viewportSize.Y > viewportSize.X
		
		local scale
		
		-- Ajustements spécifiques pour mobile/tablette
		if isMobileDevice then
			if isPortrait then
				-- Téléphone en mode portrait : utiliser 99% de la largeur
				-- Diviser par 550 pour agrandir de 82%
				scale = (viewportSize.X * 0.99) / 550
				-- Vérifier que ça ne dépasse pas en hauteur (max 95%)
				local maxHeightScale = (viewportSize.Y * 0.95) / 400
				if scale > maxHeightScale then
					scale = maxHeightScale
				end
			else
				-- Téléphone/tablette en mode paysage : utiliser 98% de la largeur
				-- Diviser par 550 pour agrandir de 82%
				scale = (viewportSize.X * 0.98) / 550
				-- Vérifier que ça ne dépasse pas en hauteur (max 98%)
				local maxHeightScale = (viewportSize.Y * 0.98) / 400
				if scale > maxHeightScale then
					scale = maxHeightScale
				end
			end
		else
			-- Desktop : calcul normal mais avec max plus élevé
			local scaleX = viewportSize.X / 1920
			local scaleY = viewportSize.Y / 1080
			scale = math.min(scaleX, scaleY, 1.5) -- Max 150% pour desktop
		end
		
		-- Limites finales
		scale = math.max(scale, 1.0) -- Min 100%
		scale = math.min(scale, 4.0) -- Max 400% pour très petits écrans mobiles
		
		pokedexUIScale.Scale = scale
	end
	
	-- Mettre à jour au démarrage
	updatePokedexScale()
	
	-- Mettre à jour quand la taille de l'écran change
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePokedexScale)

	local corner = Instance.new("UICorner", pokedexFrame)
	corner.CornerRadius = UDim.new(0, 15)
	local stroke = Instance.new("UIStroke", pokedexFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = 6

	-- À chaque ouverture, repartir sur des références propres pour les boutons et badges
	rareteButtons = {}
	rareteBadges = {}

	-- Header (taille réduite pour mobile)
	local header = Instance.new("Frame")
	local headerHeight = 55 -- Réduit de 70 à 55
	header.Size = UDim2.new(1, 0, 0, headerHeight)
	header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	header.BorderSizePixel = 0
	header.Parent = pokedexFrame
	local hCorner = Instance.new("UICorner", header)
	hCorner.CornerRadius = UDim.new(0, 10)
	local hStroke = Instance.new("UIStroke", header)
	hStroke.Thickness = 4
	hStroke.Color = Color3.fromRGB(66, 103, 38)

	local titre = Instance.new("TextLabel", header)
	titre.Size = UDim2.new(0.7, 0, 1, 0)
	titre.Position = UDim2.new(0.05, 0, 0, 0)
	titre.BackgroundTransparency = 1
	titre.Text = "📚 CandyDex"
	titre.TextColor3 = Color3.new(1, 1, 1)
	titre.TextSize = 28
	titre.Font = Enum.Font.GothamBold
	titre.TextXAlignment = Enum.TextXAlignment.Left
	titre.TextScaled = false

	local boutonFermer = Instance.new("TextButton", header)
	local closeSize = (isMobile or isSmallScreen) and 28 or 50
	boutonFermer.Size = UDim2.new(0, closeSize, 0, closeSize)
	boutonFermer.Position = UDim2.new(1, -(closeSize + 5), 0.5, -closeSize/2)
	boutonFermer.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	boutonFermer.Text = "X"
	boutonFermer.TextColor3 = Color3.new(1, 1, 1)
	boutonFermer.TextSize = (isMobile or isSmallScreen) and 16 or 24
	boutonFermer.Font = Enum.Font.GothamBold
	boutonFermer.TextScaled = (isMobile or isSmallScreen)
	boutonFermer.MouseButton1Click:Connect(fermerPokedex)
	local xCorner = Instance.new("UICorner", boutonFermer)
	xCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 10)
	local xStroke = Instance.new("UIStroke", boutonFermer)
	xStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
	xStroke.Color = Color3.fromHSV(0, 0, 0.2)

	-- Barre de filtres (taille fixe, sera scalée)
	local filtresFrame = Instance.new("Frame")
	local filtersHeight = 50
	local filtersTop = headerHeight + 8
	filtresFrame.Size = UDim2.new(1, -20, 0, filtersHeight)
	filtresFrame.Position = UDim2.new(0, 10, 0, filtersTop)
	filtresFrame.BackgroundTransparency = 1
	filtresFrame.Parent = pokedexFrame

	local layout = Instance.new("UIListLayout", filtresFrame)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)

	-- Bouton "Toutes"
	local boutonTous = Instance.new("TextButton")
	boutonTous.Size = UDim2.new(0, 65, 0, 32) -- Réduit encore un peu
	boutonTous.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	boutonTous.Text = "ALL"
	boutonTous.TextColor3 = Color3.new(1, 1, 1)
	boutonTous.TextSize = 12
	boutonTous.Font = Enum.Font.GothamBold
	boutonTous.LayoutOrder = 1
	boutonTous.Parent = filtresFrame
	local tCorner = Instance.new("UICorner", boutonTous)
	tCorner.CornerRadius = UDim.new(0, 8)
	local tStroke = Instance.new("UIStroke", boutonTous)
	tStroke.Thickness = 3
	tStroke.Color = Color3.fromHSV(0, 0, 0.2)

	boutonTous.MouseButton1Click:Connect(function()
		-- "ALL" ne réinitialise plus le surlignage: il enlève seulement le filtre de rareté
		currentFilter = nil
		-- Optionnel: on enlève le filtre par ingrédient actif mais on conserve le surlignage visuel
		ingredientFilterName = nil
		if ingredientFilterButton then
			ingredientFilterButton.Visible = false
		end
		updatePokedexContent()
		updateFilterBadges()
		local pr = pokedexFrame:FindFirstChild("PageRecettes")
		local pd = pokedexFrame:FindFirstChild("PageDefis")
		if pr then pr.Visible = true end
		if pd then pd.Visible = false end
	end)
	rareteButtons["ALL"] = boutonTous

	-- Boutons de rareté (triés par ordre)
	-- Créer une liste triée des raretés par ordre
	local raretesSorted = {}
	for _, rareteInfo in pairs(RARETES) do
		table.insert(raretesSorted, rareteInfo)
	end
	table.sort(raretesSorted, function(a, b)
		return (a.ordre or 999) < (b.ordre or 999)
	end)
	
	for i, rareteInfo in ipairs(raretesSorted) do
		local boutonRarete = Instance.new("TextButton")
		boutonRarete.Size = UDim2.new(0, 82, 0, 32) -- Réduit encore un peu
		boutonRarete.BackgroundColor3 = rareteInfo.couleur
		boutonRarete.Text = rareteInfo.nom:upper()
		boutonRarete.TextColor3 = Color3.new(1, 1, 1)
		boutonRarete.TextSize = 11
		boutonRarete.Font = Enum.Font.GothamBold
		boutonRarete.LayoutOrder = i + 1
		boutonRarete.Parent = filtresFrame
		local rCorner = Instance.new("UICorner", boutonRarete)
		rCorner.CornerRadius = UDim.new(0, 8)
		local rStroke = Instance.new("UIStroke", boutonRarete)
		rStroke.Thickness = 3
		rStroke.Color = Color3.fromHSV(0, 0, 0.2)

		boutonRarete.MouseButton1Click:Connect(function()
			currentFilter = rareteInfo.nom
			ingredientFilterName = nil
			if ingredientFilterButton then
				ingredientFilterButton.Visible = false
			end
			updatePokedexContent()
			updateFilterBadges()
			local pr = pokedexFrame:FindFirstChild("PageRecettes")
			local pd = pokedexFrame:FindFirstChild("PageDefis")
			if pr then pr.Visible = true end
			if pd then pd.Visible = false end
		end)
		rareteButtons[rareteInfo.nom] = boutonRarete
	end

	-- Bouton filtre auto par ingrédient (affiché uniquement si un ingrédient vient d'être acquis)
	ingredientFilterButton = Instance.new("TextButton")
	ingredientFilterButton.Size = UDim2.new(0, (isMobile or isSmallScreen) and 100 or 160, 0, (isMobile or isSmallScreen) and 22 or 40)
	ingredientFilterButton.TextSize = (isMobile or isSmallScreen) and 10 or 14
	ingredientFilterButton.BackgroundColor3 = Color3.fromRGB(90, 120, 200)
	ingredientFilterButton.TextColor3 = Color3.new(1, 1, 1)
	ingredientFilterButton.TextSize = 14
	ingredientFilterButton.Font = Enum.Font.GothamBold
	ingredientFilterButton.Text = lastIngredientAddedName and ("ING: " .. lastIngredientAddedName .. " ✕") or "ING: -"
	ingredientFilterButton.Visible = lastIngredientAddedName ~= nil
	ingredientFilterButton.Parent = filtresFrame
	local iCorner = Instance.new("UICorner", ingredientFilterButton); iCorner.CornerRadius = UDim.new(0, 8)
	local iStroke = Instance.new("UIStroke", ingredientFilterButton); iStroke.Thickness = 3; iStroke.Color = Color3.fromHSV(0, 0, 0.2)
	ingredientFilterButton.MouseButton1Click:Connect(function()
		if ingredientFilterName then
			-- clic = effacer le filtre ingrédient
			ingredientFilterName = nil
			ingredientFilterButton.Visible = false
			updatePokedexContent()
		elseif lastIngredientAddedName then
			ingredientFilterName = lastIngredientAddedName
			ingredientFilterButton.Visible = true
			ingredientFilterButton.Text = "ING: " .. lastIngredientAddedName .. " ✕"
			currentFilter = nil
			updatePokedexContent()
		end
		local pr = pokedexFrame:FindFirstChild("PageRecettes")
		local pd = pokedexFrame:FindFirstChild("PageDefis")
		if pr then pr.Visible = true end
		if pd then pd.Visible = false end
	end)

	-- Défis Pokédex (barres de progression par rareté)
	local function _computePokedexChallenges()
		local pd = player:FindFirstChild("PlayerData")
		local sizesRoot = pd and pd:FindFirstChild("PokedexSizes")
		local result = {
			Commune = { total = 0, done = 0 },
			Rare = { total = 0, done = 0 },
			["Épique"] = { total = 0, done = 0 },
			["Légendaire"] = { total = 0, done = 0 },
			Mythique = { total = 0, done = 0 },
		}
		for nomRecette, donneesRecette in pairs(RECETTES) do
			local r = normalizeRarete(donneesRecette.rarete)
			if result[r] then
				result[r].total += 1
				local rf = sizesRoot and sizesRoot:FindFirstChild(nomRecette)
				local discoveredSizes = 0
				if rf then
					for _, child in ipairs(rf:GetChildren()) do
						if child:IsA("BoolValue") and child.Value == true then
							discoveredSizes += 1
						end
					end
				end
				if discoveredSizes >= 7 then
					result[r].done += 1
				end
			end
		end
		return result
	end

	local function _createChallengeCard(parent, rareteName, data)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 60)
		card.BackgroundColor3 = Color3.fromRGB(120, 90, 50)
		card.BorderSizePixel = 0
		local c = Instance.new("UICorner", card); c.CornerRadius = UDim.new(0, 8)
		local s = Instance.new("UIStroke", card); s.Thickness = 2; s.Color = Color3.fromRGB(60, 40, 20)

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(0.5, 0, 0, 22)
		title.Position = UDim2.new(0, 10, 0, 6)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.new(1,1,1)
		title.Text = "Défi • " .. rareteName

		local progress = Instance.new("TextLabel", card)
		progress.Size = UDim2.new(0.5, -10, 0, 20)
		progress.Position = UDim2.new(1, -10, 0, 6)
		progress.AnchorPoint = Vector2.new(1,0)
		progress.BackgroundTransparency = 1
		progress.Font = Enum.Font.GothamBold
		progress.TextSize = 16
		progress.TextXAlignment = Enum.TextXAlignment.Right
		progress.TextColor3 = Color3.fromRGB(220,220,220)
		progress.Text = string.format("%d/%d completed candies", data.done, data.total)

		local barBg = Instance.new("Frame", card)
		barBg.Size = UDim2.new(1, -20, 0, 10)
		barBg.Position = UDim2.new(0, 10, 1, -18)
		barBg.BackgroundColor3 = Color3.fromRGB(60, 45, 30)
		barBg.BorderSizePixel = 0
		local cb = Instance.new("UICorner", barBg); cb.CornerRadius = UDim.new(0, 6)

		local ratio = data.total > 0 and math.clamp(data.done / data.total, 0, 1) or 0
		local bar = Instance.new("Frame", barBg)
		bar.Size = UDim2.new(ratio, 0, 1, 0)
		bar.BackgroundColor3 = (rareteName == "Commune" and Color3.fromRGB(150,150,150))
			or (rareteName == "Rare" and Color3.fromRGB(100,150,255))
			or (rareteName == "Épique" and Color3.fromRGB(200,100,255))
			or (rareteName == "Légendaire" and Color3.fromRGB(255,180,100))
			or Color3.fromRGB(255,100,100)
		bar.BorderSizePixel = 0
		local cb2 = Instance.new("UICorner", bar); cb2.CornerRadius = UDim.new(0, 6)

		-- Affichage déblocage + bouton Réclamer
		local rewardMap = {
			["Common"] = "EssenceCommune",
			["Rare"] = "EssenceRare",
			["Epic"] = "EssenceEpique",
			["Legendary"] = "EssenceLegendaire",
			["Mythic"] = "EssenceMythique",
		}
		local rewardIng = rewardMap[rareteName]
		local shopUnlocks = player:FindFirstChild("PlayerData") and player.PlayerData:FindFirstChild("ShopUnlocks")
		local alreadyUnlocked = shopUnlocks and rewardIng and shopUnlocks:FindFirstChild(rewardIng) and shopUnlocks[rewardIng].Value == true
		-- Seuil = nombre de bonbons dans cette rareté (plus logique)
		local threshold = data.total

		local unlockText = Instance.new("TextLabel", card)
		unlockText.Size = UDim2.new(0.45, 0, 0, 20)
		unlockText.Position = UDim2.new(0, 10, 0, 32)
		unlockText.BackgroundTransparency = 1
		unlockText.Font = Enum.Font.Gotham
		unlockText.TextSize = 14
		unlockText.TextXAlignment = Enum.TextXAlignment.Left
		unlockText.TextColor3 = Color3.fromRGB(230,230,230)
		unlockText.Text = string.format("Déblocage: %d/%d", math.min(data.done, threshold), threshold)

		local claimBtn = nil
		if rewardIng then
			if alreadyUnlocked then
				local doneLbl = Instance.new("TextLabel", card)
				doneLbl.Size = UDim2.new(0, 120, 0, 26)
				doneLbl.Position = UDim2.new(1, -130, 0, 30)
				doneLbl.BackgroundColor3 = Color3.fromRGB(70, 140, 80)
				doneLbl.Text = "Débloqué ✓"
				doneLbl.TextColor3 = Color3.new(1,1,1)
				doneLbl.Font = Enum.Font.GothamBold
				doneLbl.TextSize = 14
				local dc = Instance.new("UICorner", doneLbl); dc.CornerRadius = UDim.new(0, 6)
			elseif data.done >= threshold then
				claimBtn = Instance.new("TextButton", card)
				claimBtn.Size = UDim2.new(0, 120, 0, 26)
				claimBtn.Position = UDim2.new(1, -130, 0, 30)
				claimBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 200)
				claimBtn.Text = "Réclamer"
				claimBtn.TextColor3 = Color3.new(1,1,1)
				claimBtn.Font = Enum.Font.GothamBold
				claimBtn.TextSize = 14
				local cc = Instance.new("UICorner", claimBtn); cc.CornerRadius = UDim.new(0, 6)
				local cs = Instance.new("UIStroke", claimBtn); cs.Thickness = 2; cs.Color = Color3.fromHSV(0,0,0.2)
				claimBtn.MouseButton1Click:Connect(function()
					local ev = ReplicatedStorage:FindFirstChild("ClaimPokedexReward")
					if not ev then
						showPokedexToast("Erreur: service indisponible")
						return
					end
					claimBtn.Active = false; claimBtn.AutoButtonColor = false
					ev:FireServer(rareteName)
					task.delay(0.5, function()
						-- Rafraîchir: re-vérifier déblocage
						local su = player:FindFirstChild("PlayerData") and player.PlayerData:FindFirstChild("ShopUnlocks")
						if su and su:FindFirstChild(rewardIng) and su[rewardIng].Value == true then
							showPokedexToast("Récompense débloquée: " .. rewardIng)
							claimBtn.Text = "Débloqué ✓"
							claimBtn.BackgroundColor3 = Color3.fromRGB(70, 140, 80)
						else
							claimBtn.Active = true; claimBtn.AutoButtonColor = true
							showPokedexToast("Condition non remplie")
						end
					end)
				end)
			end
		end

		card.Parent = parent
		return card
	end

	-- Zone de défilement Recettes
	-- Réserver davantage de marge sous les filtres (évite collision avec hotbar) + responsive mobile
	local extraUnderFilters = (isMobile or isSmallScreen) and 12 or 14
	local pageTop = headerHeight + filtersHeight + extraUnderFilters
	local pageRecettes = Instance.new("Frame", pokedexFrame)
	pageRecettes.Name = "PageRecettes"
	pageRecettes.Size = UDim2.new(1, 0, 1, -pageTop)
	pageRecettes.Position = UDim2.new(0, 0, 0, pageTop)
	pageRecettes.BackgroundTransparency = 1

	-- ScrollFrame avec marges réduites
	local scrollFrame = Instance.new("ScrollingFrame", pageRecettes)
	scrollFrame.Name = "ScrollFrame"
	local scrollMargin = 15 -- Réduit de 30 à 15
	scrollFrame.Size = UDim2.new(1, -(scrollMargin * 2), 1, -15)
	scrollFrame.Position = UDim2.new(0, scrollMargin, 0, 8)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 12
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100) -- Scrollbar plus visible
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local sCorner = Instance.new("UICorner", scrollFrame)
	sCorner.CornerRadius = UDim.new(0, 10)

	-- Padding interne réduit
	local scrollPadding = Instance.new("UIPadding", scrollFrame)
	scrollPadding.PaddingLeft = UDim.new(0, 8)
	scrollPadding.PaddingRight = UDim.new(0, 8)
	scrollPadding.PaddingTop = UDim.new(0, 8)
	scrollPadding.PaddingBottom = UDim.new(0, 8)

	local listLayout = Instance.new("UIListLayout", scrollFrame)
	listLayout.Padding = UDim.new(0, 10) -- Réduit de 12 à 10
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Animation d'ouverture
	pokedexFrame.Size = UDim2.new(0, 0, 0, 0)
	local finalSize = (isMobile or isSmallScreen) and UDim2.new(0.88, 0, 0.85, 0) or UDim2.new(0.8, 0, 0.8, 0)
	local tween = TweenService:Create(pokedexFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = finalSize})
	tween:Play()

	-- Charger le contenu
	-- Par défaut: ALL (aucun filtre)
	currentFilter = nil
	ingredientFilterName = nil
	if ingredientFilterButton then ingredientFilterButton.Visible = false end

	-- Page Défis (cachée au départ)
	local pageRecettesRef = pokedexFrame:FindFirstChild("PageRecettes")
	local pageDefis = Instance.new("Frame", pokedexFrame)
	pageDefis.Name = "PageDefis"
	pageDefis.Size = pageRecettesRef and pageRecettesRef.Size or UDim2.new(1, -20, 1, -(headerHeight + filtersHeight + 10))
	pageDefis.Position = pageRecettesRef and pageRecettesRef.Position or UDim2.new(0, 10, 0, headerHeight + filtersHeight + 10)
	pageDefis.BackgroundTransparency = 1
	pageDefis.Visible = false

	-- Conteneur scrollable pour les Défis (avec marges confortables)
	local defisScroll = Instance.new("ScrollingFrame", pageDefis)
	defisScroll.Name = "DefisScroll"
	local defisMargin = 20
	defisScroll.Size = UDim2.new(1, -(defisMargin * 2), 1, -20)
	defisScroll.Position = UDim2.new(0, defisMargin, 0, 10)
	defisScroll.BackgroundTransparency = 1
	defisScroll.ScrollBarThickness = 12
	defisScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100)
	defisScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	
	-- Padding interne
	local defisPadding = Instance.new("UIPadding", defisScroll)
	defisPadding.PaddingLeft = UDim.new(0, 10)
	defisPadding.PaddingRight = UDim.new(0, 10)
	defisPadding.PaddingTop = UDim.new(0, 10)
	defisPadding.PaddingBottom = UDim.new(0, 10)

	local function clearChildren(frame)
		for _, ch in ipairs(frame:GetChildren()) do ch:Destroy() end
	end

	-- (shadow fix) renommage: computePokedexChallenges2
	local function computePokedexChallenges2()
		local pd = player:FindFirstChild("PlayerData")
		local sizesRoot = pd and pd:FindFirstChild("PokedexSizes")
		local result = { Commune = { total = 0, done = 0 }, Rare = { total = 0, done = 0 }, ["Épique"] = { total = 0, done = 0 }, ["Légendaire"] = { total = 0, done = 0 }, Mythique = { total = 0, done = 0 } }
		for nomRecette, donneesRecette in pairs(RECETTES) do
			local r = normalizeRarete(donneesRecette.rarete)
			-- Debug: afficher les raretés trouvées
			if not result[r] then
				warn("[PokedexUI DEBUG] Rareté non reconnue:", donneesRecette.rarete, "->", r, "pour recette:", nomRecette)
			end
			if result[r] then
				result[r].total += 1
				local rf = sizesRoot and sizesRoot:FindFirstChild(nomRecette)
				if not rf and sizesRoot then
					local targetKey = normalizeText(nomRecette)
					for _, ch in ipairs(sizesRoot:GetChildren()) do
						if normalizeText(ch.Name) == targetKey then
							rf = ch
							break
						end
					end
				end
				local discoveredSizes = 0
				if rf then
					for _, child in ipairs(rf:GetChildren()) do
						if child:IsA("BoolValue") and child.Value == true then discoveredSizes += 1 end
					end
				end
				if discoveredSizes >= 7 then result[r].done += 1 end
			end
		end
		return result
	end

	local function buildChallengeCard(parent, rareteName, data)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 60)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = Color3.fromRGB(120, 90, 50)
		card.BorderSizePixel = 0
		local c = Instance.new("UICorner", card); c.CornerRadius = UDim.new(0, 8)
		local s = Instance.new("UIStroke", card); s.Thickness = 2; s.Color = Color3.fromRGB(60, 40, 20)
		-- Flèche expand/collapse
		local expandBtn = Instance.new("TextButton", card)
		expandBtn.Size = UDim2.new(0, 26, 0, 26)
		expandBtn.Position = UDim2.new(0, 8, 0, 6)
		expandBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		expandBtn.Text = "▼"
		expandBtn.TextColor3 = Color3.new(1,1,1)
		expandBtn.Font = Enum.Font.GothamBold
		expandBtn.TextScaled = true
		local ebc = Instance.new("UICorner", expandBtn); ebc.CornerRadius = UDim.new(0, 6)
		local ebs = Instance.new("UIStroke", expandBtn); ebs.Thickness = 2; ebs.Color = Color3.fromHSV(0,0,0.2)

		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(0.5, -36, 0, 22)
		title.Position = UDim2.new(0, 10 + 26 + 6, 0, 6)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.new(1,1,1)
		title.Text = "Challenge • " .. rareteName
		local progress = Instance.new("TextLabel", card)
		progress.Size = UDim2.new(0.5, -10, 0, 20)
		progress.Position = UDim2.new(1, -10, 0, 6)
		progress.AnchorPoint = Vector2.new(1,0)
		progress.BackgroundTransparency = 1
		progress.Font = Enum.Font.GothamBold
		progress.TextSize = 16
		progress.TextXAlignment = Enum.TextXAlignment.Right
		progress.TextColor3 = Color3.fromRGB(220,220,220)
		progress.Text = string.format("%d/%d completed candies", data.done, data.total)
		local barBg = Instance.new("Frame", card)
		barBg.Size = UDim2.new(1, -20, 0, 10)
		barBg.Position = UDim2.new(0, 10, 1, -18)
		barBg.BackgroundColor3 = Color3.fromRGB(60, 45, 30)
		barBg.BorderSizePixel = 0
		local cb = Instance.new("UICorner", barBg); cb.CornerRadius = UDim.new(0, 6)
		local ratio = data.total > 0 and math.clamp(data.done / data.total, 0, 1) or 0
		local bar = Instance.new("Frame", barBg)
		bar.Size = UDim2.new(ratio, 0, 1, 0)
		bar.BackgroundColor3 = (rareteName == "Commune" and Color3.fromRGB(150,150,150)) or (rareteName == "Rare" and Color3.fromRGB(100,150,255)) or (rareteName == "Épique" and Color3.fromRGB(200,100,255)) or (rareteName == "Légendaire" and Color3.fromRGB(255,180,100)) or Color3.fromRGB(255,100,100)
		bar.BorderSizePixel = 0
		local cb2 = Instance.new("UICorner", bar); cb2.CornerRadius = UDim.new(0, 6)

		local rewardMap = { ["Commune"] = "EssenceCommune", ["Rare"] = "EssenceRare", ["Épique"] = "EssenceEpique", ["Légendaire"] = "EssenceLegendaire", ["Mythique"] = "EssenceMythique" }
		local rewardIng = rewardMap[rareteName]
		local shopUnlocks = player:FindFirstChild("PlayerData") and player.PlayerData:FindFirstChild("ShopUnlocks")
		local alreadyUnlocked = shopUnlocks and rewardIng and shopUnlocks:FindFirstChild(rewardIng) and shopUnlocks[rewardIng].Value == true
		-- Seuil = nombre de bonbons dans cette rareté (plus logique)
		local threshold = data.total
		-- Barre de progression (défi) sous le titre
		local unlockBarBg = Instance.new("Frame", card)
		unlockBarBg.Size = UDim2.new(0.45, 0, 0, 10)
		unlockBarBg.Position = UDim2.new(0, 10, 0, 34)
		unlockBarBg.BackgroundColor3 = Color3.fromRGB(70, 55, 35)
		unlockBarBg.BorderSizePixel = 0
		local ubc = Instance.new("UICorner", unlockBarBg); ubc.CornerRadius = UDim.new(0, 6)
		local ratioDefi = math.clamp((threshold > 0) and (data.done / threshold) or 0, 0, 1)
		local unlockBar = Instance.new("Frame", unlockBarBg)
		unlockBar.Size = UDim2.new(ratioDefi, 0, 1, 0)
		unlockBar.BackgroundColor3 = Color3.fromRGB(100, 170, 80)
		unlockBar.BorderSizePixel = 0
		local ubc2 = Instance.new("UICorner", unlockBar); ubc2.CornerRadius = UDim.new(0, 6)
		-- Option: pas de texte pour éviter la confusion avec la 2e barre globale
		if rewardIng then
			if alreadyUnlocked then
				local doneLbl = Instance.new("TextLabel", card)
				doneLbl.Size = UDim2.new(0, 120, 0, 26)
				doneLbl.Position = UDim2.new(1, -130, 0, 30)
				doneLbl.BackgroundColor3 = Color3.fromRGB(70, 140, 80)
				doneLbl.Text = "Débloqué ✓"
				doneLbl.TextColor3 = Color3.new(1,1,1)
				doneLbl.Font = Enum.Font.GothamBold
				doneLbl.TextSize = 14
				local dc = Instance.new("UICorner", doneLbl); dc.CornerRadius = UDim.new(0, 6)
			elseif data.done >= threshold then
				local claimBtn = Instance.new("TextButton", card)
				claimBtn.Size = UDim2.new(0, 120, 0, 26)
				claimBtn.Position = UDim2.new(1, -130, 0, 30)
				claimBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 200)
				claimBtn.Text = "Réclamer"
				claimBtn.TextColor3 = Color3.new(1,1,1)
				claimBtn.Font = Enum.Font.GothamBold
				claimBtn.TextSize = 14
				local cc = Instance.new("UICorner", claimBtn); cc.CornerRadius = UDim.new(0, 6)
				local cs = Instance.new("UIStroke", claimBtn); cs.Thickness = 2; cs.Color = Color3.fromHSV(0,0,0.2)
				claimBtn.MouseButton1Click:Connect(function()
					local ev = ReplicatedStorage:FindFirstChild("ClaimPokedexReward")
					if not ev then showPokedexToast("Erreur: service indisponible"); return end
					claimBtn.Active = false; claimBtn.AutoButtonColor = false
					ev:FireServer(rareteName)
					task.delay(0.5, function()
						local su = player:FindFirstChild("PlayerData") and player.PlayerData:FindFirstChild("ShopUnlocks")
						if su and su:FindFirstChild(rewardIng) and su[rewardIng].Value == true then
							showPokedexToast("Récompense débloquée: " .. rewardIng)
							-- Reconstruire la section localement
							clearChildren(pageDefis)
							local container = Instance.new("Frame", pageDefis)
							container.Size = UDim2.new(1, -20, 1, -10)
							container.Position = UDim2.new(0, 10, 0, 0)
							container.BackgroundTransparency = 1
							local lay = Instance.new("UIListLayout", container)
							lay.Padding = UDim.new(0, 8)
							lay.SortOrder = Enum.SortOrder.LayoutOrder
							local headerLbl = Instance.new("TextLabel", container)
							headerLbl.Size = UDim2.new(1, 0, 0, 24)
							headerLbl.BackgroundTransparency = 1
							headerLbl.Font = Enum.Font.GothamBold
							headerLbl.TextSize = 20
							headerLbl.TextXAlignment = Enum.TextXAlignment.Left
							headerLbl.TextColor3 = Color3.new(1,1,1)
							headerLbl.Text = "🏆 CandyDex Challenges"
							local ch = computePokedexChallenges2()
							buildChallengeCard(container, "Commune", ch.Commune)
							buildChallengeCard(container, "Rare", ch.Rare)
							buildChallengeCard(container, "Épique", ch["Épique"])
							buildChallengeCard(container, "Légendaire", ch["Légendaire"])
							buildChallengeCard(container, "Mythique", ch.Mythique)
						else
							claimBtn.Active = true; claimBtn.AutoButtonColor = true
							showPokedexToast("Condition non remplie")
						end
					end)
				end)
			end
		end
		-- Détails: liste des recettes et tailles découvertes
		local maxDetailHeight = (isMobile or isSmallScreen) and 140 or 220
		local detailContainer = Instance.new("Frame", card)
		detailContainer.Name = "DetailContainer"
		detailContainer.BackgroundTransparency = 1
		detailContainer.Size = UDim2.new(1, -20, 0, 0)
		detailContainer.Position = UDim2.new(0, 10, 0, 62)
		detailContainer.Visible = false

		local detailScroll = Instance.new("ScrollingFrame", detailContainer)
		detailScroll.Name = "DetailScroll"
		detailScroll.BackgroundTransparency = 1
		detailScroll.Size = UDim2.new(1, -10, 1, 0)
		detailScroll.Position = UDim2.new(0, 5, 0, 0)
		detailScroll.ScrollBarThickness = 10
		detailScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100)
		detailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		
		-- Padding interne
		local detailPadding = Instance.new("UIPadding", detailScroll)
		detailPadding.PaddingLeft = UDim.new(0, 5)
		detailPadding.PaddingRight = UDim.new(0, 5)
		detailPadding.PaddingTop = UDim.new(0, 5)
		detailPadding.PaddingBottom = UDim.new(0, 5)

		local dl = Instance.new("UIListLayout", detailScroll)
		dl.FillDirection = Enum.FillDirection.Vertical
		dl.Padding = UDim.new(0, 8)
		dl.SortOrder = Enum.SortOrder.LayoutOrder
		local dspad = Instance.new("UIPadding", detailScroll)
		dspad.PaddingBottom = UDim.new(0, 6)

		-- Affichage tailles: PC = libellés complets, Mobile = abréviations
		local SIZES_ORDER = {}
		if isMobile or isSmallScreen then
			SIZES_ORDER = {"T","S","N","L","G","C","L+"}
		else
			SIZES_ORDER = {"Tiny","Small","Normal","Large","Giant","Colossal","Legendary"}
		end

		local function createSizeChip(parent, label, isFound)
			local chip = Instance.new("TextButton")
			chip.AutoButtonColor = false
			chip.Text = ""
			chip.Size = UDim2.new(0, (isMobile or isSmallScreen) and 28 or 72, 0, (isMobile or isSmallScreen) and 20 or 26)
			chip.BackgroundColor3 = isFound and Color3.fromRGB(85,170,85) or Color3.fromRGB(110,110,110)
			chip.Parent = parent
			local cc = Instance.new("UICorner", chip); cc.CornerRadius = UDim.new(0, 6)
			local cs = Instance.new("UIStroke", chip); cs.Thickness = 1; cs.Color = Color3.fromHSV(0,0,0.2)
			local lbl = Instance.new("TextLabel", chip)
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = label
			lbl.TextColor3 = Color3.new(1,1,1)
			lbl.Font = Enum.Font.GothamBold
			lbl.TextScaled = true
			return chip
		end

		local function buildDetailRows()
			for _, ch in ipairs(detailScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
			local recs = {}
			local normalizedRareteName = normalizeRarete(rareteName)
			for nomRecette, def in pairs(RECETTES) do
				if normalizeRarete(def.rarete) == normalizedRareteName then table.insert(recs, nomRecette) end
			end
			table.sort(recs)
			local pd = player:FindFirstChild("PlayerData")
			local sizesRoot = pd and pd:FindFirstChild("PokedexSizes")
			-- Mapping abréviations mobile -> clés réelles dans PokedexSizes
			local function sizeLabelToKey(label)
				-- 🔧 CORRECTION: Retourner les noms FRANÇAIS pour le serveur
				if isMobile or isSmallScreen then
					local map = { 
						["T"] = "Minuscule", 
						["S"] = "Petit", 
						["N"] = "Normal", 
						["L"] = "Grand", 
						["G"] = "Géant", 
						["C"] = "Colossal", 
						["L+"] = "Légendaire"  -- 🔧 Pas de majuscules!
					}
					return map[label] or label
				end
				-- Sur PC, les labels sont déjà en français
				return label
			end
			local function normalizeSizeName(s)
				s = tostring(s or "")
				s = s:gsub("é", "e"):gsub("É", "E"):gsub("è","e"):gsub("È","E")
				s = s:gsub("à","a"):gsub("À","A"):gsub("ï","i"):gsub("Ï","I")
				s = s:lower()
				s = s:gsub("[^%w]", "") -- retirer espaces et symboles
				-- 🔧 CORRECTION: Normaliser vers les noms français
				if s == "minuscule" or s == "tiny" then return "minuscule" end
				if s == "petit" or s == "small" then return "petit" end
				if s == "normal" then return "normal" end
				if s == "grand" or s == "large" then return "grand" end
				if s == "geant" or s == "giant" then return "geant" end
				if s == "colossal" then return "colossal" end
				if s == "legendaire" or s == "legendary" then return "legendaire" end
				return s
			end
			for _, recName in ipairs(recs) do
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 34)
				row.BackgroundColor3 = Color3.fromRGB(100, 75, 40)
				row.BorderSizePixel = 0
				row.Parent = detailScroll
				local rc = Instance.new("UICorner", row); rc.CornerRadius = UDim.new(0, 6)
				local rs = Instance.new("UIStroke", row); rs.Thickness = 1; rs.Color = Color3.fromRGB(60,40,20)

				local nameCard = Instance.new("Frame", row)
				nameCard.Size = UDim2.new(0.32, -8, 1, -4)
				nameCard.Position = UDim2.new(0, 8, 0, 2)
				nameCard.BackgroundColor3 = Color3.fromRGB(85, 65, 35)
				nameCard.BorderSizePixel = 0
				local ncCorner = Instance.new("UICorner", nameCard); ncCorner.CornerRadius = UDim.new(0, 6)
				local ncStroke = Instance.new("UIStroke", nameCard); ncStroke.Thickness = 1; ncStroke.Color = Color3.fromRGB(60,40,20)
				local nameLbl = Instance.new("TextLabel", nameCard)
				nameLbl.Size = UDim2.new(1, -10, 1, 0)
				nameLbl.Position = UDim2.new(0, 10, 0, 0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextSize = 14
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextColor3 = Color3.new(1,1,1)
				-- Utiliser le champ 'nom' du RecipeManager si disponible
				local displayName = recName
				if RECETTES[recName] and RECETTES[recName].nom then
					displayName = RECETTES[recName].nom
				end
				nameLbl.Text = displayName

				-- Grille de 7 cartes de taille
				local chips = Instance.new("Frame", row)
				chips.Size = UDim2.new(0.68, -10, 1, -4)
				chips.Position = UDim2.new(1, -10, 0, 2)
				chips.AnchorPoint = Vector2.new(1,0)
				chips.BackgroundTransparency = 1
				local cl = Instance.new("UIGridLayout", chips)
				cl.CellSize = UDim2.new(0, (isMobile or isSmallScreen) and 30 or 72, 0, (isMobile or isSmallScreen) and 22 or 28)
				cl.CellPadding = UDim2.new(0, 6)
				cl.HorizontalAlignment = Enum.HorizontalAlignment.Right
				cl.VerticalAlignment = Enum.VerticalAlignment.Center

				local rf = sizesRoot and sizesRoot:FindFirstChild(recName)
				-- Tolérance: si le nom exact ne correspond pas (espaces/accents), essayer une recherche normalisée
				if not rf and sizesRoot then
					local targetKey = normalizeText(recName)
					for _, child in ipairs(sizesRoot:GetChildren()) do
						if normalizeText(child.Name) == targetKey then
							rf = child
							break
						end
					end
				end
				-- Construire un set normalisé des tailles trouvées (tolérant aux variations d'écriture)
				local foundNormalized = {}
				if rf then
					for _, child in ipairs(rf:GetChildren()) do
						if child:IsA("BoolValue") and child.Value == true then
							foundNormalized[normalizeSizeName(child.Name)] = true
						end
					end
				end
				for _, sizeName in ipairs(SIZES_ORDER) do
					local key = sizeLabelToKey(sizeName)
					local isFound = false
					if rf then
						-- Essai direct
						local direct = rf:FindFirstChild(key)
						isFound = (direct and direct:IsA("BoolValue") and direct.Value == true) or false
						-- Fallback: comparaison normalisée
						if not isFound then
							isFound = foundNormalized[normalizeSizeName(key)] == true
						end
					end
					local chip = createSizeChip(chips, sizeName, isFound)
					if isFound then
						chip.Active = false
					else
						chip.Active = true
						chip.MouseButton1Click:Connect(function()
							-- Rafraîchir la référence au RemoteEvent si nécessaire
							local ev = requestPokedexSizeEvt or ReplicatedStorage:FindFirstChild("RequestPokedexSizePurchaseRobux")
							if not ev or not ev:IsA("RemoteEvent") then
								showPokedexToast("Purchase not available at the moment")
								return
							end
							-- Anti double-clic local
							chip.Active = false
							-- Debug: log exactement ce qui est envoyé (clé et octets UTF-8)
							local _b = {}
							for i = 1, #key do _b[#_b+1] = string.byte(key, i) end
							warn("[PokedexUI] Envoi achat taille:", recName, "key:", key, "bytes:", table.concat(_b, ","))
							local ok, err = pcall(function()
								ev:FireServer(recName, key)
							end)
							if not ok then
								warn("[PokedexUI] Erreur envoi demande achat taille:", err)
								chip.Active = true
							else
								-- Option: réactiver après un court délai si le prompt ne s'ouvre pas
								task.delay(1.5, function()
									if chip and chip.Parent and not isFound then
										chip.Active = true
									end
								end)
							end
						end)
					end
				end
			end
		end

		expandBtn.MouseButton1Click:Connect(function()
			local v = not detailContainer.Visible
			detailContainer.Visible = v
			expandBtn.Text = v and "▲" or "▼"
			if v then
				detailContainer.Size = UDim2.new(1, -20, 0, maxDetailHeight)
				buildDetailRows()
			else
				detailContainer.Size = UDim2.new(1, -20, 0, 0)
			end
		end)

		card.Parent = parent
	end

	local function refreshChallengesPage()
		clearChildren(defisScroll)
		local container = Instance.new("Frame", defisScroll)
		container.Size = UDim2.new(1, -20, 1, -10)
		container.Position = UDim2.new(0, 10, 0, 0)
		container.BackgroundTransparency = 1
		local lay = Instance.new("UIListLayout", container)
		lay.Padding = UDim.new(0, 8)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		local headerLbl = Instance.new("TextLabel", container)
		headerLbl.Size = UDim2.new(1, 0, 0, 24)
		headerLbl.BackgroundTransparency = 1
		headerLbl.Font = Enum.Font.GothamBold
		headerLbl.TextSize = 20
		headerLbl.TextXAlignment = Enum.TextXAlignment.Left
		headerLbl.TextColor3 = Color3.new(1,1,1)
		headerLbl.Text = "🏆 Pokédex Challenges"
		local ch = computePokedexChallenges2()
		buildChallengeCard(container, "Commune", ch.Commune)
		buildChallengeCard(container, "Rare", ch.Rare)
		buildChallengeCard(container, "Épique", ch["Épique"])
		buildChallengeCard(container, "Légendaire", ch["Légendaire"])
		buildChallengeCard(container, "Mythique", ch.Mythique)
	end
	-- Exposer la fonction pour le watcher temps réel
	_refreshChallengesPage = refreshChallengesPage

	-- Bouton "DÉFIS" aligné à droite dans la barre de filtres (overlay)
	local defisBtn = Instance.new("TextButton")
	local defisWidth = (isMobile or isSmallScreen) and 58 or 110
	local defisHeight = (isMobile or isSmallScreen) and 20 or 40
	defisBtn.Size = UDim2.new(0, defisWidth, 0, defisHeight)
	defisBtn.Position = UDim2.new(1, -(defisWidth + 14), 0, filtersTop + math.floor((filtersHeight - defisHeight)/2))
	defisBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
	defisBtn.Text = "CHALLENGES"
	defisBtn.TextColor3 = Color3.new(1,1,1)
	defisBtn.Font = Enum.Font.GothamBold
	defisBtn.TextScaled = (isMobile or isSmallScreen)
	defisBtn.Parent = pokedexFrame
	local dbc = Instance.new("UICorner", defisBtn); dbc.CornerRadius = UDim.new(0, 8)
	local dbs = Instance.new("UIStroke", defisBtn); dbs.Thickness = 2; dbs.Color = Color3.fromHSV(0,0,0.2)
	defisBtn.MouseButton1Click:Connect(function()
		local pr = pokedexFrame:FindFirstChild("PageRecettes")
		local pd = pokedexFrame:FindFirstChild("PageDefis")
		if pr then pr.Visible = false end
		if pd then pd.Visible = true end
		refreshChallengesPage()
	end)

	-- (DEV) Boutons de déblocage instant supprimés

		-- État par défaut: afficher les recettes avec le filtre ALL
	do
		local pr = pokedexFrame:FindFirstChild("PageRecettes")
		local pd = pokedexFrame:FindFirstChild("PageDefis")
		if pr then pr.Visible = true end
		if pd then pd.Visible = false end
		currentFilter = nil
		ingredientFilterName = nil
		if ingredientFilterButton then ingredientFilterButton.Visible = false end
		updatePokedexContent()
		updateFilterBadges()
	end
end

-- Fonction de fermeture
fermerPokedex = function()
	if pokedexFrame then
		local tween = TweenService:Create(pokedexFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
		tween:Play()
		tween.Completed:Connect(function()
			pokedexFrame:Destroy()
			pokedexFrame = nil
			isPokedexOpen = false
			if screenGui and _oldScreenGuiDisplayOrder ~= nil then
				screenGui.DisplayOrder = _oldScreenGuiDisplayOrder
				_oldScreenGuiDisplayOrder = nil
			end
			-- Ne plus rafraîchir quand la fenêtre est fermée
			_refreshChallengesPage = nil
		end)
	end
end

-- Fonction d'ouverture
local function ouvrirPokedex()
	if not isPokedexOpen then
		-- Mettre le Pokédex au premier plan (devant hotbar et bouton)
		if screenGui then
			_oldScreenGuiDisplayOrder = screenGui.DisplayOrder
			screenGui.DisplayOrder = 2000
		end
		createPokedexInterface()
		-- Dès qu'on ouvre, le badge s'enlève et le contour redevient normal
		if pokedexButtonNotifBadge then pokedexButtonNotifBadge.Visible = false end
		if pokedexButtonStroke then pokedexButtonStroke.Enabled = false end
		-- On garde le surlignage des cartes tant qu'on n'a pas appuyé sur ALL
	end
end

-- Crée le bouton d'accès permanent (responsive et repositionné)
local function createPokedexButton()
	local boutonPokedex = screenGui:FindFirstChild("BoutonPokedex")
	if boutonPokedex then
		pokedexButton = boutonPokedex
		return
	end

	boutonPokedex = Instance.new("ImageButton")
	boutonPokedex.Name = "BoutonPokedex"
	-- Taille réduite pour éviter la superposition et responsive
	local buttonSize = (isMobile or isSmallScreen) and 50 or 65
	boutonPokedex.Size = UDim2.new(0, buttonSize, 0, buttonSize)
	-- Position en bas à gauche pour éviter les conflits avec téléportation
	boutonPokedex.Position = UDim2.new(0, 10, 1, -(buttonSize + 20))
	boutonPokedex.BackgroundTransparency = 1
	boutonPokedex.Image = "rbxassetid://117559923838203"
	boutonPokedex.ScaleType = Enum.ScaleType.Fit
	boutonPokedex.BorderSizePixel = 0
	boutonPokedex.ZIndex = 1500
	boutonPokedex.Parent = screenGui

	local bCorner = Instance.new("UICorner", boutonPokedex)
	bCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 12)

	pokedexButton = boutonPokedex

	-- Effet de survol (responsive)
	boutonPokedex.MouseEnter:Connect(function()
		local hoverSize = buttonSize + 5
		local tween = TweenService:Create(boutonPokedex, TweenInfo.new(0.2), {Size = UDim2.new(0, hoverSize, 0, hoverSize)})
		tween:Play()
	end)

	boutonPokedex.MouseLeave:Connect(function()
		local tween = TweenService:Create(boutonPokedex, TweenInfo.new(0.2), {Size = UDim2.new(0, buttonSize, 0, buttonSize)})
		tween:Play()
	end)

	-- Connexion du clic
	boutonPokedex.MouseButton1Click:Connect(function()
		if isPokedexOpen then
			fermerPokedex()
		else
			ouvrirPokedex()
		end
	end)
end

-- Système de surveillance des tailles découvertes pour mise à jour en temps réel des défis
local function setupPokedexSizesWatcher()
	local playerData = player:WaitForChild("PlayerData")

	-- Fonction pour surveiller les changements dans PokedexSizes
	local function watchPokedexSizes()
		local pokedexSizes = playerData:FindFirstChild("PokedexSizes")
		if not pokedexSizes then
			-- Attendre que PokedexSizes soit créé
			local connection
			connection = playerData.ChildAdded:Connect(function(child)
				if child.Name == "PokedexSizes" then
					connection:Disconnect()
					watchPokedexSizes() -- Relancer la surveillance
				end
			end)
			return
		end

		-- Surveiller l'ajout de nouvelles recettes
		pokedexSizes.ChildAdded:Connect(function(recipeFolder)
			if not recipeFolder:IsA("Folder") then return end
			print("📚  New recipe discovered in CandyDex:", recipeFolder.Name)

			-- À chaque nouvelle taille ajoutée dans cette recette
			recipeFolder.ChildAdded:Connect(function(sizeValue)
				if not sizeValue:IsA("BoolValue") then return end
				print("✨ New size discovered:", recipeFolder.Name, "en", sizeValue.Name)
				-- Rafraîchir si la page Défis est visible
				if isPokedexOpen and pokedexFrame then
					local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
					if pageDefis and pageDefis.Visible and _refreshChallengesPage then
						task.defer(_refreshChallengesPage)
					end
				end
				-- Surveiller le changement de valeur (pour les bascules ultérieures)
				sizeValue:GetPropertyChangedSignal("Value"):Connect(function()
					if sizeValue.Value == true then
						print("✨ Valideted Size:", recipeFolder.Name, "en", sizeValue.Name)
						if isPokedexOpen and pokedexFrame then
							local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
							if pageDefis and pageDefis.Visible and _refreshChallengesPage then
								task.defer(_refreshChallengesPage)
							end
						end
					end
				end)
			end)

			-- Surveiller aussi les changements de valeur des tailles déjà présentes
			for _, child in ipairs(recipeFolder:GetChildren()) do
				if child:IsA("BoolValue") then
					child:GetPropertyChangedSignal("Value"):Connect(function()
						if child.Value == true then
							print("✨ Taille découverte:", recipeFolder.Name, "en", child.Name)
							if isPokedexOpen and pokedexFrame then
								local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
								if pageDefis and pageDefis.Visible and _refreshChallengesPage then
									task.defer(_refreshChallengesPage)
								end
							end
						end
					end)
				end
			end
		end)

		-- Surveiller les dossiers de recettes existants
		for _, recipeFolder in ipairs(pokedexSizes:GetChildren()) do
			if not recipeFolder:IsA("Folder") then continue end
			-- Surveiller l'ajout de nouvelles tailles
			recipeFolder.ChildAdded:Connect(function(sizeValue)
				if not sizeValue:IsA("BoolValue") then return end
				print("✨ New Size Add:", recipeFolder.Name, "en", sizeValue.Name)
				if isPokedexOpen and pokedexFrame then
					local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
					if pageDefis and pageDefis.Visible and _refreshChallengesPage then
						task.defer(_refreshChallengesPage)
					end
				end
				sizeValue:GetPropertyChangedSignal("Value"):Connect(function()
					if sizeValue.Value == true and isPokedexOpen and pokedexFrame then
						local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
						if pageDefis and pageDefis.Visible and _refreshChallengesPage then
							task.defer(_refreshChallengesPage)
						end
					end
				end)
			end)

			-- Surveiller les tailles existantes
			for _, child in ipairs(recipeFolder:GetChildren()) do
				if child:IsA("BoolValue") then
					child:GetPropertyChangedSignal("Value"):Connect(function()
						if child.Value == true and isPokedexOpen and pokedexFrame then
							local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
							if pageDefis and pageDefis.Visible and _refreshChallengesPage then
								task.defer(_refreshChallengesPage)
							end
						end
					end)
				end
			end
		end
	end

	watchPokedexSizes()

	-- Rafraîchir la page DÉFIS lorsqu'on gagne/perd un Tool bonbon (fallback basé Backpack)
	local function maybeRefreshOnInventoryChange()
		if isPokedexOpen and pokedexFrame and _refreshChallengesPage then
			local pageDefis = pokedexFrame:FindFirstChild("PageDefis")
			if pageDefis and pageDefis.Visible then
				task.defer(_refreshChallengesPage)
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
	if backpack then
		backpack.ChildAdded:Connect(maybeRefreshOnInventoryChange)
		backpack.ChildRemoved:Connect(maybeRefreshOnInventoryChange)
	end
	-- Aussi surveiller l'outil équipé/déséquipé
	player.CharacterAdded:Connect(function(char)
		char.ChildAdded:Connect(maybeRefreshOnInventoryChange)
		char.ChildRemoved:Connect(maybeRefreshOnInventoryChange)
	end)
end

-- Initialisation
createPokedexButton()
setupIngredientWatchers()
setupPokedexSizesWatcher()

print("✅ Pokédex v3.0 (Style Simulateur) chargé !") 

-- === Barre HUD des passifs (5 slots) ===
do
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:FindFirstChild("PassivesHUD")
	if not hud then
		hud = Instance.new("ScreenGui")
		hud.Name = "PassivesHUD"
		hud.ResetOnSpawn = false
		hud.DisplayOrder = 2500
		hud.Parent = playerGui
	end
	local bar = hud:FindFirstChild("Bar")
	if not bar then
		bar = Instance.new("Frame")
		bar.Name = "Bar"
		-- Aligner à droite, vertical
		bar.AnchorPoint = Vector2.new(1, 0.5)
		-- Position collée complètement à droite sur mobile
		bar.Position = UDim2.new(1, (isMobile or isSmallScreen) and 0 or -10, 0.5, 0)
		-- Largeur réduite sur mobile pour être plus compact
		bar.Size = UDim2.new(0, (isMobile or isSmallScreen) and 32 or 64, 0, 0)
		bar.AutomaticSize = Enum.AutomaticSize.Y
		bar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		bar.BackgroundTransparency = 0.2
		bar.Parent = hud
		local bc = Instance.new("UICorner", bar); bc.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 10)
		local bs = Instance.new("UIStroke", bar); bs.Thickness = (isMobile or isSmallScreen) and 1 or 2; bs.Color = Color3.fromRGB(60,60,60)
		local pad = Instance.new("UIPadding", bar)
		-- Padding réduit sur mobile pour être plus compact
		pad.PaddingLeft = UDim.new(0, (isMobile or isSmallScreen) and 3 or 6)
		pad.PaddingRight = UDim.new(0, (isMobile or isSmallScreen) and 3 or 6)
		pad.PaddingTop = UDim.new(0, (isMobile or isSmallScreen) and 4 or 8)
		pad.PaddingBottom = UDim.new(0, (isMobile or isSmallScreen) and 4 or 8)
		local list = Instance.new("UIListLayout", bar)
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		-- Espacement réduit entre les icônes sur mobile
		list.Padding = UDim.new(0, (isMobile or isSmallScreen) and 4 or 12)
	end

	local slotOrder = {
		{key = "EssenceCommune",    emoji = "⚡", color = Color3.fromRGB(120,200,90),  tip = "Vitesse x2", desc = "Production speed x2", unlock = "Unlock with Common Challenge in CandyDex"},
		{key = "EssenceRare",       emoji = "💵", color = Color3.fromRGB(90,160,255),   tip = "Vente x1.5", desc = "Sell price x1.5", unlock = "Unlock with Rare Challenge in CandyDex"},
		{key = "EssenceEpique",     emoji = "➕", color = Color3.fromRGB(200,120,255),  tip = "Double prod", desc = "Production x2", unlock = "Unlock with Epic Challenge in CandyDex"},
		{key = "EssenceLegendaire", emoji = "🏭", color = Color3.fromRGB(255,180,100),  tip = "Plateformes x2", desc = "Platform production x2", unlock = "Unlock with Legendary Challenge in CandyDex"},
		{key = "EssenceMythique",   emoji = "👑", color = Color3.fromRGB(255,120,160),  tip = "Taille LEGENDARY", desc = "Force LEGENDARY size", unlock = "Unlock with Mythic Challenge in CandyDex"},
	}

	local function renderHUD()
		print("🎨 [PASSIVE] renderHUD() appelé - isMobile:", isMobile, "isSmallScreen:", isSmallScreen)
		if not bar then return end
		for _, ch in ipairs(bar:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		local pd = player:FindFirstChild("PlayerData")
		local su = pd and pd:FindFirstChild("ShopUnlocks")
		print("🎨 [PASSIVE] Création de", #slotOrder, "slots")
		for _, info in ipairs(slotOrder) do
			local active = su and su:FindFirstChild(info.key) and su[info.key].Value == true
			-- Taille des icônes réduite sur mobile
			local slotSize = (isMobile or isSmallScreen) and 26 or 56
			local slot = Instance.new("Frame")
			slot.Size = UDim2.new(0, slotSize, 0, slotSize)
			slot.BackgroundColor3 = active and info.color or Color3.fromRGB(60,60,60)
			slot.BackgroundTransparency = active and 0 or 0.35
			slot.Parent = bar
			local sc = Instance.new("UICorner", slot); sc.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 12)
			local ss = Instance.new("UIStroke", slot); ss.Thickness = (isMobile or isSmallScreen) and 1 or 2; ss.Color = active and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,90,90)

			local lbl = Instance.new("TextLabel", slot)
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = info.emoji
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.new(1,1,1)
			lbl.Font = Enum.Font.GothamBold
			lbl.TextTransparency = active and 0 or 0.25
			lbl.ZIndex = 1
			lbl.Active = false  -- Ne pas bloquer les clics

			-- Overlay cadenas si non débloqué
			local overlay = Instance.new("Frame", slot)
			overlay.Name = "LockOverlay"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
			overlay.BackgroundTransparency = active and 1 or 0.45
			overlay.ZIndex = 3
			overlay.Active = false  -- Ne pas bloquer les clics
			local oc = Instance.new("UICorner", overlay); oc.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 12)
			local lock = Instance.new("TextLabel", overlay)
			lock.BackgroundTransparency = 1
			lock.Size = UDim2.new(1, 0, 1, 0)
			lock.Text = "🔒"
			lock.TextScaled = true
			lock.TextColor3 = Color3.fromRGB(255,255,255)
			lock.Font = Enum.Font.GothamBold
			lock.ZIndex = 4
			lock.Visible = not active
			lock.Active = false  -- Ne pas bloquer les clics
			
			-- 📱 BOUTON CLIQUABLE (Mobile et PC)
			local clickButton = Instance.new("TextButton")
			clickButton.Name = "ClickButton"
			clickButton.Size = UDim2.new(1, 0, 1, 0)
			clickButton.BackgroundTransparency = 1
			clickButton.Text = ""
			clickButton.ZIndex = 50  -- Au-dessus de tout
			clickButton.Active = true
			clickButton.Modal = false
			clickButton.Parent = slot
			
			print("🔧 [PASSIVE] Bouton créé pour", info.key, "- ZIndex:", clickButton.ZIndex)

			-- Petit libellé (tooltip) sous la tuile (facultatif)
			local tip = Instance.new("TextLabel", slot)
			tip.Size = UDim2.new(1, 0, 0, 12)
			tip.Position = UDim2.new(0, 0, 1, -12)
			tip.BackgroundTransparency = 1
			tip.Text = (isMobile or isSmallScreen) and "" or info.tip
			tip.TextScaled = true
			tip.TextColor3 = Color3.fromRGB(240,240,240)
			tip.Font = Enum.Font.Gotham
			tip.TextTransparency = active and 0 or 0.5
			tip.ZIndex = 2
			tip.Active = false  -- Ne pas bloquer les clics
			
			-- 🆕 TOOLTIP DÉTAILLÉ au survol (PC uniquement)
			local tooltipFrame
			if not isMobile and not isSmallScreen then
				tooltipFrame = Instance.new("Frame")
				tooltipFrame.Name = "Tooltip"
				tooltipFrame.Size = UDim2.new(0, 220, 0, 0)
				tooltipFrame.AutomaticSize = Enum.AutomaticSize.Y
				tooltipFrame.AnchorPoint = Vector2.new(1, 0.5)
				tooltipFrame.Position = UDim2.new(0, -10, 0.5, 0)
				tooltipFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
				tooltipFrame.BackgroundTransparency = 0.05
				tooltipFrame.Visible = false
				tooltipFrame.ZIndex = 100
				tooltipFrame.Parent = slot
				
				local tooltipCorner = Instance.new("UICorner", tooltipFrame)
				tooltipCorner.CornerRadius = UDim.new(0, 8)
				
				local tooltipStroke = Instance.new("UIStroke", tooltipFrame)
				tooltipStroke.Thickness = 2
				tooltipStroke.Color = active and info.color or Color3.fromRGB(80, 80, 80)
				tooltipStroke.Transparency = 0.3
				
				local tooltipPadding = Instance.new("UIPadding", tooltipFrame)
				tooltipPadding.PaddingLeft = UDim.new(0, 12)
				tooltipPadding.PaddingRight = UDim.new(0, 12)
				tooltipPadding.PaddingTop = UDim.new(0, 10)
				tooltipPadding.PaddingBottom = UDim.new(0, 10)
				
				local tooltipLayout = Instance.new("UIListLayout", tooltipFrame)
				tooltipLayout.FillDirection = Enum.FillDirection.Vertical
				tooltipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				tooltipLayout.Padding = UDim.new(0, 6)
				
				-- Titre avec emoji
				local titleLabel = Instance.new("TextLabel", tooltipFrame)
				titleLabel.Size = UDim2.new(1, 0, 0, 24)
				titleLabel.BackgroundTransparency = 1
				titleLabel.Text = info.emoji .. " " .. info.desc
				titleLabel.TextColor3 = active and info.color or Color3.fromRGB(180, 180, 180)
				titleLabel.Font = Enum.Font.GothamBold
				titleLabel.TextSize = 16
				titleLabel.TextXAlignment = Enum.TextXAlignment.Left
				titleLabel.TextWrapped = true
				titleLabel.AutomaticSize = Enum.AutomaticSize.Y
				titleLabel.ZIndex = 101
				
				-- Séparateur
				local separator = Instance.new("Frame", tooltipFrame)
				separator.Size = UDim2.new(1, 0, 0, 1)
				separator.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
				separator.BorderSizePixel = 0
				separator.ZIndex = 101
				
				-- Description unlock
				local unlockLabel = Instance.new("TextLabel", tooltipFrame)
				unlockLabel.Size = UDim2.new(1, 0, 0, 20)
				unlockLabel.BackgroundTransparency = 1
				unlockLabel.Text = info.unlock
				unlockLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
				unlockLabel.Font = Enum.Font.Gotham
				unlockLabel.TextSize = 13
				unlockLabel.TextXAlignment = Enum.TextXAlignment.Left
				unlockLabel.TextWrapped = true
				unlockLabel.AutomaticSize = Enum.AutomaticSize.Y
				unlockLabel.ZIndex = 101
				
				-- Statut
				local statusLabel = Instance.new("TextLabel", tooltipFrame)
				statusLabel.Size = UDim2.new(1, 0, 0, 20)
				statusLabel.BackgroundTransparency = 1
				statusLabel.Text = active and "✅ Unlocked" or "🔒 Locked"
				statusLabel.TextColor3 = active and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120)
				statusLabel.Font = Enum.Font.GothamBold
				statusLabel.TextSize = 14
				statusLabel.TextXAlignment = Enum.TextXAlignment.Left
				statusLabel.ZIndex = 101
				
				-- Afficher/cacher le tooltip au survol (PC)
				clickButton.MouseEnter:Connect(function()
					if tooltipFrame then
						tooltipFrame.Visible = true
					end
				end)
				
				clickButton.MouseLeave:Connect(function()
					if tooltipFrame then
						tooltipFrame.Visible = false
					end
				end)
			end
			
			-- 📱 POPUP au clic (Mobile et PC)
			clickButton.MouseButton1Click:Connect(function()
				print("🔍 [PASSIVE] Clic détecté sur", info.key, "- isMobile:", isMobile, "isSmallScreen:", isSmallScreen)
				
				-- Sur PC, ne rien faire (tooltip au survol suffit)
				if not isMobile and not isSmallScreen then
					print("⚠️ [PASSIVE] PC détecté, pas de popup")
					return
				end
				
				-- Sur mobile, afficher le popup
				print("✅ [PASSIVE] Mobile détecté, création du popup")
				
				-- 🔧 Fermer l'ancien popup s'il existe
				local oldPopup = playerGui:FindFirstChild("PassivePopup")
				if oldPopup then
					print("🗑️ [PASSIVE] Fermeture ancien popup")
					oldPopup:Destroy()
				end
				
				-- Créer le popup avec fond invisible cliquable
				local popupBg = Instance.new("ScreenGui")
				popupBg.Name = "PassivePopup"
				popupBg.ResetOnSpawn = false
				popupBg.DisplayOrder = 1000
				popupBg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				popupBg.Parent = playerGui
				
				-- Fond invisible cliquable pour fermer
				local bgButton = Instance.new("TextButton")
				bgButton.Size = UDim2.new(1, 0, 1, 0)
				bgButton.BackgroundTransparency = 1
				bgButton.Text = ""
				bgButton.ZIndex = 1
				bgButton.Parent = popupBg
				
				bgButton.MouseButton1Click:Connect(function()
					print("🗑️ [PASSIVE] Fermeture popup (clic écran)")
					popupBg:Destroy()
				end)
					
				local popup = Instance.new("Frame")
				popup.Size = UDim2.new(0, 120, 0, 120)
				popup.AnchorPoint = Vector2.new(1, 0.5)
				popup.Position = UDim2.new(1, -20, 0.5, 0)  -- 2px du bord droit
				popup.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				popup.BorderSizePixel = 0
				popup.ZIndex = 10  -- Au-dessus du fond
				popup.Parent = popupBg
					
					local popupCorner = Instance.new("UICorner", popup)
					popupCorner.CornerRadius = UDim.new(0, 12)
					
					local popupStroke = Instance.new("UIStroke", popup)
					popupStroke.Thickness = 2
					popupStroke.Color = active and info.color or Color3.fromRGB(80, 80, 80)
					popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					
					local popupPadding = Instance.new("UIPadding", popup)
					popupPadding.PaddingLeft = UDim.new(0, 6)
					popupPadding.PaddingRight = UDim.new(0, 6)
					popupPadding.PaddingTop = UDim.new(0, 6)
					popupPadding.PaddingBottom = UDim.new(0, 6)
					
					local popupLayout = Instance.new("UIListLayout", popup)
					popupLayout.FillDirection = Enum.FillDirection.Vertical
					popupLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					popupLayout.Padding = UDim.new(0, 3)
					
					-- Emoji micro
					local emojiLabel = Instance.new("TextLabel", popup)
					emojiLabel.Size = UDim2.new(0, 22, 0, 22)
					emojiLabel.BackgroundColor3 = active and info.color or Color3.fromRGB(60, 60, 60)
					emojiLabel.BackgroundTransparency = active and 0 or 0.3
					emojiLabel.Text = info.emoji
					emojiLabel.TextScaled = true
					emojiLabel.TextColor3 = Color3.new(1, 1, 1)
					emojiLabel.Font = Enum.Font.GothamBold
					emojiLabel.ZIndex = 11
					local emojiCorner = Instance.new("UICorner", emojiLabel)
					emojiCorner.CornerRadius = UDim.new(0, 5)
					local emojiStroke = Instance.new("UIStroke", emojiLabel)
					emojiStroke.Thickness = 1
					emojiStroke.Color = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)
					emojiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					
					-- Titre micro
					local titleLabel = Instance.new("TextLabel", popup)
					titleLabel.Size = UDim2.new(1, 0, 0, 15)
					titleLabel.BackgroundTransparency = 1
					titleLabel.Text = info.desc
					titleLabel.TextColor3 = active and info.color or Color3.fromRGB(180, 180, 180)
					titleLabel.Font = Enum.Font.GothamBold
					titleLabel.TextSize = 8
					titleLabel.TextWrapped = true
					titleLabel.ZIndex = 11
					
					-- Séparateur micro (caché pour gagner de la place)
					-- local separator = Instance.new("Frame", popup)
					-- separator.Size = UDim2.new(1, 0, 0, 1)
					
					-- Description micro
					local unlockLabel = Instance.new("TextLabel", popup)
					unlockLabel.Size = UDim2.new(1, 0, 0, 20)
					unlockLabel.BackgroundTransparency = 1
					unlockLabel.Text = info.unlock
					unlockLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
					unlockLabel.Font = Enum.Font.Gotham
					unlockLabel.TextSize = 6
					unlockLabel.TextWrapped = true
					unlockLabel.ZIndex = 11
					
					-- Statut micro
					local statusLabel = Instance.new("TextLabel", popup)
					statusLabel.Size = UDim2.new(1, 0, 0, 12)
					statusLabel.BackgroundTransparency = 1
					statusLabel.Text = active and "✅ Unlocked" or "🔒 Locked"
					statusLabel.TextColor3 = active and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120)
					statusLabel.Font = Enum.Font.GothamBold
					statusLabel.TextSize = 7
					statusLabel.ZIndex = 11
					
					-- Bouton fermer micro
					local closeButton = Instance.new("TextButton", popup)
					closeButton.Size = UDim2.new(1, 0, 0, 18)
					closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
					closeButton.Text = "Close"
					closeButton.TextColor3 = Color3.new(1, 1, 1)
					closeButton.Font = Enum.Font.GothamBold
					closeButton.TextSize = 7
					closeButton.ZIndex = 11
					local closeCorner = Instance.new("UICorner", closeButton)
					closeCorner.CornerRadius = UDim.new(0, 3)
					
					closeButton.MouseButton1Click:Connect(function()
						print("🗑️ [PASSIVE] Fermeture popup (bouton)")
						popupBg:Destroy()
					end)
					
					-- Animation d'apparition
					popup.Size = UDim2.new(0, 0, 0, 0)
					popup.BackgroundTransparency = 1
					
					local tween = game:GetService("TweenService"):Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.new(0, 120, 0, 120),
						BackgroundTransparency = 0
					})
					tween:Play()
					
					print("✅ [PASSIVE] Popup créé et animé")
				end)
		end
	end

	renderHUD()

	-- Watcher dynamique: toute modif sur ShopUnlocks rafraîchit la barre
	task.spawn(function()
		local pd = player:WaitForChild("PlayerData")
		local su = pd:FindFirstChild("ShopUnlocks")
		if not su then
			pd.ChildAdded:Connect(function(ch)
				if ch.Name == "ShopUnlocks" then
					renderHUD()
					ch.ChildAdded:Connect(renderHUD)
					ch.ChildRemoved:Connect(renderHUD)
					for _, c in ipairs(ch:GetChildren()) do
						if c:IsA("BoolValue") then
							c:GetPropertyChangedSignal("Value"):Connect(renderHUD)
						end
					end
				end
			end)
		else
			su.ChildAdded:Connect(renderHUD)
			su.ChildRemoved:Connect(renderHUD)
			for _, c in ipairs(su:GetChildren()) do
				if c:IsA("BoolValue") then
					c:GetPropertyChangedSignal("Value"):Connect(renderHUD)
				end
			end
		end
	end)
end