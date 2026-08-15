# BetterQuestList

Лёгкая надстройка над стандартным Blizzard Objective Tracker:

- настраиваемый порядок категорий;
- прокрутка длинного списка колесом мыши;
- без собственного рендера квестов.

## Структура

- `BetterQuestList.toc`, `Core.lua`, `Scroll.lua`, `Options.lua` — исходники аддона в корне репозитория;
- `scripts/Validate.ps1` — проверка TOC и структуры;
- `scripts/Deploy.ps1` — чистый деплой в WoW;
- `scripts/Watch.ps1` — деплой при каждом сохранении исходников;
- `scripts/Package.ps1` — сборка готового ZIP;
- `.pkgmeta` — правила упаковки WoW Packager;
- `.github/workflows/ci.yml` — проверка и тестовая сборка;
- `.github/workflows/release.yml` — GitHub Release и публикация по тегу.

Папка `Interface/AddOns/BetterQuestList` является только результатом деплоя. Не редактируйте файлы в ней вручную.

## Локальная разработка

Локальный путь WoW хранится в `.deploy.local.ps1`, который исключён из Git:

```powershell
$BetterQuestListWowRoot = "F:\G\World of Warcraft\_retail_"
```

Проверить и задеплоить:

```powershell
./scripts/Validate.ps1
./scripts/Deploy.ps1
```

Следить за изменениями и автоматически деплоить после сохранения:

```powershell
./scripts/Watch.ps1
```

После деплоя выполните `/reload` в WoW.

Собрать ZIP локально:

```powershell
./scripts/Package.ps1
```

## GitHub CI и релизы

Каждый push в `main` и pull request проверяет проект и собирает тестовый ZIP. Тег, совпадающий с версией из TOC, запускает `BigWigsMods/packager@v2` и создаёт GitHub Release:

```powershell
git tag v0.1.2
git push origin v0.1.2
```

Перед тегом обновите `## Version` в `BetterQuestList.toc`.

Для публикации на CurseForge дополнительно нужны:

1. `## X-Curse-Project-ID: ...` в `BetterQuestList.toc`;
2. секрет репозитория `CF_API_KEY`.

Без CurseForge Project ID packager продолжит создавать обычные GitHub Releases.
