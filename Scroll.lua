local _, BQL = ...

local LAYOUT_HEIGHT = 8192
local VIEWPORT_LEFT_OVERFLOW = 36
local VIEWPORT_RIGHT_OVERFLOW = 8
local MINIMUM_VIEWPORT_HEIGHT = 40

local function AreAuraSecretsActive()
    return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() or false
end

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

function BQL:IsTrackerGeometrySafe()
    return not InCombatLockdown() and not AreAuraSecretsActive()
end

function BQL:GetOrderedModules()
    local state = self.scrollState
    local tracker = state and state.tracker
    if not tracker or not tracker.modules then
        return {}
    end

    local modulesByName = {}
    local orderedModules = {}
    local seen = {}

    for _, module in ipairs(tracker.modules) do
        local name = self:GetModuleName(module)
        if name then
            modulesByName[name] = module
        end
    end

    for _, name in ipairs(self.db.moduleOrder or {}) do
        local module = modulesByName[name]
        if module and not seen[module] then
            seen[module] = true
            orderedModules[#orderedModules + 1] = module
        end
    end

    for _, module in ipairs(tracker.modules) do
        if not seen[module] then
            seen[module] = true
            orderedModules[#orderedModules + 1] = module
        end
    end

    return orderedModules
end

local function RestoreNineSliceAnchors(state)
    local nineSlice = state.tracker.NineSlice
    if not nineSlice then
        return
    end

    nineSlice:ClearAllPoints()
    nineSlice:SetPoint("TOPLEFT", state.tracker, "TOPLEFT", -30, 0)
    nineSlice:SetPoint("TOPRIGHT", state.tracker, "TOPRIGHT", 5, 0)
end

local function AnchorNineSliceToViewport(state)
    local nineSlice = state.tracker.NineSlice
    if not nineSlice or not state.viewportHeight then
        return
    end

    nineSlice:ClearAllPoints()
    nineSlice:SetPoint("TOPLEFT", state.tracker, "TOPLEFT", -30, 0)
    nineSlice:SetPoint("TOPRIGHT", state.tracker, "TOPRIGHT", 5, 0)
    nineSlice:SetPoint("BOTTOMLEFT", state.tracker, "TOPLEFT", -30, -state.viewportHeight)
    nineSlice:SetPoint("BOTTOMRIGHT", state.tracker, "TOPRIGHT", 5, -state.viewportHeight)
end

local function UpdateViewportGeometry(state)
    if not state.viewportHeight then
        return false
    end

    local tracker = state.tracker
    local topModulePadding = tracker.topModulePadding or 0
    local viewportContentHeight = math.max(state.viewportHeight - topModulePadding, 1)
    local trackerWidth = tracker:GetWidth()
    if IsSecretValue(trackerWidth) then
        return false
    end

    state.scrollFrame:ClearAllPoints()
    state.scrollFrame:SetPoint("TOPLEFT", tracker, "TOPLEFT", -VIEWPORT_LEFT_OVERFLOW, -topModulePadding)
    state.scrollFrame:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", VIEWPORT_RIGHT_OVERFLOW, -topModulePadding)
    state.scrollFrame:SetHeight(viewportContentHeight)

    state.scrollChild:ClearAllPoints()
    state.scrollChild:SetPoint("TOPLEFT", state.scrollFrame, "TOPLEFT", VIEWPORT_LEFT_OVERFLOW, topModulePadding)
    state.scrollChild:SetWidth(math.max(trackerWidth, 1))
    return true
end

local function CaptureViewportHeight(state, height)
    if IsSecretValue(height) or height < MINIMUM_VIEWPORT_HEIGHT or height >= (LAYOUT_HEIGHT * 0.5) then
        return false
    end

    state.viewportHeight = height
    UpdateViewportGeometry(state)
    return true
end

local function SetTrackerHeight(state, height)
    state.settingHeight = true
    state.tracker:SetHeight(height)
    state.settingHeight = false
end

local function RestoreTrackerHeight(state)
    if not state.layoutExpanded or not state.viewportHeight then
        return
    end

    SetTrackerHeight(state, state.viewportHeight)
    state.layoutExpanded = false
    state.layoutExpandedAt = nil
end

function BQL:RefreshTrackerLayout(afterTrackerUpdate)
    local state = self.scrollState
    if not state or not state.tracker then
        return false
    end

    if afterTrackerUpdate then
        -- Always return the native frame to its Edit Mode height, even if aura
        -- restrictions became active between MarkDirty and Update.
        RestoreTrackerHeight(state)
    elseif state.layoutExpanded then
        local expandedAt = state.layoutExpandedAt or 0
        if (GetTime() - expandedAt) < 0.20 then
            -- A clean Blizzard update is already queued. Do not cancel its
            -- temporary full-height layout during the same frame.
            state.pendingLayout = true
            return false
        end

        -- During login Blizzard can mark the tracker dirty before the matching
        -- callback reaches our Update hook. Never leave the native frame stuck
        -- at the temporary layout height while waiting for another UI action.
        RestoreTrackerHeight(state)
    end

    if not self:IsTrackerGeometrySafe() then
        state.pendingLayout = true
        return false
    end

    local tracker = state.tracker
    local orderedModules = self:GetOrderedModules()
    local previousModule
    local contentHeight = 0
    local topModulePadding = tracker.topModulePadding or 0
    local moduleSpacing = tracker.moduleSpacing or 0

    for _, module in ipairs(orderedModules) do
        local moduleHeight = module:GetContentsHeight()
        if IsSecretValue(moduleHeight) then
            state.pendingLayout = true
            return false
        end

        if moduleHeight > 0 then
            if state.enabled and module:GetParent() ~= state.scrollChild then
                module:SetParent(state.scrollChild)
            end

            module:ClearAllPoints()
            if previousModule then
                module:SetPoint("TOP", previousModule, "BOTTOM", 0, -moduleSpacing)
                contentHeight = contentHeight + moduleSpacing
            else
                local parent = state.enabled and state.scrollChild or tracker
                module:SetPoint("TOP", parent, "TOP", 0, -topModulePadding)
            end
            module:SetPoint("LEFT", tracker, "LEFT", module.leftMargin or 0, 0)

            contentHeight = contentHeight + moduleHeight
            previousModule = module
        end
    end

    state.contentHeight = contentHeight
    state.pendingLayout = false

    if state.enabled then
        UpdateViewportGeometry(state)
        local viewportContentHeight = math.max((state.viewportHeight or 1) - topModulePadding, 1)
        state.scrollChild:SetHeight(math.max(contentHeight + topModulePadding, viewportContentHeight + topModulePadding, 1))

        local maximum = state.scrollFrame:GetVerticalScrollRange()
        if not IsSecretValue(maximum) and state.scrollFrame:GetVerticalScroll() > maximum then
            state.scrollFrame:SetVerticalScroll(maximum)
        end
        AnchorNineSliceToViewport(state)
    elseif previousModule and tracker.NineSlice then
        RestoreNineSliceAnchors(state)
        tracker.NineSlice:SetPoint("BOTTOM", previousModule, "BOTTOM", 0, -(tracker.bottomModulePadding or 0))
    end

    return true
end

function BQL:PrepareFullHeightLayout()
    local state = self.scrollState
    if not state or not state.enabled or state.settingHeight or state.layoutExpanded or not self:IsTrackerGeometrySafe() then
        return false
    end

    local trackerHeight = state.tracker:GetHeight()
    if IsSecretValue(trackerHeight) then
        return false
    end

    if not state.viewportHeight and not CaptureViewportHeight(state, trackerHeight) then
        return false
    end

    -- MarkDirty has already queued Blizzard's clean callback. Inflate only for
    -- that pending layout and restore the Edit Mode height in the Update hook.
    SetTrackerHeight(state, LAYOUT_HEIGHT)
    state.layoutExpanded = true
    state.layoutExpandedAt = GetTime()
    return true
end

function BQL:RestoreTrackerGeometry()
    local state = self.scrollState
    if not state then
        return false
    end

    RestoreTrackerHeight(state)
    state.scrollFrame:SetVerticalScroll(0)
    state.scrollFrame:Hide()

    if self:IsTrackerGeometrySafe() then
        for _, module in ipairs(state.tracker.modules or {}) do
            if module:GetParent() == state.scrollChild then
                module:SetParent(state.tracker)
            end
        end
        RestoreNineSliceAnchors(state)
    else
        state.pendingLayout = true
    end

    return true
end

local function ScheduleDeferredRetry(addon)
    local state = addon.scrollState
    if not state or state.retryScheduled or (state.retryCount or 0) >= 20 then
        return
    end

    state.retryScheduled = true
    state.retryCount = (state.retryCount or 0) + 1
    C_Timer.After(0.25, function()
        state.retryScheduled = false
        if state.pending or state.pendingLayout then
            addon:RequestScrollingState()
        end
    end)
end

local function StartInitialLayoutRefresh(addon)
    local state = addon.scrollState
    if not state then
        return
    end

    state.initialRefreshGeneration = (state.initialRefreshGeneration or 0) + 1
    local generation = state.initialRefreshGeneration
    local attempts = 0

    local function RefreshWhenReady()
        if not addon.scrollState or addon.scrollState.initialRefreshGeneration ~= generation then
            return
        end

        attempts = attempts + 1
        addon:RequestScrollingState()

        if attempts < 12 then
            C_Timer.After(0.25, RefreshWhenReady)
        end
    end

    C_Timer.After(0.25, RefreshWhenReady)
end

function BQL:ApplyScrollingState()
    local state = self.scrollState
    if not state then
        return false
    end

    local _, kalielsLoaded = C_AddOns.IsAddOnLoaded("!KalielsTracker")
    if kalielsLoaded then
        state.pending = false
        return false
    end

    if not self:IsTrackerGeometrySafe() then
        state.pending = true
        if not state.deferredWarningShown then
            state.deferredWarningShown = true
            self:Print(self.text.scrollDeferred)
        end
        ScheduleDeferredRetry(self)
        return false
    end

    state.deferredWarningShown = false
    state.pending = false
    state.retryCount = 0
    local shouldEnable = self.db.scrollEnabled and true or false

    if shouldEnable then
        local trackerHeight = state.tracker:GetHeight()
        if not state.layoutExpanded then
            CaptureViewportHeight(state, trackerHeight)
        end
        state.enabled = true
        UpdateViewportGeometry(state)
        state.scrollFrame:Show()
        self:RefreshTrackerLayout()
    else
        state.enabled = false
        self:RestoreTrackerGeometry()
        self:RefreshTrackerLayout()
    end

    return true
end

function BQL:RequestScrollingState()
    local state = self.scrollState
    if not state or state.updateScheduled then
        return
    end

    state.updateScheduled = true
    C_Timer.After(0, function()
        state.updateScheduled = false
        self:ApplyScrollingState()
    end)
end

function BQL:SetScrollingEnabled(enabled)
    self.db.scrollEnabled = enabled and true or false
    if self.scrollState then
        self.scrollState.retryCount = 0
    end
    self:RequestScrollingState()
    return true
end

function BQL:InitializeScrolling()
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker then
        return
    end

    local scrollFrame = CreateFrame("ScrollFrame", "BetterQuestListScrollFrame", tracker)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:Hide()

    local scrollChild = CreateFrame("Frame", "BetterQuestListScrollChild", scrollFrame)
    scrollChild:SetSize(math.max(tracker:GetWidth(), 1), 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollState = {
        tracker = tracker,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        enabled = false,
        dirtyCycleActive = tracker.dirty and true or false,
        layoutExpanded = false,
        pending = false,
        pendingLayout = false,
        contentHeight = 0,
    }

    CaptureViewportHeight(self.scrollState, tracker:GetHeight())

    scrollFrame:SetScript("OnMouseWheel", function(frame, delta)
        if not self.scrollState.enabled then
            return
        end

        local current = frame:GetVerticalScroll()
        local maximum = frame:GetVerticalScrollRange()
        if IsSecretValue(current) or IsSecretValue(maximum) then
            return
        end

        local target = current - (delta * self.db.scrollStep)
        frame:SetVerticalScroll(math.max(0, math.min(target, maximum)))
    end)

    hooksecurefunc(tracker, "MarkDirty", function()
        local state = self.scrollState
        if not state.settingHeight and not state.dirtyCycleActive then
            state.dirtyCycleActive = true
            self:PrepareFullHeightLayout()
        end
    end)

    hooksecurefunc(tracker, "Update", function()
        self:RefreshTrackerLayout(true)
        self.scrollState.dirtyCycleActive = false
    end)

    hooksecurefunc(ObjectiveTrackerManager, "SetModuleContainer", function(_, module, container)
        local state = self.scrollState
        if state and state.enabled and container == tracker and self:IsTrackerGeometrySafe() then
            module:SetParent(state.scrollChild)
        end
    end)

    tracker:HookScript("OnSizeChanged", function(_, _, height)
        local state = self.scrollState
        if not state or state.settingHeight or state.layoutExpanded or IsSecretValue(height) then
            return
        end

        if self:IsTrackerGeometrySafe() and CaptureViewportHeight(state, height) and state.enabled then
            AnchorNineSliceToViewport(state)
        end
    end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(_, event)
        self.scrollState.retryCount = 0
        self:RequestScrollingState()
        if event == "PLAYER_ENTERING_WORLD" then
            StartInitialLayoutRefresh(self)
        end
    end)
    self.scrollState.eventFrame = eventFrame

    self:RequestScrollingState()
    StartInitialLayoutRefresh(self)
end
