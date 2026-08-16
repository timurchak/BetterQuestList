local addonName, BQL = ...

_G.BetterQuestList = BQL

BQL.addonName = addonName
BQL.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
BQL.ICON_PATH = "Interface\\AddOns\\BetterQuestList\\Media\\BetterQuestListIcon.tga"

BQL.DEFAULT_ORDER = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "InitiativeTasksObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
}

BQL.FONT_CHOICES = { "default", "chat", "quest", "system" }
BQL.FONT_OUTLINE_CHOICES = { "default", "none", "outline", "thick" }
BQL.FONT_SHADOW_CHOICES = { "default", "enabled", "disabled" }
BQL.BACKGROUND_CHOICES = { "none", "subtle", "dark" }
BQL.CATEGORY_STYLE_CHOICES = { "blizzard", "plain" }

local function IsChoiceValid(choices, value)
    for _, choice in ipairs(choices) do
        if choice == value then
            return true
        end
    end
    return false
end

local function CopyArray(source)
    local result = {}
    for index, value in ipairs(source) do
        result[index] = value
    end
    return result
end

function BQL:Print(message)
    print(("|T%s:14:14:0:0|t |cff33ff99BetterQuestList:|r %s"):format(self.ICON_PATH, message))
end

function BQL:GetModuleLabel(name)
    return self.fallbackLabels[name] or name
end

function BQL:GetAvailableModuleNames()
    return CopyArray(self.DEFAULT_ORDER)
end

function BQL:ReconcileOrder()
    local available = self:GetAvailableModuleNames()
    local availableSet = {}
    local reconciled = {}
    local seen = {}

    for _, name in ipairs(available) do
        availableSet[name] = true
    end

    for _, name in ipairs(self.db.moduleOrder or {}) do
        if availableSet[name] and not seen[name] then
            seen[name] = true
            reconciled[#reconciled + 1] = name
        end
    end

    for _, name in ipairs(available) do
        if not seen[name] then
            seen[name] = true
            reconciled[#reconciled + 1] = name
        end
    end

    self.db.moduleOrder = reconciled
    return reconciled
end

function BQL:ApplyModuleOrder()
    self:ReconcileOrder()
    if self.RequestCustomRefresh then
        self:RequestCustomRefresh(false)
    end
    return true
end

function BQL:IsAcceptedQuestAutoTrackingEnabled()
    if not C_CVar or type(C_CVar.GetCVarBool) ~= "function" then
        return false
    end

    local ok, enabled = pcall(C_CVar.GetCVarBool, "autoQuestWatch")
    return ok and enabled and true or false
end

function BQL:SetAcceptedQuestAutoTrackingEnabled(enabled)
    if not C_CVar or type(C_CVar.SetCVar) ~= "function" then
        return false
    end

    local ok, changed = pcall(C_CVar.SetCVar, "autoQuestWatch", enabled and "1" or "0")
    return ok and changed ~= false
end

function BQL:AutoTrackAcceptedQuest(questID)
    if not self:IsAcceptedQuestAutoTrackingEnabled()
        or type(questID) ~= "number"
        or (issecretvalue and issecretvalue(questID))
        or not C_QuestLog
    then
        return false
    end

    local taskOK, isTask = pcall(C_QuestLog.IsQuestTask, questID)
    local bountyOK, isBounty = pcall(C_QuestLog.IsQuestBounty, questID)
    if not taskOK
        or not bountyOK
        or (issecretvalue and (issecretvalue(isTask) or issecretvalue(isBounty)))
        or isTask
        or isBounty
    then
        return false
    end

    local watchTypeOK, watchType = pcall(C_QuestLog.GetQuestWatchType, questID)
    if not watchTypeOK or (issecretvalue and issecretvalue(watchType)) then
        return false
    end
    if watchType ~= nil then
        return true
    end

    local countOK, watchCount = pcall(C_QuestLog.GetNumQuestWatches)
    if not countOK
        or type(watchCount) ~= "number"
        or (issecretvalue and issecretvalue(watchCount))
    then
        return false
    end

    local maximum = Constants
        and Constants.QuestWatchConsts
        and Constants.QuestWatchConsts.MAX_QUEST_WATCHES
    if type(maximum) == "number" and watchCount >= maximum then
        return false
    end

    local addOK, added = pcall(C_QuestLog.AddQuestWatch, questID)
    return addOK and added and true or false
end

function BQL:MoveModule(index, delta)
    local order = self:ReconcileOrder()
    local target = index + delta
    if target < 1 or target > #order then
        return
    end

    order[index], order[target] = order[target], order[index]
    self.db.moduleOrder = order
    self:ApplyModuleOrder()
    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

function BQL:ResetOrder()
    self.db.moduleOrder = CopyArray(self.DEFAULT_ORDER)
    self:ApplyModuleOrder()
    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

function BQL:OpenOptions()
    if Settings and Settings.OpenToCategory and self.settingsCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
        return
    end
    self:Print(self.text.optionsUnavailable)
end

function BQL:ShowDebugWindow(report)
    local frame = self.debugWindow
    if not frame then
        frame = CreateFrame("Frame", "BetterQuestListDebugWindow", UIParent, "BackdropTemplate")
        frame:SetSize(720, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -16)
        frame.title = title

        local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        hint:SetTextColor(0.75, 0.75, 0.75)
        frame.hint = hint

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -5, -5)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -62)
        scroll:SetPoint("BOTTOMRIGHT", -38, 18)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetJustifyH("LEFT")
        editBox:SetJustifyV("TOP")
        editBox:SetWidth(650)
        editBox:SetHeight(4000)
        editBox:SetTextInsets(4, 4, 4, 4)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            frame:Hide()
        end)
        scroll:SetScrollChild(editBox)

        frame.scroll = scroll
        frame.editBox = editBox
        self.debugWindow = frame
    end

    frame.title:SetText(self.text.debugWindowTitle)
    frame.hint:SetText(self.text.debugCopyHint)
    frame.editBox:SetText(report or "No diagnostic data available.")
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText()
    frame:Show()
    frame.editBox:SetFocus()
end

function BQL:ShowCopyTextWindow(titleText, hintText, value)
    local frame = self.copyTextWindow
    if not frame then
        frame = CreateFrame("Frame", "BetterQuestListCopyTextWindow", UIParent, "BackdropTemplate")
        frame:SetSize(560, 145)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -18)
        frame.title = title

        local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
        hint:SetTextColor(0.75, 0.75, 0.75)
        frame.hint = hint

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -5, -5)

        local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        editBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 4, -16)
        editBox:SetWidth(500)
        editBox:SetHeight(30)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            frame:Hide()
        end)
        editBox:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
        end)
        frame.editBox = editBox
        self.copyTextWindow = frame
    end

    frame.title:SetText(titleText or self.text.title)
    frame.hint:SetText(hintText or "")
    frame.editBox:SetText(value or "")
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText()
    frame:Show()
    frame.editBox:SetFocus()
end

function BQL:PrintDebugInfo()
    local report = self.CollectCustomDebugInfo and self:CollectCustomDebugInfo()
        or "BetterQuestList custom tracker is not initialized."
    self:ShowDebugWindow(report)
    self:Print(self.text.debugOpened)
end

local function HandleSlashCommand(input)
    local command = strtrim(input or ""):lower()
    if command == "reset" then
        BQL:ResetOrder()
        BQL:Print(BQL.text.resetDone)
    elseif command == "scroll" then
        BQL.db.scrollEnabled = not BQL.db.scrollEnabled
        BQL:SetScrollingEnabled(BQL.db.scrollEnabled)
        BQL:Print(BQL.db.scrollEnabled and BQL.text.scrollOn or BQL.text.scrollOff)
    elseif command == "debug" then
        BQL:PrintDebugInfo()
    else
        BQL:OpenOptions()
    end
end

function BQL:Initialize()
    BetterQuestListDB = BetterQuestListDB or {}
    self.db = BetterQuestListDB

    if type(self.db.moduleOrder) ~= "table" then
        self.db.moduleOrder = CopyArray(self.DEFAULT_ORDER)
    end
    if self.db.schemaVersion ~= 3 then
        self.db.schemaVersion = 3
        self.db.scrollEnabled = true
        self.db.collapsed = false
    end
    if self.db.scrollEnabled == nil then
        self.db.scrollEnabled = true
    end
    if self.db.collapsed == nil then
        self.db.collapsed = false
    end
    if type(self.db.scrollStep) ~= "number" then
        self.db.scrollStep = 45
    end
    if not IsChoiceValid(self.FONT_CHOICES, self.db.font) then
        self.db.font = "default"
    end
    if not IsChoiceValid(self.FONT_OUTLINE_CHOICES, self.db.fontOutline) then
        self.db.fontOutline = "default"
    end
    if not IsChoiceValid(self.FONT_SHADOW_CHOICES, self.db.fontShadow) then
        self.db.fontShadow = "default"
    end
    if not IsChoiceValid(self.BACKGROUND_CHOICES, self.db.background) then
        self.db.background = "subtle"
    end
    if not IsChoiceValid(self.CATEGORY_STYLE_CHOICES, self.db.categoryStyle) then
        self.db.categoryStyle = "blizzard"
    end
    if self.db.appearanceSchemaVersion ~= 1 then
        if self.db.categoryOffset == nil then
            self.db.categoryOffset = 5
        end
        self.db.appearanceSchemaVersion = 1
    end
    if type(self.db.categoryOffset) ~= "number" then
        self.db.categoryOffset = 5
    end
    self.db.categoryOffset = math.max(-20, math.min(math.floor(self.db.categoryOffset + 0.5), 20))
    if type(self.db.categoryTextOffset) ~= "number" then
        self.db.categoryTextOffset = 30
    end
    self.db.categoryTextOffset = math.max(
        -100,
        math.min(math.floor(self.db.categoryTextOffset + 0.5), 100)
    )
    if type(self.db.categorySpacing) ~= "number" then
        self.db.categorySpacing = 10
    end
    self.db.categorySpacing = math.max(
        0,
        math.min(math.floor(self.db.categorySpacing + 0.5), 30)
    )
    if type(self.db.questSpacing) ~= "number" then
        self.db.questSpacing = 0
    end
    self.db.questSpacing = math.max(0, math.min(math.floor(self.db.questSpacing + 0.5), 30))
    if type(self.db.questObjectiveSpacing) ~= "number" then
        self.db.questObjectiveSpacing = 0
    end
    self.db.questObjectiveSpacing = math.max(
        0,
        math.min(math.floor(self.db.questObjectiveSpacing + 0.5), 20)
    )

    self:ReconcileOrder()

    SLASH_BETTERQUESTLIST1 = "/bql"
    SLASH_BETTERQUESTLIST2 = "/betterquestlist"
    SlashCmdList.BETTERQUESTLIST = HandleSlashCommand

    self:CreateOptions()
    self:InitializeCustomTracker()
    self:InitializeEditModeIntegration()
    self:Print(self.text.customMode)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            BQL:Initialize()
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0, function()
            local _, kalielsLoaded = C_AddOns.IsAddOnLoaded("!KalielsTracker")
            if kalielsLoaded and not BQL.kalielsWarningShown then
                BQL.kalielsWarningShown = true
                BQL:Print(BQL.text.kalielsConflict)
            end
            if BQL.RequestCustomRefresh then
                BQL:RequestCustomRefresh(true)
            end
        end)
    end
end)
