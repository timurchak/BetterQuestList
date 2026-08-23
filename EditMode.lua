local _, BQL = ...

local PANEL_WIDTH = 540
local PANEL_HEIGHT = 680
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

function BQL:SuppressBlizzardTrackerEditModeSelection()
    local state = self.customState
    local tracker = state and state.blizzardTracker
    local selection = tracker and tracker.Selection
    if not selection or type(selection.SetAlpha) ~= "function" then
        return
    end

    if type(securecallfunction) == "function" then
        securecallfunction(selection.SetAlpha, selection, 0)
    else
        selection:SetAlpha(0)
    end
end

local function SetOverlayHidden(integration, hidden)
    if not integration then
        return
    end
    integration.overlayHidden = hidden and true or false
    integration.overlay:SetAlpha(integration.overlayHidden and 0 or 1)
    UpdateEyeButton(integration.eyeButton, integration.overlayHidden)
    integration.addon:SuppressBlizzardTrackerEditModeSelection()
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

    local function GetChoices()
        if type(choices) == "function" then
            return choices()
        end
        return choices
    end

    function dropdown:Refresh()
        local selectedValue = getValue()
        local availableChoices = GetChoices()
        for _, choice in ipairs(availableChoices) do
            if choice.value == selectedValue then
                self:SetDefaultText(choice.label)
                return
            end
        end
        if availableChoices[1] then
            self:SetDefaultText(availableChoices[1].label)
        end
    end

    dropdown:SetupMenu(function(_, rootDescription)
        local availableChoices = GetChoices()
        if #availableChoices > 12 and rootDescription.SetScrollMode then
            rootDescription:SetScrollMode(320)
        end
        for _, choice in ipairs(availableChoices) do
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

local function CreateSlider(
    parent,
    labelText,
    minimum,
    maximum,
    getValue,
    setValue,
    formatValue
)
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
                local roundedValue = math.floor(value + 0.5)
                if formatValue then
                    return formatValue(roundedValue)
                end
                return ("%+d px"):format(roundedValue)
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

    local function GetLabelText()
        return type(labelText) == "function" and labelText() or labelText
    end

    local label = CreateLabel(row, "GameFontHighlightMedium", GetLabelText())
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(220)

    local dropdown = CreateChoiceDropdown(row, choices, getValue, setValue)
    dropdown:SetPoint("LEFT", label, "RIGHT", 5, -2)

    function row:Refresh()
        label:SetText(GetLabelText())
        dropdown:Refresh()
    end

    return row
end

local function CreateCheckBoxRow(parent, labelText, getValue, setValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(38)

    local label = CreateLabel(row, "GameFontHighlightMedium", labelText)
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(390)

    local checkBox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkBox:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    checkBox:SetScript("OnClick", function(button)
        setValue(button:GetChecked() and true or false)
    end)

    function row:Refresh()
        checkBox:SetChecked(getValue() and true or false)
    end

    return row
end

local function ShowColorPicker(color, setColor)
    if not ColorPickerFrame then
        return
    end

    local previous = {
        r = tonumber(color and color.r) or 1,
        g = tonumber(color and color.g) or 1,
        b = tonumber(color and color.b) or 1,
    }

    local function ApplyPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        setColor(red, green, blue)
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous.r,
            g = previous.g,
            b = previous.b,
            hasOpacity = false,
            swatchFunc = ApplyPickerColor,
            cancelFunc = function()
                setColor(previous.r, previous.g, previous.b)
            end,
        })
    else
        ColorPickerFrame.func = ApplyPickerColor
        ColorPickerFrame.cancelFunc = function()
            setColor(previous.r, previous.g, previous.b)
        end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(previous.r, previous.g, previous.b)
        ColorPickerFrame:Show()
    end
end

local function CreateColorRow(parent, labelText, getColor, setColor)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(38)

    local label = CreateLabel(row, "GameFontHighlightMedium", labelText)
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(220)

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(42, 24)
    swatch:SetPoint("LEFT", label, "RIGHT", 12, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
    swatch:SetScript("OnClick", function()
        ShowColorPicker(getColor(), function(red, green, blue)
            setColor(red, green, blue)
            row:Refresh()
        end)
    end)

    function row:Refresh()
        local color = getColor() or {}
        swatch:SetBackdropColor(
            tonumber(color.r) or 1,
            tonumber(color.g) or 1,
            tonumber(color.b) or 1,
            1
        )
    end

    return row
end


local function CreateSectionHeader(parent, labelText)
    local header = CreateFrame("Button", nil, parent, "BackdropTemplate")
    header:SetHeight(30)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(0.12, 0.12, 0.12, 0.92)

    header.arrow = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    header.arrow:SetPoint("LEFT", 9, 0)

    header.label = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header.label:SetPoint("LEFT", header.arrow, "RIGHT", 7, 0)
    header.label:SetText(labelText)

    header:SetScript("OnEnter", function(button)
        button:SetBackdropColor(0.20, 0.20, 0.20, 0.95)
    end)
    header:SetScript("OnLeave", function(button)
        button:SetBackdropColor(0.12, 0.12, 0.12, 0.92)
    end)

    function header:SetCollapsed(collapsed)
        self.arrow:SetText(collapsed and "+" or "-")
    end

    return header
end

function BQL:RefreshEditModeAppearancePanel()
    local integration = self.editModeIntegration
    if not integration then
        return
    end

    for _, row in ipairs(integration.optionRows) do
        row:Refresh()
    end
    if integration.LayoutSections then
        integration:LayoutSections()
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
    local trackerRight = state.frame:GetRight()
    local trackerTop = state.frame:GetTop()
    if not trackerLeft or not trackerRight or not trackerTop then
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    -- Anchor to UIParent at the tracker's current screen coordinates. Keeping
    -- the panel attached directly to the tracker makes the width slider move
    -- out from under the cursor as the tracker grows to the left.
    if trackerLeft and trackerLeft > PANEL_WIDTH + 24 then
        panel:SetPoint(
            "TOPRIGHT",
            UIParent,
            "BOTTOMLEFT",
            trackerLeft - 12,
            trackerTop
        )
    else
        panel:SetPoint(
            "TOPLEFT",
            UIParent,
            "BOTTOMLEFT",
            trackerRight + 12,
            trackerTop
        )
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
        self:SuppressBlizzardTrackerEditModeSelection()
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
    self:SuppressBlizzardTrackerEditModeSelection()
    if state then
        state.editModeActive = true
        state.scrollFrame:EnableMouseWheel(false)
        state.collapseButton:Disable()
        self:RequestCustomRefresh(false)
    end
    if self.OnActiveQuestItemEditModeEnter then
        self:OnActiveQuestItemEditModeEnter()
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
            self:SuppressBlizzardTrackerEditModeSelection()
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
    if self.OnActiveQuestItemEditModeExit then
        self:OnActiveQuestItemEditModeExit()
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
        local tooltip = self:GetTooltip()
        tooltip:SetOwner(button, "ANCHOR_RIGHT")
        tooltip:SetText(
            integration and integration.overlayHidden
                and self.text.showEditModeHighlight
                or self.text.hideEditModeHighlight
        )
        tooltip:ShowTooltip()
    end)
    eyeButton:SetScript("OnLeave", function()
        self:HideTooltip()
    end)
    UpdateEyeButton(eyeButton, false)

    local optionsScrollFrame = CreateFrame("ScrollFrame", nil, panel)
    optionsScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -52)
    optionsScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 14)
    optionsScrollFrame:EnableMouseWheel(true)

    local optionsContent = CreateFrame("Frame", nil, optionsScrollFrame)
    optionsContent:SetSize(PANEL_WIDTH - 38, 1)
    optionsScrollFrame:SetScrollChild(optionsContent)
    optionsScrollFrame:SetScript("OnMouseWheel", function(scrollFrame, delta)
        local maximum = math.max(
            0,
            optionsContent:GetHeight() - scrollFrame:GetHeight()
        )
        local target = scrollFrame:GetVerticalScroll() - (delta * 42)
        scrollFrame:SetVerticalScroll(math.max(0, math.min(target, maximum)))
    end)

    local function GetFontChoices()
        return self:GetMediaChoices("font", true)
    end
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
    local function GetProgressBarTextureChoices()
        return self:GetMediaChoices("statusbar", false)
    end

    local layoutRows = {
        CreateSlider(
            optionsContent,
            self.text.trackerWidth,
            self.TRACKER_WIDTH_MIN,
            self.TRACKER_WIDTH_MAX,
            function()
                return self.db.trackerWidth
            end,
            function(value)
                self:SetCustomTrackerSize(value, nil)
            end,
            function(value)
                return ("%d px"):format(value)
            end
        ),
        CreateSlider(
            optionsContent,
            self.text.trackerHeight,
            self.TRACKER_HEIGHT_MIN,
            self.TRACKER_HEIGHT_MAX,
            function()
                return self.db.trackerHeight
            end,
            function(value)
                self:SetCustomTrackerSize(nil, value)
            end,
            function(value)
                return ("%d px"):format(value)
            end
        ),
        CreateDropdownRow(optionsContent, self.text.background, backgroundChoices, function()
            return self.db.background
        end, function(value)
            self.db.background = value
            self:ApplyCustomAppearance()
        end),
    }

    local textRows = {
        CreateDropdownRow(optionsContent, self.text.font, GetFontChoices, function()
            return self.db.fontFace
        end, function(value)
            self.db.fontFace = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.fontSize, 8, 32, function()
            return self.db.fontSize
        end, function(value)
            self.db.fontSize = value
            self:ApplyCustomAppearance()
        end, function(value)
            return ("%d px"):format(value)
        end),
        CreateDropdownRow(optionsContent, self.text.fontOutline, fontOutlineChoices, function()
            return self.db.fontOutline
        end, function(value)
            self.db.fontOutline = value
            self:ApplyCustomAppearance()
        end),
        CreateDropdownRow(optionsContent, self.text.fontShadow, fontShadowChoices, function()
            return self.db.fontShadow
        end, function(value)
            self.db.fontShadow = value
            self:ApplyCustomAppearance()
        end),
    }

    local questRows = {
        CreateColorRow(optionsContent, self.text.questTitleColor, function()
            return self.db.questTitleColor
        end, function(red, green, blue)
            self.db.questTitleColor = { r = red, g = green, b = blue }
            self:ApplyCustomAppearance()
        end),
        CreateColorRow(optionsContent, self.text.questCompleteColor, function()
            return self.db.questCompleteColor
        end, function(red, green, blue)
            self.db.questCompleteColor = { r = red, g = green, b = blue }
            self:ApplyCustomAppearance()
        end),
        CreateColorRow(optionsContent, self.text.questLowLevelColor, function()
            return self.db.questLowLevelColor
        end, function(red, green, blue)
            self.db.questLowLevelColor = { r = red, g = green, b = blue }
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questLowLevelThreshold, -20, 0, function()
            return self.db.questLowLevelThreshold
        end, function(value)
            self.db.questLowLevelThreshold = value
            self:ApplyCustomAppearance()
        end, function(value)
            return ("%+d"):format(value)
        end),
        CreateCheckBoxRow(optionsContent, self.text.showQuestLevel, function()
            return self.db.showQuestLevel
        end, function(value)
            self.db.showQuestLevel = value
            self:ApplyCustomAppearance()
        end),
        CreateCheckBoxRow(optionsContent, self.text.showQuestLocation, function()
            return self.db.showQuestLocation
        end, function(value)
            self.db.showQuestLocation = value
            self:ApplyCustomAppearance()
        end),
        CreateColorRow(optionsContent, self.text.questLocationColor, function()
            return self.db.questLocationColor
        end, function(red, green, blue)
            self.db.questLocationColor = { r = red, g = green, b = blue }
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questSpacing, 0, 30, function()
            return self.db.questSpacing
        end, function(value)
            self.db.questSpacing = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questObjectiveSpacing, 0, 20, function()
            return self.db.questObjectiveSpacing
        end, function(value)
            self.db.questObjectiveSpacing = value
            self:ApplyCustomAppearance()
        end),
    }

    local positioningRows = {
        CreateSlider(optionsContent, self.text.questIconOffsetX, -100, 100, function()
            return self.db.questIconOffsetX
        end, function(value)
            self.db.questIconOffsetX = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questIconOffsetY, -50, 50, function()
            return self.db.questIconOffsetY
        end, function(value)
            self.db.questIconOffsetY = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questTitleOffsetX, -100, 100, function()
            return self.db.questTitleOffsetX
        end, function(value)
            self.db.questTitleOffsetX = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questTitleOffsetY, -50, 50, function()
            return self.db.questTitleOffsetY
        end, function(value)
            self.db.questTitleOffsetY = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questLocationOffsetX, -100, 100, function()
            return self.db.questLocationOffsetX
        end, function(value)
            self.db.questLocationOffsetX = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questLocationOffsetY, -50, 50, function()
            return self.db.questLocationOffsetY
        end, function(value)
            self.db.questLocationOffsetY = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questObjectiveOffsetX, -100, 100, function()
            return self.db.questObjectiveOffsetX
        end, function(value)
            self.db.questObjectiveOffsetX = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.questObjectiveOffsetY, -50, 50, function()
            return self.db.questObjectiveOffsetY
        end, function(value)
            self.db.questObjectiveOffsetY = value
            self:ApplyCustomAppearance()
        end),
    }

    local progressRows = {
        CreateDropdownRow(
            optionsContent,
            self.text.progressBarTexture,
            GetProgressBarTextureChoices,
            function()
                return self.db.progressBarTexture
            end,
            function(value)
                self.db.progressBarTexture = value
                self:ApplyCustomAppearance()
            end
        ),
        CreateSlider(optionsContent, self.text.progressBarHeight, 8, 28, function()
            return self.db.progressBarHeight
        end, function(value)
            self.db.progressBarHeight = value
            self:ApplyCustomAppearance()
        end, function(value)
            return ("%d px"):format(value)
        end),
        CreateColorRow(optionsContent, self.text.progressBarColor, function()
            return self.db.progressBarColor
        end, function(red, green, blue)
            self.db.progressBarColor = { r = red, g = green, b = blue }
            self:ApplyCustomAppearance()
        end),
        CreateSlider(
            optionsContent,
            self.text.progressBarBackgroundOpacity,
            0,
            100,
            function()
                return self.db.progressBarBackgroundOpacity
            end,
            function(value)
                self.db.progressBarBackgroundOpacity = value
                self:ApplyCustomAppearance()
            end,
            function(value)
                return ("%d%%"):format(value)
            end
        ),
    }

    local categoryRows = {
        CreateDropdownRow(optionsContent, self.text.categoryStyle, categoryStyleChoices, function()
            return self.db.categoryStyle
        end, function(value)
            self.db.categoryStyle = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.categoryOffset, -20, 20, function()
            return self.db.categoryOffset
        end, function(value)
            self.db.categoryOffset = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.categoryTextOffset, -100, 100, function()
            return self.db.categoryTextOffset
        end, function(value)
            self.db.categoryTextOffset = value
            self:ApplyCustomAppearance()
        end),
        CreateSlider(optionsContent, self.text.categorySpacing, 0, 30, function()
            return self.db.categorySpacing
        end, function(value)
            self.db.categorySpacing = value
            self:ApplyCustomAppearance()
        end),
    }

    local integrationRows = {
        CreateSlider(
            optionsContent,
            self.text.mythicPlusTimerHeight,
            0,
            600,
            function()
                return self.db.enhanceQoLMythicPlusTimerHeight
            end,
            function(value)
                self.db.enhanceQoLMythicPlusTimerHeight = value
                self:RequestCustomRefresh(false)
                if self.RefreshOptions then
                    self:RefreshOptions()
                end
            end,
            function(value)
                return value == 0 and self.text.automatic or ("%d px"):format(value)
            end
        ),
        CreateDropdownRow(
            optionsContent,
            function()
                return self:GetModuleLabel(self.DAMAGE_METER_CATEGORIES[1])
            end,
            function()
                return self:GetEnhanceQoLDamageMeterChoices()
            end,
            function()
                return self:GetEnhanceQoLDamageMeterWindow(1)
            end,
            function(value)
                self:SetEnhanceQoLDamageMeterWindow(1, value)
            end
        ),
        CreateDropdownRow(
            optionsContent,
            function()
                return self:GetModuleLabel(self.DAMAGE_METER_CATEGORIES[2])
            end,
            function()
                return self:GetEnhanceQoLDamageMeterChoices()
            end,
            function()
                return self:GetEnhanceQoLDamageMeterWindow(2)
            end,
            function(value)
                self:SetEnhanceQoLDamageMeterWindow(2, value)
            end
        ),
        CreateDropdownRow(
            optionsContent,
            function()
                return self:GetModuleLabel(self.DAMAGE_METER_CATEGORIES[3])
            end,
            function()
                return self:GetEnhanceQoLDamageMeterChoices()
            end,
            function()
                return self:GetEnhanceQoLDamageMeterWindow(3)
            end,
            function(value)
                self:SetEnhanceQoLDamageMeterWindow(3, value)
            end
        ),
        CreateDropdownRow(
            optionsContent,
            function()
                return self:GetModuleLabel(self.DAMAGE_METER_CATEGORIES[4])
            end,
            function()
                return self:GetEnhanceQoLDamageMeterChoices()
            end,
            function()
                return self:GetEnhanceQoLDamageMeterWindow(4)
            end,
            function(value)
                self:SetEnhanceQoLDamageMeterWindow(4, value)
            end
        ),
        CreateDropdownRow(
            optionsContent,
            function()
                return self:GetModuleLabel(self.DAMAGE_METER_CATEGORIES[5])
            end,
            function()
                return self:GetEnhanceQoLDamageMeterChoices()
            end,
            function()
                return self:GetEnhanceQoLDamageMeterWindow(5)
            end,
            function(value)
                self:SetEnhanceQoLDamageMeterWindow(5, value)
            end
        ),
    }

    local sections = {
        { id = "layout", label = self.text.editSectionLayout, rows = layoutRows },
        { id = "text", label = self.text.editSectionText, rows = textRows },
        { id = "quests", label = self.text.editSectionQuests, rows = questRows },
        {
            id = "positioning",
            label = self.text.editSectionPositioning,
            rows = positioningRows,
        },
        { id = "progress", label = self.text.editSectionProgress, rows = progressRows },
        { id = "categories", label = self.text.editSectionCategories, rows = categoryRows },
        { id = "integrations", label = self.text.editSectionIntegrations, rows = integrationRows },
    }
    local optionRows = {}
    for _, section in ipairs(sections) do
        local currentSection = section
        section.header = CreateSectionHeader(optionsContent, section.label)
        section.header:SetScript("OnClick", function()
            local collapsed = self.db.editModeCollapsedSections
            collapsed[currentSection.id] = not collapsed[currentSection.id]
            if self.editModeIntegration and self.editModeIntegration.LayoutSections then
                self.editModeIntegration:LayoutSections()
            end
        end)
        for _, row in ipairs(section.rows) do
            optionRows[#optionRows + 1] = row
        end
    end

    local integration = {
        overlay = overlay,
        panel = panel,
        eyeButton = eyeButton,
        optionsScrollFrame = optionsScrollFrame,
        optionsContent = optionsContent,
        sections = sections,
        optionRows = optionRows,
    }
    function integration:LayoutSections()
        local offsetY = -2
        for _, section in ipairs(self.sections) do
            local collapsed = self.addon.db.editModeCollapsedSections[section.id] == true
            section.header:ClearAllPoints()
            section.header:SetPoint("TOPLEFT", self.optionsContent, "TOPLEFT", 0, offsetY)
            section.header:SetPoint("TOPRIGHT", self.optionsContent, "TOPRIGHT", 0, offsetY)
            section.header:SetCollapsed(collapsed)
            section.header:Show()
            offsetY = offsetY - 34

            for _, row in ipairs(section.rows) do
                row:ClearAllPoints()
                row:SetShown(not collapsed)
                if not collapsed then
                    row:SetPoint("TOPLEFT", self.optionsContent, "TOPLEFT", 8, offsetY)
                    row:SetPoint("TOPRIGHT", self.optionsContent, "TOPRIGHT", -8, offsetY)
                    offsetY = offsetY - row:GetHeight() - 2
                end
            end
        end

        self.optionsContent:SetHeight(math.max(1, -offsetY + 4))
        local maximum = math.max(
            0,
            self.optionsContent:GetHeight() - self.optionsScrollFrame:GetHeight()
        )
        self.optionsScrollFrame:SetVerticalScroll(math.min(
            self.optionsScrollFrame:GetVerticalScroll(),
            maximum
        ))
    end
    integration.addon = self
    self.editModeIntegration = integration
    integration:LayoutSections()
    if self.InitializeActiveQuestItemEditMode then
        self:InitializeActiveQuestItemEditMode()
    end

    local function SelectBetterQuestList()
        if InCombatLockdown() then
            return
        end

        local manager = _G.EditModeManagerFrame
        local tracker = state.blizzardTracker
        if manager and manager.SelectSystem and tracker then
            if type(securecallfunction) == "function" then
                securecallfunction(manager.SelectSystem, manager, tracker)
            end
            self:SuppressBlizzardTrackerEditModeSelection()
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
            if type(securecallfunction) == "function" then
                securecallfunction(tracker.OnDragStart, tracker)
            end
        end
    end)
    overlay:SetScript("OnDragStop", function()
        local tracker = state.blizzardTracker
        if tracker and tracker.OnDragStop then
            if type(securecallfunction) == "function" then
                securecallfunction(tracker.OnDragStop, tracker)
            end
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
