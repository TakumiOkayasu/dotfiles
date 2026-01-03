# Context Pattern

## 概要

Context Patternは、組み込みシステムやメモリ制約環境向けの依存性注入パターン。
DIコンテナのオーバーヘッドなしに、テスタブルで疎結合なコードを実現する。

pre-omusubiフレームワークで採用されているアプローチ。

## 背景と動機

### 組み込み環境の制約

- メモリ: Arduino Uno = 2KB RAM, ESP32 = 520KB RAM
- CPU: 動的メモリ確保のオーバーヘッドを避けたい
- コンパイル: 依存関係はコンパイル時に解決したい

### 従来のアプローチの問題

**グローバル変数**

```cpp
// ❌ テスト困難、依存関係が不明確
Sensor sensor;
void loop() {
    int value = sensor.read();
}
```

**Constructor Injection**

```cpp
// ❌ 組み込みでは初期化順序の問題
class Controller {
    Controller(Sensor& s) : sensor(s) {}
};
// グローバルオブジェクトの初期化順序は不定
```

**DIコンテナ**

```cpp
// ❌ 組み込みでは使えない
// - 動的メモリ確保
// - RTTI(実行時型情報)
// - 例外処理
```

## Context Patternの設計

### 基本構造

```cpp
// context.hpp
template<typename T>
class Context {
    static T* instance_;
public:
    static void set(T* inst) { 
        instance_ = inst; 
    }
    
    static T& get() { 
        // 組み込みではassertを使用(例外なし)
        assert(instance_ != nullptr && "Context not initialized");
        return *instance_; 
    }
    
    static bool has() {
        return instance_ != nullptr;
    }
    
    static void clear() {
        instance_ = nullptr;
    }
};

// 静的メンバの定義(cppファイルまたはヘッダ)
template<typename T>
T* Context<T>::instance_ = nullptr;
```

### インターフェース定義

```cpp
// interfaces.hpp

// センサーインターフェース
class ISensor {
public:
    virtual ~ISensor() = default;
    virtual int read() = 0;
    virtual bool isReady() = 0;
};

// 出力インターフェース
class IOutput {
public:
    virtual ~IOutput() = default;
    virtual void write(bool state) = 0;
    virtual void toggle() = 0;
};

// ロガーインターフェース
class ILogger {
public:
    virtual ~ILogger() = default;
    virtual void log(const char* message) = 0;
    virtual void logValue(const char* name, int value) = 0;
};
```

### 具象クラス実装

```cpp
// implementations.hpp

// アナログセンサー
class AnalogSensor : public ISensor {
    uint8_t pin_;
public:
    explicit AnalogSensor(uint8_t pin) : pin_(pin) {}
    
    int read() override {
        return analogRead(pin_);
    }
    
    bool isReady() override {
        return true;
    }
};

// デジタル出力(LED等)
class DigitalOutput : public IOutput {
    uint8_t pin_;
    bool state_ = false;
public:
    explicit DigitalOutput(uint8_t pin) : pin_(pin) {
        pinMode(pin_, OUTPUT);
    }
    
    void write(bool state) override {
        state_ = state;
        digitalWrite(pin_, state ? HIGH : LOW);
    }
    
    void toggle() override {
        write(!state_);
    }
};

// シリアルロガー
class SerialLogger : public ILogger {
public:
    void log(const char* message) override {
        Serial.println(message);
    }
    
    void logValue(const char* name, int value) override {
        Serial.print(name);
        Serial.print(": ");
        Serial.println(value);
    }
};
```

### 使用例

```cpp
// main.cpp

// グローバルインスタンス(静的確保)
AnalogSensor sensor(A0);
DigitalOutput led(13);
SerialLogger logger;

void setup() {
    Serial.begin(9600);
    
    // Contextへの登録
    Context<ISensor>::set(&sensor);
    Context<IOutput>::set(&led);
    Context<ILogger>::set(&logger);
}

void loop() {
    // Contextから取得して使用
    auto& sensor = Context<ISensor>::get();
    auto& output = Context<IOutput>::get();
    auto& log = Context<ILogger>::get();
    
    int value = sensor.read();
    log.logValue("sensor", value);
    
    output.write(value > 500);
    
    delay(100);
}
```

## テスタビリティ

### モック実装

```cpp
// test_mocks.hpp

class MockSensor : public ISensor {
    int mockValue_ = 0;
public:
    void setMockValue(int value) { mockValue_ = value; }
    
    int read() override { return mockValue_; }
    bool isReady() override { return true; }
};

class MockOutput : public IOutput {
public:
    bool lastState = false;
    int writeCount = 0;
    
    void write(bool state) override {
        lastState = state;
        writeCount++;
    }
    
    void toggle() override {
        write(!lastState);
    }
};
```

### テストコード

```cpp
// test_threshold.cpp
#include "unity.h"  // または他のテストフレームワーク

MockSensor mockSensor;
MockOutput mockOutput;

void setUp() {
    Context<ISensor>::set(&mockSensor);
    Context<IOutput>::set(&mockOutput);
}

void tearDown() {
    Context<ISensor>::clear();
    Context<IOutput>::clear();
}

void test_output_on_when_above_threshold() {
    mockSensor.setMockValue(600);  // 閾値(500)以上
    
    processReading();  // テスト対象の関数
    
    TEST_ASSERT_TRUE(mockOutput.lastState);
}

void test_output_off_when_below_threshold() {
    mockSensor.setMockValue(400);  // 閾値(500)未満
    
    processReading();
    
    TEST_ASSERT_FALSE(mockOutput.lastState);
}
```

## 応用: 複数インスタンス対応

### タグ付きContext

```cpp
// 複数のセンサーを区別
struct TemperatureSensorTag {};
struct HumiditySensorTag {};

template<typename Tag, typename T>
class TaggedContext {
    static T* instance_;
public:
    static void set(T* inst) { instance_ = inst; }
    static T& get() { return *instance_; }
};

// 使用
Context<TemperatureSensorTag, ISensor>::set(&tempSensor);
Context<HumiditySensorTag, ISensor>::set(&humiditySensor);
```

### IDベースのContext

```cpp
// 動的なID指定(少し複雑)
template<typename T, size_t MaxInstances = 8>
class MultiContext {
    static T* instances_[MaxInstances];
public:
    static void set(size_t id, T* inst) {
        assert(id < MaxInstances);
        instances_[id] = inst;
    }
    
    static T& get(size_t id) {
        assert(id < MaxInstances && instances_[id] != nullptr);
        return *instances_[id];
    }
};
```

## トレードオフ

### 得られるもの

| メリット | 説明 |
|----------|------|
| ゼロオーバーヘッド | テンプレートによりコンパイル時解決 |
| メモリ効率 | 動的確保なし、ポインタ1つ分のみ |
| テスタブル | モック注入が容易 |
| 依存の明示化 | インターフェースにより依存が明確 |
| 初期化制御 | 明示的なset()で初期化順序を制御 |

### 失うもの

| デメリット | 説明 |
|------------|------|
| グローバル状態 | 実質的にグローバルアクセス |
| 情報の少なさ | 一般的なパターンではない |
| 学習コスト | チームへの説明が必要 |
| スコープ管理 | リクエストスコープ等は手動管理 |

### 向いているケース

- ✅ Arduino, ESP32, STM32等のマイコン
- ✅ メモリ制約が厳しい環境
- ✅ リアルタイム性が求められる
- ✅ DIコンテナが使えない/使いたくない

### 向いていないケース

- ❌ Webアプリケーション(通常のDIで十分)
- ❌ リクエストスコープが必要
- ❌ 大規模チーム(学習コスト)

## 参考

- pre-omusubi framework: [https://github.com/TakumiOkayasu/pre-omusubi]
- 関連パターン: Service Locator, Dependency Injection
