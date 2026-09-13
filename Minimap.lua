local FishStat = LibStub("AceAddon-3.0"):GetAddon("FishStat")
local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

local LibDBIcon = LibStub("LibDBIcon-1.0")
local LDB = LibStub("LibDataBroker-1.1")

--- Создаёт кнопку у миникарты через LibDataBroker и LibDBIcon.
function FishStat:InitMinimap()
	if self.minimapReady then
		return
	end

	local dataObject = LDB:NewDataObject("FishStat", {
		type = "launcher",
		label = L["ADDON_NAME"],
		icon = "Interface\\Icons\\Trade_Fishing",
		OnClick = function(frame, button)
			if button == "LeftButton" then
				FishStat:ToggleWindow()
			elseif button == "RightButton" then
				FishStat:ShowMinimapMenu(frame)
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(L["TOOLTIP_TITLE"])
			tooltip:AddLine(L["TOOLTIP_LEFT"], 0.8, 0.8, 0.8)
			tooltip:AddLine(L["TOOLTIP_RIGHT"], 0.8, 0.8, 0.8)
		end,
	})

	LibDBIcon:Register("FishStat", dataObject, self.db.char.minimap)
	self.minimapReady = true
	self:UpdateMinimapVisibility()
end

--- Показывает или скрывает кнопку у миникарты согласно настройке персонажа.
function FishStat:UpdateMinimapVisibility()
	if not self.minimapReady then
		return
	end
	if self.db.char.minimap.hide then
		LibDBIcon:Hide("FishStat")
	else
		LibDBIcon:Show("FishStat")
	end
end

--- Показывает или скрывает контекстное меню кнопки у миникарты.
-- @param anchor Frame фрейм-якорь (обычно кнопка миникарты)
function FishStat:ShowMinimapMenu(anchor)
	if self.minimapMenu then
		self.minimapMenu:Hide()
		self.minimapMenu = nil
		return
	end

	local menu = CreateFrame("Frame", "FishStatMinimapMenu", UIParent, "BackdropTemplate")
	menu:SetFrameStrata("TOOLTIP")
	menu:SetClampedToScreen(true)
	menu:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	menu:SetBackdropColor(0.05, 0.08, 0.12, 0.95)

	--- Создаёт пункт контекстного меню миникарты.
	-- @param text string подпись пункта
	-- @param onClick function обработчик нажатия
	-- @return Button созданная кнопка
	-- @local
	local function addOption(text, onClick)
		local btn = CreateFrame("Button", nil, menu)
		btn:SetHeight(22)
		btn:SetPoint("LEFT", 6, 0)
		btn:SetPoint("RIGHT", -6, 0)
		local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", 4, 0)
		label:SetText(text)
		btn:SetFontString(label)
		btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		btn:SetScript("OnClick", function()
			onClick()
			menu:Hide()
			FishStat.minimapMenu = nil
		end)
		return btn
	end

	local resetBtn = addOption(L["RESET_SESSION"], function()
		FishStat:ResetSession()
		FishStat:Print(L["SESSION_RESET"])
	end)
	resetBtn:SetPoint("TOP", 0, -8)

	local hideText = self.db.char.minimap.hide and L["SHOW_MINIMAP"] or L["HIDE_MINIMAP"]
	local hideBtn = addOption(hideText, function()
		FishStat.db.char.minimap.hide = not FishStat.db.char.minimap.hide
		FishStat:UpdateMinimapVisibility()
	end)
	hideBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -2)

	menu:SetSize(180, 60)
	menu:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
	menu:Show()
	menu:SetScript("OnHide", function()
		FishStat.minimapMenu = nil
	end)

	-- Закрытие по клику вне меню
	menu:EnableMouse(true)
	menu:SetScript("OnUpdate", function(selfMenu, elapsed)
		selfMenu.elapsed = (selfMenu.elapsed or 0) + elapsed
		if selfMenu.elapsed < 0.2 then
			return
		end
		if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
			return
		end
		if not MouseIsOver(selfMenu) and not (anchor and MouseIsOver(anchor)) then
			selfMenu:Hide()
		end
	end)

	self.minimapMenu = menu
end
