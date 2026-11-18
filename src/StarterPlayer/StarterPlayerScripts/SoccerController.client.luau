--!strict
-- SoccerController.client.luau
-- Client input, stamina/sprint, hold-to-charge curving shots, pinpoint through-balls, GK dives, and tackles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local stamina = Config.Stamina.Max
local isSprinting = false
local chargingKick: string? = nil
local chargePower = 0
local curveAmount = 0
local lastTackleTime = 0
local lastDiveTime = 0
local currentMode: Config.MatchMode = Config.DefaultMode
local ballOwnerId = 0

-- Trajectory preview dots for curving free kicks & shots
local previewFolder = Instance.new("Folder")
previewFolder.Name = "TrajectoryPreview"
previewFolder.Parent = Workspace

local previewDots: { Part } = {}
for i = 1, 16 do
	local dot = Instance.new("Part")
	dot.Name = "Dot_" .. i
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.one * (0.45 - i * 0.018)
	dot.Color = Color3.fromRGB(250, 204, 21)
	dot.Material = Enum.Material.Neon
	dot.Anchored = true
	dot.CanCollide = false
	dot.Transparency = 1
	dot.Parent = previewFolder
	previewDots[i] = dot
end

local function hidePreview()
	for _, dot in ipairs(previewDots) do
		dot.Transparency = 1
	end
end

-- Listen for ball owner & match mode updates
Network.GetEvent("BallStateUpdate").OnClientEvent:Connect(function(_pos, _vel, _spin, ownerId: number)
	ballOwnerId = ownerId
end)

Network.GetEvent("MatchStateUpdate").OnClientEvent:Connect(function(state)
	if state and state.Mode then
		currentMode = state.Mode
	end
end)

local function getHRP(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function findThroughBallTarget(hrp: BasePart, camDir: Vector3): Vector3
	local bestScore = -math.huge
	local bestDir = camDir
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Team == player.Team and other.Character then
			local oHrp = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if oHrp then
				local toMate = oHrp.Position - hrp.Position
				local dist = toMate.Magnitude
				if dist > 8 and dist < 140 then
					local align = toMate.Unit:Dot(camDir)
					if align > 0.35 then
						-- Lead the pass ahead of teammate's velocity
						local leadPos = oHrp.Position + oHrp.AssemblyLinearVelocity * 0.65
						local score = align * 100 - dist * 0.25
						if score > bestScore then
							bestScore = score
							bestDir = (leadPos - hrp.Position).Unit
						end
					end
				end
			end
		end
	end
	return Vector3.new(bestDir.X, 0, bestDir.Z).Unit
end

local function getAimDirection(): Vector3
	local hrp = getHRP()
	if not hrp or not camera then
		return Vector3.new(0, 0, 1)
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return hrp.CFrame.LookVector
	end
	return flat.Unit
end

local function releaseKick()
	if not chargingKick then
		return
	end
	local kickType = chargingKick
	chargingKick = nil
	hidePreview()

	local hrp = getHRP()
	if not hrp then
		return
	end

	local dir = getAimDirection()
	if kickType == "ThroughBall" then
		dir = findThroughBallTarget(hrp, dir)
	end

	Network.GetEvent("KickRequest"):FireServer(kickType, dir, math.clamp(chargePower, 0.15, 1), curveAmount)
	chargePower = 0
	curveAmount = 0
	player:SetAttribute("KickCharge", 0)
	player:SetAttribute("KickCurve", 0)
end

-- Input Handling
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.E then
		chargingKick = "Shoot"
		chargePower = 0.15
		curveAmount = 0
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q then
		chargingKick = "Lob"
		chargePower = 0.15
		curveAmount = 0
	elseif input.KeyCode == Enum.KeyCode.F then
		chargingKick = "ThroughBall"
		chargePower = 0.2
		curveAmount = 0
	elseif input.KeyCode == Enum.KeyCode.R then
		if os.clock() - lastTackleTime >= Config.Kicks.TackleCooldown then
			lastTackleTime = os.clock()
			local hrp = getHRP()
			if hrp then
				hrp.AssemblyLinearVelocity = hrp.CFrame.LookVector * Config.Kicks.TackleImpulse + Vector3.new(0, 8, 0)
				Network.GetEvent("TackleRequest"):FireServer()
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Space then
		-- Goalkeeper Dive if inside either penalty box
		local hrp = getHRP()
		if hrp and os.clock() - lastDiveTime >= Config.Kicks.DiveCooldown then
			local modeCfg = Config.MatchModes[currentMode]
			local halfL = modeCfg.PitchLength * 0.5
			local inBox = math.abs(hrp.Position.Z) >= (halfL - Config.Kicks.GKBoxDepth)
				and math.abs(hrp.Position.X) <= (Config.Kicks.GKBoxWidth * 0.5)
			if inBox then
				lastDiveTime = os.clock()
				local hum = getHumanoid()
				local moveDir = if hum and hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection.Unit else getAimDirection()
				hrp.AssemblyLinearVelocity = moveDir * Config.Kicks.DiveSpeed + Vector3.new(0, Config.Kicks.DiveUpward, 0)
				Network.GetEvent("GKDiveRequest"):FireServer(moveDir)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.G then
		Network.GetEvent("CelebrationTrigger"):FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
	elseif
		(input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.E)
		and chargingKick == "Shoot"
	then
		releaseKick()
	elseif
		(input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q)
		and chargingKick == "Lob"
	then
		releaseKick()
	elseif input.KeyCode == Enum.KeyCode.F and chargingKick == "ThroughBall" then
		releaseKick()
	end
end)

-- Frame Loop: Stamina, Speed, Kick Charge, and Live Curve Trajectory Preview
RunService.RenderStepped:Connect(function(dt: number)
	local hum = getHumanoid()
	local hasBall = (ballOwnerId == player.UserId)

	if hum then
		if isSprinting and hum.MoveDirection.Magnitude > 0.1 and stamina > 2 then
			stamina = math.max(0, stamina - Config.Stamina.SprintDrainPerSec * dt)
			hum.WalkSpeed = if hasBall then Config.Stamina.DribbleSprintSpeed else Config.Stamina.SprintSpeed
		else
			stamina = math.min(Config.Stamina.Max, stamina + Config.Stamina.RegenPerSec * dt)
			hum.WalkSpeed = if hasBall then Config.Stamina.DribbleWalkSpeed else Config.Stamina.BaseWalkSpeed
		end
	end
	player:SetAttribute("Stamina", stamina)

	if chargingKick then
		chargePower = math.min(1, chargePower + Config.Kicks.ChargeRate * dt)

		-- Adjust curve spin with A / D keys while charging
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			curveAmount = math.max(-1, curveAmount - 2.2 * dt)
		elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
			curveAmount = math.min(1, curveAmount + 2.2 * dt)
		end

		player:SetAttribute("KickCharge", chargePower)
		player:SetAttribute("KickCurve", curveAmount)

		-- Render live curved trajectory preview from ball position
		local ball = Workspace:FindFirstChild("SoccerBall") :: BasePart?
		local hrp = getHRP()
		if ball and hrp and (ball.Position - hrp.Position).Magnitude < 12 then
			local dir = getAimDirection()
			if chargingKick == "ThroughBall" then
				dir = findThroughBallTarget(hrp, dir)
			end
			local maxS = if chargingKick == "Lob"
				then Config.Kicks.MaxLobPower
				elseif chargingKick == "ThroughBall" then Config.Kicks.MaxThroughBallPower
				else Config.Kicks.MaxShotPower
			local speed = Config.Kicks.MinPower + (maxS - Config.Kicks.MinPower) * chargePower
			local loft = if chargingKick == "Lob" then (0.55 + 0.2 * chargePower) else (0.22 + 0.18 * chargePower)
			local launchVel = Vector3.new(dir.X, loft, dir.Z).Unit * speed
			local spin = Vector3.new(0, curveAmount * Config.Kicks.MaxSpin * (0.4 + 0.6 * chargePower), 0)

			local modeCfg = Config.MatchModes[currentMode]
			local pts = BallPhysics.PredictTrajectory(
				ball.Position,
				launchVel,
				spin,
				#previewDots,
				0.06,
				modeCfg.PitchLength * 0.5,
				modeCfg.PitchWidth * 0.5
			)
			for i, pt in ipairs(pts) do
				previewDots[i].Position = pt
				previewDots[i].Transparency = 0.25 + (i / #previewDots) * 0.55
			end
		else
			hidePreview()
		end
	end
end)
