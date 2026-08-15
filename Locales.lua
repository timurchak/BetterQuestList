local _, BQL = ...

local locales = {}

locales.enUS = {
    text = {
        title = "BetterQuestList",
        description = "BetterQuestList settings for Blizzard's Objective Tracker.",
        compatibilityWarning = "Compatibility workaround: BetterQuestList temporarily expands layout calculations, then restores the native Edit Mode size. Blizzard functions and protected tracker fields remain untouched.",
        order = "Category order",
        scrolling = "Mouse-wheel scrolling",
        scrollingDescription = "Renders all tracked objectives and scrolls them inside Blizzard's tracker.",
        reset = "Reset order",
        moveUp = "Move up",
        moveDown = "Move down",
        optionsUnavailable = "Could not open the settings panel.",
        resetDone = "Category order reset.",
        scrollOn = "Scrolling enabled.",
        scrollOff = "Scrolling disabled.",
        debugUnavailable = "Blizzard's tracker is not ready yet.",
        kalielsConflict = "Disable !KalielsTracker while testing; it replaces Blizzard's Objective Tracker.",
        restrictedMode = "WoW 12.1 compatibility workaround is active.",
        scrollDeferred = "Tracker changes are deferred until combat and protected aura restrictions end.",
    },
    moduleLabels = {
        ScenarioObjectiveTracker = "Scenario",
        UIWidgetObjectiveTracker = "Events",
        CampaignQuestObjectiveTracker = "Campaign",
        QuestObjectiveTracker = "Quests",
        AdventureObjectiveTracker = "Adventures",
        AchievementObjectiveTracker = "Achievements",
        MonthlyActivitiesObjectiveTracker = "Traveler's Log",
        InitiativeTasksObjectiveTracker = "Endeavors",
        ProfessionsRecipeTracker = "Profession Recipes",
        BonusObjectiveTracker = "Bonus Objectives",
        WorldQuestObjectiveTracker = "World Quests",
    },
}

locales.ruRU = {
    text = {
        title = "BetterQuestList",
        description = "Настройки BetterQuestList для стандартного трекера Blizzard.",
        compatibilityWarning = "Режим совместимости: BetterQuestList временно расширяет расчёт раскладки, затем возвращает размер из режима редактирования. Функции Blizzard и защищённые поля трекера не изменяются.",
        order = "Порядок категорий",
        scrolling = "Прокрутка колесом мыши",
        scrollingDescription = "Показывает все отслеживаемые цели и прокручивает их внутри стандартного трекера.",
        reset = "Сбросить порядок",
        moveUp = "Переместить выше",
        moveDown = "Переместить ниже",
        optionsUnavailable = "Не удалось открыть настройки.",
        resetDone = "Порядок категорий сброшен.",
        scrollOn = "Прокрутка включена.",
        scrollOff = "Прокрутка выключена.",
        debugUnavailable = "Стандартный трекер ещё не готов.",
        kalielsConflict = "Для проверки отключите !KalielsTracker: он заменяет стандартный трекер Blizzard.",
        restrictedMode = "Включён обход совместимости с WoW 12.1.",
        scrollDeferred = "Изменения трекера отложены до окончания боя и ограничений защищённых аур.",
    },
    moduleLabels = {
        ScenarioObjectiveTracker = "Сценарий",
        UIWidgetObjectiveTracker = "События",
        CampaignQuestObjectiveTracker = "Кампания",
        QuestObjectiveTracker = "Задания",
        AdventureObjectiveTracker = "Приключения",
        AchievementObjectiveTracker = "Достижения",
        MonthlyActivitiesObjectiveTracker = "Журнал путешественника",
        InitiativeTasksObjectiveTracker = "Начинания",
        ProfessionsRecipeTracker = "Рецепты профессий",
        BonusObjectiveTracker = "Бонусные цели",
        WorldQuestObjectiveTracker = "Локальные задания",
    },
}

locales.deDE = {
    text = {
        title = "BetterQuestList",
        description = "BetterQuestList-Einstellungen für Blizzards Zielverfolgung.",
        compatibilityWarning = "Kompatibilitätslösung: BetterQuestList erweitert die Layoutberechnung kurzzeitig und stellt danach die Größe aus dem Bearbeitungsmodus wieder her. Blizzard-Funktionen und geschützte Tracker-Felder bleiben unverändert.",
        order = "Kategorienreihenfolge",
        scrolling = "Scrollen mit dem Mausrad",
        scrollingDescription = "Zeigt alle verfolgten Ziele an und scrollt sie innerhalb von Blizzards Zielverfolgung.",
        reset = "Reihenfolge zurücksetzen",
        moveUp = "Nach oben verschieben",
        moveDown = "Nach unten verschieben",
        optionsUnavailable = "Das Einstellungsfenster konnte nicht geöffnet werden.",
        resetDone = "Kategorienreihenfolge zurückgesetzt.",
        scrollOn = "Scrollen aktiviert.",
        scrollOff = "Scrollen deaktiviert.",
        debugUnavailable = "Blizzards Zielverfolgung ist noch nicht bereit.",
        kalielsConflict = "Deaktiviere zum Testen !KalielsTracker; das Addon ersetzt Blizzards Zielverfolgung.",
        restrictedMode = "Die WoW-12.1-Kompatibilitätslösung ist aktiv.",
        scrollDeferred = "Tracker-Änderungen werden bis zum Ende des Kampfes und der geschützten Aura-Einschränkungen verschoben.",
    },
    moduleLabels = {
        ScenarioObjectiveTracker = "Szenario",
        UIWidgetObjectiveTracker = "Ereignisse",
        CampaignQuestObjectiveTracker = "Kampagne",
        QuestObjectiveTracker = "Quests",
        AdventureObjectiveTracker = "Abenteuer",
        AchievementObjectiveTracker = "Erfolge",
        MonthlyActivitiesObjectiveTracker = "Reisetagebuch",
        InitiativeTasksObjectiveTracker = "Unternehmungen",
        ProfessionsRecipeTracker = "Berufsrezepte",
        BonusObjectiveTracker = "Bonusziele",
        WorldQuestObjectiveTracker = "Weltquests",
    },
}

locales.enGB = locales.enUS

local selectedLocale = locales[GetLocale()] or locales.enUS
BQL.text = selectedLocale.text
BQL.fallbackLabels = selectedLocale.moduleLabels
