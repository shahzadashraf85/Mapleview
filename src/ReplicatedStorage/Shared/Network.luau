--!strict
-- Network.luau
-- Centralizes RemoteEvents and RemoteFunctions so server and client never desync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = {}

local REMOTE_EVENTS = {
	"BallStateUpdate",     -- Server -> Clients: authoritative ball pos/vel/spin/owner
	"KickRequest",         -- Client -> Server: Shoot / Pass / ThroughBall / Lob / FreeKick (with targetPos)
	"DribbleToggle",       -- Client -> Server: Request close control or release
	"TackleRequest",       -- Client -> Server: Slide tackle / steal attempt
	"GKDiveRequest",       -- Client -> Server: Goalkeeper dive direction
	"MatchStateUpdate",    -- Server -> Clients: timer, scores, phase, mode, stadium, set-piece info
	"GoalScoredVFX",       -- Server -> Clients: goal banner, net ripple, scorer info, fan cheer
	"CelebrationTrigger",  -- Client <-> Server: trigger equipped celebration
	"TrophyCeremonyStart", -- Server -> Clients: confetti & trophy lift FX
	"VoteMatchMode",       -- Client -> Server: vote 5v5 or 11v11
	"EquipItem",           -- Client -> Server: equip kit / celebration / formation
	"PurchaseItem",        -- Client -> Server: buy kit / celebration
	"UpdateClubName",      -- Client -> Server: set custom club name
	"ProfileUpdated",      -- Server -> Client: sync player profile & coins/ELO
	"AdminCommand",        -- Client -> Server: ninja373670 admin actions
	"TrainingBallKick",    -- Client -> Server: kick a practice ball on the lobby training pitch
	"ToggleAFK",           -- Client -> Server: toggle AFK (stay in lobby vs join match)
	"GlobalAnnouncement",  -- Server -> Clients: global chat/banner broadcast from admin
	"DiscoPartyStart",     -- Server -> Clients: 3-minute disco lights + raining tacos FX
	"OpenHammerPanel",     -- Server -> Client: triggered when ninja373670 activates the Hammer Tool
}

local REMOTE_FUNCTIONS = {
	"GetProfile",          -- Client -> Server: fetch initial player data
	"GetLeaderboards",     -- Client -> Server: fetch global top scorers, ELO, wins
}

local function getOrCreateFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		return existing
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		return folder
	else
		return ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
end

function Network.InitServer()
	local folder = getOrCreateFolder()
	for _, name in ipairs(REMOTE_EVENTS) do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
	for _, name in ipairs(REMOTE_FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
end

function Network.GetEvent(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	local ev = folder:WaitForChild(name, 15)
	assert(ev and ev:IsA("RemoteEvent"), "Missing RemoteEvent: " .. name)
	return ev :: RemoteEvent
end

function Network.GetFunction(name: string): RemoteFunction
	local folder = getOrCreateFolder()
	local fn = folder:WaitForChild(name, 15)
	assert(fn and fn:IsA("RemoteFunction"), "Missing RemoteFunction: " .. name)
	return fn :: RemoteFunction
end

return Network
