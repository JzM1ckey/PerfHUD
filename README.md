# PerfHUD

**A lightweight macOS desktop HUD for system performance and game frame-time monitoring.**

[![Support PerfHUD](https://img.shields.io/badge/♥%20Support%20%2F%20Підтримати-Donate%20%2F%20Донат-ff5f5f?style=for-the-badge)](https://donatello.to/JzM1ckey)

## English

PerfHUD places live performance metrics in a compact, draggable desktop overlay with native SwiftUI Liquid Glass styling.

### Features

- CPU model and manufacturer icon shown with CPU utilization, plus GPU utilization, memory use, Apple Silicon temperature, system power draw, and battery charge with estimated remaining time.
- Game FPS and frame-time history, average FPS, rolling 10-second minimum/maximum FPS, 1% low, and average/maximum frame time. Long game names truncate before FPS readings.
- Choose the FPS source: capture the foreground game window with ScreenCaptureKit, or use display-compositor cadence without Screen Recording permission.
- Automatic game detection using the macOS Games category, Game Mode, Steam/Epic/GOG install paths, and Wine/CrossOver; add or exclude apps manually.
- Customize overlay opacity, size (50–150%, with 100% as the default), accent color (including automatic load-based color), and displayed metrics.
- Choose window level; in locked mode, prevent dragging and let pointer clicks pass through the HUD.
- Configure refresh interval, launch at login, temperature units, and English/Ukrainian language.
- Reduced idle polling and on-demand display-link sampling to lower background work.

### Requirements

- macOS 26 or later.
- Apple Silicon recommended for temperature and power metrics.
- Screen Recording permission is needed only for the foreground-game capture source. The display-cadence source does not require it.

### Install

Download `PerfHUD-1.5.zip` from [release v1.5.0](https://github.com/JzM1ckey/PerfHUD/releases/tag/v1.5.0) on the [Releases](https://github.com/JzM1ckey/PerfHUD/releases) page, unzip it, and move `PerfHUD.app` to Applications. If macOS blocks the app, open it from Finder using Control-click → Open.

See [Changelog](CHANGELOG.md) for release history.

### License

PerfHUD is distributed under the [MIT License](LICENSE).

## Українська

**Легкий віджет для macOS із показниками системи та частоти кадрів в іграх.**

PerfHUD показує поточні показники у компактному перетягуваному вікні з нативним оформленням SwiftUI Liquid Glass.

### Можливості

- Модель процесора та значок виробника поруч із навантаженням CPU, а також навантаження GPU, використання пам’яті, температура Apple Silicon, споживання системної потужності та заряд батареї з орієнтовним часом роботи.
- FPS і графік часу кадру в іграх, середній FPS, мінімальний/максимальний FPS за останні 10 секунд, 1% low, середній і максимальний час кадру. Довга назва гри скорочується, щоб показники FPS залишалися видимими.
- Вибір джерела FPS: захоплення вікна гри через ScreenCaptureKit або ритм композитора дисплея без дозволу на запис екрана.
- Автоматичне визначення ігор за категорією macOS Games, Game Mode, шляхами Steam/Epic/GOG і Wine/CrossOver; застосунки можна додавати або виключати вручну.
- Налаштування прозорості, розміру (50–150%, типовий — 100%), кольору акценту (зокрема автоматичного за навантаженням) і набору показників.
- Вибір рівня вікна; у зафіксованому режимі HUD не перетягується та пропускає кліки наскрізь.
- Налаштування інтервалу оновлення, запуску під час входу, одиниць температури та мови English/Українська.
- Менше фонових обчислень завдяки рідшому опитуванню в режимі очікування та запуску вимірювання дисплея лише за потреби.

### Вимоги

- macOS 26 або новіша.
- Для показників температури та потужності рекомендовано Apple Silicon.
- Дозвіл «Запис екрана» потрібен лише для захоплення активного вікна гри. Джерело за ритмом дисплея його не потребує.

### Встановлення

Завантажте `PerfHUD-1.5.zip` із [релізу v1.5.0](https://github.com/JzM1ckey/PerfHUD/releases/tag/v1.5.0) на сторінці [Releases](https://github.com/JzM1ckey/PerfHUD/releases), розпакуйте архів і перемістіть `PerfHUD.app` до Applications. Якщо macOS блокує застосунок, відкрийте його у Finder через Control-click → Open.

Історія змін — у [Changelog](CHANGELOG.md).

### Ліцензія

PerfHUD поширюється за [ліцензією MIT](LICENSE).
