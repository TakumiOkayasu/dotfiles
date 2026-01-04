# Dependency Injection パターンカタログ

## 概要

依存性注入(DI)の様々なアプローチと、状況に応じた選択基準。

## パターンスペクトラム

### 🟢 Conservative

#### Constructor Injection(手動)

```python
# Python
class UserService:
    def __init__(self, repository: UserRepository, logger: Logger):
        self.repository = repository
        self.logger = logger

# 使用側
service = UserService(
    repository=PostgresUserRepository(db),
    logger=FileLogger("user_service.log")
)
```

```java
// Java
public class UserService {
    private final UserRepository repository;
    private final Logger logger;
    
    public UserService(UserRepository repository, Logger logger) {
        this.repository = repository;
        this.logger = logger;
    }
}
```

**得られるもの:**
- シンプルで理解しやすい
- フレームワーク非依存
- テスト時にモック注入が容易

**失うもの:**
- 依存が多いと配線コードが冗長
- 依存グラフの管理が手動

**適用条件:**
- 小規模プロジェクト
- 依存関係が少ない(5個以下)
- フレームワークを入れたくない

**アンチパターン:**
- 大規模プロジェクトで手動配線が複雑化

#### Service Locator

```python
# Python
class ServiceLocator:
    _services = {}
    
    @classmethod
    def register(cls, interface, implementation):
        cls._services[interface] = implementation
    
    @classmethod
    def get(cls, interface):
        return cls._services[interface]

# 登録
ServiceLocator.register(UserRepository, PostgresUserRepository(db))

# 使用
class UserService:
    def __init__(self):
        self.repository = ServiceLocator.get(UserRepository)
```

**得られるもの:**
- 配線コードが簡潔
- 動的な依存解決

**失うもの:**
- 依存関係が隠蔽される
- テストが複雑化
- グローバル状態への依存

**適用条件:**
- レガシーコードへの段階的DI導入
- プラグインシステム

**アンチパターン:**
- 新規プロジェクトでの採用(隠れた依存が問題に)



### 🟡 Pragmatic

#### DIコンテナ(フレームワーク)

```python
# Python (dependency-injector)
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()
    
    database = providers.Singleton(
        Database,
        connection_string=config.db.connection_string
    )
    
    user_repository = providers.Factory(
        PostgresUserRepository,
        database=database
    )
    
    user_service = providers.Factory(
        UserService,
        repository=user_repository
    )
```

```java
// Java (Spring)
@Service
public class UserService {
    private final UserRepository repository;
    
    @Autowired
    public UserService(UserRepository repository) {
        this.repository = repository;
    }
}
```

**得られるもの:**
- 依存グラフの自動解決
- ライフサイクル管理(Singleton, Scoped等)
- 設定の外部化

**失うもの:**
- フレームワークへの依存
- マジック感(何が注入されるか分かりにくい)
- 起動時間の増加

**適用条件:**
- 中〜大規模プロジェクト
- 依存関係が複雑
- チームがフレームワークに習熟

**アンチパターン:**
- 小規模プロジェクトでのオーバーエンジニアリング
- 組み込み/メモリ制約環境

#### Pure DI(Composition Root)

```python
# Python
# composition_root.py
def create_application():
    # 全ての依存をここで組み立て
    config = load_config()
    
    database = Database(config.db_connection)
    
    user_repository = PostgresUserRepository(database)
    order_repository = PostgresOrderRepository(database)
    
    email_service = SmtpEmailService(config.smtp)
    
    user_service = UserService(user_repository, email_service)
    order_service = OrderService(order_repository, user_service)
    
    return Application(user_service, order_service)

# main.py
if __name__ == "__main__":
    app = create_application()
    app.run()
```

**得られるもの:**
- DIコンテナなしで依存グラフを管理
- コンパイル時に依存関係の問題を検出
- フレームワーク非依存

**失うもの:**
- Composition Rootが大きくなりがち
- ライフサイクル管理は手動

**適用条件:**
- DIコンテナを避けたいが、手動配線は整理したい
- テスタビリティを重視
- 依存関係を明示的に把握したい

**アンチパターン:**
- Composition Root以外で依存を生成

### 🔴 Experimental

#### Context Pattern(組み込み向け)

**詳細は [examples/context-pattern.md](../examples/context-pattern.md) を参照**

```cpp
// C++ (組み込み)
template<typename T>
class Context {
    static T* instance_;
public:
    static void set(T* inst) { instance_ = inst; }
    static T& get() { 
        assert(instance_ != nullptr);
        return *instance_; 
    }
};

// 初期化(main.cpp)
AnalogSensor sensor(A0);
LedOutput led(13);

Context<ISensor>::set(&sensor);
Context<IOutput>::set(&led);

// 使用側
void process() {
    auto value = Context<ISensor>::get().read();
    Context<IOutput>::get().write(value > 500);
}
```

**得られるもの:**
- ゼロオーバーヘッド(コンパイル時解決)
- メモリ制約環境で使用可能
- 依存の明示的管理

**失うもの:**
- パターンの理解が必要
- 情報が少ない
- グローバルアクセスに近い形

**適用条件:**
- 組み込み/メモリ制約環境
- DIコンテナが使えない
- ゼロオーバーヘッドが必須

**アンチパターン:**
- Webアプリなど制約のない環境(通常のDIで十分)

## 選択フローチャート

```
[開始]
  |
  v
メモリ制約が厳しい? ──Yes──> Context Pattern(🔴)
  |
  No
  v
依存が5個以下? ──Yes──> Constructor Injection(🟢)
  |
  No
  v
フレームワーク採用OK? ──Yes──> DIコンテナ(🟡)
  |
  No
  v
Pure DI(🟡)
```

## 判断基準まとめ

| 基準 | 🟢 Conservative | 🟡 Pragmatic | 🔴 Experimental |
|--|--|--|
| プロジェクト規模 | 小 | 中〜大 | 制約環境 |
| 依存の数 | 少(〜5) | 多(6+) | 問わない |
| チーム経験 | 初心者OK | 中級以上 | 上級 |
| パフォーマンス要件 | 通常 | 通常 | 厳格 |
| フレームワーク | 不要 | 必要 | 不要 |
