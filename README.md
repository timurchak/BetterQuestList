# BetterQuestList

<img src="Media/BetterQuestListIcon.png" alt="BetterQuestList" width="96">

BetterQuestList is a lightweight customization layer for Blizzard's Objective Tracker. The project is intended to provide:

- configurable category ordering;
- mouse-wheel scrolling for long tracked-objective lists;
- the native Blizzard quest rendering style.

> [!IMPORTANT]
> WoW 12.1 compatibility safe mode currently disables native tracker mutations. Changing Blizzard's internal module order or available-height logic taints protected Objective Tracker updates and can trigger Secret Values errors. The settings remain available while a safe rendering approach is developed.

## Localization

The addon currently supports:

- English (`enUS` and `enGB`, also used as the fallback);
- German (`deDE`);
- Russian (`ruRU`).

Runtime strings and fallback module labels are defined in `Locales.lua`.

## Project structure

- `BetterQuestList.toc`, `Locales.lua`, `Core.lua`, `Scroll.lua`, and `Options.lua` are the addon runtime sources;
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

## Manual CurseForge upload

Create a local release package:

```powershell
./scripts/Package.ps1
```

Upload the generated `dist/BetterQuestList-<version>.zip` file through the CurseForge project dashboard. The ZIP contains a single top-level `BetterQuestList` directory and can be used for the initial manual project upload.

## GitHub CI and releases

Every push to `main` and every pull request validates the addon and builds a test ZIP. A tag matching the TOC version runs `BigWigsMods/packager@v2` and creates a GitHub release:

```powershell
git tag v0.1.5
git push origin v0.1.5
```

Update `## Version` in `BetterQuestList.toc` before creating the tag.

CurseForge publishing additionally requires:

1. `## X-Curse-Project-ID: ...` in `BetterQuestList.toc`;
2. a repository secret named `CF_API_KEY`.

Without a CurseForge project ID, the packager can still create standard GitHub releases.
