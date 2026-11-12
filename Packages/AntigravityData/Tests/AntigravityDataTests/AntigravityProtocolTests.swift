import XCTest
@testable import AntigravityData

final class AntigravityProtocolTests: XCTestCase {

    func testConnectEnvelopeRoundTripAndChunkedStreamParsing() {
        let message1 = Data("{\"stepIndex\":1,\"status\":\"RUNNING\"}".utf8)
        let message2 = Data("{\"stepIndex\":2,\"status\":\"WAITING\"}".utf8)

        let frame1 = ConnectEnvelope.encode(payload: message1, flags: [])
        let frame2 = ConnectEnvelope.encode(payload: message2, flags: [.endStream])

        var combined = Data()
        combined.append(frame1)
        combined.append(frame2)

        var parser = ConnectStreamParser()
        let firstHalf = combined.prefix(7)
        let secondHalf = combined.dropFirst(7)

        let partial = parser.feed(Data(firstHalf))
        XCTAssertTrue(partial.isEmpty, "Partial frame should wait for remaining bytes")

        let decodedFrames = parser.feed(Data(secondHalf))
        XCTAssertEqual(decodedFrames.count, 2)
        XCTAssertEqual(decodedFrames[0].payload, message1)
        XCTAssertFalse(decodedFrames[0].isEndStream)
        XCTAssertEqual(decodedFrames[1].payload, message2)
        XCTAssertTrue(decodedFrames[1].isEndStream)
    }

    func testProtobufStepRequestEncodingAndJSONValueCodable() throws {
        let encodedReq = ProtobufStepCodec.encodeGetStepsRequest(
            cascadeId: "cas-rate-limiter",
            startIndex: 0,
            endIndex: 750
        )
        XCTAssertEqual(encodedReq.first, 0x0A)
        XCTAssertGreaterThan(encodedReq.count, 18)

        let sample: [String: JSONValue] = [
            "cascadeId": .string("cas-rate-limiter"),
            "stepCount": .int(28),
            "thinkingDurationSeconds": .double(14.5),
            "verified": .bool(true),
            "tags": .array([.string("go"), .string("ratelimit")])
        ]
        let raw = try JSONEncoder().encode(sample)
        let roundTrip = try JSONDecoder().decode([String: JSONValue].self, from: raw)
        XCTAssertEqual(roundTrip, sample)
        XCTAssertEqual(roundTrip["thinkingDurationSeconds"]?.doubleValue, 14.5)
        XCTAssertEqual(roundTrip["stepCount"]?.doubleValue, 28.0)
    }

    func testInteractionBuilderMatchesRequestedOneofFaceIDAndSafeAutoAccept() throws {
        let cmd = "vegeta attack -rate=2000/s -duration=30s -targets=load/transfers.txt | vegeta report"
        let step = CascadeStep(
            cascadeId: "cas-rate-limiter",
            stepIndex: 5,
            type: .runCommand,
            status: .waiting,
            runCommand: RunCommandPayload(
                commandId: "cmd-vegeta-01",
                commandLine: cmd,
                proposedCommandLine: cmd,
                cwd: "~/code/ledger-svc"
            ),
            requestedInteraction: RequestedInteraction(
                kind: .runCommand,
                runCommand: RunCommandInteractionSpec(
                    proposedCommandLine: cmd,
                    cwd: "~/code/ledger-svc"
                )
            )
        )

        let payload = try XCTUnwrap(
            InteractionBuilder.buildPayload(
                step: step,
                decision: .allowWithFaceID,
                workspaceUri: "file:///Users/wl/code/ledger-svc"
            )
        )
        XCTAssertEqual(payload.cascadeId, "cas-rate-limiter")
        XCTAssertEqual(payload.stepIndex, 5)
        XCTAssertEqual(payload.runCommand?.confirm, true)
        XCTAssertEqual(payload.runCommand?.faceIdVerified, true)
        XCTAssertEqual(payload.runCommand?.proposedCommandLine, cmd)

        XCTAssertTrue(SafeAutoAcceptPolicy.isSafeReadOnlyCommand("git status -s"))
        XCTAssertFalse(SafeAutoAcceptPolicy.isSafeReadOnlyCommand("rm -rf /tmp/build"))
        XCTAssertFalse(SafeAutoAcceptPolicy.isSafeReadOnlyCommand(cmd))
    }

    @MainActor
    func testAgentsHomeDisplayOptionsAndContextMenuMutations() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()

        // UE01 badge counts: Running 2, Needs you 1, Unread 3, Pinned 2
        XCTAssertEqual(store.runningCount, 2)
        XCTAssertEqual(store.needsYouCount, 1)
        XCTAssertEqual(store.unreadCount, 3)
        XCTAssertEqual(store.pinnedSummaries.count, 2)
        XCTAssertEqual(store.unpinnedSummaries(forProject: "ledger-svc").count, 3)

        // UE01 quick filters
        store.quickFilter = .needsYou
        XCTAssertEqual(store.filteredSummaries.count, 1)
        XCTAssertEqual(store.filteredSummaries.first?.cascadeId, "cas-flaky-settlement")

        store.quickFilter = .all
        store.displayOptions.sortBy = .title
        store.displayOptions.newestFirst = false
        store.resetDisplayOptions()
        XCTAssertEqual(store.displayOptions, AgentDisplayOptions())

        // UE02 Mark All as Read
        store.markAllConversationsAsRead()
        XCTAssertEqual(store.unreadCount, 0)

        // UE03 Pin / Unread / Rename / Move / Archive / Delete
        store.togglePinCascade("cas-upgrade-go")
        XCTAssertEqual(store.pinnedSummaries.count, 3)

        store.toggleUnreadCascade("cas-upgrade-go")
        XCTAssertEqual(store.unreadCount, 1)

        store.renameCascade("cas-upgrade-go", newTitle: "Upgrade toolchain to Go 1.25.1")
        XCTAssertEqual(
            store.summaries.first(where: { $0.cascadeId == "cas-upgrade-go" })?.title,
            "Upgrade toolchain to Go 1.25.1"
        )

        store.moveCascade("cas-upgrade-go", toProject: "web-console")
        XCTAssertEqual(
            store.summaries.first(where: { $0.cascadeId == "cas-upgrade-go" })?.projectSlug,
            "web-console"
        )

        store.archiveCascade("cas-upgrade-go")
        XCTAssertTrue(store.summaries.first(where: { $0.cascadeId == "cas-upgrade-go" })?.isArchived == true)

        store.deleteCascade("cas-upgrade-go")
        XCTAssertNil(store.summaries.first(where: { $0.cascadeId == "cas-upgrade-go" }))
    }

    @MainActor
    func testCreateProjectScopedConversationAndAutomations() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()

        // UE05 Create New Project (Cloud + GitHub acme/ledger-svc -> ledger-svc-cloud)
        let createdProject = store.createNewProject()
        XCTAssertEqual(createdProject.id, "ledger-svc-cloud")
        XCTAssertEqual(createdProject.runtime, .cloud)
        XCTAssertEqual(store.activeRoute, .projectDetail("ledger-svc-cloud"))

        // UE04 New Conversation in Project
        let convId = store.createConversationInProject("ledger-svc", title: "Verify settlement metrics")
        XCTAssertEqual(store.activeCascadeId, convId)
        XCTAssertEqual(store.activeRoute, .cascadeChat(convId))

        // UE06 Automations: Scheduled 2, Always On 1, Paused 1
        XCTAssertEqual(store.scheduledAutomations.count, 2)
        XCTAssertEqual(store.alwaysOnAutomations.count, 1)
        XCTAssertEqual(store.pausedAutomations.count, 1)

        let createdAuto = store.createAutomationFromPrompt("Every weekday at 9, summarize")
        XCTAssertNotNil(createdAuto)
        XCTAssertEqual(store.scheduledAutomations.count, 3)

        store.triggerAutomationNow("auto-nightly-audit")
        XCTAssertTrue(store.automations.first(where: { $0.id == "auto-nightly-audit" })?.isRunningNow == true)

        store.resumeAutomation("auto-bundle-size")
        XCTAssertEqual(store.pausedAutomations.count, 0)
        XCTAssertEqual(store.scheduledAutomations.count, 4)
    }

    @MainActor
    func testChat7SegmentTaskFaceIDGateAddContextAndModelCatalog() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()

        // UE07 7-Segment Task Checklist + Evidence Grouping + Face ID Gate
        XCTAssertEqual(store.activeTaskBoundary?.completedCount, 4)
        XCTAssertEqual(store.activeTaskBoundary?.totalCount, 7)
        XCTAssertEqual(store.activeTaskBoundary?.elapsedLabel, "2m 41s")
        XCTAssertEqual(store.activeTaskBoundary?.checklist.count, 3)

        let hasEvidenceGroup = store.displayItems.contains { item in
            if case .evidenceGroup(_, let grouped) = item {
                return grouped.count == 2
            }
            return false
        }
        XCTAssertTrue(hasEvidenceGroup)

        // UE08 Add Context (3 selected -> Add to message)
        XCTAssertEqual(store.selectedContextCount, 3)
        store.applySelectedContextToComposer()
        XCTAssertTrue(store.composerAttachments.contains(where: { $0.label == "Skill · go-testing" }))

        // UE09 Model & Persona Catalog
        XCTAssertEqual(CascadeModelConfig.catalog.map(\.displayName), [
            "Gemini 3.1 Pro",
            "Gemini 3.8 Flash",
            "Claude Opus 5.5",
            "Claude Sonnet 5.5"
        ])
        XCTAssertEqual(CascadeModelConfig.availableAgents, ["Default", "go-reviewer", "release-captain"])

        // Approve Step 5 vegeta load test with Face ID
        store.approveWaitingCommandWithFaceID(stepIndex: 5)
        XCTAssertEqual(store.lastDispatchedInteraction?.runCommand?.faceIdVerified, true)
        XCTAssertEqual(store.activeTaskBoundary?.completedCount, 5)
    }

    @MainActor
    func testStructuredQuestionsPlanCommentsAndTurnDiffReview() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()

        // UE10 Multi-Step Structured Question (1 Storage -> 2 Actions -> 3 Retention)
        store.configureForVerifyScene(.structuredQuestion)
        XCTAssertEqual(store.activeQuestionStepIndex, 1)
        XCTAssertEqual(store.currentQuestionStep?.shortTabTitle, "Actions")

        store.previousQuestionStep()
        XCTAssertEqual(store.activeQuestionStepIndex, 0)
        store.advanceQuestionStep()
        XCTAssertEqual(store.activeQuestionStepIndex, 1)
        store.advanceQuestionStep()
        XCTAssertEqual(store.activeQuestionStepIndex, 2)

        // UE11 Implementation Plan Review & Inline Comments
        store.configureForVerifyScene(.planReview)
        XCTAssertEqual(store.planChanges.count, 3)
        XCTAssertEqual(store.planComments.count, 2)
        store.addPlanComment(body: "Ensure NewTestClock registers t.Cleanup automatically.")
        XCTAssertEqual(store.planComments.count, 3)
        store.sendPlanCommentsToAgent()
        XCTAssertTrue(store.planComments.allSatisfy { $0.statusLabel == "Sent" })

        // UE12 Turn Diff Line-Level Review (+128 -14 across 4 files)
        store.configureForVerifyScene(.turnDiffReview)
        XCTAssertEqual(store.totalDiffAdditions, 128)
        XCTAssertEqual(store.totalDiffDeletions, 14)
        XCTAssertEqual(store.activeTurnDiffs.count, 4)
        XCTAssertEqual(store.currentDiffFile?.filePath, "middleware/ratelimit.go")

        store.submitDiffLineComment(sendImmediately: true)
        XCTAssertEqual(store.diffComments.count, 1)
        XCTAssertEqual(store.diffComments.first?.lineNumber, 29)
        XCTAssertEqual(store.diffComments.first?.sentToAgent, true)

        store.toggleDiffFileViewed()
        XCTAssertEqual(store.currentDiffFile?.isReviewed, true)

        store.acceptCurrentDiffFile()
        XCTAssertEqual(store.activeTurnDiffs.count, 3)

        store.revertCurrentDiffFile()
        XCTAssertEqual(store.activeTurnDiffs.count, 2)

        store.acceptAllTurnDiffs()
        XCTAssertTrue(store.activeTurnDiffs.isEmpty)

        // Verify all 13 ESDD scenes configure cleanly
        for scene in ESDDVerifySceneCase.allCases {
            let fresh = AntigravitySessionStore.makeESDDVerificationStore()
            fresh.configureForVerifyScene(scene)
            XCTAssertNotNil(fresh.activeHost)
        }
    }

    func testDesktopLiveTrajectoryStatusUnreadTimestampAndEmptyFilter() throws {
        // 1. Verify all Antigravity Desktop `CASCADE_RUN_STATUS_*` enum strings map accurately
        XCTAssertEqual(CortexStepStatus.from(jsonName: "CASCADE_RUN_STATUS_RUNNING"), .inProgress)
        XCTAssertEqual(CortexStepStatus.from(jsonName: "CASCADE_RUN_STATUS_WAITING_FOR_USER"), .waiting)
        XCTAssertEqual(CortexStepStatus.from(jsonName: "CASCADE_RUN_STATUS_DONE"), .done)
        XCTAssertEqual(CortexStepStatus.from(jsonName: "CASCADE_RUN_STATUS_IDLE"), .unspecified)
        XCTAssertEqual(CortexStepStatus.from(jsonName: "CASCADE_RUN_STATUS_CANCELLED"), .cancelled)

        let refNow = try XCTUnwrap(
            AntigravityRPCClient.parseProtoTimestamp(.string("2026-11-11T09:00:00.000000000Z"))
        )

        // 2. Unused 0-step blank New Chat placeholder -> filtered out (`nil`)
        let blankPlaceholder: JSONValue = .object([
            "stepCount": .int(0),
            "status": .string("CASCADE_RUN_STATUS_IDLE"),
            "workspaces": .array([
                .object(["workspaceFolderAbsoluteUri": .string("file:///Users/dev/slardar_app_ai")])
            ])
        ])
        XCTAssertNil(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "empty-0-step-tab",
                value: blankPlaceholder,
                now: refNow
            )
        )

        // 3. Completed turn with `CASCADE_RUN_STATUS_DONE` & nanosecond RFC3339 timestamp -> Unread = true
        let unreadDoneEntry: JSONValue = .object([
            "summary": .string("Slardar Tag Code Review"),
            "stepCount": .int(18),
            "status": .string("CASCADE_RUN_STATUS_DONE"),
            "lastModifiedTime": .string("2026-11-11T08:47:30.839201442Z"),
            "annotations": .object([
                "lastUserViewTime": .string("2026-11-11T08:30:00.100000Z")
            ]),
            "workspaces": .array([
                .object(["workspaceFolderAbsoluteUri": .string("file:///Users/dev/slardar_app_ai")])
            ])
        ])
        let decodedUnread = try XCTUnwrap(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "cid-slardar-code-review",
                value: unreadDoneEntry,
                now: refNow
            )
        )
        XCTAssertEqual(decodedUnread.title, "Slardar Tag Code Review")
        XCTAssertEqual(decodedUnread.projectSlug, "slardar_app_ai")
        XCTAssertEqual(decodedUnread.status, .done)
        XCTAssertTrue(decodedUnread.isUnread)
        XCTAssertEqual(decodedUnread.relativeTimeLabel, "12m")
        XCTAssertEqual(decodedUnread.statusSubtitle, "Done · New reply · 18 steps")

        // 4. Viewed idle session (`CASCADE_RUN_STATUS_IDLE`, `lastModifiedTime <= lastUserViewTime`) -> Unread = false
        let viewedIdleEntry: JSONValue = .object([
            "summary": .string("Slardar App AI 埋点梳理"),
            "stepCount": .int(11),
            "status": .string("CASCADE_RUN_STATUS_IDLE"),
            "lastModifiedTime": .string("2026-11-11T06:55:00Z"),
            "annotations": .object([
                "lastUserViewTime": .string("2026-11-11T07:05:00Z")
            ]),
            "workspaces": .array([
                .object(["workspaceFolderAbsoluteUri": .string("file:///Users/dev/slardar_app_ai")])
            ])
        ])
        let decodedIdle = try XCTUnwrap(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "cid-slardar-tracking",
                value: viewedIdleEntry,
                now: refNow
            )
        )
        XCTAssertEqual(decodedIdle.status, .unspecified)
        XCTAssertFalse(decodedIdle.isUnread)
        XCTAssertEqual(decodedIdle.relativeTimeLabel, "2h")
        XCTAssertEqual(decodedIdle.statusSubtitle, "Idle · 11 steps")

        // 5. Synthetic probe session (`iOS Connect-RPC Handshake`) -> filtered out (`nil`)
        let syntheticProbeEntry: JSONValue = .object([
            "summary": .string("Reply in one short sentence confirming iOS Connect-RPC handshake."),
            "stepCount": .int(1),
            "status": .string("CASCADE_RUN_STATUS_DONE"),
            "workspaces": .array([
                .object(["workspaceFolderAbsoluteUri": .string("file:///Users/dev/iOSAntigravity")])
            ])
        ])
        XCTAssertNil(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "cid-probe-handshake",
                value: syntheticProbeEntry,
                now: refNow
            )
        )

        // 6. Cloud project (`cloud://venciallee/iOSAntigravity`) preserves `owner/repo` projectSlug & running status
        let cloudRunningEntry: JSONValue = .object([
            "summary": .string("Antigravity iOS App Architecture Research"),
            "stepCount": .int(7),
            "status": .string("CASCADE_RUN_STATUS_RUNNING"),
            "lastModifiedTime": .string("2026-11-11T08:59:55Z"),
            "workspaces": .array([
                .object(["workspaceFolderAbsoluteUri": .string("cloud://venciallee/iOSAntigravity")])
            ])
        ])
        let decodedCloudRunning = try XCTUnwrap(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "cid-arch-research",
                value: cloudRunningEntry,
                now: refNow
            )
        )
        XCTAssertEqual(decodedCloudRunning.projectSlug, "venciallee/iOSAntigravity")
        XCTAssertEqual(decodedCloudRunning.status, .inProgress)
    }

    @MainActor
    func testDesktopStepDecodingAndLiveRouteSelection() throws {
        // 1. UserInput where `userResponse` is empty string "" and `items` carries prompt + file URI
        let rawUserStep: JSONValue = .object([
            "stepIndex": .int(0),
            "type": .string("CORTEX_STEP_TYPE_USER_INPUT"),
            "status": .string("CORTEX_STEP_STATUS_DONE"),
            "userInput": .object([
                "userResponse": .string(""),
                "items": .array([
                    .object(["text": .string("请帮我梳理 Slardar Tag 核心逻辑")]),
                    .object([
                        "item": .object([
                            "file": .object([
                                "absoluteUri": .string("file:///Users/dev/slardar_app_ai/internal/tag/manager.go")
                            ])
                        ])
                    ])
                ])
            ])
        ])
        let userStep = try XCTUnwrap(
            AntigravityRPCClient.decodeJSONStep(rawUserStep, cascadeId: "cid-1", fallbackIndex: 0)
        )
        XCTAssertEqual(userStep.type, .userInput)
        XCTAssertEqual(userStep.userInput, "请帮我梳理 Slardar Tag 核心逻辑")
        XCTAssertEqual(userStep.attachedMentions, ["@manager.go"])
        XCTAssertTrue(userStep.hasRenderableChatContent)

        // 2. Housekeeping `CORTEX_STEP_TYPE_CHECKPOINT` should be excluded from displayItems
        let rawCheckpoint: JSONValue = .object([
            "stepIndex": .int(1),
            "type": .string("CORTEX_STEP_TYPE_CHECKPOINT"),
            "status": .string("CORTEX_STEP_STATUS_DONE")
        ])
        let checkpointStep = try XCTUnwrap(
            AntigravityRPCClient.decodeJSONStep(rawCheckpoint, cascadeId: "cid-1", fallbackIndex: 1)
        )
        XCTAssertFalse(checkpointStep.hasRenderableChatContent)

        // 3. PlannerResponse where `modifiedResponse` is "" must NOT shadow `response`
        let rawPlanner: JSONValue = .object([
            "stepIndex": .int(2),
            "type": .string("CORTEX_STEP_TYPE_PLANNER_RESPONSE"),
            "status": .string("CORTEX_STEP_STATUS_DONE"),
            "plannerResponse": .object([
                "modifiedResponse": .string(""),
                "response": .string("已完成梳理：Tag 校验链路位于 RegisterTagValidator。"),
                "thinking": .string("Inspected manager.go and validator registry."),
                "thinkingDuration": .string("6.4s")
            ])
        ])
        let plannerStep = try XCTUnwrap(
            AntigravityRPCClient.decodeJSONStep(rawPlanner, cascadeId: "cid-1", fallbackIndex: 2)
        )
        XCTAssertEqual(plannerStep.type, .plannerResponse)
        XCTAssertEqual(plannerStep.plannerResponse?.response, "已完成梳理：Tag 校验链路位于 RegisterTagValidator。")
        XCTAssertEqual(plannerStep.plannerResponse?.thinkingDurationSeconds ?? 0, 6.4, accuracy: 0.01)

        // 4. `CORTEX_STEP_TYPE_NOTIFY_USER` renders as assistant message
        let rawNotify: JSONValue = .object([
            "stepIndex": .int(3),
            "type": .string("CORTEX_STEP_TYPE_NOTIFY_USER"),
            "status": .string("CORTEX_STEP_STATUS_DONE"),
            "notifyUser": .object([
                "notificationContent": .string("Implementation plan is ready for review.")
            ])
        ])
        let notifyStep = try XCTUnwrap(
            AntigravityRPCClient.decodeJSONStep(rawNotify, cascadeId: "cid-1", fallbackIndex: 3)
        )
        XCTAssertEqual(notifyStep.type, .notifyUser)
        XCTAssertTrue(notifyStep.hasRenderableChatContent)

        let items = CascadeDisplayItem.buildDisplayItems(from: [userStep, checkpointStep, plannerStep, notifyStep])
        XCTAssertEqual(items.count, 3, "Housekeeping checkpoint step must be filtered out of displayItems")

        // 5. Selecting a cascade updates activeRoute to .cascadeChat(id) and clears unread badge
        let store = AntigravitySessionStore.makeESDDVerificationStore()
        store.selectCascade("cas-upgrade-go")
        XCTAssertEqual(store.activeRoute, .cascadeChat("cas-upgrade-go"))
        XCTAssertEqual(store.summaries.first(where: { $0.cascadeId == "cas-upgrade-go" })?.isUnread, false)
    }

    @MainActor
    func testCloudVMWorkspaceDetectionAndProjectReconciliation() throws {
        let refNow = try XCTUnwrap(
            AntigravityRPCClient.parseProtoTimestamp(.string("2026-11-11T09:00:00Z"))
        )

        // 1. Jetski Cloud VM trajectory includes container home `/home/antigravity` + repo `/home/antigravity/venciallee/iOSAntigravity`
        let jetskiCloudEntry: JSONValue = .object([
            "summary": .string("Fix offline host badge and Cloud workspace detection"),
            "stepCount": .int(12),
            "status": .string("CASCADE_RUN_STATUS_RUNNING"),
            "lastModifiedTime": .string("2026-11-11T08:59:30Z"),
            "workspaces": .array([
                .object(["workspaceFolderAbsoluteUri": .string("file:///home/antigravity")]),
                .object([
                    "workspaceFolderAbsoluteUri": .string("file:///home/antigravity/venciallee/iOSAntigravity"),
                    "gitBranch": .string("main")
                ])
            ])
        ])
        let cloudSummary = try XCTUnwrap(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "v1/default/jetski_remote_agents_3p/02268caa-6eb1-426b-a5c3-8629460e0111",
                value: jetskiCloudEntry,
                now: refNow
            )
        )
        XCTAssertTrue(cloudSummary.isCloud)
        XCTAssertEqual(cloudSummary.projectSlug, "iOSAntigravity")
        XCTAssertEqual(cloudSummary.workspaceUri, "cloud://venciallee/iOSAntigravity")

        // 2. Remote-SSH and GitHub URLs also classify as Cloud
        XCTAssertTrue(AntigravityCloudDetector.isCloudWorkspaceURI("vscode-remote://ssh-remote+devbox/home/dev/iOSAntigravity"))
        XCTAssertEqual(
            AntigravityCloudDetector.normalizeWorkspaceURI("https://github.com/venciallee/iOSAntigravity.git", isCloud: true),
            "cloud://venciallee/iOSAntigravity"
        )

        // 3. Reconcile projects when a 0-chat local workspace has the same repo name as an active Cloud session
        let localMacEntry: JSONValue = .object([
            "summary": .string("Slardar Tag Code Review"),
            "stepCount": .int(5),
            "status": .string("CASCADE_RUN_STATUS_DONE"),
            "lastModifiedTime": .string("2026-11-11T08:50:00Z"),
            "workspaces": .array([
                .object([
                    "workspaceFolderAbsoluteUri": .string("file:///Users/dev/slardar_app_ai"),
                    "gitBranch": .string("main")
                ])
            ])
        ])
        let localSummary = try XCTUnwrap(
            AntigravityRPCClient.decodeTrajectorySummaryEntry(
                cascadeId: "cid-local-slardar",
                value: localMacEntry,
                now: refNow
            )
        )
        XCTAssertFalse(localSummary.isCloud)

        var summaries = [cloudSummary, localSummary]
        let workspaces = [
            WorkspaceInfo(workspaceUri: "file:///Users/dev/iOSAntigravity", displayName: "iOSAntigravity", activeBranch: "main", isCloud: false),
            WorkspaceInfo(workspaceUri: "file:///Users/dev/slardar_app_ai", displayName: "slardar_app_ai", activeBranch: "main", isCloud: false)
        ]
        let reconciled = AntigravitySessionStore.reconcileLiveProjects(
            workspaces: workspaces,
            summaries: &summaries,
            existingProjects: [],
            hostName: "LT74XT6L0M"
        )
        XCTAssertEqual(reconciled.count, 2)

        let iosProj = try XCTUnwrap(reconciled.first(where: { $0.name == "iOSAntigravity" }))
        XCTAssertEqual(iosProj.runtime, .cloud)
        XCTAssertEqual(iosProj.homeSubtitle(isHostOnline: true), "Cloud · venciallee/iOSAntigravity · main")
        XCTAssertEqual(iosProj.homeSubtitle(isHostOnline: false), "Cloud · venciallee/iOSAntigravity · main")

        let slardarProj = try XCTUnwrap(reconciled.first(where: { $0.name == "slardar_app_ai" }))
        XCTAssertEqual(slardarProj.runtime, .macBookPro)
        XCTAssertEqual(slardarProj.homeSubtitle(isHostOnline: true), "Local · LT74XT6L0M · main")
        XCTAssertEqual(slardarProj.homeSubtitle(isHostOnline: false), "Offline · LT74XT6L0M · main")
    }

    @MainActor
    func testOfflineErrorClassificationAndStoreOfflineStateTransition() {
        XCTAssertTrue(AntigravitySessionStore.isBackendOfflineError(URLError(.cannotConnectToHost)))
        XCTAssertTrue(AntigravitySessionStore.isBackendOfflineError(URLError(.timedOut)))
        XCTAssertTrue(AntigravitySessionStore.isBackendOfflineError(AntigravityRPCError.httpError(statusCode: 503, body: "Antigravity Desktop is offline")))
        XCTAssertTrue(AntigravitySessionStore.isBackendOfflineError(AntigravityRPCError.unauthorized("CSRF mismatch")))
        XCTAssertFalse(
            AntigravitySessionStore.isBackendOfflineError(AntigravityRPCError.httpError(statusCode: 404, body: "unimplemented")),
            "Optional unimplemented RPCs (HTTP 404) on raw language_server must not mark the host offline"
        )

        let store = AntigravitySessionStore.makeESDDVerificationStore()
        store.hasPairedBackend = true
        store.isLiveBackendConnected = true
        store.activeHost = RemoteHostInstance(
            instanceId: "direct-mac",
            hostname: "LT74XT6L0M",
            channel: .directHost,
            endpointURL: URL(string: "http://192.168.1.20:8787")!,
            isOnline: true
        )
        store.hosts = [store.activeHost]
        store.projects = [
            ProjectWorkspace(
                id: "iOSAntigravity",
                name: "iOSAntigravity",
                pathDisplay: "cloud://venciallee/iOSAntigravity",
                workspaceUri: "cloud://venciallee/iOSAntigravity",
                runtime: .cloud,
                hostName: "Cloud",
                activeBranch: "main"
            )
        ]

        store.markBackendOffline(error: AntigravityRPCError.httpError(statusCode: 503, body: "Antigravity Desktop is offline"))
        XCTAssertTrue(store.hasPairedBackend, "Paired host flag must remain true while temporarily offline")
        XCTAssertFalse(store.isLiveBackendConnected)
        XCTAssertFalse(store.activeHost.isOnline)
        XCTAssertEqual(store.hosts.first?.isOnline, false)
        XCTAssertEqual(store.connectionStatusText, "Offline · LT74XT6L0M")
        XCTAssertEqual(store.projects.map(\.id), ["iOSAntigravity"])
    }

    func testOfficialRemoteControlQRAndCloudRelayJSPBCodec() throws {
        // 1. Official QR URL parsing (`/r/<slug>`, `/u/<authuser>/r/<uuid>`, `?p=c%2F<cid>`, and bare slug)
        let parsedQR = try XCTUnwrap(
            RemoteHostInstance.parseRemoteControlTarget(
                "https://antigravity.google.com/u/2/r/lt74xt6l0m-golden-star?p=c%2Fcas-rate-limiter"
            )
        )
        XCTAssertEqual(parsedQR.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(parsedQR.authUser, "2")
        XCTAssertEqual(parsedQR.conversationId, "cas-rate-limiter")
        XCTAssertEqual(parsedQR.canonicalRelayURLString, "https://antigravity.google.com/r/lt74xt6l0m-golden-star")
        XCTAssertFalse(parsedQR.requiresRedirectResolution)

        let bareTarget = try XCTUnwrap(RemoteHostInstance.parseRemoteControlTarget("0f5819ac-9308-40d8-a308-98b55122c533-v2"))
        XCTAssertEqual(bareTarget.instanceId, "0f5819ac-9308-40d8-a308-98b55122c533-v2")

        // 1b. Google AccountChooser / ServiceLogin wrapped QR URLs
        let accountChooserWrapped =
            "https://accounts.google.com/AccountChooser?Email=dev%40gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fu%2F1%2Fr%2Flt74xt6l0m-golden-star%3Fp%3Dc%252Fcas-wrapped"
        let parsedWrapped = try XCTUnwrap(RemoteHostInstance.parseRemoteControlTarget(accountChooserWrapped))
        XCTAssertEqual(parsedWrapped.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(parsedWrapped.authUser, "1")
        XCTAssertEqual(parsedWrapped.conversationId, "cas-wrapped")
        XCTAssertEqual(parsedWrapped.relayOrigin, "https://antigravity.google.com")
        XCTAssertEqual(parsedWrapped.originalURLString, accountChooserWrapped)

        // 1c. Alternate Antigravity domains, query-param / hash-route formats, scheme-less links, custom schemes, JSON & CLI prose
        let corpTarget = try XCTUnwrap(
            RemoteHostInstance.parseRemoteControlTarget("https://antigravity.corp.google.com/remote?instance=lt74xt6l0m-golden-star")
        )
        XCTAssertEqual(corpTarget.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(corpTarget.relayOrigin, "https://antigravity.corp.google.com")

        let schemelessTarget = try XCTUnwrap(
            RemoteHostInstance.parseRemoteControlTarget("antigravity.google.com/r/lt74xt6l0m-golden-star")
        )
        XCTAssertEqual(schemelessTarget.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(schemelessTarget.relayOrigin, "https://antigravity.google.com")

        let customSchemeTarget = try XCTUnwrap(
            RemoteHostInstance.parseRemoteControlTarget("agy://r/lt74xt6l0m-golden-star?p=c%2Fcas-mobile")
        )
        XCTAssertEqual(customSchemeTarget.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(customSchemeTarget.conversationId, "cas-mobile")
        XCTAssertEqual(customSchemeTarget.relayOrigin, "https://antigravity.google.com")

        let jsonTarget = try XCTUnwrap(
            RemoteHostInstance.parseRemoteControlTarget(#"{"instanceId":"lt74xt6l0m-golden-star","authUser":"0"}"#)
        )
        XCTAssertEqual(jsonTarget.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(jsonTarget.authUser, "0")

        let proseTarget = try XCTUnwrap(
            RemoteHostInstance.parseRemoteControlTarget(
                "Open https://antigravity.google.com/r/lt74xt6l0m-golden-star on another device."
            )
        )
        XCTAssertEqual(proseTarget.instanceId, "lt74xt6l0m-golden-star")

        // 1d. Official Google shortlinks pin `relayOrigin` to `https://antigravity.google.com` & mark redirect resolution
        let shortlinkTarget = try XCTUnwrap(RemoteHostInstance.parseRemoteControlTarget("https://g.co/r/abc123xyz"))
        XCTAssertEqual(shortlinkTarget.instanceId, "")
        XCTAssertEqual(shortlinkTarget.relayOrigin, "https://antigravity.google.com")
        XCTAssertTrue(shortlinkTarget.requiresRedirectResolution)
        XCTAssertEqual(
            RemoteHostInstance.resolveEffectiveRelayTarget(
                scannedInput: "https://g.co/r/abc123xyz",
                webViewFinalURL: "https://antigravity.google.com/u/1/r/lt74xt6l0m-golden-star"
            ),
            "https://antigravity.google.com/u/1/r/lt74xt6l0m-golden-star"
        )

        // 1e. Local mock loopback `/r/<id>` vs plain LAN endpoint vs arbitrary third-party `/r/` URLs
        let mockLoopback = try XCTUnwrap(RemoteHostInstance.parseRemoteControlTarget("http://127.0.0.1:18080/r/mock-inst-1"))
        XCTAssertEqual(mockLoopback.instanceId, "mock-inst-1")
        XCTAssertEqual(mockLoopback.relayOrigin, "http://127.0.0.1:18080")
        XCTAssertNil(RemoteHostInstance.parseRemoteControlTarget("http://127.0.0.1:18080"))
        XCTAssertNil(RemoteHostInstance.parseRemoteControlTarget("https://www.reddit.com/r/swift"))
        XCTAssertNil(RemoteHostInstance.parseRemoteControlTarget("antigravity://verify/agents-home"))
        XCTAssertTrue(RemoteHostInstance.isDirectLANPairingURI("antigravity://pair?url=https://192.168.1.20:8787&csrf=tok"))
        XCTAssertNil(RemoteHostInstance.parseRemoteControlTarget("antigravity://pair?url=https://192.168.1.20:8787&csrf=tok"))

        // 2. SAPISIDHASH SHA-1 vector & pure-Swift parity
        let mockCookie = "SAPISID=test_sapisid_val_123; __Secure-1PAPISID=test_sapisid_val_123; SID=test_sid_val"
        XCTAssertTrue(SAPISIDHashGenerator.hasRequiredGoogleAuthCookies(mockCookie))
        let authHeader = try XCTUnwrap(
            SAPISIDHashGenerator.computeAuthorizationHeader(
                cookieHeader: mockCookie,
                origin: "https://antigravity.google.com",
                timestamp: 1794406100
            )
        )
        let expectedDigest = SAPISIDHashGenerator.pureSwiftSHA1Hex(
            Array("1794406100 test_sapisid_val_123 https://antigravity.google.com".utf8)
        )
        XCTAssertEqual(
            SAPISIDHashGenerator.sha1Hex("1794406100 test_sapisid_val_123 https://antigravity.google.com"),
            expectedDigest
        )
        XCTAssertTrue(authHeader.contains("SAPISIDHASH 1794406100_\(expectedDigest)"))
        XCTAssertTrue(authHeader.contains("SAPISID1PHASH 1794406100_\(expectedDigest)"))

        // 3. ListInstances JSPB decoding (with XSSI `)]}'\n` prefix)
        let rawListInstances = Data(
            ")]}'\n[[[\"0f5819ac-9308-40d8-a308-98b55122c533-v2\",[\"lt74xt6l0m-golden-star\",\"2.32.0\",1],1,[1794406100,0]]],5]".utf8
        )
        let instances = try CloudRelayJSPBCodec.decodeListInstancesResponse(rawListInstances)
        XCTAssertEqual(instances.count, 1)
        XCTAssertEqual(instances[0].uuid, "0f5819ac-9308-40d8-a308-98b55122c533-v2")
        XCTAssertEqual(instances[0].name, "lt74xt6l0m-golden-star")
        XCTAssertEqual(instances[0].status, .connected)
        XCTAssertTrue(instances[0].matches(identifier: "lt74xt6l0m-golden-star"))
        XCTAssertTrue(instances[0].matches(identifier: "0f5819ac-9308-40d8-a308-98b55122c533-v2"))

        // 4. ProxyCommand request & response JSPB round-trip (including outer Base64 safety wrapper)
        let encodedProxyReq = try CloudRelayJSPBCodec.encodeProxyCommandRequest(
            targetInstanceUuid: "0f5819ac-9308-40d8-a308-98b55122c533-v2",
            rpcPath: "/exa.language_server_pb.LanguageServerService/GetWorkspaceInfos",
            payload: Data("{}".utf8),
            contentType: "application/json"
        )
        let reqArray = try XCTUnwrap(try JSONDecoder().decode(JSONValue.self, from: encodedProxyReq).arrayValue)
        XCTAssertEqual(reqArray[0].stringValue, "0f5819ac-9308-40d8-a308-98b55122c533-v2")
        XCTAssertEqual(reqArray[2].stringValue, "e30=")

        let sampleProxyResp = Data("[\"e30=\",[[\"accept-encoding\",\"gzip\"],[\"content-type\",\"application/json\"]]]".utf8)
        let decodedResp = try CloudRelayJSPBCodec.decodeProxyCommandResponse(sampleProxyResp)
        XCTAssertEqual(String(data: decodedResp.payload, encoding: .utf8), "{}")
        XCTAssertEqual(decodedResp.headers["content-type"], "application/json")

        let xssiOuterWrapped = Data((")]}'\n" + String(data: sampleProxyResp, encoding: .utf8)!).utf8).base64EncodedData()
        let decodedWrapped = try CloudRelayJSPBCodec.decodeProxyCommandResponse(
            xssiOuterWrapped,
            responseHeaders: ["Content-Transfer-Encoding": "base64"]
        )
        XCTAssertEqual(String(data: decodedWrapped.payload, encoding: .utf8), "{}")
    }

    @MainActor
    func testMakeLiveStoreStartsEmptyWithZeroMockFixtures() {
        let liveStore = AntigravitySessionStore.makeLiveStore()
        XCTAssertFalse(liveStore.isVerificationMode)
        XCTAssertFalse(liveStore.hasPairedBackend)
        XCTAssertFalse(liveStore.isLiveBackendConnected)
        XCTAssertTrue(liveStore.projects.isEmpty)
        XCTAssertTrue(liveStore.workspaces.isEmpty)
        XCTAssertTrue(liveStore.summaries.isEmpty)
        XCTAssertTrue(liveStore.automations.isEmpty)
        XCTAssertTrue(liveStore.contextCandidates.isEmpty)
        XCTAssertTrue(liveStore.availableGitHubRepos.isEmpty)
        XCTAssertTrue(liveStore.composerAttachments.isEmpty)
        XCTAssertEqual(liveStore.composerDraftText, "")
        XCTAssertEqual(liveStore.activeCascadeId, "")
        XCTAssertEqual(liveStore.selectedProjectId, "")

        XCTAssertEqual(liveStore.availableModels, CascadeModelConfig.liveDefaultCatalog)
        XCTAssertEqual(liveStore.availableAgents, ["Default"])

        let verifyStore = AntigravitySessionStore.makeESDDVerificationStore()
        XCTAssertTrue(verifyStore.isVerificationMode)
        XCTAssertFalse(verifyStore.summaries.isEmpty)
        XCTAssertEqual(verifyStore.availableModels, CascadeModelConfig.catalog)
    }

    func testBinaryProtobufGetStepsRequestAndRealStepDecoding() throws {
        // 1. Verify field 3 (`verbosity`) is NEVER populated with `endIndex`
        let req = ProtobufStepCodec.encodeGetStepsRequest(
            cascadeId: "cas-1",
            startIndex: 120,
            endIndex: 999
        )
        // 0x0A, 0x05, "cas-1" (7 bytes) + 0x10, 0x78 (2 bytes) = 9 bytes total
        XCTAssertEqual(Array(req), [0x0A, 0x05, 0x63, 0x61, 0x73, 0x2D, 0x31, 0x10, 0x78])

        // Helper functions for assembling deterministic binary Protobuf wire bytes
        func pbVarintField(_ field: Int, _ val: UInt64) -> Data {
            var d = Data(ProtobufStepCodec.encodeVarint(UInt64((field << 3) | 0)))
            d.append(contentsOf: ProtobufStepCodec.encodeVarint(val))
            return d
        }
        func pbBytesField(_ field: Int, _ payload: Data) -> Data {
            var d = Data(ProtobufStepCodec.encodeVarint(UInt64((field << 3) | 2)))
            d.append(contentsOf: ProtobufStepCodec.encodeVarint(UInt64(payload.count)))
            d.append(payload)
            return d
        }
        func pbStringField(_ field: Int, _ text: String) -> Data {
            pbBytesField(field, Data(text.utf8))
        }

        // Step 0: USER_INPUT (type=14, status=3, user_input=19 with user_response + user_config Planning + M37)
        let conversationalMsg = pbVarintField(14, 1) // agentic_mode = true -> Planning
        let requestedModelMsg = pbVarintField(1, 1037) // model = 1037 -> MODEL_PLACEHOLDER_M37
        var plannerCfgMsg = Data()
        plannerCfgMsg.append(pbBytesField(2, conversationalMsg))
        plannerCfgMsg.append(pbBytesField(15, requestedModelMsg))
        let cascadeCfgMsg = pbBytesField(1, plannerCfgMsg)

        var userInputMsg = Data()
        userInputMsg.append(pbStringField(2, "Check Antigravity Cloud sync"))
        userInputMsg.append(pbBytesField(12, cascadeCfgMsg))

        var step0 = Data()
        step0.append(pbVarintField(1, 14))
        step0.append(pbVarintField(4, 3))
        step0.append(pbBytesField(19, userInputMsg))

        // Step 1: PLANNER_RESPONSE (type=15, status=3, planner_response=20)
        var plannerRespMsg = Data()
        plannerRespMsg.append(pbStringField(1, "Cloud sync verified."))
        plannerRespMsg.append(pbStringField(3, "Inspected JetboxSubscribeToSummaries."))
        var step1 = Data()
        step1.append(pbVarintField(1, 15))
        step1.append(pbVarintField(4, 3))
        step1.append(pbBytesField(20, plannerRespMsg))

        // Step 2: NOTIFY_USER (type=82, status=3, notify_user=94)
        let notifyMsg = pbStringField(2, "All checks green.")
        var step2 = Data()
        step2.append(pbVarintField(1, 82))
        step2.append(pbVarintField(4, 3))
        step2.append(pbBytesField(94, notifyMsg))

        var responseBytes = Data()
        responseBytes.append(pbBytesField(1, step0))
        responseBytes.append(pbBytesField(1, step1))
        responseBytes.append(pbBytesField(1, step2))

        let decoded = ProtobufStepCodec.decodeStepsResponse(responseBytes, cascadeId: "cid-proto-test")
        XCTAssertEqual(decoded.count, 3)

        XCTAssertEqual(decoded[0].type, .userInput)
        XCTAssertEqual(decoded[0].status, .done)
        XCTAssertEqual(decoded[0].userInput, "Check Antigravity Cloud sync")
        XCTAssertEqual(decoded[0].recordedExecutionMode, .planning)
        XCTAssertEqual(decoded[0].recordedModelId, "MODEL_PLACEHOLDER_M37")

        XCTAssertEqual(decoded[1].type, .plannerResponse)
        XCTAssertEqual(decoded[1].plannerResponse?.response, "Cloud sync verified.")
        XCTAssertEqual(decoded[1].plannerResponse?.thinking, "Inspected JetboxSubscribeToSummaries.")

        XCTAssertEqual(decoded[2].type, .notifyUser)
        XCTAssertEqual(decoded[2].plannerResponse?.response, "All checks green.")
    }

    func testCloudRelayUnbufferedJSPBStreamParserAndJetboxRemoteAicodeDecode() throws {
        // 1. Unbuffered StreamProxyCommand JSPB stream without trailing newline emits inner Connect frames immediately
        let connectFrame1 = ConnectEnvelope.encode(
            payload: Data(#"{"updates":{"cid-cloud-1":{"summary":"Cloud Agent Task","stepCount":4,"status":"CASCADE_RUN_STATUS_RUNNING","projectId":"proj-uuid-1"}}}"#.utf8)
        )
        let connectFrame2 = ConnectEnvelope.encode(
            payload: Data(#"{"deletes":["cid-old"]}"#.utf8)
        )
        let b64Frame1 = connectFrame1.base64EncodedString()
        let b64Frame2 = connectFrame2.base64EncodedString()

        var jspbParser = CloudRelayJSPBStreamParser()
        var connectParser = ConnectStreamParser()

        // First network chunk has XSSI prefix and top-level `[...]` closed without trailing newline
        var standaloneParser = CloudRelayJSPBStreamParser()
        let unbufferedChunk1 = Data(")]}'\n[[\"\(b64Frame1)\",[[\"content-type\",\"application/connect+json\"]]]]".utf8)
        let emitted1 = standaloneParser.feed(unbufferedChunk1)
        XCTAssertEqual(emitted1.count, 1)

        let frames1 = connectParser.feed(emitted1[0])
        XCTAssertEqual(frames1.count, 1)
        let event1 = try JSONDecoder().decode([String: JSONValue].self, from: frames1[0].payload)

        let cloudProj = ProjectWorkspace(
            id: "iOSAntigravity",
            name: "iOSAntigravity",
            pathDisplay: "cloud://venciallee/iOSAntigravity",
            workspaceUri: "cloud://venciallee/iOSAntigravity",
            runtime: .cloud,
            hostName: "Cloud",
            activeBranch: "main",
            cloudProjectId: "proj-uuid-1"
        )
        let decodedBatch = AntigravityRPCClient.decodeJetboxSummariesEvent(
            event1,
            forceCloud: true,
            originInstanceUuid: "inst-uuid-1",
            originHostName: "Antigravity",
            cloudProjectsById: ["proj-uuid-1": cloudProj]
        )
        XCTAssertEqual(decodedBatch.upserts.count, 1)
        let summary = decodedBatch.upserts[0]
        XCTAssertTrue(summary.isCloud)
        XCTAssertEqual(summary.originHostName, "Antigravity")
        XCTAssertEqual(summary.projectSlug, "iOSAntigravity")
        XCTAssertEqual(summary.workspaceUri, "cloud://venciallee/iOSAntigravity")
        XCTAssertEqual(summary.cloudProjectId, "proj-uuid-1")

        // Also feed split multi-part stream across arbitrary byte boundaries
        let combinedStream = Data("[[\"\(b64Frame1)\",null]][[\"\(b64Frame2)\",null]]".utf8)
        let splitIdx = 19
        let partA = jspbParser.feed(Data(combinedStream.prefix(splitIdx)))
        XCTAssertTrue(partA.isEmpty)
        let partB = jspbParser.feed(Data(combinedStream.dropFirst(splitIdx)))
        XCTAssertEqual(partB.count, 2)
    }

    @MainActor
    func testPairedBackendNeverInjectsMockReplyAndSyncsRecordedModeAndModel() throws {
        let store = AntigravitySessionStore.makeLiveStore()
        store.hasPairedBackend = true
        store.isLiveBackendConnected = false // Simulate transient Cloud Relay offline state
        store.activeCascadeId = "cid-live-session"
        store.composerDraftText = "修复云端会话同步"
        store.sendCurrentDraft()

        let steps = try XCTUnwrap(store.stepsByCascadeId["cid-live-session"])
        XCTAssertEqual(steps.count, 1, "Paired backend must never inject fake ESDD mock plannerResponse steps")
        XCTAssertEqual(steps.first?.type, .userInput)
        XCTAssertEqual(steps.first?.userInput, "修复云端会话同步")

        // Verify JSON step decoding extracts `agenticMode: false` -> `.fast` and `MODEL_PLACEHOLDER_M18` -> `Gemini 3 Flash`
        let rawFastUserStep: JSONValue = .object([
            "stepIndex": .int(0),
            "type": .string("CORTEX_STEP_TYPE_USER_INPUT"),
            "status": .string("CORTEX_STEP_STATUS_DONE"),
            "userInput": .object([
                "userResponse": .string("Quick local tweak"),
                "userConfig": .object([
                    "plannerConfig": .object([
                        "conversational": .object([
                            "plannerMode": .string("CONVERSATIONAL_PLANNER_MODE_DEFAULT"),
                            "agenticMode": .bool(false)
                        ]),
                        "requestedModel": .object([
                            "model": .string("MODEL_PLACEHOLDER_M18")
                        ])
                    ])
                ])
            ])
        ])
        let decodedFastStep = try XCTUnwrap(
            AntigravityRPCClient.decodeJSONStep(rawFastUserStep, cascadeId: "cid-fast-chat", fallbackIndex: 0)
        )
        XCTAssertEqual(decodedFastStep.recordedExecutionMode, .fast)
        XCTAssertEqual(decodedFastStep.recordedModelId, "MODEL_PLACEHOLDER_M18")

        store.stepsByCascadeId["cid-fast-chat"] = [decodedFastStep]
        store.selectCascade("cid-fast-chat")
        XCTAssertEqual(store.selectedModelConfig.mode, .fast)
        XCTAssertEqual(store.selectedModelConfig.modelId, "MODEL_PLACEHOLDER_M18")
        XCTAssertEqual(store.selectedModelConfig.displayName, "Gemini 3 Flash")
    }

    func testGitHubFlavoredMarkdownParserBlocksAndInlines() throws {
        let sample = """
        ### 1. 修复 `Markdown` 渲染

        1. **云端对话**：支持 `BACKEND_TYPE_REMOTE_AICODE` 与 mock_language_server.py
           - **根因**：查看 [`StepCellViews.swift`](file:///Users/dev/StepCellViews.swift#L560-L567)
             - [x] 已完成 GFM AST 解析

        > [!WARNING]
        > 拉取后直接编译即可，无需运行 `xcodegen`

        | 模块 | 语法示例 | 状态 |
        | :--- | :---: | ---: |
        | 表格 | `a | b` | ~~旧版~~ **通过** |

        ```swift
        let blocks = AntigravityMarkdownParser.parse(prose)
        ```
        """

        let blocks = AntigravityMarkdownParser.parse(sample)
        XCTAssertEqual(blocks.count, 7)

        // 1. Heading H3 with inline code
        guard case .heading(_, let level, let headingInlines) = blocks[0] else {
            return XCTFail("Expected heading at block 0, got \(blocks[0])")
        }
        XCTAssertEqual(level, 3)
        XCTAssertEqual(headingInlines, [.text("1. 修复 "), .code("Markdown"), .text(" 渲染")])

        // 2. Top-level ordered list item preserving intraword underscores in `mock_language_server.py`
        guard case .listItem(_, let indent0, let marker0, let item0Inlines) = blocks[1] else {
            return XCTFail("Expected listItem at block 1")
        }
        XCTAssertEqual(indent0, 0)
        XCTAssertEqual(marker0, .ordered(1))
        XCTAssertTrue(item0Inlines.map(\.plainText).joined().contains("mock_language_server.py"))

        // 3. Nested bullet item (indent 1) with `[`StepCellViews.swift`](file:///...)`
        guard case .listItem(_, let indent1, let marker1, let item1Inlines) = blocks[2] else {
            return XCTFail("Expected nested bullet listItem at block 2")
        }
        XCTAssertEqual(indent1, 1)
        XCTAssertEqual(marker1, .bullet)
        let expectedLink = MarkdownInline.link(
            label: [.code("StepCellViews.swift")],
            destination: "file:///Users/dev/StepCellViews.swift#L560-L567"
        )
        XCTAssertTrue(item1Inlines.contains(expectedLink), "Expected nested code link in \(item1Inlines)")

        // 4. Nested task item (indent 2, checked)
        guard case .listItem(_, let indent2, let marker2, _) = blocks[3] else {
            return XCTFail("Expected nested task listItem at block 3")
        }
        XCTAssertEqual(indent2, 2)
        XCTAssertEqual(marker2, .task(checked: true))

        // 5. GitHub `[!WARNING]` alert blockquote
        guard case .blockquote(_, let alertKind, let alertBlocks) = blocks[4] else {
            return XCTFail("Expected blockquote at block 4")
        }
        XCTAssertEqual(alertKind, .warning)
        XCTAssertEqual(alertBlocks.count, 1)

        // 6. GFM Table ignoring `|` inside inline code `` `a | b` ``
        guard case .table(_, let headers, let alignments, let rows) = blocks[5] else {
            return XCTFail("Expected table at block 5")
        }
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(alignments, [.leading, .center, .trailing])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][1], [.code("a | b")])
        XCTAssertEqual(rows[0][2], [.strikethrough([.text("旧版")]), .text(" "), .strong([.text("通过")])])

        // 7. Fenced Swift code block
        guard case .codeBlock(_, let lang, let code) = blocks[6] else {
            return XCTFail("Expected codeBlock at block 6")
        }
        XCTAssertEqual(lang, "swift")
        XCTAssertEqual(code, "let blocks = AntigravityMarkdownParser.parse(prose)")

        // 8. Streaming unclosed code fence while Agent is mid-turn
        let streamingMarkdown = "正在执行：\n```bash\ngit pull origin main"
        let streamingBlocks = AntigravityMarkdownParser.parse(streamingMarkdown)
        XCTAssertEqual(streamingBlocks.count, 2)
        if case .codeBlock(_, let streamLang, let streamCode) = streamingBlocks[1] {
            XCTAssertEqual(streamLang, "bash")
            XCTAssertEqual(streamCode, "git pull origin main")
        } else {
            XCTFail("Expected streaming unclosed codeBlock")
        }
    }
}


