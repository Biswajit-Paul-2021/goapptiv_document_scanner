import AVFoundation
import UIKit

/// Full-screen camera that outlines the document live and takes a photo,
/// either when the user taps the shutter or by itself once the document holds still.
final class DocumentCameraViewController: UIViewController {

    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    /// AVCaptureSession calls block, so they run here rather than on the main thread.
    private let sessionQueue = DispatchQueue(label: "goapptiv_document_scanner.session")
    private let videoQueue = DispatchQueue(label: "goapptiv_document_scanner.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?

    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)
    private let outline = CAShapeLayer()
    private let shutterButton = UIButton(type: .custom)
    private let torchButton = UIButton(type: .system)
    private let autoButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var isTorchOn = false

    private static let autoCaptureKey = "goapptiv_document_scanner.autoCapture"
    /// On by default; the user's choice is remembered between scans.
    private var isAutoCaptureOn = UserDefaults.standard.object(
        forKey: DocumentCameraViewController.autoCaptureKey) as? Bool ?? true
    private var tracker = AutoCaptureTracker()

    /// Only used on videoQueue.
    private var lastDetection = Date.distantPast
    /// When the outline last matched a document, so a missed frame doesn't make it flicker.
    private var lastSeenDocument = Date.distantPast
    private var lastValidOrientation = UIDeviceOrientation.portrait

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        outline.strokeColor = UIColor.systemBlue.cgColor
        outline.fillColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        outline.lineWidth = 3
        outline.lineJoin = .round
        view.layer.addSublayer(outline)

        setUpControls()
        sessionQueue.async { self.configureSession() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        outline.frame = view.bounds
    }

    // The session runs only while the camera is on screen, including after
    // returning from the corner editor with Retake.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        shutterButton.isEnabled = true
        // After Retake the document must hold still again before the next photo.
        tracker.reset()
        showAutoCaptureState(.searching)
        sessionQueue.async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        setTorch(false)
        outline.path = nil
        sessionQueue.async { self.session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        // Frames stay in the camera's own orientation, which is what lets the
        // preview layer place the live outline.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()

        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        }

        DispatchQueue.main.async {
            self.device = device
            self.torchButton.isHidden = !device.hasTorch
        }
    }

    // MARK: - Controls

    private func setUpControls() {
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 32
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.lightGray.cgColor
        shutterButton.accessibilityLabel = "Take photo"
        shutterButton.addTarget(self, action: #selector(capture), for: .touchUpInside)

        torchButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        torchButton.setImage(UIImage(systemName: "bolt.fill"), for: .selected)
        torchButton.tintColor = .white
        torchButton.accessibilityLabel = "Torch"
        torchButton.isHidden = true
        torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)

        autoButton.tintColor = .white
        autoButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        autoButton.accessibilityLabel = "Automatic capture"
        autoButton.addTarget(self, action: #selector(toggleAutoCapture), for: .touchUpInside)
        updateAutoButton()

        // Kept readable over a bright camera feed.
        let hintBackground = UIView()
        hintBackground.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        hintBackground.layer.cornerRadius = 8
        hintLabel.textColor = .white
        hintLabel.font = .preferredFont(forTextStyle: .subheadline)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintBackground.addSubview(hintLabel)

        for control in [cancelButton, shutterButton, torchButton, autoButton, hintBackground] {
            control.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(control)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
            shutterButton.widthAnchor.constraint(equalToConstant: 64),
            shutterButton.heightAnchor.constraint(equalToConstant: 64),

            cancelButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            torchButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            torchButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            torchButton.widthAnchor.constraint(equalToConstant: 44),
            torchButton.heightAnchor.constraint(equalToConstant: 44),

            autoButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            autoButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            hintBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintBackground.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -20),
            hintBackground.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 20),
            hintLabel.topAnchor.constraint(equalTo: hintBackground.topAnchor, constant: 8),
            hintLabel.bottomAnchor.constraint(equalTo: hintBackground.bottomAnchor, constant: -8),
            hintLabel.leadingAnchor.constraint(equalTo: hintBackground.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: hintBackground.trailingAnchor, constant: -12),
        ])
    }

    @objc private func toggleAutoCapture() {
        isAutoCaptureOn.toggle()
        UserDefaults.standard.set(isAutoCaptureOn, forKey: Self.autoCaptureKey)
        tracker.reset()
        updateAutoButton()
        showAutoCaptureState(.searching)
    }

    private func updateAutoButton() {
        autoButton.setTitle(isAutoCaptureOn ? "Auto" : "Manual", for: .normal)
    }

    @objc private func cancel() {
        onCancel?()
    }

    @objc private func toggleTorch() {
        setTorch(!isTorchOn)
    }

    private func setTorch(_ on: Bool) {
        isTorchOn = on
        torchButton.isSelected = on
        guard let device = device, device.hasTorch else { return }
        sessionQueue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if !on {
                device.torchMode = .off
            } else if device.isTorchAvailable {
                device.torchMode = .on
            }
            device.unlockForConfiguration()
        }
    }

    @objc private func capture() {
        shutterButton.isEnabled = false
        let orientation = photoOrientation()
        sessionQueue.async {
            // Missing if the camera could not be set up; capturing then would crash.
            guard let connection = self.photoOutput.connection(with: .video) else {
                DispatchQueue.main.async { self.shutterButton.isEnabled = true }
                return
            }
            Self.rotate(connection, for: orientation)
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    /// The screen stays in portrait, but the photo should be upright for the
    /// way the phone is actually held.
    private func photoOrientation() -> UIDeviceOrientation {
        let orientation = UIDevice.current.orientation
        if orientation.isPortrait || orientation.isLandscape {
            lastValidOrientation = orientation
        }
        return lastValidOrientation
    }

    private static func rotate(_ connection: AVCaptureConnection, for orientation: UIDeviceOrientation) {
        if #available(iOS 17.0, *) {
            let angle: CGFloat
            switch orientation {
            case .landscapeLeft: angle = 0
            case .landscapeRight: angle = 180
            case .portraitUpsideDown: angle = 270
            default: angle = 90
            }
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else {
            switch orientation {
            case .landscapeLeft: connection.videoOrientation = .landscapeRight
            case .landscapeRight: connection.videoOrientation = .landscapeLeft
            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
            default: connection.videoOrientation = .portrait
            }
        }
    }

    // MARK: - Auto capture

    private func updateAutoCapture(with quad: Quadrilateral?) {
        let state = tracker.update(corners: quad?.corners, at: Date())
        showAutoCaptureState(state)
        guard state == .ready, isAutoCaptureOn, shutterButton.isEnabled else { return }
        // Starts over, so a failed photo needs another full hold before retrying.
        tracker.reset()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        capture()
    }

    private func showAutoCaptureState(_ state: AutoCaptureTracker.State) {
        var isHolding = false
        switch state {
        case .searching:
            hintLabel.text = "Point the camera at a document"
        case .holding(let progress):
            hintLabel.text = isAutoCaptureOn ? "Hold still" : "Tap the shutter to take the photo"
            isHolding = isAutoCaptureOn && progress >= 0.25
        case .ready:
            hintLabel.text = isAutoCaptureOn ? "Hold still" : "Tap the shutter to take the photo"
            isHolding = isAutoCaptureOn
        }
        // Green tells the user the photo is about to be taken.
        let color = isHolding ? UIColor.systemGreen : UIColor.systemBlue
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.strokeColor = color.cgColor
        outline.fillColor = color.withAlphaComponent(0.2).cgColor
        CATransaction.commit()
    }

    // MARK: - Live outline

    private func showOutline(_ quad: Quadrilateral?) {
        updateAutoCapture(with: quad)
        guard let quad = quad else {
            if Date().timeIntervalSince(lastSeenDocument) > 0.5 {
                outline.path = nil
            }
            return
        }
        lastSeenDocument = Date()
        let points = quad.corners.map { previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
        let path = UIBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.close()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.path = path.cgPath
        CATransaction.commit()
    }
}

extension DocumentCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // About eight checks a second keep the outline responsive without
        // heating up low-end phones.
        let now = Date()
        guard now.timeIntervalSince(lastDetection) > 0.12,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        lastDetection = now
        let quad = DocumentDetector.detect(in: pixelBuffer)
        DispatchQueue.main.async { self.showOutline(quad) }
    }
}

extension DocumentCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.shutterButton.isEnabled = true }
            return
        }
        DispatchQueue.main.async { self.onCapture?(image) }
    }
}
