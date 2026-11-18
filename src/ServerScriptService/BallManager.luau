--!strict
-- BallManager.luau
-- Server-authoritative soccer ball simulation, click-to-target kicks, AI Goalkeepers, training balls, and goal detection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)
local GoalkeeperAI = require(script.Parent.GoalkeeperAI)

local BallManager = {}

local ballPart: Part? = nil
local ballState: BallPhysics.BallState = {
	Position = Vector3.new(0, Config.Ball.Radius, 0),
	Velocity = Vector3.zero,
	Spin = Vector3.zero,
}

local currentMode: Config.MatchMode = Config.DefaultMode
local matchPlaying = false
local ballFrozen = false

local ownerPlayer: Player? = nil
local lastTouchPlayer: Player? = nil
local previousTouchPlayer: Player? = nil
local stealCooldowns: { [number]: number } = {}
local divingPlayers: { [number]: number } = {}

local onGoalCallback: ((scoringTeam: "Home" | "Away", scorer: Player?, assister: Player?) -> ())? = nil
local onSaveCallback: ((keeper: Player) -> ())? = nil
local onAISaveCallback: (() -> ())? = nil
local onSetPieceCallback: ((kind: string, spot: Vector3, team: "Home" | "Away") -> ())? = nil

local function ensureBallPart(): Part
	if ballPart and ballPart.Parent then
		return ballPart
	end
	local existing = Workspace:FindFirstChild("SoccerBall")
	if existing and existing:IsA("Part") then
		ballPart = existing
		return existing
	end

	local p = Instance.new("Part")
	p.Name = "SoccerBall"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * (Config.Ball.Radius * 2)
	p.Color = Color3.fromRGB(248, 250, 252)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(250, 204, 21)
	highlight.OutlineTransparency = 0.65
	highlight.Parent = p

	p.Parent = Workspace
	ballPart = p
	return p
end

function BallManager.ResetToSpot(pos: Vector3, freeze: boolean)
	ownerPlayer = nil
	ballState = {
		Position = Vector3.new(pos.X, Config.Ball.Radius, pos.Z),
		Velocity = Vector3.zero,
		Spin = Vector3.zero,
	}
	ballFrozen = freeze
	local bp = ensureBallPart()
	bp.CFrame = CFrame.new(ballState.Position)
end

function BallManager.SetMatchActive(active: boolean, mode: Config.MatchMode)
	matchPlaying = active
	currentMode = mode
	if not active then
		ballFrozen = false
	end
end

function BallManager.GetBallPosition(): Vector3
	return ballState.Position
end

local function recordTouch(player: Player)
	if lastTouchPlayer ~= player then
		previousTouchPlayer = lastTouchPlayer
		lastTouchPlayer = player
	end
end

local function isInPenaltyBox(pos: Vector3, halfL: number): boolean
	local inZ = math.abs(pos.Z) >= (halfL - Config.Kicks.GKBoxDepth) and math.abs(pos.Z) <= halfL + 4
	local inX = math.abs(pos.X) <= (Config.Kicks.GKBoxWidth * 0.5)
	return inZ and inX
end

local function broadcastState()
	Network.GetEvent("BallStateUpdate"):FireAllClients(
		ballState.Position,
		ballState.Velocity,
		ballState.Spin,
		if ownerPlayer then ownerPlayer.UserId else 0
	)
end

function BallManager.Init(
	onGoal: (scoringTeam: "Home" | "Away", scorer: Player?, assister: Player?) -> (),
	onSave: (keeper: Player) -> (),
	onAISave: () -> (),
	onSetPiece: (kind: string, spot: Vector3, team: "Home" | "Away") -> ()
)
	onGoalCallback = onGoal
	onSaveCallback = onSave
	onAISaveCallback = onAISave
	onSetPieceCallback = onSetPiece

	ensureBallPart()
	BallManager.ResetToSpot(Vector3.zero, false)

	-- Kick / Pass / Through-Ball / Click-to-Target Shot
	Network.GetEvent("KickRequest").OnServerEvent:Connect(
		function(player: Player, kickType: string, direction: Vector3, powerRatio: number, curveAmount: number, targetPos: Vector3?)
			if typeof(direction) ~= "Vector3" or type(powerRatio) ~= "number" or type(curveAmount) ~= "number" then
				return
			end
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				return
			end

			local dist = (hrp.Position - ballState.Position).Magnitude
			if ownerPlayer ~= player and dist > 12 then
				return
			end

			local pwr = math.clamp(powerRatio, 0.1, 1)
			local curve = math.clamp(curveAmount, -1, 1)

			local speed = Config.Kicks.MinPower
			local loft = 0.18
			if kickType == "Shoot" or kickType == "FreeKick" then
				speed = Config.Kicks.MinPower + (Config.Kicks.MaxShotPower - Config.Kicks.MinPower) * pwr
				loft = 0.18 + 0.18 * pwr
			elseif kickType == "Lob" then
				speed = Config.Kicks.MinPower + (Config.Kicks.MaxLobPower - Config.Kicks.MinPower) * pwr
				loft = 0.52 + 0.2 * pwr
			elseif kickType == "ThroughBall" then
				speed = Config.Kicks.MinPower + (Config.Kicks.MaxThroughBallPower - Config.Kicks.MinPower) * pwr
				loft = 0.08
			else
				speed = Config.Kicks.MinPower + (Config.Kicks.MaxPassPower - Config.Kicks.MinPower) * pwr
				loft = 0.06
			end

			local launchDir: Vector3
			if typeof(targetPos) == "Vector3" then
				local toTarget = targetPos - ballState.Position
				local horizDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
				if horizDist > 0.5 then
					-- Aim directly at clicked point with subtle gravity compensation arc
					local heightDiff = math.clamp(targetPos.Y - ballState.Position.Y, -2, 18)
					local arcLift = math.clamp(horizDist * 0.0045 + heightDiff / math.max(horizDist, 8), 0.05, 0.55)
					local flat = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
					launchDir = Vector3.new(flat.X, arcLift, flat.Z).Unit
				else
					local dir = if direction.Magnitude > 0.01 then direction.Unit else hrp.CFrame.LookVector
					launchDir = Vector3.new(dir.X, loft, dir.Z).Unit
				end
			else
				local dir = if direction.Magnitude > 0.01 then direction.Unit else hrp.CFrame.LookVector
				launchDir = Vector3.new(dir.X, loft, dir.Z).Unit
			end

			ballState.Velocity = launchDir * speed
			ballState.Spin = Vector3.new(0, curve * Config.Kicks.MaxSpin * (0.4 + 0.6 * pwr), 0)

			ownerPlayer = nil
			ballFrozen = false
			stealCooldowns[player.UserId] = os.clock() + 0.35
			recordTouch(player)
			broadcastState()
		end
	)

	-- Lobby Training Pitch Ball Kick
	Network.GetEvent("TrainingBallKick").OnServerEvent:Connect(function(player: Player, ballInst: Instance, targetPos: Vector3, powerRatio: number)
		if typeof(ballInst) ~= "Instance" or not ballInst:IsA("BasePart") or not ballInst:GetAttribute("IsTrainingBall") then
			return
		end
		if typeof(targetPos) ~= "Vector3" or type(powerRatio) ~= "number" then
			return
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp or (hrp.Position - ballInst.Position).Magnitude > 14 then
			return
		end
		local toTarget = targetPos - ballInst.Position
		local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
		if flat.Magnitude < 0.2 then
			flat = hrp.CFrame.LookVector
		end
		local pwr = math.clamp(powerRatio, 0.2, 1)
		local speed = Config.Kicks.MinPower + (Config.Kicks.MaxShotPower - Config.Kicks.MinPower) * pwr
		local arc = math.clamp(flat.Magnitude * 0.005 + (targetPos.Y - ballInst.Position.Y) / math.max(flat.Magnitude, 8), 0.12, 0.5)
		ballInst.AssemblyLinearVelocity = Vector3.new(flat.Unit.X, arc, flat.Unit.Z).Unit * speed
	end)

	Network.GetEvent("DribbleToggle").OnServerEvent:Connect(function(player: Player)
		if ownerPlayer == player then
			ownerPlayer = nil
			stealCooldowns[player.UserId] = os.clock() + 0.4
			ballState.Velocity = Vector3.new(ballState.Velocity.X, 0, ballState.Velocity.Z) * 0.5
		end
	end)

	Network.GetEvent("TackleRequest").OnServerEvent:Connect(function(player: Player)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		if (hrp.Position - ballState.Position).Magnitude <= Config.Kicks.TackleRange then
			if ownerPlayer and ownerPlayer ~= player then
				stealCooldowns[ownerPlayer.UserId] = os.clock() + Config.Ball.StealCooldown
			end
			ownerPlayer = nil
			ballFrozen = false
			local pushDir = Vector3.new(hrp.CFrame.LookVector.X, 0.15, hrp.CFrame.LookVector.Z).Unit
			ballState.Velocity = pushDir * 42
			ballState.Spin = Vector3.zero
			recordTouch(player)
			broadcastState()
		end
	end)

	Network.GetEvent("GKDiveRequest").OnServerEvent:Connect(function(player: Player, _diveDir: Vector3)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local modeCfg = Config.MatchModes[currentMode]
		if isInPenaltyBox(hrp.Position, modeCfg.PitchLength * 0.5) then
			divingPlayers[player.UserId] = os.clock() + 0.65
		end
	end)

	local broadcastAccum = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local stepDt = math.min(dt, 0.05)
		local modeCfg = Config.MatchModes[currentMode]
		local halfL = modeCfg.PitchLength * 0.5
		local halfW = modeCfg.PitchWidth * 0.5
		local now = os.clock()

		if not ballFrozen then
			if ownerPlayer then
				local char = ownerPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum or hum.Health <= 0 then
					ownerPlayer = nil
				else
					local targetPos = hrp.Position + hrp.CFrame.LookVector * Config.Ball.DribbleDistance
					targetPos = Vector3.new(targetPos.X, Config.Ball.Radius, targetPos.Z)
					ballState.Position = ballState.Position:Lerp(targetPos, math.clamp(stepDt * 18, 0, 1))
					ballState.Velocity = hrp.AssemblyLinearVelocity
					ballState.Spin = Vector3.zero
				end
			else
				ballState = BallPhysics.Step(ballState, stepDt, halfL, halfW)

				-- AI Goalkeepers step & save check
				local aiSaved, clearVel = GoalkeeperAI.Step(stepDt, ballState.Position, ballState.Velocity, currentMode)
				if aiSaved and clearVel then
					ballState.Velocity = clearVel
					ballState.Spin = Vector3.zero
					if onAISaveCallback then
						onAISaveCallback()
					end
				end

				-- Player GK & Dribble pickup checks
				for _, player in ipairs(Players:GetPlayers()) do
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 then
						local dist = (hrp.Position - ballState.Position).Magnitude

						if divingPlayers[player.UserId] and now < divingPlayers[player.UserId] and dist <= 7.2 then
							if ballState.Velocity.Magnitude > 22 then
								divingPlayers[player.UserId] = nil
								local deflectDir = Vector3.new(hrp.CFrame.LookVector.X, 0.25, hrp.CFrame.LookVector.Z).Unit
								ballState.Velocity = deflectDir * 36
								ballState.Spin = Vector3.zero
								recordTouch(player)
								if onSaveCallback then
									onSaveCallback(player)
								end
								break
							end
						end

						local cd = stealCooldowns[player.UserId] or 0
						if now > cd and dist <= Config.Ball.DribbleSnapRange and ballState.Position.Y <= 4.0 and ballState.Velocity.Magnitude < 55 then
							ownerPlayer = player
							recordTouch(player)
							break
						end
					end
				end
			end

			if matchPlaying then
				local p = ballState.Position
				local halfGoalW = modeCfg.GoalWidth * 0.5

				if p.Z <= -halfL - Config.Ball.Radius * 0.5 and math.abs(p.X) <= halfGoalW and p.Y <= modeCfg.GoalHeight then
					matchPlaying = false
					ballFrozen = true
					local assister = if previousTouchPlayer and lastTouchPlayer and previousTouchPlayer.Team == lastTouchPlayer.Team then previousTouchPlayer else nil
					if onGoalCallback then
						onGoalCallback("Away", lastTouchPlayer, assister)
					end
				elseif p.Z >= halfL + Config.Ball.Radius * 0.5 and math.abs(p.X) <= halfGoalW and p.Y <= modeCfg.GoalHeight then
					matchPlaying = false
					ballFrozen = true
					local assister = if previousTouchPlayer and lastTouchPlayer and previousTouchPlayer.Team == lastTouchPlayer.Team then previousTouchPlayer else nil
					if onGoalCallback then
						onGoalCallback("Home", lastTouchPlayer, assister)
					end
				elseif math.abs(p.X) > halfW + 1.5 then
					ownerPlayer = nil
					local clampedZ = math.clamp(p.Z, -halfL + 5, halfL - 5)
					local spot = Vector3.new(math.sign(p.X) * (halfW - 1.5), Config.Ball.Radius, clampedZ)
					local kickingTeam: "Home" | "Away" = if lastTouchPlayer and lastTouchPlayer.Team and lastTouchPlayer.Team.Name == "Home FC" then "Away" else "Home"
					BallManager.ResetToSpot(spot, false)
					if onSetPieceCallback then
						onSetPieceCallback("Throw-In", spot, kickingTeam)
					end
				elseif math.abs(p.Z) > halfL + 2.0 and math.abs(p.X) > halfGoalW then
					ownerPlayer = nil
					local endSign = math.sign(p.Z)
					local spot = Vector3.new(math.sign(p.X) * (halfW - 2), Config.Ball.Radius, endSign * (halfL - 2))
					local kickingTeam: "Home" | "Away" = if endSign < 0 then "Home" else "Away"
					BallManager.ResetToSpot(spot, false)
					if onSetPieceCallback then
						onSetPieceCallback("Corner / Goal Kick", spot, kickingTeam)
					end
				end
			end
		end

		local bp = ensureBallPart()
		local speed = ballState.Velocity.Magnitude
		if speed > 0.5 then
			local rollAxis = Vector3.new(ballState.Velocity.Z, 0, -ballState.Velocity.X)
			if rollAxis.Magnitude > 0.01 then
				bp.CFrame = CFrame.new(ballState.Position) * (bp.CFrame.Rotation * CFrame.fromAxisAngle(rollAxis.Unit, speed * stepDt / Config.Ball.Radius))
			else
				bp.CFrame = CFrame.new(ballState.Position) * bp.CFrame.Rotation
			end
		else
			bp.CFrame = CFrame.new(ballState.Position) * bp.CFrame.Rotation
		end

		broadcastAccum += stepDt
		if broadcastAccum >= 0.05 then
			broadcastAccum = 0
			broadcastState()
		end
	end)
end

return BallManager
