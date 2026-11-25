import XCTest

/// End-to-end tests of the iOS gallery flow in the example app: Flutter's
/// "Gallery" button, the system photo picker, the plugin's corner editor, and
/// back to Flutter.
///
/// Run them with `run_gallery_tests.sh`, which puts the test photo in the
/// simulator's library and checks the crop each test saves.
final class GalleryFlowUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func test1_pickAndDone() {
        pickTestPhoto()
        tapDone()
        assertBackInApp()
        saveScreenshot(named: "gallery-after-done")
    }

    func test2_pickRotateDone() {
        pickTestPhoto()
        app.buttons["Rotate"].tap()
        tapDone()
        assertBackInApp()
    }

    func test3_pickDragCornerDone() {
        pickTestPhoto()
        let topLeft = app.otherElements["corner-0"]
        let bottomRight = app.otherElements["corner-2"]
        XCTAssertTrue(topLeft.waitForExistence(timeout: 10), "Corner handles didn't appear")
        let start = topLeft.frame.center
        let end = bottomRight.frame.center
        // 40% of the way to the opposite corner cuts off the marker near the top left.
        let target = CGPoint(x: start.x + (end.x - start.x) * 0.4, y: start.y + (end.y - start.y) * 0.4)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: start.x, dy: start.y))
            .press(forDuration: 0.3, thenDragTo: origin.withOffset(CGVector(dx: target.x, dy: target.y)))
        let moved = topLeft.frame.center
        let miss = hypot(moved.x - target.x, moved.y - target.y)
        print("Corner drag missed its target by \(miss) points")
        // The handle should stay under the finger, not trail behind it.
        XCTAssertLessThan(miss, 4, "Corner ended at \(moved), expected near \(target)")
        tapDone()
        assertBackInApp()
    }

    func test4_cancelInPicker() {
        openGallery()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "Photo picker didn't open")
        cancel.tap()
        assertBackInApp()
    }

    func test5_cancelInEditor() {
        pickTestPhoto()
        app.buttons["Cancel"].tap()
        assertBackInApp()
    }

    // MARK: - Steps

    private func openGallery() {
        let gallery = app.buttons["Gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 30), "Flutter's Gallery button didn't appear")
        gallery.tap()
    }

    /// Opens the picker, picks the test photo and waits for the corner editor.
    private func pickTestPhoto() {
        openGallery()
        // The test photo is dated 25 November, which the picker puts in its label.
        let photo = app.images.matching(NSPredicate(format: "label CONTAINS '25 November'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 15), "Test photo not found in the picker")
        // The picker runs in another process, so its cells report as not hittable;
        // tapping their position on screen works.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Corner editor didn't open")
        // Done is enabled once the corners have been found.
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: done)
        wait(for: [enabled], timeout: 15)
    }

    private func tapDone() {
        app.buttons["Done"].tap()
    }

    private func assertBackInApp() {
        let gallery = app.buttons["Gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 15), "Didn't return to the Flutter app")
        XCTAssertFalse(app.buttons["Done"].exists, "Corner editor is still open")
        // Give Flutter a moment to show the result before the app is closed.
        sleep(2)
    }

    /// Saved in the test runner's temporary folder, where the script picks it up.
    private func saveScreenshot(named name: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
