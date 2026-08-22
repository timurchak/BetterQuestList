local _, BQL = ...

local MAX_DAMAGE_METER_WINDOWS = 5

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function GetDamageMeter()
    local enhanceQoL = _G.EnhanceQoL
    local damageMeter = enhanceQoL and enhanceQoL.DamageMeter
    if type(damageMeter) ~= "table" then
        return nil
    end
    return damageMeter
end

local function GetDamageMeterFrame(damageMeter, index)
    local frame = damageMeter and damageMeter.windows and damageMeter.windows[index]
    if frame then
        return frame
    end
    return _G[("EnhanceQoLDamageMeterFrame%d"):format(index)]
end

local function CapturePoints(frame)
    local points = {}
    for pointIndex = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(pointIndex)
        points[pointIndex] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            offsetX = offsetX,
            offsetY = offsetY,
        }
    end
    return points
end

local function RestorePoints(frame, points)
    frame:ClearAllPoints()
    for _, point in ipairs(points or {}) do
        frame:SetPoint(
            point.point,
            point.relativeTo,
            point.relativePoint,
            point.offsetX,
            point.offsetY
        )
    end
end

local function CaptureOriginalState(frame)
    return {
        parent = frame:GetParent(),
        points = CapturePoints(frame),
        frameStrata = frame:GetFrameStrata(),
        frameLevel = frame:GetFrameLevel(),
        scale = frame:GetScale(),
        clampedToScreen = frame:IsClampedToScreen(),
        movable = frame:IsMovable(),
        resizable = frame:IsResizable(),
    }
end

function BQL:GetEnhanceQoLDamageMeterWindowCount()
    local enhanceQoL = _G.EnhanceQoL
    local count = enhanceQoL
        and enhanceQoL.db
        and tonumber(enhanceQoL.db.damageMeterWindowCount)
        or 0
    return math.max(0, math.min(math.floor(count + 0.5), MAX_DAMAGE_METER_WINDOWS))
end

function BQL:GetEnhanceQoLDamageMeterChoices()
    local choices = {
        { value = 0, label = self.text.integrationDisabled },
    }
    for index = 1, self:GetEnhanceQoLDamageMeterWindowCount() do
        choices[#choices + 1] = {
            value = index,
            label = self.text.enhanceQoLDamageMeterWindow:format(index),
        }
    end
    return choices
end

function BQL:GetEnhanceQoLDamageMeterSlot(category)
    for slot, categoryName in ipairs(self.DAMAGE_METER_CATEGORIES) do
        if category == categoryName then
            return slot
        end
    end
end

function BQL:GetEnhanceQoLDamageMeterWindow(slot)
    return tonumber(self.db.enhanceQoLDamageMeterWindows[slot]) or 0
end

function BQL:GetEnhanceQoLDamageMeterEntry(category)
    local slot = self:GetEnhanceQoLDamageMeterSlot(category)
    local index = slot and self:GetEnhanceQoLDamageMeterWindow(slot) or 0
    if index < 1 or index > self:GetEnhanceQoLDamageMeterWindowCount() then
        return nil
    end

    local frame = GetDamageMeterFrame(GetDamageMeter(), index)
    if not frame or not frame:IsShown() then
        return nil
    end

    return {
        kind = "enhanceQoLDamageMeter",
        category = category,
        title = self:GetModuleLabel(category),
        isEnhanceQoLDamageMeter = true,
        windowIndex = index,
        objectives = {},
    }
end

function BQL:GetEnhanceQoLDamageMeterFrame(index)
    return GetDamageMeterFrame(GetDamageMeter(), index)
end

function BQL:MaintainEnhanceQoLDamageMeterFrame(category)
    local integration = self.enhanceQoLDamageMeterIntegration
    local record = integration and integration.records[category]
    local row = record and record.row
    local frame = record and record.frame
    if not row or not frame or not record.embedded then
        return
    end

    local point, relativeTo = frame:GetPoint(1)
    if frame:GetParent() ~= row or point ~= "TOP" or relativeTo ~= row then
        frame:SetParent(row)
        frame:ClearAllPoints()
        frame:SetPoint("TOP", row, "TOP", 0, 0)
    end
    frame:SetFrameStrata(self.customState.frame:GetFrameStrata())
    frame:SetFrameLevel(row:GetFrameLevel() + 10)
    local originalScale = record.original.scale or 1
    local frameWidth = frame:GetWidth()
    local availableWidth = row:GetWidth()
    local embeddedScale = originalScale
    if type(frameWidth) == "number"
        and frameWidth > 0
        and type(availableWidth) == "number"
        and availableWidth > 0
    then
        embeddedScale = math.min(originalScale, availableWidth / frameWidth)
    end
    frame:SetScale(embeddedScale)
    frame:SetClampedToScreen(false)
    frame:SetMovable(false)
    frame:SetResizable(false)
end

function BQL:AttachEnhanceQoLDamageMeterFrame(row, category, index)
    local integration = self.enhanceQoLDamageMeterIntegration
    local frame = self:GetEnhanceQoLDamageMeterFrame(index)
    if not integration or not frame or not frame:IsShown() then
        return nil
    end

    local existingOwner = integration.frameOwners[frame]
    if existingOwner and existingOwner ~= category then
        self:DetachEnhanceQoLDamageMeterFrame(existingOwner)
    end

    local record = integration.records[category]
    if record and record.frame ~= frame then
        self:DetachEnhanceQoLDamageMeterFrame(category)
        record = nil
    end
    if not record then
        record = {
            frame = frame,
            windowIndex = index,
            original = CaptureOriginalState(frame),
        }
        integration.records[category] = record
        integration.frameOwners[frame] = category
    end

    record.row = row
    record.embedded = true
    record.lastShown = frame:IsShown()

    if not frame.bqlDamageMeterSizeHooked then
        frame.bqlDamageMeterSizeHooked = true
        frame:HookScript("OnSizeChanged", function(changedFrame)
            local current = self.enhanceQoLDamageMeterIntegration
            local owner = current and current.frameOwners[changedFrame]
            local currentRecord = owner and current.records[owner]
            if currentRecord and currentRecord.embedded then
                self:RequestCustomRefresh(false)
            end
        end)
    end
    if frame.rowsViewport and not frame.rowsViewport.bqlOuterScrollHooked then
        frame.rowsViewport.bqlOuterScrollHooked = true
        frame.rowsViewport:HookScript("OnMouseWheel", function(viewport, delta)
            local state = self.customState
            if not state or not state.scrollFrame or state.editModeActive then
                return
            end
            local current = viewport:GetVerticalScroll()
            local maximum = viewport:GetVerticalScrollRange()
            -- Midnight can protect ScrollFrame geometry while the meter is
            -- processing combat data. Its own handler may consume those
            -- values, but addon-tainted code must not compare or calculate
            -- with them. In that state, leave the wheel entirely to the meter.
            if IsSecret(delta)
                or IsSecret(current)
                or IsSecret(maximum)
                or type(delta) ~= "number"
                or type(current) ~= "number"
                or type(maximum) ~= "number"
            then
                return
            end
            local atOuterEdge = (delta > 0 and current <= 0.5)
                or (delta < 0 and current >= maximum - 0.5)
            if atOuterEdge then
                local handler = state.scrollFrame:GetScript("OnMouseWheel")
                if handler then
                    handler(state.scrollFrame, delta)
                end
            end
        end)
    end

    self:MaintainEnhanceQoLDamageMeterFrame(category)
    return frame
end

function BQL:ParkEnhanceQoLDamageMeterFrames()
    local integration = self.enhanceQoLDamageMeterIntegration
    if not integration then
        return
    end

    for _, record in pairs(integration.records) do
        local frame = record.frame
        record.embedded = false
        record.row = nil
        frame:SetParent(integration.parkingFrame)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", integration.parkingFrame, "CENTER", 0, 0)
        frame:SetClampedToScreen(false)
        frame:SetMovable(false)
        frame:SetResizable(false)
    end
end

function BQL:DetachEnhanceQoLDamageMeterFrame(category)
    local integration = self.enhanceQoLDamageMeterIntegration
    local record = integration and integration.records[category]
    if not record then
        return
    end

    local frame = record.frame
    local original = record.original
    frame:SetParent(original.parent or UIParent)
    RestorePoints(frame, original.points)
    frame:SetFrameStrata(original.frameStrata)
    frame:SetFrameLevel(original.frameLevel)
    frame:SetScale(original.scale)
    frame:SetClampedToScreen(original.clampedToScreen)
    frame:SetMovable(original.movable)
    frame:SetResizable(original.resizable)

    integration.frameOwners[frame] = nil
    integration.records[category] = nil
end

function BQL:SetEnhanceQoLDamageMeterWindow(slot, index)
    slot = tonumber(slot)
    if not slot or not self.DAMAGE_METER_CATEGORIES[slot] then
        return
    end
    index = tonumber(index) or 0
    index = math.max(0, math.min(math.floor(index + 0.5), MAX_DAMAGE_METER_WINDOWS))
    if self:GetEnhanceQoLDamageMeterWindow(slot) == index then
        return
    end

    local category = self.DAMAGE_METER_CATEGORIES[slot]
    self:DetachEnhanceQoLDamageMeterFrame(category)

    if index > 0 then
        for otherSlot, otherCategory in ipairs(self.DAMAGE_METER_CATEGORIES) do
            if otherSlot ~= slot and self:GetEnhanceQoLDamageMeterWindow(otherSlot) == index then
                self:DetachEnhanceQoLDamageMeterFrame(otherCategory)
                self.db.enhanceQoLDamageMeterWindows[otherSlot] = 0
            end
        end
    end

    self.db.enhanceQoLDamageMeterWindows[slot] = index
    self:RequestCustomRefresh(true)
    if self.RefreshEditModeAppearancePanel then
        self:RefreshEditModeAppearancePanel()
    end
end

function BQL:InitializeEnhanceQoLDamageMeterIntegration()
    if self.enhanceQoLDamageMeterIntegration then
        return
    end

    local integration = {
        hooked = false,
        records = {},
        frameOwners = {},
        lastShownByWindow = {},
    }
    integration.parkingFrame = CreateFrame("Frame", nil, UIParent)
    integration.parkingFrame:SetSize(1, 1)
    integration.parkingFrame:SetPoint("TOP", UIParent, "TOP", 0, 0)
    integration.parkingFrame:Hide()
    self.enhanceQoLDamageMeterIntegration = integration

    local function InstallHook()
        local damageMeter = GetDamageMeter()
        if not damageMeter or integration.hooked then
            return
        end
        integration.hooked = true
        hooksecurefunc(damageMeter, "RefreshWindow", function(_, index)
            local selectedCategory
            for slot, category in ipairs(self.DAMAGE_METER_CATEGORIES) do
                if self:GetEnhanceQoLDamageMeterWindow(slot) == index then
                    selectedCategory = category
                    break
                end
            end
            if not selectedCategory then
                return
            end

            local frame = GetDamageMeterFrame(damageMeter, index)
            local record = integration.records[selectedCategory]
            if record and record.embedded and record.frame == frame then
                self:MaintainEnhanceQoLDamageMeterFrame(selectedCategory)
            end

            local shown = frame and frame:IsShown() or false
            if integration.lastShownByWindow[index] ~= shown then
                integration.lastShownByWindow[index] = shown
                self:RequestCustomRefresh(true)
            end
        end)
        self:RequestCustomRefresh(true)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon == "EnhanceQoLDamageMeter" then
            InstallHook()
        end
    end)
    integration.events = events

    InstallHook()
end

local function GetMythicPlusTimer()
    local enhanceQoL = _G.EnhanceQoL
    local mythicPlus = enhanceQoL and enhanceQoL.MythicPlus
    local timer = mythicPlus and mythicPlus.MythicPlusTimer
    return type(timer) == "table" and timer or nil
end

local function GetMythicPlusTimerFrame(timer)
    return timer and timer.frame or _G.EnhanceQoLMythicPlusTimerFrame
end

local function GetMythicPlusTimerVisual(timer, frame)
    if timer and type(timer.GetStyleTarget) == "function" then
        local ok, target = pcall(timer.GetStyleTarget, timer)
        if ok and target then
            return target
        end
    end
    return frame
end

local function GetSafeRegionNumber(region, method)
    if not region or type(region[method]) ~= "function" then
        return nil
    end
    local ok, value = pcall(region[method], region)
    if not ok or IsSecret(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

function BQL:IsEnhanceQoLMythicPlusTimerActive(timer)
    timer = timer or GetMythicPlusTimer()
    local frame = GetMythicPlusTimerFrame(timer)
    if not timer or not frame or not frame:IsShown() then
        return false
    end

    if type(timer.IsEnabled) == "function" then
        local ok, enabled = pcall(timer.IsEnabled, timer)
        if not ok or IsSecret(enabled) or not enabled then
            return false
        end
    end
    if type(timer.IsInEditMode) == "function" then
        local ok, inEditMode = pcall(timer.IsInEditMode, timer)
        if ok and not IsSecret(inEditMode) and inEditMode then
            return false
        end
    end

    local timerState = timer.lastState
    if type(timerState) ~= "table"
        or IsSecret(timerState.active)
        or IsSecret(timerState.completed)
        or IsSecret(timerState.preview)
        or timerState.preview
    then
        return false
    end
    return timerState.active == true or timerState.completed == true
end

function BQL:GetEnhanceQoLMythicPlusTimerEntry()
    local integration = self.enhanceQoLMythicPlusTimerIntegration
    local timer = GetMythicPlusTimer()
    local active = self:IsEnhanceQoLMythicPlusTimerActive(timer)
    if integration then
        integration.lastActive = active
    end
    if not active then
        self:DetachEnhanceQoLMythicPlusTimerFrame()
        return nil
    end

    return {
        kind = "enhanceQoLMythicPlusTimer",
        category = self.ENHANCEQOL_MYTHIC_TIMER_CATEGORY,
        title = self:GetModuleLabel(self.ENHANCEQOL_MYTHIC_TIMER_CATEGORY),
        isEnhanceQoLMythicPlusTimer = true,
        objectives = {},
    }
end

function BQL:GetEnhanceQoLMythicPlusTimerFrame()
    return GetMythicPlusTimerFrame(GetMythicPlusTimer())
end

function BQL:GetEnhanceQoLMythicPlusTimerRowHeight(automaticHeight)
    local configured = self.db
        and tonumber(self.db.enhanceQoLMythicPlusTimerHeight)
        or 0
    if configured > 0 then
        return configured
    end
    return automaticHeight
end

function BQL:MaintainEnhanceQoLMythicPlusTimerFrame()
    local integration = self.enhanceQoLMythicPlusTimerIntegration
    local record = integration and integration.record
    local row = record and record.row
    local frame = record and record.frame
    if not row or not frame or not record.embedded then
        return nil
    end

    local timer = record.timer
    local visual = GetMythicPlusTimerVisual(timer, frame)
    frame:SetParent(row)
    frame:SetFrameStrata(self.customState.frame:GetFrameStrata())
    frame:SetFrameLevel(row:GetFrameLevel() + 10)
    frame:SetClampedToScreen(false)
    frame:SetMovable(false)

    local originalScale = record.original.scale or 1
    frame:SetScale(originalScale)
    local visualWidth = GetSafeRegionNumber(visual, "GetWidth") or 0
    local frameWidth = GetSafeRegionNumber(frame, "GetWidth") or 0
    visualWidth = math.max(visualWidth, frameWidth)
    local visualScale = GetSafeRegionNumber(visual, "GetEffectiveScale")
        or GetSafeRegionNumber(frame, "GetEffectiveScale")
        or 1
    local rowScale = GetSafeRegionNumber(row, "GetEffectiveScale") or 1
    local availableWidth = GetSafeRegionNumber(row, "GetWidth")
    local embeddedScale = originalScale
    if visualWidth and visualWidth > 0 and availableWidth and availableWidth > 0 then
        local visualWidthInRow = visualWidth * visualScale / math.max(rowScale, 0.01)
        if visualWidthInRow > availableWidth then
            embeddedScale = originalScale * (availableWidth / visualWidthInRow)
        end
    end
    frame:SetScale(embeddedScale)

    frame:ClearAllPoints()
    frame:SetPoint("TOP", row, "TOP", 0, 0)

    -- PANEL mode can draw above or beside the root frame. Align its actual
    -- visual bounds to the row instead of assuming the root rectangle is the
    -- visible rectangle.
    local rowLeft = GetSafeRegionNumber(row, "GetLeft")
    local rowRight = GetSafeRegionNumber(row, "GetRight")
    local rowTop = GetSafeRegionNumber(row, "GetTop")
    local visualLeft = GetSafeRegionNumber(visual, "GetLeft")
    local visualRight = GetSafeRegionNumber(visual, "GetRight")
    local visualTop = GetSafeRegionNumber(visual, "GetTop")
    if rowLeft and rowRight and rowTop and visualLeft and visualRight and visualTop then
        local offsetX = ((rowLeft + rowRight) - (visualLeft + visualRight)) / 2
        local offsetY = rowTop - visualTop
        frame:ClearAllPoints()
        frame:SetPoint("TOP", row, "TOP", offsetX, offsetY)
    end

    local visualHeight = GetSafeRegionNumber(visual, "GetHeight") or 0
    local frameHeight = GetSafeRegionNumber(frame, "GetHeight") or 0
    local visualEffectiveScale = GetSafeRegionNumber(visual, "GetEffectiveScale")
        or GetSafeRegionNumber(frame, "GetEffectiveScale")
        or rowScale
    local frameEffectiveScale = GetSafeRegionNumber(frame, "GetEffectiveScale") or rowScale
    local visualHeightInRow = visualHeight
        * visualEffectiveScale
        / math.max(rowScale, 0.01)
    local frameHeightInRow = frameHeight
        * frameEffectiveScale
        / math.max(rowScale, 0.01)
    return math.max(visualHeightInRow, frameHeightInRow, 40)
end

function BQL:AttachEnhanceQoLMythicPlusTimerFrame(row)
    local integration = self.enhanceQoLMythicPlusTimerIntegration
    local timer = GetMythicPlusTimer()
    local frame = GetMythicPlusTimerFrame(timer)
    if not integration or not self:IsEnhanceQoLMythicPlusTimerActive(timer) or not frame then
        return nil
    end

    local record = integration.record
    if record and record.frame ~= frame then
        self:DetachEnhanceQoLMythicPlusTimerFrame()
        record = nil
    end
    if not record then
        record = {
            timer = timer,
            frame = frame,
            original = CaptureOriginalState(frame),
        }
        integration.record = record
    end

    record.row = row
    record.embedded = true

    if not frame.bqlMythicPlusTimerSizeHooked then
        frame.bqlMythicPlusTimerSizeHooked = true
        frame:HookScript("OnSizeChanged", function()
            local current = self.enhanceQoLMythicPlusTimerIntegration
            if current and current.record and current.record.embedded then
                self:RequestCustomRefresh(false)
            end
        end)
    end

    self:MaintainEnhanceQoLMythicPlusTimerFrame()
    return frame
end

function BQL:ParkEnhanceQoLMythicPlusTimerFrame()
    local integration = self.enhanceQoLMythicPlusTimerIntegration
    local record = integration and integration.record
    if not record or not record.embedded then
        return
    end

    record.embedded = false
    record.row = nil
    record.frame:SetParent(integration.parkingFrame)
    record.frame:ClearAllPoints()
    record.frame:SetPoint("CENTER", integration.parkingFrame, "CENTER", 0, 0)
    record.frame:SetClampedToScreen(false)
    record.frame:SetMovable(false)
end

function BQL:DetachEnhanceQoLMythicPlusTimerFrame()
    local integration = self.enhanceQoLMythicPlusTimerIntegration
    local record = integration and integration.record
    if not record then
        return
    end

    integration.record = nil
    local frame = record.frame
    local original = record.original
    frame:SetParent(original.parent or UIParent)
    RestorePoints(frame, original.points)
    frame:SetFrameStrata(original.frameStrata)
    frame:SetFrameLevel(original.frameLevel)
    frame:SetScale(original.scale)
    frame:SetClampedToScreen(original.clampedToScreen)
    frame:SetMovable(original.movable)
    frame:SetResizable(original.resizable)
end

function BQL:InitializeEnhanceQoLMythicPlusTimerIntegration()
    if self.enhanceQoLMythicPlusTimerIntegration then
        return
    end

    local integration = {
        hookedTimers = {},
        lastActive = false,
    }
    integration.parkingFrame = CreateFrame("Frame", nil, UIParent)
    integration.parkingFrame:SetSize(1, 1)
    integration.parkingFrame:SetPoint("TOP", UIParent, "TOP", 0, 0)
    integration.parkingFrame:Hide()
    self.enhanceQoLMythicPlusTimerIntegration = integration

    local function RefreshIntegration(timer)
        C_Timer.After(0, function()
            local active = self:IsEnhanceQoLMythicPlusTimerActive(timer)
            if active ~= integration.lastActive then
                integration.lastActive = active
                self:RequestCustomRefresh(true)
            elseif active and integration.record and integration.record.embedded then
                local automaticHeight = self:MaintainEnhanceQoLMythicPlusTimerFrame()
                local desiredHeight = self:GetEnhanceQoLMythicPlusTimerRowHeight(
                    automaticHeight
                )
                local row = integration.record and integration.record.row
                local currentHeight = GetSafeRegionNumber(row, "GetHeight")
                if desiredHeight
                    and currentHeight
                    and math.abs(desiredHeight - currentHeight) > 0.5
                then
                    self:RequestCustomRefresh(false)
                end
            end
        end)
    end

    local function InstallHooks()
        local timer = GetMythicPlusTimer()
        if not timer or integration.hookedTimers[timer] then
            return
        end
        integration.hookedTimers[timer] = true
        if type(timer.Refresh) == "function" then
            hooksecurefunc(timer, "Refresh", function()
                RefreshIntegration(timer)
            end)
        end
        if type(timer.ApplyDynamicAnchor) == "function" then
            hooksecurefunc(timer, "ApplyDynamicAnchor", function()
                if integration.record and integration.record.embedded then
                    C_Timer.After(0, function()
                        self:MaintainEnhanceQoLMythicPlusTimerFrame()
                    end)
                end
            end)
        end
        integration.lastActive = self:IsEnhanceQoLMythicPlusTimerActive(timer)
        self:RequestCustomRefresh(true)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon == "EnhanceQoLDungeonRaid" or loadedAddon == "EnhanceQoL" then
            InstallHooks()
        end
    end)
    integration.events = events

    InstallHooks()
end
