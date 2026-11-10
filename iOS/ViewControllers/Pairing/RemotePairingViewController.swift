import SwiftUI
import AntigravityData

/// Settings & Host Pairing controller (`RemotePairingViewController`) for linking
/// local `MacBook Pro` Remote Control Connect-RPC hosts or Cloud sandbox credentials.
public struct RemotePairingViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public var onConnected: (() -> Void)?

    @State private var manualHostInput: String = "https://antigravity.google.com/r/macbook-pro-local"
    @State private var manualCSRFToken: String = "csrf-session-token-verified"
    @State private var isShowingManualEntry: Bool = false

    public init(
        store: AntigravitySessionStore,
        onConnected: (() -> Void)? = nil
    ) {
        self.store = store
        self.onConnected = onConnected
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings & Hosts")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                    Text("Pair MacBook Pro Remote Control QR or manage Cloud sandboxes")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
                    .frame(height: 210)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                    )
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 52, weight: .light))
                                .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                            Text("Connected: MacBook Pro · Local Connect-RPC")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Text("SHA256: 9F:4C:18:E2:77:AA:04:19 · 18ms")
                                .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                                .foregroundStyle(UEChromePalette.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(16)
                    )
                    .accessibilityIdentifier("qr-viewfinder")

                if isShowingManualEntry {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Host URL or QR Link", text: $manualHostInput)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        TextField("x-codeium-csrf-token (Direct Mode)", text: $manualCSRFToken)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Button {
                    onConnected?()
                } label: {
                    Text("Connect via Google Cloud Relay")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AntigravityTheme.accentPeriwinkle)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-connect-relay")

                Button {
                    onConnected?()
                } label: {
                    Text("Connect via Direct LAN / Tailscale")
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(UEChromePalette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AntigravityTheme.surfaceCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-connect-direct")

                Button {
                    isShowingManualEntry.toggle()
                } label: {
                    Text(isShowingManualEntry ? "Hide Manual Endpoint Config" : "Configure Manual Host / CSRF Token")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AntigravityTheme.canvasObsidian)
    }
}
