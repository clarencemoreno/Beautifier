import XCTest

final class BeautifierUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCameraViewPresentsControlsAndInteractsWithSlider() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Shutter button or Permission View must exist on CameraView launch
        let shutterButton = app.buttons["ShutterButton"]
        let openSettingsButton = app.buttons["OpenSettingsButton"]

        let hasCameraUI = shutterButton.waitForExistence(timeout: 5.0) || openSettingsButton.waitForExistence(timeout: 5.0)
        XCTAssertTrue(hasCameraUI, "CameraView should display shutter controls or permission overlay on launch")

        // 2. If camera controls are visible, test live smoothing slider
        let slider = app.sliders["LiveSmoothingSlider"]
        if slider.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(slider.isEnabled, "Live smoothing slider should be interactive")
            slider.adjust(toNormalizedSliderPosition: 0.8)
            slider.adjust(toNormalizedSliderPosition: 0.2)
        }
    }

    @MainActor
    func testCameraShutterButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        let shutterButton = app.buttons["ShutterButton"]
        let openSettingsButton = app.buttons["OpenSettingsButton"]

        let exists = shutterButton.waitForExistence(timeout: 5.0) || openSettingsButton.waitForExistence(timeout: 5.0)
        XCTAssertTrue(exists, "App must cleanly render CameraView UI without crashing")
    }
}
