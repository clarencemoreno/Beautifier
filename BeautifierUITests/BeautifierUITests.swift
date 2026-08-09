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
        XCTAssertTrue(slider.waitForExistence(timeout: 5.0), "Slider should exist")
        XCTAssertTrue(slider.isEnabled, "Slider should be enabled for adjusting smoothing intensity")

        // 1. Verify initial slider value
        let initialVal = slider.value as? String

        // 2. Drag slider to 0.8
        slider.adjust(toNormalizedSliderPosition: 0.8)

        // 3. Verify slider value changed in UI hierarchy
        let newVal = slider.value as? String
        XCTAssertNotEqual(initialVal, newVal, "Slider value in UI hierarchy should update after dragging")

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
        XCTAssertTrue(slider.isEnabled, "Slider should remain enabled for global fallback smoothing")

        let initialVal = slider.value as? String
        slider.adjust(toNormalizedSliderPosition: 0.9)
        let newVal = slider.value as? String
        XCTAssertNotEqual(initialVal, newVal, "Slider position should update on drag during fallback smoothing")
    }

    @MainActor
    func testSliderInteractionRange() throws {
        let app = XCUIApplication()
        app.launch()

        let demoButton = app.buttons["TryDemoPhoto"]
        demoButton.tap()

        let slider = app.sliders["SmoothingSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5.0), "Slider should exist")

        let positions: [CGFloat] = [0.0, 0.5, 1.0]
        var previousVal: String? = nil

        for pos in positions {
            slider.adjust(toNormalizedSliderPosition: pos)
            let currentVal = slider.value as? String
            if let prev = previousVal {
                XCTAssertNotEqual(prev, currentVal,
                    "Slider value should change between positions")
            }
            previousVal = currentVal
        }
    }
}
