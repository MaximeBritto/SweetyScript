--------------------------------------------------------------------
-- TutorialArrowSystem.lua - Système de flèches 3D pour le tutoriel
-- Crée un chemin de flèches continues entre le joueur et l'objectif
-- Utilise PathfindingService pour contourner les obstacles
--------------------------------------------------------------------

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local TutorialArrowSystem = {}

--------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------
local CONFIG = {
    -- Image de la flèche
    ARROW_IMAGE = "rbxassetid://88141338540731",
    
    -- Couleur de la flèche
    ARROW_COLOR = Color3.fromRGB(255, 215, 0), -- Doré
    
    -- Espacement entre les points du chemin
    PATH_SPACING = 8, -- Distance entre chaque point du chemin
    
    -- Nombre de flèches animées
    NUM_ANIMATED_ARROWS = 5, -- Nombre de flèches qui se déplacent le long du chemin
    
    -- Animation
    ARROW_SPEED = 15, -- Vitesse de déplacement des flèches (studs/seconde)
    ARROW_SIZE = UDim2.new(0, 100, 0, 100), -- Taille de la flèche
    ARROW_BASE_ROTATION = 0, -- Pas de rotation de base (l'image pointe déjà vers le haut)
    
    -- Hauteur au-dessus du sol
    HEIGHT_OFFSET = 2,
    
    -- Mise à jour
    UPDATE_RATE = 0.5, -- Secondes entre chaque mise à jour du chemin (équilibre entre fluidité et performance)
    
    -- Pathfinding
    USE_PATHFINDING = true, -- Activer le pathfinding intelligent
    MAX_PATH_DISTANCE = 500 -- Distance maximale pour le pathfinding
}

--------------------------------------------------------------------
-- CRÉATION D'UN POINT DE CHEMIN
--------------------------------------------------------------------
local function createPathPoint(position)
    -- Part invisible pour ancrer les Beams
    local point = Instance.new("Part")
    point.Name = "PathPoint"
    point.Size = Vector3.new(0.5, 0.5, 0.5)
    point.Transparency = 1
    point.Anchored = true
    point.CanCollide = false
    point.CastShadow = false
    point.Position = position
    
    -- Attachment pour les Beams
    local attachment = Instance.new("Attachment")
    attachment.Parent = point
    
    return point, attachment
end

--------------------------------------------------------------------
-- CALCUL DU CHEMIN EN LIGNE DROITE (fallback)
--------------------------------------------------------------------
local function calculateStraightPath(startPos, endPos)
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    local normalizedDir = direction.Unit
    
    -- Calculer le nombre de points nécessaires
    local numPoints = math.max(2, math.floor(distance / CONFIG.PATH_SPACING))
    
    local waypoints = {}
    for i = 0, numPoints do
        local t = i / numPoints -- Progression de 0 à 1
        local position = startPos + (normalizedDir * (distance * t))
        
        -- Ajouter une hauteur pour que les flèches flottent
        position = position + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
        
        table.insert(waypoints, {
            position = position,
            direction = normalizedDir,
            index = i
        })
    end
    
    return waypoints
end

--------------------------------------------------------------------
-- CALCUL DU CHEMIN INTELLIGENT (avec pathfinding)
--------------------------------------------------------------------
local function calculateSmartPath(startPos, endPos)
    local waypoints = {}
    
    -- Vérifier si on doit utiliser le pathfinding
    local distance = (endPos - startPos).Magnitude
    
    if CONFIG.USE_PATHFINDING and distance > 15 and distance < CONFIG.MAX_PATH_DISTANCE then
        -- Utiliser PathfindingService pour trouver un chemin intelligent
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            WaypointSpacing = CONFIG.PATH_SPACING,
            Costs = {
                Water = 20,
                Danger = math.huge
            }
        })
        
        local success, errorMessage = pcall(function()
            path:ComputeAsync(startPos, endPos)
        end)
        
        if success and path.Status == Enum.PathStatus.Success then
            -- Utiliser les waypoints du pathfinding
            local pathWaypoints = path:GetWaypoints()
            
            for i = 2, #pathWaypoints - 1 do -- Ignorer le premier (joueur) et dernier (objectif)
                local wp = pathWaypoints[i]
                local nextWp = pathWaypoints[i + 1]
                
                if nextWp then
                    local direction = (nextWp.Position - wp.Position).Unit
                    local position = wp.Position + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
                    
                    table.insert(waypoints, {
                        position = position,
                        direction = direction,
                        index = i,
                        action = wp.Action -- Jump, Walk, etc.
                    })
                end
            end
            
            print("✅ [TutorialArrow] Pathfinding réussi:", #waypoints, "waypoints")
        else
            -- Pathfinding échoué, utiliser ligne droite
            print("⚠️ [TutorialArrow] Pathfinding échoué, utilisation ligne droite")
            return calculateStraightPath(startPos, endPos)
        end
    else
        -- Distance trop courte ou pathfinding désactivé, utiliser ligne droite
        return calculateStraightPath(startPos, endPos)
    end
    
    return waypoints
end



--------------------------------------------------------------------
-- API PUBLIQUE
--------------------------------------------------------------------

-- Activer/désactiver le pathfinding
function TutorialArrowSystem.SetPathfinding(enabled)
    CONFIG.USE_PATHFINDING = enabled
    print("✅ [TutorialArrow] Pathfinding:", enabled and "activé" or "désactivé")
end

-- Configurer l'espacement des points du chemin
function TutorialArrowSystem.SetPathSpacing(spacing)
    CONFIG.PATH_SPACING = spacing
    print("✅ [TutorialArrow] Espacement du chemin configuré:", spacing, "studs")
end

-- Configurer la vitesse des flèches
function TutorialArrowSystem.SetArrowSpeed(speed)
    CONFIG.ARROW_SPEED = speed
    print("✅ [TutorialArrow] Vitesse des flèches configurée:", speed, "studs/s")
end

-- Configurer le nombre de flèches animées
function TutorialArrowSystem.SetNumArrows(num)
    CONFIG.NUM_ANIMATED_ARROWS = num
    print("✅ [TutorialArrow] Nombre de flèches configuré:", num)
end

-- Configurer la rotation de base de la flèche
function TutorialArrowSystem.SetArrowRotation(rotation)
    CONFIG.ARROW_BASE_ROTATION = rotation
    print("✅ [TutorialArrow] Rotation de base configurée:", rotation, "degrés")
end

-- Configurer les couleurs
function TutorialArrowSystem.SetColors(arrowColor, glowColor)
    CONFIG.ARROW_COLOR = arrowColor
    CONFIG.GLOW_COLOR = glowColor or arrowColor
    print("✅ [TutorialArrow] Couleurs configurées")
end

-- Créer un chemin de flèches entre le joueur et la cible
function TutorialArrowSystem.CreateArrowPath(player, target)
    local targetPosition
    local targetObject = target
    
    -- Déterminer la position cible
    if typeof(target) == "Vector3" then
        targetPosition = target
        targetObject = nil
    elseif typeof(target) == "Instance" then
        if target:IsA("BasePart") then
            targetPosition = target.Position
        elseif target:IsA("Model") and target.PrimaryPart then
            targetPosition = target.PrimaryPart.Position
        else
            warn("❌ [TutorialArrow] Impossible de déterminer la position de:", target)
            return nil
        end
    else
        warn("❌ [TutorialArrow] Type de cible invalide:", typeof(target))
        return nil
    end
    
    -- Créer un dossier pour contenir toutes les flèches
    local arrowFolder = Instance.new("Folder")
    arrowFolder.Name = "TutorialArrowPath_" .. player.Name
    arrowFolder.Parent = workspace
    
    local pathPoints = {}
    local beams = {}
    local waypoints = {}
    local updateConnection = nil
    local followConnection = nil
    
    -- Fonction pour mettre à jour le chemin
    local function updatePath()
        -- Obtenir la position du joueur
        local character = player.Character
        if not character then return end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local playerPos = humanoidRootPart.Position
        
        -- Mettre à jour la position cible si c'est un objet
        if targetObject and targetObject:IsA("BasePart") then
            targetPosition = targetObject.Position
        elseif targetObject and targetObject:IsA("Model") and targetObject.PrimaryPart then
            targetPosition = targetObject.PrimaryPart.Position
        end
        
        -- Calculer le chemin intelligent (avec pathfinding)
        waypoints = calculateSmartPath(playerPos, targetPosition)
        
        -- Nettoyer les anciens beams explicitement
        for _, beam in ipairs(beams) do
            if beam and beam.Parent then
                beam:Destroy()
            end
        end
        beams = {}
        
        -- Nettoyer les anciens points
        for _, pointData in ipairs(pathPoints) do
            if pointData.point and pointData.point.Parent then
                pointData.point:Destroy()
            end
        end
        pathPoints = {}
        
        -- Créer les nouveaux points
        for _, waypoint in ipairs(waypoints) do
            local point, attachment = createPathPoint(waypoint.position)
            point.Parent = arrowFolder
            table.insert(pathPoints, {point = point, attachment = attachment})
        end
        
        -- Créer les Beams entre les points
        for i = 1, #pathPoints - 1 do
            local currentPoint = pathPoints[i]
            local nextPoint = pathPoints[i + 1]
            
            if currentPoint and nextPoint then
                local beam = Instance.new("Beam")
                -- Inverser l'ordre pour que les flèches pointent du joueur vers l'objectif
                beam.Attachment0 = nextPoint.attachment
                beam.Attachment1 = currentPoint.attachment
                beam.Color = ColorSequence.new(CONFIG.ARROW_COLOR)
                beam.Transparency = NumberSequence.new(0.1) -- Moins transparent (était 0.3)
                beam.Width0 = 2.5 -- Plus large (était 1.5)
                beam.Width1 = 2.5 -- Plus large (était 1.5)
                beam.FaceCamera = true
                beam.LightEmission = 0.3 -- Un peu plus lumineux (était 0.2)
                beam.LightInfluence = 0
                beam.Texture = CONFIG.ARROW_IMAGE
                beam.TextureMode = Enum.TextureMode.Wrap
                beam.TextureLength = 8 -- Beaucoup plus long pour une boucle très fluide
                beam.TextureSpeed = -3 -- Beaucoup plus rapide pour masquer complètement la boucle
                beam.Parent = currentPoint.point
                table.insert(beams, beam)
            end
        end
        
        print("🎯 [TutorialArrow] Chemin mis à jour:", #waypoints, "waypoints,", #beams, "beams")
    end
    
    -- Mise à jour initiale
    updatePath()
    
    -- Suivre le joueur en temps réel (déplace juste le premier point)
    followConnection = RunService.Heartbeat:Connect(function()
        local character = player.Character
        if not character then return end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        -- Déplacer le premier point pour suivre le joueur instantanément
        if pathPoints[1] and pathPoints[1].point then
            local playerPos = humanoidRootPart.Position + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
            pathPoints[1].point.Position = playerPos
        end
    end)
    
    -- Mise à jour périodique du chemin complet (moins fréquent)
    updateConnection = task.spawn(function()
        while true do
            task.wait(CONFIG.UPDATE_RATE)
            updatePath()
        end
    end)
    
    -- Retourner un objet de contrôle
    return {
        Folder = arrowFolder,
        Points = pathPoints,
        Beams = beams,
        UpdateTask = updateConnection,
        FollowConnection = followConnection,
        
        -- Méthode pour détruire le chemin
        Destroy = function(self)
            if self.FollowConnection then
                self.FollowConnection:Disconnect()
            end
            if self.UpdateTask then
                task.cancel(self.UpdateTask)
            end
            if self.Folder and self.Folder.Parent then
                self.Folder:Destroy()
            end
        end,
        
        -- Méthode pour mettre à jour la cible
        UpdateTarget = function(self, newTarget)
            if typeof(newTarget) == "Vector3" then
                targetPosition = newTarget
                targetObject = nil
            elseif typeof(newTarget) == "Instance" then
                targetObject = newTarget
                if newTarget:IsA("BasePart") then
                    targetPosition = newTarget.Position
                elseif newTarget:IsA("Model") and newTarget.PrimaryPart then
                    targetPosition = newTarget.PrimaryPart.Position
                end
            end
        end
    }
end

return TutorialArrowSystem
