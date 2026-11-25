import AVFoundation
import UIKit

/// Shows a photo with the document's corners and edges as handles the user can
/// drag, with a magnified view of the point being moved, and lets the user turn
/// the photo.
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
    /// One per edge; edge i runs from corner i to the next corner.
    private var edgeHandles: [EdgeHandle] = []
    private let magnifier = MagnifierView()
    /// From the finger to the dragged handle's centre, so the handle keeps its
    /// place under the finger.
    private var grabOffset = CGVector.zero
    private var edgeDrag: EdgeDrag?

    /// An edge being dragged: where the drag started and the corners at that point.
    private struct EdgeDrag {
        let index: Int
        let start: CGPoint
        /// In canvas points.
        let corners: [CGPoint]
        let movesVertically: Bool
    }

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
        hint.text = "Drag the corners or edges to fit the document"
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

        // Added before the corner handles, so a corner wins where they overlap.
        for index in 0..<4 {
            let handle = EdgeHandle()
            handle.isHidden = true
            handle.isAccessibilityElement = true
            handle.accessibilityLabel = "Document edge"
            handle.accessibilityIdentifier = "edge-\(index)"
            let drag = UILongPressGestureRecognizer(target: self, action: #selector(dragEdge(_:)))
            drag.minimumPressDuration = 0
            handle.addGestureRecognizer(drag)
            canvas.addSubview(handle)
            edgeHandles.append(handle)
        }

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

        canvas.addSubview(magnifier)

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
        edgeHandles.forEach { $0.isHidden = false }
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
        for (index, handle) in edgeHandles.enumerated() {
            let a = points[index], b = points[(index + 1) % 4]
            handle.center = Self.midpoint(a, b)
            handle.align(withAngle: atan2(b.y - a.y, b.x - a.x))
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
            showMagnifier(at: handle.center)
            return
        case .changed:
            break
        default:
            magnifier.isHidden = true
            return
        }
        let moved = CGPoint(x: location.x + grabOffset.dx, y: location.y + grabOffset.dy)
        var corners = quad.corners
        corners[index] = normalisedPoint(moved)
        self.quad = Quadrilateral(corners)
        layoutCorners()
        showMagnifier(at: handle.center)
    }

    /// Moves a whole edge: up and down for a top or bottom edge, sideways for
    /// a left or right one.
    @objc private func dragEdge(_ gesture: UILongPressGestureRecognizer) {
        guard let quad = quad,
              let handle = gesture.view as? EdgeHandle,
              let index = edgeHandles.firstIndex(of: handle) else { return }
        let location = gesture.location(in: canvas)
        switch gesture.state {
        case .began:
            let corners = quad.corners.map(canvasPoint)
            let a = corners[index], b = corners[(index + 1) % 4]
            // Decided by how the edge lies on screen, so it also holds after the
            // photo has been turned.
            edgeDrag = EdgeDrag(index: index, start: location, corners: corners,
                                movesVertically: abs(b.x - a.x) >= abs(b.y - a.y))
            showMagnifier(at: handle.center)
        case .changed:
            guard let drag = edgeDrag else { return }
            let i = drag.index, j = (drag.index + 1) % 4
            let rect = imageRect
            var corners = drag.corners
            // Limited so both ends stay on the photo, so the edge moves without tilting.
            if drag.movesVertically {
                let dy = min(max(location.y - drag.start.y, rect.minY - min(corners[i].y, corners[j].y)),
                             rect.maxY - max(corners[i].y, corners[j].y))
                corners[i].y += dy
                corners[j].y += dy
            } else {
                let dx = min(max(location.x - drag.start.x, rect.minX - min(corners[i].x, corners[j].x)),
                             rect.maxX - max(corners[i].x, corners[j].x))
                corners[i].x += dx
                corners[j].x += dx
            }
            self.quad = Quadrilateral(corners.map(normalisedPoint))
            layoutCorners()
            showMagnifier(at: Self.midpoint(corners[i], corners[j]))
        default:
            edgeDrag = nil
            magnifier.isHidden = true
        }
    }

    /// Shows a close-up of the photo around [focus], in a top corner of the
    /// photo on the side away from it, so the finger doesn't cover it.
    private func showMagnifier(at focus: CGPoint) {
        guard let path = outline.path else { return }
        let margin: CGFloat = 8
        let x = focus.x < canvas.bounds.midX
            ? canvas.bounds.maxX - MagnifierView.size - margin
            : margin
        magnifier.frame.origin = CGPoint(x: x, y: margin)
        magnifier.show(image, drawnIn: imageRect, around: focus, outline: path)
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
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

/// A bar on the middle of an edge, for moving the whole edge at once, with a
/// larger invisible area around it so it is easy to grab.
private final class EdgeHandle: UIView {
    private let bar = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 8))

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: CornerHandle.size, height: CornerHandle.size))
        bar.center = CGPoint(x: bounds.midX, y: bounds.midY)
        bar.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        bar.layer.cornerRadius = 4
        bar.layer.borderColor = UIColor.systemBlue.cgColor
        bar.layer.borderWidth = 2
        bar.isUserInteractionEnabled = false
        addSubview(bar)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lines the bar up with its edge; [angle] is the edge's direction in radians.
    func align(withAngle angle: CGFloat) {
        bar.transform = CGAffineTransform(rotationAngle: angle)
    }
}

/// A round close-up of the photo around the point being moved, with the
/// outline and a crosshair, so it can be placed exactly despite the finger.
private final class MagnifierView: UIView {
    static let size: CGFloat = 120
    static let zoom: CGFloat = 2.5

    private let imageView = UIImageView()
    private let outline = CAShapeLayer()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: MagnifierView.size, height: MagnifierView.size))
        isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityLabel = "Magnified view"
        accessibilityIdentifier = "magnifier"
        backgroundColor = .black
        clipsToBounds = true
        layer.cornerRadius = MagnifierView.size / 2
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 2

        addSubview(imageView)

        outline.strokeColor = UIColor.systemBlue.cgColor
        outline.fillColor = nil
        outline.lineWidth = 2
        layer.addSublayer(outline)

        let crosshair = CAShapeLayer()
        let c = CGPoint(x: bounds.midX, y: bounds.midY), arm: CGFloat = 10
        let path = UIBezierPath()
        path.move(to: CGPoint(x: c.x - arm, y: c.y)); path.addLine(to: CGPoint(x: c.x + arm, y: c.y))
        path.move(to: CGPoint(x: c.x, y: c.y - arm)); path.addLine(to: CGPoint(x: c.x, y: c.y + arm))
        crosshair.path = path.cgPath
        crosshair.strokeColor = UIColor.white.cgColor
        crosshair.lineWidth = 1.5
        layer.addSublayer(crosshair)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows [image], which is drawn on screen in [imageRect], magnified so that
    /// [focus] sits under the crosshair. All three, and [outline], are in the
    /// coordinates of the view holding the photo.
    func show(_ image: UIImage, drawnIn imageRect: CGRect, around focus: CGPoint, outline path: CGPath) {
        if imageView.image !== image { imageView.image = image }
        // Moves [focus] to the origin, enlarges, then moves it to the centre.
        var transform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
            .scaledBy(x: MagnifierView.zoom, y: MagnifierView.zoom)
            .translatedBy(x: -focus.x, y: -focus.y)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageView.frame = imageRect.applying(transform)
        outline.path = path.copy(using: &transform)
        CATransaction.commit()
        isHidden = false
    }
}
