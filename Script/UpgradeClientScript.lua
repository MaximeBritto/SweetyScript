-- Ce script (local) envoie la demande d'amélioration au serveur
-- À placer dans le BoutonUpgrade

local bouton = script.Parent
local upgradeEvent = game.ReplicatedStorage:WaitForChild("UpgradeEvent")

local function onBoutonUpgradeClicked()
    -- On dit au serveur que le joueur veut améliorer
    upgradeEvent:FireServer()
    print("Demande d'amélioration envoyée au serveur")
end

bouton.MouseButton1Click:Connect(onBoutonUpgradeClicked) 