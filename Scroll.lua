local _, BQL = ...

function BQL:InitializeScrolling()
    self.scrollState = {
        enabled = false,
        unavailable = true,
    }
end

function BQL:SetScrollingEnabled(enabled)
    self.db.scrollEnabled = false
    if enabled and not self.scrollUnavailableWarningShown then
        self.scrollUnavailableWarningShown = true
        self:Print(self.text.restrictedMode)
    end
    return false
end

