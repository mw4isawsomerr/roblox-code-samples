-- TreadmillAnimator
-- Smooth belt stripes plus biome-specific treadmill energy motion.
local RunService=game:GetService("RunService")
local stripes={}
local visualParts={}
local rainColumns={}

local function track(inst)
	if inst:IsA("GuiObject") and inst:GetAttribute("BeltStripe") then stripes[inst]=true end
	if inst:IsA("GuiObject") and inst:GetAttribute("MatrixColumn") then rainColumns[inst]=true end
	if inst:IsA("BasePart") and inst:GetAttribute("TreadmillMotion") then visualParts[inst]=true end
end
local function untrack(inst)
	stripes[inst]=nil
	rainColumns[inst]=nil
	visualParts[inst]=nil
end
for _,inst in ipairs(workspace:GetDescendants()) do track(inst) end
-- SELF-HEALING, because DescendantAdded is a SINGLE SHOT.
--
-- Under StreamingEnabled an instance can arrive a packet BEFORE the attributes this tests for.
-- It is skipped, nothing ever looks at it again, and the thing simply never animates - in the
-- live game only. It cannot reproduce in Studio, where client and server share a process and an
-- instance shows up complete. This already cost a day on PetAnimator, where pets' legs animated
-- while their bodies never left the slot.
--
-- A DEFERRED RE-CHECK, not a rescan: workspace holds 90,000 descendants and a full walk is
-- ~7ms, which is not a price worth paying every few seconds for scenery. This is one extra call
-- per instance that actually arrived. track() keys off the instance and no-ops on a repeat, so
-- calling it twice is free.
workspace.DescendantAdded:Connect(function(inst)
	track(inst)
	task.delay(0.5, function() if inst.Parent then track(inst) end end)
end)
workspace.DescendantRemoving:Connect(untrack)

local elapsed=0
local TAU=math.pi*2
RunService.RenderStepped:Connect(function(dt)
	elapsed+=dt
	for stripe in pairs(stripes) do
		if stripe.Parent then
			local offset=stripe:GetAttribute("Offset") or 0
			local direction=stripe:GetAttribute("Direction") or 1
			local animationSpeed=stripe:GetAttribute("AnimationSpeed") or 0.42
			local x=(offset+elapsed*animationSpeed*direction)%1.14-0.07
			stripe.Position=UDim2.fromScale(x,0.5)
		else
			stripes[stripe]=nil
		end
	end
	-- DIGITAL RAIN on the treadmill decks. Each column slides down its own clipped frame
	-- and wraps; the range is 1.6 because the column is 1.6x the height of the deck, so a
	-- full wrap carries the tail all the way off before the head comes back round.
	for col in pairs(rainColumns) do
		if col.Parent then
			local offset=col:GetAttribute("Offset") or 0
			local speed=col:GetAttribute("FallSpeed") or 0.25
			local direction=col:GetAttribute("Direction") or 1
			local y=(offset+elapsed*speed*direction)%1.6-0.6
			col.Position=UDim2.fromScale(col.Position.X.Scale,y)
			-- one digit somewhere in the column flips every so often, so the rain reads as
			-- live rather than as a texture being dragged past. dt-scaled, so it is the same
			-- rate at 30fps as at 144.
			if math.random()<dt*6 then
				local digits=col:GetChildren()
				local pick=digits[math.random(1,math.max(#digits,1))]
				if pick and pick:IsA("TextLabel") then pick.Text=tostring(math.random(0,9)) end
			end
		else
			rainColumns[col]=nil
		end
	end
	for part in pairs(visualParts) do
		if part.Parent then
			local kind=part:GetAttribute("TreadmillMotion")
			local speed=part:GetAttribute("MotionSpeed") or 1
			local phase=part:GetAttribute("MotionPhase") or 0
			local amp=part:GetAttribute("MotionAmplitude") or 1
			local base=part:GetAttribute("BaseCFrame") or part.CFrame
			local baseTransparency=part:GetAttribute("BaseTransparency") or 0
			local wave=math.sin(elapsed*speed*TAU+phase)
			if kind=="Pulse" then
				part.Transparency=math.clamp(baseTransparency-wave*amp,0,0.78)
			elseif kind=="Bob" or kind=="Wave" then
				part.CFrame=base*CFrame.new(0,wave*amp,0)
			elseif kind=="Sway" then
				part.CFrame=base*CFrame.Angles(0,0,math.rad(wave*amp))
			elseif kind=="Spin" then
				part.CFrame=base*CFrame.Angles(0,elapsed*speed*TAU,0)
			elseif kind=="Orbit" then
				local theta=elapsed*speed*TAU+phase
				part.CFrame=base*CFrame.new(math.cos(theta)*amp,math.sin(theta)*amp,0)
			elseif kind=="Tremor" then
				part.CFrame=base*CFrame.new(math.sin(elapsed*speed*TAU*9+phase)*amp,math.sin(elapsed*speed*TAU*13+phase)*amp,0)
			elseif kind=="Rise" then
				local cycle=(elapsed*speed+phase)%1
				part.CFrame=base*CFrame.new(0,cycle*amp,0)
				part.Transparency=math.clamp(baseTransparency+math.max(0,cycle-0.68)*2.3,0,0.86)
			end
		else
			visualParts[part]=nil
		end
	end
end)
