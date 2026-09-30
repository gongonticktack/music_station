# Cloudflare Zaraz

Cloudflare Zarazに関する専門的なガイダンス。エッジでサードパーティ製ツールを読み込む、サーバーサイドのタグマネージャーです。

## Zarazとは？

Zarazは、サードパーティ製スクリプト（分析、広告、チャット、マーケティング）をCloudflareのエッジにオフロードし、サイトの速度、プライバシー、セキュリティを向上させます。クライアント側のパフォーマンスへの影響はありません。

**主な概念:**
- **サーバーサイドでの実行** - スクリプトはユーザーのブラウザーではなく、Cloudflare上で実行されます
- **単一のHTTPリクエスト** - すべてのツールを1つのエンドポイント経由で読み込みます
- **プライバシー優先** - サードパーティに送信するデータを制御できます
- **クライアント側JavaScriptのオーバーヘッドなし** - ブラウザーへの影響を最小限に抑えます

## クイックスタート

1. Cloudflareダッシュボードで、ドメイン > Zarazに移動します
2. 「Start setup」をクリックします
3. ツールを追加します（Google Analytics、Facebook Pixelなど）
4. トリガー（ツールを実行するタイミング）を設定します
5. トラッキングコードをサイトに追加します。

```javascript
// Track page view
zaraz.track('page_view');

// Track custom event
zaraz.track('button_click', { button_id: 'cta' });

// Set user properties
zaraz.set('userId', 'user_123');
```

## Zarazを使用する場面

**次の場合はZarazを使用します:**
- 複数のサードパーティ製ツール（分析、広告、マーケティング）を追加する
- サイトのパフォーマンスが重要である（クライアント側JavaScriptのオーバーヘッドがない）
- プライバシー規制への準拠が必要である（GDPR、CCPA）
- 技術者以外のチームがツールを管理する必要がある

**次の場合はWorkersを直接使用します:**
- カスタムのサーバーサイドトラッキングロジックを構築する
- データ処理を完全に制御する必要がある
- 複雑なバックエンドシステムと連携する
- Zarazのツールライブラリでは要件を満たせない

## このリファレンスの内容

| ファイル | 目的 | 読むタイミング |
|------|---------|--------------|
| [api.md](./api.md) | Web API、zarazオブジェクト、同意関連メソッド | トラッキング呼び出しを実装するとき |
| [configuration.md](./configuration.md) | ダッシュボードの設定、トリガー、ツール | 初期設定、ツールの追加時 |
| [patterns.md](./patterns.md) | SPA、Eコマース、Workerとの連携 | ベストプラクティス、一般的なシナリオ |
| [gotchas.md](./gotchas.md) | トラブルシューティング、制限、注意点 | 問題のデバッグ時 |

## 作業別の読む順序

| 作業 | 読むファイル |
|------|---------------|
| サイトに分析機能を追加する | README → configuration.md |
| カスタムイベントをトラッキングする | README → api.md |
| トラッキングの問題をデバッグする | gotchas.md |
| SPAをトラッキングする | api.md → patterns.md（SPAセクション） |
| Eコマースをトラッキングする | api.md#ecommerce → patterns.md#ecommerce |
| Workerと連携する | patterns.md#worker-integration |
| GDPRに準拠する | api.md#consent → configuration.md#consent |

## 判断フロー

```
What do you need?

├─ Track events in browser → api.md
│   ├─ Page views, clicks → zaraz.track()
│   ├─ User properties → zaraz.set()
│   └─ E-commerce → zaraz.ecommerce()
│
├─ Configure Zaraz → configuration.md
│   ├─ Add GA4/Facebook → tools setup
│   ├─ When tools fire → triggers
│   └─ GDPR consent → consent purposes
│
├─ Integrate with Workers → patterns.md#worker-integration
│   ├─ Enrich context → Context Enrichers
│   └─ Inject tracking → HTML rewriting
│
└─ Debug issues → gotchas.md
    ├─ Events not firing → troubleshooting
    ├─ Consent issues → consent debugging
    └─ Performance → debugging tools
```

## 主な機能

- **100種類以上の構築済みツール** - GA4、Facebook、Google Ads、TikTokなど
- **クライアントへの影響ゼロ** - ブラウザーではなくCloudflareのエッジで実行されます
- **プライバシー制御** - 同意管理、データフィルタリング
- **カスタムツール** - 独自システム向けのManaged Componentsを構築できます
- **Workerとの連携** - コンテキストの拡充、動的な値の計算
- **デバッグモード** - イベントをリアルタイムで検査できます

## リファレンス

- [Zaraz Docs](https://developers.cloudflare.com/zaraz/)
- [Web API](https://developers.cloudflare.com/zaraz/web-api/)
- [Managed Components](https://developers.cloudflare.com/zaraz/advanced/load-custom-managed-component/)

---

このスキルはZarazのみを対象としています。Workersの開発については、`cloudflare-workers`スキルを参照してください。
