import XCTest

final class BeautifierUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTryDemoPhotoLoadsEditView() throws {
        let app = XCUIApplication()
        app.launch()

        let demoButton = app.buttons["TryDemoPhoto"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5.0), "Try Demo Photo button should exist")

        demoButton.tap()

        let saveButton = app.buttons["SaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5.0), "Save button should exist on Edit screen")

        let maskDebugButton = app.buttons["MaskDebugButton"]
        XCTAssertTrue(maskDebugButton.waitForExistence(timeout: 5.0), "Mask debug button should exist in toolbar")
        
        maskDebugButton.tap()
    }

    @MainActor
    func testNoFaceDetectedState() throws {
        let app = XCUIApplication()
        app.launch()

        let noFaceButton = app.buttons["TryDemoNoFacePhoto"]
        XCTAssertTrue(noFaceButton.waitForExistence(timeout: 5.0), "Try Demo (No Face) button should exist")

        noFaceButton.tap()

        let noFaceText = app.staticTexts["NoFaceDetectedText"]
        XCTAssertTrue(noFaceText.waitForExistence(timeout: 5.0), "No face detected hint text should appear")

        let slider = app.sliders["SmoothingSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5.0), "Slider should exist")
        XCTAssertFalse(slider.isEnabled, "Slider should be disabled when no face is detected")
    }
}
