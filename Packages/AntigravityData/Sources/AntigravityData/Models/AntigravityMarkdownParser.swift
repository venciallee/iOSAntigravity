import Foundation

// MARK: - AST Models (`Sendable`, Pure Swift 6, Zero UIKit Dependency)

public enum MarkdownAlertKind: String, Sendable, Equatable, CaseIterable {
    case note = "NOTE"
    case tip = "TIP"
    case important = "IMPORTANT"
    case warning = "WARNING"
    case caution = "CAUTION"

    public var displayTitle: String {
        switch self {
        case .note: return "Note"
        case .tip: return "Tip"
        case .important: return "Important"
        case .warning: return "Warning"
        case .caution: return "Caution"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .note: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        case .important: return "exclamationmark.bubble.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .caution: return "flame.fill"
        }
    }
}

public enum MarkdownListMarker: Sendable, Equatable {
    case bullet
    case ordered(Int)
    case task(checked: Bool)
}

public enum MarkdownTableAlignment: Sendable, Equatable {
    case leading
    case center
    case trailing
}

public indirect enum MarkdownInline: Sendable, Equatable {
    case text(String)
    case softBreak
    case code(String)
    case strong([MarkdownInline])
    case emphasis([MarkdownInline])
    case strikethrough([MarkdownInline])
    case link(label: [MarkdownInline], destination: String)
    case inlineMath(String)

    /// Plain-text projection used for accessibility and testing.
    public var plainText: String {
        switch self {
        case .text(let s):
            return s
        case .softBreak:
            return "\n"
        case .code(let c):
            return c
        case .strong(let children), .emphasis(let children), .strikethrough(let children):
            return children.map(\.plainText).joined()
        case .link(let label, _):
            return label.map(\.plainText).joined()
        case .inlineMath(let latex):
            return latex
        }
    }
}

public indirect enum MarkdownBlock: Sendable, Equatable, Identifiable {
    case heading(id: Int, level: Int, inlines: [MarkdownInline])
    case paragraph(id: Int, inlines: [MarkdownInline])
    case codeBlock(id: Int, language: String?, code: String)
    case listItem(id: Int, indentLevel: Int, marker: MarkdownListMarker, inlines: [MarkdownInline])
    case blockquote(id: Int, alert: MarkdownAlertKind?, blocks: [MarkdownBlock])
    case table(id: Int, headers: [[MarkdownInline]], alignments: [MarkdownTableAlignment], rows: [[[MarkdownInline]]])
    case thematicBreak(id: Int)
    case mathBlock(id: Int, latex: String)

    public var id: Int {
        switch self {
        case .heading(let id, _, _),
             .paragraph(let id, _),
             .codeBlock(let id, _, _),
             .listItem(let id, _, _, _),
             .blockquote(let id, _, _),
             .table(let id, _, _, _),
             .thematicBreak(let id),
             .mathBlock(let id, _):
            return id
        }
    }
}

// MARK: - GitHub-Flavored Markdown Parser (`AntigravityMarkdownParser`)

/// Pure Swift 6 GitHub-Flavored Markdown (GFM) block + inline parser tailored for
/// Antigravity Desktop & Cloud Agent responses (headings, fenced/streaming code blocks,
/// nested lists, task items, GFM tables, `[!NOTE]` alerts, `` [`Symbol`](file:///...) `` links,
/// intraword-safe `snake_case`, and LaTeX math blocks).
public enum AntigravityMarkdownParser: Sendable {

    private static let asciiPunctuation: Set<Character> = Set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")

    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var nextId = 0
        return parseBlocks(from: markdown, nextId: &nextId)
    }

    // MARK: - Block Parsing

    private static func parseBlocks(from rawText: String, nextId: inout Int) -> [MarkdownBlock] {
        let normalized = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0
        var listIndentStack: [Int] = []

        while index < lines.count {
            let line = lines[index]
            let expanded = expandLeadingTabs(line)
            let leadingSpaces = countLeadingSpaces(expanded)
            let trimmedLead = String(expanded.dropFirst(leadingSpaces))
            let trimmed = trimmedLead.trimmingCharacters(in: .whitespaces)

            // 1. Blank line
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // 2. Fenced Code Block (``` or ~~~, 3+ chars, including streaming unclosed fences)
            if let fence = matchCodeFenceOpening(trimmedLead) {
                listIndentStack.removeAll()
                var codeLines: [String] = []
                index += 1
                while index < lines.count {
                    let candidateExpanded = expandLeadingTabs(lines[index])
                    let candidateTrimmed = candidateExpanded.trimmingCharacters(in: .whitespaces)
                    if isClosingCodeFence(candidateTrimmed, fenceChar: fence.char, minLength: fence.length) {
                        index += 1
                        break
                    }
                    let dedented = stripUpToLeadingSpaces(candidateExpanded, maxSpaces: leadingSpaces)
                    codeLines.append(dedented)
                    index += 1
                }
                let blockId = allocateId(&nextId)
                blocks.append(
                    .codeBlock(
                        id: blockId,
                        language: fence.language,
                        code: codeLines.joined(separator: "\n")
                    )
                )
                continue
            }

            // 3. Display Math Block (`$$ ... $$` or `\[ ... \]`)
            if trimmed.hasPrefix("$$") || trimmed.hasPrefix("\\[") {
                let closeMarker = trimmed.hasPrefix("$$") ? "$$" : "\\]"
                let afterOpen = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !afterOpen.isEmpty && afterOpen.hasSuffix(closeMarker) && afterOpen.count >= closeMarker.count {
                    listIndentStack.removeAll()
                    let inner = String(afterOpen.dropLast(closeMarker.count)).trimmingCharacters(in: .whitespaces)
                    if !inner.isEmpty {
                        blocks.append(.mathBlock(id: allocateId(&nextId), latex: inner))
                        index += 1
                        continue
                    }
                } else if afterOpen.isEmpty || !afterOpen.contains(closeMarker) {
                    listIndentStack.removeAll()
                    var mathLines: [String] = afterOpen.isEmpty ? [] : [afterOpen]
                    index += 1
                    while index < lines.count {
                        let mLine = lines[index]
                        let mTrim = mLine.trimmingCharacters(in: .whitespaces)
                        if mTrim == closeMarker {
                            index += 1
                            break
                        } else if mTrim.hasSuffix(closeMarker) {
                            let prefix = String(mTrim.dropLast(closeMarker.count)).trimmingCharacters(in: .whitespaces)
                            if !prefix.isEmpty { mathLines.append(prefix) }
                            index += 1
                            break
                        }
                        mathLines.append(mLine)
                        index += 1
                    }
                    blocks.append(.mathBlock(id: allocateId(&nextId), latex: mathLines.joined(separator: "\n")))
                    continue
                }
            }

            // 4. ATX Heading (`#` .. `######`)
            if leadingSpaces < 4, let heading = matchATXHeading(trimmedLead) {
                listIndentStack.removeAll()
                blocks.append(
                    .heading(
                        id: allocateId(&nextId),
                        level: heading.level,
                        inlines: parseInlines(heading.content)
                    )
                )
                index += 1
                continue
            }

            // 5. Thematic Break (`---`, `***`, `___`)
            if leadingSpaces < 4 && isThematicBreak(trimmed) {
                listIndentStack.removeAll()
                blocks.append(.thematicBreak(id: allocateId(&nextId)))
                index += 1
                continue
            }

            // 6. Blockquote & GitHub Alert (`> ...`, `> [!NOTE]`)
            if leadingSpaces < 4 && trimmedLead.hasPrefix(">") {
                listIndentStack.removeAll()
                var quoteLines: [String] = []
                while index < lines.count {
                    let qExpanded = expandLeadingTabs(lines[index])
                    let qSpaces = countLeadingSpaces(qExpanded)
                    let qTrimLead = String(qExpanded.dropFirst(qSpaces))
                    if qSpaces < 4 && qTrimLead.hasPrefix(">") {
                        var stripped = String(qTrimLead.dropFirst())
                        if stripped.first == " " {
                            stripped.removeFirst()
                        }
                        quoteLines.append(stripped)
                        index += 1
                    } else {
                        break
                    }
                }

                var detectedAlert: MarkdownAlertKind? = nil
                if let firstLine = quoteLines.first {
                    let firstTrim = firstLine.trimmingCharacters(in: .whitespaces)
                    for kind in MarkdownAlertKind.allCases {
                        let tag = "[!\(kind.rawValue)]"
                        if firstTrim.uppercased().hasPrefix(tag) {
                            detectedAlert = kind
                            let remainder = String(firstTrim.dropFirst(tag.count)).trimmingCharacters(in: .whitespaces)
                            if remainder.isEmpty {
                                quoteLines.removeFirst()
                            } else {
                                quoteLines[0] = remainder
                            }
                            break
                        }
                    }
                }

                let blockquoteId = allocateId(&nextId)
                let innerBlocks = parseBlocks(from: quoteLines.joined(separator: "\n"), nextId: &nextId)
                blocks.append(.blockquote(id: blockquoteId, alert: detectedAlert, blocks: innerBlocks))
                continue
            }

            // 7. GFM Table (`| col1 | col2 |` followed by delimiter row `| --- | :---: |`)
            if leadingSpaces < 4,
               index + 1 < lines.count,
               trimmed.contains("|"),
               let alignments = parseTableDelimiterRow(lines[index + 1]) {
                let headerCellsRaw = splitTableCells(trimmed)
                if !headerCellsRaw.isEmpty && headerCellsRaw.count == alignments.count {
                    listIndentStack.removeAll()
                    let headers = headerCellsRaw.map { parseInlines($0) }
                    index += 2
                    var rows: [[[MarkdownInline]]] = []
                    while index < lines.count {
                        let rowTrim = lines[index].trimmingCharacters(in: .whitespaces)
                        if rowTrim.isEmpty || !rowTrim.contains("|") {
                            break
                        }
                        if matchCodeFenceOpening(rowTrim) != nil || matchATXHeading(rowTrim) != nil || rowTrim.hasPrefix(">") {
                            break
                        }
                        var rawCells = splitTableCells(rowTrim)
                        if rawCells.count < headers.count {
                            rawCells.append(contentsOf: Array(repeating: "", count: headers.count - rawCells.count))
                        } else if rawCells.count > headers.count {
                            rawCells = Array(rawCells.prefix(headers.count))
                        }
                        rows.append(rawCells.map { parseInlines($0) })
                        index += 1
                    }
                    blocks.append(
                        .table(
                            id: allocateId(&nextId),
                            headers: headers,
                            alignments: alignments,
                            rows: rows
                        )
                    )
                    continue
                }
            }

            // 8. List Item (`- `, `* `, `+ `, `1. `, `1) `, `- [x] `, `- [ ] `)
            if let listMatch = matchListItem(trimmedLead) {
                let indentLevel = resolveListIndentLevel(spaces: leadingSpaces, stack: &listIndentStack)
                var itemLines: [String] = [listMatch.content]
                index += 1

                // Absorb indented continuation lines that aren't sub-lists or block openers
                while index < lines.count {
                    let nextRaw = lines[index]
                    let nextExpanded = expandLeadingTabs(nextRaw)
                    let nextSpaces = countLeadingSpaces(nextExpanded)
                    let nextTrimLead = String(nextExpanded.dropFirst(nextSpaces))
                    let nextTrim = nextTrimLead.trimmingCharacters(in: .whitespaces)

                    if nextTrim.isEmpty {
                        break
                    }
                    if matchCodeFenceOpening(nextTrimLead) != nil
                        || matchATXHeading(nextTrimLead) != nil
                        || isThematicBreak(nextTrim)
                        || nextTrimLead.hasPrefix(">")
                        || matchListItem(nextTrimLead) != nil {
                        break
                    }
                    if nextSpaces > leadingSpaces {
                        itemLines.append(nextTrim)
                        index += 1
                    } else {
                        break
                    }
                }

                let joinedContent = itemLines.joined(separator: "\n")
                blocks.append(
                    .listItem(
                        id: allocateId(&nextId),
                        indentLevel: indentLevel,
                        marker: listMatch.marker,
                        inlines: parseInlines(joinedContent)
                    )
                )
                continue
            }

            // 9. Paragraph (preserves GFM chat line breaks until blank line or block opener)
            listIndentStack.removeAll()
            var paragraphLines: [String] = [trimmed]
            index += 1
            while index < lines.count {
                let pExpanded = expandLeadingTabs(lines[index])
                let pSpaces = countLeadingSpaces(pExpanded)
                let pTrimLead = String(pExpanded.dropFirst(pSpaces))
                let pTrim = pTrimLead.trimmingCharacters(in: .whitespaces)

                if pTrim.isEmpty {
                    break
                }
                if matchCodeFenceOpening(pTrimLead) != nil
                    || pTrim.hasPrefix("$$")
                    || pTrim.hasPrefix("\\[")
                    || (pSpaces < 4 && matchATXHeading(pTrimLead) != nil)
                    || (pSpaces < 4 && isThematicBreak(pTrim))
                    || (pSpaces < 4 && pTrimLead.hasPrefix(">"))
                    || matchListItem(pTrimLead) != nil {
                    break
                }
                if pSpaces < 4,
                   index + 1 < lines.count,
                   pTrim.contains("|"),
                   let alignCheck = parseTableDelimiterRow(lines[index + 1]),
                   splitTableCells(pTrim).count == alignCheck.count {
                    break
                }
                paragraphLines.append(stripHardBreakSuffix(pTrimLead.trimmingCharacters(in: .whitespaces)))
                index += 1
            }
            if !paragraphLines.isEmpty {
                paragraphLines[0] = stripHardBreakSuffix(paragraphLines[0])
            }
            blocks.append(
                .paragraph(
                    id: allocateId(&nextId),
                    inlines: parseInlines(paragraphLines.joined(separator: "\n"))
                )
            )
        }

        return blocks
    }

    // MARK: - Inline Parsing

    public static func parseInlines(_ text: String) -> [MarkdownInline] {
        guard !text.isEmpty else { return [] }
        let chars = Array(text)
        return coalesceTextNodes(parseInlineSlice(chars, start: 0, end: chars.count))
    }

    private static func parseInlineSlice(_ chars: [Character], start: Int, end: Int) -> [MarkdownInline] {
        var result: [MarkdownInline] = []
        var i = start

        while i < end {
            let ch = chars[i]

            // 1. Newline -> softBreak
            if ch == "\n" {
                result.append(.softBreak)
                i += 1
                continue
            }

            // 2. Backslash escape (`\*`, `\_`, `\$`, `\[`, etc.) or `\( ... \)` inline math
            if ch == "\\" && i + 1 < end {
                let nextCh = chars[i + 1]
                if nextCh == "(" {
                    if let closeIdx = findSequence(chars, target: ["\\", ")"], from: i + 2, end: end, stopAtNewline: true) {
                        let latex = String(chars[(i + 2)..<closeIdx]).trimmingCharacters(in: .whitespaces)
                        if !latex.isEmpty {
                            result.append(.inlineMath(latex))
                            i = closeIdx + 2
                            continue
                        }
                    }
                }
                if asciiPunctuation.contains(nextCh) {
                    result.append(.text(String(nextCh)))
                    i += 2
                    continue
                }
            }

            // 3. Inline code span (1+ backticks, highest precedence)
            if ch == "`" {
                var tickCount = 0
                while i + tickCount < end && chars[i + tickCount] == "`" {
                    tickCount += 1
                }
                let contentStart = i + tickCount
                if let closeStart = findExactBacktickRun(chars, length: tickCount, from: contentStart, end: end) {
                    var codeStr = String(chars[contentStart..<closeStart])
                        .replacingOccurrences(of: "\n", with: " ")
                    if codeStr.count >= 2 && codeStr.first == " " && codeStr.last == " " && !codeStr.allSatisfy({ $0 == " " }) {
                        codeStr.removeFirst()
                        codeStr.removeLast()
                    }
                    result.append(.code(codeStr))
                    i = closeStart + tickCount
                    continue
                } else {
                    result.append(.text(String(repeating: "`", count: tickCount)))
                    i = contentStart
                    continue
                }
            }

            // 4. Link `[label](destination)` (supports nested `` [`Symbol`](file:///...) ``!)
            if ch == "[" || (ch == "!" && i + 1 < end && chars[i + 1] == "[") {
                let isImage = (ch == "!")
                let openBracket = isImage ? i + 1 : i
                if let closeBracket = findMatchingBracket(chars, openAt: openBracket, end: end),
                   closeBracket + 1 < end,
                   chars[closeBracket + 1] == "(",
                   let parsedDest = parseLinkDestination(chars, openParenAt: closeBracket + 1, end: end) {
                    let rawLabelSlice = parseInlineSlice(chars, start: openBracket + 1, end: closeBracket)
                    let labelNodes = coalesceTextNodes(rawLabelSlice)
                    let effectiveLabel: [MarkdownInline]
                    if labelNodes.isEmpty {
                        effectiveLabel = [.text(isImage ? "Image" : parsedDest.destination)]
                    } else if isImage {
                        effectiveLabel = [.text("🖼 ")] + labelNodes
                    } else {
                        effectiveLabel = labelNodes
                    }
                    result.append(.link(label: effectiveLabel, destination: parsedDest.destination))
                    i = parsedDest.nextIndex
                    continue
                }
            }

            // 5. Bare URL autolink (`https://...` or `http://...`)
            if (ch == "h" || ch == "H"),
               let bareURL = matchBareHTTPURL(chars, at: i, end: end) {
                result.append(.link(label: [.text(bareURL.url)], destination: bareURL.url))
                i = bareURL.nextIndex
                continue
            }

            // 6. Strikethrough (`~~...~~`)
            if ch == "~" && i + 1 < end && chars[i + 1] == "~" {
                let innerStart = i + 2
                if innerStart < end && !chars[innerStart].isWhitespace,
                   let closeIdx = findDelimiterOutsideCode(chars, delimiter: ["~", "~"], from: innerStart, end: end),
                   closeIdx > innerStart,
                   !chars[closeIdx - 1].isWhitespace {
                    let inner = coalesceTextNodes(parseInlineSlice(chars, start: innerStart, end: closeIdx))
                    result.append(.strikethrough(inner))
                    i = closeIdx + 2
                    continue
                }
            }

            // 7. Inline Math `$...$` (Pandoc/GFM non-whitespace boundary rules)
            if ch == "$" && !(i + 1 < end && chars[i + 1] == "$") {
                let innerStart = i + 1
                let prevIsDigit = (i > start && chars[i - 1].isNumber)
                if !prevIsDigit && innerStart < end && !chars[innerStart].isWhitespace,
                   let closeIdx = findClosingInlineMathDollar(chars, from: innerStart, end: end) {
                    let afterCloseIsDigit = (closeIdx + 1 < end && chars[closeIdx + 1].isNumber)
                    if !afterCloseIsDigit {
                        let latex = String(chars[innerStart..<closeIdx])
                        result.append(.inlineMath(latex))
                        i = closeIdx + 1
                        continue
                    }
                }
            }

            // 8. Emphasis & Strong (`***`, `**`, `*`, `___`, `__`, `_`)
            if ch == "*" || ch == "_" {
                var runLen = 0
                while i + runLen < end && chars[i + runLen] == ch {
                    runLen += 1
                }
                let prevChar: Character? = i > start ? chars[i - 1] : nil
                let afterRunIdx = i + runLen
                let nextChar: Character? = afterRunIdx < end ? chars[afterRunIdx] : nil

                // GFM intraword underscore protection: `mock_language_server` stays literal text
                let intrawordBlocked = (ch == "_")
                    && (prevChar.map(isWordChar) == true)
                    && (nextChar.map(isWordChar) == true || (i + 1 < end && isWordChar(chars[i + 1])))

                if !intrawordBlocked {
                    // Try 3-char strong+emphasis (`***text***`)
                    if runLen >= 3,
                       afterRunIdx < end,
                       !chars[afterRunIdx].isWhitespace,
                       let closeIdx = findEmphasisClose(chars, marker: ch, count: 3, from: afterRunIdx, end: end) {
                        let inner = coalesceTextNodes(parseInlineSlice(chars, start: afterRunIdx, end: closeIdx))
                        result.append(.strong([.emphasis(inner)]))
                        i = closeIdx + 3
                        continue
                    }

                    // Try 2-char strong (`**text**` / `__text__`)
                    if runLen == 2,
                       afterRunIdx < end,
                       !chars[afterRunIdx].isWhitespace,
                       let closeIdx = findEmphasisClose(chars, marker: ch, count: 2, from: afterRunIdx, end: end) {
                        let inner = coalesceTextNodes(parseInlineSlice(chars, start: afterRunIdx, end: closeIdx))
                        result.append(.strong(inner))
                        i = closeIdx + 2
                        continue
                    }

                    // Try 1-char emphasis (`*text*` / `_text_`)
                    if runLen == 1,
                       afterRunIdx < end,
                       !chars[afterRunIdx].isWhitespace,
                       let closeIdx = findEmphasisClose(chars, marker: ch, count: 1, from: afterRunIdx, end: end) {
                        let inner = coalesceTextNodes(parseInlineSlice(chars, start: afterRunIdx, end: closeIdx))
                        result.append(.emphasis(inner))
                        i = closeIdx + 1
                        continue
                    }
                }

                result.append(.text(String(repeating: String(ch), count: runLen)))
                i = afterRunIdx
                continue
            }

            // 9. Plain character
            result.append(.text(String(ch)))
            i += 1
        }

        return result
    }

    // MARK: - Block Helpers

    private static func allocateId(_ counter: inout Int) -> Int {
        defer { counter += 1 }
        return counter
    }

    private static func expandLeadingTabs(_ line: String) -> String {
        var prefix = ""
        var idx = line.startIndex
        while idx < line.endIndex {
            let c = line[idx]
            if c == "\t" {
                prefix.append("    ")
                idx = line.index(after: idx)
            } else if c == " " {
                prefix.append(" ")
                idx = line.index(after: idx)
            } else {
                break
            }
        }
        return prefix + line[idx...]
    }

    private static func countLeadingSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 } else { break }
        }
        return count
    }

    private static func stripUpToLeadingSpaces(_ line: String, maxSpaces: Int) -> String {
        guard maxSpaces > 0 else { return line }
        var removed = 0
        var idx = line.startIndex
        while idx < line.endIndex && removed < maxSpaces && line[idx] == " " {
            removed += 1
            idx = line.index(after: idx)
        }
        return String(line[idx...])
    }

    private static func stripHardBreakSuffix(_ line: String) -> String {
        if line.hasSuffix("\\") && !line.hasSuffix("\\\\") {
            return String(line.dropLast())
        }
        return line
    }

    private static func matchCodeFenceOpening(_ trimmedLead: String) -> (char: Character, length: Int, language: String?)? {
        guard let first = trimmedLead.first, first == "`" || first == "~" else { return nil }
        var len = 0
        for ch in trimmedLead {
            if ch == first { len += 1 } else { break }
        }
        guard len >= 3 else { return nil }
        let info = String(trimmedLead.dropFirst(len)).trimmingCharacters(in: .whitespaces)
        // Backtick info strings cannot contain backticks (prevents matching inline ```` ```foo``` ```` on one line)
        if first == "`" && info.contains("`") {
            return nil
        }
        let langToken = info.split(whereSeparator: \.isWhitespace).first.map(String.init)
        return (first, len, (langToken?.isEmpty == false) ? langToken : nil)
    }

    private static func isClosingCodeFence(_ trimmed: String, fenceChar: Character, minLength: Int) -> Bool {
        guard trimmed.count >= minLength else { return false }
        var len = 0
        for ch in trimmed {
            if ch == fenceChar { len += 1 } else { return false }
        }
        return len >= minLength
    }

    private static func matchATXHeading(_ trimmedLead: String) -> (level: Int, content: String)? {
        guard trimmedLead.first == "#" else { return nil }
        var level = 0
        for ch in trimmedLead {
            if ch == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level) else { return nil }
        let rest = String(trimmedLead.dropFirst(level))
        guard rest.isEmpty || rest.first?.isWhitespace == true else { return nil }
        var cleaned = rest.trimmingCharacters(in: .whitespaces)
        // Strip optional closing ` ###` sequence when preceded by whitespace
        while cleaned.last == "#" {
            let candidate = String(cleaned.dropLast())
            if candidate.isEmpty || candidate.last?.isWhitespace == true {
                cleaned = candidate.trimmingCharacters(in: .whitespaces)
            } else {
                break
            }
        }
        return (level, cleaned)
    }

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        guard let first = trimmed.first, first == "-" || first == "*" || first == "_" else {
            return false
        }
        var markerCount = 0
        for ch in trimmed {
            if ch == first {
                markerCount += 1
            } else if ch == " " || ch == "\t" {
                continue
            } else {
                return false
            }
        }
        return markerCount >= 3
    }

    private static func matchListItem(_ trimmedLead: String) -> (marker: MarkdownListMarker, content: String)? {
        guard !trimmedLead.isEmpty else { return nil }
        let chars = Array(trimmedLead)

        // Unordered (`- `, `* `, `+ `) & Task list (`- [ ] `, `- [x] `)
        if (chars[0] == "-" || chars[0] == "*" || chars[0] == "+"),
           chars.count >= 2,
           chars[1].isWhitespace {
            // Do not mistake `* * *` or `- - -` thematic break for a bullet item
            if isThematicBreak(trimmedLead.trimmingCharacters(in: .whitespaces)) {
                return nil
            }
            let afterBullet = String(chars.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if afterBullet.count >= 3 && afterBullet.hasPrefix("[") {
                let abChars = Array(afterBullet)
                if abChars.count >= 3 && abChars[2] == "]" && (abChars.count == 3 || abChars[3].isWhitespace) {
                    let box = abChars[1]
                    if box == " " || box == "x" || box == "X" {
                        let taskBody = abChars.count > 4
                            ? String(abChars.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                            : ""
                        return (.task(checked: box != " "), taskBody)
                    }
                }
            }
            return (.bullet, afterBullet)
        }

        // Ordered (`1. `, `2) `, up to 9 digits per CommonMark)
        var digitCount = 0
        while digitCount < chars.count && digitCount < 9 && chars[digitCount].isASCII && chars[digitCount].isNumber {
            digitCount += 1
        }
        if digitCount > 0,
           digitCount + 1 < chars.count,
           (chars[digitCount] == "." || chars[digitCount] == ")"),
           chars[digitCount + 1].isWhitespace {
            let numberStr = String(chars[0..<digitCount])
            if let num = Int(numberStr) {
                let body = String(chars.dropFirst(digitCount + 2)).trimmingCharacters(in: .whitespaces)
                return (.ordered(num), body)
            }
        }

        return nil
    }

    private static func resolveListIndentLevel(spaces: Int, stack: inout [Int]) -> Int {
        if spaces <= 1 {
            stack = [0]
            return 0
        }
        if stack.isEmpty {
            stack = [0, spaces]
            return 1
        }
        while stack.count > 1 && stack[stack.count - 1] > spaces {
            stack.removeLast()
        }
        if let last = stack.last, spaces > last {
            stack.append(spaces)
        }
        return min(4, max(0, stack.count - 1))
    }

    private static func parseTableDelimiterRow(_ rawLine: String) -> [MarkdownTableAlignment]? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") && trimmed.contains("-") else { return nil }
        let cells = splitTableCells(trimmed)
        guard !cells.isEmpty else { return nil }

        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { return nil }
            let startsColon = c.hasPrefix(":")
            let endsColon = c.hasSuffix(":")
            var core = c
            if startsColon { core.removeFirst() }
            if endsColon && !core.isEmpty { core.removeLast() }
            guard core.count >= 1 && core.allSatisfy({ $0 == "-" }) else {
                return nil
            }
            if startsColon && endsColon {
                alignments.append(.center)
            } else if endsColon {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }
        return alignments
    }

    private static func splitTableCells(_ rawLine: String) -> [String] {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("|") {
            line.removeFirst()
        }
        if line.hasSuffix("|") && !line.hasSuffix("\\|") {
            line.removeLast()
        }

        let chars = Array(line)
        var cells: [String] = []
        var current = ""
        var i = 0
        var inCodeTicks = 0

        while i < chars.count {
            let ch = chars[i]
            if ch == "\\" && i + 1 < chars.count && inCodeTicks == 0 {
                if chars[i + 1] == "|" {
                    current.append("|")
                    i += 2
                    continue
                }
                current.append(ch)
                current.append(chars[i + 1])
                i += 2
                continue
            }
            if ch == "`" {
                var ticks = 0
                while i + ticks < chars.count && chars[i + ticks] == "`" {
                    ticks += 1
                }
                if inCodeTicks == 0 {
                    inCodeTicks = ticks
                } else if ticks == inCodeTicks {
                    inCodeTicks = 0
                }
                current.append(String(repeating: "`", count: ticks))
                i += ticks
                continue
            }
            if ch == "|" && inCodeTicks == 0 {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                i += 1
                continue
            }
            current.append(ch)
            i += 1
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    // MARK: - Inline Helpers

    private static func isWordChar(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber
    }

    private static func coalesceTextNodes(_ nodes: [MarkdownInline]) -> [MarkdownInline] {
        var out: [MarkdownInline] = []
        for node in nodes {
            if case .text(let s) = node, let last = out.last, case .text(let prev) = last {
                out[out.count - 1] = .text(prev + s)
            } else {
                out.append(node)
            }
        }
        return out
    }

    private static func findExactBacktickRun(_ chars: [Character], length: Int, from: Int, end: Int) -> Int? {
        var i = from
        while i < end {
            if chars[i] == "`" {
                var count = 0
                while i + count < end && chars[i + count] == "`" {
                    count += 1
                }
                if count == length {
                    return i
                }
                i += count
            } else {
                i += 1
            }
        }
        return nil
    }

    private static func findMatchingBracket(_ chars: [Character], openAt: Int, end: Int) -> Int? {
        var depth = 0
        var i = openAt
        while i < end {
            let ch = chars[i]
            if ch == "\n" { return nil }
            if ch == "\\" && i + 1 < end {
                i += 2
                continue
            }
            if ch == "`" {
                var ticks = 0
                while i + ticks < end && chars[i + ticks] == "`" { ticks += 1 }
                if let close = findExactBacktickRun(chars, length: ticks, from: i + ticks, end: end) {
                    i = close + ticks
                    continue
                }
                i += ticks
                continue
            }
            if ch == "[" {
                depth += 1
            } else if ch == "]" {
                depth -= 1
                if depth == 0 {
                    return i
                }
            }
            i += 1
        }
        return nil
    }

    private static func parseLinkDestination(
        _ chars: [Character],
        openParenAt: Int,
        end: Int
    ) -> (destination: String, nextIndex: Int)? {
        var i = openParenAt + 1
        while i < end && (chars[i] == " " || chars[i] == "\t") {
            i += 1
        }
        guard i < end else { return nil }

        // Angle-bracketed destination: `[label](<file:///path with spaces>)`
        if chars[i] == "<" {
            i += 1
            let destStart = i
            while i < end && chars[i] != ">" && chars[i] != "\n" {
                i += 1
            }
            guard i < end && chars[i] == ">" else { return nil }
            let dest = String(chars[destStart..<i])
            i += 1
            while i < end && chars[i] != ")" && chars[i] != "\n" {
                i += 1
            }
            guard i < end && chars[i] == ")" else { return nil }
            return (dest, i + 1)
        }

        let destStart = i
        var parenDepth = 0
        while i < end {
            let ch = chars[i]
            if ch == "\n" { return nil }
            if ch == "\\" && i + 1 < end {
                i += 2
                continue
            }
            if ch == "(" {
                parenDepth += 1
            } else if ch == ")" {
                if parenDepth == 0 {
                    var rawDest = String(chars[destStart..<i]).trimmingCharacters(in: .whitespaces)
                    // Strip optional trailing `"title"` if separated by whitespace
                    if rawDest.hasSuffix("\""),
                       let quoteStart = rawDest.dropLast().lastIndex(of: "\""),
                       quoteStart > rawDest.startIndex {
                        let beforeQuote = rawDest[..<quoteStart]
                        if beforeQuote.last?.isWhitespace == true {
                            rawDest = beforeQuote.trimmingCharacters(in: .whitespaces)
                        }
                    }
                    return (rawDest, i + 1)
                }
                parenDepth -= 1
            }
            i += 1
        }
        return nil
    }

    private static func matchBareHTTPURL(_ chars: [Character], at start: Int, end: Int) -> (url: String, nextIndex: Int)? {
        let remaining = end - start
        guard remaining >= 10 else { return nil }
        let prefix8 = String(chars[start..<min(end, start + 8)]).lowercased()
        guard prefix8.hasPrefix("https://") || prefix8.hasPrefix("http://") else { return nil }
        if start > 0 {
            let prev = chars[start - 1]
            if prev.isLetter || prev.isNumber || prev == "/" || prev == "(" || prev == "[" {
                return nil
            }
        }

        var i = start
        while i < end {
            let ch = chars[i]
            if ch.isWhitespace || ch == "<" || ch == ">" || ch == "\"" || ch == "`" {
                break
            }
            i += 1
        }
        // Trim trailing sentence punctuation (`.,;:!?)]}。，；！）`)
        let trailingPunct: Set<Character> = Set(".,;:!?)]}。，；：！？）")
        while i > start + 8 && trailingPunct.contains(chars[i - 1]) {
            i -= 1
        }
        guard i > start + 8 else { return nil }
        return (String(chars[start..<i]), i)
    }

    private static func findSequence(
        _ chars: [Character],
        target: [Character],
        from: Int,
        end: Int,
        stopAtNewline: Bool
    ) -> Int? {
        guard !target.isEmpty && from + target.count <= end else { return nil }
        var i = from
        while i + target.count <= end {
            if stopAtNewline && chars[i] == "\n" { return nil }
            var matched = true
            for offset in 0..<target.count {
                if chars[i + offset] != target[offset] {
                    matched = false
                    break
                }
            }
            if matched { return i }
            i += 1
        }
        return nil
    }

    private static func findDelimiterOutsideCode(
        _ chars: [Character],
        delimiter: [Character],
        from: Int,
        end: Int
    ) -> Int? {
        var i = from
        while i + delimiter.count <= end {
            let ch = chars[i]
            if ch == "\\" && i + 1 < end {
                i += 2
                continue
            }
            if ch == "`" {
                var ticks = 0
                while i + ticks < end && chars[i + ticks] == "`" { ticks += 1 }
                if let close = findExactBacktickRun(chars, length: ticks, from: i + ticks, end: end) {
                    i = close + ticks
                    continue
                }
                i += ticks
                continue
            }
            if ch == "[",
               let closeBracket = findMatchingBracket(chars, openAt: i, end: end),
               closeBracket + 1 < end,
               chars[closeBracket + 1] == "(",
               let dest = parseLinkDestination(chars, openParenAt: closeBracket + 1, end: end) {
                i = dest.nextIndex
                continue
            }
            var matched = true
            for offset in 0..<delimiter.count {
                if chars[i + offset] != delimiter[offset] {
                    matched = false
                    break
                }
            }
            if matched {
                return i
            }
            i += 1
        }
        return nil
    }

    private static func findClosingInlineMathDollar(_ chars: [Character], from: Int, end: Int) -> Int? {
        var i = from
        while i < end {
            let ch = chars[i]
            if ch == "\n" || ch == "`" { return nil }
            if ch == "\\" && i + 1 < end {
                i += 2
                continue
            }
            if ch == "$" {
                if i > from && !chars[i - 1].isWhitespace {
                    return i
                }
                return nil
            }
            i += 1
        }
        return nil
    }

    private static func findEmphasisClose(
        _ chars: [Character],
        marker: Character,
        count: Int,
        from: Int,
        end: Int
    ) -> Int? {
        var i = from
        while i + count <= end {
            let ch = chars[i]
            if ch == "\\" && i + 1 < end {
                i += 2
                continue
            }
            if ch == "`" {
                var ticks = 0
                while i + ticks < end && chars[i + ticks] == "`" { ticks += 1 }
                if let close = findExactBacktickRun(chars, length: ticks, from: i + ticks, end: end) {
                    i = close + ticks
                    continue
                }
                i += ticks
                continue
            }
            if ch == "[",
               let closeBracket = findMatchingBracket(chars, openAt: i, end: end),
               closeBracket + 1 < end,
               chars[closeBracket + 1] == "(",
               let dest = parseLinkDestination(chars, openParenAt: closeBracket + 1, end: end) {
                i = dest.nextIndex
                continue
            }
            if ch == marker {
                var run = 0
                while i + run < end && chars[i + run] == marker {
                    run += 1
                }
                if run == count && i > from && !chars[i - 1].isWhitespace {
                    if marker == "_" {
                        let afterIdx = i + count
                        if afterIdx < end && isWordChar(chars[afterIdx]) {
                            i += run
                            continue
                        }
                    }
                    return i
                }
                // Also allow closing `count` inside a longer run only if `count >= 2` and `run >= 3`
                if count == 2 && run == 3 && i > from && !chars[i - 1].isWhitespace {
                    return i + 1
                }
                i += run
                continue
            }
            i += 1
        }
        return nil
    }
}
