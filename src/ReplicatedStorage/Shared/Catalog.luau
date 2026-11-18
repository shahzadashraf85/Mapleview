--!strict
-- Catalog.luau
-- Unlockable Custom Kits, Celebrations, and Dream Squad Formations.

local Catalog = {}

export type KitItem = {
	Id: string,
	Name: string,
	Price: number,
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Description: string,
}

export type CelebrationItem = {
	Id: string,
	Name: string,
	Price: number,
	Duration: number,
	Description: string,
}

Catalog.Kits = {
	{
		Id = "classic_striker",
		Name = "Classic Striker",
		Price = 0,
		Primary = Color3.fromRGB(30, 100, 240),
		Secondary = Color3.fromRGB(255, 255, 255),
		Accent = Color3.fromRGB(250, 204, 21),
		Description = "Standard club kit with crisp white trim.",
	},
	{
		Id = "royal_madrid",
		Name = "Galactico Gold",
		Price = 150,
		Primary = Color3.fromRGB(245, 245, 250),
		Secondary = Color3.fromRGB(212, 175, 55),
		Accent = Color3.fromRGB(30, 41, 59),
		Description = "Championship white with royal gold accents.",
	},
	{
		Id = "midnight_neon",
		Name = "Midnight Neon",
		Price = 250,
		Primary = Color3.fromRGB(15, 23, 42),
		Secondary = Color3.fromRGB(0, 255, 170),
		Accent = Color3.fromRGB(56, 189, 248),
		Description = "Stealth obsidian jersey with electric mint trim.",
	},
	{
		Id = "crimson_inferno",
		Name = "Crimson Inferno",
		Price = 300,
		Primary = Color3.fromRGB(185, 28, 28),
		Secondary = Color3.fromRGB(251, 146, 60),
		Accent = Color3.fromRGB(255, 255, 255),
		Description = "Fiery red and ember orange matchday kit.",
	},
	{
		Id = "samba_legacy",
		Name = "Samba Legacy",
		Price = 400,
		Primary = Color3.fromRGB(250, 204, 21),
		Secondary = Color3.fromRGB(22, 163, 74),
		Accent = Color3.fromRGB(29, 78, 216),
		Description = "Iconic canary gold and emerald green.",
	},
}

Catalog.Celebrations = {
	{
		Id = "knee_slide",
		Name = "Corner Knee Slide",
		Price = 0,
		Duration = 2.6,
		Description = "Slide across the turf toward the corner flag.",
	},
	{
		Id = "siuuu_leap",
		Name = "Championship Leap",
		Price = 120,
		Duration = 2.4,
		Description = "Soaring 180-spin jump with a power landing.",
	},
	{
		Id = "backflip",
		Name = "Acrobatic Backflip",
		Price = 220,
		Duration = 2.2,
		Description = "High-flying mid-air backflip in front of the stands.",
	},
	{
		Id = "trophy_lift",
		Name = "Imaginary Trophy Lift",
		Price = 350,
		Duration = 3.0,
		Description = "Hoist the championship cup high above your head.",
	},
}

Catalog.Formations = {
	"4-3-3 Attack",
	"4-4-2 Classic",
	"3-5-2 Wingplay",
	"1-2-1 Diamond (5v5)",
	"2-1-1 Sweeper (5v5)",
}

function Catalog.GetKit(id: string): KitItem?
	for _, kit in ipairs(Catalog.Kits) do
		if kit.Id == id then
			return kit
		end
	end
	return nil
end

function Catalog.GetCelebration(id: string): CelebrationItem?
	for _, cel in ipairs(Catalog.Celebrations) do
		if cel.Id == id then
			return cel
		end
	end
	return nil
end

return Catalog
