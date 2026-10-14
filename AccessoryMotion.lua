-- AccessoryMotion : how an accessory that MOVES moves - one description, every renderer.
--
-- THREE PLACES DRAW THE SAME HALO: the real pet in the pen, the animal on the checkout
-- preview, and the little spinning thumbnail in the item list. If each one animated it its own
-- way, the thing the player bought would not be the thing they were shown. So the MOTION lives
-- on the template as attributes, exactly as the FIT does, and this module is the one reader:
--
--   SpinSpeed  degrees a second about the piece's own normal (its local Z). 0 or absent =
--              it does not move, and nothing here touches it.
--   SpinTilt   degrees the piece is tipped out of that plane. THIS IS WHAT MAKES THE SPIN
--              VISIBLE: a halo is a torus, and a torus turning about its own axis looks
--              exactly like a torus standing still. Tipped, the ring's normal walks a cone
--              and it reads as a halo wobbling over the animal's head.
--   SpinBob    vertical float, as a fraction of the piece's own width, so it is the same
--              motion on a mouse-sized brainrot and on a twelve-stud one.
--   Shine      how far the colour brightens at the top of the shimmer. The halo is Neon, so
--              its colour IS its brightness - this is the glint, and it costs no light. It
--              brightens WITHIN ITS OWN HUE and never toward white (see Attach).
--   Glow       size of the aura, as a multiple of the piece. Absent = no aura.
--
-- The bob is applied in WORLD Y rather than in the piece's own frame: pets stand upright, and
-- a halo that floats along the ring's own axis after the Flat rotation would slide sideways.

local M = {}

-- THE AURA: a second, bigger, half-transparent copy of the piece in the same place.
--
-- THE BLOOM CANNOT DO THIS JOB, which is why this is geometry and not a lighting setting.
-- Lighting's BloomEffect is set at threshold 1.85 - higher than a Neon surface ever reaches,
-- so nothing here blooms - and post-processing does not run inside a ViewportFrame AT ALL,
-- which is exactly where the player looks at the halo when they are deciding to buy it. A
-- ring behind the ring glows in the pen and on the checkout card alike, and costs no light
-- source, which matters with six pens of pets on a phone.
local function buildAura(part, scale)
	local CollectionService = game:GetService("CollectionService")
	local old = part.Parent and part.Parent:FindFirstChild(part.Name .. "Glow")
	if old then old:Destroy() end
	local aura = part:Clone()
	-- a clone carries the weld, the attributes and the TAG, and the tag would register the
	-- aura as a halo of its own and grow an aura for the aura
	for _, child in ipairs(aura:GetChildren()) do child:Destroy() end
	for key in pairs(aura:GetAttributes()) do aura:SetAttribute(key, nil) end
	for _, tag in ipairs(CollectionService:GetTags(aura)) do CollectionService:RemoveTag(aura, tag) end
	aura.Name = part.Name .. "Glow"
	aura.Size = part.Size * scale
	aura.Material = Enum.Material.Neon
	aura.Transparency = 0.66
	aura.CastShadow = false
	aura.Anchored = true
	aura.CanCollide, aura.CanQuery, aura.CanTouch = false, false, false
	aura.Massless = true
	aura.CFrame = part.CFrame
	aura.Parent = part.Parent
	return aura
end

-- Reads the motion off a placed part and builds its aura, or nil when it is a hat and hats do
-- not move. `part` must already be at its final SIZE - the bob is measured in the piece's own
-- width - and at its final COLOUR, which is remembered here because the shimmer overwrites it
-- every frame. The caller owns what comes back and must `Release` it.
function M.Attach(part)
	local speed = tonumber(part:GetAttribute("SpinSpeed"))
	if not speed or speed == 0 then return nil end
	local colour = part.Color
	local hue, sat, val = colour:ToHSV()
	local aura = tonumber(part:GetAttribute("Glow"))
	return {
		speed = math.rad(speed),
		tilt = math.rad(tonumber(part:GetAttribute("SpinTilt")) or 0),
		bob = (tonumber(part:GetAttribute("SpinBob")) or 0) * part.Size.X,
		shine = math.clamp(tonumber(part:GetAttribute("Shine")) or 0, 0, 1),
		colour = colour,
		-- BRIGHTEN WITHIN THE HUE, NEVER TOWARD WHITE. Owner, 2026-09-25: "halo should be
		-- golden and glowing" - it was a pale gold lerped a third of the way to white, and a
		-- pale gold plus white is just white on a Neon surface, which draws its colour flat.
		-- Same hue, half the saturation, full value: it reads as gold catching the light.
		bright = Color3.fromHSV(hue, sat * 0.5, math.min(1, val + 0.1)),
		glow = (aura and aura > 1) and buildAura(part, aura) or nil,
		-- so two halos in one scene are not the same halo twice
		phase = math.random() * math.pi * 2,
	}
end

-- `base` is where the piece would hang if it never moved: the CFrame AccessoryFit solved, or
-- for a welded one, anchor.CFrame * the offset the weld is holding.
function M.Pose(base, data, clock)
	local angle = clock * data.speed + data.phase
	local lift = (data.bob > 0) and math.sin(clock * 1.7 + data.phase) * data.bob or 0
	return CFrame.new(0, lift, 0) * base * CFrame.Angles(0, 0, angle) * CFrame.Angles(data.tilt, 0, 0)
end

-- One call a frame per piece: place it, shimmer it, and carry the aura with it.
function M.Step(part, data, base, clock)
	local cf = M.Pose(base, data, clock)
	part.CFrame = cf
	local k = 0.5 + 0.5 * math.sin(clock * 2.4 + data.phase)
	if data.shine > 0 then
		part.Color = data.colour:Lerp(data.bright, data.shine * k)
	end
	if data.glow then
		if data.glow.Parent then
			data.glow.CFrame = cf
			data.glow.Color = part.Color
			-- the aura breathes with the glint rather than sitting at one strength
			data.glow.Transparency = 0.72 - 0.14 * k
		else
			data.glow = nil
		end
	end
end

-- The aura is the caller's to clean up: it is a part, and the piece being destroyed does not
-- take a sibling with it.
function M.Release(data)
	if data and data.glow then
		data.glow:Destroy()
		data.glow = nil
	end
end

return M
