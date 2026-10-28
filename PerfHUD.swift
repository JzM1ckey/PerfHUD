// PerfHUD — минималистичный HUD производительности для macOS 26+ (лучше всего на Apple Silicon)
// CPU · GPU · RAM · температура · потребление (Вт) · график времени кадра + окно настроек.
// Сборка приложения: bash build_app.sh  →  PerfHUD.app

import Cocoa
import SwiftUI
import IOKit
import IOKit.ps
import QuartzCore
import ServiceManagement
import ScreenCaptureKit
import CoreMedia
import UniformTypeIdentifiers
import Darwin

private let kMainPort: mach_port_t = 0   // замена kIOMainPortID

// MARK: - Настройки

enum K {
    static let cpu = "showCPU", gpu = "showGPU", ram = "showRAM"
    static let temp = "showTemp", power = "showPower", frame = "showFrame"
    static let opacity = "opacity", scale = "scale"
    static let interval = "interval", fahrenheit = "fahrenheit", accent = "accent"
    static let clickThrough = "clickThrough", locked = "locked", level = "windowLevel", fpsSource = "fpsSource", games = "gamesList", autoGames = "autoGames"
    static let batteryTime = "showBatteryTime"
    static let lang = "language"
}

// MARK: - Локализация (EN / UK; русский убран)

/// Поддерживаются только английский (en) и украинский (uk).
/// Язык берётся из системы; если система ни на одном из них — используется английский.
enum L {
    static private(set) var lang = "en"

    static func setup()  { lang = resolve() }
    static func refresh() { lang = resolve() }

    /// Язык из настройки (auto → по системе; en/uk — принудительно; всё иное → en).
    private static func resolve() -> String {
        switch UserDefaults.standard.string(forKey: K.lang) ?? "auto" {
        case "uk": return "uk"
        case "en": return "en"
        default:
            return (Locale.preferredLanguages.first ?? "").lowercased().hasPrefix("uk") ? "uk" : "en"
        }
    }

    static func tr(_ key: String) -> String {
        (lang == "uk" ? uk[key] : en[key]) ?? key
    }

    static func trFmt(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), arguments: args)
    }

    private static let en: [String: String] = [
        "Показатели": "Metrics", "Память (RAM)": "Memory (RAM)", "Температура": "Temperature",
        "Потребление (Вт)": "Power (W)", "График времени кадра": "Frame time graph",
        "Внешний вид": "Appearance", "Прозрачность окна": "Window opacity",
        "Размер": "Size", "Цвет": "Color",
        "Авто (по нагрузке)": "Auto (by load)", "Синий": "Blue", "Фиолетовый": "Purple",
        "Оранжевый": "Orange", "Мятный": "Mint", "Розовый": "Pink",
        "Температура в °F": "Temperature in °F",
        "Поведение": "Behavior", "Уровень окна": "Window level", "Обычный": "Normal",
        "Поверх окон": "Above windows", "Поверх игр (максимум)": "Above games (max)",
        "Закрепить (нельзя перетаскивать)": "Locked (cannot drag)",
        "Click-through (клики проходят сквозь HUD)": "Click-through (clicks pass through the HUD)",
        "Частота обновления": "Update rate", "0.5 с": "0.5 s", "1 с": "1 s", "2 с": "2 s",
        "Сбросить положение": "Reset position",
        "FPS и frame time": "FPS & frame time", "Источник": "Source",
        "Приложение в фокусе": "Foreground app", "Дисплей (ритм композитора)": "Display (compositor)",
        "Открыть доступ «Запись экрана»…": "Open “Screen Recording” access…",
        "Игры": "Games", "Определять игры автоматически": "Detect games automatically",
        "FPS и frame time показываются только для игр: по категории «Игры», путям Steam / Epic / GOG и Wine / CrossOver. Остальное можно добавить вручную.": "FPS and frame time are shown only for games: by the “Games” category, Steam / Epic / GOG paths and Wine / CrossOver. Others can be added manually.",
        "Убрать": "Remove", "Добавить приложение…": "Add app…", "исключено: ": "excluded: ",
        "Система": "System", "Запускать при входе в систему": "Launch at login",
        "Время и заряд от батареи": "Battery time & charge",
        "Показать / скрыть": "Show / Hide", "Настройки…": "Settings…", "Выход": "Quit",
        "Приложение в фокусе — игра": "App in focus is a game",
        "«%@» — это игра": "Is “%@” a game?",
        "Приложение": "app",
        "PerfHUD — Настройки": "PerfHUD — Settings",
        "нет игры": "no game", "нужен доступ": "screen access needed",
        "нет окна": "no window", "ошибка захвата": "capture error", "бат": "battery",
        "ч": "h", "м": "m",
        "Язык": "Language", "Авто (язык системы)": "Auto (system)",
        "1% low": "1% low", "макс.": "max", "мс": "ms", "— ms": "— ms",
    ]

    private static let uk: [String: String] = [
        "Показатели": "Показники", "Память (RAM)": "Пам'ять (RAM)", "Температура": "Температура",
        "Потребление (Вт)": "Споживання (Вт)", "График времени кадра": "Графік часу кадра",
        "Внешний вид": "Зовнішній вигляд", "Прозрачность окна": "Прозорість вікна",
        "Размер": "Розмір", "Цвет": "Колір",
        "Авто (по нагрузке)": "Авто (за навантаженням)", "Синий": "Синій", "Фиолетовый": "Фіолетовий",
        "Оранжевый": "Оранжевий", "Мятный": "М'ятний", "Розовый": "Рожевий",
        "Температура в °F": "Температура у °F",
        "Поведение": "Поведінка", "Уровень окна": "Рівень вікна", "Обычный": "Звичайний",
        "Поверх окон": "Поверх вікон", "Поверх игр (максимум)": "Поверх ігор (макс.)",
        "Click-through (клики проходят сквозь HUD)": "Click-through (кліки крізь HUD)",
        "Закрепить (нельзя перетаскивать)": "Зафіксувати (не можна перетягувати)",
        "Частота обновления": "Частота оновлення", "0.5 с": "0.5 с", "1 с": "1 с", "2 с": "2 с",
        "Сбросить положение": "Скинути положення",
        "FPS и frame time": "FPS і час кадру", "Источник": "Джерело",
        "Приложение в фокусе": "Застосунок у фокусі", "Дисплей (ритм композитора)": "Дисплей (частота кадрів)",
        "Открыть доступ «Запись экрана»…": "Відкрити доступ «Запис екрана»…",
        "Игры": "Ігри", "Определять игры автоматически": "Визначати ігри автоматично",
        "FPS и frame time показываются только для игр: по категории «Игры», путям Steam / Epic / GOG и Wine / CrossOver. Остальное можно добавить вручную.": "FPS і час кадру показуються лише для ігор: за категорією «Ігри», шляхами Steam / Epic / GOG і Wine / CrossOver. Інші застосунки можна додати вручну.",
        "Убрать": "Прибрати", "Добавить приложение…": "Додати застосунок…", "исключено: ": "виключено: ",
        "Система": "Система", "Запускать при входе в систему": "Запускати під час входу в систему",
        "Время и заряд от батареи": "Час і заряд від батареї",
        "Показать / скрыть": "Показати / Сховати", "Настройки…": "Налаштування…", "Выход": "Вийти",
        "Приложение в фокусе — игра": "Застосунок у фокусі — це гра",
        "«%@» — это игра": "«%@» — це гра?",
        "Приложение": "застосунок",
        "PerfHUD — Настройки": "PerfHUD — Налаштування",
        "нет игры": "немає гри", "нужен доступ": "потрібен доступ",
        "нет окна": "немає вікна", "ошибка захвата": "помилка захоплення", "бат": "акум.",
        "ч": "год", "м": "хв",
        "Язык": "Мова", "Авто (язык системы)": "Авто (система)",
        "1% low": "1% мін.", "макс.": "макс.", "мс": "мс", "— ms": "— мс",
    ]
}

extension Notification.Name {
    static let resetPosition = Notification.Name("PerfHUDResetPosition")
    static let languageChanged = Notification.Name("PerfHUDLanguageChanged")
}

func hudTint(_ accent: String, load: Double) -> Color {
    switch accent {
    case "blue":   return Color(red: 0.35, green: 0.65, blue: 1.00)
    case "purple": return Color(red: 0.70, green: 0.50, blue: 1.00)
    case "orange": return Color(red: 1.00, green: 0.62, blue: 0.25)
    case "mint":   return Color(red: 0.35, green: 0.92, blue: 0.75)
    case "pink":   return Color(red: 1.00, green: 0.45, blue: 0.65)
    default:
        if load < 60 { return Color(red: 0.35, green: 0.90, blue: 0.55) }
        if load < 85 { return Color(red: 1.00, green: 0.80, blue: 0.30) }
        return Color(red: 1.00, green: 0.38, blue: 0.38)
    }
}

// MARK: - CPU identity

private enum CPUIdentity {
    private static let brandString = readBrandString()
    static let vendor: String = {
        let brand = (brandString ?? "").lowercased()
        if brand.contains("intel") { return "Intel" }
        if brand.contains("amd") { return "AMD" }
        #if arch(arm64)
        return "Apple"
        #else
        return "CPU"
        #endif
    }()
    static let name = brandString ?? {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return vendor
        #endif
    }()

    private static func readBrandString() -> String? {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0,
              size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBufferPointer { buffer in
            sysctlbyname("machdep.cpu.brand_string", buffer.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        let value = String(cString: bytes).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

// MARK: - Private HID (датчики температуры Apple Silicon)

@_silgen_name("IOHIDEventSystemClientCreate")
private func hidCreate(_ a: CFAllocator?) -> UnsafeMutableRawPointer?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func hidSetMatching(_ c: UnsafeMutableRawPointer, _ m: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func hidCopyServices(_ c: UnsafeMutableRawPointer) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func hidCopyEvent(_ s: UnsafeMutableRawPointer, _ t: Int64, _ o: Int32, _ to: Int64) -> UnsafeMutableRawPointer?
@_silgen_name("IOHIDEventGetFloatValue")
private func hidFloat(_ e: UnsafeMutableRawPointer, _ f: Int32) -> Double

final class Thermals {
    private let client: UnsafeMutableRawPointer?
    init() {
        client = hidCreate(kCFAllocatorDefault)
        if let c = client {
            let m: [String: Any] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
            _ = hidSetMatching(c, m as CFDictionary)
        }
    }
    /// Максимум по датчикам температуры, °C
    func read() -> Double? {
        guard let c = client, let arr = hidCopyServices(c)?.takeRetainedValue() else { return nil }
        var best: Double? = nil
        for i in 0..<CFArrayGetCount(arr) {
            guard let raw = CFArrayGetValueAtIndex(arr, i) else { continue }
            let svc = UnsafeMutableRawPointer(mutating: raw)
            guard let ev = hidCopyEvent(svc, 15, 0, 0) else { continue }   // 15 = temperature
            let t = hidFloat(ev, 15 << 16)
            Unmanaged<AnyObject>.fromOpaque(ev).release()
            if t > 0 && t < 150 { best = max(best ?? 0, t) }
        }
        return best
    }
}

// MARK: - SMC (потребление системы, ключ PSTR)

final class SMC {
    private var conn: io_connect_t = 0
    init?() {
        let svc = IOServiceGetMatchingService(kMainPort, IOServiceMatching("AppleSMC"))
        guard svc != 0 else { return nil }
        defer { IOObjectRelease(svc) }
        guard IOServiceOpen(svc, mach_task_self_, 0, &conn) == KERN_SUCCESS else { return nil }
    }
    deinit { IOServiceClose(conn) }

    private func call(_ i: UnsafeMutableRawPointer, _ o: UnsafeMutableRawPointer) -> Bool {
        var outSize = 80
        return IOConnectCallStructMethod(conn, 2, i, 80, o, &outSize) == KERN_SUCCESS
            && o.load(fromByteOffset: 40, as: UInt8.self) == 0
    }

    /// Читает ключ типа "flt " (4 байта, float)
    func readFloat(_ key: String) -> Double? {
        let k = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let i = UnsafeMutableRawPointer.allocate(byteCount: 80, alignment: 8)
        let o = UnsafeMutableRawPointer.allocate(byteCount: 80, alignment: 8)
        defer { i.deallocate(); o.deallocate() }
        memset(i, 0, 80); memset(o, 0, 80)

        i.storeBytes(of: k, toByteOffset: 0, as: UInt32.self)
        i.storeBytes(of: UInt8(9), toByteOffset: 42, as: UInt8.self)      // read key info
        guard call(i, o) else { return nil }
        let size = o.load(fromByteOffset: 28, as: UInt32.self)
        let type = o.load(fromByteOffset: 32, as: UInt32.self)
        guard size == 4, type == 0x666c7420 else { return nil }           // "flt "

        memset(i, 0, 80); memset(o, 0, 80)
        i.storeBytes(of: k, toByteOffset: 0, as: UInt32.self)
        i.storeBytes(of: size, toByteOffset: 28, as: UInt32.self)
        i.storeBytes(of: UInt8(5), toByteOffset: 42, as: UInt8.self)      // read bytes
        guard call(i, o) else { return nil }
        let raw = o.load(fromByteOffset: 48, as: UInt32.self)
        return Double(Float(bitPattern: raw))
    }
}

// MARK: - Батарея

/// Состояние питания и расчётное время от батареи (оценка по темпу разряда за последние минуты).
enum Power {
    /// Возвращает (процент заряда, питается ли от сети AC).
    static func batteryInfo() -> (percent: Int, onAC: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        // IOPSGetProvidingPowerSourceType / Description — заимствованные (+0): только takeUnretainedValue,
        // иначе ARC добавит лишний release → over-release при старте.
        let providing = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        let onAC = (providing == (kIOPSACPowerValue as String))
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any],
              let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
              let maxc = desc[kIOPSMaxCapacityKey as String] as? Int, maxc > 0
        else { return nil }
        return (current * 100 / maxc, onAC)
    }

    /// Минут до разряда по паре (самый старый, самый новый) за окно данных (~4 мин).
    static func estimateMinutes(_ samples: [(t: Double, pct: Double)]) -> Int? {
        guard samples.count >= 2, let a = samples.first, let b = samples.last else { return nil }
        let span = b.t - a.t
        guard span >= 30 else { return nil }                 // накоплено < 30 с — ещё неточно, пока не показываем
        let drop = a.pct - b.pct
        guard drop > 0.4 else { return nil }                 // нет заметного разряда или идёт зарядка
        let pctPerSec = drop / span
        let minutes = b.pct / (pctPerSec * 60)
        guard minutes.isFinite, minutes > 1 else { return nil }
        return Int(minutes.rounded())
    }

    /// Формат минут → «1h 05m» / «7m» (языкозависимо).
    static func fmtMinutes(_ m: Int) -> String {
        let hu = L.tr("ч"), mu = L.tr("м")
        if m >= 60 {
            let h = m / 60, mm = m % 60
            return "\(h)\(hu) \(String(format: "%02d", mm))\(mu)"
        }
        return "\(m)\(mu)"
    }
}

@MainActor
final class Sampler: ObservableObject {
    @Published var cpu = 0.0
    @Published var memUsed = 0.0
    @Published var memTotal = Double(ProcessInfo.processInfo.physicalMemory)
    @Published var gpu: Double? = nil
    @Published var temp: Double? = nil
    @Published var power: Double? = nil
    @Published var onBattery = false
    @Published var batteryPercent: Int? = nil
    @Published var batteryMinutes: Int? = nil

    private var prevCPU: (busy: UInt64, total: UInt64)?
    private let reader = SensorReader()
    private var batSamples: [(t: Double, pct: Double)] = []   // (время, %) для оценки времени разряда

    func start() {
        Task {
            while !Task.isCancelled {
                let iv = UserDefaults.standard.double(forKey: K.interval)
                try? await Task.sleep(nanoseconds: UInt64((iv > 0 ? iv : 1.0) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await prepare()
            }
        }
    }

    func prepare() async {
        let sample = await reader.read()
        if let c = sample.cpu {
            if let p = prevCPU, c.total > p.total {
                cpu = Double(c.busy - p.busy) / Double(c.total - p.total) * 100
            }
            prevCPU = c
        }
        memUsed = sample.memory
        gpu = sample.gpu
        temp = sample.temperature
        power = sample.power
        readBattery(sample.battery)
    }

    /// Обновляет состояние питания и оценку времени от батареи (заполняется только на батарее).
    private func readBattery(_ battery: (percent: Int, onAC: Bool)?) {
        guard let info = battery else {
            onBattery = false; batteryPercent = nil; batteryMinutes = nil; batSamples.removeAll()
            return
        }
        onBattery = !info.onAC
        if info.onAC {
            batteryPercent = nil
            batteryMinutes = nil
            batSamples.removeAll()                       // от сети — оценку не считаем
            return
        }
        batteryPercent = info.percent
        let now = CACurrentMediaTime()
        batSamples.append((now, Double(info.percent)))     // ~1 выборка/сек на батарее
        if batSamples.count > 240 { batSamples.removeFirst(batSamples.count - 240) }
        batteryMinutes = Power.estimateMinutes(batSamples)
    }

}

private struct SensorSample: Sendable {
    let cpu: (busy: UInt64, total: UInt64)?
    let memory: Double
    let gpu: Double?
    let temperature: Double?
    let power: Double?
    let battery: (percent: Int, onAC: Bool)?
}

// Serial, off-main sensor access: IOKit calls never block animation frames.
private actor SensorReader {
    private lazy var thermals = Thermals()
    private lazy var smc = SMC()

    func read() -> SensorSample {
        let watts = smc?.readFloat("PSTR")
        return SensorSample(cpu: readCPU(), memory: readMem(), gpu: readGPU(),
                            temperature: thermals.read(),
                            power: watts.flatMap { $0 >= 0 && $0 < 1000 ? $0 : nil },
                            battery: Power.batteryInfo())
    }

    private func readCPU() -> (busy: UInt64, total: UInt64)? {
        var numCPU: natural_t = 0
        var info: processor_info_array_t? = nil
        var count: mach_msg_type_number_t = 0
        let r = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPU, &info, &count)
        guard r == KERN_SUCCESS, let info = info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var busy: UInt64 = 0, total: UInt64 = 0
        for i in 0..<Int(numCPU) {
            let b = Int(CPU_STATE_MAX) * i
            let u = UInt64(UInt32(bitPattern: info[b + Int(CPU_STATE_USER)]))
            let s = UInt64(UInt32(bitPattern: info[b + Int(CPU_STATE_SYSTEM)]))
            let n = UInt64(UInt32(bitPattern: info[b + Int(CPU_STATE_NICE)]))
            let d = UInt64(UInt32(bitPattern: info[b + Int(CPU_STATE_IDLE)]))
            busy += u + s + n
            total += u + s + n + d
        }
        return (busy, total)
    }

    private func readMem() -> Double {
        var st = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &st) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let app = Double(st.internal_page_count) - Double(st.purgeable_count)
        return (app + Double(st.wire_count) + Double(st.compressor_page_count)) * Double(getpagesize())
    }

    private func readGPU() -> Double? {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kMainPort, IOServiceMatching("IOAccelerator"), &it) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(it) }
        var best: Double? = nil
        var e = IOIteratorNext(it)
        while e != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(e, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let d = props?.takeRetainedValue() as? [String: Any],
               let perf = d["PerformanceStatistics"] as? [String: Any],
               let u = perf["Device Utilization %"] as? Int {
                best = max(best ?? 0, Double(u))
            }
            IOObjectRelease(e)
            e = IOIteratorNext(it)
        }
        return best
    }
}

// MARK: - Frame time

// MARK: - Определение игр

enum GameDetector {
    /// Ключ приложения в списках: bundle id, а если его нет (Wine и т.п.) — имя исполняемого файла.
    static func key(_ app: NSRunningApplication) -> String {
        app.bundleIdentifier ?? app.executableURL?.lastPathComponent ?? "pid\(app.processIdentifier)"
    }

    static var list: [String] { UserDefaults.standard.stringArray(forKey: K.games) ?? [] }

    /// Автоопределение: категория «Игры», Game Mode, пути Steam/Epic/GOG, Wine/CrossOver/GPTK.
    static func autoDetected(_ app: NSRunningApplication) -> Bool {
        if let url = app.bundleURL, let info = Bundle(url: url)?.infoDictionary {
            if let cat = info["LSApplicationCategoryType"] as? String, cat.lowercased().contains("games") { return true }
            if info["LSSupportsGameMode"] as? Bool == true { return true }
            if (info["CFBundleIdentifier"] as? String ?? app.bundleIdentifier ?? "") == "com.codeweavers.crossover" { return true }
        }
        let path = app.executableURL?.path ?? ""
        let exe = app.executableURL?.lastPathComponent.lowercased() ?? ""
        // Пути store-клиентов
        let fragments = ["/steamapps/common/", "/Epic Games/", "/GOG Games/", "/GOG.com/"]
        if fragments.contains(where: { path.contains($0) }) { return true }
        // Wine / CrossOver / GPTK: exe из бутыли, путь в drive_c, процесс wine-прелоад.
        if exe.hasSuffix(".exe") { return true }
        let lp = path.lowercased()
        if ["/drive_c/", "/crossover/bottles/"] .contains(where: { lp.contains($0) }) { return true }
        if lp.contains("wine") || lp.contains("crossover") || lp.contains("ports" ) { return true }
        if exe.hasPrefix("wine") { return true }
        return false
    }

    static func isGame(_ app: NSRunningApplication) -> Bool {
        let k = key(app)
        let l = list
        if l.contains("!" + k) { return false }              // явно исключено
        if l.contains(k) { return true }                      // добавлено вручную
        return UserDefaults.standard.bool(forKey: K.autoGames) && autoDetected(app)
    }

    /// Переключает статус «игра» для приложения (ручной список / исключение).
    static func toggle(_ app: NSRunningApplication) {
        let k = key(app)
        var l = list
        if isGame(app) {
            l.removeAll { $0 == k }
            if autoDetected(app) && UserDefaults.standard.bool(forKey: K.autoGames) { l.append("!" + k) }
        } else {
            l.removeAll { $0 == "!" + k }
            l.append(k)
        }
        UserDefaults.standard.set(l, forKey: K.games)
    }
}

// MARK: - FPS / frame time активного приложения (ScreenCaptureKit)

private let machTimebase: mach_timebase_info_data_t = {
    var t = mach_timebase_info_data_t()
    mach_timebase_info(&t)
    return t
}()

private func machToSeconds(_ ticks: UInt64) -> Double {
    Double(ticks) * Double(machTimebase.numer) / Double(machTimebase.denom) / 1_000_000_000
}

/// Принимает кадры потока захвата окна и копит их метки времени (потокобезопасно).
/// Новый «complete»-кадр приходит только когда содержимое окна реально обновилось —
/// интервалы между ними и есть frame time приложения.
final class FrameSink: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Double] = []

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sb.isValid,
              let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let att = arr.first,
              let raw = att[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete
        else { return }
        let t: Double
        if let dt = att[.displayTime] as? UInt64 { t = machToSeconds(dt) } else { t = CACurrentMediaTime() }
        lock.lock(); times.append(t); lock.unlock()
    }

    func drain() -> [Double] {
        lock.lock(); defer { lock.unlock() }
        let out = times
        times.removeAll(keepingCapacity: true)
        return out
    }
}

/// Следит за приложением в фокусе и держит поток захвата его главного окна (маленького размера — это дёшево).
@MainActor
final class AppCapture {
    let sink = FrameSink()
    private(set) var appName = ""
    private(set) var note = ""
    private(set) var generation = 0          // растёт при смене цели — монитор сбрасывает историю

    private var stream: SCStream?
    private var windowID: CGWindowID = 0
    var isCapturing: Bool { stream != nil }
    private var busy = false
    private var askedPermission = false
    private var misses = 0                // подряд «нет игры» — чтобы не рвать захват на кратковременный сбой фокуса
    private let missThreshold = 3         // сколько ретаргетов подряд терпеть (каждый ~2 с)
    private let queue = DispatchQueue(label: "perfhud.capture", qos: .userInteractive)

    func retarget() async {
        if busy { return }
        busy = true
        defer { busy = false }

        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        if app.processIdentifier == getpid() { return }          // фокус на самом PerfHUD — цель не меняем
        let name = app.localizedName ?? "App"

        // Захват включается только для игр. Дебаунс: на кратковременный сбой фокуса (окно CrossOver/wine,
        // вспомогательный процесс) захват не рвём и график не чистим — иначе он мерцает.
        guard GameDetector.isGame(app) else {
            guard stream != nil else { return }          // ещё ничего не захватывали — просто ждём
            misses += 1
            if misses < missThreshold { return }          // терпим несколько циклов — график продолжает жить
            misses = 0
            await stopStream()
            appName = ""
            note = "noGame"
            return
        }
        misses = 0
        guard CGPreflightScreenCaptureAccess() else {
            if !askedPermission { askedPermission = true; _ = CGRequestScreenCaptureAccess() }
            await stopStream()
            appName = name
            note = "perm"
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let w = pickWindow(content.windows, app: app, name: name) else {
                await stopStream()
                appName = name
                note = "noWindow"
                return
            }
            appName = name
            note = ""
            if w.windowID == windowID && stream != nil { return }   // цель та же

            await stopStream()
            let cfg = SCStreamConfiguration()
            cfg.width = 96
            cfg.height = 54
            cfg.minimumFrameInterval = CMTime(value: 1, timescale: 240)
            cfg.queueDepth = 5
            cfg.showsCursor = false
            let s = SCStream(filter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg, delegate: nil)
            try s.addStreamOutput(sink, type: .screen, sampleHandlerQueue: queue)
            try await s.startCapture()
            stream = s
            windowID = w.windowID
            generation += 1
        } catch {
            await stopStream()
            appName = name
            note = "err"
        }
    }

    func stop() async {
        await stopStream()
        appName = ""
        note = ""
    }

    /// Выбор окна игры. Игры в «безрамочном» режиме часто имеют нестандартный уровень окна (layer ≠ 0),
    /// а Wine/CrossOver владеют окном из другого процесса — поэтому фильтры мягкие, с запасными вариантами.
    private func pickWindow(_ windows: [SCWindow], app: NSRunningApplication, name: String) -> SCWindow? {
        let area: (SCWindow) -> CGFloat = { $0.frame.width * $0.frame.height }
        let all = windows.filter {
            $0.frame.width >= 100 && $0.frame.height >= 100 && $0.owningApplication?.processID != getpid()
        }
        // 1) окна того же процесса
        var c = all.filter { $0.owningApplication?.processID == app.processIdentifier }
        // 2) тот же bundle id (вспомогательные процессы)
        if c.isEmpty, let bid = app.bundleIdentifier {
            c = all.filter { $0.owningApplication?.bundleIdentifier == bid }
        }
        // 3) то же имя приложения
        if c.isEmpty { c = all.filter { $0.owningApplication?.applicationName == name } }
        // 3b) Wine/CrossOver: окно часто владеет другой wine-процесс группы — ищем окна той же бутыли
        //     (тот же владелец по имени или тот же процесс-группе wine). Пока используем имя — #3 уже взял.
        // 4) последний шанс: окно во весь экран (не системное)
        if c.isEmpty {
            let skip: Set<String> = ["com.apple.dock", "com.apple.finder", "com.apple.WindowManager",
                                     "com.apple.controlcenter", "com.apple.systemuiserver",
                                     "com.apple.loginwindow", "com.apple.notificationcenterui"]
            let screens = NSScreen.screens.map { $0.frame.size }
            c = all.filter { w in
                !skip.contains(w.owningApplication?.bundleIdentifier ?? "")
                    && screens.contains { w.frame.width >= $0.width * 0.95 && w.frame.height >= $0.height * 0.95 }
            }
        }
        if c.isEmpty { dumpWindows(windows, app: app); return nil }
        return c.max(by: { area($0) < area($1) })
    }

    /// Диагностика: список окон в /tmp/perfhud-windows.txt, если подходящее окно не найдено.
    private func dumpWindows(_ windows: [SCWindow], app: NSRunningApplication) {
        var out = "PerfHUD: окно не найдено. В фокусе: \(app.localizedName ?? "?") "
        out += "bid=\(app.bundleIdentifier ?? "-") pid=\(app.processIdentifier) exe=\(app.executableURL?.path ?? "-")\n"
        let sorted = windows.sorted { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }
        for w in sorted.prefix(40) {
            out += "pid=\(w.owningApplication?.processID ?? -1) app=\(w.owningApplication?.applicationName ?? "-") "
            out += "bid=\(w.owningApplication?.bundleIdentifier ?? "-") layer=\(w.windowLayer) "
            out += "onScreen=\(w.isOnScreen) active=\(w.isActive) frame=\(w.frame)\n"
        }
        try? out.write(toFile: "/tmp/perfhud-windows.txt", atomically: true, encoding: .utf8)
    }

    private func stopStream() async {
        guard let s = stream else { return }
        stream = nil
        windowID = 0
        generation += 1
        try? await s.stopCapture()
        _ = sink.drain()
    }
}

// MARK: - Frame time

/// Источник кадров:
///  • 0 — приложение в фокусе (ScreenCaptureKit; нужен доступ «Запись экрана»);
///  • 1 — ритм дисплея (NSScreen.displayLink), без разрешений.
/// График строится по абсолютной временной сетке (бакеты по 50 мс, максимум в бакете) — он не «дрожит»;
/// статистика считается по последним 10 секундам.
@MainActor
final class FrameMonitor: NSObject, ObservableObject {
    static let bucketCount = 200
    static let bucketSec = 0.05                      // 200 × 50 мс = 10 с
    static let windowSec = Double(bucketCount) * bucketSec

    @Published var graph = [Double](repeating: 0, count: FrameMonitor.bucketCount)
    @Published var avgFPS = 0.0
    @Published var lowFPS = 0.0      // 1% low: средний FPS по самым медленным 1% кадров
    @Published var avgMs = 0.0
    @Published var maxMs = 0.0
    @Published var appName = ""
    @Published var note = ""

    private var link: CADisplayLink?
    private var lastDisplay: CFTimeInterval = 0
    private var lastRetargetAt: CFTimeInterval = 0
    private var lastStatsAt: CFTimeInterval = 0
    private var lastApp: Double = 0
    private var events: [(t: CFTimeInterval, ms: Double)] = []
    private var mode = -1
    private var generation = 0
    private var retargeting = false
    private let capture = AppCapture()

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        Task {
            while true {
                // 10 Hz while collecting frame data; idle mode wakes 4 times per second.
                let active = self.mode == 1 || self.capture.isCapturing
                try? await Task.sleep(nanoseconds: active ? 100_000_000 : 250_000_000)
                self.loop()
            }
        }
    }

    @objc private func appChanged() { retarget() }

    // Режим «дисплей»: только копим события (вызывается на каждый кадр дисплея).
    @objc private func displayFrame(_ l: CADisplayLink) {
        guard mode == 1 else { return }
        let now = CACurrentMediaTime()
        if lastDisplay != 0 { events.append((now, (now - lastDisplay) * 1000)) }
        lastDisplay = now
    }

    private func loop() {
        let m = UserDefaults.standard.integer(forKey: K.fpsSource)
        if m != mode {
            mode = m
            events.removeAll(); lastDisplay = 0; lastApp = 0
            appName = ""; note = ""
            if m == 1 {
                startDisplayLink()
                Task { await capture.stop() }
            } else {
                stopDisplayLink()
                retarget()
            }
        }
        if mode == 0 {
            if CACurrentMediaTime() - lastRetargetAt >= 2 { retarget() }
            drainApp()
        }
        let now = CACurrentMediaTime()
        let updateStats = now - lastStatsAt >= 0.5
        if updateStats { lastStatsAt = now }
        refresh(updateStats: updateStats)
    }

    private func startDisplayLink() {
        guard link == nil, let screen = NSScreen.main else { return }
        link = screen.displayLink(target: self, selector: #selector(displayFrame(_:)))
        link?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        link?.invalidate()
        link = nil
        lastDisplay = 0
    }

    private func retarget() {
        guard mode == 0, !retargeting else { return }
        retargeting = true
        lastRetargetAt = CACurrentMediaTime()
        Task {
            await capture.retarget()
            if capture.generation != generation {
                generation = capture.generation
                events.removeAll(); lastApp = 0
            }
            appName = capture.appName
            note = capture.note
            retargeting = false
        }
    }

    private func drainApp() {
        for t in capture.sink.drain() {
            if lastApp > 0 {
                let dt = t - lastApp
                if dt > 0 && dt < 1.0 { events.append((t, dt * 1000)) }   // паузы > 1 с не считаем кадрами
            }
            lastApp = t
        }
    }

    private func refresh(updateStats: Bool) {
        let now = CACurrentMediaTime()
        let n = Self.bucketCount
        let firstIdx = Int(now / Self.bucketSec) - n + 1
        let startT = Double(firstIdx) * Self.bucketSec

        if let i = events.firstIndex(where: { $0.t >= startT }) {
            if i > 0 { events.removeFirst(i) }
        } else {
            events.removeAll()
        }

        // График: максимум кадра в каждом бакете; паузы заполняются длиной кадра, который их закончил
        var out = [Double](repeating: 0, count: n)
        var prev = -1
        for e in events {
            let idx = min(n - 1, max(0, Int(e.t / Self.bucketSec) - firstIdx))
            if prev < 0 {
                out[idx] = max(out[idx], e.ms)
            } else if idx >= prev {
                for b in prev...idx { out[b] = max(out[b], e.ms) }
            }
            prev = max(prev, idx)
        }
        if out != graph { graph = out }

        if updateStats {
            if events.isEmpty {
                avgFPS = 0; lowFPS = 0; avgMs = 0; maxMs = 0
            } else {
                let ms = events.map { $0.ms }
                let mean = ms.reduce(0, +) / Double(ms.count)
                let sorted = ms.sorted(by: >)
                let k = max(1, ms.count / 100)
                let worst = sorted.prefix(k).reduce(0, +) / Double(k)
                avgMs = mean
                maxMs = sorted[0]
                avgFPS = 1000 / mean
                lowFPS = 1000 / worst
            }
        }
    }
}

// MARK: - HUD UI

struct GradBar: View {
    let frac: Double
    let tint: Color
    let k: CGFloat
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.48), tint.opacity(0.92)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(g.size.height, g.size.width * CGFloat(min(max(frac, 0), 1))))
            }
        }
        .frame(height: 3.5 * k)
    }
}

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let frac: Double?
    let tint: Color
    let k: CGFloat
    var vendor: String? = nil

    var body: some View {
        VStack(spacing: 4 * k) {
            HStack(spacing: 6 * k) {
                if let vendor {
                    if vendor == "Apple" {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 10 * k, weight: .medium))
                            .frame(width: 13 * k)
                    } else {
                        Text(vendor == "Intel" ? "intel" : vendor)
                            .font(.system(size: 8 * k, weight: .bold, design: .rounded))
                            .italic(vendor == "Intel")
                            .frame(width: 22 * k, alignment: .leading)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10 * k, weight: .medium))
                        .frame(width: 13 * k)
                }
                Text(label)
                    .font(.system(size: 11.5 * k, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                    .foregroundColor(.white.opacity(0.68))
                if vendor != nil {
                    Text("CPU")
                        .font(.system(size: 9 * k, weight: .medium))
                        .foregroundColor(.white.opacity(0.42))
                        .fixedSize()
                }
                Spacer(minLength: 4)
                Text(value).foregroundColor(.white.opacity(0.96)).monospacedDigit()
            }
            .font(.system(size: 10.5 * k, weight: .medium))
            .foregroundColor(tint)
            if let f = frac { GradBar(frac: f, tint: tint, k: k) }
        }
    }
}

struct FrameGraph: View {
    let data: [Double]
    let tint: Color
    let k: CGFloat
    static let refMs = 1000.0 / 60.0

    // Плавно «дышащая» максимальная шкала (мс).
    @State private var dispMax: CGFloat = 24

    /// Адаптивный максимум по типичным значениям: если кадры стабильны — шкала сжимается к их величине,
    /// чтобы вариации были видны; редкие крупные всплески аккуратно расширяют её (плавно, через animation).
    /// Один проход без сортировки/аллокации копии: гистограмма целых мс + 95-й перцентиль и максимум.
    private static func adaptiveMax(_ data: [Double]) -> Double {
        var hist = [Int](repeating: 0, count: 401)     // 0..400 мс
        var total = 0
        var maxv = 0.0
        for v in data where v > 0.5 {
            let m = Int(min(v.rounded(), 399))         // выбросы > 400 мс копим в последний бакет
            hist[m] += 1
            total += 1
            if v > maxv { maxv = v }
        }
        guard total > 0 else { return 24 }
        // 95-й перцентиль: первый бакет, где накоплено >= 95% значений
        let need = max(1, Int(Double(total) * 0.95))
        var seen = 0, v95 = 0.0
        for (m, c) in hist.enumerated() where c > 0 {
            seen += c
            if seen >= need { v95 = Double(m) + 0.5; break }
        }
        var s = v95 * 1.25 + 1.5
        s = max(s, 6.0)
        if Double(maxv) > v95 * 2.5 { s = max(s, maxv * 0.75) }  // сильный выброс — расширяем
        s = min(s, 400.0)
        return (s / 1.0).rounded() * 1.0                         // квантуем до 1 мс — меньше «прыгающих» анимаций
    }

    var body: some View {
        let target = Self.adaptiveMax(data)
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let sm = CGFloat(max(dispMax, 1e-3))
            let pts: [CGPoint] = data.enumerated().compactMap { (i, v) in
                guard v > 0 else { return nil }
                return CGPoint(x: w * CGFloat(i) / CGFloat(max(data.count - 1, 1)),
                               y: h * (1 - CGFloat(min(v, Double(sm)) / Double(sm))))
            }
            ZStack {
                Path { p in                                   // 60 FPS (16.7 мс)
                    let y = h * (1 - CGFloat(Self.refMs / Double(sm)))
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                Path { p in                                   // заливка под линией
                    guard let first = pts.first, let last = pts.last else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    p.addLine(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: last.x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0)], startPoint: .top, endPoint: .bottom))

                Path { p in                                   // линия
                    for (i, pt) in pts.enumerated() {
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.1 * k, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 36 * k)
        .onChange(of: target) { _, newV in
            withAnimation(.easeInOut(duration: 0.5)) { dispMax = CGFloat(newV) }
        }
    }
}

struct MetricsView: View {
    @ObservedObject var s: Sampler
    @AppStorage(K.cpu) private var showCPU = true
    @AppStorage(K.gpu) private var showGPU = true
    @AppStorage(K.ram) private var showRAM = true
    @AppStorage(K.temp) private var showTemp = true
    @AppStorage(K.power) private var showPower = true
    @AppStorage(K.fahrenheit) private var fahrenheit = false
    @AppStorage(K.accent) private var accent = "auto"
    @AppStorage(K.scale) private var scale = 1.0
    @AppStorage(K.batteryTime) private var showBattery = true

    private func gb(_ b: Double) -> String { String(format: "%.1f", b / 1_073_741_824) }

    // Обновляется только когда меняются метрики (Sampler, ~1 Гц) — не при каждом кадре графика.
    var body: some View {
        let k = CGFloat(scale)
        let memPct = s.memTotal > 0 ? s.memUsed / s.memTotal * 100 : 0
        // Значение PWR + заряд/время от батареи (вне ViewBuilder — не может быть выражено if-оператором)
        let pwrText: String = {
            var v = s.power.map { String(format: "%.1f W", $0) } ?? "—"
            if s.onBattery && showBattery {
                let pct = s.batteryPercent.map { "\($0)%" } ?? ""
                let tm = s.batteryMinutes.map { Power.fmtMinutes($0) } ?? L.tr("бат")
                v += " · " + [pct, tm].filter { !$0.isEmpty }.joined(separator: " · ")
            }
            return v
        }()
        VStack(alignment: .leading, spacing: 9 * k) {
            if showCPU {
                MetricRow(icon: "cpu", label: CPUIdentity.name, value: String(format: "%.0f%%", s.cpu),
                          frac: s.cpu / 100, tint: hudTint(accent, load: s.cpu), k: k,
                          vendor: CPUIdentity.vendor)
            }
            if showGPU {
                MetricRow(icon: "display", label: "GPU", value: s.gpu.map { String(format: "%.0f%%", $0) } ?? "—",
                          frac: (s.gpu ?? 0) / 100, tint: hudTint(accent, load: s.gpu ?? 0), k: k)
            }
            if showRAM {
                MetricRow(icon: "memorychip", label: "RAM", value: "\(gb(s.memUsed)) / \(gb(s.memTotal)) GB",
                          frac: memPct / 100, tint: hudTint(accent, load: memPct), k: k)
            }
            if showTemp {
                let t = s.temp
                let shown = t.map { fahrenheit ? $0 * 9 / 5 + 32 : $0 }
                MetricRow(icon: "thermometer.medium", label: "TEMP",
                          value: shown.map { String(format: "%.0f°%@", $0, fahrenheit ? "F" : "C") } ?? "—",
                          // Reserve the bar before the first sensor reading so launch geometry stays stable.
                          frac: max(0, ((t ?? 30) - 30) / 70),
                          tint: hudTint(accent, load: ((t ?? 30) - 30) / 70 * 100), k: k)
            }
            if showPower {
                MetricRow(icon: "bolt.fill", label: "PWR", value: pwrText,
                          frac: nil, tint: hudTint(accent == "auto" ? "orange" : accent, load: 0), k: k)
            }
        }
    }
}

struct FPSView: View {
    @ObservedObject var f: FrameMonitor
    @AppStorage(K.accent) private var accent = "auto"
    @AppStorage(K.scale) private var scale = 1.0

    // Обновляется только при изменениях FrameMonitor (график ~20 Гц) — не пересобирает метрики.
    var body: some View {
        let k = CGFloat(scale)
        let c = hudTint(accent == "auto" ? "mint" : accent, load: 0)
        // Токен заметки → локализованный текст
        let noteStr: String = {
            switch f.note {
            case "noGame": return L.tr("нет игры")
            case "perm":   return L.tr("нужен доступ")
            case "noWindow": return L.tr("нет окна")
            case "err":    return L.tr("ошибка захвата")
            default:       return ""
            }
        }()
        let isNoGame = f.note == "noGame"
        VStack(spacing: 4 * k) {
            HStack(spacing: 6 * k) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 9.5 * k, weight: .semibold))
                    .foregroundColor(c)
                    .frame(width: 13 * k)
                Text(f.appName.isEmpty ? "FPS" : f.appName)
                    .font(.system(size: 11.5 * k, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(noteStr.isEmpty ? (f.avgFPS > 0 ? String(format: "%.0f FPS", f.avgFPS) : "—") : noteStr)
                    .foregroundColor(noteStr.isEmpty ? .white : (isNoGame ? .white.opacity(0.4) : .orange))
                    .monospacedDigit()
                    .fixedSize()
            }
            .font(.system(size: 10.5 * k, weight: .medium))
            FrameGraph(data: f.graph, tint: c, k: k)
            HStack {
                Text(f.avgFPS > 0 ? "\(L.tr("1% low")) \(String(format: "%.0f", f.lowFPS))" : "\(L.tr("1% low")) —")
                Spacer()
                Text(f.avgFPS > 0 ? "\(String(format: "%.1f", f.avgMs)) \(L.tr("мс")) · \(L.tr("макс.")) \(String(format: "%.0f", f.maxMs))" : L.tr("— ms"))
            }
            .font(.system(size: 9 * k, weight: .medium))
            .foregroundColor(.white.opacity(0.58))
            .monospacedDigit()
        }
    }
}

struct HUDView: View {
    let s: Sampler
    let f: FrameMonitor
    @AppStorage(K.frame) private var showFrame = true
    @AppStorage(K.scale) private var scale = 1.0

    // Не наблюдает объекты с данными — реагирует только на настройки (редко).
    // Обновления метрик (1 Гц) и графика (20 Гц) обрабатывают изолированные под-вью.
    var body: some View {
        let k = CGFloat(scale)
        VStack(alignment: .leading, spacing: 9 * k) {
            MetricsView(s: s)
            if showFrame { FPSView(f: f) }
        }
        .padding(12 * k)
        .frame(width: 214 * k)
        .glassEffect(.regular.tint(.black.opacity(0.38)),
                     in: RoundedRectangle(cornerRadius: 18 * k, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Окно настроек

struct SettingsView: View {
    @AppStorage(K.cpu) private var showCPU = true
    @AppStorage(K.gpu) private var showGPU = true
    @AppStorage(K.ram) private var showRAM = true
    @AppStorage(K.temp) private var showTemp = true
    @AppStorage(K.power) private var showPower = true
    @AppStorage(K.frame) private var showFrame = true
    @AppStorage(K.opacity) private var opacity = 0.85
    @AppStorage(K.scale) private var scale = 1.0
    @AppStorage(K.interval) private var interval = 1.0
    @AppStorage(K.fahrenheit) private var fahrenheit = false
    @AppStorage(K.clickThrough) private var clickThrough = false
    @AppStorage(K.locked) private var locked = false
    @AppStorage(K.accent) private var accent = "auto"
    @AppStorage(K.level) private var level = 2
    @AppStorage(K.fpsSource) private var fpsSource = 0
    @AppStorage(K.autoGames) private var autoGames = true
    @AppStorage(K.batteryTime) private var showBatteryTime = true
    @AppStorage(K.lang) private var language = "auto"
    @State private var games: [String] = UserDefaults.standard.stringArray(forKey: K.games) ?? []
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section(L.tr("Показатели")) {
                Toggle("CPU", isOn: $showCPU)
                Toggle("GPU", isOn: $showGPU)
                Toggle(L.tr("Память (RAM)"), isOn: $showRAM)
                Toggle(L.tr("Температура"), isOn: $showTemp)
                Toggle(L.tr("Потребление (Вт)"), isOn: $showPower)
                Toggle(L.tr("Время и заряд от батареи"), isOn: $showBatteryTime)
                Toggle(L.tr("График времени кадра"), isOn: $showFrame)
            }

            Section(L.tr("Внешний вид")) {
                HStack {
                    Text(L.tr("Прозрачность окна"))
                    Slider(value: $opacity, in: 0.3...1)
                    Text("\(Int(opacity * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text(L.tr("Размер"))
                    Slider(value: $scale, in: 0.8...1.5)
                    Text("\(Int(scale * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                Picker(L.tr("Цвет"), selection: $accent) {
                    Text(L.tr("Авто (по нагрузке)")).tag("auto")
                    Text(L.tr("Синий")).tag("blue")
                    Text(L.tr("Фиолетовый")).tag("purple")
                    Text(L.tr("Оранжевый")).tag("orange")
                    Text(L.tr("Мятный")).tag("mint")
                    Text(L.tr("Розовый")).tag("pink")
                }
                Toggle(L.tr("Температура в °F"), isOn: $fahrenheit)
            }

            Section(L.tr("Поведение")) {
                Picker(L.tr("Уровень окна"), selection: $level) {
                    Text(L.tr("Обычный")).tag(0)
                    Text(L.tr("Поверх окон")).tag(1)
                    Text(L.tr("Поверх игр (максимум)")).tag(2)
                }
                Toggle(L.tr("Закрепить (нельзя перетаскивать)"), isOn: $locked)
                Toggle(L.tr("Click-through (клики проходят сквозь HUD)"), isOn: $clickThrough)
                Picker(L.tr("Частота обновления"), selection: $interval) {
                    Text(L.tr("0.5 с")).tag(0.5)
                    Text(L.tr("1 с")).tag(1.0)
                    Text(L.tr("2 с")).tag(2.0)
                }
                Button(L.tr("Сбросить положение")) {
                    NotificationCenter.default.post(name: .resetPosition, object: nil)
                }
            }

            Section(L.tr("FPS и frame time")) {
                Picker(L.tr("Источник"), selection: $fpsSource) {
                    Text(L.tr("Приложение в фокусе")).tag(0)
                    Text(L.tr("Дисплей (ритм композитора)")).tag(1)
                }
                Button(L.tr("Открыть доступ «Запись экрана»…")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section(L.tr("Игры")) {
                Toggle(L.tr("Определять игры автоматически"), isOn: $autoGames)
                Text(L.tr("FPS и frame time показываются только для игр: по категории «Игры», путям Steam / Epic / GOG и Wine / CrossOver. Остальное можно добавить вручную."))
                    .font(.caption).foregroundColor(.secondary)
                ForEach(games, id: \.self) { g in
                    HStack {
                        Text(g.hasPrefix("!") ? L.tr("исключено: ") + g.dropFirst() : g)
                        Spacer()
                        Button(L.tr("Убрать")) {
                            games.removeAll { $0 == g }
                            UserDefaults.standard.set(games, forKey: K.games)
                        }
                    }
                }
                Button(L.tr("Добавить приложение…")) {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.application]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications")
                    if panel.runModal() == .OK, let url = panel.url {
                        let key = Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
                        if !games.contains(key) {
                            games.append(key)
                            UserDefaults.standard.set(games, forKey: K.games)
                        }
                    }
                }
            }

            Section(L.tr("Система")) {
                Toggle(L.tr("Запускать при входе в систему"), isOn: Binding(
                    get: { loginEnabled },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {}
                        loginEnabled = SMAppService.mainApp.status == .enabled
                    }))
            }

            Section(L.tr("Язык")) {
                Picker(L.tr("Язык"), selection: $language) {
                    Text(L.tr("Авто (язык системы)")).tag("auto")
                    Text("English").tag("en")
                    Text("Українська").tag("uk")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 720)
        .onChange(of: language) { _, _ in
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
}

// MARK: - App

/// Любое нажатие на HUD начинает перетаскивание окна (если не закреплено).
final class DragHostingView<Content: View>: NSHostingView<Content> {
    var locked = false
    override var mouseDownCanMoveWindow: Bool { !locked }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if !locked { window?.performDrag(with: event) }
    }
}

@MainActor
private final class LaunchProgress: ObservableObject {
    @Published var fraction = 0.0
}

private struct LaunchTitleView: View {
    @ObservedObject var progress: LaunchProgress
    @AppStorage(K.accent) private var accent = "auto"
    @AppStorage(K.scale) private var scale = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        let k = CGFloat(scale)
        let tint = hudTint(accent, load: 0)
        VStack(spacing: 14 * k) {
            Text("PerfHUD")
                .font(.system(size: 28 * k, weight: .semibold, design: .rounded))
                .tracking(1.5 * k)
                .foregroundStyle(.white)
                .shadow(color: tint.opacity(0.35), radius: 10 * k)
            Capsule()
                .fill(.white.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.48), tint.opacity(0.92)],
                                             startPoint: .leading, endPoint: .trailing))
                        .scaleEffect(x: progress.fraction, y: 1, anchor: .leading)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progress.fraction)
                }
                .frame(width: 110 * k, height: 3.5 * k)
        }
            .opacity(revealed ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular.tint(.black.opacity(0.38)),
                         in: RoundedRectangle(cornerRadius: 18 * CGFloat(UserDefaults.standard.double(forKey: K.scale)), style: .continuous))
            .environment(\.colorScheme, .dark)
        .task {
            // Allow text and glass to render before the first animated frame.
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9)) {
                revealed = true
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let sampler = Sampler()
    let frames = FrameMonitor()
    var panel: NSPanel!
    var host: DragHostingView<HUDView>!
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var userHidden = false
    var gameItem: NSMenuItem!
    private var isAppearing = false
    private var launchPanel: NSPanel?
    private var monitoringStarted = false
    private let launchProgress = LaunchProgress()

    private func startMonitoring() {
        guard !monitoringStarted else { return }
        monitoringStarted = true
        sampler.start()
        frames.start()
    }

    private func showLaunchTitle() {
        let splash = NSPanel(contentRect: panel.frame,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        splash.contentView = NSHostingView(rootView: LaunchTitleView(progress: launchProgress))
        splash.isOpaque = false
        splash.backgroundColor = .clear
        splash.hasShadow = false
        splash.level = panel.level
        splash.collectionBehavior = panel.collectionBehavior
        splash.hidesOnDeactivate = false
        splash.ignoresMouseEvents = true
        splash.isReleasedWhenClosed = false
        splash.setFrame(panel.frame, display: false)
        splash.alphaValue = CGFloat(UserDefaults.standard.double(forKey: K.opacity))
        launchPanel = splash
        splash.contentView?.layoutSubtreeIfNeeded()
        splash.contentView?.displayIfNeeded()
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        splash.orderFrontRegardless()

        Task { @MainActor [weak self] in
            guard let self, let splash = self.launchPanel else { return }
            // Timing is a readability minimum, never a substitute for readiness.
            let visibleSince = ContinuousClock.now
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.launchProgress.fraction = 0.25 // Interface laid out and rendered.
            await self.sampler.prepare() // First real sensor snapshot, off the main actor.
            self.launchProgress.fraction = 0.75
            self.host.layoutSubtreeIfNeeded()
            self.host.displayIfNeeded() // Prepare the HUD with its initial readings.
            self.launchProgress.fraction = 1
            // Let the final progress animation settle and retain the title for 1.5 s.
            let deadline = max(visibleSince.advanced(by: .milliseconds(1500)),
                               ContinuousClock.now.advanced(by: .milliseconds(350)))
            try? await ContinuousClock().sleep(until: deadline)
            if !self.userHidden { self.showPanel() }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.7
                splash.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.launchPanel?.close()
                    self.launchPanel = nil
                    self.startMonitoring()
                }
            }
        }
    }

    private func showPanel() {
        guard !panel.isVisible else { return }
        let opacity = CGFloat(UserDefaults.standard.double(forKey: K.opacity))
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.alphaValue = opacity
            panel.orderFrontRegardless()
            return
        }
        isAppearing = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.7
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = opacity
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAppearing = false
                self.panel.alphaValue = CGFloat(UserDefaults.standard.double(forKey: K.opacity))
            }
        }
    }

    @objc func reassert() {
        guard !userHidden, launchPanel == nil else { return }
        panel.orderFrontRegardless()
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        L.setup()
        UserDefaults.standard.register(defaults: [
            K.cpu: true, K.gpu: true, K.ram: true, K.temp: true, K.power: true, K.frame: true,
            K.opacity: 0.85, K.scale: 1.0, K.interval: 1.0,
            K.fahrenheit: false, K.accent: "auto",
            K.clickThrough: false, K.locked: false, K.level: 2, K.fpsSource: 0, K.autoGames: true,
            K.batteryTime: true,
        ])

        host = DragHostingView(rootView: HUDView(s: sampler, f: frames))
        let size = host.fittingSize
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false          // иначе панель прячется, когда активна игра
        panel.becomesKeyOnlyIfNeeded = true
        resetPosition()
        panel.setFrameAutosaveName("PerfHUDPanel")                 // запоминает положение
        applySettings()
        showLaunchTitle()

        // Меню в строке меню
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent",
                                           accessibilityDescription: "PerfHUD")
        buildMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetPositionNote),
                                               name: .resetPosition, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChangedNote),
                                               name: .languageChanged, object: nil)

        // Игры могут поднять своё окно выше — возвращаем HUD наверх при смене приложения/Space и раз в 2 с
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(reassert),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(reassert),
                       name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                // Возвращаем HUD наверх только когда в фокусе игра — в обычной работе не дёргаем окно (меньше мерцания)
                if (self.focusedApp().map(GameDetector.isGame) ?? false) { self.reassert() }
            }
        }
    }

    @objc func settingsChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.applySettings() }
    }

    func applySettings() {
        let d = UserDefaults.standard
        if !isAppearing { panel.alphaValue = CGFloat(d.double(forKey: K.opacity)) }
        panel.ignoresMouseEvents = d.bool(forKey: K.clickThrough)
        switch d.integer(forKey: K.level) {
        case 0:  panel.level = .normal
        case 1:  panel.level = .statusBar
        default: panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))   // выше игр и полноэкранных окон
        }
        host.locked = d.bool(forKey: K.locked)
        // подогнать размер под содержимое, сохранив левый верхний угол
        let size = host.fittingSize
        if abs(size.width - panel.frame.width) > 0.5 || abs(size.height - panel.frame.height) > 0.5 {
            var fr = panel.frame
            fr.origin.y += fr.height - size.height
            fr.size = size
            panel.setFrame(fr, display: true)
        }
        launchPanel?.setFrame(panel.frame, display: true)
        launchPanel?.level = panel.level
    }

    @objc func resetPositionNote() {
        resetPosition()
        launchPanel?.setFrame(panel.frame, display: true)
    }

    func resetPosition() {
        let size = host.fittingSize
        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - size.width - 14, y: f.maxY - size.height - 14))
        }
    }

    private func focusedApp() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return nil }
        return app
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let app = focusedApp() {
            gameItem.title = L.trFmt("«%@» — это игра", (app.localizedName ?? L.tr("Приложение")) as NSString)
            gameItem.state = GameDetector.isGame(app) ? .on : .off
            gameItem.isEnabled = true
        } else {
            gameItem.title = L.tr("Приложение в фокусе — игра")
            gameItem.state = .off
            gameItem.isEnabled = false
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: L.tr("Показать / скрыть"), action: #selector(toggle), keyEquivalent: "h").target = self
        menu.addItem(withTitle: L.tr("Настройки…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        gameItem = menu.addItem(withTitle: L.tr("Приложение в фокусе — игра"), action: #selector(toggleGame), keyEquivalent: "g")
        gameItem.target = self
        menu.delegate = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.tr("Выход"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc func languageChangedNote() {
        L.refresh()
        buildMenu()
        host.rootView = HUDView(s: sampler, f: frames)
        if let settingsWindow {
            settingsWindow.title = L.tr("PerfHUD — Настройки")
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        }
        applySettings()
    }

    @objc func toggleGame() {
        if let app = focusedApp() { GameDetector.toggle(app) }
    }

    @objc func toggle() {
        if let launchPanel {
            userHidden.toggle()
            if userHidden { launchPanel.orderOut(nil) } else { launchPanel.orderFrontRegardless() }
            return
        }
        userHidden = panel.isVisible
        if userHidden { panel.orderOut(nil) } else { showPanel() }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.title = L.tr("PerfHUD — Настройки")
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

@main
struct PerfHUDApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
