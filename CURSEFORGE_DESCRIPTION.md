# BetterQuestList

BetterQuestList is a lightweight, configurable replacement for the visual part of World of Warcraft's Objective Tracker. It keeps the familiar Blizzard experience while adding persistent category ordering, reliable mouse-wheel scrolling, and a cleaner customizable layout.

Unlike full tracker replacements, BetterQuestList does not try to recreate every dungeon, Delve, event, or scenario interface. It hosts Blizzard's native Scenario module inside its scrollable list, preserving the correct stages, timers, icons, counters, lives, and context-specific visuals supplied by the game.

## Features

- Arrange tracked-content categories in your preferred order.
- Keep that order after login, reloads, combat, and tracker updates.
- Scroll long objective lists with the mouse wheel.
- Display native Blizzard scenario UI for dungeons, Delves, events, and other scenarios.
- Show multiline quest names and objectives without losing counters at the edge.
- Retain familiar quest POI icons, quest-item buttons, group finder buttons, timers, auto-complete actions, and party progress tooltips.
- Track regular quests, campaigns, world quests, bonus objectives, achievements, profession recipes, Traveler's Log activities, Endeavors, collection targets, and objective widgets.
- Use Blizzard-style right-click menus with quest details, map actions, sharing, abandoning, tracking controls, and locale-aware Wowhead links.
- Customize fonts, tracker background, category header style, spacing, and offsets.
- Adjust appearance through the addon settings or WoW Edit Mode.
- Preserve the last readable objective progress when the game temporarily protects live values during combat.

## Getting started

Open the settings with:

`/bql`

You can also find BetterQuestList in WoW's standard AddOns settings and configure its appearance through Edit Mode.

Additional commands:

- `/bql reset` — restore the default category order.
- `/bql scroll` — enable or disable mouse-wheel scrolling.
- `/bql debug` — open a copyable diagnostic report for bug reports.

## Localization

BetterQuestList includes:

- English
- German
- Russian

## Compatibility

BetterQuestList is built for modern World of Warcraft Retail. It deliberately leaves Blizzard's Objective Tracker active in the background so protected game data and native scenario presentation remain under Blizzard's control.

The addon is focused: it changes how tracked content is presented, but does not alter quest data, progression, or completion state.

## Feedback and bug reports

If something is positioned incorrectly or disappears in a particular dungeon, Delve, event, or combat situation, run `/bql debug`. Copy the report with `Ctrl+A`, then `Ctrl+C`, and attach it to your report along with a short description of what was happening.
