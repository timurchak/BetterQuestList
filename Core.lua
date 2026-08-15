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

function BQL:GetModuleName(module)
    if not module then
        return nil
    end

    local name = module.GetName and module:GetName()
    if name and name ~= "" then
        return name
    end

    for _, knownName in ipairs(self.DEFAULT_ORDER) do
        if _G[knownName] == module then
            return knownName
        end
    end

    return nil
end

function BQL:GetModuleLabel(name)
    local module = _G[name]
    local header = module and module.Header
    local text = header and header.Text and header.Text:GetText()
    if text and text ~= "" then
        return text
    end
    return self.fallbackLabels[name] or name
end

function BQL:GetAvailableModuleNames()
    local tracker = _G.ObjectiveTrackerFrame
    local names = {}
    local seen = {}

    if tracker and tracker.modules then
        for _, module in ipairs(tracker.modules) do
            local name = self:GetModuleName(module)
            if name and not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end

    for _, name in ipairs(self.DEFAULT_ORDER) do
        if _G[name] and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end

    return names
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
    if self.RefreshTrackerLayout then
        return self:RefreshTrackerLayout()
    end
    return true
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

function BQL:PrintDebugInfo()
    local state = self.scrollState
    local auraSecrets = C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() or false
    self:Print(("version=%s, scrolling=%s, layoutExpanded=%s, pending=%s, viewport=%.1f, content=%.1f, auraSecrets=%s"):format(
        self.version,
        tostring(state and state.enabled or false),
        tostring(state and state.layoutExpanded or false),
        tostring(state and state.pending or false),
        state and state.viewportHeight or 0,
        state and state.contentHeight or 0,
        tostring(auraSecrets)
    ))
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
    if self.db.schemaVersion ~= 2 then
        self.db.schemaVersion = 2
        self.db.scrollEnabled = true
    elseif self.db.scrollEnabled == nil then
        self.db.scrollEnabled = true
    end
    if type(self.db.scrollStep) ~= "number" then
        self.db.scrollStep = 45
    end

    SLASH_BETTERQUESTLIST1 = "/bql"
    SLASH_BETTERQUESTLIST2 = "/betterquestlist"
    SlashCmdList.BETTERQUESTLIST = HandleSlashCommand

    self:CreateOptions()
    self:InitializeScrolling()
    self:Print(self.text.restrictedMode)
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
            if BQL.RequestScrollingState then
                BQL:RequestScrollingState()
            end
        end)
    end
end)
