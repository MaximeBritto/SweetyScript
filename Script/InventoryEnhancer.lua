-- InventoryEnhancer.lua
-- Script côté client pour améliorer l'affichage des Tools dans l'inventaire Roblox
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

-- Dossier des modèles d'ingrédients
local ingredientToolsFolder = ReplicatedStorage:WaitForChild("IngredientTools")

-- Table pour tracker les tools modifiés
local modifiedTools = {}

-- Fonction de débogage pour explorer l'interface
local function debugInterface()
	print("🔍 DIAGNOSTIC DE L'INTERFACE:")
	print("PlayerGui enfants:", #playerGui:GetChildren())

	for _, child in pairs(playerGui:GetChildren()) do
		print("  -", child.Name, "(" .. child.ClassName .. ")")

		if child.Name:lower():find("hotbar") or child.Name:lower():find("backpack") or child.Name:lower():find("toolbar") then
			print("    🎯 Interface potentielle trouvée:", child.Name)

			local function exploreRecursive(obj, depth)
				if depth > 3 then return end -- Limiter la profondeur

				local indent = string.rep("    ", depth)
				for _, subChild in pairs(obj:GetChildren()) do
					print(indent .. "└─", subChild.Name, "(" .. subChild.ClassName .. ")")

					if subChild:IsA("ImageButton") or subChild:IsA("TextButton") or subChild.Name:lower():find("tool") then
						print(indent .. "  🔧 Bouton potentiel:", subChild.Name)
					end

					exploreRecursive(subChild, depth + 1)
				end
			end

			exploreRecursive(child, 1)
		end
	end
end

-- Fonction pour créer un ViewportFrame 3D pour un tool
local function createToolViewport(toolButton, toolName)
	if modifiedTools[toolButton] then
		return -- Déjà modifié
	end

	print("🎨 Tentative de création d'un viewport 3D pour:", toolName)

	-- Chercher le modèle 3D correspondant
	local ingredientModel = ingredientToolsFolder:FindFirstChild(toolName)
	if not ingredientModel then
		print("❌ Modèle non trouvé pour:", toolName)
		print("📁 Modèles disponibles:")
		for _, model in pairs(ingredientToolsFolder:GetChildren()) do
			print("  -", model.Name)
		end
		return
	end

	local handle = ingredientModel:FindFirstChild("Handle")
	if not handle then
		print("❌ Handle non trouvé pour:", toolName)
		return
	end

	print("✅ Modèle trouvé:", toolName, "avec Handle")

	-- Créer le ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Tool3DIcon"
	viewport.Size = UDim2.new(1, -4, 1, -4)
	viewport.Position = UDim2.new(0, 2, 0, 2)
	viewport.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	viewport.BackgroundTransparency = 0.3
	viewport.BorderSizePixel = 2
	viewport.BorderColor3 = Color3.fromRGB(0, 162, 255)
	viewport.Parent = toolButton

	-- Configurer le viewport avec le modèle 3D
	UIUtils.setupViewportFrame(viewport, handle)

	-- Marquer comme modifié
	modifiedTools[toolButton] = true

	print("✅ Viewport 3D créé avec succès pour:", toolName)
end

-- Fonction améliorée pour scanner les tools
local function scanToolsAdvanced()
	print("🔎 SCAN AVANCÉ DES TOOLS...")

	-- Méthode 1: Interface moderne (CoreGui)
	local function tryModernInterface()
		local coreGui = game:GetService("CoreGui")
		local hotbar = coreGui:FindFirstChild("Hotbar")

		if hotbar then
			print("✅ Interface moderne trouvée dans CoreGui")
			-- Explorer cette interface
			local function findToolButtons(obj)
				for _, child in pairs(obj:GetDescendants()) do
					if child:IsA("ImageButton") or child:IsA("TextButton") then
						if child.Name:lower():find("tool") or child.Size == UDim2.new(0, 50, 0, 50) then
							print("🔧 Bouton tool potentiel:", child.Name)
							-- Tenter d'associer avec un tool du backpack
							local backpack = player:FindFirstChild("Backpack")
							if backpack then
								for _, tool in pairs(backpack:GetChildren()) do
									if tool:IsA("Tool") then
										local baseName = tool:GetAttribute("BaseName") or tool.Name
										createToolViewport(child, baseName)
										break
									end
								end
							end
						end
					end
				end
			end
			findToolButtons(hotbar)
		end
	end

	-- Méthode 2: Interface PlayerGui
	local function tryPlayerGuiInterface()
		for _, gui in pairs(playerGui:GetChildren()) do
			if gui.Name:lower():find("hotbar") or gui.Name:lower():find("backpack") then
				print("✅ Interface PlayerGui trouvée:", gui.Name)

				local function findToolButtons(obj)
					for _, child in pairs(obj:GetDescendants()) do
						if child:IsA("ImageButton") or child:IsA("TextButton") or child:IsA("Frame") then
							-- Vérifier si c'est un slot d'outil
							if child.Size == UDim2.new(0, 50, 0, 50) or child.Name:match("^%d+$") then
								print("🔧 Slot potentiel:", child.Name, "Size:", tostring(child.Size))

								-- Associer avec le premier tool disponible pour test
								local backpack = player:FindFirstChild("Backpack")
								if backpack then
									for _, tool in pairs(backpack:GetChildren()) do
										if tool:IsA("Tool") then
											local baseName = tool:GetAttribute("BaseName") or tool.Name
											createToolViewport(child, baseName)
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

	-- Essayer les deux méthodes
	tryModernInterface()
	tryPlayerGuiInterface()
end

-- Fonction pour surveiller l'ajout de tools
local function onToolAdded(tool)
	if not tool:IsA("Tool") then return end

	local baseName = tool:GetAttribute("BaseName") or tool.Name
	print("🔧 Tool ajouté dans le backpack:", baseName)

	-- Attendre que l'interface se mette à jour
	wait(0.5)
	scanToolsAdvanced()
end

-- Initialisation
local function initialize()
	print("🚀 DÉMARRAGE DE L'AMÉLIORATION DE L'INVENTAIRE")
	print("📍 Emplacement: StarterPlayerScripts")

	-- Debug initial
	debugInterface()

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

	print("✅ Système d'amélioration activé!")
end

-- Démarrage
task.wait(3) -- Attendre que tout soit chargé
initialize()

print("📦 Script d'amélioration de l'inventaire chargé !") 