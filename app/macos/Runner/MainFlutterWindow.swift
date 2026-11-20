import Cocoa
import EventKit
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  private let calendar = CalendarBridge()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let messenger = flutterViewController.engine.binaryMessenger
    calendar.register(messenger: messenger)
    registerLaunchAtLogin(messenger: messenger)
    registerClipboard(messenger: messenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// `ant/clipboard`: rich-text copy (HTML + plain fallback) and reading a pasted image as PNG.
  private func registerClipboard(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "ant/clipboard", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        let pb = NSPasteboard.general
        switch call.method {
        case "setHtml":
          let args = call.arguments as? [String: Any] ?? [:]
          pb.clearContents()
          pb.setString(args["html"] as? String ?? "", forType: .html)
          pb.setString(args["text"] as? String ?? "", forType: .string)
          result(nil)
        case "readImage":
          if let png = pb.data(forType: .png) {
            result(FlutterStandardTypedData(bytes: png))
          } else if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff),
                    let png = rep.representation(using: .png, properties: [:]) {
            result(FlutterStandardTypedData(bytes: png))
          } else {
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  /// Answers the `launch_at_startup` plugin's macOS channel with SMAppService (macOS 13+).
  /// On macOS 12 launch at login reports disabled and ignores changes.
  private func registerLaunchAtLogin(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "launch_at_startup", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard #available(macOS 13.0, *) else {
          result(call.method == "launchAtStartupIsEnabled" ? false : nil)
          return
        }
        switch call.method {
        case "launchAtStartupIsEnabled":
          result(SMAppService.mainApp.status == .enabled)
        case "launchAtStartupSetEnabled":
          let enable = (call.arguments as? [String: Any])?["setEnabledValue"] as? Bool ?? false
          do {
            if enable { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            result(nil)
          } catch {
            result(FlutterError(code: "launch_at_login", message: error.localizedDescription, details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }
}

/// EventKit bridge for `MacCalendarBridge` (Dart): MethodChannel `ant/calendar`
/// (requestAccess, events) and EventChannel `ant/calendar/changes` (EKEventStoreChanged).
final class CalendarBridge: NSObject, FlutterStreamHandler {
  private let store = EKEventStore()
  private var observer: NSObjectProtocol?
  private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.timeZone = TimeZone(identifier: "UTC")
    return f
  }()

  func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "ant/calendar", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { return }
        switch call.method {
        case "requestAccess":
          self.requestAccess(result)
        case "events":
          let args = call.arguments as? [String: Any] ?? [:]
          guard let from = args["from"] as? NSNumber, let to = args["to"] as? NSNumber else {
            result(FlutterError(code: "bad_args", message: "from/to (epoch ms) required", details: nil))
            return
          }
          result(self.events(
            from: Date(timeIntervalSince1970: from.doubleValue / 1000),
            to: Date(timeIntervalSince1970: to.doubleValue / 1000)))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "ant/calendar/changes", binaryMessenger: messenger).setStreamHandler(self)
  }

  private func requestAccess(_ result: @escaping FlutterResult) {
    let done: (Bool, Error?) -> Void = { granted, _ in DispatchQueue.main.async { result(granted) } }
    if #available(macOS 14.0, *) {
      store.requestFullAccessToEvents(completion: done)
    } else {
      store.requestAccess(to: .event, completion: done)
    }
  }

  private func events(from: Date, to: Date) -> [[String: Any?]] {
    let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
    return store.events(matching: predicate).map { e in
      let me = e.attendees?.first { $0.isCurrentUser }
      return [
        "id": e.eventIdentifier ?? e.calendarItemIdentifier,
        "title": e.title ?? "",
        "start": iso.string(from: e.startDate),
        "end": iso.string(from: e.endDate),
        "attendeesCount": e.attendees?.count ?? 0,
        "declined": me?.participantStatus == .declined,
        "iCalUID": e.calendarItemExternalIdentifier,
        "notes": e.notes,
        "location": e.location,
        "calendarTitle": e.calendar?.title,
      ]
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: store, queue: .main
    ) { _ in events(true) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    return nil
  }
}
