# BetterQuestList

BetterQuestList is a lightweight, configurable replacement for the visual part of World of Warcraft's Objective Tracker. It keeps the familiar Blizzard experience while adding persistent category ordering, reliable mouse-wheel scrolling, and a cleaner customizable layout.

Unlike full tracker replacements, BetterQuestList does not try to recreate every dungeon, Delve, event, or scenario interface. It hosts Blizzard's native Scenario module inside its scrollable list, preserving the correct stages, timers, icons, counters, lives, and context-specific visuals supplied by the game.

> **Work in progress:** BetterQuestList is under active development. Some content types, combat situations, or combinations with other UI addons may still expose bugs or visual conflicts. Feedback, suggestions, compatibility reports, and bug reports are very welcome and directly help shape upcoming releases.

## Features

- Arrange tracked-content categories in your preferred order.
- Keep that order after login, reloads, combat, and tracker updates.
- Scroll long objective lists with the mouse wheel.
- Automatically track newly accepted regular quests using Blizzard's standard setting.
- Display native Blizzard scenario UI for dungeons, Delves, events, and other scenarios.
- Show multiline quest names and objectives without losing counters at the edge.
- Retain familiar quest POI icons, quest-item buttons, group finder buttons, timers, auto-complete actions, and party progress tooltips.
- Track regular quests, campaigns, world quests, bonus objectives, achievements, profession recipes, Traveler's Log activities, Endeavors, collection targets, and objective widgets.
- Use Blizzard-style right-click menus with quest details, map actions, sharing, abandoning, tracking controls, and locale-aware Wowhead links.
- Customize fonts, outlines, shadows, tracker background, category header style, spacing, and offsets.
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

## Roadmap

Planned areas of development include:

- Compatibility and integration with addons that replace or modify the Mythic+ timer.
- Integration with DPS and combat meters, including Details! and EnhanceQoL.
- Better interoperability with navigation and waypoint addons, including TomTom.
- Additional integrations based on community feedback and real-world compatibility reports.

These items are development goals rather than guaranteed release dates or commitments. Priorities may change as the WoW UI and addon APIs evolve.

## Feedback and bug reports

All feedback is appreciated, even if the problem is difficult to reproduce. If something is positioned incorrectly, disappears, behaves differently in combat, or conflicts with another addon, run `/bql debug`. Copy the report with `Ctrl+A`, then `Ctrl+C`, and attach it to your report together with:

- A short description of what happened and what you expected.
- The dungeon, Delve, event, or other activity where it occurred.
- The names of other addons that modify the Objective Tracker, Mythic+ timer, combat meter, navigation, waypoints, or nearby UI elements.
