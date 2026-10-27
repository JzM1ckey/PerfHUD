// PerfHUD — минималистичный HUD производительности для macOS 14+ (лучше всего на Apple Silicon)
// CPU · GPU · RAM · температура · потребление (Вт) · график времени кадра + окно настроек.
// Сборка приложения: bash build_app.sh  →  PerfHUD.app

import Cocoa
import SwiftUI
import IOKit
import QuartzCore
import ServiceManagement

private let kMainPort: mach_port_t = 0   // замена kIOMainPortID

// MARK: - Настройки

enum K {
    static let cpu = "showCPU", gpu = "showGPU", ram = "showRAM"
    static let temp = "showTemp", power = "showPower", frame = "showFrame"
    static let opacity = "opacity", bg = "bgOpacity", scale = "scale"
    static let interval = "interval", fahrenheit = "fahrenheit", accent = "accent"
    static let clickThrough = "clickThrough", locked = "locked", onTop = "onTop"
}

extension Notification.Name {
    static let resetPosition = Notification.Name("PerfHUDResetPosition")
}

enum Palette {
    static func color(_ accent: String, load: Double) -> Color {
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

// MARK: - Sampler

@MainActor
final class Sampler: ObservableObject {
    @Published var cpu = 0.0
    @Published var memUsed = 0.0
    @Published var memTotal = Double(ProcessInfo.processInfo.physicalMemory)
    @Published var gpu: Double? = nil
    @Published var temp: Double? = nil
    @Published var power: Double? = nil

    private var prevCPU: (busy: UInt64, total: UInt64)?
    private let thermals = Thermals()
    private let smc = SMC()

    func start() {
        tick()
        Task {
            while true {
                let iv = UserDefaults.standard.double(forKey: K.interval)
                try? await Task.sleep(nanoseconds: UInt64((iv > 0 ? iv : 1.0) * 1_000_000_000))
                self.tick()
            }
        }
    }

    func tick() {
        if let c = readCPU() {
            if let p = prevCPU, c.total > p.total {
                cpu = Double(c.busy - p.busy) / Double(c.total - p.total) * 100
            }
            prevCPU = c
        }
        memUsed = readMem()
        gpu = readGPU()
        temp = thermals.read()
        if let p = smc?.readFloat("PSTR"), p >= 0, p < 1000 { power = p } else { power = nil }
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

/// Интервалы между кадрами дисплея, доставленными в главный поток (NSScreen.displayLink).
/// Всплески = просадки/фризы композитора или главного потока, а не FPS конкретного приложения.
@MainActor
final class FrameMonitor: NSObject, ObservableObject {
    static let n = 120
    @Published var samples = [Double]()
    @Published var refreshMs = 16.67

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var buf = [Double]()

    func start() {
        guard let screen = NSScreen.main else { return }
        link = screen.displayLink(target: self, selector: #selector(frame(_:)))
        link?.add(to: .main, forMode: .common)
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 66_000_000)   // ~15 Гц обновление графика
                self.samples = self.buf
            }
        }
    }

    @objc private func frame(_ l: CADisplayLink) {
        let now = CACurrentMediaTime()
        if last != 0 {
            buf.append((now - last) * 1000)
            if buf.count > FrameMonitor.n { buf.removeFirst(buf.count - FrameMonitor.n) }
        }

        last = now
        let p = (l.targetTimestamp - l.timestamp) * 1000
        if p > 1 && p < 100 { refreshMs = p }
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
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.55), tint], startPoint: .leading, endPoint: .trailing))
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

    var body: some View {
        VStack(spacing: 4 * k) {
            HStack(spacing: 6 * k) {
                Image(systemName: icon)
                    .font(.system(size: 9.5 * k, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 13 * k)
                Text(label).foregroundColor(.white.opacity(0.6))
                Spacer(minLength: 4)
                Text(value).foregroundColor(.white).monospacedDigit()
            }
            .font(.system(size: 10.5 * k, weight: .medium, design: .rounded))
            if let f = frac { GradBar(frac: f, tint: tint, k: k) }
        }

    }
}

struct FrameGraph: View {
    let samples: [Double]
    let refreshMs: Double
    let tint: Color
    let k: CGFloat

    var body: some View {
        let scaleMax = max(refreshMs * 2.5, min(samples.max() ?? 0, refreshMs * 10))
        GeometryReader { g in
            let pts: [CGPoint] = samples.enumerated().map { (i, v) in
                CGPoint(x: g.size.width * CGFloat(i) / CGFloat(FrameMonitor.n - 1),
                        y: g.size.height * (1 - CGFloat(min(v, scaleMax) / scaleMax)))
            }
            ZStack {
                Path { p in                                   // период кадра
                    let y = g.size.height * (1 - CGFloat(refreshMs / scaleMax))
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                Path { p in                                   // заливка под линией
                    guard let first = pts.first, let last = pts.last else { return }
                    p.move(to: CGPoint(x: first.x, y: g.size.height))
                    p.addLine(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: last.x, y: g.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0)], startPoint: .top, endPoint: .bottom))

                Path { p in                                   // линия
                    for (i, pt) in pts.enumerated() {
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.2 * k, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 36 * k)
    }
}

struct HUDView: View {
    @ObservedObject var s: Sampler
    @ObservedObject var f: FrameMonitor

    @AppStorage(K.cpu) private var showCPU = true
    @AppStorage(K.gpu) private var showGPU = true
    @AppStorage(K.ram) private var showRAM = true
    @AppStorage(K.temp) private var showTemp = true
    @AppStorage(K.power) private var showPower = true
    @AppStorage(K.frame) private var showFrame = true
    @AppStorage(K.bg) private var bg = 0.35
    @AppStorage(K.scale) private var scale = 1.0
    @AppStorage(K.fahrenheit) private var fahrenheit = false
    @AppStorage(K.accent) private var accent = "auto"

    private func gb(_ b: Double) -> String { String(format: "%.1f", b / 1_073_741_824) }

    var body: some View {
        let k = CGFloat(scale)
        let avg = f.samples.isEmpty ? 0 : f.samples.reduce(0, +) / Double(f.samples.count)
        let worst = f.samples.max() ?? 0
        let memPct = s.memTotal > 0 ? s.memUsed / s.memTotal * 100 : 0

        VStack(alignment: .leading, spacing: 9 * k) {
            if showCPU {
                MetricRow(icon: "cpu", label: "CPU", value: String(format: "%.0f%%", s.cpu),
                          frac: s.cpu / 100, tint: Palette.color(accent, load: s.cpu), k: k)
            }
            if showGPU {
                MetricRow(icon: "display", label: "GPU", value: s.gpu.map { String(format: "%.0f%%", $0) } ?? "—",
                          frac: (s.gpu ?? 0) / 100, tint: Palette.color(accent, load: s.gpu ?? 0), k: k)
            }
            if showRAM {
                MetricRow(icon: "memorychip", label: "RAM", value: "\(gb(s.memUsed)) / \(gb(s.memTotal)) GB",
                          frac: memPct / 100, tint: Palette.color(accent, load: memPct), k: k)
            }
            if showTemp {
                let t = s.temp
                let shown = t.map { fahrenheit ? $0 * 9 / 5 + 32 : $0 }
                MetricRow(icon: "thermometer.medium", label: "TEMP",
                          value: shown.map { String(format: "%.0f°%@", $0, fahrenheit ? "F" : "C") } ?? "—",
                          frac: t.map { max(0, ($0 - 30) / 70) },
                          tint: Palette.color(accent, load: ((t ?? 30) - 30) / 70 * 100), k: k)
            }
            if showPower {
                MetricRow(icon: "bolt.fill", label: "PWR",
                          value: s.power.map { String(format: "%.1f W", $0) } ?? "—",
                          frac: nil, tint: Palette.color(accent == "auto" ? "orange" : accent, load: 0), k: k)
            }
            if showFrame {
                VStack(spacing: 4 * k) {
                    HStack(spacing: 6 * k) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 9.5 * k, weight: .semibold))

                            .foregroundColor(Palette.color(accent == "auto" ? "mint" : accent, load: 0))
                            .frame(width: 13 * k)
                        Text("FRAME").foregroundColor(.white.opacity(0.6))
                        Spacer(minLength: 4)
                        Text(String(format: "%.1f ms · max %.0f", avg, worst))
                            .foregroundColor(.white).monospacedDigit()
                    }
                    .font(.system(size: 10.5 * k, weight: .medium, design: .rounded))
                    FrameGraph(samples: f.samples, refreshMs: f.refreshMs,
                               tint: Palette.color(accent == "auto" ? "mint" : accent, load: 0), k: k)
                }
            }
        }
        .padding(12 * k)
        .frame(width: 214 * k)
        .background(Color.black.opacity(bg))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14 * k, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * k, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
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
    @AppStorage(K.bg) private var bg = 0.35
    @AppStorage(K.scale) private var scale = 1.0
    @AppStorage(K.interval) private var interval = 1.0
    @AppStorage(K.fahrenheit) private var fahrenheit = false
    @AppStorage(K.accent) private var accent = "auto"
    @AppStorage(K.clickThrough) private var clickThrough = false
    @AppStorage(K.locked) private var locked = false
    @AppStorage(K.onTop) private var onTop = true
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Показатели") {
                Toggle("CPU", isOn: $showCPU)
                Toggle("GPU", isOn: $showGPU)
                Toggle("Память (RAM)", isOn: $showRAM)
                Toggle("Температура", isOn: $showTemp)
                Toggle("Потребление (Вт)", isOn: $showPower)
                Toggle("График времени кадра", isOn: $showFrame)
            }

            Section("Внешний вид") {
                HStack {
                    Text("Прозрачность окна")
                    Slider(value: $opacity, in: 0.3...1)
                    Text("\(Int(opacity * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("Плотность фона")
                    Slider(value: $bg, in: 0...0.8)
                    Text("\(Int(bg / 0.8 * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("Размер")
                    Slider(value: $scale, in: 0.8...1.5)
                    Text("\(Int(scale * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                Picker("Цвет", selection: $accent) {
                    Text("Авто (по нагрузке)").tag("auto")
                    Text("Синий").tag("blue")
                    Text("Фиолетовый").tag("purple")
                    Text("Оранжевый").tag("orange")
                    Text("Мятный").tag("mint")
                    Text("Розовый").tag("pink")
                }
                Toggle("Температура в °F", isOn: $fahrenheit)
            }

            Section("Поведение") {
                Toggle("Поверх всех окон", isOn: $onTop)
                Toggle("Закрепить (нельзя перетаскивать)", isOn: $locked)
                Toggle("Click-through (клики проходят сквозь HUD)", isOn: $clickThrough)
                Picker("Частота обновления", selection: $interval) {
                    Text("0.5 с").tag(0.5)
                    Text("1 с").tag(1.0)
                    Text("2 с").tag(2.0)
                }
                Button("Сбросить положение") {
                    NotificationCenter.default.post(name: .resetPosition, object: nil)
                }
            }

            Section("Система") {
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { loginEnabled },

                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() }

                            else { try SMAppService.mainApp.unregister() }
                        } catch {}
                        loginEnabled = SMAppService.mainApp.status == .enabled
                    }))
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 600)
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sampler = Sampler()
    let frames = FrameMonitor()
    var panel: NSPanel!
    var host: DragHostingView<HUDView>!
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        UserDefaults.standard.register(defaults: [
            K.cpu: true, K.gpu: true, K.ram: true, K.temp: true, K.power: true, K.frame: true,
            K.opacity: 0.85, K.bg: 0.35, K.scale: 1.0, K.interval: 1.0,
            K.fahrenheit: false, K.accent: "auto",
            K.clickThrough: false, K.locked: false, K.onTop: true,
        ])

        sampler.start()
        frames.start()

        host = DragHostingView(rootView: HUDView(s: sampler, f: frames))
        let size = host.fittingSize
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        resetPosition()
        panel.setFrameAutosaveName("PerfHUDPanel")                 // запоминает положение
        applySettings()
        panel.orderFrontRegardless()

        // Меню в строке меню
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent",
                                           accessibilityDescription: "PerfHUD")
        let menu = NSMenu()
        menu.addItem(withTitle: "Показать / скрыть", action: #selector(toggle), keyEquivalent: "h").target = self
        menu.addItem(withTitle: "Настройки…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetPositionNote),
                                               name: .resetPosition, object: nil)
    }

    @objc func settingsChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.applySettings() }
    }

    func applySettings() {
        let d = UserDefaults.standard
        panel.alphaValue = CGFloat(d.double(forKey: K.opacity))
        panel.ignoresMouseEvents = d.bool(forKey: K.clickThrough)
        panel.level = d.bool(forKey: K.onTop) ? .statusBar : .normal
        host.locked = d.bool(forKey: K.locked)

        // подогнать размер под содержимое, сохранив левый верхний угол
        let size = host.fittingSize
        if abs(size.width - panel.frame.width) > 0.5 || abs(size.height - panel.frame.height) > 0.5 {
            var fr = panel.frame
            fr.origin.y += fr.height - size.height
            fr.size = size
            panel.setFrame(fr, display: true)
        }
    }


    @objc func resetPositionNote() { resetPosition() }

    func resetPosition() {
        let size = host.fittingSize

        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - size.width - 14, y: f.maxY - size.height - 14))
        }
    }

    @objc func toggle() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.title = "PerfHUD — Настройки"
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
