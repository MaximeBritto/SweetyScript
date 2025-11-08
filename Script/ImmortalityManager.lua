-- ImmortalityManager.lua
-- Empêche les joueurs de mourir dans le jeu (y compris la commande /suicide)

local Players = game:GetService("Players")

-- Fonction pour rendre un personnage immortel
local function makeCharacterImmortal(character)
	local humanoid = character:WaitForChild("Humanoid")
	
	-- Bloquer la commande /suicide en empêchant BreakJointsOnDeath
	humanoid.BreakJointsOnDeath = false
	
	-- Empêcher la mort en réinitialisant la santé
	humanoid.Died:Connect(function()
		humanoid.Health = humanoid.MaxHealth
	end)
	
	-- Surveiller les changements de santé et empêcher qu'elle descende à 0
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
	
	-- Protection supplémentaire contre les changements de propriétés
	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if humanoid.Health <= 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

-- Appliquer l'immortalité à tous les joueurs existants et futurs
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		makeCharacterImmortal(character)
	end)
	
	-- Si le personnage existe déjà
	if player.Character then
		makeCharacterImmortal(player.Character)
	end
end)

-- Appliquer aux joueurs déjà présents
for _, player in pairs(Players:GetPlayers()) do
	if player.Character then
		makeCharacterImmortal(player.Character)
	end
	
	player.CharacterAdded:Connect(function(character)
		makeCharacterImmortal(character)
	end)
end

print("ImmortalityManager: Système d'immortalité activé")
