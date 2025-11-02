-- Ce script (local) affiche l'argent à côté de la hotbar
-- VERSION V0.5 : Interface argent simplifiée positionnée près de la hotbar
-- À placer dans ScreenGui

-- Services nécessaires
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- 🔧 ATTENDRE QUE LES DONNÉES SOIENT PRÊTES (avec timeout court)
print("⏳ [UIMANAGER] Attente des données du joueur...")
local dataReady = false
local maxWaitTime = 5

-- Vérifier d'abord si déjà prêt
if player:GetAttribute("DataReady") == true then
	dataReady = true
	print("✅ [UIMANAGER] Données déjà prêtes")
end

-- Si pas encore prêt, attendre avec timeout court
if not dataReady then
	local dataReadyEvent = ReplicatedStorage:FindFirstChild("PlayerDataReady")
	if dataReadyEvent then
		local connection
		connection = dataReadyEvent.OnClientEvent:Connect(function()
			dataReady = true
			if connection then connection:Disconnect() end
		end)
		
		local elapsed = 0
		while not dataReady and elapsed < maxWaitTime do
			task.wait(0.1)
			elapsed = elapsed + 0.1
			if player:GetAttribute("DataReady") == true then
				dataReady = true
				break
			end
		end
		
		if connection then connection:Disconnect() end
	else
		local elapsed = 0
		while not dataReady and elapsed < maxWaitTime do
			task.wait(0.1)
			elapsed = elapsed + 0.1
			if player:GetAttribute("DataReady") == true then
				dataReady = true
				break
			end
		end
	end
end

if not dataReady then
	warn("⚠️ [UIMANAGER] Timeout - Chargement forcé")
end

print("✅ [UIMANAGER] Chargement de l'interface...")

local playerData = player:WaitForChild("PlayerData")

-- === DONNÉES ===
local argent = playerData:WaitForChild("Argent")

-- On trouve les labels dans le ScreenGui
local screenGui = script.Parent

-- Mettre un DisplayOrder bas pour passer derrière le SellUI
if screenGui and screenGui:IsA("ScreenGui") then
	screenGui.DisplayOrder = 100 -- Plus bas que SellUI (1000)
end

-- Détection de la plateforme pour positionnement responsive
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Créer le badge d'argent avec image
local argentBadge = screenGui:FindFirstChild("ArgentBadge")
local argentLabel
if not argentBadge then
	-- Badge avec image de fond
	argentBadge = Instance.new("ImageLabel")
	argentBadge.Name = "ArgentBadge"
	argentBadge.Image = "rbxassetid://96025136046990" -- Ton image
	argentBadge.BackgroundTransparency = 1
	argentBadge.BorderSizePixel = 0
	argentBadge.ScaleType = Enum.ScaleType.Fit

	-- Taille et position responsive à gauche de l'écran, centré verticalement
	if isMobile or isSmallScreen then
		-- Mobile : à gauche de l'écran, centré au milieu
		argentBadge.Size = UDim2.new(0, 150, 0, 60)
		argentBadge.Position = UDim2.new(0, 10, 0.5, 0) -- Ancré à gauche avec 10px de marge
		argentBadge.AnchorPoint = Vector2.new(0, 0.5) -- Ancre en haut-gauche et centre vertical
	else
		-- Desktop : à gauche de l'écran, centré au milieu (taille augmentée)
		argentBadge.Size = UDim2.new(0, 280, 0, 110)
		argentBadge.Position = UDim2.new(0, 10, 0.5, 0) -- Ancré à gauche avec 10px de marge
		argentBadge.AnchorPoint = Vector2.new(0, 0.5) -- Ancre en haut-gauche et centre vertical
	end

	argentBadge.Parent = screenGui

	-- TextLabel pour afficher le montant (à l'intérieur de l'image)
	argentLabel = Instance.new("TextLabel")
	argentLabel.Name = "ArgentLabel"
	argentLabel.Size = UDim2.new(1, 0, 1, 0)
	argentLabel.Position = UDim2.new(0.5, 15, 0.5, 0) -- Décalé de 15px vers la droite
	argentLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	argentLabel.BackgroundTransparency = 1
	argentLabel.BorderSizePixel = 0
	argentLabel.Text = "0"
	argentLabel.TextColor3 = Color3.fromRGB(245, 222, 179) -- Beige (wheat color)
	argentLabel.TextSize = (isMobile or isSmallScreen) and 20 or 32
	argentLabel.Font = Enum.Font.GothamBold
	argentLabel.TextXAlignment = Enum.TextXAlignment.Center
	argentLabel.TextYAlignment = Enum.TextYAlignment.Center
	argentLabel.TextScaled = false
	argentLabel.Parent = argentBadge
else
	argentLabel = argentBadge:FindFirstChild("ArgentLabel")
end

-- Bouton d'aide suffixes ("?") à côté de l'UI d'argent et panneau d'explication
local helpButton = argentBadge:FindFirstChild("HelpButton")
local richnessPanel = screenGui:FindFirstChild("RichnessPanel")

if not helpButton then
	helpButton = Instance.new("TextButton")
	helpButton.Name = "HelpButton"
	helpButton.BackgroundTransparency = 0.2
	helpButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	helpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	helpButton.Font = Enum.Font.GothamBold
	helpButton.Text = "?"
	helpButton.AutoButtonColor = true
	helpButton.BorderSizePixel = 0
	-- Taille/position: petit badge en haut-droite du badge d'argent
	helpButton.Size = (isMobile or isSmallScreen) and UDim2.new(0, 22, 0, 22) or UDim2.new(0, 28, 0, 28)
	helpButton.Position = UDim2.new(1, -((isMobile or isSmallScreen) and 26 or 32), 0, ((isMobile or isSmallScreen) and 4 or 6))
	helpButton.AnchorPoint = Vector2.new(0, 0)
	helpButton.ZIndex = 1

	local hbCorner = Instance.new("UICorner")
	hbCorner.CornerRadius = UDim.new(0, 6)
	hbCorner.Parent = helpButton

	helpButton.Parent = argentBadge
end

if not richnessPanel then
	richnessPanel = Instance.new("Frame")
	richnessPanel.Name = "RichnessPanel"
	richnessPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	richnessPanel.BackgroundTransparency = 0.1
	richnessPanel.BorderSizePixel = 0
	-- Positionner près du badge d'argent, à droite si possible
	local panelWidth = (isMobile or isSmallScreen) and 220 or 280
	local panelHeight = (isMobile or isSmallScreen) and 260 or 320
	richnessPanel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
	-- Par défaut, à côté du badge, en décalant un peu vers la droite
	richnessPanel.Position = UDim2.new(0, argentBadge.AbsolutePosition.X + argentBadge.AbsoluteSize.X + 10, 0, math.max(10, argentBadge.AbsolutePosition.Y - 20))
	richnessPanel.AnchorPoint = Vector2.new(0, 0)
	richnessPanel.Visible = false
	richnessPanel.ZIndex = 1001

	local rpCorner = Instance.new("UICorner")
	rpCorner.CornerRadius = UDim.new(0, 8)
	rpCorner.Parent = richnessPanel

	local rpStroke = Instance.new("UIStroke")
	rpStroke.Thickness = 2
	rpStroke.Color = Color3.fromRGB(66, 103, 38)
	rpStroke.Transparency = 0
	rpStroke.Parent = richnessPanel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -40, 0, 34)
	titleLabel.Position = UDim2.new(0, 12, 0, 8)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = (isMobile or isSmallScreen) and 16 or 18
	titleLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Money Details"
	titleLabel.ZIndex = 1002
	titleLabel.Parent = richnessPanel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.BackgroundTransparency = 0.2
	closeButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	closeButton.Size = UDim2.new(0, 28, 0, 28)
	closeButton.Position = UDim2.new(1, -34, 0, 8)
	closeButton.AnchorPoint = Vector2.new(0, 0)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.ZIndex = 1002
	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 6)
	cbCorner.Parent = closeButton
	closeButton.Parent = richnessPanel

	local list = Instance.new("ScrollingFrame")
	list.Name = "SuffixList"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -24, 1, -54)
	list.Position = UDim2.new(0, 12, 0, 44)
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ZIndex = 1001
	list.Parent = richnessPanel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function addEntry(leftText, rightText)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 0.2
		row.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, (isMobile or isSmallScreen) and 24 or 28)
		row.ZIndex = 1001

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0.4, -8, 1, 0)
		l.Position = UDim2.new(0, 8, 0, 0)
		l.Font = Enum.Font.GothamBold
		l.TextSize = (isMobile or isSmallScreen) and 14 or 16
		l.TextColor3 = Color3.fromRGB(255, 255, 255)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = leftText
		l.ZIndex = 1001
		l.Parent = row

		local r = Instance.new("TextLabel")
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(0.6, -8, 1, 0)
		r.Position = UDim2.new(0.4, 0, 0, 0)
		r.Font = Enum.Font.Gotham
		r.TextSize = (isMobile or isSmallScreen) and 14 or 16
		r.TextColor3 = Color3.fromRGB(220, 220, 220)
		r.TextXAlignment = Enum.TextXAlignment.Left
		r.Text = rightText
		r.ZIndex = 1001
		r.Parent = row

		row.Parent = list
	end

	-- Contenu de la table des suffixes (principaux + étendus)
	local entries = {
		{"1k", "1 000"},
		{"1m", "1 000 000 (1 million)"},
		{"1b", "1 000 000 000 (1 milliard)"},
		{"1t", "1 000 000 000 000 (1 billion)"},
		{"1qa", "10^15"},
		{"1qi", "10^18"},
		{"1sx", "10^21"},
		{"1sp", "10^24"},
		{"1oc", "10^27"},
		{"1no", "10^30"},
		{"1de", "10^33"},
		{"1ud", "10^36"},
		{"1dd", "10^39"},
		{"1td", "10^42"},
		{"1qd", "10^45"},
		{"1qid", "10^48"},
		{"1sd", "10^51"},
		{"1spd", "10^54"},
		{"1od", "10^57"},
		{"1nd", "10^60"},
		{"1vg", "10^63"},
		{"1uvg", "10^66"}
	}

	for _, e in ipairs(entries) do
		addEntry(e[1], e[2])
	end

	-- Ajuster la CanvasSize selon le contenu
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
	end)

	richnessPanel.Parent = screenGui

	-- Boutons: fermer
	closeButton.Activated:Connect(function()
		richnessPanel.Visible = false
	end)
end

-- Toggle du panneau via le bouton d'aide
if helpButton then
	helpButton.Activated:Connect(function()
		-- Repositionner près du badge au moment de l'ouverture (caméra/écran peuvent changer)
		if richnessPanel then
			local x = argentBadge.AbsolutePosition.X + argentBadge.AbsoluteSize.X + 10
			local y = math.max(10, argentBadge.AbsolutePosition.Y - 20)
			richnessPanel.Position = UDim2.new(0, x, 0, y)
			richnessPanel.Visible = not richnessPanel.Visible
			richnessPanel.ZIndex = 1001
		end
	end)
end

-- Fonction pour mettre à jour l'affichage de l'argent
local function updateArgentUI()
	local UIUtils = nil
	local uiMod = ReplicatedStorage:FindFirstChild("UIUtils")
	if uiMod and uiMod:IsA("ModuleScript") then
		local ok, mod = pcall(require, uiMod)
		if ok then UIUtils = mod end
	end
	local v = argent.Value
	-- Afficher juste le chiffre sans le "$"
	if UIUtils and UIUtils.formatMoneyShort then
		argentLabel.Text = UIUtils.formatMoneyShort(v)
	else
		argentLabel.Text = tostring(v)
	end
end

-- Nettoyer les anciens labels s'ils existent
if screenGui:FindFirstChild("HudFrame") then screenGui.HudFrame:Destroy() end
if screenGui:FindFirstChild("BonbonsLabel") then screenGui.BonbonsLabel:Destroy() end
if screenGui:FindFirstChild("ProductionLabel") then screenGui.ProductionLabel:Destroy() end
if screenGui:FindFirstChild("StockLabel") then screenGui.StockLabel:Destroy() end
if screenGui:FindFirstChild("IngredientsLabel") then screenGui.IngredientsLabel:Destroy() end
-- Nettoyer l'ancien ArgentLabel (remplacé par ArgentBadge)
local oldArgentLabel = screenGui:FindFirstChild("ArgentLabel")
if oldArgentLabel and oldArgentLabel ~= argentLabel then
	oldArgentLabel:Destroy()
end

-- On met à jour l'affichage de l'argent une première fois au démarrage
updateArgentUI()

-- Son de gain d'argent (configurable)
local function playMoneyGainSound()
	local baseSound = SoundService:FindFirstChild("MoneyGain")
	local sound
	if baseSound and baseSound:IsA("Sound") then
		sound = baseSound:Clone()
	else
		local cfg = ReplicatedStorage:FindFirstChild("MoneyGainSoundId")
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

-- On met à jour l'affichage chaque fois que l'argent change
local lastArgentValue = argent.Value
argent.Changed:Connect(function(newValue)
	updateArgentUI()
	if typeof(newValue) == "number" and typeof(lastArgentValue) == "number" then
		if newValue > lastArgentValue then
			task.spawn(playMoneyGainSound)
		end
	end
	lastArgentValue = newValue
end)

print("✅ UIManager v1.0 (Badge argent avec image) chargé !") 