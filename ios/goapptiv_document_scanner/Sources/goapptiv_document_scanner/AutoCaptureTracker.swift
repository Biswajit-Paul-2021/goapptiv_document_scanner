import CoreGraphics
import Foundation

/// Decides when to take the photo by itself: once a document big enough to
/// be worth scanning has stayed in place for long enough.
///
/// Corners are normalised to 0...1, as delivered by the live detection.
struct AutoCaptureTracker {

    enum State: Equatable {
        /// No usable document in view.
        case searching
        /// A document is in view and holding still; progress runs from 0 to 1.
        case holding(progress: Double)
        /// It has held still long enough to take the photo.
        case ready
    }

    /// How long the document must stay put before the photo is taken.
    static let holdDuration: TimeInterval = 1.0
    /// How far any corner may drift, as a share of the frame, and still count as still.
    static let maxMovement: CGFloat = 0.03
    /// The smallest share of the frame a document must cover.
    static let minArea: CGFloat = 0.1
    /// Detection misses the odd frame; gaps up to this long don't restart the countdown.
    static let missTolerance: TimeInterval = 0.5

    /// Where the document was when it started holding still.
    private var anchor: [CGPoint]?
    private var anchorTime: Date?
    private var lastSeen: Date?

    mutating func reset() {
        anchor = nil
        anchorTime = nil
        lastSeen = nil
    }

    /// Feeds one detection result, or nil if none was found, and returns the new state.
    mutating func update(corners: [CGPoint]?, at time: Date) -> State {
        guard let corners = corners, Self.area(of: corners) >= Self.minArea else {
            if let lastSeen = lastSeen, let anchorTime = anchorTime,
               time.timeIntervalSince(lastSeen) <= Self.missTolerance {
                return Self.progress(from: anchorTime, to: time)
            }
            reset()
            return .searching
        }
        lastSeen = time
        if let anchor = anchor, let anchorTime = anchorTime, Self.isClose(anchor, corners) {
            return Self.progress(from: anchorTime, to: time)
        }
        // Measured against where it started rather than the last frame, so a
        // slow drift still counts as moving.
        anchor = corners
        anchorTime = time
        return .holding(progress: 0)
    }

    private static func progress(from start: Date, to time: Date) -> State {
        let progress = time.timeIntervalSince(start) / holdDuration
        return progress >= 1 ? .ready : .holding(progress: progress)
    }

    private static func isClose(_ a: [CGPoint], _ b: [CGPoint]) -> Bool {
        zip(a, b).allSatisfy { abs($0.x - $1.x) <= maxMovement && abs($0.y - $1.y) <= maxMovement }
    }

    /// Area of the four-cornered shape, by the shoelace formula.
    static func area(of corners: [CGPoint]) -> CGFloat {
        var sum: CGFloat = 0
        for i in corners.indices {
            let a = corners[i], b = corners[(i + 1) % corners.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }
}
