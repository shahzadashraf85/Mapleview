--!strict
-- StadiumBuilder.luau
-- Procedurally constructs the entire FIFA stadium, pitch markings, goals, stands, and floodlights.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local StadiumBuilder = {}

local function makePart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent
	return p
end

local function setupAtmosphere()
	Lighting.ClockTime = 20.5 -- Floodlit championship night match
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(45, 52, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 72, 95)
	Lighting.FogEnd = 1200

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmo = Instance.new("Atmosphere")
		atmo.Density = 0.22
		atmo.Offset = 0.25
		atmo.Color = Color3.fromRGB(140, 170, 220)
		atmo.Decay = Color3.fromRGB(40, 50, 80)
		atmo.Glare = 0.35
		atmo.Haze = 1.2
		atmo.Parent = Lighting
	end

	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.45
		bloom.Size = 18
		bloom.Threshold = 1.15
		bloom.Parent = Lighting
	end
end

local function buildLine(parent: Instance, name: string, p1: Vector3, p2: Vector3, width: number)
	local delta = p2 - p1
	local len = delta.Magnitude
	if len < 0.01 then
		return
	end
	local mid = (p1 + p2) * 0.5
	local cf = CFrame.lookAt(mid, p2)
	makePart({
		Name = name,
		Size = Vector3.new(width, 0.08, len + width),
		CFrame = cf,
		Color = Color3.fromRGB(245, 248, 252),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildCircle(parent: Instance, center: Vector3, radius: number, segments: number, lineWidth: number)
	for i = 1, segments do
		local a1 = ((i - 1) / segments) * math.pi * 2
		local a2 = (i / segments) * math.pi * 2
		local p1 = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		local p2 = center + Vector3.new(math.cos(a2) * radius, 0, math.sin(a2) * radius)
		buildLine(parent, "CircleSeg_" .. i, p1, p2, lineWidth)
	end
end

local function buildGoal(parent: Instance, name: string, zPos: number, facingSign: number, goalWidth: number, goalHeight: number)
	local goalFolder = Instance.new("Folder")
	goalFolder.Name = name
	goalFolder.Parent = parent

	local postRadius = 0.45
	local depth = 7.5
	local halfW = goalWidth * 0.5
	local white = Color3.fromRGB(245, 247, 250)

	-- Left & Right Posts
	makePart({
		Name = "LeftPost",
		Size = Vector3.new(postRadius * 2, goalHeight, postRadius * 2),
		CFrame = CFrame.new(-halfW, goalHeight * 0.5, zPos),
		Color = white,
		Material = Enum.Material.Metal,
		Parent = goalFolder,
	})
	makePart({
		Name = "RightPost",
		Size = Vector3.new(postRadius * 2, goalHeight, postRadius * 2),
		CFrame = CFrame.new(halfW, goalHeight * 0.5, zPos),
		Color = white,
		Material = Enum.Material.Metal,
		Parent = goalFolder,
	})
	-- Crossbar
	makePart({
		Name = "Crossbar",
		Size = Vector3.new(goalWidth + postRadius * 2, postRadius * 2, postRadius * 2),
		CFrame = CFrame.new(0, goalHeight, zPos),
		Color = white,
		Material = Enum.Material.Metal,
		Parent = goalFolder,
	})

	-- Back net frame & semi-transparent net panels
	local backZ = zPos + facingSign * depth
	local netColor = Color3.fromRGB(235, 240, 245)

	makePart({
		Name = "BackNet",
		Size = Vector3.new(goalWidth, goalHeight, 0.25),
		CFrame = CFrame.new(0, goalHeight * 0.5, backZ),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
	makePart({
		Name = "TopNet",
		Size = Vector3.new(goalWidth, 0.25, depth),
		CFrame = CFrame.new(0, goalHeight, (zPos + backZ) * 0.5),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
	makePart({
		Name = "LeftNet",
		Size = Vector3.new(0.25, goalHeight, depth),
		CFrame = CFrame.new(-halfW, goalHeight * 0.5, (zPos + backZ) * 0.5),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
	makePart({
		Name = "RightNet",
		Size = Vector3.new(0.25, goalHeight, depth),
		CFrame = CFrame.new(halfW, goalHeight * 0.5, (zPos + backZ) * 0.5),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})

	-- Goal-line sensor (used for visual reference; BallManager also checks exact coordinates)
	makePart({
		Name = "GoalSensor",
		Size = Vector3.new(goalWidth - 0.5, goalHeight - 0.5, depth),
		CFrame = CFrame.new(0, goalHeight * 0.5, (zPos + backZ) * 0.5),
		Color = Color3.fromRGB(255, 215, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = goalFolder,
	})
end

local function buildStandsAndFloodlights(parent: Instance, halfL: number, halfW: number)
	local standsFolder = Instance.new("Folder")
	standsFolder.Name = "Stands"
	standsFolder.Parent = parent

	local margin = 24
	local tierCount = 5
	local tierDepth = 7
	local tierHeight = 4.5
	local crowdPalette = {
		Color3.fromRGB(28, 100, 242),
		Color3.fromRGB(224, 36, 36),
		Color3.fromRGB(245, 158, 11),
		Color3.fromRGB(241, 245, 249),
		Color3.fromRGB(16, 185, 129),
	}

	-- Side stands (East & West)
	for _, side in ipairs({ -1, 1 }) do
		for t = 1, tierCount do
			local x = side * (halfW + margin + (t - 0.5) * tierDepth)
			local y = (t - 0.5) * tierHeight
			makePart({
				Name = "SideTier_" .. side .. "_" .. t,
				Size = Vector3.new(tierDepth, tierHeight, (halfL + margin) * 2),
				CFrame = CFrame.new(x, y, 0),
				Color = Color3.fromRGB(30, 36, 48),
				Material = Enum.Material.Concrete,
				Parent = standsFolder,
			})
			-- Crowd strip
			makePart({
				Name = "Crowd_" .. side .. "_" .. t,
				Size = Vector3.new(tierDepth * 0.55, 1.8, (halfL + margin) * 1.9),
				CFrame = CFrame.new(x, y + tierHeight * 0.5 + 0.9, 0),
				Color = crowdPalette[((t + (side > 0 and 1 or 2)) % #crowdPalette) + 1],
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = standsFolder,
			})
		end
	end

	-- End stands (North & South)
	for _, endSign in ipairs({ -1, 1 }) do
		for t = 1, tierCount do
			local z = endSign * (halfL + margin + (t - 0.5) * tierDepth)
			local y = (t - 0.5) * tierHeight
			makePart({
				Name = "EndTier_" .. endSign .. "_" .. t,
				Size = Vector3.new((halfW + margin) * 2, tierHeight, tierDepth),
				CFrame = CFrame.new(0, y, z),
				Color = Color3.fromRGB(30, 36, 48),
				Material = Enum.Material.Concrete,
				Parent = standsFolder,
			})
		end
	end

	-- 4 Towering Floodlights
	local towerCorners = {
		Vector3.new(-halfW - margin - 18, 0, -halfL - margin - 18),
		Vector3.new(halfW + margin + 18, 0, -halfL - margin - 18),
		Vector3.new(-halfW - margin - 18, 0, halfL + margin + 18),
		Vector3.new(halfW + margin + 18, 0, halfL + margin + 18),
	}
	for i, basePos in ipairs(towerCorners) do
		local towerH = 95
		makePart({
			Name = "FloodlightPole_" .. i,
			Size = Vector3.new(4, towerH, 4),
			CFrame = CFrame.new(basePos + Vector3.new(0, towerH * 0.5, 0)),
			Color = Color3.fromRGB(71, 85, 105),
			Material = Enum.Material.Metal,
			Parent = standsFolder,
		})

		local headPos = basePos + Vector3.new(0, towerH, 0)
		local head = makePart({
			Name = "FloodlightHead_" .. i,
			Size = Vector3.new(12, 6, 3),
			CFrame = CFrame.lookAt(headPos, Vector3.new(0, 0, 0)),
			Color = Color3.fromRGB(255, 250, 235),
			Material = Enum.Material.Neon,
			Parent = standsFolder,
		})

		local spot = Instance.new("SpotLight")
		spot.Brightness = 4.5
		spot.Range = 260
		spot.Angle = 75
		spot.Color = Color3.fromRGB(255, 248, 230)
		spot.Face = Enum.NormalId.Front
		spot.Parent = head
	end
end

local function buildSpawns(parent: Instance, halfL: number)
	local homeTeam = Teams:FindFirstChild("Home FC") :: Team?
	local awayTeam = Teams:FindFirstChild("Away United") :: Team?

	local function createSpawn(name: string, pos: Vector3, lookAtPos: Vector3, team: Team?)
		local sp = Instance.new("SpawnLocation")
		sp.Name = name
		sp.Size = Vector3.new(6, 0.5, 6)
		sp.CFrame = CFrame.lookAt(pos, lookAtPos)
		sp.Anchored = true
		sp.CanCollide = false
		sp.Transparency = 1
		sp.Duration = 0
		if team then
			sp.Neutral = false
			sp.TeamColor = team.TeamColor
		end
		sp.Parent = parent
	end

	for i = -2, 2 do
		createSpawn("HomeSpawn_" .. i, Vector3.new(i * 14, 0.5, -halfL * 0.45), Vector3.new(0, 0.5, 0), homeTeam)
		createSpawn("AwaySpawn_" .. i, Vector3.new(i * 14, 0.5, halfL * 0.45), Vector3.new(0, 0.5, 0), awayTeam)
	end
end

function StadiumBuilder.Build(mode: Config.MatchMode)
	setupAtmosphere()

	local existing = Workspace:FindFirstChild("Stadium")
	if existing then
		existing:Destroy()
	end

	local modeCfg = Config.MatchModes[mode]
	local halfL = modeCfg.PitchLength * 0.5
	local halfW = modeCfg.PitchWidth * 0.5

	local stadium = Instance.new("Folder")
	stadium.Name = "Stadium"
	stadium.Parent = Workspace

	-- Concrete stadium floor apron
	makePart({
		Name = "StadiumFloor",
		Size = Vector3.new(modeCfg.PitchWidth + 130, 4, modeCfg.PitchLength + 130),
		CFrame = CFrame.new(0, -2.1, 0),
		Color = Color3.fromRGB(45, 52, 64),
		Material = Enum.Material.Concrete,
		Parent = stadium,
	})

	-- Mowed grass stripes
	local stripeCount = 16
	local stripeLen = modeCfg.PitchLength / stripeCount
	for i = 1, stripeCount do
		local z = -halfL + (i - 0.5) * stripeLen
		local isEven = (i % 2 == 0)
		makePart({
			Name = "TurfStripe_" .. i,
			Size = Vector3.new(modeCfg.PitchWidth + 10, Config.TurfThickness, stripeLen),
			CFrame = CFrame.new(0, -Config.TurfThickness * 0.5, z),
			Color = if isEven then Color3.fromRGB(34, 139, 64) else Color3.fromRGB(40, 156, 72),
			Material = Enum.Material.Grass,
			Parent = stadium,
		})
	end

	-- Pitch Lines
	local linesFolder = Instance.new("Folder")
	linesFolder.Name = "PitchLines"
	linesFolder.Parent = stadium

	local y = 0.05
	local lw = 0.65

	-- Outer touchlines & goal lines
	buildLine(linesFolder, "NorthGoalLine", Vector3.new(-halfW, y, -halfL), Vector3.new(halfW, y, -halfL), lw)
	buildLine(linesFolder, "SouthGoalLine", Vector3.new(-halfW, y, halfL), Vector3.new(halfW, y, halfL), lw)
	buildLine(linesFolder, "WestTouchline", Vector3.new(-halfW, y, -halfL), Vector3.new(-halfW, y, halfL), lw)
	buildLine(linesFolder, "EastTouchline", Vector3.new(halfW, y, -halfL), Vector3.new(halfW, y, halfL), lw)

	-- Halfway line & center circle
	buildLine(linesFolder, "HalfwayLine", Vector3.new(-halfW, y, 0), Vector3.new(halfW, y, 0), lw)
	buildCircle(linesFolder, Vector3.new(0, y, 0), 22, 32, lw)

	-- Center spot
	makePart({
		Name = "CenterSpot",
		Size = Vector3.new(1.8, 0.08, 1.8),
		CFrame = CFrame.new(0, y, 0),
		Color = Color3.fromRGB(245, 248, 252),
		CanCollide = false,
		Parent = linesFolder,
	})

	-- Penalty boxes (Home & Away)
	local boxDepth = Config.Kicks.GKBoxDepth
	local boxHalfW = Config.Kicks.GKBoxWidth * 0.5
	for _, endSign in ipairs({ -1, 1 }) do
		local goalZ = endSign * halfL
		local boxZ = goalZ - endSign * boxDepth
		buildLine(linesFolder, "BoxFront_" .. endSign, Vector3.new(-boxHalfW, y, boxZ), Vector3.new(boxHalfW, y, boxZ), lw)
		buildLine(linesFolder, "BoxLeft_" .. endSign, Vector3.new(-boxHalfW, y, goalZ), Vector3.new(-boxHalfW, y, boxZ), lw)
		buildLine(linesFolder, "BoxRight_" .. endSign, Vector3.new(boxHalfW, y, goalZ), Vector3.new(boxHalfW, y, boxZ), lw)

		-- Penalty spot
		makePart({
			Name = "PenaltySpot_" .. endSign,
			Size = Vector3.new(1.5, 0.08, 1.5),
			CFrame = CFrame.new(0, y, goalZ - endSign * (boxDepth * 0.68)),
			Color = Color3.fromRGB(245, 248, 252),
			CanCollide = false,
			Parent = linesFolder,
		})
	end

	-- Corner flags
	local corners = {
		Vector3.new(-halfW, 0, -halfL),
		Vector3.new(halfW, 0, -halfL),
		Vector3.new(-halfW, 0, halfL),
		Vector3.new(halfW, 0, halfL),
	}
	for i, cPos in ipairs(corners) do
		makePart({
			Name = "CornerPole_" .. i,
			Size = Vector3.new(0.35, 5, 0.35),
			CFrame = CFrame.new(cPos + Vector3.new(0, 2.5, 0)),
			Color = Color3.fromRGB(250, 204, 21),
			CanCollide = false,
			Parent = stadium,
		})
		makePart({
			Name = "CornerFlag_" .. i,
			Size = Vector3.new(1.8, 1.1, 0.15),
			CFrame = CFrame.new(cPos + Vector3.new(0.9, 4.4, 0)),
			Color = Color3.fromRGB(239, 68, 68),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = stadium,
		})
	end

	-- Goals (Home defends -halfL, Away defends +halfL)
	buildGoal(stadium, "HomeGoal", -halfL, -1, modeCfg.GoalWidth, modeCfg.GoalHeight)
	buildGoal(stadium, "AwayGoal", halfL, 1, modeCfg.GoalWidth, modeCfg.GoalHeight)

	-- Stands & Floodlights
	buildStandsAndFloodlights(stadium, halfL, halfW)

	-- Team SpawnLocations
	buildSpawns(stadium, halfL)
end

return StadiumBuilder
