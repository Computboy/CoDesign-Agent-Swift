import XCTest

final class CoDesign_AgentUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testMindTreeAnnotationEntryIsDiscoverable() throws {
        let app = XCUIApplication()
        app.launch()

        let continueProjectButton = app.buttons["继续最近项目"].firstMatch
        XCTAssertTrue(
            continueProjectButton.waitForExistence(timeout: 10),
            "首页应提供进入最近项目的入口"
        )
        continueProjectButton.tap()

        let mindTreeButton = app.buttons["思维树"].firstMatch
        XCTAssertTrue(
            mindTreeButton.waitForExistence(timeout: 10),
            "项目工作台应提供思维树入口"
        )
        mindTreeButton.tap()

        let annotationButton = app.buttons["mindTree.startAnnotation"]
        XCTAssertTrue(
            annotationButton.waitForExistence(timeout: 10),
            "独立思维树页面应显示开始批注按钮"
        )

        let browsingScreenshot = XCTAttachment(screenshot: app.screenshot())
        browsingScreenshot.name = "Mind Tree Annotation Entry"
        browsingScreenshot.lifetime = .keepAlways
        add(browsingScreenshot)

        annotationButton.tap()

        let drawingToolsButton = app.buttons["画笔工具"]
        XCTAssertTrue(
            drawingToolsButton.waitForExistence(timeout: 10),
            "进入批注模式后应显示画笔工具按钮"
        )

        let annotatingScreenshot = XCTAttachment(screenshot: app.screenshot())
        annotatingScreenshot.name = "Mind Tree Annotating Mode"
        annotatingScreenshot.lifetime = .keepAlways
        add(annotatingScreenshot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
