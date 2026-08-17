# BetterQuestList

<img src="Media/BetterQuestListIcon.png" alt="BetterQuestList" width="96">

BetterQuestList is a lightweight, configurable replacement for the visual part of World of Warcraft's Objective Tracker. It keeps the familiar Blizzard experience while adding persistent category ordering, reliable mouse-wheel scrolling, and a cleaner customizable layout.

Unlike full tracker replacements, BetterQuestList does not try to recreate every dungeon, Delve, event, or scenario interface. It uses Blizzard-provided scenario UI, widget sets, and context-specific visuals inside its scrollable list, preserving the correct stages, timers, icons, counters, lives, and presentation supplied by the game while leaving the live Blizzard tracker under Blizzard's control.

> **Work in progress:** BetterQuestList is under active development. Some content types, combat situations, or combinations with other UI addons may still expose bugs or visual conflicts. Feedback, suggestions, compatibility reports, and bug reports are very welcome and directly help shape upcoming releases.

## Roadmap

EnhanceQoL Damage Meter integration is available now, including support for up to five independently assigned windows. Details! is the next planned combat meter integration.

Planned areas of development include:

- Details! DPS and combat meter integration.
- Compatibility and integration with addons that replace or modify the Mythic+ timer.
- Better interoperability with navigation and waypoint addons, including TomTom.
- Additional integrations based on community feedback and real-world compatibility reports.

## Features

- Arrange tracked-content categories in your preferred order.
- Keep that order after login, reloads, combat, and tracker updates.
- Scroll long objective lists with the mouse wheel.
- Display Blizzard-provided scenario UI and context-specific visuals for dungeons, Delves, events, and other scenarios.
- Embed up to five EnhanceQoL Damage Meter windows as independently ordered tracker categories.
- Assign each embedded EnhanceQoL window to its own category through WoW Edit Mode.
- Rename every category heading while retaining localized defaults.
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

## Feedback and bug reports

All feedback is appreciated, even if the problem is difficult to reproduce. If something is positioned incorrectly, disappears, behaves differently in combat, or conflicts with another addon, run `/bql debug`. Copy the report with `Ctrl+A`, then `Ctrl+C`, and attach it to your report together with:

- A short description of what happened and what you expected.
- The dungeon, Delve, event, or other activity where it occurred.
- The names of other addons that modify the Objective Tracker, Mythic+ timer, combat meter, navigation, waypoints, or nearby UI elements.

## Project structure

- `BetterQuestList.toc`, `Locales.lua`, `CustomData.lua`, `Core.lua`, `Integrations.lua`, `CustomTracker.lua`, `EditMode.lua`, and `Options.lua` are the addon runtime sources.
- `Media/BetterQuestListIcon.tga` is the in-game icon.
- `Media/BetterQuestListIcon.png` is the repository and project-page logo.
- `scripts/Validate.ps1` validates the TOC and source structure.
- `scripts/Deploy.ps1` performs a clean deployment to WoW.
- `scripts/Watch.ps1` deploys whenever a runtime source changes.
- `scripts/Package.ps1` creates a ready-to-upload ZIP.
- `.pkgmeta` configures the BigWigs WoW Packager.
- `.github/workflows/ci.yml` validates the project and builds a test package.
- `.github/workflows/release.yml` creates GitHub releases and publishes tagged builds.

The `Interface/AddOns/BetterQuestList` directory is deployment output only. Do not edit that copy directly.

## Local development

Store the local WoW path in the Git-ignored `.deploy.local.ps1` file:

```powershell
$BetterQuestListWowRoot = "F:\G\World of Warcraft\_retail_"
```

Validate and deploy the addon:

```powershell
./scripts/Validate.ps1
./scripts/Deploy.ps1
```

Watch runtime files and deploy after every saved change:

```powershell
./scripts/Watch.ps1
```

Run `/reload` in WoW after deployment.

## Manual CurseForge upload

Create a local release package:

```powershell
./scripts/Package.ps1
```

Upload the generated `dist/BetterQuestList-<version>.zip` file through the CurseForge project dashboard. The ZIP contains a single top-level `BetterQuestList` directory.

## GitHub CI and releases

Every push to `main` and every pull request validates the addon and builds a test ZIP. A tag matching the TOC version runs `BigWigsMods/packager@v2`, creates a GitHub release, and publishes to CurseForge when `CF_API_KEY` is configured.

Update `## Version` in `BetterQuestList.toc` before creating a release tag.
