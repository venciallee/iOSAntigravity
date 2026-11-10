import Foundation

/// Durable outbox entry persisted before network dispatch so user turns and approvals
/// survive network transitions or backgrounding.
public struct OutboxEntry: Codable, Sendable, Equatable, Identifiable {
    public enum PayloadKind: String, Codable, Sendable {
        case userMessage
        case interactionApproval
    }

    public var id: UUID
    public var cascadeId: String
    public var kind: PayloadKind
    public var messageText: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        cascadeId: String,
        kind: PayloadKind,
        messageText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.cascadeId = cascadeId
        self.kind = kind
        self.messageText = messageText
        self.createdAt = createdAt
    }
}

/// Manages local display projections for `<10ms` instant cold start and offline browsing,
/// plus the Durable Outbox queue.
public actor LocalProjectionStore {
    private let storageDirectory: URL
    private var cachedSummaries: [CascadeSummary] = []
    private var cachedStepsByCascade: [String: [CascadeStep]] = [:]
    private var outboxQueue: [OutboxEntry] = []

    public init(storageDirectory: URL? = nil) {
        let base = storageDirectory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageDirectory = base.appendingPathComponent("AntigravityProjections", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
    }

    public func loadProjectedSummaries() -> [CascadeSummary] {
        if !cachedSummaries.isEmpty { return cachedSummaries }
        let file = storageDirectory.appendingPathComponent("summaries_projection.json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([CascadeSummary].self, from: data) else {
            return []
        }
        cachedSummaries = decoded
        return decoded
    }

    public func saveProjectedSummaries(_ summaries: [CascadeSummary]) {
        cachedSummaries = summaries
        let file = storageDirectory.appendingPathComponent("summaries_projection.json")
        if let data = try? JSONEncoder().encode(summaries) {
            try? data.write(to: file, options: .atomic)
        }
    }

    public func loadProjectedSteps(cascadeId: String) -> [CascadeStep] {
        if let cached = cachedStepsByCascade[cascadeId] { return cached }
        let file = storageDirectory.appendingPathComponent("steps_\(cascadeId).json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([CascadeStep].self, from: data) else {
            return []
        }
        cachedStepsByCascade[cascadeId] = decoded
        return decoded
    }

    public func saveProjectedSteps(_ steps: [CascadeStep], for cascadeId: String) {
        cachedStepsByCascade[cascadeId] = steps
        let file = storageDirectory.appendingPathComponent("steps_\(cascadeId).json")
        if let data = try? JSONEncoder().encode(steps) {
            try? data.write(to: file, options: .atomic)
        }
    }

    public func enqueueOutbox(_ entry: OutboxEntry) {
        outboxQueue.append(entry)
    }

    public func drainOutbox() -> [OutboxEntry] {
        let items = outboxQueue
        outboxQueue.removeAll()
        return items
    }
}
