--!strict
-- GoalkeeperAI.luau
-- Controls 3D AI Goalkeepers in both goals to track the ball, dive for shots, and make saves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFactory = require(script.Parent.ModelFactory)

local GoalkeeperAI = {}

type KeeperState = {
	Model: Model?,
	Side: "Home" | "Away",
	Pos: Vector3,
	DiveTimer: number,
	DiveOffset: Vector3,
	SaveCooldown: number,
}

local homeGK: KeeperState = {
	Model = nil,
	Side = "Home",
	Pos = Vector3.new(0, 0, -106),
	DiveTimer = 0,
	DiveOffset = Vector3.zero,
	SaveCooldown = 0,
}

local awayGK: KeeperState = {
	Model = nil,
	Side = "Away",
	Pos = Vector3.new(0, 0, 106),
	DiveTimer = 0,
	DiveOffset = Vector3.zero,
	SaveCooldown = 0,
}

local function ensureKeepers(mode: Config.MatchMode)
	local stadium = Workspace:FindFirstChild("Stadium")
	if not stadium then
		return
	end
	local halfL = Config.MatchModes[mode].PitchLength * 0.5

	if not homeGK.Model or not homeGK.Model.Parent then
		homeGK.Pos = Vector3.new(0, 0, -halfL + 3.5)
		homeGK.Model = ModelFactory.BuildGoalkeeper(stadium, "HomeGoalkeeper", homeGK.Pos, Vector3.new(0, 0, 0), Color3.fromRGB(250, 204, 21))
	end
	if not awayGK.Model or not awayGK.Model.Parent then
		awayGK.Pos = Vector3.new(0, 0, halfL - 3.5)
		awayGK.Model = ModelFactory.BuildGoalkeeper(stadium, "AwayGoalkeeper", awayGK.Pos, Vector3.new(0, 0, 0), Color3.fromRGB(16, 185, 129))
	end
end

function GoalkeeperAI.Rebuild(mode: Config.MatchMode)
	if homeGK.Model then
		homeGK.Model:Destroy()
		homeGK.Model = nil
	end
	if awayGK.Model then
		awayGK.Model:Destroy()
		awayGK.Model = nil
	end
	ensureKeepers(mode)
end

-- Returns (saved: boolean, clearVelocity: Vector3?)
function GoalkeeperAI.Step(dt: number, ballPos: Vector3, ballVel: Vector3, mode: Config.MatchMode): (boolean, Vector3?)
	ensureKeepers(mode)

	local modeCfg = Config.MatchModes[mode]
	local halfL = modeCfg.PitchLength * 0.5
	local maxSlideX = modeCfg.GoalWidth * 0.5 - 2.0

	local savedAny = false
	local clearVel: Vector3? = nil

	for _, gk in ipairs({ homeGK, awayGK }) do
		local isHome = (gk.Side == "Home")
		local baseZ = if isHome then (-halfL + 3.5) else (halfL - 3.5)
		local forwardZ = if isHome then 1 else -1

		gk.SaveCooldown = math.max(0, gk.SaveCooldown - dt)

		-- Track ball X position smoothly
		local targetX = math.clamp(ballPos.X, -maxSlideX, maxSlideX)
		local moveSpeed = 16
		local newX = gk.Pos.X + (targetX - gk.Pos.X) * math.clamp(dt * moveSpeed * 0.35, 0, 1)

		-- Trigger dive if a fast shot is heading toward this goal
		local headingToGoal = (isHome and ballVel.Z < -18 and ballPos.Z < -halfL * 0.25)
			or ((not isHome) and ballVel.Z > 18 and ballPos.Z > halfL * 0.25)
		if headingToGoal and gk.DiveTimer <= 0 and (ballPos - gk.Pos).Magnitude < 48 then
			gk.DiveTimer = 0.65
			local diveX = math.clamp(ballPos.X - gk.Pos.X, -6, 6)
			local diveY = math.clamp(ballPos.Y - 2.5, 0, 3.8)
			gk.DiveOffset = Vector3.new(diveX * 0.5, diveY, 0)
		end

		if gk.DiveTimer > 0 then
			gk.DiveTimer -= dt
		else
			gk.DiveOffset = gk.DiveOffset:Lerp(Vector3.zero, math.clamp(dt * 8, 0, 1))
		end

		gk.Pos = Vector3.new(newX, 0, baseZ)
		local displayPos = gk.Pos + gk.DiveOffset

		if gk.Model and gk.Model.PrimaryPart then
			local lookTarget = Vector3.new(ballPos.X, displayPos.Y + 3.2, ballPos.Z)
			if (lookTarget - (displayPos + Vector3.new(0, 3.2, 0))).Magnitude < 0.1 then
				lookTarget = displayPos + Vector3.new(0, 3.2, forwardZ * 10)
			end
			local targetCF = CFrame.lookAt(displayPos + Vector3.new(0, 3.2, 0), lookTarget)
			local currentPivot = gk.Model:GetPivot()
			local delta = targetCF * currentPivot:Inverse()
			-- Move all parts cleanly
			gk.Model:PivotTo(targetCF)
		end

		-- Save collision check
		local keeperCenter = displayPos + Vector3.new(0, 3.2, 0)
		if gk.SaveCooldown <= 0 and (ballPos - keeperCenter).Magnitude <= 4.6 and ballVel.Magnitude > 12 then
			gk.SaveCooldown = 0.75
			savedAny = true
			local outDir = Vector3.new((ballPos.X - keeperCenter.X) * 0.4, 0.32, forwardZ).Unit
			clearVel = outDir * 56
		end
	end

	return savedAny, clearVel
end

return GoalkeeperAI
