--== COURONNES FLOTTANTES — 2 anneaux + anneaux d'apparition (rapide) ==--
-- Script SERVEUR – Place-le sous le Tool/Model qui contient un BasePart "Handle"

-- Texture de la couronne
local CROWN_TEX = "rbxassetid://133467336447657"

-- ===== Réglages (scalés via BonbonSkin) =====
-- Géométrie des anneaux
local BASE_RING_RADIUS     = 1.4     -- rayon de l’anneau du haut
local BASE_RING_HEIGHT     = 0.6     -- hauteur de l’anneau du haut
local SECOND_OFFSET_Y      = -0.40   -- décalage vertical anneau du bas (négatif = plus bas)
local SECOND_RADIUS_SCALE  = 0.85    -- rayon anneau bas (en % du haut)

-- Nombre de couronnes par anneau (5–6 au total)
local RING1_POINTS         = 3       -- haut
local RING2_POINTS         = 3       -- bas  (mets 2 si tu veux 5 au total)

-- Mouvement (plus rapide)
local REV_PER_SEC_RING1    = 0.38    -- orbite anneau haut (tours/sec)
local REV_PER_SEC_RING2    = -0.46   -- orbite anneau bas (sens opposé, un peu + vite)
local BOB_FREQ             = 1.9     -- fréquence du “bobbing” (plus rapide)
local BOB_AMP              = 0.18    -- amplitude bobbing (studs, sera *scale)

-- Particules “couronne” (pulsation de taille + lifetime plus court = rythme)
local LIFE                 = NumberRange.new(1.0, 1.3)
local RATE_PER_POINT_BG    = 0.0     -- fond (0 = tout vient des pulses “anneau d’apparition”)
local ROT_SPEED            = NumberRange.new(-30, 30)
local LIGHT_EMISSION       = 0.4

-- Pulses d’apparition (deuxième anneau d’apparition)
local PULSE_INTERVAL_MIN   = 0.7     -- chaque X secondes on émet une couronne par point
local PULSE_INTERVAL_MAX   = 1.1
local PULSE_EMIT_PER_POINT = 1       -- combien émettre par attachement au pulse

-- ===== Services =====
local RunService = game:GetService("RunService")

-- ===== Récup racine / scale =====
local root = script.Parent
local handle = root:FindFirstChild("Handle", true)
if not (handle and handle:IsA("BasePart")) then
	warn("[CrownsFX] Handle introuvable sous "..root:GetFullName()); return
end

-- Auto-scale via BonbonSkin
local scale = 1
do
	local skin = root:FindFirstChild("BonbonSkin", true)
	if skin and skin:IsA("BasePart") then
		local ref = 2
		local avgXZ = 0.5 * (skin.Size.X + skin.Size.Z)
		scale = math.max(0.6, avgXZ / ref)
	end
end

-- ===== Dimensions finales =====
local RING_RADIUS_TOP  = BASE_RING_RADIUS * scale
local RING_HEIGHT_TOP  = BASE_RING_HEIGHT * scale
local RING_RADIUS_BOT  = (BASE_RING_RADIUS * SECOND_RADIUS_SCALE) * scale
local RING_HEIGHT_BOT  = (BASE_RING_HEIGHT + SECOND_OFFSET_Y) * scale
local BOB_AMOUNT       = BOB_AMP * scale

-- ===== Lueur douce (désactivée pour éviter l'éblouissement) =====
-- (PointLight retirée)

-- ===== Fabrique d’un emitter “couronne” =====
local function makeCrownEmitter(parent)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = CROWN_TEX
	pe.Rate = RATE_PER_POINT_BG
	pe.Lifetime = LIFE
	-- pulsation taille (grossit → redescend)
	pe.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0.00, 0.36 * scale),
		NumberSequenceKeypoint.new(0.40, 0.54 * scale),
		NumberSequenceKeypoint.new(0.75, 0.42 * scale),
		NumberSequenceKeypoint.new(1.00, 0.34 * scale),
	}
	pe.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0.00, 0.04),
		NumberSequenceKeypoint.new(0.85, 0.12),
		NumberSequenceKeypoint.new(1.00, 1.00),
	}
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 225, 130))
	pe.LightEmission = LIGHT_EMISSION
	pe.Speed = NumberRange.new(0, 0)     -- reste collée à l’attachement
	pe.RotSpeed = ROT_SPEED
	pe.SpreadAngle = Vector2.new(0, 0)
	pe.Parent = parent
	return pe
end

-- ===== Création des deux anneaux (positions + emitters) =====
local rings = {}  -- { radius, height, rev, points, atts = {Attachment}, ems = {Emitter} }

local function createRing(radius, height, points, rev_per_sec)
	local atts, ems = {}, {}
	for i = 1, math.max(1, points) do
		local att = Instance.new("Attachment")
		att.Name = "CrownOrbiter_" .. i
		att.Parent = handle
		local pe = makeCrownEmitter(att)
		table.insert(atts, att)
		table.insert(ems, pe)
	end
	table.insert(rings, {radius = radius, height = height, rev = rev_per_sec, points = #atts, atts = atts, ems = ems})
end

createRing(RING_RADIUS_TOP, RING_HEIGHT_TOP, RING1_POINTS, REV_PER_SEC_RING1)
createRing(RING_RADIUS_BOT, RING_HEIGHT_BOT, RING2_POINTS, REV_PER_SEC_RING2)

-- ===== Animation d’orbite + bobbing =====
local t0 = os.clock()
RunService.Heartbeat:Connect(function()
	if not handle or not handle.Parent then return end
	local t  = os.clock() - t0
	local cf = handle.CFrame
	for _, ring in ipairs(rings) do
		local base = t * (math.pi * 2) * ring.rev
		for i, att in ipairs(ring.atts) do
			local frac = (i - 1) / ring.points
			local ang  = base + frac * math.pi * 2
			local bob  = math.sin((t + frac) * BOB_FREQ) * BOB_AMOUNT
			local pos  = Vector3.new(
				math.cos(ang) * ring.radius,
				ring.height + bob,
				math.sin(ang) * ring.radius
			)
			att.WorldCFrame = cf + cf:VectorToWorldSpace(pos)
		end
	end
end)

-- ===== Pulses d’apparition (anneaux d’apparition haut & bas) =====
task.spawn(function()
	while handle.Parent do
		for _, ring in ipairs(rings) do
			-- “apparition en anneau” : on émet 1 couronne par point, en même temps
			for _, em in ipairs(ring.ems) do
				em:Emit(PULSE_EMIT_PER_POINT)
			end
		end
		task.wait(math.random()*(PULSE_INTERVAL_MAX - PULSE_INTERVAL_MIN) + PULSE_INTERVAL_MIN)
	end
end)
