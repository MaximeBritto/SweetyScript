-- GamepadControlsGlobal.lua
-- Contrôles manette globaux (hors menus)
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- =========================================================
-- TÉLÉPORTATION (copié de TopButtonsUI)
-- =========================================================
local function teleportPlayer(destinationCFrame)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = destinationCFrame * CFrame.new(0, 4, 0)
end

local function getValidPart(obj)
	if obj:IsA("BasePart") then
		return obj
	end
	if obj:IsA("Model") then
		return obj:FindFirstChild("HumanoidRootPart")
			or obj:FindFirstChild("Torso")
			or obj:FindFirstChild("UpperTorso")
			or obj:FindFirstChild("Head")
			or obj.PrimaryPart
			or (function()
				for _, d in ipairs(obj:GetDescendants()) do
					if d:IsA("BasePart") then return d end
				end
				return nil
			end)()
	end
	return nil
end

local function findTeleportTargetByName(name)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local nearest, bestDist
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == name then
			local part = getValidPart(obj)
			if part then
				if hrp then
					local d = (hrp.Position - part.Position).Magnitude
					if not bestDist or d < bestDist then
						nearest, bestDist = part, d
					end
				else
					return part
				end
			end
		end
	end
	return nearest
end

local function findVendor()
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj.Name == "Vendeur" or obj.Name == "VendeurPNJ" then
			local p = getValidPart(obj)
			if p then return p end
		end
	end
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj:IsA("ClickDetector") then
			local parent = obj.Parent
			if parent and parent:IsA("BasePart") then
				local gp = parent.Parent
				if gp and (
					gp.Name:lower():find("vendeur") or
						gp.Name:lower():find("vendor") or
						gp.Name:lower():find("shop")   or
						gp.Name:lower():find("pnj")
					) then
					return getValidPart(gp) or parent
				end
			end
		end
	end
	return nil
end

-- Vérifier si un menu est ouvert
local function isAnyMenuOpen()
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Vérifier le menu d'achat
	local menuAchat = playerGui:FindFirstChild("MenuAchat")
	if menuAchat then
		local menuFrame = menuAchat:FindFirstChild("MenuFrame")
		if menuFrame and menuFrame.Visible then
			return true
		end
	end
	
	-- Vérifier l'UI incubateur
	local incubatorUI = playerGui:FindFirstChild("IncubatorUI")
	if incubatorUI then
		local mainFrame = incubatorUI:FindFirstChild("MainFrame")
		if mainFrame and mainFrame.Visible then
			return true
		end
	end
	
	-- Vérifier le Pokédex
	local pokedexUI = playerGui:FindFirstChild("PokedexUI")
	if pokedexUI then
		local mainFrame = pokedexUI:FindFirstChild("MainFrame")
		if mainFrame and mainFrame.Visible then
			return true
		end
	end
	
	return false
end

-- Cooldowns pour éviter le spam
local lastTeleportTime = 0
local lastUIOpenTime = 0
local COOLDOWN = 1 -- 1 seconde entre chaque action

-- Gestion des inputs manette globaux
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Ne rien faire si un menu est ouvert
	if isAnyMenuOpen() then return end
	
	-- Ne pas traiter si le jeu a déjà traité l'input (ex: chat)
	if gameProcessed then return end
	
	local now = tick()
	
	-- Triangle (Y sur Xbox) : Ouvrir le menu de vente
	if input.KeyCode == Enum.KeyCode.ButtonY then
		if now - lastUIOpenTime >= COOLDOWN then
			lastUIOpenTime = now
			
			-- Utiliser la même fonction que le bouton VENTE
			if _G.openSellMenu then
				_G.openSellMenu()
				print("🎮 [GAMEPAD] Ouverture du menu de vente")
			else
				warn("⚠️ [GAMEPAD] Menu de vente non encore chargé")
			end
		end
	end
	
	-- L2 : Téléporter à l'île (via SpawnLocation)
	if input.KeyCode == Enum.KeyCode.ButtonL2 then
		if now - lastTeleportTime >= COOLDOWN then
			lastTeleportTime = now
			
			-- Chercher le SpawnLocation de l'île
			local spawnPoint = Workspace:FindFirstChild("SpawnLocation")
			if not spawnPoint then
				-- Fallback: chercher dans les descendants
				for _, obj in ipairs(Workspace:GetDescendants()) do
					if obj.Name == "SpawnLocation" and obj:IsA("SpawnLocation") then
						spawnPoint = obj
						break
					end
				end
			end
			
			if spawnPoint then
				teleportPlayer(spawnPoint.CFrame)
				print("🎮 [GAMEPAD] Téléportation à l'île")
			else
				warn("⚠️ [GAMEPAD] SpawnLocation introuvable")
			end
		end
	end
	
	-- R2 : Téléporter au vendeur (via TeleportSeller)
	if input.KeyCode == Enum.KeyCode.ButtonR2 then
		if now - lastTeleportTime >= COOLDOWN then
			lastTeleportTime = now
			
			-- Chercher le TeleportSeller
			local spawnPoint = Workspace:FindFirstChild("TeleportSeller")
			if not spawnPoint then
				-- Fallback: chercher dans les descendants
				for _, obj in ipairs(Workspace:GetDescendants()) do
					if obj.Name == "TeleportSeller" and obj:IsA("BasePart") then
						spawnPoint = obj
						break
					end
				end
			end
			
			if spawnPoint and spawnPoint:IsA("BasePart") then
				teleportPlayer(spawnPoint.CFrame)
				print("🎮 [GAMEPAD] Téléportation au vendeur")
			else
				warn("⚠️ [GAMEPAD] TeleportSeller introuvable")
			end
		end
	end
end)

print("✅ [GAMEPAD] Contrôles manette globaux chargés")
print("🎮 Contrôles hors menu:")
print("  • Triangle (Y) : Ouvrir le menu de vente")
print("  • L2 : Téléporter à l'île")
print("  • R2 : Téléporter au vendeur")
print("  • R1/L1 : Changer de slot hotbar")
