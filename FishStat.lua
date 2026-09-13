local FishStat = LibStub("AceAddon-3.0"):NewAddon("FishStat", "AceEvent-3.0", "AceConsole-3.0")
_G.FishStat = FishStat

local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

-- Сохранённые данные персонажа (окно, миникарта, общий улов)
local defaults = {
	char = {
		minimap = {
			hide = false,
		},
		window = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = 0,
			width = 380,
			height = 360,
			collapsed = false,
			activeTab = "session",
			showAllSession = false,
		},
		total = {},
		selectedBait = nil,
		fishingSkillCache = {},
	},
}

--- Переносит устаревшие настройки окна в текущий формат.
-- Преобразует булево `showSession` в `activeTab` и задаёт вкладку по умолчанию.
function FishStat:MigrateWindowSettings()
	local w = self.db.char.window
	-- Устаревший булевый флаг showSession → activeTab
	if w.showSession ~= nil then
		w.activeTab = w.showSession and "session" or "total"
		w.showSession = nil
	end
	if not w.activeTab then
		w.activeTab = "session"
	end
end

--- Возвращает идентификатор активной вкладки главного окна.
-- @return string `"session"`, `"total"` или `"bait"`
function FishStat:GetActiveTab()
	return self.db.char.window.activeTab or "session"
end

--- Переключает активную вкладку главного окна и обновляет интерфейс.
-- @param tab string идентификатор вкладки: `"session"`, `"total"` или `"bait"`
function FishStat:SetActiveTab(tab)
	self.db.char.window.activeTab = tab
	self:RefreshUI()
end

--- Инициализация аддона: база данных, состояние сессии и слэш-команда.
function FishStat:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("FishStatDB", defaults, true)
	self:MigrateWindowSettings()
	self.session = {}
	self.inventoryValueExcluded = {}
	self.baitList = {}
	self.wasShownBeforeCombat = false
	self.wantShowAfterCombat = false
	self.lootHandled = false
	self.expectFishingChat = false
	self.expectFishingChatUntil = 0

	self:RegisterChatCommand("fishstat", "SlashCommand")
end

--- Регистрирует игровые события и создаёт интерфейс после включения аддона.
function FishStat:OnEnable()
	-- LOOT_READY срабатывает до того, как автолут опустошит слоты (Shift+ПКМ / autoLootDefault)
	self:RegisterEvent("LOOT_READY")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_CLOSED")
	self:RegisterEvent("CHAT_MSG_LOOT")
	self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnZoneChanged")
	self:RegisterEvent("SKILL_LINES_CHANGED", "OnSkillChanged")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnSkillChanged")
	self:RegisterEvent("CHAT_MSG_SKILL", "OnChatMsgSkill")
	self:RegisterEvent("TRADE_SKILL_SHOW", "OnTradeSkillShow")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagsChanged")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("TOOLTIP_DATA_UPDATE")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	self:RegisterEvent("PROFESSION_EQUIPMENT_CHANGED")
	self:RegisterEvent("GOSSIP_CLOSED", "OnVenomSiphoned")
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "OnVenomSiphoned")
	self:RegisterEvent("CHAT_MSG_CURRENCY", "OnVenomSiphoned")

	self:InitUI()
	self:InitMinimap()
end

--- Обрабатывает слэш-команду `/fishstat`.
-- Без аргумента переключает окно; `reset` сбрасывает сессию; `minimap` скрывает или показывает кнопку у миникарты.
-- @param input string|nil текст после команды
function FishStat:SlashCommand(input)
	input = strtrim(input or ""):lower()
	if input == "" then
		self:ToggleWindow()
	elseif input == "reset" then
		self:ResetSession()
		self:Print(L["SESSION_RESET"])
	elseif input == "minimap" then
		self.db.char.minimap.hide = not self.db.char.minimap.hide
		self:UpdateMinimapVisibility()
	else
		self:Print(L["SLASH_HELP"])
	end
end

--- Обработчик `LOOT_READY`: учитывает рыболовный лут до автолута.
function FishStat:LOOT_READY()
	self:ProcessFishingLoot()
end

--- Обработчик `LOOT_OPENED`: учитывает рыболовный лут при открытии окна добычи.
function FishStat:LOOT_OPENED()
	self:ProcessFishingLoot()
end

--- Обработчик `LOOT_CLOSED`: сбрасывает флаг обработки и оставляет окно для чат-лута.
function FishStat:LOOT_CLOSED()
	self.lootHandled = false
	-- При автолуте CHAT_MSG_LOOT может прийти уже после LOOT_CLOSED
	if self.expectFishingChat then
		self.expectFishingChatUntil = GetTime() + 1.5
	end
end

--- Обработчик `CHAT_MSG_LOOT`: запасной разбор добычи из чата при автолуте.
-- @param _ string имя события (не используется)
-- @param message string текст сообщения о добыче
function FishStat:CHAT_MSG_LOOT(_, message)
	self:ProcessFishingChatLoot(message)
end

--- Обновляет интерфейс при смене зоны или подзоны.
function FishStat:OnZoneChanged()
	self:RefreshUI()
end

--- Обновляет интерфейс при изменении навыков или экипировки.
function FishStat:OnSkillChanged()
	self:RefreshUI()
end

--- Обновляет интерфейс при открытии окна профессии.
function FishStat:OnTradeSkillShow()
	self:RefreshUI()
end

--- После входа в мир сканирует сумки и обновляет интерфейс.
function FishStat:OnPlayerEnteringWorld()
	self:OnBagsChanged()
	self:RefreshUI()
end

--- Скрывает окно при входе в бой и запоминает, нужно ли вернуть его после боя.
function FishStat:PLAYER_REGEN_DISABLED()
	self:UpdateBaitSecureButton()
	if self:IsWindowShown() then
		self.wasShownBeforeCombat = true
		self:HideWindow(true)
	else
		self.wasShownBeforeCombat = false
	end
end

--- После выхода из боя восстанавливает окно и кнопку применения наживки.
function FishStat:PLAYER_REGEN_ENABLED()
	self:UpdateBaitSecureButton()
	if self.wasShownBeforeCombat or self.wantShowAfterCombat then
		self.wasShownBeforeCombat = false
		self.wantShowAfterCombat = false
		self:ShowWindow()
	end
end

--- Показывает или скрывает главное окно. В бою показ откладывается.
function FishStat:ToggleWindow()
	if self:IsWindowShown() then
		self:HideWindow()
	else
		if InCombatLockdown() then
			self.wantShowAfterCombat = true
			self:Print(L["IN_COMBAT"])
			return
		end
		self:ShowWindow()
	end
end
