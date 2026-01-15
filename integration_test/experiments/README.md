# Performance Experiments

## Структура экспериментов

Каждый toggle тестируется **отдельно** для удобства порционного запуска:

```
integration_test/
├── core/                     # Общие модули
│   ├── csv_writer.dart       # CSV запись данных
│   ├── frame_collector.dart  # Сбор frame timing
│   └── test_constants.dart   # Константы конфигурации
│
├── experiments/              # Отдельные эксперименты
│   ├── exp_json_parse.dart   # Toggle: largeJsonParce
│   ├── exp_lazy_load.dart    # Toggle: lazyLoad
│   ├── exp_rebuild.dart      # Toggle: correctDataUpdate
│   └── exp_shimmer.dart      # Toggle: minimizeExpensiveRendering
│
└── test_config.dart          # App factory
```

## Запуск экспериментов

### 1. EXP-JSON: Large JSON Parse (25MB from GitHub)

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/experiments/exp_json_parse.dart \
  --profile --no-dds
```

- **Toggle:** `largeJsonParce`
- **Время:** ~5-10 мин (зависит от сети)
- **Output:** `flutter_perf_largeJsonParce_*.csv`

### 2. EXP-LAZY: Lazy Load Performance

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/experiments/exp_lazy_load.dart \
  --profile --no-dds
```

- **Toggle:** `lazyLoad`
- **Время:** ~15-30 мин (toggle=false загружает 50 изображений полного размера)
- **Output:** `flutter_perf_lazyLoad_*.csv`

### 3. EXP-REBUILD: Widget Rebuild (Scroll)

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/experiments/exp_rebuild.dart \
  --profile --no-dds
```

- **Toggle:** `correctDataUpdate`
- **Время:** ~5 мин
- **Output:** `flutter_perf_correctDataUpdate_*.csv`

### 4. EXP-SHIMMER: Animation Smoothness

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/experiments/exp_shimmer.dart \
  --profile --no-dds
```

- **Toggle:** `minimizeExpensiveRendering`
- **Время:** ~3 мин
- **Output:** `flutter_perf_minimizeExpensiveRendering_*.csv`

## Получение данных

После каждого эксперимента:

```bash
# Создать папку для данных
mkdir -p raw_data

# Скачать все CSV файлы
adb pull /sdcard/Download/flutter_perf_largeJsonParce_*.csv ./raw_data/
adb pull /sdcard/Download/flutter_perf_lazyLoad_*.csv ./raw_data/
adb pull /sdcard/Download/flutter_perf_correctDataUpdate_*.csv ./raw_data/
adb pull /sdcard/Download/flutter_perf_minimizeExpensiveRendering_*.csv ./raw_data/

# Или все сразу
adb pull /sdcard/Download/ ./raw_data/ && mv ./raw_data/*.csv ./raw_data/
```

## Формат CSV данных

```csv
timestamp,scenario_id,experiment_run_id,device_model,android_version,flutter_version,profile_mode,optimization_toggle,toggle_state,metric_name,metric_value,unit,iteration,frame_id,is_warmup
```

### Метрики по экспериментам:

| Эксперимент | Метрики                                                                        |
| ----------- | ------------------------------------------------------------------------------ |
| EXP-JSON    | `frame_build_time`, `frame_raster_time`, `frame_total_time`, `load_time_total` |
| EXP-LAZY    | `frame_*`, `initial_build_time`, `loaded_image_count`                          |
| EXP-REBUILD | `frame_*`, `scroll_duration`                                                   |
| EXP-SHIMMER | `frame_*`, `animation_duration`, `frame_rate`                                  |

## Конфигурация

Изменить параметры в `core/test_constants.dart`:

```dart
const int kDataIterations = 10;       // Итераций на состояние
const int kWarmupIterations = 2;      // Прогревочных итераций
const Duration kIterationCooldown = Duration(seconds: 2);
```

## Рекомендуемый порядок запуска

1. **EXP-SHIMMER** (быстрый, проверка setup)
2. **EXP-REBUILD** (средний)
3. **EXP-JSON** (требует сеть)
4. **EXP-LAZY** (самый долгий)

## Важные замечания

- Запускать в **profile** режиме (не debug!)
- Устройство должно быть подключено и разблокировано
- Для EXP-JSON нужен доступ к интернету
- EXP-LAZY с toggle=false очень медленный (~40 сек/итерация)
