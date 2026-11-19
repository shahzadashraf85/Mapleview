--!strict
-- VFXController.client.luau
-- Stadium atmosphere, ball curve trails, animated 3D cheering fans, goal confetti, and trophy ceremony fireworks.

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

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local function playSFX(soundId: string, volume: number, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function cameraShake(intensity: number, duration: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local decay = 1 - ((os.clock() - t0) / duration)
			local ox = (math.random() - 0.5) * intensity * decay
			local oy = (math.random() - 0.5) * intensity * decay
			cam.CFrame = cam.CFrame * CFrame.new(ox, oy, 0)
			task.wait()
		end
	end)
end

local function spawnShockwaveRing(pos: Vector3, color: Color3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, 3, 3)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = Workspace

	local tween = TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 16, 16),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
end

local lastShotFXTime = 0
Network.GetEvent("BallStateUpdate").OnClientEvent:Connect(function(pos: Vector3, vel: Vector3, spin: Vector3)
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

	-- Big Power Shot VFX & SFX
	if vel.Magnitude > 88 and os.clock() - lastShotFXTime > 0.6 then
		lastShotFXTime = os.clock()
		spawnShockwaveRing(pos, if spin.Magnitude > 5 then Color3.fromRGB(56, 189, 248) else Color3.fromRGB(250, 204, 21))
		playSFX("rbxassetid://131961136", 0.55, 0.9)
		cameraShake(0.35, 0.22)
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

-- Animate 3D Fans jumping in the stands on goal!
local function cheerFans()
	local stands = Workspace:FindFirstChild("Stadium") and Workspace.Stadium:FindFirstChild("Stands")
	if not stands then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 3.5 do
			local bounce = math.abs(math.sin((os.clock() - t0) * 9)) * 1.4
			for _, obj in ipairs(stands:GetChildren()) do
				if obj:IsA("BasePart") and obj:GetAttribute("IsFan") then
					local baseY = obj:GetAttribute("BaseY") :: number?
					if baseY then
						obj.Position = Vector3.new(obj.Position.X, baseY + bounce, obj.Position.Z)
					end
				end
			end
			task.wait(0.04)
		end
		for _, obj in ipairs(stands:GetChildren()) do
			if obj:IsA("BasePart") and obj:GetAttribute("IsFan") then
				local baseY = obj:GetAttribute("BaseY") :: number?
				if baseY then
					obj.Position = Vector3.new(obj.Position.X, baseY, obj.Position.Z)
				end
			end
		end
	end)
end

Network.GetEvent("GoalScoredVFX").OnClientEvent:Connect(function()
	local ball = Workspace:FindFirstChild("SoccerBall")
	if ball and ball:IsA("BasePart") then
		burstConfetti(ball.Position + Vector3.new(0, 3, 0), 90)
	end
	cheerFans()
end)

Network.GetEvent("TrophyCeremonyStart").OnClientEvent:Connect(function()
	cheerFans()
	for i = 1, 5 do
		task.delay((i - 1) * 1.2, function()
			burstConfetti(Vector3.new(0, 12, 0), 120)
			burstConfetti(Vector3.new(-15, 10, 0), 70)
			burstConfetti(Vector3.new(15, 10, 0), 70)
		end)
	end
end)

-- 3-Minute Disco Party Flashing Lights + Everyone Dancing
local discoActive = false
Network.GetEvent("DiscoPartyStart").OnClientEvent:Connect(function(duration: number, isConcert: boolean?)
	local dur = tonumber(duration) or 180

	if isConcert then
		task.spawn(function()
			local Players = game:GetService("Players")
			local lp = Players.LocalPlayer
			local t0 = os.clock()
			while os.clock() - t0 < dur do
				local char = lp.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum and hrp and hum.Health > 0 then
					-- Low-gravity disco bounce & spin dance!
					if hum.FloorMaterial ~= Enum.Material.Air then
						hum.Jump = true
					end
					hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(12), 0)
				end
				task.wait(0.28)
			end
		end)
	end

	if discoActive then
		return
	end
	discoActive = true

	local Lighting = game:GetService("Lighting")
	local origAmbient = Lighting.Ambient
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DiscoTint"
	cc.Saturation = 0.35
	cc.Parent = Lighting

	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local hue = ((os.clock() - t0) * 0.8) % 1
			local col = Color3.fromHSV(hue, 0.85, 1)
			cc.TintColor = col
			Lighting.Ambient = col
			task.wait(0.18)
		end
		cc:Destroy()
		Lighting.Ambient = origAmbient
		discoActive = false
	end)
end)
