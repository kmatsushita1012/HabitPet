# HabitPet Design (SQLiteData First)

## 1. 目的

この設計は HabitPet を Point-Free SQLiteData ベースで実装するための唯一の基準とする。
画面は SwiftUI `View + ViewModel`、バックエンドは `UseCase + DataStore (+ optional Client/Manager)` を採用する。

## 2. 非交渉ルール

1. 永続化は SQLiteData + GRDB を使う。
2. ViewModel は `@MainActor @Observable final class` で定義する。
3. ViewModel の DB 読み取りは `@FetchAll` / `@FetchOne` を基本とする（`HabitEditViewModel` は initializer 受け取りを許可）。
4. `@FetchAll` / `@FetchOne` には必ず `@ObservationIgnored` を付ける。
5. DB 書き込みは DataStore のみが担当する。
6. DataStore の公開 API は `create` / `update` / `delete` / `upsert(optional)` のみ。
7. DataStore に fetch API を作らない。
8. View から ViewModel への入力は Action メソッドのみ。
9. Action メソッドはすべて `Void` return。
10. App 起動時に migration で `CREATE TABLE` を実行し、`defaultDatabase` を 1 回だけ準備する。

## 3. レイヤー構成

### 3.1 Presentation

- View: 表示責務のみ。ビジネスロジックと DB ロジックを持たない。
- ViewModel: UI State / Entity State / Action / Utility を持つ。

### 3.2 Domain

- UseCase: ユースケース単位の業務ロジックを担当。

### 3.3 Data

- DataStore: 永続エンティティへの書き込み専用。
- `@Table`: 永続エンティティ。
- `@Selection`: JOIN / 集計 / 表示用射影。

## 4. ドメインモデル

## 4.1 永続エンティティ（@Table）

- `Habit`
- `HabitEvent`

### Habit

- `id: UUID` (PK)
- `name: String`
- `modeRaw: String`
- `characterIDRaw: String`
- `countUnitRaw: String`
- `baselineSourceRaw: String`
- `baselineManualValue: Double?`
- `goalTypeRaw: String`
- `goalValue: Int?`
- `goalDate: String?` (`yyyy-MM-dd`)
- `isArchived: Bool`
- `sortOrder: Int`
- `createdAt: Date`
- `updatedAt: Date`

### HabitEvent

- `id: UUID` (PK)
- `habitID: UUID` (FK -> Habit.id)
- `delta: Int` (`+1` / `-1`)
- `sourceRaw: String` (`app` / `widget`)
- `occurredAt: Date`
- `revokedAt: Date?` (Undo pop)
- `createdAt: Date`

## 4.2 読み取りモデル（@Selection）

- `HabitCardSelection`: メインページ表示用（習慣 + 当日値 + 状態レベル）
- `HabitTodayUsageSelection`: `todayUsage = SUM(delta)`
- `HabitBaselineSelection`: 直近期間の基準値
- `HabitStateSelection`: `todayUsage / baseline` から表示状態を算出
- `HabitRecentEventSelection`: 履歴表示用（`revokedAt == nil` のみ）

## 4.3 固定マスタ（非永続）

- `CharacterMaster` はアプリ内定数で管理する。
- `character_<id>_lv<1...5>` 命名でアセット解決する。

## 5. DB 初期化・マイグレーション

```swift
import SQLiteData

func appDatabase() throws -> any DatabaseWriter {
    let database = try defaultDatabase(configuration: Configuration())

    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create tables") { db in
        try #sql("""
            CREATE TABLE "habit" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "name" TEXT NOT NULL,
              "modeRaw" TEXT NOT NULL,
              "characterIDRaw" TEXT NOT NULL,
              "countUnitRaw" TEXT NOT NULL,
              "baselineSourceRaw" TEXT NOT NULL,
              "baselineManualValue" REAL,
              "goalTypeRaw" TEXT NOT NULL,
              "goalValue" INTEGER,
              "goalDate" TEXT,
              "isArchived" INTEGER NOT NULL,
              "sortOrder" INTEGER NOT NULL,
              "createdAt" TEXT NOT NULL,
              "updatedAt" TEXT NOT NULL
            ) STRICT
            """).execute(db)

        try #sql("""
            CREATE TABLE "habitEvent" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "habitID" TEXT NOT NULL,
              "delta" INTEGER NOT NULL,
              "sourceRaw" TEXT NOT NULL,
              "occurredAt" TEXT NOT NULL,
              "revokedAt" TEXT,
              "createdAt" TEXT NOT NULL
            ) STRICT
            """).execute(db)

        try #sql("""
            CREATE INDEX "idx_habitEvent_habitID_occurredAt"
            ON "habitEvent"("habitID", "occurredAt")
            """).execute(db)

        try #sql("""
            CREATE INDEX "idx_habitEvent_habitID_revokedAt"
            ON "habitEvent"("habitID", "revokedAt")
            """).execute(db)
    }

    try migrator.migrate(database)
    return database
}
```

アプリ起動時:

```swift
@main
struct HabitPetApp: App {
    init() {
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Scene {
        WindowGroup { MainPagerView() }
    }
}
```

## 6. DataStore 設計（書き込み専用）

- `HabitDataStore`
  - `create(...)`
  - `update(...)`
  - `delete(id:)`
  - `upsert(...)` (必要時のみ)
- `HabitEventDataStore`
  - `create(...)`
  - `update(...)`
  - `delete(id:)`
  - `revokeLast(habitID:count:now:)` (Undo の実装)

禁止:

- `find`, `fetch`, `list` などの読み取り API を DataStore に追加しない。

## 7. UseCase 設計

- `CreateHabitUseCase`
- `UpdateHabitUseCase`
- `ArchiveHabitUseCase`
- `RecordHabitDeltaUseCase`
- `UndoHabitDeltaUseCase`
- `ResolveHabitStateUseCase`

実装方針:

- `swift-dependencies` を使う。
- プロトコルと本実装は同一ファイルに定義する。
- バックエンドの protocol は `Sendable`。
- 共有可変状態が必要な箇所のみ `actor` を使う。

## 8. ViewModel 契約

すべての ViewModel は次の順序で定義する。

1. UI State
2. Entity State（基本は `@ObservationIgnored @FetchAll/@FetchOne`。Edit は initializer 入力を保持）
3. Action methods (`Void`)
4. Utility / private helper

## 8.1 MainPagerViewModel

UI State:

- `selectedPageIndex: Int`
- `isEditPresented: Bool`
- `isCreatePresented: Bool`

Entity State:

- `@FetchAll<Habit>(...) var habits`

Action:

- `onAppear()`
- `onPageChanged(_:)`
- `onTapEdit()`
- `onTapAddPage()`

## 8.2 HabitPageViewModel

UI State:

- `isHistoryPresented: Bool`
- `isSettingsPresented: Bool`

Entity State:

- `@FetchOne<Habit>(...) var habit`
- `@FetchOne<HabitStateSelection>(...) var state`
- `@FetchAll<HabitRecentEventSelection>(...) var recentEvents`

Action:

- `onTapPlus(source:)`
- `onTapMinus(source:)`
- `onTapUndo(count:)`
- `onTapEditHabit()`

## 8.3 HabitEditViewModel

UI State:

- `editingHabit: Habit?` (initializer で受け取り、画面中は UI State として保持)
- `nameInput: String`
- `selectedModeRaw: String`
- `selectedCharacterIDRaw: String`
- `baselineInput: String`
- `goalTypeRaw: String`
- `goalValueInput: String`
- `goalDate: Date?`
- `isArchiveAlertPresented: Bool`

Initializer:

- `init(habit: Habit?)`

Action:

- `onAppearForCreate()`
- `onChangeName(_:)`
- `onChangeMode(_:)`
- `onChangeCharacter(_:)`
- `onChangeBaseline(_:)`
- `onTapSave()` (`editingHabit` の有無で create/update を分岐し、DataStore 経由で保存)
- `onTapArchive()`

## 9. View 設計方針

- View は state 描画 + action dispatch だけを行う。
- 画面で DB へ直接アクセスしない。
- `Task` 起点の非同期呼び出しは ViewModel 内で実施する。

## 10. Undo (Pop) 仕様

- Undo は削除ではなく `HabitEvent.revokedAt` を設定して無効化する。
- 集計・状態・履歴は常に `revokedAt == nil` を対象にする。
- `count` 件の Undo は「最新有効イベントから順に `count` 件」を無効化する。

## 11. 画面一覧

1. `OnboardingView`
2. `MainPagerView`
3. `HabitPageView`
4. `HabitEditView`
5. `HistorySheetView`
6. `SettingsView`
7. `WidgetHabitPetView`

## 12. チェックリスト

1. ViewModel は `@MainActor @Observable final class` か。
2. Fetch property に `@ObservationIgnored` が付いているか。
3. View から ViewModel への入力が Action メソッドだけか。
4. Action メソッドは `Void` return か。
5. DataStore が書き込み API のみか。
6. `CREATE TABLE` migration が起動時に実行されるか。
7. `defaultDatabase` の初期化が process 内で 1 回だけか。
