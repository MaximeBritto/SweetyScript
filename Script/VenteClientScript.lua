-- Ce script (local) s'exécute quand le joueur clique sur "Vendre"
-- À placer dans le BoutonVendre

local bouton = script.Parent
local venteEvent = game.ReplicatedStorage:WaitForChild("VenteEvent")

local function onBoutonVendreClicked()
    -- On dit au serveur que le joueur veut vendre
    venteEvent:FireServer()
    print("Demande de vente envoyée au serveur")
end

bouton.MouseButton1Click:Connect(onBoutonVendreClicked) 