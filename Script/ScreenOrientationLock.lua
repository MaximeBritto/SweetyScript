--------------------------------------------------------------------
-- ScreenOrientationLock.lua - Force le mode paysage sur mobile
-- À placer dans: StarterPlayer → StarterPlayerScripts
--------------------------------------------------------------------
print("📱 [ORIENTATION] ScreenOrientationLock chargé!")

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Attendre le joueur local
local player = Players.LocalPlayer

-- Forcer immédiatement le mode paysage VERROUILLÉ
print("📱 [ORIENTATION] Forçage du mode paysage verrouillé...")

-- Utiliser LandscapeLeft pour verrouiller l'orientation (pas de rotation possible)
StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft

print("✅ [ORIENTATION] Mode paysage verrouillé (LandscapeLeft)")
