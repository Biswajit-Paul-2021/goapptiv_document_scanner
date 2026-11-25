import AVFoundation
import UIKit

/// Shows a photo with the document's corners as handles the user can drag,
/// and lets the user turn the photo.
final class CornerAdjustViewController: UIViewController {

    var onCancel: (() -> Void)?
    /// Called with the photo, turned as the user left it, and the adjusted
    /// corners in clockwise order.
    var onDone: ((UIImage, Quadrilateral) -> Void)?

    private var image: UIImage
    /// Quarter turns clockwise since the editor opened.
    private var quarterTurns = 0
    /// Nil until the document has been looked for; see [showCorners].
    private var quad: Quadrilateral?
    private let cancelTitle: String
    private let spinner = UIActivityIndicatorView(style: .large)
    private let doneButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .system)

    /// Holds the photo, outline and handles. The photo is inset by half a
    /// handle so handles on its edges stay fully touchable.
    private let canvas = UIView()
    private let imageView = UIImageView()
    private let outline = CAShapeLayer()
    private var handles: [CornerHandle] = []
    /// From the finger to the dragged handle's centre, so the handle keeps its
    /// place under the finger.
    private var grabOffset = CGVector.zero

    /// Opens straight away with the photo; the corners follow via [showCorners].
    init(image: UIImage, cancelTitle: String) {
        self.image = image
        self.cancelTitle = cancelTitle
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let hint = UILabel()
        hint.text = "Drag the corners to fit the document"
        hint.textColor = .white
        hint.font = .preferredFont(forTextStyle: .subheadline)
        hint.textAlignment = .center

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        canvas.addSubview(imageView)

        outline.strokeColor = UIColor.systemBlue.cgColor
        outline.fillColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        outline.lineWidth = 2
        canvas.layer.addSublayer(outline)

        for index in 0..<4 {
            let handle = CornerHandle()
            handle.isHidden = true
            // Lets VoiceOver announce the handles and UI tests find them.
            handle.isAccessibilityElement = true
            handle.accessibilityLabel = "Document corner"
            handle.accessibilityIdentifier = "corner-\(index)"
            // Starts the moment the finger touches down. A pan gesture only starts
            // after the finger has moved about 10 points, leaving the handle behind.
            let drag = UILongPressGestureRecognizer(target: self, action: #selector(dragCorner(_:)))
            drag.minimumPressDuration = 0
            handle.addGestureRecognizer(drag)
            canvas.addSubview(handle)
            handles.append(handle)
        }

        spinner.color = .white
        spinner.startAnimating()

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        doneButton.isEnabled = false
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        rotateButton.setImage(UIImage(systemName: "rotate.right"), for: .normal)
        rotateButton.tintColor = .white
        rotateButton.accessibilityLabel = "Rotate"
        rotateButton.addTarget(self, action: #selector(rotate), for: .touchUpInside)

        let toolbar = UIStackView(arrangedSubviews: [cancelButton, UIView(), doneButton])
        toolbar.axis = .horizontal
        toolbar.tintColor = .white

        for subview in [hint, canvas, toolbar, spinner, rotateButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let guide = view.safeAreaLayoutGuide
        let inset = CornerHandle.size / 2
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            canvas.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            canvas.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8),
            canvas.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
            canvas.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8),

            imageView.topAnchor.constraint(equalTo: canvas.topAnchor, constant: inset),
            imageView.leadingAnchor.constraint(equalTo: canvas.leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -inset),
            imageView.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -inset),

            toolbar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            toolbar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            toolbar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            spinner.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),

            // Centred on screen rather than placed in the toolbar, whose two
            // buttons have different widths.
            rotateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rotateButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            rotateButton.widthAnchor.constraint(equalToConstant: 44),
            rotateButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    /// Shows the handles at [quad], or at a frame inside the photo's edges if
    /// no document was found.
    func showCorners(_ quad: Quadrilateral?) {
        // The corners were found on the photo as first shown, so turn them to
        // match any rotation the user made while they were being found.
        var corners = quad ?? .fallback
        for _ in 0..<quarterTurns {
            corners = corners.rotatedClockwise()
        }
        self.quad = corners
        spinner.stopAnimating()
        handles.forEach { $0.isHidden = false }
        doneButton.isEnabled = true
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The canvas lays out the image view after this point, so without this
        // the image view's frame is still zero and every handle sits at the origin.
        canvas.layoutIfNeeded()
        layoutCorners()
    }

    /// Where the photo is drawn inside the aspect-fit image view, in canvas coordinates.
    private var imageRect: CGRect {
        AVMakeRect(aspectRatio: image.size, insideRect: imageView.frame)
    }

    private func canvasPoint(_ normalised: CGPoint) -> CGPoint {
        let rect = imageRect
        return CGPoint(x: rect.minX + normalised.x * rect.width,
                       y: rect.minY + normalised.y * rect.height)
    }

    private func normalisedPoint(_ point: CGPoint) -> CGPoint {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGPoint(x: min(max((point.x - rect.minX) / rect.width, 0), 1),
                       y: min(max((point.y - rect.minY) / rect.height, 0), 1))
    }

    private func layoutCorners() {
        guard let quad = quad else { return }
        let points = quad.corners.map(canvasPoint)
        for (handle, point) in zip(handles, points) {
            handle.center = point
        }
        let path = UIBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.close()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.frame = canvas.bounds
        outline.path = path.cgPath
        CATransaction.commit()
    }

    @objc private func dragCorner(_ gesture: UILongPressGestureRecognizer) {
        guard let quad = quad,
              let handle = gesture.view as? CornerHandle,
              let index = handles.firstIndex(of: handle) else { return }
        let location = gesture.location(in: canvas)
        switch gesture.state {
        case .began:
            grabOffset = CGVector(dx: handle.center.x - location.x, dy: handle.center.y - location.y)
            return
        case .changed:
            break
        default:
            return
        }
        let moved = CGPoint(x: location.x + grabOffset.dx, y: location.y + grabOffset.dy)
        var corners = quad.corners
        corners[index] = normalisedPoint(moved)
        self.quad = Quadrilateral(corners)
        layoutCorners()
    }

    @objc private func cancel() {
        onCancel?()
    }

    /// Turns the photo and its corners a quarter turn clockwise. The corners
    /// are turned with the photo rather than found again.
    @objc private func rotate() {
        image = image.rotatedClockwise()
        quarterTurns = (quarterTurns + 1) % 4
        quad = quad?.rotatedClockwise()
        UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) {
            self.imageView.image = self.image
        }
        view.setNeedsLayout()
    }

    @objc private func done() {
        guard let quad = quad else { return }
        onDone?(image, quad.sorted())
    }
}

/// A round handle with a larger invisible area around it, so it is easy to grab.
private final class CornerHandle: UIView {
    static let size: CGFloat = 44

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: CornerHandle.size, height: CornerHandle.size))
        let dot = UIView(frame: bounds.insetBy(dx: 11, dy: 11))
        dot.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        dot.layer.cornerRadius = dot.bounds.width / 2
        dot.layer.borderColor = UIColor.systemBlue.cgColor
        dot.layer.borderWidth = 2
        dot.isUserInteractionEnabled = false
        addSubview(dot)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
