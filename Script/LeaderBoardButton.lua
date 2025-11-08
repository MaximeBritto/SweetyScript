local boards = workspace:WaitForChild("DonoBoard")
local pagenumbers = {}

print("🔍 [DONATION CLIENT] Attente de la réplication des objets...")

-- Attendre que Buttons et Screen soient répliqués du serveur
local buttons = boards:WaitForChild("Buttons", 30)
if not buttons then
  error("❌ [DONATION CLIENT] Timeout: 'Buttons' non répliqué après 30 secondes")
end

local screen = boards:WaitForChild("Screen", 30)
if not screen then
  error("❌ [DONATION CLIENT] Timeout: 'Screen' non répliqué après 30 secondes")
end

print("✅ [DONATION CLIENT] Buttons et Screen chargés!")

function changepage(part,number)
  for i,v in pairs(part.SurfaceGui.MainFrame.Pages:GetChildren()) do
    v.Visible = false
  end
  part.SurfaceGui.MainFrame.Pages["P"..number].Visible = true
  part.SurfaceGui.MainFrame.Footer.PageNumbers.pagumber.TextLabel.Text = "Page: "..number
end

pagenumbers[boards.Name] = {}
if screen.SurfaceGui.MainFrame:FindFirstChild("Pages") and
	screen.SurfaceGui.MainFrame.Footer:FindFirstChild('PageNumbers') then
  pagenumbers[boards.Name]["Screen"] = 1
  local pagenumber = screen.SurfaceGui.MainFrame.Footer.PageNumbers
  changepage(screen,pagenumbers[boards.Name]["Screen"])
  pagenumber.Pre.Activated:Connect(function()
    if pagenumbers[boards.Name]["Screen"] > 1 then
      pagenumbers[boards.Name]["Screen"] -= 1
    elseif pagenumbers[boards.Name]["Screen"] == 1 then
      pagenumbers[boards.Name]["Screen"] = #screen.SurfaceGui.MainFrame.Pages:GetChildren()
    end
    changepage(screen,pagenumbers[boards.Name]["Screen"])
  end)
  pagenumber.Net.Activated:Connect(function()
    if pagenumbers[boards.Name]["Screen"] < #screen.SurfaceGui.MainFrame.Pages:GetChildren()then
      pagenumbers[boards.Name]["Screen"] += 1
    elseif pagenumbers[boards.Name]["Screen"] == #screen.SurfaceGui.MainFrame.Pages:GetChildren() then
      pagenumbers[boards.Name]["Screen"] = 1
    end
    changepage(screen,pagenumbers[boards.Name]["Screen"])
  end)
end

if buttons.SurfaceGui.MainFrame:FindFirstChild("Pages") and buttons.SurfaceGui.MainFrame.Footer:FindFirstChild('PageNumbers') then
  pagenumbers[boards.Name]["Button"] = 1
  local pagenumber = buttons.SurfaceGui.MainFrame.Footer.PageNumbers
  changepage(buttons,pagenumbers[boards.Name]["Button"])
  pagenumber.Pre.Activated:Connect(function()
    if pagenumbers[boards.Name]["Button"] > 1 then
      pagenumbers[boards.Name]["Button"] -= 1
    elseif pagenumbers[boards.Name]["Button"] == 1 then
      pagenumbers[boards.Name]["Button"] = #buttons.SurfaceGui.MainFrame.Pages:GetChildren()
    end
    changepage(buttons,pagenumbers[boards.Name]["Button"])
  end)
  pagenumber.Net.Activated:Connect(function()
    if pagenumbers[boards.Name]["Button"] < #buttons.SurfaceGui.MainFrame.Pages:GetChildren()then
      pagenumbers[boards.Name]["Button"] += 1
    elseif pagenumbers[boards.Name]["Button"] == #buttons.SurfaceGui.MainFrame.Pages:GetChildren() then
      pagenumbers[boards.Name]["Button"] = 1
    end
    changepage(buttons,pagenumbers[boards.Name]["Button"])
  end)
end

if boards:FindFirstChild("Products") then
  local productsmodule = require(boards.Products)
  local products = productsmodule.Products
  
  print("🎮 [DONATION CLIENT] Script de boutons chargé")
  
  if screen then
    local takeModel = screen.SurfaceGui.MainFrame.Footer:FindFirstChild("TakeModel")
    if takeModel then
      takeModel.Activated:Connect(function()
        game:GetService("MarketplaceService"):PromptPurchase(game.Players.LocalPlayer,8482978293)
      end)
    end
  end
  
  if buttons.SurfaceGui.MainFrame:FindFirstChild("Pages") then
    print("🎮 [DONATION CLIENT] Mode Pages détecté")
    local buttonCount = 0
    for _,page in pairs(boards.Buttons.SurfaceGui.MainFrame.Pages:GetChildren()) do
      if page:IsA("Frame") then
        print("🎮 [DONATION CLIENT] Page trouvée:", page.Name)
        for _,v in pairs(page:GetChildren()) do
          if v:IsA("TextButton") then
            buttonCount = buttonCount + 1
            print("🎮 [DONATION CLIENT] Bouton connecté:", v.Name, "Texte:", v.Text)
            v.Activated:Connect(function()
              print("🎯 [DONATION CLIENT] Clic détecté sur bouton:", v.Name)
              boards.MainScript.UpdateplayerDonoStats:FireServer(v.Name)
            end)
          end
        end
      end
    end
    print("🎮 [DONATION CLIENT] Total boutons connectés:", buttonCount)
  else
    print("🎮 [DONATION CLIENT] Mode Scroll détecté")
    local buttonCount = 0
    for i,v in pairs(buttons.SurfaceGui.MainFrame.Scroll:GetChildren()) do
      if v:IsA("TextButton") then
        buttonCount = buttonCount + 1
        print("🎮 [DONATION CLIENT] Bouton connecté:", v.Name, "Texte:", v.Text)
        v.Activated:Connect(function()
          print("🎯 [DONATION CLIENT] Clic détecté sur bouton:", v.Name)
          boards.MainScript.UpdateplayerDonoStats:FireServer(v.Name)
        end)
      end
    end
    print("🎮 [DONATION CLIENT] Total boutons connectés:", buttonCount)
  end
else
  warn("⚠️ [DONATION CLIENT] Module Products introuvable dans DonoBoard!")
end