local _, BQL = ...

local ROW_HEIGHT = 24
local MAX_ROWS = #BQL.DEFAULT_ORDER

local function CreateLabel(parent, fontObject, text)
    local label = parent:CreateFontString(nil, "ARTWORK", fontObject)
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

local function CreateMoveButton(parent, direction, tooltipText)
    local button = CreateFrame("Button", nil, parent)
    local texturePrefix = "Interface/Buttons/UI-ScrollBar-Scroll" .. direction .. "Button-"
    button:SetSize(24, 24)
    button:SetNormalTexture(texturePrefix .. "Up")
    button:SetPushedTexture(texturePrefix .. "Down")
    button:SetDisabledTexture(texturePrefix .. "Disabled")
    button:SetHighlightTexture(texturePrefix .. "Highlight", "ADD")
    button:SetScript("OnEnter", function(self)
        local tooltip = BQL:GetTooltip()
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
        tooltip:SetText(tooltipText)
        tooltip:ShowTooltip()
    end)
    button:SetScript("OnLeave", function()
        BQL:HideTooltip()
    end)
    return button
end

local function CreateChoiceDropdown(parent, choices, getValue, setValue)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, 190)

    function dropdown:Refresh()
        local selectedValue = getValue()
        for _, choice in ipairs(choices) do
            if choice.value == selectedValue then
                UIDropDownMenu_SetSelectedValue(self, selectedValue)
                UIDropDownMenu_SetText(self, choice.label)
                return
            end
        end
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local selectedValue = getValue()
        for _, choice in ipairs(choices) do
            local value = choice.value
            local label = choice.label
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.value = value
            info.checked = selectedValue == value
            info.func = function()
                setValue(value)
                dropdown:Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dropdown
end

function BQL:CreateCategoryNamesOptions(parentCategory)
    if not Settings or not Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = self.text.categoryNames

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    local controls = CreateFrame("Frame", nil, scrollFrame)
    controls:SetSize(620, math.max(720, 130 + MAX_ROWS * 38))
    scrollFrame:SetScrollChild(controls)
    panel:HookScript("OnSizeChanged", function(_, width)
        if type(width) == "number" then
            controls:SetWidth(math.max(width - 40, 560))
        end
    end)

    local title = CreateLabel(controls, "GameFontNormalLarge", self.text.categoryNames)
    title:SetPoint("TOPLEFT", 16, -16)

    local description = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        self.text.categoryNamesDescription
    )
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    description:SetWordWrap(true)

    self.categoryNameRows = {}
    for index = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, controls)
        row:SetHeight(34)
        row:SetPoint("LEFT", controls, "LEFT", 16, 0)
        row:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
        if index == 1 then
            row:SetPoint("TOP", description, "BOTTOM", 0, -14)
        else
            row:SetPoint("TOP", self.categoryNameRows[index - 1], "BOTTOM", 0, -4)
        end

        local defaultLabel = CreateLabel(row, "GameFontHighlight", "")
        defaultLabel:SetPoint("LEFT", 0, 0)
        defaultLabel:SetWidth(260)

        local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        editBox:SetPoint("LEFT", defaultLabel, "RIGHT", 10, 0)
        editBox:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        editBox:SetHeight(26)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(80)

        local function SaveName()
            if row.category then
                self:SetCustomModuleLabel(row.category, editBox:GetText())
            end
        end
        editBox:SetScript("OnEnterPressed", function(box)
            SaveName()
            box:ClearFocus()
        end)
        editBox:SetScript("OnEditFocusLost", SaveName)
        editBox:SetScript("OnEscapePressed", function(box)
            box:SetText(row.category and self:GetCustomModuleLabel(row.category) or "")
            box:ClearFocus()
        end)

        row.defaultLabel = defaultLabel
        row.editBox = editBox
        self.categoryNameRows[index] = row
    end

    local reset = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    reset:SetSize(190, 26)
    reset:SetPoint("TOPLEFT", self.categoryNameRows[MAX_ROWS], "BOTTOMLEFT", 0, -14)
    reset:SetText(self.text.resetCategoryNames)
    reset:SetScript("OnClick", function()
        self:ResetCustomModuleLabels()
    end)

    panel:SetScript("OnShow", function()
        self:RefreshCategoryNames()
    end)

    self.categoryNamesPanel = panel
    self.categoryNamesCategory = Settings.RegisterCanvasLayoutSubcategory(
        parentCategory,
        panel,
        panel.name
    )
    self:RefreshCategoryNames()
end

function BQL:RefreshCategoryNames()
    if not self.categoryNameRows or not self.db then
        return
    end

    local order = self:ReconcileOrder()
    for index, row in ipairs(self.categoryNameRows) do
        local category = order[index]
        row.category = category
        if category then
            row.defaultLabel:SetFormattedText(
                self.text.categoryNameDefault,
                self:GetDefaultModuleLabel(category)
            )
            if not row.editBox:HasFocus() then
                row.editBox:SetText(self:GetCustomModuleLabel(category))
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

function BQL:CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = ("|T%s:16:16:0:0|t %s"):format(self.ICON_PATH, self.text.title)
    self.optionsPanel = panel
    self.optionRows = {}

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    local controls = CreateFrame("Frame", nil, scrollFrame)
    controls:SetSize(620, 1280)
    scrollFrame:SetScrollChild(controls)
    panel:HookScript("OnSizeChanged", function(_, width)
        if type(width) == "number" then
            controls:SetWidth(math.max(width - 40, 560))
        end
    end)

    local icon = controls:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 16, -12)
    icon:SetTexture(self.ICON_PATH)

    local title = CreateLabel(controls, "GameFontNormalLarge", self.text.title)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)

    local description = CreateLabel(controls, "GameFontHighlightSmall", self.text.description)
    description:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    description:SetWordWrap(true)

    local compatibilityWarning = CreateLabel(controls, "GameFontHighlightSmall", self.text.compatibilityWarning)
    compatibilityWarning:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
    compatibilityWarning:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    compatibilityWarning:SetWordWrap(true)

    local orderTitle = CreateLabel(controls, "GameFontNormal", self.text.order)
    orderTitle:SetPoint("TOPLEFT", compatibilityWarning, "BOTTOMLEFT", 0, -18)
    self.orderTitle = orderTitle

    for index = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, controls)
        row:SetSize(500, ROW_HEIGHT)
        if index == 1 then
            row:SetPoint("TOPLEFT", orderTitle, "BOTTOMLEFT", 0, -8)
        else
            row:SetPoint("TOPLEFT", self.optionRows[index - 1], "BOTTOMLEFT", 0, -1)
        end

        row.index = index
        row.number = CreateLabel(row, "GameFontHighlight", index .. ".")
        row.number:SetPoint("LEFT", 2, 0)
        row.number:SetWidth(25)

        row.label = CreateLabel(row, "GameFontHighlight", "")
        row.label:SetPoint("LEFT", row.number, "RIGHT", 3, 0)
        row.label:SetWidth(330)

        row.up = CreateMoveButton(row, "Up", self.text.moveUp)
        row.up:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
        row.up:SetScript("OnClick", function()
            self:MoveModule(row.index, -1)
        end)

        row.down = CreateMoveButton(row, "Down", self.text.moveDown)
        row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)
        row.down:SetScript("OnClick", function()
            self:MoveModule(row.index, 1)
        end)

        self.optionRows[index] = row
    end

    local reset = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("TOPLEFT", self.optionRows[MAX_ROWS], "BOTTOMLEFT", 0, -12)
    reset:SetText(self.text.reset)
    reset:SetScript("OnClick", function()
        self:ResetOrder()
    end)
    self.resetButton = reset

    local scrollCheck = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
    scrollCheck:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", -4, -18)
    scrollCheck:SetScript("OnClick", function(button)
        self.db.scrollEnabled = button:GetChecked() and true or false
        self:SetScrollingEnabled(self.db.scrollEnabled)
    end)
    self.scrollCheck = scrollCheck

    local scrollLabel = CreateLabel(controls, "GameFontNormal", self.text.scrolling)
    scrollLabel:SetPoint("LEFT", scrollCheck, "RIGHT", 2, 0)

    local scrollDescription = CreateLabel(controls, "GameFontHighlightSmall", self.text.scrollingDescription)
    scrollDescription:SetPoint("TOPLEFT", scrollCheck, "BOTTOMLEFT", 30, -2)
    scrollDescription:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    scrollDescription:SetWordWrap(true)

    local autoTrackCheck = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
    autoTrackCheck:SetPoint("TOPLEFT", scrollDescription, "BOTTOMLEFT", -30, -14)
    autoTrackCheck:SetScript("OnClick", function(button)
        self:SetAcceptedQuestAutoTrackingEnabled(button:GetChecked() and true or false)
        button:SetChecked(self:IsAcceptedQuestAutoTrackingEnabled())
    end)
    self.autoTrackCheck = autoTrackCheck

    local autoTrackLabel = CreateLabel(
        controls,
        "GameFontNormal",
        self.text.autoTrackAcceptedQuests
    )
    autoTrackLabel:SetPoint("LEFT", autoTrackCheck, "RIGHT", 2, 0)

    local autoTrackDescription = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        self.text.autoTrackAcceptedQuestsDescription
    )
    autoTrackDescription:SetPoint("TOPLEFT", autoTrackCheck, "BOTTOMLEFT", 30, -2)
    autoTrackDescription:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    autoTrackDescription:SetWordWrap(true)

    local activeQuestItemCheck = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
    activeQuestItemCheck:SetPoint("TOPLEFT", autoTrackDescription, "BOTTOMLEFT", -30, -14)
    activeQuestItemCheck:SetScript("OnClick", function(button)
        self:SetActiveQuestItemEnabled(button:GetChecked() and true or false)
    end)
    self.activeQuestItemCheck = activeQuestItemCheck

    local activeQuestItemLabel = CreateLabel(
        controls,
        "GameFontNormal",
        self.text.activeQuestItem
    )
    activeQuestItemLabel:SetPoint("LEFT", activeQuestItemCheck, "RIGHT", 2, 0)

    local activeQuestItemDescription = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        self.text.activeQuestItemDescription
    )
    activeQuestItemDescription:SetPoint("TOPLEFT", activeQuestItemCheck, "BOTTOMLEFT", 30, -2)
    activeQuestItemDescription:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    activeQuestItemDescription:SetWordWrap(true)

    local mythicPlusTimerHeightLabel = CreateLabel(
        controls,
        "GameFontHighlight",
        self.text.mythicPlusTimerHeight
    )
    mythicPlusTimerHeightLabel:SetPoint(
        "TOPLEFT",
        activeQuestItemDescription,
        "BOTTOMLEFT",
        30,
        -18
    )
    mythicPlusTimerHeightLabel:SetWidth(190)

    local mythicPlusTimerHeightSlider = CreateFrame(
        "Slider",
        nil,
        controls,
        "OptionsSliderTemplate"
    )
    mythicPlusTimerHeightSlider:SetPoint(
        "LEFT",
        mythicPlusTimerHeightLabel,
        "RIGHT",
        18,
        0
    )
    mythicPlusTimerHeightSlider:SetWidth(170)
    mythicPlusTimerHeightSlider:SetMinMaxValues(0, 600)
    mythicPlusTimerHeightSlider:SetValueStep(1)
    mythicPlusTimerHeightSlider:SetObeyStepOnDrag(true)
    self.mythicPlusTimerHeightSlider = mythicPlusTimerHeightSlider

    local mythicPlusTimerHeightValue = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        ""
    )
    mythicPlusTimerHeightValue:SetPoint(
        "LEFT",
        mythicPlusTimerHeightSlider,
        "RIGHT",
        12,
        0
    )
    mythicPlusTimerHeightValue:SetWidth(75)
    self.mythicPlusTimerHeightValue = mythicPlusTimerHeightValue

    mythicPlusTimerHeightSlider:SetScript("OnValueChanged", function(_, value)
        local roundedValue = math.max(0, math.min(math.floor(value + 0.5), 600))
        mythicPlusTimerHeightValue:SetText(
            roundedValue == 0 and self.text.automatic or ("%d px"):format(roundedValue)
        )
        if self.db.enhanceQoLMythicPlusTimerHeight ~= roundedValue then
            self.db.enhanceQoLMythicPlusTimerHeight = roundedValue
            self:RequestCustomRefresh(false)
            if self.RefreshEditModeAppearancePanel then
                self:RefreshEditModeAppearancePanel()
            end
        end
    end)

    local appearanceTitle = CreateLabel(controls, "GameFontNormal", self.text.appearance)
    appearanceTitle:SetPoint("TOPLEFT", mythicPlusTimerHeightLabel, "BOTTOMLEFT", -30, -22)

    local fontLabel = CreateLabel(controls, "GameFontHighlight", self.text.font)
    fontLabel:SetPoint("TOPLEFT", appearanceTitle, "BOTTOMLEFT", 0, -18)
    fontLabel:SetWidth(190)

    local fontChoices = {
        { value = "default", label = self.text.fontDefault },
        { value = "chat", label = self.text.fontChat },
        { value = "quest", label = self.text.fontQuest },
        { value = "system", label = self.text.fontSystem },
    }
    local fontDropdown = CreateChoiceDropdown(controls, fontChoices, function()
        return self.db.font
    end, function(value)
        self.db.font = value
        self:ApplyCustomAppearance()
    end)
    fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", 6, -2)
    self.fontDropdown = fontDropdown

    local fontOutlineLabel = CreateLabel(controls, "GameFontHighlight", self.text.fontOutline)
    fontOutlineLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -24)
    fontOutlineLabel:SetWidth(190)

    local fontOutlineChoices = {
        { value = "default", label = self.text.fontOutlineDefault },
        { value = "none", label = self.text.fontOutlineNone },
        { value = "outline", label = self.text.fontOutlineNormal },
        { value = "thick", label = self.text.fontOutlineThick },
    }
    local fontOutlineDropdown = CreateChoiceDropdown(controls, fontOutlineChoices, function()
        return self.db.fontOutline
    end, function(value)
        self.db.fontOutline = value
        self:ApplyCustomAppearance()
    end)
    fontOutlineDropdown:SetPoint("LEFT", fontOutlineLabel, "RIGHT", 6, -2)
    self.fontOutlineDropdown = fontOutlineDropdown

    local fontShadowLabel = CreateLabel(controls, "GameFontHighlight", self.text.fontShadow)
    fontShadowLabel:SetPoint("TOPLEFT", fontOutlineLabel, "BOTTOMLEFT", 0, -24)
    fontShadowLabel:SetWidth(190)

    local fontShadowChoices = {
        { value = "default", label = self.text.fontShadowDefault },
        { value = "enabled", label = self.text.fontShadowEnabled },
        { value = "disabled", label = self.text.fontShadowDisabled },
    }
    local fontShadowDropdown = CreateChoiceDropdown(controls, fontShadowChoices, function()
        return self.db.fontShadow
    end, function(value)
        self.db.fontShadow = value
        self:ApplyCustomAppearance()
    end)
    fontShadowDropdown:SetPoint("LEFT", fontShadowLabel, "RIGHT", 6, -2)
    self.fontShadowDropdown = fontShadowDropdown

    local backgroundLabel = CreateLabel(controls, "GameFontHighlight", self.text.background)
    backgroundLabel:SetPoint("TOPLEFT", fontShadowLabel, "BOTTOMLEFT", 0, -24)
    backgroundLabel:SetWidth(190)

    local backgroundChoices = {
        { value = "none", label = self.text.backgroundNone },
        { value = "subtle", label = self.text.backgroundSubtle },
        { value = "dark", label = self.text.backgroundDark },
    }
    local backgroundDropdown = CreateChoiceDropdown(controls, backgroundChoices, function()
        return self.db.background
    end, function(value)
        self.db.background = value
        self:ApplyCustomAppearance()
    end)
    backgroundDropdown:SetPoint("LEFT", backgroundLabel, "RIGHT", 6, -2)
    self.backgroundDropdown = backgroundDropdown

    local categoryStyleLabel = CreateLabel(controls, "GameFontHighlight", self.text.categoryStyle)
    categoryStyleLabel:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", 0, -24)
    categoryStyleLabel:SetWidth(190)

    local categoryStyleChoices = {
        { value = "blizzard", label = self.text.categoryStyleBlizzard },
        { value = "plain", label = self.text.categoryStylePlain },
    }
    local categoryStyleDropdown = CreateChoiceDropdown(controls, categoryStyleChoices, function()
        return self.db.categoryStyle
    end, function(value)
        self.db.categoryStyle = value
        self:ApplyCustomAppearance()
    end)
    categoryStyleDropdown:SetPoint("LEFT", categoryStyleLabel, "RIGHT", 6, -2)
    self.categoryStyleDropdown = categoryStyleDropdown

    local categoryOffsetLabel = CreateLabel(controls, "GameFontHighlight", self.text.categoryOffset)
    categoryOffsetLabel:SetPoint("TOPLEFT", categoryStyleLabel, "BOTTOMLEFT", 0, -26)
    categoryOffsetLabel:SetWidth(190)

    local categoryOffsetSlider = CreateFrame("Slider", nil, controls, "OptionsSliderTemplate")
    categoryOffsetSlider:SetPoint("LEFT", categoryOffsetLabel, "RIGHT", 18, 0)
    categoryOffsetSlider:SetWidth(170)
    categoryOffsetSlider:SetMinMaxValues(-20, 20)
    categoryOffsetSlider:SetValueStep(1)
    categoryOffsetSlider:SetObeyStepOnDrag(true)
    self.categoryOffsetSlider = categoryOffsetSlider

    local categoryOffsetValue = CreateLabel(controls, "GameFontHighlightSmall", "")
    categoryOffsetValue:SetPoint("LEFT", categoryOffsetSlider, "RIGHT", 12, 0)
    categoryOffsetValue:SetWidth(55)
    self.categoryOffsetValue = categoryOffsetValue

    categoryOffsetSlider:SetScript("OnValueChanged", function(_, value)
        local roundedValue = math.max(-20, math.min(math.floor(value + 0.5), 20))
        categoryOffsetValue:SetFormattedText("%+d px", roundedValue)
        if self.db.categoryOffset ~= roundedValue then
            self.db.categoryOffset = roundedValue
            self:ApplyCustomAppearance()
        end
    end)

    local categoryTextOffsetLabel = CreateLabel(controls, "GameFontHighlight", self.text.categoryTextOffset)
    categoryTextOffsetLabel:SetPoint("TOPLEFT", categoryOffsetLabel, "BOTTOMLEFT", 0, -28)
    categoryTextOffsetLabel:SetWidth(190)

    local categoryTextOffsetSlider = CreateFrame("Slider", nil, controls, "OptionsSliderTemplate")
    categoryTextOffsetSlider:SetPoint("LEFT", categoryTextOffsetLabel, "RIGHT", 18, 0)
    categoryTextOffsetSlider:SetWidth(170)
    categoryTextOffsetSlider:SetMinMaxValues(-100, 100)
    categoryTextOffsetSlider:SetValueStep(1)
    categoryTextOffsetSlider:SetObeyStepOnDrag(true)
    self.categoryTextOffsetSlider = categoryTextOffsetSlider

    local categoryTextOffsetValue = CreateLabel(controls, "GameFontHighlightSmall", "")
    categoryTextOffsetValue:SetPoint("LEFT", categoryTextOffsetSlider, "RIGHT", 12, 0)
    categoryTextOffsetValue:SetWidth(55)
    self.categoryTextOffsetValue = categoryTextOffsetValue

    categoryTextOffsetSlider:SetScript("OnValueChanged", function(_, value)
        local roundedValue = math.max(-100, math.min(math.floor(value + 0.5), 100))
        categoryTextOffsetValue:SetFormattedText("%+d px", roundedValue)
        if self.db.categoryTextOffset ~= roundedValue then
            self.db.categoryTextOffset = roundedValue
            self:ApplyCustomAppearance()
        end
    end)

    local categorySpacingLabel = CreateLabel(controls, "GameFontHighlight", self.text.categorySpacing)
    categorySpacingLabel:SetPoint("TOPLEFT", categoryTextOffsetLabel, "BOTTOMLEFT", 0, -28)
    categorySpacingLabel:SetWidth(190)

    local categorySpacingSlider = CreateFrame("Slider", nil, controls, "OptionsSliderTemplate")
    categorySpacingSlider:SetPoint("LEFT", categorySpacingLabel, "RIGHT", 18, 0)
    categorySpacingSlider:SetWidth(170)
    categorySpacingSlider:SetMinMaxValues(0, 30)
    categorySpacingSlider:SetValueStep(1)
    categorySpacingSlider:SetObeyStepOnDrag(true)
    self.categorySpacingSlider = categorySpacingSlider

    local categorySpacingValue = CreateLabel(controls, "GameFontHighlightSmall", "")
    categorySpacingValue:SetPoint("LEFT", categorySpacingSlider, "RIGHT", 12, 0)
    categorySpacingValue:SetWidth(55)
    self.categorySpacingValue = categorySpacingValue

    categorySpacingSlider:SetScript("OnValueChanged", function(_, value)
        local roundedValue = math.max(0, math.min(math.floor(value + 0.5), 30))
        categorySpacingValue:SetFormattedText("%+d px", roundedValue)
        if self.db.categorySpacing ~= roundedValue then
            self.db.categorySpacing = roundedValue
            self:ApplyCustomAppearance()
        end
    end)

    local questSpacingLabel = CreateLabel(controls, "GameFontHighlight", self.text.questSpacing)
    questSpacingLabel:SetPoint("TOPLEFT", categorySpacingLabel, "BOTTOMLEFT", 0, -28)
    questSpacingLabel:SetWidth(190)

    local questSpacingSlider = CreateFrame("Slider", nil, controls, "OptionsSliderTemplate")
    questSpacingSlider:SetPoint("LEFT", questSpacingLabel, "RIGHT", 18, 0)
    questSpacingSlider:SetWidth(170)
    questSpacingSlider:SetMinMaxValues(0, 30)
    questSpacingSlider:SetValueStep(1)
    questSpacingSlider:SetObeyStepOnDrag(true)
    self.questSpacingSlider = questSpacingSlider

    local questSpacingValue = CreateLabel(controls, "GameFontHighlightSmall", "")
    questSpacingValue:SetPoint("LEFT", questSpacingSlider, "RIGHT", 12, 0)
    questSpacingValue:SetWidth(55)
    self.questSpacingValue = questSpacingValue

    questSpacingSlider:SetScript("OnValueChanged", function(_, value)
        local roundedValue = math.max(0, math.min(math.floor(value + 0.5), 30))
        questSpacingValue:SetFormattedText("%+d px", roundedValue)
        if self.db.questSpacing ~= roundedValue then
            self.db.questSpacing = roundedValue
            self:ApplyCustomAppearance()
        end
    end)

    local questObjectiveSpacingLabel = CreateLabel(
        controls,
        "GameFontHighlight",
        self.text.questObjectiveSpacing
    )
    questObjectiveSpacingLabel:SetPoint("TOPLEFT", questSpacingLabel, "BOTTOMLEFT", 0, -28)
    questObjectiveSpacingLabel:SetWidth(190)

    local questObjectiveSpacingSlider = CreateFrame("Slider", nil, controls, "OptionsSliderTemplate")
    questObjectiveSpacingSlider:SetPoint("LEFT", questObjectiveSpacingLabel, "RIGHT", 18, 0)
    questObjectiveSpacingSlider:SetWidth(170)
    questObjectiveSpacingSlider:SetMinMaxValues(0, 20)
    questObjectiveSpacingSlider:SetValueStep(1)
    questObjectiveSpacingSlider:SetObeyStepOnDrag(true)
    self.questObjectiveSpacingSlider = questObjectiveSpacingSlider

    local questObjectiveSpacingValue = CreateLabel(controls, "GameFontHighlightSmall", "")
    questObjectiveSpacingValue:SetPoint("LEFT", questObjectiveSpacingSlider, "RIGHT", 12, 0)
    questObjectiveSpacingValue:SetWidth(55)
    self.questObjectiveSpacingValue = questObjectiveSpacingValue

    questObjectiveSpacingSlider:SetScript("OnValueChanged", function(_, value)
        local roundedValue = math.max(0, math.min(math.floor(value + 0.5), 20))
        questObjectiveSpacingValue:SetFormattedText("%+d px", roundedValue)
        if self.db.questObjectiveSpacing ~= roundedValue then
            self.db.questObjectiveSpacing = roundedValue
            self:ApplyCustomAppearance()
        end
    end)

    panel:SetScript("OnShow", function()
        self:RefreshOptions()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
        self:CreateCategoryNamesOptions(category)
    end
end

function BQL:RefreshOptions()
    if not self.optionRows or not self.db then
        return
    end

    local order = self:ReconcileOrder()
    local lastVisibleRow
    for index, row in ipairs(self.optionRows) do
        local name = order[index]
        if name then
            row.index = index
            row.number:SetText(index .. ".")
            row.label:SetText(self:GetModuleLabel(name))
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #order)
            row:Show()
            lastVisibleRow = row
        else
            row:Hide()
        end
    end

    self.resetButton:ClearAllPoints()
    if lastVisibleRow then
        self.resetButton:SetPoint("TOPLEFT", lastVisibleRow, "BOTTOMLEFT", 0, -10)
    else
        self.resetButton:SetPoint("TOPLEFT", self.orderTitle, "BOTTOMLEFT", 0, -10)
    end

    self.resetButton:SetEnabled(true)
    self.scrollCheck:SetChecked(self.db.scrollEnabled)
    self.scrollCheck:SetEnabled(true)
    self.autoTrackCheck:SetChecked(self:IsAcceptedQuestAutoTrackingEnabled())
    self.autoTrackCheck:SetEnabled(C_CVar and type(C_CVar.SetCVar) == "function")
    self.activeQuestItemCheck:SetChecked(self.db.activeQuestItemEnabled)
    self.activeQuestItemCheck:SetEnabled(self.activeQuestItem ~= nil)
    self.mythicPlusTimerHeightSlider:SetValue(
        self.db.enhanceQoLMythicPlusTimerHeight
    )
    self.mythicPlusTimerHeightValue:SetText(
        self.db.enhanceQoLMythicPlusTimerHeight == 0
            and self.text.automatic
            or ("%d px"):format(self.db.enhanceQoLMythicPlusTimerHeight)
    )
    self.fontDropdown:Refresh()
    self.fontOutlineDropdown:Refresh()
    self.fontShadowDropdown:Refresh()
    self.backgroundDropdown:Refresh()
    self.categoryStyleDropdown:Refresh()
    self.categoryOffsetSlider:SetValue(self.db.categoryOffset)
    self.categoryOffsetValue:SetFormattedText("%+d px", self.db.categoryOffset)
    self.categoryTextOffsetSlider:SetValue(self.db.categoryTextOffset)
    self.categoryTextOffsetValue:SetFormattedText("%+d px", self.db.categoryTextOffset)
    self.categorySpacingSlider:SetValue(self.db.categorySpacing)
    self.categorySpacingValue:SetFormattedText("%+d px", self.db.categorySpacing)
    self.questSpacingSlider:SetValue(self.db.questSpacing)
    self.questSpacingValue:SetFormattedText("%+d px", self.db.questSpacing)
    self.questObjectiveSpacingSlider:SetValue(self.db.questObjectiveSpacing)
    self.questObjectiveSpacingValue:SetFormattedText("%+d px", self.db.questObjectiveSpacing)
end
