# BetterQuestList

<img src="Media/BetterQuestListIcon.png" alt="BetterQuestList" width="96">

BetterQuestList is a lightweight custom quest tracker. The experimental `dev` renderer provides:

- configurable category ordering;
- tracked achievements, profession recipes, Traveler's Log activities, Endeavors, collection targets, and native event widgets;
- mouse-wheel scrolling for long tracked-objective lists;
- selectable tracker fonts and background presets, including a fully transparent background;
- optional Blizzard-style textured category headers;
- an Edit Mode companion panel for live appearance, category-spacing, and quest-spacing adjustments;
- Blizzard Objective Tracker fonts and native quest POI buttons for campaign, legendary, important, recurring, world, and other quest types;
- Blizzard-style right-click quest menus plus locale-aware, copyable Wowhead URLs;
- a compact presentation inspired by Blizzard's quest tracker;
- in-memory snapshots that preserve the last readable quest progress when WoW protects live data.

> [!IMPORTANT]
> The custom renderer does not call Blizzard Objective Tracker layout methods or mutate its module order. The stock tracker remains active but visually hidden, so Blizzard can continue processing protected Scenario and aura data on its own secure path.

## Localization

The addon currently supports:

- English (`enUS` and `enGB`, also used as the fallback);
- German (`deDE`);
- Russian (`ruRU`).

Runtime strings and fallback module labels are defined in `Locales.lua`.

## Project structure

- `BetterQuestList.toc`, `Locales.lua`, `CustomData.lua`, `Core.lua`, `CustomTracker.lua`, and `Options.lua` are the addon runtime sources;
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

Run `/bql debug` to open a copyable diagnostic report containing tracker, scroll area, scenario widget, and Delve header geometry. Press `Ctrl+A`, then `Ctrl+C` in the report window and include the copied text with a bug report.

## Manual CurseForge upload

Create a local release package:

```powershell
./scripts/Package.ps1
```

Upload the generated `dist/BetterQuestList-<version>.zip` file through the CurseForge project dashboard. The ZIP contains a single top-level `BetterQuestList` directory and can be used for the initial manual project upload.

## GitHub CI and releases

Every push to `main` and every pull request validates the addon and builds a test ZIP. A tag matching the TOC version runs `BigWigsMods/packager@v2` and creates a GitHub release:

```powershell
git tag v0.2.0
git push origin v0.2.0
```

Update `## Version` in `BetterQuestList.toc` before creating the tag.

CurseForge publishing additionally requires:

1. `## X-Curse-Project-ID: ...` in `BetterQuestList.toc`;
2. a repository secret named `CF_API_KEY`.

Without a CurseForge project ID, the packager can still create standard GitHub releases.
