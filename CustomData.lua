local _, BQL = ...

local CATEGORY_SCENARIO = "ScenarioObjectiveTracker"
local CATEGORY_WIDGETS = "UIWidgetObjectiveTracker"
local CATEGORY_CAMPAIGN = "CampaignQuestObjectiveTracker"
local CATEGORY_QUESTS = "QuestObjectiveTracker"
local CATEGORY_ADVENTURES = "AdventureObjectiveTracker"
local CATEGORY_ACHIEVEMENTS = "AchievementObjectiveTracker"
local CATEGORY_MONTHLY = "MonthlyActivitiesObjectiveTracker"
local CATEGORY_INITIATIVES = "InitiativeTasksObjectiveTracker"
local CATEGORY_PROFESSIONS = "ProfessionsRecipeTracker"
local CATEGORY_BONUS = "BonusObjectiveTracker"
local CATEGORY_WORLD = "WorldQuestObjectiveTracker"

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function IsReadableTable(value)
    if IsSecret(value) then
        return false
    end

    if canaccesstable then
        local ok, accessible = pcall(canaccesstable, value)
        if not ok or not accessible then
            return false
        end
    end

    local ok, valueType = pcall(type, value)
    return ok and valueType == "table"
end

local function ReadField(source, key)
    if not IsReadableTable(source) then
        return nil, false
    end

    local ok, value = pcall(function()
        return source[key]
    end)
    if not ok or IsSecret(value) then
        return nil, false
    end
    return value, true
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil, false
    end

    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then
        return nil, false
    end
    return value, true
end

local function SafeArrayLength(value)
    if not IsReadableTable(value) then
        return nil
    end

    local ok, length = pcall(function()
        return #value
    end)
    if not ok or IsSecret(length) then
        return nil
    end
    return length
end

local function CopyQuestArray(source)
    local result = {}
    for index, quest in ipairs(source or {}) do
        result[index] = quest
    end
    return result
end

local function IndexPreviousSnapshot(snapshot)
    local questsByID = {}
    for _, quests in pairs(snapshot and snapshot.categories or {}) do
        for _, quest in ipairs(quests) do
            if quest.questID then
                questsByID[quest.questID] = quest
            end
        end
    end
    return questsByID
end

local function FindPreviousEntry(previousCategory, kind, trackingID, extraValue)
    for _, entry in ipairs(previousCategory or {}) do
        if entry.kind == kind
            and entry.trackingID == trackingID
            and (
                extraValue == nil
                or entry.isRecraft == extraValue
                or entry.trackingType == extraValue
            )
        then
            return entry
        end
    end
    return nil
end

local function SafeMethodCall(object, methodName, ...)
    local method, methodAvailable = ReadField(object, methodName)
    if not methodAvailable or type(method) ~= "function" then
        return nil, false
    end
    return SafeCall(method, object, ...)
end

local function ReadObjectives(addon, questID, previousQuest)
    local objectiveTable, objectivesAvailable = SafeCall(C_QuestLog and C_QuestLog.GetQuestObjectives, questID)
    local objectiveCount = objectivesAvailable and SafeArrayLength(objectiveTable) or nil
    if not objectiveCount then
        return previousQuest and previousQuest.objectives or {}, true
    end

    local objectives = {}
    local restricted = false
    for index = 1, objectiveCount do
        local previousObjective = previousQuest and previousQuest.objectives and previousQuest.objectives[index]
        local objectiveInfo, infoAvailable = ReadField(objectiveTable, index)
        if not infoAvailable then
            restricted = true
            if previousObjective then
                objectives[#objectives + 1] = previousObjective
            end
        else
            local text, textAvailable = ReadField(objectiveInfo, "text")
            if not textAvailable or type(text) ~= "string" or text == "" then
                restricted = true
                text = previousObjective and previousObjective.text or nil
            end

            if type(text) == "string" and text ~= "" then
                local finished
                local finishedValue, finishedAvailable = ReadField(objectiveInfo, "finished")
                if finishedAvailable and type(finishedValue) == "boolean" then
                    finished = finishedValue
                else
                    finished = previousObjective and previousObjective.finished or false
                    restricted = true
                end

                local objectiveType, typeAvailable = ReadField(objectiveInfo, "type")
                if not typeAvailable then
                    objectiveType = previousObjective and previousObjective.type or nil
                    restricted = true
                end

                local progress = previousObjective and previousObjective.progress or nil
                local progressText = previousObjective and previousObjective.progressText or nil
                if objectiveType == "progressbar" then
                    local progressValue, progressAvailable = SafeCall(_G.GetQuestProgressBarPercent, questID)
                    if progressAvailable and type(progressValue) == "number" then
                        progress = math.max(0, math.min(progressValue, 100))
                        progressText = nil
                    else
                        restricted = true
                    end
                else
                    progress = nil
                    progressText = nil
                end

                objectives[#objectives + 1] = {
                    text = text,
                    finished = finished,
                    type = objectiveType,
                    progress = progress,
                    progressText = progressText,
                }
            end
        end
    end

    -- During combat the client may expose only a readable prefix of a secret
    -- objective array. Keep the remaining last-known rows until the API becomes
    -- readable again instead of making progress visibly disappear.
    if restricted and previousQuest and previousQuest.objectives then
        for index = objectiveCount + 1, #previousQuest.objectives do
            objectives[#objectives + 1] = previousQuest.objectives[index]
        end
    end

    local readyForTurnIn, readyAvailable = SafeCall(C_QuestLog and C_QuestLog.ReadyForTurnIn, questID)
    if readyAvailable and readyForTurnIn and #objectives == 0 then
        objectives[1] = {
            text = addon.text.questComplete,
            finished = true,
        }
    elseif not readyAvailable then
        restricted = true
    end

    if restricted and previousQuest and #objectives == 0 then
        return previousQuest.objectives or {}, true
    end
    return objectives, restricted
end

local function BuildQuest(addon, questID, category, previousQuest)
    local title, titleAvailable = SafeCall(C_QuestLog and C_QuestLog.GetTitleForQuestID, questID)
    if not titleAvailable or type(title) ~= "string" or title == "" then
        if previousQuest then
            return previousQuest, true
        end
        return nil, true
    end

    local objectives, restricted = ReadObjectives(addon, questID, previousQuest)
    local readyForTurnIn, readyAvailable = SafeCall(C_QuestLog and C_QuestLog.ReadyForTurnIn, questID)
    if not readyAvailable then
        readyForTurnIn = previousQuest and previousQuest.readyForTurnIn or false
        restricted = true
    end

    local questLogIndex, indexAvailable = SafeCall(
        C_QuestLog and C_QuestLog.GetLogIndexForQuestID,
        questID
    )
    if not indexAvailable or type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        questLogIndex = previousQuest and previousQuest.questLogIndex or nil
    end

    local isFailed, failedAvailable = SafeCall(C_QuestLog and C_QuestLog.IsFailed, questID)
    if not failedAvailable then
        isFailed = previousQuest and previousQuest.isFailed or false
    end

    local isComplete, completeAvailable = SafeCall(C_QuestLog and C_QuestLog.IsComplete, questID)
    if not completeAvailable then
        isComplete = readyForTurnIn and true or false
    end

    local questCacheEntry
    local isAutoComplete = previousQuest and previousQuest.isAutoComplete or false
    if QuestCache and type(QuestCache.Get) == "function" then
        local cacheAvailable
        questCacheEntry, cacheAvailable = SafeCall(QuestCache.Get, QuestCache, questID)
        local autoComplete, autoCompleteAvailable
        if cacheAvailable then
            autoComplete, autoCompleteAvailable = ReadField(questCacheEntry, "isAutoComplete")
        end
        if autoCompleteAvailable then
            isAutoComplete = autoComplete and true or false
        end
    end

    local canCreateGroup = false
    if QuestUtil and QuestUtil.CanCreateQuestGroup then
        local value, available = SafeCall(QuestUtil.CanCreateQuestGroup, questID)
        canCreateGroup = available and value and true or false
    end

    local showsItem = false
    if questLogIndex and QuestUtil and QuestUtil.QuestShowsItemByIndex then
        local value, available = SafeCall(
            QuestUtil.QuestShowsItemByIndex,
            questLogIndex,
            isComplete and true or false
        )
        showsItem = available and value and true or false
    end


    if isComplete then
        if isAutoComplete then
            objectives = {
                {
                    text = _G.QUEST_WATCH_QUEST_COMPLETE or addon.text.questComplete,
                    finished = true,
                },
                {
                    text = _G.QUEST_WATCH_CLICK_TO_COMPLETE or addon.text.questComplete,
                    finished = true,
                },
            }
        elseif questLogIndex and type(_G.GetQuestLogCompletionText) == "function" then
            local completionText, completionAvailable = SafeCall(
                _G.GetQuestLogCompletionText,
                questLogIndex
            )
            if completionAvailable
                and type(completionText) == "string"
                and completionText ~= ""
            then
                objectives = { { text = completionText, finished = true } }
            end
        end
    else
        local superTrackedID, superTrackedAvailable = SafeCall(
            C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        )
        if superTrackedAvailable
            and superTrackedID == questID
            and C_QuestLog
            and C_QuestLog.GetNextWaypointText
        then
            local waypoint, waypointAvailable = SafeCall(C_QuestLog.GetNextWaypointText, questID)
            if waypointAvailable and type(waypoint) == "string" and waypoint ~= "" then
                objectives[#objectives + 1] = {
                    text = (_G.WAYPOINT_OBJECTIVE_FORMAT_OPTIONAL or "%s"):format(waypoint),
                    finished = false,
                }
            end
        end

        local requiredMoney, moneyAvailable = ReadField(questCacheEntry, "requiredMoney")
        local playerMoney, playerMoneyAvailable = SafeCall(_G.GetMoney)
        if moneyAvailable
            and playerMoneyAvailable
            and type(requiredMoney) == "number"
            and type(playerMoney) == "number"
            and requiredMoney > playerMoney
            and type(_G.GetMoneyString) == "function"
        then
            objectives[#objectives + 1] = {
                text = GetMoneyString(playerMoney) .. " / " .. GetMoneyString(requiredMoney),
                finished = false,
            }
        end
    end

    local timerDuration
    local timerStartTime
    if C_QuestLog and C_QuestLog.GetTimeAllowed then
        local ok, totalTime, elapsedTime = pcall(C_QuestLog.GetTimeAllowed, questID)
        if ok
            and not IsSecret(totalTime)
            and not IsSecret(elapsedTime)
            and type(totalTime) == "number"
            and type(elapsedTime) == "number"
            and elapsedTime < totalTime
        then
            timerDuration = totalTime
            timerStartTime = GetTime() - elapsedTime
        end
    end

    return {
        questID = questID,
        category = category,
        title = title,
        objectives = objectives,
        readyForTurnIn = readyForTurnIn and true or false,
        isComplete = isComplete and true or false,
        questLogIndex = questLogIndex,
        isFailed = isFailed and true or false,
        isAutoComplete = isAutoComplete,
        canCreateGroup = canCreateGroup,
        showsItem = showsItem,
        timerDuration = timerDuration,
        timerStartTime = timerStartTime,
    }, restricted
end

local function IsWorldQuest(questID)
    local isWorldQuest, available = SafeCall(C_QuestLog and C_QuestLog.IsWorldQuest, questID)
    return available and isWorldQuest and true or false, available
end

local function IsQuestKnownCompleted(questID)
    local flaggedCompleted, flaggedAvailable = SafeCall(
        C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,
        questID
    )
    if flaggedAvailable and flaggedCompleted then
        return true
    end

    local isComplete, completeAvailable = SafeCall(C_QuestLog and C_QuestLog.IsComplete, questID)
    return completeAvailable and isComplete and true or false
end

local function ShouldDisplayTaskQuest(questID, treatAsTracked)
    if IsQuestKnownCompleted(questID) then
        return false, false
    end

    if type(_G.GetTaskInfo) ~= "function" then
        return false, true
    end

    local ok, isInArea, _, numObjectives = pcall(_G.GetTaskInfo, questID)
    if not ok or IsSecret(isInArea) or IsSecret(numObjectives) then
        return false, true
    end
    if not treatAsTracked and not isInArea then
        return false, false
    end
    if type(numObjectives) ~= "number" or numObjectives <= 0 then
        return false, false
    end

    local isComplete, completeAvailable = SafeCall(C_QuestLog and C_QuestLog.IsComplete, questID)
    if not completeAvailable then
        return false, true
    end
    if isComplete then
        return false, false
    end

    local isDisabled, disabledAvailable = SafeCall(
        C_QuestLog and C_QuestLog.IsQuestDisabledForSession,
        questID
    )
    if disabledAvailable and isDisabled then
        return false, false
    end
    return true, not disabledAvailable
end

local function GetQuestCategory(questID, fallbackCategory)
    local worldQuest, worldAvailable = IsWorldQuest(questID)
    if worldAvailable and worldQuest then
        return CATEGORY_WORLD, false
    end

    local classification, classificationAvailable = SafeCall(
        C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification,
        questID
    )
    if classificationAvailable and Enum and Enum.QuestClassification and classification == Enum.QuestClassification.Campaign then
        return CATEGORY_CAMPAIGN, false
    end

    if not worldAvailable or not classificationAvailable then
        return fallbackCategory or CATEGORY_QUESTS, true
    end
    return fallbackCategory or CATEGORY_QUESTS, false
end

local function ReadWatchList(countFunction, idFunction)
    local count, countAvailable = SafeCall(countFunction)
    if not countAvailable or type(count) ~= "number" then
        return nil
    end

    local questIDs = {}
    for index = 1, count do
        local questID, idAvailable = SafeCall(idFunction, index)
        if not idAvailable then
            return nil
        end
        if type(questID) == "number" and questID > 0 then
            questIDs[#questIDs + 1] = questID
        end
    end
    return questIDs
end

local function ReadScenario(addon, previousCategory)
    if not C_Scenario or type(C_Scenario.GetInfo) ~= "function" then
        return {}, false
    end

    local ok, scenarioName, currentStage, numStages, flags, scenarioType, textureKit,
        scenarioID = pcall(function()
        local name, stage, stages, scenarioFlags, _, _, _, _, _, returnedScenarioType,
            _, returnedTextureKit, returnedScenarioID = C_Scenario.GetInfo()
        return name, stage, stages, scenarioFlags, returnedScenarioType, returnedTextureKit,
            returnedScenarioID
    end)
    if not ok or IsSecret(scenarioName) or IsSecret(currentStage) or IsSecret(numStages) then
        return CopyQuestArray(previousCategory), true
    end
    if type(numStages) ~= "number" or numStages <= 0 then
        return {}, false
    end

    local restricted = false
    if IsSecret(flags) then
        flags = nil
        restricted = true
    end
    if IsSecret(scenarioType) then
        scenarioType = nil
        restricted = true
    end
    if IsSecret(textureKit) then
        textureKit = nil
        restricted = true
    end
    if IsSecret(scenarioID) then
        scenarioID = nil
        restricted = true
    end

    local stageName
    local stageDescription
    local numCriteria = 0
    local weightedProgress
    local widgetSetID
    if C_Scenario.GetStepInfo then
        local stepOK, returnedStageName, returnedStageDescription, returnedNumCriteria,
            returnedWeightedProgress, returnedWidgetSetID = pcall(function()
            local name, description, criteriaCount, _, _, _, _, _, _, progress, _, stepWidgetSetID =
                C_Scenario.GetStepInfo()
            return name, description, criteriaCount, progress, stepWidgetSetID
        end)
        if stepOK
            and not IsSecret(returnedStageName)
            and not IsSecret(returnedStageDescription)
            and not IsSecret(returnedNumCriteria)
            and not IsSecret(returnedWeightedProgress)
            and not IsSecret(returnedWidgetSetID)
        then
            stageName = returnedStageName
            stageDescription = returnedStageDescription
            numCriteria = type(returnedNumCriteria) == "number" and returnedNumCriteria or 0
            weightedProgress = returnedWeightedProgress
            widgetSetID = type(returnedWidgetSetID) == "number" and returnedWidgetSetID or nil
        else
            return CopyQuestArray(previousCategory), true
        end
    end

    local objectives = {}
    if type(weightedProgress) == "number" and type(stageDescription) == "string" and stageDescription ~= "" then
        objectives[1] = {
            text = stageDescription,
            finished = weightedProgress >= 100,
            type = "progressbar",
            progress = math.max(0, math.min(weightedProgress, 100)),
        }
    else
        for criteriaIndex = 1, numCriteria do
            local previousScenario = previousCategory and previousCategory[1]
            local previousObjective = previousScenario
                and previousScenario.objectives
                and previousScenario.objectives[criteriaIndex]
            local criteriaInfo, criteriaAvailable = SafeCall(
                C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo,
                criteriaIndex
            )
            if criteriaAvailable and IsReadableTable(criteriaInfo) then
                local description, descriptionAvailable = ReadField(criteriaInfo, "description")
                local completed, completedAvailable = ReadField(criteriaInfo, "completed")
                local isWeighted, weightedAvailable = ReadField(criteriaInfo, "isWeightedProgress")
                local quantity, quantityAvailable = ReadField(criteriaInfo, "quantity")
                local totalQuantity, totalQuantityAvailable = ReadField(criteriaInfo, "totalQuantity")
                if descriptionAvailable and type(description) == "string" and description ~= "" then
                    local progress
                    local progressText
                    local objectiveType
                    if weightedAvailable and isWeighted then
                        objectiveType = "progressbar"
                        if quantityAvailable and type(quantity) == "number" then
                            progress = math.max(0, math.min(quantity, 100))
                        else
                            progress = previousObjective and previousObjective.progress or nil
                            restricted = true
                        end
                    elseif quantityAvailable
                        and totalQuantityAvailable
                        and type(quantity) == "number"
                        and type(totalQuantity) == "number"
                        and totalQuantity > 1
                    then
                        progress = math.max(0, math.min((quantity / totalQuantity) * 100, 100))
                        progressText = ("%d/%d"):format(quantity, totalQuantity)
                        objectiveType = "progressbar"
                    elseif previousObjective and previousObjective.progress then
                        progress = previousObjective.progress
                        progressText = previousObjective.progressText
                        objectiveType = previousObjective.type
                        restricted = true
                    end

                    local finished = completedAvailable and completed and true or false
                    if not completedAvailable and previousObjective then
                        finished = previousObjective.finished and true or false
                        restricted = true
                    end
                    objectives[#objectives + 1] = {
                        text = description,
                        finished = finished,
                        type = objectiveType,
                        progress = progress,
                        progressText = progressText,
                    }
                else
                    restricted = true
                end
            else
                restricted = true
            end
        end
    end

    local title = stageName
    if type(title) ~= "string" or title == "" then
        title = scenarioName
    end
    if type(title) ~= "string" or title == "" then
        return CopyQuestArray(previousCategory), true
    end

    local scenarioTitle = scenarioName
    if type(scenarioTitle) ~= "string" or scenarioTitle == "" then
        scenarioTitle = addon:GetModuleLabel(CATEGORY_SCENARIO)
    end

    local stageText
    if type(currentStage) == "number" and type(numStages) == "number" then
        stageText = addon.text.scenarioStage:format(currentStage, numStages)
    end
    return {
        {
            category = CATEGORY_SCENARIO,
            title = scenarioTitle,
            stageName = title,
            stageText = stageText,
            currentStage = currentStage,
            numStages = numStages,
            flags = type(flags) == "number" and flags or 0,
            scenarioType = scenarioType,
            textureKit = type(textureKit) == "string" and textureKit or "evergreen-scenario",
            scenarioID = scenarioID,
            widgetSetID = widgetSetID,
            isScenario = true,
            objectives = objectives,
            readyForTurnIn = false,
        },
    }, restricted
end

local function ReadAchievements(addon, previousCategory)
    local contentType = Enum
        and Enum.ContentTrackingType
        and Enum.ContentTrackingType.Achievement
    local trackedIDs, trackedAvailable = SafeCall(
        C_ContentTracking and C_ContentTracking.GetTrackedIDs,
        contentType
    )
    local trackedCount = trackedAvailable and SafeArrayLength(trackedIDs) or nil
    if not contentType or not trackedCount then
        return CopyQuestArray(previousCategory), true
    end

    local entries = {}
    local restricted = false
    for index = 1, trackedCount do
        local achievementID, idAvailable = ReadField(trackedIDs, index)
        local previous = idAvailable
            and FindPreviousEntry(previousCategory, "achievement", achievementID)
            or nil
        local ok, _, name, _, completed, _, _, _, description, _, _, _, _, wasEarnedByMe =
            pcall(_G.GetAchievementInfo, achievementID)
        if not ok
            or IsSecret(name)
            or IsSecret(completed)
            or IsSecret(description)
            or IsSecret(wasEarnedByMe)
            or type(name) ~= "string"
            or name == ""
        then
            if previous then
                entries[#entries + 1] = previous
            end
            restricted = true
        elseif not completed and not wasEarnedByMe then
            local objectives = {}
            local achievementRestricted = false
            local criteriaCount, countAvailable = SafeCall(
                _G.GetAchievementNumCriteria,
                achievementID
            )
            if countAvailable and type(criteriaCount) == "number" and criteriaCount > 0 then
                local incompleteCount = 0
                for criteriaIndex = 1, criteriaCount do
                    local criteriaOK, criteriaText, criteriaType, criteriaCompleted, quantity, totalQuantity,
                        _, flags, assetID, quantityText, _, eligible, duration, elapsed = pcall(
                            _G.GetAchievementCriteriaInfo,
                            achievementID,
                            criteriaIndex
                        )
                    if not criteriaOK
                        or IsSecret(criteriaText)
                        or IsSecret(criteriaCompleted)
                        or IsSecret(quantity)
                        or IsSecret(totalQuantity)
                        or IsSecret(quantityText)
                        or IsSecret(eligible)
                        or IsSecret(duration)
                        or IsSecret(elapsed)
                    then
                        achievementRestricted = true
                    elseif not criteriaCompleted and type(criteriaText) == "string" and criteriaText ~= "" then
                        incompleteCount = incompleteCount + 1
                        if #objectives < 5 then
                            if type(description) == "string"
                                and description ~= ""
                                and bit
                                and bit.band
                                and type(flags) == "number"
                                and type(_G.EVALUATION_TREE_FLAG_PROGRESS_BAR) == "number"
                                and bit.band(flags, _G.EVALUATION_TREE_FLAG_PROGRESS_BAR)
                                    == _G.EVALUATION_TREE_FLAG_PROGRESS_BAR
                                and type(quantityText) == "string"
                                and quantityText ~= ""
                            then
                                if string.find(string.lower(quantityText), "interface\\moneyframe") then
                                    criteriaText = quantityText .. "\n" .. description
                                else
                                    criteriaText = string.gsub(quantityText, " / ", "/")
                                        .. " "
                                        .. description
                                end
                            end
                            if criteriaType == _G.CRITERIA_TYPE_ACHIEVEMENT
                                and type(assetID) == "number"
                            then
                                local nestedOK, _, nestedName = pcall(_G.GetAchievementInfo, assetID)
                                if nestedOK and not IsSecret(nestedName) and type(nestedName) == "string" then
                                    criteriaText = nestedName
                                end
                            end
                            local progress
                            local progressText
                            if type(quantity) == "number"
                                and type(totalQuantity) == "number"
                                and totalQuantity > 1
                            then
                                progress = math.max(0, math.min((quantity / totalQuantity) * 100, 100))
                                progressText = type(quantityText) == "string" and quantityText ~= ""
                                    and quantityText
                                    or ("%d/%d"):format(quantity, totalQuantity)
                            end
                            objectives[#objectives + 1] = {
                                text = criteriaText,
                                finished = false,
                                failed = eligible == false,
                                progress = progress,
                                progressText = progressText,
                                timerDuration = type(duration) == "number"
                                    and type(elapsed) == "number"
                                    and elapsed < duration
                                    and duration
                                    or nil,
                                timerStartTime = type(duration) == "number"
                                    and type(elapsed) == "number"
                                    and elapsed < duration
                                    and (GetTime() - elapsed)
                                    or nil,
                            }
                        end
                    end
                end
                if incompleteCount > #objectives then
                    objectives[#objectives + 1] = { text = "...", finished = false }
                end
            elseif countAvailable and type(description) == "string" and description ~= "" then
                local failed = false
                if type(_G.IsAchievementEligible) == "function" then
                    local eligible, eligibleAvailable = SafeCall(_G.IsAchievementEligible, achievementID)
                    failed = eligibleAvailable and not eligible or false
                end
                objectives[1] = { text = description, finished = false, failed = failed }
            else
                achievementRestricted = true
            end

            if achievementRestricted and #objectives == 0 and previous then
                entries[#entries + 1] = previous
            else
                local timer = addon.customAchievementTimers
                    and addon.customAchievementTimers[achievementID]
                if timer and #objectives > 0 and not objectives[1].timerDuration then
                    objectives[1].timerDuration = timer.duration
                    objectives[1].timerStartTime = timer.startTime
                end
                entries[#entries + 1] = {
                    kind = "achievement",
                    trackingID = achievementID,
                    category = CATEGORY_ACHIEVEMENTS,
                    title = name,
                    objectives = objectives,
                }
            end
            restricted = restricted or achievementRestricted
        end
    end
    return entries, restricted
end

local function BuildRequirementsEntry(
    info,
    trackingID,
    category,
    kind,
    titleField,
    previous
)
    local title, titleAvailable = ReadField(info, titleField)
    local completed, completedAvailable = ReadField(info, "completed")
    if not titleAvailable
        or type(title) ~= "string"
        or title == ""
        or not completedAvailable
    then
        return previous, true
    end
    if completed then
        return nil, false
    end

    local requirements, requirementsAvailable = ReadField(info, "requirementsList")
    local requirementCount = requirementsAvailable and SafeArrayLength(requirements) or nil
    if not requirementCount then
        return previous, true
    end

    local objectives = {}
    local restricted = false
    for index = 1, requirementCount do
        local requirement, requirementAvailable = ReadField(requirements, index)
        local requirementText, textAvailable = requirementAvailable
            and ReadField(requirement, "requirementText")
            or nil, false
        local requirementCompleted, completionAvailable = requirementAvailable
            and ReadField(requirement, "completed")
            or nil, false
        if requirementAvailable then
            requirementText, textAvailable = ReadField(requirement, "requirementText")
            requirementCompleted, completionAvailable = ReadField(requirement, "completed")
        end
        if textAvailable
            and completionAvailable
            and not requirementCompleted
            and type(requirementText) == "string"
            and requirementText ~= ""
        then
            objectives[#objectives + 1] = {
                text = requirementText:gsub(" / ", "/"),
                finished = false,
            }
        elseif not textAvailable or not completionAvailable then
            restricted = true
        end
    end

    if restricted and #objectives == 0 and previous then
        return previous, true
    end
    return {
        kind = kind,
        trackingID = trackingID,
        category = category,
        title = title,
        objectives = objectives,
    }, restricted
end

local function ReadTrackedRequirements(
    previousCategory,
    category,
    kind,
    getTracked,
    getInfo,
    titleField
)
    local tracked, trackedAvailable = SafeCall(getTracked)
    local trackedIDs, idsAvailable = trackedAvailable and ReadField(tracked, "trackedIDs") or nil, false
    if trackedAvailable then
        trackedIDs, idsAvailable = ReadField(tracked, "trackedIDs")
    end
    local trackedCount = idsAvailable and SafeArrayLength(trackedIDs) or nil
    if not trackedCount then
        return CopyQuestArray(previousCategory), true
    end

    local entries = {}
    local restricted = false
    for index = 1, trackedCount do
        local trackingID, idAvailable = ReadField(trackedIDs, index)
        if idAvailable and type(trackingID) == "number" then
            local previous = FindPreviousEntry(previousCategory, kind, trackingID)
            local info, infoAvailable = SafeCall(getInfo, trackingID)
            if infoAvailable and IsReadableTable(info) then
                local entry, entryRestricted = BuildRequirementsEntry(
                    info,
                    trackingID,
                    category,
                    kind,
                    titleField,
                    previous
                )
                if entry then
                    entries[#entries + 1] = entry
                end
                restricted = restricted or entryRestricted
            else
                if previous then
                    entries[#entries + 1] = previous
                end
                restricted = true
            end
        else
            restricted = true
        end
    end
    return entries, restricted
end

local function ReadAdventureTracking(previousCategory)
    local sourceTypes, typesAvailable = SafeCall(
        C_ContentTracking and C_ContentTracking.GetCollectableSourceTypes
    )
    local typeCount = typesAvailable and SafeArrayLength(sourceTypes) or nil
    if not typeCount then
        return CopyQuestArray(previousCategory), true
    end

    local entries = {}
    local restricted = false
    for typeIndex = 1, typeCount do
        local trackingType, typeAvailable = ReadField(sourceTypes, typeIndex)
        local trackedIDs, idsAvailable = typeAvailable and SafeCall(
            C_ContentTracking.GetTrackedIDs,
            trackingType
        ) or nil, false
        if typeAvailable then
            trackedIDs, idsAvailable = SafeCall(C_ContentTracking.GetTrackedIDs, trackingType)
        end
        local trackedCount = idsAvailable and SafeArrayLength(trackedIDs) or nil
        if not trackedCount then
            restricted = true
        else
            for idIndex = 1, trackedCount do
                local trackingID, idAvailable = ReadField(trackedIDs, idIndex)
                local previous = idAvailable
                    and FindPreviousEntry(previousCategory, "content", trackingID, trackingType)
                    or nil
                local targetOK, targetType, targetID = pcall(
                    C_ContentTracking.GetCurrentTrackingTarget,
                    trackingType,
                    trackingID
                )
                if not idAvailable
                    or not targetOK
                    or IsSecret(targetType)
                    or IsSecret(targetID)
                    or targetType == nil
                then
                    if previous then
                        entries[#entries + 1] = previous
                    end
                    restricted = true
                else
                    local title, titleAvailable = SafeCall(
                        C_ContentTracking.GetTitle,
                        trackingType,
                        trackingID
                    )
                    local objectiveText, objectiveAvailable = SafeCall(
                        C_ContentTracking.GetObjectiveText,
                        targetType,
                        targetID
                    )
                    if titleAvailable and type(title) == "string" and title ~= "" then
                        local objectives = {}
                        if objectiveAvailable
                            and type(objectiveText) == "string"
                            and objectiveText ~= ""
                        then
                            objectives[1] = { text = objectiveText, finished = false }
                        elseif previous then
                            objectives = previous.objectives or {}
                            restricted = true
                        end

                        local targetTypes = Enum and Enum.ContentTrackingTargetType
                        local isNavigableTarget = targetTypes
                            and (targetType == targetTypes.Vendor
                                or targetType == targetTypes.JournalEncounter)
                        if isNavigableTarget
                            and objectiveAvailable
                            and C_ContentTracking.GetBestMapForTrackable
                        then
                            local mapOK, mapResult, uiMapID = pcall(
                                C_ContentTracking.GetBestMapForTrackable,
                                trackingType,
                                trackingID,
                                true
                            )
                            local results = Enum and Enum.ContentTrackingResult
                            if mapOK
                                and not IsSecret(mapResult)
                                and results
                                and mapResult ~= results.DataPending
                            then
                                if mapResult ~= results.Success or not uiMapID then
                                    objectives[#objectives + 1] = {
                                        text = _G.CONTENT_TRACKING_LOCATION_UNAVAILABLE
                                            or "Location unavailable",
                                        finished = false,
                                    }
                                elseif C_ContentTracking.IsNavigable then
                                    local navOK, navResult, navigable = pcall(
                                        C_ContentTracking.IsNavigable,
                                        trackingType,
                                        trackingID
                                    )
                                    if navOK
                                        and results
                                        and (navResult == results.Failure
                                            or (navResult == results.Success and not navigable))
                                    then
                                        objectives[#objectives + 1] = {
                                            text = _G.CONTENT_TRACKING_ROUTE_UNAVAILABLE
                                                or "Route unavailable",
                                            finished = false,
                                        }
                                    elseif navOK
                                        and C_SuperTrack
                                        and C_SuperTrack.GetSuperTrackedContent
                                    then
                                        local superOK, superType, superID = pcall(
                                            C_SuperTrack.GetSuperTrackedContent
                                        )
                                        if superOK
                                            and superType == trackingType
                                            and superID == trackingID
                                            and C_ContentTracking.GetWaypointText
                                        then
                                            local waypoint, waypointAvailable = SafeCall(
                                                C_ContentTracking.GetWaypointText,
                                                trackingType,
                                                trackingID
                                            )
                                            if waypointAvailable
                                                and type(waypoint) == "string"
                                                and waypoint ~= ""
                                            then
                                                objectives[#objectives + 1] = {
                                                    text = (_G.OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION or "%s")
                                                        :format(waypoint),
                                                    finished = false,
                                                }
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        entries[#entries + 1] = {
                            kind = "content",
                            trackingID = trackingID,
                            trackingType = trackingType,
                            targetID = targetID,
                            targetType = targetType,
                            category = CATEGORY_ADVENTURES,
                            title = title,
                            objectives = objectives,
                        }
                    elseif previous then
                        entries[#entries + 1] = previous
                        restricted = true
                    else
                        restricted = true
                    end
                end
            end
        end
    end
    return entries, restricted
end

local function GetReagentName(reagent, reagentSlot)
    local itemID, itemAvailable = ReadField(reagent, "itemID")
    if itemAvailable and type(itemID) == "number" then
        local itemName, nameAvailable = SafeCall(C_Item and C_Item.GetItemNameByID, itemID)
        if nameAvailable and type(itemName) == "string" and itemName ~= "" then
            return itemName
        end
    end

    local currencyID, currencyAvailable = ReadField(reagent, "currencyID")
    if currencyAvailable and type(currencyID) == "number" then
        local currencyInfo, infoAvailable = SafeCall(
            C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,
            currencyID
        )
        local currencyName, nameAvailable = infoAvailable
            and ReadField(currencyInfo, "name")
            or nil, false
        if infoAvailable then
            currencyName, nameAvailable = ReadField(currencyInfo, "name")
        end
        if nameAvailable and type(currencyName) == "string" and currencyName ~= "" then
            return currencyName
        end
    end

    local slotInfo, slotInfoAvailable = ReadField(reagentSlot, "slotInfo")
    local slotText, textAvailable = slotInfoAvailable and ReadField(slotInfo, "slotText") or nil, false
    if slotInfoAvailable then
        slotText, textAvailable = ReadField(slotInfo, "slotText")
    end
    if textAvailable and type(slotText) == "string" and slotText ~= "" then
        return slotText
    end
    return nil
end

local function BuildProfessionEntry(recipeID, isRecraft, previous)
    local schematic, schematicAvailable
    if ProfessionsUtil and ProfessionsUtil.GetRecipeSchematic then
        schematic, schematicAvailable = SafeCall(
            ProfessionsUtil.GetRecipeSchematic,
            recipeID,
            isRecraft
        )
    else
        schematic, schematicAvailable = SafeCall(
            C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic,
            recipeID,
            isRecraft
        )
    end
    local name, nameAvailable = schematicAvailable and ReadField(schematic, "name") or nil, false
    if schematicAvailable then
        name, nameAvailable = ReadField(schematic, "name")
    end
    if not nameAvailable or type(name) ~= "string" or name == "" then
        return previous, true
    end

    local title = name
    if isRecraft and type(_G.PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER) == "string" then
        title = _G.PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(name)
    end

    local objectives = {}
    local restricted = false
    local reagentSlots, slotsAvailable = ReadField(schematic, "reagentSlotSchematics")
    local slotCount = slotsAvailable and SafeArrayLength(reagentSlots) or nil
    if not slotCount then
        return previous or {
            kind = "profession",
            trackingID = recipeID,
            recipeID = recipeID,
            isRecraft = isRecraft,
            category = CATEGORY_PROFESSIONS,
            title = title,
            objectives = objectives,
        }, true
    end

    for slotIndex = 1, slotCount do
        local reagentSlot, slotAvailable = ReadField(reagentSlots, slotIndex)
        local required, requiredAvailable = slotAvailable and SafeCall(
            ProfessionsUtil and ProfessionsUtil.IsReagentSlotRequired,
            reagentSlot
        ) or nil, false
        if slotAvailable then
            required, requiredAvailable = SafeCall(
                ProfessionsUtil and ProfessionsUtil.IsReagentSlotRequired,
                reagentSlot
            )
        end
        if requiredAvailable and required then
            local reagents, reagentsAvailable = ReadField(reagentSlot, "reagents")
            local reagent, reagentAvailable = reagentsAvailable and ReadField(reagents, 1) or nil, false
            if reagentsAvailable then
                reagent, reagentAvailable = ReadField(reagents, 1)
            end
            local reagentName = reagentAvailable and GetReagentName(reagent, reagentSlot) or nil
            if reagentName then
                local quantityRequired, quantityAvailable = SafeMethodCall(
                    reagentSlot,
                    "GetQuantityRequired",
                    reagent
                )
                local quantity, possessionAvailable = SafeCall(
                    ProfessionsUtil and ProfessionsUtil.AccumulateReagentsInPossession,
                    reagents
                )
                local text = reagentName
                local finished = false
                if quantityAvailable
                    and possessionAvailable
                    and type(quantityRequired) == "number"
                    and type(quantity) == "number"
                then
                    local countText = type(_G.PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT) == "string"
                        and _G.PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityRequired)
                        or ("%d/%d"):format(quantity, quantityRequired)
                    text = type(_G.PROFESSIONS_TRACKER_REAGENT_FORMAT) == "string"
                        and _G.PROFESSIONS_TRACKER_REAGENT_FORMAT:format(countText, reagentName)
                        or (countText .. " " .. reagentName)
                    finished = quantity >= quantityRequired
                else
                    restricted = true
                end
                objectives[#objectives + 1] = {
                    text = text,
                    finished = finished,
                }
            else
                restricted = true
            end
        elseif not requiredAvailable then
            restricted = true
        end
    end

    if restricted and #objectives == 0 and previous then
        return previous, true
    end
    return {
        kind = "profession",
        trackingID = recipeID,
        recipeID = recipeID,
        isRecraft = isRecraft,
        category = CATEGORY_PROFESSIONS,
        title = title,
        objectives = objectives,
    }, restricted
end

local function ReadProfessionTracking(previousCategory)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipesTracked then
        return CopyQuestArray(previousCategory), true
    end

    local entries = {}
    local restricted = false
    for _, isRecraft in ipairs({ true, false }) do
        local recipeIDs, recipesAvailable = SafeCall(C_TradeSkillUI.GetRecipesTracked, isRecraft)
        local recipeCount = recipesAvailable and SafeArrayLength(recipeIDs) or nil
        if not recipeCount then
            restricted = true
        else
            for index = 1, recipeCount do
                local recipeID, idAvailable = ReadField(recipeIDs, index)
                if idAvailable and type(recipeID) == "number" then
                    local previous = FindPreviousEntry(
                        previousCategory,
                        "profession",
                        recipeID,
                        isRecraft
                    )
                    local entry, entryRestricted = BuildProfessionEntry(recipeID, isRecraft, previous)
                    if entry then
                        entries[#entries + 1] = entry
                    end
                    restricted = restricted or entryRestricted
                else
                    restricted = true
                end
            end
        end
    end
    return entries, restricted
end

local function ReadObjectiveWidgets(addon, previousCategory)
    local state = addon.customState
    local container = state and state.objectiveWidgetContainer
    local widgetCount, countAvailable = container
        and SafeCall(container.GetNumWidgetsShowing, container)
        or nil, false
    if not countAvailable or type(widgetCount) ~= "number" then
        return CopyQuestArray(previousCategory), true
    end
    if widgetCount <= 0 then
        return {}, false
    end

    local zoneName, zoneAvailable = SafeCall(_G.GetRealZoneText)
    return {
        {
            kind = "widgets",
            category = CATEGORY_WIDGETS,
            title = zoneAvailable and zoneName or addon:GetModuleLabel(CATEGORY_WIDGETS),
            isObjectiveWidget = true,
            objectives = {},
        },
    }, not zoneAvailable
end

function BQL:BuildCustomSnapshot(previousSnapshot)
    local previousByID = IndexPreviousSnapshot(previousSnapshot)
    local categories = {}
    for _, category in ipairs(self.DEFAULT_ORDER) do
        categories[category] = {}
    end

    local snapshot = {
        categories = categories,
        questCount = 0,
        restricted = false,
        updatedAt = GetTime(),
    }
    local seen = {}

    local function PreserveCategory(category)
        local previous = previousSnapshot and previousSnapshot.categories and previousSnapshot.categories[category]
        local preserved = {}
        for _, quest in ipairs(previous or {}) do
            local discardCompletedTask = (category == CATEGORY_WORLD or category == CATEGORY_BONUS)
                and quest.questID
                and IsQuestKnownCompleted(quest.questID)
            if not discardCompletedTask then
                preserved[#preserved + 1] = quest
            end
        end
        categories[category] = preserved
        snapshot.restricted = true
        for _, quest in ipairs(categories[category]) do
            if quest.questID then
                seen[quest.questID] = true
            end
        end
    end

    local function AddQuest(questID, suggestedCategory)
        if seen[questID] then
            return
        end
        seen[questID] = true

        local previousQuest = previousByID[questID]
        local fallbackCategory = previousQuest and previousQuest.category or suggestedCategory
        local category, categoryRestricted = GetQuestCategory(questID, fallbackCategory)
        local quest, questRestricted = BuildQuest(self, questID, category, previousQuest)
        snapshot.restricted = snapshot.restricted or categoryRestricted or questRestricted
        if quest and categories[category] then
            quest.category = category
            categories[category][#categories[category] + 1] = quest
        end
    end

    if type(_G.GetNumAutoQuestPopUps) == "function"
        and type(_G.GetAutoQuestPopUp) == "function"
    then
        local popupCount, popupCountAvailable = SafeCall(_G.GetNumAutoQuestPopUps)
        if popupCountAvailable and type(popupCount) == "number" then
            for index = 1, popupCount do
                local ok, questID, popupType = pcall(_G.GetAutoQuestPopUp, index)
                if ok
                    and not IsSecret(questID)
                    and not IsSecret(popupType)
                    and type(questID) == "number"
                    and not seen[questID]
                then
                    local previousQuest = previousByID[questID]
                    local category, categoryRestricted = GetQuestCategory(
                        questID,
                        previousQuest and previousQuest.category or CATEGORY_QUESTS
                    )
                    local quest, questRestricted = BuildQuest(self, questID, category, previousQuest)
                    snapshot.restricted = snapshot.restricted
                        or categoryRestricted
                        or questRestricted
                    if quest and categories[category] then
                        quest.isAutoQuestPopup = true
                        quest.popupType = popupType
                        if popupType == "COMPLETE" then
                            quest.objectives = {
                                {
                                    text = _G.QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
                                        or _G.QUEST_WATCH_CLICK_TO_COMPLETE
                                        or self.text.questComplete,
                                    finished = true,
                                },
                            }
                        else
                            quest.objectives = {
                                {
                                    text = _G.QUEST_WATCH_POPUP_CLICK_TO_VIEW
                                        or _G.QUEST_WATCH_POPUP_QUEST_DISCOVERED
                                        or "Click to view",
                                    finished = false,
                                },
                            }
                        end
                        quest.category = category
                        categories[category][#categories[category] + 1] = quest
                        seen[questID] = true
                    end
                end
            end
        end
    end

    local scenarioCategory, scenarioRestricted = ReadScenario(
        self,
        previousSnapshot and previousSnapshot.categories and previousSnapshot.categories[CATEGORY_SCENARIO]
    )
    categories[CATEGORY_SCENARIO] = scenarioCategory
    snapshot.restricted = snapshot.restricted or scenarioRestricted

    local widgetCategory, widgetRestricted = ReadObjectiveWidgets(
        self,
        previousSnapshot and previousSnapshot.categories and previousSnapshot.categories[CATEGORY_WIDGETS]
    )
    categories[CATEGORY_WIDGETS] = widgetCategory
    snapshot.restricted = snapshot.restricted or widgetRestricted

    local adventureCategory, adventureRestricted = ReadAdventureTracking(
        previousSnapshot
            and previousSnapshot.categories
            and previousSnapshot.categories[CATEGORY_ADVENTURES]
    )
    categories[CATEGORY_ADVENTURES] = adventureCategory
    snapshot.restricted = snapshot.restricted or adventureRestricted

    local achievementCategory, achievementRestricted = ReadAchievements(
        self,
        previousSnapshot
            and previousSnapshot.categories
            and previousSnapshot.categories[CATEGORY_ACHIEVEMENTS]
    )
    categories[CATEGORY_ACHIEVEMENTS] = achievementCategory
    snapshot.restricted = snapshot.restricted or achievementRestricted

    local monthlyCategory, monthlyRestricted = ReadTrackedRequirements(
        previousSnapshot and previousSnapshot.categories and previousSnapshot.categories[CATEGORY_MONTHLY],
        CATEGORY_MONTHLY,
        "monthly",
        C_PerksActivities and C_PerksActivities.GetTrackedPerksActivities,
        C_PerksActivities and C_PerksActivities.GetPerksActivityInfo,
        "activityName"
    )
    categories[CATEGORY_MONTHLY] = monthlyCategory
    snapshot.restricted = snapshot.restricted or monthlyRestricted

    local initiativeCategory, initiativeRestricted = ReadTrackedRequirements(
        previousSnapshot
            and previousSnapshot.categories
            and previousSnapshot.categories[CATEGORY_INITIATIVES],
        CATEGORY_INITIATIVES,
        "initiative",
        C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetTrackedInitiativeTasks,
        C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetInitiativeTaskInfo,
        "taskName"
    )
    categories[CATEGORY_INITIATIVES] = initiativeCategory
    snapshot.restricted = snapshot.restricted or initiativeRestricted

    local professionCategory, professionRestricted = ReadProfessionTracking(
        previousSnapshot
            and previousSnapshot.categories
            and previousSnapshot.categories[CATEGORY_PROFESSIONS]
    )
    categories[CATEGORY_PROFESSIONS] = professionCategory
    snapshot.restricted = snapshot.restricted or professionRestricted

    local questWatches = ReadWatchList(
        C_QuestLog and C_QuestLog.GetNumQuestWatches,
        C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex
    )
    if questWatches then
        for _, questID in ipairs(questWatches) do
            AddQuest(questID, CATEGORY_QUESTS)
        end
    else
        PreserveCategory(CATEGORY_CAMPAIGN)
        PreserveCategory(CATEGORY_QUESTS)
    end

    local tasks, tasksAvailable = SafeCall(_G.GetTasksTable)
    local taskCount = tasksAvailable and SafeArrayLength(tasks) or nil
    if taskCount then
        for index = 1, taskCount do
            local questID, questIDAvailable = ReadField(tasks, index)
            if questIDAvailable and type(questID) == "number" and questID > 0 then
                local worldQuest, worldAvailable = IsWorldQuest(questID)
                if worldAvailable then
                    local shouldDisplay, taskRestricted = ShouldDisplayTaskQuest(questID, false)
                    snapshot.restricted = snapshot.restricted or taskRestricted
                    if shouldDisplay then
                        AddQuest(questID, worldQuest and CATEGORY_WORLD or CATEGORY_BONUS)
                    end
                else
                    snapshot.restricted = true
                end
            end
        end
    elseif previousSnapshot then
        PreserveCategory(CATEGORY_BONUS)
    end

    local worldWatches = ReadWatchList(
        C_QuestLog and C_QuestLog.GetNumWorldQuestWatches,
        C_QuestLog and C_QuestLog.GetQuestIDForWorldQuestWatchIndex
    )
    if worldWatches then
        for _, questID in ipairs(worldWatches) do
            local shouldDisplay, taskRestricted = ShouldDisplayTaskQuest(questID, true)
            snapshot.restricted = snapshot.restricted or taskRestricted
            if shouldDisplay then
                AddQuest(questID, CATEGORY_WORLD)
            end
        end
    elseif previousSnapshot then
        PreserveCategory(CATEGORY_WORLD)
    end

    for _, quests in pairs(categories) do
        snapshot.questCount = snapshot.questCount + #quests
    end
    return snapshot
end
