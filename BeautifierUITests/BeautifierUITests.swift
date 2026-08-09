import XCTest

final class BeautifierUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTryDemoPhotoLoadsEditViewAndInteractsWithSlider() throws {
        let app = XCUIApplication()
        app.launch()

        let demoButton = app.buttons["TryDemoPhoto"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5.0), "Try Demo Photo button should exist")

        demoButton.tap()

        let saveButton = app.buttons["SaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5.0), "Save button should exist on Edit screen")

        let slider = app.sliders["SmoothingSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5.0), "Slider element should exist")

        // Wait for background face detection to complete (spinner text disappears)
        let detectingText = app.staticTexts["Detecting face skin..."]
        if detectingText.exists {
            let predicate = NSPredicate(format: "exists == false")
            let exp = expectation(for: predicate, evaluatedWith: detectingText, handler: nil)
            wait(for: [exp], timeout: 10.0)
        }

        // 1. Verify slider is enabled for face photo
        XCTAssertTrue(slider.isEnabled, "Slider must be enabled when a face is detected")

        // 2. Read initial slider value
        let initialVal = slider.value as? String
        XCTAssertNotNil(initialVal, "Slider accessibility value must exist")

        // 3. Drag slider to position 0.8
        slider.adjust(toNormalizedSliderPosition: 0.8)

        // 4. Test Mask Debug Toggle button
        let maskDebugButton = app.buttons["MaskDebugButton"]
        XCTAssertTrue(maskDebugButton.waitForExistence(timeout: 5.0), "Mask debug button should exist in toolbar")
        maskDebugButton.tap()

        // Toggle mask debug back off
        maskDebugButton.tap()
    }

    @MainActor
    func testNoFaceDetectedStateFallback() throws {
        let app = XCUIApplication()
        app.launch()

        let noFaceButton = app.buttons["TryDemoNoFacePhoto"]
        XCTAssertTrue(noFaceButton.waitForExistence(timeout: 5.0), "Try Demo (No Face) button should exist")

        noFaceButton.tap()

        let noFaceText = app.staticTexts["NoFaceDetectedText"]
        XCTAssertTrue(noFaceText.waitForExistence(timeout: 10.0), "No face detected hint text should appear")

        let slider = app.sliders["SmoothingSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5.0), "Slider should exist")
        XCTAssertFalse(slider.isEnabled, "Slider should be disabled when no face is detected")
    }

    @MainActor
    func testSliderInteractionRange() throws {
        let app = XCUIApplication()
        app.launch()

        let demoButton = app.buttons["TryDemoPhoto"]
        demoButton.tap()

        let slider = app.sliders["SmoothingSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5.0), "Slider should exist")

        // Wait for background face detection to complete
        let detectingText = app.staticTexts["Detecting face skin..."]
        if detectingText.exists {
            let predicate = NSPredicate(format: "exists == false")
            let exp = expectation(for: predicate, evaluatedWith: detectingText, handler: nil)
            wait(for: [exp], timeout: 10.0)
        }

        XCTAssertTrue(slider.isEnabled, "Slider must be enabled when a face is detected")

        slider.adjust(toNormalizedSliderPosition: 0.1)
        slider.adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertNotNil(slider.value, "Slider should exist and be adjustable")
    }
}
