local addonName, BQL = ...

_G.BetterQuestList = BQL

BQL.addonName = addonName
BQL.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

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

local isRussian = GetLocale() == "ruRU"

BQL.text = isRussian and {
    title = "BetterQuestList",
    description = "Использует стандартный трекер Blizzard и добавляет только порядок категорий и прокрутку колесом мыши.",
    order = "Порядок категорий",
    scrolling = "Прокрутка колесом мыши",
    scrollingDescription = "Показывает все отслеживаемые цели и прокручивает их внутри стандартного трекера.",
    reset = "Сбросить порядок",
    moveUp = "Переместить выше",
    moveDown = "Переместить ниже",
    optionsUnavailable = "Не удалось открыть настройки.",
    resetDone = "Порядок категорий сброшен.",
    scrollOn = "Прокрутка включена.",
    scrollOff = "Прокрутка выключена.",
    debugUnavailable = "Стандартный трекер ещё не готов.",
    kalielsConflict = "Для проверки отключите !KalielsTracker: он заменяет стандартный трекер Blizzard.",
} or {
    title = "BetterQuestList",
    description = "Keeps Blizzard's Objective Tracker renderer and adds only category ordering and mouse-wheel scrolling.",
    order = "Category order",
    scrolling = "Mouse-wheel scrolling",
    scrollingDescription = "Renders all tracked objectives and scrolls them inside Blizzard's tracker.",
    reset = "Reset order",
    moveUp = "Move up",
    moveDown = "Move down",
    optionsUnavailable = "Could not open the settings panel.",
    resetDone = "Category order reset.",
    scrollOn = "Scrolling enabled.",
    scrollOff = "Scrolling disabled.",
    debugUnavailable = "Blizzard's tracker is not ready yet.",
    kalielsConflict = "Disable !KalielsTracker while testing; it replaces Blizzard's Objective Tracker.",
}

BQL.fallbackLabels = isRussian and {
    ScenarioObjectiveTracker = "Сценарий",
    UIWidgetObjectiveTracker = "События",
    CampaignQuestObjectiveTracker = "Кампания",
    QuestObjectiveTracker = "Задания",
    AdventureObjectiveTracker = "Приключения",
    AchievementObjectiveTracker = "Достижения",
    MonthlyActivitiesObjectiveTracker = "Журнал путешественника",
    InitiativeTasksObjectiveTracker = "Начинания",
    ProfessionsRecipeTracker = "Рецепты профессий",
    BonusObjectiveTracker = "Бонусные цели",
    WorldQuestObjectiveTracker = "Локальные задания",
} or {
    ScenarioObjectiveTracker = "Scenario",
    UIWidgetObjectiveTracker = "Events",
    CampaignQuestObjectiveTracker = "Campaign",
    QuestObjectiveTracker = "Quests",
    AdventureObjectiveTracker = "Adventures",
    AchievementObjectiveTracker = "Achievements",
    MonthlyActivitiesObjectiveTracker = "Traveler's Log",
    InitiativeTasksObjectiveTracker = "Endeavors",
    ProfessionsRecipeTracker = "Profession Recipes",
    BonusObjectiveTracker = "Bonus Objectives",
    WorldQuestObjectiveTracker = "World Quests",
}

local function CopyArray(source)
    local result = {}
    for index, value in ipairs(source) do
        result[index] = value
    end
    return result
end

function BQL:Print(message)
    print("|cff33ff99BetterQuestList:|r " .. message)
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
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker or not tracker.modules then
        return
    end

    local order = self:ReconcileOrder()
    local indexByName = {}
    for index, name in ipairs(order) do
        indexByName[name] = index
    end

    local nextOrder = #order + 1
    for _, module in ipairs(tracker.modules) do
        local name = self:GetModuleName(module)
        module.uiOrder = indexByName[name] or nextOrder
        if not indexByName[name] then
            nextOrder = nextOrder + 1
        end
    end

    tracker.needsSorting = true
    tracker:MarkDirty()
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
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker or not tracker.modules then
        self:Print(self.text.debugUnavailable)
        return
    end

    local scrollState = self.scrollState
    local scrollRange = scrollState and scrollState.frame:GetVerticalScrollRange() or 0
    self:Print(("version=%s, scrolling=%s, range=%.1f"):format(
        self.version,
        tostring(scrollState and scrollState.enabled or false),
        scrollRange
    ))
    for index, module in ipairs(tracker.modules) do
        local parent = module:GetParent()
        local parentName = parent and parent:GetName() or "<anonymous>"
        self:Print(("%d. %s (uiOrder=%s, parent=%s)"):format(
            index,
            self:GetModuleName(module) or "<anonymous>",
            tostring(module.uiOrder),
            parentName
        ))
    end
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
    if self.db.scrollEnabled == nil then
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
            BQL:ApplyModuleOrder()
            BQL:SetScrollingEnabled(BQL.db.scrollEnabled)
        end)
    end
end)


