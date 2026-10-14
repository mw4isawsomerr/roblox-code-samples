-- ObstacleMotion : WHERE A MOVING OBSTACLE IS AT TIME t, as a pure function of the part's own
-- attributes. Nothing here has state.
--
-- The server runs it for authority (what is solid, what kills); every client runs the SAME
-- function every frame for smooth visuals. Both feed it workspace:GetServerTimeNow(), so they
-- agree to within latency and the motion never has to replicate frame by frame - a server-
-- animated anchored part arrives at ~20Hz and stutters, a client-animated one is butter.
--
-- Every mover carries `Motion` (which curve) and `BaseCF` (its rest pose, written at build
-- time) plus the curve's own numbers. Stored as attributes rather than in a table so a part
-- that streams in mid-cycle needs nothing but itself to be placed correctly.
--
-- A MOVER IS A PART OR A MODEL. A hazard that is one slab is a red box; a real assembly - a
-- frame, a panel, rails, emitters - is a Model with the attributes on the MODEL and a
-- PrimaryPart, placed with PivotTo. The hazard parts inside it carry no attributes of their
-- own; `M.moverOf(hazard)` finds the model they belong to.

local M = {}
local TAU = math.pi * 2

local function attr(part, name, default)
	local v = part:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The travelling hazards (a rolling ball, a wave wall) run from BaseCF along Dir for Distance
-- studs over Travel seconds, once every Period, and are parked far below the world between
-- runs. Parked is a real place: the server's overlap check still runs on a parked part and
-- must find nothing there.
local PARKED = Vector3.new(0, -120, 0)
local function travelling(part, t)
	local period = attr(part, "Period", 5)
	local phase = attr(part, "Phase", 0)
	local travel = attr(part, "Travel", 3)
	local c = ((t / period + phase) % 1) * period
	if c > travel then return nil end
	local k = c / travel
	local dir = attr(part, "Dir", -Vector3.zAxis)
	local dist = attr(part, "Distance", 200)
	return dir * (dist * k), dir * (dist / travel), k
end

-- Returns cframe, velocity. Velocity is only non-nil for platforms that carry a standing
-- player: an anchored part moved by CFrame alone leaves the character behind, and the engine
-- carries anyone standing on a part whose AssemblyLinearVelocity matches its motion.
function M.cframeFor(part, t)
	local base = part:GetAttribute("BaseCF")
	if typeof(base) ~= "CFrame" then return nil end
	local kind = part:GetAttribute("Motion")

	if kind == "Slide" then
		local axis = attr(part, "Axis", Vector3.xAxis)
		local amp = attr(part, "Amplitude", 20)
		local period = attr(part, "Period", 4)
		local a = (t / period + attr(part, "Phase", 0)) * TAU
		return base + axis * (amp * math.sin(a)), axis * (amp * math.cos(a) * TAU / period)

	elseif kind == "Spin" then
		local period = attr(part, "Period", 4)
		local angle = (t / period + attr(part, "Phase", 0)) * TAU
		return base * CFrame.Angles(0, angle, 0), nil

	elseif kind == "Crusher" then
		-- rests UP. Each cycle: slam (fast, accelerating), hold down, rise (eased), hold up.
		local period = attr(part, "Period", 3)
		local drop = attr(part, "Drop", 24)
		local c = (t / period + attr(part, "Phase", 0)) % 1
		local SLAM, HOLD, RISE = 0.08, 0.20, 0.30
		local y
		if c < SLAM then y = -drop * (c / SLAM) ^ 2
		elseif c < SLAM + HOLD then y = -drop
		elseif c < SLAM + HOLD + RISE then y = -drop * (1 - ease((c - SLAM - HOLD) / RISE))
		else y = 0 end
		return base + Vector3.new(0, y, 0), nil

	elseif kind == "Roller" then
		local offset, vel, k = travelling(part, t)
		if not offset then return base + PARKED, nil end
		-- it rolls: turn about its sideways axis by distance / radius. A model carries its
		-- radius as an attribute; a bare cylinder or ball is Size.Y/2 (a cylinder's length is X).
		local dir = attr(part, "Dir", -Vector3.zAxis)
		local side = dir:Cross(Vector3.yAxis)
		if side.Magnitude < 0.01 then side = Vector3.xAxis end
		local radius = part:GetAttribute("Radius") or (part:IsA("BasePart") and part.Size.Y / 2) or 8
		local spin = offset.Magnitude / math.max(radius, 1)
		return CFrame.new(base.Position + offset) * CFrame.fromAxisAngle(side.Unit, spin), vel

	elseif kind == "Wave" then
		local offset, vel = travelling(part, t)
		if not offset then return base + PARKED, nil end
		return base + offset, vel

	elseif kind == "Gate" then
		-- closed at rest; lifts by Lift for Open seconds out of every Period, 0.35s transitions
		local period = attr(part, "Period", 4)
		local open = attr(part, "Open", 1.5)
		local lift = attr(part, "Lift", 11)
		local c = ((t / period + attr(part, "Phase", 0)) % 1) * period
		local T = 0.35
		local y
		if c < T then y = lift * ease(c / T)
		elseif c < open then y = lift
		elseif c < open + T then y = lift * (1 - ease((c - open) / T))
		else y = 0 end
		return base + Vector3.new(0, y, 0), nil

	elseif kind == "Sink" then
		-- at rest until SunkAt is stamped (by the server, on a touch); then a tremble, a drop,
		-- a stay below, and a rise back. All from one timestamp, so both sides agree.
		local sunkAt = attr(part, "SunkAt", -1e9)
		local delay = attr(part, "Delay", 0.9)
		local depth = attr(part, "Depth", 14)
		local stay = attr(part, "Stay", 3.5)
		local DROP, RISE = 0.45, 0.8
		local dt = t - sunkAt
		if dt < 0 or dt > delay + DROP + stay + RISE then return base, nil end
		if dt < delay then
			return base + Vector3.new(0, -0.3 * math.abs(math.sin(dt * 40)), 0), nil
		elseif dt < delay + DROP then
			return base + Vector3.new(0, -depth * ease((dt - delay) / DROP), 0), nil
		elseif dt < delay + DROP + stay then
			return base + Vector3.new(0, -depth, 0), nil
		else
			return base + Vector3.new(0, -depth * (1 - ease((dt - delay - DROP - stay) / RISE)), 0), nil
		end
	end
	return base, nil
end

-- A sink key that is mid-cycle must not be re-stamped, or a second touch restarts the clock
-- and the key never comes back up.
function M.sinkAtRest(part, t)
	local sunkAt = attr(part, "SunkAt", -1e9)
	return (t - sunkAt) > attr(part, "Delay", 0.9) + 0.45 + attr(part, "Stay", 3.5) + 0.8
end

-- Blinking keys: solid for Duty of every Period.
function M.solidFor(part, t)
	local period = attr(part, "Period", 3)
	local duty = attr(part, "Duty", 0.55)
	return ((t / period + attr(part, "Phase", 0)) % 1) < duty
end

-- The mover a hazard part belongs to: itself when it carries the attributes, otherwise the
-- nearest ancestor Model that does.
function M.moverOf(inst)
	local node = inst
	while node and node ~= workspace do
		if node:GetAttribute("Motion") ~= nil then return node end
		node = node.Parent
	end
	return inst
end

-- Where a mover is right now, part or model.
function M.positionOf(inst)
	if inst:IsA("Model") then return inst:GetPivot().Position end
	return inst.Position
end

-- Whether touching this hazard kills RIGHT NOW. Most hazards always do; a timed gate only
-- kills while it is down or coming down - standing under a fully open one is the whole idea.
function M.lethal(hazard, t)
	local part = M.moverOf(hazard)
	if part:GetAttribute("Motion") == "Gate" then
		local lift = attr(part, "Lift", 11)
		local cf = M.cframeFor(part, t)
		local base = part:GetAttribute("BaseCF")
		if not (cf and base) then return true end
		return (cf.Position.Y - base.Position.Y) < lift * 0.8
	end
	return true
end

return M
