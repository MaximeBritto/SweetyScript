-- ANCIEN SYSTÈME DE VENTE DÉSACTIVÉ
-- Ce script causait des conflits avec le nouveau CandySellManager
-- Utilisez maintenant la touche V ou le bouton 💰 VENTE dans la hotbar

--[[
local bouton = script.Parent
local venteEvent = game.ReplicatedStorage:WaitForChild("VenteEvent")

local function onBoutonVendreClicked()
    -- On dit au serveur que le joueur veut vendre
    venteEvent:FireServer()
    print("Demande de vente envoyée au serveur")
end

bouton.MouseButton1Click:Connect(onBoutonVendreClicked)
--]]