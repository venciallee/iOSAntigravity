import SwiftUI
import AntigravityData
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Settings & Host Pairing controller (`RemotePairingViewController`) for authenticating against:
/// 1. Official Google Cloud Remote Control Relay (`ASWebAuthenticationSession` OAuth + `/r/<instance-id>`)
/// 2. Direct Mac `language_server` or `mac-companion-bridge.py` over LAN / Tailscale (`x-codeium-csrf-token` + TLS Pin)
public struct RemotePairingViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public var onConnected: (() -> Void)?

    @State private var manualHostInput: String = "http://127.0.0.1:8787"
    @State private var manualCSRFToken: String = ""
    @State private var manualCertSHA256: String = ""
    @State private var relayInstanceInput: String = "https://antigravity.google.com/r/macbook-pro-local"
    @State private var isShowingManualEntry: Bool = true

    public init(
        store: AntigravitySessionStore,
        onConnected: (() -> Void)? = nil
    ) {
        self.store = store
        self.onConnected = onConnected
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings & Hosts")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                    Text("Sign in via Google Cloud Relay or pair directly with Mac Companion Bridge")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }

                // Live Connection Status & QR Pairing Card
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
                    .frame(minHeight: 184)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                store.isLiveBackendConnected
                                    ? AntigravityTheme.statusDone.opacity(0.45)
                                    : UEChromePalette.cardBorder,
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: store.isLiveBackendConnected ? "checkmark.shield.fill" : "qrcode.viewfinder")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(
                                    store.isLiveBackendConnected
                                        ? AntigravityTheme.statusDone
                                        : AntigravityTheme.accentPeriwinkle
                                )

                            Text(
                                store.isLiveBackendConnected
                                    ? "Live Backend: \(store.activeHost.hostname)"
                                    : store.connectionStatusText
                            )
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)

                            Text(
                                store.isLiveBackendConnected
                                    ? "\(store.activeHost.endpointURL.absoluteString) · \(store.lastPingLatencyMs ?? store.activeHost.latencyMs)ms · \(store.summaries.count) sessions"
                                    : "Run `python3 scripts/mac-companion-bridge.py` on your Mac or scan Remote Control QR"
                            )
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        }
                        .padding(16)
                    )
                    .accessibilityIdentifier("qr-viewfinder")

                if let errorText = store.connectionErrorText, !errorText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AntigravityTheme.statusError)
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AntigravityTheme.statusError)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AntigravityTheme.statusError.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if isShowingManualEntry {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DIRECT MAC / COMPANION BRIDGE")
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(UEChromePalette.textMuted)

                        TextField("http://<mac-ip>:8787 or antigravity://pair?...", text: $manualHostInput)
                            .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("input-host-url")

                        TextField("x-codeium-csrf-token (printed by bridge or ps aux)", text: $manualCSRFToken)
                            .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("input-csrf-token")

                        TextField("Optional TLS SHA-256 Pin (leave blank for LAN TOFU)", text: $manualCertSHA256)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                // Button 1: Direct LAN / Tailscale / Companion Bridge Handshake
                Button {
                    Task {
                        let ok: Bool
                        if manualHostInput.lowercased().hasPrefix("antigravity://") {
                            ok = await store.connectWithPairingURI(manualHostInput, fallbackCookie: manualCSRFToken)
                        } else {
                            ok = await store.connectDirectLAN(
                                endpointURLString: manualHostInput,
                                csrfToken: manualCSRFToken,
                                certSHA256: manualCertSHA256.isEmpty ? nil : manualCertSHA256
                            )
                        }
                        if ok {
                            onConnected?()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if store.isConnectingToBackend {
                            ProgressView()
                                .tint(UEChromePalette.inkOnPrimaryCTA)
                        }
                        Text(store.isConnectingToBackend ? "Verifying Connect-RPC..." : "Connect via Direct LAN / Tailscale")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AntigravityTheme.accentPeriwinkle)
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.isConnectingToBackend)
                .accessibilityIdentifier("btn-connect-direct")

                // Button 2: Google Cloud Relay OAuth (`ASWebAuthenticationSession`)
                Button {
                    startCloudRelayOAuthLogin()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Sign in via Google Cloud Relay")
                            .font(.system(size: 15.5, weight: .medium))
                    }
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
                .accessibilityIdentifier("btn-connect-relay")

                HStack(spacing: 12) {
                    Button {
                        isShowingManualEntry.toggle()
                    } label: {
                        Text(isShowingManualEntry ? "Hide Endpoint Fields" : "Configure Endpoint / CSRF")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .buttonStyle(.plain)

                    if store.isLiveBackendConnected {
                        Button {
                            Task {
                                await store.disconnectBackendAndClearKeychain()
                            }
                        } label: {
                            Text("Disconnect Host")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(AntigravityTheme.statusError)
                                .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    private func startCloudRelayOAuthLogin() {
        #if canImport(AuthenticationServices) && os(iOS)
        guard let authURL = URL(string: relayInstanceInput) else { return }
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "antigravity"
        ) { callbackURL, error in
            guard error == nil, let callbackURL else { return }
            let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            let sessionCookie = comps?.queryItems?.first(where: { $0.name == "session" || $0.name == "cookie" })?.value ?? ""
            Task { @MainActor in
                let ok = await store.connectCloudRelay(
                    relayURLString: relayInstanceInput,
                    sessionCookie: sessionCookie
                )
                if ok {
                    onConnected?()
                }
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.start()
        #else
        Task {
            let ok = await store.connectCloudRelay(
                relayURLString: relayInstanceInput,
                sessionCookie: manualCSRFToken
            )
            if ok {
                onConnected?()
            }
        }
        #endif
    }
}
