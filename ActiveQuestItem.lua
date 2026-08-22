local _, BQL = ...

local BUTTON_SIZE = 44
local UPDATE_INTERVAL = 0.75
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_POSITION_X = 0
local DEFAULT_POSITION_Y = -180
local CATEGORY_SCENARIO = "ScenarioObjectiveTracker"

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function IsSafeNumber(value)
    return type(value) == "number" and not IsSecret(value)
end

local function GetSuperTrackedQuestID()
    if not C_SuperTrack or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then
        return nil
    end
    local ok, questID = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if not ok or IsSecret(questID) or type(questID) ~= "number" or questID <= 0 then
        return nil
    end
    return questID
end

local function IsInsideQuestBlob(questID)
    if not C_Minimap or type(C_Minimap.IsInsideQuestBlob) ~= "function" then
        return false
    end
    local ok, inside = pcall(C_Minimap.IsInsideQuestBlob, questID)
    return ok and not IsSecret(inside) and inside and true or false
end

local function GetQuestDistance(questID)
    if not C_QuestLog or type(C_QuestLog.GetDistanceSqToQuest) ~= "function" then
        return nil
    end
    local ok, distance, onContinent = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
    if not ok or IsSecret(distance) or IsSecret(onContinent) or not IsSafeNumber(distance) then
        return nil
    end
    if onContinent == false then
        return nil
    end
    return distance
end

local function GetQuestItemInfo(questLogIndex)
    if type(GetQuestLogSpecialItemInfo) ~= "function" then
        return nil
    end

    local ok, itemLink, icon, charges, showWhenComplete = pcall(
        GetQuestLogSpecialItemInfo,
        questLogIndex
    )
    if not ok
        or IsSecret(itemLink)
        or IsSecret(icon)
        or IsSecret(charges)
        or IsSecret(showWhenComplete)
        or type(itemLink) ~= "string"
        or itemLink == ""
        or (type(icon) ~= "number" and type(icon) ~= "string")
    then
        return nil
    end

    return {
        itemLink = itemLink,
        icon = icon,
        charges = type(charges) == "number" and charges or 0,
        showWhenComplete = showWhenComplete and true or false,
    }
end

local function CollectCandidates(addon)
    local snapshot = addon.customState and addon.customState.snapshot
    if not snapshot or type(snapshot.categories) ~= "table" then
        return {}
    end

    local superTrackedQuestID = GetSuperTrackedQuestID()
    local candidates = {}
    local sequence = 0
    for _, category in ipairs(addon:ReconcileOrder()) do
        for _, quest in ipairs(snapshot.categories[category] or {}) do
            if quest.showsItem
                and IsSafeNumber(quest.questID)
                and IsSafeNumber(quest.questLogIndex)
            then
                sequence = sequence + 1
                local priority = 3
                local distance = math.huge
                if quest.questID == superTrackedQuestID then
                    priority = 0
                elseif IsInsideQuestBlob(quest.questID) then
                    priority = 1
                else
                    local questDistance = GetQuestDistance(quest.questID)
                    if questDistance then
                        priority = 2
                        distance = questDistance
                    end
                end
                candidates[#candidates + 1] = {
                    quest = quest,
                    priority = priority,
                    distance = distance,
                    sequence = sequence,
                }
            end
        end
    end

    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        if left.distance ~= right.distance then
            return left.distance < right.distance
        end
        return left.sequence < right.sequence
    end)
    return candidates
end

local function SelectQuestItem(addon)
    for _, candidate in ipairs(CollectCandidates(addon)) do
        local item = GetQuestItemInfo(candidate.quest.questLogIndex)
        if item then
            item.questID = candidate.quest.questID
            item.questLogIndex = candidate.quest.questLogIndex
            item.questTitle = candidate.quest.title
            item.kind = "item"
            return item
        end
    end
    return nil
end

local function SelectScenarioSpell(addon)
    local snapshot = addon.customState and addon.customState.snapshot
    local scenarios = snapshot
        and snapshot.categories
        and snapshot.categories[CATEGORY_SCENARIO]
    local scenario = type(scenarios) == "table" and scenarios[1] or nil
    if type(scenario) ~= "table" or type(scenario.scenarioSpells) ~= "table" then
        return nil
    end

    for _, spellInfo in ipairs(scenario.scenarioSpells) do
        if IsSafeNumber(spellInfo.spellID) and spellInfo.spellID > 0 then
            return {
                kind = "spell",
                spellID = spellInfo.spellID,
                icon = spellInfo.spellIcon or DEFAULT_ICON,
                spellName = spellInfo.spellName,
                scenarioTitle = scenario.stageName or scenario.title,
            }
        end
    end
    return nil
end

local function SelectActiveAction(addon)
    return SelectScenarioSpell(addon) or SelectQuestItem(addon)
end

local function ClearSecureAction(state)
    state.button:SetAttribute("type", nil)
    state.button:SetAttribute("item", nil)
    state.button:SetAttribute("spell", nil)
    state.button:SetAttribute("questLogIndex", nil)
    state.button:SetAttribute("questID", nil)
end

function BQL:ApplyActiveQuestItemPosition()
    local state = self.activeQuestItem
    if not state or not state.frame then
        return
    end

    local position = self.db and self.db.activeQuestItemPosition
    local x = position and position.x
    local y = position and position.y
    if not IsSafeNumber(x) or not IsSafeNumber(y) then
        x = DEFAULT_POSITION_X
        y = DEFAULT_POSITION_Y
    end

    state.frame:ClearAllPoints()
    state.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function BQL:SaveActiveQuestItemPosition()
    local state = self.activeQuestItem
    if not state or not state.frame or not self.db then
        return
    end

    local frameX, frameY = state.frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not IsSafeNumber(frameX)
        or not IsSafeNumber(frameY)
        or not IsSafeNumber(parentX)
        or not IsSafeNumber(parentY)
    then
        return
    end

    self.db.activeQuestItemPosition = {
        x = frameX - parentX,
        y = frameY - parentY,
    }
    self:ApplyActiveQuestItemPosition()
end

function BQL:SetActiveQuestItemEnabled(enabled)
    if not self.db then
        return
    end
    self.db.activeQuestItemEnabled = enabled and true or false
    self:UpdateActiveQuestItemButton(true)
    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

function BQL:UpdateActiveQuestItemButton(force)
    local state = self.activeQuestItem
    if not state or not state.button or not self.db then
        return
    end
    if InCombatLockdown() then
        state.pendingUpdate = true
        return
    end

    state.pendingUpdate = false
    if not self.db.activeQuestItemEnabled then
        ClearSecureAction(state)
        state.currentActionKind = nil
        state.currentItemLink = nil
        state.currentSpellID = nil
        state.currentQuestID = nil
        state.currentActionTitle = nil
        state.currentActionName = nil
        state.count:SetText("")
        state.icon:SetTexture(DEFAULT_ICON)
        state.frame:Hide()
        return
    end

    local action = SelectActiveAction(self)
    if action then
        local changed = force
            or state.currentActionKind ~= action.kind
            or state.currentItemLink ~= action.itemLink
            or state.currentSpellID ~= action.spellID
            or state.currentQuestID ~= action.questID
        if changed then
            ClearSecureAction(state)
            state.button:SetAttribute("type", action.kind)
            if action.kind == "spell" then
                state.button:SetAttribute("spell", action.spellID)
            else
                state.button:SetAttribute("item", action.itemLink)
                state.button:SetAttribute("questLogIndex", action.questLogIndex)
                state.button:SetAttribute("questID", action.questID)
            end
        end
        state.currentActionKind = action.kind
        state.currentItemLink = action.itemLink
        state.currentSpellID = action.spellID
        state.currentQuestID = action.questID
        state.currentActionTitle = action.scenarioTitle or action.questTitle
        state.currentActionName = action.spellName
        state.icon:SetTexture(action.icon)
        state.count:SetText(action.charges and action.charges > 1 and action.charges or "")
        state.frame:Show()
    else
        ClearSecureAction(state)
        state.currentActionKind = nil
        state.currentItemLink = nil
        state.currentSpellID = nil
        state.currentQuestID = nil
        state.currentActionTitle = nil
        state.currentActionName = nil
        state.count:SetText("")
        state.icon:SetTexture(DEFAULT_ICON)
        state.frame:SetShown(state.editModeActive and true or false)
    end
end

function BQL:InitializeActiveQuestItemEditMode()
    local state = self.activeQuestItem
    if not state or state.overlay then
        return
    end

    local overlay = CreateFrame(
        "Frame",
        "BetterQuestListActiveQuestItemEditModeOverlay",
        state.frame,
        "EditModeSystemSelectionTemplate"
    )
    overlay:SetAllPoints(state.frame)
    overlay:SetFrameLevel(state.button:GetFrameLevel() + 20)
    overlay:SetSystem({
        GetSystemName = function()
            return self.text.activeQuestItemEditModeName
        end,
    })
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() or not self.db.activeQuestItemEnabled then
            return
        end
        state.frame:StartMoving()
        if overlay.ShowSelected then
            overlay:ShowSelected()
        end
    end)
    overlay:SetScript("OnDragStop", function()
        state.frame:StopMovingOrSizing()
        self:SaveActiveQuestItemPosition()
        if overlay.ShowHighlighted then
            overlay:ShowHighlighted()
        end
    end)
    overlay:Hide()
    state.overlay = overlay
end

function BQL:OnActiveQuestItemEditModeEnter()
    local state = self.activeQuestItem
    if not state then
        return
    end
    state.editModeActive = true
    self:UpdateActiveQuestItemButton(true)
    if self.db.activeQuestItemEnabled and state.overlay then
        state.overlay:ShowHighlighted()
    end
end

function BQL:OnActiveQuestItemEditModeExit()
    local state = self.activeQuestItem
    if not state then
        return
    end
    if state.overlay then
        state.overlay:Hide()
    end
    state.editModeActive = false
    self:UpdateActiveQuestItemButton(true)
end

function BQL:InitializeActiveQuestItem()
    if self.activeQuestItem then
        return
    end

    local frame = CreateFrame("Frame", "BetterQuestListActiveQuestItemFrame", UIParent)
    frame:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetDontSavePosition(true)

    local button = CreateFrame(
        "Button",
        "BetterQuestListActiveQuestItemButton",
        frame,
        "SecureActionButtonTemplate"
    )
    button:SetAllPoints(frame)
    -- Secure spell actions follow ActionButtonUseKeyDown. Register both phases
    -- like Blizzard/Kaliel action buttons so the cast is not discarded when
    -- the client expects the protected click on mouse-down.
    button:RegisterForClicks("AnyDown", "AnyUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(DEFAULT_ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetAllPoints(button)
    end

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")

    button:SetScript("OnEnter", function()
        local state = self.activeQuestItem
        if not state or not state.currentActionKind then
            return
        end
        local tooltip = self:GetTooltip()
        tooltip:SetOwner(button, "ANCHOR_RIGHT")
        tooltip:SetText(state.currentActionTitle or self.text.activeQuestItemEditModeName)
        if state.currentItemLink then
            tooltip:AddLine(state.currentItemLink, 1, 1, 1)
        elseif state.currentActionName then
            tooltip:AddLine(state.currentActionName, 1, 1, 1)
        end
        tooltip:AddLine(self.text.activeQuestItemHint, 0.7, 0.7, 0.7)
        tooltip:ShowTooltip()
    end)
    button:SetScript("OnLeave", function()
        self:HideTooltip()
    end)

    local events = CreateFrame("Frame")
    for _, eventName in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "SUPER_TRACKING_CHANGED",
        "BAG_UPDATE_DELAYED",
        "ITEM_DATA_LOAD_RESULT",
        "SCENARIO_UPDATE",
        "SCENARIO_SPELL_UPDATE",
        "ACTIVE_DELVE_DATA_UPDATE",
    }) do
        events:RegisterEvent(eventName)
    end
    events:SetScript("OnEvent", function()
        C_Timer.After(0, function()
            if self.activeQuestItem then
                self:UpdateActiveQuestItemButton()
            end
        end)
    end)
    events:SetScript("OnUpdate", function(_, elapsed)
        local state = self.activeQuestItem
        if not state or not self.db.activeQuestItemEnabled or state.editModeActive then
            return
        end
        state.elapsed = (state.elapsed or 0) + elapsed
        if state.elapsed >= UPDATE_INTERVAL then
            state.elapsed = 0
            self:UpdateActiveQuestItemButton()
        end
    end)

    self.activeQuestItem = {
        frame = frame,
        button = button,
        icon = icon,
        count = count,
        events = events,
    }
    self:ApplyActiveQuestItemPosition()
    frame:Hide()
    self:UpdateActiveQuestItemButton(true)
end
