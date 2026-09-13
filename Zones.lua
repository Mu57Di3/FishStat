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

-- Якорные карты проверяются при подъёме от текущей карты к родителям.
-- Зоны патчей, которые не являются детьми континента дополнения, заданы
-- явно, чтобы они не попадали в Азерот или более старый континент.
FishStat.fishingSkillLineByMapID = {
	-- Полночь
	[2537] = FISHING_SKILL_LINES.MIDNIGHT, -- Полночь
	[2424] = FISHING_SKILL_LINES.MIDNIGHT, -- Остров Кель'Данас
	[2395] = FISHING_SKILL_LINES.MIDNIGHT, -- Леса Вечной Песни
	[2437] = FISHING_SKILL_LINES.MIDNIGHT, -- Зул'Аман
	[2413] = FISHING_SKILL_LINES.MIDNIGHT, -- Харандар
	[2405] = FISHING_SKILL_LINES.MIDNIGHT, -- Буря Бездны

	-- Война внутри
	[2274] = FISHING_SKILL_LINES.KHAZ_ALGAR, -- Каз Алгар
	[2346] = FISHING_SKILL_LINES.KHAZ_ALGAR, -- Нижняя Шахта
	[2371] = FISHING_SKILL_LINES.KHAZ_ALGAR, -- К'ареш

	-- Драконы
	[1978] = FISHING_SKILL_LINES.DRAGONFLIGHT, -- Драконьи острова
	[2133] = FISHING_SKILL_LINES.DRAGONFLIGHT, -- Пещера Заралек
	[2200] = FISHING_SKILL_LINES.DRAGONFLIGHT, -- Изумрудный Сон

	-- Темные Земли
	[1550] = FISHING_SKILL_LINES.SHADOWLANDS, -- Темные Земли
	[1970] = FISHING_SKILL_LINES.SHADOWLANDS, -- Зерет Мортис

	-- Битва за Азерот
	[875] = FISHING_SKILL_LINES.BFA, -- Зандалар
	[876] = FISHING_SKILL_LINES.BFA, -- Кул-Тирас
	[1355] = FISHING_SKILL_LINES.BFA, -- Назжатар
	[1462] = FISHING_SKILL_LINES.BFA, -- Остров Мехагон

	-- Легион
	[619] = FISHING_SKILL_LINES.LEGION, -- Расколотые острова
	[905] = FISHING_SKILL_LINES.LEGION, -- Аргус

	-- Дренор
	[572] = FISHING_SKILL_LINES.DRAENOR, -- Дренор

	-- Пандария
	[424] = FISHING_SKILL_LINES.PANDARIA, -- Пандария

	-- Зоны Катаклизма нужно проверять раньше Калимдора и Восточных королевств.
	[948] = FISHING_SKILL_LINES.CATACLYSM, -- Водоворот
	[198] = FISHING_SKILL_LINES.CATACLYSM, -- Гора Хиджал
	[203] = FISHING_SKILL_LINES.CATACLYSM, -- Вайш'ир
	[201] = FISHING_SKILL_LINES.CATACLYSM, -- Лес Келп'тар
	[204] = FISHING_SKILL_LINES.CATACLYSM, -- Бездонные глубины
	[205] = FISHING_SKILL_LINES.CATACLYSM, -- Мерцающий простор
	[207] = FISHING_SKILL_LINES.CATACLYSM, -- Подземье
	[241] = FISHING_SKILL_LINES.CATACLYSM, -- Сумеречное нагорье
	[249] = FISHING_SKILL_LINES.CATACLYSM, -- Ульдум
	[244] = FISHING_SKILL_LINES.CATACLYSM, -- Тол Барад
	[245] = FISHING_SKILL_LINES.CATACLYSM, -- Полуостров Тол Барад

	-- Гнев Короля-лича / The Burning Crusade / Классика
	[113] = FISHING_SKILL_LINES.NORTHREND, -- Нордскол
	[101] = FISHING_SKILL_LINES.OUTLAND, -- Запределье
	[12] = FISHING_SKILL_LINES.CLASSIC, -- Калимдор
	[13] = FISHING_SKILL_LINES.CLASSIC, -- Восточные королевства
}
