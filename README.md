# PerfHUD

Минималистичный HUD производительности для macOS **26+** (лучше всего на Apple Silicon).
Показывает в плавающем поверх окон окне: **CPU · GPU · RAM · температуру · потребление (Вт) · график времени кадра** — и настраивается в отдельном окне.

A minimal performance HUD for **macOS 26+** (best on Apple Silicon).
A floating on-top window shows **CPU · GPU · RAM · temperature · power draw (W) · frame-time graph**, configurable through a separate window.

---

## Возможности / Features

- 🔲 Плавающий HUD поверх всех окон с настраиваемой прозрачностью и размером
- 🖥 CPU / 🎮 GPU / 🧠 RAM — загрузка в реальном времени
- 🌡 Температура датчиков Apple Silicon (приватный HID-интерфейс), °C / °F
- ⚡ Потребление системы из SMC (ключ `PSTR`), Вт
- 📈 График времени кадра (`displayLink`) — всплески показывают просадки/фризы
- 🎨 Несколько цветовых схем + «авто» по нагрузке
- 📋 Меню в строке меню: показать/скрыть, настройки, выход
- 🚀 Автозапуск при входе в систему
- 🖱 Перетаскивание окна, закрепление, click-through

---

## Скриншоты / Screenshots

> _Добавьте сюда скриншоты HUD и окна настроек._

---

## Системные требования / Requirements

- macOS 26.0+
- Apple Silicon (температура и потребление работают только там; на Intel эти показатели будут «—»)
- Xcode Command Line Tools для сборки

## Сборка / Build

```bash
bash build_app.sh
```

Скрипт компилирует `PerfHUD.swift` в `PerfHUD.app`, создаёт `Info.plist` и иконку, подписывает приложение (ad-hoc).
Перетащите `PerfHUD.app` в папку «Программы» и запустите.

---

## Устройство / How it works

- **CPU / GPU / RAM** — через `host_processor_info`, `IOAccelerator` и `host_statistics64`
- **Температура** — приватный `IOHIDEventSystem` / датчики Apple Silicon (`PrimaryUsagePage 0xff00`)
- **Потребление** — прямое чтение SMC-ключа `PSTR` (float) через `AppleSMC`
- **Время кадра** — `NSScreen.displayLink` → `CADisplayLink`

Приложение не вызывает приватных **API на уровне вызовов** Swift/ObjC, но обращается к приватным **системным сервисам** (HID, SMC). Это может быть нестабильно на будущих версиях macOS.

---

## Лицензия / License

MIT © 2026 JzM1ckey
