-- FixCandySellTest.lua
-- Script pour tester les corrections du menu de vente
-- À exécuter dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Forcer la création du menu de vente après chargement
player.CharacterAdded:Connect(function()
    wait(3) -- Attendre que tout soit chargé
    
    print("=== TEST CANDY SELL UI FIXES ===")
    
    -- Vérifier la détection de plateforme
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
    
    print("Viewport:", viewportSize.X .. "x" .. viewportSize.Y)
    print("Platform:", isMobile and "MOBILE" or "DESKTOP")
    print("Small Screen:", isSmallScreen)
    
    -- Tester la taille calculée pour le menu
    local frameWidth, frameHeight
    if isMobile or isSmallScreen then
        frameWidth = math.min(viewportSize.X * 0.95, 400)
        frameHeight = math.min(viewportSize.Y * 0.85, 600)
        print("Mobile size:", frameWidth .. "x" .. frameHeight)
    else
        frameWidth = 500
        frameHeight = 550
        if viewportSize.X < 800 then
            frameWidth = math.min(viewportSize.X * 0.8, 450)
        end
        if viewportSize.Y < 700 then
            frameHeight = math.min(viewportSize.Y * 0.8, 500)
        end
        print("Desktop size:", frameWidth .. "x" .. frameHeight)
    end
    
    -- Essayer d'ouvrir le menu de vente
    if _G.openSellMenu then
        print("✅ Menu de vente disponible via _G.openSellMenu")
    else
        print("❌ Menu de vente non disponible")
    end
    
    print("==============================")
end)

-- Commande pour ouvrir le menu
player.Chatted:Connect(function(message)
    if message:lower() == "/sell" or message:lower() == "/vente" then
        if _G.openSellMenu then
            _G.openSellMenu()
            print("Menu de vente ouvert !")
        else
            print("Menu de vente non disponible")
        end
    end
end)

print("CandySell Test chargé ! Tapez /sell ou /vente pour tester.")
