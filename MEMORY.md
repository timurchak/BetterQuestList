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

## Active quest items, delves, and widgets

- Quest/scenario action buttons must use Blizzard-compatible secure attributes so a displayed spell/item is actually clickable. Rendering an icon alone is insufficient.
- Delve objective widgets and the custom nemesis counter must not duplicate Blizzard widget containers. Keep custom widget containers isolated and ensure only the intended presentation is visible.
- The nemesis/enhanced-enemy counter uses the game's relevant widget/currency state; presentation is custom so it can match the tracker rather than exposing the raw Blizzard widget frame.

## Current UX decisions

- Category headers are collapsible in Edit Mode configuration.
- Standard settings are the home for functional behavior and category ordering/names.
- Edit Mode is the single home for appearance, media, colors, spacing, sizes, progress bars, and element offsets.
- After deployment, tell the user to run `/reload` before testing Lua/UI changes.
