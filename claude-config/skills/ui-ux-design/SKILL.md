---
name: ui-ux-design
description: Use when implementing UI or improving UX - covers accessibility and responsive design.
---

# UI/UX Design

## 鉄則

**ユーザーが最小の摩擦で目的を達成できるようにする。**

## アクセシビリティ必須事項

```html
<!-- 画像: alt必須 -->
<img src="chart.png" alt="Q4売上25%増加">

<!-- ボタン: セマンティック要素 -->
<button type="submit">送信</button>  <!-- ✅ -->
<div onclick="submit()">送信</div>   <!-- ❌ -->

<!-- フォーム: ラベル紐付け -->
<label for="email">メール</label>
<input id="email" type="email">
```

### チェック項目

- コントラスト比 4.5:1以上
- キーボードのみで操作可能
- タッチターゲット 44x44px以上
- 色だけに頼らない情報伝達

## レスポンシブ

```css
/* モバイルファースト */
.container { width: 100%; }

@media (min-width: 768px) {
  .container { width: 750px; }
}
```

## ユーザビリティ原則

1. **可視性**: 現在の状態が見える
2. **フィードバック**: 操作に即座に反応
3. **一貫性**: 同じ操作は同じ結果
4. **エラー防止**: 間違いにくいUI
5. **認知負荷軽減**: 一度に見せる情報を絞る

## フォーム設計

```
✅ ラベルは入力欄の上
✅ エラーは該当欄の近くに表示
✅ 必須項目は明示
✅ 送信ボタンは目立つ位置
```

## パフォーマンスUX

- ローディング中はスケルトン表示
- 楽観的更新(即座に反映、失敗時ロールバック)
- 画像は遅延読み込み
