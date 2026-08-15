local _, BQL = ...

local ROW_HEIGHT = 24
local MAX_ROWS = 16

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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

function BQL:CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = ("|T%s:16:16:0:0|t %s"):format(self.ICON_PATH, self.text.title)
    self.optionsPanel = panel
    self.optionRows = {}

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 16, -12)
    icon:SetTexture(self.ICON_PATH)

    local title = CreateLabel(panel, "GameFontNormalLarge", self.text.title)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)

    local description = CreateLabel(panel, "GameFontHighlightSmall", self.text.description)
    description:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    description:SetWordWrap(true)

    local compatibilityWarning = CreateLabel(panel, "GameFontRedSmall", self.text.compatibilityWarning)
    compatibilityWarning:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
    compatibilityWarning:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    compatibilityWarning:SetWordWrap(true)

    local orderTitle = CreateLabel(panel, "GameFontNormal", self.text.order)
    orderTitle:SetPoint("TOPLEFT", compatibilityWarning, "BOTTOMLEFT", 0, -18)
    self.orderTitle = orderTitle

    for index = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, panel)
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

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("TOPLEFT", self.optionRows[MAX_ROWS], "BOTTOMLEFT", 0, -12)
    reset:SetText(self.text.reset)
    reset:SetScript("OnClick", function()
        self:ResetOrder()
    end)
    self.resetButton = reset

    local scrollCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    scrollCheck:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", -4, -18)
    scrollCheck:SetScript("OnClick", function(button)
        self.db.scrollEnabled = button:GetChecked() and true or false
        self:SetScrollingEnabled(self.db.scrollEnabled)
    end)
    self.scrollCheck = scrollCheck

    local scrollLabel = CreateLabel(panel, "GameFontNormal", self.text.scrolling)
    scrollLabel:SetPoint("LEFT", scrollCheck, "RIGHT", 2, 0)

    local scrollDescription = CreateLabel(panel, "GameFontHighlightSmall", self.text.scrollingDescription)
    scrollDescription:SetPoint("TOPLEFT", scrollCheck, "BOTTOMLEFT", 30, -2)
    scrollDescription:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    scrollDescription:SetWordWrap(true)

    panel:SetScript("OnShow", function()
        self:RefreshOptions()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
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
            row.up:SetEnabled(false)
            row.down:SetEnabled(false)
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

    self.resetButton:SetEnabled(false)
    self.scrollCheck:SetChecked(false)
    self.scrollCheck:SetEnabled(false)
end
