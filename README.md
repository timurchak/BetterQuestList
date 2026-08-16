# BetterQuestList

<img src="Media/BetterQuestListIcon.png" alt="BetterQuestList" width="96">

BetterQuestList is a lightweight, configurable replacement for the visual part of Blizzard's Objective Tracker. It renders one compact, scrollable list while leaving Blizzard's tracker active and structurally untouched in the background to process protected game data.

The current version focuses on predictable behavior and familiar WoW interactions:

- one persistent, user-defined order for all supported categories;
- mouse-wheel scrolling when the tracked content is taller than the configured tracker area;
- automatic tracking for newly accepted regular quests through Blizzard's autoQuestWatch setting;
- Blizzard scenario widget sets and context-specific tracker textures for dungeons, Delves, events, and other scenario types, including their stages, icons, counters, and visual styles;
- custom quest rows with native quest POI buttons and multiline objectives;
- tracked world quests, bonus objectives, achievements, profession recipes, Traveler's Log activities, Endeavors, collection targets, and objective widgets;
- Blizzard-style right-click menus with tracking actions, quest details, map access, sharing, abandoning, and locale-aware Wowhead links;
- selectable fonts, outlines, shadows, background presets, optional Blizzard-style category textures, and configurable spacing and offsets;
- appearance controls in both the standard addon options and WoW Edit Mode, with persistent tracker width and height controls in Edit Mode;
- in-memory snapshots that preserve the last readable quest progress while WoW temporarily marks live values as secret.

## Design

BetterQuestList does not reorder, reparent, or manually update Blizzard's Objective Tracker modules. Regular quests and tracked content are rendered by the addon. Scenario rows reuse Blizzard-provided widget sets, atlases, fonts, and context metadata without moving the live `ScenarioObjectiveTracker`, because that module reads protected aura data during combat.

> [!IMPORTANT]
> The stock tracker remains active but visually hidden. BetterQuestList never calls its layout/update methods, mutates its module order, or attaches its Scenario module to addon-owned frames, allowing Blizzard to continue processing protected Scenario and aura data on its own path.

## Localization

The addon currently supports:

- English (`enUS` and `enGB`, also used as the fallback);
- German (`deDE`);
- Russian (`ruRU`).

Runtime strings and fallback module labels are defined in `Locales.lua`.

## Project structure

- `BetterQuestList.toc`, `Locales.lua`, `CustomData.lua`, `Core.lua`, `CustomTracker.lua`, `EditMode.lua`, and `Options.lua` are the addon runtime sources;
- `Media/BetterQuestListIcon.tga` is the in-game icon;
- `Media/BetterQuestListIcon.png` is the repository and project-page logo;
- `scripts/Validate.ps1` validates the TOC and source structure;
- `scripts/Deploy.ps1` performs a clean deployment to WoW;
- `scripts/Watch.ps1` deploys whenever a runtime source changes;
- `scripts/Package.ps1` creates a ready-to-upload ZIP;
- `.pkgmeta` configures the BigWigs WoW Packager;
- `.github/workflows/ci.yml` validates the project and builds a test package;
- `.github/workflows/release.yml` creates GitHub releases and publishes tagged builds.

The `Interface/AddOns/BetterQuestList` directory is a deployment output only. Do not edit that copy directly.

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

## Diagnostics

Run `/bql debug` to open a copyable diagnostic report containing tracker, scroll area, native Scenario module, scenario widgets, and Delve header geometry. Press `Ctrl+A`, then `Ctrl+C` in the report window and include the copied text with a bug report.

## Manual CurseForge upload

Create a local release package:

```powershell
./scripts/Package.ps1
```

Upload the generated `dist/BetterQuestList-<version>.zip` file through the CurseForge project dashboard. The ZIP contains a single top-level `BetterQuestList` directory and can be used for the initial manual project upload.

## GitHub CI and releases

Every push to `main` and every pull request validates the addon and builds a test ZIP. A tag matching the TOC version runs `BigWigsMods/packager@v2` and creates a GitHub release:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

Update `## Version` in `BetterQuestList.toc` before creating the tag.

CurseForge publishing additionally requires:

1. `## X-Curse-Project-ID: ...` in `BetterQuestList.toc`;
2. a repository secret named `CF_API_KEY`.

Without a CurseForge project ID, the packager can still create standard GitHub releases.
