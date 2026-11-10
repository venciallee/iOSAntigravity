import Foundation

/// Connection transport channel for Antigravity Remote Control.
public enum RemoteConnectionChannel: String, Codable, Sendable {
    /// Connects via `https://antigravity.google.com/r/<instance-id>` QR link & Google OAuth session.
    case cloudRelay
    /// Connects directly to local/Tailscale `language_server` HTTPS port with `x-codeium-csrf-token`.
    case directHost
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

    public init(
        instanceId: String,
        hostname: String,
        version: String = "v2.30.0",
        channel: RemoteConnectionChannel = .cloudRelay,
        endpointURL: URL,
        isOnline: Bool = true,
        latencyMs: Int = 18
    ) {
        self.instanceId = instanceId
        self.hostname = hostname
        self.version = version
        self.channel = channel
        self.endpointURL = endpointURL
        self.isOnline = isOnline
        self.latencyMs = latencyMs
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

    public init(
        workspaceUri: String,
        displayName: String,
        activeBranch: String = "main",
        worktrees: [String] = ["main"],
        activeCascadeCount: Int = 0
    ) {
        self.workspaceUri = workspaceUri
        self.displayName = displayName
        self.activeBranch = activeBranch
        self.worktrees = worktrees
        self.activeCascadeCount = activeCascadeCount
    }
}

public enum ThinkingEffortLevel: String, Codable, Sendable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

public enum CascadeExecutionMode: String, Codable, Sendable, CaseIterable {
    case planning = "Planning"
    case fast = "Fast"
}

public struct CascadeModelConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: String { modelId }
    public var modelId: String
    public var displayName: String
    public var effort: ThinkingEffortLevel
    public var mode: CascadeExecutionMode

    public init(
        modelId: String,
        displayName: String,
        effort: ThinkingEffortLevel = .high,
        mode: CascadeExecutionMode = .planning
    ) {
        self.modelId = modelId
        self.displayName = displayName
        self.effort = effort
        self.mode = mode
    }
}
