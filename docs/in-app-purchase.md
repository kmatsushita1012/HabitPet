# 📱 悪習慣改善アプリ 企画書（課金設計）

## コンセプト

可愛いキャラクターをパートナーとして選択し、ユーザーの悪習慣（飲酒・喫煙など）を一緒に改善していくアプリ。

- 習慣の状態に応じてキャラクターの体調・表情が変化
- ユーザーの行動がキャラに影響することで感情的な動機づけを促す
- キャラは「消費物」ではなく「伴走者」

---

## キャラクター設計

- 初期キャラ：2体（無料）
- 追加キャラ：課金で解放

### 特徴

- 統一プロンプトによる一貫したビジュアル
- 動物違いによるバリエーション展開
- 各キャラに性格・リアクション差分あり（テキストベース）

---

## 課金設計

### 基本方針

- シンプルな2プラン制
- 運用コストを増やさない（サブスク・限定要素なし）
- キャラ選択体験を阻害しない導線設計

---

## プラン構成

### ① 消費型課金（都度購入）

- **価格**：200円
- **内容**：キャラクター1体を個別解放

#### 想定ユーザー

- 特定のキャラだけ欲しいライト層
- とりあえず試したいユーザー

### ② 使い放題プラン（買い切り）

- **価格**：500円
- **内容**：全キャラクター解放

#### 想定ユーザー

- 継続利用ユーザー
- キャラ選択を自由に楽しみたい層

---

## 課金導線設計（重要）

### キャラ選択フロー

1. キャラ一覧表示（課金キャラも含めて表示）
2. 課金キャラも選択・プレビュー可能
3. 習慣にキャラを紐づけて「保存」するタイミングで課金導線表示

### ポイント

- 「選んでから課金」にすることで心理ハードルを下げる
- キャラへの感情移入を先に発生させる
- UXを損なわず自然に課金へ誘導

---

## UI/UX方針

- 未解放キャラも通常キャラと同様に表示（ロックアイコンなどで区別）
- プレビュー時は制限なしで体験可能
- 課金は"確定時のみ"発生

---

## エフェクト方針

- エフェクトによる課金差別化は行わない
- キャラクター自体の魅力（見た目・性格・リアクション）で勝負

---

## 収益構造

- **ライト層**：200円で単体キャラ購入
- **コア層**：500円で全解放

→ シンプルかつ広い層をカバー

---

## 強み

- シンプルな課金設計で離脱が少ない
- 運用コストが極めて低い
- コンセプト（キャラとの共生）と完全一致
- キャラ追加による拡張性あり

---

## 今後の拡張余地（任意）

- キャラ追加（低コストで継続展開可能）
- キャラごとのセリフ・リアクション強化

---

## まとめ

本設計は以下を優先した、シンプルかつ実用的な課金モデルである。

- UXの軽さ
- コンセプトの一貫性
- 運用のしやすさ

---

## 実装計画（StoreKit 2）

### 0. 実装スコープ定義

- 課金種別は **消費型 + 非消耗型** の2つで構成
- 商品は2系統
- 単体解放: `character.unlock.ticket`（消費型1商品）
- 全解放: `characters.all_access`
- 単体解放は「購入直後に現在選択中キャラへ付与」
- 全解放購入済みの場合は、単体解放判定より常に優先

### 1. App Store Connect 設定

- In-App Purchase を作成（審査提出可能な状態まで）
- ローカライズ文言を準備（表示名・説明）
- 価格設定
- 単体解放チケット: 200円
- 全解放: 500円
- プロダクトIDを `docs` とコード内定数で同期管理

### 2. ドメインモデル追加（Shared）

- 課金関連の最小モデルを追加
- `PurchaseProduct`: productId / 種別（singleTicket, allAccess）
- `EntitlementState`: allAccessPurchased / purchasedCharacterIds
- `PurchaseResult`: success / pending / cancelled / failed
- 「このキャラを保存可能か」を判定するユースケースを追加

### 3. StoreKit クライアント実装（Infrastructure）

- `StoreKitClient`（Protocol）を定義し、依存注入可能にする
- 主な責務
- 商品情報取得（`Product.products(for:)`）
- 購入実行（`product.purchase()`）
- トランザクション検証（`VerificationResult`）
- 復元（`AppStore.sync()`）
- 購入状態の監視（`Transaction.currentEntitlements` + updates）
- 単体チケット成功時に「選択中キャラID」をローカル付与して保存
- 検証済みトランザクションのみを有効化し、未検証は無視

### 4. 永続化と起動時同期

- 端末内に「解放状態キャッシュ」を保存（表示高速化用）
- 起動時フロー
- キャッシュ読込 → StoreKit の current entitlements で再同期 → 差分反映
- オフライン時はキャッシュを使い、オンライン復帰時に再同期

### 5. UI導線実装（既存フローに統合）

- キャラ一覧
- 未解放キャラも通常表示 + ロックバッジ表示
- プレビューは全キャラ許可
- 保存ボタン押下時
- 解放済み: そのまま保存
- 未解放: 購入モーダル表示（単体200円 / 全解放500円）
- 購入成功時はモーダルを閉じ、保存処理を再実行
- キャンセル時は保存せず一覧へ戻す
- 設定画面などに「購入を復元」を追加

### 6. 仕様ルール（競合・境界条件）

- 全解放購入済みなら単体購入ボタンは非表示または無効化
- 単体購入後に全解放購入した場合はそのまま全解放へ昇格
- 保留（Ask to Buy 等）は `pending` としてUIで案内
- 価格取得失敗時はリトライ導線を表示し、保存はブロック

### 7. テスト計画

- Unit Test（Shared/UseCase）
- 保存可否判定（未購入 / 単体購入済み / 全解放購入済み）
- 優先順位（全解放 > 単体）
- 購入結果分岐（success/pending/cancelled/failed）
- Integration Test（StoreKit Configuration）
- 単体チケット購入成功で保存対象キャラのみ解放
- 全解放購入成功で全キャラ解放
- 復元で状態復帰
- UI Test
- 未解放キャラ選択→保存で購入モーダル表示
- 購入成功後に保存完了まで遷移

### 8. リリース前チェック

- App Store Review 向け
- 復元導線が画面上で明確
- 利用規約・プライバシーポリシー導線を課金画面から到達可能
- 価格・商品説明・スクリーンショットの整合性確認
- 実機 Sandbox で購入/復元/再インストール後復帰を確認

### 9. 実装順（推奨）

1. Product ID（単体チケット1種 + 全解放1種）と課金モデル定義
2. StoreKitClient と Entitlement 同期
3. 保存時ゲート（未解放時モーダル）
4. 復元導線
5. テスト追加（Unit → Integration → UI）
6. 審査チェック項目の最終確認

---

## ASC設定詳細設計（実装準拠）

この章は、現在の実装コードに合わせた App Store Connect 設定の確定値。

- 対象アプリ Bundle ID: `com.studiomk.HabitPet`
- 単体解放チケット Product ID: `habitpet.character.unlock.ticket`
- 全解放 Product ID: `habitpet.characters.all_access`

### 1. IAP商品定義（必須）

#### A. 単体解放チケット

- Type: `CONSUMABLE`
- Product ID: `habitpet.character.unlock.ticket`
- Reference Name: `Character Unlock Ticket`
- 価格: 200円相当のティア
- 用途: 購入直後に「現在選択中キャラ」を1体解放
- 注意: キャラごとに Product ID は作らない（この1商品のみ）

#### B. 全キャラ解放

- Type: `NON_CONSUMABLE`
- Product ID: `habitpet.characters.all_access`
- Reference Name: `All Characters Access`
- 価格: 500円相当のティア
- 用途: すべての課金対象キャラを永続解放

### 2. ローカライズ定義（ja-JP / en-US）

#### A. `habitpet.character.unlock.ticket`

- `ja-JP` 表示名: `キャラ解放チケット`
- `ja-JP` 説明: `選択中のキャラクターを1体解放します。`
- `en-US` 表示名: `Character Unlock Ticket`
- `en-US` 説明: `Unlocks one selected character immediately.`

#### B. `habitpet.characters.all_access`

- `ja-JP` 表示名: `全キャラ解放`
- `ja-JP` 説明: `すべてのキャラクターを永続的に解放します。`
- `en-US` 表示名: `All Characters Access`
- `en-US` 説明: `Permanently unlocks all characters.`

### 3. 価格・提供地域

- Base Territory: `Japan`
- 単体解放チケット: 200円相当の価格ティア
- 全キャラ解放: 500円相当の価格ティア
- Availability: アプリ提供地域と揃える（基本は全地域）
- 運用ルール:
- 先に `pricing summary` と `availability` を readback してから submit
- 価格改定時は両商品を同一リリース単位で更新

### 4. 審査提出に必要なASC設定

- 各 IAP を `Ready to Submit` まで入力
- 各 IAP に審査用スクリーンショットを登録
- アプリ審査提出時に IAP を紐付けて同時提出
- App Review Notes に課金導線を明記
- 導線: `キャラ選択 → 保存タップ → 購入ダイアログ`
- 復元導線: `購入ダイアログ内「購入を復元」`

### 5. App Review Notes テンプレート（提出時に使用）

- 本アプリの課金は2種類です:
- `habitpet.character.unlock.ticket`（Consumable）: 購入直後に選択中キャラ1体を解放
- `habitpet.characters.all_access`（Non-Consumable）: すべての課金対象キャラを永続解放
- 購入導線は「キャラ選択後、保存時」に表示されます。
- 復元は購入ダイアログ内の「購入を復元」から実行できます。
- 無料キャラ（初期2体）は購入不要です。

### 6. ASC CLI運用コマンド（再現用）

前提:

- `APP_ID` は ASC上のアプリID（数値）を使う

```bash
asc auth status
asc apps view --id "$APP_ID" --output json --pretty
asc iap list --app "$APP_ID" --output json --pretty
```

単体解放チケット（Consumable）作成:

```bash
asc iap setup \
  --app "$APP_ID" \
  --type CONSUMABLE \
  --reference-name "Character Unlock Ticket" \
  --product-id "habitpet.character.unlock.ticket" \
  --locale "ja-JP" \
  --display-name "キャラ解放チケット" \
  --description "選択中のキャラクターを1体解放します。" \
  --price "200" \
  --base-territory "Japan"
```

全キャラ解放（Non-Consumable）作成:

```bash
asc iap setup \
  --app "$APP_ID" \
  --type NON_CONSUMABLE \
  --reference-name "All Characters Access" \
  --product-id "habitpet.characters.all_access" \
  --locale "ja-JP" \
  --display-name "全キャラ解放" \
  --description "すべてのキャラクターを永続的に解放します。" \
  --price "500" \
  --base-territory "Japan"
```

英語ローカライズ追加:

```bash
asc iap localizations create \
  --iap-id "$IAP_ID" \
  --locale "en-US" \
  --name "Character Unlock Ticket" \
  --description "Unlocks one selected character immediately."
```

```bash
asc iap localizations create \
  --iap-id "$IAP_ID" \
  --locale "en-US" \
  --name "All Characters Access" \
  --description "Permanently unlocks all characters."
```

最終確認と提出:

```bash
asc iap pricing summary --app "$APP_ID" --output json --pretty
asc iap submit --iap-id "$IAP_ID" --confirm
```
