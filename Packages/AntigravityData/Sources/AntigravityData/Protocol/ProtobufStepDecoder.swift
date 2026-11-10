import Foundation

/// Encodes and decodes binary Protobuf payloads for `GetCascadeTrajectorySteps`.
///
/// Why binary Protobuf is required:
/// The JSON Connect-RPC endpoint caps `GetCascadeTrajectorySteps` at 600 steps.
/// Sending `Content-Type: application/proto` bypasses the 600-step ceiling and reduces
/// payload size by ~65% over mobile connections.
public enum ProtobufStepCodec {

    /// Encodes a `GetCascadeTrajectoryStepsRequest` (`cascade_id=1`, `start_index=2`, `end_index=3`).
    public static func encodeGetStepsRequest(cascadeId: String, startIndex: Int, endIndex: Int) -> Data {
        var out = Data()
        let idBytes = Data(cascadeId.utf8)
        // field 1 (cascade_id), wire type 2 (length-delimited) -> tag 0x0A
        out.append(0x0A)
        out.append(contentsOf: encodeVarint(UInt64(idBytes.count)))
        out.append(idBytes)

        // field 2 (start_index), wire type 0 (varint) -> tag 0x10
        out.append(0x10)
        out.append(contentsOf: encodeVarint(UInt64(max(0, startIndex))))

        // field 3 (end_index), wire type 0 (varint) -> tag 0x18
        out.append(0x18)
        out.append(contentsOf: encodeVarint(UInt64(max(0, endIndex))))
        return out
    }

    public static func encodeVarint(_ value: UInt64) -> [UInt8] {
        if value == 0 { return [0] }
        var v = value
        var bytes: [UInt8] = []
        while v > 0x7F {
            bytes.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        bytes.append(UInt8(v & 0x7F))
        return bytes
    }

    public static func readVarint(from data: Data, offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[data.startIndex + offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    /// Decodes a binary `GetCascadeTrajectoryStepsResponse` (`repeated Step steps = 1`).
    public static func decodeStepsResponse(_ data: Data, cascadeId: String) -> [CascadeStep] {
        var offset = 0
        var steps: [CascadeStep] = []
        var index = 0

        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            if fieldNumber == 1 && wireType == 2 {
                guard let length = readVarint(from: data, offset: &offset) else { break }
                let len = Int(length)
                guard offset + len <= data.count else { break }
                let sub = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + len))
                offset += len
                if let step = decodeSingleStep(sub, cascadeId: cascadeId, defaultIndex: index) {
                    steps.append(step)
                    index += 1
                }
            } else {
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }
        return steps
    }

    private static func decodeSingleStep(_ data: Data, cascadeId: String, defaultIndex: Int) -> CascadeStep? {
        var offset = 0
        var stepType: CortexStepType = .unspecified
        var stepStatus: CortexStepStatus = .unspecified
        var plannerText: String?
        var thinkingText: String?
        var userInputText: String?
        var requestedInteraction: RequestedInteraction?

        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch (fieldNumber, wireType) {
            case (1, 0): // StepType enum
                if let raw = readVarint(from: data, offset: &offset) {
                    stepType = CortexStepType(rawValue: Int(raw)) ?? .unspecified
                }
            case (4, 0): // StepStatus enum
                if let raw = readVarint(from: data, offset: &offset) {
                    stepStatus = CortexStepStatus(rawValue: Int(raw)) ?? .unspecified
                }
            case (19, 2): // userInput nested message (field 2 = userResponse)
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    userInputText = extractStringField(nested, targetField: 2)
                }
            case (20, 2): // plannerResponse nested message (field 1 = response, field 3 = thinking)
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    plannerText = extractStringField(nested, targetField: 1)
                    thinkingText = extractStringField(nested, targetField: 3)
                }
            case (56, 2): // requestedInteraction oneof
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    requestedInteraction = decodeRequestedInteraction(nested)
                }
            default:
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }

        let plannerPayload = plannerText.map {
            PlannerResponsePayload(response: $0, thinking: thinkingText)
        }

        return CascadeStep(
            cascadeId: cascadeId,
            stepIndex: defaultIndex,
            type: stepType,
            status: stepStatus,
            userInput: userInputText,
            plannerResponse: plannerPayload,
            requestedInteraction: requestedInteraction
        )
    }

    private static func decodeRequestedInteraction(_ data: Data) -> RequestedInteraction? {
        var offset = 0
        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            guard wireType == 2, let nested = readLengthDelimited(from: data, offset: &offset) else {
                skipField(wireType: wireType, data: data, offset: &offset)
                continue
            }
            switch fieldNumber {
            case 3:
                let cmd = extractStringField(nested, targetField: 1) ?? ""
                return RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(proposedCommandLine: cmd, cwd: "/workspace")
                )
            case 19:
                let uri = extractStringField(nested, targetField: 1) ?? ""
                return RequestedInteraction(
                    kind: .filePermission,
                    filePermission: FilePermissionInteractionSpec(absolutePathUri: uri)
                )
            case 21:
                let pattern = extractStringField(nested, targetField: 2)
                return RequestedInteraction(
                    kind: .permission,
                    permission: PermissionInteractionSpec(
                        action: "read",
                        target: pattern ?? "*",
                        suggestedPersistPattern: pattern
                    )
                )
            case 22:
                let q = extractStringField(nested, targetField: 1) ?? "Clarification needed"
                return RequestedInteraction(
                    kind: .askQuestion,
                    askQuestion: AskQuestionInteractionSpec(question: q, options: [])
                )
            default:
                return RequestedInteraction(kind: .approvalInteraction)
            }
        }
        return nil
    }

    private static func readLengthDelimited(from data: Data, offset: inout Int) -> Data? {
        guard let length = readVarint(from: data, offset: &offset) else { return nil }
        let len = Int(length)
        guard offset + len <= data.count else { return nil }
        let slice = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + len))
        offset += len
        return slice
    }

    private static func extractStringField(_ data: Data, targetField: Int) -> String? {
        var offset = 0
        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            if fieldNumber == targetField && wireType == 2 {
                guard let bytes = readLengthDelimited(from: data, offset: &offset) else { return nil }
                return String(data: bytes, encoding: .utf8)
            } else {
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }
        return nil
    }

    private static func skipField(wireType: Int, data: Data, offset: inout Int) {
        switch wireType {
        case 0:
            _ = readVarint(from: data, offset: &offset)
        case 1:
            offset = min(data.count, offset + 8)
        case 2:
            if let len = readVarint(from: data, offset: &offset) {
                offset = min(data.count, offset + Int(len))
            }
        case 5:
            offset = min(data.count, offset + 4)
        default:
            offset = data.count
        }
    }
}
