local _, BQL = ...

local HEADER_HEIGHT = 28
local CATEGORY_HEIGHT = 24
local MIN_ROW_HEIGHT = 18
local FRAME_LEFT_OVERFLOW = 30
local FRAME_RIGHT_OVERFLOW = 6
local FRAME_BOTTOM_PADDING = 6
local DATA_REFRESH_DELAY = 0.05
local QUEST_TEXT_LEFT = FRAME_LEFT_OVERFLOW + 20
local OBJECTIVE_TEXT_LEFT = QUEST_TEXT_LEFT + 14

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function GetSafeNumber(value, fallback)
    if IsSecret(value) or type(value) ~= "number" then
        return fallback
    end
    return value
end

local WESTERN_FONT_FILES = {
    chat = "Fonts\\ARIALN.TTF",
    quest = "Fonts\\MORPHEUS.TTF",
    system = "Fonts\\SKURRI.TTF",
}

local CYRILLIC_FONT_FILES = {
    chat = "Fonts\\NIM_____.ttf",
    quest = "Fonts\\MORPHEUS_CYR.TTF",
    system = "Fonts\\SKURRI_CYR.TTF",
}

local BACKGROUND_STYLES = {
    none = {
        background = { 0, 0, 0, 0 },
        border = { 0, 0, 0, 0 },
    },
    subtle = {
        background = { 0.02, 0.02, 0.02, 0.30 },
        border = { 0.35, 0.35, 0.35, 0.25 },
    },
    dark = {
        background = { 0.015, 0.015, 0.015, 0.82 },
        border = { 0.42, 0.42, 0.42, 0.60 },
    },
}

local FONT_OUTLINE_FLAGS = {
    none = "",
    outline = "OUTLINE",
    thick = "THICKOUTLINE",
}

local function ApplySelectedFont(addon, fontString, baseFontObject)
    local baseFont = type(baseFontObject) == "string" and _G[baseFontObject] or baseFontObject
    local baseShadowRed, baseShadowGreen, baseShadowBlue, baseShadowAlpha
    local baseShadowX, baseShadowY
    if baseFont then
        fontString:SetFontObject(baseFont)
        if baseFont.GetShadowColor then
            baseShadowRed, baseShadowGreen, baseShadowBlue, baseShadowAlpha =
                baseFont:GetShadowColor()
        end
        if baseFont.GetShadowOffset then
            baseShadowX, baseShadowY = baseFont:GetShadowOffset()
        end

        -- SetFontObject does not reliably discard a previous explicit SetFont call.
        -- Reapply the resolved Blizzard font so "Default" always restores the live
        -- Objective Tracker font, including its locale and configured text size.
        local baseFile, baseHeight, baseFlags = baseFont:GetFont()
        if baseFile and baseHeight then
            fontString:SetFont(baseFile, baseHeight, baseFlags)
        end
    else
        fontString:SetFontObject(baseFontObject)
    end

    local baseFile, fontHeight, baseFlags = fontString:GetFont()
    local fontFiles = GetLocale() == "ruRU" and CYRILLIC_FONT_FILES or WESTERN_FONT_FILES
    local fontFile = fontFiles[addon.db.font] or baseFile
    local outlineFlags = FONT_OUTLINE_FLAGS[addon.db.fontOutline]
    local fontFlags = outlineFlags ~= nil and outlineFlags or baseFlags
    if fontFile and fontHeight then
        fontString:SetFont(fontFile, fontHeight, fontFlags)
    end

    if addon.db.fontShadow == "enabled" then
        fontString:SetShadowColor(0, 0, 0, 0.95)
        fontString:SetShadowOffset(1, -1)
    elseif addon.db.fontShadow == "disabled" then
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    elseif type(baseShadowRed) == "number" then
        fontString:SetShadowColor(
            baseShadowRed,
            baseShadowGreen,
            baseShadowBlue,
            baseShadowAlpha
        )
        fontString:SetShadowOffset(baseShadowX or 0, baseShadowY or 0)
    end
end

local function SetTrackerGeometry(state)
    local tracker = state.blizzardTracker
    local trackerWidth = GetSafeNumber(tracker:GetWidth(), 235)
    local trackerHeight = GetSafeNumber(tracker:GetHeight(), 600)

    state.frame:ClearAllPoints()
    state.frame:SetPoint("TOPLEFT", tracker, "TOPLEFT", -FRAME_LEFT_OVERFLOW, 0)
    state.frame:SetSize(
        math.max(trackerWidth + FRAME_LEFT_OVERFLOW + FRAME_RIGHT_OVERFLOW, 180),
        math.max(trackerHeight, HEADER_HEIGHT + 40)
    )
end

local function HideBlizzardTracker(state)
    local tracker = state.blizzardTracker
    if not state.stockVisualsHidden then
        state.originalAlpha = tracker:GetAlpha()
        state.stockVisualsHidden = true
    end
    if tracker:GetAlpha() ~= 0 then
        tracker:SetAlpha(0)
    end
end

local function CanUntrackCategory(category)
    return category == "QuestObjectiveTracker"
        or category == "CampaignQuestObjectiveTracker"
        or category == "WorldQuestObjectiveTracker"
end

local function GetWowheadQuestURL(questID)
    local localePath = ({
        deDE = "de",
        ruRU = "ru",
    })[GetLocale()]
    if localePath then
        return ("https://www.wowhead.com/%s/quest=%d"):format(localePath, questID)
    end
    return ("https://www.wowhead.com/quest=%d"):format(questID)
end

local function RefreshAfterQuestAction(state)
    C_Timer.After(0, function()
        state.addon:RequestCustomRefresh(true)
    end)
end

local function UntrackWorldQuest(state, questID)
    if QuestUtil and QuestUtil.UntrackWorldQuest then
        QuestUtil.UntrackWorldQuest(questID)
    elseif C_QuestLog and C_QuestLog.RemoveWorldQuestWatch then
        C_QuestLog.RemoveWorldQuestWatch(questID)
    end
    RefreshAfterQuestAction(state)
end

local function IsWorldQuestWatched(questID)
    if QuestUtils_IsQuestWatched then
        local ok, value = pcall(QuestUtils_IsQuestWatched, questID)
        if ok and not IsSecret(value) then
            return value and true or false
        end
    end
    if C_QuestLog and C_QuestLog.GetQuestWatchType then
        local ok, value = pcall(C_QuestLog.GetQuestWatchType, questID)
        if ok and not IsSecret(value) then
            return value ~= nil
        end
    end
    return false
end

local function OpenProfessionEntry(entry)
    if not _G.ProfessionsFrame and _G.ProfessionsFrame_LoadUI then
        _G.ProfessionsFrame_LoadUI()
    end
    if entry.isRecraft then
        return
    end

    local learned = false
    if C_TradeSkillUI and C_TradeSkillUI.IsRecipeProfessionLearned then
        local ok, value = pcall(C_TradeSkillUI.IsRecipeProfessionLearned, entry.recipeID)
        learned = ok and not IsSecret(value) and value and true or false
    end
    if learned and C_TradeSkillUI.OpenRecipe then
        C_TradeSkillUI.OpenRecipe(entry.recipeID)
    elseif Professions and Professions.InspectRecipe then
        Professions.InspectRecipe(entry.recipeID)
    end
end

local function StopContentTracking(state, entry)
    local stopType = Enum
        and Enum.ContentTrackingStopType
        and Enum.ContentTrackingStopType.Manual
    if C_ContentTracking and C_ContentTracking.StopTracking and stopType then
        C_ContentTracking.StopTracking(entry.trackingType, entry.trackingID, stopType)
        RefreshAfterQuestAction(state)
    end
end

local function ShowTrackingEntryContextMenu(state, row, entry)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end

    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        rootDescription:CreateTitle(entry.title or "")

        if entry.kind == "achievement" then
            rootDescription:SetTag("MENU_ACHIEVEMENT_TRACKER", row)
            if _G.ShowAchievementFrameForAchievement then
                rootDescription:CreateButton(
                    _G.OBJECTIVES_VIEW_ACHIEVEMENT or "View achievement",
                    function()
                        ShowAchievementFrameForAchievement(entry.trackingID)
                    end
                )
            end
            rootDescription:CreateButton(_G.OBJECTIVES_STOP_TRACKING or "Stop tracking", function()
                StopContentTracking(state, {
                    trackingType = Enum.ContentTrackingType.Achievement,
                    trackingID = entry.trackingID,
                })
            end)
        elseif entry.kind == "profession" then
            rootDescription:SetTag("MENU_PROFESSIONS_RECIPE_TRACKER")
            if not entry.isRecraft then
                rootDescription:CreateButton(
                    _G.PROFESSIONS_TRACKING_VIEW_RECIPE or "View recipe",
                    function()
                        OpenProfessionEntry(entry)
                    end
                )
            end
            rootDescription:CreateButton(
                _G.PROFESSIONS_UNTRACK_RECIPE or _G.OBJECTIVES_STOP_TRACKING or "Stop tracking",
                function()
                    C_TradeSkillUI.SetRecipeTracked(entry.recipeID, false, entry.isRecraft)
                    RefreshAfterQuestAction(state)
                end
            )
        elseif entry.kind == "monthly" then
            rootDescription:SetTag("MENU_MONTHLY_ACTVITIES_TRACKER")
            rootDescription:CreateButton(
                _G.OBJECTIVES_VIEW_IN_TRAVELERS_LOG or "View in Traveler's Log",
                function()
                    if not _G.EncounterJournal and _G.EncounterJournal_LoadUI then
                        EncounterJournal_LoadUI()
                    end
                    if _G.MonthlyActivitiesFrame_OpenFrameToActivity then
                        MonthlyActivitiesFrame_OpenFrameToActivity(entry.trackingID)
                    end
                end
            )
            rootDescription:CreateButton(_G.OBJECTIVES_STOP_TRACKING or "Stop tracking", function()
                C_PerksActivities.RemoveTrackedPerksActivity(entry.trackingID)
                RefreshAfterQuestAction(state)
            end)
        elseif entry.kind == "initiative" then
            rootDescription:SetTag("MENU_MONTHLY_ACTVITIES_TRACKER")
            rootDescription:CreateButton(
                _G.OBJECTIVES_VIEW_IN_ENDEAVORS_TAB or "View in Endeavors",
                function()
                    if HousingFramesUtil and HousingFramesUtil.OpenFrameToTaskID then
                        HousingFramesUtil.OpenFrameToTaskID(entry.trackingID)
                    end
                end
            )
            rootDescription:CreateButton(_G.OBJECTIVES_STOP_TRACKING or "Stop tracking", function()
                C_NeighborhoodInitiative.RemoveTrackedInitiativeTask(entry.trackingID)
                RefreshAfterQuestAction(state)
            end)
        elseif entry.kind == "content" then
            rootDescription:SetTag("MENU_OBJECTIVE_TRACKER", row)
            if Enum
                and Enum.ContentTrackingType
                and entry.trackingType == Enum.ContentTrackingType.Appearance
                and TransmogUtil
                and TransmogUtil.OpenCollectionToItem
            then
                rootDescription:CreateButton(
                    _G.CONTENT_TRACKING_OPEN_JOURNAL_OPTION or "Open collection",
                    function()
                        TransmogUtil.OpenCollectionToItem(entry.trackingID)
                    end
                )
            end
            rootDescription:CreateButton(_G.OBJECTIVES_STOP_TRACKING or "Stop tracking", function()
                StopContentTracking(state, entry)
            end)
        end
    end)
end

local function TryInsertTrackingLink(entry)
    if not entry or not entry.kind or not IsModifiedClick("CHATLINK") then
        return false
    end
    if not ChatFrameUtil or not ChatFrameUtil.InsertLink then
        return false
    end

    local link
    if entry.kind == "achievement" and _G.GetAchievementLink then
        link = GetAchievementLink(entry.trackingID)
    elseif entry.kind == "profession" and C_TradeSkillUI and C_TradeSkillUI.GetRecipeLink then
        link = C_TradeSkillUI.GetRecipeLink(entry.recipeID)
    elseif entry.kind == "monthly" and C_PerksActivities and C_PerksActivities.GetPerksActivityChatLink then
        link = C_PerksActivities.GetPerksActivityChatLink(entry.trackingID)
    elseif entry.kind == "initiative"
        and C_NeighborhoodInitiative
        and C_NeighborhoodInitiative.GetInitiativeTaskChatLink
    then
        link = C_NeighborhoodInitiative.GetInitiativeTaskChatLink(entry.trackingID)
    elseif entry.kind == "content"
        and ContentTrackingUtil
        and ContentTrackingUtil.ProcessChatLink
    then
        return ContentTrackingUtil.ProcessChatLink(entry.trackingType, entry.trackingID)
    end

    if link and not IsSecret(link) then
        ChatFrameUtil.InsertLink(link)
        return true
    end
    return false
end

local function HandleTrackingEntryLeftClick(state, entry)
    if entry.kind == "achievement" and _G.ShowAchievementFrameForAchievement then
        ShowAchievementFrameForAchievement(entry.trackingID)
    elseif entry.kind == "profession" then
        OpenProfessionEntry(entry)
    elseif entry.kind == "monthly" then
        if not _G.EncounterJournal and _G.EncounterJournal_LoadUI then
            EncounterJournal_LoadUI()
        end
        if _G.MonthlyActivitiesFrame_OpenFrameToActivity then
            MonthlyActivitiesFrame_OpenFrameToActivity(entry.trackingID)
        end
    elseif entry.kind == "initiative" then
        if HousingFramesUtil and HousingFramesUtil.OpenFrameToTaskID then
            HousingFramesUtil.OpenFrameToTaskID(entry.trackingID)
        end
    elseif entry.kind == "content" then
        if Enum
            and Enum.ContentTrackingTargetType
            and entry.targetType == Enum.ContentTrackingTargetType.Achievement
            and _G.ShowAchievementFrameForAchievement
        then
            ShowAchievementFrameForAchievement(entry.targetID)
        elseif Enum
            and Enum.ContentTrackingTargetType
            and entry.targetType == Enum.ContentTrackingTargetType.Profession
            and ProfessionsUtil
            and ProfessionsUtil.OpenProfessionFrameToRecipe
        then
            ProfessionsUtil.OpenProfessionFrameToRecipe(entry.targetID)
        elseif ContentTrackingUtil and ContentTrackingUtil.OpenMapToTrackable then
            ContentTrackingUtil.OpenMapToTrackable(entry.trackingType, entry.trackingID)
        end
    end
end

local function AddWowheadMenuItem(state, rootDescription, questID)
    rootDescription:CreateDivider()
    rootDescription:CreateButton(state.addon.text.wowheadUrl, function()
        state.addon:ShowCopyTextWindow(
            state.addon.text.wowheadCopyTitle,
            state.addon.text.wowheadCopyHint,
            GetWowheadQuestURL(questID)
        )
    end)
end

local function ShowQuestContextMenu(state, row)
    if row.entry and row.entry.kind then
        ShowTrackingEntryContextMenu(state, row, row.entry)
        return
    end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end

    local questID = row.questID
    local category = row.category
    local questTitle = row.questTitle or ("Quest %d"):format(questID)
    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        if category == "WorldQuestObjectiveTracker" or category == "BonusObjectiveTracker" then
            rootDescription:SetTag("MENU_BONUS_OBJECTIVE_TRACKER", row)
            rootDescription:CreateTitle(questTitle)
            if IsWorldQuestWatched(questID) then
                rootDescription:CreateButton(_G.OBJECTIVES_STOP_TRACKING or "Stop tracking", function()
                    UntrackWorldQuest(state, questID)
                end)
            end
            AddWowheadMenuItem(state, rootDescription, questID)
            return
        end

        rootDescription:SetTag("MENU_QUEST_OBJECTIVE_TRACKER")
        rootDescription:CreateTitle(questTitle)

        local superTrackedQuestID
        if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
            superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
            if IsSecret(superTrackedQuestID) then
                superTrackedQuestID = nil
            end
        end
        if superTrackedQuestID ~= questID then
            rootDescription:CreateButton(_G.SUPER_TRACK_QUEST or "Focus quest", function()
                C_SuperTrack.SetSuperTrackedQuestID(questID)
                state.addon:RequestCustomRefresh(false)
            end)
        else
            rootDescription:CreateButton(_G.STOP_SUPER_TRACK_QUEST or "Stop focusing quest", function()
                C_SuperTrack.SetSuperTrackedQuestID(0)
                state.addon:RequestCustomRefresh(false)
            end)
        end

        if QuestUtil and QuestUtil.OpenQuestDetails then
            local showingDetails = QuestUtil.IsShowingQuestDetails
                and QuestUtil.IsShowingQuestDetails(questID)
            local detailsLabel = showingDetails
                    and _G.OBJECTIVES_HIDE_VIEW_IN_QUESTLOG
                or _G.OBJECTIVES_VIEW_IN_QUESTLOG
                or "View quest details"
            rootDescription:CreateButton(detailsLabel, function()
                QuestUtil.OpenQuestDetails(questID)
            end)
        end

        if QuestMapFrame_OpenToQuestDetails then
            rootDescription:CreateButton(_G.OBJECTIVES_SHOW_QUEST_MAP or "Show on map", function()
                QuestMapFrame_OpenToQuestDetails(questID)
            end)
        end

        if row.canUntrack then
            rootDescription:CreateButton(_G.OBJECTIVES_STOP_TRACKING or "Stop tracking", function()
                C_QuestLog.RemoveQuestWatch(questID)
                RefreshAfterQuestAction(state)
            end)
        end

        local isPushable = false
        if C_QuestLog and C_QuestLog.IsPushableQuest then
            local ok, value = pcall(C_QuestLog.IsPushableQuest, questID)
            isPushable = ok and not IsSecret(value) and value and true or false
        end
        if isPushable and IsInGroup() and QuestUtil and QuestUtil.ShareQuest then
            rootDescription:CreateButton(_G.SHARE_QUEST or "Share quest", function()
                QuestUtil.ShareQuest(questID)
            end)
        end

        if QuestMapQuestOptions_AbandonQuest then
            rootDescription:CreateButton(_G.ABANDON_QUEST_ABBREV or "Abandon quest", function()
                QuestMapQuestOptions_AbandonQuest(questID)
            end)
        end

        AddWowheadMenuItem(state, rootDescription, questID)
    end)
end

local function CreateRow(state)
    local row = CreateFrame("Button", nil, state.content)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.07)
    row.highlight:Hide()

    row.categoryBG = row:CreateTexture(nil, "BACKGROUND")
    row.categoryBG:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", true)
    row.categoryBG:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(10, 10)

    row.poiButton = CreateFrame("Button", nil, row, "ObjectiveTrackerPOIButtonTemplate")
    row.poiButton:Hide()

    row.itemButton = CreateFrame("Button", nil, row, "QuestObjectiveItemButtonTemplate")
    row.itemButton:Hide()

    row.findGroupButton = CreateFrame("Button", nil, row, "QuestObjectiveFindGroupButtonTemplate")
    row.findGroupButton:Hide()

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    row.text:SetNonSpaceWrap(true)
    row.text:SetIndentedWordWrap(false)
    row.text:SetMaxLines(0)

    row.cardBG = row:CreateTexture(nil, "BACKGROUND")
    row.cardBG:SetAtlas("ScenarioTrackerToast", true)
    row.cardBG:Hide()

    row.cardStage = row:CreateFontString(nil, "ARTWORK", "Game18Font")
    row.cardStage:SetTextColor(1, 0.914, 0.682)
    row.cardStage:SetJustifyH("LEFT")
    row.cardStage:Hide()

    row.cardName = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.cardName:SetTextColor(1, 0.831, 0.380)
    row.cardName:SetJustifyH("LEFT")
    row.cardName:SetJustifyV("TOP")
    row.cardName:SetWordWrap(true)
    row.cardName:Hide()

    row.progress = CreateFrame("StatusBar", nil, row, "BackdropTemplate")
    row.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.progress:SetStatusBarColor(0.26, 0.42, 1)
    row.progress:SetMinMaxValues(0, 100)
    row.progress:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    row.progress:SetBackdropColor(0.04, 0.07, 0.18, 0.95)
    row.progress:SetBackdropBorderColor(0.50, 0.55, 0.65, 0.9)
    row.progress.label = row.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.progress.label:SetPoint("CENTER", 0, 0)
    row.progress:Hide()

    row.timer = CreateFrame("Frame", nil, row)
    row.timer.label = row.timer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.timer.label:SetPoint("LEFT", 0, 0)
    row.timer.bar = CreateFrame("StatusBar", nil, row.timer, "BackdropTemplate")
    row.timer.bar:SetPoint("LEFT", row.timer.label, "RIGHT", 6, 0)
    row.timer.bar:SetPoint("RIGHT", row.timer, "RIGHT", -4, 0)
    row.timer.bar:SetHeight(10)
    row.timer.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.timer.bar:SetStatusBarColor(0.26, 0.42, 1)
    row.timer.bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    row.timer.bar:SetBackdropColor(0.04, 0.07, 0.18, 0.95)
    row.timer:SetScript("OnUpdate", function(self)
        local duration = self.duration
        local startTime = self.startTime
        if not duration or not startTime then
            return
        end
        local remaining = math.max(0, duration - (GetTime() - startTime))
        self.bar:SetValue(remaining)
        self.label:SetText(SecondsToClock(remaining))
        local percentageLeft = duration > 0 and (remaining / duration) or 0
        if percentageLeft > 0.66 then
            self.label:SetTextColor(1, 1, 1)
        elseif percentageLeft > 0.33 then
            local blue = (percentageLeft - 0.33) / 0.33
            self.label:SetTextColor(1, 1, blue)
        else
            self.label:SetTextColor(1, percentageLeft / 0.33, 0)
        end
        if remaining <= 0 and not self.expired then
            self.expired = true
            state.addon:RequestCustomRefresh(true)
        end
    end)
    row.timer:Hide()

    row:SetScript("OnEnter", function(self)
        if self.questID or (self.entry and self.entry.kind) then
            self.highlight:Show()
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.questTitle or "", 1, 0.82, 0)
            GameTooltip:AddLine(
                self.entry and self.entry.kind
                    and state.addon.text.trackingClickHint
                    or state.addon.text.questClickHint,
                1,
                1,
                1,
                true
            )
            GameTooltip:AddLine(state.addon.text.questUntrackHint, 0.8, 0.8, 0.8, true)
            if self.questID and IsInGroup() and GameTooltip.SetQuestPartyProgress then
                GameTooltip:SetQuestPartyProgress(self.questID)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, button)
        local questID = self.questID
        local entry = self.entry
        if not questID and not (entry and entry.kind) then
            return
        end

        if entry and TryInsertTrackingLink(entry) then
            return
        end


        if entry and entry.kind == "content"
            and IsModifiedClick("DRESSUP")
            and Enum
            and Enum.ContentTrackingType
            and entry.trackingType == Enum.ContentTrackingType.Appearance
            and DressUpVisual
        then
            DressUpVisual(entry.trackingID)
            return
        end

        if questID
            and IsModifiedClick("CHATLINK")
            and ChatFrameUtil
            and ChatFrameUtil.TryInsertQuestLinkForQuestID
        then
            if ChatFrameUtil.TryInsertQuestLinkForQuestID(questID) then
                return
            end
        end

        if button == "RightButton" then
            ShowQuestContextMenu(state, self)
            return
        end

        if entry and entry.kind then
            HandleTrackingEntryLeftClick(state, entry)
            return
        end


        if entry and entry.isAutoQuestPopup then
            if entry.popupType == "OFFER" and ShowQuestOffer then
                ShowQuestOffer(questID)
            elseif ShowQuestComplete then
                ShowQuestComplete(questID)
            end
            if RemoveAutoQuestPopUp then
                RemoveAutoQuestPopUp(questID)
            end
            state.addon:RequestCustomRefresh(true)
            return
        end

        if entry and entry.isAutoComplete and entry.readyForTurnIn and ShowQuestComplete then
            ShowQuestComplete(questID)
            return
        end

        if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            C_SuperTrack.SetSuperTrackedQuestID(questID)
            state.addon:RequestCustomRefresh(false)
        end
    end)
    return row
end

local function AcquireRow(state)
    state.usedRows = state.usedRows + 1
    local row = state.rows[state.usedRows]
    if not row then
        row = CreateRow(state)
        state.rows[state.usedRows] = row
    end

    row:ClearAllPoints()
    row.text:ClearAllPoints()
    row.icon:ClearAllPoints()
    row.poiButton:Hide()
    row.poiButton:ClearAllPoints()
    if row.poiButton.Reset then
        row.poiButton:Reset()
    end
    row.itemButton:Hide()
    row.itemButton:ClearAllPoints()
    row.findGroupButton:Hide()
    row.findGroupButton:ClearAllPoints()
    row.categoryBG:ClearAllPoints()
    row.cardBG:ClearAllPoints()
    row.cardStage:ClearAllPoints()
    row.cardName:ClearAllPoints()
    row.progress:ClearAllPoints()
    row.timer:ClearAllPoints()
    row.icon:Hide()
    row.categoryBG:Hide()
    row.cardBG:Hide()
    row.cardStage:Hide()
    row.cardName:Hide()
    row.progress:Hide()
    row.timer:Hide()
    row.timer.duration = nil
    row.timer.startTime = nil
    row.timer.expired = nil
    row.text:Show()
    row.highlight:Hide()
    row.questID = nil
    row.entry = nil
    row.questTitle = nil
    row.category = nil
    row.canUntrack = false
    row:SetWidth(math.max(state.content:GetWidth(), 1))
    row:Show()
    return row
end

local function PlaceRow(state, row, height)
    row:SetPoint("TOPLEFT", state.content, "TOPLEFT", 0, -state.contentHeight)
    row:SetPoint("TOPRIGHT", state.content, "TOPRIGHT", 0, -state.contentHeight)
    row:SetHeight(height)
    state.contentHeight = state.contentHeight + height
end

local function AddVerticalSpacing(state, spacing)
    spacing = GetSafeNumber(spacing, 0)
    if spacing > 0 then
        state.contentHeight = state.contentHeight + spacing
    end
end

local function AddCategoryRow(state, category, label)
    local row = AcquireRow(state)
    row:EnableMouse(false)
    ApplySelectedFont(state.addon, row.text, "ObjectiveTrackerHeaderFont")
    row.text:SetMaxLines(1)
    row.text:SetHeight(CATEGORY_HEIGHT)
    row.text:SetText(label or state.addon:GetModuleLabel(category))
    row.text:SetTextColor(1, 0.82, 0)
    local textOffset = GetSafeNumber(state.addon.db.categoryTextOffset, 0)
    if state.addon.db.categoryStyle == "blizzard" then
        local textureOffset = GetSafeNumber(state.addon.db.categoryOffset, 0)
        row.categoryBG:SetPoint("CENTER", row, "CENTER", 0, textureOffset)
        row.categoryBG:Show()
        row.text:SetPoint("LEFT", row.categoryBG, "LEFT", 7 + textOffset, -textureOffset)
        row.text:SetPoint("RIGHT", row.categoryBG, "RIGHT", -28 + textOffset, -textureOffset)
    else
        row.text:SetPoint("LEFT", row, "LEFT", 5 + textOffset, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -5 + textOffset, 0)
    end
    PlaceRow(state, row, CATEGORY_HEIGHT)
end

local function LayoutScenarioWidgets(widgetContainer, widgets)
    local width = 1
    local height = 0
    local spacing = GetSafeNumber(widgetContainer.verticalAnchorYOffset, 0)

    if widgetContainer.horizontalRowContainerPool then
        widgetContainer.horizontalRowContainerPool:ReleaseAll()
    end

    for index, widget in ipairs(widgets) do
        local tierFrame = widget.TierFrame
        local tierFlag = tierFrame and tierFrame.Flag
        if tierFlag then
            local tierWidth = GetSafeNumber(tierFlag:GetWidth(), 1)
            local tierHeight = GetSafeNumber(tierFlag:GetHeight(), 1)
            tierFrame:SetSize(math.max(tierWidth, 1), math.max(tierHeight, 1))
            if tierFrame.MarkClean then
                tierFrame:MarkClean()
            end
        end

        widget:ClearAllPoints()
        widget:SetParent(widgetContainer)
        widget:SetPoint("TOPLEFT", widgetContainer, "TOPLEFT", 0, -height)
        widget:SetFrameLevel(widgetContainer:GetFrameLevel() + index)

        width = math.max(width, GetSafeNumber(widget:GetWidth(), 1))
        height = height + GetSafeNumber(widget:GetHeight(), 1)
        if index < #widgets then
            height = height + spacing
        end
    end

    widgetContainer:SetSize(width, math.max(height, 1))
    if widgetContainer.MarkClean then
        widgetContainer:MarkClean()
    end
end

local function LayoutObjectiveWidgets(widgetContainer, widgets)
    DefaultWidgetLayout(widgetContainer, widgets)
    local state = widgetContainer.bqlState
    if state then
        C_Timer.After(0, function()
            if state.addon and state.addon.RequestCustomRefresh then
                state.addon:RequestCustomRefresh(true)
            end
        end)
    end
end

local function AddScenarioCard(state, scenario)
    local row = AcquireRow(state)
    row:EnableMouse(false)
    row.text:Hide()

    if scenario.widgetSetID and state.scenarioWidgetContainer then
        local widgetContainer = state.scenarioWidgetContainer
        widgetContainer:ClearAllPoints()
        widgetContainer:SetPoint("TOP", row, "TOP", 0, 0)
        widgetContainer:RegisterForWidgetSet(scenario.widgetSetID, LayoutScenarioWidgets)
        widgetContainer:Show()
        widgetContainer:UpdateWidgetLayout()
        state.scenarioWidgetUsed = true
        state.scenarioWidgetRow = row

        local widgetHeight = GetSafeNumber(widgetContainer:GetHeight(), 83)
        PlaceRow(state, row, math.max(widgetHeight, 83))
        return
    end

    row.cardBG:SetPoint("TOP", row, "TOP", 0, 0)
    row.cardBG:Show()
    row.cardStage:SetPoint("TOPLEFT", row.cardBG, "TOPLEFT", 15, -10)
    row.cardStage:SetPoint("RIGHT", row.cardBG, "RIGHT", -14, 0)
    row.cardStage:SetText(scenario.stageText or "")
    ApplySelectedFont(state.addon, row.cardStage, "Game18Font")
    row.cardStage:Show()
    row.cardName:SetPoint("TOPLEFT", row.cardStage, "BOTTOMLEFT", 0, -4)
    row.cardName:SetPoint("RIGHT", row.cardBG, "RIGHT", -14, 0)
    row.cardName:SetText(scenario.stageName or scenario.title)
    ApplySelectedFont(state.addon, row.cardName, "GameFontNormal")
    row.cardName:Show()
    PlaceRow(state, row, 83)
end

local function GetNativeScenarioModule(state)
    local module = state.nativeScenarioModule or _G.ScenarioObjectiveTracker
    if not module then
        return nil
    end

    if not state.nativeScenarioModule then
        state.nativeScenarioModule = module
        local ok, parent = pcall(module.GetParent, module)
        if ok then
            state.nativeScenarioOriginalParent = parent
        end
    end
    return module
end

local function IsNativeScenarioProtected(module)
    if not module or type(module.IsProtected) ~= "function" then
        return false
    end

    local ok, protected = pcall(module.IsProtected, module)
    return ok and not IsSecret(protected) and protected and true or false
end

local function CanMoveNativeScenario(module)
    return module
        and not (IsNativeScenarioProtected(module) and InCombatLockdown())
end

local function HasNativeScenarioContents(state)
    local module = GetNativeScenarioModule(state)
    if not module then
        return false
    end

    if type(module.IsDisplayable) == "function" then
        local ok, displayable = pcall(module.IsDisplayable, module)
        if ok and not IsSecret(displayable) and not displayable then
            return false
        end
    end

    if type(module.HasContents) == "function" then
        local ok, hasContents = pcall(module.HasContents, module)
        if ok and not IsSecret(hasContents) then
            return hasContents and true or false
        end
    end

    local okShown, shown = pcall(module.IsShown, module)
    local okHeight, height = pcall(module.GetHeight, module)
    return okShown
        and shown
        and not IsSecret(shown)
        and okHeight
        and GetSafeNumber(height, 0) > 1
end

local function RequestNativeScenarioStageWidgetLayout(state)
    if state.nativeScenarioStageLayoutScheduled then
        return
    end

    local module = GetNativeScenarioModule(state)
    local stageBlock = module and module.StageBlock
    local widgetContainer = stageBlock and stageBlock.WidgetContainer
    if not widgetContainer
        or not widgetContainer.widgetSetID
        or type(widgetContainer.UpdateWidgetLayout) ~= "function"
    then
        return
    end

    state.nativeScenarioStageLayoutScheduled = true
    C_Timer.After(0, function()
        state.nativeScenarioStageLayoutScheduled = false
        if not state.nativeScenarioAttached
            or state.nativeScenarioModule ~= module
            or state.nativeScenarioRow == nil
            or module:GetParent() ~= state.nativeScenarioRow
            or stageBlock.WidgetContainer ~= widgetContainer
        then
            return
        end

        -- Scenario step widget sets use a right-anchored ResizeLayoutFrame.
        -- On first registration it can retain its initial 1 px width when the
        -- whole native module is reparented later in the same frame. Re-running
        -- only the widget container layout after the move resolves its extents;
        -- unlike ScenarioObjectiveTracker:Update(), this does not read auras or
        -- other protected scenario data.
        pcall(widgetContainer.UpdateWidgetLayout, widgetContainer)
    end)
end

local function AnchorNativeScenarioModule(state, row)
    local module = GetNativeScenarioModule(state)
    if not row or not CanMoveNativeScenario(module) then
        return false
    end

    local leftMargin = GetSafeNumber(module.leftMargin, -20)
    local ok = pcall(function()
        module:SetParent(row)
        module:ClearAllPoints()
        module:SetPoint("TOPLEFT", row, "TOPLEFT", FRAME_LEFT_OVERFLOW + leftMargin, 0)
        module:SetFrameLevel(row:GetFrameLevel() + 1)
        module:Show()
    end)
    if not ok then
        return false
    end

    state.nativeScenarioAttached = true
    state.nativeScenarioRow = row
    RequestNativeScenarioStageWidgetLayout(state)
    return true
end

local function RestoreNativeScenarioModule(state)
    if not state.nativeScenarioAttached then
        return true
    end

    local module = GetNativeScenarioModule(state)
    if not CanMoveNativeScenario(module) then
        return false
    end

    local parent = state.nativeScenarioOriginalParent or state.blizzardTracker
    local ok = pcall(function()
        module:SetParent(parent)
        module:ClearAllPoints()
    end)
    if not ok then
        return false
    end

    state.nativeScenarioAttached = false
    state.nativeScenarioRow = nil
    return true
end

local function AddNativeScenarioRow(state)
    local module = GetNativeScenarioModule(state)
    local row = AcquireRow(state)
    row:EnableMouse(false)
    row.text:Hide()

    if not AnchorNativeScenarioModule(state, row) then
        row:Hide()
        state.usedRows = state.usedRows - 1
        return false
    end

    local moduleHeight = GetSafeNumber(module:GetHeight(), 1)
    PlaceRow(state, row, math.max(moduleHeight, 1))
    state.nativeScenarioUsed = true
    return true
end

local function AddObjectiveWidgetRow(state)
    local row = AcquireRow(state)
    row:EnableMouse(false)
    row.text:Hide()

    local widgetContainer = state.objectiveWidgetContainer
    widgetContainer:SetParent(row)
    widgetContainer:ClearAllPoints()
    widgetContainer:SetPoint("TOP", row, "TOP", 0, 0)
    widgetContainer:SetWidth(math.max(GetSafeNumber(row:GetWidth(), 200), 1))
    widgetContainer:SetAlpha(1)
    widgetContainer:Show()
    state.objectiveWidgetUsed = true

    local widgetHeight = GetSafeNumber(widgetContainer:GetHeight(), 1)
    PlaceRow(state, row, math.max(widgetHeight, 1))
end

local function AddQuestTitleRow(state, quest)
    local row = AcquireRow(state)
    local isInteractive = quest.questID ~= nil or quest.kind ~= nil
    row:EnableMouse(isInteractive and not state.editModeActive)
    ApplySelectedFont(state.addon, row.text, "ObjectiveTrackerLineFont")
    if quest.isFailed then
        row.text:SetTextColor(1, 0.25, 0.25)
    elseif quest.readyForTurnIn then
        row.text:SetTextColor(0.3, 1, 0.3)
    else
        row.text:SetTextColor(1, 1, 1)
    end
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", QUEST_TEXT_LEFT, -2)
    local rightInset = 5
    if quest.showsItem and quest.questLogIndex and row.itemButton.SetUp then
        row.itemButton:SetUp(quest.questLogIndex)
        row.itemButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, 2)
        row.itemButton:EnableMouse(not state.editModeActive)
        row.itemButton:Show()
        rightInset = rightInset + 32
    end
    if quest.canCreateGroup and row.findGroupButton.SetUp then
        row.findGroupButton:SetUp(quest.questID)
        row.findGroupButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -rightInset, 4)
        row.findGroupButton:EnableMouse(not state.editModeActive)
        row.findGroupButton:Show()
        rightInset = rightInset + 32
    end
    row.text:SetWidth(math.max(GetSafeNumber(row:GetWidth(), 200) - QUEST_TEXT_LEFT - rightInset, 1))
    row.text:SetMaxLines(0)
    row.text:SetHeight(0)
    row.text:SetText(quest.title)

    row.questID = quest.questID
    row.entry = quest
    row.questTitle = quest.title
    row.category = quest.category
    row.canUntrack = quest.questID ~= nil and CanUntrackCategory(quest.category)

    if quest.kind == "content"
        and quest.trackingType
        and quest.trackingID
        and POIButtonUtil
        and POIButtonUtil.Style
        and row.poiButton.SetTrackable
    then
        row.poiButton:SetTrackable(quest.trackingType, quest.trackingID)
        row.poiButton:SetStyle(POIButtonUtil.Style.ContentTracking)
        if row.poiButton.UpdateSelected then
            row.poiButton:UpdateSelected()
        end
        row.poiButton:UpdateButtonStyle()
        row.poiButton:SetPoint("TOPRIGHT", row.text, "TOPLEFT", -7, 5)
        row.poiButton:EnableMouse(not state.editModeActive)
        row.poiButton:Show()
    end

    local showQuestPOI = quest.category == "WorldQuestObjectiveTracker"
        or quest.category == "BonusObjectiveTracker"
        or type(GetCVarBool) ~= "function"
        or GetCVarBool("questPOI")
    if quest.questID and showQuestPOI and C_QuestLog and C_QuestLog.IsQuestCalling then
        local ok, calling = pcall(C_QuestLog.IsQuestCalling, quest.questID)
        if ok and not IsSecret(calling) and calling then
            showQuestPOI = false
        end
    end
    if quest.questID and showQuestPOI and POIButtonUtil and POIButtonUtil.Style then
        local style
        if quest.category == "WorldQuestObjectiveTracker" then
            style = POIButtonUtil.Style.WorldQuest
        elseif quest.category == "BonusObjectiveTracker" then
            style = POIButtonUtil.Style.BonusObjective
        elseif quest.readyForTurnIn then
            style = POIButtonUtil.Style.QuestComplete
        else
            style = POIButtonUtil.Style.QuestInProgress
        end

        local superTrackedQuestID
        if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
            superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
            if IsSecret(superTrackedQuestID) then
                superTrackedQuestID = nil
            end
        end

        row.poiButton:SetQuestID(quest.questID)
        row.poiButton:SetStyle(style)
        row.poiButton:SetSelected(superTrackedQuestID == quest.questID)
        row.poiButton:SetPingWorldMap(quest.category == "WorldQuestObjectiveTracker")
        row.poiButton:UpdateButtonStyle()
        row.poiButton:SetPoint("TOPRIGHT", row.text, "TOPLEFT", -7, 5)
        row.poiButton:EnableMouse(not state.editModeActive)
        row.poiButton:Show()
    end

    local textHeight = GetSafeNumber(row.text:GetHeight(), MIN_ROW_HEIGHT)
    PlaceRow(state, row, math.max(MIN_ROW_HEIGHT + 2, textHeight + 6))
end


local function AddTimerRow(state, quest, duration, startTime)
    if type(duration) ~= "number" or type(startTime) ~= "number" then
        return
    end
    local row = AcquireRow(state)
    row:EnableMouse(false)
    row.text:Hide()
    ApplySelectedFont(state.addon, row.timer.label, "ObjectiveTrackerLineFont")
    row.timer:SetPoint("TOPLEFT", row, "TOPLEFT", OBJECTIVE_TEXT_LEFT, -2)
    row.timer:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row.timer:SetHeight(18)
    row.timer.duration = duration
    row.timer.startTime = startTime
    row.timer.bar:SetMinMaxValues(0, duration)
    row.timer:Show()
    row.questID = quest and quest.questID or nil
    PlaceRow(state, row, 20)
end

local function AddObjectiveRow(state, quest, objective)
    local row = AcquireRow(state)
    local isInteractive = quest.questID ~= nil or quest.kind ~= nil
    row:EnableMouse(isInteractive and not state.editModeActive)
    ApplySelectedFont(state.addon, row.text, "ObjectiveTrackerLineFont")
    if objective.failed then
        row.text:SetTextColor(1, 0.25, 0.25)
        row.icon:SetAtlas("ui-questtracker-objective-nub", false)
    elseif objective.finished then
        row.text:SetTextColor(0.4, 0.9, 0.4)
        row.icon:SetAtlas("ui-questtracker-tracker-check", false)
    else
        row.text:SetTextColor(0.78, 0.78, 0.78)
        row.icon:SetAtlas("ui-questtracker-objective-nub", false)
    end

    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", QUEST_TEXT_LEFT, -4)
    row.icon:Show()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", OBJECTIVE_TEXT_LEFT, -2)
    row.text:SetWidth(math.max(GetSafeNumber(row:GetWidth(), 200) - OBJECTIVE_TEXT_LEFT - 5, 1))
    row.text:SetMaxLines(0)
    row.text:SetHeight(0)
    row.text:SetText(objective.text)
    row.questID = quest.questID
    row.entry = quest
    row.questTitle = quest.title
    row.category = quest.category
    row.canUntrack = quest.questID ~= nil and CanUntrackCategory(quest.category)

    local textHeight = GetSafeNumber(row.text:GetHeight(), MIN_ROW_HEIGHT)
    local rowHeight = math.max(MIN_ROW_HEIGHT, textHeight + 5)
    if type(objective.progress) == "number" then
        ApplySelectedFont(state.addon, row.progress.label, "ObjectiveTrackerLineFont")
        row.progress:SetPoint("TOPLEFT", row, "TOPLEFT", OBJECTIVE_TEXT_LEFT, -(textHeight + 5))
        row.progress:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row.progress:SetHeight(15)
        row.progress:SetValue(math.max(0, math.min(objective.progress, 100)))
        if objective.progressText then
            row.progress.label:SetText(objective.progressText)
        else
            row.progress.label:SetFormattedText(PERCENTAGE_STRING, objective.progress)
        end
        row.progress:Show()
        rowHeight = rowHeight + 20
    end
    PlaceRow(state, row, rowHeight)
end

local function GetLogicalScrollRange(state)
    local viewportHeight = math.max(GetSafeNumber(state.scrollFrame:GetHeight(), 1), 1)
    return math.max(0, state.contentHeight + FRAME_BOTTOM_PADDING - viewportHeight)
end

local function UpdateScroll(state, previousScroll)
    local viewportHeight = math.max(state.scrollFrame:GetHeight(), 1)
    state.content:SetHeight(math.max(state.contentHeight + FRAME_BOTTOM_PADDING, viewportHeight))
    state.scrollFrame:UpdateScrollChildRect()
    local maximum = GetLogicalScrollRange(state)
    state.scrollFrame:SetVerticalScroll(math.max(0, math.min(previousScroll, maximum)))
end

local function DebugValue(value)
    if IsSecret(value) then
        return "<secret>"
    end
    if type(value) == "number" then
        return ("%.2f"):format(value)
    end
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function DebugRegionName(region)
    if not region then
        return "nil"
    end

    if type(region.GetDebugName) == "function" then
        local ok, name = pcall(region.GetDebugName, region)
        if ok and name and name ~= "" then
            return tostring(name)
        end
    end
    if type(region.GetName) == "function" then
        local ok, name = pcall(region.GetName, region)
        if ok and name and name ~= "" then
            return tostring(name)
        end
    end
    return tostring(region)
end

local function DescribeDebugRegion(lines, label, region)
    if not region then
        lines[#lines + 1] = label .. ": nil"
        return
    end

    local okRect, left, bottom, width, height = pcall(region.GetRect, region)
    local okScale, scale = pcall(region.GetEffectiveScale, region)
    local okShown, shown = pcall(region.IsShown, region)
    local okVisible, visible = pcall(region.IsVisible, region)
    local okParent, parent = pcall(region.GetParent, region)
    lines[#lines + 1] = ("%s: name=%s rect=[L=%s B=%s W=%s H=%s] scale=%s shown=%s visible=%s parent=%s"):format(
        label,
        DebugRegionName(region),
        okRect and DebugValue(left) or "<error>",
        okRect and DebugValue(bottom) or "<error>",
        okRect and DebugValue(width) or "<error>",
        okRect and DebugValue(height) or "<error>",
        okScale and DebugValue(scale) or "<error>",
        okShown and DebugValue(shown) or "<error>",
        okVisible and DebugValue(visible) or "<error>",
        okParent and DebugRegionName(parent) or "<error>"
    )

    local okCount, pointCount = pcall(region.GetNumPoints, region)
    if okCount and type(pointCount) == "number" then
        for pointIndex = 1, pointCount do
            local okPoint, point, relativeTo, relativePoint, offsetX, offsetY = pcall(
                region.GetPoint,
                region,
                pointIndex
            )
            if okPoint then
                lines[#lines + 1] = ("  point%d=%s -> %s.%s (%s, %s)"):format(
                    pointIndex,
                    DebugValue(point),
                    DebugRegionName(relativeTo),
                    DebugValue(relativePoint),
                    DebugValue(offsetX),
                    DebugValue(offsetY)
                )
            else
                lines[#lines + 1] = ("  point%d=<error>"):format(pointIndex)
            end
        end
    end
end

local function DescribeDebugText(lines, label, region)
    if not region or type(region.GetText) ~= "function" then
        lines[#lines + 1] = label .. " text=nil"
        return
    end

    local ok, value = pcall(region.GetText, region)
    lines[#lines + 1] = label .. " text=" .. (ok and DebugValue(value) or "<error>")
end

function BQL:CollectCustomDebugInfo()
    local lines = {
        "BetterQuestList diagnostic report",
        "version=" .. tostring(self.version),
        "locale=" .. tostring(GetLocale()),
        "time=" .. tostring(date and date("%Y-%m-%d %H:%M:%S") or GetTime()),
    }

    local state = self.customState
    if not state then
        lines[#lines + 1] = "customState=nil"
        return table.concat(lines, "\n")
    end

    local physicalWidth, physicalHeight
    if type(GetPhysicalScreenSize) == "function" then
        physicalWidth, physicalHeight = GetPhysicalScreenSize()
    end
    lines[#lines + 1] = ("screen=%sx%s uiScale=%s physical=%sx%s"):format(
        DebugValue(UIParent:GetWidth()),
        DebugValue(UIParent:GetHeight()),
        DebugValue(UIParent:GetEffectiveScale()),
        DebugValue(physicalWidth),
        DebugValue(physicalHeight)
    )
    lines[#lines + 1] = ("contentHeight=%s usedRows=%s widgetUsed=%s nativeScenarioUsed=%s"):format(
        DebugValue(state.contentHeight),
        DebugValue(state.usedRows),
        DebugValue(state.scenarioWidgetUsed),
        DebugValue(state.nativeScenarioUsed)
    )
    lines[#lines + 1] = ("appearance font=%s outline=%s shadow=%s background=%s"):format(
        DebugValue(self.db.font),
        DebugValue(self.db.fontOutline),
        DebugValue(self.db.fontShadow),
        DebugValue(self.db.background)
    )
    lines[#lines + 1] = ("scroll=%s rawRange=%s logicalRange=%s"):format(
        DebugValue(state.scrollFrame:GetVerticalScroll()),
        DebugValue(state.scrollFrame:GetVerticalScrollRange()),
        DebugValue(GetLogicalScrollRange(state))
    )
    if state.snapshot and state.snapshot.categories then
        for _, category in ipairs(self:ReconcileOrder()) do
            local entries = state.snapshot.categories[category]
            lines[#lines + 1] = ("category %s=%s"):format(
                category,
                DebugValue(entries and #entries or 0)
            )
        end
    end

    local scenario = state.snapshot
        and state.snapshot.categories
        and state.snapshot.categories.ScenarioObjectiveTracker
        and state.snapshot.categories.ScenarioObjectiveTracker[1]
    lines[#lines + 1] = ("scenario title=%s stage=%s widgetSetID=%s"):format(
        DebugValue(scenario and scenario.title),
        DebugValue(scenario and scenario.stageName),
        DebugValue(scenario and scenario.widgetSetID)
    )

    local nativeScenario = GetNativeScenarioModule(state)
    lines[#lines + 1] = ("nativeScenario available=%s hasContents=%s protected=%s attached=%s"):format(
        DebugValue(nativeScenario ~= nil),
        DebugValue(HasNativeScenarioContents(state)),
        DebugValue(IsNativeScenarioProtected(nativeScenario)),
        DebugValue(state.nativeScenarioAttached)
    )

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Tracker geometry"
    DescribeDebugRegion(lines, "UIParent", UIParent)
    DescribeDebugRegion(lines, "BlizzardTracker", state.blizzardTracker)
    DescribeDebugRegion(lines, "CustomFrame", state.frame)
    DescribeDebugRegion(lines, "ScrollFrame", state.scrollFrame)
    DescribeDebugRegion(lines, "ScrollContent", state.content)
    DescribeDebugRegion(lines, "NativeScenarioRow", state.nativeScenarioRow)
    DescribeDebugRegion(lines, "NativeScenarioModule", nativeScenario)
    DescribeDebugRegion(lines, "NativeScenarioContents", nativeScenario and nativeScenario.ContentsFrame)
    local nativeStageBlock = nativeScenario and nativeScenario.StageBlock
    local nativeStageWidgets = nativeStageBlock and nativeStageBlock.WidgetContainer
    DescribeDebugRegion(lines, "NativeScenarioStageBlock", nativeStageBlock)
    DescribeDebugRegion(lines, "NativeScenarioStageWidgets", nativeStageWidgets)
    lines[#lines + 1] = ("nativeStageWidgets widgetSetID=%s direction=%s widgetCount=%s layoutScheduled=%s"):format(
        DebugValue(nativeStageWidgets and nativeStageWidgets.widgetSetID),
        DebugValue(nativeStageWidgets and nativeStageWidgets.widgetSetLayoutDirection),
        DebugValue(nativeStageWidgets
            and nativeStageWidgets.GetNumWidgetsShowing
            and nativeStageWidgets:GetNumWidgetsShowing()),
        DebugValue(state.nativeScenarioStageLayoutScheduled)
    )
    if nativeStageWidgets and nativeStageWidgets.widgetFrames then
        for widgetID, widget in pairs(nativeStageWidgets.widgetFrames) do
            DescribeDebugRegion(lines, ("NativeStageWidget[%s]"):format(DebugValue(widgetID)), widget)
        end
    end
    DescribeDebugRegion(lines, "ScenarioRow", state.scenarioWidgetRow)
    DescribeDebugRegion(lines, "FallbackScenarioWidgetContainer", state.scenarioWidgetContainer)
    DescribeDebugRegion(lines, "ObjectiveWidgetContainer", state.objectiveWidgetContainer)

    local container = state.scenarioWidgetContainer
    lines[#lines + 1] = ("container widgetSetID=%s setDirection=%s layoutIsCustom=%s widgetCount=%s"):format(
        DebugValue(container and container.widgetSetID),
        DebugValue(container and container.widgetSetLayoutDirection),
        DebugValue(container and container.layoutFunc == LayoutScenarioWidgets),
        DebugValue(container and container.GetNumWidgetsShowing and container:GetNumWidgetsShowing())
    )

    if container and container.widgetFrames then
        local widgetIDs = {}
        for widgetID in pairs(container.widgetFrames) do
            widgetIDs[#widgetIDs + 1] = widgetID
        end
        table.sort(widgetIDs)

        for _, widgetID in ipairs(widgetIDs) do
            local widget = container.widgetFrames[widgetID]
            lines[#lines + 1] = ""
            lines[#lines + 1] = ("Widget id=%s type=%s order=%s direction=%s"):format(
                DebugValue(widgetID),
                DebugValue(widget and widget.widgetType),
                DebugValue(widget and widget.orderIndex),
                DebugValue(widget and widget.layoutDirection)
            )
            DescribeDebugRegion(lines, "Widget", widget)
            DescribeDebugRegion(lines, "Widget.Frame", widget and widget.Frame)
            DescribeDebugRegion(lines, "Widget.HeaderText", widget and widget.HeaderText)
            DescribeDebugRegion(lines, "Widget.TierFrame", widget and widget.TierFrame)
            DescribeDebugRegion(lines, "Widget.TierFrame.Flag", widget and widget.TierFrame and widget.TierFrame.Flag)
            DescribeDebugRegion(lines, "Widget.TierFrame.Text", widget and widget.TierFrame and widget.TierFrame.Text)
            DescribeDebugRegion(lines, "Widget.CurrencyContainer", widget and widget.CurrencyContainer)
            DescribeDebugRegion(lines, "Widget.SpellContainer", widget and widget.SpellContainer)
            DescribeDebugRegion(lines, "Widget.RewardFrame", widget and widget.RewardFrame)
            DescribeDebugRegion(lines, "Widget.RewardFrame.Texture", widget and widget.RewardFrame and widget.RewardFrame.Texture)

            if widget and widget.spellPool then
                local spellIndex = 0
                for spellFrame in widget.spellPool:EnumerateActive() do
                    spellIndex = spellIndex + 1
                    local okStack, stackDisplay = pcall(function()
                        return spellFrame.spellInfo and spellFrame.spellInfo.stackDisplay
                    end)
                    lines[#lines + 1] = ("SpellFrame%d stackDisplay=%s"):format(
                        spellIndex,
                        okStack and DebugValue(stackDisplay) or "<error>"
                    )
                    DescribeDebugRegion(lines, ("SpellFrame%d"):format(spellIndex), spellFrame)
                    DescribeDebugRegion(lines, ("SpellFrame%d.Icon"):format(spellIndex), spellFrame.Icon)
                    DescribeDebugRegion(lines, ("SpellFrame%d.StackCount"):format(spellIndex), spellFrame.StackCount)
                    DescribeDebugText(lines, ("SpellFrame%d.StackCount"):format(spellIndex), spellFrame.StackCount)
                    DescribeDebugRegion(lines, ("SpellFrame%d.AmountBorder"):format(spellIndex), spellFrame.AmountBorder)
                end
            end

            if widget and widget.currencyPool then
                local currencyIndex = 0
                for currencyFrame in widget.currencyPool:EnumerateActive() do
                    currencyIndex = currencyIndex + 1
                    DescribeDebugRegion(lines, ("CurrencyFrame%d"):format(currencyIndex), currencyFrame)
                    DescribeDebugRegion(lines, ("CurrencyFrame%d.Icon"):format(currencyIndex), currencyFrame.Icon)
                    DescribeDebugRegion(lines, ("CurrencyFrame%d.Text"):format(currencyIndex), currencyFrame.Text)
                    DescribeDebugText(lines, ("CurrencyFrame%d.Text"):format(currencyIndex), currencyFrame.Text)
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

function BQL:RenderCustomTracker()
    local state = self.customState
    if not state or not state.snapshot then
        return
    end

    SetTrackerGeometry(state)
    HideBlizzardTracker(state)

    -- The Blizzard scenario module keeps updating through its original
    -- ObjectiveTracker container. Detach it before recycling our host rows.
    -- If it ever becomes protected, leave the current layout untouched until
    -- combat ends instead of attempting a forbidden frame mutation.
    if not RestoreNativeScenarioModule(state) then
        return
    end

    local previousScroll = state.scrollFrame:GetVerticalScroll()
    if IsSecret(previousScroll) then
        previousScroll = 0
    end

    state.usedRows = 0
    state.contentHeight = 0
    state.scenarioWidgetUsed = false
    state.scenarioWidgetRow = nil
    state.nativeScenarioUsed = false
    state.objectiveWidgetUsed = false
    if state.objectiveWidgetContainer then
        state.objectiveWidgetContainer:SetAlpha(0)
    end
    local visibleQuestCount = 0
    local hasVisibleCategory = false

    if not self.db.collapsed then
        for _, category in ipairs(self:ReconcileOrder()) do
            local quests = state.snapshot.categories[category] or {}
            local useNativeScenario = category == "ScenarioObjectiveTracker"
                and HasNativeScenarioContents(state)
            if #quests > 0 or useNativeScenario then
                if hasVisibleCategory then
                    AddVerticalSpacing(state, self.db.categorySpacing)
                end

                if useNativeScenario and AddNativeScenarioRow(state) then
                    hasVisibleCategory = true
                    visibleQuestCount = visibleQuestCount + 1
                else
                    local firstQuest = quests[1]
                    if firstQuest then
                        local categoryLabel = (firstQuest.isScenario or firstQuest.isObjectiveWidget)
                            and firstQuest.title
                            or nil
                        AddCategoryRow(state, category, categoryLabel)
                        hasVisibleCategory = true
                        for questIndex, quest in ipairs(quests) do
                            if questIndex > 1 then
                                AddVerticalSpacing(state, self.db.questSpacing)
                            end
                            if quest.isScenario then
                                AddScenarioCard(state, quest)
                            elseif quest.isObjectiveWidget then
                                AddObjectiveWidgetRow(state)
                            else
                                AddQuestTitleRow(state, quest)
                            end
                            if #(quest.objectives or {}) > 0 then
                                AddVerticalSpacing(state, self.db.questObjectiveSpacing)
                            end
                            for _, objective in ipairs(quest.objectives or {}) do
                                AddObjectiveRow(state, quest, objective)
                                if objective.timerDuration and objective.timerStartTime then
                                    AddTimerRow(
                                        state,
                                        quest,
                                        objective.timerDuration,
                                        objective.timerStartTime
                                    )
                                end
                            end
                            AddTimerRow(state, quest, quest.timerDuration, quest.timerStartTime)
                            visibleQuestCount = visibleQuestCount + 1
                        end
                    end
                end
            end
        end
    end

    if state.scenarioWidgetContainer and not state.scenarioWidgetUsed then
        state.scenarioWidgetContainer:RegisterForWidgetSet(nil)
        state.scenarioWidgetContainer:Hide()
    end


    if state.objectiveWidgetContainer and not state.objectiveWidgetUsed then
        state.objectiveWidgetContainer:SetAlpha(0)
        state.objectiveWidgetContainer:SetParent(UIParent)
        state.objectiveWidgetContainer:ClearAllPoints()
        state.objectiveWidgetContainer:SetPoint("TOP", UIParent, "TOP", 0, 0)
    end

    for index = state.usedRows + 1, #state.rows do
        state.rows[index]:Hide()
    end

    state.countText:SetText(visibleQuestCount > 0 and tostring(visibleQuestCount) or "")
    state.collapseButton:SetText(self.db.collapsed and "+" or "-")
    state.scrollFrame:SetShown(not self.db.collapsed)
    UpdateScroll(state, previousScroll)
end

function BQL:RefreshCustomTracker(readData)
    local state = self.customState
    if not state then
        return
    end

    if readData or not state.snapshot then
        local snapshot = self:BuildCustomSnapshot(state.snapshot)
        if snapshot then
            state.snapshot = snapshot
        end
    end
    self:RenderCustomTracker()
end

function BQL:RequestCustomRefresh(readData)
    local state = self.customState
    if not state then
        return
    end

    state.refreshNeedsData = state.refreshNeedsData or readData
    if state.refreshScheduled then
        return
    end

    state.refreshScheduled = true
    C_Timer.After(state.refreshNeedsData and DATA_REFRESH_DELAY or 0, function()
        if not self.customState then
            return
        end
        local shouldReadData = self.customState.refreshNeedsData
        self.customState.refreshNeedsData = false
        self.customState.refreshScheduled = false
        self:RefreshCustomTracker(shouldReadData)
    end)
end

function BQL:SetScrollingEnabled(enabled)
    self.db.scrollEnabled = enabled and true or false
    if not self.db.scrollEnabled and self.customState then
        self.customState.scrollFrame:SetVerticalScroll(0)
    end
    return true
end

function BQL:ApplyCustomAppearance(refresh)
    local state = self.customState
    if not state then
        return
    end

    local style = BACKGROUND_STYLES[self.db.background] or BACKGROUND_STYLES.subtle
    state.frame:SetBackdropColor(unpack(style.background))
    state.frame:SetBackdropBorderColor(unpack(style.border))

    ApplySelectedFont(self, state.title, "ObjectiveTrackerHeaderFont")
    ApplySelectedFont(self, state.countText, "ObjectiveTrackerLineFont")
    for _, row in ipairs(state.rows) do
        ApplySelectedFont(self, row.cardStage, "Game18Font")
        ApplySelectedFont(self, row.cardName, "GameFontNormal")
        ApplySelectedFont(self, row.progress.label, "ObjectiveTrackerLineFont")
        ApplySelectedFont(self, row.timer.label, "ObjectiveTrackerLineFont")
    end

    if refresh ~= false then
        self:RequestCustomRefresh(false)
    end
end

function BQL:InitializeCustomTracker()
    local blizzardTracker = _G.ObjectiveTrackerFrame
    if not blizzardTracker then
        self:Print(self.text.debugUnavailable)
        return
    end

    local frame = CreateFrame("Frame", "BetterQuestListTracker", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.02, 0.02, 0.02, 0.30)
    frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.25)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)

    local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("LEFT", 8, 0)
    title:SetText(self.text.trackerTitle)

    local countText = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", title, "RIGHT", 6, 0)
    countText:SetTextColor(0.65, 0.65, 0.65)

    local collapseButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    collapseButton:SetSize(22, 20)
    collapseButton:SetPoint("RIGHT", -5, 0)

    local scrollFrame = CreateFrame("ScrollFrame", "BetterQuestListCustomScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, FRAME_BOTTOM_PADDING)
    scrollFrame:EnableMouseWheel(true)

    local content = CreateFrame("Frame", "BetterQuestListCustomScrollChild", scrollFrame)
    content:SetSize(200, 1)
    scrollFrame:SetScrollChild(content)

    local scenarioWidgetContainer = CreateFrame("Frame", nil, content, "UIWidgetContainerTemplate")
    scenarioWidgetContainer.verticalAnchorPoint = "TOPLEFT"
    scenarioWidgetContainer.verticalRelativePoint = "BOTTOMLEFT"
    scenarioWidgetContainer:Hide()

    local objectiveWidgetContainer = CreateFrame("Frame", nil, UIParent, "UIWidgetContainerTemplate")
    objectiveWidgetContainer.verticalAnchorPoint = "TOPLEFT"
    objectiveWidgetContainer.verticalRelativePoint = "BOTTOMLEFT"
    objectiveWidgetContainer:SetPoint("TOP", UIParent, "TOP", 0, 0)
    objectiveWidgetContainer:SetAlpha(0)
    objectiveWidgetContainer:Show()

    local nativeScenarioModule = _G.ScenarioObjectiveTracker
    local nativeScenarioOriginalParent
    if nativeScenarioModule then
        local ok, parent = pcall(nativeScenarioModule.GetParent, nativeScenarioModule)
        if ok then
            nativeScenarioOriginalParent = parent
        end
    end

    self.customAchievementTimers = self.customAchievementTimers or {}
    self.customState = {
        addon = self,
        blizzardTracker = blizzardTracker,
        frame = frame,
        header = header,
        title = title,
        countText = countText,
        collapseButton = collapseButton,
        scrollFrame = scrollFrame,
        content = content,
        scenarioWidgetContainer = scenarioWidgetContainer,
        objectiveWidgetContainer = objectiveWidgetContainer,
        nativeScenarioModule = nativeScenarioModule,
        nativeScenarioOriginalParent = nativeScenarioOriginalParent,
        rows = {},
        usedRows = 0,
        contentHeight = 0,
    }
    objectiveWidgetContainer.bqlState = self.customState

    if C_UIWidgetManager and C_UIWidgetManager.GetObjectiveTrackerWidgetSetID then
        local ok, widgetSetID = pcall(C_UIWidgetManager.GetObjectiveTrackerWidgetSetID)
        if ok and not IsSecret(widgetSetID) and type(widgetSetID) == "number" then
            objectiveWidgetContainer:RegisterForWidgetSet(widgetSetID, LayoutObjectiveWidgets)
        end
    end

    self:ApplyCustomAppearance(false)

    collapseButton:SetScript("OnClick", function()
        self.db.collapsed = not self.db.collapsed
        self:RenderCustomTracker()
    end)

    scrollFrame:SetScript("OnMouseWheel", function(scroll, delta)
        if not self.db.scrollEnabled or self.db.collapsed then
            return
        end

        local current = scroll:GetVerticalScroll()
        local maximum = GetLogicalScrollRange(self.customState)
        if IsSecret(current) then
            return
        end
        local target = current - (delta * self.db.scrollStep)
        scroll:SetVerticalScroll(math.max(0, math.min(target, maximum)))
    end)

    frame:HookScript("OnSizeChanged", function(_, width)
        if IsSecret(width) then
            return
        end
        content:SetWidth(math.max(width, 1))
        self:RequestCustomRefresh(false)
    end)

    scenarioWidgetContainer:HookScript("OnSizeChanged", function()
        self:RequestCustomRefresh(false)
    end)

    objectiveWidgetContainer:HookScript("OnSizeChanged", function()
        self:RequestCustomRefresh(true)
    end)

    blizzardTracker:HookScript("OnSizeChanged", function()
        SetTrackerGeometry(self.customState)
        self:RequestCustomRefresh(false)
    end)

    hooksecurefunc(blizzardTracker, "Show", function()
        HideBlizzardTracker(self.customState)
    end)

    -- ObjectiveTrackerContainerMixin captures ObjectiveTrackerFrame.Update in a
    -- dirty callback during Blizzard's OnLoad. Hooking the frame method itself
    -- therefore misses those later layouts. The base container method is the
    -- final call that assigns module anchors, so restore ours after that call.
    if ObjectiveTrackerContainerMixin
        and type(ObjectiveTrackerContainerMixin.Update) == "function"
    then
        hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", function(container)
            if container ~= blizzardTracker then
                return
            end
            local state = self.customState
            if not state then
                return
            end
            if state.nativeScenarioAttached and state.nativeScenarioRow then
                AnchorNativeScenarioModule(state, state.nativeScenarioRow)
            end
            self:RequestCustomRefresh(false)
        end)
    end

    local events = CreateFrame("Frame")
    local eventNames = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "QUEST_TURNED_IN",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_POI_UPDATE",
        "TASK_PROGRESS_UPDATE",
        "SUPER_TRACKING_CHANGED",
        "SCENARIO_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "SCENARIO_BONUS_VISIBILITY_UPDATE",
        "CRITERIA_COMPLETE",
        "ZONE_CHANGED_NEW_AREA",
        "CONTENT_TRACKING_UPDATE",
        "TRACKED_ACHIEVEMENT_UPDATE",
        "TRACKED_ACHIEVEMENT_LIST_CHANGED",
        "ACHIEVEMENT_EARNED",
        "TRANSMOG_COLLECTION_SOURCE_ADDED",
        "TRACKING_TARGET_INFO_UPDATE",
        "TRACKABLE_INFO_UPDATE",
        "HOUSE_DECOR_ADDED_TO_CHEST",
        "PERKS_ACTIVITY_COMPLETED",
        "PERKS_ACTIVITIES_TRACKED_UPDATED",
        "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED",
        "INITIATIVE_TASKS_TRACKED_UPDATED",
        "INITIATIVE_TASKS_TRACKED_LIST_CHANGED",
        "NEIGHBORHOOD_INITIATIVE_UPDATED",
        "CURRENCY_DISPLAY_UPDATE",
        "TRACKED_RECIPE_UPDATE",
        "BAG_UPDATE_DELAYED",
        "ITEM_DATA_LOAD_RESULT",
        "QUEST_AUTOCOMPLETE",
    }
    for _, eventName in ipairs(eventNames) do
        events:RegisterEvent(eventName)
    end
    events:SetScript("OnEvent", function(_, eventName, ...)
        if (eventName == "PLAYER_ENTERING_WORLD" or eventName == "ZONE_CHANGED_NEW_AREA")
            and C_NeighborhoodInitiative
            and C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo
        then
            C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
        end
        if eventName == "TRACKED_ACHIEVEMENT_UPDATE" then
            local achievementID, _, elapsed, duration = ...
            if type(achievementID) == "number"
                and type(elapsed) == "number"
                and type(duration) == "number"
                and elapsed < duration
            then
                self.customAchievementTimers[achievementID] = {
                    duration = duration,
                    startTime = GetTime() - elapsed,
                }
            end
        end
        self:RequestCustomRefresh(true)
    end)
    self.customState.events = events

    SetTrackerGeometry(self.customState)
    content:SetWidth(math.max(frame:GetWidth(), 1))
    HideBlizzardTracker(self.customState)
    if C_NeighborhoodInitiative
        and C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo
    then
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    end
    self:RequestCustomRefresh(true)
end
