import SwiftUI
import AntigravityData

/// State `S01_PAIRING_QR`: Scans the Antigravity Desktop Remote Control QR code
/// (`https://antigravity.google.com/r/lt74xt6l0m-golden-star`) or connects directly via LAN/Tailscale.
public struct RemotePairingViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text("Pair Antigravity Host")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AntigravityTheme.inkReading)

            Text("Scan Settings → Application → Remote Control QR code")
                .font(AntigravityTheme.TypographyTier.process.font)
                .foregroundStyle(AntigravityTheme.inkSecondary)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AntigravityTheme.surfaceElevated)
                .frame(height: 240)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(AntigravityTheme.accentPrimary)
                        Text("Detected: \(store.activeHost.hostname) (\(store.activeHost.version))")
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                    }
                )
                .accessibilityIdentifier("qr-viewfinder")

            Button(action: {}) {
                Text("Connect via Google Cloud Relay")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .background(AntigravityTheme.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("btn-connect-relay")

            Button(action: {}) {
                Text("Connect via Direct LAN / Tailscale")
                    .font(AntigravityTheme.TypographyTier.chrome.font)
                    .foregroundStyle(AntigravityTheme.inkLabel)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .background(AntigravityTheme.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("btn-connect-direct")
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
    }
}
