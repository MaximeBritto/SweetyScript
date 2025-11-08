local boards = workspace:WaitForChild("DonoBoard")
local pagenumbers = {}

local buttons = boards:WaitForChild("Buttons")
local screen = boards:WaitForChild("Screen")

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
  
  if screen then
    local takeModel = screen.SurfaceGui.MainFrame.Footer:FindFirstChild("TakeModel")
    if takeModel then
      takeModel.Activated:Connect(function()
        game:GetService("MarketplaceService"):PromptPurchase(game.Players.LocalPlayer,8482978293)
      end)
    end
  end
  
  if buttons.SurfaceGui.MainFrame:FindFirstChild("Pages") then
    for _,page in pairs(buttons.SurfaceGui.MainFrame.Pages:GetChildren()) do
      if page:IsA("Frame") then
        for _,v in pairs(page:GetChildren()) do
          if v:IsA("TextButton") then
            v.Activated:Connect(function()
              boards.MainScript.UpdateplayerDonoStats:FireServer(v.Name)
            end)
          end
        end
      end
    end
  else
    for i,v in pairs(buttons.SurfaceGui.MainFrame.Scroll:GetChildren()) do
      if v:IsA("TextButton") then
        v.Activated:Connect(function()
          boards.MainScript.UpdateplayerDonoStats:FireServer(v.Name)
        end)
      end
    end
  end
end