--------------------------------------------------------------------
-- ScreenOrientationLock.lua - Force le mode paysage sur mobile
-- À placer dans: StarterPlayer → StarterPlayerScripts
--------------------------------------------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Vérifier si on est sur mobile
local function isMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

print("📱 [ORIENTATION] Script chargé, détection mobile:", isMobile())

-- Forcer le mode paysage IMMÉDIATEMENT via PlayerGui
if isMobile() then
	print("📱 [ORIENTATION] Appareil mobile détecté, forçage du mode paysage...")
	
	-- Méthode 1 : Via PlayerGui (plus fiable)
	task.spawn(function()
		local success = pcall(function()
			playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft
		end)
		if success then
			print("✅ [ORIENTATION] Mode paysage verrouillé via PlayerGui")
		else
			print("⚠️ [ORIENTATION] PlayerGui.ScreenOrientation non disponible")
		end
	end)
	
	-- Méthode 2 : Via StarterGui (backup)
	task.spawn(function()
		local StarterGui = game:GetService("StarterGui")
		local success = pcall(function()
			StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft
		end)
		if success then
			print("✅ [ORIENTATION] Mode paysage verrouillé via StarterGui")
		else
			print("⚠️ [ORIENTATION] StarterGui.ScreenOrientation non disponible")
		end
	end)
	
	-- Méthode 3 : Forcer via un ScreenGui avec ScreenOrientation
	task.spawn(function()
		local orientationGui = Instance.new("ScreenGui")
		orientationGui.Name = "OrientationLocker"
		orientationGui.ResetOnSpawn = false
		orientationGui.IgnoreGuiInset = true
		orientationGui.DisplayOrder = -1000
		
		local success = pcall(function()
			orientationGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft
		end)
		
		if success then
			orientationGui.Parent = playerGui
			print("✅ [ORIENTATION] Mode paysage verrouillé via ScreenGui dédié")
		else
			print("⚠️ [ORIENTATION] ScreenGui.ScreenOrientation non disponible")
		end
	end)
	
	-- Vérification continue et réapplication
	task.spawn(function()
		while task.wait(1) do
			-- Vérifier PlayerGui
			pcall(function()
				if playerGui.ScreenOrientation ~= Enum.ScreenOrientation.LandscapeLeft then
					playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft
					print("🔄 [ORIENTATION] Réapplication du mode paysage (PlayerGui)")
				end
			end)
			
			-- Vérifier StarterGui
			pcall(function()
				local StarterGui = game:GetService("StarterGui")
				if StarterGui.ScreenOrientation ~= Enum.ScreenOrientation.LandscapeLeft then
					StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeLeft
					print("🔄 [ORIENTATION] Réapplication du mode paysage (StarterGui)")
				end
			end)
		end
	end)
else
	print("💻 [ORIENTATION] Desktop détecté, pas de verrouillage d'orientation")
end

print("✅ [ORIENTATION] Script initialisé")
