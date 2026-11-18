--!strict
-- SoccerController.client.luau
-- Click-to-target aiming (no dotted line!), power charging, curve spin, through-balls, GK dives, tackles, and lobby training pitch kicks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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

-- 3D Click Target Ring (replaces dotted line!)
local targetMarker = Instance.new("Part")
targetMarker.Name = "ClickTargetMarker"
targetMarker.Shape = Enum.PartType.Cylinder
targetMarker.Size = Vector3.new(0.25, 4.2, 4.2)
targetMarker.Color = Color3.fromRGB(250, 204, 21)
targetMarker.Material = Enum.Material.Neon
targetMarker.Anchored = true
targetMarker.CanCollide = false
targetMarker.Transparency = 1
targetMarker.Parent = Workspace

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

local function getMouseWorldTarget(): Vector3?
	if not camera then
		return nil
	end
	local mouseLoc = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excludes: { Instance } = { targetMarker }
	if player.Character then
		table.insert(excludes, player.Character)
	end
	params.FilterDescendantsInstances = excludes

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 450, params)
	if result then
		return result.Position
	end
	return unitRay.Origin + unitRay.Direction * 120
end

local function findNearbyTrainingBall(hrp: BasePart): BasePart?
	local lobby = Workspace:FindFirstChild("Stadium") and Workspace.Stadium:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end
	local closest: BasePart? = nil
	local bestDist = 13
	for _, child in ipairs(lobby:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("IsTrainingBall") then
			local d = (child.Position - hrp.Position).Magnitude
			if d < bestDist then
				bestDist = d
				closest = child
			end
		end
	end
	return closest
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
	targetMarker.Transparency = 1

	local hrp = getHRP()
	if not hrp then
		return
	end

	local clickedTarget = getMouseWorldTarget()
	local pwr = math.clamp(chargePower, 0.15, 1)

	-- Check if player is kicking a Lobby Training Ball
	local trainBall = findNearbyTrainingBall(hrp)
	local matchBall = Workspace:FindFirstChild("SoccerBall") :: BasePart?
	local matchDist = if matchBall then (matchBall.Position - hrp.Position).Magnitude else math.huge

	if trainBall and (not matchBall or (trainBall.Position - hrp.Position).Magnitude < matchDist) then
		local aimPt = clickedTarget or (hrp.Position + getAimDirection() * 60)
		Network.GetEvent("TrainingBallKick"):FireServer(trainBall, aimPt, pwr)
	else
		local dir = getAimDirection()
		if kickType == "ThroughBall" then
			dir = findThroughBallTarget(hrp, dir)
			clickedTarget = nil
		end
		Network.GetEvent("KickRequest"):FireServer(kickType, dir, pwr, curveAmount, clickedTarget)
	end

	chargePower = 0
	curveAmount = 0
	player:SetAttribute("KickCharge", 0)
	player:SetAttribute("KickCurve", 0)
end

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

		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			curveAmount = math.max(-1, curveAmount - 2.2 * dt)
		elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
			curveAmount = math.min(1, curveAmount + 2.2 * dt)
		end

		player:SetAttribute("KickCharge", chargePower)
		player:SetAttribute("KickCurve", curveAmount)

		-- Show glowing 3D target ring where the player is clicking/aiming (no dotted line!)
		local hitPos = getMouseWorldTarget()
		if hitPos then
			targetMarker.CFrame = CFrame.new(hitPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			targetMarker.Color = if chargePower > 0.8 then Color3.fromRGB(239, 68, 68) else Color3.fromRGB(250, 204, 21)
			targetMarker.Transparency = 0.25
		else
			targetMarker.Transparency = 1
		end
	end
end)
