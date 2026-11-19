--!strict
-- RagdollService.luau
-- Converts R15/R6 Motor6D joints into BallSocketConstraints for hilarious physics ragdolling and restores them cleanly.

local Players = game:GetService("Players")

local RagdollService = {}

local activeRagdolls: { [Model]: number } = {}

local function setMotorsEnabled(character: Model, enabled: boolean)
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") then
			desc.Enabled = enabled
		elseif desc:IsA("BallSocketConstraint") and desc.Name == "RagdollSocket" then
			desc.Enabled = not enabled
		elseif desc:IsA("NoCollisionConstraint") and desc.Name == "RagdollNoCollide" then
			desc.Enabled = not enabled
		end
	end
end

local function buildRagdollSockets(character: Model)
	if character:GetAttribute("RagdollBuilt") then
		return
	end
	character:SetAttribute("RagdollBuilt", true)

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part0 and desc.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollAtt0"
			a0.CFrame = desc.C0
			a0.Parent = desc.Part0

			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollAtt1"
			a1.CFrame = desc.C1
			a1.Parent = desc.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.UpperAngle = 65
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Enabled = false
			socket.Parent = desc.Part0

			local noCol = Instance.new("NoCollisionConstraint")
			noCol.Name = "RagdollNoCollide"
			noCol.Part0 = desc.Part0
			noCol.Part1 = desc.Part1
			noCol.Enabled = false
			noCol.Parent = desc.Part0
		end
	end
end

function RagdollService.IsRagdolled(character: Model): boolean
	local endT = activeRagdolls[character]
	return endT ~= nil and os.clock() < endT
end

function RagdollService.Ragdoll(character: Model, duration: number, impulse: Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp or humanoid.Health <= 0 then
		return
	end

	buildRagdollSockets(character)

	local wasRagdolled = RagdollService.IsRagdolled(character)
	activeRagdolls[character] = os.clock() + duration

	if not wasRagdolled then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		setMotorsEnabled(character, false)
	end

	if impulse and impulse.Magnitude > 0.1 then
		hrp.AssemblyLinearVelocity = impulse
		hrp.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 14,
			(math.random() - 0.5) * 14,
			(math.random() - 0.5) * 14
		)
	end

	task.delay(duration, function()
		local endT = activeRagdolls[character]
		if endT and os.clock() >= endT - 0.05 and character.Parent then
			activeRagdolls[character] = nil
			setMotorsEnabled(character, true)
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.PlatformStand = false
				humanoid.AutoRotate = true
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end)
end

function RagdollService.Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.25)
			buildRagdollSockets(char)
		end)
	end)
end

return RagdollService
