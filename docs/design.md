# HabitPet 設計書（2026-04 改訂）

## 1. 方針

- リリース前のため、データ後方互換は考慮しない。
- 永続化は `SQLiteData` のみを利用する。
- App / Widget は App Group 共有DBを正本とする。
- UIは日本語中心で実装し、文言は将来の多言語化を前提にキー管理する。

## 2. ドメイン仕様

### 2.1 習慣（Habit）

`mode` は廃止し、仕様を「減らす」に統一する。

必須項目:

- `id: UUID`
- `kind: HabitKind`  
  - `nonSmoking`（禁煙）
  - `nonAlcohol`（禁酒）
  - `nonGambling`（脱ギャンブル）
  - `other`（その他）
- `character: CharacterType`
- `name: String?`（任意）
- `goalDeadline: String`（`yyyy-MM-dd`、デフォルトは1週間後）
- `goalPerDay: Int`（1日あたり本数/杯数、デフォルト `0`）
- `isArchived: Bool`
- `sortOrder: Int`
- `createdAt: Date`
- `updatedAt: Date`

削除した項目:

- `mode`
- `countUnit`
- `baselineSource`
- `baselineManualValue`
- `goalType`
- `goalValue`
- `goalDate`

### 2.2 イベント（HabitEvent）

既存のイベントは継続利用する。

- `id: UUID`
- `habitID: UUID`
- `delta: Int`
- `source: HabitEventSource` (`app` / `widget`)
- `occurredAt: Date`
- `revokedAt: Date?`
- `createdAt: Date`

## 3. 習慣作成フロー

作成時の入力順は以下に固定する。

1. `kind`（種類）
2. `character`（キャラクター）
3. `name`（任意）

同時に目標は以下を入力可能にする。

- `goalDeadline`（何日まで）
- `goalPerDay`（1日あたり本数/杯数）

初期値:

- `goalDeadline` = 今日から7日後
- `goalPerDay` = `0`

また、作成時のみ「昨日の記録」を入力可能にする。  
保存時に「昨日」の `HabitEvent` として登録する（初回作成時のみ）。

## 4. キャラクター設計

### 4.1 Enum管理

キャラクターIDの文字列直入力は廃止し、`CharacterType` enum で管理する。  
UI上は enum の表示名（タイトル）を表示する。

### 4.2 kind別デザイン方針

キャラクターは `kind` ごとに別デザインを用意する。

アセット命名:

- `character_<kind>_<character>_lv<level>`
- 例: `character_nonSmoking_hamster_lv1`

`level` は 1...5 を維持する。

## 5. DB初期化

- migration は `Create tables` のみ。
- スキーマ変更時は `eraseDatabaseOnSchemaChange`（DEBUG）で再生成する。
- 既存データ移行処理は実装しない。

## 6. Presentation方針

- ViewModelは `@MainActor @Observable final class`。
- 読み取りは `@FetchAll` / `@FetchOne`。
- 書き込みは UseCase -> DataStore のみ。
- Toolbarは SFSymbol ベースで構成する。

## 7. Widget連携

- Widgetの表示値・画像は共有DB正本から取得する。
- App側の更新後は `WidgetCenter.shared.reloadTimelines` を呼び、反映を即時化する。
