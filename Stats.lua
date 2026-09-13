local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local KEY_SEP = "\0"
local MAX_MAP_PARENT_DEPTH = 20

--- Формирует ключ локации из зоны и подзоны.
-- @param zone string|nil название зоны (по умолчанию текущая)
-- @param subzone string|nil название подзоны (по умолчанию текущая)
-- @return string ключ `"зона\\0подзона"`
function FishStat:GetLocationKey(zone, subzone)
	zone = zone or GetZoneText() or ""
	subzone = subzone or GetSubZoneText() or ""
	return zone .. KEY_SEP .. subzone
end

--- Формирует отображаемое имя локации (зона или зона + подзона).
-- @param zone string|nil название зоны (по умолчанию текущая)
-- @param subzone string|nil название подзоны (по умолчанию текущая)
-- @return string локализованная подпись
function FishStat:GetLocationDisplayName(zone, subzone)
	zone = zone or GetZoneText() or ""
	subzone = subzone or GetSubZoneText() or ""
	if subzone ~= "" then
		return L["ZONE_SUBZONE"]:format(zone, subzone)
	end
	return L["ZONE_ONLY"]:format(zone)
end

--- Гарантирует наличие таблицы кэша навыка рыбной ловли в SavedVariables.
-- @return table|nil кэш `[skillLineID] = info`
function FishStat:EnsureFishingSkillCache()
	local char = self.db and self.db.char
	if not char then
		return nil
	end
	if type(char.fishingSkillCache) ~= "table" then
		char.fishingSkillCache = {}
	end
	return char.fishingSkillCache
end

--- Возвращает закэшированные данные навыка рыбной ловли по ID линии навыка.
-- @param skillLineID number|string|nil ID линии навыка
-- @return table|nil запись кэша
function FishStat:GetCachedFishingSkillInfo(skillLineID)
	local cache = self:EnsureFishingSkillCache()
	if not cache or not skillLineID then
		return nil
	end
	-- SavedVariables может превратить числовые ключи в строки между сессиями.
	return cache[skillLineID] or cache[tostring(skillLineID)]
end

--- Сохраняет данные навыка рыбной ловли в кэш персонажа.
-- @param skillLineID number|nil ID линии навыка
-- @param info table|nil данные навыка (`name`, `skillLevel`, `maxSkillLevel`, ...)
function FishStat:CacheFishingSkillInfo(skillLineID, info)
	if not skillLineID or not info then
		return
	end
	if not info.maxSkillLevel or info.maxSkillLevel <= 0 then
		return
	end

	local cache = self:EnsureFishingSkillCache()
	if not cache then
		return
	end

	local key = tostring(skillLineID)
	cache[key] = {
		name = info.name,
		skillLevel = info.skillLevel or 0,
		maxSkillLevel = info.maxSkillLevel,
		skillModifier = info.skillModifier or 0,
		skillLineID = skillLineID,
		expansionName = info.expansionName,
	}
	-- Удаляем устаревшую запись с числовым ключом, если она есть.
	if cache[skillLineID] and type(skillLineID) == "number" then
		cache[skillLineID] = nil
	end
end

--- Сравнивает названия навыков с учётом склонений и сокращённых форм.
-- @param a string|nil первое название
-- @param b string|nil второе название
-- @return boolean
-- @local
local function skillNamesMatch(a, b)
	if not a or not b then
		return false
	end
	a = strlower(strtrim(a))
	b = strlower(strtrim(b))
	if a == "" or b == "" then
		return false
	end
	if a == b then
		return true
	end
	-- «Классическая рыбная ловля» и «Рыбная ловля»
	if strfind(a, b, 1, true) or strfind(b, a, 1, true) then
		return true
	end
	-- Склонённые формы (ruRU |3-6(%s)|) имеют общий короткий байтовый префикс.
	local prefixLen = 8
	return #a >= prefixLen and #b >= prefixLen and strsub(a, 1, prefixLen) == strsub(b, 1, prefixLen)
end

--- Проверяет, похож ли новый уровень на обычный прирост навыка, а не на скачок другой профессии.
-- @param entry table|nil запись кэша навыка
-- @param newLevel number новый уровень
-- @return boolean
-- @local
local function isPlausibleSkillUp(entry, newLevel)
	if not entry then
		return false
	end
	local current = entry.skillLevel or 0
	if newLevel <= current then
		return false
	end
	-- Повышения навыка идут небольшими шагами; скачки другой профессии отбрасываем.
	if newLevel - current > 10 then
		return false
	end
	local maxSkill = entry.maxSkillLevel or 0
	if maxSkill > 0 and newLevel > maxSkill then
		return false
	end
	return true
end

--- Строит lua-паттерн из глобальной строки `ERR_SKILL_UP_SI`.
-- @param template string шаблон с `%s` и `%d`
-- @return string паттерн для `string.match`
-- @local
local function buildSkillUpPattern(template)
	-- ruRU: "|3-6(%s) повышается до %d." — в чате уже склонённое имя, без |3-6(...).
	template = template:gsub("|%d+%-%d+%((.-)%)", "%1")
	-- Строки чата часто без точки в конце, в отличие от глобальной строки.
	template = template:gsub("[%s%.]+$", "")
	local markS, markD = "\001", "\002"
	template = template:gsub("%%s", markS):gsub("%%d", markD)
	template = template:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	template = template:gsub(markS, "(.+)"):gsub(markD, "(%%d+)")
	return "^" .. template .. "%s*%.?$"
end

--- Разбирает сообщение чата о повышении навыка.
-- @param message string текст `CHAT_MSG_SKILL`
-- @return string|nil имя навыка
-- @return string|nil новый уровень
-- @local
local function parseSkillUpMessage(message)
	message = strtrim(message)
	message = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	message = message:gsub("|H.-|h(.-)|h", "%1")

	if ERR_SKILL_UP_SI then
		local template = ERR_SKILL_UP_SI:gsub("|%d+%-%d+%((.-)%)", "%1")
		local sPos = template:find("%%s", 1, true)
		local dPos = template:find("%%d", 1, true)
		local levelFirst = dPos and sPos and dPos < sPos
		local pattern = buildSkillUpPattern(ERR_SKILL_UP_SI)
		local first, second = message:match(pattern)
		if first and second then
			if levelFirst then
				return second, first
			end
			return first, second
		end
	end

	-- Запасные шаблоны без привязки к локали (точка в конце необязательна).
	local skillName, levelStr = message:match("^(.+)%s+повышается до%s+(%d+)%s*%.?$")
	if skillName then
		return skillName, levelStr
	end
	skillName, levelStr = message:match("^Your skill in%s+(.+)%s+has increased to%s+(%d+)%s*%.?$")
	if skillName then
		return skillName, levelStr
	end

	return nil, nil
end

--- Проверяет, относится ли имя навыка из чата к рыбной ловле.
-- @param skillName string|nil имя навыка
-- @return boolean
-- @local
local function isFishingSkillUpName(skillName)
	if not skillName then
		return false
	end
	if PROFESSIONS_FISHING and skillNamesMatch(PROFESSIONS_FISHING, skillName) then
		return true
	end
	local lower = strlower(skillName)
	-- Маркеры рыбной ловли в названиях навыков дополнений (enUS / ruRU).
	if strfind(lower, "fish", 1, true) or strfind(lower, "рыбн", 1, true) then
		return true
	end
	return false
end

--- Обновляет кэш навыка рыбной ловли по сообщению о повышении, если API уровней недоступен.
-- @param skillName string|nil имя навыка из чата
-- @param newLevel number|string|nil новый уровень
-- @return boolean true, если кэш обновлён
function FishStat:UpdateFishingSkillCacheFromSkillUp(skillName, newLevel)
	newLevel = tonumber(newLevel)
	if not skillName or not newLevel or newLevel <= 0 then
		return false
	end
	if not isFishingSkillUpName(skillName) then
		return false
	end

	local cache = self:EnsureFishingSkillCache()
	if not cache then
		return false
	end

	--- Повышает уровень записи кэша, если прирост правдоподобен.
	-- @param skillLineID number|string ID линии навыка
	-- @param entry table запись кэша
	-- @return boolean
	-- @local
	local function bump(skillLineID, entry)
		if not entry or not isPlausibleSkillUp(entry, newLevel) then
			return false
		end
		entry.skillLevel = newLevel
		-- Для последующего сопоставления сохраняем более полное имя из чата.
		if skillName and skillName ~= "" then
			entry.name = skillName
		end
		self:CacheFishingSkillInfo(skillLineID, entry)
		return true
	end

	local currentID = self:GetCurrentFishingSkillLineID()
	if currentID then
		local current = self:GetCachedFishingSkillInfo(currentID)
		if current and bump(currentID, current) then
			return true
		end
	end

	for key, entry in pairs(cache) do
		local skillLineID = entry.skillLineID or tonumber(key) or key
		if skillNamesMatch(entry.name, skillName) and bump(skillLineID, entry) then
			return true
		end
	end

	return false
end

--- Обработчик `CHAT_MSG_SKILL`: обновляет кэш рыбной ловли и интерфейс.
-- @param _ string имя события (не используется)
-- @param message string текст сообщения
function FishStat:OnChatMsgSkill(_, message)
	if type(message) ~= "string" or message == "" then
		return
	end

	local skillName, levelStr = parseSkillUpMessage(message)
	if self:UpdateFishingSkillCacheFromSkillUp(skillName, levelStr) then
		self:RefreshUI()
	end
end

--- Определяет линию навыка рыбной ловли текущего континента по карте игрока.
-- @return number|nil ID линии навыка дополнения
function FishStat:GetCurrentFishingSkillLineID()
	if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetMapInfo then
		return nil
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	local visited = {}

	for _ = 1, MAX_MAP_PARENT_DEPTH do
		if not mapID or mapID == 0 or visited[mapID] then
			break
		end

		local skillLineID = self.fishingSkillLineByMapID[mapID]
		if skillLineID then
			return skillLineID
		end

		visited[mapID] = true
		local mapInfo = C_Map.GetMapInfo(mapID)
		mapID = mapInfo and mapInfo.parentMapID
	end

	return nil
end

--- Возвращает сведения о навыке рыбной ловли текущего континента (с кэшем и запасным API).
-- @return table|nil `{name, skillLevel, maxSkillLevel, skillModifier, skillLineID, expansionName, levelsUnknown}`
function FishStat:GetFishingSkillInfo()
	local _, _, _, fishing = GetProfessions()
	if not fishing then
		return nil
	end

	local skillLineID = self:GetCurrentFishingSkillLineID()
	if skillLineID
		and C_TradeSkillUI
		and C_TradeSkillUI.GetProfessionInfoBySkillLineID
	then
		local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
		local expansionName = self.fishingExpansionBySkillLineID[skillLineID]
		local maxSkillLevel = info and info.maxSkillLevel or 0

		if info and info.professionName and maxSkillLevel > 0 then
			local result = {
				name = info.professionName,
				skillLevel = info.skillLevel or 0,
				maxSkillLevel = maxSkillLevel,
				skillModifier = info.skillModifier or 0,
				skillLineID = skillLineID,
				expansionName = expansionName,
			}
			self:CacheFishingSkillInfo(skillLineID, result)
			return result
		end

		local cached = self:GetCachedFishingSkillInfo(skillLineID)
		if cached then
			return cached
		end

		return {
			name = info and info.professionName or nil,
			skillLineID = skillLineID,
			expansionName = expansionName,
			levelsUnknown = true,
		}
	end

	local name, _, skillLevel, maxSkillLevel, _, _, _, skillModifier = GetProfessionInfo(fishing)
	return {
		name = name,
		skillLevel = skillLevel or 0,
		maxSkillLevel = maxSkillLevel or 0,
		skillModifier = skillModifier or 0,
	}
end

--- Форматирует строку навыка рыбной ловли для заголовка окна, с суффиксом яда.
-- @param info table|nil данные навыка; если nil, запрашиваются заново
-- @return string текст заголовка
-- @return boolean показывать ли подсказку о недоступных уровнях
function FishStat:FormatFishingSkill(info)
	info = info or self:GetFishingSkillInfo()
	--- Добавляет к тексту суффикс запаса яда.
	-- @param text string текст навыка
	-- @param showUnavailableTip boolean показывать ли подсказку
	-- @return string
	-- @return boolean
	-- @local
	local function withVenom(text, showUnavailableTip)
		return text .. self:FormatVenomSuffix(), showUnavailableTip
	end
	if not info then
		return withVenom(L["FISHING_UNKNOWN"], false)
	end

	if info.levelsUnknown then
		if info.name then
			return withVenom(L["FISHING_SKILL_UNAVAILABLE"]:format(info.name), true)
		end
		return withVenom(L["FISHING_UNKNOWN"], false)
	end

	local text
	if info.expansionName and info.name then
		text = ("%s %d/%d"):format(
			info.name,
			info.skillLevel,
			info.maxSkillLevel
		)
	else
		text = L["FISHING_SKILL"]:format(info.skillLevel, info.maxSkillLevel)
	end
	if info.skillModifier and info.skillModifier > 0 then
		text = text .. L["FISHING_BONUS"]:format(info.skillModifier)
	end
	return withVenom(text, false)
end

--- Возвращает или создаёт корзину улова для локации в указанном хранилище.
-- @param store table сессия или общая история
-- @param key string ключ локации
-- @param displayName string|nil отображаемое имя локации
-- @return table корзина предметов
-- @local
local function ensureBucket(store, key, displayName)
	local bucket = store[key]
	if not bucket then
		bucket = { _name = displayName }
		store[key] = bucket
	elseif displayName and bucket._name ~= displayName then
		bucket._name = displayName
	end
	return bucket
end

--- Добавляет пойманный предмет в сессию и в общую историю текущей локации.
-- @param itemID number|nil ID предмета
-- @param quantity number количество
-- @param itemName string|nil имя
-- @param itemLink string|nil ссылка
-- @param quality number|nil качество
-- @param texture string|number|nil иконка
function FishStat:AddCatch(itemID, quantity, itemName, itemLink, quality, texture)
	if not itemID or quantity <= 0 then
		return
	end

	local zone = GetZoneText() or ""
	local subzone = GetSubZoneText() or ""
	local key = self:GetLocationKey(zone, subzone)
	local displayName = self:GetLocationDisplayName(zone, subzone)

	local sessionBucket = ensureBucket(self.session, key, displayName)
	local totalBucket = ensureBucket(self.db.char.total, key, displayName)

	--- Добавляет предмет в корзину локации, обновляя счётчик и метаданные.
	-- @param bucket table корзина локации
	-- @local
	local function addTo(bucket)
		local entry = bucket[itemID]
		if type(entry) ~= "table" then
			local oldCount = type(entry) == "number" and entry or 0
			entry = {
				count = oldCount,
				name = itemName,
				link = itemLink,
				quality = quality,
				texture = texture,
			}
			bucket[itemID] = entry
		end
		entry.count = (entry.count or 0) + quantity
		entry.name = itemName or entry.name
		entry.link = itemLink or entry.link
		entry.quality = quality or entry.quality
		entry.texture = texture or entry.texture
	end

	addTo(sessionBucket)
	addTo(totalBucket)
end

--- Обрабатывает рыболовный лут из окна добычи; при пустых слотах включает разбор чата.
function FishStat:ProcessFishingLoot()
	if self.lootHandled then
		return
	end
	if not IsFishingLoot or not IsFishingLoot() then
		return
	end

	-- Если слоты уже пусты (быстрый автолут), переключаемся на разбор строк чата
	self.expectFishingChat = true
	self.expectFishingChatUntil = GetTime() + 2

	local gotAny = false
	local numSlots = GetNumLootItems() or 0
	for i = 1, numSlots do
		local texture, itemName, quantity, currencyID, quality = GetLootSlotInfo(i)
		if not currencyID and quantity and quantity > 0 then
			local link = GetLootSlotLink(i)
			local itemID
			if link then
				itemID = tonumber(link:match("item:(%d+)"))
			end
			if itemID then
				self:AddCatch(itemID, quantity, itemName, link, quality, texture)
				gotAny = true
			end
		end
	end

	if gotAny then
		self.lootHandled = true
		self.expectFishingChat = false
		self:RefreshUI()
		self:ScheduleVenomRescan()
	end
end

--- Извлекает текстовый префикс до первого `%s` или `%d` из формата лута.
-- @param fmt string|nil глобальная строка формата
-- @return string|nil префикс
-- @local
local function formatPrefix(fmt)
	if type(fmt) ~= "string" then
		return nil
	end
	return fmt:match("^(.-)%%[sd]")
end

local selfLootPrefixes

--- Возвращает кэшированный список префиксов сообщений о собственной добыче.
-- @return table массив префиксов
-- @local
local function getSelfLootPrefixes()
	if selfLootPrefixes then
		return selfLootPrefixes
	end
	selfLootPrefixes = {}
	local formats = {
		LOOT_ITEM_SELF,
		LOOT_ITEM_SELF_MULTIPLE,
		LOOT_ITEM_PUSHED_SELF,
		LOOT_ITEM_PUSHED_SELF_MULTIPLE,
	}
	for _, fmt in ipairs(formats) do
		local prefix = formatPrefix(fmt)
		if prefix and prefix ~= "" then
			selfLootPrefixes[#selfLootPrefixes + 1] = prefix
		end
	end
	return selfLootPrefixes
end

--- Проверяет, является ли сообщение чата собственной добычей игрока.
-- @param message string текст чата
-- @return boolean
-- @local
local function isSelfLootMessage(message)
	for _, prefix in ipairs(getSelfLootPrefixes()) do
		if message:sub(1, #prefix) == prefix or message:find(prefix, 1, true) then
			return true
		end
	end
	return false
end

--- Разбирает сообщение о собственной добыче: ID, количество, имя, ссылка, качество, иконка.
-- @param message string текст чата
-- @return number|nil itemID
-- @return number|nil quantity
-- @return string|nil itemName
-- @return string|nil link
-- @return number|nil quality
-- @return string|number|nil texture
-- @local
local function parseSelfLootMessage(message)
	if type(message) ~= "string" or not isSelfLootMessage(message) then
		return nil
	end

	local link = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
	if not link then
		return nil
	end

	local itemID = tonumber(link:match("item:(%d+)"))
	if not itemID then
		return nil
	end

	local quantity = tonumber(message:match(".-|r.-x(%d+)")) or tonumber(message:match("x(%d+)")) or 1
	local itemName = link:match("%[(.-)%]")
	local quality, texture = 1, nil

	if C_Item and C_Item.GetItemInfoInstant then
		texture = select(5, C_Item.GetItemInfoInstant(itemID))
	end
	if C_Item and C_Item.GetItemQualityByID then
		quality = C_Item.GetItemQualityByID(itemID) or 1
	elseif not texture then
		local _, _, itemQuality, _, _, _, _, _, _, tex = GetItemInfo(itemID)
		quality = itemQuality or 1
		texture = tex
	end

	return itemID, quantity, itemName, link, quality, texture
end

--- Запасной учёт рыболовного улова из `CHAT_MSG_LOOT`, когда слоты окна добычи уже пусты.
-- @param message string текст сообщения о добыче
function FishStat:ProcessFishingChatLoot(message)
	-- Разбор чата только если слоты окна добычи уже пусты после автолута
	if self.lootHandled or not self.expectFishingChat then
		return
	end
	if GetTime() > (self.expectFishingChatUntil or 0) then
		self.expectFishingChat = false
		return
	end

	local itemID, quantity, itemName, link, quality, texture = parseSelfLootMessage(message)
	if not itemID then
		return
	end

	self:AddCatch(itemID, quantity, itemName, link, quality, texture)
	-- Продлеваем окно ожидания чата: за один заброс может прийти несколько предметов
	self.expectFishingChatUntil = GetTime() + 1.5
	self:RefreshUI()
	self:ScheduleVenomRescan()
end

--- Суммирует количество предметов в корзине локации.
-- @param bucket table|nil корзина локации
-- @return number суммарное количество
-- @local
local function countBucketTotal(bucket)
	if not bucket then
		return 0
	end
	local total = 0
	for itemID, entry in pairs(bucket) do
		if type(itemID) == "number" then
			if type(entry) == "table" then
				total = total + (entry.count or 0)
			elseif type(entry) == "number" then
				total = total + entry
			end
		end
	end
	return total
end

--- Добавляет предметы корзины в объединённую таблицу по `itemID`.
-- @param bucket table|nil корзина локации
-- @param merged table аккумулятор `[itemID] = {count, name, link, quality, texture}`
-- @local
local function accumulateBucket(bucket, merged)
	if not bucket then
		return
	end
	for itemID, entry in pairs(bucket) do
		if type(itemID) == "number" then
			local count, name, link, quality, texture
			if type(entry) == "table" then
				count = entry.count or 0
				name = entry.name or ("item:" .. itemID)
				link = entry.link
				quality = entry.quality or 1
				texture = entry.texture
			elseif type(entry) == "number" then
				count = entry
				name = "item:" .. itemID
				quality = 1
			else
				count = 0
			end

			if count > 0 then
				local existing = merged[itemID]
				if existing then
					existing.count = existing.count + count
				else
					merged[itemID] = {
						count = count,
						name = name,
						link = link,
						quality = quality,
						texture = texture,
					}
				end
			end
		end
	end
end

--- Строит список улова для интерфейса: итог, предметы, хлам и цены сессии.
-- @param useSession boolean true — сессия, false — общая история
-- @return table массив строк `{kind, name, count, percent, ...}`
function FishStat:GetCatchList(useSession)
	local key = self:GetLocationKey()
	local store = useSession and self.session or self.db.char.total
	local showAll = useSession and self.db.char.window.showAllSession

	local merged = {}
	if showAll then
		for _, bucket in pairs(store) do
			if type(bucket) == "table" then
				accumulateBucket(bucket, merged)
			end
		end
	else
		accumulateBucket(store[key], merged)
	end

	local items = {}
	local total = 0
	local junkCount = 0

	for itemID, entry in pairs(merged) do
		local count = entry.count or 0
		total = total + count
		-- Enum.ItemQuality.Poor = 0 (серый хлам)
		if (entry.quality or 1) == 0 then
			junkCount = junkCount + count
		else
			items[#items + 1] = {
				kind = "item",
				itemID = itemID,
				count = count,
				name = entry.name,
				link = entry.link,
				quality = entry.quality,
				texture = entry.texture,
			}
		end
	end

	if total <= 0 then
		return {}
	end

	table.sort(items, function(a, b)
		if a.count == b.count then
			return (a.name or "") < (b.name or "")
		end
		return a.count > b.count
	end)

	--- Доля количества от общего улова в процентах.
	-- @param count number количество
	-- @return number процент
	-- @local
	local function pct(count)
		return (count / total) * 100
	end

	-- В сессии по одной зоне в скобках показываем общий улов зоны за всё время
	local zoneTotal
	if useSession and not showAll then
		zoneTotal = countBucketTotal(self.db.char.total[key])
	end

	local list = {
		{
			kind = "total",
			name = L["CATCH_TOTAL"],
			count = total,
			zoneTotal = zoneTotal,
			percent = 100,
			quality = 1,
			texture = "Interface\\Icons\\INV_Misc_Fish_02",
		},
	}

	for _, item in ipairs(items) do
		item.percent = pct(item.count)
		list[#list + 1] = item
	end

	if junkCount > 0 then
		list[#list + 1] = {
			kind = "junk",
			name = L["JUNK_TOTAL"],
			count = junkCount,
			percent = pct(junkCount),
			quality = 0,
			texture = "Interface\\Icons\\INV_Misc_QuestionMark",
		}
	end

	-- Только для сессии: цены Auctionator (без хлама, персональных и квестовых предметов)
	if useSession and self:IsAuctionatorReady() then
		local sessionValue = 0
		local bindCache = {}

		for _, item in ipairs(items) do
			local cached = bindCache[item.itemID]
			if not cached then
				cached = { bindType = self:GetItemBindType(item.itemID) }
				bindCache[item.itemID] = cached
			end

			if self:IsPricableItem(item.quality, cached.bindType) then
				local unitPrice = self:GetUnitAuctionPrice(item.itemID)
				if unitPrice then
					item.unitPrice = unitPrice
					item.lineValue = unitPrice * item.count
					sessionValue = sessionValue + item.lineValue
				end
			end
		end

		if sessionValue > 0 then
			list[1].sessionValue = sessionValue
		end
	end

	return list
end

--- Сбрасывает статистику текущей сессии и исключения оценки инвентаря.
function FishStat:ResetSession()
	wipe(self.session)
	if self.inventoryValueExcluded then
		wipe(self.inventoryValueExcluded)
	end
	self:RefreshUI()
end
