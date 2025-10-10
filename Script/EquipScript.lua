-- Script nommé par exemple "EquipScript"

local tool = script.Parent
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local handle = tool:WaitForChild("Handle")
local rightHand = character:WaitForChild("RightHand")

local weld = nil

tool.Equipped:Connect(function()
	-- Créer une soudure pour attacher le modèle à la main
	weld = Instance.new("Weld")
	weld.Name = "HandleWeld"
	weld.Part0 = rightHand
	weld.Part1 = handle.PrimaryPart -- C'est ici que le PrimaryPart est crucial !
	-- Rotation de 90 degrés sur l'axe X pour rendre le bonbon vertical
	-- Ajustez l'offset (0, -1, 0) selon la taille de vos bonbons
	weld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(90), 0, 0)
	weld.Parent = rightHand
end)

tool.Unequipped:Connect(function()
	-- Détruire la soudure quand on déséquipe l'outil
	if weld then
		weld:Destroy()
		weld = nil
	end
end)