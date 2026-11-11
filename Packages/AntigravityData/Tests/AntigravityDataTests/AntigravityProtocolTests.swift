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
            "lastModifiedTime": .string("2026-11-11T08:48:00.839201442Z"),
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
            "lastModifiedTime": .string("2026-11-11T07:00:00Z"),
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
    }
}
