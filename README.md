# Flutter Performance Testbed

Flutter-приложение для исследования методов оптимизации производительности.

## Структура

```
perform_test/
├── lib/                      # Код приложения (Clean Architecture)
│   ├── config/              # Конфигурация
│   ├── core/                # Feature toggles, providers
│   ├── data/                # Data layer (datasources, repositories)
│   ├── di/                  # Dependency injection
│   ├── domain/              # Domain layer (entities, usecases)
│   ├── presentation/        # UI layer (widgets, pages)
│   └── service/             # Services
│
├── integration_test/         # Эксперименты Stage 1
│   ├── experiments/         # Исполняемые тесты (exp_*.dart)
│   ├── scenarios/           # Определения сценариев (scn_*.dart)
│   ├── core/                # Инфраструктура сбора данных
│   └── raw_data_collector.dart  # Основной сборщик CSV
│
├── scripts/                 # Скрипты запуска
│   └── collect_data.ps1    # Сбор данных с устройства
│
└── assets/                  # Тестовые данные
    ├── config/
    └── data/
```

**Примечание:** Папки `raw_data/` и `docs/` находятся в корне проекта.

## Запуск экспериментов

### Отдельный эксперимент

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/experiments/exp_shimmer.dart \
  --profile --no-dds
```

### Сбор данных с устройства

```powershell
.\scripts\collect_data.ps1
```

## Feature Toggles

| Toggle                       | Описание                    | Эксперимент |
| ---------------------------- | --------------------------- | ----------- |
| `minimizeExpensiveRendering` | ShaderMask consolidation    | SCN-SHIMMER |
| `correctDataUpdate`          | Conditional setState        | SCN-REBUILD |
| `lazyLoad`                   | ListView.builder vs Column  | SCN-LAZY    |
| `largeJsonParce`             | JSON parsing in isolate     | SCN-JSON    |
| `optimImageSize`             | Image decoding optimization | SCN-IMG     |
| `optimFibonacci`             | Heavy compute in isolate    | SCN-FIB     |

## Устройство для тестирования

- Samsung Galaxy A12 SM-A125F
- Android 12
- Flutter 3.40.0-beta (profile mode)
