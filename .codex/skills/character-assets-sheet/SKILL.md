---
name: character-assets-sheet
description: Split a single batch-generated character sheet PNG into HabitPet iOS image assets and generate character-id based lv1 to lv5 `.imageset` folders with 1x/2x/3x files and `Contents.json`. Use when Codex needs to convert one source image (for example `images/image.png`) into `Assets.xcassets` files that follow `docs/character-assets.md`, including cases where the sheet contains text labels and card frames that must be removed.
---

# Character Assets Sheet

## Workflow

1. Read `docs/character-assets.md` to confirm naming and level count.
2. Determine `characterID` from user request (for example `hamster`, `rabbit`).
3. Run `scripts/split_character_sheet.py` to extract connected components from a single PNG and map them to levels 1..5 in reading order.
   - If the source is an opaque card-style sheet, remove text labels and rectangular frames automatically.
4. Create a character folder under `HabitPet/Assets.xcassets`:
   - `character_<characterID>/`
5. Generate `.imageset` folders inside that character folder using fixed names:
   - `character_<characterID>_lv1`
   - `character_<characterID>_lv2`
   - `character_<characterID>_lv3`
   - `character_<characterID>_lv4`
   - `character_<characterID>_lv5`
6. Verify output files exist and are loadable by Xcode.

## Command

```bash
python3 .codex/skills/character-assets-sheet/scripts/split_character_sheet.py \
  --input images/image.png \
  --character-id hamster \
  --assets-root HabitPet/Assets.xcassets
```

## Defaults And Assumptions

- Treat the input as one sheet containing exactly 5 separated character poses.
- Detect sprites by alpha channel connected components.
- Sort detected components in reading order (top-to-bottom, then left-to-right).
- Treat extracted crop as 3x source and derive 2x/1x by downscaling.
- Regenerate `Contents.json` for each `.imageset`.
- Place generated image sets under `Assets.xcassets/character_<characterID>/`.
- For opaque card-style sheets, keep only character and surrounding effects as transparent foreground.

## Troubleshooting

- If non-character noise is detected as a component, re-run with a larger `--min-pixels`.
- If multiple rows are merged incorrectly, tune `--row-threshold`.
- If the sheet does not contain 5 poses, stop and request corrected source image.

## References

- Read `references/habitpet-character-spec.md` when naming or folder structure is unclear.
