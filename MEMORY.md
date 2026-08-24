# BetterQuestList development memory

Last updated: 2026-08-24

Read this before rediscovering integration and WoW 12.1 behavior. This file records technical conclusions, including approaches that looked reasonable but caused regressions.

## Repository and release workflow

- Authoritative source: `C:\projects\BetterQuest`.
- Deployed game copy: `F:\G\World of Warcraft\_retail_\Interface\AddOns\BetterQuestList`.
- Never edit the deployed copy directly.
- After runtime changes, run `scripts\Validate.ps1` and then `scripts\Deploy.ps1`.
- Keep the TOC version and release tag synchronized. Do not commit, tag, bump, or push unless the user explicitly asks.
- The working tree can contain changes made in other sessions. Preserve them and review the full diff before a release.

## WoW 12.1 secret values and taint

- BetterQuestList previously tainted Blizzard tooltip widget setup. Typical failures were secret-number arithmetic in `Blizzard_UIWidgetTemplateTextWithState.lua` and `Blizzard_UIWidgetTemplateBase.lua` after using the map or a POI tooltip.
- Do not reimplement `UIWidgetContainerMixin:ProcessWidget` in addon execution. The isolated widget container must call Blizzard's original `ProcessWidget` through `securecallfunction`; otherwise shared widget/font state becomes tainted.
- Do not inherit `GameTooltipTemplate` for addon tooltips. `BQL:GetTooltip()` deliberately creates an addon-owned plain frame because shared Blizzard tooltip mixins can contaminate map tooltips.
- Use `SafeCall`, `ReadField`, `SafeArrayLength`, `IsReadableTable`, and `IsSecret` when reading quest/scenario data. Preserve the previous snapshot when protected data becomes unreadable.
- Blizzard actions that synchronously rebuild shared UI, especially map and super-tracking operations, should cross the existing `InvokeBlizzardAction` secure boundary.
- Keep the stock Objective Tracker visually hidden with `securecallfunction(tracker.SetAlpha, tracker, 0)` from an addon-owned periodic update. Hooking or replacing Blizzard `Show`/`SetAlpha` methods expands the taint chain.
- A secure state-driver experiment prevented some aura taint but made the native tracker appear underneath BetterQuestList while moving. It was reverted. Do not restore it without solving that regression first.

## Tracker and Edit Mode architecture

- The custom tracker is rendered by `CustomTracker.lua`, while the native `ObjectiveTrackerFrame` remains available as the Blizzard Edit Mode system and position source.
- Edit Mode uses `BetterQuestListEditModeOverlay` for the visible custom selection and selects the native tracker only to retain Blizzard movement/saving behavior.
- Selecting the native tracker makes Blizzard draw a second highlight through `ObjectiveTrackerFrame.Selection`, even though the tracker itself has alpha zero. `BQL:SuppressBlizzardTrackerEditModeSelection()` sets that selection alpha to zero through `securecallfunction`, and the tracker update reasserts it while Edit Mode is active.
- The eye button must affect only the BetterQuestList overlay. Never reveal the native selection when hiding the custom overlay.
- Visual customization now belongs exclusively to the Edit Mode panel. The old Appearance block was removed from `Options.lua`; standard addon settings retain behavior, ordering, integration height, and category-name controls.
- Category-name settings also own per-category header visibility. A hidden header removes the name, collapse icon, and header texture only; render that category's contents as expanded without changing its saved `collapsedCategories` state.
- Edit Mode option sections are collapsible and live-preview changes. Long SharedMedia dropdowns must use `rootDescription:SetScrollMode(320)` when there are more than 12 choices, otherwise the settings panel captures the mouse wheel.
- Use ASCII `-` and `+` for section arrows. The previous Unicode minus was missing from some WoW fonts and rendered as a square.

## Fonts, textures, colors, and offsets

- Font and status-bar choices come from the complete current `LibSharedMedia-3.0` registry when available, with built-in fallbacks in `Core.lua`.
- Stored `fontFace` and `progressBarTexture` values are SharedMedia names, not paths. Resolve them through `BQL:ResolveMediaPath`.
- Text size is an absolute pixel value (`fontSize`, 8-32), not an offset.
- Quest titles have separate in-progress, complete, and low-level colors. Low level is based on quest level minus player level and `questLowLevelThreshold`.
- Objective text, its bullet, and its progress bar share the objective X/Y offsets. Moving only the text was a visible regression.
- Existing independent offsets cover quest POI icons, quest titles, regular-quest location lines, and objectives.

## Regular quest locations

- Location is shown only for entries in `QuestObjectiveTracker`, not campaigns, world quests, bonus objectives, or scenarios.
- There is no current `C_QuestLog.GetQuestZoneID` API.
- Use `C_QuestLog.GetHeaderIndexForQuest(questID)`, then `C_QuestLog.GetInfo(headerIndex).title`. This reflects the location/header used by the quest log and is more reliable than treating the next waypoint map as the quest's zone.
- Read it through the safe data helpers and retain the previous location when data is restricted.

## Profession recipe search and Auctionator

- Profession entries use category `ProfessionsRecipeTracker` and kind `profession`.
- Kaliel Tracker does not implement reagent searching itself. It reparents Auctionator's Objective Tracker search frame into its profession header.
- Auctionator's own implementation is `Auctionator.CraftingInfo.DoTrackedRecipesSearch()` in `Source_Mainline\CraftingInfo\ObjectiveTracker.lua`.
- That function reads all tracked normal and recraft recipes, includes mandatory basic reagents, combines quantities, waits for item data, skips bound items, and sends the result to `Auctionator.API.v1.MultiSearchAdvanced`.
- BetterQuestList provides its own small header button because its tracker rows are pooled/custom-rendered, but delegates the click to the Auctionator function. The button is shown only while the auction house is open and the function exists.
- Register `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` and `_HIDE` so the button updates immediately when the auction opens or closes.
- `Auctionator` is an optional dependency in the TOC to make load order deterministic when installed.

## Mythic+ timer integrations

- The saved category key remains `EnhanceQoLMythicPlusTimer` for profile compatibility, but it is the shared Mythic+ timer category for EnhanceQoL and standalone MythicPlusTimer.
- `mythicPlusTimerSource` accepts `auto`, `mythicPlusTimer`, `enhanceQoL`, or `disabled`. Auto prefers an active standalone MythicPlusTimer, then EnhanceQoL.
- The Edit Mode source dropdown filters providers through installed-addon metadata. Keep Auto and Disabled visible, but do not advertise integrations whose addons are absent.
- Standalone MythicPlusTimer exposes its root as `_G.MythicPlusTimer`; its private addon namespace is not globally accessible.
- Its root frame is only 25 px high while most visible content hangs from child frames below it. Calculate bounds recursively from shown descendants and regions; root-frame height alone clips the integration.
- MythicPlusTimer reparents the native Objective Tracker to an anonymous hidden frame on every timer update. Never fight it by restoring the tracker to `UIParent`: that creates a visible top-of-screen/anchor oscillation. While MythicPlusTimer owns the native parent, mirror the tracker's saved points onto an addon-owned `UIParent` proxy and anchor the custom frame there. A screen-coordinate cache captured during addon initialization is too early after `/reload` and falls back to Blizzard's top-right default before Edit Mode applies the saved layout.
- Parking an embedded external frame under a hidden parent changes effective visibility and can fire `OnShow`/`OnHide`. Suppress integration visibility callbacks during BetterQuestList-controlled reparenting to avoid a refresh loop.
- `mythicPlusTimerOffsetX/Y` are shared Edit Mode offsets for the selected timer provider. Apply them after automatic visual centering for external frames. A negative Y offset must add downward space to the automatic row height.
- Mythic+/raid focus settings are transient render policies and must not overwrite `collapsedCategories`. During an active challenge mode, retain the shared Mythic+ timer category, the Blizzard scenario fallback, and every configured damage-meter category. In a raid instance, retain `ScenarioObjectiveTracker` and the damage meters. Full tracker hiding takes priority over category hiding, which takes priority over collapsing; retained categories are forced open until the instance focus mode ends so the user's normal collapse state can be restored unchanged.

## Active quest items, delves, and widgets

- Quest/scenario action buttons must use Blizzard-compatible secure attributes so a displayed spell/item is actually clickable. Rendering an icon alone is insufficient.
- Delve objective widgets and the custom nemesis counter must not duplicate Blizzard widget containers. Keep custom widget containers isolated and ensure only the intended presentation is visible.
- The nemesis/enhanced-enemy counter uses the game's relevant widget/currency state; presentation is custom so it can match the tracker rather than exposing the raw Blizzard widget frame.

## Current UX decisions

- Category headers are collapsible in Edit Mode configuration.
- Standard settings are the home for functional behavior and category ordering/names.
- Edit Mode is the single home for appearance, media, colors, spacing, sizes, progress bars, and element offsets.
- After deployment, tell the user to run `/reload` before testing Lua/UI changes.
