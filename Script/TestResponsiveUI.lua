-- TestResponsiveUI.lua
-- Script de test pour vérifier la responsiveness des interfaces
-- À exécuter dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Test de détection de plateforme
local function testPlatformDetection()
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
    
    print("=== TEST DÉTECTION PLATEFORME ===")
    print("ViewportSize:", viewportSize.X .. "x" .. viewportSize.Y)
    print("TouchEnabled:", UserInputService.TouchEnabled)
    print("KeyboardEnabled:", UserInputService.KeyboardEnabled)
    print("isMobile:", isMobile)
    print("isSmallScreen:", isSmallScreen)
    print("Platform:", isMobile and "MOBILE" or "DESKTOP")
    print("==============================")
end

-- Test des interfaces existantes
local function testInterfaces()
    print("=== TEST INTERFACES EXISTANTES ===")
    
    wait(3) -- Attendre que tout soit chargé
    
    -- Vérifier CustomBackpack
    local customBackpack = playerGui:FindFirstChild("CustomBackpack")
    if customBackpack then
        print("✅ CustomBackpack trouvé")
        local hotbar = customBackpack:FindFirstChild("CustomHotbar")
        local inventoryFrame = customBackpack:FindFirstChild("InventoryFrame")
        print("   - Hotbar:", hotbar and "✅" or "❌")
        print("   - InventoryFrame:", inventoryFrame and "✅" or "❌")
        if hotbar then
            local slotCount = 0
            for _, child in pairs(hotbar:GetChildren()) do
                if child.Name:match("HotbarSlot_") then
                    slotCount = slotCount + 1
                end
            end
            print("   - Slots trouvés:", slotCount)
        end
    else
        print("❌ CustomBackpack non trouvé")
    end
    
    -- Vérifier CandySellUI
    local sellUI = playerGui:FindFirstChild("CandySellUI")
    if sellUI then
        print("✅ CandySellUI trouvé")
        local sellFrame = sellUI:FindFirstChild("SellFrame")
        if sellFrame then
            print("   - SellFrame size:", sellFrame.Size.X.Offset .. "x" .. sellFrame.Size.Y.Offset)
        end
    else
        print("❌ CandySellUI non trouvé")
    end
    
    print("===============================")
end

-- Initialisation
testPlatformDetection()

-- Test différé des interfaces
task.spawn(function()
    testInterfaces()
end)

-- Commandes de test via chat
player.Chatted:Connect(function(message)
    if message == "/testui" then
        testInterfaces()
    elseif message == "/testplatform" then
        testPlatformDetection()
    end
end)

print("Script de test UI chargé ! Tapez /testui ou /testplatform pour tester.")
