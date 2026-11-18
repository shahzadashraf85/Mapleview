--!strict
-- StadiumBuilder.luau
-- Procedurally constructs a realistic FIFA stadium (with 3D fans, roof canopies, LED boards, dugouts, floodlights)
-- plus a cool Lobby Lounge with a Practice Training Pitch and 4 selectable Stadium Themes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFactory = require(script.Parent.ModelFactory)

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

local function setupAtmosphere(themeCfg: any)
	Lighting.ClockTime = themeCfg.ClockTime
	Lighting.Brightness = 2.4
	Lighting.Ambient = themeCfg.Ambient
	Lighting.OutdoorAmbient = themeCfg.Ambient
	Lighting.FogEnd = 1600

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.2
	atmo.Offset = 0.25
	atmo.Color = Color3.fromRGB(150, 180, 230)
	atmo.Decay = Color3.fromRGB(40, 50, 80)
	atmo.Glare = 0.35
	atmo.Haze = 1.1
	atmo.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 18
	bloom.Threshold = 1.15
	bloom.Parent = Lighting
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

local function buildGoal(parent: Instance, name: string, centerPos: Vector3, facingSign: number, goalWidth: number, goalHeight: number)
	local goalFolder = Instance.new("Folder")
	goalFolder.Name = name
	goalFolder.Parent = parent

	local postRadius = 0.45
	local depth = 7.5
	local halfW = goalWidth * 0.5
	local white = Color3.fromRGB(245, 247, 250)

	makePart({
		Name = "LeftPost",
		Size = Vector3.new(postRadius * 2, goalHeight, postRadius * 2),
		CFrame = CFrame.new(centerPos + Vector3.new(-halfW, goalHeight * 0.5, 0)),
		Color = white,
		Material = Enum.Material.Metal,
		Parent = goalFolder,
	})
	makePart({
		Name = "RightPost",
		Size = Vector3.new(postRadius * 2, goalHeight, postRadius * 2),
		CFrame = CFrame.new(centerPos + Vector3.new(halfW, goalHeight * 0.5, 0)),
		Color = white,
		Material = Enum.Material.Metal,
		Parent = goalFolder,
	})
	makePart({
		Name = "Crossbar",
		Size = Vector3.new(goalWidth + postRadius * 2, postRadius * 2, postRadius * 2),
		CFrame = CFrame.new(centerPos + Vector3.new(0, goalHeight, 0)),
		Color = white,
		Material = Enum.Material.Metal,
		Parent = goalFolder,
	})

	local backZ = centerPos.Z + facingSign * depth
	local midZ = (centerPos.Z + backZ) * 0.5
	local netColor = Color3.fromRGB(235, 240, 245)

	makePart({
		Name = "BackNet",
		Size = Vector3.new(goalWidth, goalHeight, 0.25),
		CFrame = CFrame.new(centerPos.X, centerPos.Y + goalHeight * 0.5, backZ),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
	makePart({
		Name = "TopNet",
		Size = Vector3.new(goalWidth, 0.25, depth),
		CFrame = CFrame.new(centerPos.X, centerPos.Y + goalHeight, midZ),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
	makePart({
		Name = "LeftNet",
		Size = Vector3.new(0.25, goalHeight, depth),
		CFrame = CFrame.new(centerPos.X - halfW, centerPos.Y + goalHeight * 0.5, midZ),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
	makePart({
		Name = "RightNet",
		Size = Vector3.new(0.25, goalHeight, depth),
		CFrame = CFrame.new(centerPos.X + halfW, centerPos.Y + goalHeight * 0.5, midZ),
		Color = netColor,
		Material = Enum.Material.Fabric,
		Transparency = 0.55,
		Parent = goalFolder,
	})
end

-- Spawns 3D Fan Figures in the stands
local function spawn3DFans(parent: Instance, startPos: Vector3, stepVec: Vector3, count: number, palette: { Color3 })
	local skinTones = {
		Color3.fromRGB(240, 200, 165),
		Color3.fromRGB(198, 145, 102),
		Color3.fromRGB(130, 86, 56),
		Color3.fromRGB(252, 224, 196),
	}
	for i = 0, count - 1 do
		local pos = startPos + stepVec * i
		local jersey = palette[(i % #palette) + 1]
		local skin = skinTones[(i % #skinTones) + 1]

		local torso = makePart({
			Name = "FanTorso",
			Size = Vector3.new(1.8, 2.0, 1.0),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.0, 0)),
			Color = jersey,
			CanCollide = false,
			Parent = parent,
		})
		torso:SetAttribute("IsFan", true)
		torso:SetAttribute("BaseY", pos.Y + 1.0)

		makePart({
			Name = "FanHead",
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.6, 0)),
			Color = skin,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildStandsRoofAndFans(parent: Instance, halfL: number, halfW: number, themeCfg: any)
	local standsFolder = Instance.new("Folder")
	standsFolder.Name = "Stands"
	standsFolder.Parent = parent

	local margin = 22
	local tierCount = 5
	local tierDepth = 7.5
	local tierHeight = 4.6
	local standColor = themeCfg.StandColor
	local accent = themeCfg.Accent
	local crowdPalette = {
		Config.Teams.Home.PrimaryColor,
		Config.Teams.Away.PrimaryColor,
		accent,
		Color3.fromRGB(241, 245, 249),
		Color3.fromRGB(16, 185, 129),
	}

	-- Perimeter Glowing LED Ad Boards
	local adY = 1.6
	makePart({
		Name = "LEDBoard_West",
		Size = Vector3.new(0.8, 3.2, halfL * 2 + 12),
		CFrame = CFrame.new(-halfW - 10, adY, 0),
		Color = accent,
		Material = Enum.Material.Neon,
		Parent = standsFolder,
	})
	makePart({
		Name = "LEDBoard_East",
		Size = Vector3.new(0.8, 3.2, halfL * 2 + 12),
		CFrame = CFrame.new(halfW + 10, adY, 0),
		Color = accent,
		Material = Enum.Material.Neon,
		Parent = standsFolder,
	})

	-- Side stands (East & West) + Roof Canopies + 3D Fans
	for _, side in ipairs({ -1, 1 }) do
		for t = 1, tierCount do
			local x = side * (halfW + margin + (t - 0.5) * tierDepth)
			local y = (t - 0.5) * tierHeight
			makePart({
				Name = "SideTier_" .. side .. "_" .. t,
				Size = Vector3.new(tierDepth, tierHeight, (halfL + margin) * 2),
				CFrame = CFrame.new(x, y, 0),
				Color = standColor,
				Material = Enum.Material.Concrete,
				Parent = standsFolder,
			})

			-- Add 3D fans on tiers 2 and 4
			if t == 2 or t == 4 then
				local fanCount = math.floor((halfL * 1.8) / 14)
				spawn3DFans(
					standsFolder,
					Vector3.new(x, y + tierHeight * 0.5, -halfL * 0.85),
					Vector3.new(0, 0, 14),
					fanCount,
					crowdPalette
				)
			end
		end

		-- Stadium Roof Canopy + Overhead Rim Lights
		local roofX = side * (halfW + margin + tierCount * tierDepth * 0.55)
		local roofY = tierCount * tierHeight + 14
		local roof = makePart({
			Name = "SideRoof_" .. side,
			Size = Vector3.new(tierCount * tierDepth + 14, 1.8, (halfL + margin) * 2 + 12),
			CFrame = CFrame.new(roofX, roofY, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)),
			Color = Color3.fromRGB(30, 41, 59),
			Material = Enum.Material.Metal,
			Parent = standsFolder,
		})
		makePart({
			Name = "RoofNeonTrim_" .. side,
			Size = Vector3.new(1.2, 1.2, (halfL + margin) * 2 + 10),
			CFrame = CFrame.new(side * (halfW + margin - 3), roofY - 4, 0),
			Color = accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = standsFolder,
		})
		local pl = Instance.new("PointLight")
		pl.Brightness = 1.6
		pl.Range = 90
		pl.Color = Color3.fromRGB(255, 248, 230)
		pl.Parent = roof
	end

	-- End stands (North & South) + 3D Fans + Roofs
	for _, endSign in ipairs({ -1, 1 }) do
		for t = 1, tierCount do
			local z = endSign * (halfL + margin + (t - 0.5) * tierDepth)
			local y = (t - 0.5) * tierHeight
			makePart({
				Name = "EndTier_" .. endSign .. "_" .. t,
				Size = Vector3.new((halfW + margin) * 2, tierHeight, tierDepth),
				CFrame = CFrame.new(0, y, z),
				Color = standColor,
				Material = Enum.Material.Concrete,
				Parent = standsFolder,
			})
			if t == 3 then
				local fanCount = math.floor((halfW * 1.7) / 14)
				spawn3DFans(
					standsFolder,
					Vector3.new(-halfW * 0.8, y + tierHeight * 0.5, z),
					Vector3.new(14, 0, 0),
					fanCount,
					crowdPalette
				)
			end
		end

		local roofZ = endSign * (halfL + margin + tierCount * tierDepth * 0.55)
		local roofY = tierCount * tierHeight + 14
		makePart({
			Name = "EndRoof_" .. endSign,
			Size = Vector3.new((halfW + margin) * 2 + 12, 1.8, tierCount * tierDepth + 14),
			CFrame = CFrame.new(0, roofY, roofZ) * CFrame.Angles(math.rad(endSign * 12), 0, 0),
			Color = Color3.fromRGB(30, 41, 59),
			Material = Enum.Material.Metal,
			Parent = standsFolder,
		})
	end

	-- 3D Team Dugouts along West Touchline
	ModelFactory.BuildDugout(standsFolder, CFrame.new(-halfW - 14, 0, -28) * CFrame.Angles(0, math.rad(-90), 0), Config.Teams.Home.PrimaryColor, "HomeDugout")
	ModelFactory.BuildDugout(standsFolder, CFrame.new(-halfW - 14, 0, 28) * CFrame.Angles(0, math.rad(-90), 0), Config.Teams.Away.PrimaryColor, "AwayDugout")

	-- 4 Towering 3D Floodlight Towers
	local towerCorners = {
		Vector3.new(-halfW - margin - 20, 0, -halfL - margin - 20),
		Vector3.new(halfW + margin + 20, 0, -halfL - margin - 20),
		Vector3.new(-halfW - margin - 20, 0, halfL + margin + 20),
		Vector3.new(halfW + margin + 20, 0, halfL + margin + 20),
	}
	for i, basePos in ipairs(towerCorners) do
		ModelFactory.BuildFloodlightTower(standsFolder, basePos, accent, i)
	end
end

-- Cool Lobby + Practice Training Pitch
local function buildLobby(parent: Instance)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = parent

	local center = Config.LobbyCenter

	-- Main Lobby Plaza Floor
	makePart({
		Name = "LobbyFloor",
		Size = Vector3.new(150, 3, 170),
		CFrame = CFrame.new(center + Vector3.new(0, -1.5, 0)),
		Color = Color3.fromRGB(15, 23, 42),
		Material = Enum.Material.Marble,
		Parent = lobby,
	})

	-- Glowing Neon Entrance Arch
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "ArchPillar_" .. side,
			Size = Vector3.new(3, 22, 3),
			CFrame = CFrame.new(center + Vector3.new(side * 18, 11, -68)),
			Color = Color3.fromRGB(30, 41, 59),
			Material = Enum.Material.Metal,
			Parent = lobby,
		})
	end
	local archTop = makePart({
		Name = "ArchTop",
		Size = Vector3.new(40, 4, 3.5),
		CFrame = CFrame.new(center + Vector3.new(0, 22, -68)),
		Color = Color3.fromRGB(250, 204, 21),
		Material = Enum.Material.Neon,
		Parent = lobby,
	})
	local archLight = Instance.new("PointLight")
	archLight.Brightness = 3
	archLight.Range = 120
	archLight.Color = Color3.fromRGB(250, 204, 21)
	archLight.Parent = archTop

	-- Lobby Welcome Sign
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(320, 70)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = archTop

	local signLbl = Instance.new("TextLabel")
	signLbl.Size = UDim2.fromScale(1, 1)
	signLbl.BackgroundTransparency = 1
	signLbl.Text = "MAPLEVIEW STADIUM LOBBY & TRAINING PITCH"
	signLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
	signLbl.TextStrokeTransparency = 0.2
	signLbl.Font = Enum.Font.GothamBlack
	signLbl.TextScaled = true
	signLbl.Parent = bb

	-- 3D Trophy Showcase in Lobby
	ModelFactory.BuildTrophy(lobby, center + Vector3.new(0, 0, -52), "CHAMPIONSHIP CUP")

	-- Lobby SpawnLocations (Neutral so everyone spawns in Lobby during intermission)
	for i = -1, 1 do
		local sp = Instance.new("SpawnLocation")
		sp.Name = "LobbySpawn_" .. i
		sp.Size = Vector3.new(8, 0.5, 8)
		sp.CFrame = CFrame.lookAt(center + Vector3.new(i * 12, 0.3, -60), center + Vector3.new(0, 0.3, 0))
		sp.Anchored = true
		sp.CanCollide = false
		sp.Transparency = 1
		sp.Duration = 0
		sp.Neutral = true
		sp.Parent = lobby
	end

	-- Practice Training Pitch inside the Lobby
	local trainCenter = center + Vector3.new(0, 0, 22)
	local trainL = 96
	local trainW = 76
	for i = 1, 6 do
		local z = trainCenter.Z - trainL * 0.5 + (i - 0.5) * (trainL / 6)
		makePart({
			Name = "TrainTurf_" .. i,
			Size = Vector3.new(trainW, 0.4, trainL / 6),
			CFrame = CFrame.new(trainCenter.X, 0.1, z),
			Color = if i % 2 == 0 then Color3.fromRGB(34, 139, 64) else Color3.fromRGB(40, 156, 72),
			Material = Enum.Material.Grass,
			Parent = lobby,
		})
	end

	-- Training Pitch Lines
	local ty = 0.32
	buildLine(lobby, "TrainLineL", Vector3.new(trainCenter.X - trainW * 0.5, ty, trainCenter.Z - trainL * 0.5), Vector3.new(trainCenter.X - trainW * 0.5, ty, trainCenter.Z + trainL * 0.5), 0.5)
	buildLine(lobby, "TrainLineR", Vector3.new(trainCenter.X + trainW * 0.5, ty, trainCenter.Z - trainL * 0.5), Vector3.new(trainCenter.X + trainW * 0.5, ty, trainCenter.Z + trainL * 0.5), 0.5)
	buildLine(lobby, "TrainGoalLine", Vector3.new(trainCenter.X - trainW * 0.5, ty, trainCenter.Z + trainL * 0.5), Vector3.new(trainCenter.X + trainW * 0.5, ty, trainCenter.Z + trainL * 0.5), 0.5)

	-- Training Goal at +Z end of Training Pitch
	buildGoal(lobby, "TrainingGoal", Vector3.new(trainCenter.X, 0.3, trainCenter.Z + trainL * 0.5), 1, 24, 9.5)

	-- Glowing Target Rings inside Training Goal
	for _, xOff in ipairs({ -7.5, 0, 7.5 }) do
		makePart({
			Name = "TargetRing_" .. xOff,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 3.6, 3.6),
			CFrame = CFrame.new(trainCenter.X + xOff, 6.2, trainCenter.Z + trainL * 0.5 + 1) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(250, 204, 21),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = lobby,
		})
	end

	-- 3 Practice Soccer Balls (unanchored physical balls players can dribble & shoot in the lobby!)
	for i = -1, 1 do
		local pBall = Instance.new("Part")
		pBall.Name = "TrainingBall_" .. (i + 2)
		pBall.Shape = Enum.PartType.Ball
		pBall.Size = Vector3.one * (Config.Ball.Radius * 2)
		pBall.Position = trainCenter + Vector3.new(i * 12, Config.Ball.Radius + 0.5, -18)
		pBall.Color = Color3.fromRGB(248, 250, 252)
		pBall.Material = Enum.Material.SmoothPlastic
		pBall.Anchored = false
		pBall.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.3, 0.65, 1, 1)
		pBall:SetAttribute("IsTrainingBall", true)
		pBall.Parent = lobby
	end
end

function StadiumBuilder.Build(mode: Config.MatchMode, themeId: Config.StadiumThemeId?)
	local themeKey = themeId or Config.DefaultStadium
	local themeCfg = (Config.StadiumThemes :: any)[themeKey] or Config.StadiumThemes.WembleyNight
	setupAtmosphere(themeCfg)

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
		Size = Vector3.new(modeCfg.PitchWidth + 140, 4, modeCfg.PitchLength + 140),
		CFrame = CFrame.new(0, -2.1, 0),
		Color = Color3.fromRGB(35, 42, 54),
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
			Color = if isEven then themeCfg.TurfA else themeCfg.TurfB,
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

	buildLine(linesFolder, "NorthGoalLine", Vector3.new(-halfW, y, -halfL), Vector3.new(halfW, y, -halfL), lw)
	buildLine(linesFolder, "SouthGoalLine", Vector3.new(-halfW, y, halfL), Vector3.new(halfW, y, halfL), lw)
	buildLine(linesFolder, "WestTouchline", Vector3.new(-halfW, y, -halfL), Vector3.new(-halfW, y, halfL), lw)
	buildLine(linesFolder, "EastTouchline", Vector3.new(halfW, y, -halfL), Vector3.new(halfW, y, halfL), lw)
	buildLine(linesFolder, "HalfwayLine", Vector3.new(-halfW, y, 0), Vector3.new(halfW, y, 0), lw)
	buildCircle(linesFolder, Vector3.new(0, y, 0), 22, 32, lw)

	makePart({
		Name = "CenterSpot",
		Size = Vector3.new(1.8, 0.08, 1.8),
		CFrame = CFrame.new(0, y, 0),
		Color = Color3.fromRGB(245, 248, 252),
		CanCollide = false,
		Parent = linesFolder,
	})

	local boxDepth = Config.Kicks.GKBoxDepth
	local boxHalfW = Config.Kicks.GKBoxWidth * 0.5
	for _, endSign in ipairs({ -1, 1 }) do
		local goalZ = endSign * halfL
		local boxZ = goalZ - endSign * boxDepth
		buildLine(linesFolder, "BoxFront_" .. endSign, Vector3.new(-boxHalfW, y, boxZ), Vector3.new(boxHalfW, y, boxZ), lw)
		buildLine(linesFolder, "BoxLeft_" .. endSign, Vector3.new(-boxHalfW, y, goalZ), Vector3.new(-boxHalfW, y, boxZ), lw)
		buildLine(linesFolder, "BoxRight_" .. endSign, Vector3.new(boxHalfW, y, goalZ), Vector3.new(boxHalfW, y, boxZ), lw)

		makePart({
			Name = "PenaltySpot_" .. endSign,
			Size = Vector3.new(1.6, 0.08, 1.6),
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

	-- Goals
	buildGoal(stadium, "HomeGoal", Vector3.new(0, 0, -halfL), -1, modeCfg.GoalWidth, modeCfg.GoalHeight)
	buildGoal(stadium, "AwayGoal", Vector3.new(0, 0, halfL), 1, modeCfg.GoalWidth, modeCfg.GoalHeight)

	-- Stands, Roofs, 3D Fans, Dugouts & Floodlights
	buildStandsRoofAndFans(stadium, halfL, halfW, themeCfg)

	-- Lobby & Training Pitch
	buildLobby(stadium)
end

return StadiumBuilder
