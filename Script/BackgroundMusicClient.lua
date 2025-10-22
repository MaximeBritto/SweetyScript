-- Script client pour jouer la musique de fond du jeu en boucle
-- À placer dans StarterPlayer > StarterPlayerScripts

local SoundService = game:GetService("SoundService")

-- ID de la musique de fond
local BACKGROUND_MUSIC_ID = "rbxassetid://126890608257191"

-- Créer le son de fond
local backgroundMusic = Instance.new("Sound")
backgroundMusic.Name = "BackgroundMusic"
backgroundMusic.SoundId = BACKGROUND_MUSIC_ID
backgroundMusic.Volume = 0.3  -- Volume à 30% pour ne pas être trop fort
backgroundMusic.Looped = true  -- Jouer en boucle
backgroundMusic.Parent = SoundService

-- Attendre un peu avant de jouer (pour éviter les problèmes de chargement)
task.wait(1)

-- Jouer la musique
backgroundMusic:Play()

print("🎵 [MUSIC] Musique de fond lancée en boucle !")

-- API pour contrôler le volume (optionnel)
_G.SetBackgroundMusicVolume = function(volume)
	if typeof(volume) == "number" and volume >= 0 and volume <= 1 then
		backgroundMusic.Volume = volume
		print("🎵 [MUSIC] Volume changé à:", volume * 100, "%")
	else
		warn("🎵 [MUSIC] Volume invalide (doit être entre 0 et 1)")
	end
end

-- API pour arrêter/reprendre la musique (optionnel)
_G.ToggleBackgroundMusic = function()
	if backgroundMusic.Playing then
		backgroundMusic:Pause()
		print("🎵 [MUSIC] Musique mise en pause")
	else
		backgroundMusic:Resume()
		print("🎵 [MUSIC] Musique reprise")
	end
end

print("✅ [MUSIC] Contrôles disponibles:")
print("   _G.SetBackgroundMusicVolume(0.5) -- Change le volume (0 à 1)")
print("   _G.ToggleBackgroundMusic() -- Pause/Reprend la musique")
