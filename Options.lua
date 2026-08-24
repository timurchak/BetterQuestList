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
    controls:SetSize(620, math.max(760, 150 + MAX_ROWS * 58))
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
        row:SetHeight(54)
        row:SetPoint("LEFT", controls, "LEFT", 16, 0)
        row:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
        if index == 1 then
            row:SetPoint("TOP", description, "BOTTOM", 0, -14)
        else
            row:SetPoint("TOP", self.categoryNameRows[index - 1], "BOTTOM", 0, -4)
        end

        local defaultLabel = CreateLabel(row, "GameFontHighlight", "")
        defaultLabel:SetPoint("TOPLEFT", 0, -3)
        defaultLabel:SetWidth(260)

        local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        editBox:SetPoint("TOPLEFT", defaultLabel, "TOPRIGHT", 10, 3)
        editBox:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 3)
        editBox:SetHeight(26)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(80)

        local hideHeaderCheck = CreateFrame(
            "CheckButton",
            nil,
            row,
            "UICheckButtonTemplate"
        )
        hideHeaderCheck:SetPoint("TOPLEFT", row, "TOPLEFT", -4, -26)
        hideHeaderCheck:SetScript("OnClick", function(button)
            if row.category then
                self:SetCategoryHeaderHidden(
                    row.category,
                    button:GetChecked() and true or false
                )
            end
        end)

        local hideHeaderLabel = CreateLabel(
            row,
            "GameFontNormalSmall",
            self.text.hideCategoryHeader
        )
        hideHeaderLabel:SetPoint("LEFT", hideHeaderCheck, "RIGHT", 0, 0)

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
        row.hideHeaderCheck = hideHeaderCheck
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
            row.hideHeaderCheck:SetChecked(self:IsCategoryHeaderHidden(category))
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
    controls:SetSize(620, math.max(940, 610 + MAX_ROWS * (ROW_HEIGHT + 1)))
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

    local mythicPlusHideCheck = CreateFrame(
        "CheckButton",
        nil,
        controls,
        "UICheckButtonTemplate"
    )
    mythicPlusHideCheck:SetPoint(
        "TOPLEFT",
        activeQuestItemDescription,
        "BOTTOMLEFT",
        -30,
        -14
    )
    mythicPlusHideCheck:SetScript("OnClick", function(button)
        self.db.mythicPlusHideOtherCategories = button:GetChecked() and true or false
        self:RequestCustomRefresh(false)
    end)
    self.mythicPlusHideCheck = mythicPlusHideCheck

    local mythicPlusHideLabel = CreateLabel(
        controls,
        "GameFontNormal",
        self.text.mythicPlusHideOtherCategories
    )
    mythicPlusHideLabel:SetPoint("LEFT", mythicPlusHideCheck, "RIGHT", 2, 0)

    local mythicPlusHideDescription = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        self.text.mythicPlusHideOtherCategoriesDescription
    )
    mythicPlusHideDescription:SetPoint(
        "TOPLEFT",
        mythicPlusHideCheck,
        "BOTTOMLEFT",
        30,
        -2
    )
    mythicPlusHideDescription:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    mythicPlusHideDescription:SetWordWrap(true)

    local mythicPlusCollapseCheck = CreateFrame(
        "CheckButton",
        nil,
        controls,
        "UICheckButtonTemplate"
    )
    mythicPlusCollapseCheck:SetPoint(
        "TOPLEFT",
        mythicPlusHideDescription,
        "BOTTOMLEFT",
        -30,
        -14
    )
    mythicPlusCollapseCheck:SetScript("OnClick", function(button)
        self.db.mythicPlusCollapseOtherCategories = button:GetChecked() and true or false
        self:RequestCustomRefresh(false)
    end)
    self.mythicPlusCollapseCheck = mythicPlusCollapseCheck

    local mythicPlusCollapseLabel = CreateLabel(
        controls,
        "GameFontNormal",
        self.text.mythicPlusCollapseOtherCategories
    )
    mythicPlusCollapseLabel:SetPoint("LEFT", mythicPlusCollapseCheck, "RIGHT", 2, 0)

    local mythicPlusCollapseDescription = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        self.text.mythicPlusCollapseOtherCategoriesDescription
    )
    mythicPlusCollapseDescription:SetPoint(
        "TOPLEFT",
        mythicPlusCollapseCheck,
        "BOTTOMLEFT",
        30,
        -2
    )
    mythicPlusCollapseDescription:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    mythicPlusCollapseDescription:SetWordWrap(true)

    local mythicPlusRaidHideTrackerCheck = CreateFrame(
        "CheckButton",
        nil,
        controls,
        "UICheckButtonTemplate"
    )
    mythicPlusRaidHideTrackerCheck:SetPoint(
        "TOPLEFT",
        mythicPlusCollapseDescription,
        "BOTTOMLEFT",
        -30,
        -14
    )
    mythicPlusRaidHideTrackerCheck:SetScript("OnClick", function(button)
        self.db.mythicPlusRaidHideTracker = button:GetChecked() and true or false
        self:RequestCustomRefresh(false)
    end)
    self.mythicPlusRaidHideTrackerCheck = mythicPlusRaidHideTrackerCheck

    local mythicPlusRaidHideTrackerLabel = CreateLabel(
        controls,
        "GameFontNormal",
        self.text.mythicPlusRaidHideTracker
    )
    mythicPlusRaidHideTrackerLabel:SetPoint(
        "LEFT",
        mythicPlusRaidHideTrackerCheck,
        "RIGHT",
        2,
        0
    )

    local mythicPlusRaidHideTrackerDescription = CreateLabel(
        controls,
        "GameFontHighlightSmall",
        self.text.mythicPlusRaidHideTrackerDescription
    )
    mythicPlusRaidHideTrackerDescription:SetPoint(
        "TOPLEFT",
        mythicPlusRaidHideTrackerCheck,
        "BOTTOMLEFT",
        30,
        -2
    )
    mythicPlusRaidHideTrackerDescription:SetPoint("RIGHT", controls, "RIGHT", -24, 0)
    mythicPlusRaidHideTrackerDescription:SetWordWrap(true)

    local mythicPlusTimerHeightLabel = CreateLabel(
        controls,
        "GameFontHighlight",
        self.text.mythicPlusTimerHeight
    )
    mythicPlusTimerHeightLabel:SetPoint(
        "TOPLEFT",
        mythicPlusRaidHideTrackerDescription,
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
    self.mythicPlusHideCheck:SetChecked(self.db.mythicPlusHideOtherCategories)
    self.mythicPlusHideCheck:SetEnabled(true)
    self.mythicPlusCollapseCheck:SetChecked(self.db.mythicPlusCollapseOtherCategories)
    self.mythicPlusCollapseCheck:SetEnabled(true)
    self.mythicPlusRaidHideTrackerCheck:SetChecked(self.db.mythicPlusRaidHideTracker)
    self.mythicPlusRaidHideTrackerCheck:SetEnabled(true)
    self.mythicPlusTimerHeightSlider:SetValue(
        self.db.enhanceQoLMythicPlusTimerHeight
    )
    self.mythicPlusTimerHeightValue:SetText(
        self.db.enhanceQoLMythicPlusTimerHeight == 0
            and self.text.automatic
            or ("%d px"):format(self.db.enhanceQoLMythicPlusTimerHeight)
    )
end
