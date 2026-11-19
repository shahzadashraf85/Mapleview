--!strict
-- MatchManager.server.luau
-- Orchestrates teams, Lobby/Training Pitch, 5v5/11v11 modes, Stadium themes, Admin Panel (ninja373670), and Trophy Ceremony.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)

local BallManager = require(script.Parent.BallManager)
local DataService = require(script.Parent.DataService)
local GoalkeeperAI = require(script.Parent.GoalkeeperAI)
local KitAndCelebrationService = require(script.Parent.KitAndCelebrationService)
local ModelFactory = require(script.Parent.ModelFactory)
local StadiumBuilder = require(script.Parent.StadiumBuilder)

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

DataService.Init(function(player)
	KitAndCelebrationService.ApplyKit(player)
end)
KitAndCelebrationService.Init(DataService.GetProfile)

local currentMode: Config.MatchMode = Config.DefaultMode
local currentStadium: Config.StadiumThemeId = Config.DefaultStadium
local modeVotes: { [number]: Config.MatchMode } = {}

local matchPhase = "Intermission"
local halfNumber = 1
local timeRemaining = Config.IntermissionSeconds
local homeScore = 0
local awayScore = 0
local statusBanner = "Lobby Training Pitch — Next Match Starting Soon"
local goalScoredFlag = false
local forceSkipPhase = false
local afkPlayers: { [number]: boolean } = {}
local discoEndTime = 0

local function isAdmin(player: Player): boolean
	return player.Name == Config.AdminUsername or RunService:IsStudio()
end

local function giveHammerIfAdmin(player: Player)
	if not isAdmin(player) then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if (backpack and backpack:FindFirstChild("Hammer")) or (char and char:FindFirstChild("Hammer")) then
		return
	end
	if backpack then
		local hammer = ModelFactory.BuildHammerTool()
		hammer.Activated:Connect(function()
			Network.GetEvent("OpenHammerPanel"):FireClient(player)
		end)
		hammer.Parent = backpack
	end
end

local function assignTeamBalanced(player: Player)
	local homeCount = #homeTeam:GetPlayers()
	local awayCount = #awayTeam:GetPlayers()
	player.Team = if homeCount <= awayCount then homeTeam else awayTeam
end

Players.PlayerAdded:Connect(function(player)
	assignTeamBalanced(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		KitAndCelebrationService.ApplyKit(player)
		giveHammerIfAdmin(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	afkPlayers[player.UserId] = nil
end)

for _, p in ipairs(Players:GetPlayers()) do
	if not p.Team then
		assignTeamBalanced(p)
	end
	giveHammerIfAdmin(p)
end

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
	return if v11 > v5 then "11v11" else "5v5"
end

local function broadcastMatchState()
	Network.GetEvent("MatchStateUpdate"):FireAllClients({
		Phase = matchPhase,
		Half = halfNumber,
		TimeRemaining = math.max(0, math.floor(timeRemaining)),
		HomeScore = homeScore,
		AwayScore = awayScore,
		Mode = currentMode,
		Stadium = currentStadium,
		Status = statusBanner,
	})
end

local function teleportPlayerToLobby(player: Player, idx: number)
	local c = Config.LobbyCenter
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local offX = ((idx - 1) % 4 - 1.5) * 8
		hrp.CFrame = CFrame.lookAt(c + Vector3.new(offX, 3.5, -72), c + Vector3.new(0, 3.5, -56))
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

local function teleportPlayersToLobby()
	for i, player in ipairs(Players:GetPlayers()) do
		teleportPlayerToLobby(player, i)
	end
end

local function positionPlayersForKickoff()
	local halfL = Config.MatchModes[currentMode].PitchLength * 0.5
	local homeIdx, awayIdx = 0, 0
	for i, player in ipairs(Players:GetPlayers()) do
		if afkPlayers[player.UserId] then
			teleportPlayerToLobby(player, i)
			continue
		end
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

-- AFK / Join Match Toggle
Network.GetEvent("ToggleAFK").OnServerEvent:Connect(function(player: Player, isAfk: boolean)
	if type(isAfk) ~= "boolean" then
		return
	end
	afkPlayers[player.UserId] = isAfk
	player:SetAttribute("IsAFK", isAfk)
	if isAfk then
		teleportPlayerToLobby(player, 1)
	elseif matchPhase == "Playing" then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local z = if player.Team == homeTeam then -20 else 20
			hrp.CFrame = CFrame.lookAt(Vector3.new(0, 3.5, z), Vector3.new(0, 3.5, 0))
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
end)

local function startDiscoTacoParty()
	local alreadyRunning = os.clock() < discoEndTime
	discoEndTime = os.clock() + 180 -- 3 minutes!
	Network.GetEvent("DiscoPartyStart"):FireAllClients(180)
	if alreadyRunning then
		return
	end

	task.spawn(function()
		while os.clock() < discoEndTime do
			-- Rain 3D tacos over the stadium and lobby
			for i = 1, 3 do
				local onLobby = (i == 3)
				local center = if onLobby then Config.LobbyCenter else Vector3.zero
				local rx = (math.random() - 0.5) * 140
				local rz = (math.random() - 0.5) * 160
				local taco = ModelFactory.BuildTaco(center + Vector3.new(rx, 85, rz))
				taco.Parent = Workspace
				if taco.PrimaryPart then
					taco.PrimaryPart.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
				end
				task.delay(5.5, function()
					if taco.Parent then
						taco:Destroy()
					end
				end)
			end
			task.wait(0.3)
		end
	end)
end

-- Hammer Panel Commands (strictly restricted to ninja373670)
Network.GetEvent("AdminCommand").OnServerEvent:Connect(function(player: Player, cmd: string, arg: any)
	if not isAdmin(player) then
		return
	end
	local halfL = Config.MatchModes[currentMode].PitchLength * 0.5

	if cmd == "FreeKick" then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local spot = Vector3.new(hrp.Position.X, Config.Ball.Radius, hrp.Position.Z)
			BallManager.ResetToSpot(spot, false)
			statusBanner = "FREE KICK AWARDED!"
			broadcastMatchState()
		end
	elseif cmd == "PenaltyHome" then
		local spot = Vector3.new(0, Config.Ball.Radius, halfL - Config.Kicks.GKBoxDepth * 0.68)
		BallManager.ResetToSpot(spot, false)
		statusBanner = "PENALTY KICK — HOME FC!"
		broadcastMatchState()
	elseif cmd == "PenaltyAway" then
		local spot = Vector3.new(0, Config.Ball.Radius, -(halfL - Config.Kicks.GKBoxDepth * 0.68))
		BallManager.ResetToSpot(spot, false)
		statusBanner = "PENALTY KICK — AWAY UNITED!"
		broadcastMatchState()
	elseif cmd == "SetStadium" and type(arg) == "string" and (Config.StadiumThemes :: any)[arg] then
		currentStadium = arg :: Config.StadiumThemeId
		StadiumBuilder.Build(currentMode, currentStadium)
		GoalkeeperAI.Rebuild(currentMode)
		statusBanner = "Stadium Changed: " .. (Config.StadiumThemes :: any)[arg].Name
		broadcastMatchState()
	elseif cmd == "SetMode" and (arg == "5v5" or arg == "11v11") then
		currentMode = arg :: Config.MatchMode
		StadiumBuilder.Build(currentMode, currentStadium)
		GoalkeeperAI.Rebuild(currentMode)
		BallManager.SetMatchActive(matchPhase == "Playing", currentMode)
		statusBanner = "Match Format Changed: " .. currentMode
		broadcastMatchState()
	elseif cmd == "ResetBall" then
		BallManager.ResetToSpot(Vector3.zero, false)
		statusBanner = "Ball Reset to Center"
		broadcastMatchState()
	elseif cmd == "AddGoalHome" then
		homeScore += 1
		broadcastMatchState()
	elseif cmd == "AddGoalAway" then
		awayScore += 1
		broadcastMatchState()
	elseif cmd == "SkipPhase" then
		forceSkipPhase = true
	elseif cmd == "GlobalChat" and type(arg) == "string" then
		local msg = string.sub(arg, 1, 140)
		if #msg > 0 then
			Network.GetEvent("GlobalAnnouncement"):FireAllClients(player.DisplayName, msg)
		end
	elseif cmd == "DiscoTacoParty" then
		startDiscoTacoParty()
		Network.GetEvent("GlobalAnnouncement"):FireAllClients(player.DisplayName, "DISCO PARTY & RAINING TACOS STARTED FOR 3 MINUTES!")
	elseif cmd == "GiveCoins" and type(arg) == "table" then
		local targetId = tonumber(arg.TargetUserId)
		local amount = tonumber(arg.Amount) or 0
		if targetId and amount ~= 0 then
			local targetPlayer = Players:GetPlayerByUserId(targetId)
			if targetPlayer then
				DataService.GiveCoins(targetPlayer, amount)
			end
		end
	end
end)

-- Build initial stadium + lobby + goalkeepers
StadiumBuilder.Build(currentMode, currentStadium)
GoalkeeperAI.Rebuild(currentMode)

BallManager.Init(
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
	function(keeper)
		DataService.AwardSave(keeper)
		statusBanner = "GREAT SAVE by " .. keeper.DisplayName .. "!"
		broadcastMatchState()
	end,
	function()
		statusBanner = "KEEPER SAVE!"
		broadcastMatchState()
	end,
	function(kind, _spot, team)
		local teamName = if team == "Home" then Config.Teams.Home.Name else Config.Teams.Away.Name
		statusBanner = string.format("%s — %s", kind, teamName)
		broadcastMatchState()
	end
)

local function waitCountdown(seconds: number, pauseOnGoal: boolean)
	timeRemaining = seconds
	forceSkipPhase = false
	while timeRemaining > 0 and not forceSkipPhase do
		broadcastMatchState()
		task.wait(1)
		if not (pauseOnGoal and goalScoredFlag) then
			timeRemaining -= 1
		end
	end
end

-- Main Match Loop
task.spawn(function()
	while true do
		matchPhase = "Intermission"
		halfNumber = 1
		homeScore = 0
		awayScore = 0
		BallManager.SetMatchActive(false, currentMode)
		statusBanner = "Lobby Training Pitch — Vote 5v5 or 11v11!"
		local oldTrophy = Workspace:FindFirstChild("ChampionshipTrophy")
		if oldTrophy then
			oldTrophy:Destroy()
		end
		teleportPlayersToLobby()
		waitCountdown(Config.IntermissionSeconds, false)

		local nextMode = resolveModeVote()
		if nextMode ~= currentMode then
			currentMode = nextMode
			StadiumBuilder.Build(currentMode, currentStadium)
			GoalkeeperAI.Rebuild(currentMode)
		end

		-- 1st Half
		matchPhase = "Playing"
		halfNumber = 1
		statusBanner = "1st Half — Kickoff!"
		BallManager.ResetToSpot(Vector3.zero, false)
		positionPlayersForKickoff()
		BallManager.SetMatchActive(true, currentMode)
		waitCountdown(Config.MatchModes[currentMode].HalfDurationSeconds, true)

		-- Half-Time
		matchPhase = "HalfTime"
		BallManager.SetMatchActive(false, currentMode)
		statusBanner = "Half-Time Break"
		waitCountdown(Config.HalfTimeSeconds, false)

		-- 2nd Half
		matchPhase = "Playing"
		halfNumber = 2
		statusBanner = "2nd Half — Kickoff!"
		BallManager.ResetToSpot(Vector3.zero, false)
		positionPlayersForKickoff()
		BallManager.SetMatchActive(true, currentMode)
		waitCountdown(Config.MatchModes[currentMode].HalfDurationSeconds, true)

		-- Trophy Ceremony
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
		ModelFactory.BuildTrophy(Workspace, Vector3.new(0, 0, 0), "CHAMPIONS: " .. string.upper(winnerName))
		Network.GetEvent("TrophyCeremonyStart"):FireAllClients(winnerName)

		for _, player in ipairs(Players:GetPlayers()) do
			if winner ~= "Draw" then
				local isHome = (player.Team == homeTeam)
				local won = (winner == "Home" and isHome) or (winner == "Away" and not isHome)
				DataService.RecordMatchResult(player, won)
			end
		end

		waitCountdown(Config.TrophyCeremonySeconds, false)
	end
end)
