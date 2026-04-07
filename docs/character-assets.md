# Character Asset追加ガイド（MVP）

このガイドは `ios-sqlitedata-app` 準拠の現行実装で、キャラ画像を追加するための手順。

## 1. 前提

- 動物種別は `CharacterID`（例: `hamster`, `rabbit`）で表現する。
- 状態段階は `HabitState.level` の 1..5 で表現する。
- 画像選択は `CharacterAppearanceResolver` が `CharacterID x Lv` で決める。

## 2. 命名規約

アセット名は以下で固定:

`character_<characterID>_lv<level>`

例:
- `character_hamster_lv1`
- `character_hamster_lv2`
- `character_hamster_lv3`
- `character_hamster_lv4`
- `character_hamster_lv5`
- `character_rabbit_lv1`
- `character_rabbit_lv2`
- `character_rabbit_lv3`
- `character_rabbit_lv4`
- `character_rabbit_lv5`

## 3. 画像追加手順

1. Xcodeで `Assets.xcassets` を開く。
2. キャラクターごとにフォルダを作成する（例: `character_hamster/`, `character_rabbit/`）。
3. 上記命名規約で Image Set を作成し、対応するキャラクターフォルダ配下に配置する。
4. 各 Image Set に 1x/2x/3x を配置する（最低2x/3x推奨）。
5. `Render As` は `Default` のままにする。
6. iOSシミュレータで表示を確認する。

## 4. 動作確認ポイント

- `HabitPageView` で Lv変化時に画像が切り替わること。
- 画像未追加の組み合わせはフォールバック絵文字が出ること。
- `CharacterID` に新種を追加した場合、Lv1..Lv5 すべての命名を守ること。

## 5. 新しい動物を追加する場合

1. `CharacterID` に case を追加する。
2. `CharacterCatalog.all` にマスタを追加する。
3. `CharacterAppearanceResolver` のフォールバックを追加する。
4. `character_<newID>_lv1..5` のアセットを追加する。
