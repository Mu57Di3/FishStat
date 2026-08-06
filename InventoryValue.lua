local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local ROW_HEIGHT = 24
local INV_VALUE_WIDTH = 380
local INV_VALUE_HEIGHT = 340
local INV_VALUE_TITLE_HEIGHT = 28
local INV_VALUE_FOOTER_HEIGHT = 78
local INV_VALUE_NAME_RIGHT = -220

local QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

local function qualityColor(quality)
	local c = QUALITY_COLORS and QUALITY_COLORS[quality or 1]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end

local function acquireInvValueRow(frame, index)
	local row = frame.rows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, frame.content)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("LEFT", 0, 0)
	row:SetPoint("RIGHT", 0, 0)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", 4, 0)

	local excludeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	excludeBtn:SetSize(22, 20)
	excludeBtn:SetPoint("RIGHT", -2, 0)
	excludeBtn:SetText("-")
	excludeBtn:SetScript("OnClick", function(btn)
		FishStat:ExcludeInventoryValueItem(btn:GetParent().itemID)
	end)
	excludeBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(L["INVENTORY_VALUE_EXCLUDE"])
		GameTooltip:Show()
	end)
	excludeBtn:SetScript("OnLeave", GameTooltip_Hide)
	row.excludeBtn = excludeBtn

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", INV_VALUE_NAME_RIGHT, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.count:SetPoint("RIGHT", excludeBtn, "LEFT", -4, 0)
	row.count:SetJustifyH("RIGHT")
	row.count:SetWidth(56)

	row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.price:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
	row.price:SetJustifyH("RIGHT")
	row.price:SetWidth(113)
	row.price:SetWordWrap(false)
	row.price:SetNonSpaceWrap(false)
	row.price:SetTextColor(1, 0.82, 0)

	row:SetScript("OnEnter", function(selfRow)
		if selfRow.link then
			GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(selfRow.link)
			if selfRow.priceTip then
				GameTooltip:AddLine(selfRow.priceTip, 0.8, 0.8, 0.8)
			end
			GameTooltip:Show()
		elseif selfRow.itemID then
			GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(selfRow.itemID)
			if selfRow.priceTip then
				GameTooltip:AddLine(selfRow.priceTip, 0.8, 0.8, 0.8)
			end
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)

	frame.rows[index] = row
	return row
end

function FishStat:InitInventoryValueUI()
	if self.inventoryValueFrame then
		return
	end

	local frame = CreateFrame("Frame", "FishStatInventoryValueFrame", UIParent, "BackdropTemplate")
	frame:SetSize(INV_VALUE_WIDTH, INV_VALUE_HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 40, 20)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(selfFrame)
		if not InCombatLockdown() then
			selfFrame:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(selfFrame)
		selfFrame:StopMovingOrSizing()
	end)
	frame:Hide()

	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0.05, 0.08, 0.12, 0.92)
	frame:SetBackdropBorderColor(0.35, 0.55, 0.75, 1)

	local titleBar = CreateFrame("Frame", nil, frame)
	titleBar:SetPoint("TOPLEFT", 4, -4)
	titleBar:SetPoint("TOPRIGHT", -4, -4)
	titleBar:SetHeight(INV_VALUE_TITLE_HEIGHT)

	local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titleText:SetPoint("LEFT", 8, 0)
	titleText:SetPoint("RIGHT", -28, 0)
	titleText:SetJustifyH("LEFT")
	titleText:SetText(L["INVENTORY_VALUE_TITLE"])
	frame.titleText = titleText

	local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
	closeBtn:SetPoint("RIGHT", 2, 0)
	closeBtn:SetScript("OnClick", function()
		FishStat:HideInventoryValueWindow()
	end)

	local footer = CreateFrame("Frame", nil, frame)
	footer:SetPoint("BOTTOMLEFT", 8, 8)
	footer:SetPoint("BOTTOMRIGHT", -8, 8)
	footer:SetHeight(INV_VALUE_FOOTER_HEIGHT)
	frame.footer = footer

	local closeBottomBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
	closeBottomBtn:SetSize(100, 24)
	closeBottomBtn:SetPoint("BOTTOM", 0, 0)
	closeBottomBtn:SetText(L["CLOSE"])
	closeBottomBtn:SetScript("OnClick", function()
		FishStat:HideInventoryValueWindow()
	end)
	frame.closeBottomBtn = closeBottomBtn

	local hintIcon = footer:CreateTexture(nil, "ARTWORK")
	hintIcon:SetSize(16, 16)
	hintIcon:SetPoint("BOTTOMLEFT", 0, 30)
	hintIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
	frame.hintIcon = hintIcon

	local hintText = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hintText:SetPoint("LEFT", hintIcon, "RIGHT", 4, 0)
	hintText:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
	hintText:SetJustifyH("LEFT")
	hintText:SetJustifyV("MIDDLE")
	hintText:SetWordWrap(true)
	hintText:SetText(L["INVENTORY_VALUE_HINT"])
	frame.hintText = hintText

	local totalLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	totalLabel:SetPoint("TOPLEFT", 0, 0)
	totalLabel:SetText(L["INVENTORY_VALUE_TOTAL"])
	frame.totalLabel = totalLabel

	local totalValue = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	totalValue:SetPoint("TOPRIGHT", 0, 0)
	totalValue:SetJustifyH("RIGHT")
	totalValue:SetTextColor(1, 0.82, 0)
	frame.totalValue = totalValue

	local scrollFrame = CreateFrame("ScrollFrame", "FishStatInventoryValueScroll", frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 4, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -22, 4)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(1, 1)
	scrollFrame:SetScrollChild(content)
	frame.scrollFrame = scrollFrame
	frame.content = content
	frame.rows = {}

	local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	emptyText:SetPoint("TOPLEFT", 8, -8)
	emptyText:SetPoint("TOPRIGHT", -8, -8)
	emptyText:SetJustifyH("LEFT")
	emptyText:SetText(L["INVENTORY_VALUE_EMPTY"])
	emptyText:Hide()
	frame.emptyText = emptyText

	self.inventoryValueFrame = frame
end

function FishStat:RefreshInventoryValueUI(result)
	local frame = self.inventoryValueFrame
	if not frame then
		return
	end

	result = result or { items = {}, totalValue = 0 }
	self.inventoryValueResult = result
	local list = result.items or {}
	local width = frame.scrollFrame:GetWidth()
	if width < 50 then
		width = INV_VALUE_WIDTH - 40
	end
	frame.content:SetWidth(width)

	local totalText = self:FormatMoney(result.totalValue)
	frame.totalValue:SetText(totalText or "—")

	if #list == 0 then
		frame.emptyText:Show()
		for _, row in ipairs(frame.rows) do
			row:Hide()
		end
		frame.content:SetHeight(30)
		return
	end

	frame.emptyText:Hide()
	for i, item in ipairs(list) do
		local row = acquireInvValueRow(frame, i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		row:SetPoint("TOPRIGHT", 0, -((i - 1) * ROW_HEIGHT))
		row:Show()

		local tex = item.texture
		if not tex and item.itemID and C_Item and C_Item.GetItemIconByID then
			tex = C_Item.GetItemIconByID(item.itemID)
		end
		row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		row.name:SetText(item.name or ("#" .. tostring(item.itemID)))
		row.name:SetTextColor(qualityColor(item.quality))
		row.count:SetText("x" .. tostring(item.count or 0))
		row.link = item.link
		row.itemID = item.itemID

		if item.lineValue then
			local priceText = self:FormatMoney(item.lineValue)
			row.price:SetText(priceText or "")
			row.price:Show()
			local unitPriceText = item.unitPrice and self:FormatMoney(item.unitPrice)
			row.priceTip = unitPriceText and L["AH_PRICE_TIP"]:format(unitPriceText) or nil
		else
			row.price:SetText("")
			row.price:Hide()
			row.priceTip = nil
		end
	end

	for i = #list + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	frame.content:SetHeight(math.max(#list * ROW_HEIGHT, 1))
end

local function filterExcludedItems(result, excluded)
	if not result or type(result.items) ~= "table" or not excluded then
		return result
	end

	local items = result.items
	local totalValue = 0
	local filtered = {}
	for i = 1, #items do
		local item = items[i]
		if item.itemID and excluded[item.itemID] then
			-- skip
		else
			filtered[#filtered + 1] = item
			totalValue = totalValue + (item.lineValue or 0)
		end
	end
	result.items = filtered
	result.totalValue = totalValue
	return result
end

function FishStat:ExcludeInventoryValueItem(itemID)
	local result = self.inventoryValueResult
	if not result or not itemID or type(result.items) ~= "table" then
		return
	end

	if not self.inventoryValueExcluded then
		self.inventoryValueExcluded = {}
	end
	self.inventoryValueExcluded[itemID] = true

	local items = result.items
	local removedValue = 0
	for i = #items, 1, -1 do
		if items[i].itemID == itemID then
			removedValue = items[i].lineValue or 0
			table.remove(items, i)
			break
		end
	end
	result.totalValue = math.max((result.totalValue or 0) - removedValue, 0)
	self:RefreshInventoryValueUI(result)
end

function FishStat:ShowInventoryValueWindow()
	if not self:IsAuctionatorReady() then
		return
	end
	self:InitInventoryValueUI()
	local result = self:ScanInventoryFishValue()
	filterExcludedItems(result, self.inventoryValueExcluded)
	self:RefreshInventoryValueUI(result)
	self.inventoryValueFrame:Show()
	self.inventoryValueFrame:Raise()
end

function FishStat:HideInventoryValueWindow()
	if self.inventoryValueFrame then
		self.inventoryValueFrame:Hide()
	end
	self.inventoryValueResult = nil
end
