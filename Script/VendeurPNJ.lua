-- Script vendeur ultra-simple et robuste
print("🚀 [VENDEUR] Démarrage...")

local vendeur = script.Parent
print("📍 [VENDEUR] Dans:", vendeur.Name)
print("📍 [VENDEUR] Type:", vendeur.ClassName)

-- Trouver une Part dans le Model pour le ProximityPrompt
local targetPart = nil
if vendeur:IsA("BasePart") then
	targetPart = vendeur
	print("✅ [VENDEUR] C'est déjà une Part")
elseif vendeur:IsA("Model") then
	-- Chercher spécifiquement la Part VendeurBody
	targetPart = vendeur:FindFirstChild("VendeurBody")
	if targetPart and targetPart:IsA("BasePart") then
		print("✅ [VENDEUR] VendeurBody trouvée!")
	else
		print("❌ [VENDEUR] VendeurBody manquante!")
		print("💡 [VENDEUR] Créez une Part nommée 'VendeurBody' dans le Model VendeurPNJ")
		print("🔍 [VENDEUR] Contenu actuel:")
		for _, child in pairs(vendeur:GetChildren()) do
			print("  -", child.Name, "(", child.ClassName, ")")
		end
		return
	end
else
	print("❌ [VENDEUR] Type non supporté:", vendeur.ClassName)
	return
end

-- Créer ProximityPrompt sur la Part
print("🔧 [VENDEUR] Création ProximityPrompt sur:", targetPart.Name)
local prox = Instance.new("ProximityPrompt")
prox.ActionText = "Buy"
prox.ObjectText = "Shop"
prox.HoldDuration = 0
prox.MaxActivationDistance = 15
prox.RequiresLineOfSight = false
prox.Parent = targetPart
print("✅ [VENDEUR] ProximityPrompt créé sur la Part!")

-- Récupérer le RemoteEvent pour le menu
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ouvrirMenuEvent = ReplicatedStorage:FindFirstChild("OuvrirMenuEvent")
if not ouvrirMenuEvent then
	print(" [VENDEUR] OuvrirMenuEvent manquant, création...")
	ouvrirMenuEvent = Instance.new("RemoteEvent")
	ouvrirMenuEvent.Name = "OuvrirMenuEvent"
	ouvrirMenuEvent.Parent = ReplicatedStorage
	print(" [VENDEUR] OuvrirMenuEvent créé")
else
	print(" [VENDEUR] OuvrirMenuEvent trouvé")
end

-- Fonction qui ouvre le vrai menu
local function vendeurClique(player)
	print("🛒 [VENDEUR] Clic par:", player.Name)

	-- Vérifier si le joueur est en tutoriel
	if _G.TutorialManager then
		local step = _G.TutorialManager.getTutorialStep(player)
		if step then
			print("🛒 [VENDEUR] Joueur en tutoriel (étape:", step, ")")
			_G.TutorialManager.onVendorApproached(player)
		end
	end

	-- Ouvrir le menu d'achat
	print("🛒 [VENDEUR] Envoi OuvrirMenuEvent vers", player.Name)
	ouvrirMenuEvent:FireClient(player)
	print("🛒 [VENDEUR] Menu envoyé à:", player.Name)
end

-- Connecter
prox.Triggered:Connect(vendeurClique)
print(" [VENDEUR] Connecté! Prêt!")
print(" [VENDEUR] Approchez-vous et appuyez E")
