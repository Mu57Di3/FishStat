local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local KEY_SEP = "\0"
local MAX_MAP_PARENT_DEPTH = 20

function FishStat:GetLocationKey(zone, subzone)
	zone = zone or GetZoneText() or ""
	subzone = subzone or GetSubZoneText() or ""
	return zone .. KEY_SEP .. subzone
end

function FishStat:GetLocationDisplayName(zone, subzone)
	zone = zone or GetZoneText() or ""
	subzone = subzone or GetSubZoneText() or ""
	if subzone ~= "" then
		return L["ZONE_SUBZONE"]:format(zone, subzone)
	end
	return L["ZONE_ONLY"]:format(zone)
end

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

		if info and info.professionName then
			return {
				name = info.professionName,
				skillLevel = info.skillLevel or 0,
				maxSkillLevel = info.maxSkillLevel or 0,
				skillModifier = info.skillModifier or 0,
				skillLineID = skillLineID,
				expansionName = self.fishingExpansionBySkillLineID[skillLineID],
			}
		end
	end

	local name, _, skillLevel, maxSkillLevel, _, _, _, skillModifier = GetProfessionInfo(fishing)
	return {
		name = name,
		skillLevel = skillLevel or 0,
		maxSkillLevel = maxSkillLevel or 0,
		skillModifier = skillModifier or 0,
	}
end

function FishStat:FormatFishingSkill()
	local info = self:GetFishingSkillInfo()
	if not info then
		return L["FISHING_UNKNOWN"]
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
	return text
end

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

function FishStat:ProcessFishingLoot()
	if self.lootHandled then
		return
	end
	if not IsFishingLoot or not IsFishingLoot() then
		return
	end

	-- If slots are already empty (fast autoloot), fall back to chat loot lines
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
	end
end

local function formatPrefix(fmt)
	if type(fmt) ~= "string" then
		return nil
	end
	return fmt:match("^(.-)%%[sd]")
end

local selfLootPrefixes

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

local function isSelfLootMessage(message)
	for _, prefix in ipairs(getSelfLootPrefixes()) do
		if message:sub(1, #prefix) == prefix or message:find(prefix, 1, true) then
			return true
		end
	end
	return false
end

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

function FishStat:ProcessFishingChatLoot(message)
	-- Chat fallback only when slot reading failed (autoloot emptied the window)
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
	-- Keep the chat window open: one cast can yield several items
	self.expectFishingChatUntil = GetTime() + 1.5
	self:RefreshUI()
end

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
		-- Enum.ItemQuality.Poor = 0 (grey junk)
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

	local function pct(count)
		return (count / total) * 100
	end

	-- In session view (single zone), show all-time zone total in parentheses
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

	-- Session-only: Auctionator prices (skip junk / BoP / quest bind)
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

function FishStat:ResetSession()
	wipe(self.session)
	self:RefreshUI()
end
