--!strict
-- HUDController.client.luau
-- Broadcast scoreboard, power/curve/stamina bars, goal banner, Club/Shop/Leaderboard modal, and Admin Panel (ninja373670).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Network = require(ReplicatedStorage.Shared.Network)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentProfile: any = nil
local isAdminUser = (player.Name == Config.AdminUsername or RunService:IsStudio())

local function makeCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "FIFASoccerHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- 1. Top Broadcast Scorebug
local scorebug = Instance.new("Frame")
scorebug.Size = UDim2.fromOffset(470, 68)
scorebug.Position = UDim2.new(0.5, -235, 0, 14)
scorebug.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
scorebug.BackgroundTransparency = 0.12
scorebug.Parent = gui
makeCorner(scorebug, 12)
makeStroke(scorebug, Color3.fromRGB(51, 65, 85), 1.5)

local homeTag = Instance.new("Frame")
homeTag.Size = UDim2.fromOffset(150, 38)
homeTag.Position = UDim2.fromOffset(8, 6)
homeTag.BackgroundColor3 = Config.Teams.Home.PrimaryColor
homeTag.Parent = scorebug
makeCorner(homeTag, 8)

local homeLbl = Instance.new("TextLabel")
homeLbl.Size = UDim2.fromScale(1, 1)
homeLbl.BackgroundTransparency = 1
homeLbl.Text = "HOME  0"
homeLbl.TextColor3 = Color3.new(1, 1, 1)
homeLbl.Font = Enum.Font.GothamBlack
homeLbl.TextSize = 18
homeLbl.Parent = homeTag

local awayTag = Instance.new("Frame")
awayTag.Size = UDim2.fromOffset(150, 38)
awayTag.Position = UDim2.new(1, -158, 0, 6)
awayTag.BackgroundColor3 = Config.Teams.Away.PrimaryColor
awayTag.Parent = scorebug
makeCorner(awayTag, 8)

local awayLbl = Instance.new("TextLabel")
awayLbl.Size = UDim2.fromScale(1, 1)
awayLbl.BackgroundTransparency = 1
awayLbl.Text = "0  AWAY"
awayLbl.TextColor3 = Color3.new(1, 1, 1)
awayLbl.Font = Enum.Font.GothamBlack
awayLbl.TextSize = 18
awayLbl.Parent = awayTag

local clockLbl = Instance.new("TextLabel")
clockLbl.Size = UDim2.fromOffset(138, 38)
clockLbl.Position = UDim2.fromOffset(166, 6)
clockLbl.BackgroundTransparency = 1
clockLbl.Text = "00:00  |  5v5"
clockLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
clockLbl.Font = Enum.Font.GothamBold
clockLbl.TextSize = 16
clockLbl.Parent = scorebug

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 20)
statusLbl.Position = UDim2.fromOffset(8, 45)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Lobby Training Pitch — Next Match Starting Soon"
statusLbl.TextColor3 = Color3.fromRGB(203, 213, 225)
statusLbl.Font = Enum.Font.GothamSemibold
statusLbl.TextSize = 13
statusLbl.Parent = scorebug

-- 2. Bottom-Right Power, Curve & Stamina HUD
local meterFrame = Instance.new("Frame")
meterFrame.Size = UDim2.fromOffset(250, 118)
meterFrame.Position = UDim2.new(1, -270, 1, -138)
meterFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
meterFrame.BackgroundTransparency = 0.18
meterFrame.Parent = gui
makeCorner(meterFrame, 12)
makeStroke(meterFrame, Color3.fromRGB(51, 65, 85), 1.5)

local function makeBar(yOffset: number, labelText: string, fillColor: Color3): Frame
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(70, 18)
	lbl.Position = UDim2.fromOffset(10, yOffset)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(226, 232, 240)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.Parent = meterFrame

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromOffset(154, 12)
	bg.Position = UDim2.fromOffset(84, yOffset + 3)
	bg.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	bg.Parent = meterFrame
	makeCorner(bg, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor
	fill.Parent = bg
	makeCorner(fill, 6)
	return fill
end

local powerFill = makeBar(12, "POWER", Color3.fromRGB(250, 204, 21))
local curveFill = makeBar(36, "CURVE", Color3.fromRGB(56, 189, 248))
local staminaFill = makeBar(60, "STAMINA", Color3.fromRGB(34, 197, 94))

local controlsHint = Instance.new("TextLabel")
controlsHint.Size = UDim2.new(1, -16, 0, 32)
controlsHint.Position = UDim2.fromOffset(8, 82)
controlsHint.BackgroundTransparency = 1
controlsHint.Text = "Click: Aim & Shoot | F: Through-Ball | X: Ragdoll Flop\nA/D: Curve | R: Ragdoll Tackle | Space: GK Dive | G: Cel"
controlsHint.TextColor3 = Color3.fromRGB(148, 163, 184)
controlsHint.Font = Enum.Font.Gotham
controlsHint.TextSize = 10
controlsHint.Parent = meterFrame

-- 3. Goal Banner Overlay
local goalBanner = Instance.new("Frame")
goalBanner.Size = UDim2.fromOffset(520, 96)
goalBanner.Position = UDim2.new(0.5, -260, 0.22, 0)
goalBanner.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
goalBanner.BackgroundTransparency = 0.08
goalBanner.Visible = false
goalBanner.Parent = gui
makeCorner(goalBanner, 16)
makeStroke(goalBanner, Color3.fromRGB(250, 204, 21), 3)

local goalTitle = Instance.new("TextLabel")
goalTitle.Size = UDim2.new(1, 0, 0.55, 0)
goalTitle.BackgroundTransparency = 1
goalTitle.Text = "GOAL!"
goalTitle.TextColor3 = Color3.fromRGB(250, 204, 21)
goalTitle.Font = Enum.Font.GothamBlack
goalTitle.TextSize = 38
goalTitle.Parent = goalBanner

local goalSub = Instance.new("TextLabel")
goalSub.Size = UDim2.new(1, 0, 0.45, 0)
goalSub.Position = UDim2.fromScale(0, 0.52)
goalSub.BackgroundTransparency = 1
goalSub.Text = "Scored by Player"
goalSub.TextColor3 = Color3.new(1, 1, 1)
goalSub.Font = Enum.Font.GothamBold
goalSub.TextSize = 20
goalSub.Parent = goalBanner

-- 4. Club / Locker Room / Leaderboard Modal
local menuBtn = Instance.new("TextButton")
menuBtn.Size = UDim2.fromOffset(170, 38)
menuBtn.Position = UDim2.new(1, -190, 0, 16)
menuBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
menuBtn.Text = "CLUB & SHOP [TAB]"
menuBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
menuBtn.Font = Enum.Font.GothamBold
menuBtn.TextSize = 13
menuBtn.Parent = gui
makeCorner(menuBtn, 10)
makeStroke(menuBtn, Color3.fromRGB(250, 204, 21), 1.5)

local modal = Instance.new("Frame")
modal.Size = UDim2.fromOffset(660, 460)
modal.Position = UDim2.new(0.5, -330, 0.5, -230)
modal.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
modal.BackgroundTransparency = 0.04
modal.Visible = false
modal.Parent = gui
makeCorner(modal, 16)
makeStroke(modal, Color3.fromRGB(71, 85, 105), 2)

local modalHeader = Instance.new("TextLabel")
modalHeader.Size = UDim2.new(1, -120, 0, 44)
modalHeader.Position = UDim2.fromOffset(18, 8)
modalHeader.BackgroundTransparency = 1
modalHeader.Text = "DREAM SQUAD & LOCKER ROOM"
modalHeader.TextXAlignment = Enum.TextXAlignment.Left
modalHeader.TextColor3 = Color3.new(1, 1, 1)
modalHeader.Font = Enum.Font.GothamBlack
modalHeader.TextSize = 20
modalHeader.Parent = modal

local coinsLbl = Instance.new("TextLabel")
coinsLbl.Size = UDim2.fromOffset(180, 44)
coinsLbl.Position = UDim2.new(1, -196, 0, 8)
coinsLbl.BackgroundTransparency = 1
coinsLbl.Text = "Coins: 0 | ELO: 1000"
coinsLbl.TextXAlignment = Enum.TextXAlignment.Right
coinsLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
coinsLbl.Font = Enum.Font.GothamBold
coinsLbl.TextSize = 14
coinsLbl.Parent = modal

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -36, 0, 36)
tabBar.Position = UDim2.fromOffset(18, 54)
tabBar.BackgroundTransparency = 1
tabBar.Parent = modal

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabBar

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -36, 1, -110)
contentScroll.Position = UDim2.fromOffset(18, 98)
contentScroll.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
contentScroll.BackgroundTransparency = 0.4
contentScroll.ScrollBarThickness = 6
contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroll.Parent = modal
makeCorner(contentScroll, 10)

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 10)
contentPad.PaddingLeft = UDim.new(0, 10)
contentPad.PaddingRight = UDim.new(0, 10)
contentPad.Parent = contentScroll

local contentList = Instance.new("UIListLayout")
contentList.Padding = UDim.new(0, 8)
contentList.Parent = contentScroll

local activeTab = "Squad"

local function clearContent()
	for _, child in ipairs(contentScroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeRowCard(title: string, subtitle: string, btnText: string?, btnColor: Color3?, onClick: (() -> ())?)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 58)
	card.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	card.Parent = contentScroll
	makeCorner(card, 8)

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(1, -140, 0, 26)
	tLbl.Position = UDim2.fromOffset(12, 6)
	tLbl.BackgroundTransparency = 1
	tLbl.Text = title
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.TextColor3 = Color3.new(1, 1, 1)
	tLbl.Font = Enum.Font.GothamBold
	tLbl.TextSize = 15
	tLbl.Parent = card

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(1, -140, 0, 20)
	sLbl.Position = UDim2.fromOffset(12, 32)
	sLbl.BackgroundTransparency = 1
	sLbl.Text = subtitle
	sLbl.TextXAlignment = Enum.TextXAlignment.Left
	sLbl.TextColor3 = Color3.fromRGB(148, 163, 184)
	sLbl.Font = Enum.Font.Gotham
	sLbl.TextSize = 12
	sLbl.Parent = card

	if btnText and onClick then
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(112, 36)
		btn.Position = UDim2.new(1, -124, 0.5, -18)
		btn.BackgroundColor3 = btnColor or Color3.fromRGB(37, 99, 235)
		btn.Text = btnText
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.Parent = card
		makeCorner(btn, 8)
		btn.MouseButton1Click:Connect(onClick)
	end
end

local function renderTab()
	clearContent()
	local prof = currentProfile
	if not prof then
		return
	end
	coinsLbl.Text = string.format("Coins: %d | ELO: %d", prof.Coins or 0, prof.ELO or 1000)

	if activeTab == "Squad" then
		local clubBox = Instance.new("TextBox")
		clubBox.Size = UDim2.new(1, -8, 0, 42)
		clubBox.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
		clubBox.PlaceholderText = "Enter Club Name..."
		clubBox.Text = prof.ClubName or "My Club FC"
		clubBox.TextColor3 = Color3.fromRGB(250, 204, 21)
		clubBox.Font = Enum.Font.GothamBold
		clubBox.TextSize = 16
		clubBox.Parent = contentScroll
		makeCorner(clubBox, 8)
		clubBox.FocusLost:Connect(function()
			Network.GetEvent("UpdateClubName"):FireServer(clubBox.Text)
		end)

		makeRowCard(
			string.format("Career Stats: %d Goals | %d Assists | %d Saves", prof.Goals, prof.Assists, prof.Saves),
			string.format("Wins: %d / Matches: %d | Formation: %s", prof.Wins, prof.Matches, prof.Formation),
			nil,
			nil,
			nil
		)

		local stats = prof.Stats or { Pace = 1, Shooting = 1, Passing = 1, Goalkeeping = 1 }
		for _, statInfo in ipairs({
			{ Key = "Pace", Desc = "Increases Sprint Speed & Stamina Regen" },
			{ Key = "Shooting", Desc = "Increases Shot Power & Curve Spin" },
			{ Key = "Passing", Desc = "Increases Through-Ball & Lob Speed" },
			{ Key = "Goalkeeping", Desc = "Increases Keeper Dive Speed & Reach" },
		}) do
			local lvl = (stats :: any)[statInfo.Key] or 1
			local maxed = (lvl >= 5)
			local cost = 100 * lvl
			makeRowCard(
				string.format("%s  (Lv. %d / 5)", statInfo.Key, lvl),
				statInfo.Desc,
				if maxed then "MAXED" else ("Upgrade (" .. cost .. ")"),
				if maxed then Color3.fromRGB(100, 116, 139) else Color3.fromRGB(22, 163, 74),
				function()
					if not maxed then
						Network.GetEvent("UpgradeStat"):FireServer(statInfo.Key)
					end
				end
			)
		end
		makeRowCard("Vote Match Format: 5v5 Fast-Paced", "Shorter pitch, rapid counter-attacks", "Vote 5v5", Color3.fromRGB(22, 163, 74), function()
			Network.GetEvent("VoteMatchMode"):FireServer("5v5")
		end)
		makeRowCard("Vote Match Format: 11v11 Competitive", "Full-size stadium pitch & tactical play", "Vote 11v11", Color3.fromRGB(37, 99, 235), function()
			Network.GetEvent("VoteMatchMode"):FireServer("11v11")
		end)

		for _, form in ipairs(Catalog.Formations) do
			local equipped = (prof.Formation == form)
			makeRowCard(
				form,
				"Dream Squad Tactical Setup",
				if equipped then "Active" else "Select",
				if equipped then Color3.fromRGB(100, 116, 139) else Color3.fromRGB(37, 99, 235),
				function()
					Network.GetEvent("EquipItem"):FireServer("Formation", form)
				end
			)
		end
	elseif activeTab == "Kits" then
		for _, kit in ipairs(Catalog.Kits) do
			local unlocked = prof.UnlockedKits and prof.UnlockedKits[kit.Id]
			local equipped = (prof.EquippedKit == kit.Id)
			local btnTxt = if equipped then "Equipped" elseif unlocked then "Equip" else (kit.Price .. " Coins")
			local btnCol = if equipped
				then Color3.fromRGB(100, 116, 139)
				elseif unlocked then Color3.fromRGB(22, 163, 74)
				else Color3.fromRGB(217, 119, 6)
			makeRowCard(kit.Name, kit.Description, btnTxt, btnCol, function()
				if unlocked then
					Network.GetEvent("EquipItem"):FireServer("Kit", kit.Id)
				else
					Network.GetEvent("PurchaseItem"):FireServer("Kit", kit.Id)
				end
			end)
		end
	elseif activeTab == "Celebrations" then
		for _, cel in ipairs(Catalog.Celebrations) do
			local unlocked = prof.UnlockedCelebrations and prof.UnlockedCelebrations[cel.Id]
			local equipped = (prof.EquippedCelebration == cel.Id)
			local btnTxt = if equipped then "Equipped" elseif unlocked then "Equip" else (cel.Price .. " Coins")
			local btnCol = if equipped
				then Color3.fromRGB(100, 116, 139)
				elseif unlocked then Color3.fromRGB(22, 163, 74)
				else Color3.fromRGB(217, 119, 6)
			makeRowCard(cel.Name, cel.Description, btnTxt, btnCol, function()
				if unlocked then
					Network.GetEvent("EquipItem"):FireServer("Celebration", cel.Id)
				else
					Network.GetEvent("PurchaseItem"):FireServer("Celebration", cel.Id)
				end
			end)
		end
	elseif activeTab == "Leaderboard" then
		local lbData = Network.GetFunction("GetLeaderboards"):InvokeServer()
		if lbData then
			makeRowCard("TOP SCORERS (GLOBAL)", "Most career goals across all matches", nil, nil, nil)
			for idx, entry in ipairs(lbData.Goals or {}) do
				makeRowCard(string.format("#%d  %s", idx, entry.Name), string.format("%d Goals", entry.Value), nil, nil, nil)
			end
			makeRowCard("TOP CLUBS (ELO RATING)", "Highest competitive skill rating", nil, nil, nil)
			for idx, entry in ipairs(lbData.ELO or {}) do
				makeRowCard(string.format("#%d  %s", idx, entry.Name), string.format("%d ELO", entry.Value), nil, nil, nil)
			end
		end
	end
end

local function makeTabButton(name: string, label: string)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(148, 34)
	b.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	b.Text = label
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Parent = tabBar
	makeCorner(b, 8)
	b.MouseButton1Click:Connect(function()
		activeTab = name
		renderTab()
	end)
end

makeTabButton("Squad", "Dream Squad")
makeTabButton("Kits", "Custom Kits")
makeTabButton("Celebrations", "Celebrations")
makeTabButton("Leaderboard", "Leaderboards")

local function toggleModal()
	modal.Visible = not modal.Visible
	if modal.Visible then
		renderTab()
	end
end

menuBtn.MouseButton1Click:Connect(toggleModal)
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.Tab then
		toggleModal()
	end
end)

-- 4.5 AFK / Join Match Toggle Button (top-left)
local isAfk = false
local afkBtn = Instance.new("TextButton")
afkBtn.Size = UDim2.fromOffset(180, 38)
afkBtn.Position = UDim2.new(0, 18, 0, 16)
afkBtn.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
afkBtn.Text = "IN MATCH (Click for AFK)"
afkBtn.TextColor3 = Color3.new(1, 1, 1)
afkBtn.Font = Enum.Font.GothamBold
afkBtn.TextSize = 12
afkBtn.Parent = gui
makeCorner(afkBtn, 10)
makeStroke(afkBtn, Color3.fromRGB(255, 255, 255), 1.2)

afkBtn.MouseButton1Click:Connect(function()
	isAfk = not isAfk
	if isAfk then
		afkBtn.Text = "AFK IN LOBBY (Click to Join)"
		afkBtn.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
	else
		afkBtn.Text = "IN MATCH (Click for AFK)"
		afkBtn.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
	end
	Network.GetEvent("ToggleAFK"):FireServer(isAfk)
end)

-- 4.55 Day / Night Stadium Lighting Toggle
local isDayMode = false
local dayNightBtn = Instance.new("TextButton")
dayNightBtn.Size = UDim2.fromOffset(118, 38)
dayNightBtn.Position = UDim2.new(0, 206, 0, 16)
dayNightBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
dayNightBtn.Text = "NIGHT MODE"
dayNightBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
dayNightBtn.Font = Enum.Font.GothamBold
dayNightBtn.TextSize = 12
dayNightBtn.Parent = gui
makeCorner(dayNightBtn, 10)
makeStroke(dayNightBtn, Color3.fromRGB(56, 189, 248), 1.2)

dayNightBtn.MouseButton1Click:Connect(function()
	local Lighting = game:GetService("Lighting")
	isDayMode = not isDayMode
	if isDayMode then
		Lighting.ClockTime = 14.5
		dayNightBtn.Text = "DAY MODE"
		dayNightBtn.BackgroundColor3 = Color3.fromRGB(14, 116, 144)
	else
		Lighting.ClockTime = 21.0
		dayNightBtn.Text = "NIGHT MODE"
		dayNightBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	end
end)

-- 4.6 Global Chat Announcement Banner
local globalBanner = Instance.new("Frame")
globalBanner.Size = UDim2.fromOffset(620, 64)
globalBanner.Position = UDim2.new(0.5, -310, 0, 92)
globalBanner.BackgroundColor3 = Color3.fromRGB(88, 28, 135)
globalBanner.BackgroundTransparency = 0.08
globalBanner.Visible = false
globalBanner.Parent = gui
makeCorner(globalBanner, 12)
makeStroke(globalBanner, Color3.fromRGB(250, 204, 21), 2)

local globalLbl = Instance.new("TextLabel")
globalLbl.Size = UDim2.new(1, -24, 1, -10)
globalLbl.Position = UDim2.fromOffset(12, 5)
globalLbl.BackgroundTransparency = 1
globalLbl.Text = ""
globalLbl.TextColor3 = Color3.new(1, 1, 1)
globalLbl.Font = Enum.Font.GothamBlack
globalLbl.TextSize = 16
globalLbl.TextWrapped = true
globalLbl.Parent = globalBanner

Network.GetEvent("GlobalAnnouncement").OnClientEvent:Connect(function(sender: string, msg: string)
	globalLbl.Text = string.format("[GLOBAL - %s]: %s", tostring(sender), tostring(msg))
	globalBanner.Visible = true
	task.delay(6, function()
		globalBanner.Visible = false
	end)
end)

-- 5. HAMMER PANEL (Strictly for ninja373670 — labeled "Hammer", NOT "Admin Panel")
if isAdminUser then
	local hammerBtn = Instance.new("TextButton")
	hammerBtn.Size = UDim2.fromOffset(120, 38)
	hammerBtn.Position = UDim2.new(1, -320, 0, 16)
	hammerBtn.BackgroundColor3 = Color3.fromRGB(127, 29, 29)
	hammerBtn.Text = "HAMMER"
	hammerBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
	hammerBtn.Font = Enum.Font.GothamBlack
	hammerBtn.TextSize = 13
	hammerBtn.Parent = gui
	makeCorner(hammerBtn, 10)
	makeStroke(hammerBtn, Color3.fromRGB(250, 204, 21), 1.5)

	local hammerPanel = Instance.new("Frame")
	hammerPanel.Size = UDim2.fromOffset(340, 470)
	hammerPanel.Position = UDim2.new(0, 18, 0.5, -235)
	hammerPanel.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	hammerPanel.BackgroundTransparency = 0.04
	hammerPanel.Visible = false
	hammerPanel.Parent = gui
	makeCorner(hammerPanel, 14)
	makeStroke(hammerPanel, Color3.fromRGB(250, 204, 21), 2)

	local hTitle = Instance.new("TextLabel")
	hTitle.Size = UDim2.new(1, -20, 0, 36)
	hTitle.Position = UDim2.fromOffset(10, 6)
	hTitle.BackgroundTransparency = 1
	hTitle.Text = "HAMMER CONTROLS (ninja373670)"
	hTitle.TextColor3 = Color3.fromRGB(250, 204, 21)
	hTitle.Font = Enum.Font.GothamBlack
	hTitle.TextSize = 15
	hTitle.Parent = hammerPanel

	local hScroll = Instance.new("ScrollingFrame")
	hScroll.Size = UDim2.new(1, -20, 1, -52)
	hScroll.Position = UDim2.fromOffset(10, 44)
	hScroll.BackgroundTransparency = 1
	hScroll.ScrollBarThickness = 5
	hScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	hScroll.Parent = hammerPanel

	local hList = Instance.new("UIListLayout")
	hList.Padding = UDim.new(0, 6)
	hList.Parent = hScroll

	-- Global Chat Box
	local globalBox = Instance.new("TextBox")
	globalBox.Size = UDim2.new(1, -6, 0, 34)
	globalBox.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	globalBox.PlaceholderText = "Type Global Chat message..."
	globalBox.Text = ""
	globalBox.TextColor3 = Color3.new(1, 1, 1)
	globalBox.Font = Enum.Font.GothamSemibold
	globalBox.TextSize = 13
	globalBox.Parent = hScroll
	makeCorner(globalBox, 8)

	local sendGlobalBtn = Instance.new("TextButton")
	sendGlobalBtn.Size = UDim2.new(1, -6, 0, 34)
	sendGlobalBtn.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
	sendGlobalBtn.Text = "Send Global Chat"
	sendGlobalBtn.TextColor3 = Color3.new(1, 1, 1)
	sendGlobalBtn.Font = Enum.Font.GothamBold
	sendGlobalBtn.TextSize = 13
	sendGlobalBtn.Parent = hScroll
	makeCorner(sendGlobalBtn, 8)
	sendGlobalBtn.MouseButton1Click:Connect(function()
		if #globalBox.Text > 0 then
			Network.GetEvent("AdminCommand"):FireServer("GlobalChat", globalBox.Text)
			globalBox.Text = ""
		end
	end)

	local function addHammerBtn(label: string, color: Color3, cmd: string, arg: any)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -6, 0, 34)
		b.BackgroundColor3 = color
		b.Text = label
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.Parent = hScroll
		makeCorner(b, 8)
		b.MouseButton1Click:Connect(function()
			Network.GetEvent("AdminCommand"):FireServer(cmd, arg)
		end)
	end

	-- Disco Party + Raining Tacos (3 Min)
	addHammerBtn("Disco Party + Raining Tacos (3 Min)", Color3.fromRGB(219, 39, 119), "DiscoTacoParty", nil)
	addHammerBtn("Concert Party: Ronaldo, Messi & Neymar!", Color3.fromRGB(147, 51, 234), "ConcertParty", nil)
	addHammerBtn("Ragdoll Everyone!", Color3.fromRGB(220, 38, 38), "RagdollAll", nil)

	-- Give Player Coins Section
	local selectedCoinPlayer: Player? = player
	local coinTargetBtn = Instance.new("TextButton")
	coinTargetBtn.Size = UDim2.new(1, -6, 0, 32)
	coinTargetBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	coinTargetBtn.Text = "Coin Target: " .. player.DisplayName .. " (Click to Cycle)"
	coinTargetBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
	coinTargetBtn.Font = Enum.Font.GothamBold
	coinTargetBtn.TextSize = 12
	coinTargetBtn.Parent = hScroll
	makeCorner(coinTargetBtn, 8)
	coinTargetBtn.MouseButton1Click:Connect(function()
		local all = Players:GetPlayers()
		local idx = table.find(all, selectedCoinPlayer) or 0
		selectedCoinPlayer = all[(idx % #all) + 1]
		if selectedCoinPlayer then
			coinTargetBtn.Text = "Coin Target: " .. selectedCoinPlayer.DisplayName .. " (Click to Cycle)"
		end
	end)

	local coinRow = Instance.new("Frame")
	coinRow.Size = UDim2.new(1, -6, 0, 34)
	coinRow.BackgroundTransparency = 1
	coinRow.Parent = hScroll
	local coinRowLayout = Instance.new("UIListLayout")
	coinRowLayout.FillDirection = Enum.FillDirection.Horizontal
	coinRowLayout.Padding = UDim.new(0, 6)
	coinRowLayout.Parent = coinRow

	for _, amt in ipairs({ 100, 500, 1000 }) do
		local cb = Instance.new("TextButton")
		cb.Size = UDim2.new(0.32, 0, 1, 0)
		cb.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
		cb.Text = "+" .. amt .. " Coins"
		cb.TextColor3 = Color3.new(1, 1, 1)
		cb.Font = Enum.Font.GothamBold
		cb.TextSize = 12
		cb.Parent = coinRow
		makeCorner(cb, 8)
		cb.MouseButton1Click:Connect(function()
			if selectedCoinPlayer then
				Network.GetEvent("AdminCommand"):FireServer("GiveCoins", {
					TargetUserId = selectedCoinPlayer.UserId,
					Amount = amt,
				})
			end
		end)
	end

	addHammerBtn("Give Free Kick (Where I Stand)", Color3.fromRGB(217, 119, 6), "FreeKick", nil)
	addHammerBtn("Give Penalty (Home FC)", Color3.fromRGB(37, 99, 235), "PenaltyHome", nil)
	addHammerBtn("Give Penalty (Away United)", Color3.fromRGB(220, 38, 38), "PenaltyAway", nil)
	addHammerBtn("Reset Ball to Center", Color3.fromRGB(51, 65, 85), "ResetBall", nil)
	addHammerBtn("Skip / Next Match Phase", Color3.fromRGB(22, 163, 74), "SkipPhase", nil)
	addHammerBtn("+1 Goal Home", Color3.fromRGB(30, 64, 175), "AddGoalHome", nil)
	addHammerBtn("+1 Goal Away", Color3.fromRGB(153, 27, 27), "AddGoalAway", nil)
	addHammerBtn("Mode: 5v5 Fast-Paced", Color3.fromRGB(71, 85, 105), "SetMode", "5v5")
	addHammerBtn("Mode: 11v11 Competitive", Color3.fromRGB(71, 85, 105), "SetMode", "11v11")
	addHammerBtn("Stadium: Wembley Night", Color3.fromRGB(30, 41, 59), "SetStadium", "WembleyNight")
	addHammerBtn("Stadium: Golden Sunset", Color3.fromRGB(154, 52, 18), "SetStadium", "SunsetArena")
	addHammerBtn("Stadium: Alpine Snow", Color3.fromRGB(14, 116, 144), "SetStadium", "AlpineSnow")
	addHammerBtn("Stadium: Neon Cyber Dome", Color3.fromRGB(88, 28, 135), "SetStadium", "NeonCyber")

	local function toggleHammer()
		hammerPanel.Visible = not hammerPanel.Visible
	end
	hammerBtn.MouseButton1Click:Connect(toggleHammer)
	Network.GetEvent("OpenHammerPanel").OnClientEvent:Connect(toggleHammer)
	UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Enum.KeyCode.P then
			toggleHammer()
		end
	end)
end

-- Profile & Match Event Listeners
task.spawn(function()
	currentProfile = Network.GetFunction("GetProfile"):InvokeServer()
	if modal.Visible then
		renderTab()
	end
end)

Network.GetEvent("ProfileUpdated").OnClientEvent:Connect(function(prof)
	currentProfile = prof
	if modal.Visible then
		renderTab()
	end
end)

Network.GetEvent("MatchStateUpdate").OnClientEvent:Connect(function(state)
	if not state then
		return
	end
	homeLbl.Text = string.format("HOME  %d", state.HomeScore or 0)
	awayLbl.Text = string.format("%d  AWAY", state.AwayScore or 0)
	local mins = math.floor((state.TimeRemaining or 0) / 60)
	local secs = (state.TimeRemaining or 0) % 60
	clockLbl.Text = string.format("%02d:%02d  |  %s", mins, secs, tostring(state.Mode or "5v5"))
	statusLbl.Text = tostring(state.Status or "")
end)

Network.GetEvent("GoalScoredVFX").OnClientEvent:Connect(function(info)
	goalTitle.Text = "GOAL! " .. string.upper(tostring(info.ScoringTeam or ""))
	if info.AssisterName then
		goalSub.Text = string.format("Scored by %s  (Assist: %s)", info.ScorerName, info.AssisterName)
	else
		goalSub.Text = string.format("Scored by %s", tostring(info.ScorerName))
	end
	goalBanner.Visible = true
	task.delay(4.5, function()
		goalBanner.Visible = false
	end)
end)

RunService.RenderStepped:Connect(function()
	local pwr = (player:GetAttribute("KickCharge") :: number?) or 0
	local crv = (player:GetAttribute("KickCurve") :: number?) or 0
	local stm = (player:GetAttribute("Stamina") :: number?) or 100

	powerFill.Size = UDim2.fromScale(math.clamp(pwr, 0, 1), 1)
	powerFill.BackgroundColor3 = if pwr > 0.8 then Color3.fromRGB(239, 68, 68) else Color3.fromRGB(250, 204, 21)

	local curveNorm = (math.clamp(crv, -1, 1) + 1) * 0.5
	curveFill.Size = UDim2.fromScale(curveNorm, 1)

	staminaFill.Size = UDim2.fromScale(math.clamp(stm / Config.Stamina.Max, 0, 1), 1)
end)
