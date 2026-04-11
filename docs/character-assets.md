# Character Asset 設計（kind別）

## 1. 前提

- キャラクターは `CharacterType` enum で管理する。
- 習慣種別は `HabitKind` enum で管理する。
- 画像は `kind x character x level(1...5)` で解決する。

## 2. 命名規約

アセット名:

`character_<kind>_<character>_lv<level>`

例:

- `character_nonSmoking_hamster_lv1`
- `character_nonSmoking_hamster_lv5`
- `character_nonAlcohol_fox_lv1`
- `character_nonGambling_cat_lv3`
- `character_other_dog_lv2`

## 3. ディレクトリ推奨構成

`Assets.xcassets` 内に以下を推奨する。

- `character_nonSmoking/`
- `character_nonAlcohol/`
- `character_nonGambling/`
- `character_other/`

各フォルダ内に `character_<kind>_<character>_lv1...lv5.imageset` を作成する。

## 4. 実装ルール

- 画像選択は `HabitKind` と `CharacterType` から行う。
- UIには enum のタイトルを表示し、内部ID文字列を直接編集させない。
- 画像が欠ける組み合わせはフォールバック画像を表示する。

## 5. 追加時チェック

1. kindごとに `lv1...lv5` が揃っているか
2. enum定義と表示名が一致しているか
3. WidgetとAppで同じ命名規約を使っているか
