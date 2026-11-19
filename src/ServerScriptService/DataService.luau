--!strict
-- DataService.luau
-- Manages player profiles, Dream Squad/Club settings, Custom Kits, Celebrations, and Global Leaderboards.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)

local DataService = {}

export type PlayerProfile = {
	Coins: number,
	Goals: number,
	Assists: number,
	Saves: number,
	Wins: number,
	Matches: number,
	ELO: number,
	ClubName: string,
	Formation: string,
	EquippedKit: string,
	EquippedCelebration: string,
	UnlockedKits: { [string]: boolean },
	UnlockedCelebrations: { [string]: boolean },
	Stats: {
		Pace: number,
		Shooting: number,
		Passing: number,
		Goalkeeping: number,
	},
}

local profiles: { [number]: PlayerProfile } = {}
local profileStore: DataStore? = nil
local goalsLB: OrderedDataStore? = nil
local eloLB: OrderedDataStore? = nil
local winsLB: OrderedDataStore? = nil

local function defaultProfile(player: Player): PlayerProfile
	return {
		Coins = 200,
		Goals = 0,
		Assists = 0,
		Saves = 0,
		Wins = 0,
		Matches = 0,
		ELO = 1000,
		ClubName = player.DisplayName .. " FC",
		Formation = Catalog.Formations[1],
		EquippedKit = "classic_striker",
		EquippedCelebration = "knee_slide",
		UnlockedKits = { classic_striker = true },
		UnlockedCelebrations = { knee_slide = true },
		Stats = {
			Pace = 1,
			Shooting = 1,
			Passing = 1,
			Goalkeeping = 1,
		},
	}
end

local function safePcall<T>(fn: () -> T): (boolean, T?)
	local ok, res = pcall(fn)
	return ok, if ok then res else nil
end

local function loadProfile(player: Player): PlayerProfile
	local prof = defaultProfile(player)
	if profileStore then
		local ok, saved = safePcall(function()
			return (profileStore :: DataStore):GetAsync("Player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			for k, v in pairs(saved) do
				(prof :: any)[k] = v
			end
		end
	end
	profiles[player.UserId] = prof
	return prof
end

local function saveProfile(player: Player)
	local prof = profiles[player.UserId]
	if not prof then
		return
	end
	if profileStore then
		pcall(function()
			(profileStore :: DataStore):SetAsync("Player_" .. player.UserId, prof)
		end)
	end
	if goalsLB then
		pcall(function()
			(goalsLB :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(prof.Goals))
		end)
	end
	if eloLB then
		pcall(function()
			(eloLB :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(prof.ELO))
		end)
	end
	if winsLB then
		pcall(function()
			(winsLB :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(prof.Wins))
		end)
	end
end

local function syncToClient(player: Player)
	local prof = profiles[player.UserId]
	if prof then
		if not prof.Stats then
			prof.Stats = { Pace = 1, Shooting = 1, Passing = 1, Goalkeeping = 1 }
		end
		player:SetAttribute("Stat_Pace", prof.Stats.Pace)
		player:SetAttribute("Stat_Shooting", prof.Stats.Shooting)
		player:SetAttribute("Stat_Passing", prof.Stats.Passing)
		player:SetAttribute("Stat_Goalkeeping", prof.Stats.Goalkeeping)
		Network.GetEvent("ProfileUpdated"):FireClient(player, prof)
	end
end

function DataService.GetProfile(player: Player): PlayerProfile
	return profiles[player.UserId] or loadProfile(player)
end

function DataService.AwardGoal(player: Player)
	local prof = DataService.GetProfile(player)
	prof.Goals += 1
	prof.Coins += Config.Rewards.GoalCoins
	syncToClient(player)
end

function DataService.AwardAssist(player: Player)
	local prof = DataService.GetProfile(player)
	prof.Assists += 1
	prof.Coins += Config.Rewards.AssistCoins
	syncToClient(player)
end

function DataService.AwardSave(player: Player)
	local prof = DataService.GetProfile(player)
	prof.Saves += 1
	prof.Coins += Config.Rewards.SaveCoins
	syncToClient(player)
end

function DataService.GiveCoins(player: Player, amount: number)
	local prof = DataService.GetProfile(player)
	prof.Coins = math.max(0, prof.Coins + math.floor(amount))
	syncToClient(player)
end

function DataService.RecordMatchResult(player: Player, won: boolean)
	local prof = DataService.GetProfile(player)
	prof.Matches += 1
	if won then
		prof.Wins += 1
		prof.Coins += Config.Rewards.WinCoins
		prof.ELO = math.max(100, prof.ELO + Config.Rewards.WinELO)
	else
		prof.Coins += Config.Rewards.LossCoins
		prof.ELO = math.max(100, prof.ELO + Config.Rewards.LossELO)
	end
	syncToClient(player)
	task.spawn(saveProfile, player)
end

local function fetchLeaderboard(store: OrderedDataStore?, statKey: string): { { Name: string, Value: number, Club: string } }
	local entries = {}
	if store then
		local ok, pages = safePcall(function()
			return store:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			for _, item in ipairs(page) do
				local uid = tonumber(item.key)
				local name = "Player " .. tostring(item.key)
				if uid then
					local okName, resolved = pcall(function()
						return Players:GetNameFromUserIdAsync(uid)
					end)
					if okName and resolved then
						name = resolved
					end
				end
				table.insert(entries, {
					Name = name,
					Value = item.value,
					Club = "Club",
				})
			end
		end
	end

	-- Fallback/merge with active server players if DataStore is unavailable (e.g. Studio)
	if #entries == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = DataService.GetProfile(p)
			local val = (prof :: any)[statKey] or 0
			table.insert(entries, {
				Name = p.DisplayName,
				Value = val,
				Club = prof.ClubName,
			})
		end
		table.sort(entries, function(a, b)
			return a.Value > b.Value
		end)
	end

	return entries
end

function DataService.Init(onKitChanged: ((Player) -> ())?)
	pcall(function()
		profileStore = DataStoreService:GetDataStore("MapleviewSoccer_Profiles_v1")
		goalsLB = DataStoreService:GetOrderedDataStore("MapleviewSoccer_GoalsLB_v1")
		eloLB = DataStoreService:GetOrderedDataStore("MapleviewSoccer_ELOLB_v1")
		winsLB = DataStoreService:GetOrderedDataStore("MapleviewSoccer_WinsLB_v1")
	end)

	Players.PlayerAdded:Connect(function(player)
		loadProfile(player)
		syncToClient(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		loadProfile(player)
	end

	Network.GetFunction("GetProfile").OnServerInvoke = function(player)
		return DataService.GetProfile(player)
	end

	Network.GetFunction("GetLeaderboards").OnServerInvoke = function(_player)
		return {
			Goals = fetchLeaderboard(goalsLB, "Goals"),
			ELO = fetchLeaderboard(eloLB, "ELO"),
			Wins = fetchLeaderboard(winsLB, "Wins"),
		}
	end

	Network.GetEvent("PurchaseItem").OnServerEvent:Connect(function(player, category: string, itemId: string)
		local prof = DataService.GetProfile(player)
		if category == "Kit" then
			local kit = Catalog.GetKit(itemId)
			if kit and not prof.UnlockedKits[itemId] and prof.Coins >= kit.Price then
				prof.Coins -= kit.Price
				prof.UnlockedKits[itemId] = true
				prof.EquippedKit = itemId
				syncToClient(player)
				if onKitChanged then
					onKitChanged(player)
				end
			end
		elseif category == "Celebration" then
			local cel = Catalog.GetCelebration(itemId)
			if cel and not prof.UnlockedCelebrations[itemId] and prof.Coins >= cel.Price then
				prof.Coins -= cel.Price
				prof.UnlockedCelebrations[itemId] = true
				prof.EquippedCelebration = itemId
				syncToClient(player)
			end
		end
	end)

	Network.GetEvent("EquipItem").OnServerEvent:Connect(function(player, category: string, itemId: string)
		local prof = DataService.GetProfile(player)
		if category == "Kit" and prof.UnlockedKits[itemId] then
			prof.EquippedKit = itemId
			syncToClient(player)
			if onKitChanged then
				onKitChanged(player)
			end
		elseif category == "Celebration" and prof.UnlockedCelebrations[itemId] then
			prof.EquippedCelebration = itemId
			syncToClient(player)
		elseif category == "Formation" then
			for _, f in ipairs(Catalog.Formations) do
				if f == itemId then
					prof.Formation = itemId
					syncToClient(player)
					break
				end
			end
		end
	end)

	Network.GetEvent("UpdateClubName").OnServerEvent:Connect(function(player, newName: string)
		if type(newName) ~= "string" then
			return
		end
		local trimmed = string.sub(newName:gsub("^%s*(.-)%s*$", "%1"), 1, 20)
		if #trimmed >= 2 then
			local prof = DataService.GetProfile(player)
			prof.ClubName = trimmed
			syncToClient(player)
		end
	end)

	Network.GetEvent("UpgradeStat").OnServerEvent:Connect(function(player, statName: string)
		if statName ~= "Pace" and statName ~= "Shooting" and statName ~= "Passing" and statName ~= "Goalkeeping" then
			return
		end
		local prof = DataService.GetProfile(player)
		if not prof.Stats then
			prof.Stats = { Pace = 1, Shooting = 1, Passing = 1, Goalkeeping = 1 }
		end
		local curLvl = (prof.Stats :: any)[statName] or 1
		if curLvl >= 5 then
			return
		end
		local cost = 100 * curLvl
		if prof.Coins >= cost then
			prof.Coins -= cost
			;(prof.Stats :: any)[statName] = curLvl + 1
			syncToClient(player)
		end
	end)
end

return DataService
