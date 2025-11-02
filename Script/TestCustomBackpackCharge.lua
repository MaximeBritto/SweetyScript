-- TestCustomBackpackCharge.lua
-- Test ultra-simple pour vérifier si CustomBackpack se charge
-- À placer dans StarterPlayer > StarterPlayerScripts

print("\n" .. string.rep("=", 60))
print("🧪 TEST: Vérification du chargement de CustomBackpack")
print(string.rep("=", 60))

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Attendre 2 secondes
task.wait(2)

-- Chercher le script CustomBackpack
local starterPlayerScripts = player:WaitForChild("PlayerScripts", 5)

if starterPlayerScripts then
	print("✅ PlayerScripts trouvé")
	
	local customBackpack = starterPlayerScripts:FindFirstChild("CustomBackpack")
	if customBackpack then
		print("✅ Script CustomBackpack TROUVÉ dans PlayerScripts")
		print("   Type:", customBackpack.ClassName)
		print("   Enabled:", customBackpack.Enabled)
		print("   Parent:", customBackpack.Parent.Name)
	else
		print("❌ Script CustomBackpack NON TROUVÉ dans PlayerScripts")
		print("   Scripts présents:")
		for _, script in ipairs(starterPlayerScripts:GetChildren()) do
			print("   -", script.Name, "(" .. script.ClassName .. ")")
		end
	end
else
	print("❌ PlayerScripts NON TROUVÉ")
end

print(string.rep("=", 60) .. "\n")
