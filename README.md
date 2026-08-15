# BetterQuestList

Лёгкая надстройка над стандартным Blizzard Objective Tracker:

- настраиваемый порядок категорий;
- прокрутка длинного списка колесом мыши;
- без собственного рендера квестов.

## Структура

- `addon/BetterQuestList` — единственный источник файлов аддона;
- `scripts/Validate.ps1` — проверка TOC и структуры;
- `scripts/Deploy.ps1` — чистый деплой в WoW;
- `scripts/Watch.ps1` — деплой при каждом сохранении исходников;
- `scripts/Package.ps1` — сборка готового ZIP;
- `.github/workflows/ci.yml` — CI, artifact и GitHub Release по тегу.

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

Каждый push и pull request проверяет проект и собирает ZIP. Тег, совпадающий с версией из TOC, создаёт GitHub Release:

```powershell
git tag v0.1.2
git push origin v0.1.2
```

Перед тегом обновите `## Version` в `addon/BetterQuestList/BetterQuestList.toc`.
