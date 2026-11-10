import Foundation

/// Connection transport channel for Antigravity Remote Control.
public enum RemoteConnectionChannel: String, Codable, Sendable, CaseIterable {
    /// Connects via `https://antigravity.google.com/r/<instance-id>` QR link & Google OAuth session.
    case cloudRelay
    /// Connects directly to local/Tailscale `language_server` HTTPS port with `x-codeium-csrf-token`.
    case directHost

    public var displayName: String {
        switch self {
        case .cloudRelay: return "Google Cloud Relay"
        case .directHost: return "Direct LAN / Tailscale"
        }
    }
}

/// Represents a paired Antigravity Desktop or CLI Daemon host instance.
public struct RemoteHostInstance: Codable, Sendable, Equatable, Identifiable {
    public var id: String { instanceId }
    public var instanceId: String
    public var hostname: String
    public var version: String
    public var channel: RemoteConnectionChannel
    public var endpointURL: URL
    public var isOnline: Bool
    public var latencyMs: Int
    public var certificateFingerprintSHA256: String

    public init(
        instanceId: String,
        hostname: String,
        version: String = "v2.30.0",
        channel: RemoteConnectionChannel = .cloudRelay,
        endpointURL: URL,
        isOnline: Bool = true,
        latencyMs: Int = 18,
        certificateFingerprintSHA256: String = "SHA256:9F:86:D0:81:88:4C:7D:65:9A:2F:EA:A0:C5:5A:D0:15"
    ) {
        self.instanceId = instanceId
        self.hostname = hostname
        self.version = version
        self.channel = channel
        self.endpointURL = endpointURL
        self.isOnline = isOnline
        self.latencyMs = latencyMs
        self.certificateFingerprintSHA256 = certificateFingerprintSHA256
    }

    /// Parses an official Antigravity Remote Control QR URL (`https://antigravity.google.com/r/<id>?p=c%2F<conv>`).
    public static func parseRemoteControlQR(urlString: String) -> (instanceId: String, conversationId: String?)? {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              host.contains("antigravity.google") else {
            return nil
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "r" else { return nil }
        let instanceId = parts[1]
        var conversationId: String?
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let pValue = queryItems.first(where: { $0.name == "p" })?.value?.removingPercentEncoding,
           pValue.hasPrefix("c/") {
            conversationId = String(pValue.dropFirst(2))
        }
        return (instanceId, conversationId)
    }
}

public struct WorkspaceInfo: Codable, Sendable, Equatable, Identifiable {
    public var id: String { workspaceUri }
    public var workspaceUri: String
    public var displayName: String
    public var activeBranch: String
    public var worktrees: [String]
    public var activeCascadeCount: Int
    public var indexedFiles: [String]

    public init(
        workspaceUri: String,
        displayName: String,
        activeBranch: String = "main",
        worktrees: [String] = ["main"],
        activeCascadeCount: Int = 0,
        indexedFiles: [String] = []
    ) {
        self.workspaceUri = workspaceUri
        self.displayName = displayName
        self.activeBranch = activeBranch
        self.worktrees = worktrees
        self.activeCascadeCount = activeCascadeCount
        self.indexedFiles = indexedFiles
    }
}

/// Filter tabs for the Conversation List (`WorkspaceHomeViewController`).
public enum SessionFilterCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case waitingApproval = "Waiting"
    case running = "Running"
    case pinned = "Pinned"
    case done = "Completed"

    public var id: String { rawValue }
}

public enum ThinkingEffortLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    public var id: String { rawValue }
}

public enum CascadeExecutionMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case planning = "Planning"
    case fast = "Fast"

    public var id: String { rawValue }
}

public struct CascadeModelConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: String { modelId }
    public var modelId: String
    public var displayName: String
    public var providerBadge: String
    public var effort: ThinkingEffortLevel
    public var mode: CascadeExecutionMode

    public init(
        modelId: String,
        displayName: String,
        providerBadge: String = "Anthropic",
        effort: ThinkingEffortLevel = .high,
        mode: CascadeExecutionMode = .planning
    ) {
        self.modelId = modelId
        self.displayName = displayName
        self.providerBadge = providerBadge
        self.effort = effort
        self.mode = mode
    }

    public static let catalog: [CascadeModelConfig] = [
        CascadeModelConfig(
            modelId: "claude-sonnet-4-5",
            displayName: "Claude Sonnet 4.5",
            providerBadge: "Anthropic",
            effort: .high,
            mode: .planning
        ),
        CascadeModelConfig(
            modelId: "claude-opus-4-5",
            displayName: "Claude Opus 4.5",
            providerBadge: "Anthropic",
            effort: .high,
            mode: .planning
        ),
        CascadeModelConfig(
            modelId: "gemini-2-5-pro",
            displayName: "Gemini 2.5 Pro",
            providerBadge: "Google DeepMind",
            effort: .high,
            mode: .planning
        ),
        CascadeModelConfig(
            modelId: "gpt-5-4",
            displayName: "GPT-5.4",
            providerBadge: "OpenAI",
            effort: .medium,
            mode: .fast
        )
    ]
}

/// Represents a `/slash` workflow command available in `ChatComposerView`.
public struct SlashCommandItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String { command }
    public var command: String
    public var title: String
    public var summary: String
    public var iconName: String

    public init(command: String, title: String, summary: String, iconName: String) {
        self.command = command
        self.title = title
        self.summary = summary
        self.iconName = iconName
    }

    public static let allCommands: [SlashCommandItem] = [
        SlashCommandItem(
            command: "/plan",
            title: "Implementation Plan",
            summary: "Draft a step-by-step architecture & verification plan before coding",
            iconName: "doc.text.magnifyingglass"
        ),
        SlashCommandItem(
            command: "/goal",
            title: "Autonomous Goal Loop",
            summary: "Run thorough multi-step execution until all ESDD acceptance criteria pass",
            iconName: "flag.checkered.2.crossed"
        ),
        SlashCommandItem(
            command: "/grill-me",
            title: "Interactive Design Alignment",
            summary: "Clarify ambiguous trade-offs via structured ask_question cards",
            iconName: "questionmark.bubble.fill"
        ),
        SlashCommandItem(
            command: "/teamwork",
            title: "Multi-Agent Swarm",
            summary: "Spawn parallel subagents for research, implementation, and verification",
            iconName: "person.3.sequence.fill"
        ),
        SlashCommandItem(
            command: "/verify",
            title: "Run ESDD E2E Suite",
            summary: "Execute Connect-RPC protocol tests and @3x screenshot verification",
            iconName: "checkmark.shield.fill"
        )
    ]
}

/// Represents a context chip attached to the Composer Input Box (`@file`, screenshot, terminal log).
public struct ComposerAttachmentChip: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case fileMention
        case imageScreenshot
        case terminalLog
    }

    public var id: String
    public var kind: Kind
    public var label: String
    public var targetUri: String

    public init(id: String = UUID().uuidString, kind: Kind, label: String, targetUri: String) {
        self.id = id
        self.kind = kind
        self.label = label
        self.targetUri = targetUri
    }
}
