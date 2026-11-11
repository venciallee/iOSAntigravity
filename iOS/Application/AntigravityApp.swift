import SwiftUI
import AntigravityData

@main
public struct AntigravityApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: AntigravitySessionStore
    @State private var activeVerifyCase: ESDDVerifySceneCase?

    public init() {
        let initialStore = AntigravitySessionStore.makeESDDVerificationStore()
        let launchCase = DebugSceneFactory.launchVerifyCase()
        if let launchCase {
            initialStore.configureForVerifyScene(launchCase)
        }
        self._store = State(initialValue: initialStore)
        self._activeVerifyCase = State(initialValue: launchCase)
    }

    public var body: some Scene {
        WindowGroup {
            AntigravityRootContainerView(store: store, activeVerifyCase: $activeVerifyCase)
                .preferredColorScheme(activeVerifyCase == .liveActivitySpec ? .light : .dark)
                .task {
                    guard activeVerifyCase == nil else { return }
                    let env = ProcessInfo.processInfo.environment
                    if let relayURL = env["ANTIGRAVITY_RELAY_URL"], !relayURL.isEmpty {
                        let cookie = env["ANTIGRAVITY_RELAY_COOKIE"] ?? ""
                        let authUser = env["ANTIGRAVITY_AUTHUSER"]
                        _ = await store.connectCloudRelay(
                            relayURLString: relayURL,
                            sessionCookie: cookie,
                            authUser: authUser,
                            hostName: env["ANTIGRAVITY_HOST_NAME"] ?? "Antigravity Desktop"
                        )
                    } else if let backendURL = env["ANTIGRAVITY_BACKEND_URL"], !backendURL.isEmpty {
                        let csrf = env["ANTIGRAVITY_CSRF_TOKEN"] ?? ""
                        let sha256 = env["ANTIGRAVITY_CERT_SHA256"]
                        _ = await store.connectDirectLAN(
                            endpointURLString: backendURL,
                            csrfToken: csrf,
                            certSHA256: sha256,
                            hostName: env["ANTIGRAVITY_HOST_NAME"] ?? "MacBook Pro"
                        )
                    } else {
                        _ = await store.restoreSavedBackendSession()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, activeVerifyCase == nil, store.hasPairedBackend else { return }
                    Task {
                        await store.refreshWorkspacesAndSummaries()
                    }
                }
                .onOpenURL { url in
                    if let sceneCase = DebugSceneFactory.resolveDeepLink(url) {
                        store.configureForVerifyScene(sceneCase)
                        activeVerifyCase = sceneCase
                        return
                    }
                    let rawURL = url.absoluteString
                    if (url.scheme?.lowercased() == "antigravity" && url.host?.lowercased() == "pair")
                        || RemoteHostInstance.parseRemoteControlQR(urlString: rawURL) != nil {
                        activeVerifyCase = nil
                        Task {
                            let webCookie = await CloudRelayCookieExtractor.readGoogleCookieHeader() ?? ""
                            let ok = await store.connectWithPairingURI(rawURL, fallbackCookie: webCookie)
                            if ok {
                                if case .cascadeChat = store.activeRoute {
                                    // Keep deep-linked conversation open (`?p=c%2F<cascadeId>`)
                                } else {
                                    store.activeRoute = .tabRoot
                                }
                            } else {
                                store.activeRoute = .pairingSettings
                            }
                        }
                    }
                }
        }
    }
}
