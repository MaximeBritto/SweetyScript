-- InventoryEnhancer.lua - Version responsive
-- Script côté client pour améliorer l'affichage des Tools dans l'inventaire Roblox
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- DÉTECTION PLATEFORME POUR INTERFACE RESPONSIVE
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Simple viewport setup function
local function setupSimpleViewport(viewport, modelPart)
	-- Créer une caméra pour le viewport
	local camera = Instance.new("Camera")
	camera.CameraType = Enum.CameraType.Scriptable
	viewport.CurrentCamera = camera
	
	-- Cloner le modèle pour le viewport
	local model = modelPart:Clone()
	model.Parent = viewport
	model.Anchored = true
	
	-- Calculer la position de la caméra
	local cf, size = model.CFrame, model.Size
	local distance = math.max(size.X, size.Y, size.Z) * 2
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance, distance, distance), cf.Position)
	
	-- Viewport configuré
end

-- Dossiers des modèles
local ingredientToolsFolder = ReplicatedStorage:WaitForChild("IngredientTools")
local candyModelsFolder = ReplicatedStorage:WaitForChild("CandyModels")

-- Table pour tracker les tools modifiés
local modifiedTools = {}

-- Fonction pour créer un ViewportFrame 3D pour un tool
local function createToolViewport(toolButton, toolName)
	if modifiedTools[toolButton] then
		return -- Déjà modifié
	end

	-- Chercher le modèle 3D correspondant (ingrédients OU bonbons)
	local toolModel = ingredientToolsFolder:FindFirstChild(toolName) or candyModelsFolder:FindFirstChild(toolName)
	if not toolModel then
		return
	end

	local handle = toolModel:FindFirstChild("Handle")
	if not handle then
		return
	end

	-- Créer le ViewportFrame (responsive)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Tool3DIcon"
	-- Taille responsive : plus de marge sur mobile pour éviter les problèmes tactiles
	local margin = (isMobile or isSmallScreen) and 6 or 4
	viewport.Size = UDim2.new(1, -margin, 1, -margin)
	viewport.Position = UDim2.new(0, margin/2, 0, margin/2)
	viewport.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	viewport.BackgroundTransparency = (isMobile or isSmallScreen) and 0.2 or 0.3  -- Plus opaque sur mobile
	viewport.BorderSizePixel = (isMobile or isSmallScreen) and 1 or 2
	viewport.BorderColor3 = Color3.fromRGB(0, 162, 255)
	viewport.Parent = toolButton

	-- Configurer le viewport avec le modèle 3D
	setupSimpleViewport(viewport, handle)

	-- Ajouter l'affichage du count si le tool en a un
	local function updateCount()
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local tool = backpack:FindFirstChild(toolName)
			if tool then
				local countValue = tool:FindFirstChild("Count")
				if countValue and countValue:IsA("IntValue") then
					-- Créer ou mettre à jour le label de count
					local countLabel = toolButton:FindFirstChild("CountLabel")
					if not countLabel then
						countLabel = Instance.new("TextLabel")
						countLabel.Name = "CountLabel"
						-- Taille responsive : plus grande sur mobile pour lisibilité
						local labelHeight = (isMobile or isSmallScreen) and 0.4 or 0.3
						countLabel.Size = UDim2.new(1, 0, labelHeight, 0)
						countLabel.Position = UDim2.new(0, 0, 1 - labelHeight, 0)
						countLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
						countLabel.BackgroundTransparency = (isMobile or isSmallScreen) and 0.2 or 0.3  -- Plus opaque sur mobile
						countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
						countLabel.TextScaled = true
						countLabel.Font = Enum.Font.SourceSansBold
						countLabel.Parent = toolButton
						
						-- Coins arrondis sur mobile
						if isMobile or isSmallScreen then
							local corner = Instance.new("UICorner")
							corner.CornerRadius = UDim.new(0, 4)
							corner.Parent = countLabel
						end
					end
					countLabel.Text = tostring(countValue.Value)
				end
			end
		end
	end
	
	-- Mettre à jour le count initial
	updateCount()
	
	-- Surveiller les changements de count
	task.spawn(function()
		while toolButton.Parent do
			updateCount()
			wait(0.5) -- Vérifier toutes les 0.5 secondes
		end
	end)

	-- Marquer comme modifié
	modifiedTools[toolButton] = true
end

-- Fonction améliorée pour scanner les tools
local function scanToolsAdvanced()
    -- Méthode PlayerGui uniquement (CoreGui est inaccessible en LocalScript non-plugin)
	local function tryPlayerGuiInterface()
		for _, gui in pairs(playerGui:GetChildren()) do
			if gui.Name:lower():find("hotbar") or gui.Name:lower():find("backpack") then
				-- Interface PlayerGui détectée

				local function findToolButtons(obj)
					for _, child in pairs(obj:GetDescendants()) do
						if child:IsA("ImageButton") or child:IsA("TextButton") or child:IsA("Frame") then
							-- Vérifier si c'est un slot d'outil
							if child.Size == UDim2.new(0, 50, 0, 50) or child.Name:match("^%d+$") then
								-- Slot détecté

								-- Associer avec le premier tool disponible pour test
								local backpack = player:FindFirstChild("Backpack")
                                if backpack then
                                    for _, tool in pairs(backpack:GetChildren()) do
                                        if tool:IsA("Tool") then
                                            local _baseName = tool:GetAttribute("BaseName") or tool.Name
                                            createToolViewport(child, _baseName)
                                            return -- Tester avec un seul pour commencer
                                        end
                                    end
                                end
							end
						end
					end
				end
				findToolButtons(gui)
			end
		end
	end

    -- Essayer uniquement PlayerGui pour éviter l'erreur "lacking capability Plugin"
    tryPlayerGuiInterface()
end

-- Fonction pour surveiller l'ajout de tools
local function onToolAdded(tool)
	if not tool:IsA("Tool") then return end

local _baseName = tool:GetAttribute("BaseName") or tool.Name
	-- Attendre mise à jour interface
	wait(0.5)
	scanToolsAdvanced()
end

-- Initialisation
local function initialize()
	-- Initialisation de l'amélioration d'inventaire

	-- Attendre le backpack
	local backpack = player:WaitForChild("Backpack")

	-- Scanner initial
	wait(2) -- Laisser l'interface se charger
	scanToolsAdvanced()

	-- Surveiller les nouveaux tools
	backpack.ChildAdded:Connect(onToolAdded)

	-- Scanner périodique
	task.spawn(function()
		while true do
			wait(5)
			scanToolsAdvanced()
		end
	end)
end

-- Démarrage
task.wait(3) -- Attendre que tout soit chargé
initialize()
-- InventoryEnhancer chargé 