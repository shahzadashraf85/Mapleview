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

return ModelFactory
