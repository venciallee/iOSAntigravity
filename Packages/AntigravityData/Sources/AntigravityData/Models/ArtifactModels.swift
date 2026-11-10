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

// MARK: - Implementation Plan Review Models (UE11)

/// Proposed file modification or addition inside `ImplementationPlanReviewViewController` (`UE11`).
public struct PlanProposedFileChange: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var changeKind: String
    public var filePath: String
    public var summaryText: String
    public var highlightedSpan: String?
    public var isSelectedForCallout: Bool

    public init(
        id: String,
        changeKind: String,
        filePath: String,
        summaryText: String,
        highlightedSpan: String? = nil,
        isSelectedForCallout: Bool = false
    ) {
        self.id = id
        self.changeKind = changeKind
        self.filePath = filePath
        self.summaryText = summaryText
        self.highlightedSpan = highlightedSpan
        self.isSelectedForCallout = isSelectedForCallout
    }
}

/// Inline review comment anchored to a quoted text span in an Implementation Plan (`UE11`).
public struct PlanInlineComment: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var authorInitials: String
    public var authorName: String
    public var statusLabel: String
    public var targetFilePath: String
    public var quotedSpan: String
    public var body: String

    public init(
        id: String = UUID().uuidString,
        authorInitials: String = "WL",
        authorName: String = "You",
        statusLabel: String = "Pending",
        targetFilePath: String,
        quotedSpan: String,
        body: String
    ) {
        self.id = id
        self.authorInitials = authorInitials
        self.authorName = authorName
        self.statusLabel = statusLabel
        self.targetFilePath = targetFilePath
        self.quotedSpan = quotedSpan
        self.body = body
    }
}

// MARK: - Multi-Turn Line-Level Diff Review Models (UE12)

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
    public var wordHighlightRange: String?
    public var emphasizedRanges: [Range<Int>]

    public init(
        id: Int,
        kind: Kind,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil,
        text: String,
        wordHighlightRange: String? = nil,
        emphasizedRanges: [Range<Int>] = []
    ) {
        self.id = id
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.text = text
        self.wordHighlightRange = wordHighlightRange
        self.emphasizedRanges = emphasizedRanges
    }

    public var displayLineNumber: Int? {
        newLineNumber ?? oldLineNumber
    }
}

public struct FilePatchDiff: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(turnNumber):\(filePath)" }
    public var turnNumber: Int
    public var filePath: String
    public var additions: Int
    public var deletions: Int
    public var hunkHeader: String
    public var isReviewed: Bool
    public var lines: [DiffLine]

    public init(
        turnNumber: Int = 3,
        filePath: String,
        additions: Int,
        deletions: Int,
        hunkHeader: String = "@@ -18,9 +18,27 @@ Allow",
        isReviewed: Bool = false,
        lines: [DiffLine]
    ) {
        self.turnNumber = turnNumber
        self.filePath = filePath
        self.additions = additions
        self.deletions = deletions
        self.hunkHeader = hunkHeader
        self.isReviewed = isReviewed
        self.lines = lines
    }
}

/// Inline review annotation attached to a specific line in `TurnDiffReviewViewController` (`UE12`).
public struct DiffLineComment: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var filePath: String
    public var lineNumber: Int
    public var body: String
    public var sentToAgent: Bool
    public var author: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        filePath: String,
        lineNumber: Int,
        body: String,
        sentToAgent: Bool = false,
        author: String = "You",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.body = body
        self.sentToAgent = sentToAgent
        self.author = author
        self.createdAt = createdAt
    }

    public var commentText: String {
        get { body }
        set { body = newValue }
    }
}

public typealias DiffLineReviewComment = DiffLineComment
