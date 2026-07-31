local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local TEEP_NEEDLES = {
	["ruRU"] = {"рыбалк", "внимательност", "навык рыбной ловли", "Можно насадить на крючок", "наживк", "бросьте"},
	["enUS"] = {"fishing", "throw", "perception", "fishing lure", "lure to your fishing", "attach", "bait", "lure"},
}

local function getItemCount(itemID)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(itemID, false, false) or 0
	end
	return GetItemCount(itemID, false, false) or 0
end

local function getItemName(itemID)
	if C_Item and C_Item.GetItemNameByID then
		local n = C_Item.GetItemNameByID(itemID)
		if n then
			return n
		end
	end
	return GetItemInfo(itemID)
end

local function getItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		return C_Item.GetItemIconByID(itemID)
	end
	return select(10, GetItemInfo(itemID))
end

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
			print(name, needle);
			return true
		end
	end
	return false
end

local function isRecipe(itemID)
	local name = getItemName(itemID)
	local lower = string.lower(name);

	return lower:find(L["RECIPE"], 1, true)
end

--- Only fishing-related baits/lures/throw-back fish
function FishStat:IsBaitItem(itemID, name)
	if not itemID then
		return false
	end

	return tooltipLooksLikeFishingBait(itemID) and not isRecipe(itemID)
end

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

function FishStat:SelectBait(itemID)
	self.db.char.selectedBait = itemID
	self:UpdateBaitSecureButton()
	self:RefreshBaitUI()
end

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

function FishStat:OnBagsChanged()
	if self.frame and self.frame:IsShown() and self:GetActiveTab() == "bait" then
		self:ScanBaits()
		self:RefreshBaitUI()
		self:UpdateBaitSecureButton()
	end
end
