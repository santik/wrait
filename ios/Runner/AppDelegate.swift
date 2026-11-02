import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let entryImportErrorCode = "entry-import-failed"
  private let entryImportFileTooLargeErrorCode = "entry-import-file-too-large"
  private let deviceIdChannelName = "wrait/preferences"
  private let entryExportChannelName = "wrait/entry_export"
  private let entryImportChannelName = "wrait/entry_import"
  private let getDeviceIdMethod = "getDeviceId"
  private let pickCsvImportMethod = "pickCsvImport"
  private let writeCsvExportMethod = "writeCsvExport"
  private var entryImportDocumentPicker: EntryImportDocumentPicker?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "WraitDeviceIdBridge"
    ) else {
      return
    }

    let channel = FlutterMethodChannel(
      name: deviceIdChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (
      call: FlutterMethodCall,
      result: @escaping FlutterResult
    ) in
      guard let self else {
        result(
          FlutterError(
            code: "device_id_unavailable",
            message: "AppDelegate was deallocated before handling the device ID request",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case self.getDeviceIdMethod:
        if let identifier = UIDevice.current.identifierForVendor?.uuidString,
          !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
          result(identifier)
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let exportChannel = FlutterMethodChannel(
      name: entryExportChannelName,
      binaryMessenger: registrar.messenger()
    )
    exportChannel.setMethodCallHandler { [weak self] (
      call: FlutterMethodCall,
      result: @escaping FlutterResult
    ) in
      guard let self else {
        result(
          FlutterError(
            code: "entry_export_failed",
            message: "AppDelegate was deallocated before handling the export request",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case self.writeCsvExportMethod:
        guard
          let arguments = call.arguments as? [String: Any],
          let fileName = (arguments["fileName"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
          ),
          !fileName.isEmpty,
          let contents = arguments["contents"] as? String,
          !contents.isEmpty
        else {
          result(
            FlutterError(
              code: "entry_export_failed",
              message: "Invalid export arguments.",
              details: nil
            )
          )
          return
        }

        do {
          let pathLabel = try self.writeCsvExport(fileName: fileName, contents: contents)
          result(["fileName": fileName, "pathLabel": pathLabel])
        } catch {
          result(
            FlutterError(
              code: "entry_export_failed",
              message: "Failed to write CSV export.",
              details: error.localizedDescription
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let importChannel = FlutterMethodChannel(
      name: entryImportChannelName,
      binaryMessenger: registrar.messenger()
    )
    importChannel.setMethodCallHandler { [weak self] (
      call: FlutterMethodCall,
      result: @escaping FlutterResult
    ) in
      guard let self else {
        result(
          FlutterError(
            code: "entry-import-failed",
            message: "AppDelegate was deallocated before handling the import request",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case self.pickCsvImportMethod:
        self.presentEntryImportPicker(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func writeCsvExport(fileName: String, contents: String) throws -> String {
    let exportDirectory = try exportDirectoryUrl()
    let exportFile = exportDirectory.appendingPathComponent(fileName)
    try contents.write(to: exportFile, atomically: true, encoding: .utf8)
    return "Files/Wrait Exports"
  }

  private func exportDirectoryUrl() throws -> URL {
    guard
      let documentsDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
      ).first
    else {
      throw CocoaError(.fileNoSuchFile)
    }

    let exportDirectory = documentsDirectory.appendingPathComponent(
      "Wrait Exports",
      isDirectory: true
    )
    var isDirectory = ObjCBool(false)
    if FileManager.default.fileExists(atPath: exportDirectory.path, isDirectory: &isDirectory) {
      if !isDirectory.boolValue {
        throw NSError(
          domain: "WraitEntryExport",
          code: 1,
          userInfo: [
            NSLocalizedDescriptionKey: "The export directory path is occupied by a file."
          ]
        )
      }
      return exportDirectory
    }

    try FileManager.default.createDirectory(
      at: exportDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return exportDirectory
  }

  private func presentEntryImportPicker(result: @escaping FlutterResult) {
    if entryImportDocumentPicker != nil {
      result(
        FlutterError(
          code: entryImportErrorCode,
          message: "Another CSV import picker request is already active.",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController(from: window?.rootViewController) else {
      result(
        FlutterError(
          code: entryImportErrorCode,
          message: "No active view controller was available for CSV import.",
          details: nil
        )
      )
      return
    }

    let picker = EntryImportDocumentPicker(presenter: presenter) { [weak self] completion in
      guard let self else {
        return
      }

      self.entryImportDocumentPicker = nil
      switch completion {
      case .success(let payload):
        result(payload)
      case .failure(let error):
        let code = (error as NSError).domain == EntryImportDocumentPicker.errorDomain
          && (error as NSError).code == EntryImportDocumentPicker.fileTooLargeCode
          ? self.entryImportFileTooLargeErrorCode
          : self.entryImportErrorCode
        result(
          FlutterError(
            code: code,
            message: code == self.entryImportFileTooLargeErrorCode
              ? "Selected CSV import file is too large."
              : "Failed to read CSV import.",
            details: error.localizedDescription
          )
        )
      }
    }
    entryImportDocumentPicker = picker
    picker.present()
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }

    if let tabBarController = controller as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }

    if let presentedViewController = controller?.presentedViewController {
      return topViewController(from: presentedViewController)
    }

    return controller
  }
}

private final class EntryImportDocumentPicker: NSObject, UIDocumentPickerDelegate {
  static let errorDomain = "WraitEntryImport"
  static let fileTooLargeCode = 2
  private static let maxImportBytes = 10 * 1024 * 1024

  private weak var presenter: UIViewController?
  private let completion: (Result<[String: String]?, Error>) -> Void
  private var didComplete = false

  init(
    presenter: UIViewController,
    completion: @escaping (Result<[String: String]?, Error>) -> Void
  ) {
    self.presenter = presenter
    self.completion = completion
  }

  func present() {
    let picker = UIDocumentPickerViewController(
      documentTypes: ["public.comma-separated-values-text", "public.text"],
      in: .import
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter?.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(.success(nil))
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      finish(.success(nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else {
        return
      }

      do {
        let payload = try Self.readPayload(from: url)
        self.finishOnMain(.success(payload))
      } catch {
        self.finishOnMain(.failure(error))
      }
    }
  }

  private static func readPayload(from url: URL) throws -> [String: String] {
    let hasSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if hasSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
    if let fileSize = resourceValues?.fileSize, fileSize > maxImportBytes {
      throw NSError(
        domain: errorDomain,
        code: fileTooLargeCode,
        userInfo: [
          NSLocalizedDescriptionKey: "The selected CSV file exceeds the import size limit."
        ]
      )
    }

    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    if data.count > maxImportBytes {
      throw NSError(
        domain: errorDomain,
        code: fileTooLargeCode,
        userInfo: [
          NSLocalizedDescriptionKey: "The selected CSV file exceeds the import size limit."
        ]
      )
    }
    if data.isEmpty {
      throw NSError(
        domain: errorDomain,
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "The selected CSV file was empty."
        ]
      )
    }

    guard let contents = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: errorDomain,
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "The selected CSV file was not valid UTF-8 text."
        ]
      )
    }

    let fileName = (resourceValues?.name ?? url.lastPathComponent)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if fileName.isEmpty {
      throw NSError(
        domain: errorDomain,
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "The selected CSV file was missing a file name."
        ]
      )
    }

    return ["fileName": fileName, "contents": contents]
  }

  private func finishOnMain(_ result: Result<[String: String]?, Error>) {
    if Thread.isMainThread {
      finish(result)
      return
    }

    DispatchQueue.main.async { [weak self] in
      self?.finish(result)
    }
  }

  private func finish(_ result: Result<[String: String]?, Error>) {
    guard !didComplete else {
      return
    }
    didComplete = true
    completion(result)
  }
}
