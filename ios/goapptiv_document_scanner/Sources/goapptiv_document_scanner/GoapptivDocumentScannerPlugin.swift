import AVFoundation
import Flutter
import UIKit

public class GoapptivDocumentScannerPlugin: NSObject, FlutterPlugin {

    /// The Dart call waiting for the scan on screen. Only one scan runs at a time.
    private var pendingResult: FlutterResult?
    /// The app screen the scanner was opened over. Dismissing it closes every
    /// screen the plugin opened on top of it.
    private weak var root: UIViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: Utils.channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(GoapptivDocumentScannerPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPicture":
            if begin(result) { openCamera() }
        case "getPictureFromGallery":
            if begin(result) { openGallery() }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Takes over [result], unless another scan is already running.
    private func begin(_ result: @escaping FlutterResult) -> Bool {
        guard pendingResult == nil else {
            result(Utils.error("Document scanner is already active"))
            return false
        }
        pendingResult = result
        return true
    }

    // MARK: - Camera

    private func openCamera() {
        // The simulator, for one, has no camera.
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            finish(Utils.error("No camera available on this device"))
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? self.presentCamera() : self.finish(Utils.error("Camera access was denied"))
                }
            }
        default:
            finish(Utils.error("Camera access was denied"))
        }
    }

    private func presentCamera() {
        let camera = DocumentCameraViewController()
        camera.onCancel = { [weak self] in
            self?.close(returning: nil)
        }
        camera.onCapture = { [weak self, weak camera] image in
            guard let self = self, let camera = camera else { return }
            // Retake closes the editor, which shows the camera again.
            self.showCornerEditor(for: image, over: camera, cancelTitle: "Retake") { editor in
                editor.dismiss(animated: true)
            }
        }
        present(camera)
    }

    // MARK: - Gallery

    private func openGallery() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker)
    }

    // MARK: - Corner editor

    /// Lets the user adjust the document's corners in [image]. The editor
    /// opens at once and shows the corners when detection finishes, so there
    /// is no blank pause while the document is being found.
    private func showCornerEditor(for image: UIImage, over presenter: UIViewController, cancelTitle: String,
                                  onCancel: @escaping (UIViewController) -> Void) {
        let editor = CornerAdjustViewController(image: image, cancelTitle: cancelTitle)
        editor.onCancel = { [weak editor] in
            if let editor = editor { onCancel(editor) }
        }
        // The editor hands back the photo as the user turned it.
        editor.onDone = { turnedImage, quad in
            self.finish(cropping: turnedImage, to: quad)
        }
        presenter.present(editor, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak editor] in
            let quad = DocumentDetector.detect(in: image)
            DispatchQueue.main.async {
                editor?.showCorners(quad)
            }
        }
    }

    private func finish(cropping image: UIImage, to quad: Quadrilateral) {
        root?.dismiss(animated: true)
        DispatchQueue.global(qos: .userInitiated).async {
            let path = DocumentDetector.crop(image, to: quad).flatMap(Utils.saveImage)
            DispatchQueue.main.async {
                self.finish(path ?? Utils.error("Failed to save the scanned image"))
            }
        }
    }

    // MARK: - Presentation

    private func present(_ controller: UIViewController) {
        guard let root = topViewController() else {
            finish(Utils.error("No screen available to show the document scanner"))
            return
        }
        self.root = root
        controller.modalPresentationStyle = .fullScreen
        root.present(controller, animated: true)
    }

    /// Looked up at presentation time, because no window may exist yet when the
    /// plugin is registered, and apps using scenes have no delegate window.
    private func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow }
            ?? windows.first
            ?? (UIApplication.shared.delegate?.window ?? nil)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Closes all scanner screens and completes the Dart call.
    private func close(returning value: Any?) {
        root?.dismiss(animated: true)
        finish(value)
    }

    private func finish(_ value: Any?) {
        let result = pendingResult
        pendingResult = nil
        result?(value)
    }
}

extension GoapptivDocumentScannerPlugin: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        close(returning: nil)
    }

    public func imagePickerController(_ picker: UIImagePickerController,
                                      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let image = info[.originalImage] as? UIImage else {
            close(returning: Utils.error("Could not read the selected image"))
            return
        }
        // The editor can only be shown once the picker has gone.
        picker.dismiss(animated: true) {
            guard let root = self.root else {
                self.finish(Utils.error("No screen available to show the document scanner"))
                return
            }
            self.showCornerEditor(for: image, over: root, cancelTitle: "Cancel") { _ in
                self.close(returning: nil)
            }
        }
    }
}
