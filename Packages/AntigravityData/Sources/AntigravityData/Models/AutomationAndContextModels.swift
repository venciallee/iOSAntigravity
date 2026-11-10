import Foundation

// MARK: - Automations Models (UE06)

/// Section grouping in `AutomationsViewController` (`UE06`).
public enum AutomationSectionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case scheduled = "SCHEDULED"
    case alwaysOn = "ALWAYS ON"
    case paused = "PAUSED"

    public var id: String { rawValue }
}

public typealias AutomationCategory = AutomationSectionKind

/// Scheduled, event-triggered, or paused background agent automation (`UE04`, `UE06`).
public struct AutomationItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var projectSlug: String
    public var scheduleSummary: String
    public var section: AutomationSectionKind
    public var nextRunText: String
    public var lastRunText: String
    public var needsReview: Bool
    public var isRunningNow: Bool

    public init(
        id: String,
        title: String,
        projectSlug: String,
        scheduleSummary: String,
        section: AutomationSectionKind,
        nextRunText: String,
        lastRunText: String,
        needsReview: Bool = false,
        isRunningNow: Bool = false
    ) {
        self.id = id
        self.title = title
        self.projectSlug = projectSlug
        self.scheduleSummary = scheduleSummary
        self.section = section
        self.nextRunText = nextRunText
        self.lastRunText = lastRunText
        self.needsReview = needsReview
        self.isRunningNow = isRunningNow
    }

    public var category: AutomationSectionKind {
        get { section }
        set { section = newValue }
    }

    public var nextRunLabel: String {
        get { nextRunText }
        set { nextRunText = newValue }
    }

    public var lastRunLabel: String {
        get { lastRunText }
        set { lastRunText = newValue }
    }
}

// MARK: - Add Context Sheet Models (UE08)

/// Category tiles at the top of `AddContextSheetView` (`UE08`).
public enum ContextCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case files = "Files"
    case folder = "Folder"
    case mentions = "Mentions"
    case actions = "Actions"
    case skills = "Skills"

    public var id: String { rawValue }
}

/// Selectable file, folder, mention, action, or skill item in `AddContextSheetView` (`UE08`).
public struct ContextCandidateItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var category: ContextCategory
    public var title: String
    public var subtitle: String
    public var chipLabel: String
    public var isActionTrigger: Bool
    public var isSelected: Bool

    public init(
        id: String,
        category: ContextCategory,
        title: String,
        subtitle: String,
        chipLabel: String,
        isActionTrigger: Bool = false,
        isSelected: Bool = false
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.chipLabel = chipLabel
        self.isActionTrigger = isActionTrigger
        self.isSelected = isSelected
    }

    public var attachmentKind: ComposerAttachmentChip.Kind {
        switch category {
        case .files: return .fileMention
        case .folder: return .folder
        case .mentions:
            return title.lowercased().contains("terminal") ? .terminalLog : .conversationMention
        case .actions: return .action
        case .skills: return .skill
        }
    }
}
