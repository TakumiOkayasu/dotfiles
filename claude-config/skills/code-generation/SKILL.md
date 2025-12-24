---
name: code-generation
description: スキャフォールディングやボイラープレート生成時に使用。
---

# Code Generation

## 鉄則

**繰り返し作業は自動化。生成コードも理解する。**

## ディレクトリ構造

```
src/
├── components/
├── hooks/
├── services/
├── utils/
└── types/
tests/
docs/
```

## テンプレート例

```typescript
// templates/component.tsx
import { FC } from 'react';

interface {{Name}}Props {}

export const {{Name}}: FC<{{Name}}Props> = () => {
  return <div>{{Name}}</div>;
};
```

## 生成スクリプト

```bash
#!/bin/bash
NAME=$1
mkdir -p "src/components/${NAME}"
cat > "src/components/${NAME}/${NAME}.tsx" << EOF
import { FC } from 'react';
export const ${NAME}: FC = () => <div>${NAME}</div>;
EOF
```

## plop.js(推奨)

```javascript
// plopfile.js
module.exports = function(plop) {
  plop.setGenerator('component', {
    prompts: [{ type: 'input', name: 'name' }],
    actions: [{
      type: 'add',
      path: 'src/components/{{pascalCase name}}.tsx',
      templateFile: 'templates/component.tsx.hbs'
    }]
  });
};
```

## 良い生成コード

```
✅ 人間が読める
✅ プロジェクト規約に従う
✅ テストも生成
✅ 最小限の依存
```
