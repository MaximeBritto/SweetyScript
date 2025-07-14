-- UIUtils.lua
-- Ce module fournit des fonctions utiles pour l'interface,
-- notamment pour gérer l'affichage de modèles 3D dans des ViewportFrames.

local UIUtils = {}

local RunService = game:GetService("RunService")

-- Fonction pour configurer une ViewportFrame avec un modèle 3D
function UIUtils.setupViewportFrame(viewportFrame, model)
	if not model then
		--warn("Modèle non fourni pour setupViewportFrame")
		return nil
	end

	-- Nettoyer les anciens éléments
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end

	-- Cloner le modèle et le mettre dans le viewport
	local modelClone = model:Clone()
	modelClone.Parent = viewportFrame

	-- Créer une caméra
	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	-- Positionner la caméra pour bien cadrer le modèle
	local function updateCamera()
		local modelCFrame, modelSize
		if modelClone:IsA("Model") then
			modelCFrame, modelSize = modelClone:GetBoundingBox()
		elseif modelClone:IsA("BasePart") then
			modelCFrame = modelClone.CFrame
			modelSize = modelClone.Size
		else
			return -- On ne peut pas gérer cet objet
		end

		local maxExtent = math.max(modelSize.X, modelSize.Y, modelSize.Z)
		
		-- Positionner la caméra un peu en retrait, en regardant le centre du modèle
		local cameraDistance = maxExtent * 2 -- Augmenter la distance pour un meilleur cadrage
		local cameraPosition = modelCFrame.Position + Vector3.new(0, maxExtent * 0.2, cameraDistance)
		camera.CFrame = CFrame.lookAt(cameraPosition, modelCFrame.Position)
	end
	
	updateCamera()

	-- Optionnel : Ajouter un effet de rotation
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not modelClone or not modelClone.Parent then
			connection:Disconnect()
			return
		end
		-- Pivoter le modèle pour un effet visuel
		modelClone:PivotTo(modelClone:GetPivot() * CFrame.Angles(0, dt * 1, 0))
	end)

	-- Détruire la connexion quand l'UI est détruite
	viewportFrame.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			connection:Disconnect()
		end
	end)

	return modelClone, camera
end

return UIUtils 