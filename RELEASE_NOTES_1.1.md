# PerfHUD 1.1

## English

- Added CPU, GPU, memory, Apple Silicon temperature, system power, and battery charge/estimated time metrics.
- Added the CPU model and manufacturer icon to the CPU row.
- Added game FPS and frame-time monitoring, including average FPS, 1% low, average/max frame time, and a history graph.
- Added foreground game capture through ScreenCaptureKit and a display-compositor cadence source.
- Added automatic game detection for macOS Games, Game Mode, Steam/Epic/GOG, Wine/CrossOver, plus manual include/exclude controls.
- Added appearance and overlay controls: opacity, size, accent color, window level, position lock, and click-through.
- Added configurable refresh interval, launch at login, temperature units, and English/Ukrainian interface.
- Adopted native SwiftUI Liquid Glass styling and reduced background polling while idle.

Requires macOS 26 or later. Screen Recording permission is needed only for foreground game capture.

## Українська

- Додано показники CPU, GPU, пам’яті, температури Apple Silicon, системної потужності та заряду батареї з орієнтовним часом роботи.
- У рядку CPU показуються модель процесора та значок виробника.
- Додано моніторинг FPS і часу кадру в іграх: середній FPS, 1% low, середній/максимальний час кадру та графік історії.
- Додано захоплення активного вікна гри через ScreenCaptureKit і джерело за ритмом композитора дисплея.
- Додано автоматичне визначення ігор для macOS Games, Game Mode, Steam/Epic/GOG, Wine/CrossOver і ручне додавання/виключення застосунків.
- Додано налаштування вигляду та вікна: прозорість, розмір, колір акценту, рівень вікна, фіксація позиції та проходження кліків.
- Додано налаштування інтервалу оновлення, запуску під час входу, одиниць температури та інтерфейсу English/Українська.
- Використано нативний SwiftUI Liquid Glass і зменшено фонове опитування в режимі очікування.

Потрібна macOS 26 або новіша. Дозвіл «Запис екрана» потрібен лише для захоплення активного вікна гри.
