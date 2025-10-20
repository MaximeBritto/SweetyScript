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

	return screenGui, container, textLabel, subLabel
end

local function destroyOverlay(screenGui, container, textLabel, subLabel)
	if not screenGui or not screenGui.Parent then return end
	pcall(function()
		TweenService:Create(container, TweenInfo.new(FADE_DURATION), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(textLabel, TweenInfo.new(FADE_DURATION), { TextTransparency = 1 }):Play()
		if subLabel then
			TweenService:Create(subLabel, TweenInfo.new(FADE_DURATION), { TextTransparency = 1 }):Play()
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
		return
	end

	local overlayGui, container, label, hint = createLoadingOverlay()

	local ready = false

	-- 1) Listen to DataReady attribute
	local attributeConn
	attributeConn = localPlayer.AttributeChanged:Connect(function(attrName)
		if attrName == "DataReady" and areDataReady() and not ready then
			ready = true
			if attributeConn then attributeConn:Disconnect() end
			destroyOverlay(overlayGui, container, label, hint)
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
					destroyOverlay(overlayGui, container, label, hint)
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
			destroyOverlay(overlayGui, container, label, hint)
		end
	end)
end


