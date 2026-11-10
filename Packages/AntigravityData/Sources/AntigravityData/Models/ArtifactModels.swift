import Foundation

public enum ArtifactKind: String, Codable, Sendable {
    case implementationPlan
    case walkthrough
    case taskList
    case generativeUIHTML
    case urlBookmark
}

/// Represents an Antigravity artifact (`GetArtifactSnapshots` / `GetRevisionArtifact`).
public struct ArtifactSnapshot: Codable, Sendable, Equatable, Identifiable {
    public var id: String { artifactPath }
    public var artifactPath: String
    public var title: String
    public var summary: String
    public var kind: ArtifactKind
    public var content: String
    public var requestFeedback: Bool
    public var userFacing: Bool
    public var version: Int
    public var updatedAt: Date

    public init(
        artifactPath: String,
        title: String,
        summary: String,
        kind: ArtifactKind,
        content: String,
        requestFeedback: Bool = false,
        userFacing: Bool = true,
        version: Int = 1,
        updatedAt: Date = Date()
    ) {
        self.artifactPath = artifactPath
        self.title = title
        self.summary = summary
        self.kind = kind
        self.content = content
        self.requestFeedback = requestFeedback
        self.userFacing = userFacing
        self.version = version
        self.updatedAt = updatedAt
    }
}

public struct DiffLine: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case context
        case addition
        case deletion
        case hunkHeader
    }

    public var id: Int
    public var kind: Kind
    public var oldLineNumber: Int?
    public var newLineNumber: Int?
    public var text: String
    public var emphasizedRanges: [Range<Int>]

    public init(
        id: Int,
        kind: Kind,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil,
        text: String,
        emphasizedRanges: [Range<Int>] = []
    ) {
        self.id = id
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.text = text
        self.emphasizedRanges = emphasizedRanges
    }
}

public struct FilePatchDiff: Codable, Sendable, Equatable, Identifiable {
    public var id: String { filePath }
    public var filePath: String
    public var additions: Int
    public var deletions: Int
    public var lines: [DiffLine]

    public init(filePath: String, additions: Int, deletions: Int, lines: [DiffLine]) {
        self.filePath = filePath
        self.additions = additions
        self.deletions = deletions
        self.lines = lines
    }
}
