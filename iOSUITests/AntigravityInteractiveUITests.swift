import Darwin
import Foundation
import XCTest

/// Embedded Connect-RPC HTTP server simulating a live Antigravity Desktop `language_server`
/// inside the `XCUITest` runner process so `Antigravity.app` exercises real network + real UI touch events.
private final class EmbeddedDesktopMockServer: @unchecked Sendable {
    let port: UInt16
    private let listenFD: Int32
    private let lock = NSLock()
    private var isStopped = false
    private var trajectoriesByCascadeId: [String: [[String: Any]]] = [:]
    private var summariesMap: [String: [String: Any]] = [:]
    private var createdCounter = 0

    init() throws {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NSError(domain: "EmbeddedDesktopMockServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "socket() failed"])
        }

        var yes: Int32 = 1
        _ = Darwin.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        _ = Darwin.setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0, Darwin.listen(fd, 32) == 0 else {
            Darwin.close(fd)
            throw NSError(domain: "EmbeddedDesktopMockServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "bind/listen failed"])
        }

        var boundAddr = sockaddr_in()
        var boundLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.getsockname(fd, sockPtr, &boundLen)
            }
        }

        self.listenFD = fd
        self.port = UInt16(bigEndian: boundAddr.sin_port)
        seedRealisticDesktopFixtures()

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        lock.lock()
        let alreadyStopped = isStopped
        isStopped = true
        lock.unlock()
        if !alreadyStopped {
            Darwin.shutdown(listenFD, SHUT_RDWR)
            Darwin.close(listenFD)
        }
    }

    private func seedRealisticDesktopFixtures() {
        summariesMap = [
            // Blank 0-step Desktop tab placeholder that MUST be filtered out on iOS
            "cid-blank-placeholder": [
                "stepCount": 0,
                "status": "CASCADE_RUN_STATUS_IDLE",
                "workspaces": [
                    ["workspaceFolderAbsoluteUri": "file:///Users/dev/slardar_app_ai"]
                ]
            ],
            // Synthetic probe session that MUST be filtered out on iOS
            "cid-synthetic-probe": [
                "summary": "iOS Connect-RPC Handshake Confirmation",
                "stepCount": 1,
                "status": "CASCADE_RUN_STATUS_DONE",
                "lastModifiedTime": "2026-11-11T08:59:00.000000000Z",
                "workspaces": [
                    ["workspaceFolderAbsoluteUri": "file:///Users/dev/iOSAntigravity"]
                ]
            ],
            // Running Cloud session (`venciallee/iOSAntigravity` -> `Antigravity iOS App Architecture Research` with 2x2 four-dot loading indicator)
            "cid-arch-research": [
                "summary": "Antigravity iOS App Architecture Research",
                "stepCount": 3,
                "status": "CASCADE_RUN_STATUS_RUNNING",
                "lastModifiedTime": "2026-11-11T08:58:00.000000000Z",
                "workspaces": [
                    [
                        "workspaceFolderAbsoluteUri": "cloud://venciallee/iOSAntigravity",
                        "gitBranch": "main"
                    ]
                ]
            ],
            // Unread completed Desktop session
            "cid-slardar-review": [
                "summary": "Slardar Tag Code Review",
                "stepCount": 5,
                "status": "CASCADE_RUN_STATUS_DONE",
                "lastModifiedTime": "2026-11-11T08:50:12.481920114Z",
                "annotations": [
                    "lastUserViewTime": "2026-11-11T08:30:00.000000Z"
                ],
                "workspaces": [
                    [
                        "workspaceFolderAbsoluteUri": "file:///Users/dev/slardar_app_ai",
                        "gitBranch": "main"
                    ]
                ]
            ],
            // Previously viewed idle Desktop session
            "cid-slardar-tracking": [
                "summary": "Slardar App AI 埋点梳理",
                "stepCount": 2,
                "status": "CASCADE_RUN_STATUS_IDLE",
                "lastModifiedTime": "2026-11-11T07:10:00.000000000Z",
                "annotations": [
                    "lastUserViewTime": "2026-11-11T07:25:00.000000Z"
                ],
                "workspaces": [
                    [
                        "workspaceFolderAbsoluteUri": "file:///Users/dev/slardar_app_ai",
                        "gitBranch": "main"
                    ]
                ]
            ]
        ]

        trajectoriesByCascadeId["cid-arch-research"] = [
            [
                "stepIndex": 0,
                "type": "CORTEX_STEP_TYPE_USER_INPUT",
                "status": "CORTEX_STEP_STATUS_DONE",
                "userInput": [
                    "items": [
                        ["text": "调研 Antigravity iOS App 与 PC language_server 的实时同步架构"]
                    ]
                ]
            ],
            [
                "stepIndex": 1,
                "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
                "status": "CORTEX_STEP_STATUS_IN_PROGRESS",
                "plannerResponse": [
                    "response": "正在通过 JetboxSubscribeToSummaries 与 ProjectUpdatesStream 同步全部项目会话..."
                ]
            ]
        ]

        trajectoriesByCascadeId["cid-slardar-review"] = [
            [
                "stepIndex": 0,
                "type": "CORTEX_STEP_TYPE_USER_INPUT",
                "status": "CORTEX_STEP_STATUS_DONE",
                "userInput": [
                    "userResponse": "",
                    "items": [
                        ["text": "请帮我 Review Slardar Tag 核心代码逻辑"],
                        [
                            "item": [
                                "file": [
                                    "absoluteUri": "file:///Users/dev/slardar_app_ai/internal/tag/manager.go"
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            [
                "stepIndex": 1,
                "type": "CORTEX_STEP_TYPE_CHECKPOINT",
                "status": "CORTEX_STEP_STATUS_DONE"
            ],
            [
                "stepIndex": 2,
                "type": "CORTEX_STEP_TYPE_VIEW_FILE",
                "status": "CORTEX_STEP_STATUS_DONE",
                "viewFile": [
                    "absolutePathUri": "file:///Users/dev/slardar_app_ai/internal/tag/manager.go",
                    "startLine": 1,
                    "endLine": 88
                ]
            ],
            [
                "stepIndex": 3,
                "type": "CORTEX_STEP_TYPE_GREP_SEARCH",
                "status": "CORTEX_STEP_STATUS_DONE",
                "grepSearch": [
                    "query": "RegisterTagValidator",
                    "searchPath": "internal/tag"
                ]
            ],
            [
                "stepIndex": 4,
                "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
                "status": "CORTEX_STEP_STATUS_DONE",
                "plannerResponse": [
                    "modifiedResponse": "",
                    "response": "已完成 Slardar Tag 模块审查：建议在 RegisterTagValidator 增加空值保护。",
                    "thinking": "Checked manager.go and validator chain.",
                    "thinkingDuration": "5.2s"
                ]
            ]
        ]

        trajectoriesByCascadeId["cid-slardar-tracking"] = [
            [
                "stepIndex": 0,
                "type": "CORTEX_STEP_TYPE_USER_INPUT",
                "status": "CORTEX_STEP_STATUS_DONE",
                "userInput": [
                    "items": [
                        ["text": "梳理 Slardar App AI 全链路埋点上报时机"]
                    ]
                ]
            ],
            [
                "stepIndex": 1,
                "type": "CORTEX_STEP_TYPE_NOTIFY_USER",
                "status": "CORTEX_STEP_STATUS_DONE",
                "notifyUser": [
                    "notificationContent": "已整理完冷启动、会话切换与异常捕获三处核心埋点。"
                ]
            ]
        ]
    }

    /// Simulates a new message sent from Antigravity Desktop (PC) while iOS is viewing the conversation.
    func injectPCMessage(cascadeId: String, userText: String, assistantReply: String) {
        lock.lock()
        defer { lock.unlock() }
        var steps = trajectoriesByCascadeId[cascadeId] ?? []
        let baseIdx = steps.count
        steps.append([
            "stepIndex": baseIdx,
            "type": "CORTEX_STEP_TYPE_USER_INPUT",
            "status": "CORTEX_STEP_STATUS_DONE",
            "userInput": [
                "items": [["text": userText]]
            ]
        ])
        steps.append([
            "stepIndex": baseIdx + 1,
            "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
            "status": "CORTEX_STEP_STATUS_DONE",
            "plannerResponse": [
                "modifiedResponse": "",
                "response": assistantReply
            ]
        ])
        trajectoriesByCascadeId[cascadeId] = steps
        if var summary = summariesMap[cascadeId] {
            summary["stepCount"] = steps.count
            summary["status"] = "CASCADE_RUN_STATUS_DONE"
            summary["lastModifiedTime"] = "2026-11-11T09:05:00.000000000Z"
            summariesMap[cascadeId] = summary
        }
    }

    private func acceptLoop() {
        while true {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    Darwin.accept(listenFD, sockPtr, &clientLen)
                }
            }
            if clientFD < 0 {
                lock.lock()
                let stopped = isStopped
                lock.unlock()
                if stopped { break }
                continue
            }
            var yes: Int32 = 1
            _ = Darwin.setsockopt(clientFD, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { Darwin.close(fd) }

        var rawData = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        let headerSeparator = Data("\r\n\r\n".utf8)
        var headerEndIndex: Int?
        var expectedBodyBytes = 0

        while true {
            let n = Darwin.recv(fd, &buffer, buffer.count, 0)
            if n <= 0 { break }
            rawData.append(contentsOf: buffer.prefix(n))

            if headerEndIndex == nil, let range = rawData.range(of: headerSeparator) {
                headerEndIndex = range.upperBound
                let headerString = String(decoding: rawData[..<range.lowerBound], as: UTF8.self)
                for line in headerString.split(separator: "\r\n") {
                    if line.lowercased().hasPrefix("content-length:") {
                        let val = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        expectedBodyBytes = Int(val) ?? 0
                    }
                }
            }

            if let endIdx = headerEndIndex, rawData.count >= endIdx + expectedBodyBytes {
                break
            }
        }

        guard let bodyStart = headerEndIndex else { return }
        let headerText = String(decoding: rawData[..<(bodyStart - 4)], as: UTF8.self)
        let firstLine = headerText.split(separator: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let path = parts.count >= 2 ? String(parts[1]) : "/"
        let bodyData = rawData.subdata(in: bodyStart..<min(rawData.count, bodyStart + expectedBodyBytes))

        let (statusCode, contentType, responseBody) = routeRequest(path: path, bodyData: bodyData)
        var headerLines = "HTTP/1.1 \(statusCode) OK\r\n"
        headerLines += "Content-Type: \(contentType)\r\n"
        headerLines += "Content-Length: \(responseBody.count)\r\n"
        headerLines += "Connection: close\r\n\r\n"

        var out = Data(headerLines.utf8)
        out.append(responseBody)
        out.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return }
            var sent = 0
            while sent < out.count {
                let written = Darwin.send(fd, base.advanced(by: sent), out.count - sent, 0)
                if written <= 0 { break }
                sent += written
            }
        }
    }

    private func routeRequest(path: String, bodyData: Data) -> (Int, String, Data) {
        let jsonBody = (try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]) ?? [:]

        if path.hasSuffix("/JetboxSubscribeToSummaries") {
            lock.lock()
            let payloadDict: [String: Any] = ["updates": summariesMap, "deletes": []]
            lock.unlock()
            let jsonBytes = (try? JSONSerialization.data(withJSONObject: payloadDict)) ?? Data("{}".utf8)
            var frame = Data([0x00])
            var lenBE = UInt32(jsonBytes.count).bigEndian
            withUnsafeBytes(of: &lenBE) { frame.append(contentsOf: $0) }
            frame.append(jsonBytes)
            frame.append(contentsOf: [0x02, 0x00, 0x00, 0x00, 0x02])
            frame.append(contentsOf: "{}".utf8)
            return (200, "application/connect+json", frame)
        }

        lock.lock()
        defer { lock.unlock() }

        let responseDict: [String: Any]
        if path.hasSuffix("/GetWorkspaceInfos") {
            responseDict = [
                "workspaceInfos": [
                    [
                        "workspaceUri": "cloud://venciallee/iOSAntigravity",
                        "gitBranch": "main"
                    ],
                    [
                        "workspaceUri": "file:///Users/dev/slardar_app_ai",
                        "gitBranch": "main"
                    ]
                ]
            ]
        } else if path.hasSuffix("/GetAllCascadeTrajectories") {
            responseDict = ["trajectorySummaries": summariesMap]
        } else if path.hasSuffix("/GetCascadeTrajectorySteps") {
            let cid = (jsonBody["cascadeId"] as? String) ?? ""
            let allSteps = trajectoriesByCascadeId[cid] ?? []
            let startIdx = max(0, (jsonBody["startIndex"] as? Int) ?? 0)
            let endIdx = min(allSteps.count, max(startIdx, (jsonBody["endIndex"] as? Int) ?? allSteps.count))
            let slice = startIdx < endIdx ? Array(allSteps[startIdx..<endIdx]) : []
            responseDict = ["steps": slice]
        } else if path.hasSuffix("/ListAutomations") {
            responseDict = ["automations": []]
        } else if path.hasSuffix("/StartCascade") {
            createdCounter += 1
            let newId = "cid-live-created-\(createdCounter)"
            let wsUris = (jsonBody["workspaceUris"] as? [String]) ?? ["file:///Users/dev/slardar_app_ai"]
            let wsUri = wsUris.first ?? "file:///Users/dev/slardar_app_ai"
            summariesMap[newId] = [
                "summary": "New Conversation",
                "stepCount": 0,
                "status": "CASCADE_RUN_STATUS_IDLE",
                "lastModifiedTime": "2026-11-11T09:00:00.000000000Z",
                "workspaces": [
                    ["workspaceFolderAbsoluteUri": wsUri, "gitBranch": "main"]
                ]
            ]
            trajectoriesByCascadeId[newId] = []
            responseDict = ["cascadeId": newId]
        } else if path.hasSuffix("/SendUserCascadeMessage") {
            let cid = (jsonBody["cascadeId"] as? String) ?? ""
            var promptText = (jsonBody["userResponse"] as? String) ?? ""
            if promptText.isEmpty,
               let items = jsonBody["items"] as? [[String: Any]],
               let firstText = items.first?["text"] as? String {
                promptText = firstText
            }
            var steps = trajectoriesByCascadeId[cid] ?? []
            let baseIdx = steps.count
            steps.append([
                "stepIndex": baseIdx,
                "type": "CORTEX_STEP_TYPE_USER_INPUT",
                "status": "CORTEX_STEP_STATUS_DONE",
                "userInput": [
                    "items": [["text": promptText]]
                ]
            ])
            steps.append([
                "stepIndex": baseIdx + 1,
                "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
                "status": "CORTEX_STEP_STATUS_DONE",
                "plannerResponse": [
                    "modifiedResponse": "",
                    "response": "收到来自 iOS 真模拟器的实时指令，已同步至 Desktop。"
                ]
            ])
            trajectoriesByCascadeId[cid] = steps
            if var summary = summariesMap[cid] {
                summary["summary"] = String(promptText.prefix(40))
                summary["stepCount"] = steps.count
                summary["status"] = "CASCADE_RUN_STATUS_DONE"
                summariesMap[cid] = summary
            }
            responseDict = ["ok": true]
        } else {
            responseDict = ["ok": true]
        }

        let data = (try? JSONSerialization.data(withJSONObject: responseDict)) ?? Data("{}".utf8)
        return (200, "application/json", data)
    }
}

@MainActor
final class AntigravityInteractiveUITests: XCTestCase {

    /// End-to-end real UI touch/click test on iOS Simulator against a live Connect-RPC Desktop server:
    /// 1. Verifies cloud project (`venciallee/iOSAntigravity` -> `Antigravity iOS App Architecture Research`) and its 2×2 four-dot loading indicator (`loading-four-dots-cid-arch-research`), while filtering out 0-step blank tabs and synthetic `iOS Connect-RPC Handshake` probes.
    /// 2. Taps a live conversation row on `Agents` home and verifies `CascadeChatViewController` opens & renders steps, then injects a live PC message and verifies iOS receives it automatically without user interaction.
    /// 3. Navigates back, opens `ProjectDetailViewController`, taps a conversation row inside the project, and returns.
    /// 4. Taps the Periwinkle Compose FAB, types a prompt, taps Send, and verifies live `StartCascade` + `SendUserCascadeMessage` round-trip.
    func testLiveConversationRowTapProjectNavigationAndSendMessage() throws {
        let server = try EmbeddedDesktopMockServer()
        defer { server.stop() }

        let app = XCUIApplication()
        app.launchEnvironment["ANTIGRAVITY_BACKEND_URL"] = "http://127.0.0.1:\(server.port)"
        app.launchEnvironment["ANTIGRAVITY_CSRF_TOKEN"] = "uitest-csrf-token"
        app.launchEnvironment["ANTIGRAVITY_HOST_NAME"] = "MacBook-Pro-Live"
        app.launchEnvironment["NO_PROXY"] = "127.0.0.1,localhost,::1"
        app.launchEnvironment["no_proxy"] = "127.0.0.1,localhost,::1"
        app.launch()

        // 1. Verify live Desktop sessions load on Agents Home, 2x2 four-dot loading indicator is present, and synthetic probe / 0-step placeholder are filtered out
        let reviewRow = app.buttons["conv-row-cid-slardar-review"]
        XCTAssertTrue(
            reviewRow.waitForExistence(timeout: 12),
            "Live Desktop conversation row 'Slardar Tag Code Review' must render as a tappable Button on Agents Home"
        )
        let archResearchRow = app.buttons["conv-row-cid-arch-research"]
        XCTAssertTrue(
            archResearchRow.waitForExistence(timeout: 6),
            "Cloud project conversation 'Antigravity iOS App Architecture Research' must render on Agents Home"
        )
        let fourDotIndicator = app.descendants(matching: .any)["loading-four-dots-cid-arch-research"].firstMatch
        XCTAssertTrue(
            fourDotIndicator.waitForExistence(timeout: 5),
            "Running conversation row MUST render the authentic Antigravity 2x2 four-dot loading indicator"
        )
        XCTAssertFalse(
            app.buttons["conv-row-cid-blank-placeholder"].exists,
            "Unused 0-step Desktop tab placeholders must not appear on Agents Home"
        )
        XCTAssertFalse(
            app.buttons["conv-row-cid-synthetic-probe"].exists,
            "Synthetic 'iOS Connect-RPC Handshake' probe sessions must be filtered out"
        )
        attachScreenshot(named: "01_Live_Agents_Home")

        // 2. REAL TAP on conversation row -> MUST open CascadeChatViewController and load steps
        reviewRow.tap()

        let backToSessionsButton = app.buttons["btn-back-sessions"]
        XCTAssertTrue(
            backToSessionsButton.waitForExistence(timeout: 6),
            "Tapping a conversation row on Agents Home MUST navigate to CascadeChatViewController"
        )
        let navTitle = app.descendants(matching: .any)["chat-nav-title"].firstMatch
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(navTitle.label.contains("Slardar Tag Code Review"))

        XCTAssertTrue(
            waitForTextContaining("请帮我 Review Slardar Tag 核心代码逻辑", in: app, timeout: 6),
            "Real Desktop userInput items[].text must render inside CascadeChatViewController"
        )
        XCTAssertTrue(
            waitForTextContaining("已完成 Slardar Tag 模块审查", in: app, timeout: 6),
            "Real Desktop plannerResponse must render even when modifiedResponse is empty"
        )

        // 2b. Simulate PC sending a new message while iOS is viewing this conversation -> verify iOS auto-updates in real time!
        server.injectPCMessage(
            cascadeId: "cid-slardar-review",
            userText: "PC 端新增的实时追问消息：请补充单元测试",
            assistantReply: "已为您补充 RegisterTagValidator 的边界单元测试。"
        )
        XCTAssertTrue(
            waitForTextContaining("PC 端新增的实时追问消息：请补充单元测试", in: app, timeout: 6),
            "New message added on PC must automatically appear on iOS within seconds without touching the screen"
        )
        XCTAssertTrue(
            waitForTextContaining("已为您补充 RegisterTagValidator 的边界单元测试", in: app, timeout: 6),
            "New assistant reply from PC must automatically appear on iOS"
        )

        // Verify zero offline ESDD mock artifacts leak into live conversation view
        XCTAssertFalse(app.buttons["composer-chip-ratelimit"].exists, "Offline @ratelimit.go mock chip must not appear in live mode")
        XCTAssertFalse(app.buttons["chat-diff-pill"].exists, "Offline +128/-14 mock diff pill must not appear when live diffs are zero")
        attachScreenshot(named: "02_Opened_Live_Conversation_Detail")

        // 3. Navigate back -> open Project Detail -> tap conversation row inside Project Detail
        backToSessionsButton.tap()
        XCTAssertTrue(reviewRow.waitForExistence(timeout: 5), "Back button must return to Agents Home")

        let projectHeader = app.buttons["project-header-slardar_app_ai"]
        XCTAssertTrue(projectHeader.waitForExistence(timeout: 5))
        projectHeader.tap()

        let backToAgentsButton = app.buttons["btn-back-agents"]
        XCTAssertTrue(
            backToAgentsButton.waitForExistence(timeout: 5),
            "Tapping project header must open ProjectDetailViewController"
        )
        attachScreenshot(named: "03_Opened_Live_Project_Detail")

        let projectConvRow = app.buttons["project-conv-row-cid-slardar-tracking"]
        XCTAssertTrue(projectConvRow.waitForExistence(timeout: 5))
        projectConvRow.tap()

        XCTAssertTrue(
            backToSessionsButton.waitForExistence(timeout: 5),
            "Tapping a conversation row inside ProjectDetailViewController must open CascadeChatViewController"
        )
        XCTAssertTrue(app.descendants(matching: .any)["chat-nav-title"].firstMatch.label.contains("Slardar App AI 埋点梳理"))
        XCTAssertTrue(
            waitForTextContaining("已整理完冷启动", in: app, timeout: 5),
            "CORTEX_STEP_TYPE_NOTIFY_USER content must render in CascadeChatViewController"
        )

        // Back from project-launched chat returns to ProjectDetail, then back to Agents Home
        backToSessionsButton.tap()
        XCTAssertTrue(backToAgentsButton.waitForExistence(timeout: 5))
        backToAgentsButton.tap()
        XCTAssertTrue(reviewRow.waitForExistence(timeout: 5))

        // 4. Tap Compose FAB -> send live message -> verify StartCascade + SendUserCascadeMessage round-trip
        let composeFAB = app.buttons["fab-compose"]
        XCTAssertTrue(composeFAB.waitForExistence(timeout: 5))
        composeFAB.tap()
        XCTAssertTrue(backToSessionsButton.waitForExistence(timeout: 5))

        let composerInput = app.descendants(matching: .any)["composer-text-input"].firstMatch
        XCTAssertTrue(composerInput.waitForExistence(timeout: 5))
        composerInput.tap()
        composerInput.typeText("Verify live Simulator tap and send")

        let sendButton = app.buttons["composer-btn-send"]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()

        XCTAssertTrue(
            waitForTextContaining("收到来自 iOS 真模拟器的实时指令", in: app, timeout: 8),
            "Sending a message in Composer must dispatch StartCascade + SendUserCascadeMessage and render streamed reply"
        )
        attachScreenshot(named: "04_Live_Composed_And_Streamed_Reply")
    }

    private func waitForTextContaining(_ substring: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)
        return app.descendants(matching: .any).containing(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
