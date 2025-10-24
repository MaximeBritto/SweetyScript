--------------------------------------------------------------------
-- ServerMonitoring.lua - Surveillance et logs détaillés du serveur
--------------------------------------------------------------------
print("📊 [MONITOR] ServerMonitoring chargé!")

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local ENABLE_MONITORING = true  -- Mettre à false pour désactiver
local LOG_TO_CONSOLE = true     -- Afficher dans la console
local SAVE_TO_DATASTORE = false -- Sauvegarder dans un DataStore (optionnel)

--------------------------------------------------------------------
-- DONNÉES DE MONITORING
--------------------------------------------------------------------
local serverStats = {
	startTime = tick(),
	maxPlayersReached = 0,
	totalPlayersJoined = 0,
	totalPlayersRedirected = 0,
	totalPlayersKicked = 0,
	playerHistory = {},
	redirectHistory = {},
	isStudio = RunService:IsStudio()
}

--------------------------------------------------------------------
-- FONCTIONS DE LOG
--------------------------------------------------------------------
local function logEvent(eventType, playerName, details)
	if not ENABLE_MONITORING then return end
	
	local timestamp = tick() - serverStats.startTime
	local logEntry = {
		time = timestamp,
		type = eventType,
		player = playerName,
		details = details or {},
		playerCount = #Players:GetPlayers()
	}
	
	table.insert(serverStats.playerHistory, logEntry)
	
	if LOG_TO_CONSOLE then
		local timeStr = string.format("%.2fs", timestamp)
		print(string.format("📊 [MONITOR] [%s] %s - %s (Joueurs: %d)", 
			timeStr, eventType, playerName, logEntry.playerCount))
		if details then
			for key, value in pairs(details) do
				print(string.format("   └─ %s: %s", key, tostring(value)))
			end
		end
	end
end

local function generateReport()
	local uptime = tick() - serverStats.startTime
	local report = {
		"",
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
		"📊 RAPPORT DE SERVEUR",
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
		string.format("⏱️  Uptime: %.2f secondes (%.2f minutes)", uptime, uptime / 60),
		string.format("🎮 Mode: %s", serverStats.isStudio and "Studio" or "Jeu Réel"),
		string.format("👥 Joueurs actuels: %d", #Players:GetPlayers()),
		string.format("📈 Maximum atteint: %d joueurs", serverStats.maxPlayersReached),
		string.format("✅ Total rejoints: %d joueurs", serverStats.totalPlayersJoined),
		string.format("🔄 Total redirigés: %d joueurs", serverStats.totalPlayersRedirected),
		string.format("❌ Total kickés: %d joueurs", serverStats.totalPlayersKicked),
		"",
		"📜 HISTORIQUE DES ÉVÉNEMENTS:",
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	}
	
	for i, entry in ipairs(serverStats.playerHistory) do
		local timeStr = string.format("%.2fs", entry.time)
		table.insert(report, string.format("[%s] %s - %s (Joueurs: %d)", 
			timeStr, entry.type, entry.player, entry.playerCount))
	end
	
	if #serverStats.redirectHistory > 0 then
		table.insert(report, "")
		table.insert(report, "🔄 REDIRECTIONS DÉTAILLÉES:")
		table.insert(report, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		for i, redirect in ipairs(serverStats.redirectHistory) do
			table.insert(report, string.format("%d. %s - Raison: %s", 
				i, redirect.player, redirect.reason))
		end
	end
	
	table.insert(report, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	table.insert(report, "")
	
	return table.concat(report, "\n")
end

--------------------------------------------------------------------
-- MONITORING DES JOUEURS
--------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	serverStats.totalPlayersJoined = serverStats.totalPlayersJoined + 1
	
	local currentCount = #Players:GetPlayers()
	if currentCount > serverStats.maxPlayersReached then
		serverStats.maxPlayersReached = currentCount
	end
	
	logEvent("CONNEXION", player.Name, {
		UserId = player.UserId,
		AccountAge = player.AccountAge .. " jours"
	})
	
	-- Surveiller si le joueur est redirigé
	task.spawn(function()
		task.wait(2)
		if player:GetAttribute("BeingRedirected") then
			serverStats.totalPlayersRedirected = serverStats.totalPlayersRedirected + 1
			table.insert(serverStats.redirectHistory, {
				player = player.Name,
				reason = "Serveur plein",
				time = tick() - serverStats.startTime
			})
			logEvent("REDIRECTION", player.Name, {
				Raison = "Serveur plein",
				Mode = serverStats.isStudio and "Kick (Studio)" or "Téléportation (Jeu)"
			})
		end
	end)
	
	-- Surveiller l'attribution d'île
	task.spawn(function()
		task.wait(3)
		if player.Parent then  -- Toujours connecté
			local slot = player:GetAttribute("IslandSlot")
			if slot then
				logEvent("ÎLE ATTRIBUÉE", player.Name, {
					Slot = slot
				})
			else
				logEvent("⚠️ PAS D'ÎLE", player.Name, {
					Raison = "Aucun slot attribué"
				})
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local slot = player:GetAttribute("IslandSlot")
	local wasRedirected = player:GetAttribute("BeingRedirected")
	
	if wasRedirected then
		serverStats.totalPlayersKicked = serverStats.totalPlayersKicked + 1
	end
	
	logEvent("DÉCONNEXION", player.Name, {
		Slot = slot or "Aucun",
		Redirigé = wasRedirected and "Oui" or "Non"
	})
end)

--------------------------------------------------------------------
-- COMMANDES CHAT ADMIN
--------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		-- Commande pour afficher le rapport
		if message == "/report" or message == "/stats" then
			print(generateReport())
		end
		
		-- Commande pour afficher le statut actuel
		if message == "/status" then
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("📊 STATUT ACTUEL DU SERVEUR")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("👥 Joueurs connectés:", #Players:GetPlayers())
			print("🏝️ Îles disponibles:", 6 - #Players:GetPlayers())
			if _G.ServerManager then
				print("🔒 Serveur plein?", _G.ServerManager.isServerFull() and "OUI" or "NON")
			end
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		end
		
		-- Commande pour lister les joueurs
		if message == "/players" or message == "/list" then
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("👥 LISTE DES JOUEURS (" .. #Players:GetPlayers() .. "/6)")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			for i, plr in ipairs(Players:GetPlayers()) do
				local slot = plr:GetAttribute("IslandSlot")
				print(string.format("%d. %s - Île %s", i, plr.Name, slot or "Aucune"))
			end
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		end
	end)
end)

--------------------------------------------------------------------
-- RAPPORT AUTOMATIQUE
--------------------------------------------------------------------
-- Afficher un rapport toutes les 2 minutes
task.spawn(function()
	while true do
		task.wait(120)  -- 2 minutes
		if #Players:GetPlayers() > 0 then
			print(generateReport())
		end
	end
end)

-- Afficher un rapport quand le serveur se ferme
game:BindToClose(function()
	print("🛑 [MONITOR] Serveur en cours de fermeture...")
	print(generateReport())
	task.wait(2)
end)

--------------------------------------------------------------------
-- EXPOSER LES FONCTIONS
--------------------------------------------------------------------
_G.ServerMonitoring = {
	getStats = function() return serverStats end,
	generateReport = generateReport,
	logEvent = logEvent
}

print("✅ [MONITOR] ServerMonitoring initialisé")
print("💡 [MONITOR] Commandes disponibles: /report, /status, /players")
