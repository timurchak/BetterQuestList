local _, BQL = ...

local FULL_CONTENT_HEIGHT = 100000
local VIEWPORT_LEFT_OVERFLOW = 36
local VIEWPORT_RIGHT_OVERFLOW = 8

local function SaveAnchors(frame)
    local anchors = {}
    for index = 1, frame:GetNumPoints() do
        anchors[index] = { frame:GetPoint(index) }
    end
    return anchors
end

local function RestoreAnchors(frame, anchors)
    frame:ClearAllPoints()
    for _, anchor in ipairs(anchors or {}) do
        frame:SetPoint(unpack(anchor))
    end
end

function BQL:InitializeScrolling()
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker then
        return
    end

    self.scrollState = {
        tracker = tracker,
        enabled = false,
        originalTopModulePadding = tracker.topModulePadding or 0,
        originalGetAvailableHeight = tracker.GetAvailableHeight,
        nineSliceAnchors = nil,
    }

    local scrollFrame = CreateFrame("ScrollFrame", "BetterQuestListScrollFrame", tracker)
    scrollFrame:SetPoint(
        "TOPLEFT",
        tracker,
        "TOPLEFT",
        -VIEWPORT_LEFT_OVERFLOW,
        -self.scrollState.originalTopModulePadding
    )
    scrollFrame:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", VIEWPORT_RIGHT_OVERFLOW, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollChild = CreateFrame("Frame", "BetterQuestListScrollChild", scrollFrame)
    scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", VIEWPORT_LEFT_OVERFLOW, 0)
    scrollChild:SetSize(math.max(tracker:GetWidth(), 1), 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:Hide()

    scrollFrame:SetScript("OnMouseWheel", function(frame, delta)
        if not self.scrollState.enabled then
            return
        end

        local current = frame:GetVerticalScroll()
        local maximum = frame:GetVerticalScrollRange()
        local target = current - (delta * self.db.scrollStep)
        frame:SetVerticalScroll(math.max(0, math.min(target, maximum)))
    end)

    self.scrollState.frame = scrollFrame
    self.scrollState.child = scrollChild

    local combatFrame = CreateFrame("Frame")
    combatFrame:SetScript("OnEvent", function(frame)
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local desired = self.scrollState.pendingEnabled
        self.scrollState.pendingEnabled = nil
        if desired ~= nil then
            self:SetScrollingEnabled(desired)
        end
    end)
    self.scrollState.combatFrame = combatFrame

    hooksecurefunc(tracker, "Update", function()
        if self.scrollState.enabled then
            self:RefreshScrollLayout()
        end
    end)

    hooksecurefunc(ObjectiveTrackerManager, "SetModuleContainer", function(_, module, container)
        if self.scrollState.enabled and container == tracker then
            if InCombatLockdown() then
                self.scrollState.pendingEnabled = true
                combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            else
                module:SetParent(scrollChild)
                module.isDirty = true
            end
        end
    end)

    hooksecurefunc(ObjectiveTrackerManager, "Init", function()
        C_Timer.After(0, function()
            self:ApplyModuleOrder()
            self:SetScrollingEnabled(self.db.scrollEnabled)
        end)
    end)
end

function BQL:GetFullContentHeight()
    local state = self.scrollState
    local tracker = state and state.tracker
    if not tracker then
        return 0
    end

    local height = 0
    local hasPrevious = false
    for _, module in ipairs(tracker.modules or {}) do
        local moduleHeight = module:GetContentsHeight()
        if moduleHeight > 0 then
            if hasPrevious then
                height = height + (tracker.moduleSpacing or 0)
            end
            height = height + moduleHeight
            hasPrevious = true
        end
    end

    return height + (tracker.bottomModulePadding or 0)
end

function BQL:RefreshScrollLayout()
    local state = self.scrollState
    if not state or not state.enabled then
        return
    end

    local tracker = state.tracker
    local scrollFrame = state.frame
    local scrollChild = state.child

    -- The Blizzard modules are laid out against the tracker's original width. The
    -- viewport is deliberately wider only to avoid clipping POIs and decorations
    -- which extend past that width on either side.
    scrollChild:SetWidth(math.max(tracker:GetWidth(), 1))
    scrollChild:SetHeight(math.max(scrollFrame:GetHeight(), self:GetFullContentHeight(), 1))

    local maximum = math.max(scrollChild:GetHeight() - scrollFrame:GetHeight(), 0)
    if scrollFrame:GetVerticalScroll() > maximum then
        scrollFrame:SetVerticalScroll(maximum)
    end

    if tracker.NineSlice then
        tracker.NineSlice:ClearAllPoints()
        tracker.NineSlice:SetPoint("TOPLEFT", tracker, "TOPLEFT", -30, 0)
        tracker.NineSlice:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 5, 0)
    end
end

function BQL:EnableScrolling()
    local state = self.scrollState
    if not state or state.enabled then
        return
    end

    local tracker = state.tracker
    state.enabled = true
    if tracker.NineSlice then
        state.nineSliceAnchors = SaveAnchors(tracker.NineSlice)
    end
    tracker.topModulePadding = 0
    tracker.GetAvailableHeight = function()
        return FULL_CONTENT_HEIGHT
    end

    for _, module in ipairs(tracker.modules or {}) do
        module:SetParent(state.child)
        module.isDirty = true
    end

    state.frame:Show()
    tracker:MarkDirty()
end

function BQL:DisableScrolling()
    local state = self.scrollState
    if not state or not state.enabled then
        return
    end

    local tracker = state.tracker
    state.enabled = false
    state.frame:SetVerticalScroll(0)
    state.frame:Hide()

    tracker.topModulePadding = state.originalTopModulePadding
    tracker.GetAvailableHeight = state.originalGetAvailableHeight

    for _, module in ipairs(tracker.modules or {}) do
        module:SetParent(tracker)
        module.isDirty = true
    end

    if tracker.NineSlice and state.nineSliceAnchors then
        RestoreAnchors(tracker.NineSlice, state.nineSliceAnchors)
    end

    tracker:MarkDirty()
end

function BQL:SetScrollingEnabled(enabled)
    local state = self.scrollState
    if not state then
        return
    end

    if InCombatLockdown() and state.enabled ~= enabled then
        state.pendingEnabled = enabled
        state.combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if enabled then
        self:EnableScrolling()
    else
        self:DisableScrolling()
    end
end


