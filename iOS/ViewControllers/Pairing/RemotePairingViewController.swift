import SwiftUI
import AntigravityData

/// State `S01_PAIRING_QR`: Scans the Antigravity Desktop Remote Control QR code
/// (`https://antigravity.google.com/r/lt74xt6l0m-golden-star`) or connects directly via LAN/Tailscale.
public struct RemotePairingViewController: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var manualHostInput: String = "https://antigravity.google.com/r/lt74xt6l0m-golden-star"
    @State private var manualCSRFToken: String = "csrf-golden-star-session-token"
    @State private var isShowingManualEntry: Bool = false

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pair Antigravity Host")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                    Text("Scan Settings → Application → Remote Control QR code")
                        .font(AntigravityTheme.TypographyTier.process.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }
                Spacer()
            }

            // QR Viewfinder & Discovered Host Card
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AntigravityTheme.surfaceElevated)
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(AntigravityTheme.accentPrimary)
                        Text("Detected: \(store.activeHost.hostname) (\(store.activeHost.version))")
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                        Text(store.activeHost.certificateFingerprintSHA256)
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    .padding(16)
                )
                .accessibilityIdentifier("qr-viewfinder")

            if isShowingManualEntry {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Host URL or QR Link", text: $manualHostInput)
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(12)
                        .background(AntigravityTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    TextField("x-codeium-csrf-token (Direct Mode)", text: $manualCSRFToken)
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(12)
                        .background(AntigravityTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Button {
                if let parsed = RemoteHostInstance.parseRemoteControlQR(urlString: manualHostInput) {
                    store.activeHost.instanceId = parsed.instanceId
                    store.activeHost.hostname = parsed.instanceId
                }
                store.activeHost.channel = .cloudRelay
                store.activeHost.isOnline = true
                store.currentRoute = .workspaceHome
            } label: {
                Text("Connect via Google Cloud Relay")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .background(AntigravityTheme.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("btn-connect-relay")

            Button {
                store.activeHost.channel = .directHost
                store.activeHost.isOnline = true
                store.currentRoute = .workspaceHome
            } label: {
                Text("Connect via Direct LAN / Tailscale")
                    .font(AntigravityTheme.TypographyTier.chrome.font)
                    .foregroundStyle(AntigravityTheme.inkLabel)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .background(AntigravityTheme.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("btn-connect-direct")

            Button {
                isShowingManualEntry.toggle()
            } label: {
                Text(isShowingManualEntry ? "Hide Manual Endpoint Config" : "Configure Manual Host / CSRF Token")
                    .font(AntigravityTheme.TypographyTier.process.font)
                    .foregroundStyle(AntigravityTheme.accentSecondary)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
    }
}
