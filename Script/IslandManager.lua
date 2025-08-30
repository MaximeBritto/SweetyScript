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
local PLATFORM_TEMPLATE_NAME = "Platform"     -- NOUVEAU: modèle pour les plateformes
local BARRIER_TEMPLATE_NAME = "barriereModel" -- optionnel: modèle de barrière décorative (MeshPart)
local MAX_ISLANDS        = 6
local HUB_CENTER         = Vector3.new(0, 1, 0)
local RADIUS             = 190               -- distance du hub

-- Parcels
local PARCELS_PER_ISLAND = 3
-- Les tailles sont maintenant définies par le modèle ParcelTemplate

-- Plateformes (configuration automatique des plateformes existantes)
local _PLATFORM_ARC_RADIUS = 25   -- rayon de l'arc où poser les plateformes (unused)
local _PLATFORM_HEIGHT     = 2    -- hauteur relative (unused)
local PLATFORM_EDGE_INSET  = 3    -- réduit le rayon des plateformes (avancées vers le centre)

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
	lbl.Text = "Empty"
end

--------------------------------------------------------------------
-- CONFIGURATION D'UNE PLATEFORME EXISTANTE ORIENTÉE VERS LE CENTRE
--------------------------------------------------------------------
local function setupExistingPlatform(platform, islandCenter)
	-- Orienter la plateforme vers le centre de l'île (comme les parcelles vers le hub)
	local currentPos = platform.Position
	local lookAtCFrame = CFrame.lookAt(currentPos, islandCenter)
	platform.CFrame = lookAtCFrame

	-- Optionnel : Appliquer le style (vous pouvez commenter si vous voulez garder votre style)
	-- platform.Material = Enum.Material.Neon
	-- platform.BrickColor = BrickColor.new("Bright blue")

	print("🏭 [DEBUG] Plateforme configurée:", platform.Name, "à", currentPos, "orientée vers", islandCenter)
end

--------------------------------------------------------------------
-- CONFIGURATION D'UNE PARCELLE (depuis un modèle)
--------------------------------------------------------------------
local function setupParcel(parcelModel, parent, idx, center)
	parcelModel.Name = "Parcel_" .. idx
	parcelModel.Parent = parent

	-- Pivoter la parcelle pour qu'elle fasse face au hub avec rotation vers le centre pour les latéraux
	local rotationOffset = 0
	-- Les incubateurs latéraux (gauche et droite) tournent vers le centre de l'île (~40°)
	if idx == 1 then rotationOffset = math.rad(40) -- Incubateur gauche: +40° vers le centre
	elseif idx == 3 then rotationOffset = math.rad(-40) -- Incubateur droite: -40° vers le centre
	end
	local lookAtCFrame = CFrame.lookAt(center, HUB_CENTER)
	parcelModel:PivotTo(lookAtCFrame * CFrame.Angles(0, math.rad(180) + rotationOffset, 0))

	-- Trouver l'incubateur dans le modèle (support Model ou MeshPart)
	local function findIncubatorPart(root: Instance)
		-- 1) Nom standard "Incubator"
		local obj = root:FindFirstChild("Incubator", true)
		if obj then
			if obj:IsA("BasePart") then return obj end
			if obj:IsA("Model") then
				return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
			end
		end
		-- 2) Nom alternatif "IncubatorMesh"
		obj = root:FindFirstChild("IncubatorMesh", true)
		if obj then
			if obj:IsA("BasePart") then return obj end
			if obj:IsA("Model") then
				return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
			end
		end
		-- 3) Chercher un BasePart contenant des ancres d'ingrédients ou un CandySpawn
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if descendant:FindFirstChild("IngredientAnchors")
					or descendant:FindFirstChild("IngredientPoints")
					or descendant:FindFirstChild("CandySpawn")
				then
					return descendant
				end
			end
		end
		-- 4) Dernier recours: un BasePart dont le nom contient "Incubator"
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "incubator") then
				return descendant
			end
		end
		return nil
	end

	local inc = findIncubatorPart(parcelModel)
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
	prompt.ObjectText = "Incubator"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 30 

	local openEvt = ReplicatedStorage:WaitForChild("OpenIncubatorMenu")
	prompt.Triggered:Connect(function(plr)
		print("🖱️ Incubateur cliqué par", plr.Name, "- ID:", idVal.Value)
		-- Vérifier que le joueur est bien le propriétaire de l'île contenant cet incubateur
		local isOwner = false
		local container = parcelModel
		while container and container.Parent do
			if container:IsA("Model") and (container.Name:match("^Ile_") or container.Name:match("^Ile_Slot_")) then
				break
			end
			container = container.Parent
		end
		if container then
			local pname = container.Name:match("^Ile_(.+)$")
			if pname and not pname:match("^Slot_") then
				isOwner = (plr.Name == pname)
			else
				local slotN = container.Name:match("Slot_(%d+)")
				if slotN then
					local attr = plr:GetAttribute("IslandSlot")
					isOwner = (attr and tostring(attr) == tostring(slotN)) or false
				end
			end
		end
		if not isOwner then
			warn("⛔ Accès refusé au menu incubateur pour ", plr.Name)
			return
		end

		-- Système de déblocage: n'autoriser que le premier incubateur si non débloqué
		local pd = plr:FindFirstChild("PlayerData")
		local iu = pd and pd:FindFirstChild("IncubatorsUnlocked")
		local unlocked = iu and iu.Value or 1
		-- Extraire l'index de parcelle (1,2,3) à partir de l'ID "Ile_<Name>_<idx>" ou "Ile_Slot_X_<idx>"
		local parcelIdx = tonumber(string.match(idVal.Value or "", "_(%d+)$")) or 1
		if parcelIdx > unlocked then
			-- Incubateur verrouillé: laisser le client afficher l'UI d'unlock
			prompt.ObjectText = "Incubator (Locked)"
			prompt.ActionText = "Unlock"
			-- Ne pas acheter directement ici; on ouvre le menu côté client pour choisir ($ ou Robux)
		end
		-- Notifier le tutoriel que l'incubateur est utilisé (pour avancer de phase)
		if _G and _G.TutorialManager and _G.TutorialManager.onIncubatorUsed then
			pcall(function()
				_G.TutorialManager.onIncubatorUsed(plr)
			end)
		end
		openEvt:FireClient(plr, idVal.Value)
		print("📡 Signal envoyé au client!")
	end)
end

--------------------------------------------------------------------
-- MUR INVISIBLE AUTOUR DE L'ÎLE avec ouverture côté HUB
--------------------------------------------------------------------
local function createInvisibleBoundary(container: Instance, islandCenter: Vector3, groundPart: BasePart?, edgeRadius: number, forward: Vector3, right: Vector3, barrierTemplate: Instance?)
	-- Dimensions du mur
	local THICKNESS = 3
	local HEIGHT    = 24
	-- Ouverture (porte) alignée au pont (côté HUB)
	local BRIDGE_WIDTH = 15
	local GAP = BRIDGE_WIDTH + 4 -- petit marge pour bien passer
	-- Décalage vertical global (négatif pour descendre les murs)
	local Y_OFFSET = -93.5

	local totalLen = math.max(4, edgeRadius * 2)
	local gap = math.clamp(GAP, 4, totalLen - 2)
	local halfLen = (totalLen - gap) * 0.5
	if halfLen < 1 then
		-- île trop petite, on ne place pas de mur
		return
	end

	-- Calcul de la hauteur au-dessus du sol
	local baseY
	if groundPart and groundPart:IsA("BasePart") then
		baseY = groundPart.Position.Y + (groundPart.Size.Y * 0.5)
	else
		baseY = islandCenter.Y
	end
	-- Placer le pied du mur au niveau du sol (baseY), puis appliquer un offset global
	-- centerY = baseY + HEIGHT/2 + Y_OFFSET
	local centerY = baseY + (HEIGHT * 0.5) + Y_OFFSET

	local function wall(parent: Instance, center: Vector3, lookDir: Vector3, length: number)
		local p = Instance.new("Part")
		p.Name = "BoundaryWall"
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.CastShadow = false
		p.Size = Vector3.new(THICKNESS, HEIGHT, length)
		p.CFrame = CFrame.lookAt(Vector3.new(center.X, centerY, center.Z), Vector3.new(center.X, centerY, center.Z) + lookDir)
		p.Parent = parent
		return p
	end

	local model = Instance.new("Model")
	model.Name = "Boundary"
	model.Parent = container

	-- Parents pour la barrière décorative
	local barrierParent
	if barrierTemplate then
		barrierParent = Instance.new("Model")
		barrierParent.Name = "Barrier"
		barrierParent.Parent = container
	end

	-- Vecteurs unitaires
	local f = forward.Unit               -- du hub vers l'île
	local entranceDir = (-f).Unit        -- de l'île vers le hub (ouverture)

	-- Anneau de murs segmentés (approximation d'un cercle)
	local R_OFFSET = 1.0                      -- agrandit légèrement le rayon
	local R = math.max(2, edgeRadius + R_OFFSET)
	local targetSegLen = 6                   -- longueur visée par segment (arc)
	local circumference = 2 * math.pi * R
	local segCount = math.max(16, math.floor(circumference / targetSegLen + 0.5))
	segCount = math.min(segCount, 96)
	local dTheta = (2 * math.pi) / segCount

	-- Largeur angulaire de l'ouverture (gap converti en angle)
	local gapAngle = math.clamp(gap / R, dTheta, math.rad(90))

	local function angleOf(v: Vector3)
		return math.atan2(v.Z, v.X)
	end
	local entranceAngle = angleOf(entranceDir)
	local function angleDiff(a, b)
		local d = math.atan2(math.sin(a - b), math.cos(a - b))
		return math.abs(d)
	end

	for i = 0, segCount - 1 do
		local theta = i * dTheta
		-- Centre du segment sur le cercle
		local dir = Vector3.new(math.cos(theta), 0, math.sin(theta)) -- radial
		local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta)) -- tangente

		-- Sauter les segments qui chevauchent l'ouverture côté hub
		if angleDiff(theta, entranceAngle) > (gapAngle * 0.5) then
			local segCenter = islandCenter + dir * R
			local chord = 2 * R * math.sin(dTheta * 0.5)
			local length = math.max(2, chord + 0.1) -- léger chevauchement
			wall(model, segCenter, tangent, length)

			-- Optionnel: barrière décorative (MeshPart) placée régulièrement
			if barrierParent and barrierTemplate then
				local PLACE_EVERY = 2 -- 1 = chaque segment, 2 = un sur deux
				if (i % PLACE_EVERY) == 0 then
					local clone = barrierTemplate:Clone()
					if clone:IsA("BasePart") then
						clone.Anchored = true
						clone.CanCollide = false
						clone.CanQuery = false
						clone.CanTouch = false
						local bSizeY = clone.Size.Y
						local bPos = islandCenter + dir * R
						local bY = baseY + Y_OFFSET + (bSizeY * 0.5) -- aligné au pied du mur invisible
						clone.CFrame = CFrame.lookAt(Vector3.new(bPos.X, bY, bPos.Z), Vector3.new(bPos.X, bY, bPos.Z) + tangent) * CFrame.Angles(0, math.rad(90), 0)
						clone.Parent = barrierParent
					else
						-- Si c'est un Model, tenter un placement basique via Pivot
						local pivotPos = islandCenter + dir * R
						local look = CFrame.lookAt(Vector3.new(pivotPos.X, baseY + Y_OFFSET, pivotPos.Z), Vector3.new(pivotPos.X, baseY + Y_OFFSET, pivotPos.Z) + tangent) * CFrame.Angles(0, math.rad(90), 0)
						pcall(function()
							clone:PivotTo(look)
							clone.Parent = barrierParent
						end)
					end
				end
			end
		end
	end
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

	local platformTemplate = ReplicatedStorage:FindFirstChild(PLATFORM_TEMPLATE_NAME)
	assert(platformTemplate and platformTemplate:IsA("Model"),
		"⚠️  Modèle de plateformes manquant pour "..PLATFORM_TEMPLATE_NAME)
	local barrierTemplate = ReplicatedStorage:FindFirstChild(BARRIER_TEMPLATE_NAME)
	if not barrierTemplate then
		warn("⚠️ Modèle de barrière optionnel introuvable: " .. BARRIER_TEMPLATE_NAME)
	end

	for slot = 1, MAX_ISLANDS do
		local container = Instance.new("Model", Workspace)
		container.Name  = "Ile_Slot_" .. slot

		local ile = islandTemplate:Clone()
		ile.Parent = container

		-- Position circulaire (on laisse l'île dans son orientation originale)
		local ang  = (2 * math.pi / MAX_ISLANDS) * (slot - 1)
		local pos  = HUB_CENTER + Vector3.new(RADIUS * math.cos(ang), 0, RADIUS * math.sin(ang))
		ile:PivotTo(ile:GetPivot() + (pos - ile:GetPivot().Position))

		-- Calcul du rayon effectif de l'île (pour placer les plateformes à l'extrémité)
		local solPart = ile:FindFirstChild("sol", true)
		local islandRadius = 30
		if solPart and solPart:IsA("BasePart") then
			islandRadius = math.max(solPart.Size.X, solPart.Size.Z) * 0.5
		end
		local EDGE_MARGIN = 3
		local edgeRadius = math.max(4, islandRadius - EDGE_MARGIN)

		-- Déterminer le centre d'orientation des plateformes
		local centerCandidate = ile:FindFirstChild("PlatformCenter", true)
			or ile:FindFirstChild("IslandCenter", true)
			or ile:FindFirstChild("Center", true)
		local centerPos
		if centerCandidate then
			if centerCandidate:IsA("BasePart") then centerPos = centerCandidate.Position else centerPos = centerCandidate:GetPivot().Position end
		else
			centerPos = pos
		end

		-- Vecteurs d'orientation de l'île
		local forward = (pos - HUB_CENTER).Unit      -- du hub vers l'île
		local right   = Vector3.new(-forward.Z, 0, forward.X) -- perpendiculaire

		-- Pont
		local pont = Instance.new("Part", container)
		pont.Size      = Vector3.new(15, 0.5, 195)
		pont.Anchored  = true
		pont.Material  = Enum.Material.WoodPlanks
		pont.Color     = Color3.fromRGB(163, 116, 82)
		pont.CFrame    = CFrame.new(HUB_CENTER + (pos - HUB_CENTER) * 0.5, pos)
			* CFrame.new(0, 0, -47.5)

		-- Arche + Parcels (maintenant depuis un template)
		createArche(container, slot, HUB_CENTER, pos)
		for p = 1, PARCELS_PER_ISLAND do
			-- Angle local de la parcelle par rapport au centre de l'île (augmenté de 140° à 160° pour encore plus d'espacement)
			local localTheta = math.rad(160 / (PARCELS_PER_ISLAND - 1) * (p - 1) - 80)
			-- Angle de l'île par rapport au hub (pour orienter les parcelles correctement)
			local islandAngle = math.atan2(pos.Z - HUB_CENTER.Z, pos.X - HUB_CENTER.X)
			-- Angle final : angle de l'île + angle local pour mettre les parcelles du côté du hub
			local finalTheta = islandAngle + localTheta
			-- Position mondiale réelle de la parcelle (augmenté de 55 à 65 pour pousser vers le bord)
			local offset = Vector3.new(65 * math.cos(finalTheta), 0, 65 * math.sin(finalTheta))
			local parcelWorldPos = pos + offset

			local parcelClone = parcelTemplate:Clone()
			setupParcel(parcelClone, container, p, parcelWorldPos)
		end

		-- Cloner et configurer le Model Platform
		local platformModel = platformTemplate:Clone()
		platformModel.Parent = container

		print("🔍 [DEBUG] Model Platform cloné dans", container.Name)

		-- Lister et ordonner les plateformes par numéro (Platform1, Platform2, ...)
		local platforms = {}
		for _, child in ipairs(platformModel:GetDescendants()) do
			if child:IsA("BasePart") and string.match(child.Name, "^Platform%d+$") then
				local n = tonumber(child.Name:match("Platform(%d+)$")) or 0
				table.insert(platforms, {index = n, part = child})
			end
		end
		table.sort(platforms, function(a,b) return a.index < b.index end)

		-- Référentiels pour rotation
		local originPart = platformModel:FindFirstChild("Origin", true)
		assert(originPart and originPart:IsA("BasePart"), "Le modèle 'Platform' doit contenir un Part 'Origin' centré")
		local originPos = originPart.Position
		local islandAngle = math.atan2(pos.Z - HUB_CENTER.Z, pos.X - HUB_CENTER.X)

		for _, item in ipairs(platforms) do
			local child = item.part
			-- Vecteur local par rapport à l'Origin du template
			local v = child.Position - originPos
			local vXZ = Vector3.new(v.X, 0, v.Z)
			local yOffset = v.Y
			if vXZ.Magnitude < 1e-4 then vXZ = Vector3.new(1,0,0) end
			-- Angle local autour de l'origin
			local angleLocal = math.atan2(vXZ.Z, vXZ.X)
			-- Angle mondial = orientation de l'île + angle local (assure le mirroring parfait)
			local angleWorld = islandAngle + angleLocal
			-- Position finale sur le bord
			local platformRadius = math.max(2, edgeRadius - PLATFORM_EDGE_INSET)
			local worldPos = centerPos + Vector3.new(math.cos(angleWorld) * platformRadius, yOffset, math.sin(angleWorld) * platformRadius)
			-- Poser et orienter vers le centre de l'île
			child.CFrame = CFrame.new(worldPos, centerPos)
			child.Anchored = true
			print("✅ [DEBUG] Platform", child.Name, "placée (angleLocal=", math.deg(angleLocal), ") à", worldPos)
		end

		-- (Placement strict par angle; pas de décalage anti-pont)

		-- Configurer toutes les plateformes (déjà orientées ci-dessus)
		for _, child in pairs(platformModel:GetChildren()) do
			if child:IsA("BasePart") and string.match(child.Name, "^Platform%d+$") then
				setupExistingPlatform(child, centerPos)
			end
		end

		-- Mur invisible autour de l'île avec ouverture côté HUB + barrière décorative
		createInvisibleBoundary(container, centerPos, solPart, edgeRadius, forward, right, barrierTemplate)

		islandPlots[slot] = container
		table.insert(unclaimedSlots, slot)
	end
	print("🌴 Monde généré — parcelles créées depuis le modèle : " .. PARCEL_TEMPLATE_NAME)
	print("🏭 Plateformes clonées et configurées depuis le modèle : " .. PLATFORM_TEMPLATE_NAME)
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
	if not slot then warn("Serveur plein"); return end
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
			if lbl then lbl.Text = "Empty"; end
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
