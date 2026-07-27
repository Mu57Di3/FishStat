local FishStat = LibStub("AceAddon-3.0"):NewAddon("FishStat", "AceEvent-3.0", "AceConsole-3.0")
_G.FishStat = FishStat

local L = LibStub("AceLocale-3.0"):GetLocale("FishStat")

-- Per-character saved data (window, minimap, total catches)
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
	},
}

function FishStat:MigrateWindowSettings()
	local w = self.db.char.window
	-- Legacy boolean showSession → activeTab
	if w.showSession ~= nil then
		w.activeTab = w.showSession and "session" or "total"
		w.showSession = nil
	end
	if not w.activeTab then
		w.activeTab = "session"
	end
end

function FishStat:GetActiveTab()
	return self.db.char.window.activeTab or "session"
end

function FishStat:SetActiveTab(tab)
	self.db.char.window.activeTab = tab
	self:RefreshUI()
end

function FishStat:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("FishStatDB", defaults, true)
	self:MigrateWindowSettings()
	self.session = {}
	self.baitList = {}
	self.wasShownBeforeCombat = false
	self.wantShowAfterCombat = false
	self.lootHandled = false
	self.expectFishingChat = false
	self.expectFishingChatUntil = 0

	self:RegisterChatCommand("fishstat", "SlashCommand")
end

function FishStat:OnEnable()
	-- LOOT_READY fires before autoloot empties slots (Shift+RMB / autoLootDefault)
	self:RegisterEvent("LOOT_READY")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_CLOSED")
	self:RegisterEvent("CHAT_MSG_LOOT")
	self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnZoneChanged")
	self:RegisterEvent("SKILL_LINES_CHANGED", "OnSkillChanged")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnSkillChanged")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagsChanged")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnBagsChanged")

	self:InitUI()
	self:InitMinimap()
end

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

function FishStat:LOOT_READY()
	self:ProcessFishingLoot()
end

function FishStat:LOOT_OPENED()
	self:ProcessFishingLoot()
end

function FishStat:LOOT_CLOSED()
	self.lootHandled = false
	-- CHAT_MSG_LOOT can arrive after LOOT_CLOSED when autolooting
	if self.expectFishingChat then
		self.expectFishingChatUntil = GetTime() + 1.5
	end
end

function FishStat:CHAT_MSG_LOOT(_, message)
	self:ProcessFishingChatLoot(message)
end

function FishStat:OnZoneChanged()
	self:RefreshUI()
end

function FishStat:OnSkillChanged()
	self:RefreshUI()
end

function FishStat:PLAYER_REGEN_DISABLED()
	self:UpdateBaitSecureButton()
	if self:IsWindowShown() then
		self.wasShownBeforeCombat = true
		self:HideWindow(true)
	else
		self.wasShownBeforeCombat = false
	end
end

function FishStat:PLAYER_REGEN_ENABLED()
	self:UpdateBaitSecureButton()
	if self.wasShownBeforeCombat or self.wantShowAfterCombat then
		self.wasShownBeforeCombat = false
		self.wantShowAfterCombat = false
		self:ShowWindow()
	end
end

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
