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

    func testInteractionBuilderMatchesRequestedOneofAndSafeAutoAccept() {
        let step = CascadeStep(
            cascadeId: "cas-01",
            stepIndex: 24,
            type: .runCommand,
            status: .waiting,
            runCommand: RunCommandPayload(
                commandId: "cmd-1",
                commandLine: "python3 verification/esdd-verify.py",
                proposedCommandLine: "python3 verification/esdd-verify.py",
                cwd: "/home/antigravity/venciallee/iOSAntigravity"
            ),
            requestedInteraction: RequestedInteraction(
                kind: .runCommand,
                runCommand: RunCommandInteractionSpec(
                    proposedCommandLine: "python3 verification/esdd-verify.py",
                    cwd: "/home/antigravity/venciallee/iOSAntigravity"
                )
            )
        )

        let payload = InteractionBuilder.buildPayload(
            step: step,
            decision: .allowOnce,
            workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity"
        )
        XCTAssertEqual(payload.cascadeId, "cas-01")
        XCTAssertEqual(payload.stepIndex, 24)
        XCTAssertEqual(payload.runCommand?.confirm, true)
        XCTAssertEqual(payload.runCommand?.proposedCommandLine, "python3 verification/esdd-verify.py")

        XCTAssertTrue(SafeAutoAcceptPolicy.isSafeReadOnlyCommand("git status -s"))
        XCTAssertFalse(SafeAutoAcceptPolicy.isSafeReadOnlyCommand("rm -rf /tmp/build"))
    }

    @MainActor
    func testSessionListFilteringPinningAndCreation() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()
        XCTAssertEqual(store.filteredSummaries.count, 3)
        XCTAssertEqual(store.waitingApprovalCount, 1)

        // Filter by WAITING status
        store.selectedFilterCategory = .waitingApproval
        XCTAssertEqual(store.filteredSummaries.count, 1)
        XCTAssertEqual(store.filteredSummaries.first?.cascadeId, "cas-01-waiting")

        // Filter by branch worktree
        store.selectedFilterCategory = .all
        store.selectedWorktreeFilter = "main"
        XCTAssertEqual(store.filteredSummaries.count, 1)
        XCTAssertEqual(store.filteredSummaries.first?.cascadeId, "cas-03-done")

        // Reset filter & create new cascade
        store.selectedWorktreeFilter = nil
        store.createNewCascade(
            title: "Verify Session List & Composer",
            branchName: "feat/connect-rpc-client",
            initialPrompt: "Run swift test on AntigravityData"
        )
        XCTAssertEqual(store.summaries.count, 4)
        XCTAssertEqual(store.activeSteps.count, 2) // User input + optimistic planner response
    }

    @MainActor
    func testMessageListConsecutiveEvidenceStepGrouping() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()
        // Steps 21 (viewFile) and 22 (codeAction) are consecutive groupable evidence steps
        let items = store.displayItems
        let hasEvidenceGroup = items.contains { item in
            if case .evidenceGroup(_, let grouped) = item {
                return grouped.count == 2
            }
            return false
        }
        XCTAssertTrue(hasEvidenceGroup, "Consecutive viewFile + codeAction steps must collapse into an evidenceGroup")
    }

    @MainActor
    func testComposerSlashAutocompleteFileMentionsAndSend() {
        let store = AntigravitySessionStore.makeESDDVerificationStore()
        store.composerDraftText = "/pl"
        XCTAssertEqual(store.activeSlashCommandSuggestions.first?.command, "/plan")

        store.applySlashCommand(SlashCommandItem.allCommands[0])
        XCTAssertEqual(store.composerDraftText, "/plan ")

        store.attachFileMention("verification/esdd-verify.py")
        XCTAssertTrue(store.composerAttachments.contains(where: { $0.label == "@esdd-verify.py" }))

        let initialCount = store.activeSteps.count
        store.composerDraftText = "/plan Add interactive E2E state transition tests"
        store.sendCurrentDraft()

        XCTAssertEqual(store.activeSteps.count, initialCount + 2)
        XCTAssertEqual(store.composerDraftText, "")
        XCTAssertTrue(store.composerAttachments.isEmpty)
    }
}
