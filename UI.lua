local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local ROW_HEIGHT = 24
local TITLE_HEIGHT = 28
local TAB_HEIGHT = 24
local SESSION_FOOTER_HEIGHT = 28
local EXPANDED_HEIGHT_DEFAULT = 360
local COLLAPSED_HEIGHT = TITLE_HEIGHT + 6
local MIN_WIDTH, MIN_HEIGHT = 320, 180
local MAX_WIDTH, MAX_HEIGHT = 700, 900

local QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

local function qualityColor(quality)
	local c = QUALITY_COLORS and QUALITY_COLORS[quality or 1]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end

local function setTabActive(btn, active)
	btn:Enable()
	local fs = btn:GetFontString()
	if not fs then
		return
	end
	if active then
		fs:SetTextColor(1, 1, 1)
	else
		fs:SetTextColor(1, 0.82, 0)
	end
end

function FishStat:InitUI()
	if self.frame then
		return
	end

	local db = self.db.char.window
	local frame = CreateFrame("Frame", "FishStatFrame", UIParent, "BackdropTemplate")
	frame:SetSize(db.width or 280, db.collapsed and COLLAPSED_HEIGHT or (db.height or EXPANDED_HEIGHT_DEFAULT))
	frame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.x or 0, db.y or 0)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
	else
		frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		frame:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
	end
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(selfFrame)
		if not InCombatLockdown() then
			selfFrame:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(selfFrame)
		selfFrame:StopMovingOrSizing()
		FishStat:SaveWindowPosition()
	end)
	frame:SetScript("OnSizeChanged", function()
		if FishStat.frame and FishStat.frame:IsShown() and not FishStat.db.char.window.collapsed then
			FishStat:RefreshUI()
		end
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
	frame:SetBackdropColor(0.05, 0.08, 0.12, 0.55)
	frame:SetBackdropBorderColor(0.35, 0.55, 0.75, 1)

	-- Title bar
	local titleBar = CreateFrame("Frame", nil, frame)
	titleBar:SetPoint("TOPLEFT", 4, -4)
	titleBar:SetPoint("TOPRIGHT", -4, -4)
	titleBar:SetHeight(TITLE_HEIGHT)

	local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titleText:SetPoint("LEFT", 8, 0)
	titleText:SetPoint("RIGHT", -56, 0)
	titleText:SetJustifyH("LEFT")
	titleText:SetWordWrap(false)
	frame.titleText = titleText

	local collapseBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
	collapseBtn:SetSize(22, 20)
	collapseBtn:SetPoint("RIGHT", -30, 0)
	collapseBtn:SetText("-")
	collapseBtn:SetScript("OnClick", function()
		FishStat:ToggleCollapsed()
	end)
	collapseBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(FishStat.db.char.window.collapsed and L["EXPAND"] or L["COLLAPSE"])
		GameTooltip:Show()
	end)
	collapseBtn:SetScript("OnLeave", GameTooltip_Hide)
	frame.collapseBtn = collapseBtn

	local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
	closeBtn:SetPoint("RIGHT", -2, 0)
	closeBtn:SetScript("OnClick", function()
		FishStat:HideWindow()
	end)

	-- Body (tabs + list)
	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
	body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	frame.body = body

	local sessionBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
	sessionBtn:SetSize(80, TAB_HEIGHT)
	sessionBtn:SetPoint("TOPLEFT", 4, 0)
	sessionBtn:SetText(L["SESSION"])
	sessionBtn:SetScript("OnClick", function()
		FishStat:SetActiveTab("session")
	end)
	frame.sessionBtn = sessionBtn

	local totalBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
	totalBtn:SetSize(80, TAB_HEIGHT)
	totalBtn:SetPoint("LEFT", sessionBtn, "RIGHT", 4, 0)
	totalBtn:SetText(L["TOTAL"])
	totalBtn:SetScript("OnClick", function()
		FishStat:SetActiveTab("total")
	end)
	frame.totalBtn = totalBtn

	local baitTabBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
	baitTabBtn:SetSize(90, TAB_HEIGHT)
	baitTabBtn:SetPoint("LEFT", totalBtn, "RIGHT", 4, 0)
	baitTabBtn:SetText(L["BAIT"])
	baitTabBtn:SetScript("OnClick", function()
		FishStat:SetActiveTab("bait")
	end)
	frame.baitTabBtn = baitTabBtn

	local resetBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
	resetBtn:SetSize(70, TAB_HEIGHT)
	resetBtn:SetPoint("TOPRIGHT", -4, 0)
	resetBtn:SetText(L["RESET"])
	resetBtn:SetScript("OnClick", function()
		FishStat:ResetSession()
		FishStat:Print(L["SESSION_RESET"])
	end)
	resetBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(L["RESET_SESSION"])
		GameTooltip:Show()
	end)
	resetBtn:SetScript("OnLeave", GameTooltip_Hide)
	frame.resetBtn = resetBtn

	local scrollFrame = CreateFrame("ScrollFrame", "FishStatScrollFrame", body, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 4, -(TAB_HEIGHT + 4))
	scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(1, 1)
	scrollFrame:SetScrollChild(content)

	frame.scrollFrame = scrollFrame
	frame.content = content
	frame.rows = {}

	local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	emptyText:SetPoint("TOPLEFT", 8, -8)
	emptyText:SetText(L["NO_CATCH"])
	emptyText:Hide()
	frame.emptyText = emptyText

	local showAllCheck = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
	showAllCheck:SetSize(24, 24)
	showAllCheck:SetPoint("BOTTOMLEFT", 4, 2)
	showAllCheck:SetChecked(db.showAllSession)
	showAllCheck:Hide()
	showAllCheck:SetScript("OnClick", function(btn)
		FishStat.db.char.window.showAllSession = btn:GetChecked() and true or false
		FishStat:RefreshUI()
	end)
	showAllCheck:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(L["SHOW_ALL_SESSION_TIP"])
		GameTooltip:Show()
	end)
	showAllCheck:SetScript("OnLeave", GameTooltip_Hide)

	local showAllLabel = showAllCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	showAllLabel:SetPoint("LEFT", showAllCheck, "RIGHT", 2, 0)
	showAllLabel:SetText(L["SHOW_ALL_SESSION"])
	frame.showAllCheck = showAllCheck

	-- Bait panel
	local baitPanel = CreateFrame("Frame", nil, body)
	baitPanel:SetPoint("TOPLEFT", 4, -(TAB_HEIGHT + 4))
	baitPanel:SetPoint("BOTTOMRIGHT", -4, 4)
	baitPanel:Hide()
	frame.baitPanel = baitPanel

	local baitScroll = CreateFrame("ScrollFrame", "FishStatBaitScrollFrame", baitPanel, "UIPanelScrollFrameTemplate")
	baitScroll:SetPoint("TOPLEFT", 0, 0)
	baitScroll:SetPoint("BOTTOMRIGHT", -22, 36)

	local baitContent = CreateFrame("Frame", nil, baitScroll)
	baitContent:SetSize(1, 1)
	baitScroll:SetScrollChild(baitContent)
	frame.baitScroll = baitScroll
	frame.baitContent = baitContent
	frame.baitRows = {}

	local noBaitText = baitContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	noBaitText:SetPoint("TOPLEFT", 8, -8)
	noBaitText:SetText(L["NO_BAIT"])
	noBaitText:Hide()
	frame.noBaitText = noBaitText

	local applyBtn = CreateFrame("Button", "FishStatApplyBaitButton", baitPanel, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	applyBtn:SetSize(110, 24)
	applyBtn:SetPoint("BOTTOMLEFT", 0, 4)
	applyBtn:SetText(L["APPLY"])
	applyBtn:RegisterForClicks("AnyUp", "AnyDown")
	applyBtn:Disable()
	frame.applyBaitBtn = applyBtn

	-- Bottom-right resize grip
	local resize = CreateFrame("Button", nil, frame)
	resize:SetSize(16, 16)
	resize:SetPoint("BOTTOMRIGHT", -3, 3)
	resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatFrame-ResizeGrip")
	resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatFrame-ResizeGrip")
	resize:SetFrameLevel(frame:GetFrameLevel() + 5)
	resize:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
	resize:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" or InCombatLockdown() or FishStat.db.char.window.collapsed then
			return
		end
		frame:StartSizing("BOTTOMRIGHT")
	end)
	resize:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		FishStat:SaveWindowPosition()
		FishStat:RefreshUI()
	end)
	resize:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(L["RESIZE"])
		GameTooltip:Show()
	end)
	resize:SetScript("OnLeave", GameTooltip_Hide)
	frame.resizeBtn = resize

	self.frame = frame
	self:ApplyCollapsedState(true)
end

function FishStat:SaveWindowPosition()
	local frame = self.frame
	if not frame then
		return
	end
	local db = self.db.char.window
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	db.point = point
	db.relativePoint = relativePoint
	db.x = x
	db.y = y
	if not db.collapsed then
		db.width = frame:GetWidth()
		db.height = frame:GetHeight()
	end
end

function FishStat:IsWindowShown()
	return self.frame and self.frame:IsShown()
end

function FishStat:ShowWindow()
	self:InitUI()
	if InCombatLockdown() then
		self.wantShowAfterCombat = true
		self:Print(L["IN_COMBAT"])
		return
	end
	self.frame:Show()
	self:RefreshUI()
end

function FishStat:HideWindow(fromCombat)
	if self.frame then
		self.frame:Hide()
	end
	if not fromCombat then
		self.wantShowAfterCombat = false
		self.wasShownBeforeCombat = false
	end
end

function FishStat:ToggleCollapsed()
	local db = self.db.char.window
	db.collapsed = not db.collapsed
	self:ApplyCollapsedState()
end

function FishStat:ApplyCollapsedState(skipRefresh)
	local frame = self.frame
	if not frame then
		return
	end
	local db = self.db.char.window
	if db.collapsed then
		if not db.height or db.height < COLLAPSED_HEIGHT + 40 then
			db.height = EXPANDED_HEIGHT_DEFAULT
		else
			-- keep last expanded height already stored
		end
		frame.body:Hide()
		frame:SetHeight(COLLAPSED_HEIGHT)
		frame.collapseBtn:SetText("+")
		if frame.resizeBtn then
			frame.resizeBtn:Hide()
		end
	else
		frame.body:Show()
		frame:SetHeight(db.height or EXPANDED_HEIGHT_DEFAULT)
		frame.collapseBtn:SetText("-")
		if frame.resizeBtn then
			frame.resizeBtn:Show()
		end
	end
	if not skipRefresh then
		self:RefreshUI()
	end
end

local function acquireRow(frame, index)
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

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -78, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.count:SetPoint("RIGHT", -8, 0)
	row.count:SetJustifyH("RIGHT")
	row.count:SetWidth(70)

	row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.price:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
	row.price:SetJustifyH("RIGHT")
	row.price:SetWidth(130)
	row.price:SetTextColor(1, 0.82, 0)
	row.price:Hide()

	row:SetScript("OnEnter", function(selfRow)
		if selfRow.link then
			GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(selfRow.link)
			if selfRow.priceTip then
				GameTooltip:AddLine(selfRow.priceTip, 0.8, 0.8, 0.8)
			end
			GameTooltip:Show()
		elseif selfRow.priceTip then
			GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
			GameTooltip:SetText(selfRow.priceTip)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)

	frame.rows[index] = row
	return row
end

local COUNT_ONLY_NAME_RIGHT = -78
local COUNT_AND_PRICE_NAME_RIGHT = -214
local BAIT_ROW_HEIGHT = 26

local function acquireBaitRow(frame, index)
	local row = frame.baitRows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, frame.baitContent)
	row:SetHeight(BAIT_ROW_HEIGHT)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", 4, 0)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -40, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.count:SetPoint("RIGHT", -8, 0)
	row.count:SetJustifyH("RIGHT")

	row.selectedBg = row:CreateTexture(nil, "BACKGROUND")
	row.selectedBg:SetAllPoints()
	row.selectedBg:SetColorTexture(0.2, 0.35, 0.55, 0.45)
	row.selectedBg:Hide()

	row:SetScript("OnClick", function(self)
		FishStat:SelectBait(self.itemID)
	end)
	row:SetScript("OnEnter", function(self)
		if self.link or self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.link then
				GameTooltip:SetHyperlink(self.link)
			else
				GameTooltip:SetItemByID(self.itemID)
			end
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)

	frame.baitRows[index] = row
	return row
end

function FishStat:RefreshBaitUI()
	local frame = self.frame
	if not frame or not frame.baitPanel then
		return
	end

	local list = self.baitList or self:ScanBaits()
	local width = frame.baitScroll:GetWidth()
	if width < 50 then
		width = (frame:GetWidth() or 380) - 50
	end
	frame.baitContent:SetWidth(width)

	local selected = self.db.char.selectedBait
	if selected then
		local stillThere = false
		for _, bait in ipairs(list) do
			if bait.itemID == selected then
				stillThere = true
				break
			end
		end
		if not stillThere then
			self.db.char.selectedBait = list[1] and list[1].itemID or nil
			selected = self.db.char.selectedBait
		end
	elseif list[1] then
		self.db.char.selectedBait = list[1].itemID
		selected = list[1].itemID
	end

	if #list == 0 then
		frame.noBaitText:Show()
		for _, row in ipairs(frame.baitRows) do
			row:Hide()
		end
		frame.baitContent:SetHeight(30)
		self:UpdateBaitSecureButton()
		return
	end

	frame.noBaitText:Hide()
	for i, bait in ipairs(list) do
		local row = acquireBaitRow(frame, i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -((i - 1) * BAIT_ROW_HEIGHT))
		row:SetPoint("TOPRIGHT", 0, -((i - 1) * BAIT_ROW_HEIGHT))
		row:Show()
		row.itemID = bait.itemID
		row.link = select(2, GetItemInfo(bait.itemID))
		row.icon:SetTexture(bait.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
		row.name:SetText(bait.name)
		row.count:SetText(tostring(bait.count))
		if bait.itemID == selected then
			row.selectedBg:Show()
			row.name:SetTextColor(1, 1, 1)
		else
			row.selectedBg:Hide()
			row.name:SetTextColor(1, 0.82, 0)
		end
	end

	for i = #list + 1, #frame.baitRows do
		frame.baitRows[i]:Hide()
	end
	frame.baitContent:SetHeight(math.max(#list * BAIT_ROW_HEIGHT, 1))

	self:UpdateBaitSecureButton()
end

function FishStat:RefreshUI()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end

	local locName = self:GetLocationDisplayName()
	local skill = self:FormatFishingSkill()
	frame.titleText:SetText(locName .. "  |  " .. skill)

	if self.db.char.window.collapsed or not frame.body:IsShown() then
		return
	end

	local tab = self:GetActiveTab()
	setTabActive(frame.sessionBtn, tab == "session")
	setTabActive(frame.totalBtn, tab == "total")
	setTabActive(frame.baitTabBtn, tab == "bait")

	if tab == "bait" then
		frame.scrollFrame:Hide()
		frame.resetBtn:Hide()
		frame.showAllCheck:Hide()
		frame.baitPanel:Show()
		self:ScanBaits()
		self:RefreshBaitUI()
		return
	end

	frame.baitPanel:Hide()
	frame.scrollFrame:Show()
	frame.resetBtn:Show()

	local showSession = (tab == "session")
	if showSession then
		frame.showAllCheck:Show()
		frame.showAllCheck:SetChecked(self.db.char.window.showAllSession)
		frame.scrollFrame:SetPoint("BOTTOMRIGHT", -26, SESSION_FOOTER_HEIGHT)
	else
		frame.showAllCheck:Hide()
		frame.scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
	end

	local list = self:GetCatchList(showSession)
	local width = frame.scrollFrame:GetWidth()
	if width < 50 then
		width = (frame:GetWidth() or 280) - 40
	end
	frame.content:SetWidth(width)

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
		local row = acquireRow(frame, i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		row:SetPoint("TOPRIGHT", 0, -((i - 1) * ROW_HEIGHT))
		row:Show()

		local tex = item.texture
		if not tex and item.itemID then
			tex = C_Item.GetItemIconByID(item.itemID)
		end
		row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		row.name:SetText(item.name or ("#" .. tostring(item.itemID)))
		row.name:SetTextColor(qualityColor(item.quality))

		local count = item.count or 0
		if item.kind == "total" then
			if item.zoneTotal then
				row.count:SetText(("%d (%d)"):format(count, item.zoneTotal))
			else
				row.count:SetText(tostring(count))
			end
			row.name:SetTextColor(1, 0.82, 0)
		else
			row.count:SetText(("%d (%.0f%%)"):format(count, item.percent or 0))
		end

		local priceText
		local priceTip
		if showSession then
			if item.kind == "item" and item.unitPrice then
				priceText = self:FormatUnitAndLinePrice(item.unitPrice, item.count)
				priceTip = L["AH_PRICE_TIP"]
			elseif item.kind == "total" and item.sessionValue then
				priceText = self:FormatMoney(item.sessionValue)
				priceTip = L["AH_SESSION_TOTAL_TIP"]
			end
		end

		if priceText then
			row.price:SetText(priceText)
			row.price:Show()
			row.name:SetPoint("RIGHT", row, "RIGHT", COUNT_AND_PRICE_NAME_RIGHT, 0)
			row.priceTip = priceTip
		else
			row.price:SetText("")
			row.price:Hide()
			row.name:SetPoint("RIGHT", row, "RIGHT", COUNT_ONLY_NAME_RIGHT, 0)
			row.priceTip = nil
		end

		row.link = (item.kind == "item") and item.link or nil
	end

	for i = #list + 1, #frame.rows do
		frame.rows[i]:Hide()
	end

	frame.content:SetHeight(math.max(#list * ROW_HEIGHT, 1))
end
