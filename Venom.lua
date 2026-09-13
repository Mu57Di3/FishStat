local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local COILED_HUNTRESS_ID = 244790
-- Слоты FISHINGTOOLSLOT, FISHINGGEAR0SLOT, FISHINGGEAR1SLOT
local FISHING_SLOTS = { 28, 29, 30 }

-- Строки подсказки: "+ 42 Venom" / "+ 42 к запасам яда"
-- Без якоря ^: характеристика может стоять в середине строки «Если на персонаже:».
local VENOM_PATTERNS = {
	"%+%s*(%d+)%s+Venom",
	"%+%s*(%d+)%s+к%s+запас",
}

local cachedVenom
local lastDataInstanceID
local rescanTimerA
local rescanTimerB
local scannerTooltip

--- Создаёт `ItemLocation` для слота экипировки.
-- @param slot number|nil индекс слота
-- @return ItemLocation|nil
-- @local
local function getItemLocation(slot)
	if not slot or not ItemLocation or not ItemLocation.CreateFromEquipmentSlot then
		return nil
	end
	return ItemLocation:CreateFromEquipmentSlot(slot)
end

--- Проверяет, есть ли предмет в указанном `ItemLocation`.
-- @param loc ItemLocation|nil
-- @return boolean
-- @local
local function locationHasItem(loc)
	return loc and C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)
end

--- Возвращает ID предмета в слоте экипировки и его `ItemLocation`.
-- @param slot number индекс слота
-- @return number|nil itemID
-- @return ItemLocation|nil loc
-- @local
local function getEquippedItemID(slot)
	local loc = getItemLocation(slot)
	if locationHasItem(loc) then
		if C_Item.GetItemID then
			local id = C_Item.GetItemID(loc)
			if id then
				return id, loc
			end
		end
		if C_Item.GetItemLink then
			local link = C_Item.GetItemLink(loc)
			if link then
				return tonumber(link:match("item:(%d+)")), loc
			end
		end
	end

	-- API слотов экипировки (не контейнеров сумок).
	if GetInventoryItemID then
		local id = GetInventoryItemID("player", slot)
		if id then
			return id, loc
		end
	end
	if GetInventoryItemLink then
		local link = GetInventoryItemLink("player", slot)
		if link then
			return tonumber(link:match("item:(%d+)")), loc
		end
	end
	return nil, loc
end

--- Ищет слот рыболовной экипировки с «Свитой охотницей».
-- @return number|nil слот
-- @return ItemLocation|nil loc
-- @local
local function getCoiledHuntressSlot()
	for _, slot in ipairs(FISHING_SLOTS) do
		local itemID, loc = getEquippedItemID(slot)
        if itemID == COILED_HUNTRESS_ID then
			return slot, loc
		end
	end
	return nil
end

--- Удаляет цветовые коды, текстуры и лишние пробелы из текста подсказки.
-- @param text string|nil исходный текст
-- @return string|nil очищенный текст
-- @local
local function stripMarkup(text)
	if not text then
		return nil
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|A:.-|a", ""):gsub("|T.-|t", "")
	text = text:gsub("\194\160", " ")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text
end

--- Извлекает запас яда из строки текста подсказки.
-- @param text string|nil строка подсказки
-- @return number|nil количество яда
-- @local
local function parseVenomFromText(text)
	text = stripMarkup(text)
	if not text or text == "" then
		return nil
	end
	for _, pattern in ipairs(VENOM_PATTERNS) do
		local n = text:match(pattern)
		if n then
			return tonumber(n)
		end
	end
	return nil
end

--- Добавляет текстовые поля строки подсказки в список частей.
-- @param parts table массив строк
-- @param line table строка данных подсказки
-- @local
local function appendLineTexts(parts, line)
	if not line then
		return
	end
	if TooltipUtil and TooltipUtil.SurfaceArgs then
		TooltipUtil.SurfaceArgs(line)
	end
	if line.leftText then
		parts[#parts + 1] = line.leftText
	end
	if line.rightText then
		parts[#parts + 1] = line.rightText
	end
	if line.args then
		for _, arg in ipairs(line.args) do
			if type(arg.stringVal) == "string" then
				parts[#parts + 1] = arg.stringVal
			elseif type(arg.intVal) == "number" then
				parts[#parts + 1] = tostring(arg.intVal)
			end
		end
	end
end

--- Разбирает запас яда из структурированных данных подсказки `C_TooltipInfo`.
-- @param data table|nil данные подсказки
-- @return number|nil количество яда
-- @local
local function parseVenomFromTooltip(data)
	if not data then
		return nil
	end
	if TooltipUtil and TooltipUtil.SurfaceArgs then
		TooltipUtil.SurfaceArgs(data)
	end
	if not data.lines then
		return nil
	end
	local parts = {}
	for _, line in ipairs(data.lines) do
		appendLineTexts(parts, line)
		local value = parseVenomFromText(line.leftText) or parseVenomFromText(line.rightText)
		if value ~= nil then
			return value
		end
	end
	return parseVenomFromText(table.concat(parts, " "))
end

--- Возвращает скрытый GameTooltip для сканирования текста экипировки.
-- @return Frame сканер-подсказка
-- @local
local function getScannerTooltip()
	if scannerTooltip then
		return scannerTooltip
	end
	scannerTooltip = CreateFrame("GameTooltip", "FishStatVenomScanner", nil, "GameTooltipTemplate")
	scannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	return scannerTooltip
end

--- Разбирает запас яда через скрытый GameTooltip (запасной способ).
-- @param slot number|nil слот экипировки
-- @param loc ItemLocation|nil расположение предмета
-- @return number|nil количество яда
-- @local
local function parseVenomFromScanner(slot, loc)
	local tip = getScannerTooltip()
	tip:ClearLines()
	if slot and tip.SetInventoryItem then
		tip:SetInventoryItem("player", slot)
	elseif loc and C_Item and C_Item.GetItemLink and tip.SetHyperlink then
		local link = C_Item.GetItemLink(loc)
		if link then
			tip:SetHyperlink(link)
		end
	else
		return nil
	end
	local parts = {}
	local n = tip:NumLines() or 0
	for i = 1, n do
		local left = _G["FishStatVenomScannerTextLeft" .. i]
		local right = _G["FishStatVenomScannerTextRight" .. i]
		local leftText = left and left:GetText()
		local rightText = right and right:GetText()
		if leftText then
			parts[#parts + 1] = leftText
		end
		if rightText then
			parts[#parts + 1] = rightText
		end
		local value = parseVenomFromText(leftText) or parseVenomFromText(rightText)
		if value ~= nil then
			return value
		end
	end
	return parseVenomFromText(table.concat(parts, " "))
end

--- Собирает кандидатов `C_TooltipInfo` для слота «Свитой охотницы».
-- @param slot number|nil слот экипировки
-- @param loc ItemLocation|nil расположение предмета
-- @return table список данных подсказок
-- @local
local function tooltipCandidates(slot, loc)
	local list = {}
	--- Добавляет результат геттера в список кандидатов, если он не пуст.
	-- @param getter function|nil функция, возвращающая данные подсказки
	-- @local
	local function add(getter)
		if getter then
			local data = getter()
			if data then
				list[#list + 1] = data
			end
		end
	end
	if C_TooltipInfo then
		if slot and C_TooltipInfo.GetInventoryItem then
			add(function()
				return C_TooltipInfo.GetInventoryItem("player", slot)
			end)
		end
		if loc and locationHasItem(loc) and C_Item.GetItemGUID then
			local guid = C_Item.GetItemGUID(loc)
			if guid then
				add(function()
					return C_TooltipInfo.GetItemByGUID and C_TooltipInfo.GetItemByGUID(guid)
				end)
				add(function()
					return C_TooltipInfo.GetGUID and C_TooltipInfo.GetGUID(guid)
				end)
			end
		end
		if loc and C_Item.GetItemLink and C_TooltipInfo.GetHyperlink then
			add(function()
				local link = C_Item.GetItemLink(loc)
				return link and C_TooltipInfo.GetHyperlink(link)
			end)
		end
	end
	return list
end

--- Проверяет, надета ли «Свитая охотница».
-- @return boolean
function FishStat:IsCoiledHuntressEquipped()
	return getCoiledHuntressSlot() ~= nil
end

--- Возвращает запас яда «Свитой охотницы», если она надета.
-- Ноль — допустимое значение. Пока подсказка грузится, возвращается последний разобранный запас.
-- @return number|nil количество яда или nil, если предмет не надет
function FishStat:GetCoiledHuntressVenom()
    local slot, loc = getCoiledHuntressSlot()

	if not slot then
		cachedVenom = nil
		lastDataInstanceID = nil
		return nil
	end

	local parsed
	for _, data in ipairs(tooltipCandidates(slot, loc)) do
		parsed = parseVenomFromTooltip(data)
		if parsed ~= nil then
			cachedVenom = parsed
			lastDataInstanceID = nil
			return cachedVenom
		end
		if data.dataInstanceID then
			lastDataInstanceID = data.dataInstanceID
		end
	end

	parsed = parseVenomFromScanner(slot, loc)
	if parsed ~= nil then
		cachedVenom = parsed
		lastDataInstanceID = nil
		return cachedVenom
	end

	return cachedVenom
end

-- Ability_Creature_Poison_06. Используем FileDataID: классические пути иконок
-- на актуальном клиенте часто не находятся и оставляют пустой пробел в FontString.
local VENOM_ICON_FILE_ID = 132108
local CRYSTAL_VIAL_ITEM_ID = 3371

--- Формирует разметку иконки запаса яда (пузырёк или запасная иконка).
-- @return string текстурная разметка для FontString
-- @local
local function formatVenomIcon()
	local fileID = VENOM_ICON_FILE_ID
	if C_Item and C_Item.GetItemIconByID then
		local itemIcon = C_Item.GetItemIconByID(CRYSTAL_VIAL_ITEM_ID)
		if itemIcon and itemIcon > 0 then
			fileID = itemIcon
		end
	end
	-- 0x0 — квадратная иконка по размеру шрифта FontString.
	if CreateSimpleTextureMarkup then
		return CreateSimpleTextureMarkup(fileID, 0, 0)
	end
	return "|T" .. fileID .. ":0|t"
end

--- Возвращает суффикс заголовка с иконкой и запасом яда, либо пустую строку.
-- @return string
function FishStat:FormatVenomSuffix()
	local venom = self:GetCoiledHuntressVenom()
	if venom == nil then
		return ""
	end
	return " " .. formatVenomIcon() .. L["VENOM_STOCK"]:format(venom)
end

--- Обновляет интерфейс и планирует повторное чтение яда после возможного изменения.
function FishStat:OnVenomMaybeChanged()
	self:RefreshUI()
	self:ScheduleVenomRescan()
end

--- Сбрасывает кэш яда после слива (диалог, взаимодействие, валюта) и перечитывает запас.
function FishStat:OnVenomSiphoned()
	cachedVenom = nil
	lastDataInstanceID = nil
	self:RefreshUI()
	self:ScheduleVenomRescan()
end

--- Обработчик `TOOLTIP_DATA_UPDATE`: обновляет яд, когда подгрузилась нужная подсказка.
-- @param _ string имя события (не используется)
-- @param dataInstanceID number|nil идентификатор экземпляра данных подсказки
function FishStat:TOOLTIP_DATA_UPDATE(_, dataInstanceID)
	if dataInstanceID and lastDataInstanceID and dataInstanceID == lastDataInstanceID then
		self:OnVenomMaybeChanged()
	end
end

--- Обработчик `UNIT_INVENTORY_CHANGED`: обновляет яд при смене экипировки игрока.
-- @param _ string имя события (не используется)
-- @param unit string|nil юнит
function FishStat:UNIT_INVENTORY_CHANGED(_, unit)
	if unit and unit ~= "player" then
		return
	end
	self:OnVenomMaybeChanged()
end

--- Обработчик `CURRENCY_DISPLAY_UPDATE`: запас яда может измениться вместе с валютой.
function FishStat:CURRENCY_DISPLAY_UPDATE()
	self:OnVenomMaybeChanged()
end

--- Обработчик `PROFESSION_EQUIPMENT_CHANGED`: обновляет яд при смене рыболовной экипировки.
function FishStat:PROFESSION_EQUIPMENT_CHANGED()
	self:OnVenomMaybeChanged()
end

--- Отменяет таймер `C_Timer`, если он ещё активен.
-- @param timer table|nil объект таймера
-- @local
local function cancelTimer(timer)
	if timer and timer.Cancel then
		timer:Cancel()
	end
end

--- Планирует повторное чтение запаса яда с задержками (подсказка может подгружаться асинхронно).
function FishStat:ScheduleVenomRescan()
	if not self:IsCoiledHuntressEquipped() then
		return
	end
	if not C_Timer then
		self:RefreshUI()
		return
	end

	cancelTimer(rescanTimerA)
	cancelTimer(rescanTimerB)
	rescanTimerA = nil
	rescanTimerB = nil

	--- Обновляет интерфейс после отложенного перечитывания яда.
	-- @local
	local function refresh()
		FishStat:RefreshUI()
	end

	if C_Timer.NewTimer then
		rescanTimerA = C_Timer.NewTimer(0.3, function()
			rescanTimerA = nil
			refresh()
		end)
		rescanTimerB = C_Timer.NewTimer(1.0, function()
			rescanTimerB = nil
			refresh()
		end)
	else
		C_Timer.After(0.3, refresh)
		C_Timer.After(1.0, refresh)
	end
end
