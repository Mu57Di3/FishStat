local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local TEEP_NEEDLES = {
	["ruRU"] = {"рыбалк", "внимательност", "навык рыбной ловли", "Можно насадить на крючок", "наживк", "бросьте"},
	["enUS"] = {"fishing", "throw", "perception", "fishing lure", "lure to your fishing", "attach", "bait", "lure"},
}

--- Возвращает количество предмета в сумках персонажа (без банка).
-- @param itemID number ID предмета
-- @return number количество
-- @local
local function getItemCount(itemID)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(itemID, false, false) or 0
	end
	return GetItemCount(itemID, false, false) or 0
end

--- Возвращает локализованное имя предмета по ID.
-- @param itemID number ID предмета
-- @return string|nil имя предмета
-- @local
local function getItemName(itemID)
	if C_Item and C_Item.GetItemNameByID then
		local n = C_Item.GetItemNameByID(itemID)
		if n then
			return n
		end
	end
	return GetItemInfo(itemID)
end

--- Возвращает путь или FileDataID иконки предмета.
-- @param itemID number ID предмета
-- @return string|number|nil текстура иконки
-- @local
local function getItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		return C_Item.GetItemIconByID(itemID)
	end
	return select(10, GetItemInfo(itemID))
end

--- Возвращает заклинание, связанное с предметом (имя или ID).
-- @param itemID number ID предмета
-- @return string|number|nil имя или ID заклинания
-- @local
local function getItemSpell(itemID)
	if C_Item and C_Item.GetItemSpell then
		local spellID, spellName = C_Item.GetItemSpell(itemID)
		return spellName or spellID
	end
	if GetItemSpell then
		return GetItemSpell(itemID)
	end
	return nil
end

--- Собирает текст всех строк подсказки предмета в одну строку.
-- @param itemID number ID предмета
-- @return string|nil текст подсказки
-- @local
local function getTooltipText(itemID)
	if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then
		return nil
	end
	local data = C_TooltipInfo.GetItemByID(itemID)
	if not data then
		return nil
	end
	if TooltipUtil and TooltipUtil.SurfaceArgs then
		TooltipUtil.SurfaceArgs(data)
	end
	local parts = {}
	if data.lines then
		for _, line in ipairs(data.lines) do
			if TooltipUtil and TooltipUtil.SurfaceArgs then
				TooltipUtil.SurfaceArgs(line)
			end
			if line.leftText then
				parts[#parts + 1] = line.leftText
			end
			if line.rightText then
				parts[#parts + 1] = line.rightText
			end
		end
	end
	return table.concat(parts, "\n")
end


--- Проверяет по тексту подсказки, похож ли предмет на рыболовную наживку или приманку.
-- @param itemID number ID предмета
-- @return boolean true, если найдены характерные ключевые слова
-- @local
local function tooltipLooksLikeFishingBait(itemID)
	local locale = GetLocale();
	local name = getItemName(itemID);
	local needles = TEEP_NEEDLES[locale] or TEEP_NEEDLES["enUS"]
	local text = getTooltipText(itemID)
	if not text or text == "" then
		return false
	end
	local lower = string.lower(text)
	for _, needle in ipairs(needles) do
		if lower:find(needle, 1, true) then
			return true
		end
	end
	return false
end

--- Проверяет, является ли предмет рецептом (по локализованному слову «рецепт»).
-- @param itemID number ID предмета
-- @return number|nil позиция совпадения или nil
-- @local
local function isRecipe(itemID)
	local name = getItemName(itemID)
	local lower = string.lower(name);

	return lower:find(L["RECIPE"], 1, true)
end

--- Проверяет, является ли предмет рыболовной наживкой, приманкой или рыбой для насадки.
-- Рецепты исключаются.
-- @param itemID number|nil ID предмета
-- @param name string|nil имя предмета (зарезервировано, не используется)
-- @return boolean
function FishStat:IsBaitItem(itemID, name)
	if not itemID then
		return false
	end

	return tooltipLooksLikeFishingBait(itemID) and not isRecipe(itemID)
end

--- Сканирует сумки на рыболовные наживки и сохраняет список в `self.baitList`.
-- @return table список найденных наживок `{itemID, name, count, texture}`
function FishStat:ScanBaits()
	local found = {}
	local seen = {}

	local lastBag = 5
	if Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots then
		lastBag = Constants.InventoryConstants.NumBagSlots + 1
	elseif NUM_BAG_SLOTS then
		lastBag = NUM_BAG_SLOTS + 1
	end

	for bag = 0, lastBag do
		local slots = 0
		if C_Container and C_Container.GetContainerNumSlots then
			slots = C_Container.GetContainerNumSlots(bag) or 0
		elseif GetContainerNumSlots then
			slots = GetContainerNumSlots(bag) or 0
		end
		for slot = 1, slots do
			local itemID, link
			if C_Container and C_Container.GetContainerItemID then
				itemID = C_Container.GetContainerItemID(bag, slot)
				if C_Container.GetContainerItemLink then
					link = C_Container.GetContainerItemLink(bag, slot)
				end
			elseif GetContainerItemLink then
				link = GetContainerItemLink(bag, slot)
				itemID = link and tonumber(link:match("item:(%d+)"))
			end
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local count = getItemCount(itemID)
				if count > 0 then
					local nameFromLink = link and link:match("%[(.-)%]")
					if not nameFromLink and not getItemName(itemID) and C_Item and C_Item.RequestLoadItemDataByID then
						C_Item.RequestLoadItemDataByID(itemID)
					end
					local name = nameFromLink or getItemName(itemID)
					if self:IsBaitItem(itemID, name) then
						found[#found + 1] = {
							itemID = itemID,
							name = name or ("#" .. itemID),
							count = count,
							texture = getItemIcon(itemID),
						}
					end
				end
			end
		end
	end

	table.sort(found, function(a, b)
		return (a.count or "") > (b.count or "")
	end)

	self.baitList = found
	return found
end

--- Возвращает выбранную наживку из текущего списка, если она ещё есть в сумках.
-- @return table|nil запись наживки или nil
function FishStat:GetSelectedBait()
	local id = self.db.char.selectedBait
	if not id or not self.baitList then
		return nil
	end
	for _, bait in ipairs(self.baitList) do
		if bait.itemID == id then
			return bait
		end
	end
	return nil
end

--- Запоминает выбранную наживку и обновляет кнопку применения и список.
-- @param itemID number|nil ID предмета наживки
function FishStat:SelectBait(itemID)
	self.db.char.selectedBait = itemID
	self:UpdateBaitSecureButton()
	self:RefreshBaitUI()
end

--- Настраивает защищённую кнопку применения выбранной наживки.
-- В бою кнопка отключается, так как атрибуты SecureActionButton нельзя менять.
function FishStat:UpdateBaitSecureButton()
	local frame = self.frame
	if not frame or not frame.applyBaitBtn then
		return
	end
	local btn = frame.applyBaitBtn

	if InCombatLockdown() then
		btn:Disable()
		btn:SetText(L["APPLY"])
		return
	end

	local bait = self:GetSelectedBait()
	if not bait then
		btn:SetAttribute("type", nil)
		btn:SetAttribute("item", nil)
		btn:SetAttribute("macrotext", nil)
		btn:Disable()
		btn:SetText(L["APPLY"])
		return
	end

	btn:Enable()
	btn:SetText(L["APPLY"])
	btn:SetAttribute("type", "item")
	btn:SetAttribute("item", "item:" .. bait.itemID)
	btn:SetAttribute("macrotext", nil)
end

--- Обработчик изменения сумок: пересканирует яд и, при открытой вкладке наживок, список приманок.
function FishStat:OnBagsChanged()
	self:ScheduleVenomRescan()
	if self.frame and self.frame:IsShown() and self:GetActiveTab() == "bait" then
		self:ScanBaits()
		self:RefreshBaitUI()
		self:UpdateBaitSecureButton()
	end
end
