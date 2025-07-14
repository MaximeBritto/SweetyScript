-- Ce script gère la production de bonbons avec sélection de recettes
-- À placer dans la MachineDeMelange avec un ClickDetector
-- VERSION V0.3 : Sélection de recettes + timer de production

local machine = script.Parent
local clickDetector = machine.ClickDetector

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- RemoteEvents
local ouvrirRecettesEvent = ReplicatedStorage:WaitForChild("OuvrirRecettesEvent")

local function onMachineClicked(player)
	-- Vérifier si le joueur est déjà en production
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return end

	local enProduction = playerData:FindFirstChild("EnProduction")
	if enProduction and enProduction.Value then
		print(player.Name .. " - Production déjà en cours ! Attendez la fin.")
		return
	end

	-- Ouvrir le menu de sélection de recettes
	ouvrirRecettesEvent:FireClient(player)
end

-- On connecte la fonction à l'événement du clic
clickDetector.MouseClick:Connect(onMachineClicked) 