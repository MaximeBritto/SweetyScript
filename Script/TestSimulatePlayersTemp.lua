--------------------------------------------------------------------
-- TestSimulatePlayersTemp.lua - SCRIPT DE TEST TEMPORAIRE
-- ⚠️ À SUPPRIMER APRÈS LES TESTS !
--------------------------------------------------------------------
print("🧪 [TEST] Script de simulation de joueurs chargé")

local Players = game:GetService("Players")

-- ⚠️ ATTENTION : Ce script est UNIQUEMENT pour les tests !
-- Il simule l'arrivée de joueurs pour tester le système de redirection
-- NE PAS UTILISER EN PRODUCTION !

local SIMULATE_PLAYERS = true  -- Mettre à false pour désactiver
local FAKE_PLAYER_COUNT = 5    -- Nombre de joueurs fantômes à simuler (5 = vous serez le 6ème)

if not SIMULATE_PLAYERS then
	print("🧪 [TEST] Simulation désactivée")
	return
end

print("🧪 [TEST] Simulation de", FAKE_PLAYER_COUNT, "joueurs fantômes")

-- Modifier temporairement la fonction getPlayerCount de ServerManager
task.wait(1)

if _G.ServerManager then
	local originalGetPlayerCount = _G.ServerManager.getPlayerCount
	
	_G.ServerManager.getPlayerCount = function()
		local realCount = originalGetPlayerCount()
		local fakeCount = FAKE_PLAYER_COUNT
		local totalCount = realCount + fakeCount
		
		return totalCount
	end
	
	print("✅ [TEST] ServerManager.getPlayerCount() modifié")
	print("🧪 [TEST] Le prochain joueur réel sera considéré comme le", FAKE_PLAYER_COUNT + 1, "ème joueur")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🎮 INSTRUCTIONS:")
	print("   1. Rejoignez avec votre compte principal → Vous serez le joueur", FAKE_PLAYER_COUNT + 1)
	print("   2. Si FAKE_PLAYER_COUNT = 5, vous serez accepté (6ème joueur)")
	print("   3. Si FAKE_PLAYER_COUNT = 6, vous serez redirigé (7ème joueur)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
else
	warn("⚠️ [TEST] ServerManager non trouvé!")
end
