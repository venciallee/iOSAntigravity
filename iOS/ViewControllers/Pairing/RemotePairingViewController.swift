import SwiftUI
import AntigravityData
#if canImport(UIKit)
import UIKit
#endif

/// Minimalist Settings & Remote Control pairing screen (`RemotePairingViewController`).
/// Pairs directly by scanning Antigravity Desktop's official Remote Control QR code (`https://antigravity.google.com/r/<id>`)
/// over Google Cloud Relay across Wi-Fi & 5G.
public struct RemotePairingViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public var externalScannerTrigger: Binding<Bool>?
    public var onConnected: (() -> Void)?

    @State private var pendingRelayURL: String = ""
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingGoogleSignIn: Bool = false

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
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                    Text("Scan Antigravity Desktop's Remote Control QR code — works over Wi-Fi & 5G")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }

                // Single Primary Card: Tap to Scan Remote Control QR (or Live Connection Status)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
                    .frame(minHeight: 236)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                isOnlineConnected
                                    ? AntigravityTheme.statusDone.opacity(0.45)
                                    : (isOfflinePaired ? AntigravityTheme.statusError.opacity(0.50) : UEChromePalette.cardBorder),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        VStack(spacing: 12) {
                            if store.isConnectingToBackend {
                                ProgressView()
                                    .controlSize(.large)
                                    .tint(AntigravityTheme.accentPeriwinkle)
                                    .padding(.bottom, 4)

                                Text("Connecting to Antigravity...")
                                    .font(.system(size: 16.5, weight: .semibold))
                                    .foregroundStyle(Color.white)

                                Text(store.connectionStatusText)
                                    .font(.system(size: 12.5, weight: .regular))
                                    .foregroundStyle(UEChromePalette.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            } else {
                                Image(
                                    systemName: isOnlineConnected
                                        ? "checkmark.shield.fill"
                                        : (isOfflinePaired ? "wifi.slash" : "qrcode.viewfinder")
                                )
                                .font(.system(size: 48, weight: .light))
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
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.center)

                                Text(
                                    isOnlineConnected
                                        ? "\(store.activeHost.channel.displayName) · \(store.lastPingLatencyMs ?? store.activeHost.latencyMs)ms · \(store.summaries.count) sessions"
                                        : (isOfflinePaired
                                            ? "Auto-reconnecting · Tap below to retry or scan a new QR"
                                            : "Open Antigravity on Mac/PC → Remote Control")
                                )
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(UEChromePalette.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                                if isOfflinePaired {
                                    HStack(spacing: 10) {
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

                                        Button {
                                            isShowingQRScanner = true
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "qrcode.viewfinder")
                                                    .font(.system(size: 12.5, weight: .semibold))
                                                Text("Scan QR")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundStyle(UEChromePalette.textPrimary)
                                            .padding(.horizontal, 14)
                                            .frame(minHeight: 36)
                                            .background(Capsule().fill(UEChromePalette.surfacePill))
                                            .overlay(Capsule().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.top, 2)
                                } else if isOnlineConnected {
                                    Button {
                                        isShowingQRScanner = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "qrcode.viewfinder")
                                                .font(.system(size: 12.5, weight: .semibold))
                                            Text("Scan New QR")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 36)
                                        .background(Capsule().fill(UEChromePalette.surfacePill))
                                        .overlay(Capsule().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                }
                            }
                        }
                        .padding(24)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .onTapGesture {
                        if !store.isConnectingToBackend && !isOnlineConnected && !isOfflinePaired {
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

                // Multi-instance switcher (shown only when >1 Desktop instance is online on the signed-in Google account)
                if store.availableRelayInstances.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AVAILABLE HOSTS")
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
                                        Text("\(inst.status.badgeText) · \(inst.version)")
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
                targetRelayURLString: pendingRelayURL.isEmpty ? SAPISIDHashGenerator.defaultOrigin : pendingRelayURL,
                onAuthenticated: { cookieHeader, finalURL, detectedAuthUser in
                    isShowingGoogleSignIn = false
                    let effectiveURL = RemoteHostInstance.resolveEffectiveRelayTarget(
                        scannedInput: pendingRelayURL,
                        webViewFinalURL: finalURL
                    )
                    Task {
                        let ok = await store.connectCloudRelay(
                            relayURLString: effectiveURL,
                            sessionCookie: cookieHeader,
                            authUser: detectedAuthUser
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
        guard !trimmed.isEmpty else { return }
        if RemoteHostInstance.isDirectLANPairingURI(trimmed) {
            Task {
                let ok = await store.connectWithPairingURI(trimmed, fallbackCookie: "")
                if ok {
                    onConnected?()
                }
            }
            return
        }
        pendingRelayURL = trimmed
        Task {
            await initiateCloudRelayConnection(targetInput: trimmed)
        }
    }

    private func initiateCloudRelayConnection(targetInput: String) async {
        let target = targetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveURL = target.isEmpty ? SAPISIDHashGenerator.defaultOrigin : target

        // 1. Reuse existing Keychain or WKWebsiteDataStore Google session cookie if already signed in
        var existingCookie: String? = nil
        var savedAuthUser: String? = nil
        if let cached = await store.loadSavedSessionCookie() {
            existingCookie = cached.cookie
            savedAuthUser = cached.authUser
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
            // If cached Google session expired (401/403), automatically present Google Sign-In
            if store.connectionStatusText.contains("Expired") {
                isShowingGoogleSignIn = true
            }
            return
        }

        // 2. First-time pairing -> automatically present Google Sign-In sheet (`WKWebView`)
        isShowingGoogleSignIn = true
    }
}
