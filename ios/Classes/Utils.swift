import Flutter
import Foundation
import UIKit

class Utils {

    static let channelName = "goapptiv_document_scanner"

    /// Same error code as the Android side.
    static func error(_ message: String) -> FlutterError {
        FlutterError(code: "DocumentScanner", message: message, details: nil)
    }

    /// Writes the image as a JPEG and returns its `file://` URL, which the Dart
    /// side turns into a path. Returns nil if the image could not be saved.
    static func saveImage(_ image: UIImage) -> String? {
        guard let directory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
              let data = image.jpegData(compressionQuality: 1) else {
            return nil
        }
        let fileURL = directory.appendingPathComponent(uniqueFileName(fileExtension: "jpg"))
        do {
            try data.write(to: fileURL)
            return fileURL.absoluteString
        } catch {
            print("error saving file with error", error)
            return nil
        }
    }

    private static func uniqueFileName(fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddhhmmsss"
        return "\(ProcessInfo.processInfo.globallyUniqueString)_\(formatter.string(from: Date())).\(fileExtension)"
    }
}
