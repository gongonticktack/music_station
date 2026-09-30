# CNI のパターン

概要については [README.md](README.md) を参照してください。

## 高可用性

**重要:** 初日から耐障害性を考慮して設計します。

**要件:**
- デバイスレベルで分散する（別々のハードウェアを使用）
- バックアップのインターネット接続（CNI に SLA はない）
- ネットワーク障害に強いロケーションを優先する
- 定期的にフェイルオーバーをテストする

**アーキテクチャ:**
```
Your Network A ──10G CNI v2──> CF CCR Device 1
                                     │
Your Network B ──10G CNI v2──> CF CCR Device 2
                                     │
                            CF Global Network (AS13335)
```

**容量計画:**
- すべてのリンクを考慮して計画する
- フェイルオーバー時のシナリオを考慮する
- 計画は利用者の責任

## パターン: Magic Transit + CNI v2

**ユースケース:** DDoS 対策、プライベート接続、GRE のオーバーヘッドなし。

```typescript
// 1. Create interconnect
const ic = await client.networkInterconnects.interconnects.create({
  account_id: id,
  type: 'direct',
  facility: 'EWR1',
  speed: '10G',
  name: 'magic-transit-primary',
});

// 2. Poll until active
const status = await pollUntilActive(id, ic.id);

// 3. Configure Magic Transit tunnel via Dashboard/API
```

**メリット:** 双方向とも MTU 1500、簡素化されたルーティング。

## パターン: マルチクラウド・ハイブリッド

**ユースケース:** Cloudflare と AWS/GCP のワークロードを接続する。

**AWS Direct Connect:**
```typescript
// 1. Order Direct Connect in AWS Console
// 2. Get LOA + VLAN from AWS
// 3. Send to CF account team (no API)
// 4. Configure static routes in Magic WAN

await configureStaticRoutes(id, {
  prefix: '10.0.0.0/8',
  nexthop: 'aws-direct-connect',
});
```

**GCP Cloud Interconnect:**
```
1. Get VLAN attachment pairing key from GCP Console
2. Create via Dashboard: Interconnects → Create → Cloud Interconnect → Google
   - Enter pairing key, name, MTU, speed
3. Configure static routes in Magic WAN (BGP routes from GCP ignored)
4. Configure custom learned routes in GCP Cloud Router
```

**注:** Dashboard でのみ操作可能。API/SDK はまだサポートされていません。

## パターン: 複数ロケーションでの HA

**ユースケース:** 稼働率 99.99% 以上。

```typescript
// Primary (NY)
const primary = await client.networkInterconnects.interconnects.create({
  account_id: id,
  type: 'direct',
  facility: 'EWR1',
  speed: '10G',
  name: 'primary-ewr1',
});

// Secondary (NY, different hardware)
const secondary = await client.networkInterconnects.interconnects.create({
  account_id: id,
  type: 'direct',
  facility: 'EWR2',
  speed: '10G',
  name: 'secondary-ewr2',
});

// Tertiary (LA, different geography)
const tertiary = await client.networkInterconnects.interconnects.create({
  account_id: id,
  type: 'partner',
  facility: 'LAX1',
  speed: '10G',
  name: 'tertiary-lax1',
});

// BGP local preferences:
// Primary: 200
// Secondary: 150
// Tertiary: 100
// Internet: Last resort
```

## パターン: パートナーインターコネクト（Equinix）

**ユースケース:** コロケーションなしで迅速に導入する。

**設定手順:**
1. Equinix Fabric Portal で仮想回線を注文する
2. 接続先に Cloudflare を選択する
3. 施設を選択する
4. 詳細を CF アカウントチームに送る
5. CF がポータルで承認する
6. BGP を設定する

**API による自動化は不可** – パートナーポータルは個別に管理されます。

## フェイルオーバーとセキュリティ

**フェイルオーバーのベストプラクティス:**
- 優先順位に BGP ローカル優先度を使う
- 高速検出のため BFD を設定する（v1）
- トラフィックを切り替えて定期的にテストする
- 運用手順書を作成する

**セキュリティ:**
- BGP パスワード認証
- BGP ルートフィルタリング
- 想定外のルートを監視する
- DDoS/脅威対策に Magic Firewall を使う
- API トークンの権限を最小限にする
- 認証情報を定期的にローテーションする

## 選定基準

| 要件 | 推奨 |
|-------------|-------------|
| CF とコロケーションしている | Direct |
| コロケーションしていない | Partner |
| AWS/GCP のワークロード | Cloud |
| 双方向とも MTU 1500 | v2 |
| VLAN タグ付け | v1 |
| パブリックピアリング | v1 |
| 最も簡単な設定 | v2 |
| BFD による高速フェイルオーバー | v1 |
| LACP による束ね | v1 |

## リソース

- [Magic Transit Docs](https://developers.cloudflare.com/magic-transit/)
- [Magic WAN Docs](https://developers.cloudflare.com/magic-wan/)
- [Argo Smart Routing](https://developers.cloudflare.com/argo/)
