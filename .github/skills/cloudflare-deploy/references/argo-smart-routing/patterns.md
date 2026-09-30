# 統合パターン

## Argo と Tiered Cache の有効化

```typescript
async function enableOptimalPerformance(client: Cloudflare, zoneId: string) {
  await Promise.all([
    client.argo.smartRouting.edit({ zone_id: zoneId, value: 'on' }),
    client.argo.tieredCaching.edit({ zone_id: zoneId, value: 'on' }),
  ]);
}
```

**フロー:** ビジター → エッジ（下位ティア） → [キャッシュミス] → 上位ティア → [キャッシュミス + Argo] → オリジン

**効果:** Argo によるレイテンシ約30%削減 + Tiered Cache によるオリジン負荷50～80%軽減

## 使用状況の分析（GraphQL）

```graphql
query ArgoAnalytics($zoneTag: string!) {
  viewer {
    zones(filter: { zoneTag: $zoneTag }) {
      httpRequestsAdaptiveGroups(limit: 1000) {
        sum { argoBytes, bytes }
      }
    }
  }
}
```

**請求:** 約$0.10/GB。DDoS によって軽減されたトラフィックと WAF によってブロックされたトラフィックは請求対象外です。

## Spectrum TCP の統合

HTTP 以外のトラフィック（データベース、ゲームサーバー、IoT）に対して Argo を有効化します:

```typescript
// Update existing app
await client.spectrum.apps.update(appId, { zone_id: zoneId, argo_smart_routing: true });

// Create new app with Argo
await client.spectrum.apps.create({
  zone_id: zoneId,
  dns: { type: 'CNAME', name: 'tcp.example.com' },
  origin_direct: ['tcp://origin.example.com:3306'],
  protocol: 'tcp/3306',
  argo_smart_routing: true,
});
```

**用途:** MySQL／PostgreSQL（3306／5432）、ゲームサーバー、MQTT（1883）、SSH（22）

## 事前検証

```typescript
async function validateArgoEligibility(client: Cloudflare, zoneId: string) {
  const status = await client.argo.smartRouting.get({ zone_id: zoneId });
  const zone = await client.zones.get({ zone_id: zoneId });
  
  const issues: string[] = [];
  if (!status.editable) issues.push('Zone not editable');
  if (['free', 'pro'].includes(zone.plan.legacy_id)) issues.push('Requires Business+ plan');
  if (zone.status !== 'active') issues.push('Zone not active');
  
  return { canEnable: issues.length === 0, issues };
}
```

## 有効化後の検証

```typescript
async function verifyArgoEnabled(client: Cloudflare, zoneId: string): Promise<boolean> {
  await new Promise(r => setTimeout(r, 2000)); // Wait for propagation
  const status = await client.argo.smartRouting.get({ zone_id: zoneId });
  return status.value === 'on';
}
```

## セットアップ全体のパターン

```typescript
async function setupArgo(client: Cloudflare, zoneId: string) {
  // 1. Validate
  const { canEnable, issues } = await validateArgoEligibility(client, zoneId);
  if (!canEnable) throw new Error(issues.join(', '));
  
  // 2. Enable both features
  await Promise.all([
    client.argo.smartRouting.edit({ zone_id: zoneId, value: 'on' }),
    client.argo.tieredCaching.edit({ zone_id: zoneId, value: 'on' }),
  ]);
  
  // 3. Verify
  const [argo, cache] = await Promise.all([
    client.argo.smartRouting.get({ zone_id: zoneId }),
    client.argo.tieredCaching.get({ zone_id: zoneId }),
  ]);
  
  return { argo: argo.value === 'on', tieredCache: cache.value === 'on' };
}
```

**併用する場合:** トラフィックの多いサイト（月間1TB超）、世界各地にユーザーがいるサイト、キャッシュ可能なコンテンツがあるサイト。
