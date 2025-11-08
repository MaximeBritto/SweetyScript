print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🚀 [DONATION] MainScript démarré!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local leaderboardbuttons = script:WaitForChild("LeaderBoardButtons")
local firstplace = script.Parent:WaitForChild("FirstPlace")
local secondplace = script.Parent:WaitForChild("SecondPlace")
local therdplace = script.Parent:WaitForChild("ThirdPlace")
local buttons = script.Parent:WaitForChild("Buttons")
local screen = script.Parent:WaitForChild("Screen")
local infomation = script.Parent:WaitForChild("Infomation")

print("✅ [DONATION] Tous les objets chargés")

local datastore = game:GetService("DataStoreService")
local DSLB = datastore:GetOrderedDataStore("DonoPurchaseLB")
local productsmodule = require(script.Parent:WaitForChild("Products"))
local market = game:GetService("MarketplaceService")
local products = productsmodule.Products
local PeopleDonatedinlast1minute = {}

leaderboardbuttons.Disabled = false
leaderboardbuttons.Parent = game.StarterPlayer.StarterPlayerScripts

function Defult()
  coroutine.wrap(updatecharacter)(78217237,1)coroutine.wrap(updatecharacter)(78217237,2)coroutine.wrap(updatecharacter)(78217237,3)
  screen.SurfaceGui.MainFrame.Title.Title.Title.Text = "Top "..infomation.AmountofPlayers.Value.." Donors"
  buttons.SurfaceGui.MainFrame.Scroll.TempDono.Parent = script
  screen.SurfaceGui.MainFrame.Scroll.TempScreen.Parent = script
  for _,v in pairs(screen.SurfaceGui.MainFrame.Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
  if infomation.DoPages.Value then
    local numberofplayers = math.ceil(infomation.AmountofPlayers.Value/15)
    local numberofproducts = math.ceil(#products/4)
    for i = 1,numberofplayers do
      local temp = screen.SurfaceGui.MainFrame.Pages.ScreenPageTemp:Clone()
      temp.Parent = screen.SurfaceGui.MainFrame.Pages
      temp.Name = "P"..i
    end
    screen.SurfaceGui.MainFrame.Pages.P1.Visible = true
    screen.SurfaceGui.MainFrame.Pages.ScreenPageTemp:Destroy()
    screen.SurfaceGui.MainFrame.Scroll:Destroy()
    for i = 1,numberofproducts do
      local temp = buttons.SurfaceGui.MainFrame.Pages.ButtonPageTemp:Clone()
      temp.Parent = buttons.SurfaceGui.MainFrame.Pages
      temp.Name = "P"..i
    end
    buttons.SurfaceGui.MainFrame.Pages.ButtonPageTemp:Destroy()
    buttons.SurfaceGui.MainFrame.Scroll:Destroy()
    if #screen.SurfaceGui.MainFrame.Pages:GetChildren() == 1 then
      screen.SurfaceGui.MainFrame.Footer.PageNumbers:Destroy()
    end
    if #buttons.SurfaceGui.MainFrame.Pages:GetChildren() == 1 then
      buttons.SurfaceGui.MainFrame.Footer.PageNumbers:Destroy()
    end
  else
    buttons.SurfaceGui.MainFrame.Pages:Destroy()
    buttons.SurfaceGui.MainFrame.Footer.PageNumbers:Destroy()
    screen.SurfaceGui.MainFrame.Footer.PageNumbers:Destroy()
    screen.SurfaceGui.MainFrame.Pages:Destroy()
  end
  for place,v in pairs(products) do
    local button = script.TempDono:Clone()
    button.Text = NumberConvert(v.ProductPrice).." Robux"
    button.LayoutOrder = place
    button.Name = v.ProductId
    if infomation.DoPages.Value then
      button.Parent = buttons.SurfaceGui.MainFrame.Pages["P"..math.ceil(place/4)]
    else
      button.Parent = buttons.SurfaceGui.MainFrame.Scroll
    end
  end
end
function find(tab,object,Type)
  for i,v in pairs(tab) do
    if Type == "i" then
      if i == object then
        return true
      end
    elseif Type == "v" then
      if v == object then
        return true
      end
    end
  end
  return false
end
function updatecharacter(userid,number)
  local description = game.Players:GetHumanoidDescriptionFromUserId(tonumber(userid))
  local character
  local animName = "First"

  if number ==1 then
    character = firstplace
    animName = "First"
  elseif number ==2 then
    character = secondplace
    animName = "Second"
  elseif number ==3 then
    character = therdplace
    animName = "Third"
  end

  local humanoid = character:WaitForChild("Humanoid")
  local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator",humanoid)
  local animation = nil
  local playingtrack = animator:GetPlayingAnimationTracks()
  for i,track in pairs(playingtrack) do
    if track.Name == animName then
      animation = track
    end
  end
  if animation == nil then
    animation = humanoid:LoadAnimation(infomation.CharacterAnimations[animName])
  end
  animation.Looped = true
  animation:Play()

  character.Humanoid:ApplyDescription(description)
  if character:FindFirstChild("Tags") then
    character.Tags.Container.pName.Text = game.Players:GetNameFromUserIdAsync(tonumber(userid))
  end

end
function NumberConvert(num)
  local x = tostring(num)
  if #x:split("") < 7 then
    if #x>=10 then
      local important = (#x-9)
      return x:sub(0,(important))..","..x:sub(important+1,important+3)..","..x:sub(important+4,important+6)..","..x:sub(important+7)
    elseif #x>= 7 then
      local important = (#x-6)
      return x:sub(0,(important))..","..x:sub(important+1,important+3)..","..x:sub(important+4)
    elseif #x>=4 then
      return x:sub(0,(#x-3))..","..x:sub((#x-3)+1)
    else
      return num
    end
  else
    local suffixes = {"k","M","B","T","qd","Qn","sx","Sp","O","N","de","Ud","DD","tdD","qdD","QnD","sxD","SpD","OcD","NvD","Vgn","UVg","DVg","TVg","qtV","QnV","SeV","SPG","OVG","NVG"}
    local amnt = math.floor(((#x)-1)/3)
    local remove = 3*amnt
    local important = (#x-6)
    if suffixes [amnt] then
      local retuen
      if important+1 > 0 then
        retuen = x:sub(0,(important)).."."..x:sub(important+1,important+1)..suffixes[amnt]
      else
        retuen =  x:sub(0,(important))..suffixes[amnt]
      end
      return retuen
    end
  end
end
function receipt(receiptInfo)
  print("💳 [DONATION MAINSCRIPT] Receipt reçu - ProductId:", receiptInfo.ProductId, "UserId:", receiptInfo.PlayerId)
  
  -- Trouver le prix du produit dans notre liste
  local price = 0
  for _, prod in ipairs(products) do
    if prod.ProductId == receiptInfo.ProductId then
      price = prod.ProductPrice
      break
    end
  end
  
  if price > 0 then
    print("✅ [DONATION MAINSCRIPT] Donation de", price, "Robux enregistrée")
    DSLB:IncrementAsync(receiptInfo.PlayerId, price)
    return Enum.ProductPurchaseDecision.PurchaseGranted
  else
    warn("⚠️ [DONATION MAINSCRIPT] Produit inconnu, ignoré")
    return Enum.ProductPurchaseDecision.NotProcessedYet
  end
end

-- Attendre un peu pour s'assurer qu'on écrase tous les autres ProcessReceipt
task.wait(1)

market.ProcessReceipt = receipt
print("✅ [DONATION MAINSCRIPT] ProcessReceipt configuré (après délai)")

-- Vérifier toutes les 10 secondes qu'on est toujours le ProcessReceipt actif
task.spawn(function()
	while true do
		task.wait(10)
		if market.ProcessReceipt ~= receipt then
			warn("⚠️ [DONATION] ProcessReceipt a été écrasé! On le restaure...")
			market.ProcessReceipt = receipt
		end
	end
end)
Defult()

function updateboard()
  if infomation.DoPages.Value then
    for _,page in pairs(screen.SurfaceGui.MainFrame.Pages:GetChildren()) do for _,v in pairs(page:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end end
  else
    for _,v in pairs(screen.SurfaceGui.MainFrame.Scroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
  end

  local success, errorMessage = pcall(function()
    local Data
    if infomation.AmountofPlayers.Value < 0 then
      Data= DSLB:GetSortedAsync(false,15)
    elseif infomation.AmountofPlayers.Value > 60 then
      Data= DSLB:GetSortedAsync(false,60)
    else
      Data= DSLB:GetSortedAsync(false,infomation.AmountofPlayers.Value)
    end
    local WinPage = Data:GetCurrentPage()
    for Rank, data in ipairs(WinPage) do
      local userName = game.Players:GetNameFromUserIdAsync(data.key)
      local Name = userName
      local amount = data.value
      local isOnLeaderboard = false
      if infomation.DoPages.Value then
        for _,page in pairs(screen.SurfaceGui.MainFrame.Pages:GetChildren()) do for _,v in pairs(page:GetChildren()) do if v.Name == Name then isOnLeaderboard = true break end end end
      else
        for _,v in pairs(screen.SurfaceGui.MainFrame.Scroll:GetChildren()) do if v.Name == Name then isOnLeaderboard = true break end end
      end
      if amount > 0 and isOnLeaderboard == false  then
        if Rank <= 3 then
          coroutine.wrap(updatecharacter)(data.key,Rank)
        end
        local newLBFrame = script.TempScreen:Clone()
        newLBFrame.Title.Text = Name
        newLBFrame.Explaination.Text = coroutine.wrap(NumberConvert)(amount)
        newLBFrame.LayoutOrder = Rank
        newLBFrame.Name = Name
        newLBFrame.Visible = true
        if infomation.ShowUserThumbnail.Value then
          newLBFrame.Icon.Image = game.Players:GetUserThumbnailAsync(data.key,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420)
        else
          newLBFrame.Icon:Destroy()
        end
        if infomation.DoPages.Value then 
          newLBFrame.Parent = screen.SurfaceGui.MainFrame.Pages["P"..math.ceil(Rank/15)]
        else 
          newLBFrame.Parent = screen.SurfaceGui.MainFrame.Scroll
        end
        local color = nil
        if Rank == 1 then color = infomation.PlaceColors.First.Value
        elseif Rank == 2 then color = infomation.PlaceColors.Second.Value
        elseif Rank == 3 then color = infomation.PlaceColors.Third.Value
        elseif Rank <= 5 and Rank > 3  then color = infomation.PlaceColors.FouthAndFith.Value
        else color = infomation.PlaceColors.Rest.Value end

        newLBFrame.Title.BackgroundColor3 = color
        newLBFrame.Explaination.BackgroundColor3 = color
      end
    end
  end)

  if not success then
    print("TimeLB error: "..errorMessage)
  end
end

script.UpdateplayerDonoStats.OnServerEvent:Connect(function(player,product)
  market:PromptProductPurchase(player,tonumber(product))
end)
game.Players.PlayerRemoving:Connect(function(player)
  local num = 0
  if find(PeopleDonatedinlast1minute,player.UserId,"i") then
    if DSLB:GetAsync(player.UserId) then
      num = DSLB:GetAsync(player.UserId)
    end
    DSLB:SetAsync(player.UserId,PeopleDonatedinlast1minute[player.UserId] + num)
    PeopleDonatedinlast1minute[player.UserId] = 0
  end
end)

updateboard()
while wait(0) do
  for i,v in pairs(PeopleDonatedinlast1minute) do
    if v > 0 then
      if DSLB:GetAsync(i) then
        num = DSLB:GetAsync(i)
      end
      DSLB:SetAsync(i,v)
    end
  end
  table.clear(PeopleDonatedinlast1minute)
  print(PeopleDonatedinlast1minute)
  wait(1)
  updateboard()
  wait(10) -- Mise à jour toutes les 10 secondes
end
