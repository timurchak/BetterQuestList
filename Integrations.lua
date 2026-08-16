local _, BQL = ...

local MAX_DAMAGE_METER_WINDOWS = 5

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
            local current = viewport:GetVerticalScroll() or 0
            local maximum = viewport:GetVerticalScrollRange() or 0
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
