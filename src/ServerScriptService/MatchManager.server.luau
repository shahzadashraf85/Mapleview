--!strict
-- MatchManager.server.luau
-- Orchestrates teams, 5v5 / 11v11 match modes, match clock, goals, set pieces, and the championship trophy ceremony.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)

local BallManager = require(script.Parent.BallManager)
local DataService = require(script.Parent.DataService)
local KitAndCelebrationService = require(script.Parent.KitAndCelebrationService)
local StadiumBuilder = require(script.Parent.StadiumBuilder)

-- 1. Initialize Remotes & Teams
Network.InitServer()

local function getOrCreateTeam(name: string, color: BrickColor): Team
	local existing = Teams:FindFirstChild(name)
	if existing and existing:IsA("Team") then
		return existing
	end
	local t = Instance.new("Team")
	t.Name = name
	t.TeamColor = color
	t.AutoAssignable = false
	t.Parent = Teams
	return t
end

local homeTeam = getOrCreateTeam(Config.Teams.Home.Name, Config.Teams.Home.Color)
local awayTeam = getOrCreateTeam(Config.Teams.Away.Name, Config.Teams.Away.Color)

-- 2. Initialize Services
DataService.Init(function(player)
	KitAndCelebrationService.ApplyKit(player)
end)
KitAndCelebrationService.Init(DataService.GetProfile)

-- 3. Match State
local currentMode: Config.MatchMode = Config.DefaultMode
local modeVotes: { [number]: Config.MatchMode } = {}

local matchPhase = "Intermission"
local halfNumber = 1
local timeRemaining = Config.IntermissionSeconds
local homeScore = 0
local awayScore = 0
local statusBanner = "Warmup — Next Match Starting Soon"
local goalScoredFlag = false

local function assignTeamBalanced(player: Player)
	local homeCount = #homeTeam:GetPlayers()
	local awayCount = #awayTeam:GetPlayers()
	player.Team = if homeCount <= awayCount then homeTeam else awayTeam
end

Players.PlayerAdded:Connect(function(player)
	assignTeamBalanced(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		KitAndCelebrationService.ApplyKit(player)
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	if not p.Team then
		assignTeamBalanced(p)
	end
end

-- Mode voting
Network.GetEvent("VoteMatchMode").OnServerEvent:Connect(function(player: Player, mode: string)
	if mode == "5v5" or mode == "11v11" then
		modeVotes[player.UserId] = mode :: Config.MatchMode
	end
end)

local function resolveModeVote(): Config.MatchMode
	local v5, v11 = 0, 0
	for _, m in pairs(modeVotes) do
		if m == "5v5" then
			v5 += 1
		else
			v11 += 1
		end
	end
	if v11 > v5 then
		return "11v11"
	end
	return "5v5"
end

local function broadcastMatchState()
	Network.GetEvent("MatchStateUpdate"):FireAllClients({
		Phase = matchPhase,
		Half = halfNumber,
		TimeRemaining = math.max(0, math.floor(timeRemaining)),
		HomeScore = homeScore,
		AwayScore = awayScore,
		Mode = currentMode,
		Status = statusBanner,
	})
end

local function positionPlayersForKickoff()
	local halfL = Config.MatchModes[currentMode].PitchLength * 0.5
	local homeIdx, awayIdx = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			if player.Team == homeTeam then
				homeIdx += 1
				local offsetX = ((homeIdx - 1) % 3 - 1) * 14
				local offsetZ = -18 - math.floor((homeIdx - 1) / 3) * 18
				hrp.CFrame = CFrame.lookAt(Vector3.new(offsetX, 3.5, math.max(offsetZ, -halfL + 10)), Vector3.new(0, 3.5, 0))
			else
				awayIdx += 1
				local offsetX = ((awayIdx - 1) % 3 - 1) * 14
				local offsetZ = 18 + math.floor((awayIdx - 1) / 3) * 18
				hrp.CFrame = CFrame.lookAt(Vector3.new(offsetX, 3.5, math.min(offsetZ, halfL - 10)), Vector3.new(0, 3.5, 0))
			end
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function spawnChampionshipTrophy(winningTeamName: string)
	local old = Workspace:FindFirstChild("ChampionshipTrophy")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "ChampionshipTrophy"

	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Size = Vector3.new(6, 2.5, 6)
	pedestal.Position = Vector3.new(0, 1.25, 0)
	pedestal.Color = Color3.fromRGB(15, 23, 42)
	pedestal.Material = Enum.Material.Marble
	pedestal.Anchored = true
	pedestal.Parent = model

	local cup = Instance.new("Part")
	cup.Name = "GoldenCup"
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(5.5, 3.6, 3.6)
	cup.CFrame = CFrame.new(0, 5.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	cup.Color = Color3.fromRGB(250, 204, 21)
	cup.Material = Enum.Material.Metal
	cup.Reflectance = 0.45
	cup.Anchored = true
	cup.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 60)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = cup

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "CHAMPIONS: " .. string.upper(winningTeamName)
	lbl.TextColor3 = Color3.fromRGB(250, 204, 21)
	lbl.TextStrokeTransparency = 0.2
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = bb

	model.Parent = Workspace
end

-- Build initial stadium & init BallManager
StadiumBuilder.Build(currentMode)

BallManager.Init(
	-- On Goal Scored
	function(scoringTeam, scorer, assister)
		if goalScoredFlag or matchPhase ~= "Playing" then
			return
		end
		goalScoredFlag = true
		if scoringTeam == "Home" then
			homeScore += 1
		else
			awayScore += 1
		end

		if scorer then
			DataService.AwardGoal(scorer)
			KitAndCelebrationService.PlayCelebration(scorer)
		end
		if assister and assister ~= scorer then
			DataService.AwardAssist(assister)
		end

		statusBanner = string.format(
			"GOAL! %s (%s)",
			if scorer then scorer.DisplayName else scoringTeam,
			if scoringTeam == "Home" then Config.Teams.Home.Name else Config.Teams.Away.Name
		)

		Network.GetEvent("GoalScoredVFX"):FireAllClients({
			ScoringTeam = scoringTeam,
			ScorerName = if scorer then scorer.DisplayName else scoringTeam,
			AssisterName = if assister and assister ~= scorer then assister.DisplayName else nil,
		})
		broadcastMatchState()

		task.delay(Config.GoalCelebrationSeconds, function()
			goalScoredFlag = false
			if matchPhase == "Playing" then
				BallManager.ResetToSpot(Vector3.zero, false)
				positionPlayersForKickoff()
				BallManager.SetMatchActive(true, currentMode)
				statusBanner = "Kickoff!"
				broadcastMatchState()
			end
		end)
	end,
	-- On Goalkeeper Save
	function(keeper)
		DataService.AwardSave(keeper)
		statusBanner = "GREAT SAVE by " .. keeper.DisplayName .. "!"
		broadcastMatchState()
	end,
	-- On Set Piece
	function(kind, _spot, team)
		local teamName = if team == "Home" then Config.Teams.Home.Name else Config.Teams.Away.Name
		statusBanner = string.format("%s — %s", kind, teamName)
		broadcastMatchState()
	end
)

-- 4. Main Match Loop
task.spawn(function()
	while true do
		-- INTERMISSION
		matchPhase = "Intermission"
		halfNumber = 1
		homeScore = 0
		awayScore = 0
		timeRemaining = Config.IntermissionSeconds
		BallManager.SetMatchActive(false, currentMode)
		statusBanner = "Intermission — Vote 5v5 or 11v11!"
		local oldTrophy = Workspace:FindFirstChild("ChampionshipTrophy")
		if oldTrophy then
			oldTrophy:Destroy()
		end

		while timeRemaining > 0 do
			broadcastMatchState()
			task.wait(1)
			timeRemaining -= 1
		end

		-- Apply voted mode & rebuild stadium if changed
		local nextMode = resolveModeVote()
		if nextMode ~= currentMode then
			currentMode = nextMode
			StadiumBuilder.Build(currentMode)
		end

		-- 1ST HALF
		matchPhase = "Playing"
		halfNumber = 1
		timeRemaining = Config.MatchModes[currentMode].HalfDurationSeconds
		statusBanner = "1st Half — Kickoff!"
		BallManager.ResetToSpot(Vector3.zero, false)
		positionPlayersForKickoff()
		BallManager.SetMatchActive(true, currentMode)

		while timeRemaining > 0 do
			broadcastMatchState()
			task.wait(1)
			if not goalScoredFlag then
				timeRemaining -= 1
			end
		end

		-- HALF TIME
		matchPhase = "HalfTime"
		BallManager.SetMatchActive(false, currentMode)
		timeRemaining = Config.HalfTimeSeconds
		statusBanner = "Half-Time Break"
		while timeRemaining > 0 do
			broadcastMatchState()
			task.wait(1)
			timeRemaining -= 1
		end

		-- 2ND HALF
		matchPhase = "Playing"
		halfNumber = 2
		timeRemaining = Config.MatchModes[currentMode].HalfDurationSeconds
		statusBanner = "2nd Half — Kickoff!"
		BallManager.ResetToSpot(Vector3.zero, false)
		positionPlayersForKickoff()
		BallManager.SetMatchActive(true, currentMode)

		while timeRemaining > 0 do
			broadcastMatchState()
			task.wait(1)
			if not goalScoredFlag then
				timeRemaining -= 1
			end
		end

		-- FULL TIME & TROPHY CEREMONY
		matchPhase = "TrophyCeremony"
		BallManager.SetMatchActive(false, currentMode)
		local winner: "Home" | "Away" | "Draw" = "Draw"
		local winnerName = "Draw Match"
		if homeScore > awayScore then
			winner = "Home"
			winnerName = Config.Teams.Home.Name
		elseif awayScore > homeScore then
			winner = "Away"
			winnerName = Config.Teams.Away.Name
		end

		statusBanner = "FULL TIME! " .. winnerName .. " Wins!"
		spawnChampionshipTrophy(winnerName)
		Network.GetEvent("TrophyCeremonyStart"):FireAllClients(winnerName)

		for _, player in ipairs(Players:GetPlayers()) do
			if winner ~= "Draw" then
				local isHome = (player.Team == homeTeam)
				local won = (winner == "Home" and isHome) or (winner == "Away" and not isHome)
				DataService.RecordMatchResult(player, won)
			end
		end

		timeRemaining = Config.TrophyCeremonySeconds
		while timeRemaining > 0 do
			broadcastMatchState()
			task.wait(1)
			timeRemaining -= 1
		end
	end
end)
