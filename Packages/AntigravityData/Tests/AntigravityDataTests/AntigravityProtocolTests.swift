import XCTest
@testable import AntigravityData

final class AntigravityProtocolTests: XCTestCase {

    func testRemoteControlQRCodeParser() {
        let qrURL = "https://antigravity.google.com/r/lt74xt6l0m-golden-star?p=c%2Fcas-01-waiting"
        let parsed = RemoteHostInstance.parseRemoteControlQR(urlString: qrURL)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.instanceId, "lt74xt6l0m-golden-star")
        XCTAssertEqual(parsed?.conversationId, "cas-01-waiting")
    }

    func testConnectEnvelopeRoundTrip() {
        let jsonPayload = Data("{\"cascadeId\":\"cas-01\"}".utf8)
        let frame = ConnectEnvelopeFrame(flags: [], payload: jsonPayload)
        let encoded = frame.encode()
        XCTAssertEqual(encoded.count, 5 + jsonPayload.count)

        var parser = ConnectStreamParser()
        let decodedFrames = parser.feed(encoded)
        XCTAssertEqual(decodedFrames.count, 1)
        XCTAssertEqual(decodedFrames[0].payload, jsonPayload)
    }

    func testInteractionBuilderMatchesRequestedOneof() {
        let step = CascadeStep(
            cascadeId: "cas-01",
            stepIndex: 24,
            type: .runCommand,
            status: .waiting,
            requestedInteraction: RequestedInteraction(
                kind: .permission,
                permission: PermissionInteractionSpec(
                    action: "read",
                    target: "/home/antigravity/file.swift",
                    suggestedPersistPattern: "/home/antigravity/*"
                )
            )
        )

        let payload = InteractionBuilder.buildPayload(step: step, decision: .alwaysAllowInTurn)
        XCTAssertNotNil(payload)
        let perm = payload?["permission"] as? [String: Any]
        XCTAssertEqual(perm?["allow"] as? Bool, true)
        let grants = perm?["turnGrants"] as? [String: [String]]
        XCTAssertEqual(grants?["allow"], ["read(/home/antigravity/*)"])
    }
}
