import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// A document's four corners, normalised to 0...1 with the origin at the top
/// left of the upright image, so they map directly onto UIKit views.
struct Quadrilateral {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// Used when no document is found: a frame slightly inside the image edges.
    static let fallback = Quadrilateral(
        topLeft: CGPoint(x: 0.1, y: 0.1), topRight: CGPoint(x: 0.9, y: 0.1),
        bottomRight: CGPoint(x: 0.9, y: 0.9), bottomLeft: CGPoint(x: 0.1, y: 0.9))

    /// Clockwise from the top left.
    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// The same corners put back in clockwise order from the one nearest the
    /// top left, so corners dragged past each other never give a twisted crop.
    func sorted() -> Quadrilateral {
        let points = corners
        let center = CGPoint(x: points.map(\.x).reduce(0, +) / 4,
                             y: points.map(\.y).reduce(0, +) / 4)
        // y grows downwards, so a growing angle runs clockwise on screen.
        func angle(_ p: CGPoint) -> CGFloat { atan2(p.y - center.y, p.x - center.x) }
        let clockwise = points.sorted { angle($0) < angle($1) }
        let start = clockwise.indices.min { clockwise[$0].x + clockwise[$0].y < clockwise[$1].x + clockwise[$1].y } ?? 0
        return Quadrilateral((0..<4).map { clockwise[(start + $0) % 4] })
    }

    /// The same corners after turning the photo a quarter turn clockwise.
    /// What was the top left ends up at the top right, and so on.
    func rotatedClockwise() -> Quadrilateral {
        Quadrilateral(corners.map { CGPoint(x: 1 - $0.y, y: $0.x) })
    }
}

extension Quadrilateral {
    /// Corners in the order of [corners].
    init(_ corners: [CGPoint]) {
        self.init(topLeft: corners[0], topRight: corners[1],
                  bottomRight: corners[2], bottomLeft: corners[3])
    }

    /// Vision's points have their origin at the bottom left.
    init(_ observation: VNRectangleObservation) {
        func flipped(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        self.init(topLeft: flipped(observation.topLeft), topRight: flipped(observation.topRight),
                  bottomRight: flipped(observation.bottomRight), bottomLeft: flipped(observation.bottomLeft))
    }
}

/// Finds documents in photos and camera frames, and crops them out.
enum DocumentDetector {

    private static let context = CIContext()

    /// Finds the document in a photo. Corners are relative to the upright photo.
    static func detect(in image: UIImage) -> Quadrilateral? {
        guard let upright = uprightImage(image) else { return nil }
        return detect(with: VNImageRequestHandler(ciImage: upright, options: [:]))
    }

    /// Finds the document in a camera frame. Corners are relative to the frame
    /// as the camera delivers it, which is the camera's own coordinate space.
    static func detect(in pixelBuffer: CVPixelBuffer) -> Quadrilateral? {
        detect(with: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:]))
    }

    private static func detect(with handler: VNImageRequestHandler) -> Quadrilateral? {
        let request = VNDetectDocumentSegmentationRequest()
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first.map { Quadrilateral($0) }
    }

    /// Returns the area inside [quad], straightened into a rectangle.
    static func crop(_ image: UIImage, to quad: Quadrilateral) -> UIImage? {
        guard let upright = uprightImage(image) else { return nil }

        // Core Image's origin is at the bottom left.
        let size = upright.extent.size
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = upright
        filter.topLeft = point(quad.topLeft)
        filter.topRight = point(quad.topRight)
        filter.bottomRight = point(quad.bottomRight)
        filter.bottomLeft = point(quad.bottomLeft)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// The photo as a Core Image image that is the right way up, with its
    /// origin at zero so normalised points map straight onto it.
    private static func uprightImage(_ image: UIImage) -> CIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let oriented = CIImage(cgImage: cgImage)
            .oriented(CGImagePropertyOrientation(image.imageOrientation))
        return oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y))
    }
}

extension UIImage {
    /// The same photo turned a quarter turn clockwise. For ordinary photos only
    /// the orientation flag changes, so no pixels are redrawn.
    func rotatedClockwise() -> UIImage {
        let next: UIImage.Orientation
        switch imageOrientation {
        case .up: next = .right
        case .right: next = .down
        case .down: next = .left
        case .left: next = .up
        default:
            // Mirrored photos are rare; draw them upright once, then turn that.
            return redrawnUpright().rotatedClockwise()
        }
        guard let cgImage = cgImage else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: next)
    }

    private func redrawnUpright() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(at: .zero)
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
