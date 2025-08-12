-- Script vendeur complet et fonctionnel
print("🔥 VENDEUR SCRIPT COMPLET CHARGÉ")

local vendeur = script.Parent
print("📍 Vendeur:", vendeur.Name)

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
print("📦 ReplicatedStorage trouvé")

-- Créer ou récupérer le RemoteEvent
local ouvrirMenuEvent = ReplicatedStorage:FindFirstChild("OuvrirMenuEvent")
if not ouvrirMenuEvent then
    print("⚠️ OuvrirMenuEvent n'existe pas, création...")
    ouvrirMenuEvent = Instance.new("RemoteEvent")
    ouvrirMenuEvent.Name = "OuvrirMenuEvent"
    ouvrirMenuEvent.Parent = ReplicatedStorage
    print("✅ OuvrirMenuEvent créé")
else
    print("✅ OuvrirMenuEvent trouvé")
end

-- Créer le ProximityPrompt
local proximityPrompt = vendeur:FindFirstChild("ProximityPrompt")
if not proximityPrompt then
    proximityPrompt = Instance.new("ProximityPrompt")
    proximityPrompt.ActionText = "Acheter"
    proximityPrompt.ObjectText = "Vendeur"
    proximityPrompt.HoldDuration = 0
    proximityPrompt.MaxActivationDistance = 10
    proximityPrompt.RequiresLineOfSight = false
    proximityPrompt.Parent = vendeur
    print("✅ ProximityPrompt créé avec succès")
else
    print("✅ ProximityPrompt existant trouvé")
end

-- Fonction quand le joueur interagit
local function onVendeurClicked(player)
    print("🔔 [VENDEUR] Interaction par:", player.Name)
    
    -- Vérifier si le joueur est en tutoriel
    if _G.TutorialManager then
        local step = _G.TutorialManager.getTutorialStep(player)
        if step then
            print("🛒 [VENDEUR] Joueur en tutoriel (étape:", step, ")")
            _G.TutorialManager.onVendorApproached(player)
        end
    end
    
    -- Ouvrir le menu d'achat
    ouvrirMenuEvent:FireClient(player)
    print("📤 [VENDEUR] Menu envoyé à:", player.Name)
end

-- Connecter l'événement
proximityPrompt.Triggered:Connect(onVendeurClicked)
print("🔗 [VENDEUR] Événement connecté")

print("🎯 [VENDEUR] Prêt ! Approchez-vous et appuyez E")
