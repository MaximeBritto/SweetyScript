--[[
	🔄 PASSIVE TOGGLE SERVER
	Gère l'activation/désactivation des passifs débloqués
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Créer le RemoteEvent
local toggleEvent = ReplicatedStorage:FindFirstChild("TogglePassive")
if not toggleEvent then
	toggleEvent = Instance.new("RemoteEvent")
	toggleEvent.Name = "TogglePassive"
	toggleEvent.Parent = ReplicatedStorage
end

-- Liste des passifs valides
local VALID_PASSIVES = {
	"EssenceCommune",
	"EssenceRare",
	"EssenceEpique",
	"EssenceLegendaire",
	"EssenceMythique"
}

-- Initialiser PassiveStates pour un joueur
local function initializePassiveStates(player)
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return end
	
	local passiveStates = playerData:FindFirstChild("PassiveStates")
	if not passiveStates then
		passiveStates = Instance.new("Folder")
		passiveStates.Name = "PassiveStates"
		passiveStates.Parent = playerData
	end
	
	-- Créer les BoolValues pour chaque passif (par défaut: activé)
	for _, passiveName in ipairs(VALID_PASSIVES) do
		if not passiveStates:FindFirstChild(passiveName) then
			local state = Instance.new("BoolValue")
			state.Name = passiveName
			state.Value = true -- Par défaut activé
			state.Parent = passiveStates
		end
	end
end

-- Gérer le toggle
toggleEvent.OnServerEvent:Connect(function(player, passiveName)
	-- Vérifier que c'est un passif valide
	if not table.find(VALID_PASSIVES, passiveName) then
		warn("⚠️ [PASSIVE TOGGLE] Passif invalide:", passiveName)
		return
	end
	
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return end
	
	local shopUnlocks = playerData:FindFirstChild("ShopUnlocks")
	if not shopUnlocks then return end
	
	-- Vérifier que le passif est débloqué
	local passiveUnlock = shopUnlocks:FindFirstChild(passiveName)
	if not passiveUnlock or passiveUnlock.Value ~= true then
		warn("⚠️ [PASSIVE TOGGLE] Passif non débloqué:", passiveName)
		return
	end
	
	-- Toggle l'état
	local passiveStates = playerData:FindFirstChild("PassiveStates")
	if not passiveStates then
		initializePassiveStates(player)
		passiveStates = playerData:FindFirstChild("PassiveStates")
	end
	
	local state = passiveStates:FindFirstChild(passiveName)
	if state then
		state.Value = not state.Value
		print("🔄 [PASSIVE TOGGLE]", player.Name, "a", state.Value and "activé" or "désactivé", passiveName)
	end
end)

-- Initialiser pour les joueurs existants et nouveaux
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1) -- Attendre que PlayerData soit créé
		initializePassiveStates(player)
	end)
end)

-- Initialiser pour les joueurs déjà présents
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(1)
		initializePassiveStates(player)
	end)
end

print("✅ [PASSIVE TOGGLE] Système de toggle initialisé")
