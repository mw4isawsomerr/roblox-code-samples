-- UITheme : shared typography, colour and surface rules for every interface.
-- The UI uses quiet navy surfaces, soft cool borders and a compact Gotham hierarchy.
-- Contrast comes from spacing, weight and accent colour rather than black keylines.
-- Cards float with a restrained shadow; controls respond with short, subtle motion.

local T = {}

T.FONT      = Enum.Font.GothamBold
T.BODY_FONT = Enum.Font.GothamMedium

T.INK       = Color3.fromRGB( 25,  34,  49)   -- dark copy on light surfaces
T.PANEL     = Color3.fromRGB( 20,  29,  44)
T.PANEL_HI  = Color3.fromRGB( 30,  43,  62)
T.WELL      = Color3.fromRGB( 13,  21,  34)   -- inset rows and input fields
T.BORDER    = Color3.fromRGB( 91, 110, 140)   -- soft edge, never a black keyline
T.SHADOW    = Color3.fromRGB(  7,  13,  24)
T.TEXT      = Color3.fromRGB(248, 250, 252)
T.TEXT_DIM  = Color3.fromRGB(159, 174, 199)
T.CASH      = Color3.fromRGB( 88, 226, 132)
T.SPEED     = Color3.fromRGB( 92, 194, 255)
T.GOLD      = Color3.fromRGB(255, 199,  60)
T.DANGER    = Color3.fromRGB(255,  94,  90)
T.PURPLE    = Color3.fromRGB(178, 118, 255)

------------------------------------------------------------------ primitives

function T.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 18)
	c.Parent = parent
	return c
end

function T.stroke(parent, colour, thickness, transparency)
	local s = Instance.new("UIStroke")
	local edge = colour or T.BORDER
	local luminance = edge.R * 0.299 + edge.G * 0.587 + edge.B * 0.114
	if edge == T.INK or luminance < 0.18 then edge = T.BORDER end
	s.Color = edge
	s.Thickness = math.min(thickness or 1, 1.5)
	s.Transparency = math.max(transparency or 0.38, 0.28)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- Top-lit vertical sheen. Two flat colours make a panel look printed; a subtle
-- light-to-dark ramp is what gives it a surface.
function T.sheen(parent, top, bottom)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top or T.PANEL_HI, bottom or T.PANEL)
	g.Rotation = 90
	g.Parent = parent
	return g
end

local function shade(colour, amount)
	return colour:Lerp(Color3.new(0, 0, 0), amount)
end
T.shade = shade

local function tint(colour, amount)
	return colour:Lerp(Color3.new(1, 1, 1), amount)
end
T.tint = tint

-- One polished, transparent speed icon everywhere: HUD, treadmill gains, and any
-- future speed UI. The CanvasGroup keeps popup fades working without adding a badge.
T.SHOE_IMAGE = "rbxassetid://71173316856782"
function T.shoeIcon(parent, size)
	size = size or 48
	local icon = Instance.new("CanvasGroup")
	icon.Name = "SpeedShoe"
	icon.Size = UDim2.fromOffset(size, size)
	icon.BackgroundTransparency = 1
	icon.GroupTransparency = 0
	icon.ClipsDescendants = false
	icon.Parent = parent

	local art = Instance.new("ImageLabel")
	art.Name = "Artwork"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = T.SHOE_IMAGE
	art.ScaleType = Enum.ScaleType.Fit
	art.ResampleMode = Enum.ResamplerMode.Default
	art.ZIndex = 2
	art.Parent = icon
	return icon
end

------------------------------------------------------------------ text

-- Text stays crisp without keylines. Readability comes from a controlled surface
-- behind the type; this helper also cleans up any legacy outline on reused labels.
local function applyTextOutline(label, _thickness)
	local stroke = label:FindFirstChild("CleanTextOutline")
	if stroke then stroke:Destroy() end
	label.TextStrokeTransparency = 1
	return nil
end

local function autoOutline(label, _size, _colour)
	label.TextStrokeTransparency = 1
	return nil
end

function T.text(parent, str, size, colour, align)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = T.FONT
	t.Text = str or ""
	t.TextSize = size or 18
	t.TextColor3 = colour or T.TEXT
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Parent = parent
	autoOutline(t, size or 18, colour or T.TEXT)
	return t
end

-- Compatibility hook for callers that previously requested a text keyline.
-- The new system deliberately leaves type clean and relies on its surface for contrast.
function T.outlined(label, thickness)
	return applyTextOutline(label, thickness or 2)
end

------------------------------------------------------------------ surfaces

-- Card with a drop shadow behind it. Returns the CARD; the shadow is its sibling
-- and is parented first so it sorts underneath.
function T.panel(parent, radius)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	-- fills its parent by default, so T.panel drops straight into a container;
	-- callers that want a fixed size (a pill, a toast) just overwrite this, and a
	-- UIGridLayout/UIListLayout overwrites it for free.
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BackgroundColor3 = T.SHADOW
	shadow.BackgroundTransparency = 0.62
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = holder
	T.corner(shadow, radius or 18)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = T.PANEL
	card.BorderSizePixel = 0
	card.ZIndex = 1
	card.Parent = holder
	T.corner(card, radius or 16)
	T.stroke(card, T.BORDER, 1, 0.38)
	T.sheen(card)

	return card, holder
end

-- Inset well: a row or list background that reads as cut INTO the panel.
function T.well(parent, radius)
	local w = Instance.new("Frame")
	w.BackgroundColor3 = T.WELL
	w.BorderSizePixel = 0
	w.Parent = parent
	T.corner(w, radius or 14)
	T.stroke(w, T.INK, 3)
	return w
end

-- Coloured strip across the top of a card, in the accent for that screen. Its
-- corner radius has to MATCH the card's, or its squarer corners poke out past the
-- card's rounded ones and the strip reads as a separate floating line.
function T.accentBar(card, colour, height)
	local cardCorner = card:FindFirstChildOfClass("UICorner")
	local bar = Instance.new("Frame")
	bar.Name = "AccentBar"
	bar.Size = UDim2.new(1, 0, 0, height or 7)
	bar.BackgroundColor3 = colour
	bar.BorderSizePixel = 0
	bar.ZIndex = (card.ZIndex or 1) + 1
	bar.Parent = card
	local corner = T.corner(bar, 8)
	if cardCorner then corner.CornerRadius = cardCorner.CornerRadius end
	return bar
end

-- THE TRAIL-CARD TREATMENT, made reusable. The card that this style is being
-- pulled towards is not a dark panel with a coloured accent on it - it is a
-- BRIGHT GROUND in the thing's own colour, wearing a heavy black border, with the
-- name centred over it in white and outlined. That inversion is most of why it
-- reads as a product and the dark panels read as a list.
--
-- Returns the card frame; the title and subtitle are optional and are laid out
-- from the top, so anything else the caller adds starts below `titleBottom`.
function T.card(parent, colour, title, subtitle)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = colour
	card.BorderSizePixel = 0
	card.Parent = parent
	T.corner(card, 22)
	T.stroke(card, T.INK, 6)

	-- a light-to-dark ramp of the ground's OWN colour, never a grey sheen: the
	-- point is that the card is the colour, so shading it toward neutral undoes it
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, tint(colour, 0.20)),
		ColorSequenceKeypoint.new(0.55, colour),
		ColorSequenceKeypoint.new(1, shade(colour, 0.22)),
	})
	g.Rotation = 90
	g.Parent = card

	local titleBottom = 10
	if title then
		local t = T.text(card, title, 30, T.TEXT, Enum.TextXAlignment.Center)
		t.Position = UDim2.fromOffset(10, titleBottom)
		t.Size = UDim2.new(1, -20, 0, 36)
		T.outlined(t, 5)
		titleBottom += 34
	end
	if subtitle then
		local s = T.text(card, subtitle, 22, T.TEXT, Enum.TextXAlignment.Center)
		s.Position = UDim2.fromOffset(10, titleBottom)
		s.Size = UDim2.new(1, -20, 0, 28)
		T.outlined(s, 4)
		titleBottom += 30
	end
	return card, titleBottom
end

-- The flat inked pill the trail card uses for its two rows - no extrusion, just a
-- solid fill, a heavy keyline and centred outlined text. T.button is still the
-- right control for anything that is pressed repeatedly; this is for the one big
-- call to action at the bottom of a card.
function T.slab(parent, str, fill, textSize)
	local slab = Instance.new("TextButton")
	slab.BackgroundColor3 = fill
	slab.BorderSizePixel = 0
	slab.AutoButtonColor = true
	slab.Font = T.FONT
	slab.Text = str or ""
	slab.TextSize = textSize or 24
	slab.TextColor3 = T.TEXT
	slab.Parent = parent
	T.corner(slab, 16)
	T.stroke(slab, T.INK, 4)
	T.outlined(slab, 4)
	return slab
end

------------------------------------------------------------------ controls

-- Extruded button. `lip` is a darker slab behind the face; pressing drops the
-- face onto it. This one detail is most of the difference between a control that
-- feels like a game button and one that feels like a hyperlink.
function T.button(parent, str, colour, textSize)
	colour = colour or T.SPEED
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.fromScale(0.5, 1)
	lip.Size = UDim2.fromScale(1, 1)
	lip.BackgroundColor3 = shade(colour, 0.45)
	lip.BorderSizePixel = 0
	lip.Parent = holder
	T.corner(lip, 16)
	T.stroke(lip, T.INK, 4)

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Position = UDim2.fromOffset(0, 0)
	face.Size = UDim2.new(1, 0, 1, -5)
	face.BackgroundColor3 = colour
	face.BorderSizePixel = 0
	face.AutoButtonColor = false
	face.Font = T.FONT
	face.Text = str or ""
	face.TextSize = textSize or 17
	face.TextColor3 = T.TEXT
	face.Parent = holder
	T.corner(face, 16)
	T.stroke(face, T.INK, 4)
	T.sheen(face, tint(colour, 0.18), colour)
	T.outlined(face, 3.5)

	face.MouseEnter:Connect(function() face.BackgroundColor3 = tint(colour, 0.12) end)
	face.MouseLeave:Connect(function()
		face.BackgroundColor3 = colour
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 5) end)
	face.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)

	return face, holder
end

-- Round icon badge - the coin/boot disc that sits at the left of a currency pill
-- or the head of a nav button.
function T.badge(parent, glyph, colour, diameter)
	local d = diameter or 42
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.Size = UDim2.fromOffset(d, d)
	b.BackgroundColor3 = colour
	b.BorderSizePixel = 0
	b.Parent = parent
	T.corner(b, d)
	T.stroke(b, T.INK, 4)
	T.sheen(b, tint(colour, 0.3), shade(colour, 0.12))
	local g = T.text(b, glyph, math.floor(d * 0.55), T.INK, Enum.TextXAlignment.Center)
	g.Size = UDim2.fromScale(1, 1)
	g.ZIndex = b.ZIndex + 1
	return b
end

------------------------------------------------------------------ numbers

local UNITS = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.2K". Trailing zeros are stripped with "%.?0+$" and NOT "0+$", which
-- would turn 100.00 into "1".
function T.short(n)
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #UNITS do n /= 1000; i += 1 end
	local body
	if i == 1 then
		body = string.format("%d", math.floor(n))
	else
		body = (string.format("%.1f", n):gsub("%.?0+$", "")) .. UNITS[i]
	end
	return (neg and "-" or "") .. body
end

------------------------------------------------------------------ fit

-- One scale rule for every screen: a phone gets the same layout, shrunk, rather
-- than a second layout that has to be maintained.
function T.autoScale(frames, designW, designH, floor)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local function apply()
		local vp = camera.ViewportSize
		local s = math.clamp(math.min(vp.X / (designW or 1150), vp.Y / (designH or 760)), floor or 0.6, 1)
		for _, f in ipairs(frames) do
			if f and f.Parent then
				local u = f:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", f)
				u.Scale = s
			end
		end
	end
	apply()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	return apply
end

-- Compatibility aliases used by the refreshed light-surface interfaces.
T.C = {
	Ink = T.INK,
	InkSoft = Color3.fromRGB(55, 65, 81),
	Muted = Color3.fromRGB(105, 115, 132),
	Panel = Color3.fromRGB(255, 255, 255),
	PanelAlt = Color3.fromRGB(244, 247, 251),
	White = T.TEXT,
	Shadow = T.SHADOW,
	Yellow = T.GOLD,
	YellowDark = Color3.fromRGB(190, 126, 24),
	Green = T.CASH,
	GreenDark = Color3.fromRGB(42, 139, 67),
	Blue = T.SPEED,
	BlueDark = Color3.fromRGB(38, 113, 170),
	Purple = T.PURPLE,
	Red = T.DANGER,
	RedDark = Color3.fromRGB(169, 52, 66),
}

T.Round = T.corner
T.Stroke = T.stroke

function T.Text(parent, value, position, size, textSize, color, font, align)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = value or ""
	label.TextSize = textSize or 16
	label.TextColor3 = color or T.C.Ink
	label.Font = font or T.BODY_FONT
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	autoOutline(label, textSize or 18, color or T.C.Text)
	return label
end

return T
