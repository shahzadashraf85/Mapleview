--!strict
-- ModelFactory.luau
-- Procedurally constructs custom 3D models: Championship Trophy, Dugouts, Floodlight Towers, 3D Fans, and 3D Goalkeepers.

local ModelFactory = {}

local function part(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	Reflectance: number?,
	Parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	p.Reflectance = props.Reflectance or 0
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent
	return p
end

-- Custom 3D Championship Trophy Model
function ModelFactory.BuildTrophy(parent: Instance, position: Vector3, titleText: string): Model
	local model = Instance.new("Model")
	model.Name = "ChampionshipTrophy"

	local gold = Color3.fromRGB(250, 204, 21)
	local darkMarble = Color3.fromRGB(15, 23, 42)

	-- Tiered Base
	part({
		Name = "BaseLower",
		Size = Vector3.new(6.5, 1.4, 6.5),
		CFrame = CFrame.new(position + Vector3.new(0, 0.7, 0)),
		Color = darkMarble,
		Material = Enum.Material.Marble,
		Parent = model,
	})
	part({
		Name = "BaseUpper",
		Size = Vector3.new(4.4, 1.1, 4.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.95, 0)),
		Color = gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.4,
		Parent = model,
	})
	-- Stem
	part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 1.3, 1.3),
		CFrame = CFrame.new(position + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.5,
		Parent = model,
	})
	-- Cup Bowl
	local bowl = part({
		Name = "CupBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 3.8, 3.8),
		CFrame = CFrame.new(position + Vector3.new(0, 6.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.55,
		Parent = model,
	})
	-- Handles
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "Handle_" .. side,
			Size = Vector3.new(0.5, 2.2, 1.2),
			CFrame = CFrame.new(position + Vector3.new(side * 2.25, 6.1, 0)),
			Color = gold,
			Material = Enum.Material.Metal,
			Reflectance = 0.45,
			Parent = model,
		})
	end
	-- Glowing Crown Ball
	part({
		Name = "CrownOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.5, 1.5),
		CFrame = CFrame.new(position + Vector3.new(0, 8.2, 0)),
		Color = Color3.fromRGB(255, 235, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 56)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = bowl

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = titleText
	lbl.TextColor3 = gold
	lbl.TextStrokeTransparency = 0.2
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = bb

	model.Parent = parent
	return model
end

-- Custom 3D Team Dugout Shelter & Bench
function ModelFactory.BuildDugout(parent: Instance, cf: CFrame, teamColor: Color3, name: string): Model
	local model = Instance.new("Model")
	model.Name = name

	-- Back & Roof Glass
	part({
		Name = "BackGlass",
		Size = Vector3.new(24, 7.5, 0.4),
		CFrame = cf * CFrame.new(0, 3.75, 2.5),
		Color = Color3.fromRGB(148, 163, 184),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		Parent = model,
	})
	part({
		Name = "Roof",
		Size = Vector3.new(24.6, 0.4, 6),
		CFrame = cf * CFrame.new(0, 7.6, 0) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = teamColor,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Bench Seat
	part({
		Name = "Bench",
		Size = Vector3.new(21, 0.6, 2.2),
		CFrame = cf * CFrame.new(0, 1.8, 0.8),
		Color = Color3.fromRGB(30, 41, 59),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	for i = -2, 2 do
		part({
			Name = "SeatBack_" .. i,
			Size = Vector3.new(2.6, 2.4, 0.4),
			CFrame = cf * CFrame.new(i * 4.2, 3.1, 1.7),
			Color = teamColor,
			Parent = model,
		})
	end

	model.Parent = parent
	return model
end

-- Custom 3D Floodlight Tower with Neon Light Bank & SpotLights
function ModelFactory.BuildFloodlightTower(parent: Instance, basePos: Vector3, accentColor: Color3, idx: number): Model
	local model = Instance.new("Model")
	model.Name = "FloodlightTower_" .. idx

	local towerH = 105
	-- Main Steel Pylon
	part({
		Name = "Pylon",
		Size = Vector3.new(4.2, towerH, 4.2),
		CFrame = CFrame.new(basePos + Vector3.new(0, towerH * 0.5, 0)),
		Color = Color3.fromRGB(51, 65, 85),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Accent Neon Ring
	part({
		Name = "TowerAccent",
		Size = Vector3.new(4.8, 2.0, 4.8),
		CFrame = CFrame.new(basePos + Vector3.new(0, towerH * 0.85, 0)),
		Color = accentColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	-- Light Bank aimed at center pitch
	local headPos = basePos + Vector3.new(0, towerH, 0)
	local headCF = CFrame.lookAt(headPos, Vector3.new(0, 0, 0))
	local bank = part({
		Name = "LightBank",
		Size = Vector3.new(18, 9, 2.5),
		CFrame = headCF,
		Color = Color3.fromRGB(30, 41, 59),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local bulbs = part({
		Name = "Bulbs",
		Size = Vector3.new(16, 7.5, 0.6),
		CFrame = headCF * CFrame.new(0, 0, -1.4),
		Color = Color3.fromRGB(255, 250, 232),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	local spot = Instance.new("SpotLight")
	spot.Brightness = 5.5
	spot.Range = 320
	spot.Angle = 82
	spot.Color = Color3.fromRGB(255, 248, 228)
	spot.Face = Enum.NormalId.Front
	spot.Parent = bulbs

	model.Parent = parent
	return model
end

-- Custom 3D Articulated Goalkeeper Model
function ModelFactory.BuildGoalkeeper(parent: Instance, name: string, pos: Vector3, lookAtPos: Vector3, jerseyColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = name

	local cf = CFrame.lookAt(pos, lookAtPos)
	local skin = Color3.fromRGB(234, 192, 150)
	local glove = Color3.fromRGB(250, 204, 21)

	local root = part({
		Name = "Root",
		Size = Vector3.new(2.2, 2.6, 1.2),
		CFrame = cf * CFrame.new(0, 3.2, 0),
		Color = jerseyColor,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = root

	part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.7, 1.7, 1.7),
		CFrame = cf * CFrame.new(0, 5.2, 0),
		Color = skin,
		CanCollide = false,
		Parent = model,
	})
	-- Arms & Keeper Gloves
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "Arm_" .. side,
			Size = Vector3.new(0.75, 2.3, 0.75),
			CFrame = cf * CFrame.new(side * 1.65, 3.4, 0) * CFrame.Angles(0, 0, math.rad(side * 18)),
			Color = jerseyColor,
			CanCollide = false,
			Parent = model,
		})
		part({
			Name = "Glove_" .. side,
			Size = Vector3.new(0.95, 0.95, 0.95),
			CFrame = cf * CFrame.new(side * 2.0, 2.2, -0.3),
			Color = glove,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	-- Legs & Boots
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "Leg_" .. side,
			Size = Vector3.new(0.9, 2.0, 0.9),
			CFrame = cf * CFrame.new(side * 0.55, 1.1, 0),
			Color = Color3.fromRGB(20, 24, 34),
			CanCollide = false,
			Parent = model,
		})
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 28)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "GK"
	lbl.TextColor3 = glove
	lbl.TextStrokeTransparency = 0.2
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = bb

	model.Parent = parent
	return model
end

-- Custom 3D Stadium Jumbotron Scoreboard
function ModelFactory.BuildJumbotron(parent: Instance, cf: CFrame, accentColor: Color3, titleText: string): Model
	local model = Instance.new("Model")
	model.Name = "StadiumJumbotron"

	part({
		Name = "Frame",
		Size = Vector3.new(44, 18, 2.5),
		CFrame = cf,
		Color = Color3.fromRGB(15, 23, 42),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(41, 15, 0.5),
		CFrame = cf * CFrame.new(0, 0, -1.3),
		Color = Color3.fromRGB(20, 30, 50),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	part({
		Name = "TopTrim",
		Size = Vector3.new(45, 1.2, 3),
		CFrame = cf * CFrame.new(0, 9.4, 0),
		Color = accentColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = screen

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = titleText
	lbl.TextColor3 = Color3.fromRGB(250, 204, 21)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = sg

	model.Parent = parent
	return model
end

-- Custom 3D Glowing Lobby Fountain
function ModelFactory.BuildFountain(parent: Instance, pos: Vector3, accentColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = "LobbyFountain"

	part({
		Name = "PoolRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.8, 18, 18),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(30, 41, 59),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local water = part({
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 16, 16),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(56, 189, 248),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Parent = model,
	})
	part({
		Name = "CenterPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 3, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = accentColor,
		Material = Enum.Material.Neon,
		Parent = model,
	})

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(186, 230, 253), Color3.fromRGB(255, 255, 255))
	pe.Size = NumberSequence.new(0.45)
	pe.Speed = NumberRange.new(12, 18)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.Acceleration = Vector3.new(0, -28, 0)
	pe.Lifetime = NumberRange.new(0.9, 1.3)
	pe.Rate = 35
	pe.Parent = water

	model.Parent = parent
	return model
end

-- Custom 3D Stylized Lobby Tree
function ModelFactory.BuildTree(parent: Instance, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "LobbyTree"

	part({
		Name = "Planter",
		Size = Vector3.new(5, 1.6, 5),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)),
		Color = Color3.fromRGB(51, 65, 85),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 1.4, 1.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 72, 42),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Name = "Canopy1",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 5.5, 7),
		CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)),
		Color = Color3.fromRGB(34, 197, 94),
		Material = Enum.Material.Grass,
		Parent = model,
	})
	model.Parent = parent
	return model
end

-- Custom 3D VIP Lounge Booth
function ModelFactory.BuildLoungeBooth(parent: Instance, cf: CFrame, accentColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = "LoungeBooth"

	part({
		Name = "SofaSeat",
		Size = Vector3.new(10, 1.4, 3.2),
		CFrame = cf * CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(30, 41, 59),
		Parent = model,
	})
	part({
		Name = "SofaBack",
		Size = Vector3.new(10, 2.2, 0.8),
		CFrame = cf * CFrame.new(0, 2.0, 1.2),
		Color = accentColor,
		Parent = model,
	})
	part({
		Name = "Table",
		Size = Vector3.new(6, 1.2, 2.4),
		CFrame = cf * CFrame.new(0, 0.6, -4.2),
		Color = Color3.fromRGB(148, 163, 184),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = model,
	})
	model.Parent = parent
	return model
end

-- Custom 3D Hammer Tool (labeled "Hammer", opens the secret panel when activated)
function ModelFactory.BuildHammerTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Hammer"
	tool.ToolTip = "Hammer"
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 3.4, 0.45)
	handle.Color = Color3.fromRGB(120, 72, 42)
	handle.Material = Enum.Material.Wood
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "HammerHead"
	head.Size = Vector3.new(1.4, 1.2, 2.6)
	head.Color = Color3.fromRGB(250, 204, 21)
	head.Material = Enum.Material.Metal
	head.Reflectance = 0.35
	head.CanCollide = false
	head.CFrame = handle.CFrame * CFrame.new(0, 1.8, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head

	local glow = Instance.new("Part")
	glow.Name = "HammerGlow"
	glow.Size = Vector3.new(1.5, 0.35, 2.7)
	glow.Color = Color3.fromRGB(239, 68, 68)
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	glow.CFrame = head.CFrame
	glow.Parent = tool

	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = head
	weld2.Part1 = glow
	weld2.Parent = glow

	return tool
end

-- Custom 3D Taco Model for Raining Tacos Disco Party!
function ModelFactory.BuildTaco(position: Vector3): Model
	local taco = Instance.new("Model")
	taco.Name = "RainingTaco"

	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Size = Vector3.new(2.2, 1.3, 1.0)
	shell.Position = position
	shell.Color = Color3.fromRGB(245, 190, 70)
	shell.Material = Enum.Material.SmoothPlastic
	shell.CanCollide = false
	shell.Anchored = false
	shell.Parent = taco
	taco.PrimaryPart = shell

	local filling = Instance.new("Part")
	filling.Name = "Filling"
	filling.Size = Vector3.new(1.9, 0.7, 0.7)
	filling.Position = position + Vector3.new(0, 0.45, 0)
	filling.Color = Color3.fromRGB(115, 62, 34)
	filling.CanCollide = false
	filling.Parent = taco

	local lettuce = Instance.new("Part")
	lettuce.Name = "Lettuce"
	lettuce.Size = Vector3.new(2.0, 0.35, 0.8)
	lettuce.Position = position + Vector3.new(0, 0.75, 0)
	lettuce.Color = Color3.fromRGB(74, 222, 128)
	lettuce.CanCollide = false
	lettuce.Parent = taco

	for _, p in ipairs({ filling, lettuce }) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = shell
		w.Part1 = p
		w.Parent = p
	end

	return taco
end

-- Custom 3D Footballer Star Model (Ronaldo, Messi, Neymar)
function ModelFactory.BuildFootballer(
	parent: Instance,
	name: string,
	pos: Vector3,
	lookAtPos: Vector3,
	jerseyColor: Color3,
	shortsColor: Color3,
	labelColor: Color3
): Model
	local model = Instance.new("Model")
	model.Name = name

	local cf = CFrame.lookAt(pos, lookAtPos)
	local skin = Color3.fromRGB(234, 192, 150)

	local root = part({
		Name = "Root",
		Size = Vector3.new(2.3, 2.7, 1.2),
		CFrame = cf * CFrame.new(0, 3.3, 0),
		Color = jerseyColor,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = root

	part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = cf * CFrame.new(0, 5.4, 0),
		Color = skin,
		CanCollide = false,
		Parent = model,
	})
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "Arm_" .. side,
			Size = Vector3.new(0.75, 2.3, 0.75),
			CFrame = cf * CFrame.new(side * 1.65, 3.4, 0) * CFrame.Angles(0, 0, math.rad(side * 14)),
			Color = jerseyColor,
			CanCollide = false,
			Parent = model,
		})
		part({
			Name = "Leg_" .. side,
			Size = Vector3.new(0.9, 2.1, 0.9),
			CFrame = cf * CFrame.new(side * 0.55, 1.1, 0),
			Color = shortsColor,
			CanCollide = false,
			Parent = model,
		})
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 44)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = name
	lbl.TextColor3 = labelColor
	lbl.TextStrokeTransparency = 0.2
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = bb

	model.Parent = parent
	return model
end

-- Custom 3D Football Concert Disco Stage with Ronaldo, Messi, Neymar & Concert Goal
function ModelFactory.BuildConcertStage(parent: Instance, center: Vector3): Folder
	local concert = Instance.new("Folder")
	concert.Name = "ConcertStage"
	concert.Parent = parent

	-- Main Disco Dance Floor
	part({
		Name = "DiscoFloor",
		Size = Vector3.new(140, 3, 140),
		CFrame = CFrame.new(center + Vector3.new(0, -1.5, 0)),
		Color = Color3.fromRGB(15, 23, 42),
		Material = Enum.Material.Marble,
		Parent = concert,
	})

	-- Colorful Neon Disco Tiles
	local tileColors = {
		Color3.fromRGB(236, 72, 153),
		Color3.fromRGB(56, 189, 248),
		Color3.fromRGB(250, 204, 21),
		Color3.fromRGB(34, 197, 94),
		Color3.fromRGB(168, 85, 247),
	}
	for gx = -3, 3 do
		for gz = -2, 3 do
			local col = tileColors[((math.abs(gx) + math.abs(gz)) % #tileColors) + 1]
			part({
				Name = "DiscoTile_" .. gx .. "_" .. gz,
				Size = Vector3.new(13, 0.2, 13),
				CFrame = CFrame.new(center + Vector3.new(gx * 15, 0.1, gz * 15)),
				Color = col,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				CanCollide = false,
				Parent = concert,
			})
		end
	end

	-- Elevated Concert Stage Platform at -Z
	local stagePos = center + Vector3.new(0, 3.5, -42)
	part({
		Name = "StageDeck",
		Size = Vector3.new(72, 7, 28),
		CFrame = CFrame.new(stagePos),
		Color = Color3.fromRGB(30, 41, 59),
		Material = Enum.Material.Metal,
		Parent = concert,
	})
	part({
		Name = "StageNeonRim",
		Size = Vector3.new(73, 1, 29),
		CFrame = CFrame.new(stagePos + Vector3.new(0, 3.3, 0)),
		Color = Color3.fromRGB(236, 72, 153),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = concert,
	})

	-- Stage Lighting Truss & Overhead Rig
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "StagePillar_" .. side,
			Size = Vector3.new(3, 32, 3),
			CFrame = CFrame.new(stagePos + Vector3.new(side * 34, 16, -8)),
			Color = Color3.fromRGB(51, 65, 85),
			Material = Enum.Material.Metal,
			Parent = concert,
		})
	end
	local rig = part({
		Name = "StageLightRig",
		Size = Vector3.new(72, 2.5, 3),
		CFrame = CFrame.new(stagePos + Vector3.new(0, 32, -8)),
		Color = Color3.fromRGB(56, 189, 248),
		Material = Enum.Material.Neon,
		Parent = concert,
	})
	local pl = Instance.new("PointLight")
	pl.Brightness = 4
	pl.Range = 160
	pl.Color = Color3.fromRGB(236, 72, 153)
	pl.Parent = rig

	ModelFactory.BuildJumbotron(concert, CFrame.new(stagePos + Vector3.new(0, 20, -12)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(236, 72, 153), "RONALDO • MESSI • NEYMAR CONCERT")

	-- Concert Goal on Stage Right for Ronaldo's Scoring + SIUUUU Scene!
	local goalCenter = stagePos + Vector3.new(22, 3.5, 0)
	part({
		Name = "ConcertGoalPostL",
		Size = Vector3.new(0.6, 7, 0.6),
		CFrame = CFrame.new(goalCenter + Vector3.new(0, 3.5, -5.5)),
		Color = Color3.new(1, 1, 1),
		Parent = concert,
	})
	part({
		Name = "ConcertGoalPostR",
		Size = Vector3.new(0.6, 7, 0.6),
		CFrame = CFrame.new(goalCenter + Vector3.new(0, 3.5, 5.5)),
		Color = Color3.new(1, 1, 1),
		Parent = concert,
	})
	part({
		Name = "ConcertGoalBar",
		Size = Vector3.new(0.6, 0.6, 11.6),
		CFrame = CFrame.new(goalCenter + Vector3.new(0, 7, 0)),
		Color = Color3.new(1, 1, 1),
		Parent = concert,
	})
	part({
		Name = "ConcertGoalNet",
		Size = Vector3.new(0.25, 7, 11),
		CFrame = CFrame.new(goalCenter + Vector3.new(4, 3.5, 0)),
		Color = Color3.fromRGB(235, 240, 245),
		Material = Enum.Material.Fabric,
		Transparency = 0.5,
		Parent = concert,
	})

	-- 3D Football Superstars on Stage: RONALDO #7, MESSI #10, NEYMAR #10
	local stageTopY = stagePos.Y + 3.5
	ModelFactory.BuildFootballer(
		concert,
		"RONALDO #7",
		Vector3.new(stagePos.X - 6, stageTopY, stagePos.Z + 2),
		Vector3.new(goalCenter.X, stageTopY, goalCenter.Z),
		Color3.fromRGB(245, 245, 250),
		Color3.fromRGB(250, 204, 21),
		Color3.fromRGB(250, 204, 21)
	)
	ModelFactory.BuildFootballer(
		concert,
		"MESSI #10",
		Vector3.new(stagePos.X - 18, stageTopY, stagePos.Z - 4),
		center,
		Color3.fromRGB(56, 189, 248),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(56, 189, 248)
	)
	ModelFactory.BuildFootballer(
		concert,
		"NEYMAR #10",
		Vector3.new(stagePos.X - 28, stageTopY, stagePos.Z + 2),
		center,
		Color3.fromRGB(250, 204, 21),
		Color3.fromRGB(22, 163, 74),
		Color3.fromRGB(74, 222, 128)
	)

	-- Golden Ball for Ronaldo's Concert Shot
	local rBall = Instance.new("Part")
	rBall.Name = "RonaldoConcertBall"
	rBall.Shape = Enum.PartType.Ball
	rBall.Size = Vector3.one * 2.8
	rBall.Position = Vector3.new(stagePos.X - 2, stageTopY + 1.4, stagePos.Z + 2)
	rBall.Color = Color3.fromRGB(250, 204, 21)
	rBall.Material = Enum.Material.Neon
	rBall.Anchored = true
	rBall.CanCollide = false
	rBall.Parent = concert

	return concert
end

return ModelFactory
