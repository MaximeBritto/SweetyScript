--------------------------------------------------------------------
-- IslandManager.lua – îles orientées vers le hub, enclos face au hub
--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local CUSTOM_ISLAND_NAME = "MyCustomIsland"   -- modèle dans ReplicatedStorage
local PARCEL_TEMPLATE_NAME = "ParcelTemplate" -- NOUVEAU: modèle pour la parcelle
local MAX_ISLANDS        = 6
local HUB_CENTER         = Vector3.new(0, 1, 0)
local RADIUS             = 130               -- distance du hub

-- Parcels
local PARCELS_PER_ISLAND = 3
-- Les tailles sont maintenant définies par le modèle ParcelTemplate

--------------------------------------------------------------------
-- TABLES
--------------------------------------------------------------------
local islandPlots    = {}   -- slot → Model
local unclaimedSlots = {}   -- slots libres

--------------------------------------------------------------------
-- ARCHE
--------------------------------------------------------------------
local function createArche(parent, slot, hubPos, islandPos)
	local m = Instance.new("Model", parent)
	m.Name = "Arche_" .. slot

	local dir  = (islandPos - hubPos).Unit
	local pos  = hubPos + dir * 70
	local base = CFrame.new(pos, islandPos)

	local function pilier(dx)
		local p = Instance.new("Part", m)
		p.Size = Vector3.new(4, 20, 4)
		p.Anchored = true
		p.Material = Enum.Material.Wood
		p.Color    = Color3.fromRGB(139, 90, 43)
		p.CFrame   = base * CFrame.new(dx, 10, 0)
	end
	pilier(-10); pilier(10)

	local beam = Instance.new("Part", m)
	beam.Size = Vector3.new(24, 4, 4)
	beam.Anchored = true
	beam.Material = Enum.Material.Wood
	beam.Color    = Color3.fromRGB(139, 90, 43)
	beam.CFrame   = base * CFrame.new(0, 22, 0)

	local tag = Instance.new("BillboardGui", m)
	tag.Name        = "NameTag"
	tag.Size        = UDim2.new(0, 200, 0, 50)
	tag.Adornee     = beam
	tag.AlwaysOnTop = true
	tag.StudsOffset = Vector3.new(0, 6, 0)

	local lbl = Instance.new("TextLabel", tag)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.SourceSansBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Text = "Libre"
end

--------------------------------------------------------------------
-- CONFIGURATION D'UNE PARCELLE (depuis un modèle)
--------------------------------------------------------------------
local function setupParcel(parcelModel, parent, idx, center)
	parcelModel.Name = "Parcel_" .. idx
	parcelModel.Parent = parent

	-- Pivoter la parcelle pour qu'elle fasse face au hub
	local lookAtCFrame = CFrame.lookAt(center, HUB_CENTER)
	parcelModel:PivotTo(lookAtCFrame * CFrame.Angles(0, math.rad(180), 0))

	-- Trouver l'incubateur dans le modèle
	local inc = parcelModel:FindFirstChild("Incubator", true)
	if not inc then
		warn("⚠️ Incubateur non trouvé dans le modèle de parcelle : " .. parcelModel:GetFullName())
		return
	end

	-- S'assurer que l'incubateur est bien une BasePart pour le ProximityPrompt
	if not inc:IsA("BasePart") then
		inc = inc:IsA("Model") and inc.PrimaryPart or inc:FindFirstChildWhichIsA("BasePart")
		if not inc then
			warn("⚠️ L'incubateur dans ".. parcelModel:GetFullName() .." n'a pas de Part principale valide pour le ProximityPrompt.")
			return
		end
	end
	
	-- ID + Prompt
	local idVal = Instance.new("StringValue", inc)
	idVal.Name  = "ParcelID"
	idVal.Value = parent.Name .. "_" .. idx

	local prompt = Instance.new("ProximityPrompt", inc)
	prompt.ActionText = "Start"
	prompt.ObjectText = "Incubateur"
	prompt.RequiresLineOfSight = false

	local openEvt = ReplicatedStorage:WaitForChild("OpenIncubatorMenu")
	prompt.Triggered:Connect(function(plr)
		print("🖱️ Incubateur cliqué par", plr.Name, "- ID:", idVal.Value)
		openEvt:FireClient(plr, idVal.Value)
		print("📡 Signal envoyé au client!")
	end)
end

--------------------------------------------------------------------
-- GÉNÉRATION MONDE (îles orientées vers le hub)
--------------------------------------------------------------------
local function generateWorld()
	local islandTemplate = ReplicatedStorage:FindFirstChild(CUSTOM_ISLAND_NAME)
	assert(islandTemplate and islandTemplate:IsA("Model") and islandTemplate.PrimaryPart,
		"⚠️  Modèle d'île ou PrimaryPart manquant pour "..CUSTOM_ISLAND_NAME)

	local parcelTemplate = ReplicatedStorage:FindFirstChild(PARCEL_TEMPLATE_NAME)
	assert(parcelTemplate and parcelTemplate:IsA("Model") and parcelTemplate.PrimaryPart,
		"⚠️  Modèle de parcelle ou PrimaryPart manquant pour "..PARCEL_TEMPLATE_NAME)

	for slot = 1, MAX_ISLANDS do
		local container = Instance.new("Model", Workspace)
		container.Name  = "Ile_Slot_" .. slot

		local ile = islandTemplate:Clone()
		ile.Parent = container

		-- Position circulaire (on laisse l'île dans son orientation originale)
		local ang  = (2 * math.pi / MAX_ISLANDS) * (slot - 1)
		local pos  = HUB_CENTER + Vector3.new(RADIUS * math.cos(ang), 0, RADIUS * math.sin(ang))
		ile:PivotTo(ile:GetPivot() + (pos - ile:GetPivot().Position))

		-- Pont
		local pont = Instance.new("Part", container)
		pont.Size      = Vector3.new(15, 0.5, 95)
		pont.Anchored  = true
		pont.Material  = Enum.Material.WoodPlanks
		pont.Color     = Color3.fromRGB(163, 116, 82)
		pont.CFrame    = CFrame.new(HUB_CENTER + (pos - HUB_CENTER) * 0.5, pos)
			* CFrame.new(0, 0, -47.5)

		-- Arche + Parcels (maintenant depuis un template)
		createArche(container, slot, HUB_CENTER, pos)
		for p = 1, PARCELS_PER_ISLAND do
			-- Angle local de la parcelle par rapport au centre de l'île
			local localTheta = math.rad(120 / (PARCELS_PER_ISLAND - 1) * (p - 1) - 60)
			-- Angle de l'île par rapport au hub (pour orienter les parcelles correctement)
			local islandAngle = math.atan2(pos.Z - HUB_CENTER.Z, pos.X - HUB_CENTER.X)
			-- Angle final : angle de l'île + angle local pour mettre les parcelles du côté du hub
			local finalTheta = islandAngle + localTheta
			local offset = Vector3.new(35 * math.cos(finalTheta), 0, 35 * math.sin(finalTheta))
			-- Position mondiale réelle de la parcelle
			local parcelWorldPos = pos + offset
			
			local parcelClone = parcelTemplate:Clone()
			setupParcel(parcelClone, container, p, parcelWorldPos)
		end

		islandPlots[slot] = container
		table.insert(unclaimedSlots, slot)
	end
	print("🌴 Monde généré — parcelles créées depuis le modèle : " .. PARCEL_TEMPLATE_NAME)
end

--------------------------------------------------------------------
-- FONCTIONS PUBLIQUES POUR LES EVENTS
--------------------------------------------------------------------
local function getIslandBySlot(slot)
	return islandPlots[slot]
end

local function getAllIslands()
	return islandPlots
end

-- Exposer les fonctions pour l'EventMapManager
_G.IslandManager = {
	getIslandBySlot = getIslandBySlot,
	getAllIslands = getAllIslands,
	getMaxIslands = function() return MAX_ISLANDS end
}

--------------------------------------------------------------------
-- ATTRIBUTION / LIBÉRATION
--------------------------------------------------------------------
local function onPlayerAdded(plr)
	local slot = table.remove(unclaimedSlots, 1)
	if not slot then warn("Serveur plein") return end
	plr:SetAttribute("IslandSlot", slot)

	local ile = islandPlots[slot]
	ile.Name  = "Ile_" .. plr.Name

	local spawn = ile:FindFirstChild("SpawnLocation", true)
	if spawn then
		plr.RespawnLocation = spawn
		plr.CharacterAdded:Connect(function(char)
			task.wait(0.5)
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0) end
		end)
	end

	local arche = ile:FindFirstChild("Arche_" .. slot)
	if arche then
		arche.Name = "Arche_" .. plr.Name
		local lbl = arche:FindFirstChild("NameTag", true)
			and arche.NameTag:FindFirstChild("TextLabel")
		if lbl then lbl.Text = plr.Name end
	end
end

local function onPlayerRemoving(plr)
	local slot = plr:GetAttribute("IslandSlot")
	if not slot then return end
	local ile = Workspace:FindFirstChild("Ile_" .. plr.Name)
	if ile then
		ile.Name = "Ile_Slot_" .. slot
		local arche = ile:FindFirstChild("Arche_" .. plr.Name)
		if arche then
			arche.Name = "Arche_" .. slot
			local lbl = arche:FindFirstChild("NameTag", true)
				and arche.NameTag:FindFirstChild("TextLabel")
			if lbl then lbl.Text = "Libre" end
		end
	end
	table.insert(unclaimedSlots, slot)
end

--------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------
generateWorld()
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("🏝️ IslandManager prêt — îles orientées vers hub, enclos face hub.")
