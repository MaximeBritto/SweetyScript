-- Ce script gère le PNJ vendeur d'ingrédients
-- À placer dans le PNJ vendeur (Part ou Model)

local vendeur = script.Parent

-- Créer ou récupérer le ProximityPrompt (fonctionne avec outils équipés)
local proximityPrompt = vendeur:FindFirstChild("ProximityPrompt")
if not proximityPrompt then
    proximityPrompt = Instance.new("ProximityPrompt")
    proximityPrompt.ActionText = "Acheter"
    proximityPrompt.ObjectText = "Vendeur"
    proximityPrompt.HoldDuration = 0
    proximityPrompt.MaxActivationDistance = 10
    proximityPrompt.RequiresLineOfSight = false
    proximityPrompt.Parent = vendeur
end

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- RemoteEvent pour ouvrir le menu d'achat
local ouvrirMenuEvent = ReplicatedStorage:WaitForChild("OuvrirMenuEvent")

local function onVendeurClicked(player)
	print("🔔 [DEBUG VENDEUR] Interaction déclenchée par:", player.Name)
	print(player.Name .. " a interagi avec le vendeur")

	-- Vérifier si le joueur est en tutoriel et notifier
	if _G.TutorialManager then
		local step = _G.TutorialManager.getTutorialStep(player)
		if step then
			print("🛒 [VENDEUR] Joueur en tutoriel (étape:", step, ") - notification du clic")
			_G.TutorialManager.onVendorApproached(player)
		end
	end

	-- On dit au client d'ouvrir le menu d'achat
	ouvrirMenuEvent:FireClient(player)
end

-- On connecte la fonction à l'événement ProximityPrompt
proximityPrompt.Triggered:Connect(onVendeurClicked)

print("📝 [DEBUG VENDEUR] Script vendeur chargé dans:", vendeur.Name)
print("📝 [DEBUG VENDEUR] Type de l'objet:", vendeur.ClassName)
print("📝 [DEBUG VENDEUR] Position:", vendeur.Position or "N/A")
print("📝 [DEBUG VENDEUR] Parent:", vendeur.Parent.Name)
print("📝 [DEBUG VENDEUR] ProximityPrompt créé avec succès")
print("📝 [DEBUG VENDEUR] Distance max:", proximityPrompt.MaxActivationDistance)

-- Vérifier que le vendeur est visible
if vendeur:IsA("BasePart") then
    print("✅ [DEBUG VENDEUR] C'est une Part - OK")
elseif vendeur:IsA("Model") then
    print("✅ [DEBUG VENDEUR] C'est un Model - OK")
    local parts = vendeur:GetChildren()
    print("📝 [DEBUG VENDEUR] Parties du model:", #parts)
else
    print("⚠️ [DEBUG VENDEUR] Type non standard:", vendeur.ClassName)
end 