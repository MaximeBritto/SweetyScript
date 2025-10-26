-- VendeurPNJPet.lua
-- Script serveur pour le vendeur de PETs
-- À placer dans le Model VendeurPNJPet > VendeurBody

print("🐾 [VENDEUR PET] Démarrage...")

local vendeur = script.Parent
print("📍 [VENDEUR PET] Dans:", vendeur.Name)
print("📍 [VENDEUR PET] Type:", vendeur.ClassName)

-- Trouver la Part VendeurBody
local targetPart = nil
if vendeur:IsA("BasePart") then
	targetPart = vendeur
	print("✅ [VENDEUR PET] C'est déjà une Part")
elseif vendeur:IsA("Model") then
	targetPart = vendeur:FindFirstChild("VendeurBody")
	if targetPart and targetPart:IsA("BasePart") then
		print("✅ [VENDEUR PET] VendeurBody trouvée!")
	else
		print("❌ [VENDEUR PET] VendeurBody manquante!")
		print("💡 [VENDEUR PET] Créez une Part nommée 'VendeurBody' dans le Model VendeurPNJPet")
		return
	end
else
	print("❌ [VENDEUR PET] Type non supporté:", vendeur.ClassName)
	return
end

-- Créer ProximityPrompt
print("🔧 [VENDEUR PET] Création ProximityPrompt sur:", targetPart.Name)
local prox = Instance.new("ProximityPrompt")
prox.ActionText = "Voir les PETs"
prox.ObjectText = "Animalerie"
prox.HoldDuration = 0
prox.MaxActivationDistance = 15
prox.RequiresLineOfSight = false
prox.Parent = targetPart
print("✅ [VENDEUR PET] ProximityPrompt créé!")

-- Récupérer/créer le RemoteEvent pour ouvrir le menu PET
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ouvrirMenuPetEvent = ReplicatedStorage:FindFirstChild("OuvrirMenuPetEvent")
if not ouvrirMenuPetEvent then
	print("🔧 [VENDEUR PET] Création OuvrirMenuPetEvent...")
	ouvrirMenuPetEvent = Instance.new("RemoteEvent")
	ouvrirMenuPetEvent.Name = "OuvrirMenuPetEvent"
	ouvrirMenuPetEvent.Parent = ReplicatedStorage
	print("✅ [VENDEUR PET] OuvrirMenuPetEvent créé")
else
	print("✅ [VENDEUR PET] OuvrirMenuPetEvent trouvé")
end

-- Fonction d'ouverture du menu
local function vendeurClique(player)
	print("🐾 [VENDEUR PET] Clic par:", player.Name)
	ouvrirMenuPetEvent:FireClient(player)
	print("🐾 [VENDEUR PET] Menu PET envoyé à:", player.Name)
end

-- Connecter le ProximityPrompt
prox.Triggered:Connect(vendeurClique)
print("✅ [VENDEUR PET] Connecté! Prêt!")
print("🐾 [VENDEUR PET] Approchez-vous et appuyez E pour voir les PETs")
