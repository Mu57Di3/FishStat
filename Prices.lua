local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")

local BIND_ON_ACQUIRE = (Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire) or 1
local BIND_QUEST = (Enum and Enum.ItemBind and Enum.ItemBind.Quest) or 4

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

--- Junk, BoP and quest-bound items are not valued for AH.
--- Unknown bindType (item info not cached) → not priced yet.
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

function FishStat:FormatUnitAndLinePrice(unitPrice, count)
	if not unitPrice or unitPrice <= 0 then
		return nil
	end
	local unitText = self:FormatMoney(unitPrice)
	local lineText = self:FormatMoney(unitPrice * (count or 1))
	if not unitText or not lineText then
		return nil
	end
	return unitText .. " | " .. lineText
end
