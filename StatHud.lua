-- StatHud : Speed and Money, bottom-left, permanently on screen.
--
-- Neither number had a home before this. leaderstats.Cash was displayed NOWHERE on the
-- HUD at all, and Speed appeared only inside the biome meter at the bottom centre -
-- which is a progress bar toward the next gate, not a readout of what you have.
--
-- The order is deliberate and was specified: SPEED at the bottom, MONEY directly above
-- it. The stack is anchored to the bottom-left corner and grows UPWARD, so a third row
-- added later pushes these two up rather than shifting them off their corner.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Tween   = game:GetService("TweenService")
local Input   = game:GetService("UserInputService")
local plr     = Players.LocalPlayer
local UI      = require(RS:WaitForChild("UITheme"))

local ROW_W, ROW_H, GAP = 420, 76, 6

-- PHONES AND TABLETS HANG THIS OFF THE NAV GRID instead of the corner. The bottom-left
-- corner of a landscape phone is the thumbstick's, and at full size the readout reached
-- across to the biome meter, so on touch the stack moves up under the four nav buttons
-- and shrinks again on top of the usual scale rule.
local isTouch = Input.TouchEnabled
local TOUCH_SHRINK = 0.72

local gui = Instance.new("ScreenGui")
gui.Name = "StatHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = plr:WaitForChild("PlayerGui")

local stack = Instance.new("Frame")
stack.Name = "Stack"
stack.AnchorPoint = isTouch and Vector2.new(0, 0) or Vector2.new(0, 1)
stack.Position = UDim2.new(0, 18, 1, -18)
stack.Size = UDim2.fromOffset(ROW_W, ROW_H * 2 + GAP)
stack.BackgroundTransparency = 1
stack.Parent = gui

-- The grid's own rect, not a copy of its arithmetic. ProfessionalGameUI lays the four
-- buttons out two-by-two under the topbar on touch and rescales them with the viewport;
-- both ScreenGuis IgnoreGuiInset, so they share one coordinate space and reading the
-- frame back is the one way this cannot drift out from under them.
local quickMenu
local function seat()
	if not isTouch then return end
	local below = 190 -- fallback: a topbar plus two rows of buttons, measured from the rect top
	if quickMenu and quickMenu.Parent then
		below = quickMenu.AbsolutePosition.Y + quickMenu.AbsoluteSize.Y - gui.AbsolutePosition.Y
	end
	stack.Position = UDim2.new(0, 16, 0, below + 12)
end
seat()
task.spawn(function()
	if not isTouch then return end
	local nav = plr.PlayerGui:WaitForChild("ProfessionalGameUI", 20)
	quickMenu = nav and nav:WaitForChild("QuickMenu", 20)
	if not quickMenu then return end
	seat()
	quickMenu:GetPropertyChangedSignal("AbsoluteSize"):Connect(seat)
	quickMenu:GetPropertyChangedSignal("AbsolutePosition"):Connect(seat)
end)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, GAP)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Parent = stack

-- One row: an icon badge, then the figure set large in the display face. That is
-- UITheme's own rule - the same digits as plain body text read as decoration.
local function iconPiece(parent, name, position, size, colour, rotation, radius)
	local piece = Instance.new("Frame")
	piece.Name = name
	piece.Position = position
	piece.Size = size
	piece.BackgroundColor3 = colour
	piece.BorderSizePixel = 0
	piece.Rotation = rotation or 0
	piece.ZIndex = 7
	piece.Parent = parent
	UI.corner(piece, radius or 3)
	UI.stroke(piece, UI.INK, 1.5)
	return piece
end

-- THE MONEY ART IS DRAWN IN ITS OWN BOX, then that box is centred in the badge.
--
-- It used to be six pieces at hand-placed offsets straight onto the 64x64 badge, and
-- their bounding box came out at x 6..36, y 6..35 - thirty pixels of art sitting high and
-- left in a sixty-four pixel slot. The shoe row uses UI.shoeIcon at 64 and fills the whole
-- badge, so the two icons had visual centres eleven pixels apart horizontally and the
-- column read as crooked no matter what the rows did.
--
-- Now the offsets are relative to a 30x29 ART frame anchored at the badge's centre, so
-- the cash art is optically nudged 3px right: its heavy bills sit left of the small coin,
-- while the shoe artwork's visible mass sits right inside its square. MONEY_ART_SCALE remains the size knob and
-- it cannot drift out of alignment, because scaling happens about that same centre.
local MONEY_ART_W, MONEY_ART_H = 30, 29
local MONEY_ART_SCALE = 2.1

local function drawMoneyIcon(badge)
	for _, child in ipairs(badge:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	badge.BackgroundColor3 = Color3.fromRGB(25, 34, 37)
	badge.BackgroundTransparency = 1

	local art = Instance.new("Frame")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.new(0.5, 2, 0.5, 0)
	art.Size = UDim2.fromOffset(MONEY_ART_W, MONEY_ART_H)
	art.BackgroundTransparency = 1
	art.ZIndex = 6
	art.Parent = badge
	local scale = Instance.new("UIScale")
	scale.Scale = MONEY_ART_SCALE
	scale.Parent = art

	-- Three offset notes form one strong stack instead of several tiny unrelated shapes.
	-- Offsets are the originals less (6, 6), so the art starts at the frame's own origin.
	iconPiece(art, "BackBill", UDim2.fromOffset(2, 0), UDim2.fromOffset(23, 15), Color3.fromRGB(24, 123, 62), -10, 3)
	iconPiece(art, "MiddleBill", UDim2.fromOffset(1, 4), UDim2.fromOffset(25, 16), Color3.fromRGB(38, 177, 82), -4, 3)
	local front = iconPiece(art, "FrontBill", UDim2.fromOffset(0, 8), UDim2.fromOffset(26, 16), Color3.fromRGB(82, 225, 116), 2, 3)
	front:FindFirstChildOfClass("UIStroke").Thickness = 1.8

	local band = iconPiece(art, "GoldBand", UDim2.fromOffset(10, 8), UDim2.fromOffset(6, 16), Color3.fromRGB(255, 218, 76), 2, 2)
	band:FindFirstChildOfClass("UIStroke").Thickness = 1
	local seal = iconPiece(art, "BillSeal", UDim2.fromOffset(3, 13), UDim2.fromOffset(6, 6), Color3.fromRGB(217, 255, 224), 2, 999)
	seal:FindFirstChildOfClass("UIStroke").Thickness = 1

	local coin = iconPiece(art, "GoldCoin", UDim2.fromOffset(18, 17), UDim2.fromOffset(12, 12), UI.GOLD, 0, 999)
	coin:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(105, 63, 8)
	local shine = iconPiece(coin, "CoinShine", UDim2.fromOffset(3, 2), UDim2.fromOffset(3, 5), Color3.fromRGB(255, 247, 166), -25, 999)
	shine:FindFirstChildOfClass("UIStroke"):Destroy()
end

-- CENTRED THE SAME WAY, so the two icons share a centre by construction rather than by
-- both happening to be pinned at 0,0 with different art inside them.
local function drawShoeIcon(badge)
	for _, child in ipairs(badge:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	badge.BackgroundTransparency = 1
	-- The source PNG has more transparent room around the shoe than the drawn cash icon.
	-- A 74px render with a small optical shift gives both visible silhouettes the same
	-- 51px footprint while their fixed 64px layout slots remain perfectly identical.
	local shoe = UI.shoeIcon(badge, 84)
	shoe.AnchorPoint = Vector2.new(0.5, 0.5)
	shoe.Position = UDim2.new(0.5, -2, 0.5, 0)
	shoe.ZIndex = 9
end

local function row(name, order, iconKind, colour)
	-- Open HUD like the reference: icon + oversized outlined number directly over the
	-- world, with no card, shadow, well, or black pill behind it.
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.fromOffset(ROW_W, ROW_H)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = stack

	local badge = Instance.new("Frame")
	badge.Name = "Icon"
	badge.Position = UDim2.fromOffset(0, 6)
	badge.Size = UDim2.fromOffset(64, 64)
	badge.AnchorPoint = Vector2.new(0, 0)
	badge.BackgroundTransparency = 1
	badge.BorderSizePixel = 0
	badge.ZIndex = 4
	badge.Parent = holder
	if iconKind == "money" then drawMoneyIcon(badge) else drawShoeIcon(badge) end

	local content = Instance.new("Frame")
	content.Name = "Readout"
	content.Position = UDim2.fromOffset(74, 0)
	content.Size = UDim2.new(1, -74, 1, 0)
	content.BackgroundTransparency = 1
	content.Parent = holder
	local readoutLayout = Instance.new("UIListLayout")
	readoutLayout.FillDirection = Enum.FillDirection.Horizontal
	readoutLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	readoutLayout.Padding = UDim.new(0, 10)
	readoutLayout.SortOrder = Enum.SortOrder.LayoutOrder
	readoutLayout.Parent = content

	local valueColour = iconKind == "money"
		and Color3.fromRGB(72, 255, 105)
		or Color3.fromRGB(255, 38, 207)
	-- THE NUMBER COMES FIRST, AND ITS LayoutOrder SAYS SO.
	--
	-- Both labels were left at LayoutOrder 0, and a UIListLayout breaks that tie by NAME -
	-- so "Multiplier" sorted ahead of "Value" and the row rendered "(x1) 50K" even though
	-- the code builds the value first. That pushed the speed figure out to x 135 while the
	-- money figure below it sat at x 78: the two numbers in a two-row stack were 57 pixels
	-- out of line, which is what read as the HUD being crooked. The icons were never the
	-- problem - both badges measured dead on 43.9.
	--
	-- Ordering these explicitly is what keeps the figures in one column: the money row has
	-- no multiplier, so anything placed BEFORE the value can only exist on one of the two
	-- rows and must therefore break the alignment.
	local value = UI.text(content, "0", 48, valueColour, Enum.TextXAlignment.Left)
	value.Name = "Value"
	value.LayoutOrder = 1
	value.Size = UDim2.fromOffset(0, ROW_H)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.ZIndex = 4
	UI.outlined(value, 5)

	local multiplier
	if iconKind == "shoe" then
		multiplier = UI.text(content, "(x1)", 42, Color3.fromRGB(56, 255, 76), Enum.TextXAlignment.Left)
		multiplier.Name = "Multiplier"
		multiplier.LayoutOrder = 2
		multiplier.Size = UDim2.fromOffset(0, ROW_H)
		multiplier.AutomaticSize = Enum.AutomaticSize.X
		multiplier.ZIndex = 4
		UI.outlined(multiplier, 5)
	end
	return value, badge, multiplier
end

-- LayoutOrder 1 sorts first and the list is bottom-aligned, so 1 ends up HIGHER on
-- screen. Money is 1, speed is 2.
local speedValue, speedBadge, speedMultiplier = row("Speed", 1, "shoe", UI.SPEED)
local moneyValue, moneyBadge = row("Money", 2, "money", UI.CASH)

-- THE COMBINED MULTIPLIER, DERIVED - not the treadmill's alone.
--
-- This read `SpeedMultiplier`, which TreadmillService publishes for the TREADMILL tiers only.
-- A player wearing a x14 Divine trail and the x2 Speed pass therefore saw "(x1)" beside a raw
-- 82.5M while the player list showed 2.31B, and quite reasonably concluded the trail was not
-- registering at all.
--
-- EffectiveSpeed is what BiomeGates actually gates on: the raw stat times Passes.StatMult,
-- which is where the trail lives. Dividing the two is the true combined figure BY
-- CONSTRUCTION, so it can never drift from what the game is really using - which is exactly
-- the failure a second published attribute would reintroduce.
local function refreshSpeedMultiplier()
	local effective = tonumber(plr:GetAttribute("EffectiveSpeed"))
	local stats = plr:FindFirstChild("Stats")
	local rawValue = stats and stats:FindFirstChild("Speed")
	local raw = rawValue and tonumber(rawValue.Value) or 0
	local mult = (effective and raw > 0) and (effective / raw)
		or (tonumber(plr:GetAttribute("SpeedMultiplier")) or 1)
	-- x1 is not worth the pixels; the chip is there to explain a number that looks wrong
	speedMultiplier.Visible = mult > 1.005
	speedMultiplier.Text = "(x" .. UI.short(mult) .. ")"
end
refreshSpeedMultiplier()
plr:GetAttributeChangedSignal("SpeedMultiplier"):Connect(refreshSpeedMultiplier)
plr:GetAttributeChangedSignal("EffectiveSpeed"):Connect(refreshSpeedMultiplier)
plr:GetAttributeChangedSignal("TrailMultiplier"):Connect(refreshSpeedMultiplier)

-- A number that changes should be seen changing. The badge pops, not the text: the
-- labels are plain TextLabels but a tween on the text still fights the outline stroke,
-- and a 38px badge is the more legible thing to move anyway.
local function pulse(badge)
	badge.Size = UDim2.fromOffset(70, 70)
	badge.Position = UDim2.fromOffset(-3, 3)
	Tween:Create(badge, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, 6)}):Play()
end

local function bind(stat, label, badge)
	if not stat then return end
	local last = stat.Value
	label.Text = UI.short(stat.Value)
	stat.Changed:Connect(function(value)
		label.Text = UI.short(value)
		if value > last then pulse(badge) end
		last = value
	end)
end

-- `Stats`, not `leaderstats`: leaderstats now holds the formatted scoreboard STRINGS, and
-- this HUD does arithmetic (it compares against the previous value to pulse the badge),
-- so it needs the real numbers. See BiomeGates.
-- THE TRUE SPEED, NOT THE BELT'S RAW STAT (2026-09-12). This row bound the raw NumberValue and
-- left the trail to a "(x10)" chip beside it, so a player on a x10 trail read 50M here while
-- every gate, guardian and scoreboard row was running them at 500M - and concluded the trail
-- was not counting. EffectiveSpeed is that 500M, published by BiomeGates the moment the raw
-- stat ticks. The chip stays, now explaining how the number shown was reached.
--
-- max() of the two, because the raw tick and the re-published attribute can arrive a frame
-- apart and the multiplier is never below 1 - so the figure never dips on the way up.
local function speedShown()
	local st = plr:FindFirstChild("Stats")
	local rawValue = st and st:FindFirstChild("Speed")
	local raw = rawValue and tonumber(rawValue.Value) or 0
	local effective = tonumber(plr:GetAttribute("EffectiveSpeed")) or 0
	return math.max(raw, effective)
end

local stats = plr:WaitForChild("Stats", 30)
if stats then
	bind(stats:WaitForChild("Cash", 20), moneyValue, moneyBadge)
	local speedStat = stats:WaitForChild("Speed", 20)
	if speedStat then
		local lastShown = speedShown()
		local function refreshSpeed()
			local shown = speedShown()
			speedValue.Text = UI.short(shown)
			if shown > lastShown then pulse(speedBadge) end
			lastShown = shown
		end
		refreshSpeed()
		speedStat.Changed:Connect(refreshSpeed)
		plr:GetAttributeChangedSignal("EffectiveSpeed"):Connect(refreshSpeed)
		plr:GetAttributeChangedSignal("TrailMultiplier"):Connect(refreshSpeed)
	end
end

-- The same single scale rule every other screen uses, so a phone gets this layout
-- shrunk instead of a second layout that has to be kept in step. Touch takes that same
-- number down again by TOUCH_SHRINK, because up under the nav grid the readout is
-- sharing the left edge rather than owning a whole corner.
if isTouch then
	local scale = stack:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", stack)
	local camera = workspace.CurrentCamera
	local function fit()
		if not camera then return end
		local vp = camera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1150, vp.Y / 760), 0.7, 1) * TOUCH_SHRINK
		seat()
	end
	fit()
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
else
	UI.autoScale({stack}, 1150, 760, 0.7)
end
