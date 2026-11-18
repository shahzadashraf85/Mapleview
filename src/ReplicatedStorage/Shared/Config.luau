--!strict
-- Config.luau
-- Central configuration for pitch dimensions, ball physics, match modes, and controls.

local Config = {}

export type MatchMode = "5v5" | "11v11"

Config.MatchModes = {
	["5v5"] = {
		Label = "5v5 Fast-Paced",
		MaxPlayersPerTeam = 5,
		HalfDurationSeconds = 150, -- 2m 30s per half
		PitchLength = 220,
		PitchWidth = 130,
		GoalWidth = 22,
		GoalHeight = 9,
	},
	["11v11"] = {
		Label = "11v11 Competitive",
		MaxPlayersPerTeam = 11,
		HalfDurationSeconds = 240, -- 4m per half
		PitchLength = 320,
		PitchWidth = 190,
		GoalWidth = 28,
		GoalHeight = 10.5,
	},
}

Config.DefaultMode = "5v5" :: MatchMode
Config.IntermissionSeconds = 15
Config.GoalCelebrationSeconds = 6
Config.HalfTimeSeconds = 10
Config.TrophyCeremonySeconds = 14

-- Stadium origin (center of pitch surface)
Config.PitchCenter = Vector3.new(0, 0, 0)
Config.TurfThickness = 2

-- Ball Physics Constants
Config.Ball = {
	Radius = 1.45,
	Gravity = 68,              -- Studs/s^2 (tuned for crisp Roblox arc)
	AirDrag = 0.22,            -- Linear aerodynamic drag
	MagnusCoefficient = 0.042, -- Spin-to-curve acceleration factor
	GrassFriction = 0.985,     -- Ground roll damping per 60Hz tick
	BounceRestitution = 0.62,  -- Vertical bounce elasticity
	SpinDecay = 0.992,         -- Spin decay per tick
	MaxSpeed = 165,
	DribbleDistance = 4.2,     -- Studs in front of player when dribbling
	DribbleSnapRange = 6.5,    -- Range to pick up loose ball
	StealCooldown = 0.65,      -- Seconds after being tackled before re-grabbing
}

-- Kick & Mechanics Constants
Config.Kicks = {
	MinPower = 38,
	MaxShotPower = 138,
	MaxPassPower = 88,
	MaxThroughBallPower = 98,
	MaxLobPower = 112,
	MaxSpin = 28, -- rad/s equivalent for Magnus curve
	ChargeRate = 1.35, -- Full charge in ~0.75s
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
