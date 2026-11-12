import Foundation

/// Encodes and decodes binary Protobuf payloads for `GetCascadeTrajectorySteps`.
///
/// Why binary Protobuf is required:
/// The JSON Connect-RPC endpoint caps `GetCascadeTrajectorySteps` at 600 steps.
/// Sending `Content-Type: application/proto` bypasses the 600-step ceiling and reduces
/// payload size by ~65% over mobile connections.
public enum ProtobufStepCodec {

    /// Encodes a `GetCascadeTrajectoryStepsRequest` (`cascade_id=1`, `step_offset=2`).
    /// Note: `endIndex` is retained in signature for source compatibility; field 3 in upstream
    /// `GetCascadeTrajectoryStepsRequest` is `verbosity` enum and must not be populated with step counts.
    public static func encodeGetStepsRequest(cascadeId: String, startIndex: Int, endIndex: Int = 0) -> Data {
        _ = endIndex
        var out = Data()
        let idBytes = Data(cascadeId.utf8)
        // field 1 (cascade_id), wire type 2 (length-delimited) -> tag 0x0A
        out.append(0x0A)
        out.append(contentsOf: encodeVarint(UInt64(idBytes.count)))
        out.append(idBytes)

        // field 2 (step_offset), wire type 0 (varint) -> tag 0x10
        out.append(0x10)
        out.append(contentsOf: encodeVarint(UInt64(max(0, startIndex))))
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

    /// Maps upstream `exa.cortex_pb.CortexStepStatus` integer values cleanly to `CortexStepStatus`.
    public static func decodeStepStatus(_ raw: Int) -> CortexStepStatus {
        switch raw {
        case 0, 5: return .unspecified // UNSPECIFIED, CLEARED
        case 1, 11: return .pending    // PENDING, QUEUED
        case 2, 8: return .inProgress  // RUNNING, GENERATING
        case 3: return .done           // DONE
        case 4, 7: return .error       // INVALID, ERROR
        case 6, 12: return .cancelled  // CANCELED, INTERRUPTED
        case 9: return .waiting        // WAITING
        default:
            return CortexStepStatus(rawValue: raw) ?? .unspecified
        }
    }

    /// Maps upstream `exa.cortex_pb.CortexStepType` integer values cleanly to `CortexStepType`.
    public static func decodeStepType(_ raw: Int) -> CortexStepType {
        switch raw {
        case 5, 24, 86: return .codeAction        // CODE_ACTION, PROPOSE_CODE, FILE_CHANGE
        case 7, 25, 33, 73, 84: return .search    // GREP_SEARCH, FIND, SEARCH_WEB, CODE_SEARCH, INTERNAL_SEARCH
        case 8, 13, 47: return .viewFile          // VIEW_FILE, VIEW_CODE_ITEM, VIEW_FILE_OUTLINE
        case 9: return .listDirectory             // LIST_DIRECTORY
        case 14: return .userInput                // USER_INPUT
        case 15: return .plannerResponse          // PLANNER_RESPONSE
        case 21, 112: return .runCommand          // RUN_COMMAND, SHELL_EXEC
        case 23, 1, 2, 3, 27, 29, 34, 55, 98:     // CHECKPOINT & housekeeping
            return .checkpoint
        case 28: return .commandStatus            // COMMAND_STATUS
        case 31: return .readUrlContent           // READ_URL_CONTENT
        case 32: return .viewContentChunk         // VIEW_CONTENT_CHUNK
        case 81: return .taskBoundary             // TASK_BOUNDARY
        case 82: return .notifyUser               // NOTIFY_USER
        case 83: return .codeAcknowledgement      // CODE_ACKNOWLEDGEMENT
        case 85: return .browserSubagent          // BROWSER_SUBAGENT
        case 90: return .ephemeralMessage         // EPHEMERAL_MESSAGE
        case 91: return .generateImage            // GENERATE_IMAGE
        case 99: return .knowledgeArtifacts       // KNOWLEDGE_ARTIFACTS
        case 100: return .sendCommandInput        // SEND_COMMAND_INPUT
        case 122: return .workspaceApi            // WORKSPACE_API
        default:
            return CortexStepType(rawValue: raw) ?? .unspecified
        }
    }

    /// Maps upstream `exa.codeium_common_pb.Model` integer enum values to proto enum names.
    public static func modelEnumName(fromProtoInt raw: Int) -> String? {
        guard raw > 0 else { return nil }
        if raw >= 1000 && raw <= 1200 {
            return "MODEL_PLACEHOLDER_M\(raw - 1000)"
        }
        switch raw {
        case 246: return "MODEL_GOOGLE_GEMINI_2_5_PRO"
        case 281: return "MODEL_CLAUDE_4_SONNET"
        case 282: return "MODEL_CLAUDE_4_SONNET_THINKING"
        case 290: return "MODEL_CLAUDE_4_OPUS"
        case 291: return "MODEL_CLAUDE_4_OPUS_THINKING"
        case 312: return "MODEL_GOOGLE_GEMINI_2_5_FLASH"
        case 313: return "MODEL_GOOGLE_GEMINI_2_5_FLASH_THINKING"
        case 330: return "MODEL_GOOGLE_GEMINI_2_5_FLASH_LITE"
        case 333: return "MODEL_CLAUDE_4_5_SONNET"
        case 334: return "MODEL_CLAUDE_4_5_SONNET_THINKING"
        case 340: return "MODEL_CLAUDE_4_5_HAIKU"
        case 341: return "MODEL_CLAUDE_4_5_HAIKU_THINKING"
        case 342: return "MODEL_OPENAI_GPT_OSS_120B_MEDIUM"
        default: return nil
        }
    }

    /// Decodes a binary `GetCascadeTrajectoryStepsResponse` (`repeated Step steps = 1`).
    public static func decodeStepsResponse(_ data: Data, cascadeId: String, startingIndex: Int = 0) -> [CascadeStep] {
        var offset = 0
        var steps: [CascadeStep] = []
        var index = startingIndex

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
        var rawType: Int = 0
        var stepType: CortexStepType = .unspecified
        var stepStatus: CortexStepStatus = .unspecified
        var createdAt: Date = Date()

        var userInputText: String?
        var attachedMentions: [String] = []
        var recordedMode: CascadeExecutionMode?
        var recordedModelId: String?

        var plannerPayload: PlannerResponsePayload?
        var taskBoundaryPayload: TaskBoundaryPayload?
        var runCommandPayload: RunCommandPayload?
        var codeActionPayload: CodeActionPayload?
        var viewFilePayload: ViewFilePayload?
        var searchPayload: SearchPayload?
        var requestedInteraction: RequestedInteraction?

        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch (fieldNumber, wireType) {
            case (1, 0): // CortexStepType
                if let raw = readVarint(from: data, offset: &offset) {
                    rawType = Int(raw)
                    stepType = decodeStepType(rawType)
                }
            case (4, 0): // CortexStepStatus
                if let raw = readVarint(from: data, offset: &offset) {
                    stepStatus = decodeStepStatus(Int(raw))
                }
            case (5, 2): // CortexStepMetadata (field 1 = created_at Timestamp)
                if let nested = readLengthDelimited(from: data, offset: &offset),
                   let ts = extractTimestampField(nested, targetField: 1) {
                    createdAt = ts
                }
            case (10, 2), (23, 2), (98, 2): // code_action (10), write_to_file (23), file_change (98)
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    let uri = nonEmpty(extractStringField(nested, targetField: 1))
                        ?? nonEmpty(extractNestedStringField(nested, outerField: 1, innerField: 1))
                        ?? "workspace/file"
                    let desc = nonEmpty(extractStringField(nested, targetField: 4))
                        ?? nonEmpty(extractStringField(nested, targetField: 2))
                        ?? "Modified file"
                    codeActionPayload = CodeActionPayload(
                        targetFileUri: uri,
                        description: desc,
                        additions: 0,
                        deletions: 0
                    )
                    if stepType == .unspecified { stepType = .codeAction }
                }
            case (13, 2), (34, 2), (42, 2), (85, 2): // grep_search (13), find (34), search_web (42), code_search (85)
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    let q = nonEmpty(extractStringField(nested, targetField: 3))
                        ?? nonEmpty(extractStringField(nested, targetField: 1))
                        ?? nonEmpty(extractStringField(nested, targetField: 2))
                        ?? "search"
                    let scope = nonEmpty(extractStringField(nested, targetField: 1)) ?? "workspace"
                    searchPayload = SearchPayload(query: q, scopeDirectory: scope, matchCount: 0)
                    if stepType == .unspecified { stepType = .search }
                }
            case (14, 2), (22, 2), (58, 2): // view_file (14), view_code_item (22), view_file_outline (58)
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    if let uri = nonEmpty(extractStringField(nested, targetField: 1)) {
                        viewFilePayload = ViewFilePayload(fileUri: uri)
                        if stepType == .unspecified { stepType = .viewFile }
                    }
                }
            case (15, 2): // list_directory (15)
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    if let uri = nonEmpty(extractStringField(nested, targetField: 1)) {
                        viewFilePayload = ViewFilePayload(fileUri: uri)
                        if stepType == .unspecified { stepType = .listDirectory }
                    }
                }
            case (19, 2): // CortexStepUserInput
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    let parsed = decodeUserInput(nested)
                    userInputText = parsed.text
                    attachedMentions = parsed.mentions
                    recordedMode = parsed.mode
                    recordedModelId = parsed.modelId
                    if stepType == .unspecified { stepType = .userInput }
                }
            case (20, 2): // CortexStepPlannerResponse
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    plannerPayload = decodePlannerResponse(nested)
                    if stepType == .unspecified { stepType = .plannerResponse }
                }
            case (24, 2): // CortexStepErrorMessage
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    let errMsg = nonEmpty(extractStringField(nested, targetField: 1))
                        ?? nonEmpty(extractNestedStringField(nested, outerField: 1, innerField: 1))
                    if let errMsg {
                        plannerPayload = PlannerResponsePayload(response: "⚠️ \(errMsg)")
                        stepType = .plannerResponse
                        stepStatus = .error
                    }
                }
            case (28, 2): // CortexStepRunCommand
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    runCommandPayload = decodeRunCommand(nested, fallbackStepIndex: defaultIndex)
                    if stepType == .unspecified { stepType = .runCommand }
                }
            case (56, 2): // RequestedInteraction oneof
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    requestedInteraction = decodeRequestedInteraction(nested, hintStepType: stepType)
                    if requestedInteraction?.kind == .runCommand,
                       runCommandPayload == nil,
                       let spec = requestedInteraction?.runCommand {
                        runCommandPayload = RunCommandPayload(
                            commandId: "cmd-\(defaultIndex)",
                            commandLine: spec.proposedCommandLine,
                            proposedCommandLine: spec.proposedCommandLine,
                            cwd: spec.cwd
                        )
                    }
                }
            case (93, 2): // CortexStepTaskBoundary
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    let tName = nonEmpty(extractStringField(nested, targetField: 1)) ?? "Task Progress"
                    let tStatus = nonEmpty(extractStringField(nested, targetField: 2)) ?? ""
                    let tSummary = nonEmpty(extractStringField(nested, targetField: 3)) ?? tStatus
                    taskBoundaryPayload = TaskBoundaryPayload(
                        taskName: tName,
                        taskStatus: tStatus,
                        taskSummary: tSummary
                    )
                    stepType = .taskBoundary
                }
            case (94, 2): // CortexStepNotifyUser
                if let nested = readLengthDelimited(from: data, offset: &offset) {
                    let reviewUris = extractRepeatedStringField(nested, targetField: 1)
                    let content = nonEmpty(extractStringField(nested, targetField: 2)) ?? ""
                    if !content.isEmpty || !reviewUris.isEmpty {
                        plannerPayload = PlannerResponsePayload(
                            response: content.isEmpty ? "Ready for review." : content,
                            referencedFiles: reviewUris
                        )
                        stepType = .notifyUser
                    }
                }
            default:
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }

        // Legacy mock_language_server compatibility: rawType 17 with no error payload stays .generateImage
        if rawType == 17 && plannerPayload == nil {
            stepType = .generateImage
        }
        if (stepType == .plannerResponse || stepType == .notifyUser)
            && plannerPayload == nil
            && (stepStatus == .inProgress || stepStatus == .pending) {
            plannerPayload = PlannerResponsePayload(response: "")
        }

        return CascadeStep(
            cascadeId: cascadeId,
            stepIndex: defaultIndex,
            type: stepType,
            status: stepStatus,
            createdAt: createdAt,
            userInput: userInputText,
            attachedMentions: attachedMentions,
            plannerResponse: plannerPayload,
            taskBoundary: taskBoundaryPayload,
            runCommand: runCommandPayload,
            codeAction: codeActionPayload,
            viewFile: viewFilePayload,
            search: searchPayload,
            requestedInteraction: requestedInteraction,
            recordedExecutionMode: recordedMode,
            recordedModelId: recordedModelId
        )
    }

    private static func decodeUserInput(_ data: Data) -> (
        text: String?,
        mentions: [String],
        mode: CascadeExecutionMode?,
        modelId: String?
    ) {
        var offset = 0
        var queryText: String?
        var userResponseText: String?
        var itemTexts: [String] = []
        var mentions: [String] = []
        var recordedMode: CascadeExecutionMode?
        var recordedModelId: String?

        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch (fieldNumber, wireType) {
            case (1, 2): // query
                if let bytes = readLengthDelimited(from: data, offset: &offset),
                   let s = nonEmpty(String(data: bytes, encoding: .utf8)) {
                    queryText = s
                }
            case (2, 2): // user_response
                if let bytes = readLengthDelimited(from: data, offset: &offset),
                   let s = nonEmpty(String(data: bytes, encoding: .utf8)) {
                    userResponseText = s
                }
            case (3, 2): // repeated TextOrScopeItem items (field 1 = text, field 2 = item)
                if let itemData = readLengthDelimited(from: data, offset: &offset) {
                    if let t = nonEmpty(extractStringField(itemData, targetField: 1)) {
                        itemTexts.append(t)
                    }
                    if let scopeData = extractMessageField(itemData, targetField: 2),
                       let fileData = extractMessageField(scopeData, targetField: 1),
                       let fileUri = nonEmpty(extractStringField(fileData, targetField: 1)) {
                        let name = URL(string: fileUri)?.lastPathComponent ?? (fileUri as NSString).lastPathComponent
                        if !name.isEmpty {
                            mentions.append("@\(name)")
                        }
                    }
                }
            case (12, 2), (13, 2): // user_config (12) or last_user_config (13): CascadeConfig
                if let cfgData = readLengthDelimited(from: data, offset: &offset) {
                    let parsedCfg = decodeCascadeConfig(cfgData)
                    if let m = parsedCfg.mode { recordedMode = m }
                    if let mid = parsedCfg.modelId { recordedModelId = mid }
                }
            default:
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }

        let joinedItems = nonEmpty(itemTexts.joined(separator: "\n"))
        let resolvedText = userResponseText ?? joinedItems ?? queryText
        return (resolvedText, mentions, recordedMode, recordedModelId)
    }

    private static func decodeCascadeConfig(_ data: Data) -> (mode: CascadeExecutionMode?, modelId: String?) {
        // CascadeConfig.planner_config = field 1
        guard let plannerData = extractMessageField(data, targetField: 1) else {
            return (nil, nil)
        }
        var mode: CascadeExecutionMode?
        var modelId: String?

        // CascadePlannerConfig.conversational = field 2 -> agentic_mode = field 14 (bool)
        if let convData = extractMessageField(plannerData, targetField: 2) {
            if let agenticVal = extractVarintField(convData, targetField: 14) {
                mode = (agenticVal != 0) ? .planning : .fast
            } else {
                // Present conversational block with omitted proto3 false default (`agentic_mode = false`) -> Fast
                mode = .fast
            }
        }

        // CascadePlannerConfig.requested_model = field 15 (ModelOrAlias: field 1 = model varint, field 2 = alias varint/string)
        if let reqModelData = extractMessageField(plannerData, targetField: 15) {
            if let modelInt = extractVarintField(reqModelData, targetField: 1),
               let enumName = modelEnumName(fromProtoInt: Int(modelInt)) {
                modelId = enumName
            } else if let aliasStr = nonEmpty(extractStringField(reqModelData, targetField: 2)) {
                modelId = aliasStr
            }
        }

        // Fallback: CascadePlannerConfig.plan_model = field 1 (used by Cloud Remote Agents)
        if modelId == nil,
           let planModelInt = extractVarintField(plannerData, targetField: 1),
           let enumName = modelEnumName(fromProtoInt: Int(planModelInt)) {
            modelId = enumName
        }

        return (mode, modelId)
    }

    private static func decodePlannerResponse(_ data: Data) -> PlannerResponsePayload? {
        var offset = 0
        var responseText: String?
        var modifiedResponseText: String?
        var thinkingText: String?
        var durationSeconds: Double?

        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch (fieldNumber, wireType) {
            case (1, 2): // response
                if let bytes = readLengthDelimited(from: data, offset: &offset),
                   let s = nonEmpty(String(data: bytes, encoding: .utf8)) {
                    responseText = s
                }
            case (3, 2): // thinking
                if let bytes = readLengthDelimited(from: data, offset: &offset),
                   let s = nonEmpty(String(data: bytes, encoding: .utf8)) {
                    thinkingText = s
                }
            case (8, 2): // modified_response
                if let bytes = readLengthDelimited(from: data, offset: &offset),
                   let s = nonEmpty(String(data: bytes, encoding: .utf8)) {
                    modifiedResponseText = s
                }
            case (11, 2): // thinking_duration (google.protobuf.Duration: seconds=1, nanos=2)
                if let durData = readLengthDelimited(from: data, offset: &offset) {
                    let secs = Double(extractVarintField(durData, targetField: 1) ?? 0)
                    let nanos = Double(extractVarintField(durData, targetField: 2) ?? 0) / 1_000_000_000.0
                    let total = secs + nanos
                    if total > 0 {
                        durationSeconds = total
                    }
                }
            default:
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }

        let finalResponse = modifiedResponseText ?? responseText ?? ""
        if finalResponse.isEmpty && thinkingText == nil {
            return nil
        }
        return PlannerResponsePayload(
            response: finalResponse,
            thinking: thinkingText,
            thinkingDurationSeconds: durationSeconds
        )
    }

    private static func decodeRunCommand(_ data: Data, fallbackStepIndex: Int) -> RunCommandPayload {
        let cmdLine = nonEmpty(extractStringField(data, targetField: 23)) // command_line
            ?? nonEmpty(extractStringField(data, targetField: 25))        // proposed_command_line
            ?? nonEmpty(extractStringField(data, targetField: 1))         // command
            ?? ""
        let proposed = nonEmpty(extractStringField(data, targetField: 25)) ?? cmdLine
        let cwd = nonEmpty(extractStringField(data, targetField: 2)) ?? ""
        let cmdId = nonEmpty(extractStringField(data, targetField: 13)) ?? "cmd-\(fallbackStepIndex)"
        let exitCodeRaw = extractVarintField(data, targetField: 6)
        let exitCode = exitCodeRaw.map { Int(Int32(truncatingIfNeeded: $0)) }
        let stdout = nonEmpty(extractStringField(data, targetField: 4))
            ?? nonEmpty(extractStringField(data, targetField: 7))
            ?? nonEmpty(extractNestedStringField(data, outerField: 21, innerField: 1))
            ?? ""
        let stderr = nonEmpty(extractStringField(data, targetField: 5))
            ?? nonEmpty(extractStringField(data, targetField: 8))
            ?? ""
        let combined = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")

        return RunCommandPayload(
            commandId: cmdId,
            commandLine: cmdLine,
            proposedCommandLine: proposed,
            cwd: cwd,
            exitCode: exitCode,
            outputPreview: String(combined.prefix(2000))
        )
    }

    private static func decodeRequestedInteraction(_ data: Data, hintStepType: CortexStepType) -> RequestedInteraction? {
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
            case 2:
                return RequestedInteraction(kind: .deploy)
            case 3: // CascadeRunCommandInteractionSpec
                let cmd = nonEmpty(extractStringField(nested, targetField: 2))
                    ?? nonEmpty(extractStringField(nested, targetField: 1))
                    ?? ""
                let cwd = nonEmpty(extractStringField(nested, targetField: 1)) ?? "/workspace"
                return RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(
                        proposedCommandLine: cmd.isEmpty ? cwd : cmd,
                        cwd: cwd
                    )
                )
            case 19: // FilePermissionInteractionSpec
                let uri = extractStringField(nested, targetField: 1) ?? ""
                return RequestedInteraction(
                    kind: .filePermission,
                    filePermission: FilePermissionInteractionSpec(absolutePathUri: uri)
                )
            case 21: // PermissionInteractionSpec
                let pattern = extractStringField(nested, targetField: 2)
                return RequestedInteraction(
                    kind: .permission,
                    permission: PermissionInteractionSpec(
                        action: "read",
                        target: pattern ?? "*",
                        suggestedPersistPattern: pattern
                    )
                )
            case 22, 24: // AskQuestionInteractionSpec (22 real, 24 mock_language_server)
                let q = extractStringField(nested, targetField: 1) ?? "Clarification needed"
                let opts = extractRepeatedStringField(nested, targetField: 2)
                return RequestedInteraction(
                    kind: .askQuestion,
                    askQuestion: AskQuestionInteractionSpec(question: q, options: opts)
                )
            case 23: // ApprovalInteractionSpec (23 real) or mock_language_server runCommand (when stepType == .runCommand)
                if hintStepType == .runCommand,
                   let cmd = nonEmpty(extractStringField(nested, targetField: 1)) {
                    return RequestedInteraction(
                        kind: .runCommand,
                        runCommand: RunCommandInteractionSpec(proposedCommandLine: cmd, cwd: "/workspace")
                    )
                }
                return RequestedInteraction(kind: .approvalInteraction)
            default:
                return RequestedInteraction(kind: .approvalInteraction)
            }
        }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return value
    }

    private static func readLengthDelimited(from data: Data, offset: inout Int) -> Data? {
        guard let length = readVarint(from: data, offset: &offset) else { return nil }
        let len = Int(length)
        guard offset + len <= data.count else { return nil }
        let slice = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + len))
        offset += len
        return slice
    }

    private static func extractMessageField(_ data: Data, targetField: Int) -> Data? {
        var offset = 0
        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            if fieldNumber == targetField && wireType == 2 {
                return readLengthDelimited(from: data, offset: &offset)
            } else {
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }
        return nil
    }

    private static func extractVarintField(_ data: Data, targetField: Int) -> UInt64? {
        var offset = 0
        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            if fieldNumber == targetField && wireType == 0 {
                return readVarint(from: data, offset: &offset)
            } else {
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }
        return nil
    }

    private static func extractTimestampField(_ data: Data, targetField: Int) -> Date? {
        guard let tsData = extractMessageField(data, targetField: targetField),
              let secs = extractVarintField(tsData, targetField: 1) else {
            return nil
        }
        let nanos = extractVarintField(tsData, targetField: 2) ?? 0
        let epoch = TimeInterval(Int64(bitPattern: secs)) + (TimeInterval(nanos) / 1_000_000_000.0)
        guard epoch > 946_684_800 else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }

    private static func extractNestedStringField(_ data: Data, outerField: Int, innerField: Int) -> String? {
        guard let nested = extractMessageField(data, targetField: outerField) else { return nil }
        return extractStringField(nested, targetField: innerField)
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

    private static func extractRepeatedStringField(_ data: Data, targetField: Int) -> [String] {
        var offset = 0
        var results: [String] = []
        while offset < data.count {
            guard let tag = readVarint(from: data, offset: &offset) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)
            if fieldNumber == targetField && wireType == 2 {
                if let bytes = readLengthDelimited(from: data, offset: &offset),
                   let s = String(data: bytes, encoding: .utf8),
                   !s.isEmpty {
                    results.append(s)
                }
            } else {
                skipField(wireType: wireType, data: data, offset: &offset)
            }
        }
        return results
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
