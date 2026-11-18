--!strict
-- KitAndCelebrationService.luau
-- Applies custom kits to player characters and executes procedural goal celebrations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Network = require(ReplicatedStorage.Shared.Network)

local KitAndCelebrationService = {}

local getProfileFn: ((Player) -> any)? = nil

function KitAndCelebrationService.ApplyKit(player: Player)
	local character = player.Character
	if not character or not getProfileFn then
		return
	end
	local prof = getProfileFn(player)
	local kit = Catalog.GetKit(prof.EquippedKit) or Catalog.Kits[1]

	-- Determine team tint for shorts/trim if on a team
	local teamAccent = kit.Secondary
	if player.Team then
		teamAccent = player.Team.TeamColor.Color
	end

	-- Remove existing Shirt/Pants so kit colors show crisply on any rig
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local n = part.Name
			if n == "Torso" or n == "UpperTorso" or n == "LowerTorso" then
				part.Color = kit.Primary
			elseif string.find(n, "Arm") or string.find(n, "Hand") then
				-- Keep sleeves matching primary kit
				if string.find(n, "UpperArm") then
					part.Color = kit.Primary
				end
			elseif string.find(n, "Leg") or n == "LeftUpperLeg" or n == "RightUpperLeg" then
				part.Color = kit.Secondary
			elseif string.find(n, "Foot") then
				part.Color = kit.Accent
			end
		end
	end

	-- Overhead Club & Kit Nameplate
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local old = head:FindFirstChild("PlayerTag")
		if old then
			old:Destroy()
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "PlayerTag"
		bb.Size = UDim2.fromOffset(160, 44)
		bb.StudsOffset = Vector3.new(0, 2.8, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 90
		bb.Parent = head

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = player.DisplayName
		nameLbl.TextColor3 = Color3.new(1, 1, 1)
		nameLbl.TextStrokeTransparency = 0.25
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextScaled = true
		nameLbl.Parent = bb

		local clubLbl = Instance.new("TextLabel")
		clubLbl.Size = UDim2.new(1, 0, 0.45, 0)
		clubLbl.Position = UDim2.fromScale(0, 0.55)
		clubLbl.BackgroundTransparency = 1
		clubLbl.Text = string.upper(prof.ClubName or "CLUB")
		clubLbl.TextColor3 = teamAccent
		clubLbl.TextStrokeTransparency = 0.35
		clubLbl.Font = Enum.Font.GothamSemibold
		clubLbl.TextScaled = true
		clubLbl.Parent = bb
	end
end

function KitAndCelebrationService.PlayCelebration(player: Player)
	local character = player.Character
	if not character or not getProfileFn then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end

	local prof = getProfileFn(player)
	local celId = prof.EquippedCelebration or "knee_slide"

	-- Broadcast celebration VFX to all clients
	Network.GetEvent("CelebrationTrigger"):FireAllClients(player, celId)

	task.spawn(function()
		if celId == "knee_slide" then
			local forward = hrp.CFrame.LookVector
			hrp.AssemblyLinearVelocity = forward * 52 + Vector3.new(0, 8, 0)
			humanoid.Sit = true
			task.wait(1.6)
			humanoid.Sit = false
		elseif celId == "siuuu_leap" then
			hrp.AssemblyLinearVelocity = Vector3.new(0, 46, 0) + hrp.CFrame.LookVector * 12
			local startCF = hrp.CFrame
			for i = 1, 12 do
				task.wait(0.04)
				if hrp.Parent then
					hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(15), 0)
				end
			end
			task.wait(0.3)
			if hrp.Parent then
				hrp.CFrame = CFrame.new(hrp.Position) * startCF.Rotation * CFrame.Angles(0, math.pi, 0)
			end
		elseif celId == "backflip" then
			hrp.AssemblyLinearVelocity = Vector3.new(0, 52, 0) - hrp.CFrame.LookVector * 8
			for i = 1, 18 do
				task.wait(0.035)
				if hrp.Parent then
					hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(20), 0, 0)
				end
			end
		elseif celId == "trophy_lift" then
			-- Spawn a temporary golden mini-cup above player's hands
			local cup = Instance.new("Part")
			cup.Name = "CelebrationCup"
			cup.Shape = Enum.PartType.Cylinder
			cup.Size = Vector3.new(2.4, 1.4, 1.4)
			cup.Color = Color3.fromRGB(250, 204, 21)
			cup.Material = Enum.Material.Neon
			cup.CanCollide = false
			cup.Anchored = true
			cup.Parent = workspace

			local t0 = os.clock()
			while os.clock() - t0 < 2.5 and hrp.Parent do
				cup.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4.5 + math.sin(os.clock() * 6) * 0.3, 0))
					* CFrame.Angles(0, os.clock() * 3, math.rad(90))
				task.wait()
			end
			cup:Destroy()
		end
	end)
end

function KitAndCelebrationService.Init(profileGetter: (Player) -> any)
	getProfileFn = profileGetter

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.15)
			KitAndCelebrationService.ApplyKit(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(KitAndCelebrationService.ApplyKit, player)
		end
	end

	Network.GetEvent("CelebrationTrigger").OnServerEvent:Connect(function(player)
		KitAndCelebrationService.PlayCelebration(player)
	end)
end

return KitAndCelebrationService
