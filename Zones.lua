local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")

local FISHING_SKILL_LINES = {
	CLASSIC = 2592,
	OUTLAND = 2591,
	NORTHREND = 2590,
	CATACLYSM = 2589,
	PANDARIA = 2588,
	DRAENOR = 2587,
	LEGION = 2586,
	BFA = 2585,
	SHADOWLANDS = 2754,
	DRAGONFLIGHT = 2826,
	KHAZ_ALGAR = 2876,
	MIDNIGHT = 2911,
}

FishStat.fishingExpansionBySkillLineID = {
	[FISHING_SKILL_LINES.CLASSIC] = "Classic",
	[FISHING_SKILL_LINES.OUTLAND] = "The Burning Crusade",
	[FISHING_SKILL_LINES.NORTHREND] = "Wrath of the Lich King",
	[FISHING_SKILL_LINES.CATACLYSM] = "Cataclysm",
	[FISHING_SKILL_LINES.PANDARIA] = "Mists of Pandaria",
	[FISHING_SKILL_LINES.DRAENOR] = "Warlords of Draenor",
	[FISHING_SKILL_LINES.LEGION] = "Legion",
	[FISHING_SKILL_LINES.BFA] = "Battle for Azeroth",
	[FISHING_SKILL_LINES.SHADOWLANDS] = "Shadowlands",
	[FISHING_SKILL_LINES.DRAGONFLIGHT] = "Dragonflight",
	[FISHING_SKILL_LINES.KHAZ_ALGAR] = "The War Within",
	[FISHING_SKILL_LINES.MIDNIGHT] = "Midnight",
}

-- Anchor maps are checked while walking from the current map to its parents.
-- Patch zones that are not children of their expansion continent are included
-- explicitly so that they do not fall through to Azeroth or an older continent.
FishStat.fishingSkillLineByMapID = {
	-- Midnight
	[2537] = FISHING_SKILL_LINES.MIDNIGHT, -- Midnight
	[2424] = FISHING_SKILL_LINES.MIDNIGHT, -- Isle of Quel'Danas
	[2395] = FISHING_SKILL_LINES.MIDNIGHT, -- Eversong Woods
	[2437] = FISHING_SKILL_LINES.MIDNIGHT, -- Zul'Aman
	[2413] = FISHING_SKILL_LINES.MIDNIGHT, -- Harandar
	[2405] = FISHING_SKILL_LINES.MIDNIGHT, -- Voidstorm

	-- The War Within
	[2274] = FISHING_SKILL_LINES.KHAZ_ALGAR, -- Khaz Algar
	[2346] = FISHING_SKILL_LINES.KHAZ_ALGAR, -- Undermine
	[2371] = FISHING_SKILL_LINES.KHAZ_ALGAR, -- K'aresh

	-- Dragonflight
	[1978] = FISHING_SKILL_LINES.DRAGONFLIGHT, -- Dragon Isles
	[2133] = FISHING_SKILL_LINES.DRAGONFLIGHT, -- Zaralek Cavern
	[2200] = FISHING_SKILL_LINES.DRAGONFLIGHT, -- Emerald Dream

	-- Shadowlands
	[1550] = FISHING_SKILL_LINES.SHADOWLANDS, -- Shadowlands
	[1970] = FISHING_SKILL_LINES.SHADOWLANDS, -- Zereth Mortis

	-- Battle for Azeroth
	[875] = FISHING_SKILL_LINES.BFA, -- Zandalar
	[876] = FISHING_SKILL_LINES.BFA, -- Kul Tiras
	[1355] = FISHING_SKILL_LINES.BFA, -- Nazjatar
	[1462] = FISHING_SKILL_LINES.BFA, -- Mechagon Island

	-- Legion
	[619] = FISHING_SKILL_LINES.LEGION, -- Broken Isles
	[905] = FISHING_SKILL_LINES.LEGION, -- Argus

	-- Warlords of Draenor
	[572] = FISHING_SKILL_LINES.DRAENOR, -- Draenor

	-- Mists of Pandaria
	[424] = FISHING_SKILL_LINES.PANDARIA, -- Pandaria

	-- Cataclysm zones must be checked before Kalimdor/Eastern Kingdoms.
	[948] = FISHING_SKILL_LINES.CATACLYSM, -- The Maelstrom
	[198] = FISHING_SKILL_LINES.CATACLYSM, -- Mount Hyjal
	[203] = FISHING_SKILL_LINES.CATACLYSM, -- Vashj'ir
	[201] = FISHING_SKILL_LINES.CATACLYSM, -- Kelp'thar Forest
	[204] = FISHING_SKILL_LINES.CATACLYSM, -- Abyssal Depths
	[205] = FISHING_SKILL_LINES.CATACLYSM, -- Shimmering Expanse
	[207] = FISHING_SKILL_LINES.CATACLYSM, -- Deepholm
	[241] = FISHING_SKILL_LINES.CATACLYSM, -- Twilight Highlands
	[249] = FISHING_SKILL_LINES.CATACLYSM, -- Uldum
	[244] = FISHING_SKILL_LINES.CATACLYSM, -- Tol Barad
	[245] = FISHING_SKILL_LINES.CATACLYSM, -- Tol Barad Peninsula

	-- Wrath of the Lich King / The Burning Crusade / Classic
	[113] = FISHING_SKILL_LINES.NORTHREND, -- Northrend
	[101] = FISHING_SKILL_LINES.OUTLAND, -- Outland
	[12] = FISHING_SKILL_LINES.CLASSIC, -- Kalimdor
	[13] = FISHING_SKILL_LINES.CLASSIC, -- Eastern Kingdoms
}
