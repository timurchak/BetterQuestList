local addonName, BQL = ...

_G.BetterQuestList = BQL

BQL.addonName = addonName
BQL.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
BQL.ICON_PATH = "Interface\\AddOns\\BetterQuestList\\Media\\BetterQuestListIcon.tga"

BQL.DAMAGE_METER_CATEGORIES = {
    "EnhanceQoLDamageMeter1",
    "EnhanceQoLDamageMeter2",
    "EnhanceQoLDamageMeter3",
    "EnhanceQoLDamageMeter4",
    "EnhanceQoLDamageMeter5",
}
BQL.LEGACY_DAMAGE_METER_CATEGORY = "EnhanceQoLDamageMeter"
BQL.ENHANCEQOL_MYTHIC_TIMER_CATEGORY = "EnhanceQoLMythicPlusTimer"
BQL.MYTHIC_PLUS_TIMER_CATEGORY = BQL.ENHANCEQOL_MYTHIC_TIMER_CATEGORY
BQL.MYTHIC_PLUS_TIMER_SOURCE_CHOICES = {
    "auto",
    "mythicPlusTimer",
    "enhanceQoL",
    "disabled",
}

BQL.DEFAULT_ORDER = {
    "EnhanceQoLMythicPlusTimer",
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
    "EnhanceQoLDamageMeter1",
    "EnhanceQoLDamageMeter2",
    "EnhanceQoLDamageMeter3",
    "EnhanceQoLDamageMeter4",
    "EnhanceQoLDamageMeter5",
}

BQL.FONT_CHOICES = { "default", "chat", "quest", "system" }
BQL.FONT_OUTLINE_CHOICES = { "default", "none", "outline", "thick" }
BQL.FONT_SHADOW_CHOICES = { "default", "enabled", "disabled" }
BQL.BACKGROUND_CHOICES = { "none", "subtle", "dark" }
BQL.CATEGORY_STYLE_CHOICES = { "blizzard", "plain" }
BQL.PROGRESS_BAR_STYLE_CHOICES = { "blizzard", "smooth", "flat" }

local BUILTIN_MEDIA = {
    font = {
        ["2002"] = "Fonts\\2002.TTF",
        ["2002 Bold"] = "Fonts\\2002B.TTF",
        ["AR CrystalzcuheiGBK Demibold"] = "Fonts\\ARHei.TTF",
        ["AR ZhongkaiGBK Medium (Combat)"] = "Fonts\\ARKai_C.TTF",
        ["AR ZhongkaiGBK Medium"] = "Fonts\\ARKai_T.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Friz Quadrata TT"] = GetLocale() == "ruRU"
            and "Fonts\\FRIZQT___CYR.TTF"
            or "Fonts\\FRIZQT__.TTF",
        ["MoK"] = "Fonts\\K_Pagetext.TTF",
        ["Morpheus"] = GetLocale() == "ruRU"
            and "Fonts\\MORPHEUS_CYR.TTF"
            or "Fonts\\MORPHEUS.TTF",
        ["Nimrod MT"] = "Fonts\\NIM_____.ttf",
        ["Skurri"] = GetLocale() == "ruRU"
            and "Fonts\\SKURRI_CYR.TTF"
            or "Fonts\\SKURRI.TTF",
    },
    statusbar = {
        ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["Blizzard Character Skills Bar"] =
            "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
        ["Blizzard Raid Bar"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        ["Solid"] = "Interface\\Buttons\\WHITE8X8",
    },
}

local function GetSharedMedia()
    if type(LibStub) ~= "table" and type(LibStub) ~= "function" then
        return nil
    end
    return LibStub("LibSharedMedia-3.0", true)
end

function BQL:GetMediaChoices(mediaType, includeBlizzardDefault)
    local names = {}
    local seen = {}
    local function AddName(name)
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end

    for name in pairs(BUILTIN_MEDIA[mediaType] or {}) do
        AddName(name)
    end
    local sharedMedia = GetSharedMedia()
    local hash = sharedMedia
        and sharedMedia.HashTable
        and sharedMedia:HashTable(mediaType)
    for name in pairs(hash or {}) do
        AddName(name)
    end
    table.sort(names, function(left, right)
        local leftLower = left:lower()
        local rightLower = right:lower()
        return leftLower == rightLower and left < right or leftLower < rightLower
    end)

    local choices = {}
    if includeBlizzardDefault then
        choices[1] = {
            value = "__blizzard",
            label = self.text and self.text.fontDefault or "Blizzard default",
        }
    end
    for _, name in ipairs(names) do
        choices[#choices + 1] = { value = name, label = name }
    end
    return choices
end

function BQL:ResolveMediaPath(mediaType, name, fallback)
    if name == "__blizzard" or type(name) ~= "string" or name == "" then
        return fallback
    end
    local sharedMedia = GetSharedMedia()
    if sharedMedia and sharedMedia.Fetch then
        local resolved = sharedMedia:Fetch(mediaType, name, true)
        if type(resolved) == "string" and resolved ~= "" then
            return resolved
        end
    end
    return (BUILTIN_MEDIA[mediaType] and BUILTIN_MEDIA[mediaType][name]) or fallback
end

function BQL:GetLegacyFontFace(value)
    if value == "chat" then
        return GetLocale() == "ruRU" and "Nimrod MT" or "Arial Narrow"
    elseif value == "quest" then
        return "Morpheus"
    elseif value == "system" then
        return "Skurri"
    end
    return "__blizzard"
end

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

function BQL:GetTooltip()
    if not self.tooltip then
        -- Do not inherit GameTooltipTemplate here. Even a separate addon-owned
        -- GameTooltip runs Blizzard's shared tooltip mixins; in Midnight that
        -- can taint the global map tooltip before it measures secret widgets.
        local tooltip = CreateFrame("Frame", "BetterQuestListTooltip", UIParent, "BackdropTemplate")
        tooltip:SetFrameStrata("TOOLTIP")
        tooltip:SetClampedToScreen(true)
        tooltip:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        tooltip:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
        tooltip:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
        tooltip:SetWidth(300)
        tooltip.lines = {}

        function tooltip:SetOwner(owner, anchor)
            self.owner = owner
            self.anchor = anchor
        end

        function tooltip:ResetLines()
            for _, line in ipairs(self.lines) do
                line:Hide()
                line:ClearAllPoints()
            end
            self.lineCount = 0
        end

        function tooltip:AddStyledLine(text, red, green, blue, isTitle)
            self.lineCount = (self.lineCount or 0) + 1
            local line = self.lines[self.lineCount]
            if not line then
                line = self:CreateFontString(
                    nil,
                    "ARTWORK",
                    isTitle and "GameTooltipHeaderText" or "GameTooltipText"
                )
                line:SetJustifyH("LEFT")
                line:SetJustifyV("TOP")
                line:SetWordWrap(true)
                self.lines[self.lineCount] = line
            end
            line:SetFontObject(isTitle and "GameTooltipHeaderText" or "GameTooltipText")
            line:SetWidth(280)
            line:SetText(text or "")
            line:SetTextColor(red or 1, green or 1, blue or 1)
            line:Show()
        end

        function tooltip:SetText(text, red, green, blue)
            self:ResetLines()
            self:AddStyledLine(text, red, green, blue, true)
        end

        function tooltip:AddLine(text, red, green, blue)
            self:AddStyledLine(text, red, green, blue, false)
        end

        function tooltip:ShowTooltip()
            local previousLine
            local contentHeight = 0
            for index = 1, self.lineCount or 0 do
                local line = self.lines[index]
                line:ClearAllPoints()
                if previousLine then
                    line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -4)
                else
                    line:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -10)
                end
                local lineHeight = line:GetStringHeight()
                if (issecretvalue and issecretvalue(lineHeight))
                    or type(lineHeight) ~= "number"
                then
                    lineHeight = 14
                end
                contentHeight = contentHeight + lineHeight + (previousLine and 4 or 0)
                previousLine = line
            end

            self:SetHeight(math.max(contentHeight + 20, 34))
            self:ClearAllPoints()
            if self.anchor == "ANCHOR_LEFT" then
                self:SetPoint("RIGHT", self.owner or UIParent, "LEFT", -8, 0)
            elseif self.anchor == "ANCHOR_RIGHT" then
                self:SetPoint("LEFT", self.owner or UIParent, "RIGHT", 8, 0)
            else
                self:SetPoint("BOTTOMLEFT", self.owner or UIParent, "TOPLEFT", 0, 8)
            end
            self:Show()
        end

        self.tooltip = tooltip
    end

    return self.tooltip
end

function BQL:HideTooltip()
    if self.tooltip then
        self.tooltip:Hide()
    end
end

function BQL:GetModuleLabel(name)
    local customLabel = self.db
        and self.db.categoryLabels
        and self.db.categoryLabels[name]
    if type(customLabel) == "string" and customLabel ~= "" then
        return customLabel
    end
    return self.fallbackLabels[name] or name
end

function BQL:GetDefaultModuleLabel(name)
    return self.fallbackLabels[name] or name
end

function BQL:GetCustomModuleLabel(name)
    local value = self.db
        and self.db.categoryLabels
        and self.db.categoryLabels[name]
    return type(value) == "string" and value or ""
end

function BQL:SetCustomModuleLabel(name, value)
    if not self.db or type(self.db.categoryLabels) ~= "table" then
        return
    end

    value = type(value) == "string" and strtrim(value) or ""
    if value == "" then
        self.db.categoryLabels[name] = nil
    else
        self.db.categoryLabels[name] = value
    end
    self:RequestCustomRefresh(false)
    if self.RefreshOptions then
        self:RefreshOptions()
    end
    if self.RefreshCategoryNames then
        self:RefreshCategoryNames()
    end
    if self.RefreshEditModeAppearancePanel then
        self:RefreshEditModeAppearancePanel()
    end
end

function BQL:ResetCustomModuleLabels()
    self.db.categoryLabels = {}
    self:RequestCustomRefresh(false)
    if self.RefreshOptions then
        self:RefreshOptions()
    end
    if self.RefreshCategoryNames then
        self:RefreshCategoryNames()
    end
    if self.RefreshEditModeAppearancePanel then
        self:RefreshEditModeAppearancePanel()
    end
end

function BQL:IsCategoryCollapsed(name)
    return self.db
        and type(self.db.collapsedCategories) == "table"
        and self.db.collapsedCategories[name] == true
end

function BQL:IsCategoryHeaderHidden(name)
    return self.db
        and type(self.db.hiddenCategoryHeaders) == "table"
        and self.db.hiddenCategoryHeaders[name] == true
end

function BQL:SetCategoryHeaderHidden(name, hidden)
    if not self.db or type(name) ~= "string" or name == "" then
        return false
    end
    if type(self.db.hiddenCategoryHeaders) ~= "table" then
        self.db.hiddenCategoryHeaders = {}
    end

    local shouldHide = hidden and true or false
    if (self.db.hiddenCategoryHeaders[name] == true) == shouldHide then
        return false
    end
    self.db.hiddenCategoryHeaders[name] = shouldHide and true or nil
    if self.RequestCustomRefresh then
        self:RequestCustomRefresh(false)
    end
    return true
end

function BQL:ToggleCategoryCollapsed(name)
    if not self.db or type(name) ~= "string" or name == "" then
        return
    end
    if type(self.db.collapsedCategories) ~= "table" then
        self.db.collapsedCategories = {}
    end
    if type(self.db.hiddenCategoryHeaders) ~= "table" then
        self.db.hiddenCategoryHeaders = {}
    end
    local hasMythicTimerCategory = false
    local scenarioCategoryIndex
    for index, category in ipairs(self.db.moduleOrder) do
        if category == self.ENHANCEQOL_MYTHIC_TIMER_CATEGORY then
            hasMythicTimerCategory = true
        elseif category == "ScenarioObjectiveTracker" then
            scenarioCategoryIndex = index
        end
    end
    if not hasMythicTimerCategory then
        table.insert(
            self.db.moduleOrder,
            scenarioCategoryIndex or 1,
            self.ENHANCEQOL_MYTHIC_TIMER_CATEGORY
        )
    end

    if self.db.collapsedCategories[name] then
        self.db.collapsedCategories[name] = nil
    else
        self.db.collapsedCategories[name] = true
    end
    self:RequestCustomRefresh(false)
end

function BQL:SetCategoryCollapsed(name, collapsed, refresh)
    if not self.db or type(name) ~= "string" or name == "" then
        return false
    end
    if type(self.db.collapsedCategories) ~= "table" then
        self.db.collapsedCategories = {}
    end

    local wasCollapsed = self.db.collapsedCategories[name] == true
    local shouldCollapse = collapsed and true or false
    if wasCollapsed == shouldCollapse then
        return false
    end

    self.db.collapsedCategories[name] = shouldCollapse and true or nil
    if refresh ~= false and self.RequestCustomRefresh then
        self:RequestCustomRefresh(false)
    end
    return true
end

function BQL:ExpandCategory(name, refresh)
    return self:SetCategoryCollapsed(name, false, refresh)
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

    for _, storedName in ipairs(self.db.moduleOrder or {}) do
        local name = storedName == self.LEGACY_DAMAGE_METER_CATEGORY
            and self.DAMAGE_METER_CATEGORIES[1]
            or storedName
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
    if self.RefreshCategoryNames then
        self:RefreshCategoryNames()
    end
end

function BQL:ResetOrder()
    self.db.moduleOrder = CopyArray(self.DEFAULT_ORDER)
    self:ApplyModuleOrder()
    if self.RefreshOptions then
        self:RefreshOptions()
    end
    if self.RefreshCategoryNames then
        self:RefreshCategoryNames()
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
    if type(self.db.categoryLabels) ~= "table" then
        self.db.categoryLabels = {}
    end
    if type(self.db.collapsedCategories) ~= "table" then
        self.db.collapsedCategories = {}
    end
    if self.db.categoryLabels[self.LEGACY_DAMAGE_METER_CATEGORY]
        and not self.db.categoryLabels[self.DAMAGE_METER_CATEGORIES[1]]
    then
        self.db.categoryLabels[self.DAMAGE_METER_CATEGORIES[1]] =
            self.db.categoryLabels[self.LEGACY_DAMAGE_METER_CATEGORY]
    end
    self.db.categoryLabels[self.LEGACY_DAMAGE_METER_CATEGORY] = nil
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
    if self.db.activeQuestItemEnabled == nil then
        self.db.activeQuestItemEnabled = false
    else
        self.db.activeQuestItemEnabled = self.db.activeQuestItemEnabled and true or false
    end
    if type(self.db.mythicPlusHideOtherCategories) ~= "boolean" then
        self.db.mythicPlusHideOtherCategories = false
    end
    if type(self.db.mythicPlusCollapseOtherCategories) ~= "boolean" then
        self.db.mythicPlusCollapseOtherCategories = false
    end
    if type(self.db.mythicPlusRaidHideTracker) ~= "boolean" then
        self.db.mythicPlusRaidHideTracker = false
    end
    if type(self.db.enhanceQoLMythicPlusTimerHeight) ~= "number" then
        self.db.enhanceQoLMythicPlusTimerHeight = 0
    end
    self.db.enhanceQoLMythicPlusTimerHeight = math.max(
        0,
        math.min(math.floor(self.db.enhanceQoLMythicPlusTimerHeight + 0.5), 600)
    )
    for _, key in ipairs({
        "mythicPlusTimerOffsetX",
        "mythicPlusTimerOffsetY",
    }) do
        local value = tonumber(self.db[key]) or 0
        self.db[key] = math.max(-100, math.min(math.floor(value + 0.5), 100))
    end
    if not IsChoiceValid(
        self.MYTHIC_PLUS_TIMER_SOURCE_CHOICES,
        self.db.mythicPlusTimerSource
    ) then
        self.db.mythicPlusTimerSource = "auto"
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
    if type(self.db.fontFace) ~= "string" or self.db.fontFace == "" then
        self.db.fontFace = self:GetLegacyFontFace(self.db.font)
    end
    if type(self.db.fontSize) ~= "number" then
        local defaultFontSize = 13
        if ObjectiveTrackerLineFont and ObjectiveTrackerLineFont.GetFont then
            local _, currentSize = ObjectiveTrackerLineFont:GetFont()
            if type(currentSize) == "number" then
                defaultFontSize = currentSize
            end
        end
        self.db.fontSize = defaultFontSize + (tonumber(self.db.fontSizeOffset) or 0)
    end
    self.db.fontSize = math.max(8, math.min(math.floor(self.db.fontSize + 0.5), 32))
    self.db.fontSizeOffset = nil
    if type(self.db.showQuestLevel) ~= "boolean" then
        self.db.showQuestLevel = false
    end
    if type(self.db.showQuestLocation) ~= "boolean" then
        self.db.showQuestLocation = true
    end
    if type(self.db.questLocationColor) ~= "table" then
        self.db.questLocationColor = { r = 0.65, g = 0.65, b = 0.65 }
    end
    for _, component in ipairs({ "r", "g", "b" }) do
        local value = tonumber(self.db.questLocationColor[component]) or 0.65
        self.db.questLocationColor[component] = math.max(0, math.min(value, 1))
    end
    if type(self.db.questTitleColor) ~= "table" then
        self.db.questTitleColor = { r = 1, g = 1, b = 1 }
    end
    for _, component in ipairs({ "r", "g", "b" }) do
        local value = tonumber(self.db.questTitleColor[component]) or 1
        self.db.questTitleColor[component] = math.max(0, math.min(value, 1))
    end
    if type(self.db.questCompleteColor) ~= "table" then
        self.db.questCompleteColor = { r = 0.3, g = 1, b = 0.3 }
    end
    if type(self.db.questLowLevelColor) ~= "table" then
        self.db.questLowLevelColor = { r = 0.55, g = 0.55, b = 0.55 }
    end
    for _, color in ipairs({ self.db.questCompleteColor, self.db.questLowLevelColor }) do
        for _, component in ipairs({ "r", "g", "b" }) do
            local value = tonumber(color[component]) or 1
            color[component] = math.max(0, math.min(value, 1))
        end
    end
    if type(self.db.questLowLevelThreshold) ~= "number" then
        self.db.questLowLevelThreshold = -5
    end
    self.db.questLowLevelThreshold = math.max(
        -20,
        math.min(math.floor(self.db.questLowLevelThreshold + 0.5), 0)
    )
    if not IsChoiceValid(self.PROGRESS_BAR_STYLE_CHOICES, self.db.progressBarStyle) then
        self.db.progressBarStyle = "blizzard"
    end
    if type(self.db.progressBarTexture) ~= "string" or self.db.progressBarTexture == "" then
        self.db.progressBarTexture = ({
            blizzard = "Blizzard",
            smooth = "Blizzard Raid Bar",
            flat = "Solid",
        })[self.db.progressBarStyle] or "Blizzard"
    end
    if type(self.db.progressBarHeight) ~= "number" then
        self.db.progressBarHeight = 15
    end
    self.db.progressBarHeight = math.max(
        8,
        math.min(math.floor(self.db.progressBarHeight + 0.5), 28)
    )
    if type(self.db.progressBarColor) ~= "table" then
        self.db.progressBarColor = { r = 0.26, g = 0.42, b = 1 }
    end
    for _, component in ipairs({ "r", "g", "b" }) do
        local value = tonumber(self.db.progressBarColor[component])
            or ({ r = 0.26, g = 0.42, b = 1 })[component]
        self.db.progressBarColor[component] = math.max(0, math.min(value, 1))
    end
    if type(self.db.progressBarBackgroundOpacity) ~= "number" then
        self.db.progressBarBackgroundOpacity = 95
    end
    self.db.progressBarBackgroundOpacity = math.max(
        0,
        math.min(math.floor(self.db.progressBarBackgroundOpacity + 0.5), 100)
    )
    if type(self.db.editModeCollapsedSections) ~= "table" then
        self.db.editModeCollapsedSections = {
            integrations = true,
            categories = true,
        }
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
    for _, setting in ipairs({
        { key = "questIconOffsetX", minimum = -100, maximum = 100 },
        { key = "questIconOffsetY", minimum = -50, maximum = 50 },
        { key = "questTitleOffsetX", minimum = -100, maximum = 100 },
        { key = "questTitleOffsetY", minimum = -50, maximum = 50 },
        { key = "questLocationOffsetX", minimum = -100, maximum = 100 },
        { key = "questLocationOffsetY", minimum = -50, maximum = 50 },
        { key = "questObjectiveOffsetX", minimum = -100, maximum = 100 },
        { key = "questObjectiveOffsetY", minimum = -50, maximum = 50 },
    }) do
        local value = tonumber(self.db[setting.key]) or 0
        self.db[setting.key] = math.max(
            setting.minimum,
            math.min(math.floor(value + 0.5), setting.maximum)
        )
    end
    if type(self.db.enhanceQoLDamageMeterWindows) ~= "table" then
        self.db.enhanceQoLDamageMeterWindows = {
            tonumber(self.db.enhanceQoLDamageMeterWindow) or 0,
        }
    end
    local assignedDamageMeterWindows = {}
    for slot = 1, #self.DAMAGE_METER_CATEGORIES do
        local windowIndex = tonumber(self.db.enhanceQoLDamageMeterWindows[slot]) or 0
        windowIndex = math.max(
            0,
            math.min(math.floor(windowIndex + 0.5), 5)
        )
        if windowIndex > 0 and assignedDamageMeterWindows[windowIndex] then
            windowIndex = 0
        elseif windowIndex > 0 then
            assignedDamageMeterWindows[windowIndex] = true
        end
        self.db.enhanceQoLDamageMeterWindows[slot] = windowIndex
    end
    self.db.enhanceQoLDamageMeterWindow = nil

    self:ReconcileOrder()

    SLASH_BETTERQUESTLIST1 = "/bql"
    SLASH_BETTERQUESTLIST2 = "/betterquestlist"
    SlashCmdList.BETTERQUESTLIST = HandleSlashCommand

    self:CreateOptions()
    self:InitializeCustomTracker()
    self:InitializeEnhanceQoLDamageMeterIntegration()
    self:InitializeMythicPlusTimerIntegration()
    self:InitializeActiveQuestItem()
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
