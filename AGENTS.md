# BetterQuestList development

- Treat `addon/BetterQuestList` as the only source of addon files.
- Do not edit the deployed copy under the World of Warcraft installation directly.
- After changing addon sources, run `./scripts/Validate.ps1` and then `./scripts/Deploy.ps1` unless the user explicitly requests a source-only change.
- Keep the version in `addon/BetterQuestList/BetterQuestList.toc` synchronized with release tags (`vX.Y.Z`).
- Run `./scripts/Package.ps1` when changing packaging or CI behavior and inspect the ZIP layout.
