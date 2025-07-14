-- Ce script gère le PNJ vendeur d'ingrédients
-- À placer dans le PNJ vendeur (Part ou Model) avec un ClickDetector

local vendeur = script.Parent
local clickDetector = vendeur.ClickDetector

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- RemoteEvent pour ouvrir le menu d'achat
local ouvrirMenuEvent = ReplicatedStorage:WaitForChild("OuvrirMenuEvent")

-- Variables pour la bulle de dialogue
local currentDialogue = nil

--------------------------------------------------------------------
-- SYSTÈME DE BULLE DE DIALOGUE
--------------------------------------------------------------------
local function createDialogueBubble(message)
    -- Supprimer l'ancienne bulle si elle existe
    if currentDialogue then
        currentDialogue:Destroy()
        currentDialogue = nil
    end
    
    -- Trouver la tête du vendeur pour positionner la bulle
    local head = vendeur
    if vendeur:IsA("Model") then
        head = vendeur:FindFirstChild("Head") or vendeur:FindFirstChild("Torso") or vendeur:FindFirstChild("HumanoidRootPart") or vendeur:FindFirstChildOfClass("BasePart")
    end
    
    if not head then
        warn("❌ [VENDEUR] Impossible de trouver une partie pour attacher la bulle")
        return
    end
    
    -- Créer le BillboardGui au-dessus de la tête
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "VendorDialogue"
    billboardGui.Size = UDim2.new(0, 300, 0, 80)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0) -- Au-dessus de la tête
    billboardGui.Adornee = head
    billboardGui.Parent = workspace
    
    -- Frame de la bulle
    local bubbleFrame = Instance.new("Frame")
    bubbleFrame.Size = UDim2.new(1, 0, 1, 0)
    bubbleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bubbleFrame.BackgroundTransparency = 0.1
    bubbleFrame.BorderSizePixel = 0
    bubbleFrame.Parent = billboardGui
    
    -- Coins arrondis
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = bubbleFrame
    
    -- Bordure
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 2
    stroke.Parent = bubbleFrame
    
    -- Texte du dialogue
    local dialogueText = Instance.new("TextLabel")
    dialogueText.Size = UDim2.new(1, -10, 1, -10)
    dialogueText.Position = UDim2.new(0, 5, 0, 5)
    dialogueText.BackgroundTransparency = 1
    dialogueText.Text = message
    dialogueText.TextColor3 = Color3.fromRGB(50, 50, 50)
    dialogueText.TextSize = 18
    dialogueText.Font = Enum.Font.GothamBold
    dialogueText.TextWrapped = true
    dialogueText.TextXAlignment = Enum.TextXAlignment.Center
    dialogueText.TextYAlignment = Enum.TextYAlignment.Center
    dialogueText.Parent = bubbleFrame
    
    -- Animation d'apparition
    bubbleFrame.Size = UDim2.new(0, 0, 0, 0)
    bubbleFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local popIn = TweenService:Create(bubbleFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0)
    })
    popIn:Play()
    
    -- Animation de flottement
    local float = TweenService:Create(billboardGui, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        StudsOffset = Vector3.new(0, 3.5, 0)
    })
    float:Play()
    
    currentDialogue = billboardGui
    
    -- Auto-supprimer après 5 secondes
    task.spawn(function()
        task.wait(5)
        if currentDialogue == billboardGui then
            local fadeOut = TweenService:Create(bubbleFrame, TweenInfo.new(0.5), {
                BackgroundTransparency = 1
            })
            local textFadeOut = TweenService:Create(dialogueText, TweenInfo.new(0.5), {
                TextTransparency = 1
            })
            local strokeFadeOut = TweenService:Create(stroke, TweenInfo.new(0.5), {
                Transparency = 1
            })
            
            fadeOut:Play()
            textFadeOut:Play()
            strokeFadeOut:Play()
            
            fadeOut.Completed:Connect(function()
                if currentDialogue == billboardGui then
                    billboardGui:Destroy()
                    currentDialogue = nil
                end
            end)
        end
    end)
    
    return billboardGui
end

local function onVendeurClicked(player)
    print(player.Name .. " a interagi avec le vendeur")
    
    -- Afficher la bulle de dialogue
    createDialogueBubble("Hey tu veux acheter quoi ? 🛒")
    
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

-- On connecte la fonction à l'événement du clic
clickDetector.MouseClick:Connect(onVendeurClicked) 

--------------------------------------------------------------------
-- DIALOGUES AUTOMATIQUES ALÉATOIRES
--------------------------------------------------------------------
local randomDialogues = {
    "Besoin d'ingrédients ? 🧪",
    "J'ai tout ce qu'il vous faut ! ✨",
    "Venez voir mes produits ! 🛒",
    "Ingrédients frais du jour ! 🌟",
    "Psst... j'ai de bonnes affaires ! 💰"
}

-- Afficher un dialogue aléatoire toutes les 30-60 secondes
local function startRandomDialogue()
    task.spawn(function()
        while true do
            task.wait(math.random(30, 60)) -- Entre 30 et 60 secondes
            
            -- Seulement si aucune bulle n'est déjà affichée
            if not currentDialogue then
                local randomMessage = randomDialogues[math.random(1, #randomDialogues)]
                createDialogueBubble(randomMessage)
            end
        end
    end)
end

-- Démarrer les dialogues aléatoires
startRandomDialogue()

print("✅ VendeurPNJ chargé avec système de dialogue") 