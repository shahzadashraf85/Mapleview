--!strict
-- VFXController.client.luau
-- Stadium atmosphere, ball speed/curve trail, goal fireworks/confetti, and trophy ceremony FX.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.Shared.Network)

local trailAttached = false
local ballTrail: Trail? = nil

local function attachBallVFX()
	local ball = Workspace:FindFirstChild("SoccerBall")
	if not ball or not ball:IsA("BasePart") or trailAttached then
		return
	end
	trailAttached = true

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.7, 0)
	a0.Parent = ball

	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.7, 0)
	a1.Parent = ball

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.MinLength = 0.2
	trail.Color = ColorSequence.new(Color3.fromRGB(250, 204, 21), Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Enabled = false
	trail.Parent = ball
	ballTrail = trail
end

Network.GetEvent("BallStateUpdate").OnClientEvent:Connect(function(_pos, vel: Vector3, spin: Vector3)
	attachBallVFX()
	if ballTrail then
		local fast = vel.Magnitude > 52
		ballTrail.Enabled = fast
		if spin.Magnitude > 5 then
			ballTrail.Color = ColorSequence.new(Color3.fromRGB(56, 189, 248), Color3.fromRGB(250, 204, 21))
		else
			ballTrail.Color = ColorSequence.new(Color3.fromRGB(250, 204, 21), Color3.fromRGB(255, 255, 255))
		end
	end
end)

local function burstConfetti(position: Vector3, count: number)
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.one
	emitterPart.Position = position
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = Workspace

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 204, 21)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 189, 248)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 68, 68)),
	})
	pe.Size = NumberSequence.new(0.65)
	pe.Speed = NumberRange.new(25, 55)
	pe.SpreadAngle = Vector2.new(65, 65)
	pe.Lifetime = NumberRange.new(2.2, 3.5)
	pe.Acceleration = Vector3.new(0, -24, 0)
	pe.Rate = 0
	pe.Parent = emitterPart
	pe:Emit(count)

	task.delay(4, function()
		emitterPart:Destroy()
	end)
end

Network.GetEvent("GoalScoredVFX").OnClientEvent:Connect(function()
	local ball = Workspace:FindFirstChild("SoccerBall")
	if ball and ball:IsA("BasePart") then
		burstConfetti(ball.Position + Vector3.new(0, 3, 0), 90)
	end
end)

Network.GetEvent("TrophyCeremonyStart").OnClientEvent:Connect(function()
	for i = 1, 5 do
		task.delay((i - 1) * 1.2, function()
			burstConfetti(Vector3.new(0, 12, 0), 120)
			burstConfetti(Vector3.new(-15, 10, 0), 70)
			burstConfetti(Vector3.new(15, 10, 0), 70)
		end)
	end
end)
