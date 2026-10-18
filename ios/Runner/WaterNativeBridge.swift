import Flutter
import Combine
import SwiftUI
import UIKit

final class WaterNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var parent: UIViewController?

    init(messenger: FlutterBinaryMessenger, parent: UIViewController?) {
        self.messenger = messenger
        self.parent = parent
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        WaterNativePlatformView(frame: frame, id: viewId, messenger: messenger, parent: parent)
    }
}

final class WaterNativePlatformView: NSObject, FlutterPlatformView {
    private let controller: UIHostingController<WaterNativeRoot>
    private let store: WaterNativeStore
    private let container: WaterHostingContainer

    init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, parent: UIViewController?) {
        store = WaterNativeStore(channel: FlutterMethodChannel(name: "com.fakeuy.water/native_ui_\(id)", binaryMessenger: messenger))
        controller = UIHostingController(rootView: WaterNativeRoot(store: store))
        container = WaterHostingContainer(frame: frame)
        super.init()
        controller.view.frame = frame
        controller.view.backgroundColor = .clear
        controller.overrideUserInterfaceStyle = .dark
        container.host = controller
        controller.view.frame = container.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let parent = parent {
            parent.addChild(controller)
            container.addSubview(controller.view)
            controller.didMove(toParent: parent)
        } else {
            container.addSubview(controller.view)
        }
    }

    func view() -> UIView { container }

    deinit {
        store.disconnect()
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }
}

/// The implicit engine can register the factory before its Flutter controller
/// exists. Attach once the platform UIView joins the responder hierarchy so
/// SwiftUI sheets, PHPicker, and safe-area propagation have a proper parent.
private final class WaterHostingContainer: UIView {
    weak var host: UIViewController?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, let host = host, host.parent == nil else { return }
        var responder: UIResponder? = superview
        while let current = responder {
            if let parent = current as? UIViewController, parent !== host {
                parent.addChild(host); host.didMove(toParent: parent); return
            }
            responder = current.next
        }
    }
}

struct WaterUIDevice: Identifiable {
    let id: String
    let name: String
    let billType: Int
    let count: Int
    let monthly: [String: Int]
    var symbol: String { billType == 2 ? "shower.fill" : "drop.fill" }
    var kind: String { billType == 2 ? "热水设备" : "直饮水设备" }
    var currentMonthCount: Int {
        let date = Calendar.current.dateComponents([.year, .month], from: Date())
        return monthly[String(format: "%04d-%02d", date.year ?? 0, date.month ?? 0)] ?? 0
    }
    init(_ map: [String: Any]) {
        id = map["id"] as? String ?? ""
        name = map["name"] as? String ?? "设备"
        billType = (map["billType"] as? NSNumber)?.intValue ?? 0
        count = (map["count"] as? NSNumber)?.intValue ?? 0
        monthly = (map["monthly"] as? [String: NSNumber] ?? [:]).mapValues(\.intValue)
    }
}

struct WaterUIRecord: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let date: Date
    let duration: String
    init(_ map: [String: Any]) {
        id = map["id"] as? String ?? UUID().uuidString
        name = map["name"] as? String ?? "设备"
        amount = (map["amount"] as? NSNumber)?.doubleValue ?? 0
        date = Date(timeIntervalSince1970: ((map["date"] as? NSNumber)?.doubleValue ?? 0) / 1000)
        duration = map["duration"] as? String ?? "--"
    }
}

struct WaterUIOption: Identifiable {
    let id: String
    let name: String
}

enum WaterUISheet: String, Identifiable {
    case appearance, profile, history, addDevice, manage, scanner
    var id: String { rawValue }
}

struct WaterUIMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

/// One source of truth: all account/device/water/history data comes from Dart.
/// Swift owns presentation state and appearance only.
final class WaterNativeStore: ObservableObject {
    @Published var ready = false
    @Published var loggedIn = false
    @Published var busy = false
    @Published var waterBusy = false
    @Published var historyLoading = false
    @Published var running = false
    @Published var selectedId = ""
    @Published var activeId = ""
    @Published var runningTime = "00:00"
    @Published var balance = "0.00"
    @Published var devices: [WaterUIDevice] = []
    @Published var records: [WaterUIRecord] = []
    @Published var recent: [WaterUIRecord] = []
    @Published var profile: [String: Any] = [:]
    @Published var todaySeconds = 0
    @Published var todayCount = 0
    @Published var lastDuration = ""
    @Published var historyYear = Calendar.current.component(.year, from: Date())
    @Published var historyMonth = Calendar.current.component(.month, from: Date())
    @Published var historyYears = [Calendar.current.component(.year, from: Date())]
    @Published var expandedStats = false
    @Published var sheet: WaterUISheet?
    @Published var message: WaterUIMessage?
    @Published var toast = ""
    @Published var defaultId = WaterIntentStore.defaultDevice()?.id ?? ""
    let appearance = WaterAppearance()
    private let channel: FlutterMethodChannel
    private var toastWork: DispatchWorkItem?
    private var connected = true
    private var appearanceSubscription: AnyCancellable?
    var pickAvatarAfterDismiss = false

    func sheetDidDismiss() {
        guard pickAvatarAfterDismiss else { return }
        pickAvatarAfterDismiss = false
        perform("avatar")
    }

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        appearanceSubscription = appearance.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "state":
                self.receive(call.arguments as? [String: Any] ?? [:])
                result(nil)
            case "toast":
                let args = call.arguments as? [String: Any] ?? [:]
                self.showToast(args["message"] as? String ?? "", seconds: Double((args["duration"] as? Int) ?? 3000) / 1000)
                result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        }
    }

    func disconnect() { connected = false; channel.setMethodCallHandler(nil); toastWork?.cancel() }

    private func receive(_ map: [String: Any]) {
        ready = map["ready"] as? Bool ?? ready
        let wasLoggedIn = loggedIn
        loggedIn = map["loggedIn"] as? Bool ?? loggedIn
        busy = map["busy"] as? Bool ?? busy
        waterBusy = map["waterBusy"] as? Bool ?? waterBusy
        running = map["running"] as? Bool ?? running
        historyLoading = map["historyLoading"] as? Bool ?? historyLoading
        balance = map["balance"] as? String ?? balance
        selectedId = map["selectedId"] as? String ?? selectedId
        activeId = map["activeId"] as? String ?? activeId
        runningTime = map["runningTime"] as? String ?? runningTime
        if let raw = map["devices"] as? [[String: Any]] { devices = raw.map(WaterUIDevice.init) }
        if let raw = map["records"] as? [[String: Any]] { records = raw.map(WaterUIRecord.init) }
        if let raw = map["recent"] as? [[String: Any]] { recent = raw.map(WaterUIRecord.init) }
        if let raw = map["profile"] as? [String: Any] { profile = raw }
        if let value = map["todaySeconds"] as? Int { todaySeconds = value }
        if let value = map["todayCount"] as? Int { todayCount = value }
        if let value = map["lastDuration"] as? String { lastDuration = value }
        if let value = map["historyYear"] as? Int { historyYear = value }
        if let value = map["historyMonth"] as? Int { historyMonth = value }
        if let value = map["historyYears"] as? [Int] { historyYears = value }
        if let value = map["expandedStats"] as? Bool { expandedStats = value }
        defaultId = WaterIntentStore.defaultDevice()?.id ?? ""
        if wasLoggedIn && !loggedIn { sheet = nil; records = []; recent = []; devices = [] }
    }

    var selectedDevice: WaterUIDevice? {
        devices.first(where: { $0.id == (running ? activeId : selectedId) }) ?? devices.first
    }
    var durationValue: String {
        if running { return runningTime }
        if recent.isEmpty { return "随时用水" }
        return "\(todaySeconds / 60)分\(todaySeconds % 60)秒"
    }

    func perform(_ name: String, _ args: [String: Any] = [:], completion: ((Result<Any?, Error>) -> Void)? = nil) {
        guard connected else { return }
        channel.invokeMethod("action", arguments: args.merging(["name": name]) { _, new in new }) { [weak self] response in
            guard let self = self, self.connected else { return }
            if let error = response as? FlutterError {
                let failure = NSError(domain: "WaterNativeUI", code: 1, userInfo: [NSLocalizedDescriptionKey: error.message ?? "操作失败，请稍后重试"])
                self.message = WaterUIMessage(title: "操作未完成", text: failure.localizedDescription)
                completion?(.failure(failure))
            } else {
                completion?(.success(response))
            }
        }
    }

    func showToast(_ value: String, seconds: Double = 3) {
        toastWork?.cancel()
        toast = value
        let work = DispatchWorkItem { [weak self] in self?.toast = "" }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func palette(seed: UInt32? = nil, image: Data? = nil) {
        var args: [String: Any] = [:]
        if let seed = seed { args["seed"] = Int64(seed) }
        if let image = image { args["image"] = FlutterStandardTypedData(bytes: image) }
        perform("palette", args) { [weak self] result in
            guard case .success(let value) = result, let map = value as? [String: NSNumber] else { return }
            self?.appearance.applyPalette(map)
        }
    }

    func begin(_ device: WaterUIDevice) { perform("start", ["id": device.id]) }
}
