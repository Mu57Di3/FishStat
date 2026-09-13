local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")

local BIND_ON_ACQUIRE = (Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire) or 1
local BIND_QUEST = (Enum and Enum.ItemBind and Enum.ItemBind.Quest) or 4

--- Проверяет, загружен ли Auctionator и доступен ли API цен.
-- @return boolean
function FishStat:IsAuctionatorReady()
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		if not C_AddOns.IsAddOnLoaded("Auctionator") then
			return false
		end
	elseif not IsAddOnLoaded or not IsAddOnLoaded("Auctionator") then
		return false
	end

	return Auctionator
		and Auctionator.API
		and Auctionator.API.v1
		and type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end

--- Возвращает тип привязки предмета (`Enum.ItemBind`) или nil, если данные ещё не в кэше.
-- @param itemID number|nil ID предмета
-- @return number|nil тип привязки
function FishStat:GetItemBindType(itemID)
	if not itemID then
		return nil
	end

	local bindType
	if C_Item and C_Item.GetItemInfo then
		bindType = select(14, C_Item.GetItemInfo(itemID))
	else
		bindType = select(14, GetItemInfo(itemID))
	end
	return bindType
end

--- Проверяет, можно ли оценивать предмет по аукциону.
-- Серый хлам, персональные (BoP) и квестовые предметы не оцениваются.
-- Неизвестный `bindType` (данные предмета ещё не в кэше) тоже исключается.
-- @param quality number|nil качество предмета
-- @param bindType number|nil тип привязки
-- @return boolean
function FishStat:IsPricableItem(quality, bindType)
	if (quality or 1) == 0 then
		return false
	end
	if bindType == nil then
		return false
	end
	if bindType == BIND_ON_ACQUIRE or bindType == BIND_QUEST then
		return false
	end
	return true
end

--- Возвращает цену за штуку по данным Auctionator.
-- @param itemID number|nil ID предмета
-- @return number|nil цена в медных монетах или nil
function FishStat:GetUnitAuctionPrice(itemID)
	if not itemID or not self:IsAuctionatorReady() then
		return nil
	end

	local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "FishStat", itemID)
	if not ok or type(price) ~= "number" or price <= 0 then
		return nil
	end
	return price
end

--- Форматирует сумму меди в строку с иконками монет.
-- @param copper number|nil сумма в медных монетах
-- @return string|nil отформатированная строка или nil при нуле и меньше
function FishStat:FormatMoney(copper)
	if not copper or copper <= 0 then
		return nil
	end
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(copper)
	end
	if GetMoneyString then
		return GetMoneyString(copper, true)
	end
	return tostring(copper)
end

--- Собирает множество ID предметов, когда-либо попавших в общую историю улова.
-- @return table множество `[itemID] = true`
-- @return table метаданные предметов `[itemID] = {name, link, quality, texture}`
function FishStat:CollectKnownCatchItemIDs()
	local known = {}
	local meta = {}
	local total = self.db and self.db.char and self.db.char.total
	if type(total) ~= "table" then
		return known, meta
	end

	for _, bucket in pairs(total) do
		if type(bucket) == "table" then
			for itemID, entry in pairs(bucket) do
				if type(itemID) == "number" then
					known[itemID] = true
					if type(entry) == "table" and not meta[itemID] then
						meta[itemID] = {
							name = entry.name,
							link = entry.link,
							quality = entry.quality,
							texture = entry.texture,
						}
					end
				end
			end
		end
	end
	return known, meta
end

local ITEM_CLASS_TRADEGOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
-- Подкласс хозяйственных товаров: кулинария (мясо, рыба и прочие ингредиенты)
local ITEM_SUBCLASS_COOKING = 8

--- Возвращает количество предмета в сумках персонажа (без банка).
-- @param itemID number ID предмета
-- @return number количество
-- @local
local function getBagItemCount(itemID)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(itemID, false, false) or 0
	end
	if GetItemCount then
		return GetItemCount(itemID, false, false) or 0
	end
	return 0
end

--- Возвращает индекс последней сумки, включая сумку реагентов.
-- @return number индекс последней сумки
-- @local
local function getLastBagIndex()
	if Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots then
		return Constants.InventoryConstants.NumBagSlots + 1
	elseif NUM_BAG_SLOTS then
		return NUM_BAG_SLOTS + 1
	end
	return 5
end

--- Проверяет, является ли предмет ингредиентом кулинарии (Хозяйственные товары / Кулинария).
-- @param itemID number|nil ID предмета
-- @return boolean
function FishStat:IsCookingIngredient(itemID)
	if not itemID then
		return false
	end

	local classID, subclassID
	if C_Item and C_Item.GetItemInfoInstant then
		classID, subclassID = select(6, C_Item.GetItemInfoInstant(itemID))
	elseif GetItemInfoInstant then
		classID, subclassID = select(6, GetItemInfoInstant(itemID))
	else
		local info
		if C_Item and C_Item.GetItemInfo then
			info = { C_Item.GetItemInfo(itemID) }
		elseif GetItemInfo then
			info = { GetItemInfo(itemID) }
		end
		if info then
			classID, subclassID = info[12], info[13]
		end
	end

	return classID == ITEM_CLASS_TRADEGOODS and subclassID == ITEM_SUBCLASS_COOKING
end

--- Сканирует сумки на кулинарные ингредиенты из истории улова и оценивает их через Auctionator.
-- @return table `{ items = { {itemID, name, link, quality, texture, count, unitPrice, lineValue}, ... }, totalValue = copper }`
function FishStat:ScanInventoryFishValue()
	local known, meta = self:CollectKnownCatchItemIDs()
	local aggregated = {}
	local seen = {}
	local lastBag = getLastBagIndex()

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
			if itemID and known[itemID] and not seen[itemID] and self:IsCookingIngredient(itemID) then
				seen[itemID] = true
				local count = getBagItemCount(itemID)
				if count > 0 then
					local info = meta[itemID] or {}
					local name = info.name
					local quality = info.quality
					local texture = info.texture
					if link then
						name = name or link:match("%[(.-)%]")
					end
					if (not name or name == "") and C_Item and C_Item.GetItemNameByID then
						name = C_Item.GetItemNameByID(itemID)
					end
					if not name and GetItemInfo then
						name = GetItemInfo(itemID)
					end
					if not texture and C_Item and C_Item.GetItemIconByID then
						texture = C_Item.GetItemIconByID(itemID)
					elseif not texture and C_Item and C_Item.GetItemInfoInstant then
						texture = select(5, C_Item.GetItemInfoInstant(itemID))
					end
					if quality == nil then
						if C_Item and C_Item.GetItemQualityByID then
							quality = C_Item.GetItemQualityByID(itemID)
						end
					end
					aggregated[itemID] = {
						itemID = itemID,
						name = name or ("#" .. itemID),
						link = link or info.link,
						quality = quality or 1,
						texture = texture,
						count = count,
					}
				end
			end
		end
	end

	local items = {}
	local totalValue = 0
	for _, entry in pairs(aggregated) do
		local bindType = self:GetItemBindType(entry.itemID)
		local unitPrice
		if self:IsPricableItem(entry.quality, bindType) then
			unitPrice = self:GetUnitAuctionPrice(entry.itemID)
		end
		entry.unitPrice = unitPrice
		if unitPrice then
			entry.lineValue = unitPrice * entry.count
			totalValue = totalValue + entry.lineValue
		else
			entry.lineValue = nil
		end
		items[#items + 1] = entry
	end

	table.sort(items, function(a, b)
		local av = a.lineValue or -1
		local bv = b.lineValue or -1
		if av ~= bv then
			return av > bv
		end
		return (a.name or "") < (b.name or "")
	end)

	return { items = items, totalValue = totalValue }
end
