local _, BQL = ...

local PANEL_WIDTH = 540
local PANEL_HEIGHT = 490
local LFG_EYE_TEXTURE = "Interface\\LFGFrame\\LFG-Eye"
local LFG_EYE_FRAME_OPEN = 0
local LFG_EYE_FRAME_CLOSED = 4
local LFG_EYE_FRAME_WIDTH = 64
local LFG_EYE_FRAME_HEIGHT = 64
local LFG_EYE_TEXTURE_WIDTH = 512
local LFG_EYE_TEXTURE_HEIGHT = 256

local function SetEyeTextureFrame(texture, frameIndex)
    local columns = LFG_EYE_TEXTURE_WIDTH / LFG_EYE_FRAME_WIDTH
    local column = frameIndex % columns
    local row = math.floor(frameIndex / columns)
    texture:SetTexCoord(
        (column * LFG_EYE_FRAME_WIDTH) / LFG_EYE_TEXTURE_WIDTH,
        ((column + 1) * LFG_EYE_FRAME_WIDTH) / LFG_EYE_TEXTURE_WIDTH,
        (row * LFG_EYE_FRAME_HEIGHT) / LFG_EYE_TEXTURE_HEIGHT,
        ((row + 1) * LFG_EYE_FRAME_HEIGHT) / LFG_EYE_TEXTURE_HEIGHT
    )
end

local function UpdateEyeButton(button, hidden)
    local texture = button and button:GetNormalTexture()
    if not texture then
        return
    end
    texture:SetTexture(LFG_EYE_TEXTURE)
    SetEyeTextureFrame(texture, hidden and LFG_EYE_FRAME_CLOSED or LFG_EYE_FRAME_OPEN)
end

local function SetOverlayHidden(integration, hidden)
    if not integration then
        return
    end
    integration.overlayHidden = hidden and true or false
    integration.overlay:SetAlpha(integration.overlayHidden and 0 or 1)
    UpdateEyeButton(integration.eyeButton, integration.overlayHidden)
end

local function CreateLabel(parent, fontObject, text)
    local label = parent:CreateFontString(nil, "ARTWORK", fontObject)
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

local function CreateChoiceDropdown(parent, choices, getValue, setValue)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(230, 30)

    function dropdown:Refresh()
        local selectedValue = getValue()
        for _, choice in ipairs(choices) do
            if choice.value == selectedValue then
                self:SetDefaultText(choice.label)
                return
            end
        end
    end

    dropdown:SetupMenu(function(_, rootDescription)
        for _, choice in ipairs(choices) do
            local value = choice.value
            rootDescription:CreateRadio(choice.label, function()
                return getValue() == value
            end, function()
                setValue(value)
                dropdown:Refresh()
            end)
        end
    end)
    return dropdown
end

local function CreateSlider(parent, labelText, minimum, maximum, getValue, setValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(38)

    local label = CreateLabel(row, "GameFontHighlightMedium", labelText)
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(220)

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", label, "RIGHT", 8, 0)
    slider:SetSize(180, 32)

    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right,
            function(value)
                return ("%+d px"):format(math.floor(value + 0.5))
            end
        ),
    }

    function row:OnSliderValueChanged(value)
        if self.refreshing then
            return
        end
        local roundedValue = math.max(minimum, math.min(math.floor(value + 0.5), maximum))
        if getValue() ~= roundedValue then
            setValue(roundedValue)
        end
    end

    row.cbrHandles = EventUtil.CreateCallbackHandleContainer()
    row.cbrHandles:RegisterCallback(
        slider,
        MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        row.OnSliderValueChanged,
        row
    )

    function row:Refresh()
        local value = getValue()
        self.refreshing = true
        slider:Init(value, minimum, maximum, maximum - minimum, formatters)
        self.refreshing = false
    end

    return row
end

local function CreateDropdownRow(parent, labelText, choices, getValue, setValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(38)

    local label = CreateLabel(row, "GameFontHighlightMedium", labelText)
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(220)

    local dropdown = CreateChoiceDropdown(row, choices, getValue, setValue)
    dropdown:SetPoint("LEFT", label, "RIGHT", 5, -2)

    function row:Refresh()
        dropdown:Refresh()
    end

    return row
end

function BQL:RefreshEditModeAppearancePanel()
    local integration = self.editModeIntegration
    if not integration then
        return
    end

    for _, row in ipairs(integration.optionRows) do
        row:Refresh()
    end
end

function BQL:PositionEditModeAppearancePanel()
    local integration = self.editModeIntegration
    local state = self.customState
    if not integration or not state then
        return
    end

    local panel = integration.panel
    panel:ClearAllPoints()
    local trackerLeft = state.frame:GetLeft()
    if trackerLeft and trackerLeft > PANEL_WIDTH + 24 then
        panel:SetPoint("TOPRIGHT", state.frame, "TOPLEFT", -12, 0)
    else
        panel:SetPoint("TOPLEFT", state.frame, "TOPRIGHT", 12, 0)
    end
end

function BQL:SetEditModeAppearanceShown(shown)
    local integration = self.editModeIntegration
    if not integration then
        return
    end

    if shown then
        if integration.overlay.ShowSelected then
            integration.overlay:ShowSelected()
        end
        self:RefreshEditModeAppearancePanel()
        self:PositionEditModeAppearancePanel()
        integration.panel:Show()
    else
        integration.panel:Hide()
        SetOverlayHidden(integration, false)
        local state = self.customState
        if state and state.editModeActive and integration.overlay.ShowHighlighted then
            integration.overlay:ShowHighlighted()
        end
    end
end

function BQL:OnBetterQuestListEditModeEnter()
    local integration = self.editModeIntegration
    if not integration then
        return
    end

    local state = self.customState
    SetOverlayHidden(integration, false)
    if state then
        state.editModeActive = true
        state.scrollFrame:EnableMouseWheel(false)
        state.collapseButton:Disable()
        if state.blizzardTracker.Selection then
            state.blizzardTracker.Selection:Hide()
        end
        self:RequestCustomRefresh(false)
    end

    local manager = _G.EditModeManagerFrame
    if manager and not integration.managerHookInstalled then
        integration.managerHookInstalled = true
        hooksecurefunc(manager, "SelectSystem", function(_, selectedFrame)
            local currentState = self.customState
            local currentIntegration = self.editModeIntegration
            if currentState
                and currentIntegration
                and currentState.editModeActive
                and selectedFrame ~= currentState.blizzardTracker
            then
                currentIntegration.panel:Hide()
                SetOverlayHidden(currentIntegration, false)
                currentIntegration.overlay:ShowHighlighted()
            end
        end)
    end

    integration.overlay:ShowHighlighted()
    integration.panel:Hide()
end

function BQL:OnBetterQuestListEditModeExit()
    local integration = self.editModeIntegration
    if not integration then
        return
    end

    integration.overlay:Hide()
    integration.panel:Hide()
    SetOverlayHidden(integration, false)
    local state = self.customState
    if state then
        state.editModeActive = false
        state.scrollFrame:EnableMouseWheel(true)
        state.collapseButton:Enable()
        self:RequestCustomRefresh(false)
    end
    CloseDropDownMenus()
end

function BQL:InitializeEditModeIntegration()
    local state = self.customState
    if not state or self.editModeIntegration then
        return
    end

    local overlay = CreateFrame(
        "Frame",
        "BetterQuestListEditModeOverlay",
        state.frame,
        "EditModeSystemSelectionTemplate"
    )
    overlay:SetAllPoints(state.frame)
    overlay:SetSystem({
        GetSystemName = function()
            return self.text.title
        end,
    })
    overlay:Hide()

    local panel = CreateFrame(
        "Frame",
        "BetterQuestListEditModeAppearance",
        UIParent
    )
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(200)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    border.ignoreInLayout = true

    local title = CreateLabel(panel, "GameFontHighlightLarge", self.text.editModeAppearance)
    title:SetPoint("TOP", panel, "TOP", 0, -15)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function()
        self:SetEditModeAppearanceShown(false)
    end)

    local eyeButton = CreateFrame("Button", nil, panel)
    eyeButton:SetSize(32, 32)
    eyeButton:SetPoint("RIGHT", close, "LEFT", -4, 0)
    eyeButton:SetNormalTexture(LFG_EYE_TEXTURE)
    eyeButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    eyeButton:SetScript("OnClick", function()
        local integration = self.editModeIntegration
        if integration then
            SetOverlayHidden(integration, not integration.overlayHidden)
        end
    end)
    eyeButton:SetScript("OnEnter", function(button)
        local integration = self.editModeIntegration
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(
            integration and integration.overlayHidden
                and self.text.showEditModeHighlight
                or self.text.hideEditModeHighlight
        )
        GameTooltip:Show()
    end)
    eyeButton:SetScript("OnLeave", GameTooltip_Hide)
    UpdateEyeButton(eyeButton, false)

    local fontChoices = {
        { value = "default", label = self.text.fontDefault },
        { value = "chat", label = self.text.fontChat },
        { value = "quest", label = self.text.fontQuest },
        { value = "system", label = self.text.fontSystem },
    }
    local backgroundChoices = {
        { value = "none", label = self.text.backgroundNone },
        { value = "subtle", label = self.text.backgroundSubtle },
        { value = "dark", label = self.text.backgroundDark },
    }
    local fontOutlineChoices = {
        { value = "default", label = self.text.fontOutlineDefault },
        { value = "none", label = self.text.fontOutlineNone },
        { value = "outline", label = self.text.fontOutlineNormal },
        { value = "thick", label = self.text.fontOutlineThick },
    }
    local fontShadowChoices = {
        { value = "default", label = self.text.fontShadowDefault },
        { value = "enabled", label = self.text.fontShadowEnabled },
        { value = "disabled", label = self.text.fontShadowDisabled },
    }
    local categoryStyleChoices = {
        { value = "blizzard", label = self.text.categoryStyleBlizzard },
        { value = "plain", label = self.text.categoryStylePlain },
    }

    local optionRows = {
        CreateDropdownRow(panel, self.text.font, fontChoices, function()
            return self.db.font
        end, function(value)
            self.db.font = value
            self:ApplyCustomAppearance()
        end),
        CreateDropdownRow(panel, self.text.fontOutline, fontOutlineChoices, function()
            return self.db.fontOutline
        end, function(value)
            self.db.fontOutline = value
            self:ApplyCustomAppearance()
        end),
        CreateDropdownRow(panel, self.text.fontShadow, fontShadowChoices, function()
            return self.db.fontShadow
        end, function(value)
            self.db.fontShadow = value
            self:ApplyCustomAppearance()
        end),
        CreateDropdownRow(panel, self.text.background, backgroundChoices, function()
            return self.db.background
        end, function(value)
            self.db.background = value
            self:ApplyCustomAppearance()
        end),
        CreateDropdownRow(panel, self.text.categoryStyle, categoryStyleChoices, function()
            return self.db.categoryStyle
        end, function(value)
            self.db.categoryStyle = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(panel, self.text.categoryOffset, -20, 20, function()
            return self.db.categoryOffset
        end, function(value)
            self.db.categoryOffset = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(panel, self.text.categoryTextOffset, -100, 100, function()
            return self.db.categoryTextOffset
        end, function(value)
            self.db.categoryTextOffset = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(panel, self.text.categorySpacing, 0, 30, function()
            return self.db.categorySpacing
        end, function(value)
            self.db.categorySpacing = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(panel, self.text.questSpacing, 0, 30, function()
            return self.db.questSpacing
        end, function(value)
            self.db.questSpacing = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(panel, self.text.questObjectiveSpacing, 0, 20, function()
            return self.db.questObjectiveSpacing
        end, function(value)
            self.db.questObjectiveSpacing = value
            self:ApplyCustomAppearance()
        end),
    }

    for index, row in ipairs(optionRows) do
        if index == 1 then
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -58)
        else
            row:SetPoint("TOPLEFT", optionRows[index - 1], "BOTTOMLEFT", 0, -2)
        end
        row:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    end

    self.editModeIntegration = {
        overlay = overlay,
        panel = panel,
        eyeButton = eyeButton,
        optionRows = optionRows,
    }

    local function SelectBetterQuestList()
        if InCombatLockdown() then
            return
        end

        local manager = _G.EditModeManagerFrame
        local tracker = state.blizzardTracker
        if manager and manager.SelectSystem and tracker then
            manager:SelectSystem(tracker)
            if tracker.Selection then
                tracker.Selection:Hide()
            end
            if _G.EditModeSystemSettingsDialog then
                EditModeSystemSettingsDialog:Hide()
            end
        end
        self:SetEditModeAppearanceShown(true)
    end

    overlay:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            SelectBetterQuestList()
        end
    end)
    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() then
            return
        end
        local tracker = state.blizzardTracker
        if tracker and tracker.OnDragStart then
            tracker:OnDragStart()
        end
    end)
    overlay:SetScript("OnDragStop", function()
        local tracker = state.blizzardTracker
        if tracker and tracker.OnDragStop then
            tracker:OnDragStop()
        end
        self:PositionEditModeAppearancePanel()
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", self.OnBetterQuestListEditModeEnter, self)
    EventRegistry:RegisterCallback("EditMode.Exit", self.OnBetterQuestListEditModeExit, self)

    C_Timer.After(0, function()
        local manager = _G.EditModeManagerFrame
        if manager and manager.IsEditModeActive and manager:IsEditModeActive() then
            self:OnBetterQuestListEditModeEnter()
        end
    end)
end
