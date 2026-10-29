# Changelog

## 1.3

### English

- Refreshed the settings experience with four native toolbar panes and a live HUD preview.
- Improved HUD readability and appearance controls, including separately adjustable glass-background opacity.
- Kept power draw visible; battery charge is always shown, with charging status and remaining-time details on a secondary line.
- Added default exclusions for launchers and helper processes, plus a clearer game-management view.
- Added app-menu settings and quit commands with standard keyboard shortcuts.
- Added a quick HUD-lock toggle to the menu bar extra.
- Added rolling 10-second minimum and maximum FPS readings below the FPS graph.
- Combined HUD locking and click-through behavior into one control: when locked, the HUD cannot be dragged and pointer clicks pass through it.
- Bug fixes and stability improvements.

### Українська

- Оновлено дизайн налаштувань: чотири нативні вкладки на панелі інструментів і живий попередній перегляд HUD.
- Покращено читабельність HUD і налаштування вигляду, зокрема окреме регулювання прозорості скляного тла.
- Потужність залишається видимою; відсоток заряду показується завжди, а індикатор заряджання й орієнтовний час — додатковим рядком.
- Додано стандартні виключення для лаунчерів і службових процесів та зрозуміліший список ігор.
- Додано команди налаштувань і виходу в меню застосунку зі стандартними клавіатурними скороченнями.
- Додано швидкий перемикач фіксації HUD у меню значка в рядку меню.
- Додано мінімальний і максимальний FPS за останні 10 секунд під графіком FPS.
- Об’єднано фіксацію HUD і проходження кліків в один перемикач: у зафіксованому режимі HUD не перетягується та пропускає кліки наскрізь.
- Виправлення помилок і підвищення стабільності.


## 1.2

### English

- Added a startup animation.

### Українська

- Додано анімацію запуску застосунку.

## 1.1

### English

- Added CPU, GPU, memory, Apple Silicon temperature, system power, and battery charge/estimated time metrics.
- Added the CPU model and manufacturer icon to the CPU row.
- Added game FPS and frame-time monitoring, including average FPS, 1% low, average/max frame time, and a history graph.
- Added foreground game capture through ScreenCaptureKit and a display-compositor cadence source.
- Added automatic game detection for macOS Games, Game Mode, Steam/Epic/GOG, Wine/CrossOver, plus manual include/exclude controls.
- Added appearance and overlay controls: opacity, size, accent color, window level, position lock, and click-through.
- Added configurable refresh interval, launch at login, temperature units, and English/Ukrainian interface.
- Adopted native SwiftUI Liquid Glass styling and reduced background polling while idle.

Requires macOS 26 or later. Screen Recording permission is needed only for foreground game capture.

### Українська

- Додано показники CPU, GPU, пам’яті, температури Apple Silicon, системної потужності та заряду батареї з орієнтовним часом роботи.
- У рядку CPU показуються модель процесора та значок виробника.
- Додано моніторинг FPS і часу кадру в іграх: середній FPS, 1% low, середній/максимальний час кадру та графік історії.
- Додано захоплення активного вікна гри через ScreenCaptureKit і джерело за ритмом композитора дисплея.
- Додано автоматичне визначення ігор для macOS Games, Game Mode, Steam/Epic/GOG, Wine/CrossOver і ручне додавання/виключення застосунків.
- Додано налаштування вигляду та вікна: прозорість, розмір, колір акценту, рівень вікна, фіксація позиції та проходження кліків.
- Додано налаштування інтервалу оновлення, запуску під час входу, одиниць температури та інтерфейсу English/Українська.
- Використано нативний SwiftUI Liquid Glass і зменшено фонове опитування в режимі очікування.

Потрібна macOS 26 або новіша. Дозвіл «Запис екрана» потрібен лише для захоплення активного вікна гри.
