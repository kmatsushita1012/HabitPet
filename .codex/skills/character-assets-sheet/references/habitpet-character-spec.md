# HabitPet Character Asset Spec (MVP)

Source: `docs/character-assets.md`

## Naming

- Use `character_<characterID>_lv<level>`.
- Keep level range fixed to `1..5`.

Examples:

- `character_hamster_lv1`
- `character_hamster_lv2`
- `character_hamster_lv3`
- `character_hamster_lv4`
- `character_hamster_lv5`

## xcassets Layout

- Create one character folder per ID: `character_<characterID>/`.
- Create one `.imageset` per asset name.
- Place each level image set in its character folder.
- Put `1x`, `2x`, `3x` PNG files in each image set.
- Generate valid `Contents.json` for each image set.

## Runtime Behavior

- `CharacterAppearanceResolver` uses `characterID x level`.
- Missing assets must still allow fallback emoji rendering.
- When adding a new `CharacterID`, prepare all 5 levels.
