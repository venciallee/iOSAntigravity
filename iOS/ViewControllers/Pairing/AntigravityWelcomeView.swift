import SwiftUI
import AntigravityData
#if canImport(UIKit)
import UIKit
#endif

/// Clean first-launch Welcome screen (`AntigravityWelcomeView`) displayed when no host is paired yet.
/// Shows zero mock/demo data and provides a single action to scan Antigravity Desktop's Remote Control QR code.
public struct AntigravityWelcomeView: View {
    @Bindable public var store: AntigravitySessionStore
    public var onConnected: (() -> Void)?

    @State private var pendingRelayURL: String = ""
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingGoogleSignIn: Bool = false

    public init(
        store: AntigravitySessionStore,
        onConnected: (() -> Void)? = nil
    ) {
        self.store = store
        self.onConnected = onConnected
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                welcomeIconBadge
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(AntigravityTheme.accentPeriwinkle.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: AntigravityTheme.accentPeriwinkle.opacity(0.18), radius: 24, x: 0, y: 8)

                VStack(spacing: 8) {
                    Text("AG Orbit")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(Color.white)

                    Text("Companion for Antigravity")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.accentPeriwinkle)

                    Text("Scan the Remote Control QR code in Antigravity Desktop to sync your conversations over Wi-Fi or 5G.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }
            }

            Spacer()

            VStack(spacing: 14) {
                if !store.isInitialSessionCheckComplete || store.isConnectingToBackend {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(AntigravityTheme.accentPeriwinkle)

                        Text(
                            store.isConnectingToBackend
                                ? store.connectionStatusText
                                : "Checking saved connection..."
                        )
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                } else {
                    if let errorText = store.connectionErrorText, !errorText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AntigravityTheme.statusError)
                            Text(errorText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AntigravityTheme.statusError)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AntigravityTheme.statusError.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        isShowingQRScanner = true
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Scan Remote Control QR")
                                .font(.system(size: 16.5, weight: .semibold))
                        }
                        .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            Capsule()
                                .fill(AntigravityTheme.accentPeriwinkle)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("btn-welcome-scan-qr")

                    VStack(spacing: 4) {
                        Text("Open Antigravity on Mac / PC → Remote Control")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(UEChromePalette.textMuted)

                        Text("Independent third-party companion · Not affiliated with Google LLC")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(UEChromePalette.textMuted.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
        .accessibilityIdentifier("welcome-screen")
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

    @ViewBuilder
    private var welcomeIconBadge: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: "AntigravityAppIconPreview") {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        } else {
            fallbackWelcomeBadge
        }
        #else
        fallbackWelcomeBadge
        #endif
    }

    private var fallbackWelcomeBadge: some View {
        ZStack {
            AntigravityTheme.surfaceCard
            Image(systemName: "terminal")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AntigravityTheme.accentPeriwinkle)
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
            if store.connectionStatusText.contains("Expired") {
                isShowingGoogleSignIn = true
            }
            return
        }

        isShowingGoogleSignIn = true
    }
}
