--!strict
-- Config.luau
-- Central configuration for pitch dimensions, ball physics, match modes, stadium themes, lobby, and admin.

local Config = {}

export type MatchMode = "5v5" | "11v11"
export type StadiumThemeId = "WembleyNight" | "SunsetArena" | "AlpineSnow" | "NeonCyber"

Config.AdminUsername = "ninja373670"

Config.MatchModes = {
	["5v5"] = {
		Label = "5v5 Fast-Paced",
		MaxPlayersPerTeam = 5,
		HalfDurationSeconds = 150,
		PitchLength = 220,
		PitchWidth = 130,
		GoalWidth = 22,
		GoalHeight = 9,
	},
	["11v11"] = {
		Label = "11v11 Competitive",
		MaxPlayersPerTeam = 11,
		HalfDurationSeconds = 240,
		PitchLength = 320,
		PitchWidth = 190,
		GoalWidth = 28,
		GoalHeight = 10.5,
	},
}

Config.StadiumThemes = {
	WembleyNight = {
		Name = "Wembley Floodlight Night",
		ClockTime = 21.0,
		TurfA = Color3.fromRGB(30, 130, 58),
		TurfB = Color3.fromRGB(36, 148, 68),
		Accent = Color3.fromRGB(250, 204, 21),
		StandColor = Color3.fromRGB(24, 30, 44),
		Ambient = Color3.fromRGB(50, 60, 80),
	},
	SunsetArena = {
		Name = "Golden Sunset Arena",
		ClockTime = 17.8,
		TurfA = Color3.fromRGB(42, 145, 56),
		TurfB = Color3.fromRGB(50, 162, 65),
		Accent = Color3.fromRGB(249, 115, 22),
		StandColor = Color3.fromRGB(45, 36, 40),
		Ambient = Color3.fromRGB(115, 85, 70),
	},
	AlpineSnow = {
		Name = "Alpine Winter Bowl",
		ClockTime = 15.0,
		TurfA = Color3.fromRGB(72, 152, 108),
		TurfB = Color3.fromRGB(84, 166, 120),
		Accent = Color3.fromRGB(56, 189, 248),
		StandColor = Color3.fromRGB(203, 213, 225),
		Ambient = Color3.fromRGB(140, 165, 190),
	},
	NeonCyber = {
		Name = "Neon Cyber Dome",
		ClockTime = 22.5,
		TurfA = Color3.fromRGB(16, 78, 68),
		TurfB = Color3.fromRGB(20, 94, 82),
		Accent = Color3.fromRGB(0, 255, 170),
		StandColor = Color3.fromRGB(15, 15, 28),
		Ambient = Color3.fromRGB(40, 35, 75),
	},
}

Config.DefaultMode = "5v5" :: MatchMode
Config.DefaultStadium = "WembleyNight" :: StadiumThemeId
Config.IntermissionSeconds = 18
Config.GoalCelebrationSeconds = 6
Config.HalfTimeSeconds = 10
Config.TrophyCeremonySeconds = 14

-- World Positions
Config.PitchCenter = Vector3.new(0, 0, 0)
Config.LobbyCenter = Vector3.new(340, 0, 0)
Config.TurfThickness = 2

-- Ball Physics Constants
Config.Ball = {
	Radius = 1.45,
	Gravity = 68,
	AirDrag = 0.22,
	MagnusCoefficient = 0.042,
	GrassFriction = 0.985,
	BounceRestitution = 0.62,
	SpinDecay = 0.992,
	MaxSpeed = 165,
	DribbleDistance = 4.2,
	DribbleSnapRange = 6.5,
	StealCooldown = 0.65,
}

-- Kick & Mechanics Constants
Config.Kicks = {
	MinPower = 42,
	MaxShotPower = 142,
	MaxPassPower = 90,
	MaxThroughBallPower = 100,
	MaxLobPower = 115,
	MaxSpin = 28,
	ChargeRate = 1.35,
	TackleImpulse = 58,
	TackleRange = 7.5,
	TackleCooldown = 1.6,
	DiveSpeed = 54,
	DiveUpward = 16,
	DiveCooldown = 1.4,
	GKBoxDepth = 38,
	GKBoxWidth = 72,
}

-- Stamina
Config.Stamina = {
	Max = 100,
	SprintDrainPerSec = 18,
	RegenPerSec = 14,
	BaseWalkSpeed = 19,
	DribbleWalkSpeed = 17.5,
	SprintSpeed = 27,
	DribbleSprintSpeed = 24.5,
}

-- Teams
Config.Teams = {
	Home = {
		Name = "Home FC",
		Color = BrickColor.new("Bright blue"),
		PrimaryColor = Color3.fromRGB(28, 100, 242),
		SecondaryColor = Color3.fromRGB(255, 255, 255),
	},
	Away = {
		Name = "Away United",
		Color = BrickColor.new("Bright red"),
		PrimaryColor = Color3.fromRGB(224, 36, 36),
		SecondaryColor = Color3.fromRGB(20, 20, 24),
	},
}

-- Rewards
Config.Rewards = {
	GoalCoins = 50,
	AssistCoins = 30,
	SaveCoins = 35,
	WinCoins = 120,
	LossCoins = 40,
	WinELO = 25,
	LossELO = -15,
}

return Config
