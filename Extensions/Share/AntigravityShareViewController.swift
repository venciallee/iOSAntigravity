import Foundation
import SwiftUI
import AntigravityData

/// Credential-free Share Extension (`AntigravityShare`) that writes shared URLs, screenshots,
/// or stack traces into the App Group durable outbox and wakes the main app via `antigravity://share/<id>`.
public struct AntigravityShareSheetView: View {
    public var sharedText: String
    public var targetHostName: String
    public var targetWorkspaceName: String

    public init(
        sharedText: String,
        targetHostName: String = "MacBook Pro",
        targetWorkspaceName: String = "ledger-svc"
    ) {
        self.sharedText = sharedText
        self.targetHostName = targetHostName
        self.targetWorkspaceName = targetWorkspaceName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Send to Antigravity")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                Spacer()
                Text("\(targetWorkspaceName) · \(targetHostName)")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.inkSecondary)
            }

            Text(sharedText)
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkLabel)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
    }
}
