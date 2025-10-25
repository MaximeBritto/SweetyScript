--------------------------------------------------------------------
-- ConfigurerCouleursFleches.lua
-- Configuration simple des flèches animées
-- Place ce script dans ServerScriptService
--------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TutorialArrowSystem = require(ReplicatedStorage:WaitForChild("TutorialArrowSystem"))

print("🎨 [CONFIG] Configuration des flèches...")

--------------------------------------------------------------------
-- CONFIGURATIONS DE COULEUR
--------------------------------------------------------------------

-- Configuration 1: Doré (par défaut)
-- TutorialArrowSystem.SetColors(Color3.fromRGB(255, 215, 0))

-- Configuration 2: Bleu Néon
-- TutorialArrowSystem.SetColors(Color3.fromRGB(0, 200, 255))

-- Configuration 3: Vert Émeraude
-- TutorialArrowSystem.SetColors(Color3.fromRGB(0, 255, 150))

-- Configuration 4: Rose/Magenta
-- TutorialArrowSystem.SetColors(Color3.fromRGB(255, 100, 200))

-- Configuration 5: Orange Feu
-- TutorialArrowSystem.SetColors(Color3.fromRGB(255, 150, 0))

-- Configuration 6: Violet Mystique
-- TutorialArrowSystem.SetColors(Color3.fromRGB(150, 0, 255))

-- Configuration 7: Rouge Urgence
-- TutorialArrowSystem.SetColors(Color3.fromRGB(255, 50, 50))

-- Configuration 8: Blanc Pur
-- TutorialArrowSystem.SetColors(Color3.fromRGB(255, 255, 255))

--------------------------------------------------------------------
-- CONFIGURATIONS D'ANIMATION
--------------------------------------------------------------------

-- Vitesse des flèches (par défaut: 15 studs/seconde)
-- TutorialArrowSystem.SetArrowSpeed(15)
-- Plus rapide: 25
-- Plus lent: 8

-- Nombre de flèches animées (par défaut: 5)
-- TutorialArrowSystem.SetNumArrows(5)
-- Plus de flèches: 8
-- Moins de flèches: 3

-- Espacement des points du chemin (par défaut: 8 studs)
-- TutorialArrowSystem.SetPathSpacing(8)

-- Rotation de base de la flèche (par défaut: -90)
-- Ajuste selon l'orientation de ton image:
-- TutorialArrowSystem.SetArrowRotation(-90)  -- Image pointe vers la droite → flèche vers le haut
-- TutorialArrowSystem.SetArrowRotation(0)    -- Image pointe vers le haut → pas de rotation
-- TutorialArrowSystem.SetArrowRotation(90)   -- Image pointe vers la gauche → flèche vers le haut
-- TutorialArrowSystem.SetArrowRotation(180)  -- Image pointe vers le bas → flèche vers le haut

--------------------------------------------------------------------
-- PATHFINDING
--------------------------------------------------------------------

-- Activer/désactiver le pathfinding (par défaut: activé)
-- TutorialArrowSystem.SetPathfinding(true)

print("✅ [CONFIG] Configuration terminée!")
