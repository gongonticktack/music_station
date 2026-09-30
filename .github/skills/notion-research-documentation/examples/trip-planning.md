# 例：グループ旅行の調査と計画

**ユーザーの依頼**：「3月に友人たちと行く日本旅行を調査して計画してください。6人で、10日間の予定です」

## ワークフロー

### 1. 既存のメモを検索
```
Notion:notion-search
query: "Japan travel"
```
見つかったもの：日本旅行ガイド（友人作成）、東京のレストラン、京都の寺院ガイド

### 2. ヒントを取得して抽出
```
Notion:notion-fetch (3x)
```
**以前の旅行者から得た主な情報：**
- 最適な時期：3月～4月（桜の季節）
- 必見スポット：東京、京都、大阪
- 予算：1日あたり200～300ドル（中程度）
- 宿泊先は3か月前に予約
- JRパスは到着前に購入
- おすすめのレストラン：寿司大、一蘭ラーメン、つな八の天ぷら

### 3. 調査して情報を統合
以前の旅行者の知見に、以下の情報を組み合わせました。
- フライトの選択肢と価格
- 宿泊施設の種類（ホテル／旅館／Airbnb）
- 交通手段（JRパスが必須）
- 10日間の旅程構成
- 予算の内訳

### 4. 詳細な計画を作成
```
Notion:notion-create-pages
parent: { page_id: "travel-plans-parent-id" }
pages: [{
  properties: {
    title: "Japan Trip 2026 - March 15-25 (10 Days)"
  },
  content: "[Full trip plan with itinerary, budget, tips...]"
}]
```

## 出力例

```markdown
# Japan Trip 2026 - March 15-25 (10 Days)

## Trip Overview
**Dates**: March 15-25, 2026 (Cherry Blossom Season 🌸)
**Group**: 6 people | **Budget**: $3,000-4,000/person

## Itinerary Summary

**Days 1-3: Tokyo**
- Arrive, explore Shibuya, Harajuku, Shinjuku
- Visit Tsukiji Market, Imperial Palace, Sensoji Temple
- Experience Tokyo nightlife, teamLab Borderless

**Days 4-5: Hakone**  
- Day trip from Tokyo
- Hot springs, Mt. Fuji views, Lake Ashi cruise

**Days 6-8: Kyoto**
- Bullet train from Tokyo
- Fushimi Inari, Kinkaku-ji, Arashiyama Bamboo Grove
- Geisha district (Gion), traditional tea ceremony

**Days 9-10: Osaka + Depart**
- Osaka Castle, Dotonbori food district
- Nara day trip (deer park, Todai-ji Temple)
- Return flight from Osaka (KIX)

## Budget Breakdown (per person)
- **Flights**: $900-1,200 (round-trip)
- **Accommodations**: $700-1,000 (9 nights)
- **JR Pass**: $280 (7-day pass)
- **Food**: $500-700 ($50-70/day)
- **Activities**: $300-400
- **Local transport**: $100
**Total**: $2,780-3,680

## Key Bookings
- **Flights**: Book 3-4 months ahead
- **Hotels**: Book now (cherry blossom season)
  - Tokyo: Shinjuku area (2 nights) + Asakusa (1 night)
  - Kyoto: Gion area (3 nights)
  - Osaka: Namba area (2 nights)
- **JR Pass**: Order 2-3 weeks before travel
- **Restaurants**: Reserve 1 week ahead (Sushi Dai, high-end spots)

## Essential Tips
Source: <mention-page url="...">Japan Travel Guide</mention-page>
- Get pocket WiFi or eSIM on arrival
- Download: Google Translate, Hyperdia (train routes), Tabelog (restaurants)
- Cash-heavy country - withdraw at 7-Eleven ATMs
- Shoes off in temples, ryokans, some restaurants
- Trains extremely punctual - don't be late
- Learn basic phrases: arigatou, sumimasen, itadakimasu

## Packing List
- Comfortable walking shoes (10k+ steps/day)
- Light jacket (March 55-65°F)
- Backpack for day trips
- Cash pouch
- Portable charger

## Next Steps
- [ ] Book flights (target: <$1,100/person)
- [ ] Order JR Passes
- [ ] Book hotels (Tokyo → Kyoto → Osaka)
- [ ] Create shared expense tracker
- [ ] Schedule group planning call

## Sources
- <mention-page url="...">Japan Travel Guide</mention-page> (Sarah's 2024 trip)
- <mention-page url="...">Tokyo Restaurant Recommendations</mention-page>
- <mention-page url="...">Kyoto Temple Guide</mention-page>
```

## 主なポイント
- Notionにある以前の旅行者のメモを活用
- 個人の知見と調査結果を組み合わせた
- 予算の内訳を含む、実行しやすい旅程を作成
- 経験豊富な旅行者から得た実用的なヒントを含めた
- グループでの調整に向けて、次のステップを明確にした
