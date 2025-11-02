-- CandySizeManager.lua
-- Gère les tailles variables des bonbons et leurs prix

local CandySizeManager = {}

-- Configuration des tailles et probabilités (plages plus dramatiques)
-- NOUVEAU : Probabilités FORTEMENT réduites pour les grandes tailles (compensation du système de fournées)
local SIZE_CONFIG = {
	-- Tailles et leurs probabilités (total = 100%)
	-- Les petits bonbons sont beaucoup plus communs pour équilibrer l'économie
	{minSize = 0.50, maxSize = 0.75, probability = 5,  rarity = "Tiny", color = Color3.fromRGB(150, 150, 150)}, -- Gris - 25% (x2.5 augmentation)
	{minSize = 0.75, maxSize = 0.90, probability = 10, rarity = "Small", color = Color3.fromRGB(255, 200, 100)}, -- Jaune pâle - 35% (x1.67 augmentation)
	{minSize = 0.90, maxSize = 1.10, probability = 35, rarity = "Normal", color = Color3.fromRGB(255, 255, 255)}, -- Blanc - 35% (réduit de 55%)
	{minSize = 1.15, maxSize = 1.50, probability = 3, rarity = "Large", color = Color3.fromRGB(100, 255, 100)}, -- Vert - 3% (divisé par 2)
	{minSize = 1.50, maxSize = 2.20, probability = 1.5,  rarity = "Giant", color = Color3.fromRGB(100, 200, 255)}, -- Bleu - 1.5% (divisé par ~1.67)
	{minSize = 2.20, maxSize = 3.50, probability = 0.1, rarity = "Colossal", color = Color3.fromRGB(255, 100, 255)}, -- Magenta - 0.4% (divisé par 2)
	{minSize = 3.50, maxSize = 5.00, probability = 0.05, rarity = "LEGENDARY", color = Color3.fromRGB(255, 215, 0)} -- Or - 0.1% (légèrement augmenté)
}

-- Fonction pour obtenir le prix de base d'un bonbon depuis RecipeManager
-- NOUVEAU : Divise le prix total par candiesPerBatch pour obtenir le prix unitaire
local function getBasePriceFromRecipeManager(candyName)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local rmModule = ReplicatedStorage:FindFirstChild("RecipeManager")
	local recipeManager = nil
	if rmModule and rmModule:IsA("ModuleScript") then
		local ok, rm = pcall(require, rmModule)
		if ok then recipeManager = rm end
	end
	if recipeManager and recipeManager.Recettes then
		for recipeName, recipeData in pairs(recipeManager.Recettes) do
			if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
				local totalBatchPrice = recipeData.valeur or 15
				local candiesPerBatch = recipeData.candiesPerBatch or 1
				local unitPrice = math.floor(totalBatchPrice / candiesPerBatch)
				return math.max(1, unitPrice) -- Au moins 1$ par bonbon
			end
		end
	end
	return 15
end

-- Génère une taille aléatoire selon les probabilités
function CandySizeManager.generateRandomSize(forceRarity, minRarity)
	-- Si une rareté minimale est spécifiée (ex: "Colossal"), garantir au moins cette rareté
	-- mais garder une chance d'avoir mieux (ex: "LEGENDARY")
	if minRarity ~= nil then
		local minIndex = nil
		for i, config in ipairs(SIZE_CONFIG) do
			if config.rarity == minRarity then
				minIndex = i
				break
			end
		end
		
		if minIndex then
			-- Calculer les probabilités ajustées pour les raretés >= minRarity
			local adjustedConfigs = {}
			local totalProb = 0
			for i = minIndex, #SIZE_CONFIG do
				table.insert(adjustedConfigs, SIZE_CONFIG[i])
				totalProb = totalProb + SIZE_CONFIG[i].probability
			end
			
			-- Générer selon les probabilités ajustées
			local random = math.random() * totalProb
			local cumulativeProbability = 0
			for _, config in ipairs(adjustedConfigs) do
				cumulativeProbability = cumulativeProbability + config.probability
				if random <= cumulativeProbability then
					local randomValue = math.random()
					local size = randomValue * (config.maxSize - config.minSize) + config.minSize
					local finalSize = math.floor(size * 1000) / 1000
					print("🎯 Génération avec minimum:", minRarity, "| Obtenu:", config.rarity, "| Taille:", finalSize)
					return {
						size = finalSize,
						rarity = config.rarity,
						color = config.color,
						config = config,
					}
				end
			end
		end
	end
	
	-- Si une rareté est forcée EXACTEMENT, ignorer les probabilités et choisir directement dans sa plage
	if forceRarity ~= nil then
		local target = tostring(forceRarity)
		for _, config in ipairs(SIZE_CONFIG) do
			if config.rarity == target then
				local randomValue = math.random()
				local size = randomValue * (config.maxSize - config.minSize) + config.minSize
				local finalSize = math.floor(size * 1000) / 1000
				print("🎯 Génération forcée:", config.rarity, "| Rand:", randomValue, "| Plage:", config.minSize .. "-" .. config.maxSize, "| Taille:", finalSize)
				return {
					size = finalSize,
					rarity = config.rarity,
					color = config.color,
					config = config,
				}
			end
		end
		-- Si rareté forcée inconnue, on retombe sur la génération normale
	end

	-- Génération probabiliste normale
	local random = math.random(1, 1000)
	local cumulativeProbability = 0
	for _, config in ipairs(SIZE_CONFIG) do
		cumulativeProbability = cumulativeProbability + (config.probability * 10)
		if random <= cumulativeProbability then
			local randomValue = math.random()
			local size = randomValue * (config.maxSize - config.minSize) + config.minSize
			local finalSize = math.floor(size * 1000) / 1000
			print("🎲 Génération:", config.rarity, "| Random:", randomValue, "| Plage:", config.minSize .. "-" .. config.maxSize, "| Taille finale:", finalSize)
			return {
				size = finalSize,
				rarity = config.rarity,
				color = config.color,
				config = config
			}
		end
	end

	-- Fallback (ne devrait jamais arriver)
	return {
		size = 1.0,
		rarity = "Normal",
		color = Color3.fromRGB(255, 255, 255),
		config = SIZE_CONFIG[3]
	}
end

-- Calcule le prix d'un bonbon selon sa taille
function CandySizeManager.calculatePrice(candyName, sizeData)
	local basePrice = getBasePriceFromRecipeManager(candyName)
	local sizeMultiplier = sizeData.size ^ 2.5 -- Progression exponentielle

	-- Bonus de rareté
	local rarityBonus = 1
	if sizeData.rarity == "Géant" then rarityBonus = 1.2
	elseif sizeData.rarity == "Colossal" then rarityBonus = 1.5
	elseif sizeData.rarity == "LEGENDARY" then rarityBonus = 2.0
	end

	local finalPrice = math.floor(basePrice * sizeMultiplier * rarityBonus)
	return math.max(finalPrice, 1) -- Minimum 1$
end

-- Obtient les informations de taille depuis les attributs d'un Tool
function CandySizeManager.getSizeDataFromTool(tool)
	if not tool then return nil end

	local size = tool:GetAttribute("CandySize") or 1.0
	local rarity = tool:GetAttribute("CandyRarity") or "Normal"
	local colorR = tool:GetAttribute("CandyColorR") or 255
	local colorG = tool:GetAttribute("CandyColorG") or 255  
	local colorB = tool:GetAttribute("CandyColorB") or 255

	return {
		size = size,
		rarity = rarity,
		color = Color3.fromRGB(colorR, colorG, colorB)
	}
end

-- Applique les données de taille à un Tool
function CandySizeManager.applySizeDataToTool(tool, sizeData)
	if not tool or not sizeData then return end

	-- Sauvegarder dans les attributs
	tool:SetAttribute("CandySize", sizeData.size)
	tool:SetAttribute("CandyRarity", sizeData.rarity)
	tool:SetAttribute("CandyColorR", math.floor(sizeData.color.R * 255))
	tool:SetAttribute("CandyColorG", math.floor(sizeData.color.G * 255))
	tool:SetAttribute("CandyColorB", math.floor(sizeData.color.B * 255))
end

-- Met à l'échelle les effets de particules selon la taille du bonbon
function CandySizeManager.scaleParticleEffects(model, sizeData)
	if not model or not sizeData then return end

	local scale = sizeData.size
	local particleCount = 0
	local beamCount = 0

	print("🔍 [BEAM DEBUG] Recherche des Beams dans:", model.Name, "| Scale:", scale)

	-- Parcourir tous les descendants pour trouver les ParticleEmitters
	for _, descendant in pairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			particleCount = particleCount + 1

			-- Sauvegarder les valeurs originales si pas déjà fait
			local originalSizeMin = descendant:GetAttribute("OriginalSizeMin")
			local originalSizeMax = descendant:GetAttribute("OriginalSizeMax")
			local originalSpeed = descendant:GetAttribute("OriginalSpeed")
			local originalRate = descendant:GetAttribute("OriginalRate")

			if not originalSizeMin then
				-- Sauvegarder les valeurs de Size (NumberSequence)
				local sizeSeq = descendant.Size
				if sizeSeq.Keypoints[1] then
					descendant:SetAttribute("OriginalSizeMin", sizeSeq.Keypoints[1].Value)
				end
				if sizeSeq.Keypoints[#sizeSeq.Keypoints] then
					descendant:SetAttribute("OriginalSizeMax", sizeSeq.Keypoints[#sizeSeq.Keypoints].Value)
				end

				-- Sauvegarder Speed (NumberRange)
				descendant:SetAttribute("OriginalSpeed", descendant.Speed.Max)

				-- Sauvegarder Rate
				descendant:SetAttribute("OriginalRate", descendant.Rate)

				originalSizeMin = descendant:GetAttribute("OriginalSizeMin")
				originalSizeMax = descendant:GetAttribute("OriginalSizeMax")
				originalSpeed = descendant:GetAttribute("OriginalSpeed")
				originalRate = descendant:GetAttribute("OriginalRate")
			end

			-- Appliquer le scale à la taille des particules
			if originalSizeMin and originalSizeMax then
				local newKeypoints = {}
				for _, keypoint in ipairs(descendant.Size.Keypoints) do
					table.insert(newKeypoints, NumberSequenceKeypoint.new(
						keypoint.Time,
						keypoint.Value * scale,
						keypoint.Envelope * scale
						))
				end
				descendant.Size = NumberSequence.new(newKeypoints)
			end

			-- Appliquer le scale à la vitesse des particules (optionnel, moins dramatique)
			if originalSpeed then
				descendant.Speed = NumberRange.new(originalSpeed * scale * 0.5, originalSpeed * scale)
			end

			-- Ajuster le taux d'émission pour les gros bonbons (optionnel)
			if originalRate and originalRate > 0 then
				-- Pour les gros bonbons, on peut augmenter légèrement le taux
				local rateScale = math.min(scale, 2.0) -- Limite à 2x pour éviter trop de particules
				descendant.Rate = originalRate * rateScale
			end

			print("✨ Particule mise à l'échelle:", descendant.Name, "| Scale:", scale)
		end

		-- Ajuster aussi les PointLight si présentes
		if descendant:IsA("PointLight") then
			local originalRange = descendant:GetAttribute("OriginalRange")
			local originalBrightness = descendant:GetAttribute("OriginalBrightness")

			if not originalRange then
				descendant:SetAttribute("OriginalRange", descendant.Range)
				descendant:SetAttribute("OriginalBrightness", descendant.Brightness)
				originalRange = descendant.Range
				originalBrightness = descendant.Brightness
			end

			descendant.Range = originalRange * scale
			-- La luminosité peut aussi être ajustée légèrement
			descendant.Brightness = originalBrightness * math.min(scale, 1.5)

			print("💡 Lumière mise à l'échelle:", descendant.Name, "| Range:", descendant.Range)
		end

		-- Ajuster les Beams si présents
		if descendant:IsA("Beam") then
			beamCount = beamCount + 1
			print("🔍 [BEAM TROUVÉ]", descendant.Name, "| Parent:", descendant.Parent.Name)
			print("  - Width0 actuel:", descendant.Width0, "| Width1 actuel:", descendant.Width1)

			local originalWidth0 = descendant:GetAttribute("OriginalWidth0")
			local originalWidth1 = descendant:GetAttribute("OriginalWidth1")

			if not originalWidth0 then
				print("  - Sauvegarde des valeurs originales")
				descendant:SetAttribute("OriginalWidth0", descendant.Width0)
				descendant:SetAttribute("OriginalWidth1", descendant.Width1)
				originalWidth0 = descendant.Width0
				originalWidth1 = descendant.Width1
			else
				print("  - Valeurs originales déjà sauvegardées:", originalWidth0, "|", originalWidth1)
			end

			-- Appliquer le scale à la largeur du beam
			local newWidth0 = originalWidth0 * scale
			local newWidth1 = originalWidth1 * scale
			descendant.Width0 = newWidth0
			descendant.Width1 = newWidth1

			print("⚡ Beam mis à l'échelle:", descendant.Name)
			print("  - Nouvelles largeurs: Width0=", newWidth0, "| Width1=", newWidth1)
			print("  - Attachment0:", descendant.Attachment0, "| Attachment1:", descendant.Attachment1)
		end
	end

	if particleCount > 0 then
		print("✅ Total de", particleCount, "effets de particules mis à l'échelle avec facteur:", scale)
	end

	if beamCount > 0 then
		print("✅ Total de", beamCount, "Beams mis à l'échelle avec facteur:", scale)
	else
		print("⚠️ Aucun Beam trouvé dans le modèle:", model.Name)
	end
end

-- Applique la taille visuelle au modèle 3D du bonbon
function CandySizeManager.applySizeToModel(model, sizeData)
	if not model or not sizeData then 
		print("❌ applySizeToModel: modèle ou sizeData manquant")
		return 
	end

	print("🔍 Recherche partie à redimensionner dans:", model.Name, "| Type:", model.ClassName)

	-- Chercher la partie principale du bonbon avec plus de debug
	local bonbonPart = model:FindFirstChild("BonbonSkin") or model:FindFirstChild("Handle")

	-- Si pas trouvé, chercher toutes les BasePart dans le Tool
	if not bonbonPart and model:IsA("Tool") then
		for _, child in pairs(model:GetDescendants()) do
			if child:IsA("BasePart") and child.Name ~= "Handle" then
				bonbonPart = child
				print("🔍 Partie trouvée:", child.Name, "| Taille actuelle:", child.Size)
				break
			end
		end
	end

	-- Fallback sur le model lui-même s'il est une BasePart
	if not bonbonPart and model:IsA("BasePart") then
		bonbonPart = model
	end

	if bonbonPart and bonbonPart:IsA("BasePart") then
		-- Sauvegarder la taille originale si pas déjà fait
		local originalSizeX = bonbonPart:GetAttribute("OriginalSizeX")
		local originalSizeY = bonbonPart:GetAttribute("OriginalSizeY")
		local originalSizeZ = bonbonPart:GetAttribute("OriginalSizeZ")

		if not originalSizeX then
			-- Première fois : sauvegarder les dimensions originales
			bonbonPart:SetAttribute("OriginalSizeX", bonbonPart.Size.X)
			bonbonPart:SetAttribute("OriginalSizeY", bonbonPart.Size.Y)
			bonbonPart:SetAttribute("OriginalSizeZ", bonbonPart.Size.Z)
			originalSizeX = bonbonPart.Size.X
			originalSizeY = bonbonPart.Size.Y
			originalSizeZ = bonbonPart.Size.Z
		end

		-- Appliquer le facteur de taille aux dimensions originales
		bonbonPart.Size = Vector3.new(
			originalSizeX * sizeData.size,
			originalSizeY * sizeData.size,
			originalSizeZ * sizeData.size
		)

		-- Debug pour voir la taille appliquée
		print("📜 Taille appliquée:", bonbonPart.Name, "facteur:", sizeData.size, "nouvelle size:", bonbonPart.Size)

		-- 🆕 AJUSTEMENT DU HANDLE pour les bonbons gigantesques
		-- Repositionner le Handle pour que le joueur tienne toujours le bonbon par l'extrémité

		print("🔍 [HANDLE DEBUG] === DÉBUT AJUSTEMENT HANDLE ===")
		print("🔍 [HANDLE DEBUG] Model:", model.Name, "| Type:", model.ClassName)
		print("🔍 [HANDLE DEBUG] BonbonPart:", bonbonPart.Name, "| Taille:", bonbonPart.Size)

		-- Lister tous les enfants pour debug
		print("🔍 [HANDLE DEBUG] Liste des enfants du model:")
		for _, child in pairs(model:GetChildren()) do
			print("  - ", child.Name, "| Type:", child.ClassName, "| Est BasePart:", child:IsA("BasePart"))
		end

		local handle = model:FindFirstChild("Handle")
		print("🔍 [HANDLE DEBUG] Handle trouvé:", handle ~= nil)

		if handle then
			print("🔍 [HANDLE DEBUG] Handle.Name:", handle.Name)
			print("🔍 [HANDLE DEBUG] Handle.ClassName:", handle.ClassName)
			print("🔍 [HANDLE DEBUG] Handle est BasePart:", handle:IsA("BasePart"))
			print("🔍 [HANDLE DEBUG] Handle.Position avant:", handle.Position)
			print("🔍 [HANDLE DEBUG] BonbonPart == Handle:", bonbonPart == handle)
		else
			print("❌ [HANDLE DEBUG] Aucun Handle trouvé dans le model!")
		end

		if handle and handle:IsA("BasePart") then
			-- Calculer un décalage basé sur la TAILLE RÉELLE du bonbon
			-- Le Handle sera positionné au bout inférieur du bonbon (pour le tenir "par le bas")

			-- Calculer la demi-hauteur du bonbon (pour le positionner au bord)
			local bonbonHalfHeight = bonbonPart.Size.Y / 2

			print("🔍 [HANDLE DEBUG] Demi-hauteur bonbon:", bonbonHalfHeight)

			-- OPTION 1: Position par défaut en bas du bonbon si BonbonSkin et Handle différents
			if bonbonPart ~= handle then
				print("✅ [HANDLE DEBUG] BonbonSkin et Handle sont différents - repositionnement possible")

				-- 🔧 SUPPRIMER TOUS LES WELDS qui pourraient bloquer le mouvement
				print("🔍 [HANDLE DEBUG] Recherche et suppression des Welds...")
				local weldCount = 0
				for _, child in pairs(handle:GetChildren()) do
					if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D") then
						print("🔧 [HANDLE DEBUG] Suppression:", child.ClassName, "dans Handle")
						child:Destroy()
						weldCount = weldCount + 1
					end
				end
				for _, child in pairs(bonbonPart:GetChildren()) do
					if (child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D")) and 
						(child.Part0 == handle or child.Part1 == handle) then
						print("🔧 [HANDLE DEBUG] Suppression:", child.ClassName, "dans BonbonPart lié au Handle")
						child:Destroy()
						weldCount = weldCount + 1
					end
				end
				print("🔧 [HANDLE DEBUG]", weldCount, "Welds supprimés")

				-- Positionner le Handle en dessous du centre du bonbon
				-- Plus le bonbon est grand, plus le Handle doit être décalé vers le bas

				-- 🎯 DÉCALAGE AJUSTÉ : 0.8x pour tenir le bonbon naturellement
				-- (1.0 = au bord exact, 0.8 = un peu plus haut, 0.5 = au milieu)
				local verticalOffset = -bonbonHalfHeight * 0.8

				print("🔍 [HANDLE DEBUG] Décalage vertical calculé:", verticalOffset)
				print("🔍 [HANDLE DEBUG] BonbonPart.CFrame:", bonbonPart.CFrame)

				-- Appliquer la position avec un décalage visible
				handle.CFrame = bonbonPart.CFrame * CFrame.new(0, verticalOffset, 0)

				print("🔍 [HANDLE DEBUG] Handle.Position après:", handle.Position)
				print("🎯 [HANDLE DEBUG] Handle repositionné en bas du bonbon | Taille:", sizeData.size .. "x | Décalage Y:", verticalOffset)

				-- 🔧 Créer un nouveau Weld pour maintenir la position
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = bonbonPart
				weld.Part1 = handle
				weld.Parent = handle
				print("✅ [HANDLE DEBUG] Nouveau WeldConstraint créé pour maintenir la position")

			else
				-- Si Handle = BonbonSkin, créer un petit offset horizontal pour test
				print("⚠️ [HANDLE DEBUG] Handle et BonbonSkin sont la même part - pas de repositionnement")
			end
		else
			print("❌ [HANDLE DEBUG] Handle non trouvé ou pas une BasePart")
		end

		print("🔍 [HANDLE DEBUG] === FIN AJUSTEMENT HANDLE ===")
		print("")

		-- NOUVEAU: Mettre à l'échelle les effets de particules existants
		CandySizeManager.scaleParticleEffects(model, sizeData)

		-- Effet visuel de rareté (particules, glow, etc.)
		if sizeData.rarity ~= "Normal" then
			CandySizeManager.addVisualEffects(bonbonPart, sizeData)
		end
	else
		print("❌ Aucune partie à redimensionner trouvée dans:", model.Name)
		-- Lister toutes les parties pour debug
		for _, child in pairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				print("  - Partie disponible:", child.Name, "Type:", child.ClassName, "Taille:", child.Size)
			end
		end
	end
end

-- Ajoute des effets visuels selon la rareté
function CandySizeManager.addVisualEffects(part, sizeData)
	-- Supprimer les anciens effets
	for _, child in pairs(part:GetChildren()) do
		if child.Name:find("RarityEffect") then
			child:Destroy()
		end
	end

	-- Effet de glow pour les bonbons rares
	if sizeData.rarity == "Géant" or sizeData.rarity == "Colossal" or sizeData.rarity == "LEGENDARY" then
		local pointLight = Instance.new("PointLight")
		pointLight.Name = "RarityEffectLight"
		pointLight.Color = sizeData.color
		pointLight.Brightness = sizeData.rarity == "LEGENDARY" and 2 or 1
		pointLight.Range = sizeData.size * 5
		pointLight.Parent = part
	end

	-- Particules pour les légendaires
	if sizeData.rarity == "LEGENDARY" then
		local attachment = Instance.new("Attachment")
		attachment.Name = "RarityEffectAttachment"
		attachment.Parent = part

		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "RarityEffectSparkles"
		sparkles.SparkleColor = sizeData.color
		sparkles.Parent = part
	end
end

-- Obtient une chaîne formatée pour afficher la taille et rareté
function CandySizeManager.getDisplayString(sizeData)
	local sizePercent = math.floor(sizeData.size * 100)
	return string.format("%s (%d%%)", sizeData.rarity, sizePercent)
end

return CandySizeManager
