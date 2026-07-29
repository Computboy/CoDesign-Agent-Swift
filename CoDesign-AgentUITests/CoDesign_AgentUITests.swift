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

        let rootNode = app.buttons["mindTree.rootNode"]
        XCTAssertTrue(
            rootNode.waitForExistence(timeout: 10),
            "思维树根节点应当可见"
        )
        let viewportMidX = app.windows.firstMatch.frame.midX
        XCTAssertLessThan(
            abs(rootNode.frame.midX - viewportMidX),
            120,
            "思维树初始视角应以根节点为水平中心"
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

        let textBoxButton = app.buttons["文本框"]
        XCTAssertTrue(
            textBoxButton.waitForExistence(timeout: 10),
            "进入批注模式后应显示文本框按钮"
        )
        textBoxButton.tap()

        XCTAssertTrue(
            app.navigationBars["新建文本框"].waitForExistence(timeout: 10),
            "文本框按钮应打开文字编辑器"
        )
        XCTAssertTrue(
            app.textViews.firstMatch.waitForExistence(timeout: 10),
            "文字编辑器应提供多行文本输入"
        )
        app.buttons["取消"].tap()

        let annotatingScreenshot = XCTAttachment(screenshot: app.screenshot())
        annotatingScreenshot.name = "Mind Tree Annotating Mode"
        annotatingScreenshot.lifetime = .keepAlways
        add(annotatingScreenshot)
    }

    @MainActor
    func testWorkspaceRedesignKeepsCoreDestinationsAccessible() throws {
        XCUIDevice.shared.orientation = .landscapeLeft

        let app = XCUIApplication()
        app.launch()

        let continueProjectButton = app.buttons["继续最近项目"].firstMatch
        XCTAssertTrue(
            continueProjectButton.waitForExistence(timeout: 10),
            "首页应提供进入最近项目的入口"
        )
        continueProjectButton.tap()

        XCTAssertTrue(
            app.buttons["工作台"].waitForExistence(timeout: 10),
            "横屏工作台应显示工作台入口"
        )
        XCTAssertTrue(app.buttons["思维树"].exists)
        XCTAssertTrue(app.buttons["成果看板"].exists)
        XCTAssertTrue(app.buttons["导出报告"].exists)
        XCTAssertFalse(app.buttons["专注"].exists)

        XCTAssertTrue(
            app.buttons["项目库"].waitForExistence(timeout: 10),
            "页面浮动侧栏应提供项目库入口"
        )
        XCTAssertTrue(app.buttons["资源库"].exists)
        XCTAssertTrue(app.buttons["设置"].exists)
        XCTAssertTrue(app.buttons["收起侧栏"].exists)

        XCTAssertTrue(
            app.buttons["查看详情"].waitForExistence(timeout: 10),
            "工作区应显示设计依据摘要卡"
        )
        XCTAssertTrue(app.buttons["查看全部字段"].exists)
        XCTAssertTrue(app.buttons["查看学习记录"].exists)

        let rootNode = app.buttons["mindTree.rootNode"]
        XCTAssertTrue(
            rootNode.waitForExistence(timeout: 10),
            "重设计后仍应显示原有思维树根节点"
        )

        let startCreatingButton = app.buttons["mindTree.startCreating"]
        XCTAssertTrue(
            startCreatingButton.waitForExistence(timeout: 10),
            "嵌入式思维树右上角应提供开始创作入口"
        )
        XCTAssertTrue(
            app.sliders["缩放范围"].waitForExistence(timeout: 10),
            "嵌入式思维树右下角应保留缩放控制"
        )

        let firstStage = app.buttons["workspace.stage.1"]
        XCTAssertTrue(
            firstStage.waitForExistence(timeout: 10),
            "底部阶段进度栏应提供可交互的阶段圆点"
        )
        firstStage.tap()

        let stageBubble = app.scrollViews["workspace.stageExplanation"]
        XCTAssertTrue(
            stageBubble.waitForExistence(timeout: 10),
            "点击阶段圆点应显示阶段说明气泡"
        )

        let closeStageBubble = app.buttons["workspace.stageExplanation.close"]
        XCTAssertTrue(
            closeStageBubble.waitForExistence(timeout: 10) && closeStageBubble.isHittable,
            "阶段说明气泡位于侧栏上方时，关闭按钮应保持可点击"
        )
        closeStageBubble.tap()

        let projectLibraryButton = app.buttons["workspace.sideRail.项目库"]
        XCTAssertTrue(
            projectLibraryButton.waitForExistence(timeout: 10),
            "浮动侧栏应保留项目库入口"
        )
        projectLibraryButton.tap()

        XCTAssertTrue(
            app.navigationBars["项目库"].waitForExistence(timeout: 10),
            "项目库入口应进入完整项目仓库，而不是退回首页"
        )
        XCTAssertTrue(
            app.searchFields["搜索项目"].exists,
            "完整项目仓库应提供项目搜索"
        )
        app.buttons["返回"].firstMatch.tap()

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Workspace UI Redesign"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        startCreatingButton.tap()
        XCTAssertTrue(
            app.buttons["画笔工具"].waitForExistence(timeout: 10),
            "开始创作应一次进入全屏思维树的批注状态"
        )
    }

    @MainActor
    func testTextAnnotationSurvivesTransitionLayoutChange() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launch()

        let continueProjectButton = app.buttons["继续最近项目"].firstMatch
        XCTAssertTrue(continueProjectButton.waitForExistence(timeout: 10))
        continueProjectButton.tap()

        let mindTreeButton = app.buttons["思维树"].firstMatch
        XCTAssertTrue(mindTreeButton.waitForExistence(timeout: 10))
        mindTreeButton.tap()

        let startAnnotation = app.buttons["mindTree.startAnnotation"]
        XCTAssertTrue(startAnnotation.waitForExistence(timeout: 10))
        startAnnotation.tap()

        let textBoxButton = app.buttons["文本框"]
        XCTAssertTrue(textBoxButton.waitForExistence(timeout: 10))
        textBoxButton.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        editor.typeText("layout-anchor-note")

        let saveButton = app.buttons["保存"]
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: saveButton)
        waitForExpectations(timeout: 10)
        saveButton.tap()

        let annotation = app.descendants(matching: .any)
            .matching(identifier: "mindTree.annotation.text")
            .firstMatch
        XCTAssertTrue(
            annotation.waitForExistence(timeout: 10),
            "保存后应立即显示文字批注"
        )
        app.buttons["完成"].tap()

        let transition = app.buttons["mindTree.transition.1"]
        XCTAssertTrue(
            transition.waitForExistence(timeout: 10),
            "阶段连线应提供可访问的展开按钮"
        )
        transition.tap()

        XCTAssertTrue(
            annotation.waitForExistence(timeout: 10),
            "思维树展开并改变指纹后，文字批注仍应存在"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
