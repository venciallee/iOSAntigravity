import SwiftUI
import AntigravityData
#if canImport(UIKit)
import UIKit
#endif

/// Settings & Host Pairing controller (`RemotePairingViewController`) for authenticating against:
/// 1. **Primary (Recommended)**: Official Antigravity Remote Control QR (`https://antigravity.google.com/r/<id>`)
///    over Google Cloud Relay (`devtools_jetski_boq_api_proto.ApiService`) — works across Wi-Fi & 5G with zero bridge/Tailscale.
/// 2. **Optional Fallback**: Direct Mac `language_server` or `mac-companion-bridge.py` over LAN / Tailscale (`x-codeium-csrf-token`).
public struct RemotePairingViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public var externalScannerTrigger: Binding<Bool>?
    public var onConnected: (() -> Void)?

    @State private var relayInstanceInput: String = ""
    @State private var manualCookieInput: String = ""
    @State private var manualAuthUserInput: String = ""
    @State private var manualHostInput: String = "http://127.0.0.1:8787"
    @State private var manualCSRFToken: String = ""
    @State private var manualCertSHA256: String = ""

    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingGoogleSignIn: Bool = false
    @State private var isShowingCookieOverride: Bool = false
    @State private var isShowingDirectLAN: Bool = false

    public init(
        store: AntigravitySessionStore,
        externalScannerTrigger: Binding<Bool>? = nil,
        onConnected: (() -> Void)? = nil
    ) {
        self.store = store
        self.externalScannerTrigger = externalScannerTrigger
        self.onConnected = onConnected
    }

    public var body: some View {
        let isOnlineConnected = store.isLiveBackendConnected && store.activeHost.isOnline
        let isOfflinePaired = store.hasPairedBackend && (!store.isLiveBackendConnected || !store.activeHost.isOnline)

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings & Remote Control")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                    Text("Scan Antigravity Desktop's official Remote Control QR code — works over Wi-Fi & 5G")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }

                // Hero Status & Instant Scan Card
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
                    .frame(minHeight: 178)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                isOnlineConnected
                                    ? AntigravityTheme.statusDone.opacity(0.45)
                                    : (isOfflinePaired ? AntigravityTheme.statusError.opacity(0.50) : UEChromePalette.cardBorder),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        VStack(spacing: 10) {
                            Image(
                                systemName: isOnlineConnected
                                    ? "checkmark.shield.fill"
                                    : (isOfflinePaired ? "wifi.slash" : "qrcode.viewfinder")
                            )
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(
                                isOnlineConnected
                                    ? AntigravityTheme.statusDone
                                    : (isOfflinePaired ? AntigravityTheme.statusError : AntigravityTheme.accentPeriwinkle)
                            )

                            Text(
                                isOnlineConnected
                                    ? "Connected: \(store.activeHost.hostname)"
                                    : (isOfflinePaired ? "Host Offline: \(store.activeHost.hostname)" : "Tap to Scan Remote Control QR")
                            )
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)

                            Text(
                                isOnlineConnected
                                    ? "\(store.activeHost.channel.displayName) · \(store.lastPingLatencyMs ?? store.activeHost.latencyMs)ms · \(store.summaries.count) sessions"
                                    : (isOfflinePaired
                                        ? "\(store.activeHost.endpointURL.absoluteString) · Auto-reconnecting"
                                        : "Open Antigravity on Mac/PC → Remote Control → Scan `antigravity.google.com/r/...` (No bridge or Tailscale needed)")
                            )
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)

                            if isOfflinePaired {
                                Button {
                                    Task {
                                        await store.refreshWorkspacesAndSummaries()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12.5, weight: .semibold))
                                        Text("Reconnect Now")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 36)
                                    .background(Capsule().fill(UEChromePalette.surfacePill))
                                    .overlay(Capsule().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("btn-retry-connection")
                            }
                        }
                        .padding(16)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture {
                        if !isOnlineConnected && !isOfflinePaired {
                            isShowingQRScanner = true
                        }
                    }
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

                // Official Remote Control QR / Cloud Relay Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("OFFICIAL REMOTE CONTROL (CLOUD RELAY)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(UEChromePalette.textMuted)
                        Spacer()
                        #if canImport(UIKit)
                        Button {
                            if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !clip.isEmpty {
                                relayInstanceInput = clip
                            }
                        } label: {
                            Label("Paste Link", systemImage: "doc.on.clipboard")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }

                    TextField(
                        "https://antigravity.google.com/r/<id> (or leave blank to auto-discover)",
                        text: $relayInstanceInput
                    )
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(UEChromePalette.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("input-relay-url")

                    // Primary CTA 1: Scan QR Camera / Screenshot
                    Button {
                        isShowingQRScanner = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Scan Remote Control QR Code")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AntigravityTheme.accentPeriwinkle)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isConnectingToBackend)
                    .accessibilityIdentifier("btn-scan-remote-qr")

                    // Primary CTA 2: Sign in with Google & Connect via Official Cloud Relay
                    Button {
                        Task {
                            await initiateCloudRelayConnection(targetInput: relayInstanceInput)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isConnectingToBackend {
                                ProgressView()
                                    .tint(UEChromePalette.textPrimary)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(
                                store.isConnectingToBackend
                                    ? "Connecting to Antigravity Cloud Relay..."
                                    : "Sign in with Google & Pair Host"
                            )
                            .font(.system(size: 15.5, weight: .semibold))
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
                    .disabled(store.isConnectingToBackend)
                    .accessibilityIdentifier("btn-connect-relay")
                }

                // Discovered Cloud Relay Desktop Instances (when >0 available on Google account)
                if !store.availableRelayInstances.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR GOOGLE ACCOUNT INSTANCES (AUTHUSER \(store.activeAuthUser))")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.7)
                            .foregroundStyle(UEChromePalette.textMuted)

                        ForEach(store.availableRelayInstances) { inst in
                            let isSelected = (store.activeHost.instanceId == inst.uuid)
                            Button {
                                Task {
                                    if let cached = await store.loadSavedSessionCookie() {
                                        let ok = await store.connectCloudRelay(
                                            relayURLString: "https://antigravity.google.com/r/\(inst.uuid)",
                                            sessionCookie: cached.cookie,
                                            authUser: store.activeAuthUser,
                                            resolvedInstanceUuid: inst.uuid,
                                            hostName: inst.name
                                        )
                                        if ok {
                                            onConnected?()
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(inst.status.isReachable ? AntigravityTheme.statusDone : UEChromePalette.textMuted)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(inst.name)
                                            .font(.system(size: 14.5, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                        Text("\(inst.status.badgeText) · \(inst.version) · \(String(inst.uuid.prefix(8)))…")
                                            .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                                            .foregroundStyle(UEChromePalette.textSecondary)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                                    }
                                }
                                .padding(12)
                                .background(AntigravityTheme.surfaceCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? AntigravityTheme.accentPeriwinkle.opacity(0.5) : UEChromePalette.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Optional Simulator / DevTools Cookie Override + Direct LAN Fallback Toggles
                HStack(spacing: 12) {
                    Button {
                        isShowingCookieOverride.toggle()
                    } label: {
                        Text(isShowingCookieOverride ? "Hide Cookie Override" : "Cookie / AuthUser")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingDirectLAN.toggle()
                    } label: {
                        Text(isShowingDirectLAN ? "Hide Direct LAN" : "Direct LAN / Bridge")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .buttonStyle(.plain)
                }

                if isShowingCookieOverride {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MANUAL GOOGLE COOKIE / AUTHUSER (OPTIONAL FOR SIMULATOR)")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.7)
                            .foregroundStyle(UEChromePalette.textMuted)

                        TextField("Cookie header (SAPISID=...; __Secure-1PSID=...)", text: $manualCookieInput)
                            .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        TextField("X-Goog-AuthUser index (optional, e.g. 0 or 2)", text: $manualAuthUserInput)
                            .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if isShowingDirectLAN {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DIRECT MAC LAN / COMPANION BRIDGE (OPTIONAL FALLBACK)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(UEChromePalette.textMuted)

                        TextField("http://<mac-ip>:8787 or antigravity://pair?...", text: $manualHostInput)
                            .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("input-host-url")

                        TextField("x-codeium-csrf-token", text: $manualCSRFToken)
                            .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("input-csrf-token")

                        TextField("Optional TLS SHA-256 Pin (leave blank for LAN TOFU)", text: $manualCertSHA256)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(UEChromePalette.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                            Text("Connect via Direct LAN / Bridge")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(UEChromePalette.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AntigravityTheme.surfaceElevated)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isConnectingToBackend)
                        .accessibilityIdentifier("btn-connect-direct")
                    }
                }

                if store.hasPairedBackend || store.isLiveBackendConnected {
                    Button {
                        Task {
                            await CloudRelayCookieExtractor.clearGoogleCookies()
                            await store.disconnectBackendAndClearKeychain()
                        }
                    } label: {
                        Text("Sign Out & Disconnect Host")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AntigravityTheme.statusError)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AntigravityTheme.statusError.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("btn-disconnect-host")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AntigravityTheme.canvasObsidian)
        .onAppear {
            if relayInstanceInput.isEmpty && !store.lastScannedRelayURL.isEmpty {
                relayInstanceInput = store.lastScannedRelayURL
            }
        }
        .onChange(of: externalScannerTrigger?.wrappedValue ?? false) { _, triggered in
            if triggered {
                isShowingQRScanner = true
                externalScannerTrigger?.wrappedValue = false
            }
        }
        .sheet(isPresented: $isShowingQRScanner) {
            RemoteControlQRScannerSheet(
                onScannedQR: { scannedValue in
                    isShowingQRScanner = false
                    handleScannedQRValue(scannedValue)
                },
                onDismiss: {
                    isShowingQRScanner = false
                }
            )
        }
        .sheet(isPresented: $isShowingGoogleSignIn) {
            CloudRelaySignInSheet(
                targetRelayURLString: relayInstanceInput.isEmpty ? SAPISIDHashGenerator.defaultOrigin : relayInstanceInput,
                onAuthenticated: { cookieHeader, finalURL, detectedAuthUser in
                    isShowingGoogleSignIn = false
                    let effectiveURL: String = {
                        if !relayInstanceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return relayInstanceInput
                        }
                        return finalURL ?? SAPISIDHashGenerator.defaultOrigin
                    }()
                    let authIdx = manualAuthUserInput.isEmpty ? detectedAuthUser : manualAuthUserInput
                    Task {
                        let ok = await store.connectCloudRelay(
                            relayURLString: effectiveURL,
                            sessionCookie: cookieHeader,
                            authUser: authIdx
                        )
                        if ok {
                            onConnected?()
                        }
                    }
                },
                onDismiss: {
                    isShowingGoogleSignIn = false
                }
            )
        }
    }

    private func handleScannedQRValue(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("antigravity://") && trimmed.contains("url=") {
            Task {
                let ok = await store.connectWithPairingURI(trimmed, fallbackCookie: manualCSRFToken)
                if ok {
                    onConnected?()
                }
            }
            return
        }
        relayInstanceInput = trimmed
        Task {
            await initiateCloudRelayConnection(targetInput: trimmed)
        }
    }

    private func initiateCloudRelayConnection(targetInput: String) async {
        let target = targetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveURL = target.isEmpty ? SAPISIDHashGenerator.defaultOrigin : target
        let explicitAuthUser = manualAuthUserInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : manualAuthUserInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Manual cookie override if entered
        let manualCookie = manualCookieInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualCookie.isEmpty {
            let ok = await store.connectCloudRelay(
                relayURLString: effectiveURL,
                sessionCookie: manualCookie,
                authUser: explicitAuthUser
            )
            if ok {
                onConnected?()
            }
            return
        }

        // 2. Existing Keychain or WKWebsiteDataStore Google session cookie
        var existingCookie: String? = nil
        var savedAuthUser = explicitAuthUser
        if let cached = await store.loadSavedSessionCookie() {
            existingCookie = cached.cookie
            if savedAuthUser == nil {
                savedAuthUser = cached.authUser
            }
        } else if let webKitCookie = await CloudRelayCookieExtractor.readGoogleCookieHeader() {
            existingCookie = webKitCookie
        }

        if let existingCookie, !existingCookie.isEmpty {
            let ok = await store.connectCloudRelay(
                relayURLString: effectiveURL,
                sessionCookie: existingCookie,
                authUser: savedAuthUser
            )
            if ok {
                onConnected?()
                return
            }
            // If existing session cookie expired (401/403), prompt interactive Google Sign-In
            if store.connectionStatusText.contains("Expired") {
                isShowingGoogleSignIn = true
            }
            return
        }

        // 3. First-time pairing -> open interactive Google Sign-In sheet (`WKWebView`)
        isShowingGoogleSignIn = true
    }
}
